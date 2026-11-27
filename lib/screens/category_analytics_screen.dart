import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_format.dart';
import '../models/movement_category.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import 'widgets/cloud_sync_badge.dart';
import 'widgets/transaction_detail_dialog.dart';

class CategoryAnalyticsScreen extends StatefulWidget {
  final FinanceProvider provider;
  final String categoryName;
  final MovementType? movementTypeFilter;

  const CategoryAnalyticsScreen({
    super.key,
    required this.provider,
    required this.categoryName,
    this.movementTypeFilter,
  });

  @override
  State<CategoryAnalyticsScreen> createState() => _CategoryAnalyticsScreenState();
}

class _CategoryAnalyticsScreenState extends State<CategoryAnalyticsScreen> {
  int _monthsWindow = 6; // 6 or 12
  int? _selectedBarIndex;

  static const List<String> _monthAbbr = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  String _monthLabel(int year, int month, {bool includeYear = false}) {
    final abbr = _monthAbbr[(month - 1).clamp(0, 11)];
    return includeYear ? '$abbr $year' : abbr;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isIncome = widget.movementTypeFilter == MovementType.income;
    final catMeta = widget.provider.categoryByName(
      widget.categoryName,
      isIncome: widget.movementTypeFilter == null ? null : isIncome,
    );
    final accentColor = catMeta?.color ??
        (isIncome ? AppTheme.emeraldGreen : AppTheme.electricCyan);
    final iconData = catMeta?.iconData ?? Icons.category_outlined;

    final txs = widget.provider.transactions.where((tx) {
      if (tx.category.trim().toLowerCase() !=
          widget.categoryName.trim().toLowerCase()) {
        return false;
      }
      if (widget.movementTypeFilter != null &&
          tx.type != widget.movementTypeFilter) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final accountMap = {for (final a in widget.provider.accounts) a.id: a};

    final totalAll = txs.fold<double>(0.0, (s, t) => s + t.amount);
    final avgTicket = txs.isEmpty ? 0.0 : totalAll / txs.length;
    final maxTx = txs.isEmpty
        ? null
        : txs.reduce((a, b) => a.amount >= b.amount ? a : b);

    // Monthly totals across all history
    final Map<String, double> monthlyTotals = {};
    for (final tx in txs) {
      final key =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      monthlyTotals[key] = (monthlyTotals[key] ?? 0.0) + tx.amount;
    }

    String? peakMonthKey;
    double peakMonthAmount = 0.0;
    monthlyTotals.forEach((k, v) {
      if (v > peakMonthAmount) {
        peakMonthAmount = v;
        peakMonthKey = k;
      }
    });

    final activeMonthsCount = monthlyTotals.isEmpty ? 1 : monthlyTotals.length;
    final avgMonthly = totalAll / activeMonthsCount;

    // Build last _monthsWindow months series (oldest -> newest)
    final now = DateTime.now();
    final List<({String key, String label, double amount})> chartMonths = [];
    for (int i = _monthsWindow - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      chartMonths.add((
        key: key,
        label: _monthLabel(d.year, d.month),
        amount: monthlyTotals[key] ?? 0.0,
      ));
    }

    final maxChartVal = chartMonths.fold<double>(
      0.0,
      (m, e) => e.amount > m ? e.amount : m,
    );

    // Group by normalized concept / merchant
    final Map<String, ({String displayTitle, int count, double total, DateTime lastDate, List<Transaction> txs})>
        conceptStats = {};
    for (final tx in txs) {
      final norm = MovementCategory.normalizeText(tx.title);
      final key = norm.isEmpty ? tx.title.toLowerCase() : norm;
      final existing = conceptStats[key];
      if (existing == null) {
        conceptStats[key] = (
          displayTitle: tx.title,
          count: 1,
          total: tx.amount,
          lastDate: tx.date,
          txs: [tx],
        );
      } else {
        conceptStats[key] = (
          displayTitle: existing.displayTitle,
          count: existing.count + 1,
          total: existing.total + tx.amount,
          lastDate: tx.date.isAfter(existing.lastDate)
              ? tx.date
              : existing.lastDate,
          txs: [...existing.txs, tx],
        );
      }
    }
    final topConcepts = conceptStats.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    String peakDisplay = 'Sin datos';
    if (peakMonthKey != null) {
      final parts = peakMonthKey!.split('-');
      final y = int.tryParse(parts[0]) ?? now.year;
      final m = int.tryParse(parts[1]) ?? now.month;
      peakDisplay =
          '${_monthLabel(y, m, includeYear: true)} • ${CurrencyFormat.formatMXN(peakMonthAmount, includeDecimals: false)}';
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        actions: [
          CloudSyncBadge(provider: widget.provider),
        ],
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: accentColor.withOpacity(0.2),
              child: Icon(iconData, size: 16, color: accentColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.categoryName,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: txs.isEmpty
          ? const Center(
              child: Text(
                'No hay movimientos registrados en esta categoría.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // KPI Grid
                Row(
                  children: [
                    Expanded(
                      child: _kpiCard(
                        label: isIncome ? 'Total Recibido' : 'Total Gastado',
                        value: CurrencyFormat.formatMXN(totalAll, includeDecimals: false),
                        sub: '${txs.length} movimientos',
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _kpiCard(
                        label: 'Promedio Mensual',
                        value: CurrencyFormat.formatMXN(avgMonthly, includeDecimals: false),
                        sub: 'En $activeMonthsCount ${activeMonthsCount == 1 ? "mes" : "meses"} activos',
                        color: AppTheme.electricCyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _kpiCard(
                        label: isIncome ? 'Mes con Mayor Ingreso' : 'Mes con Mayor Gasto',
                        value: peakDisplay,
                        sub: 'Pico histórico',
                        color: AppTheme.amberGold,
                        compactValue: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _kpiCard(
                        label: 'Ticket Promedio',
                        value: CurrencyFormat.formatMXN(avgTicket, includeDecimals: false),
                        sub: maxTx != null
                            ? 'Máx: ${CurrencyFormat.formatMXN(maxTx.amount, includeDecimals: false)}'
                            : '',
                        color: AppTheme.purpleGlow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Monthly Bar Chart
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Evolución Mensual',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Row(
                            children: [
                              _windowChip('6M', 6),
                              const SizedBox(width: 6),
                              _windowChip('12M', 12),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Builder(builder: (_) {
                        final activeIdx = (_selectedBarIndex != null &&
                                _selectedBarIndex! < chartMonths.length)
                            ? _selectedBarIndex!
                            : chartMonths.length - 1;
                        final activeItem = chartMonths[activeIdx];
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mes seleccionado: ${activeItem.label}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  CurrencyFormat.formatMXN(activeItem.amount),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: activeItem.key == peakMonthKey &&
                                            activeItem.amount > 0
                                        ? AppTheme.amberGold
                                        : accentColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 150,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(chartMonths.length, (i) {
                                  final item = chartMonths[i];
                                  final isPeak = item.key == peakMonthKey &&
                                      item.amount > 0;
                                  final isSelected = i == activeIdx;
                                  final ratio = maxChartVal > 0
                                      ? (item.amount / maxChartVal)
                                          .clamp(0.0, 1.0)
                                      : 0.0;
                                  final barColor = isPeak
                                      ? AppTheme.amberGold
                                      : accentColor;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _selectedBarIndex = i),
                                      behavior: HitTestBehavior.opaque,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 3),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            if (item.amount > 0)
                                              Text(
                                                item.amount >= 1000
                                                    ? '${(item.amount / 1000).toStringAsFixed(1)}k'
                                                    : item.amount
                                                        .toStringAsFixed(0),
                                                style: TextStyle(
                                                  fontSize: _monthsWindow > 6
                                                      ? 8.5
                                                      : 9.5,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : AppTheme.textMuted,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.clip,
                                              ),
                                            const SizedBox(height: 4),
                                            AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 220),
                                              height:
                                                  (ratio * 102).clamp(4.0, 102.0),
                                              width: _monthsWindow > 6 ? 12 : 20,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? barColor
                                                    : barColor.withOpacity(0.55),
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                        top: Radius.circular(6)),
                                                border: isSelected
                                                    ? Border.all(
                                                        color: Colors.white,
                                                        width: 1)
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              item.label,
                                              style: TextStyle(
                                                fontSize: _monthsWindow > 6
                                                    ? 9
                                                    : 10.5,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? Colors.white
                                                    : AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Top Concepts / Merchants
                if (topConcepts.isNotEmpty) ...[
                  const Text(
                    'Conceptos más frecuentes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...topConcepts.take(8).map((c) {
                    final share = totalAll > 0 ? (c.total / totalAll) : 0.0;
                    return InkWell(
                      onTap: () {
                        if (c.txs.length == 1) {
                          showTransactionDetailDialog(
                              context, widget.provider, c.txs.first);
                        } else {
                          _showConceptTransactionsSheet(
                              context, c.displayTitle, c.txs, accountMap);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  c.displayTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormat.formatMXN(c.total),
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${c.count} ${c.count == 1 ? "vez" : "veces"} • Último: ${c.lastDate.day}/${c.lastDate.month}/${c.lastDate.year}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                              Text(
                                '${(share * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: share.clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: AppTheme.surface,
                              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                // Full History
                const Text(
                  'Historial detallado (cuándo y cuánto)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                ...txs.map((tx) {
                  final acc = accountMap[tx.accountId];
                  return InkWell(
                    onTap: () => showTransactionDetailDialog(
                        context, widget.provider, tx),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${tx.date.day}/${tx.date.month}/${tx.date.year}${acc != null ? " • ${acc.name}" : ""}',
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
                          CurrencyFormat.formatMXN(tx.amount),
                          style: TextStyle(
                            color: tx.type == MovementType.income
                                ? AppTheme.emeraldGreen
                                : AppTheme.alertCoral,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required String sub,
    required Color color,
    bool compactValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: compactValue ? 13 : 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(fontSize: 10.5, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _windowChip(String label, int months) {
    final selected = _monthsWindow == months;
    return ChoiceChip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.electricCyan.withOpacity(0.25),
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        color: selected ? Colors.white : AppTheme.textSecondary,
      ),
      onSelected: (_) => setState(() => _monthsWindow = months),
    );
  }

  void _showConceptTransactionsSheet(
    BuildContext context,
    String title,
    List<Transaction> items,
    Map<String, dynamic> accountMap,
  ) {
    final sorted = [...items]..sort((a, b) => b.date.compareTo(a.date));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.72,
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        decoration: const BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${sorted.length} movimientos • Toca cualquiera para ver o editar',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, idx) {
                  final tx = sorted[idx];
                  final acc = accountMap[tx.accountId];
                  return InkWell(
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      showTransactionDetailDialog(
                          context, widget.provider, tx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${tx.date.day}/${tx.date.month}/${tx.date.year}${acc != null ? " • ${acc.name}" : ""}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (tx.note != null &&
                                    tx.note!.trim().isNotEmpty)
                                  Text(
                                    tx.note!.trim(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormat.formatMXN(tx.amount),
                            style: TextStyle(
                              color: tx.type == MovementType.income
                                  ? AppTheme.emeraldGreen
                                  : AppTheme.alertCoral,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              size: 16, color: AppTheme.textMuted),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

