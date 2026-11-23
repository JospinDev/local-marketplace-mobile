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
import '../../../core/widgets/reseau_image.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../domain/conversation.dart';
import '../providers/messagerie_providers.dart';

/// Liste des conversations (etape 6, module 7).
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(conversationsProvider);
    final sombre = Theme.of(context).brightness == Brightness.dark;

    return GradientBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaces.ecran,
                Espaces.md,
                Espaces.ecran,
                Espaces.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Messages',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (etat.totalNonLus > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Espaces.sm,
                        vertical: Espaces.xxs + 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emeraude.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(Rayons.pilule),
                      ),
                      child: Text(
                        '${etat.totalNonLus} non lu${etat.totalNonLus > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraude,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(conversationsProvider.notifier).charger(),
                child: _corps(context, ref, etat, sombre),
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
    EtatConversations etat,
    bool sombre,
  ) {
    if (etat.chargement && etat.conversations.isEmpty) {
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

    if (etat.erreur != null && etat.conversations.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
          EtatErreur(
            erreur: etat.erreur!,
            onReessayer: () =>
                ref.read(conversationsProvider.notifier).charger(),
          ),
        ],
      );
    }

    if (etat.estVide) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
          const EtatVide(
            icone: Icons.forum_outlined,
            titre: 'Aucune conversation',
            message:
                'Ouvrez une annonce et appuyez sur « Contacter » pour '
                'discuter avec le vendeur.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        Espaces.ecran,
        0,
        Espaces.ecran,
        Espaces.xxxl,
      ),
      itemCount: etat.conversations.length,
      separatorBuilder: (_, _) => const SizedBox(height: Espaces.xs),
      itemBuilder: (context, index) {
        final conversation = etat.conversations[index];
        return _LigneConversation(conversation: conversation)
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: 24 * index),
              duration: Mouvements.normal,
            )
            .slideY(begin: 0.08, curve: Mouvements.sortie);
      },
    );
  }
}

class _LigneConversation extends StatelessWidget {
  const _LigneConversation({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final autre = conversation.interlocuteur;
    final nonLus = conversation.messagesNonLus;
    final dernier = conversation.dernierMessage;

    return Material(
      color: sombre
          ? AppColors.encreSurface.withValues(alpha: 0.7)
          : AppColors.blanc,
      borderRadius: BorderRadius.circular(Rayons.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rayons.md),
        onTap: () => context.pushNamed(
          Routes.conversation,
          pathParameters: {'id': '${conversation.id}'},
        ),
        child: Container(
          padding: const EdgeInsets.all(Espaces.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rayons.md),
            border: Border.all(
              color: nonLus > 0
                  ? AppColors.emeraude.withValues(alpha: 0.35)
                  : (sombre
                      ? AppColors.encreBordure
                      : AppColors.bordureClaire),
            ),
          ),
          child: Row(
            children: [
              _Avatar(interlocuteur: autre, produit: conversation.produit),
              const SizedBox(width: Espaces.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            autre?.nomAffiche ?? 'Conversation',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight:
                                  nonLus > 0 ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: Espaces.xs),
                        Text(
                          Formats.depuis(
                            conversation.dernierMessageLe ?? conversation.creeLe,
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: sombre
                                ? AppColors.texteClairDoux
                                : AppColors.texteSombreDoux,
                          ),
                        ),
                      ],
                    ),
                    if (conversation.produit != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        conversation.produit!.titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emeraude,
                        ),
                      ),
                    ],
                    const SizedBox(height: Espaces.xxs),
                    Row(
                      children: [
                        if (conversation.estBloquee) ...[
                          const Icon(Icons.block_rounded,
                              size: 13, color: AppColors.erreur),
                          const SizedBox(width: Espaces.xxs),
                        ],
                        Expanded(
                          child: Text(
                            _apercu(dernier, conversation),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: nonLus > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: nonLus > 0
                                  ? (sombre
                                      ? AppColors.texteClair
                                      : AppColors.texteSombre)
                                  : (sombre
                                      ? AppColors.texteClairDoux
                                      : AppColors.texteSombreDoux),
                            ),
                          ),
                        ),
                        if (nonLus > 0) ...[
                          const SizedBox(width: Espaces.xs),
                          Container(
                            constraints:
                                const BoxConstraints(minWidth: 20, minHeight: 20),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: const BoxDecoration(
                              color: AppColors.emeraude,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              nonLus > 99 ? '99+' : '$nonLus',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blanc,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _apercu(Message? dernier, Conversation conversation) {
    if (conversation.estBloquee) {
      return conversation.bloqueeParMoi
          ? 'Vous avez bloque cette conversation'
          : 'Conversation bloquee';
    }
    if (dernier == null) return 'Aucun message';
    if (dernier.aUneImage && dernier.contenu.trim().isEmpty) return 'Photo';
    return '${dernier.estDeMoi ? 'Vous : ' : ''}${dernier.contenu}';
  }
}

/// Photo du produit en vignette, avec l'avatar de l'interlocuteur en
/// medaillon : la conversation se reconnait d'abord par l'annonce.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.interlocuteur, required this.produit});

  final Interlocuteur? interlocuteur;
  final ProduitConversation? produit;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        children: [
          if (produit?.image != null)
            ReseauImage(
              url: produit!.image,
              largeur: 52,
              hauteur: 52,
              rayon: BorderRadius.circular(Rayons.sm),
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.emeraude, AppColors.sarcelle],
                ),
                borderRadius: BorderRadius.circular(Rayons.sm),
              ),
              alignment: Alignment.center,
              child: Text(
                interlocuteur?.initiales ?? '?',
                style: const TextStyle(
                  color: AppColors.blanc,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          if (produit?.image != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.emeraude, AppColors.sarcelle],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sombre ? AppColors.encre : AppColors.blanc,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  interlocuteur?.initiales ?? '?',
                  style: const TextStyle(
                    color: AppColors.blanc,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
