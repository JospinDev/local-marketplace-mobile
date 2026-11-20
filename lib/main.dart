import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/storage/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Barre de statut transparente : le fond degrade de l'application
  // remonte jusqu'en haut de l'ecran, ce qui donne l'aspect « pleine
  // hauteur » des maquettes modernes.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // L'application reste en portrait : toutes les mises en page sont
  // pensees pour une colonne, et un paysage mal gere fait plus de degats
  // qu'une orientation verrouillee.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Le trousseau est relu AVANT le premier rendu : sans cela, l'ecran de
  // demarrage afficherait brievement « deconnecte » avant de se corriger.
  final jetons = TokenStore();
  await jetons.initialiser();

  runApp(
    ProviderScope(
      overrides: [tokenStoreProvider.overrideWithValue(jetons)],
      child: const MarketplaceApp(),
    ),
  );
}
