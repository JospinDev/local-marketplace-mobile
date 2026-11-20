import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/account_screen.dart';
import '../../features/auth/presentation/email_verify_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/catalogue/presentation/accueil_screen.dart';
import '../../features/catalogue/presentation/produit_detail_screen.dart';
import '../../features/catalogue/presentation/recherche_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/shell/placeholder_screen.dart';
import '../theme/app_theme.dart';
import 'routes.dart';

final _cleRacine = GlobalKey<NavigatorState>();
final _cleCoquille = GlobalKey<NavigatorState>();

/// Routeur de l'application.
///
/// Un choix structurant : le catalogue est accessible SANS compte. Les
/// routes publiques ne sont donc pas protegees, et la redirection ne
/// s'occupe que de deux cas — sortir de l'ecran de demarrage une fois la
/// session connue, et renvoyer vers l'accueil quelqu'un de deja connecte
/// qui retomberait sur la connexion.
///
/// Les ecrans qui exigent un compte (mes annonces, reservations) le
/// demanderont au moment de l'action, pas en bloquant la navigation : un
/// visiteur doit pouvoir regarder avant de s'inscrire.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _cleRacine,
    initialLocation: Routes.cheminDemarrage,
    debugLogDiagnostics: false,

    redirect: (context, etat) {
      final surDemarrage = etat.matchedLocation == Routes.cheminDemarrage;
      final surAuth = {
        Routes.cheminConnexion,
        Routes.cheminInscription,
        Routes.cheminVerificationEmail,
        Routes.cheminMotDePasseOublie,
      }.contains(etat.matchedLocation);

      switch (auth.phase) {
        case PhaseAuth.verification:
          // On attend de savoir : seul l'ecran de demarrage a du sens.
          return surDemarrage ? null : Routes.cheminDemarrage;

        case PhaseAuth.connecte:
          // Deja connecte : l'ecran de demarrage et ceux d'authentification
          // n'ont plus de raison d'etre affiches.
          if (surDemarrage || surAuth) return Routes.cheminAccueil;
          return null;

        case PhaseAuth.deconnecte:
          // Le catalogue reste ouvert : on ne redirige que depuis le
          // demarrage, vers la connexion.
          if (surDemarrage) return Routes.cheminConnexion;
          return null;
      }
    },

    routes: [
      GoRoute(
        path: Routes.cheminDemarrage,
        name: Routes.demarrage,
        builder: (context, etat) => const SplashScreen(),
      ),

      // --- authentification ------------------------------------------
      GoRoute(
        path: Routes.cheminConnexion,
        name: Routes.connexion,
        pageBuilder: (context, etat) => _pageFondu(
          etat,
          const LoginScreen(),
        ),
        routes: [
          GoRoute(
            path: 'inscription',
            name: Routes.inscription,
            builder: (context, etat) => const RegisterScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.cheminInscription,
        builder: (context, etat) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.cheminVerificationEmail,
        name: Routes.verificationEmail,
        builder: (context, etat) => EmailVerifyScreen(
          username: etat.uri.queryParameters['username'] ?? '',
          email: etat.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: Routes.cheminMotDePasseOublie,
        name: Routes.motDePasseOublie,
        builder: (context, etat) => const ForgotPasswordScreen(),
      ),

      GoRoute(
        path: Routes.cheminProduit,
        name: Routes.produit,
        parentNavigatorKey: _cleRacine,
        builder: (context, etat) {
          final extra = etat.extra;
          final hero = extra is Map && extra['hero'] is String
              ? extra['hero'] as String
              : 'recherche';
          return ProduitDetailScreen(
            produitId: int.tryParse(etat.pathParameters['id'] ?? '') ?? 0,
            etiquetteHero: hero,
          );
        },
      ),

      // --- coquille a onglets -----------------------------------------
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _cleRacine,
        builder: (context, etat, coquille) => MainShell(coquille: coquille),
        branches: [
          StatefulShellBranch(
            navigatorKey: _cleCoquille,
            routes: [
              GoRoute(
                path: Routes.cheminAccueil,
                name: Routes.accueil,
                builder: (context, etat) => const AccueilScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.cheminRecherche,
                name: Routes.recherche,
                builder: (context, etat) {
                  final parametres = etat.uri.queryParameters;
                  return RechercheScreen(
                    // Cle sur la categorie : changer de categorie depuis
                    // l'accueil doit RECONSTRUIRE l'ecran, sinon
                    // `initState` ne rejoue pas et la recherche garde les
                    // criteres precedents.
                    key: ValueKey(parametres['categorie'] ?? 'tout'),
                    categorieInitiale:
                        int.tryParse(parametres['categorie'] ?? ''),
                    nomCategorie: parametres['nom'],
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.cheminFavoris,
                name: Routes.favoris,
                builder: (context, etat) => const PlaceholderScreen(
                  titre: 'Favoris',
                  etape: 'Etape 5',
                  icone: Icons.favorite_rounded,
                  description:
                      'Vos produits sauvegardes, avec les alertes de prix '
                      'et de disponibilite.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.cheminMessages,
                name: Routes.messages,
                builder: (context, etat) => const PlaceholderScreen(
                  titre: 'Messages',
                  etape: 'Etape 6',
                  icone: Icons.chat_bubble_rounded,
                  description:
                      'Les discussions avec les vendeurs, en temps reel '
                      'par WebSocket.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.cheminCompte,
                name: Routes.compte,
                builder: (context, etat) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
    ],

    errorBuilder: (context, etat) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Espaces.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 48),
              const SizedBox(height: Espaces.md),
              Text(
                'Page introuvable',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Espaces.xs),
              Text(
                etat.uri.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Espaces.xl),
              FilledButton(
                onPressed: () => context.goNamed(Routes.accueil),
                child: const Text("Revenir a l'accueil"),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});

/// Transition en fondu pour les ecrans d'authentification : un glissement
/// lateral suggererait une hierarchie qui n'existe pas entre eux.
CustomTransitionPage<void> _pageFondu(GoRouterState etat, Widget enfant) {
  return CustomTransitionPage<void>(
    key: etat.pageKey,
    child: enfant,
    transitionDuration: Mouvements.page,
    transitionsBuilder: (context, animation, _, enfant) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Mouvements.sortie),
      child: enfant,
    ),
  );
}
