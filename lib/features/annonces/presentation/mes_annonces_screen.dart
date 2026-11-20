import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formats.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/reseau_image.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalogue/domain/produit.dart';
import '../providers/annonces_providers.dart';
import 'widgets/stock_feuille.dart';

/// Mes annonces (etape 4 du guide).
///
/// Le cycle de vie d'une annonce est separe de celui des reservations et
/// des ventes. Deux transitions sont AUTOMATIQUES cote serveur —
/// `ACTIVE → OUT_OF_STOCK` quand le disponible tombe a zero, et le retour
/// inverse. L'application ne les declenche donc jamais : apres toute
/// operation de stock, elle relit l'annonce au lieu de recalculer.
class MesAnnoncesScreen extends ConsumerWidget {
  const MesAnnoncesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final utilisateur = ref.watch(utilisateurProvider);
    final etat = ref.watch(annoncesProvider);

    if (utilisateur == null) {
      return const _InvitationVendeur();
    }

    return GradientBackground(
      anime: false,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaces.ecran,
                Espaces.sm,
                Espaces.ecran,
                Espaces.sm,
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mes annonces',
                        style: theme.textTheme.headlineMedium,
                      ),
                      if (!etat.chargement)
                        Text(
                          '${etat.total} au total',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const Spacer(),
                  AppButton(
                    libelle: 'Publier',
                    icone: Icons.add_rounded,
                    compact: true,
                    pleineLargeur: false,
                    onPressed: () => context.pushNamed(Routes.nouvelleAnnonce),
                  ),
                ],
              ).animate().fadeIn(),
            ),

            _RangeeFiltres(
              actif: etat.filtre,
              onChange: (filtre) =>
                  ref.read(annoncesProvider.notifier).charger(filtre: filtre),
            ),

            const SizedBox(height: Espaces.xs),
            Expanded(child: _Corps(etat: etat)),
          ],
        ),
      ),
    );
  }
}

class _Corps extends ConsumerWidget {
  const _Corps({required this.etat});

  final EtatAnnonces etat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (etat.chargement) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          Espaces.ecran,
          Espaces.xs,
          Espaces.ecran,
          Espaces.xxl,
        ),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: Espaces.sm),
        itemBuilder: (_, _) => const _SqueletteLigne(),
      );
    }

    if (etat.erreur != null) {
      return EtatErreur(
        erreur: etat.erreur!,
        onReessayer: () => ref.read(annoncesProvider.notifier).charger(),
      );
    }

    if (etat.estVide) {
      return EtatVide(
        titre: etat.filtre == FiltreAnnonces.toutes
            ? 'Aucune annonce'
            : 'Rien dans cet onglet',
        message: etat.filtre == FiltreAnnonces.toutes
            ? 'Publiez votre premiere annonce : il suffit d\'un titre, '
                'd\'une categorie et d\'un prix.'
            : 'Changez d\'onglet pour voir vos autres annonces.',
        icone: Icons.sell_outlined,
        libelleAction: etat.filtre == FiltreAnnonces.toutes
            ? 'Publier une annonce'
            : null,
        onAction: etat.filtre == FiltreAnnonces.toutes
            ? () => context.pushNamed(Routes.nouvelleAnnonce)
            : null,
      );
    }

    return RefreshIndicator(
      color: AppColors.emeraude,
      onRefresh: () => ref.read(annoncesProvider.notifier).charger(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          Espaces.ecran,
          Espaces.xs,
          Espaces.ecran,
          Espaces.xxl,
        ),
        itemCount: etat.annonces.length,
        separatorBuilder: (_, _) => const SizedBox(height: Espaces.sm),
        itemBuilder: (context, index) {
          final annonce = etat.annonces[index];
          return _LigneAnnonce(annonce: annonce)
              .animate(delay: (index < 8 ? index * 45 : 0).ms)
              .fadeIn(duration: 280.ms)
              .slideY(begin: 0.12);
        },
      ),
    );
  }
}

/// Une annonce dans la liste du vendeur.
///
/// Format horizontal et non une carte de grille : le vendeur gere, il ne
/// fait pas du lechage de vitrine. Il lui faut le statut, le stock et les
/// actions sous les yeux, pas une grande photo.
class _LigneAnnonce extends ConsumerWidget {
  const _LigneAnnonce({required this.annonce});

  final Produit annonce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (couleurStatut, iconeStatut) = _apparenceStatut(annonce.statut);

    return SolidCard(
      padding: const EdgeInsets.all(Espaces.sm),
      onTap: () => context.pushNamed(
        Routes.modifierAnnonce,
        pathParameters: {'id': '${annonce.id}'},
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReseauImage(
            url: annonce.imageAffichee?.url,
            largeur: 76,
            hauteur: 76,
            rayon: BorderRadius.circular(Rayons.xs),
          ),
          const SizedBox(width: Espaces.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        annonce.titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: Espaces.xs),
                    Etiquette(
                      texte: annonce.statut.libelle,
                      couleur: couleurStatut,
                      icone: iconeStatut,
                      compacte: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  Formats.montant(annonce.prix, devise: annonce.devise),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.emeraude,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Espaces.xs),
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 13,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${annonce.quantiteDisponible} dispo',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: Espaces.sm),
                    Icon(
                      Icons.visibility_outlined,
                      size: 13,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${annonce.nombreVues}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    _MenuActions(annonce: annonce),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static (Color, IconData) _apparenceStatut(StatutProduit statut) =>
      switch (statut) {
        StatutProduit.active => (AppColors.succes, Icons.check_circle_outline),
        StatutProduit.rupture => (AppColors.alerte, Icons.inventory_outlined),
        StatutProduit.brouillon => (
            AppColors.texteSombreDoux,
            Icons.edit_note_rounded
          ),
        StatutProduit.enAttente => (AppColors.info, Icons.hourglass_empty),
        StatutProduit.enPause => (AppColors.alerte, Icons.pause_circle_outline),
        StatutProduit.archivee => (
            AppColors.texteSombreDoux,
            Icons.archive_outlined
          ),
        StatutProduit.retiree => (AppColors.erreur, Icons.block_rounded),
      };
}

class _MenuActions extends ConsumerWidget {
  const _MenuActions({required this.annonce});

  final Produit annonce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peutPublier = annonce.statut != StatutProduit.active &&
        annonce.statut != StatutProduit.retiree;
    final peutMettreEnPause = annonce.statut == StatutProduit.active ||
        annonce.statut == StatutProduit.rupture;

    return PopupMenuButton<String>(
      tooltip: 'Actions',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: Rayons.carte),
      icon: const Icon(Icons.more_horiz_rounded, size: 20),
      padding: EdgeInsets.zero,
      onSelected: (action) => _executer(context, ref, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'stock',
          child: _ItemMenu(
            icone: Icons.inventory_2_outlined,
            texte: 'Gerer le stock',
          ),
        ),
        const PopupMenuItem(
          value: 'modifier',
          child: _ItemMenu(
            icone: Icons.edit_outlined,
            texte: 'Modifier',
          ),
        ),
        if (peutPublier)
          const PopupMenuItem(
            value: 'publier',
            child: _ItemMenu(
              icone: Icons.publish_rounded,
              texte: 'Publier',
              couleur: AppColors.succes,
            ),
          ),
        if (peutMettreEnPause)
          const PopupMenuItem(
            value: 'pause',
            child: _ItemMenu(
              icone: Icons.pause_rounded,
              texte: 'Mettre en pause',
              couleur: AppColors.alerte,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'archiver',
          child: _ItemMenu(
            icone: Icons.archive_outlined,
            texte: 'Archiver',
            couleur: AppColors.erreur,
          ),
        ),
      ],
    );
  }

  Future<void> _executer(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final depot = ref.read(annoncesRepositoryProvider);
    final notifier = ref.read(annoncesProvider.notifier);

    try {
      switch (action) {
        case 'stock':
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => StockFeuille(annonce: annonce),
          );
          // Le statut a pu basculer tout seul (ACTIVE <-> OUT_OF_STOCK) :
          // on relit plutot que de deviner.
          final relue = await depot.annonce(annonce.id);
          notifier.remplacer(relue);
          return;

        case 'modifier':
          if (!context.mounted) return;
          context.pushNamed(
            Routes.modifierAnnonce,
            pathParameters: {'id': '${annonce.id}'},
          );
          return;

        case 'publier':
          final maj = await depot.publier(annonce.id);
          notifier.remplacer(maj);
          if (!context.mounted) return;
          AppFeedback.succes(
            context,
            maj.statut == StatutProduit.rupture
                ? 'Annonce en ligne, mais sans stock disponible.'
                : 'Annonce en ligne.',
          );
          return;

        case 'pause':
          final maj = await depot.mettreEnPause(annonce.id);
          notifier.remplacer(maj);
          if (!context.mounted) return;
          AppFeedback.info(context, 'Annonce mise en pause.');
          return;

        case 'archiver':
          final confirme = await _confirmerArchivage(context);
          if (confirme != true) return;
          await depot.archiver(annonce.id);
          notifier.retirer(annonce.id);
          if (!context.mounted) return;
          AppFeedback.info(
            context,
            'Annonce archivee. Elle reste dans votre historique.',
          );
          return;
      }
    } on ApiException catch (erreur) {
      if (!context.mounted) return;
      AppFeedback.erreur(context, erreur.message);
    }
  }

  Future<bool?> _confirmerArchivage(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Espaces.ecran,
          0,
          Espaces.ecran,
          Espaces.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Archiver cette annonce ?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Espaces.xs),
            Text(
              'Elle disparait du catalogue public, mais rien n\'est '
              'efface : vos ventes passees restent lisibles.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Espaces.xl),
            AppButton(
              libelle: 'Archiver',
              style: StyleBouton.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: Espaces.xs),
            AppButton(
              libelle: 'Annuler',
              style: StyleBouton.fantome,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.icone,
    required this.texte,
    this.couleur,
  });

  final IconData icone;
  final String texte;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 18, color: couleur),
        const SizedBox(width: Espaces.sm),
        Text(texte, style: TextStyle(color: couleur)),
      ],
    );
  }
}

class _RangeeFiltres extends StatelessWidget {
  const _RangeeFiltres({required this.actif, required this.onChange});

  final FiltreAnnonces actif;
  final ValueChanged<FiltreAnnonces> onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Espaces.ecran),
        itemCount: FiltreAnnonces.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: Espaces.xs),
        itemBuilder: (context, index) {
          final filtre = FiltreAnnonces.values[index];
          final choisi = filtre == actif;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChange(filtre),
              borderRadius: BorderRadius.circular(Rayons.pilule),
              child: AnimatedContainer(
                duration: Mouvements.rapide,
                padding: const EdgeInsets.symmetric(
                  horizontal: Espaces.md,
                  vertical: Espaces.xs,
                ),
                decoration: BoxDecoration(
                  gradient: choisi ? AppColors.degradeMarque : null,
                  color: choisi
                      ? null
                      : (sombre ? AppColors.encreSurface : AppColors.blanc),
                  borderRadius: BorderRadius.circular(Rayons.pilule),
                  border: Border.all(
                    color: choisi
                        ? Colors.transparent
                        : (sombre
                            ? AppColors.encreBordure
                            : AppColors.bordureClaire),
                  ),
                ),
                child: Text(
                  filtre.libelle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 13,
                    color: choisi ? Colors.white : null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(
            largeur: 76,
            hauteur: 76,
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
                SizedBox(height: Espaces.sm),
                ShimmerBox(hauteur: 12, largeur: 150),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Affiche quand on ouvre « Mes annonces » sans etre connecte.
class _InvitationVendeur extends StatelessWidget {
  const _InvitationVendeur();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientBackground(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Espaces.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IconPastille(
                  icone: Icons.sell_outlined,
                  taille: 76,
                  tailleIcone: 34,
                ),
                const SizedBox(height: Espaces.xl),
                Text(
                  'Vendez sur Marketplace',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Espaces.xs),
                Text(
                  'Tout compte peut publier : il n\'y a pas de statut '
                  'vendeur a demander, pas de validation a attendre.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Espaces.xxl),
                AppButton(
                  libelle: 'Se connecter',
                  icone: Icons.login_rounded,
                  onPressed: () => context.pushNamed(Routes.connexion),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
