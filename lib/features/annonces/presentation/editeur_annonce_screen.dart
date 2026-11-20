import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validateurs.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/reseau_image.dart';
import '../../catalogue/domain/produit.dart';
import '../../catalogue/providers/catalogue_providers.dart';
import '../providers/annonces_providers.dart';

/// Creation et modification d'une annonce.
///
/// Le parcours de publication du guide, dans l'ordre :
///
/// 1. `POST /products/` → l'annonce nait en `DRAFT` ;
/// 2. `PATCH /products/{id}/stock/` → la quantite ;
/// 3. `POST /products/{id}/images/` → les photos ;
/// 4. `POST /products/{id}/publish/` → elle passe en ligne.
///
/// L'ecran enchaine ces quatre appels, mais ne les montre pas : du point
/// de vue du vendeur, il remplit un formulaire et appuie sur « Publier ».
/// Les etapes 2 a 4 sont facultatives — un brouillon sans stock ni photo
/// reste valide, et le serveur le mettra en `OUT_OF_STOCK` plutot que de
/// refuser la publication.
class EditeurAnnonceScreen extends ConsumerStatefulWidget {
  const EditeurAnnonceScreen({super.key, this.annonceId});

  /// `null` = creation. Sinon, modification.
  final int? annonceId;

  @override
  ConsumerState<EditeurAnnonceScreen> createState() =>
      _EditeurAnnonceScreenState();
}

class _EditeurAnnonceScreenState
    extends ConsumerState<EditeurAnnonceScreen> {
  final _formulaire = GlobalKey<FormState>();
  final _titre = TextEditingController();
  final _description = TextEditingController();
  final _prix = TextEditingController();
  final _localisation = TextEditingController();
  final _quantite = TextEditingController(text: '1');

  int? _categorie;
  EtatProduit _etat = EtatProduit.neuf;
  final List<File> _nouvellesPhotos = [];
  List<ImageProduit> _photosExistantes = const [];

  bool _chargementInitial = false;
  bool _enCours = false;
  String _etapeEnCours = '';
  Map<String, String> _erreurs = {};

  bool get _estModification => widget.annonceId != null;

  @override
  void initState() {
    super.initState();
    if (_estModification) _chargerAnnonce();
  }

  @override
  void dispose() {
    for (final c in [
      _titre,
      _description,
      _prix,
      _localisation,
      _quantite,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerAnnonce() async {
    setState(() => _chargementInitial = true);
    try {
      final annonce = await ref
          .read(annoncesRepositoryProvider)
          .annonce(widget.annonceId!);
      if (!mounted) return;
      setState(() {
        _titre.text = annonce.titre;
        _description.text = annonce.description ?? '';
        _prix.text = annonce.prix.round().toString();
        _localisation.text = annonce.localisation ?? '';
        _categorie = annonce.categorie;
        _etat = annonce.etat;
        _photosExistantes = annonce.images;
        _chargementInitial = false;
      });
    } on ApiException catch (erreur) {
      if (!mounted) return;
      setState(() => _chargementInitial = false);
      AppFeedback.erreur(context, erreur.message);
    }
  }

  Future<void> _choisirPhotos() async {
    final selecteur = ImagePicker();
    try {
      final fichiers = await selecteur.pickMultiImage(
        // On compresse a la source : une photo de telephone pese 4 Mo,
        // et televerser cela sur un reseau mobile burundais prendrait
        // une minute par image. 1600 px suffisent largement a une
        // annonce.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (fichiers.isEmpty || !mounted) return;
      setState(() {
        _nouvellesPhotos.addAll(fichiers.map((x) => File(x.path)));
      });
    } catch (erreur) {
      if (!mounted) return;
      AppFeedback.erreur(
        context,
        "Acces aux photos impossible. Verifiez l'autorisation.",
      );
    }
  }

  Future<void> _enregistrer({required bool publier}) async {
    FocusScope.of(context).unfocus();
    setState(() => _erreurs = {});

    if (!_formulaire.currentState!.validate()) return;
    if (_categorie == null) {
      AppFeedback.attention(context, 'Choisissez une categorie.');
      return;
    }

    setState(() {
      _enCours = true;
      _etapeEnCours = _estModification
          ? 'Enregistrement...'
          : 'Creation de l\'annonce...';
    });

    final depot = ref.read(annoncesRepositoryProvider);

    try {
      // --- 1. creer ou modifier --------------------------------------
      Produit annonce;
      if (_estModification) {
        annonce = await depot.modifier(widget.annonceId!, {
          'titre': _titre.text.trim(),
          'description': _description.text.trim(),
          'categorie': _categorie,
          'prix': (double.tryParse(_prix.text.trim()) ?? 0)
              .toStringAsFixed(2),
          'etat': _etat.code,
          'localisation': _localisation.text.trim(),
        });
      } else {
        annonce = await depot.creer(
          titre: _titre.text,
          categorie: _categorie!,
          prix: double.tryParse(_prix.text.trim()) ?? 0,
          description: _description.text,
          etat: _etat,
          localisation: _localisation.text,
        );
      }

      // --- 2. stock ----------------------------------------------------
      final quantite = int.tryParse(_quantite.text.trim());
      if (quantite != null && !_estModification) {
        setState(() => _etapeEnCours = 'Enregistrement du stock...');
        await depot.majStock(annonce.id, quantite);
      }

      // --- 3. photos ---------------------------------------------------
      if (_nouvellesPhotos.isNotEmpty) {
        setState(
          () => _etapeEnCours =
              'Envoi de ${_nouvellesPhotos.length} photo(s)...',
        );
        await depot.ajouterImages(
          annonce.id,
          _nouvellesPhotos,
          // La premiere image ajoutee devient principale cote serveur ;
          // on ne force le drapeau que si l'annonce n'en avait aucune.
          principale: _photosExistantes.isEmpty,
        );
      }

      // --- 4. publier --------------------------------------------------
      if (publier) {
        setState(() => _etapeEnCours = 'Mise en ligne...');
        annonce = await depot.publier(annonce.id);
      }

      if (!mounted) return;

      // On recharge la liste : le statut final depend du serveur
      // (ACTIVE ou OUT_OF_STOCK selon le stock disponible).
      await ref.read(annoncesProvider.notifier).charger();
      if (!mounted) return;

      context.pop();
      AppFeedback.succes(
        context,
        publier
            ? (annonce.statut == StatutProduit.rupture
                ? 'Annonce en ligne, mais sans stock disponible.'
                : 'Annonce en ligne.')
            : 'Brouillon enregistre.',
      );
    } on ApiException catch (erreur) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreurs = erreur.erreursChamps;
      });
      AppFeedback.erreur(context, erreur.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      body: GradientBackground(
        anime: false,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaces.sm,
                  Espaces.xs,
                  Espaces.ecran,
                  Espaces.xs,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _enCours ? null : () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Retour',
                    ),
                    const SizedBox(width: Espaces.xs),
                    Text(
                      _estModification
                          ? 'Modifier l\'annonce'
                          : 'Nouvelle annonce',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),

              if (_chargementInitial)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: Form(
                    key: _formulaire,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        Espaces.ecran,
                        Espaces.xs,
                        Espaces.ecran,
                        Espaces.xxl,
                      ),
                      children: [
                        // ------------------------------- photos
                        const _Section(
                          titre: 'Photos',
                          sousTitre:
                              'La premiere devient la photo principale.',
                        ),
                        const SizedBox(height: Espaces.sm),
                        _GaleriePhotos(
                          existantes: _photosExistantes,
                          nouvelles: _nouvellesPhotos,
                          actif: !_enCours,
                          onAjouter: _choisirPhotos,
                          onRetirerNouvelle: (index) => setState(
                            () => _nouvellesPhotos.removeAt(index),
                          ),
                          onRetirerExistante: _supprimerPhotoExistante,
                        ).animate().fadeIn().slideY(begin: 0.15),

                        const SizedBox(height: Espaces.xl),

                        // ------------------------------ essentiel
                        const _Section(titre: 'L\'essentiel'),
                        const SizedBox(height: Espaces.sm),
                        AppTextField(
                          controleur: _titre,
                          libelle: 'Titre',
                          indice: 'Guitare acoustique Yamaha F310',
                          icone: Icons.title_rounded,
                          validateur: (v) =>
                              Validateurs.requis(v, champ: 'Le titre'),
                          erreurServeur: _erreurs['titre'],
                          actif: !_enCours,
                          maxCaracteres: 200,
                        ),
                        const SizedBox(height: Espaces.md),

                        categories.when(
                          loading: () =>
                              const LinearProgressIndicator(minHeight: 2),
                          error: (erreur, _) => EtatErreur(
                            erreur: erreur,
                            onReessayer: () =>
                                ref.invalidate(categoriesProvider),
                          ),
                          data: (liste) => _ChoixCategorie(
                            categories: liste,
                            choisie: _categorie,
                            erreur: _erreurs['categorie'],
                            actif: !_enCours,
                            onChange: (id) => setState(() => _categorie = id),
                          ),
                        ),

                        const SizedBox(height: Espaces.md),

                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: AppTextField(
                                controleur: _prix,
                                libelle: 'Prix (BIF)',
                                indice: '250000',
                                icone: Icons.payments_outlined,
                                typeClavier: TextInputType.number,
                                validateur: (v) {
                                  final vide = Validateurs.requis(
                                    v,
                                    champ: 'Le prix',
                                  );
                                  if (vide != null) return vide;
                                  final valeur =
                                      double.tryParse(v!.trim());
                                  if (valeur == null || valeur < 0) {
                                    return 'Prix invalide.';
                                  }
                                  return null;
                                },
                                erreurServeur: _erreurs['prix'],
                                actif: !_enCours,
                              ),
                            ),
                            if (!_estModification) ...[
                              const SizedBox(width: Espaces.sm),
                              Expanded(
                                child: AppTextField(
                                  controleur: _quantite,
                                  libelle: 'Quantite',
                                  indice: '1',
                                  icone: Icons.inventory_2_outlined,
                                  typeClavier: TextInputType.number,
                                  actif: !_enCours,
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: Espaces.md),
                        _ChoixEtat(
                          etat: _etat,
                          actif: !_enCours,
                          onChange: (e) => setState(() => _etat = e),
                        ),

                        const SizedBox(height: Espaces.xl),

                        // ------------------------------- details
                        const _Section(titre: 'Details'),
                        const SizedBox(height: Espaces.sm),
                        AppTextField(
                          controleur: _description,
                          libelle: 'Description',
                          indice: 'Etat, accessoires inclus, '
                              'conditions de retrait...',
                          icone: Icons.notes_rounded,
                          lignes: 5,
                          maxCaracteres: 2000,
                          erreurServeur: _erreurs['description'],
                          actif: !_enCours,
                        ),
                        const SizedBox(height: Espaces.md),
                        AppTextField(
                          controleur: _localisation,
                          libelle: 'Localisation',
                          indice: 'Kinindo pres du marche',
                          icone: Icons.place_outlined,
                          erreurServeur: _erreurs['localisation'],
                          actif: !_enCours,
                        ),
                        const SizedBox(height: Espaces.xs),
                        Text(
                          'Texte libre : un quartier, une commune ou un '
                          'point de rencontre. Vous n\'avez pas a donner '
                          'votre adresse exacte.',
                          style: theme.textTheme.bodySmall,
                        ),

                        if (_estModification) ...[
                          const SizedBox(height: Espaces.lg),
                          Container(
                            padding: const EdgeInsets.all(Espaces.sm),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.08),
                              borderRadius: Rayons.champ,
                              border: Border.all(
                                color:
                                    AppColors.info.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 17,
                                  color: AppColors.info,
                                ),
                                const SizedBox(width: Espaces.xs),
                                Expanded(
                                  child: Text(
                                    'Le stock se modifie depuis la liste '
                                    'de vos annonces : il est lie aux '
                                    'reservations en cours.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _chargementInitial
          ? null
          : _BarreEnregistrement(
              enCours: _enCours,
              etape: _etapeEnCours,
              estModification: _estModification,
              onBrouillon: () => _enregistrer(publier: false),
              onPublier: () => _enregistrer(publier: true),
            ),
    );
  }

  Future<void> _supprimerPhotoExistante(int imageId) async {
    try {
      await ref
          .read(annoncesRepositoryProvider)
          .supprimerImage(widget.annonceId!, imageId);
      if (!mounted) return;
      setState(
        () => _photosExistantes =
            _photosExistantes.where((i) => i.id != imageId).toList(),
      );
    } on ApiException catch (erreur) {
      if (!mounted) return;
      AppFeedback.erreur(context, erreur.message);
    }
  }
}

// ------------------------------------------------------------- fragments
class _GaleriePhotos extends StatelessWidget {
  const _GaleriePhotos({
    required this.existantes,
    required this.nouvelles,
    required this.actif,
    required this.onAjouter,
    required this.onRetirerNouvelle,
    required this.onRetirerExistante,
  });

  final List<ImageProduit> existantes;
  final List<File> nouvelles;
  final bool actif;
  final VoidCallback onAjouter;
  final ValueChanged<int> onRetirerNouvelle;
  final ValueChanged<int> onRetirerExistante;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _BoutonAjout(actif: actif, onTap: onAjouter),
          const SizedBox(width: Espaces.xs),
          for (final image in existantes) ...[
            _Vignette(
              enfant: ReseauImage(
                url: image.url,
                largeur: 96,
                hauteur: 96,
              ),
              principale: image.estPrincipale,
              onRetirer: actif ? () => onRetirerExistante(image.id) : null,
            ),
            const SizedBox(width: Espaces.xs),
          ],
          for (var i = 0; i < nouvelles.length; i++) ...[
            _Vignette(
              enfant: Image.file(
                nouvelles[i],
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
              nouvelle: true,
              onRetirer: actif ? () => onRetirerNouvelle(i) : null,
            ),
            const SizedBox(width: Espaces.xs),
          ],
        ],
      ),
    );
  }
}

class _BoutonAjout extends StatelessWidget {
  const _BoutonAjout({required this.actif, required this.onTap});

  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: actif ? onTap : null,
        borderRadius: BorderRadius.circular(Rayons.sm),
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rayons.sm),
            border: Border.all(
              color: AppColors.emeraude.withValues(alpha: 0.45),
              width: 1.4,
            ),
            color: AppColors.emeraude.withValues(alpha: 0.07),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_a_photo_outlined,
                color: AppColors.emeraude,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                'Ajouter',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.emeraude,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette({
    required this.enfant,
    this.principale = false,
    this.nouvelle = false,
    this.onRetirer,
  });

  final Widget enfant;
  final bool principale;
  final bool nouvelle;
  final VoidCallback? onRetirer;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Rayons.sm),
          child: enfant,
        ),
        if (principale)
          const Positioned(
            bottom: 4,
            left: 4,
            child: Etiquette(
              texte: 'Principale',
              couleur: AppColors.or,
              compacte: true,
            ),
          ),
        if (nouvelle)
          const Positioned(
            bottom: 4,
            left: 4,
            child: Etiquette(
              texte: 'Nouvelle',
              couleur: AppColors.emeraude,
              compacte: true,
            ),
          ),
        if (onRetirer != null)
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: AppColors.encre.withValues(alpha: 0.6),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRetirer,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChoixCategorie extends StatelessWidget {
  const _ChoixCategorie({
    required this.categories,
    required this.choisie,
    required this.actif,
    required this.onChange,
    this.erreur,
  });

  final List categories;
  final int? choisie;
  final bool actif;
  final ValueChanged<int> onChange;
  final String? erreur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: Espaces.xs),
          child: Text(
            'Categorie',
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 13,
              color: sombre
                  ? AppColors.texteClairDoux
                  : AppColors.texteSombreDoux,
            ),
          ),
        ),
        Wrap(
          spacing: Espaces.xs,
          runSpacing: Espaces.xs,
          children: [
            for (final categorie in categories)
              _Puce(
                texte: categorie.nom as String,
                choisie: choisie == categorie.id,
                onTap: actif ? () => onChange(categorie.id as int) : null,
              ),
          ],
        ),
        if (erreur != null)
          Padding(
            padding: const EdgeInsets.only(top: Espaces.xs),
            child: Text(
              erreur!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.erreur,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _ChoixEtat extends StatelessWidget {
  const _ChoixEtat({
    required this.etat,
    required this.actif,
    required this.onChange,
  });

  final EtatProduit etat;
  final bool actif;
  final ValueChanged<EtatProduit> onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: Espaces.xs),
          child: Text(
            'Etat',
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 13,
              color: sombre
                  ? AppColors.texteClairDoux
                  : AppColors.texteSombreDoux,
            ),
          ),
        ),
        Row(
          children: [
            for (final valeur in EtatProduit.values) ...[
              _Puce(
                texte: valeur.libelle,
                choisie: etat == valeur,
                onTap: actif ? () => onChange(valeur) : null,
              ),
              const SizedBox(width: Espaces.xs),
            ],
          ],
        ),
      ],
    );
  }
}

class _Puce extends StatelessWidget {
  const _Puce({
    required this.texte,
    required this.choisie,
    required this.onTap,
  });

  final String texte;
  final bool choisie;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rayons.pilule),
        child: AnimatedContainer(
          duration: Mouvements.rapide,
          padding: const EdgeInsets.symmetric(
            horizontal: Espaces.md,
            vertical: Espaces.xs + 1,
          ),
          decoration: BoxDecoration(
            gradient: choisie ? AppColors.degradeMarque : null,
            color: choisie
                ? null
                : (sombre ? AppColors.encreSurface : AppColors.blanc),
            borderRadius: BorderRadius.circular(Rayons.pilule),
            border: Border.all(
              color: choisie
                  ? Colors.transparent
                  : (sombre
                      ? AppColors.encreBordure
                      : AppColors.bordureClaire),
            ),
          ),
          child: Text(
            texte,
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 13,
              color: choisie ? Colors.white : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.titre, this.sousTitre});

  final String titre;
  final String? sousTitre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre, style: theme.textTheme.titleMedium),
        if (sousTitre != null)
          Text(sousTitre!, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Barre basse : brouillon a gauche, publication a droite.
///
/// Les deux boutons existent parce que les deux usages existent : on
/// prepare une annonce le soir et on la publie le lendemain avec les
/// photos. Forcer la publication immediate perdrait ce travail.
class _BarreEnregistrement extends StatelessWidget {
  const _BarreEnregistrement({
    required this.enCours,
    required this.etape,
    required this.estModification,
    required this.onBrouillon,
    required this.onPublier,
  });

  final bool enCours;
  final String etape;
  final bool estModification;
  final VoidCallback onBrouillon;
  final VoidCallback onPublier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        Espaces.ecran,
        Espaces.sm,
        Espaces.ecran,
        Espaces.sm + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: sombre ? AppColors.encreSurface : AppColors.blanc,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // L'etape en cours est nommee : televerser trois photos prend
          // du temps, et un voyant muet laisse croire a un blocage.
          AnimatedSize(
            duration: Mouvements.rapide,
            child: enCours && etape.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: Espaces.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: Espaces.xs),
                        Text(etape, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  libelle: 'Brouillon',
                  style: StyleBouton.secondaire,
                  icone: Icons.save_outlined,
                  compact: true,
                  onPressed: enCours ? null : onBrouillon,
                ),
              ),
              const SizedBox(width: Espaces.xs),
              Expanded(
                flex: 2,
                child: AppButton(
                  libelle: estModification ? 'Enregistrer' : 'Publier',
                  icone: Icons.publish_rounded,
                  compact: true,
                  enChargement: enCours,
                  onPressed: onPublier,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
