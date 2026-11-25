import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/ventes_repository.dart';
import '../domain/vente.dart';

final ventesRepositoryProvider = Provider<VentesRepository>((ref) {
  return VentesRepository(api: ref.watch(apiClientProvider));
});

enum CoteVente { mesVentes, mesAchats }

@immutable
class EtatVentes {
  const EtatVentes({
    this.ventes = const [],
    this.chargement = true,
    this.filtreStatut,
    this.erreur,
  });

  final List<Vente> ventes;
  final bool chargement;
  final String? filtreStatut;
  final Object? erreur;

  bool get estVide => ventes.isEmpty && !chargement && erreur == null;

  EtatVentes copyWith({
    List<Vente>? ventes,
    bool? chargement,
    String? filtreStatut,
    bool viderFiltre = false,
    Object? erreur,
    bool viderErreur = false,
  }) {
    return EtatVentes(
      ventes: ventes ?? this.ventes,
      chargement: chargement ?? this.chargement,
      filtreStatut: viderFiltre ? null : (filtreStatut ?? this.filtreStatut),
      erreur: viderErreur ? null : (erreur ?? this.erreur),
    );
  }
}

class VentesNotifier extends StateNotifier<EtatVentes> {
  VentesNotifier(this._depot, {required this.cote, required bool connecte})
      : super(EtatVentes(chargement: connecte)) {
    if (connecte) charger();
  }

  final VentesRepository _depot;
  final CoteVente cote;

  Future<void> charger() async {
    state = state.copyWith(chargement: true, viderErreur: true);
    try {
      final page = cote == CoteVente.mesVentes
          ? await _depot.mesVentes(statut: state.filtreStatut)
          : await _depot.mesAchats(statut: state.filtreStatut);
      if (!mounted) return;
      state = state.copyWith(ventes: page.elements, chargement: false);
    } catch (erreur) {
      if (!mounted) return;
      state = state.copyWith(chargement: false, erreur: erreur);
    }
  }

  Future<void> filtrer(String? statut) async {
    state = statut == null
        ? state.copyWith(viderFiltre: true)
        : state.copyWith(filtreStatut: statut);
    await charger();
  }

  /// Injecte la vente renvoyee par le serveur, sans recharger la liste.
  void appliquer(Vente maj) {
    if (!mounted) return;

    final filtre = state.filtreStatut;
    final sortDuFiltre =
        filtre != null && filtre.toUpperCase() != _code(maj.statut);

    final liste = <Vente>[];
    var trouvee = false;
    for (final existante in state.ventes) {
      if (existante.id != maj.id) {
        liste.add(existante);
        continue;
      }
      trouvee = true;
      if (!sortDuFiltre) liste.add(maj);
    }
    if (!trouvee && !sortDuFiltre) liste.insert(0, maj);

    state = state.copyWith(ventes: liste);
  }

  static String _code(StatutVente statut) {
    switch (statut) {
      case StatutVente.initiated:
        return 'INITIATED';
      case StatutVente.paid:
        return 'PAID';
      case StatutVente.completed:
        return 'COMPLETED';
      case StatutVente.cancelled:
        return 'CANCELLED';
      case StatutVente.refunded:
        return 'REFUNDED';
      case StatutVente.inconnu:
        return '';
    }
  }
}

final mesVentesProvider =
    StateNotifierProvider<VentesNotifier, EtatVentes>((ref) {
  final connecte = ref.watch(authProvider).estConnecte;
  return VentesNotifier(
    ref.watch(ventesRepositoryProvider),
    cote: CoteVente.mesVentes,
    connecte: connecte,
  );
});

final mesAchatsProvider =
    StateNotifierProvider<VentesNotifier, EtatVentes>((ref) {
  final connecte = ref.watch(authProvider).estConnecte;
  return VentesNotifier(
    ref.watch(ventesRepositoryProvider),
    cote: CoteVente.mesAchats,
    connecte: connecte,
  );
});

/// Achats payes qui attendent MA confirmation de reception.
///
/// C'est le seul moment ou l'acheteur doit agir, et rien ne le lui
/// disait : la vente restait bloquee en `PAID`, le vendeur attendait, et
/// l'acheteur ne pouvait pas laisser d'avis sans savoir pourquoi. Ce
/// compteur alimente la pastille du menu.
final achatsAConfirmerProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(authProvider).estConnecte) return 0;
  final page = await ref.watch(ventesRepositoryProvider).mesAchats(
        statut: 'PAID',
      );
  return page.total;
});

final revenusProvider = FutureProvider<Revenus>((ref) async {
  if (!ref.watch(authProvider).estConnecte) return const Revenus();
  return ref.watch(ventesRepositoryProvider).revenus();
});

final venteProvider =
    FutureProvider.autoDispose.family<Vente, int>((ref, id) {
  return ref.watch(ventesRepositoryProvider).vente(id);
});
