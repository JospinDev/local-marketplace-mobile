import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formats.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../reservations/domain/reservation.dart';
import '../../../reservations/providers/reservations_providers.dart';
import '../../domain/vente.dart';
import '../../providers/ventes_providers.dart';

/// Enregistre la vente d'une reservation confirmee.
///
/// La **vente partielle** est le scenario central : le client avait reserve
/// 3 pantalons et n'en prend que 2. Le serveur enregistre la vente de 2,
/// libere les 3 unites reservees, en passe 2 en vendues et rend la
/// troisieme disponible — le tout dans une seule transaction.
Future<bool?> ouvrirEnregistrerVente(
  BuildContext context, {
  required Reservation reservation,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _Feuille(reservation: reservation),
  );
}

class _Feuille extends ConsumerStatefulWidget {
  const _Feuille({required this.reservation});

  final Reservation reservation;

  @override
  ConsumerState<_Feuille> createState() => _FeuilleState();
}

class _FeuilleState extends ConsumerState<_Feuille> {
  late int _quantite;
  late final TextEditingController _prix;
  final _note = TextEditingController();
  MoyenPaiement _moyen = MoyenPaiement.cash;
  bool _envoi = false;

  int get _reservee => widget.reservation.quantiteConfirmee;

  @override
  void initState() {
    super.initState();
    _quantite = _reservee > 0 ? _reservee : 1;
    final prixAnnonce = widget.reservation.produit?.prix;
    _prix = TextEditingController(
      text: prixAnnonce == null ? '' : prixAnnonce.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _prix.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _prixSaisi {
    final texte = _prix.text.trim().replaceAll(' ', '');
    if (texte.isEmpty) return null;
    return double.tryParse(texte.replaceAll(',', '.'));
  }

  Future<void> _enregistrer() async {
    final prix = _prixSaisi;
    if (_prix.text.trim().isNotEmpty && (prix == null || prix <= 0)) {
      AppFeedback.erreur(context, 'Le prix unitaire est invalide.');
      return;
    }

    setState(() => _envoi = true);
    try {
      final resultat =
          await ref.read(ventesRepositoryProvider).depuisReservation(
                widget.reservation.id,
                // Sans ecart, on n'envoie rien : le serveur vend alors
                // toute la quantite reservee.
                quantite: _quantite == _reservee ? null : _quantite,
                prixUnitaire: prix,
                moyenPaiement: _moyen,
                note: _note.text,
              );

      ref.read(mesVentesProvider.notifier).appliquer(resultat.vente);
      ref.invalidate(revenusProvider);

      // Le serveur renvoie la reservation mise a jour dans la meme
      // reponse : on la propage sans seconde requete.
      final reservation = resultat.reservation;
      if (reservation != null) {
        ref.read(demandesRecuesProvider.notifier).appliquer(reservation);
        ref.read(mesDemandesProvider.notifier).appliquer(reservation);
      }
      ref.invalidate(resumeReservationsProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppFeedback.succes(
        context,
        resultat.message.isNotEmpty
            ? resultat.message
            : 'Vente enregistree.',
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
    final devise = widget.reservation.produit?.devise ?? 'BIF';
    final prix = _prixSaisi ?? widget.reservation.produit?.prix ?? 0;
    final liberees = _reservee - _quantite;

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
            Text('Enregistrer la vente', style: theme.textTheme.titleMedium),
            const SizedBox(height: Espaces.xxs),
            Text(
              widget.reservation.produit?.titre ?? 'Annonce',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: Espaces.md),
            Row(
              children: [
                Text('Quantite vendue', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '$_reservee reservee${_reservee > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: Espaces.xs),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.encreSurfaceHaute
                    : AppColors.nuage,
                borderRadius: BorderRadius.circular(Rayons.sm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _quantite > 1
                        ? () => setState(() => _quantite--)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Text(
                    '$_quantite',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: _quantite < _reservee
                        ? () => setState(() => _quantite++)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),

            if (liberees > 0) ...[
              const SizedBox(height: Espaces.xs),
              Container(
                padding: const EdgeInsets.all(Espaces.sm),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Rayons.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.call_split_rounded,
                        size: 17, color: AppColors.info),
                    const SizedBox(width: Espaces.xs),
                    Expanded(
                      child: Text(
                        'Vente partielle : $liberees unite'
                        '${liberees > 1 ? 's' : ''} '
                        '${liberees > 1 ? 'redeviendront' : 'redeviendra'} '
                        'disponible${liberees > 1 ? 's' : ''} pour les '
                        'autres acheteurs.',
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: Espaces.md),
            TextField(
              controller: _prix,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Prix unitaire ($devise)',
                helperText: 'Laissez le prix de l\'annonce, ou corrigez-le '
                    'si vous avez negocie. Il sera fige sur cette vente.',
                helperMaxLines: 3,
              ),
            ),

            const SizedBox(height: Espaces.md),
            Text('Moyen de paiement', style: theme.textTheme.titleSmall),
            const SizedBox(height: Espaces.xxs),
            // L'avertissement compte : sans lui, l'utilisateur croira a un
            // paiement en ligne.
            Text(
              'Declaratif : l\'application n\'encaisse rien et ne verifie '
              'aucun transfert.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
            ),
            const SizedBox(height: Espaces.xs),
            Wrap(
              spacing: Espaces.xs,
              runSpacing: Espaces.xxs,
              children: [
                for (final moyen in MoyenPaiement.values)
                  ChoiceChip(
                    label: Text(moyen.libelle),
                    selected: _moyen == moyen,
                    onSelected: (_) => setState(() => _moyen = moyen),
                    selectedColor: AppColors.emeraude.withValues(alpha: 0.18),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: _moyen == moyen
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _moyen == moyen ? AppColors.emeraude : null,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: Espaces.md),
            TextField(
              controller: _note,
              maxLines: 2,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note interne (optionnel)',
              ),
            ),

            const SizedBox(height: Espaces.xs),
            Row(
              children: [
                Text('Total de la vente', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  Formats.montant(prix * _quantite, devise: devise),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emeraude,
                  ),
                ),
              ],
            ),

            const SizedBox(height: Espaces.md),
            AppButton(
              libelle: 'Enregistrer la vente',
              icone: Icons.point_of_sale_rounded,
              enChargement: _envoi,
              onPressed: _envoi ? null : _enregistrer,
            ),
            const SizedBox(height: Espaces.xxs),
            Text(
              'La vente sera « declaree ». Confirmez ensuite le paiement '
              'recu, puis l\'acheteur confirmera la reception.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}
