import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'shimmer_box.dart';

/// Image distante avec ses trois etats : chargement, succes, echec.
///
/// `Image.network` nu affiche un carre vide pendant le telechargement puis
/// une icone de rupture en cas d'echec — deux moments ou l'interface a
/// l'air cassee. Ce composant traite les trois cas explicitement.
///
/// Il n'utilise PAS `cached_network_image` : Flutter garde deja les images
/// en memoire, et chaque dependance native en moins est une compilation
/// qui aboutit sur une connexion instable. Le cache DISQUE, lui, reste a
/// gagner — c'est le seul vrai apport du paquet, et on l'ajoutera quand le
/// reseau le permettra.
class ReseauImage extends StatelessWidget {
  const ReseauImage({
    super.key,
    required this.url,
    this.ajustement = BoxFit.cover,
    this.rayon,
    this.largeur,
    this.hauteur,
    this.iconeRepli = Icons.image_outlined,
  });

  final String? url;
  final BoxFit ajustement;
  final BorderRadius? rayon;
  final double? largeur;
  final double? hauteur;
  final IconData iconeRepli;

  @override
  Widget build(BuildContext context) {
    final coins = rayon ?? BorderRadius.zero;

    if (url == null || url!.trim().isEmpty) {
      return ClipRRect(
        borderRadius: coins,
        child: _Repli(
          icone: iconeRepli,
          largeur: largeur,
          hauteur: hauteur,
        ),
      );
    }

    return ClipRRect(
      borderRadius: coins,
      child: Image.network(
        url!,
        width: largeur,
        height: hauteur,
        fit: ajustement,
        // Un fondu a l'arrivee : l'image qui « claque » d'un coup donne
        // une impression de saccade, meme quand tout va vite.
        frameBuilder: (context, enfant, frame, charge) {
          if (charge || frame != null) {
            return AnimatedOpacity(
              opacity: 1,
              duration: Mouvements.normal,
              curve: Mouvements.sortie,
              child: enfant,
            );
          }
          return ShimmerBox(
            largeur: largeur,
            hauteur: hauteur ?? 120,
            rayon: BorderRadius.zero,
          );
        },
        loadingBuilder: (context, enfant, progression) {
          if (progression == null) return enfant;
          return ShimmerBox(
            largeur: largeur,
            hauteur: hauteur ?? 120,
            rayon: BorderRadius.zero,
          );
        },
        errorBuilder: (context, erreur, trace) => _Repli(
          icone: Icons.broken_image_outlined,
          largeur: largeur,
          hauteur: hauteur,
        ),
      ),
    );
  }
}

class _Repli extends StatelessWidget {
  const _Repli({required this.icone, this.largeur, this.hauteur});

  final IconData icone;
  final double? largeur;
  final double? hauteur;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: largeur,
      height: hauteur,
      color: sombre ? AppColors.encreSurfaceHaute : AppColors.bordureClaire,
      alignment: Alignment.center,
      child: Icon(
        icone,
        size: 28,
        color: (sombre ? AppColors.texteClairDoux : AppColors.texteSombreDoux)
            .withValues(alpha: 0.5),
      ),
    );
  }
}
