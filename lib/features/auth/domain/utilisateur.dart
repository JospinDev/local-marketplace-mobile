/// Statut d'un compte, tel que le backend le renvoie.
enum StatutCompte { actif, suspendu, inconnu }

/// Compte de l'utilisateur connecte.
///
/// Le backend ne distingue pas « acheteur » et « vendeur » : un seul compte
/// fait les deux. Il ne faut donc PAS inventer de role cote application —
/// c'est explicitement rappele par le guide d'integration.
class Utilisateur {
  const Utilisateur({
    required this.id,
    required this.username,
    this.email,
    this.emailVerifie = false,
    this.nomComplet,
    this.telephone,
    this.photo,
    this.localisation,
    this.nomCommercial,
    this.description,
    this.telephonePublic = false,
    this.statutCompte = StatutCompte.actif,
    this.motifSuspension,
    this.estActif = true,
    this.estSuperutilisateur = false,
    this.groupes = const [],
    this.permissions = const [],
  });

  final int id;
  final String username;
  final String? email;
  final bool emailVerifie;
  final String? nomComplet;
  final String? telephone;
  final String? photo;
  final String? localisation;

  /// Vitrine commerciale : visible de tous des que le compte publie.
  final String? nomCommercial;
  final String? description;
  final bool telephonePublic;

  final StatutCompte statutCompte;
  final String? motifSuspension;
  final bool estActif;
  final bool estSuperutilisateur;
  final List<String> groupes;
  final List<String> permissions;

  /// Nom a afficher : le commercial d'abord, puis le civil, puis
  /// l'identifiant. On n'affiche jamais un champ vide.
  String get nomAffiche {
    for (final candidat in [nomCommercial, nomComplet]) {
      if (candidat != null && candidat.trim().isNotEmpty) return candidat.trim();
    }
    return username;
  }

  /// Initiales pour l'avatar de repli, quand il n'y a pas de photo.
  String get initiales {
    final nom = nomAffiche.trim();
    final mots = nom.split(RegExp(r'\s+'));
    if (mots.length >= 2 && mots[0].isNotEmpty && mots[1].isNotEmpty) {
      return (mots[0][0] + mots[1][0]).toUpperCase();
    }
    if (nom.isEmpty) return '?';
    return nom.substring(0, nom.length >= 2 ? 2 : 1).toUpperCase();
  }

  bool get estSuspendu => statutCompte == StatutCompte.suspendu;

  /// Vrai quand le compte peut ecrire (publier, reserver, discuter).
  bool get peutAgir => estActif && !estSuspendu;

  factory Utilisateur.depuisJson(Map<String, dynamic> json) {
    return Utilisateur(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: json['username'] as String? ?? '',
      email: _texte(json['email']),
      emailVerifie: json['email_verifie'] as bool? ?? false,
      nomComplet: _texte(json['nom_complet']),
      telephone: _texte(json['telephone']),
      photo: _texte(json['photo']),
      localisation: _texte(json['localisation']),
      nomCommercial: _texte(json['nom_commercial']),
      description: _texte(json['description']),
      telephonePublic: json['telephone_public'] as bool? ?? false,
      statutCompte: _statut(json['statut_compte'] as String?),
      motifSuspension: _texte(json['motif_suspension']),
      estActif: json['is_active'] as bool? ?? true,
      estSuperutilisateur: json['is_superuser'] as bool? ?? false,
      groupes: _liste(json['groupes']),
      permissions: _liste(json['permissions']),
    );
  }

  static String? _texte(dynamic valeur) {
    if (valeur == null) return null;
    final texte = valeur.toString().trim();
    return texte.isEmpty ? null : texte;
  }

  static List<String> _liste(dynamic valeur) {
    if (valeur is List) return valeur.map((e) => e.toString()).toList();
    return const [];
  }

  static StatutCompte _statut(String? brut) {
    switch (brut) {
      case 'ACTIF':
        return StatutCompte.actif;
      case 'SUSPENDU':
        return StatutCompte.suspendu;
      default:
        return brut == null ? StatutCompte.actif : StatutCompte.inconnu;
    }
  }

  Utilisateur copyWith({
    String? nomComplet,
    String? telephone,
    String? photo,
    String? localisation,
    String? nomCommercial,
    String? description,
    bool? telephonePublic,
  }) {
    return Utilisateur(
      id: id,
      username: username,
      email: email,
      emailVerifie: emailVerifie,
      nomComplet: nomComplet ?? this.nomComplet,
      telephone: telephone ?? this.telephone,
      photo: photo ?? this.photo,
      localisation: localisation ?? this.localisation,
      nomCommercial: nomCommercial ?? this.nomCommercial,
      description: description ?? this.description,
      telephonePublic: telephonePublic ?? this.telephonePublic,
      statutCompte: statutCompte,
      motifSuspension: motifSuspension,
      estActif: estActif,
      estSuperutilisateur: estSuperutilisateur,
      groupes: groupes,
      permissions: permissions,
    );
  }
}
