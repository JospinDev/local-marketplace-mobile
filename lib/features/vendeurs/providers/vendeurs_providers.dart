import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../catalogue/domain/produit.dart';
import '../data/vendeurs_repository.dart';
import '../domain/vendeur_public.dart';

final vendeursRepositoryProvider = Provider<VendeursRepository>((ref) {
  return VendeursRepository(api: ref.watch(apiClientProvider));
});

/// Vitrine d'un vendeur.
///
/// `autoDispose` : en quittant la boutique, inutile de garder la fiche en
/// memoire. Mais on garde le resultat tant que l'ecran vit, sinon chaque
/// reconstruction relancerait la requete.
final vendeurPublicProvider =
    FutureProvider.autoDispose.family<VendeurPublic, int>((ref, id) {
  return ref.watch(vendeursRepositoryProvider).vendeur(id);
});

/// Annonces d'un vendeur.
final produitsVendeurProvider =
    FutureProvider.autoDispose.family<List<Produit>, int>((ref, id) async {
  final page = await ref.watch(vendeursRepositoryProvider).produits(id);
  return page.elements;
});
