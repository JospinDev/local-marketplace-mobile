import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/utils/validateurs.dart';
import '../providers/auth_provider.dart';

/// Ecran de connexion.
///
/// Le guide d'integration impose de distinguer trois echecs, parce que la
/// conduite a tenir differe :
///
/// - `401` : identifiants faux, on reste sur place ;
/// - `403` + email non verifie : on envoie vers la saisie du code ;
/// - `403` + compte suspendu : on affiche le motif, sans proposer de
///   reessayer, ce serait inutile.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formulaire = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _motDePasse = TextEditingController();

  Map<String, String> _erreursServeur = {};

  @override
  void dispose() {
    _username.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _soumettre() async {
    FocusScope.of(context).unfocus();
    setState(() => _erreursServeur = {});
    if (!_formulaire.currentState!.validate()) return;

    try {
      await ref.read(authProvider.notifier).connecter(
            username: _username.text,
            motDePasse: _motDePasse.text,
          );
      // La redirection est faite par le routeur.
    } on ApiException catch (erreur) {
      if (!mounted) return;
      setState(() => _erreursServeur = erreur.erreursChamps);

      // Email non verifie : le serveur refuse en 403 et le message le dit.
      // On conduit directement vers l'ecran de code, avec le username
      // deja rempli — redemander de le retaper serait une punition.
      final messageBas = erreur.message.toLowerCase();
      if (erreur.estInterdit &&
          (messageBas.contains('verif') || messageBas.contains('code'))) {
        AppFeedback.attention(context, erreur.message);
        context.pushNamed(
          Routes.verificationEmail,
          queryParameters: {'username': _username.text.trim()},
        );
        return;
      }

      AppFeedback.erreur(context, erreur.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final etat = ref.watch(authProvider);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: Espaces.ecran,
                vertical: Espaces.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Form(
                  key: _formulaire,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: Espaces.xl),
                      const Center(child: BrandMark(taille: 72))
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            curve: Curves.easeOutBack,
                          ),
                      const SizedBox(height: Espaces.xxl),

                      Text(
                        'Bon retour',
                        style: theme.textTheme.headlineLarge,
                      ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.3),
                      const SizedBox(height: Espaces.xs),
                      Text(
                        'Connectez-vous pour retrouver vos annonces, '
                        'vos reservations et vos discussions.',
                        style: theme.textTheme.bodyMedium,
                      ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.3),

                      const SizedBox(height: Espaces.xxl),

                      AppTextField(
                        controleur: _username,
                        libelle: "Nom d'utilisateur",
                        indice: 'chris',
                        icone: Icons.person_outline_rounded,
                        typeClavier: TextInputType.text,
                        actionClavier: TextInputAction.next,
                        validateur: Validateurs.requis,
                        erreurServeur: _erreursServeur['username'],
                        actif: !etat.enCours,
                      ).animate(delay: 240.ms).fadeIn().slideY(begin: 0.25),

                      const SizedBox(height: Espaces.md),

                      AppTextField(
                        controleur: _motDePasse,
                        libelle: 'Mot de passe',
                        indice: '........',
                        icone: Icons.lock_outline_rounded,
                        motDePasse: true,
                        actionClavier: TextInputAction.done,
                        onSubmit: (_) => _soumettre(),
                        validateur: Validateurs.requis,
                        erreurServeur: _erreursServeur['password'],
                        actif: !etat.enCours,
                      ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.25),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: etat.enCours
                              ? null
                              : () => context.pushNamed(
                                    Routes.motDePasseOublie,
                                  ),
                          child: Text(
                            'Mot de passe oublie ?',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.emeraude,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ).animate(delay: 340.ms).fadeIn(),

                      const SizedBox(height: Espaces.md),

                      AppButton(
                        libelle: 'Se connecter',
                        icone: Icons.arrow_forward_rounded,
                        enChargement: etat.enCours,
                        onPressed: _soumettre,
                      ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3),

                      const SizedBox(height: Espaces.xl),
                      const _Separateur(texte: 'ou')
                          .animate(delay: 460.ms)
                          .fadeIn(),
                      const SizedBox(height: Espaces.lg),

                      AppButton(
                        libelle: 'Decouvrir sans compte',
                        style: StyleBouton.secondaire,
                        icone: Icons.storefront_outlined,
                        onPressed: etat.enCours
                            ? null
                            : () => context.goNamed(Routes.accueil),
                      ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.3),

                      const SizedBox(height: Espaces.xl),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Pas encore de compte ?',
                            style: theme.textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: etat.enCours
                                ? null
                                : () => context.pushNamed(Routes.inscription),
                            child: Text(
                              'Creer un compte',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.emeraude,
                              ),
                            ),
                          ),
                        ],
                      ).animate(delay: 560.ms).fadeIn(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Separateur extends StatelessWidget {
  const _Separateur({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final trait = sombre ? AppColors.encreBordure : AppColors.bordureClaire;
    return Row(
      children: [
        Expanded(child: Divider(color: trait)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espaces.sm),
          child: Text(
            texte,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(child: Divider(color: trait)),
      ],
    );
  }
}
