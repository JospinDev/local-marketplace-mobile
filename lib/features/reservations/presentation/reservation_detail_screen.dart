import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formats.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/reseau_image.dart';
import '../../ventes/presentation/widgets/enregistrer_vente_feuille.dart';
import '../data/reservations_repository.dart';
import '../domain/reservation.dart';
import '../providers/reservations_providers.dart';
import 'widgets/reservation_carte.dart';

/// Detail d'une reservation, construit autour de `mon_role`.
///
/// Les boutons proposes decoulent du role et du statut, jamais d'une
/// comparaison d'identifiants : c'est le serveur qui sait de quel cote on
/// se trouve, et il le dit dans la reponse.
class ReservationDetailScreen extends ConsumerStatefulWidget {
  const ReservationDetailScreen({super.key, required this.reservationId});

  final int reservationId;

  @override
  ConsumerState<ReservationDetailScreen> createState() =>
      _ReservationDetailScreenState();
}

class _ReservationDetailScreenState
    extends ConsumerState<ReservationDetailScreen> {
  bool _actionEnCours = false;

  ReservationsRepository get _depot =>
      ref.read(reservationsRepositoryProvider);

  /// Execute une action et propage la reservation renvoyee partout.
  Future<void> _executer(
    Future<ResultatReservation> Function() action, {
    String repli = 'Reservation mise a jour.',
  }) async {
    if (_actionEnCours) return;
    setState(() => _actionEnCours = true);

    try {
      final resultat = await action();

      ref
          .read(mesDemandesProvider.notifier)
          .appliquer(resultat.reservation);
      ref
          .read(demandesRecuesProvider.notifier)
          .appliquer(resultat.reservation);
      ref.invalidate(resumeReservationsProvider);
      ref.invalidate(reservationProvider(widget.reservationId));

      if (!mounted) return;
      AppFeedback.succes(
        context,
        resultat.message.isNotEmpty ? resultat.message : repli,
      );
    } catch (erreur) {
      // Les messages du serveur sont affichables tels quels : « Stock
      // insuffisant : 2 unite(s) disponible(s) » vaut mieux que « echec ».
      if (mounted) AppFeedback.erreur(context, '$erreur');
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fiche = ref.watch(reservationProvider(widget.reservationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Reservation')),
      body: GradientBackground(
        anime: false,
        child: fiche.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (erreur, _) => EtatErreur(
            erreur: erreur,
            onReessayer: () =>
                ref.invalidate(reservationProvider(widget.reservationId)),
          ),
          data: (reservation) => _corps(reservation),
        ),
      ),
    );
  }

  Widget _corps(Reservation reservation) {
    final theme = Theme.of(context);
    final produit = reservation.produit;
    final apparence = apparenceStatut(reservation.statut);
    final devise = produit?.devise ?? 'BIF';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espaces.ecran,
        Espaces.md,
        Espaces.ecran,
        Espaces.xxxl,
      ),
      children: [
        // --- statut -------------------------------------------------
        Container(
          padding: const EdgeInsets.all(Espaces.sm),
          decoration: BoxDecoration(
            color: apparence.couleur.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Rayons.sm),
          ),
          child: Row(
            children: [
              Icon(apparence.icone, color: apparence.couleur, size: 20),
              const SizedBox(width: Espaces.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.statutLibelle,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: apparence.couleur,
                      ),
                    ),
                    Text(
                      _explication(reservation),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (reservation.accepteePartiellement) ...[
          const SizedBox(height: Espaces.sm),
          _Avis(
            icone: Icons.call_split_rounded,
            couleur: AppColors.alerte,
            texte: 'Acceptation partielle : '
                '${reservation.quantiteConfirmee} sur '
                '${reservation.quantiteDemandee} demandee'
                '${reservation.quantiteDemandee > 1 ? 's' : ''}.',
          ),
        ],

        // --- produit ------------------------------------------------
        const SizedBox(height: Espaces.md),
        SolidCard(
          onTap: produit == null
              ? null
              : () => context.pushNamed(
                    Routes.produit,
                    pathParameters: {'id': '${produit.id}'},
                    extra: {'hero': 'reservation'},
                  ),
          child: Row(
            children: [
              ReseauImage(
                url: produit?.image,
                largeur: 56,
                hauteur: 56,
                rayon: BorderRadius.circular(Rayons.sm),
              ),
              const SizedBox(width: Espaces.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produit?.titre ?? 'Annonce',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (produit?.prix != null)
                      Text(
                        '${Formats.montant(produit!.prix!, devise: devise)}'
                        ' / unite',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraude,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),

        // --- quantites ----------------------------------------------
        const SizedBox(height: Espaces.md),
        Text('Quantites', style: theme.textTheme.titleMedium),
        const SizedBox(height: Espaces.xs),
        SolidCard(
          child: Column(
            children: [
              _Ligne(
                libelle: 'Demandee',
                valeur: Formats.unites(reservation.quantiteDemandee),
              ),
              _Ligne(
                libelle: 'Confirmee',
                valeur: Formats.unites(reservation.quantiteConfirmee),
              ),
              _Ligne(
                libelle: 'Mise de cote maintenant',
                valeur: Formats.unites(reservation.quantiteImmobilisee),
                accent: reservation.quantiteImmobilisee > 0,
              ),
              if (reservation.quantiteLivree > 0)
                _Ligne(
                  libelle: 'Deja vendue',
                  valeur: Formats.unites(reservation.quantiteLivree),
                ),
              if (reservation.valeurEstimee != null)
                _Ligne(
                  libelle: 'Valeur estimee',
                  valeur: Formats.montant(
                    reservation.valeurEstimee!,
                    devise: devise,
                  ),
                  note: 'Au prix du jour, ce n\'est pas un revenu.',
                ),
            ],
          ),
        ),

        // --- interlocuteur et messages ------------------------------
        const SizedBox(height: Espaces.md),
        Text(
          reservation.monRole.estVendeur ? 'Acheteur' : 'Vendeur',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Espaces.xs),
        SolidCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reservation.monRole.estVendeur
                    ? reservation.acheteurUsername ?? '?'
                    : reservation.vendeurUsername ?? '?',
                style: theme.textTheme.titleSmall,
              ),
              if (reservation.message.isNotEmpty) ...[
                const SizedBox(height: Espaces.xs),
                Text(
                  reservation.message,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (reservation.motif.isNotEmpty) ...[
                const SizedBox(height: Espaces.xs),
                Text(
                  'Motif : ${reservation.motif}'
                  '${reservation.clotureePar.isNotEmpty ? ' (${reservation.clotureePar})' : ''}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.erreur),
                ),
              ],
            ],
          ),
        ),

        // --- dates --------------------------------------------------
        const SizedBox(height: Espaces.md),
        SolidCard(
          child: Column(
            children: [
              _Ligne(
                libelle: 'Demandee le',
                valeur: Formats.depuis(reservation.creeLe),
              ),
              if (reservation.confirmeeLe != null)
                _Ligne(
                  libelle: 'Acceptee le',
                  valeur: Formats.depuis(reservation.confirmeeLe),
                ),
              if (reservation.expireLe != null)
                _Ligne(
                  libelle: 'Delai de retrait',
                  valeur: _delai(reservation.expireLe!),
                  note: 'Le compte a rebours repart a l\'acceptation.',
                ),
              if (reservation.clotureeLe != null)
                _Ligne(
                  libelle: 'Cloturee le',
                  valeur: Formats.depuis(reservation.clotureeLe),
                ),
            ],
          ),
        ),

        const SizedBox(height: Espaces.lg),
        ..._actions(reservation),
      ],
    );
  }

  // --------------------------------------------------------------- actions
  List<Widget> _actions(Reservation reservation) {
    final boutons = <Widget>[];

    if (reservation.jePeuxEnregistrerLaVente) {
      boutons.add(
        AppButton(
          libelle: 'Enregistrer la vente',
          icone: Icons.point_of_sale_rounded,
          enChargement: _actionEnCours,
          onPressed: _actionEnCours
              ? null
              : () => _enregistrerLaVente(reservation),
        ),
      );
    }

    if (reservation.jePeuxAccepter) {
      boutons.add(
        AppButton(
          libelle: 'Accepter la demande',
          icone: Icons.check_rounded,
          enChargement: _actionEnCours,
          onPressed: _actionEnCours ? null : () => _accepter(reservation),
        ),
      );
    }

    if (reservation.jePeuxChangerLaQuantite) {
      boutons.add(
        AppButton(
          libelle: 'Changer la quantite',
          style: StyleBouton.secondaire,
          icone: Icons.tune_rounded,
          onPressed:
              _actionEnCours ? null : () => _changerQuantite(reservation),
        ),
      );
    }

    if (reservation.jePeuxRefuser) {
      boutons.add(
        AppButton(
          libelle: 'Refuser',
          style: StyleBouton.secondaire,
          icone: Icons.close_rounded,
          onPressed: _actionEnCours
              ? null
              : () => _avecMotif(
                    titre: 'Refuser la demande',
                    libelleAction: 'Refuser',
                    obligatoire: false,
                    action: (motif) =>
                        _depot.refuser(reservation.id, motif: motif),
                  ),
        ),
      );
    }

    if (reservation.jePeuxAnnuler) {
      boutons.add(
        AppButton(
          libelle: 'Annuler la reservation',
          style: StyleBouton.secondaire,
          icone: Icons.cancel_outlined,
          onPressed: _actionEnCours
              ? null
              : () => _avecMotif(
                    titre: 'Annuler la reservation',
                    libelleAction: 'Annuler la reservation',
                    obligatoire: false,
                    note: reservation.statut.immobiliseDuStock
                        ? 'Les unites mises de cote redeviendront '
                            'disponibles pour les autres acheteurs.'
                        : null,
                    action: (motif) =>
                        _depot.annuler(reservation.id, motif: motif),
                  ),
        ),
      );
    }

    if (boutons.isEmpty) return const [];

    return [
      for (final bouton in boutons) ...[
        bouton,
        const SizedBox(height: Espaces.xs),
      ],
    ];
  }

  Future<void> _accepter(Reservation reservation) async {
    final quantite = await _demanderQuantite(
      titre: 'Accepter la demande',
      initiale: reservation.quantiteDemandee,
      maximum: reservation.quantiteDemandee,
      note: 'Vous pouvez accepter moins que la quantite demandee. La '
          'quantite acceptee sera mise de cote immediatement.',
      libelleAction: 'Accepter',
    );
    if (quantite == null) return;

    await _executer(
      () => _depot.accepter(
        reservation.id,
        // Envoyer la quantite complete est inutile : sans parametre, le
        // serveur accepte tout. On ne l'envoie donc qu'en cas d'ecart.
        quantite:
            quantite == reservation.quantiteDemandee ? null : quantite,
      ),
      repli: 'Demande acceptee.',
    );
  }

  Future<void> _changerQuantite(Reservation reservation) async {
    final disponible = reservation.produit?.quantiteDisponible;
    final quantite = await _demanderQuantite(
      titre: 'Changer la quantite',
      initiale: reservation.quantiteUtile,
      // En PENDING, le plafond reel est le disponible du moment ; le
      // serveur tranchera de toute facon.
      maximum: disponible != null && disponible > 0 ? disponible : 999,
      note: reservation.monRole.estVendeur
          ? 'Vous ajustez la quantite mise de cote sur votre stock.'
          : 'Le vendeur n\'a encore rien promis : vous pouvez changer '
              'librement votre demande.',
      libelleAction: 'Enregistrer',
    );
    if (quantite == null) return;

    await _executer(
      () => _depot.changerQuantite(reservation.id, quantite),
      repli: 'Quantite mise a jour.',
    );
  }

  Future<void> _enregistrerLaVente(Reservation reservation) async {
    final enregistree = await ouvrirEnregistrerVente(
      context,
      reservation: reservation,
    );
    if (enregistree != true) return;

    ref.invalidate(reservationProvider(widget.reservationId));
    ref.invalidate(resumeReservationsProvider);
    ref.read(demandesRecuesProvider.notifier).charger();
  }

  // ---------------------------------------------------------- dialogues
  Future<int?> _demanderQuantite({
    required String titre,
    required int initiale,
    required int maximum,
    required String note,
    required String libelleAction,
  }) {
    var valeur = initiale.clamp(1, maximum < 1 ? 1 : maximum);

    return showDialog<int>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text(titre),
        content: StatefulBuilder(
          builder: (contexte, rafraichir) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(note, style: Theme.of(contexte).textTheme.bodySmall),
              const SizedBox(height: Espaces.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    onPressed: valeur > 1
                        ? () => rafraichir(() => valeur--)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Text(
                    '$valeur',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: valeur < maximum
                        ? () => rafraichir(() => valeur++)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexte).pop(valeur),
            child: Text(libelleAction),
          ),
        ],
      ),
    );
  }

  Future<void> _avecMotif({
    required String titre,
    required String libelleAction,
    required bool obligatoire,
    required Future<ResultatReservation> Function(String? motif) action,
    String? note,
  }) async {
    final champ = TextEditingController();

    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text(titre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (note != null) ...[
              Text(note, style: Theme.of(contexte).textTheme.bodySmall),
              const SizedBox(height: Espaces.sm),
            ],
            TextField(
              controller: champ,
              maxLines: 2,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: obligatoire ? 'Motif' : 'Motif (optionnel)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: const Text('Retour'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.erreur),
            onPressed: () => Navigator.of(contexte).pop(true),
            child: Text(libelleAction),
          ),
        ],
      ),
    );

    if (confirme == true) {
      await _executer(() => action(champ.text));
    }
    champ.dispose();
  }

  // ------------------------------------------------------------- textes
  static String _explication(Reservation reservation) {
    switch (reservation.statut) {
      case StatutReservation.pending:
        return reservation.monRole.estVendeur
            ? 'En attente de votre reponse. Rien n\'est encore mis de cote.'
            : 'En attente du vendeur. Le stock n\'est pas encore immobilise.';
      case StatutReservation.confirmed:
        return reservation.monRole.estVendeur
            ? 'La quantite est retiree de votre disponible.'
            : 'Le vendeur garde la quantite pour vous jusqu\'au delai.';
      case StatutReservation.fulfilled:
        return 'Transformee en vente.';
      case StatutReservation.cancelled:
        return 'Annulee. Le stock a ete rendu disponible.';
      case StatutReservation.expired:
        return 'Delai de retrait depasse. Le stock a ete libere.';
      case StatutReservation.inconnu:
        return '';
    }
  }

  static String _delai(DateTime expireLe) {
    final restant = expireLe.difference(DateTime.now());
    if (restant.isNegative) return 'Depasse';
    if (restant.inDays >= 1) return '${restant.inDays} jour(s) restant(s)';
    if (restant.inHours >= 1) return '${restant.inHours} h restantes';
    return '${restant.inMinutes} min restantes';
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.libelle,
    required this.valeur,
    this.accent = false,
    this.note,
  });

  final String libelle;
  final String valeur;
  final bool accent;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(libelle, style: theme.textTheme.bodyMedium),
              ),
              Text(
                valeur,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accent ? AppColors.emeraude : null,
                ),
              ),
            ],
          ),
          if (note != null)
            Text(
              note!,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
            ),
        ],
      ),
    );
  }
}

class _Avis extends StatelessWidget {
  const _Avis({
    required this.icone,
    required this.couleur,
    required this.texte,
  });

  final IconData icone;
  final Color couleur;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Espaces.sm),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Rayons.sm),
      ),
      child: Row(
        children: [
          Icon(icone, size: 17, color: couleur),
          const SizedBox(width: Espaces.xs),
          Expanded(
            child: Text(texte, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
