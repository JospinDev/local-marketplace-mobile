import '../../../core/network/api_client.dart';
import '../domain/tableau_bord.dart';

/// Tableau de bord vendeur (module 10, etape 10 du guide).
///
/// Aucun identifiant n'est passe : tout part du jeton. Un vendeur ne peut
/// donc voir que ses propres chiffres, et il n'y a rien a falsifier dans
/// une requete.
class TableauBordRepository {
  TableauBordRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<VueGenerale> vueGenerale() async {
    final reponse = await _api.get('/seller-dashboard/overview/');
    return VueGenerale.depuisJson(reponse as Map<String, dynamic>);
  }

  Future<Revenus> revenus() async {
    final reponse = await _api.get('/seller-dashboard/revenue/');
    return Revenus.depuisJson(reponse as Map<String, dynamic>);
  }

  Future<Inventaire> inventaire() async {
    final reponse = await _api.get('/seller-dashboard/inventory/');
    return Inventaire.depuisJson(reponse as Map<String, dynamic>);
  }

  Future<StatistiquesReservations> reservations() async {
    final reponse = await _api.get('/seller-dashboard/reservations/');
    return StatistiquesReservations.depuisJson(
      reponse as Map<String, dynamic>,
    );
  }

  Future<Palmares> palmares({int limite = 5}) async {
    final reponse = await _api.get(
      '/seller-dashboard/top-products/',
      parametres: {'limite': limite},
    );
    return Palmares.depuisJson(reponse as Map<String, dynamic>);
  }
}
