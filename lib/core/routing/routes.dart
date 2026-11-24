/// Noms des routes.
///
/// On navigue par NOM et jamais par chemin ecrit en dur : une faute de
/// frappe dans `context.go('/acceuil')` ne se voit qu'a l'execution, alors
/// qu'une constante inexistante ne compile pas.
class Routes {
  const Routes._();

  // --- demarrage et authentification ----------------------------------
  static const demarrage = 'demarrage';
  static const connexion = 'connexion';
  static const inscription = 'inscription';
  static const verificationEmail = 'verification-email';
  static const motDePasseOublie = 'mot-de-passe-oublie';

  // --- coquille principale ---------------------------------------------
  static const accueil = 'accueil';
  static const recherche = 'recherche';
  static const favoris = 'favoris';
  static const messages = 'messages';
  static const compte = 'compte';
  static const produit = 'produit';
  static const mesAnnonces = 'mes-annonces';
  static const nouvelleAnnonce = 'nouvelle-annonce';
  static const modifierAnnonce = 'modifier-annonce';
  static const mesListes = 'mes-listes';
  static const conversation = 'conversation';
  static const boutique = 'boutique';
  static const mesReservations = 'mes-reservations';
  static const reservation = 'reservation';
  static const mesVentes = 'mes-ventes';
  static const vente = 'vente';
  static const notifications = 'notifications';

  // --- chemins ----------------------------------------------------------
  static const cheminDemarrage = '/';
  static const cheminConnexion = '/connexion';
  static const cheminInscription = '/inscription';
  static const cheminVerificationEmail = '/verification-email';
  static const cheminMotDePasseOublie = '/mot-de-passe-oublie';
  static const cheminAccueil = '/accueil';
  static const cheminRecherche = '/recherche';
  static const cheminFavoris = '/favoris';
  static const cheminMessages = '/messages';
  static const cheminCompte = '/compte';
  static const cheminProduit = '/produit/:id';
  static const cheminMesAnnonces = '/mes-annonces';
  static const cheminNouvelleAnnonce = '/annonce/nouvelle';
  static const cheminModifierAnnonce = '/annonce/:id/modifier';
  static const cheminMesListes = '/mes-listes';
  static const cheminConversation = '/conversation/:id';
  static const cheminBoutique = '/boutique/:id';
  static const cheminMesReservations = '/reservations';
  static const cheminReservation = '/reservations/:id';
  static const cheminMesVentes = '/ventes';
  static const cheminVente = '/ventes/:id';
  static const cheminNotifications = '/notifications';
}
