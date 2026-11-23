import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/conversation.dart';

/// Une bulle de message.
///
/// Trois etats visuels pour MES messages : en cours d'envoi (horloge),
/// envoye (coche), lu (double coche). L'echec devient rouge et cliquable.
/// Sans ce retour, un message perdu sur un reseau coupe passerait pour
/// envoye.
class BulleMessage extends StatelessWidget {
  const BulleMessage({
    super.key,
    required this.message,
    required this.afficherHeure,
    this.onReessayer,
  });

  final Message message;
  final bool afficherHeure;
  final VoidCallback? onReessayer;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final mien = message.estDeMoi;

    final fond = mien
        ? (message.echecEnvoi
            ? AppColors.erreur.withValues(alpha: 0.18)
            : AppColors.emeraude)
        : (sombre ? AppColors.encreSurfaceHaute : AppColors.blanc);

    final couleurTexte = mien
        ? (message.echecEnvoi
            ? (sombre ? AppColors.texteClair : AppColors.texteSombre)
            : AppColors.blanc)
        : (sombre ? AppColors.texteClair : AppColors.texteSombre);

    final rayon = BorderRadius.only(
      topLeft: const Radius.circular(Rayons.md),
      topRight: const Radius.circular(Rayons.md),
      bottomLeft: Radius.circular(mien ? Rayons.md : Rayons.xs),
      bottomRight: Radius.circular(mien ? Rayons.xs : Rayons.md),
    );

    final bulle = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.sm + 2,
        vertical: Espaces.xs + 2,
      ),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: rayon,
        border: mien
            ? null
            : Border.all(
                color: sombre
                    ? AppColors.encreBordure
                    : AppColors.bordureClaire,
              ),
        boxShadow: mien && !message.echecEnvoi
            ? [
                BoxShadow(
                  color: AppColors.emeraude.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message.contenu,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.35,
              color: couleurTexte,
            ),
          ),
          if (afficherHeure || mien) ...[
            const SizedBox(height: Espaces.xxs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _heure(message.creeLe),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: couleurTexte.withValues(alpha: 0.72),
                  ),
                ),
                if (mien) ...[
                  const SizedBox(width: Espaces.xxs),
                  _Accuse(message: message, couleur: couleurTexte),
                ],
              ],
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaces.xxs),
      child: Row(
        mainAxisAlignment:
            mien ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // 78 % de large au maximum : une bulle pleine largeur se lit mal
          // et on ne distingue plus qui parle.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: message.echecEnvoi
                ? InkWell(
                    onTap: onReessayer,
                    borderRadius: rayon,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        bulle,
                        const SizedBox(height: Espaces.xxs),
                        const Text(
                          'Non envoye — appuyez pour reessayer',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.erreur,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : bulle,
          ),
        ],
      ),
    );
  }

  static String _heure(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Accuse extends StatelessWidget {
  const _Accuse({required this.message, required this.couleur});

  final Message message;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    if (message.echecEnvoi) {
      return const Icon(Icons.error_outline_rounded,
          size: 13, color: AppColors.erreur);
    }
    if (message.enCoursEnvoi) {
      return Icon(Icons.schedule_rounded,
          size: 12, color: couleur.withValues(alpha: 0.72));
    }
    return Icon(
      message.estLu ? Icons.done_all_rounded : Icons.done_rounded,
      size: 13,
      color: message.estLu
          ? AppColors.orClair
          : couleur.withValues(alpha: 0.72),
    );
  }
}

/// Separateur de jour insere entre deux groupes de messages.
class SeparateurJour extends StatelessWidget {
  const SeparateurJour({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaces.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Espaces.sm,
            vertical: Espaces.xxs + 1,
          ),
          decoration: BoxDecoration(
            color: sombre
                ? AppColors.encreSurface.withValues(alpha: 0.9)
                : AppColors.blanc.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(Rayons.pilule),
            border: Border.all(
              color: sombre ? AppColors.encreBordure : AppColors.bordureClaire,
            ),
          ),
          child: Text(
            _libelle(date),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: sombre
                  ? AppColors.texteClairDoux
                  : AppColors.texteSombreDoux,
            ),
          ),
        ),
      ),
    );
  }

  static String _libelle(DateTime date) {
    final maintenant = DateTime.now();
    final jour = DateTime(date.year, date.month, date.day);
    final aujourdhui =
        DateTime(maintenant.year, maintenant.month, maintenant.day);
    final ecart = aujourdhui.difference(jour).inDays;

    if (ecart == 0) return 'Aujourd\'hui';
    if (ecart == 1) return 'Hier';

    const mois = [
      'janv.', 'fevr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'aout', 'sept.', 'oct.', 'nov.', 'dec.',
    ];
    final libelle = '${date.day} ${mois[date.month - 1]}';
    return date.year == maintenant.year ? libelle : '$libelle ${date.year}';
  }
}
