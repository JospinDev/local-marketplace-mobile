// Teste que le menu lateral affiche bien ses entrees.
//
// Ce test existe parce que le tiroir s'ouvrait VIDE sur l'appareil : sans
// moyen de reproduire sur le telephone, il fallait un endroit ou l'erreur
// soit visible.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_burundi/core/providers.dart';
import 'package:marketplace_burundi/core/storage/token_store.dart';
import 'package:marketplace_burundi/features/shell/menu_lateral.dart';

void main() {
  testWidgets('le menu lateral affiche ses entrees', (tester) async {
    final jetons = TokenStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(jetons)],
        child: const MaterialApp(
          home: Scaffold(
            drawer: MenuLateral(),
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );

    // Ouvrir le tiroir par l'etat du Scaffold, comme le fait le bouton.
    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffold.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Mes annonces'), findsOneWidget);
    expect(find.text('Mes ventes'), findsOneWidget);
    expect(find.text('Demandes recues'), findsOneWidget);
    expect(find.text('ACHETER'), findsOneWidget);
  });

  testWidgets(
    'le hamburger ouvre le menu depuis le corps de la coquille',
    (tester) async {
      // Reproduit la structure reelle : UN SEUL Scaffold, celui de la
      // coquille, qui porte la barre basse ET le tiroir. Le bouton vit
      // dans son corps et ouvre ce tiroir.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStoreProvider.overrideWithValue(TokenStore()),
          ],
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: const SizedBox(height: 60),
              drawer: const MenuLateral(),
              body: Builder(
                builder: (context) => Center(
                  child: IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: Scaffold.of(context).openDrawer,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Mes annonces'), findsOneWidget);
      expect(find.text('ACHETER'), findsOneWidget);
    },
  );
}
