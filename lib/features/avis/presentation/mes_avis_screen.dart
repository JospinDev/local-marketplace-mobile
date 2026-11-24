import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../domain/evaluation.dart';
import '../providers/avis_providers.dart';
import 'widgets/avis_carte.dart';
import 'widgets/deposer_avis_feuille.dart';
import 'widgets/etoiles.dart';

/// Mes avis : ceux que j'ai ecrits, et ceux que j'ai recus.
class MesAvisScreen extends ConsumerStatefulWidget {
  const MesAvisScreen({super.key, this.ongletInitial = 0});

  final int ongletInitial;

  @override
  ConsumerState<MesAvisScreen> createState() => _MesAvisScreenState();
}

class _MesAvisScreenState extends ConsumerState<MesAvisScreen>
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
        title: const Text('Avis'),
        bottom: TabBar(
          controller: _onglets,
          tabs: const [
            Tab(text: 'Mes avis'),
            Tab(text: 'Recus'),
          ],
        ),
      ),
      body: GradientBackground(
        anime: false,
        child: TabBarView(
          controller: _onglets,
          children: const [
            _Liste(cote: CoteAvis.ecrits),
            _Liste(cote: CoteAvis.recus),
          ],
        ),
      ),
    );
  }
}

class _Liste extends ConsumerWidget {
  const _Liste({required this.cote});

  final CoteAvis cote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fournisseur =
        cote == CoteAvis.ecrits ? mesAvisProvider : avisRecusProvider;
    final etat = ref.watch(fournisseur);
    final notifier = ref.read(fournisseur.notifier);

    return Column(
      children: [
        if (cote == CoteAvis.recus) const _BandeauReputation(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(maReputationProvider);
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
    EtatAvis etat,
    AvisNotifier notifier,
  ) {
    if (etat.chargement && etat.avis.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: Espaces.ecran),
        itemCount: 4,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: Espaces.sm),
          child: ShimmerBox(
            hauteur: 120,
            rayon: BorderRadius.all(Radius.circular(Rayons.md)),
          ),
        ),
      );
    }

    if (etat.erreur != null && etat.avis.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
          EtatErreur(erreur: etat.erreur!, onReessayer: notifier.charger),
        ],
      );
    }

    if (etat.estVide) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
          EtatVide(
            icone: Icons.star_outline_rounded,
            titre: cote == CoteAvis.ecrits
                ? 'Aucun avis ecrit'
                : 'Aucun avis recu',
            message: cote == CoteAvis.ecrits
                ? 'Vous pourrez noter un vendeur depuis le detail d\'un '
                    'achat, apres avoir confirme la reception du produit.'
                : 'Les avis de vos clients apparaitront ici, une fois '
                    'qu\'ils auront confirme la reception.',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        Espaces.ecran,
        Espaces.sm,
        Espaces.ecran,
        Espaces.xxxl,
      ),
      itemCount: etat.avis.length,
      separatorBuilder: (_, _) => const SizedBox(height: Espaces.sm),
      itemBuilder: (context, index) {
        final avis = etat.avis[index];
        return AvisCarte(
          avis: avis,
          montrerAuteur: cote == CoteAvis.recus,
          // Seul l'auteur corrige ou retire le sien ; le vendeur qui
          // recoit un avis abusif peut le signaler.
          onCorriger: cote == CoteAvis.ecrits && avis.probablementCorrigeable
              ? () => _corriger(context, ref, avis)
              : null,
          onRetirer: cote == CoteAvis.ecrits && avis.estValide
              ? () => _retirer(context, ref, avis, notifier)
              : null,
          onSignaler: cote == CoteAvis.recus
              ? () => _signaler(context, ref, avis)
              : null,
        )
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: 22 * index),
              duration: Mouvements.normal,
            )
            .slideY(begin: 0.06, curve: Mouvements.sortie);
      },
    );
  }

  Future<void> _corriger(
    BuildContext context,
    WidgetRef ref,
    Evaluation avis,
  ) async {
    await ouvrirDeposerAvis(
      context,
      venteId: avis.venteId,
      titreProduit: avis.produitTitre,
      vendeur: avis.vendeurUsername,
      existant: avis,
    );
  }

  Future<void> _retirer(
    BuildContext context,
    WidgetRef ref,
    Evaluation avis,
    AvisNotifier notifier,
  ) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Retirer cet avis ?'),
        content: const Text(
          'Il sortira des moyennes et des listes publiques. Il n\'est pas '
          'efface : vous le reverrez ici, marque comme retire.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.erreur),
            onPressed: () => Navigator.of(contexte).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      final resultat = await ref.read(avisRepositoryProvider).retirer(avis.id);
      notifier.appliquer(resultat.evaluation);
      ref.read(avisRecusProvider.notifier).appliquer(resultat.evaluation);
      ref.invalidate(maReputationProvider);
      if (avis.produitId != null) {
        ref.invalidate(avisProduitProvider(avis.produitId!));
      }
      if (context.mounted) {
        AppFeedback.succes(
          context,
          resultat.message.isNotEmpty ? resultat.message : 'Avis retire.',
        );
      }
    } catch (erreur) {
      if (context.mounted) AppFeedback.erreur(context, '$erreur');
    }
  }

  Future<void> _signaler(
    BuildContext context,
    WidgetRef ref,
    Evaluation avis,
  ) async {
    String? motif;
    final description = TextEditingController();

    final envoyer = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (contexte) => Padding(
        padding: EdgeInsets.only(
          left: Espaces.ecran,
          right: Espaces.ecran,
          top: Espaces.lg,
          bottom: MediaQuery.viewInsetsOf(contexte).bottom + Espaces.lg,
        ),
        child: StatefulBuilder(
          builder: (contexte, rafraichir) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Signaler cet avis',
                style: Theme.of(contexte).textTheme.titleMedium,
              ),
              const SizedBox(height: Espaces.xs),
              Text(
                'Un moderateur l\'examinera. Signaler un avis ne le masque '
                'pas automatiquement.',
                style: Theme.of(contexte).textTheme.bodySmall,
              ),
              const SizedBox(height: Espaces.md),
              RadioGroup<String>(
                groupValue: motif,
                onChanged: (valeur) => rafraichir(() => motif = valeur),
                child: Column(
                  children: motifsSignalementAvis.entries
                      .map(
                        (entree) => RadioListTile<String>(
                          value: entree.key,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(entree.value),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: Espaces.xs),
              TextField(
                controller: description,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Details (optionnel)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: Espaces.sm),
              FilledButton(
                onPressed:
                    motif == null ? null : () => Navigator.of(contexte).pop(true),
                child: const Text('Envoyer le signalement'),
              ),
            ],
          ),
        ),
      ),
    );

    if (envoyer != true || motif == null) {
      description.dispose();
      return;
    }

    try {
      await ref.read(avisRepositoryProvider).signaler(
            avis.id,
            motif: motif!,
            description: description.text,
          );
      if (context.mounted) {
        AppFeedback.succes(context, 'Signalement envoye. Merci.');
      }
    } catch (erreur) {
      if (context.mounted) AppFeedback.erreur(context, '$erreur');
    } finally {
      description.dispose();
    }
  }
}

/// Ma reputation de vendeur, telle que le serveur la calcule.
class _BandeauReputation extends ConsumerWidget {
  const _BandeauReputation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reputation = ref.watch(maReputationProvider);

    return reputation.maybeWhen(
      data: (donnees) {
        if (donnees.estVide) return const SizedBox.shrink();
        return Container(
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
                      'Ma reputation',
                      style: TextStyle(color: AppColors.blanc, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _Chiffre(
                          libelle: 'Produits',
                          note: donnees.noteProduit,
                        ),
                        const SizedBox(width: Espaces.md),
                        _Chiffre(
                          libelle: 'Vendeur',
                          note: donnees.noteVendeur,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '${donnees.nombreEvaluations}',
                    style: const TextStyle(
                      color: AppColors.blanc,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'avis',
                    style: TextStyle(
                      color: AppColors.blanc.withValues(alpha: 0.8),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.libelle, required this.note});

  final String libelle;
  final double? note;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$libelle ',
          style: TextStyle(
            color: AppColors.blanc.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
        if (note == null)
          Text(
            '—',
            style: TextStyle(color: AppColors.blanc.withValues(alpha: 0.8)),
          )
        else ...[
          Etoiles(note: note!, taille: 12, couleur: AppColors.orClair),
          const SizedBox(width: 3),
          Text(
            note!.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.blanc,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
