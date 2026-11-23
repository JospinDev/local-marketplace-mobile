import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formats.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/reseau_image.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../auth/providers/auth_provider.dart';
import '../../catalogue/presentation/widgets/produit_carte.dart';
import '../../favoris/presentation/widgets/bouton_favori.dart';
import '../../messagerie/providers/messagerie_providers.dart';
import '../domain/vendeur_public.dart';
import '../providers/vendeurs_providers.dart';

/// Boutique d'un vendeur : sa vitrine et UNIQUEMENT ses annonces.
///
/// On y arrive depuis la liste des vendeurs suivis, depuis une fiche
/// produit, ou depuis une conversation. L'ecran est public : un visiteur
/// sans compte peut parcourir la boutique, et c'est seulement au moment
/// de suivre ou d'ecrire qu'on lui demande de se connecter.
class BoutiqueVendeurScreen extends ConsumerWidget {
  const BoutiqueVendeurScreen({super.key, required this.vendeurId});

  final int vendeurId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fiche = ref.watch(vendeurPublicProvider(vendeurId));

    return Scaffold(
      body: GradientBackground(
        anime: false,
        child: fiche.when(
          loading: () => const _Squelette(),
          error: (erreur, _) => SafeArea(
            child: EtatErreur(
              erreur: erreur,
              onReessayer: () => ref.invalidate(
                vendeurPublicProvider(vendeurId),
              ),
            ),
          ),
          data: (vendeur) => _Contenu(vendeur: vendeur),
        ),
      ),
    );
  }
}

class _Contenu extends ConsumerWidget {
  const _Contenu({required this.vendeur});

  final VendeurPublic vendeur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final produits = ref.watch(produitsVendeurProvider(vendeur.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(vendeurPublicProvider(vendeur.id));
        ref.invalidate(produitsVendeurProvider(vendeur.id));
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 212,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              // `titlePadding` laisse la place au bouton de retour : sans
              // cela le nom du vendeur passe dessous quand la barre se
              // replie.
              titlePadding: const EdgeInsets.only(
                left: 56,
                right: Espaces.md,
                bottom: Espaces.sm,
              ),
              title: Text(
                vendeur.nomAffiche,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: _Enseigne(vendeur: vendeur),
            ),
          ),
          SliverToBoxAdapter(child: _Actions(vendeur: vendeur)),
          if (vendeur.description != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espaces.ecran,
                  Espaces.xs,
                  Espaces.ecran,
                  0,
                ),
                child: Text(
                  vendeur.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaces.ecran,
                Espaces.lg,
                Espaces.ecran,
                Espaces.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Ses annonces',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  produits.maybeWhen(
                    data: (liste) => Text(
                      '${liste.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.emeraude,
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          ...produits.when(
            loading: () => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: Espaces.ecran),
                  child: ShimmerBox(
                    hauteur: 220,
                    rayon: BorderRadius.all(Radius.circular(Rayons.md)),
                  ),
                ),
              ),
            ],
            error: (erreur, _) => [
              SliverToBoxAdapter(
                child: EtatErreur(
                  erreur: erreur,
                  onReessayer: () =>
                      ref.invalidate(produitsVendeurProvider(vendeur.id)),
                ),
              ),
            ],
            data: (liste) => [
              if (liste.isEmpty)
                const SliverToBoxAdapter(
                  child: EtatVide(
                    icone: Icons.inventory_2_outlined,
                    titre: 'Aucune annonce',
                    message:
                        'Ce vendeur n\'a pas d\'annonce visible en ce '
                        'moment. Suivez-le pour etre prevenu.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaces.ecran,
                    0,
                    Espaces.ecran,
                    Espaces.xxxl,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: Espaces.sm,
                      crossAxisSpacing: Espaces.sm,
                      // Meme proportion que la recherche : les cartes ont
                      // ete reglees la-bas pour ne pas deborder.
                      childAspectRatio: 0.60,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      childCount: liste.length,
                      (context, index) {
                        final produit = liste[index];
                        return ProduitCarte(
                          produit: produit,
                          etiquetteHero: 'boutique',
                          onTap: () => context.pushNamed(
                            Routes.produit,
                            pathParameters: {'id': '${produit.id}'},
                            extra: {'hero': 'boutique'},
                          ),
                        )
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: 24 * index),
                              duration: Mouvements.normal,
                            )
                            .slideY(begin: 0.06, curve: Mouvements.sortie);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// En-tete : photo, nom, note, localisation.
class _Enseigne extends StatelessWidget {
  const _Enseigne({required this.vendeur});

  final VendeurPublic vendeur;

  @override
  Widget build(BuildContext context) {
    final note = Formats.note(vendeur.noteMoyenne);

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.emeraudeSombre, AppColors.sarcelleSombre],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Espaces.ecran,
              Espaces.xxl,
              Espaces.ecran,
              Espaces.xxl,
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.blanc.withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: vendeur.photo != null
                        ? ReseauImage(url: vendeur.photo, largeur: 68, hauteur: 68)
                        : Container(
                            color: AppColors.blanc.withValues(alpha: 0.18),
                            alignment: Alignment.center,
                            child: Text(
                              vendeur.initiales,
                              style: const TextStyle(
                                color: AppColors.blanc,
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: Espaces.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendeur.nomAffiche,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.blanc,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${vendeur.username}',
                        style: TextStyle(
                          color: AppColors.blanc.withValues(alpha: 0.78),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: Espaces.xs),
                      Wrap(
                        spacing: Espaces.xs,
                        runSpacing: Espaces.xxs,
                        children: [
                          if (note != null)
                            _Jeton(
                              icone: Icons.star_rounded,
                              texte: '$note'
                                  '${vendeur.nombreEvaluations > 0 ? ' (${vendeur.nombreEvaluations})' : ''}',
                            ),
                          if (vendeur.localisation != null)
                            _Jeton(
                              icone: Icons.place_outlined,
                              texte: vendeur.localisation!,
                            ),
                          _Jeton(
                            icone: Icons.group_outlined,
                            texte: '${vendeur.nombreAbonnes} abonne'
                                '${vendeur.nombreAbonnes > 1 ? 's' : ''}',
                          ),
                        ],
                      ),
                    ],
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

class _Jeton extends StatelessWidget {
  const _Jeton({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.blanc.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(Rayons.pilule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: AppColors.blanc),
          const SizedBox(width: 3),
          Text(
            texte,
            style: const TextStyle(
              color: AppColors.blanc,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Suivre, contacter, et le compteur d'annonces.
class _Actions extends ConsumerStatefulWidget {
  const _Actions({required this.vendeur});

  final VendeurPublic vendeur;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _ouvertureEnCours = false;

  Future<void> _contacter() async {
    if (_ouvertureEnCours) return;

    if (!ref.read(authProvider).estConnecte) {
      AppFeedback.info(context, 'Connectez-vous pour ecrire au vendeur.');
      context.pushNamed(Routes.connexion);
      return;
    }

    setState(() => _ouvertureEnCours = true);
    try {
      // Sans produit : le serveur ouvre une conversation generale avec ce
      // vendeur, ou retrouve celle qui existe deja.
      final conversation = await ref
          .read(messagerieRepositoryProvider)
          .ouvrir(interlocuteurId: widget.vendeur.id);

      if (!mounted) return;
      ref.read(conversationsProvider.notifier).charger();
      context.pushNamed(
        Routes.conversation,
        pathParameters: {'id': '${conversation.id}'},
      );
    } catch (erreur) {
      if (mounted) AppFeedback.erreur(context, '$erreur');
    } finally {
      if (mounted) setState(() => _ouvertureEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendeur = widget.vendeur;
    final moi = ref.watch(utilisateurProvider);
    final cestMoi = moi != null && moi.id == vendeur.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espaces.ecran,
        Espaces.md,
        Espaces.ecran,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Compteur(
                valeur: '${vendeur.nombreProduitsActifs}',
                libelle: 'en vente',
              ),
              _Compteur(
                valeur: '${vendeur.nombreProduitsPublies}',
                libelle: 'publiees',
              ),
              _Compteur(
                valeur: '${vendeur.nombreProduitsEnRupture}',
                libelle: 'en rupture',
              ),
            ],
          ),
          if (!cestMoi) ...[
            const SizedBox(height: Espaces.md),
            Row(
              children: [
                Expanded(child: BoutonSuivre(vendeurId: vendeur.id)),
                const SizedBox(width: Espaces.xs),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _ouvertureEnCours ? null : _contacter,
                    icon: _ouvertureEnCours
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chat_bubble_outline_rounded,
                            size: 17),
                    label: const Text('Contacter'),
                  ),
                ),
              ],
            ),
            if (vendeur.afficheSonNumero) ...[
              const SizedBox(height: Espaces.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 14, color: AppColors.emeraude),
                    const SizedBox(width: Espaces.xxs),
                    Text(
                      vendeur.telephone!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emeraude,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({required this.valeur, required this.libelle});

  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        children: [
          Text(
            valeur,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.emeraude,
            ),
          ),
          Text(
            libelle,
            style: TextStyle(
              fontSize: 11,
              color: sombre
                  ? AppColors.texteClairDoux
                  : AppColors.texteSombreDoux,
            ),
          ),
        ],
      ),
    );
  }
}

class _Squelette extends StatelessWidget {
  const _Squelette();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(Espaces.ecran),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShimmerBox(
              hauteur: 96,
              rayon: BorderRadius.all(Radius.circular(Rayons.md)),
            ),
            SizedBox(height: Espaces.md),
            ShimmerBox(hauteur: 56),
            SizedBox(height: Espaces.md),
            Expanded(
              child: ShimmerBox(
                rayon: BorderRadius.all(Radius.circular(Rayons.md)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
