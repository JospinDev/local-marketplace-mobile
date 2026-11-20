import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../catalogue/domain/produit.dart';

/// Etat du stock d'une annonce.
///
/// Les trois quantites du cahier des charges, avec l'invariant qui les
/// relie :
///
/// ```
/// disponible = totale - reservee - vendue
/// ```
///
/// Le vendeur ne declare QUE `totale`. Les deux autres sont pilotees par
/// les reservations et les ventes, et sont en lecture seule — il ne faut
/// jamais en faire un champ de formulaire.
class Stock {
  const Stock({
    this.quantiteTotale = 0,
    this.quantiteReservee = 0,
    this.quantiteVendue = 0,
    this.quantiteDisponible = 0,
    this.valeurStock,
    this.valeurReservations,
  });

  final int quantiteTotale;
  final int quantiteReservee;
  final int quantiteVendue;
  final int quantiteDisponible;
  final double? valeurStock;
  final double? valeurReservations;

  /// Quantite deja engagee : c'est le plancher en dessous duquel le
  /// serveur refusera de descendre le stock total.
  int get engagee => quantiteReservee + quantiteVendue;

  factory Stock.depuisJson(Map<String, dynamic> json) => Stock(
        quantiteTotale: (json['quantite_totale'] as num?)?.toInt() ?? 0,
        quantiteReservee: (json['quantite_reservee'] as num?)?.toInt() ?? 0,
        quantiteVendue: (json['quantite_vendue'] as num?)?.toInt() ?? 0,
        quantiteDisponible:
            (json['quantite_disponible'] as num?)?.toInt() ?? 0,
        valeurStock: _decimal(json['valeur_stock']),
        valeurReservations: _decimal(json['valeur_reservations']),
      );

  static double? _decimal(dynamic valeur) {
    if (valeur == null) return null;
    if (valeur is num) return valeur.toDouble();
    return double.tryParse(valeur.toString());
  }
}

/// Acces aux annonces du vendeur connecte (etape 4 du guide).
///
/// La protection est la PROPRIETE, pas un groupe de permissions : tout
/// compte peut vendre, et le serveur filtre sur `owner = vous`. L'annonce
/// d'un autre vendeur renvoie 404 sur ces routes, meme si elle est
/// publique ailleurs.
class AnnoncesRepository {
  AnnoncesRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  // ------------------------------------------------------------- lecture
  Future<PageResultats<Produit>> mesAnnonces({
    int page = 1,
    String? statut,
    String? recherche,
  }) async {
    final reponse = await _api.get(
      '/products/',
      parametres: {
        'page': page,
        'status': ?statut,
        if (recherche?.trim().isNotEmpty ?? false) 'q': recherche!.trim(),
        'ordering': '-created_at',
      },
    );
    return PageResultats.depuisJson(reponse, Produit.depuisJson);
  }

  Future<Produit> annonce(int id) async {
    final reponse = await _api.get('/products/$id/') as Map<String, dynamic>;
    return Produit.depuisJson(reponse);
  }

  // ------------------------------------------------------------- ecriture
  /// Cree une annonce. Elle nait toujours en `DRAFT` : `status` n'est pas
  /// accepte a la creation, c'est `publish/` qui met en ligne.
  Future<Produit> creer({
    required String titre,
    required int categorie,
    required double prix,
    String? description,
    EtatProduit etat = EtatProduit.neuf,
    String? localisation,
    double? latitude,
    double? longitude,
  }) async {
    final corps = <String, dynamic>{
      'titre': titre.trim(),
      'categorie': categorie,
      // Le serveur attend une chaine decimale : envoyer un double peut
      // produire « 250000.0 » ou une notation scientifique selon la
      // valeur, que le serializer DecimalField refuse parfois.
      'prix': prix.toStringAsFixed(2),
      'etat': etat.code,
    };
    if (description?.trim().isNotEmpty ?? false) {
      corps['description'] = description!.trim();
    }
    if (localisation?.trim().isNotEmpty ?? false) {
      corps['localisation'] = localisation!.trim();
    }
    if (latitude != null) corps['latitude'] = latitude;
    if (longitude != null) corps['longitude'] = longitude;

    final reponse =
        await _api.post('/products/', corps: corps) as Map<String, dynamic>;
    return Produit.depuisJson(reponse);
  }

  Future<Produit> modifier(int id, Map<String, dynamic> champs) async {
    final reponse =
        await _api.patch('/products/$id/', corps: champs) as Map<String, dynamic>;
    return Produit.depuisJson(reponse);
  }

  /// Suppression DOUCE : le serveur archive, il n'efface pas. C'est ce qui
  /// garde l'historique des ventes lisible.
  Future<void> archiver(int id) => _api.delete('/products/$id/');

  // ------------------------------------------------------ cycle de vie
  Future<Produit> publier(int id) => _action(id, 'publish');

  Future<Produit> mettreEnPause(int id) => _action(id, 'pause');

  Future<Produit> _action(int id, String chemin) async {
    final reponse = await _api.post('/products/$id/$chemin/');
    // Ces routes repondent soit l'annonce, soit une enveloppe qui la
    // contient : on accepte les deux formes.
    if (reponse is Map<String, dynamic>) {
      final imbrique = reponse['produit'];
      if (imbrique is Map<String, dynamic>) return Produit.depuisJson(imbrique);
      return Produit.depuisJson(reponse);
    }
    return annonce(id);
  }

  // --------------------------------------------------------------- stock
  Future<Stock> stock(int id) async {
    final reponse =
        await _api.get('/products/$id/stock/') as Map<String, dynamic>;
    return Stock.depuisJson(reponse);
  }

  Future<Stock> majStock(int id, int quantiteTotale) async {
    final reponse = await _api.patch(
      '/products/$id/stock/',
      corps: {'quantite_totale': quantiteTotale},
    ) as Map<String, dynamic>;
    return Stock.depuisJson(reponse);
  }

  // -------------------------------------------------------------- images
  /// Televerse une ou plusieurs photos.
  ///
  /// Le serveur attend un champ repete `images`, et non un tableau JSON :
  /// c'est un envoi multipart classique de formulaire.
  Future<List<ImageProduit>> ajouterImages(
    int id,
    List<File> fichiers, {
    bool principale = false,
  }) async {
    if (fichiers.isEmpty) return const [];

    final formulaire = FormData();
    for (final fichier in fichiers) {
      formulaire.files.add(
        MapEntry(
          'images',
          await MultipartFile.fromFile(
            fichier.path,
            filename: fichier.path.split(RegExp(r'[\\/]')).last,
          ),
        ),
      );
    }
    if (principale) {
      formulaire.fields.add(const MapEntry('est_principale', 'true'));
    }

    final reponse = await _api.envoyerFichiers(
      '/products/$id/images/',
      formulaire,
      methode: 'POST',
    );

    // La reponse peut etre la liste des images, ou une enveloppe.
    final brutes = reponse is Map ? reponse['images'] ?? reponse['results'] : reponse;
    if (brutes is List) {
      return brutes
          .whereType<Map<String, dynamic>>()
          .map(ImageProduit.depuisJson)
          .toList();
    }
    return const [];
  }

  Future<void> supprimerImage(int produitId, int imageId) =>
      _api.delete('/products/$produitId/images/$imageId/');
}
