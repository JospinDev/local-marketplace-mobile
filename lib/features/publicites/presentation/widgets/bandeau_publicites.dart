import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/reseau_image.dart';
import '../../domain/publicite.dart';
import '../../providers/publicites_providers.dart';

/// Bandeau publicitaire en haut de l'accueil.
///
/// Trois regles tenues ici :
///
/// - **l'emplacement disparait completement** quand il n'y a rien a
///   montrer : pas de cadre vide, pas de hauteur reservee, pas de message
///   d'erreur. Une publicite est un supplement ;
/// - **le defilement est automatique** vers la gauche, et s'interrompt des
///   que la personne touche le bandeau — reprendre a defiler sous le doigt
///   serait desagreable ;
/// - **une seule publicite ne defile pas** : animer un element unique
///   n'apporte rien et attire l'oeil pour rien.
class BandeauPublicites extends ConsumerWidget {
  const BandeauPublicites({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bandeau = ref.watch(bandeauProvider);

    return bandeau.maybeWhen(
      data: (publicites) => publicites.isEmpty
          ? const SizedBox.shrink()
          : _Carrousel(publicites: publicites),
      // Chargement ET erreur : rien du tout. L'accueil ne doit pas sauter
      // quand le bandeau arrive, ni afficher un encart d'echec.
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _Carrousel extends ConsumerStatefulWidget {
  const _Carrousel({required this.publicites});

  final List<Publicite> publicites;

  @override
  ConsumerState<_Carrousel> createState() => _CarrouselState();
}

class _CarrouselState extends ConsumerState<_Carrousel> {
  static const _hauteur = 148.0;
  static const _intervalle = Duration(seconds: 4);

  final _defilement = PageController();
  Timer? _minuterie;
  int _page = 0;
  bool _toucheParLUtilisateur = false;

  bool get _defileAutomatiquement => widget.publicites.length > 1;

  @override
  void initState() {
    super.initState();
    if (_defileAutomatiquement) _demarrer();
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    _defillementDispose();
    super.dispose();
  }

  void _defillementDispose() => _defilement.dispose();

  void _demarrer() {
    _minuterie?.cancel();
    _minuterie = Timer.periodic(_intervalle, (_) {
      if (!mounted || _toucheParLUtilisateur) return;
      if (!_defilement.hasClients) return;

      final suivante = (_page + 1) % widget.publicites.length;

      // Retour a la premiere : un saut sans animation evite un long
      // defilement arriere disgracieux.
      if (suivante == 0) {
        _defilement.jumpToPage(0);
      } else {
        _defilement.animateToPage(
          suivante,
          duration: Mouvements.page,
          curve: Mouvements.entree,
        );
      }
    });
  }

  Future<void> _ouvrir(Publicite publicite) async {
    ref.read(publicitesRepositoryProvider).signalerClic(publicite.id);
    if (!publicite.estCliquable) return;

    switch (publicite.cible) {
      case CiblePublicite.produit:
        context.pushNamed(
          Routes.produit,
          pathParameters: {'id': '${publicite.cibleId}'},
          extra: {'hero': 'publicite'},
        );
      case CiblePublicite.vendeur:
        context.pushNamed(
          Routes.boutique,
          pathParameters: {'id': '${publicite.cibleId}'},
        );
      case CiblePublicite.categorie:
        context.goNamed(
          Routes.recherche,
          queryParameters: {'categorie': '${publicite.cibleId}'},
        );
      case CiblePublicite.url:
        // Une adresse externe part dans le navigateur : on n'ouvre jamais
        // un site tiers dans une vue interne, la personne doit voir ou
        // elle va.
        final adresse = Uri.tryParse(publicite.cibleUrl);
        if (adresse == null) return;
        final ouvert = await launchUrl(
          adresse,
          mode: LaunchMode.externalApplication,
        );
        if (!ouvert && mounted) {
          AppFeedback.erreur(context, 'Impossible d\'ouvrir ce lien.');
        }
      case CiblePublicite.aucune:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Espaces.sm),
      child: Column(
        children: [
          SizedBox(
            height: _hauteur,
            child: Listener(
              // Le doigt sur le bandeau suspend le defilement automatique.
              onPointerDown: (_) => _toucheParLUtilisateur = true,
              onPointerUp: (_) => _toucheParLUtilisateur = false,
              onPointerCancel: (_) => _toucheParLUtilisateur = false,
              child: PageView.builder(
                controller: _defilement,
                onPageChanged: (page) => setState(() => _page = page),
                itemCount: widget.publicites.length,
                padEnds: false,
                itemBuilder: (context, index) {
                  final publicite = widget.publicites[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      left: index == 0 ? Espaces.ecran : Espaces.xs,
                      right: index == widget.publicites.length - 1
                          ? Espaces.ecran
                          : 0,
                    ),
                    child: _Carte(
                      publicite: publicite,
                      onTap: () => _ouvrir(publicite),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_defileAutomatiquement) ...[
            const SizedBox(height: Espaces.xs),
            _Points(total: widget.publicites.length, actif: _page),
          ],
        ],
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({required this.publicite, required this.onTap});

  final Publicite publicite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final aUnTexte =
        publicite.titre.isNotEmpty || publicite.sousTitre.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(Rayons.md),
      child: Material(
        color: AppColors.encreSurface,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ReseauImage(url: publicite.image, ajustement: BoxFit.cover),

              // Voile sombre seulement s'il y a du texte a lire : une
              // publicite purement graphique doit rester nette.
              if (aUnTexte)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xCC070B14), Color(0x11070B14)],
                    ),
                  ),
                ),

              if (aUnTexte)
                Padding(
                  padding: const EdgeInsets.all(Espaces.md),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (publicite.titre.isNotEmpty)
                        Flexible(
                          child: Text(
                            publicite.titre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.blanc,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                      if (publicite.sousTitre.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Flexible(
                          child: Text(
                            publicite.sousTitre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.blanc.withValues(alpha: 0.9),
                              fontSize: 12.5,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                      if (publicite.libelleAction.isNotEmpty) ...[
                        const SizedBox(height: Espaces.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Espaces.sm,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.emeraude,
                            borderRadius:
                                BorderRadius.circular(Rayons.pilule),
                          ),
                          child: Text(
                            publicite.libelleAction,
                            style: const TextStyle(
                              color: AppColors.blanc,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Points extends StatelessWidget {
  const _Points({required this.total, required this.actif});

  final int total;
  final int actif;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < total; index++)
          AnimatedContainer(
            duration: Mouvements.rapide,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: index == actif ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: index == actif
                  ? AppColors.emeraude
                  : Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(Rayons.pilule),
            ),
          ),
      ],
    );
  }
}
