import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formats.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/reseau_image.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/favori.dart';
import '../providers/favoris_providers.dart';
import 'widgets/bouton_favori.dart';

/// « Mes listes » : favoris produits et vendeurs suivis.
///
/// Les deux vivent dans le meme ecran mais dans deux ONGLETS distincts,
/// jamais melanges. Le guide insiste sur la difference : le favori porte
/// sur un produit et sert a surveiller un prix, l'abonnement porte sur un
/// vendeur et sert a voir ses nouveautes. Les fondre ferait perdre les
/// deux usages.
class MesListesScreen extends ConsumerWidget {
  const MesListesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final connecte = ref.watch(authProvider).estConnecte;

    if (!connecte) return const _InvitationListes();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                    0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Retour',
                      ),
                      const SizedBox(width: Espaces.xs),
                      Text('Mes listes', style: theme.textTheme.titleLarge),
                    ],
                  ),
                ),
                TabBar(
                  labelColor: AppColors.emeraude,
                  indicatorColor: AppColors.emeraude,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: theme.dividerColor,
                  tabs: const [
                    Tab(text: 'Favoris'),
                    Tab(text: 'Vendeurs suivis'),
                  ],
                ),
                const Expanded(
                  child: TabBarView(
                    children: [_OngletFavoris(), _OngletVendeurs()],
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

// ============================================================== favoris
class _OngletFavoris extends ConsumerWidget {
  const _OngletFavoris();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(favorisProvider);

    if (etat.chargement) {
      return ListView.separated(
        padding: const EdgeInsets.all(Espaces.ecran),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: Espaces.sm),
        itemBuilder: (_, _) => const _SqueletteLigne(),
      );
    }

    if (etat.erreur != null) {
      return EtatErreur(
        erreur: etat.erreur!,
        onReessayer: () => ref.read(favorisProvider.notifier).charger(),
      );
    }

    if (etat.estVide) {
      return EtatVide(
        titre: 'Aucun favori',
        message: 'Touchez le coeur sur une annonce pour la garder ici et '
            'etre prevenu si son prix change.',
        icone: Icons.favorite_border_rounded,
        libelleAction: 'Parcourir le catalogue',
        onAction: () => context.goNamed(Routes.recherche),
      );
    }

    final alertes = etat.avecAlerte;

    return RefreshIndicator(
      color: AppColors.emeraude,
      onRefresh: () => ref.read(favorisProvider.notifier).charger(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Espaces.ecran,
          Espaces.md,
          Espaces.ecran,
          Espaces.xxl,
        ),
        children: [
          // Les alertes remontent en haut : c'est la raison d'etre de
          // l'ecran. Les enterrer au milieu de la liste les rendrait
          // inutiles.
          if (alertes.isNotEmpty) ...[
            _BandeauAlertes(nombre: alertes.length)
                .animate()
                .fadeIn()
                .slideY(begin: 0.15),
            const SizedBox(height: Espaces.md),
          ],
          for (var i = 0; i < etat.favoris.length; i++) ...[
            _LigneFavori(favori: etat.favoris[i])
                .animate(delay: (i < 8 ? i * 45 : 0).ms)
                .fadeIn(duration: 280.ms)
                .slideY(begin: 0.12),
            const SizedBox(height: Espaces.sm),
          ],
        ],
      ),
    );
  }
}

class _BandeauAlertes extends StatelessWidget {
  const _BandeauAlertes({required this.nombre});

  final int nombre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Espaces.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.or.withValues(alpha: 0.12),
        borderRadius: Rayons.carte,
        border: Border.all(color: AppColors.or.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            size: 19,
            color: AppColors.or,
          ),
          const SizedBox(width: Espaces.sm),
          Expanded(
            child: Text(
              nombre == 1
                  ? '1 de vos favoris a du nouveau.'
                  : '$nombre de vos favoris ont du nouveau.',
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneFavori extends ConsumerWidget {
  const _LigneFavori({required this.favori});

  final Favori favori;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final produit = favori.produit;

    return SolidCard(
      padding: const EdgeInsets.all(Espaces.sm),
      onTap: () => context.pushNamed(
        Routes.produit,
        pathParameters: {'id': '${produit.id}'},
        extra: const {'hero': 'favoris'},
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ReseauImage(
                    url: produit.imageAffichee?.url,
                    largeur: 76,
                    hauteur: 76,
                    rayon: BorderRadius.circular(Rayons.xs),
                  ),
                  if (favori.estRetire || !favori.estToujoursDisponible)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.encre.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(Rayons.xs),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: Espaces.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produit.titre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: Espaces.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          Formats.montant(
                            favori.prixActuel ?? produit.prix,
                            devise: produit.devise,
                          ),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.emeraude,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (favori.prixAChange) ...[
                          const SizedBox(width: Espaces.xs),
                          // Le prix d'origine barre : la comparaison est
                          // immediate, sans calcul mental.
                          Text(
                            Formats.montantCourt(favori.prixALAjout),
                            style: theme.textTheme.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (produit.localisation != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        produit.localisation!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              BoutonFavori(produitId: produit.id, taille: 34),
            ],
          ),

          // Le message d'alerte vient du SERVEUR, deja redige. On
          // l'affiche tel quel : le reconstruire ici ferait deux
          // formulations a maintenir.
          if (favori.aUneAlerte) ...[
            const SizedBox(height: Espaces.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Espaces.xs + 2),
              decoration: BoxDecoration(
                color: _couleurAlerte(favori).withValues(alpha: 0.10),
                borderRadius: Rayons.champ,
              ),
              child: Row(
                children: [
                  Icon(
                    _iconeAlerte(favori),
                    size: 15,
                    color: _couleurAlerte(favori),
                  ),
                  const SizedBox(width: Espaces.xs),
                  Expanded(
                    child: Text(
                      favori.alerte!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _couleurAlerte(favori),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _couleurAlerte(Favori favori) {
    if (favori.estRetire) return AppColors.erreur;
    if (!favori.estToujoursDisponible) return AppColors.alerte;
    return favori.prixABaisse ? AppColors.succes : AppColors.info;
  }

  static IconData _iconeAlerte(Favori favori) {
    if (favori.estRetire) return Icons.block_rounded;
    if (!favori.estToujoursDisponible) return Icons.inventory_outlined;
    return favori.prixABaisse
        ? Icons.trending_down_rounded
        : Icons.trending_up_rounded;
  }
}

// ============================================================= vendeurs
class _OngletVendeurs extends ConsumerWidget {
  const _OngletVendeurs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(vendeursSuivisProvider);

    if (etat.chargement) {
      return ListView.separated(
        padding: const EdgeInsets.all(Espaces.ecran),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: Espaces.sm),
        itemBuilder: (_, _) => const _SqueletteLigne(),
      );
    }

    if (etat.erreur != null) {
      return EtatErreur(
        erreur: etat.erreur!,
        onReessayer: () => ref.read(vendeursSuivisProvider.notifier).charger(),
      );
    }

    if (etat.estVide) {
      return EtatVide(
        titre: 'Aucun vendeur suivi',
        message: 'Suivez une boutique pour voir ses nouvelles annonces '
            'des leur publication.',
        icone: Icons.storefront_outlined,
        libelleAction: 'Decouvrir des vendeurs',
        onAction: () => context.goNamed(Routes.recherche),
      );
    }

    return RefreshIndicator(
      color: AppColors.emeraude,
      onRefresh: () => ref.read(vendeursSuivisProvider.notifier).charger(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          Espaces.ecran,
          Espaces.md,
          Espaces.ecran,
          Espaces.xxl,
        ),
        itemCount: etat.vendeurs.length,
        separatorBuilder: (_, _) => const SizedBox(height: Espaces.sm),
        itemBuilder: (context, index) {
          final vendeur = etat.vendeurs[index];
          return _LigneVendeur(vendeur: vendeur)
              .animate(delay: (index < 8 ? index * 45 : 0).ms)
              .fadeIn(duration: 280.ms)
              .slideY(begin: 0.12);
        },
      ),
    );
  }
}

class _LigneVendeur extends StatelessWidget {
  const _LigneVendeur({required this.vendeur});

  final VendeurSuivi vendeur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SolidCard(
      padding: EdgeInsets.zero,
      // Toute la ligne ouvre la boutique du vendeur : on y voit ses
      // annonces et rien d'autre. Le bouton « suivre » garde son propre
      // geste, il ne declenche donc pas l'ouverture.
      child: InkWell(
        borderRadius: BorderRadius.circular(Rayons.md),
        onTap: () => context.pushNamed(
          Routes.boutique,
          pathParameters: {'id': '${vendeur.vendeurId}'},
        ),
        child: Padding(
          padding: const EdgeInsets.all(Espaces.sm),
          child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Rayons.sm),
            child: vendeur.photo != null
                ? ReseauImage(url: vendeur.photo, largeur: 52, hauteur: 52)
                : Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      gradient: AppColors.degradeMarque,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      vendeur.initiales,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: Espaces.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendeur.nomAffiche,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (vendeur.localisation != null)
                  Text(
                    vendeur.localisation!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: Espaces.xs),
                Wrap(
                  spacing: 6,
                  children: [
                    Etiquette(
                      texte: '${vendeur.nombreProduitsActifs} annonces',
                      couleur: AppColors.emeraude,
                      icone: Icons.sell_outlined,
                      compacte: true,
                    ),
                    Etiquette(
                      texte: '${vendeur.nombreAbonnes} abonnes',
                      couleur: AppColors.sarcelle,
                      icone: Icons.group_outlined,
                      compacte: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
              const SizedBox(width: Espaces.xs),
              BoutonSuivre(vendeurId: vendeur.vendeurId, compact: true),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.textTheme.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================ fragments
class _SqueletteLigne extends StatelessWidget {
  const _SqueletteLigne();

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(Espaces.sm),
      decoration: BoxDecoration(
        color: sombre ? AppColors.encreSurface : AppColors.blanc,
        borderRadius: Rayons.carte,
        border: Border.all(
          color: sombre ? AppColors.encreBordure : AppColors.bordureClaire,
        ),
      ),
      child: Row(
        children: [
          ShimmerBox(
            largeur: 66,
            hauteur: 66,
            rayon: BorderRadius.circular(Rayons.xs),
          ),
          const SizedBox(width: Espaces.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(hauteur: 14),
                SizedBox(height: Espaces.xs),
                ShimmerBox(hauteur: 16, largeur: 110),
                SizedBox(height: Espaces.xs),
                ShimmerBox(hauteur: 12, largeur: 150),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationListes extends StatelessWidget {
  const _InvitationListes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Espaces.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const IconPastille(
                          icone: Icons.favorite_rounded,
                          couleur: AppColors.erreur,
                          taille: 76,
                          tailleIcone: 34,
                        ),
                        const SizedBox(height: Espaces.xl),
                        Text(
                          'Vos listes vous attendent',
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Espaces.xs),
                        Text(
                          'Avec un compte, gardez vos coups de coeur, '
                          'suivez vos boutiques preferees et soyez prevenu '
                          'quand un prix baisse.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Espaces.xxl),
                        AppButton(
                          libelle: 'Se connecter',
                          icone: Icons.login_rounded,
                          onPressed: () =>
                              context.pushNamed(Routes.connexion),
                        ),
                      ],
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
