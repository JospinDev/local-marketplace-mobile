import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formats.dart';
import '../../domain/vente.dart';

({Color couleur, IconData icone}) apparenceVente(StatutVente statut) {
  switch (statut) {
    case StatutVente.initiated:
      return (couleur: AppColors.alerte, icone: Icons.receipt_outlined);
    case StatutVente.paid:
      return (couleur: AppColors.info, icone: Icons.payments_outlined);
    case StatutVente.completed:
      return (couleur: AppColors.emeraude, icone: Icons.task_alt_rounded);
    case StatutVente.cancelled:
      return (couleur: AppColors.erreur, icone: Icons.cancel_outlined);
    case StatutVente.refunded:
      return (couleur: AppColors.erreur, icone: Icons.undo_rounded);
    case StatutVente.inconnu:
      return (couleur: AppColors.texteSombreDoux, icone: Icons.help_outline);
  }
}

class VenteCarte extends StatelessWidget {
  const VenteCarte({super.key, required this.vente, required this.onTap});

  final Vente vente;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final apparence = apparenceVente(vente.statut);

    // Les deux gestes qui attendent quelqu'un meritent d'etre signales.
    final aAgir =
        vente.jePeuxConfirmerLePaiement || vente.jePeuxConfirmerLaReception;

    return Material(
      color: sombre
          ? AppColors.encreSurface.withValues(alpha: 0.7)
          : AppColors.blanc,
      borderRadius: BorderRadius.circular(Rayons.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rayons.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Espaces.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rayons.md),
            border: Border.all(
              color: aAgir
                  ? AppColors.info.withValues(alpha: 0.45)
                  : (sombre
                      ? AppColors.encreBordure
                      : AppColors.bordureClaire),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(apparence.icone, size: 18, color: apparence.couleur),
                  const SizedBox(width: Espaces.xs),
                  Expanded(
                    child: Text(
                      vente.titreResume,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    Formats.montant(vente.montantTotal, devise: vente.devise),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emeraude,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Espaces.xxs),
              Text(
                vente.monRole.estVendeur
                    ? 'Client : ${vente.acheteurUsername ?? '?'}'
                    : 'Vendeur : ${vente.vendeurUsername ?? '?'}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: sombre
                      ? AppColors.texteClairDoux
                      : AppColors.texteSombreDoux,
                ),
              ),
              const SizedBox(height: Espaces.xs),
              _Progression(vente: vente),
              const SizedBox(height: Espaces.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      vente.statutLibelle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: apparence.couleur,
                      ),
                    ),
                  ),
                  Text(
                    '${Formats.unites(vente.quantiteTotale)} · '
                    '${Formats.depuis(vente.creeLe)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: sombre
                          ? AppColors.texteClairDoux
                          : AppColors.texteSombreDoux,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les trois etapes du double accuse, en une ligne.
///
/// Rendre la progression visible est le point : sans elle, personne ne
/// comprend pourquoi une vente payee n'est pas encore « terminee ».
class _Progression extends StatelessWidget {
  const _Progression({required this.vente});

  final Vente vente;

  @override
  Widget build(BuildContext context) {
    if (vente.statut.estAnnulee) {
      return Row(
        children: [
          const Icon(Icons.block_rounded, size: 13, color: AppColors.erreur),
          const SizedBox(width: Espaces.xxs),
          Expanded(
            child: Text(
              vente.statut == StatutVente.refunded
                  ? 'Remboursee'
                  : 'Annulee',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.erreur,
              ),
            ),
          ),
        ],
      );
    }

    final atteint = switch (vente.statut) {
      StatutVente.initiated => 1,
      StatutVente.paid => 2,
      StatutVente.completed => 3,
      _ => 0,
    };

    return Row(
      children: [
        for (var etape = 1; etape <= 3; etape++) ...[
          if (etape > 1)
            Expanded(
              child: Container(
                height: 2,
                color: etape <= atteint
                    ? AppColors.emeraude
                    : Theme.of(context).dividerColor,
              ),
            ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: etape <= atteint
                  ? AppColors.emeraude
                  : Colors.transparent,
              border: Border.all(
                color: etape <= atteint
                    ? AppColors.emeraude
                    : Theme.of(context).dividerColor,
                width: 1.5,
              ),
            ),
            child: etape <= atteint
                ? const Icon(Icons.check_rounded,
                    size: 10, color: AppColors.blanc)
                : null,
          ),
        ],
        const SizedBox(width: Espaces.xs),
        Text(
          switch (atteint) {
            1 => 'Declaree',
            2 => 'Payee',
            3 => 'Terminee',
            _ => '',
          },
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
