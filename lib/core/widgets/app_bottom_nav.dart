import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ElementNav {
  const ElementNav({
    required this.icone,
    required this.iconeActive,
    required this.libelle,
  });

  final IconData icone;
  final IconData iconeActive;
  final String libelle;
}

/// Barre de navigation basse.
///
/// Elle est dessinee a la main plutot que d'utiliser `NavigationBar` pour
/// trois raisons : une pastille lumineuse qui GLISSE jusqu'a l'onglet
/// choisi (le composant standard se contente d'un fondu), un libelle qui
/// n'apparait que sur l'onglet actif — ce qui laisse respirer les quatre
/// autres — et un fond translucide accorde au reste de l'application.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.onChange,
    required this.elements,
    this.badges = const {},
  });

  final int index;
  final ValueChanged<int> onChange;
  final List<ElementNav> elements;

  /// Pastilles de comptage par index d'onglet (messages non lus...).
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final basSysteme = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(
        left: Espaces.sm,
        right: Espaces.sm,
        top: Espaces.xs,
        bottom: basSysteme > 0 ? basSysteme - 4 : Espaces.xs,
      ),
      decoration: BoxDecoration(
        color: sombre
            ? AppColors.encreSurface.withValues(alpha: 0.96)
            : AppColors.blanc.withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(
            color: sombre ? AppColors.encreBordure : AppColors.bordureClaire,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, contraintes) {
            final largeurOnglet = contraintes.maxWidth / elements.length;
            return Stack(
              children: [
                // Pastille lumineuse, qui glisse d'un onglet a l'autre.
                AnimatedPositioned(
                  duration: Mouvements.normal,
                  curve: Mouvements.entree,
                  left: largeurOnglet * index + largeurOnglet / 2 - 22,
                  top: 0,
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: AppColors.degradeMarque,
                      borderRadius: BorderRadius.circular(Rayons.pilule),
                      boxShadow: AppColors.halo(AppColors.emeraude),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(elements.length, (i) {
                    return Expanded(
                      child: _Onglet(
                        element: elements[i],
                        actif: i == index,
                        badge: badges[i] ?? 0,
                        onTap: () {
                          if (i != index) HapticFeedback.selectionClick();
                          onChange(i);
                        },
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({
    required this.element,
    required this.actif,
    required this.badge,
    required this.onTap,
  });

  final ElementNav element;
  final bool actif;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;
    final couleur = actif
        ? AppColors.emeraude
        : (sombre ? AppColors.texteClairDoux : AppColors.texteSombreDoux);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Rayons.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Espaces.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  duration: Mouvements.normal,
                  curve: Mouvements.rebond,
                  scale: actif ? 1.12 : 1,
                  child: Icon(
                    actif ? element.iconeActive : element.icone,
                    size: 23,
                    color: couleur,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -5,
                    right: -9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      constraints: const BoxConstraints(minWidth: 17),
                      decoration: BoxDecoration(
                        color: AppColors.erreur,
                        borderRadius: BorderRadius.circular(Rayons.pilule),
                        border: Border.all(
                          color: sombre
                              ? AppColors.encreSurface
                              : AppColors.blanc,
                          width: 1.6,
                        ),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Le libelle n'existe que pour l'onglet actif : il apparait en
            // poussant doucement, ce qui attire l'oeil sur le changement.
            AnimatedSize(
              duration: Mouvements.normal,
              curve: Mouvements.entree,
              child: actif
                  ? Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        element.libelle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: couleur,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                      ),
                    )
                  : const SizedBox(width: 0, height: 3),
            ),
          ],
        ),
      ),
    );
  }
}
