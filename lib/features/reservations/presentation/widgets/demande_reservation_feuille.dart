import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formats.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../providers/reservations_providers.dart';

/// Feuille de demande de reservation, ouverte depuis une fiche produit.
///
/// Le texte est explicite sur le point que le cahier des charges insiste :
/// une demande **n'immobilise rien**. Si l'interface disait « reserve »,
/// l'acheteur croirait le produit garde pour lui alors qu'un autre peut
/// encore l'acheter.
Future<bool?> ouvrirDemandeReservation(
  BuildContext context, {
  required int produitId,
  required String titreProduit,
  required double prix,
  required String devise,
  required int quantiteDisponible,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _Feuille(
      produitId: produitId,
      titreProduit: titreProduit,
      prix: prix,
      devise: devise,
      quantiteDisponible: quantiteDisponible,
    ),
  );
}

class _Feuille extends ConsumerStatefulWidget {
  const _Feuille({
    required this.produitId,
    required this.titreProduit,
    required this.prix,
    required this.devise,
    required this.quantiteDisponible,
  });

  final int produitId;
  final String titreProduit;
  final double prix;
  final String devise;
  final int quantiteDisponible;

  @override
  ConsumerState<_Feuille> createState() => _FeuilleState();
}

class _FeuilleState extends ConsumerState<_Feuille> {
  final _message = TextEditingController();
  int _quantite = 1;
  bool _envoi = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  int get _maximum =>
      widget.quantiteDisponible > 0 ? widget.quantiteDisponible : 1;

  Future<void> _envoyer() async {
    setState(() => _envoi = true);
    try {
      final resultat =
          await ref.read(reservationsRepositoryProvider).demander(
                produitId: widget.produitId,
                quantite: _quantite,
                message: _message.text,
              );

      ref.read(mesDemandesProvider.notifier).appliquer(resultat.reservation);
      ref.invalidate(resumeReservationsProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      // Le message vient du serveur : il est plus precis que tout ce
      // qu'on pourrait rediger ici.
      AppFeedback.succes(
        context,
        resultat.message.isNotEmpty
            ? resultat.message
            : 'Demande envoyee au vendeur.',
      );
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _envoi = false);
      AppFeedback.erreur(context, '$erreur');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.prix * _quantite;

    return Padding(
      padding: EdgeInsets.only(
        left: Espaces.ecran,
        right: Espaces.ecran,
        top: Espaces.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Espaces.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Demander une reservation', style: theme.textTheme.titleMedium),
          const SizedBox(height: Espaces.xxs),
          Text(
            widget.titreProduit,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Espaces.md),

          // L'avertissement est le coeur de cet ecran, pas un detail.
          Container(
            padding: const EdgeInsets.all(Espaces.sm),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Rayons.sm),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 17, color: AppColors.info),
                SizedBox(width: Espaces.xs),
                Expanded(
                  child: Text(
                    "Votre demande n'immobilise pas encore le stock. La "
                    'quantite est mise de cote seulement quand le vendeur '
                    'accepte.',
                    style: TextStyle(fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Espaces.md),
          Row(
            children: [
              Text('Quantite', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '${widget.quantiteDisponible} disponible'
                '${widget.quantiteDisponible > 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: Espaces.xs),
          _Compteur(
            valeur: _quantite,
            minimum: 1,
            maximum: _maximum,
            onChange: (valeur) => setState(() => _quantite = valeur),
          ),

          const SizedBox(height: Espaces.md),
          TextField(
            controller: _message,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Message au vendeur (optionnel)',
              hintText: 'Je passe demain matin vers 9 h',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: Espaces.xs),
          Row(
            children: [
              Text('Valeur indicative', style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(
                Formats.montant(total, devise: widget.devise),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.emeraude,
                ),
              ),
            ],
          ),
          Text(
            'Au prix du jour. Ce montant n\'est pas un engagement de paiement.',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
          ),

          const SizedBox(height: Espaces.md),
          AppButton(
            libelle: 'Envoyer la demande',
            icone: Icons.send_rounded,
            enChargement: _envoi,
            onPressed: _envoi ? null : _envoyer,
          ),
        ],
      ),
    );
  }
}

/// Compteur borne : on ne peut pas demander plus que le disponible, le
/// serveur refuserait de toute facon.
class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.valeur,
    required this.minimum,
    required this.maximum,
    required this.onChange,
  });

  final int valeur;
  final int minimum;
  final int maximum;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: sombre ? AppColors.encreSurfaceHaute : AppColors.nuage,
        borderRadius: BorderRadius.circular(Rayons.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed:
                valeur > minimum ? () => onChange(valeur - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Text(
            '$valeur',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          IconButton(
            onPressed:
                valeur < maximum ? () => onChange(valeur + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
