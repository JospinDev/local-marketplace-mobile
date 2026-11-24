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
    final utilisateur = ref.watch(utilisateurProvider);
    final connecte = utilisateur != null;

    final aTraiter = ref.watch(resumeReservationsProvider).maybeWhen(
          data: (resume) => resume.aTraiter,
          orElse: () => 0,
        );
    final mesDemandes = ref.watch(resumeReservationsProvider).maybeWhen(
          data: (resume) => resume.demandesEnAttente,
          orElse: () => 0,
        );
    final messages = ref.watch(messagesNonLusProvider).maybeWhen(
          data: (nombre) => nombre,
          orElse: () => 0,
        );
    final alertes =
        ref.watch(favorisProvider.select((e) => e.avecAlerte.length));
    final notifications = ref.watch(nonLuesProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _Entete(connecte: connecte, nom: utilisateur?.nomAffiche,
                photo: utilisateur?.photo, username: utilisateur?.username),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: Espaces.xs),
                children: [
                  const _Rubrique(libelle: 'Acheter'),
                  _Entree(
                    icone: Icons.notifications_none_rounded,
                    libelle: 'Notifications',
                    pastille: notifications,
                    onTap: () => _aller(context, Routes.notifications),
                  ),
                  _Entree(
                    icone: Icons.chat_bubble_outline_rounded,
                    libelle: 'Messages',
                    pastille: messages,
                    onTap: () => _allerOnglet(context, Routes.messages),
                  ),
                  _Entree(
                    icone: Icons.bookmark_border_rounded,
                    libelle: 'Mes demandes de reservation',
                    pastille: mesDemandes,
                    onTap: () => _aller(
                      context,
                      Routes.mesReservations,
                      parametres: {'onglet': '0'},
                    ),
                  ),
                  _Entree(
                    icone: Icons.shopping_bag_outlined,
                    libelle: 'Mes achats',
                    onTap: () => _aller(
                      context,
                      Routes.mesVentes,
                      parametres: {'onglet': '1'},
                    ),
                  ),
                  _Entree(
                    icone: Icons.favorite_border_rounded,
                    libelle: 'Favoris et vendeurs suivis',
                    pastille: alertes,
                    onTap: () => _aller(context, Routes.mesListes),
                  ),

                  const Divider(height: Espaces.lg),
                  const _Rubrique(libelle: 'Vendre'),
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
                    pastille: aTraiter,
                    // Les demandes a traiter sont le seul compteur qui
                    // appelle une action immediate : on l'accentue.
                    accentuerPastille: true,
                    onTap: () => _aller(
                      context,
                      Routes.mesReservations,
                      parametres: {'onglet': '1'},
                    ),
                  ),
                  _Entree(
                    icone: Icons.receipt_long_outlined,
                    libelle: 'Mes ventes',
                    onTap: () => _aller(
                      context,
                      Routes.mesVentes,
                      parametres: {'onglet': '0'},
                    ),
                  ),
                  if (connecte)
                    _Entree(
                      icone: Icons.storefront_outlined,
                      libelle: 'Ma boutique publique',
                      onTap: () => _aller(
                        context,
                        Routes.boutique,
                        chemin: {'id': '${utilisateur.id}'},
                      ),
                    ),

                  const Divider(height: Espaces.lg),
                  const _Rubrique(libelle: 'Compte'),
                  _Entree(
                    icone: Icons.person_outline_rounded,
                    libelle: connecte ? 'Mon profil' : 'Se connecter',
                    onTap: () => connecte
                        ? _allerOnglet(context, Routes.compte)
                        : _aller(context, Routes.connexion),
                  ),
                  _Entree(
                    icone: Icons.search_rounded,
                    libelle: 'Explorer le catalogue',
                    onTap: () => _allerOnglet(context, Routes.recherche),
                  ),
                ],
              ),
            ),
          ],
        ),
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

class _Entete extends StatelessWidget {
  const _Entete({
    required this.connecte,
    required this.nom,
    required this.photo,
    required this.username,
  });

  final bool connecte;
  final String? nom;
  final String? photo;
  final String? username;

  @override
  Widget build(BuildContext context) {
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
              child: photo != null
                  ? ReseauImage(url: photo, largeur: 48, hauteur: 48)
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
                  connecte ? (nom ?? '') : 'Visiteur',
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
                      ? '@${username ?? ''}'
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
          color: sombre
              ? AppColors.texteClairDoux
              : AppColors.texteSombreDoux,
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
    this.pastille = 0,
    this.accentuerPastille = false,
  });

  final IconData icone;
  final String libelle;
  final VoidCallback onTap;
  final int pastille;
  final bool accentuerPastille;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icone, size: 21),
      title: Text(libelle, style: const TextStyle(fontSize: 13.5)),
      trailing: pastille > 0
          ? Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: accentuerPastille
                    ? AppColors.alerte
                    : AppColors.emeraude,
                borderRadius: BorderRadius.circular(Rayons.pilule),
              ),
              child: Text(
                pastille > 99 ? '99+' : '$pastille',
                style: const TextStyle(
                  color: AppColors.blanc,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
