import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validateurs.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/code_input.dart';
import '../../../core/widgets/gradient_background.dart';

/// Reinitialisation du mot de passe, en deux temps sur un seul ecran.
///
/// Le serveur n'accepte cette procedure QUE pour un compte dont l'email est
/// verifie : il n'existe pas d'autre canal. L'ecran le dit d'emblee, sinon
/// une personne sans email cherchera longtemps pourquoi on la refuse.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formulaireDemande = GlobalKey<FormState>();
  final _formulaireConfirmation = GlobalKey<FormState>();

  final _username = TextEditingController();
  final _code = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();

  bool _codeEnvoye = false;
  bool _enCours = false;
  Map<String, String> _erreurs = {};

  @override
  void dispose() {
    for (final c in [_username, _code, _nouveau, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _demander() async {
    FocusScope.of(context).unfocus();
    setState(() => _erreurs = {});
    if (!_formulaireDemande.currentState!.validate()) return;

    setState(() => _enCours = true);
    try {
      final message = await ref
          .read(authRepositoryProvider)
          .demanderReinitialisation(_username.text);
      if (!mounted) return;
      AppFeedback.succes(context, message);
      setState(() => _codeEnvoye = true);
    } on ApiException catch (erreur) {
      if (!mounted) return;
      setState(() => _erreurs = erreur.erreursChamps);
      AppFeedback.erreur(context, erreur.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _confirmer() async {
    FocusScope.of(context).unfocus();
    setState(() => _erreurs = {});
    if (!_formulaireConfirmation.currentState!.validate()) return;
    if (_code.text.trim().length != 6) {
      AppFeedback.attention(context, 'Entrez les 6 chiffres du code.');
      return;
    }

    setState(() => _enCours = true);
    try {
      final message =
          await ref.read(authRepositoryProvider).confirmerReinitialisation(
                username: _username.text,
                code: _code.text,
                nouveau: _nouveau.text,
                confirmation: _confirmation.text,
              );
      if (!mounted) return;
      AppFeedback.succes(context, message);
      context.pop();
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

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Retour',
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Espaces.ecran,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: Espaces.md),
                        Text(
                          'Mot de passe oublie',
                          style: theme.textTheme.headlineLarge,
                        ).animate().fadeIn().slideY(begin: 0.25),
                        const SizedBox(height: Espaces.xs),
                        Text(
                          _codeEnvoye
                              ? 'Entrez le code recu et choisissez un '
                                  'nouveau mot de passe.'
                              : "Indiquez votre nom d'utilisateur. Un code "
                                  'sera envoye a votre email verifie.',
                          style: theme.textTheme.bodyMedium,
                        ).animate(delay: 80.ms).fadeIn(),

                        const SizedBox(height: Espaces.xl),

                        // Volet 1 — toujours visible, il porte le username.
                        Form(
                          key: _formulaireDemande,
                          child: AppTextField(
                            controleur: _username,
                            libelle: "Nom d'utilisateur",
                            indice: 'chris',
                            icone: Icons.person_outline_rounded,
                            validateur: Validateurs.requis,
                            erreurServeur: _erreurs['username'],
                            actif: !_enCours && !_codeEnvoye,
                            actionClavier: TextInputAction.done,
                            onSubmit: (_) => _codeEnvoye ? null : _demander(),
                          ),
                        ).animate(delay: 140.ms).fadeIn().slideY(begin: 0.2),

                        const SizedBox(height: Espaces.lg),

                        // Volet 2 — apparait en glissant apres l'envoi.
                        AnimatedSize(
                          duration: Mouvements.lent,
                          curve: Mouvements.entree,
                          child: _codeEnvoye
                              ? Form(
                                  key: _formulaireConfirmation,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Code recu par email',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                          fontSize: 13,
                                          color: AppColors.texteSombreDoux,
                                        ),
                                      ),
                                      const SizedBox(height: Espaces.xs),
                                      CodeInput(
                                        controleur: _code,
                                        actif: !_enCours,
                                      ),
                                      const SizedBox(height: Espaces.lg),
                                      AppTextField(
                                        controleur: _nouveau,
                                        libelle: 'Nouveau mot de passe',
                                        icone: Icons.lock_outline_rounded,
                                        motDePasse: true,
                                        validateur: Validateurs.motDePasse,
                                        erreurServeur:
                                            _erreurs['nouveau_password'],
                                        actif: !_enCours,
                                      ),
                                      const SizedBox(height: Espaces.md),
                                      AppTextField(
                                        controleur: _confirmation,
                                        libelle: 'Confirmer',
                                        icone: Icons.lock_person_outlined,
                                        motDePasse: true,
                                        validateur: Validateurs.confirmation(
                                          () => _nouveau.text,
                                        ),
                                        erreurServeur: _erreurs[
                                            'nouveau_password_confirmation'],
                                        actif: !_enCours,
                                        actionClavier: TextInputAction.done,
                                        onSubmit: (_) => _confirmer(),
                                      ),
                                      const SizedBox(height: Espaces.xl),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),

                        AppButton(
                          libelle: _codeEnvoye
                              ? 'Reinitialiser'
                              : 'Envoyer le code',
                          icone: _codeEnvoye
                              ? Icons.lock_reset_rounded
                              : Icons.send_rounded,
                          enChargement: _enCours,
                          onPressed: _codeEnvoye ? _confirmer : _demander,
                        ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.25),

                        if (_codeEnvoye) ...[
                          const SizedBox(height: Espaces.sm),
                          TextButton(
                            onPressed: _enCours
                                ? null
                                : () => setState(() {
                                      _codeEnvoye = false;
                                      _code.clear();
                                    }),
                            child: const Text(
                              "Changer de nom d'utilisateur",
                            ),
                          ),
                        ],

                        const SizedBox(height: Espaces.xl),

                        Container(
                          padding: const EdgeInsets.all(Espaces.sm),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.08),
                            borderRadius: Rayons.champ,
                            border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 17,
                                color: AppColors.info,
                              ),
                              const SizedBox(width: Espaces.xs),
                              Expanded(
                                child: Text(
                                  "Cette procedure n'est possible que pour "
                                  'un compte dont l\'email a ete verifie. '
                                  "Sans email, contactez l'administration.",
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ).animate(delay: 260.ms).fadeIn(),

                        const SizedBox(height: Espaces.xxl),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
