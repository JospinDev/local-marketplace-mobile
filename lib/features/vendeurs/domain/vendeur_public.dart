/// Vitrine publique d'un vendeur (module 5).
///
/// `telephone` est `null` quand le vendeur n'a pas autorise l'affichage de
/// son numero. C'est son seul reglage de confidentialite : l'ecran doit
/// simplement masquer le bouton d'appel, jamais proposer un contournement.
class VendeurPublic {
  const VendeurPublic({
    required this.id,
    required this.username,
    this.nomCommercial,
    this.nomComplet,
    this.photo,
    this.localisation,
    this.description,
    this.telephone,
    this.nombreProduitsActifs = 0,
    this.nombreAbonnes = 0,
    this.nombreProduitsPublies = 0,
    this.nombreProduitsEnRupture = 0,
    this.noteMoyenne,
    this.nombreEvaluations = 0,
    this.estSuivi = false,
    this.statutCompte,
    this.membreDepuis,
  });

  final int id;
  final String username;
  final String? nomCommercial;
  final String? nomComplet;
  final String? photo;
  final String? localisation;
  final String? description;
  final String? telephone;

  final int nombreProduitsActifs;
  final int nombreAbonnes;
  final int nombreProduitsPublies;
  final int nombreProduitsEnRupture;

  final double? noteMoyenne;
  final int nombreEvaluations;

  final bool estSuivi;
  final String? statutCompte;
  final DateTime? membreDepuis;

  bool get afficheSonNumero =>
      telephone != null && telephone!.trim().isNotEmpty;

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

  factory VendeurPublic.depuisJson(Map<String, dynamic> json) => VendeurPublic(
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
        nomCommercial: _texte(json['nom_commercial']),
        nomComplet: _texte(json['nom_complet']),
        photo: _texte(json['photo']),
        localisation: _texte(json['localisation']),
        description: _texte(json['description']),
        telephone: _texte(json['telephone']),
        nombreProduitsActifs:
            (json['nombre_produits_actifs'] as num?)?.toInt() ?? 0,
        nombreAbonnes: (json['nombre_abonnes'] as num?)?.toInt() ?? 0,
        nombreProduitsPublies:
            (json['nombre_produits_publies'] as num?)?.toInt() ?? 0,
        nombreProduitsEnRupture:
            (json['nombre_produits_en_rupture'] as num?)?.toInt() ?? 0,
        noteMoyenne: _nombre(json['note_moyenne']),
        nombreEvaluations: (json['nombre_evaluations'] as num?)?.toInt() ?? 0,
        estSuivi: json['est_suivi'] as bool? ?? false,
        statutCompte: _texte(json['statut_compte']),
        membreDepuis: DateTime.tryParse(json['date_joined']?.toString() ?? ''),
      );
}

String? _texte(dynamic valeur) {
  if (valeur == null) return null;
  final texte = valeur.toString().trim();
  return texte.isEmpty ? null : texte;
}

double? _nombre(dynamic valeur) {
  if (valeur == null) return null;
  if (valeur is num) return valeur.toDouble();
  return double.tryParse(valeur.toString());
}
