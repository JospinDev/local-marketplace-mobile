import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/token_store.dart';

/// Canal personnel des notifications : `/ws/notifications/`.
///
/// Un seul canal pour toute l'application, ouvert tant qu'une session
/// existe. Le groupe Channels est personnel cote serveur : on ne recoit
/// que ses propres notifications.
///
/// Le temps reel est un confort. La notification est deja en base quand
/// elle est diffusee, donc une coupure ne perd rien : le prochain
/// chargement de la liste la fera apparaitre. C'est pourquoi ce canal ne
/// montre aucune erreur a l'ecran.
class NotificationsSocket {
  NotificationsSocket({required TokenStore jetons}) : _jetons = jetons;

  final TokenStore _jetons;

  WebSocketChannel? _canal;
  StreamSubscription<dynamic>? _abonnement;
  Timer? _reconnexion;

  final _evenements = StreamController<Map<String, dynamic>>.broadcast();

  int _tentatives = 0;
  bool _fermetureVoulue = false;
  bool _refusDefinitif = false;

  Stream<Map<String, dynamic>> get evenements => _evenements.stream;
  bool get estOuvert => _canal != null;

  Future<void> connecter() async {
    if (_canal != null || _refusDefinitif) return;
    _fermetureVoulue = false;

    final jeton = _jetons.acces;
    if (jeton == null || jeton.isEmpty) return;

    try {
      final canal = WebSocketChannel.connect(
        Uri.parse('${AppConfig.wsUrl}/ws/notifications/?token=$jeton'),
      );
      _canal = canal;
      await canal.ready;
      _tentatives = 0;

      _abonnement = canal.stream.listen(
        _surTrame,
        onError: (Object _) => _surCoupure(),
        onDone: _surCoupure,
        cancelOnError: true,
      );
    } catch (erreur) {
      if (kDebugMode) debugPrint('[ws notifications] echec : $erreur');
      _canal = null;
      _surCoupure();
    }
  }

  void _surTrame(dynamic brut) {
    try {
      final decode = jsonDecode(brut as String);
      if (decode is Map<String, dynamic> && !_evenements.isClosed) {
        _evenements.add(decode);
      }
    } catch (_) {
      // Trame illisible : on l'ignore plutot que de tuer le canal.
    }
  }

  void _surCoupure() {
    final code = _canal?.closeCode;

    _abonnement?.cancel();
    _abonnement = null;
    _canal = null;

    if (_fermetureVoulue) return;

    // 4403 : compte suspendu. 4401 au-dela de deux essais : le jeton ne
    // sera pas accepte. Dans les deux cas, insister ne sert a rien.
    if (code == 4403 || (code == 4401 && _tentatives >= 2)) {
      _refusDefinitif = true;
      return;
    }

    _reconnexion?.cancel();
    _tentatives++;
    final secondes = (2 << (_tentatives - 1)).clamp(2, 60);
    _reconnexion = Timer(Duration(seconds: secondes), () {
      if (!_fermetureVoulue) connecter();
    });
  }

  /// Demande au serveur le compteur a jour.
  void demanderCompteur() => _envoyer({'type': 'compteur'});

  /// Marque comme lues, par le canal. On prefere le REST pour cela, mais
  /// la trame existe et sert quand le reseau HTTP vient d'echouer.
  void marquerLues({List<int>? identifiants}) => _envoyer({
        'type': 'lecture',
        if (identifiants != null && identifiants.isNotEmpty)
          'identifiants': identifiants,
      });

  void _envoyer(Map<String, dynamic> trame) {
    final canal = _canal;
    if (canal == null) return;
    try {
      canal.sink.add(jsonEncode(trame));
    } catch (_) {
      _surCoupure();
    }
  }

  Future<void> fermer() async {
    _fermetureVoulue = true;
    _reconnexion?.cancel();
    await _abonnement?.cancel();
    await _canal?.sink.close();
    _canal = null;
    await _evenements.close();
  }
}
