import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/tableau_bord_repository.dart';
import '../domain/tableau_bord.dart';

final tableauBordRepositoryProvider = Provider<TableauBordRepository>((ref) {
  return TableauBordRepository(api: ref.watch(apiClientProvider));
});

/// Les cinq sections sont des providers SEPARES, et non un seul appel.
///
/// Elles viennent de cinq routes distinctes : les charger separement
/// permet d'afficher la vue generale sans attendre le palmares, et une
/// section en echec n'emporte pas les autres.
///
/// Chacune surveille l'authentification : ces chiffres sont personnels et
/// ne doivent pas survivre a un changement de compte.
final vueGeneraleProvider = FutureProvider<VueGenerale>((ref) async {
  if (!ref.watch(authProvider).estConnecte) return const VueGenerale();
  return ref.watch(tableauBordRepositoryProvider).vueGenerale();
});

final revenusDetaillesProvider = FutureProvider<Revenus>((ref) async {
  if (!ref.watch(authProvider).estConnecte) return const Revenus();
  return ref.watch(tableauBordRepositoryProvider).revenus();
});

final inventaireProvider = FutureProvider<Inventaire>((ref) async {
  if (!ref.watch(authProvider).estConnecte) return const Inventaire();
  return ref.watch(tableauBordRepositoryProvider).inventaire();
});

final statistiquesReservationsProvider =
    FutureProvider<StatistiquesReservations>((ref) async {
  if (!ref.watch(authProvider).estConnecte) {
    return const StatistiquesReservations();
  }
  return ref.watch(tableauBordRepositoryProvider).reservations();
});

final palmaresProvider = FutureProvider<Palmares>((ref) async {
  if (!ref.watch(authProvider).estConnecte) return const Palmares();
  return ref.watch(tableauBordRepositoryProvider).palmares();
});

/// Recharge tout le tableau de bord.
void rafraichirTableauBord(WidgetRef ref) {
  ref.invalidate(vueGeneraleProvider);
  ref.invalidate(revenusDetaillesProvider);
  ref.invalidate(inventaireProvider);
  ref.invalidate(statistiquesReservationsProvider);
  ref.invalidate(palmaresProvider);
}
