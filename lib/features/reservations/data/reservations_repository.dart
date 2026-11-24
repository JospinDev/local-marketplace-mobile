import '../../../core/network/api_client.dart';
import '../../catalogue/domain/produit.dart';
import '../domain/reservation.dart';

/// Acces aux reservations (module 8, etape 7 du guide).
///
/// Toutes les actions renvoient la meme enveloppe
/// `{success, message, reservation}` : le `message` est redige cote serveur
/// et affichable tel quel. On le remonte donc a l'appelant plutot que
/// d'en reecrire un moins precis dans l'application — c'est le serveur qui
/// sait, par exemple, combien d'unites une vente partielle a liberees.
class ResultatReservation {
  const ResultatReservation({required this.reservation, required this.message});

  final Reservation reservation;
  final String message;
}

class ReservationsRepository {
  ReservationsRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  // ------------------------------------------------------------- lectures
  Future<PageResultats<Reservation>> mesDemandes({
    int page = 1,
    String? statut,
  }) async {
    final reponse = await _api.get(
      '/reservations/my-requests/',
      parametres: {'page': page, 'statut': ?statut},
    );
    return PageResultats.depuisJson(reponse, Reservation.depuisJson);
  }

  Future<PageResultats<Reservation>> demandesRecues({
    int page = 1,
    String? statut,
  }) async {
    final reponse = await _api.get(
      '/reservations/my-sales/',
      parametres: {'page': page, 'statut': ?statut},
    );
    return PageResultats.depuisJson(reponse, Reservation.depuisJson);
  }

  Future<Reservation> reservation(int id) async {
    final reponse =
        await _api.get('/reservations/$id/') as Map<String, dynamic>;
    return Reservation.depuisJson(reponse);
  }

  Future<ResumeReservations> resume() async {
    final reponse = await _api.get('/reservations/summary/');
    if (reponse is Map<String, dynamic>) {
      return ResumeReservations.depuisJson(reponse);
    }
    return const ResumeReservations();
  }

  // -------------------------------------------------------------- actions
  /// Demande une quantite. Le stock n'est PAS immobilise ici.
  Future<ResultatReservation> demander({
    required int produitId,
    required int quantite,
    String? message,
  }) =>
      _action(
        '/reservations/',
        corps: {
          'produit': produitId,
          'quantite_demandee': quantite,
          if (message?.trim().isNotEmpty ?? false) 'message': message!.trim(),
        },
      );

  /// Accepte la demande. Sans `quantite`, toute la quantite demandee est
  /// confirmee ; avec, l'acceptation est partielle.
  ///
  /// C'est ici que le serveur verrouille la ligne de stock : un `400`
  /// « Stock insuffisant » signifie qu'une autre reservation est passee
  /// entre-temps, et son message donne le disponible exact.
  Future<ResultatReservation> accepter(int id, {int? quantite}) => _action(
        '/reservations/$id/accept/',
        corps: {'quantite': ?quantite},
      );

  Future<ResultatReservation> refuser(int id, {String? motif}) => _action(
        '/reservations/$id/reject/',
        corps: {if (motif?.trim().isNotEmpty ?? false) 'motif': motif!.trim()},
      );

  Future<ResultatReservation> annuler(int id, {String? motif}) => _action(
        '/reservations/$id/cancel/',
        corps: {if (motif?.trim().isNotEmpty ?? false) 'motif': motif!.trim()},
      );

  Future<ResultatReservation> changerQuantite(int id, int quantite) => _action(
        '/reservations/$id/quantity/',
        corps: {'quantite': quantite},
      );

  Future<ResultatReservation> _action(
    String chemin, {
    Map<String, dynamic> corps = const {},
  }) async {
    final reponse = await _api.post(chemin, corps: corps);
    final map = reponse as Map<String, dynamic>;
    final brut = map['reservation'];

    return ResultatReservation(
      reservation: Reservation.depuisJson(
        brut is Map<String, dynamic> ? brut : map,
      ),
      message: map['message'] as String? ?? '',
    );
  }
}
