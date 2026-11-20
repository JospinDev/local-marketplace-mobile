import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Logo de Marketplace Burundi, dessine et non importe.
///
/// Un logo peint se redimensionne sans perte, change de couleur avec le
/// theme et s'anime (le toit se construit). Une image PNG ne fait aucune de
/// ces trois choses.
///
/// Le dessin : un toit de marche traditionnel pose sur un panier, reduit a
/// ses lignes essentielles.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.taille = 64,
    this.progression = 1,
  });

  final double taille;

  /// 0 → rien n'est dessine, 1 → logo complet. Permet de « construire » le
  /// logo a l'ouverture de l'application.
  final double progression;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille,
      height: taille,
      child: CustomPaint(
        painter: _PeintreLogo(progression: progression.clamp(0, 1)),
      ),
    );
  }
}

class _PeintreLogo extends CustomPainter {
  _PeintreLogo({required this.progression});

  final double progression;

  @override
  void paint(Canvas toile, Size taille) {
    final l = taille.width;
    final h = taille.height;

    final traitLarge = l * 0.11;

    // --- le toit : un chevron qui se trace de gauche a droite ----------
    final toit = Path()
      ..moveTo(l * 0.12, h * 0.42)
      ..lineTo(l * 0.5, h * 0.12)
      ..lineTo(l * 0.88, h * 0.42);

    final avancementToit = (progression / 0.55).clamp(0.0, 1.0);
    _tracerPartiel(
      toile,
      toit,
      avancementToit,
      Paint()
        ..shader = AppColors.degradeMarque
            .createShader(Rect.fromLTWH(0, 0, l, h))
        ..style = PaintingStyle.stroke
        ..strokeWidth = traitLarge
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // --- le panier : un U qui apparait ensuite --------------------------
    final avancementPanier =
        ((progression - 0.45) / 0.55).clamp(0.0, 1.0);
    if (avancementPanier > 0) {
      final panier = Path()
        ..moveTo(l * 0.22, h * 0.52)
        ..lineTo(l * 0.28, h * 0.84)
        ..lineTo(l * 0.72, h * 0.84)
        ..lineTo(l * 0.78, h * 0.52);

      _tracerPartiel(
        toile,
        panier,
        avancementPanier,
        Paint()
          ..shader = AppColors.degradeMarqueInverse
              .createShader(Rect.fromLTWH(0, 0, l, h))
          ..style = PaintingStyle.stroke
          ..strokeWidth = traitLarge * 0.86
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // --- la pastille d'or : le point final ------------------------------
    final avancementPoint = ((progression - 0.82) / 0.18).clamp(0.0, 1.0);
    if (avancementPoint > 0) {
      toile.drawCircle(
        Offset(l * 0.5, h * 0.60),
        l * 0.085 * avancementPoint,
        Paint()..color = AppColors.or,
      );
    }
  }

  /// Dessine une fraction d'un chemin, pour l'effet « trait qui se trace ».
  void _tracerPartiel(
    Canvas toile,
    Path chemin,
    double fraction,
    Paint peinture,
  ) {
    if (fraction <= 0) return;
    if (fraction >= 1) {
      toile.drawPath(chemin, peinture);
      return;
    }
    for (final metrique in chemin.computeMetrics()) {
      toile.drawPath(
        metrique.extractPath(0, metrique.length * fraction),
        peinture,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PeintreLogo ancien) =>
      ancien.progression != progression;
}

/// Logo accompagne du nom, pour les en-tetes.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.taille = 34, this.clair = false});

  final double taille;
  final bool clair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(taille: taille),
        SizedBox(width: taille * 0.3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Marketplace',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: taille * 0.46,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -0.5,
                color: clair ? Colors.white : null,
              ),
            ),
            Text(
              'BURUNDI',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: taille * 0.27,
                fontWeight: FontWeight.w700,
                letterSpacing: 3.2,
                height: 1.1,
                color: clair
                    ? Colors.white.withValues(alpha: 0.75)
                    : AppColors.emeraude,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Pastille circulaire contenant une icone, avec fond teinte.
class IconPastille extends StatelessWidget {
  const IconPastille({
    super.key,
    required this.icone,
    this.couleur = AppColors.emeraude,
    this.taille = 40,
    this.tailleIcone,
  });

  final IconData icone;
  final Color couleur;
  final double taille;
  final double? tailleIcone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(taille * 0.34),
        border: Border.all(color: couleur.withValues(alpha: 0.22)),
      ),
      child: Icon(
        icone,
        size: tailleIcone ?? taille * 0.46,
        color: couleur,
      ),
    );
  }
}

/// Etiquette arrondie, pour les statuts et les categories.
class Etiquette extends StatelessWidget {
  const Etiquette({
    super.key,
    required this.texte,
    this.couleur = AppColors.emeraude,
    this.icone,
    this.compacte = false,
  });

  final String texte;
  final Color couleur;
  final IconData? icone;
  final bool compacte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacte ? Espaces.xs : Espaces.sm,
        vertical: compacte ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(Rayons.pilule),
        border: Border.all(color: couleur.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: compacte ? 11 : 13, color: couleur),
            const SizedBox(width: 4),
          ],
          Text(
            texte,
            style: TextStyle(
              color: couleur,
              fontSize: compacte ? 10.5 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
