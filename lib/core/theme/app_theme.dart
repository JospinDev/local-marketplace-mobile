import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Rythme d'espacement et rayons de l'application.
///
/// Tout est un multiple de 4 : c'est ce qui fait qu'une interface « tombe
/// juste » sans qu'on sache dire pourquoi. Aucun widget ne doit ecrire une
/// marge en dur.
class Espaces {
  const Espaces._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Marge laterale des ecrans. Constante partout, sinon les colonnes ne
  /// s'alignent pas d'un ecran a l'autre.
  static const double ecran = 20;
}

class Rayons {
  const Rayons._();

  static const double xs = 10;
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 26;
  static const double xl = 34;
  static const double pilule = 999;

  static BorderRadius get carte => BorderRadius.circular(md);
  static BorderRadius get grandeCarte => BorderRadius.circular(lg);
  static BorderRadius get champ => BorderRadius.circular(sm);
}

/// Durees et courbes partagees.
///
/// Une application parait rapide quand ses animations sont COURTES et bien
/// amorties, pas quand elles sont absentes. 180–340 ms est la fenetre ou
/// l'oeil percoit un mouvement sans ressentir d'attente.
class Mouvements {
  const Mouvements._();

  static const Duration eclair = Duration(milliseconds: 120);
  static const Duration rapide = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration lent = Duration(milliseconds: 340);
  static const Duration page = Duration(milliseconds: 420);

  /// Courbe « emphasized » du Material 3 : demarre vite, finit en douceur.
  static const Curve sortie = Curves.easeOutCubic;
  static const Curve entree = Curves.easeInOutCubicEmphasized;
  static const Curve rebond = Curves.easeOutBack;
}

/// Themes clair et sombre de l'application.
class AppTheme {
  const AppTheme._();

  /// Police : Plus Jakarta Sans. Ses chiffres sont tabulaires, ce qui
  /// compte pour une application ou l'on affiche beaucoup de prix : les
  /// colonnes de montants restent alignees.
  static TextTheme _police(TextTheme base, Color couleur, Color couleurDouce) {
    final theme = GoogleFonts.plusJakartaSansTextTheme(base);
    return theme.copyWith(
      displayLarge: theme.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: couleur,
      ),
      displayMedium: theme.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        color: couleur,
      ),
      headlineLarge: theme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: couleur,
      ),
      headlineMedium: theme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: couleur,
      ),
      headlineSmall: theme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: couleur,
      ),
      titleLarge: theme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: couleur,
      ),
      titleMedium: theme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: couleur,
      ),
      titleSmall: theme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: couleur,
      ),
      bodyLarge: theme.bodyLarge?.copyWith(color: couleur, height: 1.5),
      bodyMedium: theme.bodyMedium?.copyWith(color: couleurDouce, height: 1.5),
      bodySmall: theme.bodySmall?.copyWith(color: couleurDouce, height: 1.45),
      labelLarge: theme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: couleur,
      ),
    );
  }

  // ------------------------------------------------------------- clair
  static ThemeData get clair {
    final base = ThemeData.light(useMaterial3: true);
    final schema = ColorScheme.fromSeed(
      seedColor: AppColors.emeraude,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.emeraude,
      secondary: AppColors.sarcelle,
      tertiary: AppColors.or,
      surface: AppColors.blanc,
      error: AppColors.erreur,
      onSurface: AppColors.texteSombre,
    );

    return base.copyWith(
      colorScheme: schema,
      scaffoldBackgroundColor: AppColors.nuage,
      textTheme: _police(
        base.textTheme,
        AppColors.texteSombre,
        AppColors.texteSombreDoux,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.texteSombre),
      ),
      cardTheme: CardThemeData(
        color: AppColors.blanc,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Rayons.carte),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.bordureClaire,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: _champs(
        fond: AppColors.blanc,
        bordure: AppColors.bordureClaire,
        texteDoux: AppColors.texteSombreDoux,
      ),
      snackBarTheme: _bulles(AppColors.texteSombre, AppColors.blanc),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.blanc,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Rayons.xl)),
        ),
      ),
      pageTransitionsTheme: _transitions,
      splashFactory: InkSparkle.splashFactory,
    );
  }

  // ------------------------------------------------------------ sombre
  static ThemeData get sombre {
    final base = ThemeData.dark(useMaterial3: true);
    final schema = ColorScheme.fromSeed(
      seedColor: AppColors.emeraude,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.emeraudeClair,
      secondary: AppColors.sarcelle,
      tertiary: AppColors.or,
      surface: AppColors.encreSurface,
      error: AppColors.erreur,
      onSurface: AppColors.texteClair,
    );

    return base.copyWith(
      colorScheme: schema,
      scaffoldBackgroundColor: AppColors.encre,
      textTheme: _police(
        base.textTheme,
        AppColors.texteClair,
        AppColors.texteClairDoux,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.texteClair),
      ),
      cardTheme: CardThemeData(
        color: AppColors.encreSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Rayons.carte),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.encreBordure,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: _champs(
        fond: AppColors.encreSurface,
        bordure: AppColors.encreBordure,
        texteDoux: AppColors.texteClairDoux,
      ),
      snackBarTheme: _bulles(AppColors.encreSurfaceHaute, AppColors.texteClair),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.encreSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Rayons.xl)),
        ),
      ),
      pageTransitionsTheme: _transitions,
      splashFactory: InkSparkle.splashFactory,
    );
  }

  // --------------------------------------------------------- fragments
  static InputDecorationTheme _champs({
    required Color fond,
    required Color bordure,
    required Color texteDoux,
  }) {
    OutlineInputBorder trait(Color couleur, double epaisseur) =>
        OutlineInputBorder(
          borderRadius: Rayons.champ,
          borderSide: BorderSide(color: couleur, width: epaisseur),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: fond,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Espaces.md,
        vertical: Espaces.md + 2,
      ),
      border: trait(bordure, 1),
      enabledBorder: trait(bordure, 1),
      // Le champ actif s'epaissit ET change de couleur : deux signaux
      // valent mieux qu'un pour qui distingue mal les teintes.
      focusedBorder: trait(AppColors.emeraude, 1.8),
      errorBorder: trait(AppColors.erreur, 1.4),
      focusedErrorBorder: trait(AppColors.erreur, 1.8),
      hintStyle: TextStyle(color: texteDoux, fontWeight: FontWeight.w400),
      labelStyle: TextStyle(color: texteDoux),
      errorStyle: const TextStyle(
        color: AppColors.erreur,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );
  }

  static SnackBarThemeData _bulles(Color fond, Color texte) =>
      SnackBarThemeData(
        backgroundColor: fond,
        contentTextStyle: TextStyle(color: texte, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.all(Espaces.md),
        shape: RoundedRectangleBorder(borderRadius: Rayons.carte),
      );

  /// Transitions de page : glissement + fondu, LA MEME sur les deux
  /// plateformes.
  ///
  /// On n'utilise pas la transition native d'iOS : l'application doit
  /// avoir la meme personnalite partout, et deux animations differentes
  /// compliquent les tests sans rien apporter a qui n'a qu'un telephone.
  static const PageTransitionsTheme _transitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _TransitionGlissee(),
      TargetPlatform.iOS: _TransitionGlissee(),
      TargetPlatform.macOS: _TransitionGlissee(),
      TargetPlatform.windows: _TransitionGlissee(),
      TargetPlatform.linux: _TransitionGlissee(),
    },
  );
}

/// Transition maison : la page entre depuis la droite en se fondant, et
/// l'ancienne recule legerement — ce qui donne une impression de
/// profondeur sans le cout d'une vraie animation 3D.
class _TransitionGlissee extends PageTransitionsBuilder {
  const _TransitionGlissee();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final entree = CurvedAnimation(
      parent: animation,
      curve: Mouvements.entree,
      reverseCurve: Mouvements.sortie,
    );
    final sortie = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Mouvements.entree,
    );

    return FadeTransition(
      opacity: entree,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(entree),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.04, 0),
          ).animate(sortie),
          child: child,
        ),
      ),
    );
  }
}
