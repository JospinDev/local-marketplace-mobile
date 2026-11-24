import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/notifications_repository.dart';
import '../data/notifications_socket.dart';
import '../domain/notification.dart';

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(api: ref.watch(apiClientProvider));
});

@immutable
class EtatNotifications {
  const EtatNotifications({
    this.notifications = const [],
    this.nonLues = 0,
    this.chargement = true,
    this.seulementNonLues = false,
    this.erreur,
  });

  final List<NotificationItem> notifications;

  /// Compteur du serveur, et non la taille de la liste : la liste est
  /// paginee, le compteur porte sur tout.
  final int nonLues;

  final bool chargement;
  final bool seulementNonLues;
  final Object? erreur;

  bool get estVide =>
      notifications.isEmpty && !chargement && erreur == null;

  EtatNotifications copyWith({
    List<NotificationItem>? notifications,
    int? nonLues,
    bool? chargement,
    bool? seulementNonLues,
    Object? erreur,
    bool viderErreur = false,
  }) {
    return EtatNotifications(
      notifications: notifications ?? this.notifications,
      nonLues: nonLues ?? this.nonLues,
      chargement: chargement ?? this.chargement,
      seulementNonLues: seulementNonLues ?? this.seulementNonLues,
      erreur: viderErreur ? null : (erreur ?? this.erreur),
    );
  }
}

class NotificationsNotifier extends StateNotifier<EtatNotifications> {
  NotificationsNotifier({
    required NotificationsRepository depot,
    required NotificationsSocket canal,
    required bool connecte,
  })  : _depot = depot,
        _canal = canal,
        super(EtatNotifications(chargement: connecte)) {
    if (connecte) _demarrer();
  }

  final NotificationsRepository _depot;
  final NotificationsSocket _canal;
  StreamSubscription<Map<String, dynamic>>? _ecoute;

  Future<void> _demarrer() async {
    _ecoute = _canal.evenements.listen(_surEvenement);
    await charger();
    await _canal.connecter();
  }

  Future<void> charger() async {
    state = state.copyWith(chargement: true, viderErreur: true);
    try {
      final page = await _depot.liste(
        seulementNonLues: state.seulementNonLues ? true : null,
      );
      final compteur = await _depot.nonLues();
      if (!mounted) return;
      state = state.copyWith(
        notifications: page.elements,
        nonLues: compteur,
        chargement: false,
      );
    } catch (erreur) {
      if (!mounted) return;
      state = state.copyWith(chargement: false, erreur: erreur);
    }
  }

  Future<void> basculerFiltre(bool seulementNonLues) async {
    state = state.copyWith(seulementNonLues: seulementNonLues);
    await charger();
  }

  // ----------------------------------------------------------- temps reel
  void _surEvenement(Map<String, dynamic> evenement) {
    if (!mounted) return;
    final type = evenement['type'] as String? ?? '';

    if (type == 'notification.nouvelle') {
      final brut = evenement['notification'];
      final compteur = (evenement['non_lues'] as num?)?.toInt();

      if (brut is Map<String, dynamic>) {
        final arrivee = NotificationItem.depuisJson(brut);
        // Garde-fou contre une double diffusion : on ne reinsere pas une
        // notification deja presente.
        final deja = state.notifications.any((n) => n.id == arrivee.id);
        state = state.copyWith(
          notifications:
              deja ? state.notifications : [arrivee, ...state.notifications],
          nonLues: compteur ?? state.nonLues + 1,
        );
      } else if (compteur != null) {
        state = state.copyWith(nonLues: compteur);
      }
      return;
    }

    if (type == 'notifications.lues' || type == 'compteur') {
      final compteur = (evenement['non_lues'] as num?)?.toInt();
      if (compteur == null) return;

      // Un autre appareil a lu : on reflete le compteur, et si tout a ete
      // lu on marque la liste locale en consequence.
      state = state.copyWith(
        nonLues: compteur,
        notifications: compteur == 0
            ? state.notifications
                .map((n) => n.estLue ? n : n.copyWith(estLue: true))
                .toList(growable: false)
            : state.notifications,
      );
    }
  }

  // -------------------------------------------------------------- lecture
  /// Marque une notification comme lue, de facon optimiste.
  ///
  /// L'ouverture doit etre instantanee : attendre l'aller-retour reseau
  /// avant d'eteindre la pastille donnerait l'impression d'un bogue.
  Future<void> marquerLue(NotificationItem notification) async {
    if (notification.estLue) return;

    final avant = state;
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.id == notification.id
              ? n.copyWith(estLue: true, lueLe: DateTime.now())
              : n)
          .toList(growable: false),
      nonLues: state.nonLues > 0 ? state.nonLues - 1 : 0,
    );

    try {
      await _depot.marquerLue(notification.id);
    } catch (_) {
      if (mounted) state = avant;
    }
  }

  Future<void> toutMarquerLu() async {
    if (state.nonLues == 0) return;

    final avant = state;
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.estLue ? n : n.copyWith(estLue: true))
          .toList(growable: false),
      nonLues: 0,
    );

    try {
      await _depot.marquerLues();
      // Le filtre « non lues » n'a plus rien a montrer : on recharge pour
      // que la liste soit honnete.
      if (state.seulementNonLues) await charger();
    } catch (_) {
      if (mounted) state = avant;
    }
  }

  @override
  void dispose() {
    _ecoute?.cancel();
    _canal.fermer();
    super.dispose();
  }
}

/// Etat global des notifications.
///
/// Volontairement NON `autoDispose` : le canal doit rester ouvert pendant
/// toute la session pour que la pastille de l'en-tete se mette a jour
/// meme quand l'ecran des notifications n'est pas affiche.
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, EtatNotifications>((ref) {
  final connecte = ref.watch(authProvider).estConnecte;
  return NotificationsNotifier(
    depot: ref.watch(notificationsRepositoryProvider),
    canal: NotificationsSocket(jetons: ref.watch(tokenStoreProvider)),
    connecte: connecte,
  );
});

/// Raccourci pour la pastille de la cloche.
final nonLuesProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider.select((e) => e.nonLues)),
);
