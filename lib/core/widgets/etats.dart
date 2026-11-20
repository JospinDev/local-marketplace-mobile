import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Ecran vide : il n'y a rien a montrer, et ce n'est pas une erreur.
///
/// La distinction avec [EtatErreur] compte : « aucun resultat » invite a
/// elargir la recherche, « connexion impossible » invite a reessayer. Les
/// confondre fait chercher un probleme la ou il n'y en a pas.
class EtatVide extends StatelessWidget {
  const EtatVide({
    super.key,
    required this.titre,
    required this.message,
    this.icone = Icons.search_off_rounded,
    this.libelleAction,
    this.onAction,
  });

  final String titre;
  final String message;
  final IconData icone;
  final String? libelleAction;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espaces.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: (sombre
                        ? AppColors.encreSurfaceHaute
                        : AppColors.bordureClaire)
                    .withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icone,
                size: 34,
                color: sombre
                    ? AppColors.texteClairDoux
                    : AppColors.texteSombreDoux,
              ),
            )
                .animate()
                .fadeIn(duration: 350.ms)
                .scale(begin: const Offset(0.85, 0.85)),
            const SizedBox(height: Espaces.lg),
            Text(
              titre,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ).animate(delay: 80.ms).fadeIn(),
            const SizedBox(height: Espaces.xs),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ).animate(delay: 120.ms).fadeIn(),
            if (onAction != null && libelleAction != null) ...[
              const SizedBox(height: Espaces.xl),
              AppButton(
                libelle: libelleAction!,
                style: StyleBouton.secondaire,
                pleineLargeur: false,
                compact: true,
                onPressed: onAction,
              ).animate(delay: 180.ms).fadeIn(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ecran d'erreur, avec le message du serveur et un bouton « reessayer ».
///
/// Le message affiche est celui du backend, tel quel : il est deja redige
/// pour la personne, et le reecrire ici ferait deux verites a maintenir.
class EtatErreur extends StatelessWidget {
  const EtatErreur({super.key, required this.erreur, this.onReessayer});

  final Object erreur;
  final VoidCallback? onReessayer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final estReseau = erreur is ApiException && (erreur as ApiException).estReseau;
    final message = erreur is ApiException
        ? (erreur as ApiException).message
        : "Une erreur inattendue s'est produite.";

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espaces.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.erreur.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                estReseau
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                size: 34,
                color: AppColors.erreur,
              ),
            ).animate().fadeIn(duration: 350.ms).scale(
                  begin: const Offset(0.85, 0.85),
                ),
            const SizedBox(height: Espaces.lg),
            Text(
              estReseau ? 'Connexion impossible' : 'Une erreur est survenue',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ).animate(delay: 80.ms).fadeIn(),
            const SizedBox(height: Espaces.xs),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ).animate(delay: 120.ms).fadeIn(),
            if (onReessayer != null) ...[
              const SizedBox(height: Espaces.xl),
              AppButton(
                libelle: 'Reessayer',
                icone: Icons.refresh_rounded,
                pleineLargeur: false,
                compact: true,
                onPressed: onReessayer,
              ).animate(delay: 180.ms).fadeIn(),
            ],
          ],
        ),
      ),
    );
  }
}
