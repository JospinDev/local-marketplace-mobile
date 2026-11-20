import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Saisie d'un code a 6 chiffres.
///
/// Un seul `TextField` invisible porte toute la valeur, et les six cases
/// ne sont que de la peinture. C'est ce qui permet au collage et au
/// remplissage automatique du SMS/email de fonctionner, alors que six
/// champs separes les cassent — chacun ne recevant qu'un caractere.
class CodeInput extends StatefulWidget {
  const CodeInput({
    super.key,
    required this.controleur,
    this.longueur = 6,
    this.onComplet,
    this.actif = true,
    this.enErreur = false,
  });

  final TextEditingController controleur;
  final int longueur;

  /// Appele des que les six chiffres sont saisis : on valide sans obliger
  /// a chercher le bouton.
  final void Function(String)? onComplet;

  final bool actif;
  final bool enErreur;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controleur.addListener(_surChangement);
  }

  @override
  void dispose() {
    widget.controleur.removeListener(_surChangement);
    _focus.dispose();
    super.dispose();
  }

  void _surChangement() {
    setState(() {});
    if (widget.controleur.text.length == widget.longueur) {
      _focus.unfocus();
      widget.onComplet?.call(widget.controleur.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final saisi = widget.controleur.text;

    return Stack(
      children: [
        // Le vrai champ, invisible mais bien present : c'est lui qui
        // recoit le clavier, le collage et l'autofill.
        Opacity(
          opacity: 0,
          child: SizedBox(
            height: 60,
            child: TextField(
              controller: widget.controleur,
              focusNode: _focus,
              enabled: widget.actif,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: widget.longueur,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.longueur),
              ],
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
        ),
        GestureDetector(
          onTap: widget.actif ? () => _focus.requestFocus() : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.longueur, (index) {
              final rempli = index < saisi.length;
              final actif = index == saisi.length && _focus.hasFocus;

              return AnimatedContainer(
                duration: Mouvements.rapide,
                curve: Mouvements.sortie,
                width: 48,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sombre ? AppColors.encreSurface : AppColors.blanc,
                  borderRadius: Rayons.champ,
                  border: Border.all(
                    color: widget.enErreur
                        ? AppColors.erreur
                        : actif
                            ? AppColors.emeraude
                            : rempli
                                ? AppColors.emeraude.withValues(alpha: 0.45)
                                : (sombre
                                    ? AppColors.encreBordure
                                    : AppColors.bordureClaire),
                    width: actif || widget.enErreur ? 1.8 : 1,
                  ),
                  boxShadow: actif
                      ? [
                          BoxShadow(
                            color: AppColors.emeraude.withValues(alpha: 0.18),
                            blurRadius: 14,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child: AnimatedSwitcher(
                  duration: Mouvements.eclair,
                  transitionBuilder: (enfant, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: enfant),
                  ),
                  child: rempli
                      ? Text(
                          saisi[index],
                          key: ValueKey('$index-${saisi[index]}'),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        )
                      : Container(
                          key: ValueKey('vide-$index'),
                          width: 8,
                          height: 2,
                          decoration: BoxDecoration(
                            color: (sombre
                                    ? AppColors.texteClairDoux
                                    : AppColors.texteSombreDoux)
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
