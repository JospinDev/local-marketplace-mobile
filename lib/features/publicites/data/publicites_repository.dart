import '../../../core/network/api_client.dart';
import '../domain/publicite.dart';

/// Acces au bandeau publicitaire.
///
/// Route PUBLIQUE : aucun compte requis, et le serveur applique deja tous
/// les filtres (actif, fenetre de diffusion, interrupteur global). Une
/// liste vide est une reponse normale, pas une erreur.
class PublicitesRepository {
  PublicitesRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<Publicite>> bandeau() async {
    final reponse = await _api.get('/public/ads/');

    // La route n'est pas paginee : elle renvoie une liste nue.
    if (reponse is List) {
      return reponse
          .whereType<Map<String, dynamic>>()
          .map(Publicite.depuisJson)
          .toList(growable: false);
    }
    // Repli au cas ou la pagination serait activee plus tard.
    if (reponse is Map && reponse['results'] is List) {
      return (reponse['results'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Publicite.depuisJson)
          .toList(growable: false);
    }
    return const [];
  }

  /// Compteur indicatif. Un echec est sans consequence : on l'avale.
  Future<void> signalerClic(int id) async {
    try {
      await _api.post('/public/ads/$id/click/');
    } catch (_) {
      // Un compteur perdu ne vaut pas un message d'erreur a l'ecran.
    }
  }
}
