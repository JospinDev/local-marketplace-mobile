import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalogue_repository.dart';
import '../domain/produit.dart';
import 'catalogue_providers.dart';

/// Flux « tout le catalogue » sous les carrousels de l'accueil.
///
/// Les trois carrousels montrent une selection ; ce flux prend la suite et
/// se charge page par page quand on continue a descendre. Sans lui, la
/// page s'arretait apres trois rangees et il fallait passer par l'onglet
/// Recherche pour voir le reste du catalogue.
@immutable
class EtatFlux {
  const EtatFlux({
    this.produits = const [],
    this.chargementInitial = true,
    this.chargementSuite = false,
    this.aUneSuite = true,
    this.total = 0,
    this.erreur,
  });

  final List<Produit> produits;
  final bool chargementInitial;

  /// Une page supplementaire est en route : on montre un indicateur en bas
  /// de liste, sans vider ce qui est deja affiche.
  final bool chargementSuite;

  final bool aUneSuite;
  final int total;
  final Object? erreur;

  EtatFlux copyWith({
    List<Produit>? produits,
    bool? chargementInitial,
    bool? chargementSuite,
    bool? aUneSuite,
    int? total,
    Object? erreur,
    bool viderErreur = false,
  }) {
    return EtatFlux(
      produits: produits ?? this.produits,
      chargementInitial: chargementInitial ?? this.chargementInitial,
      chargementSuite: chargementSuite ?? this.chargementSuite,
      aUneSuite: aUneSuite ?? this.aUneSuite,
      total: total ?? this.total,
      erreur: viderErreur ? null : (erreur ?? this.erreur),
    );
  }
}

class FluxAccueilNotifier extends StateNotifier<EtatFlux> {
  FluxAccueilNotifier(this._depot) : super(const EtatFlux()) {
    charger();
  }

  final CatalogueRepository _depot;

  /// Les plus recentes d'abord : le flux prolonge « Nouveautes ».
  static const _filtres = FiltresCatalogue(tri: TriCatalogue.recent);

  int _page = 1;

  /// Empeche deux chargements simultanes.
  ///
  /// `chargementSuite` ne suffit pas : entre l'appel et la mise a jour de
  /// l'etat, un second defilement pourrait relancer la meme page et
  /// dupliquer les cartes.
  bool _enCours = false;

  Future<void> charger() async {
    if (_enCours) return;
    _enCours = true;

    _page = 1;
    state = state.copyWith(chargementInitial: true, viderErreur: true);
    try {
      final resultat = await _depot.rechercher(_filtres, page: 1);
      if (!mounted) return;
      state = EtatFlux(
        produits: resultat.elements,
        chargementInitial: false,
        aUneSuite: resultat.aUneSuite,
        total: resultat.total,
      );
    } catch (erreur) {
      if (mounted) {
        state = state.copyWith(chargementInitial: false, erreur: erreur);
      }
    } finally {
      _enCours = false;
    }
  }

  Future<void> chargerLaSuite() async {
    if (_enCours || !state.aUneSuite || state.chargementInitial) return;
    _enCours = true;
    state = state.copyWith(chargementSuite: true, viderErreur: true);

    try {
      final resultat = await _depot.rechercher(_filtres, page: _page + 1);
      if (!mounted) return;

      // Garde-fou contre les doublons : le catalogue bouge entre deux
      // pages, et une annonce publiee entre-temps decale la pagination.
      final connus = state.produits.map((p) => p.id).toSet();
      final nouveaux = resultat.elements
          .where((p) => !connus.contains(p.id))
          .toList(growable: false);

      _page += 1;
      state = state.copyWith(
        produits: [...state.produits, ...nouveaux],
        chargementSuite: false,
        aUneSuite: resultat.aUneSuite,
        total: resultat.total,
      );
    } catch (erreur) {
      if (mounted) {
        state = state.copyWith(chargementSuite: false, erreur: erreur);
      }
    } finally {
      _enCours = false;
    }
  }
}

final fluxAccueilProvider =
    StateNotifierProvider<FluxAccueilNotifier, EtatFlux>((ref) {
  return FluxAccueilNotifier(ref.watch(catalogueRepositoryProvider));
});
