import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formats.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/reseau_image.dart';
import '../../domain/produit.dart';

/// Carte produit de la grille.
///
/// Trois partis pris :
///
/// - **l'image est carree-ish (ratio 1.08)** et non 16/9 : les annonces
///   d'un marche local sont photographiees au telephone, en portrait le
///   plus souvent. Un cadre large couperait le sujet ;
/// - **le prix est le dernier element lu**, en gras et en couleur de
///   marque : c'est l'information qui decide d'un appui ;
/// - **le badge de rupture recouvre l'image** plutot que de se glisser
///   dans le texte, pour qu'on ne lise pas un prix en croyant pouvoir
///   acheter.
///
/// La carte est enveloppee d'un `Hero` : l'image grandit jusqu'a la fiche
/// au lieu de disparaitre puis reapparaitre.
class ProduitCarte extends StatefulWidget {
  const ProduitCarte({
    super.key,
    required this.produit,
    required this.onTap,
    this.etiquetteHero = 'grille',
  });

  final Produit produit;
  final VoidCallback onTap;

  /// Deux listes peuvent afficher le meme produit (mises en avant ET
  /// nouveautes). Sans prefixe distinct, Flutter trouverait deux `Hero`
  /// de meme nom a l'ecran et leverait une erreur.
  final String etiquetteHero;

  @override
  State<ProduitCarte> createState() => _ProduitCarteState();
}

class _ProduitCarteState extends State<ProduitCarte> {
  bool _appuye = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;
    final produit = widget.produit;
    final indisponible = produit.estEnRupture;

    return GestureDetector(
      onTapDown: (_) => setState(() => _appuye = true),
      onTapUp: (_) => setState(() => _appuye = false),
      onTapCancel: () => setState(() => _appuye = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _appuye ? 0.97 : 1,
        duration: Mouvements.eclair,
        curve: Mouvements.sortie,
        child: Container(
          decoration: BoxDecoration(
            color: sombre ? AppColors.encreSurface : AppColors.blanc,
            borderRadius: Rayons.carte,
            border: Border.all(
              color: sombre
                  ? AppColors.encreBordure
                  : AppColors.bordureClaire,
            ),
            boxShadow: AppColors.ombreCarte(sombre: sombre),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----------------------------------------------- visuel
              Stack(
                children: [
                  Hero(
                    tag: '${widget.etiquetteHero}-produit-${produit.id}',
                    child: AspectRatio(
                      aspectRatio: 1.08,
                      child: ReseauImage(
                        url: produit.imageAffichee?.url,
                        rayon: const BorderRadius.vertical(
                          top: Radius.circular(Rayons.md),
                        ),
                      ),
                    ),
                  ),

                  if (indisponible)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.encre.withValues(alpha: 0.55),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(Rayons.md),
                          ),
                        ),
                        child: const Center(
                          child: Etiquette(
                            texte: 'Rupture',
                            couleur: AppColors.erreur,
                            icone: Icons.remove_shopping_cart_outlined,
                          ),
                        ),
                      ),
                    ),

                  if (produit.estMisEnAvant && !indisponible)
                    const Positioned(
                      top: Espaces.xs,
                      left: Espaces.xs,
                      child: _Pastille(
                        texte: 'Mis en avant',
                        icone: Icons.star_rounded,
                        degrade: AppColors.degradeOr,
                      ),
                    ),

                  if (produit.distanceKm != null)
                    Positioned(
                      top: Espaces.xs,
                      right: Espaces.xs,
                      child: _Pastille(
                        texte: Formats.distance(produit.distanceKm),
                        icone: Icons.near_me_rounded,
                        degrade: AppColors.degradeMarque,
                      ),
                    ),
                ],
              ),

              // ---------------------------------------------- contenu
              Padding(
                padding: const EdgeInsets.all(Espaces.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (produit.categorieNom != null)
                      Text(
                        produit.categorieNom!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9.5,
                          letterSpacing: 0.9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraude,
                        ),
                      ),
                    const SizedBox(height: 3),

                    // Hauteur fixe sur deux lignes : sans cela, une carte
                    // a titre court et une a titre long n'ont pas la meme
                    // hauteur et la grille devient irreguliere.
                    SizedBox(
                      height: 38,
                      child: Text(
                        produit.titre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          height: 1.25,
                          fontSize: 13.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: Espaces.xs),

                    if (produit.localisation != null)
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 12,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              produit.localisation!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: Espaces.xs),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            Formats.montant(produit.prix,
                                devise: produit.devise),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.emeraude,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (produit.etat == EtatProduit.occasion)
                          const Etiquette(
                            texte: 'Occasion',
                            couleur: AppColors.sarcelle,
                            compacte: true,
                          ),
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
}

/// Pastille posee sur l'image, lisible quelle que soit la photo.
class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.texte,
    required this.icone,
    required this.degrade,
  });

  final String texte;
  final IconData icone;
  final LinearGradient degrade;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        gradient: degrade,
        borderRadius: BorderRadius.circular(Rayons.pilule),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            texte,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte horizontale, pour les carrousels de l'accueil.
class ProduitCarteLarge extends StatelessWidget {
  const ProduitCarteLarge({
    super.key,
    required this.produit,
    required this.onTap,
    this.etiquetteHero = 'carrousel',
  });

  final Produit produit;
  final VoidCallback onTap;
  final String etiquetteHero;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: ProduitCarte(
        produit: produit,
        onTap: onTap,
        etiquetteHero: etiquetteHero,
      ),
    );
  }
}
