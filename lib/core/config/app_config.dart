import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Configuration d'environnement de l'application.
///
/// L'adresse du serveur n'est jamais codee en dur dans un ecran : elle se
/// surcharge au lancement sans recompiler, ce qui permet de viser un vrai
/// serveur depuis un telephone physique :
///
/// ```bash
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.12:8000
/// ```
class AppConfig {
  const AppConfig._();

  /// Valeur passee par `--dart-define`, prioritaire sur toute deduction.
  static const String _surcharge = String.fromEnvironment('API_BASE_URL');

  /// Origine du serveur, sans le `/api/v1` final.
  ///
  /// Par defaut, on devine l'adresse qui marche selon la cible :
  /// l'emulateur Android ne voit pas `127.0.0.1` (c'est le telephone
  /// virtuel lui-meme), il doit passer par `10.0.2.2`. C'est l'erreur de
  /// configuration numero un en developpement Flutter, autant l'eviter.
  static String get origine {
    if (_surcharge.isNotEmpty) return _surcharge;
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  /// Racine de l'API REST, versionnee.
  static String get baseUrl => '$origine/api/v1';

  /// Racine des WebSocket (modules 7 et 12).
  static String get wsUrl => origine.replaceFirst(RegExp(r'^http'), 'ws');

  /// Les listes de l'API sont paginees a 20 par defaut, 100 au maximum.
  static const int taillePage = 20;

  /// Delais reseau. Volontairement courts : sur un reseau mobile instable,
  /// un echec rapide suivi d'un bouton « reessayer » est preferable a une
  /// roue qui tourne pendant une minute.
  static const Duration delaiConnexion = Duration(seconds: 15);
  static const Duration delaiReception = Duration(seconds: 20);
}
