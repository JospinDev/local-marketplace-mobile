import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/favoris_providers.dart';

/// Bouton coeur, a poser sur une carte ou une fiche produit.
///
/// Deux comportements qui comptent :
///
/// - **la bascule est optimiste** : le coeur se remplit avant la reponse
///   du serveur. Sur un reseau lent, attendre l'aller-retour donne
///   l'impression que le bouton ne marche pas, et la personne appuie deux
///   fois ;
/// - **sans compte, on invite a se connecter** plutot que d'afficher un
///   bouton mort ou de cacher la fonction. Le catalogue est ouvert aux
///   visiteurs, les favoris non : la difference doit s'expliquer au
///   moment ou elle se presente.
class BoutonFavori extends ConsumerStatefulWidget {
  const BoutonFavori({
    super.key,
    required this.produitId,
    this.taille = 38,
    this.surImage = false,
  });

  final int produitId;
  final double taille;

  /// Pose sur une photo : le bouton prend un fond sombre translucide
  /// pour rester visible quelle que soit l'image.
  final bool surImage;

  @override
  ConsumerState<BoutonFavori> createState() => _BoutonFavoriState();
}

class _BoutonFavoriState extends ConsumerState<BoutonFavori>
    with SingleTickerProviderStateMixin {
  late final AnimationController _battement = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _battement.dispose();
    super.dispose();
  }

  Future<void> _basculer() async {
    if (!ref.read(authProvider).estConnecte) {
      _inviterAConnexion();
      return;
    }

    HapticFeedback.lightImpact();
    try {
      final ajoute =
          await ref.read(favorisProvider.notifier).basculer(widget.produitId);
      if (ajoute) _battement.forward(from: 0);
    } on ApiException catch (erreur) {
      if (!mounted) return;
      AppFeedback.erreur(context, erreur.message);
    }
  }

  void _inviterAConnexion() {
    showModalBottomSheet<void>(
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
              'Gardez vos coups de coeur',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Espaces.xs),
            Text(
              'Avec un compte, vous retrouvez vos favoris sur tous vos '
              'appareils et vous etes prevenu quand un prix baisse.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Espaces.xl),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.pushNamed(Routes.connexion);
              },
              icon: const Icon(Icons.login_rounded),
              label: const Text('Se connecter'),
            ),
            const SizedBox(height: Espaces.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Plus tard'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estFavori = ref.watch(
      favorisProvider.select((e) => e.contient(widget.produitId)),
    );
    final sombre = Theme.of(context).brightness == Brightness.dark;

    final fond = widget.surImage
        ? AppColors.encre.withValues(alpha: 0.42)
        : (sombre ? AppColors.encreSurface : AppColors.blanc);

    return Material(
      color: fond,
      shape: CircleBorder(
        side: widget.surImage
            ? BorderSide.none
            : BorderSide(
                color:
                    sombre ? AppColors.encreBordure : AppColors.bordureClaire,
              ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _basculer,
        child: SizedBox(
          width: widget.taille,
          height: widget.taille,
          child: AnimatedBuilder(
            animation: _battement,
            builder: (context, enfant) {
              // Un seul rebond amorti a l'ajout : le coeur « bat » une
              // fois. Repeter l'animation serait vite agacant.
              final t = _battement.value;
              final echelle = 1 + 0.38 * (t < 0.5 ? t * 2 : (1 - t) * 2);
              return Transform.scale(scale: echelle, child: enfant);
            },
            child: AnimatedSwitcher(
              duration: Mouvements.rapide,
              transitionBuilder: (enfant, animation) => ScaleTransition(
                scale: animation,
                child: enfant,
              ),
              child: Icon(
                estFavori
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(estFavori),
                size: widget.taille * 0.5,
                color: estFavori
                    ? AppColors.erreur
                    : (widget.surImage
                        ? Colors.white
                        : (sombre
                            ? AppColors.texteClairDoux
                            : AppColors.texteSombreDoux)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton « Suivre » / « Suivi », pour une vitrine de vendeur.
class BoutonSuivre extends ConsumerWidget {
  const BoutonSuivre({super.key, required this.vendeurId, this.compact = false});

  final int vendeurId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final suit = ref.watch(
      vendeursSuivisProvider.select((e) => e.suit(vendeurId)),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rayons.pilule),
        onTap: () async {
          if (!ref.read(authProvider).estConnecte) {
            context.pushNamed(Routes.connexion);
            return;
          }
          HapticFeedback.selectionClick();
          try {
            await ref
                .read(vendeursSuivisProvider.notifier)
                .basculer(vendeurId);
          } on ApiException catch (erreur) {
            if (!context.mounted) return;
            AppFeedback.erreur(context, erreur.message);
          }
        },
        child: AnimatedContainer(
          duration: Mouvements.rapide,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? Espaces.sm : Espaces.md,
            vertical: compact ? 5 : Espaces.xs + 1,
          ),
          decoration: BoxDecoration(
            gradient: suit ? null : AppColors.degradeMarque,
            color: suit ? AppColors.emeraude.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(Rayons.pilule),
            border: Border.all(
              color: suit
                  ? AppColors.emeraude.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                suit ? Icons.check_rounded : Icons.add_rounded,
                size: compact ? 13 : 16,
                color: suit ? AppColors.emeraude : Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                suit ? 'Suivi' : 'Suivre',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: compact ? 12 : 13,
                  color: suit ? AppColors.emeraude : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
