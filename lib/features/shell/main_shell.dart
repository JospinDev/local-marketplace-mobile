import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import 'menu_lateral.dart';
import '../messagerie/providers/messagerie_providers.dart';

/// Coquille de l'application : la barre basse reste en place pendant que
/// le contenu change.
///
/// Le `StatefulNavigationShell` de go_router garde une pile de navigation
/// PAR onglet : on peut descendre dans une fiche produit, passer aux
/// messages, revenir — et retrouver la fiche. C'est le comportement
/// qu'attendent les gens, et le reproduire a la main est laborieux.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.coquille});

  final StatefulNavigationShell coquille;

  static const _elements = [
    ElementNav(
      icone: Icons.home_outlined,
      iconeActive: Icons.home_rounded,
      libelle: 'Accueil',
    ),
    ElementNav(
      icone: Icons.search_outlined,
      iconeActive: Icons.search_rounded,
      libelle: 'Recherche',
    ),
    ElementNav(
      icone: Icons.sell_outlined,
      iconeActive: Icons.sell_rounded,
      libelle: 'Vendre',
    ),
    ElementNav(
      icone: Icons.chat_bubble_outline_rounded,
      iconeActive: Icons.chat_bubble_rounded,
      libelle: 'Messages',
    ),
    ElementNav(
      icone: Icons.person_outline_rounded,
      iconeActive: Icons.person_rounded,
      libelle: 'Compte',
    ),
  ];

  void _changer(int index) {
    // `initialLocation: true` quand on retouche l'onglet courant : c'est
    // le raccourci « remonter en haut » auquel les gens sont habitues.
    coquille.goBranch(index, initialLocation: index == coquille.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // La cle designe CE Scaffold : le bouton hamburger l'ouvre par la
      // cle et non par `Scaffold.of`, qui pouvait tomber sur un autre
      // Scaffold et ne rien faire du tout.
      key: cleScaffoldCoquille,
      drawer: const MenuLateral(),
      body: AnimatedSwitcher(
        duration: Mouvements.normal,
        switchInCurve: Mouvements.sortie,
        // Fondu doux entre onglets, sans glissement : un glissement
        // lateral laisserait croire a une hierarchie entre les onglets.
        transitionBuilder: (enfant, animation) => FadeTransition(
          opacity: animation,
          child: enfant,
        ),
        child: KeyedSubtree(
          key: ValueKey(coquille.currentIndex),
          child: coquille,
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        index: coquille.currentIndex,
        onChange: _changer,
        elements: _elements,
        // Onglet 3 = Messages. La pastille se tait pendant le chargement
        // et en cas d'erreur : annoncer « 0 » a tort serait pire que de
        // ne rien annoncer.
        badges: {
          3: ref.watch(messagesNonLusProvider).maybeWhen(
                data: (nombre) => nombre,
                orElse: () => 0,
              ),
        },
      ),
    );
  }
}
