import 'package:dio/dio.dart';

/// Erreur d'API, decodee depuis l'enveloppe unique du serveur.
///
/// Le backend renvoie TOUJOURS la meme forme :
///
/// ```json
/// { "success": false, "status_code": 400, "message": "Donnees invalides.",
///   "errors": { "quantite_demandee": ["Quantite trop elevee : 7 ..."] } }
/// ```
///
/// Un seul decodeur suffit donc pour toute l'application — c'est ce que
/// recommande le guide d'integration, et cela evite d'ecrire un traitement
/// d'erreur par ecran.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.statusCode,
    this.erreursChamps = const {},
    this.estReseau = false,
  });

  /// Message lisible, deja redige cote serveur et affichable tel quel.
  final String message;

  /// Code HTTP, ou 0 quand la requete n'a jamais atteint le serveur.
  final int statusCode;

  /// Erreurs par champ, a afficher sous les champs concernes.
  final Map<String, String> erreursChamps;

  /// Vrai quand l'echec vient du reseau et non d'une reponse du serveur :
  /// l'ecran propose alors « reessayer » plutot qu'une correction de saisie.
  final bool estReseau;

  // --------------------------------------------------------- raccourcis
  bool get estNonAuthentifie => statusCode == 401;
  bool get estInterdit => statusCode == 403;
  bool get estIntrouvable => statusCode == 404;
  bool get estQuotaDepasse => statusCode == 429;
  bool get estValidation => statusCode == 400 && erreursChamps.isNotEmpty;

  /// Erreur d'un champ precis, s'il y en a une.
  String? champ(String nom) => erreursChamps[nom];

  // --------------------------------------------------------- fabriques
  /// Traduit une erreur Dio en message utile pour la personne.
  factory ApiException.depuisDio(DioException erreur) {
    switch (erreur.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      // `transformTimeout` existe dans les versions recentes de Dio :
      // c'est un depassement pendant la (de)serialisation, que la
      // personne vit exactement comme une lenteur reseau.
      case DioExceptionType.transformTimeout:
        return const ApiException(
          message: 'Le serveur met trop de temps a repondre. '
              'Verifiez votre connexion et reessayez.',
          statusCode: 0,
          estReseau: true,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'Impossible de joindre le serveur. '
              'Verifiez votre connexion internet.',
          statusCode: 0,
          estReseau: true,
        );
      case DioExceptionType.cancel:
        return const ApiException(
          message: 'Requete annulee.',
          statusCode: 0,
          estReseau: true,
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          message: 'Connexion non securisee refusee.',
          statusCode: 0,
          estReseau: true,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return ApiException.depuisReponse(erreur.response);
    }
  }

  /// Decode l'enveloppe d'erreur du backend.
  factory ApiException.depuisReponse(Response<dynamic>? reponse) {
    final code = reponse?.statusCode ?? 0;
    final corps = reponse?.data;

    if (corps is! Map) {
      return ApiException(
        message: _messageParDefaut(code),
        statusCode: code,
        estReseau: code == 0,
      );
    }

    final message = (corps['message'] as String?)?.trim();
    final brutes = corps['errors'];

    final champs = <String, String>{};
    if (brutes is Map) {
      brutes.forEach((cle, valeur) {
        // Le serveur renvoie une LISTE de messages par champ ; on garde
        // le premier, qui est le plus precis, et on joint les autres.
        final texte = valeur is List
            ? valeur.map((e) => e.toString()).join(' ')
            : valeur.toString();
        if (texte.trim().isNotEmpty) champs[cle.toString()] = texte.trim();
      });
    }

    return ApiException(
      message: message?.isNotEmpty == true ? message! : _messageParDefaut(code),
      statusCode: code,
      erreursChamps: champs,
    );
  }

  static String _messageParDefaut(int code) {
    switch (code) {
      case 400:
        return 'Les informations envoyees sont invalides.';
      case 401:
        return 'Votre session a expire. Reconnectez-vous.';
      case 403:
        return "Vous n'avez pas le droit d'effectuer cette action.";
      case 404:
        return 'Introuvable.';
      case 405:
        return 'Action non autorisee.';
      case 429:
        return 'Trop de tentatives. Reessayez dans un instant.';
      case 500:
      case 502:
      case 503:
        return 'Le serveur rencontre un probleme. Reessayez plus tard.';
      default:
        return "Une erreur inattendue s'est produite.";
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
