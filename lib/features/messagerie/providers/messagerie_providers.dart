import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/conversation_socket.dart';
import '../data/messagerie_repository.dart';
import '../domain/conversation.dart';

final messagerieRepositoryProvider = Provider<MessagerieRepository>((ref) {
  return MessagerieRepository(api: ref.watch(apiClientProvider));
});

// ===========================================================================
// Liste des conversations
// ===========================================================================

@immutable
class EtatConversations {
  const EtatConversations({
    this.conversations = const [],
    this.chargement = true,
    this.erreur,
  });

  final List<Conversation> conversations;
  final bool chargement;
  final Object? erreur;

  bool get estVide =>
      conversations.isEmpty && !chargement && erreur == null;

  int get totalNonLus =>
      conversations.fold(0, (somme, c) => somme + c.messagesNonLus);

  EtatConversations copyWith({
    List<Conversation>? conversations,
    bool? chargement,
    Object? erreur,
    bool viderErreur = false,
  }) {
    return EtatConversations(
      conversations: conversations ?? this.conversations,
      chargement: chargement ?? this.chargement,
      erreur: viderErreur ? null : (erreur ?? this.erreur),
    );
  }
}

class ConversationsNotifier extends StateNotifier<EtatConversations> {
  ConversationsNotifier(this._depot, {required bool connecte})
      : super(EtatConversations(chargement: connecte)) {
    if (connecte) charger();
  }

  final MessagerieRepository _depot;

  Future<void> charger() async {
    state = state.copyWith(chargement: true, viderErreur: true);
    try {
      final page = await _depot.conversations();
      if (!mounted) return;
      state = EtatConversations(
        conversations: page.elements,
        chargement: false,
      );
    } catch (erreur) {
      if (!mounted) return;
      state = state.copyWith(chargement: false, erreur: erreur);
    }
  }

  /// Remet a zero la pastille d'une conversation, sans recharger la liste.
  ///
  /// Appele quand on ouvre la conversation : le serveur a deja marque les
  /// messages comme lus, la liste doit le refleter immediatement au retour
  /// en arriere.
  void marquerLueLocalement(int conversationId) {
    if (!mounted) return;
    final maj = state.conversations.map((c) {
      if (c.id != conversationId || c.messagesNonLus == 0) return c;
      return c.copyWith(messagesNonLus: 0);
    }).toList(growable: false);
    state = state.copyWith(conversations: maj);
  }
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, EtatConversations>((ref) {
  final connecte = ref.watch(authProvider).estConnecte;
  return ConversationsNotifier(
    ref.watch(messagerieRepositoryProvider),
    connecte: connecte,
  );
});

/// Pastille de l'onglet Messages.
///
/// Elle se lit sur la liste deja chargee quand elle existe, sinon sur le
/// point de terminaison dedie. Pas de minuterie de rafraichissement : le
/// WebSocket du module 12 (etape 11) poussera le compteur.
final messagesNonLusProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(authProvider).estConnecte) return 0;

  final etat = ref.watch(conversationsProvider);
  if (!etat.chargement && etat.erreur == null) return etat.totalNonLus;

  return ref.watch(messagerieRepositoryProvider).nonLus();
});

// ===========================================================================
// Une conversation ouverte
// ===========================================================================

@immutable
class EtatConversation {
  const EtatConversation({
    this.conversation,
    this.messages = const [],
    this.chargement = true,
    this.envoiEnCours = false,
    this.interlocuteurSaisit = false,
    this.etatCanal = EtatSocket.ferme,
    this.erreur,
  });

  final Conversation? conversation;

  /// Du plus RECENT au plus ancien : la liste s'affiche inversee, ce qui
  /// garde le dernier message visible sans calcul de defilement.
  final List<Message> messages;

  final bool chargement;
  final bool envoiEnCours;
  final bool interlocuteurSaisit;
  final EtatSocket etatCanal;
  final Object? erreur;

  bool get peutEcrire =>
      conversation != null && !conversation!.estBloquee && !chargement;

  EtatConversation copyWith({
    Conversation? conversation,
    List<Message>? messages,
    bool? chargement,
    bool? envoiEnCours,
    bool? interlocuteurSaisit,
    EtatSocket? etatCanal,
    Object? erreur,
    bool viderErreur = false,
  }) {
    return EtatConversation(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      chargement: chargement ?? this.chargement,
      envoiEnCours: envoiEnCours ?? this.envoiEnCours,
      interlocuteurSaisit: interlocuteurSaisit ?? this.interlocuteurSaisit,
      etatCanal: etatCanal ?? this.etatCanal,
      erreur: viderErreur ? null : (erreur ?? this.erreur),
    );
  }
}

class ConversationNotifier extends StateNotifier<EtatConversation> {
  ConversationNotifier({
    required MessagerieRepository depot,
    required ConversationSocket canal,
    required int conversationId,
    required int? moiId,
  })  : _depot = depot,
        _canal = canal,
        _conversationId = conversationId,
        _moiId = moiId,
        super(const EtatConversation()) {
    _demarrer();
  }

  final MessagerieRepository _depot;
  final ConversationSocket _canal;
  final int _conversationId;
  final int? _moiId;

  StreamSubscription<EvenementSocket>? _ecouteEvenements;
  StreamSubscription<EtatSocket>? _ecouteEtats;
  Timer? _finDeSaisie;

  Future<void> _demarrer() async {
    _ecouteEvenements = _canal.evenements.listen(_surEvenement);
    _ecouteEtats = _canal.etats.listen((etat) {
      if (mounted) state = state.copyWith(etatCanal: etat);
    });

    await charger();

    // Le canal se connecte APRES le chargement REST : si on inversait,
    // un message pousse pendant le chargement serait ecrase par la page
    // d'historique qui arrive ensuite.
    await _canal.connecter();
  }

  Future<void> charger() async {
    state = state.copyWith(chargement: true, viderErreur: true);
    try {
      final conversation = await _depot.conversation(_conversationId);
      final page = await _depot.messages(_conversationId);
      if (!mounted) return;
      state = EtatConversation(
        conversation: conversation,
        messages: page.elements,
        chargement: false,
        etatCanal: _canal.etat,
      );
      await _marquerLus();
    } catch (erreur) {
      if (!mounted) return;
      state = state.copyWith(chargement: false, erreur: erreur);
    }
  }

  Future<void> _marquerLus() async {
    try {
      await _depot.marquerLus(_conversationId);
    } catch (_) {
      // Un accuse de lecture perdu n'est pas une erreur a montrer : le
      // serveur le recalculera a la prochaine ouverture.
    }
  }

  // ----------------------------------------------------------- evenements
  void _surEvenement(EvenementSocket evenement) {
    if (!mounted) return;

    if (evenement.estNouveauMessage) {
      final brut = evenement.donnees['message'];
      if (brut is! Map<String, dynamic>) return;
      _integrer(Message.depuisJson(brut, moiId: _moiId));
      return;
    }

    if (evenement.estLecture) {
      // `lu_par` evite de prendre MA propre lecture pour celle de l'autre :
      // le serveur diffuse l'evenement aux deux participants.
      final luPar = (evenement.donnees['lu_par'] as num?)?.toInt();
      if (luPar != null && luPar == _moiId) return;

      // L'autre a lu : toutes MES bulles passent a « lu ».
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.estDeMoi ? m.copyWith(estLu: true) : m)
            .toList(growable: false),
      );
      return;
    }

    if (evenement.estSaisie) {
      final auteur = (evenement.donnees['utilisateur'] as num?)?.toInt();
      // Le serveur peut renvoyer notre propre frappe en echo : on ignore.
      if (auteur != null && auteur == _moiId) return;
      final enCours = evenement.donnees['en_cours'] as bool? ?? true;
      state = state.copyWith(interlocuteurSaisit: enCours);

      // Garde-fou : si la trame « fin de saisie » se perd, l'indicateur
      // resterait allume pour toujours.
      _finDeSaisie?.cancel();
      if (enCours) {
        _finDeSaisie = Timer(const Duration(seconds: 6), () {
          if (mounted) state = state.copyWith(interlocuteurSaisit: false);
        });
      }
    }
  }

  /// Insere un message venu du serveur, en remplacant la bulle provisoire
  /// correspondante s'il y en a une.
  void _integrer(Message message) {
    final liste = List<Message>.from(state.messages);

    // Deja present (double poussee, ou retour REST + WebSocket) : on sort.
    if (liste.any((m) => m.id == message.id && m.id > 0)) return;

    if (message.estDeMoi) {
      final indice = liste.indexWhere(
        (m) => m.id < 0 && m.contenu.trim() == message.contenu.trim(),
      );
      if (indice >= 0) {
        liste[indice] = message;
        state = state.copyWith(messages: liste, interlocuteurSaisit: false);
        return;
      }
    }

    liste.insert(0, message);
    state = state.copyWith(messages: liste, interlocuteurSaisit: false);

    if (!message.estDeMoi) _marquerLus();
  }

  // ---------------------------------------------------------------- envoi
  Future<void> envoyer(String contenu) async {
    final texte = contenu.trim();
    if (texte.isEmpty || _moiId == null) return;

    final provisoire = Message.provisoire(
      conversationId: _conversationId,
      expediteurId: _moiId,
      contenu: texte,
    );
    state = state.copyWith(
      messages: [provisoire, ...state.messages],
      envoiEnCours: true,
    );
    signalerSaisie(enCours: false);

    try {
      final reel = await _depot.envoyer(_conversationId, texte);
      if (!mounted) return;
      state = state.copyWith(envoiEnCours: false);
      _remplacer(provisoire.id, reel);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        envoiEnCours: false,
        messages: state.messages
            .map((m) => m.id == provisoire.id
                ? m.copyWith(enCoursEnvoi: false, echecEnvoi: true)
                : m)
            .toList(growable: false),
      );
    }
  }

  void _remplacer(int idProvisoire, Message reel) {
    final liste = List<Message>.from(state.messages);
    final indice = liste.indexWhere((m) => m.id == idProvisoire);

    // Le WebSocket a pu arriver avant la reponse REST et avoir deja fait
    // le remplacement : dans ce cas il n'y a plus rien a faire.
    if (indice < 0) return;
    if (liste.any((m) => m.id == reel.id && m.id > 0)) {
      liste.removeAt(indice);
    } else {
      liste[indice] = reel;
    }
    state = state.copyWith(messages: liste);
  }

  /// Reessaie un message dont l'envoi a echoue.
  Future<void> reessayer(Message echoue) async {
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != echoue.id).toList(),
    );
    await envoyer(echoue.contenu);
  }

  void signalerSaisie({required bool enCours}) =>
      _canal.signalerSaisie(enCours: enCours);

  // -------------------------------------------------------------- blocage
  Future<void> basculerBlocage() async {
    final conversation = state.conversation;
    if (conversation == null) return;

    if (conversation.estBloquee && !conversation.bloqueeParMoi) {
      // Bloque par l'autre : rien a debloquer de notre cote.
      return;
    }

    if (conversation.estBloquee) {
      await _depot.debloquer(_conversationId);
    } else {
      await _depot.bloquer(_conversationId);
    }
    await charger();
  }

  Future<void> signaler({required String motif, String? description}) =>
      _depot.signaler(
        _conversationId,
        motif: motif,
        description: description,
      );

  @override
  void dispose() {
    _finDeSaisie?.cancel();
    _ecouteEvenements?.cancel();
    _ecouteEtats?.cancel();
    _canal.fermer();
    super.dispose();
  }
}

/// Une conversation ouverte, indexee par identifiant.
///
/// `autoDispose` est essentiel : en quittant l'ecran, le WebSocket doit se
/// fermer. Sans cela, chaque conversation visitee laisserait un canal
/// ouvert derriere elle.
final conversationProvider = StateNotifierProvider.autoDispose
    .family<ConversationNotifier, EtatConversation, int>((ref, id) {
  final notifier = ConversationNotifier(
    depot: ref.watch(messagerieRepositoryProvider),
    canal: ConversationSocket(
      conversationId: id,
      jetons: ref.watch(tokenStoreProvider),
    ),
    conversationId: id,
    moiId: ref.watch(utilisateurProvider)?.id,
  );

  // Au retour sur la liste, la pastille doit avoir disparu.
  ref.onDispose(() {
    ref.read(conversationsProvider.notifier).marquerLueLocalement(id);
  });

  return notifier;
});

/// Motifs de signalement, tels que le serveur les accepte (verifies contre
/// `MotifSignalement` du module 7).
const motifsSignalement = <String, String>{
  'ARNAQUE': 'Tentative d\'arnaque',
  'HARCELEMENT': 'Harcelement',
  'SPAM': 'Spam ou publicite',
  'PRODUIT_INTERDIT': 'Produit interdit',
  'AUTRE': 'Autre raison',
};
