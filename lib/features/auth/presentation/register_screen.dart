import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validateurs.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/gradient_background.dart';
import '../providers/auth_provider.dart';

/// Ecran d'inscription, en deux temps.
///
/// Le formulaire est coupe en deux volets, et ce n'est pas cosmetique :
/// le backend n'exige que trois champs (`username`, `password`,
/// `password_confirmation`). Tout le reste est facultatif. Presenter
/// huit champs d'un bloc laisse croire qu'ils sont tous obligatoires et
/// fait abandonner ; en demander trois, puis proposer de completer,
/// respecte ce que le serveur demande vraiment.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formulaireEssentiel = GlobalKey<FormState>();
  final _formulaireProfil = GlobalKey<FormState>();
  final _pages = PageController();

  final _username = TextEditingController();
  final _motDePasse = TextEditingController();
  final _confirmation = TextEditingController();
  final _email = TextEditingController();
  final _nomComplet = TextEditingController();
  final _telephone = TextEditingController();
  final _localisation = TextEditingController();

  Map<String, String> _erreursServeur = {};
  int _volet = 0;

  @override
  void dispose() {
    _pages.dispose();
    for (final c in [
      _username,
      _motDePasse,
      _confirmation,
      _email,
      _nomComplet,
      _telephone,
      _localisation,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _allerAu(int volet) {
    setState(() => _volet = volet);
    _pages.animateToPage(
      volet,
      duration: Mouvements.lent,
      curve: Mouvements.entree,
    );
  }

  void _suivant() {
    FocusScope.of(context).unfocus();
    if (!_formulaireEssentiel.currentState!.validate()) return;
    _allerAu(1);
  }

  Future<void> _soumettre() async {
    FocusScope.of(context).unfocus();
    setState(() => _erreursServeur = {});
    if (!_formulaireProfil.currentState!.validate()) return;

    try {
      final resultat = await ref.read(authProvider.notifier).inscrire(
            username: _username.text,
            motDePasse: _motDePasse.text,
            confirmation: _confirmation.text,
            email: _email.text,
            nomComplet: _nomComplet.text,
            telephone: _telephone.text,
            localisation: _localisation.text,
          );

      if (!mounted) return;

      // C'est le SERVEUR qui decide s'il faut verifier l'email, pas la
      // presence du champ dans le formulaire.
      if (resultat.verificationRequise) {
        AppFeedback.info(context, resultat.message);
        context.pushReplacementNamed(
          Routes.verificationEmail,
          queryParameters: {
            'username': _username.text.trim(),
            'email': _email.text.trim(),
          },
        );
      } else {
        AppFeedback.succes(context, 'Bienvenue sur Marketplace Burundi.');
      }
    } on ApiException catch (erreur) {
      if (!mounted) return;
      setState(() => _erreursServeur = erreur.erreursChamps);

      // Une erreur sur un champ du premier volet doit ramener l'oeil
      // dessus, sinon la personne cherche un message qu'elle ne voit pas.
      const champsEssentiels = {
        'username',
        'password',
        'password_confirmation',
      };
      if (erreur.erreursChamps.keys.any(champsEssentiels.contains)) {
        _allerAu(0);
      }
      AppFeedback.erreur(context, erreur.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(authProvider);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _EnTeteEtapes(
                volet: _volet,
                onRetour: () {
                  if (_volet == 0) {
                    context.pop();
                  } else {
                    _allerAu(0);
                  }
                },
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _VoletEssentiel(
                      cle: _formulaireEssentiel,
                      username: _username,
                      motDePasse: _motDePasse,
                      confirmation: _confirmation,
                      erreurs: _erreursServeur,
                      actif: !etat.enCours,
                      onSuivant: _suivant,
                      onConnexion: () => context.pop(),
                    ),
                    _VoletProfil(
                      cle: _formulaireProfil,
                      email: _email,
                      nomComplet: _nomComplet,
                      telephone: _telephone,
                      localisation: _localisation,
                      erreurs: _erreursServeur,
                      enCours: etat.enCours,
                      onSoumettre: _soumettre,
                    ),
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

/// En-tete avec la barre de progression des deux volets.
class _EnTeteEtapes extends StatelessWidget {
  const _EnTeteEtapes({required this.volet, required this.onRetour});

  final int volet;
  final VoidCallback onRetour;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espaces.sm,
        Espaces.xs,
        Espaces.ecran,
        Espaces.xs,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onRetour,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Retour',
          ),
          const SizedBox(width: Espaces.xs),
          Expanded(
            child: Row(
              children: List.generate(2, (index) {
                final atteint = index <= volet;
                return Expanded(
                  child: AnimatedContainer(
                    duration: Mouvements.normal,
                    curve: Mouvements.sortie,
                    height: 4,
                    margin: EdgeInsets.only(right: index == 0 ? 6 : 0),
                    decoration: BoxDecoration(
                      gradient: atteint ? AppColors.degradeMarque : null,
                      color: atteint
                          ? null
                          : Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(Rayons.pilule),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: Espaces.md),
          Text(
            '${volet + 1}/2',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.emeraude,
                ),
          ),
        ],
      ),
    );
  }
}

class _VoletEssentiel extends StatelessWidget {
  const _VoletEssentiel({
    required this.cle,
    required this.username,
    required this.motDePasse,
    required this.confirmation,
    required this.erreurs,
    required this.actif,
    required this.onSuivant,
    required this.onConnexion,
  });

  final GlobalKey<FormState> cle;
  final TextEditingController username;
  final TextEditingController motDePasse;
  final TextEditingController confirmation;
  final Map<String, String> erreurs;
  final bool actif;
  final VoidCallback onSuivant;
  final VoidCallback onConnexion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Espaces.ecran,
        Espaces.md,
        Espaces.ecran,
        Espaces.xxl,
      ),
      child: Form(
        key: cle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Creer votre compte', style: theme.textTheme.headlineLarge)
                .animate()
                .fadeIn()
                .slideY(begin: 0.25),
            const SizedBox(height: Espaces.xs),
            Text(
              "Trois informations suffisent pour commencer. "
              "Le reste est facultatif.",
              style: theme.textTheme.bodyMedium,
            ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.25),
            const SizedBox(height: Espaces.xxl),

            AppTextField(
              controleur: username,
              libelle: "Nom d'utilisateur",
              indice: 'chris',
              icone: Icons.alternate_email_rounded,
              actionClavier: TextInputAction.next,
              validateur: Validateurs.username,
              erreurServeur: erreurs['username'],
              actif: actif,
            ).animate(delay: 140.ms).fadeIn().slideY(begin: 0.25),
            const SizedBox(height: Espaces.xxs),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                "C'est votre identifiant de connexion. Il est unique et "
                "ne pourra plus etre change.",
                style: theme.textTheme.bodySmall,
              ),
            ).animate(delay: 160.ms).fadeIn(),

            const SizedBox(height: Espaces.md),

            AppTextField(
              controleur: motDePasse,
              libelle: 'Mot de passe',
              indice: 'Au moins 8 caracteres',
              icone: Icons.lock_outline_rounded,
              motDePasse: true,
              actionClavier: TextInputAction.next,
              validateur: Validateurs.motDePasse,
              erreurServeur: erreurs['password'],
              actif: actif,
            ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.25),

            const SizedBox(height: Espaces.md),

            AppTextField(
              controleur: confirmation,
              libelle: 'Confirmer le mot de passe',
              icone: Icons.lock_person_outlined,
              motDePasse: true,
              actionClavier: TextInputAction.done,
              onSubmit: (_) => onSuivant(),
              validateur: Validateurs.confirmation(() => motDePasse.text),
              erreurServeur: erreurs['password_confirmation'],
              actif: actif,
            ).animate(delay: 250.ms).fadeIn().slideY(begin: 0.25),

            const SizedBox(height: Espaces.xxl),

            AppButton(
              libelle: 'Continuer',
              icone: Icons.arrow_forward_rounded,
              onPressed: actif ? onSuivant : null,
            ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3),

            const SizedBox(height: Espaces.md),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Deja inscrit ?', style: theme.textTheme.bodyMedium),
                TextButton(
                  onPressed: actif ? onConnexion : null,
                  child: Text(
                    'Se connecter',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.emeraude,
                    ),
                  ),
                ),
              ],
            ).animate(delay: 340.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}

class _VoletProfil extends StatelessWidget {
  const _VoletProfil({
    required this.cle,
    required this.email,
    required this.nomComplet,
    required this.telephone,
    required this.localisation,
    required this.erreurs,
    required this.enCours,
    required this.onSoumettre,
  });

  final GlobalKey<FormState> cle;
  final TextEditingController email;
  final TextEditingController nomComplet;
  final TextEditingController telephone;
  final TextEditingController localisation;
  final Map<String, String> erreurs;
  final bool enCours;
  final VoidCallback onSoumettre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Espaces.ecran,
        Espaces.md,
        Espaces.ecran,
        Espaces.xxl,
      ),
      child: Form(
        key: cle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Completer le profil', style: theme.textTheme.headlineLarge),
            const SizedBox(height: Espaces.xs),
            Text(
              'Tout est facultatif. Vous pourrez le modifier plus tard.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Espaces.xl),

            AppTextField(
              controleur: email,
              libelle: 'Email (facultatif)',
              indice: 'chris@exemple.bi',
              icone: Icons.mail_outline_rounded,
              typeClavier: TextInputType.emailAddress,
              actionClavier: TextInputAction.next,
              validateur: Validateurs.emailFacultatif,
              erreurServeur: erreurs['email'],
              actif: !enCours,
            ),
            const SizedBox(height: Espaces.xs),
            const _NoteEmail(),

            const SizedBox(height: Espaces.md),

            AppTextField(
              controleur: nomComplet,
              libelle: 'Nom complet',
              indice: 'Chris Ndayizeye',
              icone: Icons.badge_outlined,
              actionClavier: TextInputAction.next,
              erreurServeur: erreurs['nom_complet'],
              actif: !enCours,
            ),
            const SizedBox(height: Espaces.md),

            AppTextField(
              controleur: telephone,
              libelle: 'Telephone',
              indice: '+257 69 00 00 00',
              icone: Icons.phone_outlined,
              typeClavier: TextInputType.phone,
              actionClavier: TextInputAction.next,
              validateur: Validateurs.telephoneFacultatif,
              erreurServeur: erreurs['telephone'],
              actif: !enCours,
            ),
            const SizedBox(height: Espaces.md),

            AppTextField(
              controleur: localisation,
              libelle: 'Localisation',
              indice: 'Kinindo, Bujumbura',
              icone: Icons.place_outlined,
              actionClavier: TextInputAction.done,
              onSubmit: (_) => onSoumettre(),
              erreurServeur: erreurs['localisation'],
              actif: !enCours,
            ),
            const SizedBox(height: Espaces.xxs),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                'Ecrivez librement : un quartier, une commune ou un simple '
                'point de rencontre. Vous n\'avez pas a donner votre adresse.',
                style: theme.textTheme.bodySmall,
              ),
            ),

            const SizedBox(height: Espaces.xxl),

            AppButton(
              libelle: 'Creer mon compte',
              icone: Icons.check_rounded,
              enChargement: enCours,
              onPressed: onSoumettre,
            ),
          ],
        ),
      ),
    );
  }
}

/// Explique la contrepartie de l'email avant que la personne ne le saisisse,
/// plutot que de la surprendre avec un ecran de code ensuite.
class _NoteEmail extends StatelessWidget {
  const _NoteEmail();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Espaces.sm),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.09),
        borderRadius: Rayons.champ,
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
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
              "Si vous donnez un email, un code vous sera envoye et le "
              "compte restera inactif tant qu'il n'est pas saisi. Sans "
              "email, votre compte est utilisable immediatement — mais vous "
              "ne pourrez pas reinitialiser votre mot de passe.",
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
