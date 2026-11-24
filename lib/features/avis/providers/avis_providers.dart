import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalogue/domain/produit.dart';
import '../data/avis_repository.dart';
import '../domain/evaluation.dart';

final avisRepositoryProvider = Provider<AvisRepository>((ref) {
  return AvisRepository(api: ref.watch(apiClientProvider));
});

enum CoteAvis { ecrits, recus }

@immutable
class EtatAvis {
  const EtatAvis({
    this.avis = const [],
    this.chargement = true,
    this.erreur,
  });

  final List<Evaluation> avis;
  final bool chargement;
  final Object? erreur;

  bool get estVide => avis.isEmpty && !chargement && erreur == null;

  EtatAvis copyWith({
    List<Evaluation>? avis,
    bool? chargement,
    Object? erreur,
    bool viderErreur = false,
  }) {
    return EtatAvis(
      avis: avis ?? this.avis,
      chargement: chargement ?? this.chargement,
      erreur: viderErreur ? null : (erreur ?? this.erreur),
    );
  }
}

class AvisNotifier extends StateNotifier<EtatAvis> {
  AvisNotifier(this._depot, {required this.cote, required bool connecte})
      : super(EtatAvis(chargement: connecte)) {
    if (connecte) charger();
  }

  final AvisRepository _depot;
  final CoteAvis cote;

  Future<void> charger() async {
    state = state.copyWith(chargement: true, viderErreur: true);
    try {
      final page = cote == CoteAvis.ecrits
          ? await _depot.mesAvis()
          : await _depot.avisRecus();
      if (!mounted) return;
      state = state.copyWith(avis: page.elements, chargement: false);
    } catch (erreur) {
      if (!mounted) return;
      state = state.copyWith(chargement: false, erreur: erreur);
    }
  }

  /// Injecte la version renvoyee par le serveur.
  ///
  /// Un avis RETIRE reste dans la liste de son auteur — il doit voir
  /// qu'il l'a retire — mais disparait des avis recus par le vendeur,
  /// puisqu'il ne compte plus.
  void appliquer(Evaluation maj) {
    if (!mounted) return;

    if (cote == CoteAvis.recus && !maj.estValide) {
      state = state.copyWith(
        avis: state.avis.where((a) => a.id != maj.id).toList(growable: false),
      );
      return;
    }

    final liste = <Evaluation>[];
    var trouve = false;
    for (final existant in state.avis) {
      if (existant.id == maj.id) {
        trouve = true;
        liste.add(maj);
      } else {
        liste.add(existant);
      }
    }
    if (!trouve) liste.insert(0, maj);
    state = state.copyWith(avis: liste);
  }
}

final mesAvisProvider =
    StateNotifierProvider<AvisNotifier, EtatAvis>((ref) {
  final connecte = ref.watch(authProvider).estConnecte;
  return AvisNotifier(
    ref.watch(avisRepositoryProvider),
    cote: CoteAvis.ecrits,
    connecte: connecte,
  );
});

final avisRecusProvider =
    StateNotifierProvider<AvisNotifier, EtatAvis>((ref) {
  final connecte = ref.watch(authProvider).estConnecte;
  return AvisNotifier(
    ref.watch(avisRepositoryProvider),
    cote: CoteAvis.recus,
    connecte: connecte,
  );
});

/// Ma reputation de vendeur.
final maReputationProvider = FutureProvider<Reputation>((ref) async {
  if (!ref.watch(authProvider).estConnecte) return const Reputation();
  return ref.watch(avisRepositoryProvider).maReputation();
});

/// Avis publics d'une annonce, pour la fiche produit.
final avisProduitProvider =
    FutureProvider.autoDispose.family<List<Evaluation>, int>((ref, id) async {
  final page = await ref.watch(avisRepositoryProvider).avisDuProduit(id);
  return page.elements;
});

/// Avis publics et reputation d'un vendeur, pour sa boutique.
final avisVendeurProvider = FutureProvider.autoDispose
    .family<(List<Evaluation>, Reputation), int>((ref, id) async {
  final (page, reputation) =
      await ref.watch(avisRepositoryProvider).avisDuVendeur(id);
  return (page.elements, reputation);
});
