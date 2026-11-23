import '../../../core/network/api_client.dart';
import '../../catalogue/domain/produit.dart';
import '../domain/vendeur_public.dart';

/// Vitrines publiques des vendeurs (module 5).
///
/// Ces routes sont sous `/public/` et ne demandent aucun compte : un
/// visiteur doit pouvoir parcourir une boutique avant de s'inscrire. Le
/// champ `est_suivi` n'a de sens que pour quelqu'un de connecte, et le
/// serveur le met alors a jour tout seul.
class VendeursRepository {
  VendeursRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<VendeurPublic> vendeur(int id) async {
    final reponse =
        await _api.get('/public/sellers/$id/') as Map<String, dynamic>;
    return VendeurPublic.depuisJson(reponse);
  }

  /// Annonces visibles de ce vendeur, les plus recentes d'abord.
  Future<PageResultats<Produit>> produits(int id, {int page = 1}) async {
    final reponse = await _api.get(
      '/public/sellers/$id/products/',
      parametres: {'page': page},
    );
    return PageResultats.depuisJson(reponse, Produit.depuisJson);
  }

  Future<PageResultats<VendeurPublic>> rechercher({
    int page = 1,
    String? recherche,
    String? localisation,
  }) async {
    final reponse = await _api.get(
      '/public/sellers/',
      parametres: {
        'page': page,
        'search': ?recherche,
        'localisation': ?localisation,
      },
    );
    return PageResultats.depuisJson(reponse, VendeurPublic.depuisJson);
  }
}
