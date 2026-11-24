import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/evaluation.dart';
import '../../providers/avis_providers.dart';
import 'etoiles.dart';

/// Depose ou corrige un avis.
///
/// La meme feuille sert aux deux : corriger, c'est redonner ses notes.
/// Passer `existant` bascule en correction et pre-remplit les champs.
Future<bool?> ouvrirDeposerAvis(
  BuildContext context, {
  required int venteId,
  required String titreProduit,
  required String vendeur,
  Evaluation? existant,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _Feuille(
      venteId: venteId,
      titreProduit: titreProduit,
      vendeur: vendeur,
      existant: existant,
    ),
  );
}

class _Feuille extends ConsumerStatefulWidget {
  const _Feuille({
    required this.venteId,
    required this.titreProduit,
    required this.vendeur,
    this.existant,
  });

  final int venteId;
  final String titreProduit;
  final String vendeur;
  final Evaluation? existant;

  @override
  ConsumerState<_Feuille> createState() => _FeuilleState();
}

class _FeuilleState extends ConsumerState<_Feuille> {
  late int _noteProduit;
  late int _noteVendeur;
  late final TextEditingController _commentaire;
  bool _envoi = false;

  bool get _correction => widget.existant != null;

  @override
  void initState() {
    super.initState();
    final existant = widget.existant;
    // En depot, on part de 5 : la note la plus courante, et la personne
    // n'a a toucher que ce qu'elle veut baisser.
    _noteProduit = existant?.noteProduit ?? 5;
    _noteVendeur = existant?.noteVendeur ?? 5;
    _commentaire = TextEditingController(text: existant?.commentaire ?? '');
  }

  @override
  void dispose() {
    _commentaire.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    setState(() => _envoi = true);
    final depot = ref.read(avisRepositoryProvider);

    try {
      final resultat = _correction
          ? await depot.corriger(
              widget.existant!.id,
              noteProduit: _noteProduit,
              noteVendeur: _noteVendeur,
              commentaire: _commentaire.text,
            )
          : await depot.deposer(
              venteId: widget.venteId,
              noteProduit: _noteProduit,
              noteVendeur: _noteVendeur,
              commentaire: _commentaire.text,
            );

      ref.read(mesAvisProvider.notifier).appliquer(resultat.evaluation);
      ref.invalidate(maReputationProvider);
      final produitId = resultat.evaluation.produitId;
      if (produitId != null) ref.invalidate(avisProduitProvider(produitId));

      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppFeedback.succes(
        context,
        resultat.message.isNotEmpty
            ? resultat.message
            : 'Merci, votre avis est publie.',
      );
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _envoi = false);
      // Le message du serveur nomme la cause exacte — vente non terminee,
      // delai de correction depasse, avis deja depose.
      AppFeedback.erreur(context, '$erreur');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restant = widget.existant?.tempsRestantPourCorriger;

    return Padding(
      padding: EdgeInsets.only(
        left: Espaces.ecran,
        right: Espaces.ecran,
        top: Espaces.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Espaces.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _correction ? 'Corriger mon avis' : 'Laisser un avis',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Espaces.xxs),
            Text(
              widget.titreProduit,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),

            if (restant != null) ...[
              const SizedBox(height: Espaces.sm),
              Container(
                padding: const EdgeInsets.all(Espaces.sm),
                decoration: BoxDecoration(
                  color: AppColors.alerte.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Rayons.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 16, color: AppColors.alerte),
                    const SizedBox(width: Espaces.xs),
                    Expanded(
                      child: Text(
                        'Modifiable encore ${_duree(restant)} environ. '
                        'Passe ce delai, l\'avis est definitif.',
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Deux notes distinctes, jamais fondues en une seule : c'est
            // ce qui distingue un bon produit mal vendu d'un mauvais
            // produit bien vendu.
            const SizedBox(height: Espaces.md),
            _Bloc(
              titre: 'Le produit',
              sousTitre: 'Conformite, etat, qualite',
              note: _noteProduit,
              onChange: (valeur) => setState(() => _noteProduit = valeur),
            ),
            const SizedBox(height: Espaces.sm),
            _Bloc(
              titre: 'Le vendeur',
              sousTitre: '${widget.vendeur} — accueil, exactitude, ponctualite',
              note: _noteVendeur,
              onChange: (valeur) => setState(() => _noteVendeur = valeur),
            ),

            const SizedBox(height: Espaces.md),
            TextField(
              controller: _commentaire,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Commentaire (optionnel)',
                hintText: 'Telephone conforme, vendeur ponctuel',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: Espaces.sm),
            AppButton(
              libelle: _correction ? 'Enregistrer' : 'Publier mon avis',
              icone: Icons.star_rounded,
              enChargement: _envoi,
              onPressed: _envoi ? null : _envoyer,
            ),
            const SizedBox(height: Espaces.xxs),
            Text(
              'Votre avis est public et signe de votre nom.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  static String _duree(Duration d) {
    if (d.inHours >= 24) {
      final jours = d.inDays;
      return '$jours jour${jours > 1 ? 's' : ''}';
    }
    if (d.inHours >= 1) return '${d.inHours} h';
    return '${d.inMinutes} min';
  }
}

class _Bloc extends StatelessWidget {
  const _Bloc({
    required this.titre,
    required this.sousTitre,
    required this.note,
    required this.onChange,
  });

  final String titre;
  final String sousTitre;
  final int note;
  final ValueChanged<int> onChange;

  static const _libelles = {
    1: 'Tres decu',
    2: 'Decu',
    3: 'Correct',
    4: 'Satisfait',
    5: 'Tres satisfait',
  };

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(Espaces.sm),
      decoration: BoxDecoration(
        color: sombre ? AppColors.encreSurfaceHaute : AppColors.nuage,
        borderRadius: BorderRadius.circular(Rayons.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      sousTitre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                _libelles[note] ?? '',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.or,
                ),
              ),
            ],
          ),
          const SizedBox(height: Espaces.xxs),
          Center(child: EtoilesSaisie(note: note, onChange: onChange)),
        ],
      ),
    );
  }
}
