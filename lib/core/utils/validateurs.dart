/// Validateurs de formulaire.
///
/// Ils ne font que la verification evidente : champ vide, longueur
/// minimale, forme d'une adresse. Le reste — unicite du nom d'utilisateur,
/// robustesse du mot de passe selon les regles Django — appartient au
/// serveur, qui est le seul a pouvoir en juger. Dupliquer ces regles ici
/// produirait deux verites qui finiraient par diverger.
class Validateurs {
  const Validateurs._();

  static String? requis(String? valeur, {String champ = 'Ce champ'}) {
    if (valeur == null || valeur.trim().isEmpty) {
      return '$champ est obligatoire.';
    }
    return null;
  }

  static String? username(String? valeur) {
    final vide = requis(valeur, champ: "Le nom d'utilisateur");
    if (vide != null) return vide;
    final texte = valeur!.trim();
    if (texte.length < 3) {
      return "Au moins 3 caracteres.";
    }
    if (texte.contains(' ')) {
      return "Pas d'espace dans le nom d'utilisateur.";
    }
    return null;
  }

  /// Le mot de passe doit faire 8 caracteres : c'est le minimum impose par
  /// le serializer du backend. Le reste des regles (trop courant, trop
  /// proche du nom) est verifie par Django et revient en `errors`.
  static String? motDePasse(String? valeur) {
    final vide = requis(valeur, champ: 'Le mot de passe');
    if (vide != null) return vide;
    if (valeur!.length < 8) {
      return 'Au moins 8 caracteres.';
    }
    return null;
  }

  static String? Function(String?) confirmation(String Function() attendu) {
    return (valeur) {
      final vide = requis(valeur, champ: 'La confirmation');
      if (vide != null) return vide;
      if (valeur != attendu()) {
        return 'Les deux mots de passe ne correspondent pas.';
      }
      return null;
    };
  }

  /// Email FACULTATIF : vide est valide. C'est une regle metier du
  /// backend — on peut creer un compte sans adresse.
  static String? emailFacultatif(String? valeur) {
    if (valeur == null || valeur.trim().isEmpty) return null;
    final texte = valeur.trim();
    final motif = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!motif.hasMatch(texte)) {
      return 'Adresse email invalide.';
    }
    return null;
  }

  static String? codeVerification(String? valeur) {
    final vide = requis(valeur, champ: 'Le code');
    if (vide != null) return vide;
    final texte = valeur!.trim();
    if (texte.length != 6 || int.tryParse(texte) == null) {
      return 'Le code comporte 6 chiffres.';
    }
    return null;
  }

  /// Telephone facultatif, format libre : le serveur ne le verifie pas non
  /// plus (c'est une information de contact, jamais utilisee pour
  /// authentifier).
  static String? telephoneFacultatif(String? valeur) {
    if (valeur == null || valeur.trim().isEmpty) return null;
    final chiffres = valeur.replaceAll(RegExp(r'[^0-9]'), '');
    if (chiffres.length < 6) return 'Numero trop court.';
    return null;
  }
}
