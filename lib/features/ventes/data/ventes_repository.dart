import '../../../core/network/api_client.dart';
import '../../catalogue/domain/produit.dart';
import '../../reservations/domain/reservation.dart';
import '../domain/vente.dart';

class ResultatVente {
  const ResultatVente({
    required this.vente,
    required this.message,
    this.reservation,
  });

  final Vente vente;
  final String message;

  /// Presente quand la vente vient d'une reservation : le serveur renvoie
  /// la reservation mise a jour dans la meme reponse, ce qui evite une
  /// seconde requete pour rafraichir l'autre ecran.
  final Reservation? reservation;
}

/// Acces aux ventes (module 9, etape 8 du guide).
class VentesRepository {
  VentesRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  // ------------------------------------------------------------- lectures
  Future<PageResultats<Vente>> mesVentes({int page = 1, String? statut}) async {
    final reponse = await _api.get(
      '/sales/my-sales/',
      parametres: {'page': page, 'statut': ?statut},
    );
    return PageResultats.depuisJson(reponse, Vente.depuisJson);
  }

  Future<PageResultats<Vente>> mesAchats({int page = 1, String? statut}) async {
    final reponse = await _api.get(
      '/sales/my-purchases/',
      parametres: {'page': page, 'statut': ?statut},
    );
    return PageResultats.depuisJson(reponse, Vente.depuisJson);
  }

  Future<Vente> vente(int id) async {
    final reponse = await _api.get('/sales/$id/') as Map<String, dynamic>;
    return Vente.depuisJson(reponse);
  }

  Future<Revenus> revenus() async {
    final reponse = await _api.get('/sales/summary/');
    if (reponse is Map<String, dynamic>) return Revenus.depuisJson(reponse);
    return const Revenus();
  }

  // -------------------------------------------------------------- actions
  /// Enregistre la vente depuis une reservation acceptee : **la voie
  /// normale**.
  ///
  /// Tout est facultatif. Sans `quantite`, toute la quantite reservee est
  /// vendue ; sans `prixUnitaire`, le prix affiche de l'annonce
  /// s'applique. Une quantite inferieure declenche la vente partielle :
  /// le serveur libere les unites non achetees et les rend disponibles.
  Future<ResultatVente> depuisReservation(
    int reservationId, {
    int? quantite,
    double? prixUnitaire,
    MoyenPaiement moyenPaiement = MoyenPaiement.cash,
    String? note,
  }) =>
      _action(
        '/reservations/$reservationId/complete/',
        corps: {
          'quantite': ?quantite,
          if (prixUnitaire != null)
            'prix_unitaire': prixUnitaire.toStringAsFixed(2),
          'moyen_paiement': moyenPaiement.code,
          if (note?.trim().isNotEmpty ?? false) 'note': note!.trim(),
        },
      );

  /// Vente directe, sans reservation : le client est venu sur place.
  ///
  /// La quantite est plafonnee au DISPONIBLE : ce qui est reserve par
  /// d'autres n'est pas vendable.
  Future<ResultatVente> directe({
    required int produitId,
    required int acheteurId,
    required int quantite,
    MoyenPaiement moyenPaiement = MoyenPaiement.cash,
    double? prixUnitaire,
    String? note,
  }) =>
      _action(
        '/sales/',
        corps: {
          'produit': produitId,
          'acheteur': acheteurId,
          'quantite': quantite,
          'moyen_paiement': moyenPaiement.code,
          if (prixUnitaire != null)
            'prix_unitaire': prixUnitaire.toStringAsFixed(2),
          if (note?.trim().isNotEmpty ?? false) 'note': note!.trim(),
        },
      );

  /// Vendeur : « j'ai recu le paiement ». La vente compte alors dans le
  /// chiffre d'affaires.
  Future<ResultatVente> confirmerPaiement(int id) =>
      _action('/sales/$id/confirm/');

  /// Acheteur : « j'ai recu le produit ». Termine la vente.
  Future<ResultatVente> confirmerReception(int id) =>
      _action('/sales/$id/buyer-confirmation/');

  /// Annule. Le motif est OBLIGATOIRE cote serveur (400 sinon).
  Future<ResultatVente> annuler(int id, {required String motif}) =>
      _action('/sales/$id/cancel/', corps: {'motif': motif.trim()});

  Future<ResultatVente> _action(
    String chemin, {
    Map<String, dynamic> corps = const {},
  }) async {
    final reponse = await _api.post(chemin, corps: corps);
    final map = reponse as Map<String, dynamic>;

    final brutVente = map['vente'];
    final brutReservation = map['reservation'];

    return ResultatVente(
      vente: Vente.depuisJson(
        brutVente is Map<String, dynamic> ? brutVente : map,
      ),
      message: map['message'] as String? ?? '',
      reservation: brutReservation is Map<String, dynamic>
          ? Reservation.depuisJson(brutReservation)
          : null,
    );
  }
}
