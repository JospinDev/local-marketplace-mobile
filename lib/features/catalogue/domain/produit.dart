/// Lit un champ texte en traitant `null` et la chaine vide de la meme
/// facon : le serveur renvoie parfois `""` pour un champ non renseigne,
/// et afficher une chaine vide produit une ligne fantome dans
/// l'interface.
String? _texte(dynamic valeur) {
  if (valeur == null) return null;
  final texte = valeur.toString().trim();
  return texte.isEmpty ? null : texte;
}

/// Les montants arrivent en chaine ("250000.00") pour ne pas perdre de
/// precision en JSON, les coordonnees parfois en nombre : un seul
/// convertisseur tolerant evite une serie de `as` fragiles.
double? _nombre(dynamic valeur) {
  if (valeur == null) return null;
  if (valeur is num) return valeur.toDouble();
  return double.tryParse(valeur.toString());
}

/// Etat d'une annonce, tel que le serveur le renvoie.
///
/// Les deux SEULS statuts visibles du public sont `ACTIVE` et
/// `OUT_OF_STOCK` : les autres n'arrivent jamais sur les routes
/// `/public/...`. On les declare quand meme, car le vendeur voit les
/// siens (etape 4).
enum StatutProduit {
  brouillon,
  enAttente,
  active,
  rupture,
  enPause,
  archivee,
  retiree;

  static StatutProduit depuis(String? brut) => switch (brut) {
        'DRAFT' => StatutProduit.brouillon,
        'PENDING' => StatutProduit.enAttente,
        'ACTIVE' => StatutProduit.active,
        'OUT_OF_STOCK' => StatutProduit.rupture,
        'PAUSED' => StatutProduit.enPause,
        'ARCHIVED' => StatutProduit.archivee,
        'REMOVED' => StatutProduit.retiree,
        _ => StatutProduit.active,
      };

  String get libelle => switch (this) {
        StatutProduit.brouillon => 'Brouillon',
        StatutProduit.enAttente => 'En moderation',
        StatutProduit.active => 'En ligne',
        StatutProduit.rupture => 'Rupture de stock',
        StatutProduit.enPause => 'En pause',
        StatutProduit.archivee => 'Archivee',
        StatutProduit.retiree => 'Retiree',
      };
}

enum EtatProduit {
  neuf,
  occasion;

  static EtatProduit depuis(String? brut) =>
      brut == 'OCCASION' ? EtatProduit.occasion : EtatProduit.neuf;

  String get libelle => this == EtatProduit.neuf ? 'Neuf' : 'Occasion';
  String get code => this == EtatProduit.neuf ? 'NEUF' : 'OCCASION';
}

/// Image d'une annonce.
class ImageProduit {
  const ImageProduit({
    required this.id,
    required this.url,
    this.legende,
    this.estPrincipale = false,
    this.ordre = 0,
  });

  final int id;
  final String url;
  final String? legende;
  final bool estPrincipale;
  final int ordre;

  factory ImageProduit.depuisJson(Map<String, dynamic> json) => ImageProduit(
        id: (json['id'] as num?)?.toInt() ?? 0,
        url: json['image'] as String? ?? '',
        legende: (json['legende'] as String?)?.trim(),
        estPrincipale: json['est_principale'] as bool? ?? false,
        ordre: (json['ordre'] as num?)?.toInt() ?? 0,
      );
}

/// Notes moyennes d'un produit ou d'un vendeur (module 11).
///
/// `null` ne veut PAS dire zero : il veut dire « pas encore d'avis ».
/// Afficher `0/5` dans ce cas serait un mensonge qui dessert le vendeur.
/// Reputation : les moyennes ne comptent que les avis VALIDES.
///
/// Un avis masque par la moderation ou retire par son auteur n'entre dans
/// aucune moyenne. C'est le serveur qui applique la regle ; le client ne
/// recalcule jamais une moyenne a partir d'une liste paginee.
class Reputation {
  const Reputation({
    this.noteProduit,
    this.noteVendeur,
    this.nombreEvaluations = 0,
    this.repartition = const {},
  });

  final double? noteProduit;
  final double? noteVendeur;
  final int nombreEvaluations;

  /// Nombre d'avis par note, de "1" a "5".
  ///
  /// Renseignee uniquement par la vitrine publique d'un vendeur
  /// (`ReputationVendeurSerializer`). Vide ailleurs, et c'est normal :
  /// l'affichage doit alors se contenter de la moyenne.
  final Map<String, int> repartition;

  bool get aDesAvis => nombreEvaluations > 0;
  bool get estVide => nombreEvaluations == 0;

  factory Reputation.depuisJson(Map<String, dynamic>? json) {
    if (json == null) return const Reputation();

    final brut = json['repartition'];
    final repartition = <String, int>{};
    if (brut is Map) {
      brut.forEach((cle, valeur) {
        if (valeur is num) repartition['$cle'] = valeur.toInt();
      });
    }

    return Reputation(
      noteProduit: (json['note_produit'] as num?)?.toDouble(),
      noteVendeur: (json['note_vendeur'] as num?)?.toDouble(),
      nombreEvaluations:
          (json['nombre_evaluations'] as num?)?.toInt() ?? 0,
      repartition: repartition,
    );
  }
}

/// Encart vendeur affiche sur une fiche produit.
class VendeurResume {
  const VendeurResume({
    required this.id,
    required this.username,
    this.nomCommercial,
    this.photo,
    this.localisation,
    this.telephone,
    this.membreDepuis,
  });

  final int id;
  final String username;
  final String? nomCommercial;
  final String? photo;
  final String? localisation;

  /// `null` quand le vendeur n'a pas autorise l'affichage de son numero :
  /// c'est son seul reglage de confidentialite, il faut le respecter.
  final String? telephone;

  final DateTime? membreDepuis;

  String get nomAffiche =>
      (nomCommercial?.trim().isNotEmpty ?? false) ? nomCommercial! : username;

  factory VendeurResume.depuisJson(Map<String, dynamic> json) =>
      VendeurResume(
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
        nomCommercial: _texte(json['nom_commercial']),
        photo: _texte(json['photo']),
        localisation: _texte(json['localisation']),
        telephone: _texte(json['telephone']),
        membreDepuis: DateTime.tryParse(json['membre_depuis']?.toString() ?? ''),
      );
}

/// Annonce, en version liste.
///
/// La fiche detaillee ajoute des champs mais garde la meme base : une
/// seule classe evite de dupliquer la logique d'affichage entre la carte
/// et la fiche.
class Produit {
  const Produit({
    required this.id,
    required this.titre,
    required this.slug,
    required this.prix,
    this.devise = 'BIF',
    this.etat = EtatProduit.neuf,
    this.statut = StatutProduit.active,
    this.categorie,
    this.categorieNom,
    this.localisation,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.quantiteDisponible = 0,
    this.imagePrincipale,
    this.vendeurUsername,
    this.estMisEnAvant = false,
    this.nombreVues = 0,
    this.publieLe,
    this.creeLe,
    // --- detail -------------------------------------------------------
    this.description,
    this.categorieChemin,
    this.images = const [],
    this.vendeur,
    this.reputation = const Reputation(),
  });

  final int id;
  final String titre;
  final String slug;

  /// Le serveur renvoie le prix comme une CHAINE ("250000.00") pour ne pas
  /// perdre de precision en JSON. On le convertit une fois ici.
  final double prix;
  final String devise;

  final EtatProduit etat;
  final StatutProduit statut;

  final int? categorie;
  final String? categorieNom;

  final String? localisation;
  final double? latitude;
  final double? longitude;

  /// Rempli seulement quand la requete porte `latitude` et `longitude`.
  /// `null` = annonce sans coordonnees : elle reste valide, simplement
  /// releguee en fin de tri par proximite.
  final double? distanceKm;

  final int quantiteDisponible;
  final ImageProduit? imagePrincipale;
  final String? vendeurUsername;
  final bool estMisEnAvant;
  final int nombreVues;
  final DateTime? publieLe;
  final DateTime? creeLe;

  // --- champs de la fiche detaillee -------------------------------------
  final String? description;
  final String? categorieChemin;
  final List<ImageProduit> images;
  final VendeurResume? vendeur;
  final Reputation reputation;

  bool get estDisponible =>
      statut == StatutProduit.active && quantiteDisponible > 0;

  bool get estEnRupture =>
      statut == StatutProduit.rupture || quantiteDisponible <= 0;

  /// Image a afficher : la principale, sinon la premiere disponible.
  ImageProduit? get imageAffichee =>
      imagePrincipale ?? (images.isNotEmpty ? images.first : null);

  factory Produit.depuisJson(Map<String, dynamic> json) {
    final brutesImages = json['images'];
    final brutImagePrincipale = json['image_principale'];
    final brutVendeur = json['vendeur'];

    return Produit(
      id: (json['id'] as num?)?.toInt() ?? 0,
      titre: json['titre'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      prix: _nombre(json['prix']) ?? 0,
      devise: json['devise'] as String? ?? 'BIF',
      etat: EtatProduit.depuis(json['etat'] as String?),
      statut: StatutProduit.depuis(json['status'] as String?),
      categorie: (json['categorie'] as num?)?.toInt(),
      categorieNom: _texte(json['categorie_nom']),
      localisation: _texte(json['localisation']),
      latitude: _nombre(json['latitude']),
      longitude: _nombre(json['longitude']),
      distanceKm: _nombre(json['distance_km']),
      quantiteDisponible:
          (json['quantite_disponible'] as num?)?.toInt() ?? 0,
      imagePrincipale: brutImagePrincipale is Map<String, dynamic>
          ? ImageProduit.depuisJson(brutImagePrincipale)
          : null,
      vendeurUsername: _texte(json['vendeur_username']),
      estMisEnAvant: json['est_mis_en_avant'] as bool? ?? false,
      nombreVues: (json['nombre_vues'] as num?)?.toInt() ?? 0,
      publieLe: DateTime.tryParse(json['publie_le']?.toString() ?? ''),
      creeLe: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      description: _texte(json['description']),
      categorieChemin: _texte(json['categorie_chemin']),
      images: brutesImages is List
          ? brutesImages
              .whereType<Map<String, dynamic>>()
              .map(ImageProduit.depuisJson)
              .toList()
          : const [],
      vendeur: brutVendeur is Map<String, dynamic>
          ? VendeurResume.depuisJson(brutVendeur)
          : null,
      reputation: Reputation.depuisJson(
        json['reputation'] as Map<String, dynamic>?,
      ),
    );
  }

}

/// Page de resultats paginee, telle que DRF la renvoie.
class PageResultats<T> {
  const PageResultats({
    required this.elements,
    required this.total,
    this.suivante,
    this.precedente,
  });

  final List<T> elements;
  final int total;

  /// URL complete de la page suivante, ou `null` a la fin de la liste.
  final String? suivante;
  final String? precedente;

  bool get aUneSuite => suivante != null;

  /// Meme page, autres elements : sert a reordonner ou filtrer sans
  /// perdre la pagination.
  PageResultats<T> avecElements(List<T> nouveaux) => PageResultats<T>(
        elements: nouveaux,
        total: total,
        suivante: suivante,
        precedente: precedente,
      );

  static PageResultats<T> depuisJson<T>(
    dynamic json,
    T Function(Map<String, dynamic>) lire,
  ) {
    // Certaines routes renvoient une liste nue (l'arbre des categories) :
    // on l'accepte plutot que de planter.
    if (json is List) {
      final elements =
          json.whereType<Map<String, dynamic>>().map(lire).toList();
      return PageResultats<T>(elements: elements, total: elements.length);
    }

    final map = json as Map<String, dynamic>;
    final brut = map['results'];
    return PageResultats<T>(
      elements: brut is List
          ? brut.whereType<Map<String, dynamic>>().map(lire).toList()
          : const [],
      total: (map['count'] as num?)?.toInt() ?? 0,
      suivante: map['next'] as String?,
      precedente: map['previous'] as String?,
    );
  }
}
