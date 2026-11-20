import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Messages flottants de l'application.
///
/// Une seule entree pour tous les retours : succes, erreur, information. Le
/// bandeau porte une icone ET une couleur, parce qu'une couleur seule ne
/// suffit pas pour qui distingue mal le rouge du vert.
class AppFeedback {
  const AppFeedback._();

  static void succes(BuildContext context, String message) =>
      _afficher(context, message, AppColors.succes, Icons.check_circle_rounded);

  static void erreur(BuildContext context, String message) {
    HapticFeedback.heavyImpact();
    _afficher(context, message, AppColors.erreur, Icons.error_rounded);
  }

  static void info(BuildContext context, String message) =>
      _afficher(context, message, AppColors.info, Icons.info_rounded);

  static void attention(BuildContext context, String message) =>
      _afficher(context, message, AppColors.alerte, Icons.warning_rounded);

  static void _afficher(
    BuildContext context,
    String message,
    Color couleur,
    IconData icone,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    // On remplace le message precedent : empiler trois bandeaux oblige la
    // personne a attendre que les deux premiers disparaissent.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: _Bandeau(message: message, couleur: couleur, icone: icone),
        ),
      );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({
    required this.message,
    required this.couleur,
    required this.icone,
  });

  final String message;
  final Color couleur;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.md,
        vertical: Espaces.sm + 2,
      ),
      decoration: BoxDecoration(
        color: sombre ? AppColors.encreSurfaceHaute : AppColors.blanc,
        borderRadius: Rayons.carte,
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
        boxShadow: AppColors.ombreCarte(sombre: sombre),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: couleur, size: 18),
          ),
          const SizedBox(width: Espaces.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: sombre
                        ? AppColors.texteClair
                        : AppColors.texteSombre,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
