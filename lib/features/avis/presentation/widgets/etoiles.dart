import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Etoiles en LECTURE, avec demi-etoiles pour les moyennes.
///
/// Une moyenne de 4,5 doit se voir comme 4,5 et non comme 4 ou 5 :
/// arrondir ferait mentir l'affichage sur une donnee que le serveur a
/// calculee precisement.
class Etoiles extends StatelessWidget {
  const Etoiles({
    super.key,
    required this.note,
    this.taille = 15,
    this.couleur = AppColors.or,
  });

  final double note;
  final double taille;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 1; index <= 5; index++)
          Icon(
            note >= index
                ? Icons.star_rounded
                : (note >= index - 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded),
            size: taille,
            color: couleur,
          ),
      ],
    );
  }
}

/// Etoiles en SAISIE, de 1 a 5.
///
/// Pas de zero : le serveur exige `1 <= note <= 5`. Proposer une etoile
/// vide comme valeur ferait croire a une note nulle possible, et l'envoi
/// serait refuse.
class EtoilesSaisie extends StatelessWidget {
  const EtoilesSaisie({
    super.key,
    required this.note,
    required this.onChange,
    this.taille = 34,
  });

  final int note;
  final ValueChanged<int> onChange;
  final double taille;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var valeur = 1; valeur <= 5; valeur++)
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(),
            iconSize: taille,
            tooltip: '$valeur sur 5',
            onPressed: () {
              HapticFeedback.selectionClick();
              onChange(valeur);
            },
            icon: Icon(
              note >= valeur ? Icons.star_rounded : Icons.star_outline_rounded,
              color: note >= valeur
                  ? AppColors.or
                  : Theme.of(context).dividerColor,
            ),
          ),
      ],
    );
  }
}

/// Note chiffree accolee a ses etoiles, format compact.
class NoteCompacte extends StatelessWidget {
  const NoteCompacte({
    super.key,
    required this.note,
    this.nombre,
    this.taille = 13,
  });

  final double? note;
  final int? nombre;
  final double taille;

  @override
  Widget build(BuildContext context) {
    if (note == null) {
      return Text(
        'Pas encore note',
        style: TextStyle(
          fontSize: taille - 1.5,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: taille + 2, color: AppColors.or),
        const SizedBox(width: 2),
        Text(
          note!.toStringAsFixed(1),
          style: TextStyle(fontSize: taille, fontWeight: FontWeight.w700),
        ),
        if (nombre != null && nombre! > 0) ...[
          const SizedBox(width: 3),
          Text(
            '($nombre)',
            style: TextStyle(
              fontSize: taille - 2,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ],
    );
  }
}

/// Repartition des notes, de 5 vers 1.
///
/// Elle vient de la route publique du vendeur. Montrer la repartition
/// plutot que la seule moyenne permet de distinguer un 4 regulier d'un 4
/// fait de 5 et de 1 — ce n'est pas la meme chose pour un acheteur.
class RepartitionNotes extends StatelessWidget {
  const RepartitionNotes({
    super.key,
    required this.repartition,
    required this.total,
  });

  final Map<String, int> repartition;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (repartition.isEmpty || total == 0) return const SizedBox.shrink();

    return Column(
      children: [
        for (var note = 5; note >= 1; note--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  child: Text(
                    '$note',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.star_rounded, size: 11, color: AppColors.or),
                const SizedBox(width: Espaces.xs),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Rayons.pilule),
                    child: LinearProgressIndicator(
                      value: (repartition['$note'] ?? 0) / total,
                      minHeight: 5,
                      backgroundColor: Theme.of(context).dividerColor,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.or),
                    ),
                  ),
                ),
                const SizedBox(width: Espaces.xs),
                SizedBox(
                  width: 24,
                  child: Text(
                    '${repartition['$note'] ?? 0}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
