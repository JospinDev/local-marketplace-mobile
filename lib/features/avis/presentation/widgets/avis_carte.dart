import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formats.dart';
import '../../../../core/widgets/reseau_image.dart';
import '../../domain/evaluation.dart';
import 'etoiles.dart';

/// Carte d'un avis.
///
/// `montrerAuteur` est faux sur « mes avis » : on sait que c'est le sien,
/// et repeter son propre nom n'apprend rien.
class AvisCarte extends StatelessWidget {
  const AvisCarte({
    super.key,
    required this.avis,
    this.montrerAuteur = true,
    this.montrerProduit = true,
    this.onCorriger,
    this.onRetirer,
    this.onSignaler,
  });

  final Evaluation avis;
  final bool montrerAuteur;
  final bool montrerProduit;
  final VoidCallback? onCorriger;
  final VoidCallback? onRetirer;
  final VoidCallback? onSignaler;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;
    final aDesActions =
        onCorriger != null || onRetirer != null || onSignaler != null;

    return Container(
      padding: const EdgeInsets.all(Espaces.sm),
      decoration: BoxDecoration(
        color: sombre
            ? AppColors.encreSurface.withValues(alpha: 0.7)
            : AppColors.blanc,
        borderRadius: BorderRadius.circular(Rayons.md),
        border: Border.all(
          color: avis.estValide
              ? (sombre ? AppColors.encreBordure : AppColors.bordureClaire)
              : AppColors.erreur.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (montrerAuteur) ...[
                ClipOval(
                  child: avis.auteurPhoto != null
                      ? ReseauImage(
                          url: avis.auteurPhoto,
                          largeur: 32,
                          hauteur: 32,
                        )
                      : Container(
                          width: 32,
                          height: 32,
                          color: AppColors.emeraude.withValues(alpha: 0.18),
                          alignment: Alignment.center,
                          child: Text(
                            avis.auteurUsername.isNotEmpty
                                ? avis.auteurUsername[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.emeraude,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: Espaces.xs),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      montrerAuteur
                          ? (avis.auteurUsername.isNotEmpty
                              ? avis.auteurUsername
                              : 'Acheteur')
                          : 'Mon avis',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      [
                        Formats.depuis(avis.creeLe),
                        if (avis.aEteCorrigee) 'corrige',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              if (aDesActions)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, size: 19),
                  onSelected: (choix) {
                    switch (choix) {
                      case 'corriger':
                        onCorriger?.call();
                      case 'retirer':
                        onRetirer?.call();
                      case 'signaler':
                        onSignaler?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    if (onCorriger != null)
                      const PopupMenuItem(
                        value: 'corriger',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Corriger'),
                        ),
                      ),
                    if (onRetirer != null)
                      const PopupMenuItem(
                        value: 'retirer',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.visibility_off_outlined),
                          title: Text('Retirer'),
                        ),
                      ),
                    if (onSignaler != null)
                      const PopupMenuItem(
                        value: 'signaler',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.flag_outlined),
                          title: Text('Signaler'),
                        ),
                      ),
                  ],
                ),
            ],
          ),

          if (montrerProduit && avis.produitTitre.isNotEmpty) ...[
            const SizedBox(height: Espaces.xxs),
            Text(
              avis.produitTitre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.emeraude,
              ),
            ),
          ],

          // Les deux notes restent separees jusqu'a l'affichage.
          const SizedBox(height: Espaces.xs),
          Row(
            children: [
              _Note(libelle: 'Produit', note: avis.noteProduit),
              const SizedBox(width: Espaces.md),
              _Note(libelle: 'Vendeur', note: avis.noteVendeur),
            ],
          ),

          if (avis.commentaire.isNotEmpty) ...[
            const SizedBox(height: Espaces.xs),
            Text(
              avis.commentaire,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ],

          // Un avis masque ou retire doit le dire a son auteur, sinon il
          // croit qu'il compte encore dans la reputation du vendeur.
          if (!avis.estValide) ...[
            const SizedBox(height: Espaces.xs),
            Container(
              padding: const EdgeInsets.all(Espaces.xs),
              decoration: BoxDecoration(
                color: AppColors.erreur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Rayons.xs),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_off_rounded,
                      size: 14, color: AppColors.erreur),
                  const SizedBox(width: Espaces.xxs),
                  Expanded(
                    child: Text(
                      avis.motifModeration.isNotEmpty
                          ? '${avis.statutLibelle} : ${avis.motifModeration}'
                          : '${avis.statutLibelle} — cet avis ne compte plus '
                              'dans les moyennes.',
                      style: const TextStyle(fontSize: 11, height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.libelle, required this.note});

  final String libelle;
  final int note;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$libelle ',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontSize: 10.5),
        ),
        Etoiles(note: note.toDouble(), taille: 13),
      ],
    );
  }
}
