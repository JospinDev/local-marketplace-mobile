import '../../../core/network/api_client.dart';
import '../../catalogue/domain/produit.dart';
import '../domain/notification.dart';

/// Acces aux notifications (module 12).
class NotificationsRepository {
  NotificationsRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<PageResultats<NotificationItem>> liste({
    int page = 1,
    bool? seulementNonLues,
  }) async {
    final reponse = await _api.get(
      '/notifications/',
      parametres: {
        'page': page,
        // Nom de filtre verifie contre le serveur : `non_lues=true`, et
        // non `est_lue=false`. Absent, on recoit tout.
        if (seulementNonLues == true) 'non_lues': true,
      },
    );
    return PageResultats.depuisJson(reponse, NotificationItem.depuisJson);
  }

  Future<int> nonLues() async {
    final reponse = await _api.get('/notifications/unread-count/');
    if (reponse is Map) {
      // Clef verifiee contre le serveur : `{"non_lues": N}`.
      final valeur = reponse['non_lues'];
      if (valeur is num) return valeur.toInt();
    }
    return 0;
  }

  /// Marque une notification comme lue.
  Future<void> marquerLue(int id) => _api.post('/notifications/$id/read/');

  /// Marque tout comme lu, ou seulement les identifiants donnes.
  Future<void> marquerLues({List<int>? identifiants}) => _api.post(
        '/notifications/read/',
        corps: {
          if (identifiants != null && identifiants.isNotEmpty)
            'identifiants': identifiants,
        },
      );
}
