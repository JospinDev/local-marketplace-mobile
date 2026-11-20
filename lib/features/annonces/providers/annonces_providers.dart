import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../catalogue/domain/produit.dart';
import '../data/annonces_repository.dart';

final annoncesRepositoryProvider = Provider<AnnoncesRepository>((ref) {
  return AnnoncesRepository(api: ref.watch(apiClientProvider));
});

/// Onglets de l'ecran « Mes annonces ».
///
/// Le filtre `status_in` permet de regrouper plusieurs statuts sous un
/// meme onglet : « Hors ligne » couvre la pause ET l'archive, car du
/// point de vue du vendeur c'est la meme chose — personne ne la voit.
enum FiltreAnnonces {
  toutes,
  enLigne,
  brouillons,
  horsLigne;

  String? get parametre => switch (this) {
        FiltreAnnonces.toutes => null,
        FiltreAnnonces.enLigne => 'ACTIVE,OUT_OF_STOCK',
        FiltreAnnonces.brouillons => 'DRAFT,PENDING',
        FiltreAnnonces.horsLigne => 'PAUSED,ARCHIVED,REMOVED',
      };

  String get libelle => switch (this) {
        FiltreAnnonces.toutes => 'Toutes',
        FiltreAnnonces.enLigne => 'En ligne',
        FiltreAnnonces.brouillons => 'Brouillons',
        FiltreAnnonces.horsLigne => 'Hors ligne',
      };
}

@immutable
class EtatAnnonces {
  const EtatAnnonces({
    this.filtre = FiltreAnnonces.toutes,
    this.annonces = const [],
    this.total = 0,
    this.chargement = true,
    this.erreur,
  });

  final FiltreAnnonces filtre;
  final List<Produit> annonces;
  final int total;
  final bool chargement;
  final Object? erreur;

  bool get estVide => annonces.isEmpty && !chargement && erreur == null;

  EtatAnnonces copyWith({
    FiltreAnnonces? filtre,
    List<Produit>? annonces,
    int? total,
    bool? chargement,
    Object? erreur,
    bool viderErreur = false,
  }) {
    return EtatAnnonces(
      filtre: filtre ?? this.filtre,
      annonces: annonces ?? this.annonces,
      total: total ?? this.total,
      chargement: chargement ?? this.chargement,
      erreur: viderErreur ? null : (erreur ?? this.erreur),
    );
  }
}

class AnnoncesNotifier extends StateNotifier<EtatAnnonces> {
  AnnoncesNotifier(this._depot) : super(const EtatAnnonces()) {
    charger();
  }

  final AnnoncesRepository _depot;

  Future<void> charger({FiltreAnnonces? filtre}) async {
    final choisi = filtre ?? state.filtre;
    state = state.copyWith(
      filtre: choisi,
      chargement: true,
      viderErreur: true,
    );
    try {
      final page = await _depot.mesAnnonces(statut: choisi.parametre);
      if (!mounted) return;
      state = state.copyWith(
        annonces: page.elements,
        total: page.total,
        chargement: false,
      );
    } catch (erreur) {
      if (!mounted) return;
      state = state.copyWith(chargement: false, erreur: erreur);
    }
  }

  /// Remplace une annonce dans la liste apres une action.
  ///
  /// On ne recharge PAS toute la liste : le defilement sauterait en haut,
  /// et sur un filtre « En ligne » l'annonce qu'on vient de mettre en
  /// pause disparaitrait brutalement sous le doigt.
  void remplacer(Produit maj) {
    state = state.copyWith(
      annonces: [
        for (final annonce in state.annonces)
          if (annonce.id == maj.id) maj else annonce,
      ],
    );
  }

  void retirer(int id) {
    state = state.copyWith(
      annonces: state.annonces.where((a) => a.id != id).toList(),
      total: state.total > 0 ? state.total - 1 : 0,
    );
  }
}

final annoncesProvider =
    StateNotifierProvider<AnnoncesNotifier, EtatAnnonces>((ref) {
  return AnnoncesNotifier(ref.watch(annoncesRepositoryProvider));
});

/// Stock d'une annonce, charge a la demande.
final stockProvider = FutureProvider.family<Stock, int>((ref, id) async {
  return ref.watch(annoncesRepositoryProvider).stock(id);
});
