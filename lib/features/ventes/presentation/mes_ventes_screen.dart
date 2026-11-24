import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formats.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../providers/ventes_providers.dart';
import 'widgets/vente_carte.dart';

/// Mes ventes et mes achats.
///
/// Deux onglets, parce que les gestes attendus ne sont pas les memes : le
/// vendeur confirme le paiement, l'acheteur confirme la reception.
class MesVentesScreen extends ConsumerStatefulWidget {
  const MesVentesScreen({super.key, this.ongletInitial = 0});

  final int ongletInitial;

  @override
  ConsumerState<MesVentesScreen> createState() => _MesVentesScreenState();
}

class _MesVentesScreenState extends ConsumerState<MesVentesScreen>
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventes et achats'),
        bottom: TabBar(
          controller: _onglets,
          tabs: const [
            Tab(text: 'Mes ventes'),
            Tab(text: 'Mes achats'),
          ],
        ),
      ),
      body: GradientBackground(
        anime: false,
        child: TabBarView(
          controller: _onglets,
          children: const [
            _Liste(cote: CoteVente.mesVentes),
            _Liste(cote: CoteVente.mesAchats),
          ],
        ),
      ),
    );
  }
}

class _Liste extends ConsumerWidget {
  const _Liste({required this.cote});

  final CoteVente cote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fournisseur =
        cote == CoteVente.mesVentes ? mesVentesProvider : mesAchatsProvider;
    final etat = ref.watch(fournisseur);
    final notifier = ref.read(fournisseur.notifier);

    return Column(
      children: [
        if (cote == CoteVente.mesVentes) const _BandeauRevenus(),
        _Filtres(actif: etat.filtreStatut, onChange: notifier.filtrer),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(revenusProvider);
              await notifier.charger();
            },
            child: _corps(context, etat, notifier),
          ),
        ),
      ],
    );
  }

  Widget _corps(
    BuildContext context,
    EtatVentes etat,
    VentesNotifier notifier,
  ) {
    if (etat.chargement && etat.ventes.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: Espaces.ecran),
        itemCount: 4,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: Espaces.sm),
          child: ShimmerBox(
            hauteur: 124,
            rayon: BorderRadius.all(Radius.circular(Rayons.md)),
          ),
        ),
      );
    }

    if (etat.erreur != null && etat.ventes.isEmpty) {
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
            icone: Icons.receipt_long_outlined,
            titre: filtre
                ? 'Rien avec ce filtre'
                : (cote == CoteVente.mesVentes
                    ? 'Aucune vente'
                    : 'Aucun achat'),
            message: filtre
                ? 'Changez de filtre pour voir les autres.'
                : (cote == CoteVente.mesVentes
                    ? 'Acceptez une demande de reservation, puis '
                        'enregistrez la vente depuis son detail.'
                    : 'Vos achats apparaitront ici des que le vendeur '
                        'aura enregistre la vente.'),
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
      itemCount: etat.ventes.length,
      separatorBuilder: (_, _) => const SizedBox(height: Espaces.sm),
      itemBuilder: (context, index) {
        final vente = etat.ventes[index];
        return VenteCarte(
          vente: vente,
          onTap: () => context.pushNamed(
            Routes.vente,
            pathParameters: {'id': '${vente.id}'},
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

/// Chiffre d'affaires, calcule sur les seules ventes comptabilisables.
class _BandeauRevenus extends ConsumerWidget {
  const _BandeauRevenus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenus = ref.watch(revenusProvider);

    return revenus.maybeWhen(
      data: (donnees) => Container(
        margin: const EdgeInsets.fromLTRB(
          Espaces.ecran,
          Espaces.sm,
          Espaces.ecran,
          0,
        ),
        padding: const EdgeInsets.all(Espaces.sm),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.emeraudeSombre, AppColors.sarcelleSombre],
          ),
          borderRadius: BorderRadius.circular(Rayons.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Chiffre d'affaires",
                    style: TextStyle(color: AppColors.blanc, fontSize: 11),
                  ),
                  Text(
                    Formats.montant(donnees.chiffreAffaires),
                    style: const TextStyle(
                      color: AppColors.blanc,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${donnees.ventesConfirmees} vente'
                    '${donnees.ventesConfirmees > 1 ? 's' : ''} comptabilisee'
                    '${donnees.ventesConfirmees > 1 ? 's' : ''} · '
                    '${donnees.nombreClients} client'
                    '${donnees.nombreClients > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: AppColors.blanc.withValues(alpha: 0.8),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (donnees.ventesEnAttenteDeConfirmation > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Espaces.xs,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blanc.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(Rayons.pilule),
                ),
                child: Text(
                  '${donnees.ventesEnAttenteDeConfirmation} a confirmer',
                  style: const TextStyle(
                    color: AppColors.blanc,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Filtres extends StatelessWidget {
  const _Filtres({required this.actif, required this.onChange});

  final String? actif;
  final ValueChanged<String?> onChange;

  static const _choix = <(String?, String)>[
    (null, 'Tout'),
    ('INITIATED', 'Declarees'),
    ('PAID', 'Payees'),
    ('COMPLETED', 'Terminees'),
    ('CANCELLED', 'Annulees'),
    ('REFUNDED', 'Remboursees'),
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
