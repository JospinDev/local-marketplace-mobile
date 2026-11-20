import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../domain/utilisateur.dart';

/// Resultat d'une inscription.
///
/// Le serveur decide s'il faut verifier l'email ou non ; l'application ne
/// doit PAS deduire cette information de la presence du champ email dans le
/// formulaire. Ce drapeau vient donc directement de la reponse.
class ResultatInscription {
  const ResultatInscription({
    required this.verificationRequise,
    required this.message,
    this.utilisateur,
  });

  final bool verificationRequise;
  final String message;
  final Utilisateur? utilisateur;
}

/// Acces au module 1 du backend : inscription, connexion, jetons, mot de
/// passe, et profil `/me/`.
///
/// Aucun ecran n'appelle l'API directement : tout passe par ce depot, ce
/// qui laisse un seul endroit a corriger si une route change.
class AuthRepository {
  AuthRepository({required ApiClient api, required TokenStore jetons})
      : _api = api,
        _jetons = jetons;

  final ApiClient _api;
  final TokenStore _jetons;

  // ----------------------------------------------------------- inscription
  Future<ResultatInscription> sInscrire({
    required String username,
    required String motDePasse,
    required String confirmation,
    String? email,
    String? nomComplet,
    String? telephone,
    String? localisation,
  }) async {
    final corps = <String, dynamic>{
      'username': username.trim(),
      'password': motDePasse,
      'password_confirmation': confirmation,
    };
    void ajouter(String cle, String? valeur) {
      if (valeur != null && valeur.trim().isNotEmpty) {
        corps[cle] = valeur.trim();
      }
    }

    ajouter('email', email);
    ajouter('nom_complet', nomComplet);
    ajouter('telephone', telephone);
    ajouter('localisation', localisation);

    final reponse = await _api.post(
      '/auth/register/',
      corps: corps,
      sansJeton: true,
    ) as Map<String, dynamic>;

    final verification = reponse['verification_email_requise'] as bool? ?? false;

    // Sans email a verifier, le serveur renvoie deja les jetons : on
    // enchaine directement sur l'accueil sans redemander une connexion.
    if (!verification) {
      await _memoriserJetons(reponse);
    }

    return ResultatInscription(
      verificationRequise: verification,
      message: reponse['message'] as String? ?? 'Compte cree.',
      utilisateur: _lireUtilisateur(reponse),
    );
  }

  // ------------------------------------------------------------- connexion
  Future<Utilisateur> seConnecter({
    required String username,
    required String motDePasse,
  }) async {
    final reponse = await _api.post(
      '/auth/login/',
      corps: {'username': username.trim(), 'password': motDePasse},
      sansJeton: true,
    ) as Map<String, dynamic>;

    await _memoriserJetons(reponse);
    final utilisateur = _lireUtilisateur(reponse);
    return utilisateur ?? await profil();
  }

  Future<void> seDeconnecter() async {
    final refresh = _jetons.rafraichissement;
    if (refresh != null && refresh.isNotEmpty) {
      try {
        // Met le refresh en liste noire cote serveur. Un echec ici ne doit
        // pas empecher la deconnexion locale : si le reseau est coupe,
        // l'utilisateur doit quand meme pouvoir fermer sa session.
        await _api.post('/auth/logout/', corps: {'refresh': refresh});
      } catch (_) {}
    }
    await _jetons.vider();
  }

  // ------------------------------------------------------ verification email
  Future<Utilisateur> verifierEmail({
    required String username,
    required String code,
  }) async {
    final reponse = await _api.post(
      '/auth/email/verify/',
      corps: {'username': username.trim(), 'code': code.trim()},
      sansJeton: true,
    ) as Map<String, dynamic>;

    await _memoriserJetons(reponse);
    final utilisateur = _lireUtilisateur(reponse);
    return utilisateur ?? await profil();
  }

  Future<String> renvoyerCode({
    required String username,
    String? email,
  }) async {
    final corps = <String, dynamic>{'username': username.trim()};
    if (email != null && email.trim().isNotEmpty) corps['email'] = email.trim();

    final reponse = await _api.post(
      '/auth/email/resend/',
      corps: corps,
      sansJeton: true,
    );
    if (reponse is Map && reponse['message'] is String) {
      return reponse['message'] as String;
    }
    return 'Un nouveau code vous a ete envoye.';
  }

  // ----------------------------------------------------------- mot de passe
  Future<String> changerMotDePasse({
    required String ancien,
    required String nouveau,
    required String confirmation,
  }) async {
    final reponse = await _api.post(
      '/auth/password/change/',
      corps: {
        'ancien_password': ancien,
        'nouveau_password': nouveau,
        'nouveau_password_confirmation': confirmation,
      },
    );
    return (reponse is Map ? reponse['message'] as String? : null) ??
        'Mot de passe modifie.';
  }

  Future<String> demanderReinitialisation(String username) async {
    final reponse = await _api.post(
      '/auth/password/reset/',
      corps: {'username': username.trim()},
      sansJeton: true,
    );
    return (reponse is Map ? reponse['message'] as String? : null) ??
        'Un code vous a ete envoye par email.';
  }

  Future<String> confirmerReinitialisation({
    required String username,
    required String code,
    required String nouveau,
    required String confirmation,
  }) async {
    final reponse = await _api.post(
      '/auth/password/reset/confirm/',
      corps: {
        'username': username.trim(),
        'code': code.trim(),
        'nouveau_password': nouveau,
        'nouveau_password_confirmation': confirmation,
      },
      sansJeton: true,
    );
    return (reponse is Map ? reponse['message'] as String? : null) ??
        'Mot de passe reinitialise.';
  }

  // ---------------------------------------------------------------- profil
  Future<Utilisateur> profil() async {
    final reponse = await _api.get('/me/') as Map<String, dynamic>;
    return Utilisateur.depuisJson(reponse);
  }

  Future<Utilisateur> majProfil(Map<String, dynamic> champs) async {
    final reponse = await _api.patch('/me/', corps: champs)
        as Map<String, dynamic>;
    return Utilisateur.depuisJson(reponse);
  }

  // --------------------------------------------------------------- interne
  Future<void> _memoriserJetons(Map<String, dynamic> reponse) async {
    final acces = reponse['access'] as String?;
    final refresh = reponse['refresh'] as String?;
    if (acces != null && refresh != null) {
      await _jetons.enregistrer(acces: acces, rafraichissement: refresh);
    }
  }

  Utilisateur? _lireUtilisateur(Map<String, dynamic> reponse) {
    final brut = reponse['utilisateur'];
    if (brut is Map<String, dynamic>) return Utilisateur.depuisJson(brut);
    return null;
  }
}
