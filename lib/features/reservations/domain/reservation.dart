/// Cycle de vie d'une reservation (module 8).
///
/// Le point a ne pas se tromper : **le stock n'est immobilise qu'a
/// l'acceptation du vendeur**. Une demande `pending` ne bloque rien, elle
/// est seulement verifiee contre le disponible du moment. L'interface ne
/// doit donc jamais dire « reserve » avant la confirmation.
enum StatutReservation {
  pending,
  confirmed,
  cancelled,
  expired,
  fulfilled,
  inconnu;

  static StatutReservation depuisCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'PENDING':
        return StatutReservation.pending;
      case 'CONFIRMED':
        return StatutReservation.confirmed;
      case 'CANCELLED':
        return StatutReservation.cancelled;
      case 'EXPIRED':
        return StatutReservation.expired;
      case 'FULFILLED':
        return StatutReservation.fulfilled;
      default:
        return StatutReservation.inconnu;
    }
  }

  /// Vrai quand la reservation attend encore quelque chose de quelqu'un.
  bool get estOuverte =>
      this == StatutReservation.pending || this == StatutReservation.confirmed;

  /// Seul `confirmed` immobilise reellement du stock.
  bool get immobiliseDuStock => this == StatutReservation.confirmed;
}

/// Role du lecteur, calcule par le serveur (`mon_role`).
///
/// A preferer a toute comparaison d'identifiants : c'est le serveur qui
/// sait, et les ecrans se construisent autour de ce champ.
enum RoleReservation {
  acheteur,
  vendeur,
  aucun;

  static RoleReservation depuisCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'ACHETEUR':
        return RoleReservation.acheteur;
      case 'VENDEUR':
        return RoleReservation.vendeur;
      default:
        return RoleReservation.aucun;
    }
  }

  bool get estAcheteur => this == RoleReservation.acheteur;
  bool get estVendeur => this == RoleReservation.vendeur;
}

/// Apercu du produit porte par la reservation.
class ProduitReservation {
  const ProduitReservation({
    required this.id,
    required this.titre,
    this.prix,
    this.devise = 'BIF',
    this.image,
    this.statut,
    this.quantiteDisponible,
  });

  final int id;
  final String titre;
  final double? prix;
  final String devise;
  final String? image;
  final String? statut;
  final int? quantiteDisponible;

  factory ProduitReservation.depuisJson(Map<String, dynamic> json) {
    final brutImage = json['image_principale'];
    final brutInventaire = json['inventaire'];

    return ProduitReservation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      titre: json['titre'] as String? ?? '',
      prix: _nombre(json['prix']),
      devise: json['devise'] as String? ?? 'BIF',
      image: brutImage is Map<String, dynamic>
          ? _texte(brutImage['image'])
          : _texte(brutImage),
      statut: _texte(json['status']),
      quantiteDisponible: brutInventaire is Map<String, dynamic>
          ? (brutInventaire['quantite_disponible'] as num?)?.toInt()
          : (json['quantite_disponible'] as num?)?.toInt(),
    );
  }
}

/// Une reservation, vue par l'un ou l'autre des deux participants.
class Reservation {
  const Reservation({
    required this.id,
    required this.produitId,
    this.produit,
    this.acheteurId,
    this.acheteurUsername,
    this.vendeurId,
    this.vendeurUsername,
    this.quantiteDemandee = 0,
    this.quantiteConfirmee = 0,
    this.quantiteLivree = 0,
    this.quantiteImmobilisee = 0,
    this.quantiteNonAchetee = 0,
    this.valeurEstimee,
    this.statut = StatutReservation.inconnu,
    this.statutLibelle = '',
    this.estExpiree = false,
    this.message = '',
    this.expireLe,
    this.confirmeeLe,
    this.clotureeLe,
    this.clotureePar = '',
    this.motif = '',
    this.monRole = RoleReservation.aucun,
    this.creeLe,
  });

  final int id;
  final int produitId;
  final ProduitReservation? produit;

  final int? acheteurId;
  final String? acheteurUsername;
  final int? vendeurId;
  final String? vendeurUsername;

  final int quantiteDemandee;
  final int quantiteConfirmee;
  final int quantiteLivree;

  /// Quantite effectivement mise de cote en ce moment.
  final int quantiteImmobilisee;

  /// Confirmee mais pas encore achetee : ce qui sera libere en cas de
  /// vente partielle ou d'annulation.
  final int quantiteNonAchetee;

  /// **Indicatif**, au prix du jour. Ce n'est PAS un revenu, et il ne faut
  /// jamais l'afficher comme tel.
  final double? valeurEstimee;

  final StatutReservation statut;
  final String statutLibelle;
  final bool estExpiree;
  final String message;

  /// Delai de RETRAIT : le compte a rebours repart a l'acceptation.
  final DateTime? expireLe;

  final DateTime? confirmeeLe;
  final DateTime? clotureeLe;
  final String clotureePar;
  final String motif;

  final RoleReservation monRole;
  final DateTime? creeLe;

  /// Quantite a afficher comme « la quantite qui compte », selon l'etat.
  int get quantiteUtile =>
      statut == StatutReservation.pending ? quantiteDemandee : quantiteConfirmee;

  bool get accepteePartiellement =>
      statut.immobiliseDuStock &&
      quantiteConfirmee > 0 &&
      quantiteConfirmee < quantiteDemandee;

  /// L'acheteur peut changer la quantite tant que rien n'est promis ; une
  /// fois confirmee, c'est le stock du vendeur qui est engage et c'est lui
  /// qui ajuste. Regle inhabituelle, verifiee cote serveur.
  bool get jePeuxChangerLaQuantite {
    if (statut == StatutReservation.pending) return monRole.estAcheteur;
    if (statut == StatutReservation.confirmed) return monRole.estVendeur;
    return false;
  }

  bool get jePeuxAccepter =>
      monRole.estVendeur && statut == StatutReservation.pending && !estExpiree;

  bool get jePeuxRefuser => jePeuxAccepter;

  /// Annuler est ouvert aux deux cotes, tant que la reservation vit.
  bool get jePeuxAnnuler => statut.estOuverte && !monRole.isAucun;

  bool get jePeuxEnregistrerLaVente =>
      monRole.estVendeur && statut == StatutReservation.confirmed;

  factory Reservation.depuisJson(Map<String, dynamic> json) {
    final brutProduit = json['produit_detail'];

    return Reservation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      produitId: (json['produit'] as num?)?.toInt() ?? 0,
      produit: brutProduit is Map<String, dynamic>
          ? ProduitReservation.depuisJson(brutProduit)
          : null,
      acheteurId: (json['acheteur'] as num?)?.toInt(),
      acheteurUsername: _texte(json['acheteur_username']),
      vendeurId: (json['vendeur'] as num?)?.toInt(),
      vendeurUsername: _texte(json['vendeur_username']),
      quantiteDemandee: (json['quantite_demandee'] as num?)?.toInt() ?? 0,
      quantiteConfirmee: (json['quantite_confirmee'] as num?)?.toInt() ?? 0,
      quantiteLivree: (json['quantite_livree'] as num?)?.toInt() ?? 0,
      quantiteImmobilisee: (json['quantite_immobilisee'] as num?)?.toInt() ?? 0,
      quantiteNonAchetee: (json['quantite_non_achetee'] as num?)?.toInt() ?? 0,
      valeurEstimee: _nombre(json['valeur_estimee']),
      statut: StatutReservation.depuisCode(json['statut'] as String?),
      statutLibelle: json['statut_libelle'] as String? ?? '',
      estExpiree: json['est_expiree'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      expireLe: DateTime.tryParse(json['expire_le']?.toString() ?? ''),
      confirmeeLe: DateTime.tryParse(json['confirmee_le']?.toString() ?? ''),
      clotureeLe: DateTime.tryParse(json['cloturee_le']?.toString() ?? ''),
      clotureePar: json['cloturee_par'] as String? ?? '',
      motif: json['motif'] as String? ?? '',
      monRole: RoleReservation.depuisCode(json['mon_role'] as String?),
      creeLe: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

extension on RoleReservation {
  bool get isAucun => this == RoleReservation.aucun;
}

/// Compteurs de `/reservations/summary/`, pour les pastilles.
class ResumeReservations {
  const ResumeReservations({
    this.demandesEnAttente = 0,
    this.demandesAcceptees = 0,
    this.aTraiter = 0,
    this.reservationsAccepteesRecues = 0,
    this.quantiteImmobilisee = 0,
  });

  /// Mes demandes qui attendent une reponse du vendeur.
  final int demandesEnAttente;
  final int demandesAcceptees;

  /// Demandes RECUES qui attendent MA reponse : c'est le seul compteur qui
  /// appelle une action immediate.
  final int aTraiter;

  final int reservationsAccepteesRecues;
  final int quantiteImmobilisee;

  int get total =>
      demandesEnAttente + demandesAcceptees + aTraiter + reservationsAccepteesRecues;

  factory ResumeReservations.depuisJson(Map<String, dynamic> json) =>
      ResumeReservations(
        demandesEnAttente: (json['demandes_en_attente'] as num?)?.toInt() ?? 0,
        demandesAcceptees: (json['demandes_acceptees'] as num?)?.toInt() ?? 0,
        aTraiter: (json['a_traiter'] as num?)?.toInt() ?? 0,
        reservationsAccepteesRecues:
            (json['reservations_acceptees_recues'] as num?)?.toInt() ?? 0,
        quantiteImmobilisee:
            (json['quantite_immobilisee'] as num?)?.toInt() ?? 0,
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
