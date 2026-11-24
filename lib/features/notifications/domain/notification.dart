/// Ce vers quoi une notification conduit quand on l'ouvre.
///
/// Le serveur donne `reference_type` et `reference_id` : c'est lui qui
/// decide de la cible, le client n'a qu'a traduire en route. Les six
/// valeurs ci-dessous sont celles que le module 12 emet reellement.
enum CibleNotification {
  conversation,
  reservation,
  vente,
  produit,
  evaluation,
  utilisateur,
  aucune;

  static CibleNotification depuisCode(String? code) {
    switch ((code ?? '').toLowerCase()) {
      case 'conversation':
        return CibleNotification.conversation;
      case 'reservation':
        return CibleNotification.reservation;
      case 'vente':
        return CibleNotification.vente;
      case 'produit':
        return CibleNotification.produit;
      case 'evaluation':
        return CibleNotification.evaluation;
      case 'utilisateur':
        return CibleNotification.utilisateur;
      default:
        return CibleNotification.aucune;
    }
  }
}

/// Famille d'une notification, pour choisir son icone et sa couleur.
///
/// On regroupe volontairement : il existe une dizaine de types cote
/// serveur, mais cinq familles suffisent a l'oeil, et un type inconnu
/// retombe sur « autre » au lieu de casser l'affichage.
enum FamilleNotification {
  message,
  reservation,
  vente,
  stock,
  avis,
  administration,
  autre;

  static FamilleNotification depuisType(String type) {
    final code = type.toUpperCase();
    if (code.startsWith('MESSAGE')) return FamilleNotification.message;
    if (code.startsWith('RESERVATION')) return FamilleNotification.reservation;
    if (code.startsWith('ACHAT') || code.startsWith('VENTE')) {
      return FamilleNotification.vente;
    }
    if (code.startsWith('STOCK')) return FamilleNotification.stock;
    if (code.startsWith('AVIS')) return FamilleNotification.avis;
    if (code.startsWith('COMPTE') || code.startsWith('ANNONCE_')) {
      return FamilleNotification.administration;
    }
    if (code.startsWith('FAVORI') || code.startsWith('VENDEUR_')) {
      return FamilleNotification.autre;
    }
    return FamilleNotification.autre;
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.typeNotification,
    this.typeLibelle = '',
    this.titre = '',
    this.message = '',
    this.referenceType,
    this.referenceId,
    this.donnees = const {},
    this.estLue = false,
    this.lueLe,
    this.creeLe,
  });

  final int id;
  final String typeNotification;
  final String typeLibelle;
  final String titre;
  final String message;

  final String? referenceType;
  final int? referenceId;

  /// Charge utile libre selon le type. Lue avec prudence : son contenu
  /// depend de l'evenement et peut changer sans que le client casse.
  final Map<String, dynamic> donnees;

  final bool estLue;
  final DateTime? lueLe;
  final DateTime? creeLe;

  CibleNotification get cible => CibleNotification.depuisCode(referenceType);
  FamilleNotification get famille =>
      FamilleNotification.depuisType(typeNotification);

  bool get peutSOuvrir =>
      cible != CibleNotification.aucune && (referenceId ?? 0) > 0;

  NotificationItem copyWith({bool? estLue, DateTime? lueLe}) =>
      NotificationItem(
        id: id,
        typeNotification: typeNotification,
        typeLibelle: typeLibelle,
        titre: titre,
        message: message,
        referenceType: referenceType,
        referenceId: referenceId,
        donnees: donnees,
        estLue: estLue ?? this.estLue,
        lueLe: lueLe ?? this.lueLe,
        creeLe: creeLe,
      );

  factory NotificationItem.depuisJson(Map<String, dynamic> json) {
    final brutDonnees = json['donnees'];
    return NotificationItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      typeNotification: json['type_notification'] as String? ?? '',
      typeLibelle: json['type_libelle'] as String? ?? '',
      titre: json['titre'] as String? ?? '',
      message: json['message'] as String? ?? '',
      referenceType: _texte(json['reference_type']),
      referenceId: (json['reference_id'] as num?)?.toInt(),
      donnees: brutDonnees is Map<String, dynamic> ? brutDonnees : const {},
      estLue: json['est_lue'] as bool? ?? false,
      lueLe: DateTime.tryParse(json['lu_le']?.toString() ?? ''),
      creeLe: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

String? _texte(dynamic valeur) {
  if (valeur == null) return null;
  final texte = valeur.toString().trim();
  return texte.isEmpty ? null : texte;
}
