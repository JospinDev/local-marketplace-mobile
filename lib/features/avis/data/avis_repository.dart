import '../../../core/network/api_client.dart';
import '../../catalogue/domain/produit.dart';
import '../domain/evaluation.dart';

class ResultatAvis {
  const ResultatAvis({required this.evaluation, required this.message});

  final Evaluation evaluation;
  final String message;
}

/// Acces aux avis (module 11, etape 9 du guide).
///
/// Un avis exige une vente **terminee** : confirmee par le vendeur, puis
/// par l'acheteur. Le serveur refuse autrement, et son message nomme la
/// route qui manque — on l'affiche tel quel plutot que de le reecrire.
class AvisRepository {
  AvisRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  // ------------------------------------------------------------- lectures
  /// Avis que j'ai ecrits.
  Future<PageResultats<Evaluation>> mesAvis({int page = 1}) async {
    final reponse = await _api.get(
      '/reviews/my-reviews/',
      parametres: {'page': page},
    );
    return PageResultats.depuisJson(reponse, Evaluation.depuisJson);
  }

  /// Avis recus sur mes ventes.
  Future<PageResultats<Evaluation>> avisRecus({int page = 1}) async {
    final reponse = await _api.get(
      '/reviews/received/',
      parametres: {'page': page},
    );
    return PageResultats.depuisJson(reponse, Evaluation.depuisJson);
  }

  Future<Reputation> maReputation() async {
    final reponse = await _api.get('/reviews/my-rating/');
    if (reponse is Map<String, dynamic>) {
      return Reputation.depuisJson(reponse);
    }
    return const Reputation();
  }

  /// Avis publics d'une annonce. Lisibles sans compte.
  Future<PageResultats<Evaluation>> avisDuProduit(
    int produitId, {
    int page = 1,
  }) async {
    final reponse = await _api.get(
      '/public/products/$produitId/reviews/',
      parametres: {'page': page},
    );
    return PageResultats.depuisJson(reponse, Evaluation.depuisJson);
  }

  /// Avis publics d'un vendeur. La reponse porte EN PLUS `reputation`,
  /// que l'on extrait au passage pour eviter une seconde requete.
  Future<(PageResultats<Evaluation>, Reputation)> avisDuVendeur(
    int vendeurId, {
    int page = 1,
  }) async {
    final reponse = await _api.get(
      '/public/sellers/$vendeurId/reviews/',
      parametres: {'page': page},
    );
    final avis = PageResultats.depuisJson(reponse, Evaluation.depuisJson);

    var reputation = const Reputation();
    if (reponse is Map && reponse['reputation'] is Map<String, dynamic>) {
      reputation =
          Reputation.depuisJson(reponse['reputation'] as Map<String, dynamic>);
    }
    return (avis, reputation);
  }

  // -------------------------------------------------------------- ecriture
  /// Depose un avis sur une vente terminee.
  ///
  /// Le produit et le vendeur sont DEDUITS de la vente : on ne peut pas
  /// noter un vendeur chez qui on n'a rien achete.
  Future<ResultatAvis> deposer({
    required int venteId,
    required int noteProduit,
    required int noteVendeur,
    String? commentaire,
  }) =>
      _action(
        '/reviews/',
        corps: {
          'vente': venteId,
          'note_produit': noteProduit,
          'note_vendeur': noteVendeur,
          if (commentaire?.trim().isNotEmpty ?? false)
            'commentaire': commentaire!.trim(),
        },
      );

  /// Corrige son propre avis, dans le delai autorise.
  Future<ResultatAvis> corriger(
    int id, {
    int? noteProduit,
    int? noteVendeur,
    String? commentaire,
  }) async {
    final reponse = await _api.patch(
      '/reviews/$id/',
      corps: {
        'note_produit': ?noteProduit,
        'note_vendeur': ?noteVendeur,
        if (commentaire != null) 'commentaire': commentaire.trim(),
      },
    );
    return _lire(reponse);
  }

  /// Retire son avis. Le serveur le SORT des moyennes sans l'effacer, et
  /// repond `200` avec l'avis — pas `204`.
  Future<ResultatAvis> retirer(int id) async {
    final reponse = await _api.delete('/reviews/$id/');
    return _lire(reponse);
  }

  Future<void> signaler(
    int id, {
    required String motif,
    String? description,
  }) =>
      _api.post(
        '/reviews/$id/report/',
        corps: {
          'motif': motif,
          if (description?.trim().isNotEmpty ?? false)
            'description': description!.trim(),
        },
      );

  Future<ResultatAvis> _action(
    String chemin, {
    Map<String, dynamic> corps = const {},
  }) async {
    final reponse = await _api.post(chemin, corps: corps);
    return _lire(reponse);
  }

  ResultatAvis _lire(dynamic reponse) {
    final map = reponse as Map<String, dynamic>;
    final brut = map['evaluation'];
    return ResultatAvis(
      evaluation: Evaluation.depuisJson(
        brut is Map<String, dynamic> ? brut : map,
      ),
      message: map['message'] as String? ?? '',
    );
  }
}
