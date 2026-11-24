/// Vue generale du tableau de bord (`/seller-dashboard/overview/`).
class VueGenerale {
  const VueGenerale({
    this.produitsPublies = 0,
    this.produitsDisponibles = 0,
    this.produitsEnRupture = 0,
    this.produitsTotal = 0,
    this.demandesEnAttente = 0,
    this.reservationsEnCours = 0,
    this.ventesConfirmees = 0,
    this.nombreClients = 0,
    this.nombreConversations = 0,
    this.noteMoyenneVendeur,
    this.nombreEvaluations = 0,
  });

  final int produitsPublies;
  final int produitsDisponibles;
  final int produitsEnRupture;
  final int produitsTotal;

  /// Le badge « a traiter » : des demandes attendent une reponse.
  final int demandesEnAttente;
  final int reservationsEnCours;

  final int ventesConfirmees;
  final int nombreClients;
  final int nombreConversations;

  final double? noteMoyenneVendeur;
  final int nombreEvaluations;

  factory VueGenerale.depuisJson(Map<String, dynamic> json) => VueGenerale(
        produitsPublies: _entier(json['produits_publies']),
        produitsDisponibles: _entier(json['produits_disponibles']),
        produitsEnRupture: _entier(json['produits_en_rupture']),
        produitsTotal: _entier(json['produits_total']),
        demandesEnAttente:
            _entier(json['demandes_de_reservation_en_attente']),
        reservationsEnCours: _entier(json['reservations_en_cours']),
        ventesConfirmees: _entier(json['ventes_confirmees']),
        nombreClients: _entier(json['nombre_clients']),
        nombreConversations: _entier(json['nombre_conversations']),
        noteMoyenneVendeur: _nombre(json['note_moyenne_vendeur']),
        nombreEvaluations: _entier(json['nombre_evaluations']),
      );
}

/// Une ligne de revenu, par produit ou par categorie.
class LigneRevenu {
  const LigneRevenu({
    required this.id,
    required this.nom,
    this.revenu = 0,
    this.quantiteVendue = 0,
  });

  final int id;
  final String nom;
  final double revenu;
  final int quantiteVendue;

  /// Les deux formes de la reponse : `par_produit` porte `produit` et
  /// `titre`, `par_categorie` porte `categorie` et `nom`.
  factory LigneRevenu.depuisJson(Map<String, dynamic> json) => LigneRevenu(
        id: _entier(json['produit'] ?? json['categorie']),
        nom: (json['titre'] ?? json['nom'] ?? '').toString(),
        revenu: _nombre(json['revenu']) ?? 0,
        quantiteVendue: _entier(json['quantite_vendue']),
      );
}

/// Revenus (`/seller-dashboard/revenue/`).
///
/// **`chiffreAffairesTotal` et `valeurReservationsEnCours` ne
/// s'additionnent jamais.** Le premier est de l'argent encaisse, le second
/// de la valeur immobilisee par des reservations acceptees — qui peuvent
/// encore expirer ou etre annulees. Les confondre ferait croire a un
/// revenu qui n'existe pas.
class Revenus {
  const Revenus({
    this.chiffreAffairesTotal = 0,
    this.revenusDuJour = 0,
    this.revenusDeLaSemaine = 0,
    this.revenusDuMois = 0,
    this.valeurReservationsEnCours = 0,
    this.quantiteVendue = 0,
    this.ventesEnAttenteDeConfirmation = 0,
    this.devise = 'BIF',
    this.parProduit = const [],
    this.parCategorie = const [],
  });

  final double chiffreAffairesTotal;

  /// Mesures a la date de CONFIRMATION du paiement : le moment ou
  /// l'argent est entre, et non celui de la commande.
  final double revenusDuJour;
  final double revenusDeLaSemaine;
  final double revenusDuMois;

  final double valeurReservationsEnCours;
  final int quantiteVendue;
  final int ventesEnAttenteDeConfirmation;
  final String devise;

  /// Deja triees par revenu decroissant cote serveur : aucun tri a
  /// refaire ici.
  final List<LigneRevenu> parProduit;
  final List<LigneRevenu> parCategorie;

  factory Revenus.depuisJson(Map<String, dynamic> json) => Revenus(
        chiffreAffairesTotal: _nombre(json['chiffre_affaires_total']) ?? 0,
        revenusDuJour: _nombre(json['revenus_du_jour']) ?? 0,
        revenusDeLaSemaine: _nombre(json['revenus_de_la_semaine']) ?? 0,
        revenusDuMois: _nombre(json['revenus_du_mois']) ?? 0,
        valeurReservationsEnCours:
            _nombre(json['valeur_reservations_en_cours']) ?? 0,
        quantiteVendue: _entier(json['quantite_vendue']),
        ventesEnAttenteDeConfirmation:
            _entier(json['ventes_en_attente_de_confirmation']),
        devise: json['devise'] as String? ?? 'BIF',
        parProduit: _lignes(json['par_produit']),
        parCategorie: _lignes(json['par_categorie']),
      );
}

/// Une ligne d'inventaire.
class LigneStock {
  const LigneStock({
    required this.produitId,
    required this.titre,
    this.statut = '',
    this.prix = 0,
    this.quantiteTotale = 0,
    this.quantiteDisponible = 0,
    this.quantiteReservee = 0,
    this.quantiteVendue = 0,
  });

  final int produitId;
  final String titre;
  final String statut;
  final double prix;
  final int quantiteTotale;
  final int quantiteDisponible;
  final int quantiteReservee;
  final int quantiteVendue;

  bool get estEnRupture => quantiteDisponible == 0;

  factory LigneStock.depuisJson(Map<String, dynamic> json) => LigneStock(
        produitId: _entier(json['produit']),
        titre: json['titre'] as String? ?? '',
        statut: json['statut'] as String? ?? '',
        prix: _nombre(json['prix']) ?? 0,
        quantiteTotale: _entier(json['quantite_totale']),
        quantiteDisponible: _entier(json['quantite_disponible']),
        quantiteReservee: _entier(json['quantite_reservee']),
        quantiteVendue: _entier(json['quantite_vendue']),
      );
}

/// Inventaire (`/seller-dashboard/inventory/`).
class Inventaire {
  const Inventaire({
    this.stockTotal = 0,
    this.quantiteDisponible = 0,
    this.quantiteReservee = 0,
    this.quantiteVendue = 0,
    this.valeurStockDisponible = 0,
    this.valeurReservationsEnCours = 0,
    this.parProduit = const [],
  });

  final int stockTotal;
  final int quantiteDisponible;
  final int quantiteReservee;
  final int quantiteVendue;

  final double valeurStockDisponible;
  final double valeurReservationsEnCours;

  final List<LigneStock> parProduit;

  List<LigneStock> get enRupture =>
      parProduit.where((l) => l.estEnRupture).toList(growable: false);

  factory Inventaire.depuisJson(Map<String, dynamic> json) {
    final brut = json['par_produit'];
    return Inventaire(
      stockTotal: _entier(json['stock_total']),
      quantiteDisponible: _entier(json['quantite_disponible']),
      quantiteReservee: _entier(json['quantite_reservee']),
      quantiteVendue: _entier(json['quantite_vendue']),
      valeurStockDisponible: _nombre(json['valeur_stock_disponible']) ?? 0,
      valeurReservationsEnCours:
          _nombre(json['valeur_reservations_en_cours']) ?? 0,
      parProduit: brut is List
          ? brut
              .whereType<Map<String, dynamic>>()
              .map(LigneStock.depuisJson)
              .toList(growable: false)
          : const [],
    );
  }
}

/// Compteurs de reservations (`/seller-dashboard/reservations/`).
class StatistiquesReservations {
  const StatistiquesReservations({
    this.enAttente = 0,
    this.acceptees = 0,
    this.annulees = 0,
    this.expirees = 0,
    this.transformeesEnVente = 0,
    this.quantiteImmobilisee = 0,
    this.tauxDeTransformation = 0,
  });

  final int enAttente;
  final int acceptees;
  final int annulees;
  final int expirees;
  final int transformeesEnVente;
  final int quantiteImmobilisee;

  /// Part des demandes devenues des ventes, en pourcentage.
  final double tauxDeTransformation;

  factory StatistiquesReservations.depuisJson(Map<String, dynamic> json) =>
      StatistiquesReservations(
        enAttente: _entier(json['en_attente']),
        acceptees: _entier(json['acceptees']),
        annulees: _entier(json['annulees']),
        expirees: _entier(json['expirees']),
        transformeesEnVente: _entier(json['transformees_en_vente']),
        quantiteImmobilisee: _entier(json['quantite_immobilisee']),
        tauxDeTransformation: _nombre(json['taux_de_transformation']) ?? 0,
      );
}

/// Une entree du palmares.
class ProduitPalmares {
  const ProduitPalmares({
    required this.produitId,
    required this.titre,
    this.prix = 0,
    this.revenu,
    this.quantiteVendue,
    this.nombreVentes,
    this.nombreVues,
    this.noteMoyenne,
    this.quantiteDisponible,
  });

  final int produitId;
  final String titre;
  final double prix;

  // Renseignes pour « les plus vendus ».
  final double? revenu;
  final int? quantiteVendue;
  final int? nombreVentes;

  // Renseignes pour « les plus consultes ».
  final int? nombreVues;
  final double? noteMoyenne;
  final int? quantiteDisponible;

  factory ProduitPalmares.depuisJson(Map<String, dynamic> json) =>
      ProduitPalmares(
        produitId: _entier(json['produit']),
        titre: json['titre'] as String? ?? '',
        prix: _nombre(json['prix']) ?? 0,
        revenu: _nombre(json['revenu']),
        quantiteVendue: json['quantite_vendue'] == null
            ? null
            : _entier(json['quantite_vendue']),
        nombreVentes: json['nombre_ventes'] == null
            ? null
            : _entier(json['nombre_ventes']),
        nombreVues:
            json['nombre_vues'] == null ? null : _entier(json['nombre_vues']),
        noteMoyenne: _nombre(json['note_moyenne']),
        quantiteDisponible: json['quantite_disponible'] == null
            ? null
            : _entier(json['quantite_disponible']),
      );
}

/// Palmares (`/seller-dashboard/top-products/`).
class Palmares {
  const Palmares({this.lesPlusVendus = const [], this.lesPlusConsultes = const []});

  final List<ProduitPalmares> lesPlusVendus;
  final List<ProduitPalmares> lesPlusConsultes;

  bool get estVide => lesPlusVendus.isEmpty && lesPlusConsultes.isEmpty;

  factory Palmares.depuisJson(Map<String, dynamic> json) => Palmares(
        lesPlusVendus: _palmares(json['les_plus_vendus']),
        lesPlusConsultes: _palmares(json['les_plus_consultes']),
      );
}

List<LigneRevenu> _lignes(dynamic brut) => brut is List
    ? brut
        .whereType<Map<String, dynamic>>()
        .map(LigneRevenu.depuisJson)
        .toList(growable: false)
    : const [];

List<ProduitPalmares> _palmares(dynamic brut) => brut is List
    ? brut
        .whereType<Map<String, dynamic>>()
        .map(ProduitPalmares.depuisJson)
        .toList(growable: false)
    : const [];

int _entier(dynamic valeur) {
  if (valeur is num) return valeur.toInt();
  return int.tryParse(valeur?.toString() ?? '') ?? 0;
}

double? _nombre(dynamic valeur) {
  if (valeur == null) return null;
  if (valeur is num) return valeur.toDouble();
  return double.tryParse(valeur.toString());
}
