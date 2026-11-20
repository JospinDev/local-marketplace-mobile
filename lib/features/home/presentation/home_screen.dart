import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../auth/providers/auth_provider.dart';

/// Accueil.
///
/// Les etapes 3 et suivantes du guide (catalogue, recherche, fiche
/// produit) viendront remplir cet ecran. Pour l'instant il sert deux
/// choses utiles : verifier que la session tient apres connexion, et
/// poser l'en-tete que les prochains modules reprendront.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final utilisateur = ref.watch(utilisateurProvider);
    final connecte = utilisateur != null;

    return GradientBackground(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaces.ecran,
                  Espaces.sm,
                  Espaces.ecran,
                  Espaces.md,
                ),
                child: Row(
                  children: [
                    const BrandLockup(taille: 32),
                    const Spacer(),
                    _BoutonRond(
                      icone: Icons.notifications_none_rounded,
                      onTap: () {},
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Espaces.ecran,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Espaces.sm),
                    Text(
                      connecte
                          ? 'Bonjour ${utilisateur.nomAffiche},'
                          : 'Bienvenue,',
                      style: theme.textTheme.bodyLarge,
                    ).animate(delay: 80.ms).fadeIn().slideX(begin: -0.15),
                    const SizedBox(height: 2),
                    Text(
                      'que cherchez-vous\naujourd\'hui ?',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        height: 1.15,
                      ),
                    ).animate(delay: 140.ms).fadeIn().slideY(begin: 0.2),
                    const SizedBox(height: Espaces.xl),

                    // Bandeau de bienvenue : il disparaitra quand le
                    // catalogue du module 3 prendra la place.
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const IconPastille(
                                icone: Icons.rocket_launch_outlined,
                                taille: 44,
                              ),
                              const SizedBox(width: Espaces.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Authentification prete',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      connecte
                                          ? 'Session active, jeton valide.'
                                          : 'Vous naviguez sans compte.',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Espaces.md),
                          Text(
                            'Les prochaines etapes du guide ajouteront ici '
                            'le catalogue, la recherche par localisation et '
                            'la fiche produit.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (connecte && utilisateur.estSuspendu) ...[
                            const SizedBox(height: Espaces.md),
                            _BandeauSuspension(
                              motif: utilisateur.motifSuspension,
                            ),
                          ],
                        ],
                      ),
                    ).animate(delay: 220.ms).fadeIn().slideY(begin: 0.2),

                    const SizedBox(height: Espaces.lg),

                    Text(
                      'Prochainement',
                      style: theme.textTheme.titleMedium,
                    ).animate(delay: 300.ms).fadeIn(),
                    const SizedBox(height: Espaces.sm),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Espaces.ecran,
                0,
                Espaces.ecran,
                Espaces.xxl,
              ),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: Espaces.sm,
                  crossAxisSpacing: Espaces.sm,
                  childAspectRatio: 1.55,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    const cartes = [
                      (Icons.storefront_outlined, 'Catalogue', 'Etape 3'),
                      (Icons.sell_outlined, 'Mes annonces', 'Etape 4'),
                      (Icons.bookmark_added_outlined, 'Reservations', 'Etape 7'),
                      (Icons.insights_outlined, 'Tableau de bord', 'Etape 10'),
                    ];
                    final (icone, titre, etape) = cartes[index];
                    return SolidCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconPastille(icone: icone, taille: 36),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titre,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Etiquette(
                                texte: etape,
                                couleur: AppColors.or,
                                compacte: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                        .animate(delay: (340 + index * 70).ms)
                        .fadeIn()
                        .slideY(begin: 0.25);
                  },
                  childCount: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutonRond extends StatelessWidget {
  const _BoutonRond({required this.icone, required this.onTap});

  final IconData icone;
  final VoidCallback onTap;

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
          child: Icon(icone, size: 20),
        ),
      ),
    );
  }
}

/// Bandeau persistant quand le compte est suspendu : le guide demande de
/// le rendre visible en permanence, pas seulement dans un message fugace.
class _BandeauSuspension extends StatelessWidget {
  const _BandeauSuspension({this.motif});

  final String? motif;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Espaces.sm),
      decoration: BoxDecoration(
        color: AppColors.erreur.withValues(alpha: 0.10),
        borderRadius: Rayons.champ,
        border: Border.all(color: AppColors.erreur.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block_rounded, size: 18, color: AppColors.erreur),
          const SizedBox(width: Espaces.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compte suspendu',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.erreur,
                  ),
                ),
                if (motif != null && motif!.isNotEmpty)
                  Text(motif!, style: theme.textTheme.bodySmall),
                Text(
                  'La lecture reste possible, mais vous ne pouvez plus '
                  'publier ni contacter les vendeurs.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
