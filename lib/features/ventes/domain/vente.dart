/// Cycle de vie d'une vente (module 9).
///
/// Le double accusé est la regle importante : le vendeur declare avoir
/// recu le paiement (`paid`), puis l'ACHETEUR confirme avoir recu le
/// produit (`completed`). Cette seconde confirmation empeche un vendeur de
/// se fabriquer de bonnes notes avec de fausses ventes — seule une vente
/// `completed` ouvre le droit a un avis.
enum StatutVente {
  initiated,
  paid,
  completed,
  cancelled,
  refunded,
  inconnu;

  static StatutVente depuisCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'INITIATED':
        return StatutVente.initiated;
      case 'PAID':
        return StatutVente.paid;
      case 'COMPLETED':
        return StatutVente.completed;
      case 'CANCELLED':
        return StatutVente.cancelled;
      case 'REFUNDED':
        return StatutVente.refunded;
      default:
        return StatutVente.inconnu;
    }
  }

  bool get estTerminee => this == StatutVente.completed;

  bool get estAnnulee =>
      this == StatutVente.cancelled || this == StatutVente.refunded;
}

/// Moyens de paiement DECLARATIFS. Il n'y a aucune passerelle de paiement :
/// l'application n'encaisse rien et ne verifie aucun transfert. L'interface
/// doit le dire, sinon l'utilisateur croira a un paiement en ligne.
enum MoyenPaiement {
  cash('CASH', 'Especes'),
  lumicash('LUMICASH', 'Lumicash'),
  ecocash('ECOCASH', 'EcoCash'),
  virement('VIREMENT', 'Virement bancaire'),
  autre('AUTRE', 'Autre');

  const MoyenPaiement(this.code, this.libelle);

  final String code;
  final String libelle;

  static MoyenPaiement depuisCode(String? code) {
    for (final moyen in MoyenPaiement.values) {
      if (moyen.code == (code ?? '').toUpperCase()) return moyen;
    }
    return MoyenPaiement.cash;
  }
}

/// Role du lecteur, calcule par le serveur.
enum RoleVente {
  acheteur,
  vendeur,
  aucun;

  static RoleVente depuisCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'ACHETEUR':
        return RoleVente.acheteur;
      case 'VENDEUR':
        return RoleVente.vendeur;
      default:
        return RoleVente.aucun;
    }
  }

  bool get estAcheteur => this == RoleVente.acheteur;
  bool get estVendeur => this == RoleVente.vendeur;
}

/// Une ligne de vente, avec son prix FIGE.
///
/// Changer le prix de l'annonce ensuite ne modifie aucun revenu passe :
/// c'est pour cela que le prix est porte par la ligne et non lu sur le
/// produit.
class LigneVente {
  const LigneVente({
    required this.id,
    required this.produitId,
    required this.produitTitre,
    required this.quantite,
    required this.prixUnitaire,
    required this.sousTotal,
    this.produitSlug,
  });

  final int id;
  final int produitId;
  final String produitTitre;
  final String? produitSlug;
  final int quantite;
  final double prixUnitaire;
  final double sousTotal;

  factory LigneVente.depuisJson(Map<String, dynamic> json) => LigneVente(
        id: (json['id'] as num?)?.toInt() ?? 0,
        produitId: (json['produit'] as num?)?.toInt() ?? 0,
        produitTitre: json['produit_titre'] as String? ?? '',
        produitSlug: json['produit_slug'] as String?,
        quantite: (json['quantite'] as num?)?.toInt() ?? 0,
        prixUnitaire: _nombre(json['prix_unitaire']) ?? 0,
        sousTotal: _nombre(json['sous_total']) ?? 0,
      );
}

class Vente {
  const Vente({
    required this.id,
    this.reservationId,
    this.acheteurId,
    this.acheteurUsername,
    this.vendeurId,
    this.vendeurUsername,
    this.lignes = const [],
    this.quantiteTotale = 0,
    this.montantTotal = 0,
    this.devise = 'BIF',
    this.moyenPaiement = MoyenPaiement.cash,
    this.moyenPaiementLibelle = '',
    this.statut = StatutVente.inconnu,
    this.statutLibelle = '',
    this.statutPaiement = '',
    this.estComptabilisable = false,
    this.note = '',
    this.confirmeeLe,
    this.confirmeeParAcheteurLe,
    this.annuleeLe,
    this.motifAnnulation = '',
    this.monRole = RoleVente.aucun,
    this.creeLe,
  });

  final int id;
  final int? reservationId;

  final int? acheteurId;
  final String? acheteurUsername;
  final int? vendeurId;
  final String? vendeurUsername;

  final List<LigneVente> lignes;
  final int quantiteTotale;
  final double montantTotal;
  final String devise;

  final MoyenPaiement moyenPaiement;
  final String moyenPaiementLibelle;

  final StatutVente statut;
  final String statutLibelle;
  final String statutPaiement;

  /// Dit d'un coup d'oeil si la vente compte dans le chiffre d'affaires.
  final bool estComptabilisable;

  final String note;
  final DateTime? confirmeeLe;
  final DateTime? confirmeeParAcheteurLe;
  final DateTime? annuleeLe;
  final String motifAnnulation;

  final RoleVente monRole;
  final DateTime? creeLe;

  String get titreResume => lignes.isEmpty
      ? 'Vente #$id'
      : (lignes.length == 1
          ? lignes.first.produitTitre
          : '${lignes.first.produitTitre} + ${lignes.length - 1}');

  String? get imageIndisponible => null;

  /// Le vendeur declare le paiement recu.
  bool get jePeuxConfirmerLePaiement =>
      monRole.estVendeur && statut == StatutVente.initiated;

  /// L'acheteur confirme la reception. C'est ce geste qui termine la vente
  /// et ouvre le droit a l'avis.
  bool get jePeuxConfirmerLaReception =>
      monRole.estAcheteur && statut == StatutVente.paid;

  bool get jePeuxAnnuler =>
      monRole.estVendeur &&
      (statut == StatutVente.initiated || statut == StatutVente.paid);

  /// Un avis n'est possible que sur une vente terminee.
  bool get ouvreLeDroitAUnAvis =>
      monRole.estAcheteur && statut == StatutVente.completed;

  factory Vente.depuisJson(Map<String, dynamic> json) {
    final brutLignes = json['lignes'];

    return Vente(
      id: (json['id'] as num?)?.toInt() ?? 0,
      reservationId: (json['reservation'] as num?)?.toInt(),
      acheteurId: (json['acheteur'] as num?)?.toInt(),
      acheteurUsername: json['acheteur_username'] as String?,
      vendeurId: (json['vendeur'] as num?)?.toInt(),
      vendeurUsername: json['vendeur_username'] as String?,
      lignes: brutLignes is List
          ? brutLignes
              .whereType<Map<String, dynamic>>()
              .map(LigneVente.depuisJson)
              .toList(growable: false)
          : const [],
      quantiteTotale: (json['quantite_totale'] as num?)?.toInt() ?? 0,
      montantTotal: _nombre(json['montant_total']) ?? 0,
      devise: json['devise'] as String? ?? 'BIF',
      moyenPaiement: MoyenPaiement.depuisCode(json['moyen_paiement'] as String?),
      moyenPaiementLibelle: json['moyen_paiement_libelle'] as String? ?? '',
      statut: StatutVente.depuisCode(json['statut'] as String?),
      statutLibelle: json['statut_libelle'] as String? ?? '',
      statutPaiement: json['statut_paiement'] as String? ?? '',
      estComptabilisable: json['est_comptabilisable'] as bool? ?? false,
      note: json['note'] as String? ?? '',
      confirmeeLe: DateTime.tryParse(json['confirmee_le']?.toString() ?? ''),
      confirmeeParAcheteurLe: DateTime.tryParse(
        json['confirmee_par_acheteur_le']?.toString() ?? '',
      ),
      annuleeLe: DateTime.tryParse(json['annulee_le']?.toString() ?? ''),
      motifAnnulation: json['motif_annulation'] as String? ?? '',
      monRole: RoleVente.depuisCode(json['mon_role'] as String?),
      creeLe: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

/// Totaux de `/sales/summary/`.
class Revenus {
  const Revenus({
    this.ventesConfirmees = 0,
    this.quantiteVendue = 0,
    this.chiffreAffaires = 0,
    this.ventesEnAttenteDeConfirmation = 0,
    this.ventesAnnulees = 0,
    this.nombreClients = 0,
  });

  final int ventesConfirmees;
  final int quantiteVendue;
  final double chiffreAffaires;
  final int ventesEnAttenteDeConfirmation;
  final int ventesAnnulees;
  final int nombreClients;

  factory Revenus.depuisJson(Map<String, dynamic> json) => Revenus(
        ventesConfirmees: (json['ventes_confirmees'] as num?)?.toInt() ?? 0,
        quantiteVendue: (json['quantite_vendue'] as num?)?.toInt() ?? 0,
        chiffreAffaires: _nombre(json['chiffre_affaires']) ?? 0,
        ventesEnAttenteDeConfirmation:
            (json['ventes_en_attente_de_confirmation'] as num?)?.toInt() ?? 0,
        ventesAnnulees: (json['ventes_annulees'] as num?)?.toInt() ?? 0,
        nombreClients: (json['nombre_clients'] as num?)?.toInt() ?? 0,
      );
}

double? _nombre(dynamic valeur) {
  if (valeur == null) return null;
  if (valeur is num) return valeur.toDouble();
  return double.tryParse(valeur.toString());
}
