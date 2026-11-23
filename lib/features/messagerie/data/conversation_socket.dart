import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/token_store.dart';

/// Evenement recu du serveur sur le canal d'une conversation.
@immutable
class EvenementSocket {
  const EvenementSocket({required this.type, required this.donnees});

  final String type;
  final Map<String, dynamic> donnees;

  bool get estNouveauMessage => type == 'message.nouveau';
  bool get estLecture => type == 'messages.lus';
  bool get estSaisie => type == 'saisie';
  bool get estErreur => type == 'erreur';
  bool get estConnexion => type == 'connexion.ok';
}

/// Codes de fermeture renvoyes par le consumer du module 7.
///
/// Ils decident s'il vaut la peine de se reconnecter : un jeton expire se
/// rejoue, mais une conversation dont on n'est pas participant ne
/// s'ouvrira jamais, et reessayer indefiniment ne ferait que chauffer le
/// telephone.
class CodesFermeture {
  const CodesFermeture._();

  static const nonAuthentifie = 4401;
  static const interdit = 4403;
  static const introuvable = 4404;
}

/// Etat du canal, pour l'afficher honnetement a l'utilisateur.
enum EtatSocket { ferme, connexion, ouvert, erreur }

/// Canal WebSocket d'une conversation.
///
/// Le jeton passe en `?token=` et non dans un en-tete : `web_socket_channel`
/// ne permet pas d'ajouter d'en-tetes sur toutes les plateformes, et le
/// serveur accepte les trois formes (en-tete, sous-protocole, parametre).
///
/// Reconnexion : l'intervalle double a chaque echec, de 2 a 30 secondes.
/// Reessayer toutes les secondes sur un reseau coupe viderait la batterie
/// sans rien gagner ; abandonner apres un echec laisserait la personne
/// devant un chat mort apres un simple passage sous un tunnel.
class ConversationSocket {
  ConversationSocket({
    required this.conversationId,
    required TokenStore jetons,
  }) : _jetons = jetons;

  final int conversationId;
  final TokenStore _jetons;

  WebSocketChannel? _canal;
  StreamSubscription<dynamic>? _abonnement;
  Timer? _reconnexion;

  final _evenements = StreamController<EvenementSocket>.broadcast();
  final _etats = StreamController<EtatSocket>.broadcast();

  int _tentatives = 0;
  bool _fermetureVoulue = false;

  /// Vrai quand le serveur a refuse l'acces pour de bon : on arrete.
  bool _refusDefinitif = false;
  bool get refusDefinitif => _refusDefinitif;

  Stream<EvenementSocket> get evenements => _evenements.stream;
  Stream<EtatSocket> get etats => _etats.stream;

  EtatSocket _etat = EtatSocket.ferme;
  EtatSocket get etat => _etat;

  void _changerEtat(EtatSocket nouvel) {
    _etat = nouvel;
    if (!_etats.isClosed) _etats.add(nouvel);
  }

  // --------------------------------------------------------- connexion
  Future<void> connecter() async {
    if (_canal != null || _refusDefinitif) return;
    _fermetureVoulue = false;

    final jeton = _jetons.acces;
    if (jeton == null || jeton.isEmpty) {
      _changerEtat(EtatSocket.erreur);
      return;
    }

    _changerEtat(EtatSocket.connexion);
    final adresse = Uri.parse(
      '${AppConfig.wsUrl}/ws/conversations/$conversationId/?token=$jeton',
    );

    try {
      final canal = WebSocketChannel.connect(adresse);
      _canal = canal;

      // `ready` leve si la poignee de main echoue : sans ce `await`, une
      // connexion refusee passerait pour un succes jusqu'au premier
      // envoi.
      await canal.ready;

      _tentatives = 0;
      _changerEtat(EtatSocket.ouvert);

      _abonnement = canal.stream.listen(
        _surTrame,
        onError: (Object erreur) => _surCoupure(erreur),
        onDone: () => _surCoupure(null),
        cancelOnError: true,
      );
    } catch (erreur) {
      _canal = null;
      _surCoupure(erreur);
    }
  }

  void _surTrame(dynamic brut) {
    try {
      final decode = jsonDecode(brut as String);
      if (decode is! Map<String, dynamic>) return;
      final type = decode['type'] as String? ?? '';
      if (type.isEmpty) return;
      if (!_evenements.isClosed) {
        _evenements.add(EvenementSocket(type: type, donnees: decode));
      }
    } catch (_) {
      // Une trame illisible ne doit pas tuer le canal : on l'ignore.
      if (kDebugMode) debugPrint('[ws] trame illisible ignoree');
    }
  }

  void _surCoupure(Object? erreur) {
    // Le code se lit AVANT de lacher le canal, sinon il est perdu.
    final code = _canal?.closeCode;

    _abonnement?.cancel();
    _abonnement = null;
    _canal = null;

    if (_fermetureVoulue) {
      _changerEtat(EtatSocket.ferme);
      return;
    }

    if (code == CodesFermeture.interdit ||
        code == CodesFermeture.introuvable) {
      // Acces refuse ou conversation disparue : rien a retenter.
      _refusDefinitif = true;
      _changerEtat(EtatSocket.erreur);
      return;
    }

    // Jeton refuse : on laisse deux chances, le temps qu'un appel REST
    // rafraichisse le jeton de son cote. Au-dela, insister est inutile.
    if (code == CodesFermeture.nonAuthentifie && _tentatives >= 2) {
      _refusDefinitif = true;
      _changerEtat(EtatSocket.erreur);
      return;
    }

    _changerEtat(EtatSocket.erreur);
    _planifierReconnexion();
  }

  void _planifierReconnexion() {
    _reconnexion?.cancel();
    _tentatives++;

    // 2, 4, 8, 16, 30, 30... secondes.
    final secondes = (2 << (_tentatives - 1)).clamp(2, 30);
    _reconnexion = Timer(Duration(seconds: secondes), () {
      if (!_fermetureVoulue) connecter();
    });
  }

  // ------------------------------------------------------------- envois
  void envoyerMessage(String contenu) =>
      _envoyer({'type': 'message', 'contenu': contenu});

  void signalerLecture() => _envoyer({'type': 'lecture'});

  void signalerSaisie({required bool enCours}) =>
      _envoyer({'type': 'saisie', 'en_cours': enCours});

  void _envoyer(Map<String, dynamic> trame) {
    final canal = _canal;
    if (canal == null || _etat != EtatSocket.ouvert) return;
    try {
      canal.sink.add(jsonEncode(trame));
    } catch (_) {
      _surCoupure(null);
    }
  }

  // ---------------------------------------------------------- fermeture
  Future<void> fermer() async {
    _fermetureVoulue = true;
    _reconnexion?.cancel();
    await _abonnement?.cancel();
    await _canal?.sink.close();
    _canal = null;
    _changerEtat(EtatSocket.ferme);
    await _evenements.close();
    await _etats.close();
  }
}
