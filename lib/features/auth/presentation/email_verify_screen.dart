import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/code_input.dart';
import '../../../core/widgets/gradient_background.dart';
import '../providers/auth_provider.dart';

/// Saisie du code a 6 chiffres recu par email.
///
/// Deux details comptent ici :
///
/// - le renvoi est limite a 5 par heure cote serveur ; on affiche donc un
///   compte a rebours de 60 secondes plutot que de laisser marteler le
///   bouton jusqu'au `429` ;
/// - le code expire au bout de 15 minutes et accepte 5 essais. Quand le
///   serveur refuse, son message dit precisement lequel des deux est en
///   cause, et on l'affiche tel quel.
class EmailVerifyScreen extends ConsumerStatefulWidget {
  const EmailVerifyScreen({
    super.key,
    required this.username,
    this.email,
  });

  final String username;
  final String? email;

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen> {
  final _code = TextEditingController();

  Timer? _minuteur;
  int _secondesRestantes = 0;
  bool _renvoiEnCours = false;
  bool _enErreur = false;

  @override
  void initState() {
    super.initState();
    _lancerCompteARebours();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _lancerCompteARebours() {
    _minuteur?.cancel();
    setState(() => _secondesRestantes = 60);
    _minuteur = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondesRestantes--);
      if (_secondesRestantes <= 0) timer.cancel();
    });
  }

  Future<void> _verifier() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      AppFeedback.attention(context, 'Entrez les 6 chiffres du code.');
      return;
    }

    setState(() => _enErreur = false);
    try {
      await ref.read(authProvider.notifier).verifierEmail(
            username: widget.username,
            code: code,
          );
      if (!mounted) return;
      AppFeedback.succes(context, 'Compte verifie. Bienvenue !');
      // Le routeur redirige vers l'accueil des que la phase change.
    } on ApiException catch (erreur) {
      if (!mounted) return;
      setState(() => _enErreur = true);
      _code.clear();
      AppFeedback.erreur(context, erreur.message);
    }
  }

  Future<void> _renvoyer() async {
    if (_secondesRestantes > 0 || _renvoiEnCours) return;
    setState(() => _renvoiEnCours = true);
    try {
      final message = await ref.read(authRepositoryProvider).renvoyerCode(
            username: widget.username,
            email: widget.email,
          );
      if (!mounted) return;
      AppFeedback.succes(context, message);
      _lancerCompteARebours();
    } on ApiException catch (erreur) {
      if (!mounted) return;
      AppFeedback.erreur(context, erreur.message);
    } finally {
      if (mounted) setState(() => _renvoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final etat = ref.watch(authProvider);
    final destinataire = widget.email?.isNotEmpty == true
        ? widget.email!
        : 'votre adresse email';

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
                        Center(
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              gradient: AppColors.degradeMarque,
                              borderRadius: BorderRadius.circular(Rayons.lg),
                              boxShadow: AppColors.halo(AppColors.emeraude),
                            ),
                            child: const Icon(
                              Icons.mark_email_unread_outlined,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .scale(
                              begin: const Offset(0.7, 0.7),
                              curve: Curves.easeOutBack,
                            ),

                        const SizedBox(height: Espaces.xl),
                        Text(
                          'Verifiez votre email',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium,
                        ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.25),
                        const SizedBox(height: Espaces.xs),
                        Text.rich(
                          TextSpan(
                            text: 'Nous avons envoye un code a 6 chiffres a ',
                            children: [
                              TextSpan(
                                text: destinataire,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ).animate(delay: 150.ms).fadeIn(),

                        const SizedBox(height: Espaces.xxl),

                        CodeInput(
                          controleur: _code,
                          enErreur: _enErreur,
                          actif: !etat.enCours,
                          onComplet: (_) => _verifier(),
                        ).animate(delay: 220.ms).fadeIn().slideY(begin: 0.2),

                        const SizedBox(height: Espaces.xxl),

                        AppButton(
                          libelle: 'Verifier',
                          icone: Icons.verified_outlined,
                          enChargement: etat.enCours,
                          onPressed: _verifier,
                        ).animate(delay: 280.ms).fadeIn().slideY(begin: 0.25),

                        const SizedBox(height: Espaces.lg),

                        Center(
                          child: _secondesRestantes > 0
                              ? Text(
                                  'Nouveau code possible dans '
                                  '${_secondesRestantes}s',
                                  style: theme.textTheme.bodySmall,
                                )
                              : TextButton.icon(
                                  onPressed:
                                      _renvoiEnCours ? null : _renvoyer,
                                  icon: _renvoiEnCours
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.refresh_rounded,
                                          size: 18,
                                        ),
                                  label: const Text('Renvoyer le code'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.emeraude,
                                  ),
                                ),
                        ).animate(delay: 320.ms).fadeIn(),

                        const SizedBox(height: Espaces.xl),

                        Container(
                          padding: const EdgeInsets.all(Espaces.sm),
                          decoration: BoxDecoration(
                            color: AppColors.alerte.withValues(alpha: 0.08),
                            borderRadius: Rayons.champ,
                            border: Border.all(
                              color: AppColors.alerte.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 17,
                                color: AppColors.alerte,
                              ),
                              const SizedBox(width: Espaces.xs),
                              Expanded(
                                child: Text(
                                  'Le code expire au bout de 15 minutes. '
                                  "Tant qu'il n'est pas saisi, le compte "
                                  'reste inactif.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ).animate(delay: 380.ms).fadeIn(),

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
