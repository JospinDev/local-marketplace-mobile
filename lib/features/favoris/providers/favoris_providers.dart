import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalogue/domain/produit.dart';
import '../data/favoris_repository.dart';
import '../domain/favori.dart';

final favorisRepositoryProvider = Provider<FavorisRepository>((ref) {
  return FavorisRepository(api: ref.watch(apiClientProvider));
});

/// Etat des favoris, avec l'ensemble des identifiants mis en favori.
///
/// Cet ensemble est la raison d'etre du provider : le bouton coeur d'une
/// carte doit savoir s'il est plein ou vide SANS declencher une requete
/// par carte affichee. On le garde donc en memoire, et on le met a jour
/// localement a chaque bascule — l'affichage reagit immediatement, avant
/// meme la reponse du serveur.
@immutable
class EtatFavoris {
  const EtatFavoris({
    this.favoris = const [],
    this.identifiants = const {},
    this.chargement = true,
    this.erreur,
  });

  final List<Favori> favoris;

  /// Identifiants des PRODUITS en favori.
  final Set<int> identifiants;

  final bool chargement;
  final Object? erreur;

  bool contient(int produitId) => identifiants.contains(produitId);

  bool get estVide => favoris.isEmpty && !chargement && erreur == null;

  /// Favoris qui meritent l'attention : prix change, rupture, retrait.
  List<Favori> get avecAlerte =>
      favoris.where((f) => f.aUneAlerte).toList(growable: false);

  EtatFavoris copyWith({
    List<Favori>? favoris,
    Set<int>? identifiants,
    bool? chargement,
    Object? erreur,
    bool viderErreur = false,
  }) {
    return EtatFavoris(
      favoris: favoris ?? this.favoris,
      identifiants: identifiants ?? this.identifiants,
      chargement: chargement ?? this.chargement,
      erreur: viderErreur ? null : (erreur ?? this.erreur),
    );
  }
}

class FavorisNotifier extends StateNotifier<EtatFavoris> {
  FavorisNotifier(this._depot, {required bool connecte})
      : super(EtatFavoris(chargement: connecte)) {
    if (connecte) charger();
  }

  final FavorisRepository _depot;

  Future<void> charger() async {
    state = state.copyWith(chargement: true, viderErreur: true);
    try {
      final page = await _depot.mesFavoris();
      if (!mounted) return;
      state = EtatFavoris(
        favoris: page.elements,
        identifiants: page.elements.map((f) => f.produit.id).toSet(),
        chargement: false,
      );
    } catch (erreur) {
      if (!mounted) return;
      state = state.copyWith(chargement: false, erreur: erreur);
    }
  }

  /// Bascule le favori d'un produit. Retourne l'etat final.
  ///
  /// La mise a jour est OPTIMISTE : le coeur se remplit avant la reponse
  /// du serveur. Sur un reseau lent, attendre l'aller-retour donne
  /// l'impression que le bouton ne marche pas, et la personne appuie
  /// deux fois. En cas d'echec, on revient en arriere.
  Future<bool> basculer(int produitId) async {
    final etaitFavori = state.contient(produitId);
    final nouveaux = Set<int>.from(state.identifiants);
    etaitFavori ? nouveaux.remove(produitId) : nouveaux.add(produitId);
    state = state.copyWith(identifiants: nouveaux);

    try {
      if (etaitFavori) {
        await _depot.retirer(produitId);
        state = state.copyWith(
          favoris:
              state.favoris.where((f) => f.produit.id != produitId).toList(),
        );
      } else {
        await _depot.ajouter(produitId);
        // On recharge pour recuperer le prix memorise et l'alerte, que
        // seul le serveur peut calculer.
        await charger();
      }
      return !etaitFavori;
    } catch (_) {
      if (mounted) state = state.copyWith(identifiants: state.identifiants);
      // Retour en arriere : l'affichage doit refleter la verite.
      final retabli = Set<int>.from(state.identifiants);
      etaitFavori ? retabli.add(produitId) : retabli.remove(produitId);
      if (mounted) state = state.copyWith(identifiants: retabli);
      rethrow;
    }
  }
}

final favorisProvider =
    StateNotifierProvider<FavorisNotifier, EtatFavoris>((ref) {
  // Se reconstruit a la connexion et a la deconnexion : les favoris sont
  // personnels, ceux du compte precedent ne doivent pas survivre.
  final connecte = ref.watch(authProvider).estConnecte;
  return FavorisNotifier(
    ref.watch(favorisRepositoryProvider),
    connecte: connecte,
  );
});

// ===========================================================================
// Vendeurs suivis
// ===========================================================================

@immutable
class EtatVendeurs {
  const EtatVendeurs({
    this.vendeurs = const [],
    this.identifiants = const {},
    this.chargement = true,
    this.erreur,
  });

  final List<VendeurSuivi> vendeurs;
  final Set<int> identifiants;
  final bool chargement;
  final Object? erreur;

  bool suit(int vendeurId) => identifiants.contains(vendeurId);
  bool get estVide => vendeurs.isEmpty && !chargement && erreur == null;

  EtatVendeurs copyWith({
    List<VendeurSuivi>? vendeurs,
    Set<int>? identifiants,
    bool? chargement,
    Object? erreur,
    bool viderErreur = false,
  }) {
    return EtatVendeurs(
      vendeurs: vendeurs ?? this.vendeurs,
      identifiants: identifiants ?? this.identifiants,
      chargement: chargement ?? this.chargement,
      erreur: viderErreur ? null : (erreur ?? this.erreur),
    );
  }
}

class VendeursNotifier extends StateNotifier<EtatVendeurs> {
  VendeursNotifier(this._depot, {required bool connecte})
      : super(EtatVendeurs(chargement: connecte)) {
    if (connecte) charger();
  }

  final FavorisRepository _depot;

  Future<void> charger() async {
    state = state.copyWith(chargement: true, viderErreur: true);
    try {
      final page = await _depot.mesVendeurs();
      if (!mounted) return;
      state = EtatVendeurs(
        vendeurs: page.elements,
        identifiants: page.elements.map((v) => v.vendeurId).toSet(),
        chargement: false,
      );
    } catch (erreur) {
      if (!mounted) return;
      state = state.copyWith(chargement: false, erreur: erreur);
    }
  }

  Future<bool> basculer(int vendeurId) async {
    final suivait = state.suit(vendeurId);
    try {
      if (suivait) {
        await _depot.nePlusSuivre(vendeurId);
        state = state.copyWith(
          vendeurs:
              state.vendeurs.where((v) => v.vendeurId != vendeurId).toList(),
          identifiants: {...state.identifiants}..remove(vendeurId),
        );
      } else {
        await _depot.suivre(vendeurId);
        await charger();
      }
      return !suivait;
    } catch (_) {
      rethrow;
    }
  }
}

final vendeursSuivisProvider =
    StateNotifierProvider<VendeursNotifier, EtatVendeurs>((ref) {
  final connecte = ref.watch(authProvider).estConnecte;
  return VendeursNotifier(
    ref.watch(favorisRepositoryProvider),
    connecte: connecte,
  );
});

/// Fil des annonces des vendeurs suivis.
///
/// `ref.watch(authProvider)` est indispensable : ce fil est personnel, et
/// sans lui le resultat du compte precedent resterait en cache apres une
/// deconnexion.
final filVendeursProvider = FutureProvider<List<Produit>>((ref) async {
  if (!ref.watch(authProvider).estConnecte) return const [];
  final page = await ref.watch(favorisRepositoryProvider).filDesVendeurs();
  return page.elements;
});
