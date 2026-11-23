import '../../../core/network/api_client.dart';
import '../../catalogue/domain/produit.dart';
import '../domain/conversation.dart';

/// Acces a la messagerie (etape 6 du guide).
///
/// Choix d'architecture important : **on ENVOIE en REST et on RECOIT par
/// WebSocket**. Les deux chemins passent par le meme service cote
/// serveur, donc un message envoye en REST arrive bien sur les sockets
/// ouverts. L'envoi REST est simplement plus facile a reessayer qu'une
/// trame socket perdue — et sur mobile, la connexion se coupe souvent.
class MessagerieRepository {
  MessagerieRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  // ------------------------------------------------------- conversations
  Future<PageResultats<Conversation>> conversations({int page = 1}) async {
    final reponse = await _api.get(
      '/conversations/',
      parametres: {'page': page},
    );
    return PageResultats.depuisJson(reponse, Conversation.depuisJson);
  }

  Future<Conversation> conversation(int id) async {
    final reponse =
        await _api.get('/conversations/$id/') as Map<String, dynamic>;
    return Conversation.depuisJson(reponse);
  }

  /// Cree la conversation ou retrouve celle qui existe.
  ///
  /// Idempotent cote serveur : meme trio acheteur / vendeur / produit, on
  /// recoit 200 et la conversation existante au lieu d'un doublon. Les
  /// deux cas se traitent donc pareil.
  ///
  /// `interlocuteur` n'est necessaire QUE lorsque le vendeur ecrit le
  /// premier sur sa propre annonce : il doit alors designer son client,
  /// puisque le serveur ne peut pas le deviner.
  Future<Conversation> ouvrir({
    int? produitId,
    int? interlocuteurId,
    String? message,
  }) async {
    final corps = <String, dynamic>{};
    if (produitId != null) corps['produit'] = produitId;
    if (interlocuteurId != null) corps['interlocuteur'] = interlocuteurId;
    if (message?.trim().isNotEmpty ?? false) {
      corps['message'] = message!.trim();
    }

    final reponse =
        await _api.post('/conversations/', corps: corps) as Map<String, dynamic>;

    // La reponse peut etre la conversation, ou une enveloppe.
    final imbriquee = reponse['conversation'];
    if (imbriquee is Map<String, dynamic>) {
      return Conversation.depuisJson(imbriquee);
    }
    return Conversation.depuisJson(reponse);
  }

  // ------------------------------------------------------------ messages
  Future<PageResultats<Message>> messages(int conversationId, {
    int page = 1,
  }) async {
    final reponse = await _api.get(
      '/conversations/$conversationId/messages/',
      parametres: {'page': page},
    );
    return PageResultats.depuisJson(reponse, Message.depuisJson);
  }

  Future<Message> envoyer(int conversationId, String contenu) async {
    final reponse = await _api.post(
      '/conversations/$conversationId/messages/',
      corps: {'contenu': contenu.trim()},
    ) as Map<String, dynamic>;

    final imbrique = reponse['message'];
    if (imbrique is Map<String, dynamic>) return Message.depuisJson(imbrique);
    return Message.depuisJson(reponse);
  }

  Future<void> marquerLus(int conversationId) =>
      _api.post('/conversations/$conversationId/read/');

  // ------------------------------------------------------------- blocage
  Future<void> bloquer(int conversationId) =>
      _api.post('/conversations/$conversationId/block/');

  Future<void> debloquer(int conversationId) =>
      _api.delete('/conversations/$conversationId/block/');

  Future<void> signaler(
    int conversationId, {
    required String motif,
    String? description,
  }) =>
      _api.post(
        '/conversations/$conversationId/report/',
        corps: {
          'motif': motif,
          if (description?.trim().isNotEmpty ?? false)
            'description': description!.trim(),
        },
      );

  // --------------------------------------------------------------- badge
  /// Nombre total de messages non lus, pour la pastille de l'onglet.
  ///
  /// Nom de champ verifie contre le serveur : `{"messages_non_lus": N}`.
  Future<int> nonLus() async {
    final reponse = await _api.get('/conversations/unread-count/');
    if (reponse is Map) {
      final valeur = reponse['messages_non_lus'];
      if (valeur is num) return valeur.toInt();
    }
    return 0;
  }
}
