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
import '../../reservations/providers/reservations_providers.dart';
import '../data/ventes_repository.dart';
import '../domain/vente.dart';
import '../providers/ventes_providers.dart';
import 'widgets/vente_carte.dart';

/// Detail d'une vente, avec le double accuse mis en avant.
class VenteDetailScreen extends ConsumerStatefulWidget {
  const VenteDetailScreen({super.key, required this.venteId});

  final int venteId;

  @override
  ConsumerState<VenteDetailScreen> createState() => _VenteDetailScreenState();
}

class _VenteDetailScreenState extends ConsumerState<VenteDetailScreen> {
  bool _actionEnCours = false;

  VentesRepository get _depot => ref.read(ventesRepositoryProvider);

  Future<void> _executer(
    Future<ResultatVente> Function() action, {
    String repli = 'Vente mise a jour.',
  }) async {
    if (_actionEnCours) return;
    setState(() => _actionEnCours = true);

    try {
      final resultat = await action();

      ref.read(mesVentesProvider.notifier).appliquer(resultat.vente);
      ref.read(mesAchatsProvider.notifier).appliquer(resultat.vente);
      ref.invalidate(revenusProvider);
      ref.invalidate(venteProvider(widget.venteId));

      // Une annulation rend du stock : les reservations en dependent.
      final reservation = resultat.reservation;
      if (reservation != null) {
        ref.read(demandesRecuesProvider.notifier).appliquer(reservation);
        ref.read(mesDemandesProvider.notifier).appliquer(reservation);
      }
      ref.invalidate(resumeReservationsProvider);

      if (!mounted) return;
      AppFeedback.succes(
        context,
        resultat.message.isNotEmpty ? resultat.message : repli,
      );
    } catch (erreur) {
      if (mounted) AppFeedback.erreur(context, '$erreur');
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fiche = ref.watch(venteProvider(widget.venteId));

    return Scaffold(
      appBar: AppBar(title: Text('Vente #${widget.venteId}')),
      body: GradientBackground(
        anime: false,
        child: fiche.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (erreur, _) => EtatErreur(
            erreur: erreur,
            onReessayer: () => ref.invalidate(venteProvider(widget.venteId)),
          ),
          data: _corps,
        ),
      ),
    );
  }

  Widget _corps(Vente vente) {
    final theme = Theme.of(context);
    final apparence = apparenceVente(vente.statut);

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
                      vente.statutLibelle,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: apparence.couleur,
                      ),
                    ),
                    Text(
                      vente.estComptabilisable
                          ? "Comptee dans votre chiffre d'affaires."
                          : 'Pas encore comptee dans le chiffre d\'affaires.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- le double accuse ---------------------------------------
        const SizedBox(height: Espaces.md),
        Text('Avancement', style: theme.textTheme.titleMedium),
        const SizedBox(height: Espaces.xs),
        SolidCard(
          child: Column(
            children: [
              _Etape(
                titre: 'Vente declaree par le vendeur',
                date: vente.creeLe,
                faite: true,
              ),
              _Etape(
                titre: 'Paiement declare recu',
                sousTitre: 'Le vendeur confirme avoir ete paye.',
                date: vente.confirmeeLe,
                faite: vente.confirmeeLe != null,
              ),
              _Etape(
                titre: 'Reception confirmee par l\'acheteur',
                sousTitre:
                    "C'est ce geste qui termine la vente et ouvre le droit "
                    'a un avis.',
                date: vente.confirmeeParAcheteurLe,
                faite: vente.confirmeeParAcheteurLe != null,
                derniere: true,
              ),
            ],
          ),
        ),

        if (vente.statut.estAnnulee && vente.motifAnnulation.isNotEmpty) ...[
          const SizedBox(height: Espaces.sm),
          Container(
            padding: const EdgeInsets.all(Espaces.sm),
            decoration: BoxDecoration(
              color: AppColors.erreur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Rayons.sm),
            ),
            child: Row(
              children: [
                const Icon(Icons.block_rounded,
                    size: 17, color: AppColors.erreur),
                const SizedBox(width: Espaces.xs),
                Expanded(
                  child: Text(
                    'Motif : ${vente.motifAnnulation}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],

        // --- lignes -------------------------------------------------
        const SizedBox(height: Espaces.md),
        Text('Detail', style: theme.textTheme.titleMedium),
        const SizedBox(height: Espaces.xs),
        SolidCard(
          child: Column(
            children: [
              for (final ligne in vente.lignes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => context.pushNamed(
                            Routes.produit,
                            pathParameters: {'id': '${ligne.produitId}'},
                            extra: {'hero': 'vente'},
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ligne.produitTitre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                '${ligne.quantite} x '
                                '${Formats.montant(ligne.prixUnitaire, devise: vente.devise)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: Espaces.xs),
                      Text(
                        Formats.montant(ligne.sousTotal, devise: vente.devise),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              const Divider(height: Espaces.md),
              Row(
                children: [
                  Expanded(
                    child: Text('Total', style: theme.textTheme.titleSmall),
                  ),
                  Text(
                    Formats.montant(vente.montantTotal, devise: vente.devise),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emeraude,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Espaces.xxs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Moyen de paiement',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    vente.moyenPaiementLibelle.isNotEmpty
                        ? vente.moyenPaiementLibelle
                        : vente.moyenPaiement.libelle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Declaratif : aucun paiement en ligne n\'a eu lieu.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                ),
              ),
            ],
          ),
        ),

        // --- interlocuteur ------------------------------------------
        const SizedBox(height: Espaces.md),
        SolidCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vente.monRole.estVendeur ? 'Client' : 'Vendeur',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                vente.monRole.estVendeur
                    ? vente.acheteurUsername ?? '?'
                    : vente.vendeurUsername ?? '?',
                style: theme.textTheme.titleSmall,
              ),
              if (vente.reservationId != null) ...[
                const SizedBox(height: Espaces.xs),
                InkWell(
                  onTap: () => context.pushNamed(
                    Routes.reservation,
                    pathParameters: {'id': '${vente.reservationId}'},
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bookmark_rounded,
                          size: 15, color: AppColors.emeraude),
                      SizedBox(width: Espaces.xxs),
                      Text(
                        "Voir la reservation d'origine",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emeraude,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (vente.note.isNotEmpty) ...[
                const SizedBox(height: Espaces.xs),
                Text(vente.note, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),

        const SizedBox(height: Espaces.lg),
        ..._actions(vente),
      ],
    );
  }

  List<Widget> _actions(Vente vente) {
    final boutons = <Widget>[];

    if (vente.jePeuxConfirmerLePaiement) {
      boutons.add(
        AppButton(
          libelle: 'J\'ai recu le paiement',
          icone: Icons.payments_rounded,
          enChargement: _actionEnCours,
          onPressed: _actionEnCours
              ? null
              : () => _confirmer(
                    titre: 'Confirmer le paiement',
                    message:
                        'Declarez-vous avoir recu le paiement ? La vente '
                        'comptera alors dans votre chiffre d\'affaires.',
                    libelleAction: 'Oui, paiement recu',
                    action: () => _depot.confirmerPaiement(vente.id),
                  ),
        ),
      );
    }

    if (vente.jePeuxConfirmerLaReception) {
      boutons.add(
        AppButton(
          libelle: 'J\'ai recu le produit',
          icone: Icons.inventory_rounded,
          enChargement: _actionEnCours,
          onPressed: _actionEnCours
              ? null
              : () => _confirmer(
                    titre: 'Confirmer la reception',
                    message:
                        'Confirmez-vous avoir recu le produit ? La vente '
                        'sera terminee et vous pourrez laisser un avis.',
                    libelleAction: 'Oui, produit recu',
                    action: () => _depot.confirmerReception(vente.id),
                  ),
        ),
      );
    }

    if (vente.ouvreLeDroitAUnAvis) {
      boutons.add(
        AppButton(
          libelle: 'Laisser un avis',
          style: StyleBouton.secondaire,
          icone: Icons.star_outline_rounded,
          onPressed: () => AppFeedback.info(
            context,
            'Les avis arrivent a l\'etape 9.',
          ),
        ),
      );
    }

    if (vente.jePeuxAnnuler) {
      boutons.add(
        AppButton(
          libelle: 'Annuler la vente',
          style: StyleBouton.secondaire,
          icone: Icons.cancel_outlined,
          onPressed: _actionEnCours ? null : () => _annuler(vente),
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

  Future<void> _confirmer({
    required String titre,
    required String message,
    required String libelleAction,
    required Future<ResultatVente> Function() action,
  }) async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexte).pop(true),
            child: Text(libelleAction),
          ),
        ],
      ),
    );

    if (oui == true) await _executer(action);
  }

  /// Le motif est OBLIGATOIRE : le serveur refuse l'annulation sans lui.
  /// Le bouton reste donc desactive tant que le champ est vide, plutot que
  /// d'envoyer une requete vouee a echouer.
  Future<void> _annuler(Vente vente) async {
    final champ = TextEditingController();

    final motif = await showDialog<String>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Annuler la vente'),
        content: StatefulBuilder(
          builder: (contexte, rafraichir) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                vente.statut == StatutVente.paid
                    ? 'Le paiement avait ete declare recu : la vente partira '
                        'en « remboursee », pour que la trace reste visible.'
                    : 'Les quantites redeviendront disponibles.',
                style: Theme.of(contexte).textTheme.bodySmall,
              ),
              const SizedBox(height: Espaces.sm),
              TextField(
                controller: champ,
                maxLines: 2,
                maxLength: 500,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => rafraichir(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motif (obligatoire)',
                  hintText: 'Produit defectueux',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(),
            child: const Text('Retour'),
          ),
          StatefulBuilder(
            builder: (contexte, _) => ValueListenableBuilder(
              valueListenable: champ,
              builder: (contexte, valeur, _) => FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.erreur),
                onPressed: valeur.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(contexte).pop(valeur.text.trim()),
                child: const Text('Annuler la vente'),
              ),
            ),
          ),
        ],
      ),
    );

    if (motif != null && motif.isNotEmpty) {
      await _executer(() => _depot.annuler(vente.id, motif: motif));
    }
    champ.dispose();
  }
}

/// Une etape du double accuse.
class _Etape extends StatelessWidget {
  const _Etape({
    required this.titre,
    required this.faite,
    this.sousTitre,
    this.date,
    this.derniere = false,
  });

  final String titre;
  final String? sousTitre;
  final DateTime? date;
  final bool faite;
  final bool derniere;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: faite ? AppColors.emeraude : Colors.transparent,
                border: Border.all(
                  color: faite ? AppColors.emeraude : theme.dividerColor,
                  width: 1.5,
                ),
              ),
              child: faite
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: AppColors.blanc)
                  : null,
            ),
            if (!derniere)
              Container(
                width: 2,
                height: 34,
                color: faite ? AppColors.emeraude : theme.dividerColor,
              ),
          ],
        ),
        const SizedBox(width: Espaces.sm),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: derniere ? 0 : Espaces.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: faite ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (sousTitre != null)
                  Text(
                    sousTitre!,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                if (date != null)
                  Text(
                    Formats.depuis(date),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emeraude,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
