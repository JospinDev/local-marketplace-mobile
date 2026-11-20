import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

/// Racine de l'application.
///
/// Le routeur est lu depuis Riverpod : il se reconstruit quand la phase
/// d'authentification change, ce qui declenche la redirection sans qu'un
/// seul ecran n'ait besoin d'appeler `Navigator`.
class MarketplaceApp extends ConsumerWidget {
  const MarketplaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeur = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Marketplace Burundi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.clair,
      darkTheme: AppTheme.sombre,
      // On suit le reglage du systeme : imposer un mode est une facon de
      // dire a la personne qu'on sait mieux qu'elle ce qui lui convient.
      themeMode: ThemeMode.system,
      routerConfig: routeur,
      builder: (context, enfant) {
        // Plafonne l'agrandissement du texte. Au-dela de 1,3, les cartes
        // de prix et les barres d'onglets debordent ; en dessous de 0,9,
        // le reglage de la personne n'est plus respecte.
        final echelle = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: echelle),
          child: enfant ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
