import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formats.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../avis/presentation/widgets/etoiles.dart';
import '../domain/tableau_bord.dart';
import '../providers/tableau_bord_providers.dart';

/// Tableau de bord vendeur (etape 10).
///
/// La regle qui structure l'ecran : **le chiffre d'affaires ne compte que
/// les ventes confirmees**. La valeur immobilisee par des reservations est
/// affichee a cote, jamais additionnee — c'est de l'argent qui peut encore
/// ne jamais arriver.
class TableauBordScreen extends ConsumerWidget {
  const TableauBordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
      body: GradientBackground(
        anime: false,
        child: RefreshIndicator(
          onRefresh: () async => rafraichirTableauBord(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Espaces.ecran,
              Espaces.md,
              Espaces.ecran,
              Espaces.xxxl,
            ),
            children: const [
              _Revenus(),
              SizedBox(height: Espaces.md),
              _VueGenerale(),
              SizedBox(height: Espaces.md),
              _Reservations(),
              SizedBox(height: Espaces.md),
              _Stocks(),
              SizedBox(height: Espaces.md),
              _Palmares(),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Revenus
// ===========================================================================

class _Revenus extends ConsumerWidget {
  const _Revenus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenus = ref.watch(revenusDetaillesProvider);

    return revenus.when(
      loading: () => const ShimmerBox(
        hauteur: 190,
        rayon: BorderRadius.all(Radius.circular(Rayons.md)),
      ),
      error: (erreur, _) => _Echec(
        titre: 'Revenus indisponibles',
        onReessayer: () => ref.invalidate(revenusDetaillesProvider),
      ),
      data: (donnees) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(Espaces.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.emeraudeSombre, AppColors.sarcelleSombre],
              ),
              borderRadius: BorderRadius.circular(Rayons.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Chiffre d'affaires",
                  style: TextStyle(color: AppColors.blanc, fontSize: 12),
                ),
                Text(
                  Formats.montant(
                    donnees.chiffreAffairesTotal,
                    devise: donnees.devise,
                  ),
                  style: const TextStyle(
                    color: AppColors.blanc,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Ventes confirmees uniquement · '
                  '${Formats.unites(donnees.quantiteVendue)} vendue(s)',
                  style: TextStyle(
                    color: AppColors.blanc.withValues(alpha: 0.82),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: Espaces.sm),
                Row(
                  children: [
                    _Periode(
                      libelle: "Aujourd'hui",
                      montant: donnees.revenusDuJour,
                      devise: donnees.devise,
                    ),
                    _Periode(
                      libelle: 'Cette semaine',
                      montant: donnees.revenusDeLaSemaine,
                      devise: donnees.devise,
                    ),
                    _Periode(
                      libelle: 'Ce mois',
                      montant: donnees.revenusDuMois,
                      devise: donnees.devise,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Volontairement SOUS le chiffre d'affaires et visuellement
          // distinct : ce n'est pas un revenu, et rien ne doit suggerer
          // qu'on puisse les additionner.
          if (donnees.valeurReservationsEnCours > 0) ...[
            const SizedBox(height: Espaces.xs),
            Container(
              padding: const EdgeInsets.all(Espaces.sm),
              decoration: BoxDecoration(
                color: AppColors.alerte.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Rayons.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded,
                      size: 18, color: AppColors.alerte),
                  const SizedBox(width: Espaces.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${Formats.montant(donnees.valeurReservationsEnCours, devise: donnees.devise)} immobilises',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          "Valeur des reservations acceptees. Ce n'est pas "
                          'un revenu : elles peuvent encore expirer ou '
                          'etre annulees.',
                          style: TextStyle(fontSize: 11, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (donnees.ventesEnAttenteDeConfirmation > 0) ...[
            const SizedBox(height: Espaces.xs),
            _Rappel(
              icone: Icons.payments_outlined,
              couleur: AppColors.info,
              texte: '${donnees.ventesEnAttenteDeConfirmation} vente(s) '
                  'declaree(s) dont vous n\'avez pas encore confirme le '
                  'paiement.',
              libelleAction: 'Voir',
              onAction: () => context.pushNamed(
                Routes.mesVentes,
                queryParameters: {'onglet': '0'},
              ),
            ),
          ],

          if (donnees.parProduit.isNotEmpty) ...[
            const SizedBox(height: Espaces.md),
            const _Titre(texte: 'Revenus par annonce', icone: Icons.sell_outlined),
            const SizedBox(height: Espaces.xs),
            _Classement(
              lignes: donnees.parProduit,
              devise: donnees.devise,
            ),
          ],

          if (donnees.parCategorie.isNotEmpty) ...[
            const SizedBox(height: Espaces.md),
            const _Titre(
              texte: 'Revenus par categorie',
              icone: Icons.category_outlined,
            ),
            const SizedBox(height: Espaces.xs),
            _Classement(
              lignes: donnees.parCategorie,
              devise: donnees.devise,
            ),
          ],
        ],
      ).animate().fadeIn(duration: Mouvements.normal),
    );
  }
}

class _Periode extends StatelessWidget {
  const _Periode({
    required this.libelle,
    required this.montant,
    required this.devise,
  });

  final String libelle;
  final double montant;
  final String devise;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle,
            style: TextStyle(
              color: AppColors.blanc.withValues(alpha: 0.78),
              fontSize: 10,
            ),
          ),
          Text(
            Formats.montantCourt(montant),
            style: const TextStyle(
              color: AppColors.blanc,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barres proportionnelles au meilleur resultat.
///
/// Les lignes arrivent deja triees par revenu decroissant : la premiere
/// sert donc d'echelle, sans chercher de maximum.
class _Classement extends StatelessWidget {
  const _Classement({required this.lignes, required this.devise});

  final List<LigneRevenu> lignes;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final maximum = lignes.first.revenu;

    return SolidCard(
      child: Column(
        children: [
          for (final ligne in lignes.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ligne.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: Espaces.xs),
                      Text(
                        Formats.montant(ligne.revenu, devise: devise),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.emeraude,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Rayons.pilule),
                    child: LinearProgressIndicator(
                      value: maximum > 0 ? ligne.revenu / maximum : 0,
                      minHeight: 4,
                      backgroundColor: Theme.of(context).dividerColor,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.emeraude,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Vue generale
// ===========================================================================

class _VueGenerale extends ConsumerWidget {
  const _VueGenerale();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vue = ref.watch(vueGeneraleProvider);

    return vue.when(
      loading: () => const ShimmerBox(
        hauteur: 130,
        rayon: BorderRadius.all(Radius.circular(Rayons.md)),
      ),
      error: (erreur, _) => _Echec(
        titre: 'Vue generale indisponible',
        onReessayer: () => ref.invalidate(vueGeneraleProvider),
      ),
      data: (donnees) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (donnees.demandesEnAttente > 0)
            _Rappel(
              icone: Icons.inbox_rounded,
              couleur: AppColors.alerte,
              texte: '${donnees.demandesEnAttente} demande(s) de '
                  'reservation attendent votre reponse.',
              libelleAction: 'Traiter',
              onAction: () => context.pushNamed(
                Routes.mesReservations,
                queryParameters: {'onglet': '1'},
              ),
            ),
          if (donnees.demandesEnAttente > 0)
            const SizedBox(height: Espaces.xs),
          const _Titre(texte: 'Mon activite', icone: Icons.insights_outlined),
          const SizedBox(height: Espaces.xs),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Espaces.xs,
            crossAxisSpacing: Espaces.xs,
            childAspectRatio: 1.05,
            children: [
              _Tuile(
                valeur: '${donnees.produitsPublies}',
                libelle: 'en ligne',
                icone: Icons.sell_outlined,
                couleur: AppColors.emeraude,
              ),
              _Tuile(
                valeur: '${donnees.produitsEnRupture}',
                libelle: 'en rupture',
                icone: Icons.inventory_2_outlined,
                couleur: donnees.produitsEnRupture > 0
                    ? AppColors.erreur
                    : AppColors.sarcelle,
              ),
              _Tuile(
                valeur: '${donnees.reservationsEnCours}',
                libelle: 'reservations',
                icone: Icons.bookmark_outline_rounded,
                couleur: AppColors.alerte,
              ),
              _Tuile(
                valeur: '${donnees.ventesConfirmees}',
                libelle: 'ventes',
                icone: Icons.receipt_long_outlined,
                couleur: AppColors.emeraude,
              ),
              _Tuile(
                valeur: '${donnees.nombreClients}',
                libelle: 'clients',
                icone: Icons.group_outlined,
                couleur: AppColors.info,
              ),
              _Tuile(
                valeur: '${donnees.nombreConversations}',
                libelle: 'discussions',
                icone: Icons.chat_bubble_outline_rounded,
                couleur: AppColors.sarcelle,
              ),
            ],
          ),
          const SizedBox(height: Espaces.xs),
          SolidCard(
            onTap: () => context.pushNamed(
              Routes.mesAvis,
              queryParameters: {'onglet': '1'},
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: AppColors.or),
                const SizedBox(width: Espaces.xs),
                Expanded(
                  child: Text(
                    donnees.nombreEvaluations == 0
                        ? 'Aucun avis pour le moment'
                        : '${donnees.nombreEvaluations} avis recu'
                            '${donnees.nombreEvaluations > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                NoteCompacte(note: donnees.noteMoyenneVendeur),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: Mouvements.normal),
    );
  }
}

// ===========================================================================
// Reservations
// ===========================================================================

class _Reservations extends ConsumerWidget {
  const _Reservations();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statistiquesReservationsProvider);

    return stats.maybeWhen(
      data: (donnees) {
        final total = donnees.enAttente +
            donnees.acceptees +
            donnees.annulees +
            donnees.expirees +
            donnees.transformeesEnVente;
        if (total == 0) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Titre(
              texte: 'Mes reservations',
              icone: Icons.bookmark_outline_rounded,
            ),
            const SizedBox(height: Espaces.xs),
            SolidCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Taux de transformation',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '${donnees.tauxDeTransformation.toStringAsFixed(0)} %',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emeraude,
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Part des demandes devenues des ventes.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 10.5),
                    ),
                  ),
                  const Divider(height: Espaces.md),
                  _Repartition(donnees: donnees),
                  if (donnees.quantiteImmobilisee > 0) ...[
                    const SizedBox(height: Espaces.xs),
                    Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            size: 14, color: AppColors.alerte),
                        const SizedBox(width: Espaces.xxs),
                        Expanded(
                          child: Text(
                            '${Formats.unites(donnees.quantiteImmobilisee)} '
                            'mise(s) de cote en ce moment',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ).animate().fadeIn(duration: Mouvements.normal);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Repartition extends StatelessWidget {
  const _Repartition({required this.donnees});

  final StatistiquesReservations donnees;

  @override
  Widget build(BuildContext context) {
    final lignes = <(String, int, Color)>[
      ('En attente', donnees.enAttente, AppColors.alerte),
      ('Acceptees', donnees.acceptees, AppColors.emeraude),
      ('Vendues', donnees.transformeesEnVente, AppColors.info),
      ('Annulees', donnees.annulees, AppColors.erreur),
      ('Expirees', donnees.expirees, AppColors.texteSombreDoux),
    ];

    return Column(
      children: [
        for (final (libelle, valeur, couleur) in lignes)
          if (valeur > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: couleur,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Espaces.xs),
                  Expanded(
                    child: Text(
                      libelle,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  Text(
                    '$valeur',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// ===========================================================================
// Stocks
// ===========================================================================

class _Stocks extends ConsumerWidget {
  const _Stocks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventaire = ref.watch(inventaireProvider);

    return inventaire.maybeWhen(
      data: (donnees) {
        if (donnees.parProduit.isEmpty) return const SizedBox.shrink();
        final enRupture = donnees.enRupture;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Titre(texte: 'Mes stocks', icone: Icons.warehouse_outlined),
            const SizedBox(height: Espaces.xs),
            SolidCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      _Quantite(
                        valeur: donnees.quantiteDisponible,
                        libelle: 'disponibles',
                        couleur: AppColors.emeraude,
                      ),
                      _Quantite(
                        valeur: donnees.quantiteReservee,
                        libelle: 'reservees',
                        couleur: AppColors.alerte,
                      ),
                      _Quantite(
                        valeur: donnees.quantiteVendue,
                        libelle: 'vendues',
                        couleur: AppColors.info,
                      ),
                      _Quantite(
                        valeur: donnees.stockTotal,
                        libelle: 'au total',
                        couleur: AppColors.sarcelle,
                      ),
                    ],
                  ),
                  const Divider(height: Espaces.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Valeur du stock disponible',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        Formats.montant(donnees.valeurStockDisponible),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (enRupture.isNotEmpty) ...[
              const SizedBox(height: Espaces.xs),
              _Rappel(
                icone: Icons.production_quantity_limits_rounded,
                couleur: AppColors.erreur,
                texte: '${enRupture.length} annonce(s) en rupture : '
                    '${enRupture.take(2).map((l) => l.titre).join(', ')}'
                    '${enRupture.length > 2 ? '...' : ''}',
                libelleAction: 'Reapprovisionner',
                onAction: () => context.goNamed(Routes.mesAnnonces),
              ),
            ],
          ],
        ).animate().fadeIn(duration: Mouvements.normal);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Quantite extends StatelessWidget {
  const _Quantite({
    required this.valeur,
    required this.libelle,
    required this.couleur,
  });

  final int valeur;
  final String libelle;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$valeur',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: couleur,
            ),
          ),
          Text(
            libelle,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Palmares
// ===========================================================================

class _Palmares extends ConsumerWidget {
  const _Palmares();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palmares = ref.watch(palmaresProvider);

    return palmares.maybeWhen(
      data: (donnees) {
        if (donnees.estVide) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (donnees.lesPlusVendus.isNotEmpty) ...[
              const _Titre(
                texte: 'Les plus vendus',
                icone: Icons.emoji_events_outlined,
              ),
              const SizedBox(height: Espaces.xs),
              SolidCard(
                child: Column(
                  children: [
                    for (final produit in donnees.lesPlusVendus)
                      _LignePalmares(
                        produit: produit,
                        detail: '${Formats.unites(produit.quantiteVendue ?? 0)}'
                            ' · ${Formats.montant(produit.revenu ?? 0)}',
                      ),
                  ],
                ),
              ),
            ],
            if (donnees.lesPlusConsultes.isNotEmpty) ...[
              const SizedBox(height: Espaces.md),
              const _Titre(
                texte: 'Les plus consultes',
                icone: Icons.visibility_outlined,
              ),
              const SizedBox(height: Espaces.xs),
              SolidCard(
                child: Column(
                  children: [
                    for (final produit in donnees.lesPlusConsultes)
                      _LignePalmares(
                        produit: produit,
                        detail: '${produit.nombreVues ?? 0} vue(s)'
                            '${produit.quantiteDisponible == 0 ? ' · en rupture' : ''}',
                        enRupture: produit.quantiteDisponible == 0,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ).animate().fadeIn(duration: Mouvements.normal);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _LignePalmares extends StatelessWidget {
  const _LignePalmares({
    required this.produit,
    required this.detail,
    this.enRupture = false,
  });

  final ProduitPalmares produit;
  final String detail;
  final bool enRupture;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.pushNamed(
        Routes.produit,
        pathParameters: {'id': '${produit.produitId}'},
        extra: {'hero': 'tableau-bord'},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produit.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: enRupture
                          ? AppColors.erreur
                          : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            if (produit.noteMoyenne != null)
              NoteCompacte(note: produit.noteMoyenne, taille: 11),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Fragments partages
// ===========================================================================

class _Titre extends StatelessWidget {
  const _Titre({required this.texte, required this.icone});

  final String texte;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 17, color: AppColors.sarcelle),
        const SizedBox(width: Espaces.xs),
        Text(
          texte,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.valeur,
    required this.libelle,
    required this.icone,
    required this.couleur,
  });

  final String valeur;
  final String libelle;
  final IconData icone;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(Espaces.xs),
      decoration: BoxDecoration(
        color: sombre
            ? AppColors.encreSurface.withValues(alpha: 0.7)
            : AppColors.blanc,
        borderRadius: BorderRadius.circular(Rayons.sm),
        border: Border.all(
          color: sombre ? AppColors.encreBordure : AppColors.bordureClaire,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 16, color: couleur),
          const SizedBox(height: 2),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: couleur,
            ),
          ),
          Text(
            libelle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _Rappel extends StatelessWidget {
  const _Rappel({
    required this.icone,
    required this.couleur,
    required this.texte,
    this.libelleAction,
    this.onAction,
  });

  final IconData icone;
  final Color couleur;
  final String texte;
  final String? libelleAction;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Espaces.sm,
        Espaces.xs,
        Espaces.xs,
        Espaces.xs,
      ),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Rayons.sm),
      ),
      child: Row(
        children: [
          Icon(icone, size: 17, color: couleur),
          const SizedBox(width: Espaces.xs),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(fontSize: 12, height: 1.25),
            ),
          ),
          if (libelleAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(libelleAction!, style: TextStyle(color: couleur)),
            ),
        ],
      ),
    );
  }
}

class _Echec extends StatelessWidget {
  const _Echec({required this.titre, required this.onReessayer});

  final String titre;
  final VoidCallback onReessayer;

  @override
  Widget build(BuildContext context) {
    // Une section en echec n'emporte pas les autres : on affiche un
    // encart local, pas une page d'erreur.
    return SolidCard(
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 18, color: AppColors.alerte),
          const SizedBox(width: Espaces.xs),
          Expanded(child: Text(titre, style: const TextStyle(fontSize: 12.5))),
          TextButton(onPressed: onReessayer, child: const Text('Reessayer')),
        ],
      ),
    );
  }
}
