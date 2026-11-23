import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../auth/providers/auth_provider.dart';
import '../../favoris/providers/favoris_providers.dart';
import '../domain/categorie.dart';
import '../domain/produit.dart';
import '../providers/catalogue_providers.dart';
import 'widgets/produit_carte.dart';

/// Accueil du catalogue.
///
/// Trois rangees, chargees en parallele : mises en avant, nouveautes,
/// populaires. Elles viennent de trois routes distinctes du serveur, et
/// la grille complete est a un appui de la (onglet Recherche).
class AccueilScreen extends ConsumerWidget {
  const AccueilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final utilisateur = ref.watch(utilisateurProvider);
    final accueil = ref.watch(accueilProvider);
    final categories = ref.watch(categoriesProvider);

    return GradientBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.emeraude,
          onRefresh: () async {
            ref.invalidate(accueilProvider);
            ref.invalidate(categoriesProvider);
            await ref.read(accueilProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              // ------------------------------------------- en-tete
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaces.ecran,
                    Espaces.sm,
                    Espaces.ecran,
                    0,
                  ),
                  child: Row(
                    children: [
                      const BrandLockup(taille: 30),
                      const Spacer(),
                      // Les favoris n'ont plus d'onglet depuis que
                      // « Vendre » a pris sa place : le coeur de
                      // l'en-tete y conduit, avec une pastille quand un
                      // prix a bouge.
                      Consumer(
                        builder: (context, ref, _) {
                          final alertes = ref.watch(
                            favorisProvider.select(
                              (e) => e.avecAlerte.length,
                            ),
                          );
                          return _BoutonRond(
                            icone: Icons.favorite_border_rounded,
                            pastille: alertes,
                            onTap: () => context.pushNamed(Routes.mesListes),
                          );
                        },
                      ),
                      const SizedBox(width: Espaces.xs),
                      _BoutonRond(
                        icone: Icons.notifications_none_rounded,
                        onTap: () => context.goNamed(Routes.compte),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaces.ecran,
                    Espaces.md,
                    Espaces.ecran,
                    Espaces.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        utilisateur != null
                            ? 'Bonjour ${utilisateur.nomAffiche},'
                            : 'Bienvenue,',
                        style: theme.textTheme.bodyLarge,
                      ).animate(delay: 60.ms).fadeIn().slideX(begin: -0.12),
                      const SizedBox(height: 2),
                      Text(
                        'que cherchez-vous ?',
                        style: theme.textTheme.headlineLarge
                            ?.copyWith(height: 1.15),
                      ).animate(delay: 110.ms).fadeIn().slideY(begin: 0.18),
                      const SizedBox(height: Espaces.lg),
                      _BarreRechercheFactice(
                        onTap: () => context.goNamed(Routes.recherche),
                      ).animate(delay: 160.ms).fadeIn().slideY(begin: 0.2),
                    ],
                  ),
                ),
              ),

              // ---------------------------------------- categories
              SliverToBoxAdapter(
                child: categories.when(
                  loading: () => const _RangeeSquelettePuces(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (liste) => liste.isEmpty
                      ? const SizedBox.shrink()
                      : _RangeeCategories(categories: liste),
                ),
              ),

              // ------------------------------------------ produits
              ...accueil.when(
                loading: () => [const _SqueletteAccueil()],
                error: (erreur, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EtatErreur(
                      erreur: erreur,
                      onReessayer: () => ref.invalidate(accueilProvider),
                    ),
                  ),
                ],
                data: (contenu) {
                  if (contenu.estVide) {
                    return [
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EtatVide(
                          titre: 'Le catalogue est vide',
                          message:
                              'Aucune annonce publiee pour le moment. '
                              'Revenez bientot, ou publiez la votre.',
                          icone: Icons.storefront_outlined,
                        ),
                      ),
                    ];
                  }

                  return [
                    if (contenu.misesEnAvant.isNotEmpty)
                      _Carrousel(
                        titre: 'Mis en avant',
                        icone: Icons.star_rounded,
                        couleurIcone: AppColors.or,
                        produits: contenu.misesEnAvant,
                        cle: 'avant',
                      ),
                    if (contenu.dernieres.isNotEmpty)
                      _Carrousel(
                        titre: 'Nouveautes',
                        icone: Icons.auto_awesome_rounded,
                        couleurIcone: AppColors.emeraude,
                        produits: contenu.dernieres,
                        cle: 'recent',
                      ),
                    if (contenu.populaires.isNotEmpty)
                      _Carrousel(
                        titre: 'Les plus vus',
                        icone: Icons.local_fire_department_rounded,
                        couleurIcone: AppColors.erreur,
                        produits: contenu.populaires,
                        cle: 'populaire',
                      ),
                  ];
                },
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: Espaces.xxl),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barre de recherche non editable : un appui ouvre l'onglet Recherche.
///
/// Dupliquer un vrai champ ici obligerait a synchroniser deux etats de
/// saisie ; le `Hero` fait croire a une seule barre qui se deplace.
class _BarreRechercheFactice extends StatelessWidget {
  const _BarreRechercheFactice({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return Hero(
      tag: 'barre-recherche',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: Rayons.champ,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: Espaces.md),
            decoration: BoxDecoration(
              color: sombre ? AppColors.encreSurface : AppColors.blanc,
              borderRadius: Rayons.champ,
              border: Border.all(
                color: sombre
                    ? AppColors.encreBordure
                    : AppColors.bordureClaire,
              ),
              boxShadow: AppColors.ombreCarte(sombre: sombre),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 21,
                  color: AppColors.emeraude,
                ),
                const SizedBox(width: Espaces.sm),
                Expanded(
                  child: Text(
                    'Un produit, un lieu, une categorie...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: AppColors.degradeMarque,
                    borderRadius: BorderRadius.circular(Rayons.xs),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RangeeCategories extends StatelessWidget {
  const _RangeeCategories({required this.categories});

  final List<Categorie> categories;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Espaces.ecran),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: Espaces.xs),
        itemBuilder: (context, index) {
          final categorie = categories[index];
          return _PuceCategorie(categorie: categorie)
              .animate(delay: (index * 50).ms)
              .fadeIn()
              .slideX(begin: 0.25);
        },
      ),
    );
  }
}

class _PuceCategorie extends StatelessWidget {
  const _PuceCategorie({required this.categorie});

  final Categorie categorie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rayons.pilule),
        onTap: () => context.goNamed(
          Routes.recherche,
          queryParameters: {
            'categorie': '${categorie.id}',
            'nom': categorie.nom,
          },
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Espaces.md,
            vertical: Espaces.xs,
          ),
          decoration: BoxDecoration(
            color: sombre ? AppColors.encreSurface : AppColors.blanc,
            borderRadius: BorderRadius.circular(Rayons.pilule),
            border: Border.all(
              color: sombre
                  ? AppColors.encreBordure
                  : AppColors.bordureClaire,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                categorie.nom,
                style: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
              ),
              if (categorie.nombreSousCategories > 0) ...[
                const SizedBox(width: 5),
                Icon(
                  Icons.expand_more_rounded,
                  size: 15,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Carrousel extends StatelessWidget {
  const _Carrousel({
    required this.titre,
    required this.icone,
    required this.couleurIcone,
    required this.produits,
    required this.cle,
  });

  final String titre;
  final IconData icone;
  final Color couleurIcone;
  final List<Produit> produits;
  final String cle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Espaces.ecran,
              Espaces.xl,
              Espaces.ecran,
              Espaces.sm,
            ),
            child: Row(
              children: [
                Icon(icone, size: 19, color: couleurIcone),
                const SizedBox(width: Espaces.xs),
                Text(titre, style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => context.goNamed(Routes.recherche),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.emeraude,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Espaces.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Tout voir'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 284,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Espaces.ecran),
              itemCount: produits.length,
              separatorBuilder: (_, _) => const SizedBox(width: Espaces.sm),
              itemBuilder: (context, index) {
                final produit = produits[index];
                return ProduitCarteLarge(
                  produit: produit,
                  etiquetteHero: cle,
                  onTap: () => context.pushNamed(
                    Routes.produit,
                    pathParameters: {'id': '${produit.id}'},
                    extra: {'hero': cle},
                  ),
                ).animate(delay: (index * 60).ms).fadeIn().slideY(begin: 0.2);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- squelettes
class _RangeeSquelettePuces extends StatelessWidget {
  const _RangeeSquelettePuces();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Espaces.ecran),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: Espaces.xs),
        itemBuilder: (_, index) => ShimmerBox(
          hauteur: 36,
          largeur: 90 + (index % 3) * 22,
          rayon: BorderRadius.circular(Rayons.pilule),
        ),
      ),
    );
  }
}

class _SqueletteAccueil extends StatelessWidget {
  const _SqueletteAccueil();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(2, (rangee) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  Espaces.ecran,
                  Espaces.xl,
                  Espaces.ecran,
                  Espaces.sm,
                ),
                child: ShimmerBox(hauteur: 20, largeur: 150),
              ),
              SizedBox(
                height: 284,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Espaces.ecran,
                  ),
                  itemCount: 3,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: Espaces.sm),
                  itemBuilder: (_, _) => const SizedBox(
                    width: 168,
                    child: SqueletteCarteProduit(),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _BoutonRond extends StatelessWidget {
  const _BoutonRond({
    required this.icone,
    required this.onTap,
    this.pastille = 0,
  });

  final IconData icone;
  final VoidCallback onTap;

  /// Nombre affiche dans la pastille ; 0 = pas de pastille.
  final int pastille;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rayons.pilule),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: sombre ? AppColors.encreSurface : AppColors.blanc,
            shape: BoxShape.circle,
            border: Border.all(
              color: sombre
                  ? AppColors.encreBordure
                  : AppColors.bordureClaire,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(icone, size: 20),
              if (pastille > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: BoxDecoration(
                      color: AppColors.or,
                      borderRadius: BorderRadius.circular(Rayons.pilule),
                      border: Border.all(
                        color: sombre
                            ? AppColors.encreSurface
                            : AppColors.blanc,
                        width: 1.4,
                      ),
                    ),
                    child: Text(
                      pastille > 9 ? '9+' : '$pastille',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 8.5,
                        height: 1.3,
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
