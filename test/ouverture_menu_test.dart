// Verifie le MECANISME d'ouverture du tiroir, pas son contenu.
//
// Histoire de ce test : le bouton hamburger ne faisait rien. La cause est
// que `Scaffold.of(context)` remonte au plus proche `Scaffold`, qui n'est
// pas forcement celui qui porte le tiroir — et `openDrawer()` sur un
// Scaffold sans tiroir ne leve AUCUNE erreur, il ne fait simplement rien.
// Un bouton muet, invisible dans les journaux.
//
// `ouvrirMenuLateral()` passe par une cle globale et retourne un booleen,
// ce qui rend les deux cas testables.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_burundi/core/providers.dart';
import 'package:marketplace_burundi/core/storage/token_store.dart';
import 'package:marketplace_burundi/features/shell/menu_lateral.dart';

void main() {
  testWidgets(
    'un Scaffold imbrique sans tiroir ne bloque plus l\'ouverture',
    (tester) async {
      // Reproduit le piege : le bouton vit sous un SECOND Scaffold, qui
      // n'a pas de tiroir. Avec `Scaffold.of`, le clic serait un no-op.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tokenStoreProvider.overrideWithValue(TokenStore())],
          child: MaterialApp(
            home: Scaffold(
              key: cleScaffoldCoquille,
              drawer: const MenuLateral(),
              body: const Scaffold(
                body: Center(
                  child: IconButton(
                    icon: Icon(Icons.menu_rounded),
                    onPressed: ouvrirMenuLateral,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Notifications'), findsNothing);

      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Le tiroir s'ouvre malgre le Scaffold intermediaire.
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('ACHETER'), findsOneWidget);
    },
  );

  testWidgets(
    'sans tiroir joignable, la fonction repond faux au lieu de se taire',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      // Aucun Scaffold ne porte la cle : l'appelant peut donc prevenir la
      // personne, au lieu de laisser un bouton sans effet.
      expect(ouvrirMenuLateral(), isFalse);
    },
  );
}
