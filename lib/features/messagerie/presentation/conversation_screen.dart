import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formats.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/etats.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/reseau_image.dart';
import '../data/conversation_socket.dart';
import '../domain/conversation.dart';
import '../providers/messagerie_providers.dart';
import 'widgets/bulle_message.dart';

/// Une conversation : historique en REST, temps reel en WebSocket.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final int conversationId;

  @override
  ConsumerState<ConversationScreen> createState() =>
      _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _champ = TextEditingController();
  final _defilement = ScrollController();
  Timer? _rythmeSaisie;
  bool _saisieSignalee = false;

  @override
  void dispose() {
    _rythmeSaisie?.cancel();
    _champ.dispose();
    _defilement.dispose();
    super.dispose();
  }

  ConversationNotifier get _notifier =>
      ref.read(conversationProvider(widget.conversationId).notifier);

  /// Signale la frappe au plus une fois toutes les 3 secondes.
  ///
  /// Envoyer une trame par caractere saturerait le canal pour un indicateur
  /// purement cosmetique.
  void _surFrappe(String texte) {
    if (texte.trim().isEmpty) {
      _rythmeSaisie?.cancel();
      if (_saisieSignalee) {
        _saisieSignalee = false;
        _notifier.signalerSaisie(enCours: false);
      }
      return;
    }

    if (!_saisieSignalee) {
      _saisieSignalee = true;
      _notifier.signalerSaisie(enCours: true);
    }

    _rythmeSaisie?.cancel();
    _rythmeSaisie = Timer(const Duration(seconds: 3), () {
      _saisieSignalee = false;
      _notifier.signalerSaisie(enCours: false);
    });
  }

  Future<void> _envoyer() async {
    final texte = _champ.text.trim();
    if (texte.isEmpty) return;

    _champ.clear();
    _rythmeSaisie?.cancel();
    _saisieSignalee = false;

    await _notifier.envoyer(texte);

    // La liste est inversee : l'offset 0 est le bas, donc le message qu'on
    // vient d'ecrire.
    if (_defilement.hasClients) {
      _defilement.animateTo(
        0,
        duration: Mouvements.rapide,
        curve: Mouvements.sortie,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(conversationProvider(widget.conversationId));
    final sombre = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _barre(context, etat, sombre),
      body: GradientBackground(
        anime: false,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              if (etat.conversation?.produit != null)
                _BandeauProduit(conversation: etat.conversation!),
              if (etat.etatCanal == EtatSocket.erreur)
                const _BandeauCanal(),
              Expanded(child: _liste(etat, sombre)),
              if (etat.interlocuteurSaisit)
                _IndicateurSaisie(
                  nom: etat.conversation?.interlocuteur?.nomAffiche ?? '',
                ),
              _composeur(etat, sombre),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- barre
  AppBar _barre(BuildContext context, EtatConversation etat, bool sombre) {
    final autre = etat.conversation?.interlocuteur;

    return AppBar(
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.emeraude, AppColors.sarcelle],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              autre?.initiales ?? '?',
              style: const TextStyle(
                color: AppColors.blanc,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: Espaces.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  autre?.nomAffiche ?? 'Conversation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _sousTitre(etat),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: etat.etatCanal == EtatSocket.ouvert
                        ? AppColors.emeraude
                        : (sombre
                            ? AppColors.texteClairDoux
                            : AppColors.texteSombreDoux),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (choix) => _surMenu(choix, etat),
          itemBuilder: (_) => [
            if (etat.conversation?.produit != null)
              const PopupMenuItem(
                value: 'produit',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text("Voir l'annonce"),
                ),
              ),
            const PopupMenuItem(
              value: 'signaler',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.flag_outlined),
                title: Text('Signaler'),
              ),
            ),
            PopupMenuItem(
              value: 'blocage',
              enabled: !(etat.conversation?.estBloquee ?? false) ||
                  (etat.conversation?.bloqueeParMoi ?? false),
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.block_rounded,
                  color: (etat.conversation?.estBloquee ?? false)
                      ? null
                      : AppColors.erreur,
                ),
                title: Text(
                  (etat.conversation?.estBloquee ?? false)
                      ? 'Debloquer'
                      : 'Bloquer',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _sousTitre(EtatConversation etat) {
    if (etat.conversation?.estBloquee ?? false) return 'Conversation bloquee';
    switch (etat.etatCanal) {
      case EtatSocket.ouvert:
        return 'En ligne';
      case EtatSocket.connexion:
        return 'Connexion...';
      case EtatSocket.erreur:
        return 'Hors ligne';
      case EtatSocket.ferme:
        return etat.conversation?.interlocuteur?.localisation ?? '';
    }
  }

  Future<void> _surMenu(String choix, EtatConversation etat) async {
    switch (choix) {
      case 'produit':
        final produit = etat.conversation?.produit;
        if (produit != null) {
          context.pushNamed(
            Routes.produit,
            pathParameters: {'id': '${produit.id}'},
            extra: {'hero': 'conversation'},
          );
        }
      case 'signaler':
        await _ouvrirSignalement();
      case 'blocage':
        await _basculerBlocage(etat);
    }
  }

  Future<void> _basculerBlocage(EtatConversation etat) async {
    final bloquee = etat.conversation?.estBloquee ?? false;

    if (!bloquee) {
      final confirme = await showDialog<bool>(
        context: context,
        builder: (contexte) => AlertDialog(
          title: const Text('Bloquer cette conversation ?'),
          content: const Text(
            'Plus aucun message ne pourra etre echange, dans les deux '
            'sens. Vous pourrez debloquer a tout moment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(contexte).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.erreur,
              ),
              onPressed: () => Navigator.of(contexte).pop(true),
              child: const Text('Bloquer'),
            ),
          ],
        ),
      );
      if (confirme != true) return;
    }

    try {
      await _notifier.basculerBlocage();
      if (!mounted) return;
      AppFeedback.succes(
        context,
        bloquee ? 'Conversation debloquee.' : 'Conversation bloquee.',
      );
    } catch (erreur) {
      if (!mounted) return;
      AppFeedback.erreur(context, '$erreur');
    }
  }

  Future<void> _ouvrirSignalement() async {
    String? motif;
    final description = TextEditingController();

    final envoye = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (contexte) => Padding(
        padding: EdgeInsets.only(
          left: Espaces.ecran,
          right: Espaces.ecran,
          top: Espaces.lg,
          bottom: MediaQuery.viewInsetsOf(contexte).bottom + Espaces.lg,
        ),
        child: StatefulBuilder(
          builder: (contexte, rafraichir) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Signaler la conversation',
                style: Theme.of(contexte).textTheme.titleMedium,
              ),
              const SizedBox(height: Espaces.xs),
              Text(
                'Un moderateur examinera le signalement. Les messages '
                'restent visibles pour lui.',
                style: Theme.of(contexte).textTheme.bodySmall,
              ),
              const SizedBox(height: Espaces.md),
              // `RadioGroup` porte la valeur et le changement pour tout
              // le groupe : depuis Flutter 3.32, les mettre sur chaque
              // `RadioListTile` est deprecie.
              RadioGroup<String>(
                groupValue: motif,
                onChanged: (valeur) => rafraichir(() => motif = valeur),
                child: Column(
                  children: motifsSignalement.entries
                      .map(
                        (entree) => RadioListTile<String>(
                          value: entree.key,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(entree.value),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: Espaces.xs),
              TextField(
                controller: description,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Details (optionnel)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: Espaces.sm),
              FilledButton(
                onPressed: motif == null
                    ? null
                    : () => Navigator.of(contexte).pop(true),
                child: const Text('Envoyer le signalement'),
              ),
            ],
          ),
        ),
      ),
    );

    if (envoye != true || motif == null) {
      description.dispose();
      return;
    }

    try {
      await _notifier.signaler(
        motif: motif!,
        description: description.text,
      );
      if (mounted) {
        AppFeedback.succes(context, 'Signalement envoye. Merci.');
      }
    } catch (erreur) {
      if (mounted) AppFeedback.erreur(context, '$erreur');
    } finally {
      description.dispose();
    }
  }

  // ------------------------------------------------------------- liste
  Widget _liste(EtatConversation etat, bool sombre) {
    if (etat.chargement && etat.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (etat.erreur != null && etat.messages.isEmpty) {
      return EtatErreur(erreur: etat.erreur!, onReessayer: _notifier.charger);
    }

    if (etat.messages.isEmpty) {
      return const EtatVide(
        icone: Icons.waving_hand_outlined,
        titre: 'Dites bonjour',
        message:
            'Presentez-vous et posez vos questions sur le produit. Le '
            'vendeur recevra une notification.',
      );
    }

    return ListView.builder(
      controller: _defilement,
      // Inversee : le dernier message est en bas, et un nouveau message
      // n'oblige a aucun calcul de position.
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        Espaces.md,
        Espaces.md,
        Espaces.md,
        Espaces.sm,
      ),
      itemCount: etat.messages.length,
      itemBuilder: (context, index) {
        final message = etat.messages[index];

        // La liste est inversee : l'element SUIVANT dans la liste est le
        // message PRECEDENT dans le temps.
        final precedent = index + 1 < etat.messages.length
            ? etat.messages[index + 1]
            : null;

        final changeDeJour = precedent == null ||
            !_memeJour(precedent.creeLe, message.creeLe);

        final bulle = BulleMessage(
          message: message,
          afficherHeure: precedent == null ||
              precedent.estDeMoi != message.estDeMoi ||
              changeDeJour,
          onReessayer: () => _notifier.reessayer(message),
        );

        if (!changeDeJour) return bulle;

        return Column(
          children: [
            bulle,
            if (message.creeLe != null)
              SeparateurJour(date: message.creeLe!.toLocal()),
          ],
        );
      },
    );
  }

  static bool _memeJour(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  // --------------------------------------------------------- composeur
  Widget _composeur(EtatConversation etat, bool sombre) {
    final conversation = etat.conversation;

    if (conversation != null && conversation.estBloquee) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Espaces.md),
        color: AppColors.erreur.withValues(alpha: 0.1),
        child: Row(
          children: [
            const Icon(Icons.block_rounded,
                size: 18, color: AppColors.erreur),
            const SizedBox(width: Espaces.xs),
            Expanded(
              child: Text(
                conversation.bloqueeParMoi
                    ? 'Vous avez bloque cette conversation. Debloquez-la '
                        'depuis le menu pour reprendre la discussion.'
                    : 'Cette personne a bloque la conversation. Vous ne '
                        'pouvez plus envoyer de message.',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Espaces.sm,
        Espaces.xs,
        Espaces.sm,
        Espaces.xs,
      ),
      decoration: BoxDecoration(
        color: sombre
            ? AppColors.encreSurface.withValues(alpha: 0.95)
            : AppColors.blanc,
        border: Border(
          top: BorderSide(
            color: sombre ? AppColors.encreBordure : AppColors.bordureClaire,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _champ,
              onChanged: _surFrappe,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Votre message...',
                counterText: '',
                filled: true,
                fillColor: sombre
                    ? AppColors.encreSurfaceHaute
                    : AppColors.nuage,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Espaces.md,
                  vertical: Espaces.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Rayons.lg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: Espaces.xs),
          _BoutonEnvoi(
            actif: !etat.envoiEnCours,
            onEnvoyer: _envoyer,
          ),
        ],
      ),
    );
  }
}

class _BoutonEnvoi extends StatelessWidget {
  const _BoutonEnvoi({required this.actif, required this.onEnvoyer});

  final bool actif;
  final VoidCallback onEnvoyer;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: actif ? 1 : 0.9,
      duration: Mouvements.rapide,
      child: Material(
        color: AppColors.emeraude,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: actif ? onEnvoyer : null,
          child: const SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              Icons.send_rounded,
              size: 19,
              color: AppColors.blanc,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rappel du produit discute, avec le prix du jour ET celui du depart.
class _BandeauProduit extends StatelessWidget {
  const _BandeauProduit({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final produit = conversation.produit!;
    final sombre = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: sombre
          ? AppColors.encreSurface.withValues(alpha: 0.85)
          : AppColors.blanc,
      child: InkWell(
        onTap: () => context.pushNamed(
          Routes.produit,
          pathParameters: {'id': '${produit.id}'},
          extra: {'hero': 'conversation'},
        ),
        child: Container(
          padding: const EdgeInsets.all(Espaces.xs),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color:
                    sombre ? AppColors.encreBordure : AppColors.bordureClaire,
              ),
            ),
          ),
          child: Row(
            children: [
              ReseauImage(
                url: produit.image,
                largeur: 42,
                hauteur: 42,
                rayon: BorderRadius.circular(Rayons.xs),
              ),
              const SizedBox(width: Espaces.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produit.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Text(
                          Formats.montant(
                            conversation.prixActuelProduit ?? produit.prix,
                            devise: produit.devise,
                          ),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emeraude,
                          ),
                        ),
                        if (conversation.prixAChange) ...[
                          const SizedBox(width: Espaces.xs),
                          Text(
                            Formats.montant(
                              conversation.prixInitial!,
                              devise: produit.devise,
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                              color: sombre
                                  ? AppColors.texteClairDoux
                                  : AppColors.texteSombreDoux,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: sombre
                    ? AppColors.texteClairDoux
                    : AppColors.texteSombreDoux,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau honnete quand le canal temps reel est tombe : les messages
/// envoyes partent quand meme (en REST), mais ceux de l'autre n'arriveront
/// qu'au prochain chargement.
class _BandeauCanal extends StatelessWidget {
  const _BandeauCanal();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.md,
        vertical: Espaces.xs,
      ),
      color: AppColors.alerte.withValues(alpha: 0.14),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 15, color: AppColors.alerte),
          SizedBox(width: Espaces.xs),
          Expanded(
            child: Text(
              'Temps reel interrompu — reconnexion en cours. Vos envois '
              'fonctionnent toujours.',
              style: TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndicateurSaisie extends StatelessWidget {
  const _IndicateurSaisie({required this.nom});

  final String nom;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(
          left: Espaces.md,
          bottom: Espaces.xs,
        ),
        child: Text(
          '$nom ecrit...',
          style: TextStyle(
            fontSize: 11.5,
            fontStyle: FontStyle.italic,
            color: sombre
                ? AppColors.texteClairDoux
                : AppColors.texteSombreDoux,
          ),
        ),
      ),
    );
  }
}
