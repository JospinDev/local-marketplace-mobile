import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formats.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../data/catalogue_repository.dart';
import '../../domain/produit.dart';
import '../../providers/catalogue_providers.dart';

/// Feuille des filtres de recherche.
///
/// Elle travaille sur une COPIE des criteres et ne les renvoie qu'a la
/// validation : filtrer a chaque frappe relancerait une requete par
/// caractere, et empecherait de revenir en arriere si l'on se trompe.
///
/// Le champ de localisation est un simple texte, et c'est voulu : cote
/// serveur il n'y a ni table ni identifiant de lieu, seulement une
/// recherche « contient ». Une liste deroulante de provinces serait donc
/// un mensonge sur le fonctionnement reel.
class FiltresFeuille extends ConsumerStatefulWidget {
  const FiltresFeuille({super.key, required this.filtres});

  final FiltresCatalogue filtres;

  @override
  ConsumerState<FiltresFeuille> createState() => _FiltresFeuilleState();
}

class _FiltresFeuilleState extends ConsumerState<FiltresFeuille> {
  late FiltresCatalogue _brouillon = widget.filtres;
  late final _localisation =
      TextEditingController(text: widget.filtres.localisation);
  late final _prixMin = TextEditingController(
    text: widget.filtres.prixMin?.round().toString() ?? '',
  );
  late final _prixMax = TextEditingController(
    text: widget.filtres.prixMax?.round().toString() ?? '',
  );

  @override
  void dispose() {
    _localisation.dispose();
    _prixMin.dispose();
    _prixMax.dispose();
    super.dispose();
  }

  void _appliquer() {
    final filtres = _brouillon.copyWith(
      localisation: _localisation.text.trim(),
      prixMin: double.tryParse(_prixMin.text.trim()),
      prixMax: double.tryParse(_prixMax.text.trim()),
      viderPrix: _prixMin.text.trim().isEmpty && _prixMax.text.trim().isEmpty,
    );
    Navigator.of(context).pop(filtres);
  }

  void _toutEffacer() {
    setState(() {
      _brouillon = FiltresCatalogue(recherche: widget.filtres.recherche);
      _localisation.clear();
      _prixMin.clear();
      _prixMax.clear();
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);
    final clavier = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: clavier),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, defilement) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaces.ecran,
                0,
                Espaces.ecran,
                Espaces.sm,
              ),
              child: Row(
                children: [
                  Text('Filtrer', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  if (_brouillon.aDesFiltres)
                    TextButton.icon(
                      onPressed: _toutEffacer,
                      icon: const Icon(Icons.restart_alt_rounded, size: 17),
                      label: const Text('Tout effacer'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.erreur,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: defilement,
                padding: const EdgeInsets.fromLTRB(
                  Espaces.ecran,
                  Espaces.lg,
                  Espaces.ecran,
                  Espaces.lg,
                ),
                children: [
                  // ------------------------------------- categories
                  const _Titre('Categorie'),
                  const SizedBox(height: Espaces.sm),
                  categories.when(
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (_, _) => Text(
                      'Categories indisponibles.',
                      style: theme.textTheme.bodySmall,
                    ),
                    data: (liste) => Wrap(
                      spacing: Espaces.xs,
                      runSpacing: Espaces.xs,
                      children: [
                        _Puce(
                          texte: 'Toutes',
                          choisie: _brouillon.categorieArbre == null,
                          onTap: () => setState(
                            () => _brouillon =
                                _brouillon.copyWith(viderCategorie: true),
                          ),
                        ),
                        for (final categorie in liste)
                          _Puce(
                            texte: categorie.nom,
                            choisie:
                                _brouillon.categorieArbre == categorie.id,
                            onTap: () => setState(
                              () => _brouillon = _brouillon.copyWith(
                                categorieArbre: categorie.id,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: Espaces.xl),

                  // ------------------------------------------- etat
                  const _Titre('Etat'),
                  const SizedBox(height: Espaces.sm),
                  Wrap(
                    spacing: Espaces.xs,
                    children: [
                      _Puce(
                        texte: 'Peu importe',
                        choisie: _brouillon.etat == null,
                        onTap: () => setState(
                          () => _brouillon =
                              _brouillon.copyWith(viderEtat: true),
                        ),
                      ),
                      for (final etat in EtatProduit.values)
                        _Puce(
                          texte: etat.libelle,
                          choisie: _brouillon.etat == etat,
                          onTap: () => setState(
                            () => _brouillon =
                                _brouillon.copyWith(etat: etat),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: Espaces.xl),

                  // ------------------------------------------- prix
                  const _Titre('Prix (BIF)'),
                  const SizedBox(height: Espaces.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controleur: _prixMin,
                          libelle: 'Minimum',
                          indice: '0',
                          typeClavier: TextInputType.number,
                          formateurs: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                      const SizedBox(width: Espaces.sm),
                      Expanded(
                        child: AppTextField(
                          controleur: _prixMax,
                          libelle: 'Maximum',
                          indice: 'illimite',
                          typeClavier: TextInputType.number,
                          formateurs: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: Espaces.xl),

                  // ----------------------------------- localisation
                  const _Titre('Localisation'),
                  const SizedBox(height: Espaces.sm),
                  AppTextField(
                    controleur: _localisation,
                    libelle: 'Lieu',
                    indice: 'Taba, Kinindo, Gitega...',
                    icone: Icons.place_outlined,
                  ),
                  const SizedBox(height: Espaces.xs),
                  Text(
                    'Recherche par mot contenu : « taba » trouve aussi '
                    '« Kamenge pres de Taba ». Ecrivez librement.',
                    style: theme.textTheme.bodySmall,
                  ),

                  const SizedBox(height: Espaces.xl),

                  // ------------------------------------ disponible
                  SwitchListTile.adaptive(
                    value: _brouillon.disponibleSeulement,
                    onChanged: (v) => setState(
                      () => _brouillon =
                          _brouillon.copyWith(disponibleSeulement: v),
                    ),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Uniquement ce qui est disponible',
                      style: theme.textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      'Masque les annonces en rupture de stock.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                Espaces.ecran,
                Espaces.sm,
                Espaces.ecran,
                Espaces.md + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: AppButton(
                libelle: 'Voir les resultats',
                icone: Icons.check_rounded,
                onPressed: _appliquer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) =>
      Text(texte, style: Theme.of(context).textTheme.titleMedium);
}

class _Puce extends StatelessWidget {
  const _Puce({
    required this.texte,
    required this.choisie,
    required this.onTap,
  });

  final String texte;
  final bool choisie;
  final VoidCallback onTap;

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
          curve: Mouvements.sortie,
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

/// Resume textuel des filtres actifs, utilisable dans un en-tete.
String resumerFiltres(FiltresCatalogue filtres) {
  final morceaux = <String>[];
  if (filtres.etat != null) morceaux.add(filtres.etat!.libelle);
  if (filtres.prixMin != null || filtres.prixMax != null) {
    final min = filtres.prixMin == null
        ? '0'
        : Formats.montantCourt(filtres.prixMin!);
    final max = filtres.prixMax == null
        ? '∞'
        : Formats.montantCourt(filtres.prixMax!);
    morceaux.add('$min – $max BIF');
  }
  if (filtres.localisation?.isNotEmpty ?? false) {
    morceaux.add(filtres.localisation!);
  }
  if (filtres.disponibleSeulement) morceaux.add('disponible');
  return morceaux.join(' · ');
}

/// Petite etiquette reutilisee par la fiche produit.
Widget etiquetteEtat(EtatProduit etat) => Etiquette(
      texte: etat.libelle,
      couleur:
          etat == EtatProduit.neuf ? AppColors.emeraude : AppColors.sarcelle,
    );
