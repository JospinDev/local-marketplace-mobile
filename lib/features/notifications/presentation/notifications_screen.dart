import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formats.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../domain/notification.dart';
import '../providers/notifications_providers.dart';

/// Centre de notifications.
///
/// Appuyer sur une notification la marque lue ET ouvre sa cible : c'est le
/// geste attendu. Un vendeur qui recoit une demande de reservation arrive
/// donc directement sur la demande, prete a etre acceptee.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (etat.nonLues > 0)
            TextButton.icon(
              onPressed: notifier.toutMarquerLu,
              icon: const Icon(Icons.done_all_rounded, size: 17),
              label: const Text('Tout lire'),
            ),
        ],
      ),
      body: GradientBackground(
        anime: false,
        child: Column(
          children: [
            _Filtre(
              seulementNonLues: etat.seulementNonLues,
              nonLues: etat.nonLues,
              onChange: notifier.basculerFiltre,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: notifier.charger,
                child: _corps(context, ref, etat, notifier),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corps(
    BuildContext context,
    WidgetRef ref,
    EtatNotifications etat,
    NotificationsNotifier notifier,
  ) {
    if (etat.chargement && etat.notifications.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: Espaces.ecran),
        itemCount: 6,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: Espaces.sm),
          child: ShimmerBox(
            hauteur: 76,
            rayon: BorderRadius.all(Radius.circular(Rayons.md)),
          ),
        ),
      );
    }

    if (etat.erreur != null && etat.notifications.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
          EtatErreur(erreur: etat.erreur!, onReessayer: notifier.charger),
        ],
      );
    }

    if (etat.estVide) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
          EtatVide(
            icone: Icons.notifications_none_rounded,
            titre: etat.seulementNonLues
                ? 'Tout est lu'
                : 'Aucune notification',
            message: etat.seulementNonLues
                ? 'Vous n\'avez aucune notification non lue.'
                : 'Les demandes de reservation, les messages et les ventes '
                    'apparaitront ici.',
            libelleAction: etat.seulementNonLues ? 'Tout voir' : null,
            onAction:
                etat.seulementNonLues ? () => notifier.basculerFiltre(false) : null,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        Espaces.ecran,
        Espaces.xs,
        Espaces.ecran,
        Espaces.xxxl,
      ),
      itemCount: etat.notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: Espaces.xs),
      itemBuilder: (context, index) {
        final notification = etat.notifications[index];
        return _Ligne(
          notification: notification,
          onTap: () => _ouvrir(context, ref, notification),
        )
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: 20 * index),
              duration: Mouvements.normal,
            )
            .slideY(begin: 0.06, curve: Mouvements.sortie);
      },
    );
  }

  /// Marque lue puis navigue vers la cible donnee par le serveur.
  void _ouvrir(
    BuildContext context,
    WidgetRef ref,
    NotificationItem notification,
  ) {
    ref.read(notificationsProvider.notifier).marquerLue(notification);

    final id = notification.referenceId;
    if (id == null || id <= 0) return;

    switch (notification.cible) {
      case CibleNotification.conversation:
        context.pushNamed(
          Routes.conversation,
          pathParameters: {'id': '$id'},
        );
      case CibleNotification.reservation:
        context.pushNamed(
          Routes.reservation,
          pathParameters: {'id': '$id'},
        );
      case CibleNotification.vente:
        context.pushNamed(Routes.vente, pathParameters: {'id': '$id'});
      case CibleNotification.produit:
        context.pushNamed(
          Routes.produit,
          pathParameters: {'id': '$id'},
          extra: {'hero': 'notification'},
        );
      case CibleNotification.utilisateur:
        context.pushNamed(Routes.boutique, pathParameters: {'id': '$id'});
      case CibleNotification.evaluation:
        // Un avis recu se consulte dans l'onglet « Recus » : la
        // notification ne concerne jamais un avis qu'on a soi-meme ecrit.
        context.pushNamed(
          Routes.mesAvis,
          queryParameters: {'onglet': '1'},
        );
      case CibleNotification.aucune:
        break;
    }
  }
}

class _Filtre extends StatelessWidget {
  const _Filtre({
    required this.seulementNonLues,
    required this.nonLues,
    required this.onChange,
  });

  final bool seulementNonLues;
  final int nonLues;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.ecran,
        vertical: Espaces.xs,
      ),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Tout'),
            selected: !seulementNonLues,
            onSelected: (_) => onChange(false),
            selectedColor: AppColors.emeraude.withValues(alpha: 0.18),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight:
                  !seulementNonLues ? FontWeight.w700 : FontWeight.w500,
              color: !seulementNonLues ? AppColors.emeraude : null,
            ),
          ),
          const SizedBox(width: Espaces.xs),
          ChoiceChip(
            label: Text(nonLues > 0 ? 'Non lues ($nonLues)' : 'Non lues'),
            selected: seulementNonLues,
            onSelected: (_) => onChange(true),
            selectedColor: AppColors.emeraude.withValues(alpha: 0.18),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: seulementNonLues ? FontWeight.w700 : FontWeight.w500,
              color: seulementNonLues ? AppColors.emeraude : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.notification, required this.onTap});

  final NotificationItem notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final apparence = _apparence(notification.famille);
    final lue = notification.estLue;

    return Material(
      color: lue
          ? (sombre
              ? AppColors.encreSurface.withValues(alpha: 0.55)
              : AppColors.blanc)
          : (sombre
              ? AppColors.encreSurfaceHaute
              : AppColors.emeraude.withValues(alpha: 0.05)),
      borderRadius: BorderRadius.circular(Rayons.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rayons.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Espaces.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rayons.md),
            border: Border.all(
              color: lue
                  ? (sombre
                      ? AppColors.encreBordure
                      : AppColors.bordureClaire)
                  : AppColors.emeraude.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: apparence.couleur.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Rayons.sm),
                ),
                alignment: Alignment.center,
                child: Icon(apparence.icone, size: 19, color: apparence.couleur),
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
                            notification.titre.isNotEmpty
                                ? notification.titre
                                : notification.typeLibelle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  lue ? FontWeight.w600 : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: Espaces.xs),
                        Text(
                          Formats.depuis(notification.creeLe),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: sombre
                                ? AppColors.texteClairDoux
                                : AppColors.texteSombreDoux,
                          ),
                        ),
                        if (!lue) ...[
                          const SizedBox(width: Espaces.xxs),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.emeraude,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: sombre
                            ? AppColors.texteClairDoux
                            : AppColors.texteSombreDoux,
                      ),
                    ),
                    if (notification.peutSOuvrir) ...[
                      const SizedBox(height: Espaces.xxs),
                      Row(
                        children: [
                          Text(
                            _libelleCible(notification.cible),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.emeraude,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: AppColors.emeraude,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ({Color couleur, IconData icone}) _apparence(
    FamilleNotification famille,
  ) {
    switch (famille) {
      case FamilleNotification.message:
        return (couleur: AppColors.info, icone: Icons.chat_bubble_rounded);
      case FamilleNotification.reservation:
        return (couleur: AppColors.alerte, icone: Icons.bookmark_rounded);
      case FamilleNotification.vente:
        return (couleur: AppColors.emeraude, icone: Icons.payments_rounded);
      case FamilleNotification.stock:
        return (couleur: AppColors.erreur, icone: Icons.inventory_2_rounded);
      case FamilleNotification.avis:
        return (couleur: AppColors.or, icone: Icons.star_rounded);
      case FamilleNotification.administration:
        return (couleur: AppColors.erreur, icone: Icons.gavel_rounded);
      case FamilleNotification.autre:
        return (couleur: AppColors.sarcelle, icone: Icons.campaign_rounded);
    }
  }

  static String _libelleCible(CibleNotification cible) {
    switch (cible) {
      case CibleNotification.conversation:
        return 'Ouvrir la discussion ';
      case CibleNotification.reservation:
        return 'Voir la reservation ';
      case CibleNotification.vente:
        return 'Voir la vente ';
      case CibleNotification.produit:
        return 'Voir l\'annonce ';
      case CibleNotification.utilisateur:
        return 'Voir la boutique ';
      case CibleNotification.evaluation:
        return 'Voir l\'avis ';
      case CibleNotification.aucune:
        return '';
    }
  }
}
