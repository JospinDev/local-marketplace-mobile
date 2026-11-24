/// Etat de moderation d'un avis.
enum StatutEvaluation {
  visible,
  masquee,
  retiree,
  inconnu;

  static StatutEvaluation depuisCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'VISIBLE':
        return StatutEvaluation.visible;
      case 'MASQUEE':
        return StatutEvaluation.masquee;
      case 'RETIREE':
        return StatutEvaluation.retiree;
      default:
        return StatutEvaluation.inconnu;
    }
  }
}

/// Un avis : **deux notes distinctes**, de 1 a 5.
///
/// `note_produit` juge la qualite de l'article, `note_vendeur` l'accueil,
/// l'exactitude et la ponctualite. L'interface doit montrer deux jeux
/// d'etoiles : les confondre ferait perdre l'information qui distingue un
/// bon produit mal vendu d'un mauvais produit bien vendu.
class Evaluation {
  const Evaluation({
    required this.id,
    required this.venteId,
    this.produitId,
    this.produitTitre = '',
    this.auteurId,
    this.auteurUsername = '',
    this.auteurPhoto,
    this.vendeurId,
    this.vendeurUsername = '',
    this.noteProduit = 0,
    this.noteVendeur = 0,
    this.noteGlobale,
    this.commentaire = '',
    this.statut = StatutEvaluation.inconnu,
    this.statutLibelle = '',
    this.estValide = true,
    this.motifModeration = '',
    this.modifieeLe,
    this.creeLe,
  });

  final int id;
  final int venteId;
  final int? produitId;
  final String produitTitre;

  final int? auteurId;
  final String auteurUsername;
  final String? auteurPhoto;

  final int? vendeurId;
  final String vendeurUsername;

  final int noteProduit;
  final int noteVendeur;
  final double? noteGlobale;
  final String commentaire;

  final StatutEvaluation statut;
  final String statutLibelle;

  /// Faux quand l'avis est masque par la moderation ou retire : il sort
  /// alors des moyennes et des listes publiques.
  final bool estValide;
  final String motifModeration;

  final DateTime? modifieeLe;
  final DateTime? creeLe;

  /// Delai de correction, en heures.
  ///
  /// Le serveur est la SEULE autorite : ce delai est configurable cote
  /// plateforme (`EVALUATION_DELAI_MODIFICATION_HEURES`) et le serializer
  /// ne l'expose pas. On s'en sert uniquement pour afficher un compte a
  /// rebours indicatif et masquer le bouton quand c'est manifestement
  /// trop tard ; en cas de desaccord, c'est le `400` du serveur qui
  /// tranche, et son message est affiche tel quel.
  static const delaiCorrectionHeures = 48;

  Duration? get tempsRestantPourCorriger {
    if (creeLe == null) return null;
    final limite = creeLe!.add(
      const Duration(hours: delaiCorrectionHeures),
    );
    final restant = limite.difference(DateTime.now());
    return restant.isNegative ? null : restant;
  }

  bool get probablementCorrigeable => tempsRestantPourCorriger != null;

  bool get aEteCorrigee => modifieeLe != null;

  factory Evaluation.depuisJson(Map<String, dynamic> json) => Evaluation(
        id: (json['id'] as num?)?.toInt() ?? 0,
        venteId: (json['vente'] as num?)?.toInt() ?? 0,
        produitId: (json['produit'] as num?)?.toInt(),
        produitTitre: json['produit_titre'] as String? ?? '',
        auteurId: (json['auteur'] as num?)?.toInt(),
        auteurUsername: json['auteur_username'] as String? ?? '',
        auteurPhoto: _texte(json['auteur_photo']),
        vendeurId: (json['vendeur'] as num?)?.toInt(),
        vendeurUsername: json['vendeur_username'] as String? ?? '',
        noteProduit: (json['note_produit'] as num?)?.toInt() ?? 0,
        noteVendeur: (json['note_vendeur'] as num?)?.toInt() ?? 0,
        noteGlobale: _nombre(json['note_globale']),
        commentaire: json['commentaire'] as String? ?? '',
        statut: StatutEvaluation.depuisCode(json['statut'] as String?),
        statutLibelle: json['statut_libelle'] as String? ?? '',
        estValide: json['est_valide'] as bool? ?? true,
        motifModeration: json['motif_moderation'] as String? ?? '',
        modifieeLe: DateTime.tryParse(json['modifiee_le']?.toString() ?? ''),
        creeLe: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

// `Reputation` vit dans `catalogue/domain/produit.dart` : la fiche
// produit et la vitrine vendeur s'en servaient avant ce module, et
// deux classes pour une meme notion finissent toujours par diverger.

/// Motifs de signalement d'un avis, tels que le serveur les accepte.
const motifsSignalementAvis = <String, String>{
  'INSULTE': 'Propos insultants',
  'FAUX': 'Avis mensonger',
  'HORS_SUJET': 'Hors sujet',
  'SPAM': 'Spam ou publicite',
  'AUTRE': 'Autre raison',
};

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
