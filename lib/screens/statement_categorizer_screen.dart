import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_format.dart';
import '../models/movement_category.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import 'widgets/category_form_dialog.dart';
import 'widgets/cloud_sync_badge.dart';

class StatementCategorizerScreen extends StatefulWidget {
  final FinanceProvider provider;

  const StatementCategorizerScreen({super.key, required this.provider});

  @override
  State<StatementCategorizerScreen> createState() =>
      _StatementCategorizerScreenState();
}

class _StatementCategorizerScreenState
    extends State<StatementCategorizerScreen> {
  bool _rememberKeyword = true;
  bool _isRunningAuto = false;
  int? _lastAutoClassifiedCount;
  late final Set<String> _sessionTxIds;
  final Map<String, TextEditingController> _keywordControllers = {};
  final Set<String> _skipKeywordGroups = {};
  final Map<String, String> _assignedCategoryByGroup = {};
  final Map<String, String> _assignedKeywordByGroup = {};

  static const Set<String> _aggregatorPrefixes = {
    'ztl',
    'clip',
    'dlo',
    'bpk',
    'cvz',
    'pao',
    'ccp',
    'cag',
    'merpago',
    'mp',
    'pay',
    'paypal',
    'opm',
    'bli',
    'tpt',
    'mx',
    'cr',
    'sa',
    'cv',
    'sapi',
    'rl',
    'sr',
    'sw',
    'conekta',
    'stripe',
    'openpay',
  };

  @override
  void initState() {
    super.initState();
    _sessionTxIds = widget.provider.transactions
        .where((t) =>
            t.type == MovementType.expense &&
            (t.category == 'Estado de Cuenta' || t.category == 'Varios'))
        .map((t) => t.id)
        .toSet();
  }

  @override
  void dispose() {
    for (final ctrl in _keywordControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  /// Normalizes a merchant/concept title by stripping trailing reference codes and digits
  /// so repeated charges at the same merchant group together cleanly.
  String _merchantGroupKey(String rawTitle) {
    final norm = MovementCategory.normalizeText(rawTitle);
    final tokens = norm
        .split(RegExp(r'[^a-z0-9*]+'))
        .where((t) =>
            t.length >= 2 &&
            double.tryParse(t) == null &&
            !RegExp(r'\d{4,}').hasMatch(t))
        .take(3)
        .toList();
    if (tokens.isEmpty) return norm.isEmpty ? rawTitle.toLowerCase() : norm;
    return tokens.join(' ');
  }

  /// Extracts candidate tokens from a charge description, skipping long reference IDs.
  List<String> _candidateTokensForTitle(String rawTitle) {
    return MovementCategory.extractCandidateWords(rawTitle)
        .where((w) => !RegExp(r'\d{3,}').hasMatch(w) && w.length >= 2)
        .toList();
  }

  /// Picks the best default keyword for a merchant group, skipping POS/aggregator prefixes.
  String _defaultKeywordForGroup(String rawTitle) {
    final words = _candidateTokensForTitle(rawTitle);
    if (words.isEmpty) return '';
    final meaningful = words
        .where((w) => !_aggregatorPrefixes.contains(w) && w.length >= 3)
        .toList();
    if (meaningful.isNotEmpty) return meaningful.first;
    return words.first;
  }

  TextEditingController _controllerForGroup(String groupKey, String sampleTitle) {
    return _keywordControllers.putIfAbsent(
      groupKey,
      () => TextEditingController(text: _defaultKeywordForGroup(sampleTitle)),
    );
  }

  Future<void> _runAutoClassify() async {
    setState(() => _isRunningAuto = true);
    final count = await widget.provider.autoClassifyUncategorizedStatements();
    if (mounted) {
      // Mark any session groups whose transactions were all auto-classified
      final txById = {for (final t in widget.provider.transactions) t.id: t};
      final Map<String, List<Transaction>> groups = {};
      for (final id in _sessionTxIds) {
        final tx = txById[id];
        if (tx != null) {
          groups.putIfAbsent(_merchantGroupKey(tx.title), () => []).add(tx);
        }
      }
      setState(() {
        _isRunningAuto = false;
        _lastAutoClassifiedCount = count;
        groups.forEach((key, list) {
          final cats = list.map((t) => t.category).toSet();
          if (cats.length == 1 &&
              cats.first != 'Estado de Cuenta' &&
              cats.first != 'Varios') {
            _assignedCategoryByGroup[key] = cats.first;
          }
        });
      });
    }
  }

  Future<void> _assignGroup(
    String groupKey,
    List<Transaction> groupTxs,
    String categoryName,
    String rawKeyword,
  ) async {
    final keyword = MovementCategory.normalizeText(rawKeyword);
    final ids = groupTxs.map((t) => t.id).toList();
    await widget.provider.bulkAssignCategoryByIds(
      ids,
      categoryName,
      keywordToLearn: (_rememberKeyword && keyword.isNotEmpty) ? keyword : null,
    );
    if (mounted) {
      setState(() {
        _assignedCategoryByGroup[groupKey] = categoryName;
        if (_rememberKeyword && keyword.isNotEmpty) {
          _assignedKeywordByGroup[groupKey] = keyword;
        } else {
          _assignedKeywordByGroup.remove(groupKey);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Clasificar Cargos Importados',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          CloudSyncBadge(provider: widget.provider),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.provider,
        builder: (context, _) {
          final sessionTxs = widget.provider.transactions
              .where((t) => _sessionTxIds.contains(t.id))
              .toList();

          final Map<String, List<Transaction>> groups = {};
          for (final tx in sessionTxs) {
            final key = _merchantGroupKey(tx.title);
            groups.putIfAbsent(key, () => []).add(tx);
          }

          final sortedGroups = groups.entries.toList()
            ..sort((a, b) {
              final aSum = a.value.fold<double>(0.0, (s, t) => s + t.amount);
              final bSum = b.value.fold<double>(0.0, (s, t) => s + t.amount);
              return bSum.compareTo(aSum);
            });

          final pendingCount = sortedGroups
              .where((g) => !_assignedCategoryByGroup.containsKey(g.key))
              .length;

          final seenNames = <String>{};
          final expenseCats = widget.provider.expenseCategories.where((cat) {
            final lower = cat.name.trim().toLowerCase();
            if (seenNames.contains(lower)) return false;
            seenNames.add(lower);
            return true;
          }).toList();

          return Column(
            children: [
              // Top Auto-Classify & Auto-Save Banner
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.electricCyan.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pendingCount ${pendingCount == 1 ? "comercio pendiente" : "comercios pendientes"} (${_assignedCategoryByGroup.length} clasificados)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Todos tus cambios se guardan automáticamente. Cuando termines, puedes salir de esta pantalla.',
                      style: TextStyle(
                        color: AppTheme.emeraldGreen,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.electricCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: (_isRunningAuto || pendingCount == 0)
                            ? null
                            : _runAutoClassify,
                        icon: const Icon(Icons.auto_fix_high, size: 17),
                        label: const Text(
                          'Auto-clasificar conocidos',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (_lastAutoClassifiedCount != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _lastAutoClassifiedCount! > 0
                            ? '✓ $_lastAutoClassifiedCount cargo(s) clasificados automáticamente.'
                            : 'Sin coincidencias nuevas; clasifica los grupos manualmente abajo.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.electricCyan,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppTheme.emeraldGreen,
                      title: const Text(
                        'Recordar palabra clave para futuros estados de cuenta',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      value: _rememberKeyword,
                      onChanged: (v) => setState(() => _rememberKeyword = v),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: sortedGroups.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 48, color: AppTheme.emeraldGreen),
                              SizedBox(height: 12),
                              Text(
                                '¡Todos tus cargos están clasificados!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Revisa "Movimientos → Por Categoría" para ver tus estadísticas.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: sortedGroups.length,
                        itemBuilder: (context, index) {
                          final entry = sortedGroups[index];
                          final groupKey = entry.key;
                          final list = entry.value;
                          final total =
                              list.fold<double>(0.0, (s, t) => s + t.amount);
                          final sampleTitle = list.first.title;
                          final assignedCat = _assignedCategoryByGroup[groupKey];
                          final isClassified = assignedCat != null;

                          if (isClassified) {
                            final catMeta = widget.provider.categoryByName(
                              assignedCat,
                              isIncome: false,
                            );
                            final catColor =
                                catMeta?.color ?? AppTheme.emeraldGreen;
                            final savedKw = _assignedKeywordByGroup[groupKey];

                            return Opacity(
                              opacity: 0.58,
                              child: InkWell(
                                onTap: () => setState(() {
                                  _assignedCategoryByGroup.remove(groupKey);
                                }),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: catColor.withOpacity(0.45)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sampleTitle,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${list.length} ${list.length == 1 ? "cargo" : "cargos"} • ${savedKw != null ? "Clave: \"$savedKw\"" : "Sin palabra clave"} • Toca para corregir',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            CurrencyFormat.formatMXN(total),
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: catColor.withOpacity(0.18),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: catColor.withOpacity(0.55)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              catMeta?.iconData ??
                                                  Icons.check_circle,
                                              size: 14,
                                              color: catColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '✓ $assignedCat',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final kwCtrl =
                              _controllerForGroup(groupKey, sampleTitle);
                          final tokens = _candidateTokensForTitle(sampleTitle);
                          final skipThis =
                              _skipKeywordGroups.contains(groupKey);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sampleTitle,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${list.length} ${list.length == 1 ? "cargo" : "cargos"}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyFormat.formatMXN(total),
                                      style: const TextStyle(
                                        color: AppTheme.alertCoral,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_rememberKeyword) ...[
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () => setState(() {
                                      if (skipThis) {
                                        _skipKeywordGroups.remove(groupKey);
                                      } else {
                                        _skipKeywordGroups.add(groupKey);
                                      }
                                    }),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: skipThis
                                            ? AppTheme.amberGold.withOpacity(0.16)
                                            : AppTheme.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: skipThis
                                              ? AppTheme.amberGold
                                                  .withOpacity(0.5)
                                              : AppTheme.border,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            skipThis
                                                ? Icons.block
                                                : Icons.bookmark_border,
                                            size: 13,
                                            color: skipThis
                                                ? AppTheme.amberGold
                                                : AppTheme.textSecondary,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              'No aplica ninguna palabra clave para este cargo',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: skipThis
                                                    ? FontWeight.w700
                                                    : FontWeight.normal,
                                                color: skipThis
                                                    ? AppTheme.amberGold
                                                    : AppTheme.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (skipThis) ...[
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Solo se clasificará este movimiento; no se guardará ninguna palabra clave.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: kwCtrl,
                                      style: const TextStyle(
                                        color: AppTheme.electricCyan,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        labelText:
                                            'Palabra clave a recordar (puedes editarla o borrarla)',
                                        labelStyle: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted,
                                        ),
                                        isDense: true,
                                        filled: true,
                                        fillColor: AppTheme.surface,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.clear,
                                              size: 16,
                                              color: AppTheme.textMuted),
                                          tooltip: 'No guardar palabra clave',
                                          onPressed: () => setState(() {
                                            _skipKeywordGroups.add(groupKey);
                                          }),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: AppTheme.border),
                                        ),
                                      ),
                                    ),
                                    if (tokens.length > 1) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 5,
                                        runSpacing: 4,
                                        children: tokens.map((tok) {
                                          final isPrefix =
                                              _aggregatorPrefixes.contains(tok);
                                          return InkWell(
                                            onTap: () => setState(() {
                                              kwCtrl.text = tok;
                                            }),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isPrefix
                                                      ? AppTheme.border
                                                      : AppTheme.electricCyan
                                                          .withOpacity(0.4),
                                                ),
                                              ),
                                              child: Text(
                                                tok,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: isPrefix
                                                      ? AppTheme.textMuted
                                                      : AppTheme.electricCyan,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ],
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ...expenseCats.map((cat) {
                                        final c = cat.color;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: ActionChip(
                                            avatar: Icon(cat.iconData,
                                                size: 14, color: c),
                                            label: Text(cat.name),
                                            backgroundColor: AppTheme.surface,
                                            side: BorderSide(
                                                color: c.withOpacity(0.45)),
                                            labelStyle: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            onPressed: () => _assignGroup(
                                              groupKey,
                                              list,
                                              cat.name,
                                              skipThis ? '' : kwCtrl.text,
                                            ),
                                          ),
                                        );
                                      }),
                                      ActionChip(
                                        avatar: const Icon(Icons.add,
                                            size: 15,
                                            color: AppTheme.electricCyan),
                                        label: const Text('Nueva'),
                                        backgroundColor: AppTheme.surface,
                                        side: BorderSide(
                                          color: AppTheme.electricCyan
                                              .withOpacity(0.5),
                                        ),
                                        labelStyle: const TextStyle(
                                          color: AppTheme.electricCyan,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        onPressed: () async {
                                          final created =
                                              await showCategoryFormDialog(
                                            context,
                                            initialIsIncome: false,
                                            allowTypeToggle: true,
                                          );
                                          if (created != null) {
                                            await widget.provider
                                                .addCategory(created);
                                            await _assignGroup(
                                              groupKey,
                                              list,
                                              created.name,
                                              skipThis ? '' : kwCtrl.text,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
