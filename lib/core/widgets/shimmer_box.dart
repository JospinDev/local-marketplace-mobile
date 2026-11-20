import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Squelette de chargement anime.
///
/// Ecrit a la main plutot qu'avec le paquet `shimmer`, pour deux raisons :
/// la connexion de developpement est instable et chaque dependance en
/// moins est une compilation qui aboutit ; et l'effet tient en une
/// vingtaine de lignes — un `LinearGradient` qu'on fait glisser.
///
/// Pourquoi un squelette plutot qu'une roue qui tourne : il montre la
/// FORME de ce qui arrive. L'oeil se place avant que le contenu
/// n'apparaisse, et l'attente parait plus courte a duree egale.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.largeur,
    this.hauteur = 16,
    this.rayon,
    this.forme = BoxShape.rectangle,
  });

  final double? largeur;
  final double hauteur;
  final BorderRadius? rayon;
  final BoxShape forme;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final base = sombre ? AppColors.encreSurfaceHaute : AppColors.bordureClaire;
    final eclat = sombre
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.85);

    // Respecte « reduire les animations » : on laisse alors un bloc uni.
    final mouvementReduit = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controleur,
        builder: (context, _) {
          final t = mouvementReduit ? 0.5 : _controleur.value;
          return Container(
            width: widget.largeur,
            height: widget.hauteur,
            decoration: BoxDecoration(
              shape: widget.forme,
              borderRadius: widget.forme == BoxShape.circle
                  ? null
                  : (widget.rayon ?? BorderRadius.circular(Rayons.xs)),
              gradient: LinearGradient(
                // Le reflet traverse la boite de gauche a droite : les
                // bornes vont au-dela de [0,1] pour qu'il entre et sorte
                // completement du cadre.
                begin: Alignment(-1.6 + 3.2 * t, -0.3),
                end: Alignment(-0.6 + 3.2 * t, 0.3),
                colors: [base, eclat, base],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Squelette d'une carte produit, aux proportions de la vraie carte.
///
/// Les dimensions doivent coller a celles de `ProduitCarte` : si le
/// squelette est plus petit, la grille sursaute au moment ou les donnees
/// arrivent — exactement ce qu'un squelette est cense eviter.
class SqueletteCarteProduit extends StatelessWidget {
  const SqueletteCarteProduit({super.key});

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: sombre ? AppColors.encreSurface : AppColors.blanc,
        borderRadius: Rayons.carte,
        border: Border.all(
          color: sombre ? AppColors.encreBordure : AppColors.bordureClaire,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Rayons.md),
            ),
            child: AspectRatio(
              aspectRatio: 1.08,
              child: ShimmerBox(hauteur: double.infinity, rayon: BorderRadius.zero),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(Espaces.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(hauteur: 12, largeur: 70),
                SizedBox(height: Espaces.xs),
                ShimmerBox(hauteur: 14),
                SizedBox(height: 6),
                ShimmerBox(hauteur: 14, largeur: 120),
                SizedBox(height: Espaces.sm),
                ShimmerBox(hauteur: 18, largeur: 90),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
