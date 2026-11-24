// Garde-fou sur l'isolation des annonces personnelles.
//
// Le defaut corrige : `annoncesProvider` ne surveillait pas
// l'authentification, donc le notifier survivait a un changement de compte
// et gardait en memoire les annonces du compte precedent. Connecte en
// acheteur, on voyait les annonces d'un vendeur — et la modification
// repondait `404`, puisque le serveur filtre bien sur le proprietaire.
import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_burundi/core/network/api_client.dart';
import 'package:marketplace_burundi/core/storage/token_store.dart';
import 'package:marketplace_burundi/features/annonces/data/annonces_repository.dart';
import 'package:marketplace_burundi/features/annonces/providers/annonces_providers.dart';

void main() {
  AnnoncesRepository depot() =>
      AnnoncesRepository(api: ApiClient(jetons: TokenStore()));

  test('sans session, aucune annonce et aucun chargement', () {
    final notifier = AnnoncesNotifier(depot(), connecte: false);

    // Rien n'est charge : l'ecran montre directement l'etat vide, au lieu
    // d'une roue qui tourne sur une requete vouee a un 401.
    expect(notifier.state.chargement, isFalse);
    expect(notifier.state.annonces, isEmpty);
    expect(notifier.state.estVide, isTrue);

    notifier.dispose();
  });

  test('avec une session, le chargement demarre', () {
    final notifier = AnnoncesNotifier(depot(), connecte: true);

    // L'etat part en chargement : la liste n'affiche jamais « aucune
    // annonce » avant d'avoir demande au serveur.
    expect(notifier.state.chargement, isTrue);
    expect(notifier.state.estVide, isFalse);

    notifier.dispose();
  });
}
