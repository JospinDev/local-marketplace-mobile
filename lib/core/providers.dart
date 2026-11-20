import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import 'network/api_client.dart';
import 'storage/token_store.dart';

/// Fournisseurs partages par toute l'application.
///
/// Ils sont tous declares ici, et non dans chaque module : c'est ce qui
/// garantit qu'il n'existe QU'UN client HTTP et QU'UN coffre a jetons. Deux
/// clients voudraient dire deux rafraichissements concurrents, donc une
/// deconnexion aleatoire.

/// Coffre a jetons, initialise au demarrage par `main()`.
final tokenStoreProvider = Provider<TokenStore>((ref) {
  throw UnimplementedError(
    'tokenStoreProvider doit etre surcharge dans main() apres initialisation.',
  );
});

/// Client HTTP unique.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(jetons: ref.watch(tokenStoreProvider));
});

/// Depot d'authentification (module 1).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(apiClientProvider),
    jetons: ref.watch(tokenStoreProvider),
  );
});
