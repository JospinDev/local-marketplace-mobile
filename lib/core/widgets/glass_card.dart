import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Carte translucide, posee sur le fond anime.
///
/// Le flou est volontairement MODESTE (14 px) et la carte garde une bordure
/// claire d'un pixel : un flou fort sur mobile coute cher a chaque image, et
/// la bordure suffit a detacher la carte du fond. C'est ce qui permet d'en
/// afficher plusieurs dans une liste sans faire chuter le nombre d'images
/// par seconde.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Espaces.lg),
    this.rayon,
    this.flou = 14,
    this.onTap,
    this.bordure = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? rayon;
  final double flou;
  final VoidCallback? onTap;
  final bool bordure;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final coins = rayon ?? Rayons.grandeCarte;

    final contenu = ClipRRect(
      borderRadius: coins,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: flou, sigmaY: flou),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: AppColors.verre(sombre: sombre),
            borderRadius: coins,
            border: bordure
                ? Border.all(
                    color: sombre
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.70),
                    width: 1,
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return contenu;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: coins,
        child: contenu,
      ),
    );
  }
}

/// Carte pleine, pour les listes denses ou le verre serait illisible.
class SolidCard extends StatelessWidget {
  const SolidCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Espaces.md),
    this.rayon,
    this.onTap,
    this.ombre = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? rayon;
  final VoidCallback? onTap;
  final bool ombre;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final coins = rayon ?? Rayons.carte;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: coins,
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            color: sombre ? AppColors.encreSurface : AppColors.blanc,
            borderRadius: coins,
            border: Border.all(
              color: sombre ? AppColors.encreBordure : AppColors.bordureClaire,
            ),
            boxShadow: ombre ? AppColors.ombreCarte(sombre: sombre) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
