# Marketplace Burundi — application mobile

Application Flutter du marketplace local multi-vendeurs.
**Dépôt séparé** de celui de l'API : les deux évoluent à leur rythme, et le
mobile ne dépend jamais du code source du backend — seulement de son contrat
HTTP.

- Backend : Django REST Framework, 14 modules, 117 endpoints
- Contrat suivi : `backend/docs/GUIDE_FLUTTER.md` du dépôt de l'API
- Swagger : <http://127.0.0.1:8000/api/docs/>

---

## État d'avancement

| Étape du guide | Écran | Statut |
| -------------- | ----- | ------ |
| 0 | Fondations : client HTTP, thème, animations | ✅ livré |
| 1 | Authentification complète | ✅ livré |
| 2 | Mon compte (profil + vitrine) | ✅ livré |
| 3 | Catalogue public, recherche, fiche produit | ✅ livré |
| 4 | Mes annonces, stock, images | ✅ livré |
| 5 | Favoris et vendeurs suivis | ✅ livré |
| 6 | Messagerie temps réel (WebSocket) | ✅ livré |
| — | Boutique publique d'un vendeur | ✅ livré |
| 7 | Réservations (demander, accepter, partiel) | ✅ livré |
| 8 | Ventes et double accusé | ✅ livré |
| 11 | Notifications (centre + temps réel) | ✅ livré |
| — | Bandeau publicitaire administré | ✅ livré |
| — | Menu latéral + flux infini de l'accueil | ✅ livré |
| 9–10 | Avis, tableau de bord vendeur | ⏳ à venir |

---

## Démarrage

```bash
flutter pub get

# L'émulateur Android ne voit pas 127.0.0.1 : l'adresse par défaut est
# déjà 10.0.2.2, il n'y a rien à faire.
flutter run

# Téléphone physique : viser l'IP de la machine sur le réseau local.
flutter run --dart-define=API_BASE_URL=http://192.168.1.12:8000

# Navigateur, pour un aperçu rapide sans émulateur.
flutter run -d chrome
```

Le backend doit tourner en parallèle :

```bash
cd ../mrk-lo/backend && python manage.py runserver
```

### Comptes de démonstration

| Identifiant | Mot de passe | Pour tester |
| ----------- | ------------ | ----------- |
| `vendeur_demo` | `Vendeur@2026` | le parcours vendeur |
| `acheteur_demo` | `Acheteur@2026` | le parcours acheteur |

---

## Architecture

```text
lib/
├── main.dart              point d'entrée : trousseau lu avant le 1er rendu
├── app.dart               MaterialApp.router + thèmes
│
├── core/                  tout ce qui est partagé
│   ├── config/            adresse du serveur, délais
│   ├── network/           client HTTP, intercepteur JWT, erreurs
│   ├── storage/           coffre à jetons (trousseau système)
│   ├── routing/           go_router + redirections d'authentification
│   ├── theme/             couleurs, typographie, espaces, mouvements
│   ├── utils/             validateurs
│   ├── widgets/           boutons, champs, cartes, fond animé, logo
│   └── providers.dart     fournisseurs partagés (un seul client HTTP)
│
└── features/
    ├── auth/              module 1 : data / domain / providers / presentation
    ├── account/           module 2
    ├── home/              accueil
    └── shell/             coquille à onglets
```

Chaque module suit le même découpage : `data` (appels API), `domain`
(modèles), `providers` (état), `presentation` (écrans). Aucun écran n'appelle
l'API directement.

---

## Les trois décisions qui structurent le code

### 1. Un seul client HTTP, un seul rafraîchissement

L'intercepteur ajoute le jeton, et sur un `401` il rafraîchit **une seule
fois** avant de rejouer la requête.

Le piège qu'il fallait traiter : quand l'accueil lance cinq requêtes en
parallèle et que le jeton vient d'expirer, les cinq reçoivent `401` en même
temps. Sans précaution, cela déclenche cinq rafraîchissements dont quatre
échouent — la rotation côté serveur ayant invalidé le refresh dès le premier.
Un `Completer` partagé fait donc attendre les autres au même
rafraîchissement.

Et le refresh est **écrasé** à chaque fois : le serveur le fait tourner, et
garder l'ancien déconnecte l'utilisateur au bout d'une heure.

### 2. Les redirections vivent dans le routeur, pas dans les écrans

Aucun écran n'appelle `Navigator.pushReplacement` après une connexion : le
routeur observe la phase d'authentification et redirige. C'est ce qui permet
de garder le catalogue ouvert aux visiteurs — seuls le démarrage et les
écrans d'authentification sont protégés.

### 3. Une seule enveloppe d'erreur

Le backend renvoie toujours la même forme. `ApiException` la décode une fois,
et les écrans se contentent de placer `erreursChamps['username']` sous le bon
champ. Le message du serveur est affiché **tel quel** : il est déjà rédigé
pour la personne, et le réécrire côté mobile ferait deux vérités à maintenir.

---

## Le système de design

L'identité ne copie aucune maquette : elle part des couleurs du Burundi — le
vert du drapeau devient un **émeraude** profond, accompagné d'une **sarcelle**
et d'un **or** chaud pour les prix. Le rouge est réservé aux erreurs, pour
qu'il garde sa force de signal.

| Élément | Choix | Pourquoi |
| ------- | ----- | -------- |
| Police | Plus Jakarta Sans | ses chiffres sont tabulaires : les colonnes de prix restent alignées |
| Espaces | multiples de 4 | une interface « tombe juste » sans qu'on sache dire pourquoi |
| Durées | 120–340 ms | au-delà, l'animation devient une attente |
| Fond | deux halos peints, 18 s par tour | s'adapte à tout écran, suit le thème, ne pixellise jamais |
| Ombres | larges et transparentes | une ombre serrée fait « autocollant », une ombre large fait « matériau » |

### Les animations, et à quoi elles servent

Aucune n'est décorative :

- **l'écran de démarrage** dessine le logo pendant qu'on relit le trousseau et
  qu'on appelle `/me/` — l'animation occupe exactement le temps réseau, avec
  un plancher de 1,4 s pour éviter le clignotement ;
- **les boutons** se contractent à 96 % à l'appui, avec vibration : la
  sensation d'objet physique, et une confirmation même quand le doigt masque
  l'écran ;
- **les champs** tremblent une fois à l'erreur — le mouvement est perçu avant
  que le texte ne soit lu ;
- **la barre d'onglets** fait *glisser* sa pastille lumineuse, et le libellé
  n'apparaît que sur l'onglet actif ;
- **les formulaires** entrent en cascade (`fadeIn().slideY()` décalés de
  60 ms), ce qui guide l'œil de haut en bas dans l'ordre de saisie.

Le réglage système « réduire les animations » est respecté : le fond cesse de
dériver.

---

## Qualité

```bash
flutter analyze        # doit rendre : No issues found!
flutter build apk --release
```

`analysis_options.yaml` active quelques règles au-delà du jeu par défaut et
en désactive **une seule**, avec sa raison écrite dans le fichier.

---

## Avant la mise en production

- [ ] Remplacer l'icône et le nom d'application par défaut
- [ ] Déclarer l'origine de production côté backend (`CORS_ALLOWED_ORIGINS`)
- [ ] Configurer Firebase si les notifications push sont souhaitées —
      **compte de service**, pas de clé serveur : l'ancienne API FCM a été
      désactivée par Google en 2024 (l'application fonctionne sans :
      l'historique et le temps réel suffisent)
- [ ] Signer l'APK (`android/key.properties`, jamais versionné)
