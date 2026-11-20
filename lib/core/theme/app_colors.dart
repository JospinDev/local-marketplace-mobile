import 'package:flutter/material.dart';

/// Palette de Marketplace Burundi.
///
/// L'identite ne copie aucune des maquettes de reference : elle part des
/// couleurs du Burundi (le vert et le rouge du drapeau) mais les traduit en
/// teintes utilisables sur un ecran, avec un vert emeraude profond comme
/// couleur de marque et un or chaud comme accent. Le rouge est reserve aux
/// erreurs, pour qu'il garde sa force de signal.
///
/// Toutes les valeurs existent en clair ET en sombre : on ne choisit jamais
/// une couleur « a la main » dans un widget, on prend celle du theme.
class AppColors {
  const AppColors._();

  // ----------------------------------------------------------- marque
  /// Vert emeraude : couleur principale, boutons et etats actifs.
  static const Color emeraude = Color(0xFF00B368);
  static const Color emeraudeClair = Color(0xFF3DDC97);
  static const Color emeraudeSombre = Color(0xFF007A47);

  /// Sarcelle : seconde couleur du degrade de marque.
  static const Color sarcelle = Color(0xFF00A09B);
  static const Color sarcelleSombre = Color(0xFF006D73);

  /// Or chaud : accent des prix, des promotions et des etoiles.
  static const Color or = Color(0xFFFFB020);
  static const Color orClair = Color(0xFFFFD166);

  // --------------------------------------------------------- encres
  /// Fonds sombres, bleutes plutot que gris : le noir pur ecrase les
  /// ombres et fait paraitre les cartes « collees » a l'ecran.
  static const Color encre = Color(0xFF070B14);
  static const Color encreSurface = Color(0xFF101726);
  static const Color encreSurfaceHaute = Color(0xFF18212F);
  static const Color encreBordure = Color(0xFF24304A);

  // ---------------------------------------------------------- clair
  static const Color nuage = Color(0xFFF5F7FB);
  static const Color blanc = Color(0xFFFFFFFF);
  static const Color blancCasse = Color(0xFFFBFCFE);
  static const Color bordureClaire = Color(0xFFE4E9F2);

  // ----------------------------------------------------------- texte
  static const Color texteSombre = Color(0xFF0C1322);
  static const Color texteSombreDoux = Color(0xFF5A6682);
  static const Color texteClair = Color(0xFFF2F5FA);
  static const Color texteClairDoux = Color(0xFF93A1BD);

  // --------------------------------------------------------- signaux
  static const Color succes = Color(0xFF12B76A);
  static const Color alerte = Color(0xFFF79009);
  static const Color erreur = Color(0xFFE5484D);
  static const Color info = Color(0xFF3B82F6);

  // -------------------------------------------------------- degrades
  /// Degrade de marque : du vert vers la sarcelle, en diagonale.
  static const LinearGradient degradeMarque = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emeraude, sarcelle],
  );

  static const LinearGradient degradeMarqueInverse = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sarcelle, emeraude],
  );

  /// Degrade chaud, pour les bandeaux promotionnels.
  static const LinearGradient degradeOr = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [or, Color(0xFFFF8A3D)],
  );

  /// Voile sombre pose sur une image pour que le texte reste lisible,
  /// quelle que soit la photo du vendeur.
  static const LinearGradient voileImage = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC070B14)],
    stops: [0.45, 1.0],
  );

  /// Degrade de « verre » pour les cartes translucides.
  static LinearGradient verre({bool sombre = true}) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: sombre
            ? [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.03)]
            : [Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0.55)],
      );

  // ----------------------------------------------------------- ombres
  /// Ombre douce et large : une ombre serree et foncee fait « autocollant »,
  /// une ombre large et transparente fait « materiau ».
  static List<BoxShadow> ombreCarte({bool sombre = false}) => [
        BoxShadow(
          color: sombre
              ? Colors.black.withValues(alpha: 0.45)
              : const Color(0xFF0C1322).withValues(alpha: 0.07),
          blurRadius: 28,
          offset: const Offset(0, 12),
          spreadRadius: -6,
        ),
      ];

  /// Halo colore sous un bouton principal : donne la sensation que le
  /// bouton emet sa propre lumiere.
  static List<BoxShadow> halo(Color couleur) => [
        BoxShadow(
          color: couleur.withValues(alpha: 0.38),
          blurRadius: 24,
          offset: const Offset(0, 10),
          spreadRadius: -4,
        ),
      ];
}
