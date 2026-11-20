/// Mise en forme des montants, quantites et dates.
///
/// Ecrit a la main plutot qu'avec `intl` : le besoin tient en quelques
/// lignes, et c'est une dependance de moins a telecharger sur une
/// connexion instable. `intl` reviendra a l'etape 8, quand les ventes
/// demanderont des formats de date plus riches.
class Formats {
  const Formats._();

  /// Montant en francs burundais : « 250 000 BIF ».
  ///
  /// Le separateur est une espace INSECABLE : sans elle, un montant peut
  /// se couper en fin de ligne et « 250 » se retrouver seul au-dessus de
  /// « 000 », ce qui se lit comme deux cent cinquante.
  static String montant(num valeur, {String devise = 'BIF'}) {
    final entier = valeur.round();
    return '${groupes(entier)} $devise';
  }

  /// Montant sans la devise, pour les colonnes ou elle est deja en entete.
  static String montantCourt(num valeur) => groupes(valeur.round());

  /// Insere une espace insecable tous les trois chiffres.
  static String groupes(int valeur) {
    final negatif = valeur < 0;
    final chiffres = valeur.abs().toString();
    final tampon = StringBuffer();

    for (var i = 0; i < chiffres.length; i++) {
      if (i > 0 && (chiffres.length - i) % 3 == 0) {
        tampon.write(' ');
      }
      tampon.write(chiffres[i]);
    }
    return negatif ? '-${tampon.toString()}' : tampon.toString();
  }

  /// Distance : « 450 m » en dessous du kilometre, « 3,2 km » au-dessus.
  ///
  /// Afficher « 0,45 km » pour quelque chose qui est a quatre cents
  /// metres oblige la personne a faire la conversion elle-meme.
  static String distance(double? km) {
    if (km == null) return '';
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    return '${km.round()} km';
  }

  /// Note sur 5 : « 4,5 ». `null` quand il n'y a pas encore d'avis — et
  /// surtout pas « 0 », qui serait un mensonge au detriment du vendeur.
  static String? note(double? valeur) {
    if (valeur == null) return null;
    return valeur.toStringAsFixed(1).replaceAll('.', ',');
  }

  /// Anciennete lisible : « a l'instant », « il y a 3 h », « le 12/11 ».
  static String depuis(DateTime? date) {
    if (date == null) return '';
    final ecart = DateTime.now().difference(date);

    if (ecart.inMinutes < 1) return "a l'instant";
    if (ecart.inMinutes < 60) return 'il y a ${ecart.inMinutes} min';
    if (ecart.inHours < 24) return 'il y a ${ecart.inHours} h';
    if (ecart.inDays == 1) return 'hier';
    if (ecart.inDays < 7) return 'il y a ${ecart.inDays} jours';

    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    // L'annee n'apparait que si elle differe : « le 12/11 » suffit pour
    // une annonce de cette annee.
    if (date.year == DateTime.now().year) return 'le $jour/$mois';
    return 'le $jour/$mois/${date.year}';
  }

  /// Quantite avec son mot au pluriel accorde.
  static String unites(int quantite) =>
      quantite <= 1 ? '$quantite unite' : '$quantite unites';
}
