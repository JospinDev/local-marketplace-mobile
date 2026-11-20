import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Variantes visuelles d'un bouton.
enum StyleBouton {
  /// Degrade de marque, halo colore. Une seule par ecran.
  principal,

  /// Fond neutre, bordure discrete. Pour les actions secondaires.
  secondaire,

  /// Sans fond. Pour les actions de faible engagement.
  fantome,

  /// Rouge. Pour supprimer, annuler, bloquer.
  danger,
}

/// Bouton de l'application, avec retour tactile et etat de chargement.
///
/// Trois details font la difference de rendu, et aucun n'est gratuit :
///
/// - **l'enfoncement** : le bouton se contracte a 96 % pendant l'appui.
///   C'est ce qui donne la sensation d'un objet physique plutot que d'une
///   zone cliquable ;
/// - **la vibration** : un `selectionClick` au moment du toucher confirme
///   l'appui meme quand l'animation est masquee par le doigt ;
/// - **le chargement sans saut** : le bouton garde sa largeur quand il
///   bascule en chargement, sinon toute la mise en page tressaute.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.libelle,
    this.onPressed,
    this.style = StyleBouton.principal,
    this.icone,
    this.enChargement = false,
    this.pleineLargeur = true,
    this.compact = false,
  });

  final String libelle;
  final VoidCallback? onPressed;
  final StyleBouton style;
  final IconData? icone;
  final bool enChargement;
  final bool pleineLargeur;
  final bool compact;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: Mouvements.eclair,
    lowerBound: 0,
    upperBound: 0.04,
  );

  bool get _actif => widget.onPressed != null && !widget.enChargement;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _appuyer(_) {
    if (!_actif) return;
    _controleur.forward();
    HapticFeedback.selectionClick();
  }

  void _relacher([_]) {
    if (_controleur.value > 0) _controleur.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;
    final hauteur = widget.compact ? 44.0 : 56.0;

    final (fond, texte, bordure, halo) = _apparence(sombre);

    return GestureDetector(
      onTapDown: _appuyer,
      onTapUp: _relacher,
      onTapCancel: _relacher,
      onTap: _actif ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: _controleur,
        builder: (context, enfant) => Transform.scale(
          scale: 1 - _controleur.value,
          child: enfant,
        ),
        child: AnimatedOpacity(
          duration: Mouvements.rapide,
          opacity: _actif ? 1 : 0.55,
          child: AnimatedContainer(
            duration: Mouvements.rapide,
            curve: Mouvements.sortie,
            height: hauteur,
            width: widget.pleineLargeur ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: widget.pleineLargeur ? 0 : Espaces.xl,
            ),
            decoration: BoxDecoration(
              gradient: fond,
              color: fond == null ? bordure : null,
              borderRadius: BorderRadius.circular(Rayons.sm),
              border: widget.style == StyleBouton.secondaire
                  ? Border.all(
                      color: sombre
                          ? AppColors.encreBordure
                          : AppColors.bordureClaire,
                    )
                  : null,
              boxShadow: _actif && halo != null ? AppColors.halo(halo) : null,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: Mouvements.rapide,
                child: widget.enChargement
                    ? SizedBox(
                        key: const ValueKey('chargement'),
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(texte),
                        ),
                      )
                    : Row(
                        key: const ValueKey('contenu'),
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icone != null) ...[
                            Icon(widget.icone, size: 19, color: texte),
                            const SizedBox(width: Espaces.xs + 2),
                          ],
                          Flexible(
                            child: Text(
                              widget.libelle,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: texte,
                                fontSize: widget.compact ? 14 : 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (LinearGradient?, Color, Color, Color?) _apparence(bool sombre) {
    switch (widget.style) {
      case StyleBouton.principal:
        return (
          AppColors.degradeMarque,
          Colors.white,
          Colors.transparent,
          AppColors.emeraude,
        );
      case StyleBouton.secondaire:
        return (
          null,
          sombre ? AppColors.texteClair : AppColors.texteSombre,
          sombre ? AppColors.encreSurfaceHaute : AppColors.blanc,
          null,
        );
      case StyleBouton.fantome:
        return (
          null,
          sombre ? AppColors.emeraudeClair : AppColors.emeraudeSombre,
          Colors.transparent,
          null,
        );
      case StyleBouton.danger:
        return (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE5484D), Color(0xFFB42318)],
          ),
          Colors.white,
          Colors.transparent,
          AppColors.erreur,
        );
    }
  }
}
