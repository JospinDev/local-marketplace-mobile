import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formats.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/reseau_image.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../domain/produit.dart';
import '../providers/catalogue_providers.dart';

/// Fiche produit.
///
/// La galerie occupe le haut de l'ecran et se replie au defilement : sur
/// un telephone, l'image doit convaincre d'abord, puis laisser la place
/// aux informations. La barre d'action reste collee en bas, parce que
/// c'est l'endroit ou le pouce se trouve naturellement.
class ProduitDetailScreen extends ConsumerStatefulWidget {
  const ProduitDetailScreen({
    super.key,
    required this.produitId,
    this.etiquetteHero = 'recherche',
  });

  final int produitId;
  final String etiquetteHero;

  @override
  ConsumerState<ProduitDetailScreen> createState() =>
      _ProduitDetailScreenState();
}

class _ProduitDetailScreenState extends ConsumerState<ProduitDetailScreen> {
  final _pages = PageController();
  int _imageCourante = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fiche = ref.watch(ficheProduitProvider(widget.produitId));

    return Scaffold(
      body: fiche.when(
        loading: () => const _SqueletteFiche(),
        error: (erreur, _) => SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              Expanded(
                child: EtatErreur(
                  erreur: erreur,
                  onReessayer: () => ref.invalidate(
                    ficheProduitProvider(widget.produitId),
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (produit) => _Contenu(
          produit: produit,
          etiquetteHero: widget.etiquetteHero,
          pages: _pages,
          imageCourante: _imageCourante,
          onImageChange: (i) => setState(() => _imageCourante = i),
        ),
      ),
      bottomNavigationBar: fiche.maybeWhen(
        data: (produit) => _BarreAction(produit: produit),
        orElse: () => null,
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({
    required this.produit,
    required this.etiquetteHero,
    required this.pages,
    required this.imageCourante,
    required this.onImageChange,
  });

  final Produit produit;
  final String etiquetteHero;
  final PageController pages;
  final int imageCourante;
  final ValueChanged<int> onImageChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final images = produit.images.isNotEmpty
        ? produit.images
        : (produit.imagePrincipale != null
            ? [produit.imagePrincipale!]
            : const <ImageProduit>[]);

    return CustomScrollView(
      slivers: [
        // --------------------------------------------------- galerie
        SliverAppBar(
          expandedHeight: 380,
          pinned: true,
          stretch: true,
          backgroundColor:
              theme.brightness == Brightness.dark
                  ? AppColors.encre
                  : AppColors.blanc,
          leading: const _BoutonFlottant(icone: Icons.arrow_back_rounded),
          actions: const [
            _BoutonFlottant(icone: Icons.share_outlined, action: true),
            SizedBox(width: Espaces.xs),
            _BoutonFlottant(icone: Icons.favorite_border_rounded, action: true),
            SizedBox(width: Espaces.sm),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (images.isEmpty)
                  const ReseauImage(url: null)
                else
                  Hero(
                    tag: '$etiquetteHero-produit-${produit.id}',
                    child: PageView.builder(
                      controller: pages,
                      onPageChanged: onImageChange,
                      itemCount: images.length,
                      itemBuilder: (context, index) => ReseauImage(
                        url: images[index].url,
                      ),
                    ),
                  ),

                // Voile du bas : garantit que les pastilles restent
                // lisibles sur une photo claire.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.voileImage,
                    ),
                  ),
                ),

                if (images.length > 1)
                  Positioned(
                    bottom: Espaces.md,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (index) => AnimatedContainer(
                          duration: Mouvements.rapide,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: index == imageCourante ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: index == imageCourante
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.45),
                            borderRadius:
                                BorderRadius.circular(Rayons.pilule),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (produit.estEnRupture)
                  const Positioned(
                    top: 90,
                    left: Espaces.ecran,
                    child: Etiquette(
                      texte: 'Rupture de stock',
                      couleur: AppColors.erreur,
                      icone: Icons.remove_shopping_cart_outlined,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // --------------------------------------------------- contenu
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Espaces.ecran,
              Espaces.lg,
              Espaces.ecran,
              Espaces.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (produit.categorieChemin != null ||
                    produit.categorieNom != null)
                  Text(
                    (produit.categorieChemin ?? produit.categorieNom!)
                        .toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emeraude,
                    ),
                  ).animate().fadeIn(),

                const SizedBox(height: Espaces.xs),
                Text(produit.titre, style: theme.textTheme.headlineSmall)
                    .animate(delay: 60.ms)
                    .fadeIn()
                    .slideY(begin: 0.15),

                const SizedBox(height: Espaces.sm),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formats.montant(produit.prix, devise: produit.devise),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.emeraude,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Etiquette(
                      texte: produit.etat.libelle,
                      couleur: produit.etat == EtatProduit.neuf
                          ? AppColors.emeraude
                          : AppColors.sarcelle,
                    ),
                  ],
                ).animate(delay: 110.ms).fadeIn().slideY(begin: 0.15),

                const SizedBox(height: Espaces.md),

                Wrap(
                  spacing: Espaces.xs,
                  runSpacing: Espaces.xs,
                  children: [
                    if (produit.localisation != null)
                      Etiquette(
                        texte: produit.localisation!,
                        couleur: AppColors.sarcelle,
                        icone: Icons.place_outlined,
                      ),
                    if (produit.distanceKm != null)
                      Etiquette(
                        texte: 'a ${Formats.distance(produit.distanceKm)}',
                        couleur: AppColors.info,
                        icone: Icons.near_me_rounded,
                      ),
                    Etiquette(
                      texte: produit.estEnRupture
                          ? 'Indisponible'
                          : '${Formats.unites(produit.quantiteDisponible)} '
                              'disponible${produit.quantiteDisponible > 1 ? 's' : ''}',
                      couleur: produit.estEnRupture
                          ? AppColors.erreur
                          : AppColors.succes,
                      icone: Icons.inventory_2_outlined,
                    ),
                    Etiquette(
                      texte: '${produit.nombreVues} vues',
                      couleur: AppColors.texteSombreDoux,
                      icone: Icons.visibility_outlined,
                    ),
                  ],
                ).animate(delay: 160.ms).fadeIn(),

                if (produit.reputation.aDesAvis) ...[
                  const SizedBox(height: Espaces.md),
                  _BlocNotes(reputation: produit.reputation)
                      .animate(delay: 200.ms)
                      .fadeIn()
                      .slideY(begin: 0.15),
                ],

                if (produit.description != null) ...[
                  const SizedBox(height: Espaces.xl),
                  Text('Description', style: theme.textTheme.titleMedium),
                  const SizedBox(height: Espaces.xs),
                  Text(
                    produit.description!,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ],

                if (produit.vendeur != null) ...[
                  const SizedBox(height: Espaces.xl),
                  Text('Vendeur', style: theme.textTheme.titleMedium),
                  const SizedBox(height: Espaces.sm),
                  _CarteVendeur(vendeur: produit.vendeur!),
                ],

                const SizedBox(height: Espaces.xl),
                Text(
                  'Publiee ${Formats.depuis(produit.publieLe ?? produit.creeLe)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BlocNotes extends StatelessWidget {
  const _BlocNotes({required this.reputation});

  final Reputation reputation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = reputation.noteProduit ?? reputation.noteVendeur;

    return SolidCard(
      child: Row(
        children: [
          const IconPastille(
            icone: Icons.star_rounded,
            couleur: AppColors.or,
            taille: 42,
          ),
          const SizedBox(width: Espaces.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      Formats.note(note) ?? '—',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(' / 5', style: theme.textTheme.bodySmall),
                  ],
                ),
                Text(
                  '${reputation.nombreEvaluations} avis '
                  '${reputation.nombreEvaluations > 1 ? 'verifies' : 'verifie'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (reputation.noteVendeur != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Vendeur', style: theme.textTheme.bodySmall),
                Text(
                  '${Formats.note(reputation.noteVendeur)} / 5',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CarteVendeur extends StatelessWidget {
  const _CarteVendeur({required this.vendeur});

  final VendeurResume vendeur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SolidCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Rayons.sm),
            child: vendeur.photo != null
                ? ReseauImage(
                    url: vendeur.photo,
                    largeur: 48,
                    hauteur: 48,
                  )
                : Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      gradient: AppColors.degradeMarque,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      vendeur.nomAffiche.isNotEmpty
                          ? vendeur.nomAffiche[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: Espaces.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendeur.nomAffiche,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (vendeur.localisation != null)
                  Text(
                    vendeur.localisation!,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (vendeur.membreDepuis != null)
                  Text(
                    'Membre ${Formats.depuis(vendeur.membreDepuis)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          // Le numero n'apparait que si le vendeur l'a autorise : c'est
          // son seul reglage de confidentialite.
          if (vendeur.telephone != null)
            IconButton(
              onPressed: () => AppFeedback.info(
                context,
                'Telephone : ${vendeur.telephone}',
              ),
              icon: const Icon(Icons.phone_outlined),
              tooltip: 'Telephone du vendeur',
            ),
        ],
      ),
    );
  }
}

/// Barre d'action collee en bas.
class _BarreAction extends StatelessWidget {
  const _BarreAction({required this.produit});

  final Produit produit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        Espaces.ecran,
        Espaces.sm,
        Espaces.ecran,
        Espaces.sm + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: sombre ? AppColors.encreSurface : AppColors.blanc,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppButton(
              libelle: 'Contacter',
              style: StyleBouton.secondaire,
              icone: Icons.chat_bubble_outline_rounded,
              compact: true,
              onPressed: () => AppFeedback.info(
                context,
                'La messagerie arrive a l\'etape 6.',
              ),
            ),
          ),
          const SizedBox(width: Espaces.xs),
          Expanded(
            flex: 2,
            child: AppButton(
              libelle: produit.estEnRupture
                  ? 'Indisponible'
                  : 'Reserver',
              icone: Icons.bookmark_add_outlined,
              compact: true,
              onPressed: produit.estEnRupture
                  ? null
                  : () => AppFeedback.info(
                        context,
                        'Les reservations arrivent a l\'etape 7.',
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton rond pose sur la galerie, lisible sur toute photo.
class _BoutonFlottant extends StatelessWidget {
  const _BoutonFlottant({required this.icone, this.action = false});

  final IconData icone;
  final bool action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: AppColors.encre.withValues(alpha: 0.42),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            if (action) {
              AppFeedback.info(context, 'Bientot disponible.');
            } else {
              context.pop();
            }
          },
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icone, size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _SqueletteFiche extends StatelessWidget {
  const _SqueletteFiche();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const [
        ShimmerBox(hauteur: 380, rayon: BorderRadius.zero),
        Padding(
          padding: EdgeInsets.all(Espaces.ecran),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(hauteur: 12, largeur: 120),
              SizedBox(height: Espaces.sm),
              ShimmerBox(hauteur: 26),
              SizedBox(height: Espaces.xs),
              ShimmerBox(hauteur: 26, largeur: 200),
              SizedBox(height: Espaces.lg),
              ShimmerBox(hauteur: 32, largeur: 160),
              SizedBox(height: Espaces.lg),
              ShimmerBox(hauteur: 14),
              SizedBox(height: Espaces.xs),
              ShimmerBox(hauteur: 14),
              SizedBox(height: Espaces.xs),
              ShimmerBox(hauteur: 14, largeur: 220),
            ],
          ),
        ),
      ],
    );
  }
}
