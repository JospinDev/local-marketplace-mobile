import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/catalogue_repository.dart';
import '../domain/categorie.dart';
import '../domain/produit.dart';

final catalogueRepositoryProvider = Provider<CatalogueRepository>((ref) {
  return CatalogueRepository(api: ref.watch(apiClientProvider));
});

/// Arbre des categories.
///
/// `keepAlive` : l'arbre change rarement et sert a chaque ecran. Le
/// recharger a chaque retour sur l'accueil ferait clignoter le menu pour
/// rien.
final categoriesProvider = FutureProvider<List<Categorie>>((ref) async {
  ref.keepAlive();
  return ref.watch(catalogueRepositoryProvider).arbreCategories();
});

/// Les trois rangees de l'accueil, chargees en PARALLELE.
///
/// Trois `await` successifs feraient attendre la somme des trois temps de
/// reponse ; `Future.wait` ne fait attendre que le plus lent.
final accueilProvider = FutureProvider<ContenuAccueil>((ref) async {
  final depot = ref.watch(catalogueRepositoryProvider);
  final resultats = await Future.wait([
    depot.misesEnAvant(),
    depot.dernieres(),
    depot.populaires(),
  ]);
  return ContenuAccueil(
    misesEnAvant: resultats[0],
    dernieres: resultats[1],
    populaires: resultats[2],
  );
});

@immutable
class ContenuAccueil {
  const ContenuAccueil({
    required this.misesEnAvant,
    required this.dernieres,
    required this.populaires,
  });

  final List<Produit> misesEnAvant;
  final List<Produit> dernieres;
  final List<Produit> populaires;

  bool get estVide =>
      misesEnAvant.isEmpty && dernieres.isEmpty && populaires.isEmpty;
}

/// Fiche produit. `family` : une fiche par identifiant, mise en cache
/// tant que l'ecran vit.
final ficheProduitProvider =
    FutureProvider.family<Produit, int>((ref, id) async {
  return ref.watch(catalogueRepositoryProvider).fiche(id);
});

// ===========================================================================
// Recherche paginee
// ===========================================================================

@immutable
class EtatRecherche {
  const EtatRecherche({
    this.filtres = const FiltresCatalogue(),
    this.produits = const [],
    this.total = 0,
    this.page = 1,
    this.aUneSuite = false,
    this.chargementInitial = false,
    this.chargementSuite = false,
    this.erreur,
  });

  final FiltresCatalogue filtres;
  final List<Produit> produits;
  final int total;
  final int page;
  final bool aUneSuite;

  /// Premiere page : on affiche des squelettes a la place de la grille.
  final bool chargementInitial;

  /// Pages suivantes : la grille reste visible, on ajoute une roue en bas.
  /// Remplacer toute la liste par un squelette a chaque page serait
  /// insupportable.
  final bool chargementSuite;

  final Object? erreur;

  bool get estVide =>
      produits.isEmpty && !chargementInitial && erreur == null;

  EtatRecherche copyWith({
    FiltresCatalogue? filtres,
    List<Produit>? produits,
    int? total,
    int? page,
    bool? aUneSuite,
    bool? chargementInitial,
    bool? chargementSuite,
    Object? erreur,
    bool viderErreur = false,
  }) {
    return EtatRecherche(
      filtres: filtres ?? this.filtres,
      produits: produits ?? this.produits,
      total: total ?? this.total,
      page: page ?? this.page,
      aUneSuite: aUneSuite ?? this.aUneSuite,
      chargementInitial: chargementInitial ?? this.chargementInitial,
      chargementSuite: chargementSuite ?? this.chargementSuite,
      erreur: viderErreur ? null : (erreur ?? this.erreur),
    );
  }
}

class RechercheNotifier extends StateNotifier<EtatRecherche> {
  RechercheNotifier(this._depot) : super(const EtatRecherche());

  final CatalogueRepository _depot;

  /// Numero de la requete en cours. Il protege du scenario classique :
  /// la personne tape « gui », puis « guitare » ; la premiere requete,
  /// plus lente, revient APRES la seconde et ecrase le bon resultat. On
  /// ignore donc toute reponse qui n'est pas la plus recente.
  int _jeton = 0;

  Future<void> lancer(FiltresCatalogue filtres) async {
    final jeton = ++_jeton;
    state = state.copyWith(
      filtres: filtres,
      chargementInitial: true,
      viderErreur: true,
    );

    try {
      final page = await _depot.rechercher(filtres);
      if (jeton != _jeton || !mounted) return;
      state = state.copyWith(
        produits: page.elements,
        total: page.total,
        page: 1,
        aUneSuite: page.aUneSuite,
        chargementInitial: false,
      );
    } catch (erreur) {
      if (jeton != _jeton || !mounted) return;
      state = state.copyWith(chargementInitial: false, erreur: erreur);
    }
  }

  Future<void> pageSuivante() async {
    if (!state.aUneSuite || state.chargementSuite || state.chargementInitial) {
      return;
    }
    final jeton = _jeton;
    state = state.copyWith(chargementSuite: true);

    try {
      final page = await _depot.rechercher(
        state.filtres,
        page: state.page + 1,
      );
      if (jeton != _jeton || !mounted) return;
      state = state.copyWith(
        produits: [...state.produits, ...page.elements],
        page: state.page + 1,
        aUneSuite: page.aUneSuite,
        chargementSuite: false,
      );
    } catch (erreur) {
      if (jeton != _jeton || !mounted) return;
      // On garde les produits deja affiches : perdre la liste entiere
      // parce que la page 3 a echoue serait une punition disproportionnee.
      state = state.copyWith(chargementSuite: false, erreur: erreur);
    }
  }

  Future<void> rafraichir() => lancer(state.filtres);
}

final rechercheProvider =
    StateNotifierProvider<RechercheNotifier, EtatRecherche>((ref) {
  return RechercheNotifier(ref.watch(catalogueRepositoryProvider));
});
