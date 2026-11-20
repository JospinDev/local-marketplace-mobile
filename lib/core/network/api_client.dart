import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';

/// Client HTTP unique de l'application.
///
/// Il porte a lui seul la mecanique d'authentification decrite par le guide
/// d'integration :
///
/// 1. il ajoute `Authorization: Bearer <access>` sur chaque appel ;
/// 2. sur un `401`, il rafraichit le couple de jetons **une seule fois**,
///    rejoue la requete, et deconnecte si le rafraichissement echoue ;
/// 3. il ECRASE le jeton de rafraichissement, que le serveur fait tourner.
///
/// Le point delicat est la concurrence : quand l'ecran d'accueil lance cinq
/// requetes en parallele et que le jeton vient d'expirer, les cinq recoivent
/// `401` en meme temps. Sans precaution, elles declenchent cinq
/// rafraichissements, dont quatre echouent — la rotation ayant invalide le
/// refresh des le premier. Un `Completer` partage fait donc attendre les
/// autres au meme rafraichissement.
class ApiClient {
  ApiClient({required TokenStore jetons, Dio? dio})
      : _jetons = jetons,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = AppConfig.baseUrl
      ..connectTimeout = AppConfig.delaiConnexion
      ..receiveTimeout = AppConfig.delaiReception
      ..responseType = ResponseType.json
      ..headers = {'Accept': 'application/json'}
      // On valide tout : c'est notre intercepteur qui decide ce qui est
      // une erreur, pour que chaque echec passe par le meme decodeur.
      ..validateStatus = (_) => true;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _surRequete,
        onResponse: _surReponse,
        onError: _surErreur,
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: false,
          responseHeader: false,
          logPrint: (objet) => debugPrint('[api] $objet'),
        ),
      );
    }
  }

  final Dio _dio;
  final TokenStore _jetons;

  /// Appele quand la session est definitivement perdue : la couche
  /// superieure vide l'etat et renvoie vers l'ecran de connexion.
  void Function()? surSessionPerdue;

  /// Rafraichissement en cours, partage par toutes les requetes en attente.
  Completer<bool>? _rafraichissementEnCours;

  Dio get dio => _dio;

  // ------------------------------------------------------ intercepteurs
  void _surRequete(RequestOptions options, RequestInterceptorHandler suite) {
    final libre = options.extra['sansJeton'] == true;
    final acces = _jetons.acces;
    if (!libre && acces != null && acces.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $acces';
    }
    suite.next(options);
  }

  Future<void> _surReponse(
    Response<dynamic> reponse,
    ResponseInterceptorHandler suite,
  ) async {
    final code = reponse.statusCode ?? 0;

    if (code >= 200 && code < 300) {
      suite.next(reponse);
      return;
    }

    // 401 sur une route authentifiee : on tente le rafraichissement.
    final dejaRejoue = reponse.requestOptions.extra['dejaRejoue'] == true;
    final libre = reponse.requestOptions.extra['sansJeton'] == true;

    if (code == 401 && !dejaRejoue && !libre && _jetons.aUneSession) {
      final reussi = await _rafraichir();
      if (reussi) {
        try {
          final rejouee = await _rejouer(reponse.requestOptions);
          suite.resolve(rejouee);
          return;
        } catch (_) {
          // On retombe sur l'erreur d'origine ci-dessous.
        }
      } else {
        surSessionPerdue?.call();
      }
    }

    suite.reject(
      DioException(
        requestOptions: reponse.requestOptions,
        response: reponse,
        type: DioExceptionType.badResponse,
      ),
    );
  }

  void _surErreur(DioException erreur, ErrorInterceptorHandler suite) {
    suite.reject(erreur);
  }

  /// Rafraichit les jetons. Retourne `false` si la session est perdue.
  Future<bool> _rafraichir() {
    // Un rafraichissement est deja en route : on attend le meme resultat,
    // au lieu d'en declencher un second qui echouerait.
    final enCours = _rafraichissementEnCours;
    if (enCours != null) return enCours.future;

    final completer = Completer<bool>();
    _rafraichissementEnCours = completer;

    () async {
      try {
        final refresh = _jetons.rafraichissement;
        if (refresh == null || refresh.isEmpty) {
          completer.complete(false);
          return;
        }

        final reponse = await _dio.post<dynamic>(
          '/auth/token/refresh/',
          data: {'refresh': refresh},
          options: Options(extra: {'sansJeton': true, 'dejaRejoue': true}),
        );

        final corps = reponse.data;
        final code = reponse.statusCode ?? 0;
        if (code < 200 || code >= 300 || corps is! Map) {
          await _jetons.vider();
          completer.complete(false);
          return;
        }

        final acces = corps['access'] as String?;
        // Le serveur fait tourner le refresh : on prend le nouveau s'il
        // est la, sinon on garde l'ancien.
        final nouveauRefresh = corps['refresh'] as String? ?? refresh;

        if (acces == null || acces.isEmpty) {
          await _jetons.vider();
          completer.complete(false);
          return;
        }

        await _jetons.enregistrer(
          acces: acces,
          rafraichissement: nouveauRefresh,
        );
        completer.complete(true);
      } catch (_) {
        await _jetons.vider();
        completer.complete(false);
      } finally {
        _rafraichissementEnCours = null;
      }
    }();

    return completer.future;
  }

  Future<Response<dynamic>> _rejouer(RequestOptions origine) {
    return _dio.fetch<dynamic>(
      origine..extra = {...origine.extra, 'dejaRejoue': true},
    );
  }

  // ------------------------------------------------------------- verbes
  Future<dynamic> get(
    String chemin, {
    Map<String, dynamic>? parametres,
    bool sansJeton = false,
  }) =>
      _appeler(
        () => _dio.get<dynamic>(
          chemin,
          queryParameters: _nettoyer(parametres),
          options: Options(extra: {'sansJeton': sansJeton}),
        ),
      );

  Future<dynamic> post(
    String chemin, {
    Object? corps,
    bool sansJeton = false,
  }) =>
      _appeler(
        () => _dio.post<dynamic>(
          chemin,
          data: corps,
          options: Options(extra: {'sansJeton': sansJeton}),
        ),
      );

  Future<dynamic> patch(String chemin, {Object? corps}) => _appeler(
        () => _dio.patch<dynamic>(chemin, data: corps),
      );

  Future<dynamic> put(String chemin, {Object? corps}) => _appeler(
        () => _dio.put<dynamic>(chemin, data: corps),
      );

  Future<dynamic> delete(String chemin, {Object? corps}) => _appeler(
        () => _dio.delete<dynamic>(chemin, data: corps),
      );

  /// Envoi multipart (photo de profil, images d'annonce).
  Future<dynamic> envoyerFichiers(
    String chemin,
    FormData formulaire, {
    String methode = 'PATCH',
  }) =>
      _appeler(
        () => _dio.request<dynamic>(
          chemin,
          data: formulaire,
          options: Options(method: methode),
        ),
      );

  /// Point de passage unique : toute erreur devient une [ApiException].
  Future<dynamic> _appeler(Future<Response<dynamic>> Function() action) async {
    try {
      final reponse = await action();
      return reponse.data;
    } on DioException catch (erreur) {
      throw ApiException.depuisDio(erreur);
    } catch (erreur) {
      throw ApiException(
        message: "Une erreur inattendue s'est produite. ($erreur)",
        statusCode: 0,
      );
    }
  }

  /// Retire les parametres vides : `?titre=` filtrerait sur une chaine
  /// vide cote serveur au lieu de ne pas filtrer du tout.
  Map<String, dynamic>? _nettoyer(Map<String, dynamic>? parametres) {
    if (parametres == null) return null;
    final propre = <String, dynamic>{};
    parametres.forEach((cle, valeur) {
      if (valeur == null) return;
      if (valeur is String && valeur.trim().isEmpty) return;
      propre[cle] = valeur;
    });
    return propre.isEmpty ? null : propre;
  }
}
