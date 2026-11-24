import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../providers/reservations_providers.dart';
import 'widgets/reservation_carte.dart';

/// Mes reservations : ce que j'ai demande, et ce qu'on me demande.
///
/// Les deux cotes sont separes volontairement. Une demande recue appelle
/// une action de ma part ; une demande envoyee, non. Les melanger
/// obligerait a lire le role sur chaque ligne.
class MesReservationsScreen extends ConsumerStatefulWidget {
  const MesReservationsScreen({super.key, this.ongletInitial = 0});

  final int ongletInitial;

  @override
  ConsumerState<MesReservationsScreen> createState() =>
      _MesReservationsScreenState();
}

class _MesReservationsScreenState extends ConsumerState<MesReservationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _onglets;

  @override
  void initState() {
    super.initState();
    _onglets = TabController(
      length: 2,
      initialIndex: widget.ongletInitial.clamp(0, 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resume = ref.watch(resumeReservationsProvider);
    final aTraiter = resume.maybeWhen(
      data: (valeur) => valeur.aTraiter,
      orElse: () => 0,
    );
    final enAttente = resume.maybeWhen(
      data: (valeur) => valeur.demandesEnAttente,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations'),
        bottom: TabBar(
          controller: _onglets,
          tabs: [
            Tab(text: _libelle('Mes demandes', enAttente)),
            Tab(text: _libelle('Recues', aTraiter)),
          ],
        ),
      ),
      body: GradientBackground(
        anime: false,
        child: TabBarView(
          controller: _onglets,
          children: const [
            _Liste(cote: CoteReservation.mesDemandes),
            _Liste(cote: CoteReservation.demandesRecues),
          ],
        ),
      ),
    );
  }

  static String _libelle(String base, int nombre) =>
      nombre > 0 ? '$base ($nombre)' : base;
}

class _Liste extends ConsumerWidget {
  const _Liste({required this.cote});

  final CoteReservation cote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fournisseur = cote == CoteReservation.mesDemandes
        ? mesDemandesProvider
        : demandesRecuesProvider;
    final etat = ref.watch(fournisseur);
    final notifier = ref.read(fournisseur.notifier);

    return Column(
      children: [
        _Filtres(
          actif: etat.filtreStatut,
          onChange: notifier.filtrer,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(resumeReservationsProvider);
              await notifier.charger();
            },
            child: _corps(context, ref, etat, notifier),
          ),
        ),
      ],
    );
  }

  Widget _corps(
    BuildContext context,
    WidgetRef ref,
    EtatReservations etat,
    ReservationsNotifier notifier,
  ) {
    if (etat.chargement && etat.reservations.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: Espaces.ecran),
        itemCount: 4,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: Espaces.sm),
          child: ShimmerBox(
            hauteur: 132,
            rayon: BorderRadius.all(Radius.circular(Rayons.md)),
          ),
        ),
      );
    }

    if (etat.erreur != null && etat.reservations.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
          EtatErreur(erreur: etat.erreur!, onReessayer: notifier.charger),
        ],
      );
    }

    if (etat.estVide) {
      final filtre = etat.filtreStatut != null;
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
          EtatVide(
            icone: Icons.bookmark_border_rounded,
            titre: filtre
                ? 'Rien avec ce filtre'
                : (cote == CoteReservation.mesDemandes
                    ? 'Aucune demande envoyee'
                    : 'Aucune demande recue'),
            message: filtre
                ? 'Changez de filtre pour voir les autres reservations.'
                : (cote == CoteReservation.mesDemandes
                    ? 'Ouvrez une annonce et appuyez sur « Reserver » pour '
                        'demander une quantite au vendeur.'
                    : 'Les demandes sur vos annonces apparaitront ici.'),
            libelleAction: filtre ? 'Tout voir' : null,
            onAction: filtre ? () => notifier.filtrer(null) : null,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        Espaces.ecran,
        Espaces.xs,
        Espaces.ecran,
        Espaces.xxxl,
      ),
      itemCount: etat.reservations.length,
      separatorBuilder: (_, _) => const SizedBox(height: Espaces.sm),
      itemBuilder: (context, index) {
        final reservation = etat.reservations[index];
        return ReservationCarte(
          reservation: reservation,
          onTap: () => context.pushNamed(
            Routes.reservation,
            pathParameters: {'id': '${reservation.id}'},
          ),
        )
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: 24 * index),
              duration: Mouvements.normal,
            )
            .slideY(begin: 0.07, curve: Mouvements.sortie);
      },
    );
  }
}

/// Filtres par statut. Les codes sont ceux du serveur.
class _Filtres extends StatelessWidget {
  const _Filtres({required this.actif, required this.onChange});

  final String? actif;
  final ValueChanged<String?> onChange;

  static const _choix = <(String?, String)>[
    (null, 'Tout'),
    ('PENDING', 'En attente'),
    ('CONFIRMED', 'Confirmees'),
    ('FULFILLED', 'Vendues'),
    ('CANCELLED', 'Annulees'),
    ('EXPIRED', 'Expirees'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Espaces.ecran),
        itemCount: _choix.length,
        separatorBuilder: (_, _) => const SizedBox(width: Espaces.xs),
        itemBuilder: (context, index) {
          final (code, libelle) = _choix[index];
          final selectionne = actif == code;
          return Center(
            child: ChoiceChip(
              label: Text(libelle),
              selected: selectionne,
              onSelected: (_) => onChange(code),
              selectedColor: AppColors.emeraude.withValues(alpha: 0.18),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: selectionne ? FontWeight.w700 : FontWeight.w500,
                color: selectionne ? AppColors.emeraude : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
