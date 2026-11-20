import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Champ de saisie de l'application.
///
/// Il fait trois choses qu'un `TextFormField` nu ne fait pas :
///
/// - **l'icone de gauche prend la couleur de marque au focus**, ce qui
///   designe le champ actif meme quand le clavier masque la bordure ;
/// - **l'erreur apparait en glissant** plutot qu'en poussant brutalement la
///   mise en page vers le bas ;
/// - **le champ tremble** une fois a la premiere erreur : le mouvement est
///   percu avant que le texte ne soit lu.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controleur,
    required this.libelle,
    this.indice,
    this.icone,
    this.motDePasse = false,
    this.typeClavier,
    this.validateur,
    this.erreurServeur,
    this.actionClavier,
    this.onSubmit,
    this.formateurs,
    this.actif = true,
    this.lignes = 1,
    this.maxCaracteres,
    this.autoFocus = false,
  });

  final TextEditingController controleur;
  final String libelle;
  final String? indice;
  final IconData? icone;
  final bool motDePasse;
  final TextInputType? typeClavier;
  final String? Function(String?)? validateur;

  /// Erreur renvoyee par le serveur pour CE champ, extraite de
  /// `ApiException.erreursChamps`. Elle s'efface des que l'on retape.
  final String? erreurServeur;

  final TextInputAction? actionClavier;
  final void Function(String)? onSubmit;
  final List<TextInputFormatter>? formateurs;
  final bool actif;
  final int lignes;
  final int? maxCaracteres;
  final bool autoFocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField>
    with SingleTickerProviderStateMixin {
  final FocusNode _focus = FocusNode();
  late final AnimationController _tremblement = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool _masque = true;
  bool _aLeFocus = false;
  String? _erreurAffichee;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _aLeFocus = _focus.hasFocus);
    });
    _erreurAffichee = widget.erreurServeur;
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.erreurServeur != oldWidget.erreurServeur) {
      _erreurAffichee = widget.erreurServeur;
      if (widget.erreurServeur != null) _tremblement.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _tremblement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;
    final couleurIcone = _erreurAffichee != null
        ? AppColors.erreur
        : _aLeFocus
            ? AppColors.emeraude
            : (sombre ? AppColors.texteClairDoux : AppColors.texteSombreDoux);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: Espaces.xs),
          child: Text(
            widget.libelle,
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sombre
                  ? AppColors.texteClairDoux
                  : AppColors.texteSombreDoux,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _tremblement,
          builder: (context, enfant) {
            // Oscillation amortie : l'amplitude decroit avec le temps,
            // comme un objet reel qui revient a sa position.
            final t = _tremblement.value;
            final amplitude = (1 - t) * 9;
            final decalage = amplitude * _sinus(t * 3);
            return Transform.translate(
              offset: Offset(decalage, 0),
              child: enfant,
            );
          },
          child: TextFormField(
            controller: widget.controleur,
            focusNode: _focus,
            enabled: widget.actif,
            autofocus: widget.autoFocus,
            obscureText: widget.motDePasse && _masque,
            keyboardType: widget.typeClavier,
            textInputAction: widget.actionClavier,
            onFieldSubmitted: widget.onSubmit,
            inputFormatters: widget.formateurs,
            maxLines: widget.motDePasse ? 1 : widget.lignes,
            maxLength: widget.maxCaracteres,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            // On efface l'erreur du serveur des la premiere frappe :
            // la garder affichee pendant la correction est deroutant.
            onChanged: (_) {
              if (_erreurAffichee != null) {
                setState(() => _erreurAffichee = null);
              }
            },
            validator: (valeur) {
              final erreur = widget.validateur?.call(valeur);
              if (erreur != null) {
                _tremblement.forward(from: 0);
              }
              return erreur;
            },
            decoration: InputDecoration(
              hintText: widget.indice,
              counterText: '',
              errorText: _erreurAffichee,
              prefixIcon: widget.icone == null
                  ? null
                  : AnimatedSwitcher(
                      duration: Mouvements.rapide,
                      child: Icon(
                        widget.icone,
                        key: ValueKey(couleurIcone.toARGB32()),
                        size: 20,
                        color: couleurIcone,
                      ),
                    ),
              suffixIcon: widget.motDePasse
                  ? IconButton(
                      onPressed: () => setState(() => _masque = !_masque),
                      icon: Icon(
                        _masque
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: sombre
                            ? AppColors.texteClairDoux
                            : AppColors.texteSombreDoux,
                      ),
                      tooltip: _masque
                          ? 'Afficher le mot de passe'
                          : 'Masquer le mot de passe',
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  /// Sinus approxime sans importer dart:math pour si peu.
  double _sinus(double tours) {
    const pi2 = 6.283185307179586;
    final x = tours * pi2;
    // Serie de Taylor tronquee, amplement suffisante pour un tremblement.
    final r = x % pi2;
    final y = r > 3.141592653589793 ? r - pi2 : r;
    final y2 = y * y;
    return y * (1 - y2 / 6 + y2 * y2 / 120);
  }
}
