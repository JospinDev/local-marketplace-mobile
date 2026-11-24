import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/publicites_repository.dart';
import '../domain/publicite.dart';

final publicitesRepositoryProvider = Provider<PublicitesRepository>((ref) {
  return PublicitesRepository(api: ref.watch(apiClientProvider));
});

/// Bandeau publicitaire de l'accueil.
///
/// En cas d'erreur, le widget n'affiche RIEN : une publicite est un
/// supplement, pas un contenu dont l'absence merite un message. Mieux vaut
/// un accueil sans bandeau qu'un accueil avec un encart d'erreur.
final bandeauProvider = FutureProvider<List<Publicite>>((ref) {
  return ref.watch(publicitesRepositoryProvider).bandeau();
});
