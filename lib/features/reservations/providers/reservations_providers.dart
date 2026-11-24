import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/reservations_repository.dart';
import '../domain/reservation.dart';

final reservationsRepositoryProvider = Provider<ReservationsRepository>((ref) {
  return ReservationsRepository(api: ref.watch(apiClientProvider));
});

/// Quel cote de la relation on regarde.
enum CoteReservation { mesDemandes, demandesRecues }

@immutable
class EtatReservations {
  const EtatReservations({
    this.reservations = const [],
    this.chargement = true,
    this.filtreStatut,
    this.erreur,
  });

  final List<Reservation> reservations;
  final bool chargement;

  /// Code serveur (`PENDING`, `CONFIRMED`...), ou `null` pour tout voir.
  final String? filtreStatut;

  final Object? erreur;

  bool get estVide =>
      reservations.isEmpty && !chargement && erreur == null;

  EtatReservations copyWith({
    List<Reservation>? reservations,
    bool? chargement,
    String? filtreStatut,
    bool viderFiltre = false,
    Object? erreur,
    bool viderErreur = false,
  }) {
    return EtatReservations(
      reservations: reservations ?? this.reservations,
      chargement: chargement ?? this.chargement,
      filtreStatut: viderFiltre ? null : (filtreStatut ?? this.filtreStatut),
      erreur: viderErreur ? null : (erreur ?? this.erreur),
    );
  }
}

class ReservationsNotifier extends StateNotifier<EtatReservations> {
  ReservationsNotifier(
    this._depot, {
    required this.cote,
    required bool connecte,
  }) : super(EtatReservations(chargement: connecte)) {
    if (connecte) charger();
  }

  final ReservationsRepository _depot;
  final CoteReservation cote;

  Future<void> charger() async {
    state = state.copyWith(chargement: true, viderErreur: true);
    try {
      final page = cote == CoteReservation.mesDemandes
          ? await _depot.mesDemandes(statut: state.filtreStatut)
          : await _depot.demandesRecues(statut: state.filtreStatut);
      if (!mounted) return;
      state = state.copyWith(
        reservations: page.elements,
        chargement: false,
      );
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

  /// Remplace une reservation en place apres une action.
  ///
  /// Le serveur renvoie la version a jour : on l'injecte plutot que de
  /// recharger toute la liste, pour que la carte ne clignote pas. Si son
  /// statut la fait sortir du filtre courant, on la retire.
  void appliquer(Reservation maj) {
    if (!mounted) return;

    final filtre = state.filtreStatut;
    final sortDuFiltre =
        filtre != null && filtre.toUpperCase() != _code(maj.statut);

    final liste = <Reservation>[];
    var trouvee = false;
    for (final existante in state.reservations) {
      if (existante.id != maj.id) {
        liste.add(existante);
        continue;
      }
      trouvee = true;
      if (!sortDuFiltre) liste.add(maj);
    }

    if (!trouvee && !sortDuFiltre) liste.insert(0, maj);
    state = state.copyWith(reservations: liste);
  }

  static String _code(StatutReservation statut) {
    switch (statut) {
      case StatutReservation.pending:
        return 'PENDING';
      case StatutReservation.confirmed:
        return 'CONFIRMED';
      case StatutReservation.cancelled:
        return 'CANCELLED';
      case StatutReservation.expired:
        return 'EXPIRED';
      case StatutReservation.fulfilled:
        return 'FULFILLED';
      case StatutReservation.inconnu:
        return '';
    }
  }
}

final mesDemandesProvider =
    StateNotifierProvider<ReservationsNotifier, EtatReservations>((ref) {
  final connecte = ref.watch(authProvider).estConnecte;
  return ReservationsNotifier(
    ref.watch(reservationsRepositoryProvider),
    cote: CoteReservation.mesDemandes,
    connecte: connecte,
  );
});

final demandesRecuesProvider =
    StateNotifierProvider<ReservationsNotifier, EtatReservations>((ref) {
  final connecte = ref.watch(authProvider).estConnecte;
  return ReservationsNotifier(
    ref.watch(reservationsRepositoryProvider),
    cote: CoteReservation.demandesRecues,
    connecte: connecte,
  );
});

/// Compteurs pour les pastilles.
final resumeReservationsProvider =
    FutureProvider<ResumeReservations>((ref) async {
  if (!ref.watch(authProvider).estConnecte) {
    return const ResumeReservations();
  }
  return ref.watch(reservationsRepositoryProvider).resume();
});

/// Une reservation, rechargee a l'ouverture de son detail.
final reservationProvider =
    FutureProvider.autoDispose.family<Reservation, int>((ref, id) {
  return ref.watch(reservationsRepositoryProvider).reservation(id);
});

/// Rafraichit les deux listes et les compteurs apres une action.
///
/// Une acceptation touche les deux cotes : la demande recue change
/// d'etat chez le vendeur, et la demande envoyee change chez l'acheteur.
/// Sur un meme appareil, un vendeur peut consulter les deux listes.
void rafraichirReservations(Ref ref) {
  ref.invalidate(resumeReservationsProvider);
  ref.read(mesDemandesProvider.notifier).charger();
  ref.read(demandesRecuesProvider.notifier).charger();
}
