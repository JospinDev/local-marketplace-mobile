import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Symbole de la marque : le sac de courses.
///
/// C'est desormais l'image officielle (`assets/branding/symbole.png`) et
/// non plus un dessin : l'identite doit etre LA MEME que celle de l'icone
/// de l'application et de l'ecran d'ouverture. Un logo peint a la main a
/// beau se redimensionner sans perte, deux identites differentes dans la
/// meme application en valent une seule mal faite.
///
/// `progression` est conservee pour l'animation d'ouverture : le symbole
/// apparait en fondu et grandit legerement, au lieu de se dessiner trait
/// par trait.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.taille = 64, this.progression = 1});

  final double taille;

  /// 0 → invisible, 1 → symbole complet.
  final double progression;

  @override
  Widget build(BuildContext context) {
    final avancee = progression.clamp(0.0, 1.0);

    return SizedBox(
      width: taille,
      height: taille,
      child: Opacity(
        opacity: avancee,
        child: Transform.scale(
          scale: 0.82 + 0.18 * avancee,
          // Export d'INTERFACE, distinct de `symbole.png` : ce dernier
          // porte la marge large qu'exige l'icone adaptative d'Android,
          // qui rendrait le logo minuscule ici. Imposer `width` et
          // `height` aurait de toute facon rendu `scale` sans effet.
          child: Image.asset(
            'assets/branding/symbole_ui.png',
            width: taille,
            height: taille,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

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
