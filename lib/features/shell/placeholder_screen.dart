import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/gradient_background.dart';

/// Ecran d'attente d'un module a venir.
///
/// Il annonce honnetement ce qui manque et a quelle etape du guide cela
/// arrive, plutot que d'afficher une page vide qui ressemble a un bug.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.titre,
    required this.etape,
    required this.description,
    required this.icone,
  });

  final String titre;
  final String etape;
  final String description;
  final IconData icone;

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
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: AppColors.emeraude.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Rayons.xl),
                    border: Border.all(
                      color: AppColors.emeraude.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(icone, size: 40, color: AppColors.emeraude),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: Espaces.xl),
                Text(
                  titre,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.25),
                const SizedBox(height: Espaces.xs),
                Etiquette(texte: etape, couleur: AppColors.or)
                    .animate(delay: 150.ms)
                    .fadeIn(),
                const SizedBox(height: Espaces.md),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ).animate(delay: 200.ms).fadeIn(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
