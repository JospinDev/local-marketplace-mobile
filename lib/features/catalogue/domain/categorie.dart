/// Categorie du catalogue.
///
/// Les champs suivent EXACTEMENT ceux de `CategorieSerializer` cote
/// serveur : `nom`, `slug`, `chemin_complet`, `niveau`, `icone`... Les
/// recopier de memoire est la facon la plus sure d'introduire un bug
/// silencieux — une cle absente devient `null`, puis une valeur par
/// defaut, et personne ne voit rien.
class Categorie {
  const Categorie({
    required this.id,
    required this.nom,
    required this.slug,
    this.description,
    this.parent,
    this.parentNom,
    this.cheminComplet,
    this.niveau = 0,
    this.image,
    this.icone,
    this.ordre = 0,
    this.estActive = true,
    this.nombreSousCategories = 0,
    this.sousCategories = const [],
  });

  final int id;
  final String nom;
  final String slug;
  final String? description;

  final int? parent;
  final String? parentNom;

  /// « Electronique > Telephonie > Smartphones ». Pratique pour le fil
  /// d'Ariane de la fiche produit.
  final String? cheminComplet;
  final int niveau;

  final String? image;

  /// Nom d'icone libre, choisi cote administration. On ne peut donc pas le
  /// convertir en `IconData` de facon sure : il sert d'indice, avec un
  /// repli quand il ne correspond a rien de connu.
  final String? icone;

  final int ordre;
  final bool estActive;
  final int nombreSousCategories;

  /// Rempli uniquement par `/public/categories/tree/`.
  final List<Categorie> sousCategories;

  bool get estRacine => parent == null;

  factory Categorie.depuisJson(Map<String, dynamic> json) {
    final enfants = json['sous_categories'];
    return Categorie(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nom: json['nom'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: _texte(json['description']),
      parent: (json['parent'] as num?)?.toInt(),
      parentNom: _texte(json['parent_nom']),
      cheminComplet: _texte(json['chemin_complet']),
      niveau: (json['niveau'] as num?)?.toInt() ?? 0,
      image: _texte(json['image']),
      icone: _texte(json['icone']),
      ordre: (json['ordre'] as num?)?.toInt() ?? 0,
      estActive: json['is_active'] as bool? ?? true,
      nombreSousCategories:
          (json['nombre_sous_categories'] as num?)?.toInt() ?? 0,
      sousCategories: enfants is List
          ? enfants
              .whereType<Map<String, dynamic>>()
              .map(Categorie.depuisJson)
              .toList()
          : const [],
    );
  }

  static String? _texte(dynamic valeur) {
    if (valeur == null) return null;
    final texte = valeur.toString().trim();
    return texte.isEmpty ? null : texte;
  }
}
