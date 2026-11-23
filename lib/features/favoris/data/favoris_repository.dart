import '../../../core/network/api_client.dart';
import '../../catalogue/domain/produit.dart';
import '../domain/favori.dart';

/// Acces aux favoris et aux vendeurs suivis (etape 5 du guide).
///
/// Les deux sont strictement PRIVES : le serveur ne renvoie que ceux de
/// l'utilisateur connecte. Il n'existe aucun moyen de lire les favoris de
/// quelqu'un d'autre, et c'est volontaire.
class FavorisRepository {
  FavorisRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  // -------------------------------------------------------------- favoris
  Future<PageResultats<Favori>> mesFavoris({
    int page = 1,
    bool? prixAChange,
    bool? disponible,
    bool? retire,
  }) async {
    final reponse = await _api.get(
      '/favorites/products/',
      parametres: {
        'page': page,
        'prix_a_change': ?prixAChange,
        'disponible': ?disponible,
        'retire': ?retire,
      },
    );
    return PageResultats.depuisJson(reponse, Favori.depuisJson);
  }

  /// Ajoute aux favoris. Idempotent cote serveur : un produit deja en
  /// favori renvoie 200 au lieu de 201, sans creer de doublon. Le bouton
  /// coeur peut donc etre appuye deux fois sans degat.
  Future<bool> ajouter(int produitId) async {
    final reponse = await _api.post('/favorites/products/$produitId/');
    if (reponse is Map && reponse['cree'] is bool) {
      return reponse['cree'] as bool;
    }
    return true;
  }

  Future<void> retirer(int produitId) =>
      _api.delete('/favorites/products/$produitId/');

  // ------------------------------------------------------ vendeurs suivis
  Future<PageResultats<VendeurSuivi>> mesVendeurs({int page = 1}) async {
    final reponse = await _api.get(
      '/following/sellers/',
      parametres: {'page': page},
    );
    return PageResultats.depuisJson(reponse, VendeurSuivi.depuisJson);
  }

  Future<void> suivre(int vendeurId) =>
      _api.post('/following/sellers/$vendeurId/');

  Future<void> nePlusSuivre(int vendeurId) =>
      _api.delete('/following/sellers/$vendeurId/');

  /// Fil des annonces publiees par les vendeurs suivis.
  Future<PageResultats<Produit>> filDesVendeurs({int page = 1}) async {
    final reponse = await _api.get(
      '/following/products/',
      parametres: {'page': page},
    );
    return PageResultats.depuisJson(reponse, Produit.depuisJson);
  }
}
