import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Coffre des jetons JWT.
///
/// Les jetons vont dans le trousseau du systeme (Keychain sur iOS,
/// EncryptedSharedPreferences sur Android), jamais dans les preferences en
/// clair : le guide d'integration en fait une regle, et un jeton vole donne
/// un acces complet au compte pendant quinze jours.
///
/// Les lectures passent par un cache memoire : l'intercepteur reseau lit le
/// jeton a CHAQUE requete, et une lecture de trousseau coute quelques
/// millisecondes qu'il est inutile de payer a chaque fois.
class TokenStore {
  TokenStore({FlutterSecureStorage? coffre})
      : _coffre = coffre ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _coffre;

  static const _cleAcces = 'jeton_acces';
  static const _cleRafraichissement = 'jeton_rafraichissement';

  String? _accesEnMemoire;
  String? _rafraichissementEnMemoire;
  bool _charge = false;

  /// Relit le trousseau une seule fois, au demarrage.
  Future<void> initialiser() async {
    if (_charge) return;
    try {
      _accesEnMemoire = await _coffre.read(key: _cleAcces);
      _rafraichissementEnMemoire = await _coffre.read(key: _cleRafraichissement);
    } catch (_) {
      // Trousseau indisponible (premiere installation, appareil verrouille) :
      // on repart simplement d'une session vide plutot que de planter.
      _accesEnMemoire = null;
      _rafraichissementEnMemoire = null;
    }
    _charge = true;
  }

  String? get acces => _accesEnMemoire;
  String? get rafraichissement => _rafraichissementEnMemoire;
  bool get aUneSession => (_rafraichissementEnMemoire ?? '').isNotEmpty;

  /// Enregistre le couple de jetons.
  ///
  /// Le serveur fait tourner le jeton de rafraichissement et met l'ancien
  /// en liste noire : il faut donc ECRASER le refresh a chaque appel, sinon
  /// le suivant sera rejete. C'est le piege numero un du guide.
  Future<void> enregistrer({
    required String acces,
    required String rafraichissement,
  }) async {
    _accesEnMemoire = acces;
    _rafraichissementEnMemoire = rafraichissement;
    _charge = true;
    await Future.wait([
      _coffre.write(key: _cleAcces, value: acces),
      _coffre.write(key: _cleRafraichissement, value: rafraichissement),
    ]);
  }

  /// Met a jour le seul jeton d'acces (apres un rafraichissement qui
  /// n'aurait pas renvoye de nouveau refresh).
  Future<void> majAcces(String acces) async {
    _accesEnMemoire = acces;
    await _coffre.write(key: _cleAcces, value: acces);
  }

  Future<void> vider() async {
    _accesEnMemoire = null;
    _rafraichissementEnMemoire = null;
    await Future.wait([
      _coffre.delete(key: _cleAcces),
      _coffre.delete(key: _cleRafraichissement),
    ]);
  }
}
