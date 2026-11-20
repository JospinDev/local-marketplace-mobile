import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../data/catalogue_repository.dart';
import '../providers/catalogue_providers.dart';
import 'widgets/filtres_feuille.dart';
import 'widgets/produit_carte.dart';

/// Recherche dans le catalogue.
///
/// Deux details qui changent la sensation d'usage :
///
/// - **la saisie est amortie de 400 ms** : taper « guitare » declencherait
///   sept requetes, dont six inutiles. On attend que la frappe s'arrete ;
/// - **la page suivante se charge a 400 px du bas**, pas tout en bas :
///   sur un defilement rapide, atteindre la fin avant la reponse donne un
///   a-coup. Anticiper le rend invisible.
class RechercheScreen extends ConsumerStatefulWidget {
  const RechercheScreen({
    super.key,
    this.categorieInitiale,
    this.nomCategorie,
  });

  final int? categorieInitiale;
  final String? nomCategorie;

  @override
  ConsumerState<RechercheScreen> createState() => _RechercheScreenState();
}

class _RechercheScreenState extends ConsumerState<RechercheScreen> {
  final _saisie = TextEditingController();
  final _defilement = ScrollController();
  Timer? _amortisseur;

  @override
  void initState() {
    super.initState();
    _defilement.addListener(_surDefilement);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final filtres = FiltresCatalogue(
        categorieArbre: widget.categorieInitiale,
      );
      ref.read(rechercheProvider.notifier).lancer(filtres);
    });
  }

  @override
  void dispose() {
    _amortisseur?.cancel();
    _defilement.dispose();
    _saisie.dispose();
    super.dispose();
  }

  void _surDefilement() {
    if (!_defilement.hasClients) return;
    final reste = _defilement.position.maxScrollExtent -
        _defilement.position.pixels;
    if (reste < 400) {
      ref.read(rechercheProvider.notifier).pageSuivante();
    }
  }

  void _surSaisie(String texte) {
    _amortisseur?.cancel();
    _amortisseur = Timer(const Duration(milliseconds: 400), () {
      final etat = ref.read(rechercheProvider);
      ref.read(rechercheProvider.notifier).lancer(
            etat.filtres.copyWith(recherche: texte),
          );
    });
  }

  Future<void> _ouvrirFiltres() async {
    final etat = ref.read(rechercheProvider);
    final nouveaux = await showModalBottomSheet<FiltresCatalogue>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FiltresFeuille(filtres: etat.filtres),
    );
    if (nouveaux != null && mounted) {
      ref.read(rechercheProvider.notifier).lancer(nouveaux);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final etat = ref.watch(rechercheProvider);

    return GradientBackground(
      anime: false,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _EnTeteRecherche(
              controleur: _saisie,
              onChange: _surSaisie,
              onFiltres: _ouvrirFiltres,
              nombreFiltres: etat.filtres.nombreActifs,
            ),

            if (widget.nomCategorie != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaces.ecran,
                  0,
                  Espaces.ecran,
                  Espaces.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    label: Text(widget.nomCategorie!),
                    avatar: const Icon(Icons.category_outlined, size: 16),
                    onDeleted: () => context.goNamed(Routes.recherche),
                  ),
                ),
              ),

            // Compteur de resultats : il confirme que le filtre a pris
            // effet, meme quand la grille change peu.
            if (!etat.chargementInitial && etat.erreur == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaces.ecran,
                  0,
                  Espaces.ecran,
                  Espaces.xs,
                ),
                child: Row(
                  children: [
                    Text(
                      etat.total == 0
                          ? 'Aucun resultat'
                          : '${etat.total} annonce${etat.total > 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    _MenuTri(
                      tri: etat.filtres.tri,
                      onChange: (tri) => ref
                          .read(rechercheProvider.notifier)
                          .lancer(etat.filtres.copyWith(tri: tri)),
                    ),
                  ],
                ),
              ),

            Expanded(child: _Corps(etat: etat, defilement: _defilement)),
          ],
        ),
      ),
    );
  }
}

class _Corps extends ConsumerWidget {
  const _Corps({required this.etat, required this.defilement});

  final EtatRecherche etat;
  final ScrollController defilement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (etat.chargementInitial) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          Espaces.ecran,
          Espaces.xs,
          Espaces.ecran,
          Espaces.xxl,
        ),
        gridDelegate: _grille,
        itemCount: 6,
        itemBuilder: (_, _) => const SqueletteCarteProduit(),
      );
    }

    if (etat.erreur != null && etat.produits.isEmpty) {
      return EtatErreur(
        erreur: etat.erreur!,
        onReessayer: () => ref.read(rechercheProvider.notifier).rafraichir(),
      );
    }

    if (etat.estVide) {
      return EtatVide(
        titre: 'Aucune annonce trouvee',
        message: etat.filtres.aDesFiltres
            ? 'Essayez d\'elargir vos criteres : une autre categorie, '
                'une fourchette de prix plus large, ou un lieu moins precis.'
            : 'Il n\'y a pas encore d\'annonce correspondant a '
                'votre recherche.',
        libelleAction:
            etat.filtres.aDesFiltres ? 'Effacer les filtres' : null,
        onAction: etat.filtres.aDesFiltres
            ? () => ref.read(rechercheProvider.notifier).lancer(
                  FiltresCatalogue(recherche: etat.filtres.recherche),
                )
            : null,
      );
    }

    return RefreshIndicator(
      color: AppColors.emeraude,
      onRefresh: () => ref.read(rechercheProvider.notifier).rafraichir(),
      child: GridView.builder(
        controller: defilement,
        padding: const EdgeInsets.fromLTRB(
          Espaces.ecran,
          Espaces.xs,
          Espaces.ecran,
          Espaces.xxl,
        ),
        gridDelegate: _grille,
        // +1 pour la ligne de chargement de la page suivante.
        itemCount: etat.produits.length + (etat.chargementSuite ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= etat.produits.length) {
            return const SqueletteCarteProduit();
          }
          final produit = etat.produits[index];
          return ProduitCarte(
            produit: produit,
            etiquetteHero: 'recherche',
            onTap: () => context.pushNamed(
              Routes.produit,
              pathParameters: {'id': '${produit.id}'},
              extra: const {'hero': 'recherche'},
            ),
          )
              // L'animation ne joue que pour la premiere page : la rejouer
              // a chaque page chargee ferait clignoter toute la grille.
              .animate(delay: (index < 8 ? index * 45 : 0).ms)
              .fadeIn(duration: 280.ms)
              .slideY(begin: 0.15);
        },
      ),
    );
  }

  static const _grille = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: Espaces.sm,
    crossAxisSpacing: Espaces.sm,
    // Hauteur calee sur la carte : image (ratio 1.08) + bloc de texte.
    childAspectRatio: 0.63,
  );
}

class _EnTeteRecherche extends StatelessWidget {
  const _EnTeteRecherche({
    required this.controleur,
    required this.onChange,
    required this.onFiltres,
    required this.nombreFiltres,
  });

  final TextEditingController controleur;
  final ValueChanged<String> onChange;
  final VoidCallback onFiltres;
  final int nombreFiltres;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espaces.ecran,
        Espaces.sm,
        Espaces.ecran,
        Espaces.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Hero(
              tag: 'barre-recherche',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.only(left: Espaces.md),
                  decoration: BoxDecoration(
                    color: sombre ? AppColors.encreSurface : AppColors.blanc,
                    borderRadius: Rayons.champ,
                    border: Border.all(
                      color: sombre
                          ? AppColors.encreBordure
                          : AppColors.bordureClaire,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 21,
                        color: AppColors.emeraude,
                      ),
                      const SizedBox(width: Espaces.xs),
                      Expanded(
                        child: TextField(
                          controller: controleur,
                          onChanged: onChange,
                          textInputAction: TextInputAction.search,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Un produit, un lieu...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      ValueListenableBuilder(
                        valueListenable: controleur,
                        builder: (context, valeur, _) {
                          if (valeur.text.isEmpty) {
                            return const SizedBox(width: Espaces.sm);
                          }
                          return IconButton(
                            onPressed: () {
                              controleur.clear();
                              onChange('');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Effacer',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Espaces.xs),
          _BoutonFiltres(nombre: nombreFiltres, onTap: onFiltres),
        ],
      ),
    );
  }
}

class _BoutonFiltres extends StatelessWidget {
  const _BoutonFiltres({required this.nombre, required this.onTap});

  final int nombre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Rayons.champ,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.degradeMarque,
            borderRadius: Rayons.champ,
            boxShadow: AppColors.halo(AppColors.emeraude),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.tune_rounded, color: Colors.white, size: 21),
              if (nombre > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.or,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$nombre',
                      style: const TextStyle(
                        fontSize: 8.5,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.encre,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTri extends StatelessWidget {
  const _MenuTri({required this.tri, required this.onChange});

  final TriCatalogue tri;
  final ValueChanged<TriCatalogue> onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<TriCatalogue>(
      initialValue: tri,
      onSelected: onChange,
      tooltip: 'Trier',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: Rayons.carte),
      itemBuilder: (context) => TriCatalogue.values
          .map(
            (valeur) => PopupMenuItem(
              value: valeur,
              child: Row(
                children: [
                  if (valeur == tri)
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.emeraude,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: Espaces.xs),
                  Text(valeur.libelle),
                ],
              ),
            ),
          )
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.swap_vert_rounded,
            size: 16,
            color: theme.textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 3),
          Text(
            tri.libelle,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
