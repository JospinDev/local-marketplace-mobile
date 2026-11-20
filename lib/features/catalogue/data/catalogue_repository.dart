import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/categorie.dart';
import '../domain/produit.dart';

/// Criteres de recherche du catalogue.
///
/// Un objet plutot que dix parametres nommes : il se compare, se copie et
/// se transporte dans un provider sans qu'on oublie un champ en route.
class FiltresCatalogue {
  const FiltresCatalogue({
    this.recherche,
    this.categorie,
    this.categorieArbre,
    this.localisation,
    this.prixMin,
    this.prixMax,
    this.etat,
    this.disponibleSeulement = false,
    this.latitude,
    this.longitude,
    this.rayonKm,
    this.tri = TriCatalogue.pertinence,
  });

  final String? recherche;
  final int? categorie;

  /// Inclut les sous-categories. C'est presque toujours ce qu'attend la
  /// personne qui touche « Electronique » : elle veut aussi les
  /// telephones qui sont dans une sous-categorie.
  final int? categorieArbre;

  final String? localisation;
  final double? prixMin;
  final double? prixMax;
  final EtatProduit? etat;
  final bool disponibleSeulement;

  final double? latitude;
  final double? longitude;
  final double? rayonKm;

  final TriCatalogue tri;

  bool get aDesFiltres =>
      categorie != null ||
      categorieArbre != null ||
      (localisation?.isNotEmpty ?? false) ||
      prixMin != null ||
      prixMax != null ||
      etat != null ||
      disponibleSeulement ||
      rayonKm != null;

  /// Nombre de filtres actifs, pour la pastille du bouton « Filtrer ».
  int get nombreActifs {
    var total = 0;
    if (categorie != null || categorieArbre != null) total++;
    if (localisation?.isNotEmpty ?? false) total++;
    if (prixMin != null || prixMax != null) total++;
    if (etat != null) total++;
    if (disponibleSeulement) total++;
    if (rayonKm != null) total++;
    return total;
  }

  FiltresCatalogue copyWith({
    String? recherche,
    int? categorie,
    int? categorieArbre,
    String? localisation,
    double? prixMin,
    double? prixMax,
    EtatProduit? etat,
    bool? disponibleSeulement,
    double? latitude,
    double? longitude,
    double? rayonKm,
    TriCatalogue? tri,
    bool viderCategorie = false,
    bool viderPrix = false,
    bool viderEtat = false,
    bool viderRayon = false,
  }) {
    return FiltresCatalogue(
      recherche: recherche ?? this.recherche,
      categorie: viderCategorie ? null : (categorie ?? this.categorie),
      categorieArbre:
          viderCategorie ? null : (categorieArbre ?? this.categorieArbre),
      localisation: localisation ?? this.localisation,
      prixMin: viderPrix ? null : (prixMin ?? this.prixMin),
      prixMax: viderPrix ? null : (prixMax ?? this.prixMax),
      etat: viderEtat ? null : (etat ?? this.etat),
      disponibleSeulement: disponibleSeulement ?? this.disponibleSeulement,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rayonKm: viderRayon ? null : (rayonKm ?? this.rayonKm),
      tri: tri ?? this.tri,
    );
  }

  /// Traduit les criteres en parametres d'URL attendus par le serveur.
  Map<String, dynamic> versParametres({int page = 1}) {
    final p = <String, dynamic>{'page': page};

    if (recherche?.trim().isNotEmpty ?? false) p['q'] = recherche!.trim();
    if (categorieArbre != null) {
      p['categorie_arbre'] = categorieArbre;
    } else if (categorie != null) {
      p['categorie'] = categorie;
    }
    if (localisation?.trim().isNotEmpty ?? false) {
      p['localisation'] = localisation!.trim();
    }
    if (prixMin != null) p['prix_min'] = prixMin;
    if (prixMax != null) p['prix_max'] = prixMax;
    if (etat != null) p['etat'] = etat!.code;
    if (disponibleSeulement) p['disponible'] = true;

    // `rayon_km` sans coordonnees est ignore par le serveur : on evite de
    // l'envoyer seul, cela n'aurait aucun effet et brouillerait le log.
    if (latitude != null && longitude != null) {
      p['latitude'] = latitude;
      p['longitude'] = longitude;
      if (rayonKm != null) p['rayon_km'] = rayonKm;
    }

    final ordering = tri.parametre;
    if (ordering != null) p['ordering'] = ordering;

    return p;
  }
}

enum TriCatalogue {
  pertinence,
  prixCroissant,
  prixDecroissant,
  recent,
  populaire,
  proximite;

  /// Valeur du parametre `ordering`. `null` = tri par defaut du serveur.
  String? get parametre => switch (this) {
        TriCatalogue.pertinence => null,
        TriCatalogue.prixCroissant => 'prix',
        TriCatalogue.prixDecroissant => '-prix',
        TriCatalogue.recent => '-publie_le',
        TriCatalogue.populaire => '-nombre_vues',
        TriCatalogue.proximite => 'distance_km',
      };

  String get libelle => switch (this) {
        TriCatalogue.pertinence => 'Pertinence',
        TriCatalogue.prixCroissant => 'Prix croissant',
        TriCatalogue.prixDecroissant => 'Prix decroissant',
        TriCatalogue.recent => 'Plus recents',
        TriCatalogue.populaire => 'Les plus vus',
        TriCatalogue.proximite => 'Au plus proche',
      };
}

/// Acces au catalogue public (etape 3 du guide).
///
/// Toutes ces routes fonctionnent SANS jeton : le guide insiste, un
/// visiteur doit pouvoir regarder avant de s'inscrire. On envoie quand
/// meme le jeton quand il existe, car certaines reponses s'enrichissent
/// alors (`est_suivi` sur les vendeurs).
class CatalogueRepository {
  CatalogueRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  // ---------------------------------------------------------- categories
  /// Arbre complet, non pagine. A appeler UNE fois au demarrage et garder
  /// en cache : il change rarement et pese peu.
  Future<List<Categorie>> arbreCategories() async {
    final reponse = await _api.get('/public/categories/tree/');
    final page = PageResultats.depuisJson(reponse, Categorie.depuisJson);
    return page.elements;
  }

  // ------------------------------------------------------------ produits
  Future<PageResultats<Produit>> rechercher(
    FiltresCatalogue filtres, {
    int page = 1,
  }) async {
    final reponse = await _api.get(
      '/public/products/',
      parametres: filtres.versParametres(page: page),
    );
    return PageResultats.depuisJson(reponse, Produit.depuisJson);
  }

  Future<List<Produit>> misesEnAvant() => _liste('/public/products/featured/');

  Future<List<Produit>> dernieres() => _liste('/public/products/latest/');

  Future<List<Produit>> populaires() => _liste('/public/products/popular/');

  Future<Produit> fiche(int id) async {
    final reponse =
        await _api.get('/public/products/$id/') as Map<String, dynamic>;
    return Produit.depuisJson(reponse);
  }

  // ------------------------------------------------------------- vendeur
  Future<PageResultats<Produit>> produitsDuVendeur(
    int vendeurId, {
    int page = 1,
  }) async {
    final reponse = await _api.get(
      '/public/sellers/$vendeurId/products/',
      parametres: {'page': page},
    );
    return PageResultats.depuisJson(reponse, Produit.depuisJson);
  }

  // --------------------------------------------------------------- interne
  Future<List<Produit>> _liste(String chemin) async {
    final reponse = await _api.get(
      chemin,
      parametres: {'page_size': AppConfig.taillePage},
    );
    final page = PageResultats.depuisJson(reponse, Produit.depuisJson);
    return page.elements;
  }
}
