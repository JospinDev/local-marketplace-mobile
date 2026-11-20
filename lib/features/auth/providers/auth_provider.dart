import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';
import '../domain/utilisateur.dart';

/// Phases possibles de la session.
enum PhaseAuth {
  /// On relit le trousseau et on verifie la session : ecran de demarrage.
  verification,

  /// Aucune session valide.
  deconnecte,

  /// Session active.
  connecte,
}

@immutable
class EtatAuth {
  const EtatAuth({
    this.phase = PhaseAuth.verification,
    this.utilisateur,
    this.enCours = false,
  });

  final PhaseAuth phase;
  final Utilisateur? utilisateur;

  /// Une operation reseau est en cours (connexion, inscription...).
  final bool enCours;

  bool get estConnecte => phase == PhaseAuth.connecte && utilisateur != null;

  EtatAuth copyWith({
    PhaseAuth? phase,
    Utilisateur? utilisateur,
    bool? enCours,
    bool viderUtilisateur = false,
  }) {
    return EtatAuth(
      phase: phase ?? this.phase,
      utilisateur: viderUtilisateur ? null : (utilisateur ?? this.utilisateur),
      enCours: enCours ?? this.enCours,
    );
  }
}

/// Source de verite de la session.
///
/// Tous les ecrans d'authentification passent par lui, et le routeur ecoute
/// sa phase pour rediriger. C'est ce qui evite d'eparpiller des
/// `Navigator.pushReplacement` dans dix fichiers.
class AuthNotifier extends StateNotifier<EtatAuth> {
  AuthNotifier({
    required AuthRepository depot,
    required TokenStore jetons,
  })  : _depot = depot,
        _jetons = jetons,
        super(const EtatAuth());

  final AuthRepository _depot;
  final TokenStore _jetons;

  /// Ouvre la session — le SEUL chemin vers `PhaseAuth.connecte`.
  ///
  /// L'invariant est verifie ici : une session sans jeton en coffre n'est
  /// pas une session. Sans ce garde-fou, l'application pouvait se croire
  /// connectee apres une inscription, puis recevoir 401 a chaque appel —
  /// un etat incoherent, difficile a diagnostiquer depuis l'ecran.
  void _ouvrirSession(Utilisateur utilisateur) {
    if (!_jetons.aUneSession) {
      state = const EtatAuth(phase: PhaseAuth.deconnecte);
      throw const ApiException(
        message: 'Connexion incomplete : aucun jeton recu du serveur. '
            'Reessayez de vous connecter.',
        statusCode: 0,
      );
    }
    state = EtatAuth(phase: PhaseAuth.connecte, utilisateur: utilisateur);
  }

  /// Verifie la session au demarrage.
  ///
  /// On ne se contente pas de constater la presence d'un jeton : on appelle
  /// `/me/`. Un refresh peut avoir expire, ou le compte avoir ete suspendu
  /// depuis la derniere ouverture — dans les deux cas, mieux vaut le
  /// decouvrir sur l'ecran de demarrage que devant un ecran vide.
  Future<void> demarrer() async {
    if (!_jetons.aUneSession) {
      state = const EtatAuth(phase: PhaseAuth.deconnecte);
      return;
    }
    try {
      final utilisateur = await _depot.profil();
      _ouvrirSession(utilisateur);
    } on ApiException catch (erreur) {
      // Panne reseau : on garde la session plutot que de deconnecter
      // quelqu'un simplement parce qu'il est dans un ascenseur. Le
      // profil sera relu au premier appel qui reussira.
      if (erreur.estReseau) {
        state = const EtatAuth(phase: PhaseAuth.deconnecte);
      } else {
        await _jetons.vider();
        state = const EtatAuth(phase: PhaseAuth.deconnecte);
      }
    } catch (_) {
      state = const EtatAuth(phase: PhaseAuth.deconnecte);
    }
  }

  Future<void> connecter({
    required String username,
    required String motDePasse,
  }) async {
    state = state.copyWith(enCours: true);
    try {
      final utilisateur = await _depot.seConnecter(
        username: username,
        motDePasse: motDePasse,
      );
      _ouvrirSession(utilisateur);
    } finally {
      // `finally` et non `catch` : l'erreur remonte a l'ecran, qui sait
      // l'afficher champ par champ, mais le voyant de chargement doit
      // s'eteindre dans tous les cas.
      if (mounted && state.phase != PhaseAuth.connecte) {
        state = state.copyWith(enCours: false);
      }
    }
  }

  Future<ResultatInscription> inscrire({
    required String username,
    required String motDePasse,
    required String confirmation,
    String? email,
    String? nomComplet,
    String? telephone,
    String? localisation,
  }) async {
    state = state.copyWith(enCours: true);
    try {
      final resultat = await _depot.sInscrire(
        username: username,
        motDePasse: motDePasse,
        confirmation: confirmation,
        email: email,
        nomComplet: nomComplet,
        telephone: telephone,
        localisation: localisation,
      );

      // Sans email a verifier, le compte est utilisable tout de suite :
      // on enchaine sur une vraie connexion avec les memes identifiants,
      // pour obtenir de VRAIS jetons.
      //
      // Le code precedent se contentait de l'objet `utilisateur` renvoye
      // par l'inscription et declarait la session ouverte — sans aucun
      // jeton en coffre. L'application paraissait connectee, puis chaque
      // appel authentifie repondait 401.
      if (!resultat.verificationRequise) {
        await connecter(username: username, motDePasse: motDePasse);
      }
      return resultat;
    } finally {
      if (mounted && state.phase != PhaseAuth.connecte) {
        state = state.copyWith(enCours: false);
      }
    }
  }

  Future<void> verifierEmail({
    required String username,
    required String code,
  }) async {
    state = state.copyWith(enCours: true);
    try {
      final utilisateur = await _depot.verifierEmail(
        username: username,
        code: code,
      );
      _ouvrirSession(utilisateur);
    } finally {
      if (mounted && state.phase != PhaseAuth.connecte) {
        state = state.copyWith(enCours: false);
      }
    }
  }

  Future<void> deconnecter() async {
    await _depot.seDeconnecter();
    state = const EtatAuth(phase: PhaseAuth.deconnecte);
  }

  /// Relit le profil (apres une modification, ou une suspension).
  Future<void> rafraichirProfil() async {
    if (!state.estConnecte) return;
    try {
      final utilisateur = await _depot.profil();
      state = state.copyWith(utilisateur: utilisateur);
    } catch (_) {
      // Silencieux : le profil affiche reste celui qu'on avait.
    }
  }

  void appliquerProfil(Utilisateur utilisateur) {
    state = state.copyWith(utilisateur: utilisateur);
  }

  /// Appele par le client HTTP quand le rafraichissement a definitivement
  /// echoue : la session est perdue, on renvoie vers la connexion.
  void sessionPerdue() {
    if (state.phase == PhaseAuth.deconnecte) return;
    state = const EtatAuth(phase: PhaseAuth.deconnecte);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, EtatAuth>((ref) {
  final notifier = AuthNotifier(
    depot: ref.watch(authRepositoryProvider),
    jetons: ref.watch(tokenStoreProvider),
  );

  // Le client HTTP previent la session quand les jetons sont perdus.
  ref.watch(apiClientProvider).surSessionPerdue = notifier.sessionPerdue;

  return notifier;
});

/// Raccourci pratique : l'utilisateur connecte, ou `null`.
final utilisateurProvider = Provider<Utilisateur?>(
  (ref) => ref.watch(authProvider).utilisateur,
);
