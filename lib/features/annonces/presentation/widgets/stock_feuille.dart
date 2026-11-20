import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formats.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../catalogue/domain/produit.dart';
import '../../data/annonces_repository.dart';
import '../../providers/annonces_providers.dart';

/// Gestion du stock d'une annonce.
///
/// La regle du cahier des charges est montree a l'ecran, pas seulement
/// appliquee en silence :
///
/// ```
/// disponible = totale - reservee - vendue
/// ```
///
/// Le vendeur ne modifie QUE la quantite totale. Les deux autres sont en
/// lecture seule — elles appartiennent aux reservations et aux ventes. Et
/// le serveur refuse de descendre sous ce qui est deja engage : la
/// feuille le dit avant la tentative, plutot que de laisser decouvrir
/// l'erreur apres coup.
class StockFeuille extends ConsumerStatefulWidget {
  const StockFeuille({super.key, required this.annonce});

  final Produit annonce;

  @override
  ConsumerState<StockFeuille> createState() => _StockFeuilleState();
}

class _StockFeuilleState extends ConsumerState<StockFeuille> {
  final _quantite = TextEditingController();
  bool _enCours = false;
  String? _erreurChamp;

  @override
  void dispose() {
    _quantite.dispose();
    super.dispose();
  }

  Future<void> _enregistrer(Stock stock) async {
    final saisie = int.tryParse(_quantite.text.trim());
    if (saisie == null) {
      setState(() => _erreurChamp = 'Entrez un nombre.');
      return;
    }
    if (saisie < stock.engagee) {
      setState(
        () => _erreurChamp =
            'Au minimum ${stock.engagee} : ${stock.quantiteReservee} '
            'reserve(s) et ${stock.quantiteVendue} vendu(s).',
      );
      return;
    }

    setState(() {
      _enCours = true;
      _erreurChamp = null;
    });

    try {
      await ref
          .read(annoncesRepositoryProvider)
          .majStock(widget.annonce.id, saisie);
      ref.invalidate(stockProvider(widget.annonce.id));
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.succes(context, 'Stock mis a jour.');
    } on ApiException catch (erreur) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreurChamp = erreur.champ('quantite_totale');
      });
      if (_erreurChamp == null) {
        AppFeedback.erreur(context, erreur.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stock = ref.watch(stockProvider(widget.annonce.id));
    final clavier = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: clavier),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Espaces.ecran,
          0,
          Espaces.ecran,
          Espaces.xl,
        ),
        child: stock.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Espaces.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (erreur, _) => Padding(
            padding: const EdgeInsets.all(Espaces.xl),
            child: Text(
              erreur is ApiException
                  ? erreur.message
                  : 'Stock indisponible.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          data: (donnees) {
            if (_quantite.text.isEmpty) {
              _quantite.text = '${donnees.quantiteTotale}';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Gerer le stock', style: theme.textTheme.titleLarge),
                Text(
                  widget.annonce.titre,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Espaces.lg),

                // L'equation, rendue visible.
                SolidCard(
                  child: Row(
                    children: [
                      _Chiffre(
                        valeur: donnees.quantiteTotale,
                        libelle: 'Total',
                        couleur: AppColors.texteSombreDoux,
                      ),
                      const _Signe('−'),
                      _Chiffre(
                        valeur: donnees.quantiteReservee,
                        libelle: 'Reserve',
                        couleur: AppColors.alerte,
                      ),
                      const _Signe('−'),
                      _Chiffre(
                        valeur: donnees.quantiteVendue,
                        libelle: 'Vendu',
                        couleur: AppColors.info,
                      ),
                      const _Signe('='),
                      _Chiffre(
                        valeur: donnees.quantiteDisponible,
                        libelle: 'Dispo',
                        couleur: AppColors.emeraude,
                        gras: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: Espaces.md),

                Container(
                  padding: const EdgeInsets.all(Espaces.sm),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: Rayons.champ,
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 17,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: Espaces.xs),
                      Expanded(
                        child: Text(
                          'Vous ne declarez que la quantite TOTALE. Les '
                          'quantites reservee et vendue sont pilotees par '
                          'les reservations et les ventes.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: Espaces.lg),

                Text(
                  'Quantite totale',
                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
                ),
                const SizedBox(height: Espaces.xs),
                _Compteur(
                  controleur: _quantite,
                  minimum: donnees.engagee,
                  actif: !_enCours,
                  onChange: () {
                    if (_erreurChamp != null) {
                      setState(() => _erreurChamp = null);
                    }
                  },
                ),

                if (_erreurChamp != null) ...[
                  const SizedBox(height: Espaces.xs),
                  Text(
                    _erreurChamp!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.erreur,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                if (donnees.engagee > 0) ...[
                  const SizedBox(height: Espaces.xs),
                  Text(
                    'Minimum ${donnees.engagee} : vous ne pouvez pas '
                    'descendre sous ce qui est deja engage.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],

                if (donnees.valeurStock != null) ...[
                  const SizedBox(height: Espaces.md),
                  Row(
                    children: [
                      Text(
                        'Valeur du stock disponible',
                        style: theme.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        Formats.montant(donnees.valeurStock!),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.emeraude,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: Espaces.xl),
                AppButton(
                  libelle: 'Enregistrer',
                  icone: Icons.check_rounded,
                  enChargement: _enCours,
                  onPressed: () => _enregistrer(donnees),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Champ numerique avec boutons − et +.
///
/// Sur un telephone, ajuster un stock d'une unite au clavier numerique
/// demande trois gestes ; deux boutons en demandent un.
class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.controleur,
    required this.minimum,
    required this.actif,
    required this.onChange,
  });

  final TextEditingController controleur;
  final int minimum;
  final bool actif;
  final VoidCallback onChange;

  void _ajuster(int delta) {
    final courant = int.tryParse(controleur.text.trim()) ?? minimum;
    final nouveau = (courant + delta).clamp(minimum, 999999);
    controleur.text = '$nouveau';
    HapticFeedback.selectionClick();
    onChange();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sombre = theme.brightness == Brightness.dark;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: sombre ? AppColors.encreSurface : AppColors.blanc,
        borderRadius: Rayons.champ,
        border: Border.all(
          color: sombre ? AppColors.encreBordure : AppColors.bordureClaire,
        ),
      ),
      child: Row(
        children: [
          _BoutonCompteur(
            icone: Icons.remove_rounded,
            onTap: actif ? () => _ajuster(-1) : null,
          ),
          Expanded(
            child: TextField(
              controller: controleur,
              enabled: actif,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => onChange(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          _BoutonCompteur(
            icone: Icons.add_rounded,
            onTap: actif ? () => _ajuster(1) : null,
          ),
        ],
      ),
    );
  }
}

class _BoutonCompteur extends StatelessWidget {
  const _BoutonCompteur({required this.icone, this.onTap});

  final IconData icone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Rayons.champ,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(
            icone,
            size: 21,
            color: onTap == null
                ? Theme.of(context).disabledColor
                : AppColors.emeraude,
          ),
        ),
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({
    required this.valeur,
    required this.libelle,
    required this.couleur,
    this.gras = false,
  });

  final int valeur;
  final String libelle;
  final Color couleur;
  final bool gras;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$valeur',
            style: (gras
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.titleMedium)
                ?.copyWith(color: couleur, fontWeight: FontWeight.w800),
          ),
          Text(
            libelle,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _Signe extends StatelessWidget {
  const _Signe(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        texte,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
      ),
    );
  }
}
