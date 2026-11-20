import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/gradient_background.dart';
import '../providers/auth_provider.dart';

/// Ecran de demarrage.
///
/// Il sert a quelque chose de precis : pendant que le logo se dessine, on
/// relit le trousseau et on appelle `/me/` pour savoir si la session tient
/// toujours. L'animation n'est donc pas decorative — elle occupe exactement
/// le temps d'un aller-retour reseau.
///
/// Une duree plancher de 1,4 s evite le clignotement quand la reponse
/// arrive en 80 ms : un ecran qui apparait et disparait aussitot donne une
/// impression de bug, pas de rapidite.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _trace = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final debut = DateTime.now();
      await ref.read(authProvider.notifier).demarrer();

      // Plancher d'affichage, pour que le logo ait le temps d'exister.
      final ecoule = DateTime.now().difference(debut);
      const plancher = Duration(milliseconds: 1400);
      if (ecoule < plancher) {
        await Future<void>.delayed(plancher - ecoule);
      }
      // La redirection est faite par le routeur, qui observe la phase.
    });
  }

  @override
  void dispose() {
    _trace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: GradientBackground(
        intensite: 1.3,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _trace,
                builder: (context, _) => BrandMark(
                  taille: 104,
                  progression: Curves.easeInOut.transform(_trace.value),
                ),
              ),
              const SizedBox(height: Espaces.xl),
              Text(
                'Marketplace',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              )
                  .animate(delay: 700.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.4, curve: Curves.easeOutCubic),
              const SizedBox(height: 2),
              Text(
                'BURUNDI',
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 6,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emeraude,
                ),
              )
                  .animate(delay: 820.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.6, curve: Curves.easeOutCubic),
              const SizedBox(height: Espaces.xxxl),
              SizedBox(
                width: 110,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Rayons.pilule),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: AppColors.emeraude.withValues(alpha: 0.16),
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.emeraude,
                    ),
                  ),
                ),
              ).animate(delay: 1.seconds).fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
