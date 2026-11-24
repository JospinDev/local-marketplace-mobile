/// Ce que la publicite ouvre quand on appuie dessus.
enum CiblePublicite {
  aucune,
  produit,
  categorie,
  vendeur,
  url;

  static CiblePublicite depuisCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'PRODUIT':
        return CiblePublicite.produit;
      case 'CATEGORIE':
        return CiblePublicite.categorie;
      case 'VENDEUR':
        return CiblePublicite.vendeur;
      case 'URL':
        return CiblePublicite.url;
      default:
        return CiblePublicite.aucune;
    }
  }
}

/// Une publicite du bandeau d'accueil, creee par l'administration.
///
/// Le serveur ne renvoie que les publicites **diffusables** : actives,
/// dans leur fenetre de diffusion, et seulement si l'interrupteur global
/// est allume. Le client n'a donc aucun filtrage a refaire — une liste
/// vide veut dire « pas de bandeau », et l'emplacement disparait.
class Publicite {
  const Publicite({
    required this.id,
    required this.titre,
    required this.image,
    this.sousTitre = '',
    this.libelleAction = '',
    this.cible = CiblePublicite.aucune,
    this.cibleId,
    this.cibleUrl = '',
    this.ordre = 0,
  });

  final int id;
  final String titre;
  final String image;
  final String sousTitre;

  /// Vide, aucun bouton n'est dessine.
  final String libelleAction;

  final CiblePublicite cible;
  final int? cibleId;
  final String cibleUrl;
  final int ordre;

  bool get estCliquable {
    switch (cible) {
      case CiblePublicite.aucune:
        return false;
      case CiblePublicite.url:
        return cibleUrl.trim().isNotEmpty;
      default:
        return (cibleId ?? 0) > 0;
    }
  }

  factory Publicite.depuisJson(Map<String, dynamic> json) => Publicite(
        id: (json['id'] as num?)?.toInt() ?? 0,
        titre: json['titre'] as String? ?? '',
        image: json['image']?.toString() ?? '',
        sousTitre: json['sous_titre'] as String? ?? '',
        libelleAction: json['libelle_action'] as String? ?? '',
        cible: CiblePublicite.depuisCode(json['type_cible'] as String?),
        cibleId: (json['cible_id'] as num?)?.toInt(),
        cibleUrl: json['cible_url'] as String? ?? '',
        ordre: (json['ordre'] as num?)?.toInt() ?? 0,
      );
}
