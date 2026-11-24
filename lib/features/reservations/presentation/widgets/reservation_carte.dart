import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formats.dart';
import '../../../../core/widgets/reseau_image.dart';
import '../../domain/reservation.dart';

/// Couleur et icone d'un statut, au meme endroit pour toute l'application.
({Color couleur, IconData icone}) apparenceStatut(StatutReservation statut) {
  switch (statut) {
    case StatutReservation.pending:
      return (couleur: AppColors.alerte, icone: Icons.hourglass_top_rounded);
    case StatutReservation.confirmed:
      return (couleur: AppColors.emeraude, icone: Icons.verified_rounded);
    case StatutReservation.fulfilled:
      return (couleur: AppColors.info, icone: Icons.receipt_long_rounded);
    case StatutReservation.cancelled:
      return (couleur: AppColors.erreur, icone: Icons.cancel_outlined);
    case StatutReservation.expired:
      return (couleur: AppColors.erreur, icone: Icons.timer_off_outlined);
    case StatutReservation.inconnu:
      return (couleur: AppColors.texteSombreDoux, icone: Icons.help_outline);
  }
}

/// Carte d'une reservation dans une liste.
class ReservationCarte extends StatelessWidget {
  const ReservationCarte({
    super.key,
    required this.reservation,
    required this.onTap,
  });

  final Reservation reservation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final apparence = apparenceStatut(reservation.statut);
    final produit = reservation.produit;

    // Une demande en attente chez le vendeur merite d'etre signalee : c'est
    // la seule situation qui appelle une action immediate.
    final aTraiter = reservation.jePeuxAccepter;

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
              color: aTraiter
                  ? AppColors.alerte.withValues(alpha: 0.45)
                  : (sombre
                      ? AppColors.encreBordure
                      : AppColors.bordureClaire),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReseauImage(
                    url: produit?.image,
                    largeur: 56,
                    hauteur: 56,
                    rayon: BorderRadius.circular(Rayons.sm),
                  ),
                  const SizedBox(width: Espaces.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          produit?.titre ?? 'Annonce',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: Espaces.xxs),
                        Text(
                          reservation.monRole.estVendeur
                              ? 'Demande de ${reservation.acheteurUsername ?? '?'}'
                              : 'Vendeur : ${reservation.vendeurUsername ?? '?'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: sombre
                                ? AppColors.texteClairDoux
                                : AppColors.texteSombreDoux,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Espaces.xs),
                  _Pastille(
                    texte: reservation.statutLibelle.isNotEmpty
                        ? reservation.statutLibelle
                        : 'Statut inconnu',
                    couleur: apparence.couleur,
                    icone: apparence.icone,
                  ),
                ],
              ),
              const SizedBox(height: Espaces.sm),
              Wrap(
                spacing: Espaces.xs,
                runSpacing: Espaces.xxs,
                children: [
                  _Fait(
                    libelle: reservation.statut == StatutReservation.pending
                        ? 'Demande'
                        : 'Confirme',
                    valeur: Formats.unites(reservation.quantiteUtile),
                  ),
                  if (reservation.accepteePartiellement)
                    _Fait(
                      libelle: 'Demandait',
                      valeur: Formats.unites(reservation.quantiteDemandee),
                      attention: true,
                    ),
                  if (reservation.valeurEstimee != null)
                    _Fait(
                      libelle: 'Valeur estimee',
                      valeur: Formats.montant(
                        reservation.valeurEstimee!,
                        devise: produit?.devise ?? 'BIF',
                      ),
                    ),
                ],
              ),
              if (reservation.statut.immobiliseDuStock &&
                  reservation.expireLe != null) ...[
                const SizedBox(height: Espaces.xs),
                _Delai(expireLe: reservation.expireLe!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.texte,
    required this.couleur,
    required this.icone,
  });

  final String texte;
  final Color couleur;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 108),
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Rayons.pilule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: couleur),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: couleur,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fait extends StatelessWidget {
  const _Fait({
    required this.libelle,
    required this.valeur,
    this.attention = false,
  });

  final String libelle;
  final String valeur;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          libelle,
          style: TextStyle(
            fontSize: 10,
            color: sombre
                ? AppColors.texteClairDoux
                : AppColors.texteSombreDoux,
          ),
        ),
        Text(
          valeur,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: attention ? AppColors.alerte : null,
            decoration: attention ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }
}

/// Delai de RETRAIT : ce n'est pas un delai de reponse, le compte a rebours
/// repart a l'acceptation du vendeur.
class _Delai extends StatelessWidget {
  const _Delai({required this.expireLe});

  final DateTime expireLe;

  @override
  Widget build(BuildContext context) {
    final restant = expireLe.difference(DateTime.now());
    final presse = restant.inHours < 12;
    final couleur = restant.isNegative
        ? AppColors.erreur
        : (presse ? AppColors.alerte : AppColors.emeraude);

    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 13, color: couleur),
        const SizedBox(width: Espaces.xxs),
        Expanded(
          child: Text(
            restant.isNegative
                ? 'Delai de retrait depasse'
                : 'A retirer sous ${_duree(restant)}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: couleur,
            ),
          ),
        ),
      ],
    );
  }

  static String _duree(Duration d) {
    if (d.inDays >= 1) {
      final heures = d.inHours % 24;
      return heures == 0
          ? '${d.inDays} jour${d.inDays > 1 ? 's' : ''}'
          : '${d.inDays} j $heures h';
    }
    if (d.inHours >= 1) return '${d.inHours} h';
    return '${d.inMinutes} min';
  }
}
