import '../../catalogue/domain/produit.dart';

/// Un produit mis en favori.
///
/// Le favori memorise le prix du jour ou il a ete ajoute, ce qui permet au
/// serveur de signaler les variations. Point important : le backend
/// renvoie deja un message `alerte` REDIGE — on l'affiche tel quel au lieu
/// de reconstruire la phrase cote mobile, sinon les deux versions
/// finiraient par diverger.
class Favori {
  const Favori({
    required this.id,
    required this.produit,
    required this.prixALAjout,
    this.prixActuel,
    this.variationPrix,
    this.prixAChange = false,
    this.estToujoursDisponible = true,
    this.estRetire = false,
    this.alerte,
    this.creeLe,
  });

  final int id;
  final Produit produit;

  final double prixALAjout;
  final double? prixActuel;

  /// Positive si le prix a monte, negative s'il a baisse.
  final double? variationPrix;
  final bool prixAChange;

  final bool estToujoursDisponible;
  final bool estRetire;

  /// Message pret a afficher, ou `null` quand tout va bien.
  final String? alerte;

  final DateTime? creeLe;

  bool get aUneAlerte => alerte != null && alerte!.isNotEmpty;
  bool get prixABaisse => (variationPrix ?? 0) < 0;

  factory Favori.depuisJson(Map<String, dynamic> json) {
    final brutProduit = json['produit'];
    return Favori(
      id: (json['id'] as num?)?.toInt() ?? 0,
      produit: brutProduit is Map<String, dynamic>
          ? Produit.depuisJson(brutProduit)
          : const Produit(id: 0, titre: '', slug: '', prix: 0),
      prixALAjout: _decimal(json['prix_a_l_ajout']) ?? 0,
      prixActuel: _decimal(json['prix_actuel']),
      variationPrix: _decimal(json['variation_prix']),
      prixAChange: json['prix_a_change'] as bool? ?? false,
      estToujoursDisponible:
          json['est_toujours_disponible'] as bool? ?? true,
      estRetire: json['est_retire'] as bool? ?? false,
      alerte: (json['alerte'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['alerte'] as String).trim(),
      creeLe: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static double? _decimal(dynamic valeur) {
    if (valeur == null) return null;
    if (valeur is num) return valeur.toDouble();
    return double.tryParse(valeur.toString());
  }
}

/// Un vendeur suivi.
///
/// A ne pas confondre avec un favori : le favori porte sur un PRODUIT,
/// l'abonnement sur un VENDEUR. Les deux repondent a des besoins
/// differents — surveiller un prix, ou suivre une boutique — et le guide
/// insiste pour ne pas les fusionner dans un meme ecran.
class VendeurSuivi {
  const VendeurSuivi({
    required this.id,
    required this.vendeurId,
    required this.username,
    this.nomCommercial,
    this.nomComplet,
    this.photo,
    this.localisation,
    this.nombreProduitsActifs = 0,
    this.nombreAbonnes = 0,
    this.suiviDepuis,
  });

  /// Identifiant de l'ABONNEMENT, different de celui du vendeur.
  final int id;
  final int vendeurId;

  final String username;
  final String? nomCommercial;
  final String? nomComplet;
  final String? photo;
  final String? localisation;
  final int nombreProduitsActifs;
  final int nombreAbonnes;
  final DateTime? suiviDepuis;

  String get nomAffiche {
    for (final candidat in [nomCommercial, nomComplet]) {
      if (candidat != null && candidat.trim().isNotEmpty) return candidat.trim();
    }
    return username;
  }

  String get initiales {
    final nom = nomAffiche.trim();
    if (nom.isEmpty) return '?';
    final mots = nom.split(RegExp(r'\s+'));
    if (mots.length >= 2 && mots[0].isNotEmpty && mots[1].isNotEmpty) {
      return (mots[0][0] + mots[1][0]).toUpperCase();
    }
    return nom.substring(0, nom.length >= 2 ? 2 : 1).toUpperCase();
  }

  factory VendeurSuivi.depuisJson(Map<String, dynamic> json) {
    // La route renvoie l'abonnement, qui contient le vendeur imbrique.
    final brut = json['vendeur'];
    final vendeur = brut is Map<String, dynamic> ? brut : json;

    return VendeurSuivi(
      id: (json['id'] as num?)?.toInt() ?? 0,
      vendeurId: (vendeur['id'] as num?)?.toInt() ?? 0,
      username: vendeur['username'] as String? ?? '',
      nomCommercial: _texte(vendeur['nom_commercial']),
      nomComplet: _texte(vendeur['nom_complet']),
      photo: _texte(vendeur['photo']),
      localisation: _texte(vendeur['localisation']),
      nombreProduitsActifs:
          (vendeur['nombre_produits_actifs'] as num?)?.toInt() ?? 0,
      nombreAbonnes: (vendeur['nombre_abonnes'] as num?)?.toInt() ?? 0,
      suiviDepuis: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static String? _texte(dynamic valeur) {
    if (valeur == null) return null;
    final texte = valeur.toString().trim();
    return texte.isEmpty ? null : texte;
  }
}
