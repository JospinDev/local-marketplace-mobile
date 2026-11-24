import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validateurs.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../auth/domain/utilisateur.dart';
import '../../auth/providers/auth_provider.dart';

/// Ecran « Mon compte » (etape 2 du guide).
///
/// Il montre les deux visages d'un compte : le profil prive et la vitrine
/// commerciale. La separation est visible a l'ecran parce qu'elle est
/// reelle cote serveur — `nom_commercial` et `description` sont publics,
/// `email` et `telephone` ne le sont pas.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final utilisateur = ref.watch(utilisateurProvider);

    if (utilisateur == null) return const _InvitationConnexion();

    return GradientBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(authProvider.notifier).rafraichirProfil(),
          color: AppColors.emeraude,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Espaces.ecran,
              Espaces.sm,
              Espaces.ecran,
              Espaces.xxl,
            ),
            children: [
              Row(
                children: [
                  Text('Mon compte', style: theme.textTheme.headlineMedium),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _ouvrirEdition(context, ref, utilisateur),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Modifier mon profil',
                  ),
                ],
              ).animate().fadeIn(),

              const SizedBox(height: Espaces.md),
              _CarteIdentite(utilisateur: utilisateur)
                  .animate(delay: 80.ms)
                  .fadeIn()
                  .slideY(begin: 0.2),

              if (utilisateur.estSuspendu) ...[
                const SizedBox(height: Espaces.md),
                _Alerte(
                  icone: Icons.block_rounded,
                  couleur: AppColors.erreur,
                  titre: 'Compte suspendu',
                  texte: utilisateur.motifSuspension ??
                      'Contactez l\'administration pour en savoir plus.',
                ).animate(delay: 120.ms).fadeIn(),
              ],

              if (utilisateur.email != null && !utilisateur.emailVerifie) ...[
                const SizedBox(height: Espaces.md),
                const _Alerte(
                  icone: Icons.mark_email_unread_outlined,
                  couleur: AppColors.alerte,
                  titre: 'Email non verifie',
                  texte: 'Sans verification, la reinitialisation du mot de '
                      'passe est impossible.',
                ).animate(delay: 120.ms).fadeIn(),
              ],

              const SizedBox(height: Espaces.xl),
              const _Section(titre: 'Informations privees')
                  .animate(delay: 160.ms)
                  .fadeIn(),
              const SizedBox(height: Espaces.sm),
              SolidCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Ligne(
                      icone: Icons.alternate_email_rounded,
                      libelle: "Nom d'utilisateur",
                      valeur: utilisateur.username,
                      fige: true,
                    ),
                    const Divider(height: 1),
                    _Ligne(
                      icone: Icons.mail_outline_rounded,
                      libelle: 'Email',
                      valeur: utilisateur.email ?? 'Non renseigne',
                      badge: utilisateur.email == null
                          ? null
                          : (utilisateur.emailVerifie
                              ? const Etiquette(
                                  texte: 'Verifie',
                                  couleur: AppColors.succes,
                                  compacte: true,
                                )
                              : const Etiquette(
                                  texte: 'A verifier',
                                  couleur: AppColors.alerte,
                                  compacte: true,
                                )),
                      fige: true,
                    ),
                    const Divider(height: 1),
                    _Ligne(
                      icone: Icons.phone_outlined,
                      libelle: 'Telephone',
                      valeur: utilisateur.telephone ?? 'Non renseigne',
                    ),
                    const Divider(height: 1),
                    _Ligne(
                      icone: Icons.place_outlined,
                      libelle: 'Localisation',
                      valeur: utilisateur.localisation ?? 'Non renseignee',
                    ),
                  ],
                ),
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.15),

              const SizedBox(height: Espaces.xl),
              const _Section(
                titre: 'Vitrine publique',
                sousTitre: 'Visible par tous les acheteurs',
              ).animate(delay: 240.ms).fadeIn(),
              const SizedBox(height: Espaces.sm),
              SolidCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Ligne(
                      icone: Icons.storefront_outlined,
                      libelle: 'Nom commercial',
                      valeur: utilisateur.nomCommercial ?? 'Non renseigne',
                    ),
                    const Divider(height: 1),
                    _Ligne(
                      icone: Icons.notes_rounded,
                      libelle: 'Description',
                      valeur: utilisateur.description ?? 'Non renseignee',
                    ),
                    const Divider(height: 1),
                    _Ligne(
                      icone: utilisateur.telephonePublic
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      libelle: 'Telephone affiche',
                      valeur: utilisateur.telephonePublic
                          ? 'Oui, visible sur ma vitrine'
                          : 'Non, garde prive',
                    ),
                  ],
                ),
              ).animate(delay: 280.ms).fadeIn().slideY(begin: 0.15),

              const SizedBox(height: Espaces.xl),
              AppButton(
                libelle: 'Mes reservations',
                style: StyleBouton.secondaire,
                icone: Icons.bookmark_border_rounded,
                onPressed: () => context.pushNamed(Routes.mesReservations),
              ).animate(delay: 290.ms).fadeIn(),

              const SizedBox(height: Espaces.md),
              AppButton(
                libelle: 'Mes ventes et mes achats',
                style: StyleBouton.secondaire,
                icone: Icons.receipt_long_outlined,
                onPressed: () => context.pushNamed(Routes.mesVentes),
              ).animate(delay: 295.ms).fadeIn(),

              const SizedBox(height: Espaces.md),
              AppButton(
                libelle: 'Mes favoris et vendeurs suivis',
                style: StyleBouton.secondaire,
                icone: Icons.favorite_border_rounded,
                onPressed: () => context.pushNamed(Routes.mesListes),
              ).animate(delay: 300.ms).fadeIn(),

              const SizedBox(height: Espaces.md),

              AppButton(
                libelle: 'Se deconnecter',
                style: StyleBouton.secondaire,
                icone: Icons.logout_rounded,
                onPressed: () => _confirmerDeconnexion(context, ref),
              ).animate(delay: 320.ms).fadeIn(),

              const SizedBox(height: Espaces.md),
              Center(
                child: Text(
                  'Marketplace Burundi · v1.0.0',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmerDeconnexion(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirme = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Espaces.ecran,
          0,
          Espaces.ecran,
          Espaces.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Se deconnecter ?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Espaces.xs),
            Text(
              'Votre session sera fermee sur cet appareil.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Espaces.xl),
            AppButton(
              libelle: 'Oui, me deconnecter',
              style: StyleBouton.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: Espaces.xs),
            AppButton(
              libelle: 'Annuler',
              style: StyleBouton.fantome,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );

    if (confirme == true) {
      await ref.read(authProvider.notifier).deconnecter();
    }
  }

  Future<void> _ouvrirEdition(
    BuildContext context,
    WidgetRef ref,
    Utilisateur utilisateur,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FeuilleEdition(utilisateur: utilisateur),
    );
  }
}

/// Formulaire de modification du profil.
class _FeuilleEdition extends ConsumerStatefulWidget {
  const _FeuilleEdition({required this.utilisateur});

  final Utilisateur utilisateur;

  @override
  ConsumerState<_FeuilleEdition> createState() => _FeuilleEditionState();
}

class _FeuilleEditionState extends ConsumerState<_FeuilleEdition> {
  final _formulaire = GlobalKey<FormState>();
  late final _nomComplet =
      TextEditingController(text: widget.utilisateur.nomComplet);
  late final _telephone =
      TextEditingController(text: widget.utilisateur.telephone);
  late final _localisation =
      TextEditingController(text: widget.utilisateur.localisation);
  late final _nomCommercial =
      TextEditingController(text: widget.utilisateur.nomCommercial);
  late final _description =
      TextEditingController(text: widget.utilisateur.description);

  late bool _telephonePublic = widget.utilisateur.telephonePublic;
  bool _enCours = false;
  Map<String, String> _erreurs = {};

  @override
  void dispose() {
    for (final c in [
      _nomComplet,
      _telephone,
      _localisation,
      _nomCommercial,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    setState(() => _erreurs = {});
    if (!_formulaire.currentState!.validate()) return;

    setState(() => _enCours = true);
    try {
      final maj = await ref.read(authRepositoryProvider).majProfil({
        'nom_complet': _nomComplet.text.trim(),
        'telephone': _telephone.text.trim(),
        'localisation': _localisation.text.trim(),
        'nom_commercial': _nomCommercial.text.trim(),
        'description': _description.text.trim(),
        'telephone_public': _telephonePublic,
      });
      if (!mounted) return;
      ref.read(authProvider.notifier).appliquerProfil(maj);
      Navigator.of(context).pop();
      AppFeedback.succes(context, 'Profil mis a jour.');
    } on ApiException catch (erreur) {
      if (!mounted) return;
      setState(() => _erreurs = erreur.erreursChamps);
      AppFeedback.erreur(context, erreur.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clavier = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: clavier),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, defilement) => Form(
          key: _formulaire,
          child: ListView(
            controller: defilement,
            padding: const EdgeInsets.fromLTRB(
              Espaces.ecran,
              0,
              Espaces.ecran,
              Espaces.xl,
            ),
            children: [
              Text('Modifier mon profil', style: theme.textTheme.titleLarge),
              const SizedBox(height: Espaces.xl),

              AppTextField(
                controleur: _nomComplet,
                libelle: 'Nom complet',
                icone: Icons.badge_outlined,
                erreurServeur: _erreurs['nom_complet'],
                actif: !_enCours,
              ),
              const SizedBox(height: Espaces.md),
              AppTextField(
                controleur: _telephone,
                libelle: 'Telephone',
                icone: Icons.phone_outlined,
                typeClavier: TextInputType.phone,
                validateur: Validateurs.telephoneFacultatif,
                erreurServeur: _erreurs['telephone'],
                actif: !_enCours,
              ),
              const SizedBox(height: Espaces.md),
              AppTextField(
                controleur: _localisation,
                libelle: 'Localisation',
                indice: 'Kinindo, Bujumbura',
                icone: Icons.place_outlined,
                erreurServeur: _erreurs['localisation'],
                actif: !_enCours,
              ),

              const SizedBox(height: Espaces.xl),
              Text('Vitrine publique', style: theme.textTheme.titleMedium),
              const SizedBox(height: Espaces.sm),

              AppTextField(
                controleur: _nomCommercial,
                libelle: 'Nom commercial',
                indice: 'Chris Electronics',
                icone: Icons.storefront_outlined,
                erreurServeur: _erreurs['nom_commercial'],
                actif: !_enCours,
              ),
              const SizedBox(height: Espaces.md),
              AppTextField(
                controleur: _description,
                libelle: 'Description',
                indice: 'Ce que vous vendez, vos horaires...',
                icone: Icons.notes_rounded,
                lignes: 4,
                maxCaracteres: 500,
                erreurServeur: _erreurs['description'],
                actif: !_enCours,
              ),
              const SizedBox(height: Espaces.md),

              SolidCard(
                child: Row(
                  children: [
                    const IconPastille(
                      icone: Icons.visibility_outlined,
                      taille: 38,
                    ),
                    const SizedBox(width: Espaces.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Afficher mon telephone',
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            'Les acheteurs pourront vous appeler '
                            'directement depuis votre vitrine.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _telephonePublic,
                      onChanged: _enCours
                          ? null
                          : (v) => setState(() => _telephonePublic = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Espaces.xl),
              AppButton(
                libelle: 'Enregistrer',
                icone: Icons.check_rounded,
                enChargement: _enCours,
                onPressed: _enregistrer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- fragments
class _CarteIdentite extends StatelessWidget {
  const _CarteIdentite({required this.utilisateur});

  final Utilisateur utilisateur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.degradeMarque,
              borderRadius: BorderRadius.circular(Rayons.md),
              boxShadow: AppColors.halo(AppColors.emeraude),
            ),
            alignment: Alignment.center,
            child: Text(
              utilisateur.initiales,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: Espaces.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  utilisateur.nomAffiche,
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${utilisateur.username}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: Espaces.xs),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (utilisateur.peutAgir)
                      const Etiquette(
                        texte: 'Compte actif',
                        couleur: AppColors.succes,
                        icone: Icons.check_circle_outline,
                        compacte: true,
                      ),
                    if (utilisateur.localisation != null)
                      Etiquette(
                        texte: utilisateur.localisation!,
                        couleur: AppColors.sarcelle,
                        icone: Icons.place_outlined,
                        compacte: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.titre, this.sousTitre});

  final String titre;
  final String? sousTitre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre, style: theme.textTheme.titleMedium),
        if (sousTitre != null)
          Text(sousTitre!, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icone,
    required this.libelle,
    required this.valeur,
    this.badge,
    this.fige = false,
  });

  final IconData icone;
  final String libelle;
  final String valeur;
  final Widget? badge;

  /// Champ que le serveur refuse de modifier (username, email).
  final bool fige;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.md,
        vertical: Espaces.sm + 2,
      ),
      child: Row(
        children: [
          Icon(icone, size: 19, color: AppColors.texteSombreDoux),
          const SizedBox(width: Espaces.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(libelle, style: theme.textTheme.bodySmall),
                    if (fige) ...[
                      const SizedBox(width: 5),
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 11,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ],
                  ],
                ),
                Text(
                  valeur,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ?badge,
        ],
      ),
    );
  }
}

class _Alerte extends StatelessWidget {
  const _Alerte({
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.texte,
  });

  final IconData icone;
  final Color couleur;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Espaces.sm + 2),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.10),
        borderRadius: Rayons.carte,
        border: Border.all(color: couleur.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 19, color: couleur),
          const SizedBox(width: Espaces.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: theme.textTheme.titleSmall?.copyWith(color: couleur),
                ),
                Text(texte, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Affiche quand on consulte « Mon compte » sans etre connecte.
class _InvitationConnexion extends StatelessWidget {
  const _InvitationConnexion();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GradientBackground(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Espaces.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(taille: 72),
                const SizedBox(height: Espaces.xl),
                Text(
                  'Rejoignez Marketplace',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Espaces.xs),
                Text(
                  'Creez un compte pour publier vos annonces, reserver et '
                  'discuter avec les vendeurs.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Espaces.xxl),
                AppButton(
                  libelle: 'Se connecter',
                  icone: Icons.login_rounded,
                  onPressed: () => context.pushNamed(Routes.connexion),
                ),
                const SizedBox(height: Espaces.xs),
                AppButton(
                  libelle: 'Creer un compte',
                  style: StyleBouton.secondaire,
                  onPressed: () => context.pushNamed(Routes.inscription),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
