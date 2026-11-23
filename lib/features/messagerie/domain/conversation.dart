/// Interlocuteur d'une conversation : l'autre personne, quelle que soit
/// sa position (acheteur ou vendeur).
///
/// Le serveur calcule ce champ selon QUI consulte : il n'y a donc jamais
/// a comparer des identifiants cote mobile pour savoir qui est « l'autre ».
class Interlocuteur {
  const Interlocuteur({
    required this.id,
    required this.username,
    this.nomCommercial,
    this.nomComplet,
    this.photo,
    this.localisation,
  });

  final int id;
  final String username;
  final String? nomCommercial;
  final String? nomComplet;
  final String? photo;
  final String? localisation;

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

  factory Interlocuteur.depuisJson(Map<String, dynamic> json) =>
      Interlocuteur(
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
        nomCommercial: _texte(json['nom_commercial']),
        nomComplet: _texte(json['nom_complet']),
        photo: _texte(json['photo']),
        localisation: _texte(json['localisation']),
      );
}

/// Apercu du produit discute, tel que la conversation le porte.
class ProduitConversation {
  const ProduitConversation({
    required this.id,
    required this.titre,
    required this.prix,
    this.devise = 'BIF',
    this.image,
    this.statut,
  });

  final int id;
  final String titre;
  final double prix;
  final String devise;
  final String? image;
  final String? statut;

  factory ProduitConversation.depuisJson(Map<String, dynamic> json) {
    final brutImage = json['image_principale'];
    return ProduitConversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      titre: json['titre'] as String? ?? '',
      prix: _nombre(json['prix']) ?? 0,
      devise: json['devise'] as String? ?? 'BIF',
      image: brutImage is Map<String, dynamic>
          ? _texte(brutImage['image'])
          : _texte(brutImage),
      statut: _texte(json['status']),
    );
  }
}

/// Un message.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.expediteurId,
    this.expediteurUsername,
    this.contenu = '',
    this.image,
    this.estLu = false,
    this.luLe,
    this.estDeMoi = false,
    this.creeLe,
    this.enCoursEnvoi = false,
    this.echecEnvoi = false,
  });

  final int id;
  final int conversationId;
  final int expediteurId;
  final String? expediteurUsername;
  final String contenu;
  final String? image;
  final bool estLu;
  final DateTime? luLe;

  /// Calcule par le serveur selon qui consulte.
  final bool estDeMoi;

  final DateTime? creeLe;

  // --- etats purement locaux ------------------------------------------
  /// Message affiche AVANT la confirmation du serveur, pour que la bulle
  /// apparaisse a l'instant ou on appuie sur envoyer.
  final bool enCoursEnvoi;
  final bool echecEnvoi;

  bool get aUneImage => image != null && image!.isNotEmpty;
  bool get estVide => contenu.trim().isEmpty && !aUneImage;

  /// Decode un message.
  ///
  /// `moiId` est indispensable pour les messages recus par WebSocket : la
  /// charge utile diffusee est IDENTIQUE pour les deux participants du
  /// groupe et ne contient donc pas `est_de_moi`, contrairement a celle de
  /// l'API REST. Sans ce repli, mes propres messages pousses par le canal
  /// s'afficheraient du cote de l'interlocuteur.
  factory Message.depuisJson(Map<String, dynamic> json, {int? moiId}) {
    final expediteurId = (json['expediteur'] as num?)?.toInt() ?? 0;
    final declare = json['est_de_moi'];

    return Message(
      id: (json['id'] as num?)?.toInt() ?? 0,
      conversationId: (json['conversation'] as num?)?.toInt() ?? 0,
      expediteurId: expediteurId,
      expediteurUsername: _texte(json['expediteur_username']),
      contenu: json['contenu'] as String? ?? '',
      image: _texte(json['image']),
      estLu: json['est_lu'] as bool? ?? false,
      luLe: DateTime.tryParse(json['lu_le']?.toString() ?? ''),
      estDeMoi: declare is bool
          ? declare
          : (moiId != null && expediteurId == moiId),
      creeLe: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  /// Bulle provisoire, le temps de l'aller-retour reseau.
  factory Message.provisoire({
    required int conversationId,
    required int expediteurId,
    required String contenu,
  }) =>
      Message(
        // Identifiant negatif : il ne peut entrer en collision avec aucun
        // identifiant du serveur, ce qui permet de remplacer la bulle
        // provisoire par la vraie sans ambiguite.
        id: -DateTime.now().millisecondsSinceEpoch,
        conversationId: conversationId,
        expediteurId: expediteurId,
        contenu: contenu,
        estDeMoi: true,
        creeLe: DateTime.now(),
        enCoursEnvoi: true,
      );

  Message copyWith({bool? enCoursEnvoi, bool? echecEnvoi, bool? estLu}) =>
      Message(
        id: id,
        conversationId: conversationId,
        expediteurId: expediteurId,
        expediteurUsername: expediteurUsername,
        contenu: contenu,
        image: image,
        estLu: estLu ?? this.estLu,
        luLe: luLe,
        estDeMoi: estDeMoi,
        creeLe: creeLe,
        enCoursEnvoi: enCoursEnvoi ?? this.enCoursEnvoi,
        echecEnvoi: echecEnvoi ?? this.echecEnvoi,
      );
}

/// Une conversation entre un acheteur et un vendeur, a propos d'au plus
/// un produit.
class Conversation {
  const Conversation({
    required this.id,
    this.acheteurId,
    this.vendeurId,
    this.interlocuteur,
    this.produit,
    this.prixInitial,
    this.prixActuelProduit,
    this.dernierMessage,
    this.messagesNonLus = 0,
    this.estBloquee = false,
    this.bloqueeParMoi = false,
    this.dernierMessageLe,
    this.creeLe,
  });

  final int id;
  final int? acheteurId;
  final int? vendeurId;
  final Interlocuteur? interlocuteur;
  final ProduitConversation? produit;

  /// Prix FIGE au demarrage de la discussion. Si le vendeur change son
  /// prix ensuite, la negociation garde une trace du point de depart.
  final double? prixInitial;
  final double? prixActuelProduit;

  final Message? dernierMessage;
  final int messagesNonLus;

  final bool estBloquee;

  /// Seul celui qui a bloque peut debloquer : la distinction change le
  /// message affiche et le bouton propose.
  final bool bloqueeParMoi;

  final DateTime? dernierMessageLe;
  final DateTime? creeLe;

  bool get prixAChange =>
      prixInitial != null &&
      prixActuelProduit != null &&
      (prixInitial! - prixActuelProduit!).abs() > 0.009;

  Conversation copyWith({int? messagesNonLus, bool? estBloquee, bool? bloqueeParMoi}) =>
      Conversation(
        id: id,
        acheteurId: acheteurId,
        vendeurId: vendeurId,
        interlocuteur: interlocuteur,
        produit: produit,
        prixInitial: prixInitial,
        prixActuelProduit: prixActuelProduit,
        dernierMessage: dernierMessage,
        messagesNonLus: messagesNonLus ?? this.messagesNonLus,
        estBloquee: estBloquee ?? this.estBloquee,
        bloqueeParMoi: bloqueeParMoi ?? this.bloqueeParMoi,
        dernierMessageLe: dernierMessageLe,
        creeLe: creeLe,
      );

  factory Conversation.depuisJson(Map<String, dynamic> json) {
    final brutInterlocuteur = json['interlocuteur'];
    final brutProduit = json['produit'];
    final brutDernier = json['dernier_message'];

    return Conversation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      acheteurId: (json['acheteur'] as num?)?.toInt(),
      vendeurId: (json['vendeur'] as num?)?.toInt(),
      interlocuteur: brutInterlocuteur is Map<String, dynamic>
          ? Interlocuteur.depuisJson(brutInterlocuteur)
          : null,
      produit: brutProduit is Map<String, dynamic>
          ? ProduitConversation.depuisJson(brutProduit)
          : null,
      prixInitial: _nombre(json['prix_initial']),
      prixActuelProduit: _nombre(json['prix_actuel_produit']),
      dernierMessage: brutDernier is Map<String, dynamic>
          ? Message.depuisJson(brutDernier)
          : null,
      messagesNonLus: (json['messages_non_lus'] as num?)?.toInt() ?? 0,
      estBloquee: json['est_bloquee'] as bool? ?? false,
      bloqueeParMoi: json['bloquee_par_moi'] as bool? ?? false,
      dernierMessageLe:
          DateTime.tryParse(json['dernier_message_le']?.toString() ?? ''),
      creeLe: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
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
