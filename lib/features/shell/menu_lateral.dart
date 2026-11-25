import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/reseau_image.dart';
import '../auth/providers/auth_provider.dart';
import '../favoris/providers/favoris_providers.dart';
import '../messagerie/providers/messagerie_providers.dart';
import '../notifications/providers/notifications_providers.dart';
import '../reservations/providers/reservations_providers.dart';
import '../ventes/providers/ventes_providers.dart';

/// Cle du `Scaffold` qui porte le tiroir.
///
/// Pourquoi une cle globale et non `Scaffold.of(context)` : cette
/// resolution remonte au PLUS PROCHE `Scaffold`, qui n'est pas forcement
/// celui qui porte le tiroir. Quand c'en est un autre,
/// `ScaffoldState.openDrawer()` ne leve rien — il ne trouve simplement
/// aucun `DrawerController` et ne fait RIEN, en silence. Un bouton muet,
/// impossible a diagnostiquer depuis l'ecran.
///
/// Avec cette cle, le bouton vise le Scaffold de la coquille et lui seul,
/// d'ou qu'il soit appuye.
final cleScaffoldCoquille = GlobalKey<ScaffoldState>();

/// Ouvre le menu lateral. Retourne faux si le tiroir est injoignable.
bool ouvrirMenuLateral() {
  final etat = cleScaffoldCoquille.currentState;
  if (etat == null || !etat.hasDrawer) return false;
  etat.openDrawer();
  return true;
}

/// Menu lateral ouvert par l'icone hamburger de l'accueil.
///
/// Il rassemble tout ce qui relevait auparavant de « Mon compte » :
/// reservations, ventes, achats, favoris, annonces. L'onglet Compte garde
/// le profil et la vitrine — ce qu'on y modifie —, tandis que ce menu
/// donne acces a ce qu'on consulte.
class MenuLateral extends ConsumerWidget {
  const MenuLateral({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sombre = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      // Fond explicite : un `Drawer` qui herite d'une surface
      // transparente se confondrait avec la page derriere lui.
      backgroundColor: sombre ? AppColors.encreSurface : AppColors.blanc,

      // Liseret vert sur le bord droit du panneau. C'est aussi un
      // marqueur : s'il est visible, le tiroir affiche est bien celui-ci
      // et non un `Drawer` vide venu d'ailleurs.
      shape: const BorderDirectional(
        end: BorderSide(color: AppColors.emeraude, width: 3),
      ),

      // Structure volontairement MINIMALE : une seule `ListView`, dont
      // l'en-tete est le premier element. La pile precedente
      // (`SafeArea` > `Column` > `Expanded` > `ListView`) empilait quatre
      // widgets de mise en page la ou un seul suffit, et chacun d'eux
      // pouvait faire disparaitre le contenu sans rien signaler.
      //
      // L'encoche est geree par le `padding` plutot que par `SafeArea` :
      // la valeur est lue ici, visible, au lieu d'etre appliquee par un
      // widget intermediaire.
      child: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top,
          bottom: MediaQuery.paddingOf(context).bottom + Espaces.lg,
        ),
        children: [
          const _Entete(),
          const SizedBox(height: Espaces.xs),
          const _Rubrique(libelle: 'Acheter'),
          _Entree(
            icone: Icons.notifications_none_rounded,
            libelle: 'Notifications',
            pastille: _Pastille.notifications,
            onTap: () => _aller(context, Routes.notifications),
          ),
          _Entree(
            icone: Icons.chat_bubble_outline_rounded,
            libelle: 'Messages',
            pastille: _Pastille.messages,
            onTap: () => _allerOnglet(context, Routes.messages),
          ),
          _Entree(
            icone: Icons.bookmark_border_rounded,
            libelle: 'Mes demandes de reservation',
            pastille: _Pastille.demandesEnvoyees,
            onTap: () => _aller(
              context,
              Routes.mesReservations,
              parametres: {'onglet': '0'},
            ),
          ),
          _Entree(
            icone: Icons.shopping_bag_outlined,
            libelle: 'Mes achats',
            pastille: _Pastille.achatsAConfirmer,
            onTap: () =>
                _aller(context, Routes.mesVentes, parametres: {'onglet': '1'}),
          ),
          _Entree(
            icone: Icons.star_outline_rounded,
            libelle: 'Mes avis',
            onTap: () =>
                _aller(context, Routes.mesAvis, parametres: {'onglet': '0'}),
          ),
          _Entree(
            icone: Icons.favorite_border_rounded,
            libelle: 'Favoris et vendeurs suivis',
            pastille: _Pastille.alertesFavoris,
            onTap: () => _aller(context, Routes.mesListes),
          ),

          const Divider(height: Espaces.lg),
          const _Rubrique(libelle: 'Vendre'),
          _Entree(
            icone: Icons.insights_outlined,
            libelle: 'Tableau de bord',
            onTap: () => _aller(context, Routes.tableauBord),
          ),
          _Entree(
            icone: Icons.sell_outlined,
            libelle: 'Mes annonces',
            onTap: () => _allerOnglet(context, Routes.mesAnnonces),
          ),
          _Entree(
            icone: Icons.add_business_outlined,
            libelle: 'Publier une annonce',
            onTap: () => _aller(context, Routes.nouvelleAnnonce),
          ),
          _Entree(
            icone: Icons.inbox_outlined,
            libelle: 'Demandes recues',
            pastille: _Pastille.demandesRecues,
            accentuerPastille: true,
            onTap: () => _aller(
              context,
              Routes.mesReservations,
              parametres: {'onglet': '1'},
            ),
          ),
          _Entree(
            icone: Icons.reviews_outlined,
            libelle: 'Avis recus',
            onTap: () =>
                _aller(context, Routes.mesAvis, parametres: {'onglet': '1'}),
          ),
          _Entree(
            icone: Icons.receipt_long_outlined,
            libelle: 'Mes ventes',
            onTap: () =>
                _aller(context, Routes.mesVentes, parametres: {'onglet': '0'}),
          ),
          const _EntreeMaBoutique(),

          const Divider(height: Espaces.lg),
          const _Rubrique(libelle: 'Compte'),
          const _EntreeProfil(),
          _Entree(
            icone: Icons.search_rounded,
            libelle: 'Explorer le catalogue',
            onTap: () => _allerOnglet(context, Routes.recherche),
          ),
        ],
      ),
    );
  }

  /// Ferme le menu PUIS navigue.
  ///
  /// L'ordre compte : naviguer avant de fermer laisse le tiroir ouvert
  /// par-dessus l'ecran d'arrivee.
  static void _aller(
    BuildContext context,
    String route, {
    Map<String, String> chemin = const {},
    Map<String, String> parametres = const {},
  }) {
    Navigator.of(context).pop();
    context.pushNamed(
      route,
      pathParameters: chemin,
      queryParameters: parametres,
    );
  }

  /// Pour un onglet de la coquille : `go`, et non `push`, sinon l'onglet
  /// s'empile au lieu de se selectionner.
  static void _allerOnglet(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.goNamed(route);
  }
}

/// En-tete du menu.
///
/// Il lit l'utilisateur LUI-MEME, dans son propre `Consumer`. Les lectures
/// de providers ne sont plus faites en tete du `build` du menu : une seule
/// d'entre elles qui echoue ou se reconstruit emportait tout le tiroir, et
/// on se retrouvait avec un panneau vide, sans message ni erreur visible.
/// Isolees, un compteur en panne ne coute que son propre chiffre.
class _Entete extends ConsumerWidget {
  const _Entete();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateur = ref.watch(utilisateurProvider);
    final connecte = utilisateur != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Espaces.md),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.emeraudeSombre, AppColors.sarcelleSombre],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.blanc.withValues(alpha: 0.18),
            ),
            child: ClipOval(
              child: utilisateur?.photo != null
                  ? ReseauImage(
                      url: utilisateur!.photo,
                      largeur: 48,
                      hauteur: 48,
                    )
                  : Center(
                      child: Icon(
                        connecte
                            ? Icons.person_rounded
                            : Icons.person_outline_rounded,
                        color: AppColors.blanc,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: Espaces.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connecte ? utilisateur.nomAffiche : 'Visiteur',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.blanc,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  connecte
                      ? '@${utilisateur.username}'
                      : 'Connectez-vous pour reserver et vendre',
                  maxLines: 2,
                  style: TextStyle(
                    color: AppColors.blanc.withValues(alpha: 0.82),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Entree « Ma boutique publique », visible seulement une fois connecte.
class _EntreeMaBoutique extends ConsumerWidget {
  const _EntreeMaBoutique();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisateur = ref.watch(utilisateurProvider);
    if (utilisateur == null) return const SizedBox.shrink();

    return _Entree(
      icone: Icons.storefront_outlined,
      libelle: 'Ma boutique publique',
      onTap: () => MenuLateral._aller(
        context,
        Routes.boutique,
        chemin: {'id': '${utilisateur.id}'},
      ),
    );
  }
}

/// Entree de profil : « Mon profil » ou « Se connecter ».
class _EntreeProfil extends ConsumerWidget {
  const _EntreeProfil();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connecte = ref.watch(utilisateurProvider) != null;

    return _Entree(
      icone: Icons.person_outline_rounded,
      libelle: connecte ? 'Mon profil' : 'Se connecter',
      onTap: () => connecte
          ? MenuLateral._allerOnglet(context, Routes.compte)
          : MenuLateral._aller(context, Routes.connexion),
    );
  }
}

/// Fabriques de pastilles, chacune dans son propre `Consumer`.
///
/// Une pastille est decorative : son echec ne doit jamais empecher
/// l'entree de menu de s'afficher, et encore moins le menu entier.
class _Pastille {
  const _Pastille._();

  static Widget get notifications => Consumer(
    builder: (context, ref, _) => _Bulle(nombre: ref.watch(nonLuesProvider)),
  );

  static Widget get messages => Consumer(
    builder: (context, ref, _) => _Bulle(
      nombre: ref
          .watch(messagesNonLusProvider)
          .maybeWhen(data: (nombre) => nombre, orElse: () => 0),
    ),
  );

  static Widget get demandesEnvoyees => Consumer(
    builder: (context, ref, _) => _Bulle(
      nombre: ref
          .watch(resumeReservationsProvider)
          .maybeWhen(
            data: (resume) => resume.demandesEnAttente,
            orElse: () => 0,
          ),
    ),
  );

  static Widget get demandesRecues => Consumer(
    builder: (context, ref, _) => _Bulle(
      nombre: ref
          .watch(resumeReservationsProvider)
          .maybeWhen(data: (resume) => resume.aTraiter, orElse: () => 0),
      accentuer: true,
    ),
  );

  /// Achats qui attendent ma confirmation de reception. En orange,
  /// comme les demandes a traiter : ce sont les deux seuls compteurs qui
  /// appellent une action immediate de ma part.
  static Widget get achatsAConfirmer => Consumer(
    builder: (context, ref, _) => _Bulle(
      nombre: ref
          .watch(achatsAConfirmerProvider)
          .maybeWhen(data: (nombre) => nombre, orElse: () => 0),
      accentuer: true,
    ),
  );

  static Widget get alertesFavoris => Consumer(
    builder: (context, ref, _) => _Bulle(
      nombre: ref.watch(favorisProvider.select((e) => e.avecAlerte.length)),
    ),
  );
}

class _Bulle extends StatelessWidget {
  const _Bulle({required this.nombre, this.accentuer = false});

  final int nombre;
  final bool accentuer;

  @override
  Widget build(BuildContext context) {
    if (nombre <= 0) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: accentuer ? AppColors.alerte : AppColors.emeraude,
        borderRadius: BorderRadius.circular(Rayons.pilule),
      ),
      child: Text(
        nombre > 99 ? '99+' : '$nombre',
        style: const TextStyle(
          color: AppColors.blanc,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Rubrique extends StatelessWidget {
  const _Rubrique({required this.libelle});

  final String libelle;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espaces.md,
        Espaces.xs,
        Espaces.md,
        Espaces.xxs,
      ),
      child: Text(
        libelle.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: sombre ? AppColors.texteClairDoux : AppColors.texteSombreDoux,
        ),
      ),
    );
  }
}

class _Entree extends StatelessWidget {
  const _Entree({
    required this.icone,
    required this.libelle,
    required this.onTap,
    this.pastille,
    this.accentuerPastille = false,
  });

  final IconData icone;
  final String libelle;
  final VoidCallback onTap;

  /// Widget, et non un nombre : la pastille porte sa propre lecture de
  /// provider et se reconstruit seule.
  final Widget? pastille;

  final bool accentuerPastille;

  /// Construit sans `ListTile`, volontairement.
  ///
  /// `_RenderListTile` echouait a se dimensionner dans ce tiroir
  /// (`size: MISSING`, contraintes `0.0<=h<=Infinity`), et l'assertion
  /// `child.hasSize` du sliver faisait alors avorter la liste ENTIERE :
  /// un seul element en faute, et plus rien ne s'affichait, en-tete
  /// compris. Une erreur de MISE EN PAGE ne produit pas d'encart rouge
  /// comme une erreur de construction — d'ou un panneau vide et muet.
  ///
  /// Un `Row` dont la hauteur est fixee ici ne laisse aucune place a ce
  /// genre de negociation : la ligne a une hauteur connue, quoi qu'il
  /// arrive.
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: Espaces.md),
          child: Row(
            children: [
              Icon(icone, size: 21),
              const SizedBox(width: Espaces.md),
              Expanded(
                child: Text(
                  libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
              if (pastille != null) ...[
                const SizedBox(width: Espaces.xs),
                pastille!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
