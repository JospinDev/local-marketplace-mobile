import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fond anime de l'application : deux halos colores qui derivent lentement
/// derriere un voile.
///
/// Pourquoi pas une image ? Parce qu'un degrade peint coute quelques
/// microsecondes, s'adapte a toutes les tailles d'ecran sans pixelliser, et
/// suit le theme clair/sombre sans qu'on ait deux fichiers a maintenir.
///
/// Le mouvement est TRES lent (18 secondes par tour) et de faible
/// amplitude : il doit se remarquer sans jamais attirer l'oeil pendant que
/// l'utilisateur lit un formulaire.
class GradientBackground extends StatefulWidget {
  const GradientBackground({
    super.key,
    required this.child,
    this.anime = true,
    this.intensite = 1.0,
  });

  final Widget child;

  /// Coupe l'animation : utile pour les ecrans denses, ou quand le systeme
  /// signale une preference de mouvement reduit.
  final bool anime;

  /// 0 = halos invisibles, 1 = pleine presence.
  final double intensite;

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void initState() {
    super.initState();
    if (widget.anime) _controleur.repeat();
  }

  @override
  void didUpdateWidget(covariant GradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.anime && !_controleur.isAnimating) {
      _controleur.repeat();
    } else if (!widget.anime && _controleur.isAnimating) {
      _controleur.stop();
    }
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    // Respecte le reglage systeme « reduire les animations » : une
    // interface qui bouge peut provoquer des nausees chez certaines
    // personnes, et ignorer ce reglage est un defaut d'accessibilite.
    final mouvementReduit = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controleur,
        builder: (context, enfant) {
          final t = mouvementReduit ? 0.0 : _controleur.value;
          return CustomPaint(
            painter: _PeintreHalos(
              progression: t,
              sombre: sombre,
              intensite: widget.intensite,
            ),
            child: enfant,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _PeintreHalos extends CustomPainter {
  _PeintreHalos({
    required this.progression,
    required this.sombre,
    required this.intensite,
  });

  final double progression;
  final bool sombre;
  final double intensite;

  @override
  void paint(Canvas toile, Size taille) {
    final fond = Paint()
      ..color = sombre ? AppColors.encre : AppColors.nuage;
    toile.drawRect(Offset.zero & taille, fond);

    final angle = progression * 2 * math.pi;

    // Halo emeraude, en haut a gauche.
    _halo(
      toile,
      taille,
      centre: Offset(
        taille.width * (0.18 + 0.08 * math.cos(angle)),
        taille.height * (0.12 + 0.05 * math.sin(angle)),
      ),
      rayon: taille.width * 0.75,
      couleur: AppColors.emeraude,
      opacite: (sombre ? 0.28 : 0.20) * intensite,
    );

    // Halo sarcelle, en bas a droite, en opposition de phase pour que les
    // deux ne se superposent jamais completement.
    _halo(
      toile,
      taille,
      centre: Offset(
        taille.width * (0.88 - 0.07 * math.sin(angle)),
        taille.height * (0.78 + 0.05 * math.cos(angle)),
      ),
      rayon: taille.width * 0.68,
      couleur: AppColors.sarcelle,
      opacite: (sombre ? 0.22 : 0.16) * intensite,
    );

    // Touche d'or, discrete : elle rechauffe un ensemble qui serait
    // autrement entierement froid.
    _halo(
      toile,
      taille,
      centre: Offset(
        taille.width * (0.72 + 0.06 * math.cos(angle * 0.7)),
        taille.height * (0.26 + 0.07 * math.sin(angle * 0.7)),
      ),
      rayon: taille.width * 0.42,
      couleur: AppColors.or,
      opacite: (sombre ? 0.12 : 0.10) * intensite,
    );
  }

  void _halo(
    Canvas toile,
    Size taille, {
    required Offset centre,
    required double rayon,
    required Color couleur,
    required double opacite,
  }) {
    final peinture = Paint()
      ..shader = RadialGradient(
        colors: [
          couleur.withValues(alpha: opacite),
          couleur.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: centre, radius: rayon));
    toile.drawCircle(centre, rayon, peinture);
  }

  @override
  bool shouldRepaint(covariant _PeintreHalos ancien) =>
      ancien.progression != progression ||
      ancien.sombre != sombre ||
      ancien.intensite != intensite;
}
