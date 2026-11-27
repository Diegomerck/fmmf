import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_format.dart';
import '../core/utils/file_backup_helper.dart';
import '../models/account.dart';
import '../models/credit_installment.dart';
import '../models/imported_statement.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../services/pdf_statement_parser.dart';

class StatementImportScreen extends StatefulWidget {
  final FinanceProvider provider;
  final Account card;

  const StatementImportScreen({
    super.key,
    required this.provider,
    required this.card,
  });

  @override
  State<StatementImportScreen> createState() => _StatementImportScreenState();
}

class _MsiMatchCandidate {
  final ParsedMsiRow row;
  final CreditInstallmentPlan existingPlan;
  bool associate = true;

  _MsiMatchCandidate({
    required this.row,
    required this.existingPlan,
  });
}

class _RegularMatchCandidate {
  final ParsedRegularRow row;
  final Transaction existingTx;
  bool associate = true;

  _RegularMatchCandidate({
    required this.row,
    required this.existingTx,
  });
}

class _StatementImportScreenState extends State<StatementImportScreen> {
  ParsedStatementResult? _result;
  String? _fileName;
  bool _syncCardSummary = true;
  bool _alreadyPaidStatement = false;
  bool _alreadyInBalance = true;
  bool _showRawDebug = false;
  bool _isDraggingFile = false;
  void Function()? _disposeDropListener;
  List<_MsiMatchCandidate> _msiMatches = [];
  List<_RegularMatchCandidate> _regularMatches = [];

  @override
  void initState() {
    super.initState();
    _disposeDropListener = registerStatementDropListener(
      onHoverChanged: (hovering) {
        if (mounted && _isDraggingFile != hovering) {
          setState(() => _isDraggingFile = hovering);
        }
      },
      onFileDropped: (picked) {
        if (mounted) _processPickedFile(picked);
      },
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.alertCoral,
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _disposeDropListener?.call();
    super.dispose();
  }

  static bool _amountsMatch(double a, double b) {
    final pesosDiff = (a.truncate() - b.truncate()).abs();
    final totalDiff = (a - b).abs();
    return pesosDiff <= 1 && totalDiff <= 1.50;
  }

  static String _normDesc(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<void> _pickAndParseFile() async {
    final picked = await pickStatementFile(accept: '.pdf,.csv,.txt');
    if (picked == null) return;
    _processPickedFile(picked);
  }

  void _processPickedFile(PickedFileResult picked) {
    List<String> lines = [];
    if (picked.name.toLowerCase().endsWith('.pdf')) {
      try {
        lines = PdfStatementParser.extractVisualRowsFromPdf(picked.bytes);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.alertCoral,
              content: Text('Error al leer PDF: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } else {
      final text = picked.text ?? '';
      lines = text.split(RegExp(r'\r?\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final parsed = PdfStatementParser.parseLines(lines);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isPastStatement = parsed.summary.cutoffDate != null && parsed.summary.cutoffDate!.isBefore(today);

    // Detect candidate matches against existing MSI plans and transactions on this card
    final existingPlans = widget.provider.getPlansForCard(widget.card.id);
    final claimedPlanIds = <String>{};
    final msiMatches = <_MsiMatchCandidate>[];
    for (final m in parsed.msiRows) {
      CreditInstallmentPlan? match;
      for (final plan in existingPlans) {
        if (claimedPlanIds.contains(plan.id)) continue;
        if (plan.totalMonths != m.totalMonths) continue;
        if (!_amountsMatch(plan.totalFinancedAmount, m.originalAmount)) continue;
        final daysApart = plan.startDate.difference(m.date).inDays.abs();
        if (daysApart <= 35 || _normDesc(plan.title) == _normDesc(m.description)) {
          match = plan;
          break;
        }
      }
      if (match != null) {
        claimedPlanIds.add(match.id);
        m.selected = true;
        msiMatches.add(_MsiMatchCandidate(row: m, existingPlan: match));
      }
    }

    final existingCardTxs = widget.provider.transactions
        .where((t) => t.accountId == widget.card.id || t.targetAccountId == widget.card.id)
        .toList();
    final claimedTxIds = <String>{};
    final regMatches = <_RegularMatchCandidate>[];
    for (final reg in parsed.regularRows) {
      Transaction? match;
      for (final tx in existingCardTxs) {
        if (claimedTxIds.contains(tx.id)) continue;
        final txIsPayment = tx.targetAccountId == widget.card.id || tx.type == MovementType.income;
        if (txIsPayment != reg.isPayment) continue;
        if (tx.date.difference(reg.opDate).inDays.abs() > 4) continue;
        if (!_amountsMatch(tx.amount, reg.amount)) continue;
        match = tx;
        break;
      }
      if (match != null) {
        claimedTxIds.add(match.id);
        reg.selected = true;
        regMatches.add(_RegularMatchCandidate(row: reg, existingTx: match));
      }
    }

    setState(() {
      _fileName = picked.name;
      _result = parsed;
      _alreadyPaidStatement = isPastStatement;
      _msiMatches = msiMatches;
      _regularMatches = regMatches;
    });
  }

  Future<void> _editCustomNameDialog(String bankDesc, String? currentCustom, ValueChanged<String?> onSave) async {
    final ctrl = TextEditingController(text: currentCustom ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('¿Qué compraste?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bankDesc, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre personalizado (ej. Monitor LG)',
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, foregroundColor: Colors.white),
            onPressed: () {
              final val = ctrl.text.trim();
              onSave(val.isEmpty ? null : val);
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _importSelected() async {
    final res = _result;
    if (res == null) return;

    // 1. Sync summary to Card (never overwrite current card.balance if this is a past paid statement)
    if (_syncCardSummary && res.summary.hasAnyData) {
      final currentCard = widget.provider.accounts.firstWhere((a) => a.id == widget.card.id);
      await widget.provider.updateAccount(
        currentCard.copyWith(
          balance: _alreadyPaidStatement ? currentCard.balance : (res.summary.totalDebt ?? currentCard.balance),
          creditLimit: res.summary.creditLimit ?? currentCard.creditLimit,
          cutoffDay: res.summary.cutoffDay ?? currentCard.cutoffDay,
          paymentDueDay: res.summary.dueDay ?? currentCard.paymentDueDay,
        ),
      );
    }

    int importedCount = 0;
    final List<String> createdPlanIds = [];
    final List<String> createdTxIds = [];

    // 2. Import or associate selected MSI plans
    for (final m in res.msiRows.where((r) => r.selected)) {
      final matchedCandidate = _msiMatches
          .where((c) => identical(c.row, m) && c.associate)
          .firstOrNull;
      if (matchedCandidate != null) {
        final existing = matchedCandidate.existingPlan;
        final bestPaid =
            existing.paidMonths >= m.paidMonths ? existing.paidMonths : m.paidMonths;
        final preservedCustom =
            (existing.customName != null && existing.customName!.trim().isNotEmpty)
                ? existing.customName
                : (existing.title != m.description ? existing.title : m.customName);
        await widget.provider.updateInstallmentPlan(
          existing.copyWith(
            title: m.description,
            customName: preservedCustom,
            paidMonths: bestPaid,
          ),
        );
        continue;
      }

      final planId = await widget.provider.addInstallmentPlan(
        CreditInstallmentPlan(
          id: 'msi_${DateTime.now().millisecondsSinceEpoch}_${m.description.hashCode}_${m.originalAmount.toInt()}_$importedCount',
          accountId: widget.card.id,
          title: m.description,
          customName: m.customName,
          principalAmount: m.originalAmount,
          totalMonths: m.totalMonths,
          paidMonths: m.paidMonths,
          startDate: m.date,
        ),
        isNewPurchase: !_alreadyInBalance,
      );
      createdPlanIds.add(planId);
      importedCount++;
    }

    // 3. Import or associate selected Regular charges
    for (final reg in res.regularRows.where((r) => r.selected)) {
      final matchedCandidate = _regularMatches
          .where((c) => identical(c.row, reg) && c.associate)
          .firstOrNull;
      if (matchedCandidate != null) {
        final existing = matchedCandidate.existingTx;
        final bankTag = 'Edo. Cta.: ${reg.description}';
        final currentNote = existing.note?.trim() ?? '';
        final updatedNote = currentNote.isEmpty
            ? bankTag
            : (currentNote.contains(reg.description)
                ? currentNote
                : '$currentNote • $bankTag');
        await widget.provider.updateTransaction(
          existing.copyWith(note: updatedNote),
        );
        continue;
      }

      final displayDesc = (reg.customName != null && reg.customName!.isNotEmpty)
          ? '${reg.customName} (${reg.description})'
          : reg.description;
      DateTime? billingDate;
      final stmtCutoff = res.summary.cutoffDate;
      if (stmtCutoff != null) {
        final cycleStart = PdfStatementParser.subtractMonths(stmtCutoff, 1);
        final chargeInCycle =
            reg.chargeDate.isAfter(cycleStart) && !reg.chargeDate.isAfter(stmtCutoff);
        if (chargeInCycle) {
          billingDate = reg.chargeDate != reg.opDate ? reg.chargeDate : null;
        } else {
          billingDate = stmtCutoff;
        }
      } else if (reg.chargeDate != reg.opDate) {
        billingDate = reg.chargeDate;
      }
      final suggestedCat = reg.isPayment
          ? 'Pago Tarjeta'
          : widget.provider.suggestCategoryForDescription(
              displayDesc,
              isIncome: false,
              fallback: 'Estado de Cuenta',
            );
      final txId = await widget.provider.addTransaction(
        title: displayDesc,
        amount: reg.amount,
        type: reg.isPayment ? MovementType.income : MovementType.expense,
        category: suggestedCat,
        accountId: widget.card.id,
        date: reg.opDate,
        billingDate: billingDate,
        skipBalanceUpdate: _alreadyInBalance,
        triggerSavingsRules: false,
      );
      createdTxIds.add(txId);
      importedCount++;
    }

    // 4. Record ImportedStatement in history
    await widget.provider.addImportedStatement(
      ImportedStatement(
        id: 'stmt_${DateTime.now().millisecondsSinceEpoch}',
        accountId: widget.card.id,
        fileName: _fileName ?? 'Estado de Cuenta',
        importedAt: DateTime.now(),
        cutoffDateStr: res.summary.cutoffDateStr,
        dueDateStr: res.summary.dueDateStr,
        paymentNoInterest: res.summary.paymentNoInterest,
        regularBalance: res.summary.regularBalance,
        msiBalance: res.summary.msiBalance,
        totalDebt: res.summary.totalDebt,
        creditLimit: res.summary.creditLimit,
        importedPlanIds: createdPlanIds,
        importedTransactionIds: createdTxIds,
      ),
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final res = _result;

    return Scaffold(
      appBar: AppBar(
        title: Text('Estado de Cuenta • ${widget.card.name}', style: const TextStyle(fontSize: 17)),
        actions: [
          if (res != null)
            IconButton(
              icon: Icon(_showRawDebug ? Icons.table_chart : Icons.code, size: 20),
              tooltip: _showRawDebug ? 'Ver tabla' : 'Ver líneas extraídas',
              onPressed: () => setState(() => _showRawDebug = !_showRawDebug),
            ),
        ],
      ),
      body: Column(
        children: [
          // Top Upload Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.electricCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _fileName ?? 'Seleccionar PDF (Banamex / CONDUSEF)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _pickAndParseFile,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                res == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: InkWell(
                            onTap: _pickAndParseFile,
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                              decoration: BoxDecoration(
                                color: _isDraggingFile
                                    ? AppTheme.electricCyan.withOpacity(0.12)
                                    : AppTheme.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isDraggingFile ? AppTheme.electricCyan : AppTheme.border,
                                  width: _isDraggingFile ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isDraggingFile ? Icons.file_download_outlined : Icons.description_outlined,
                                    size: 52,
                                    color: _isDraggingFile ? AppTheme.electricCyan : AppTheme.textMuted,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _isDraggingFile
                                        ? 'Suelta tu Estado de Cuenta aquí'
                                        : 'Arrastra y suelta tu PDF aquí',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'O tócalo para seleccionar un archivo (.pdf, .csv, .txt). Se leerán automáticamente el resumen, tus compras a MSI y tus cargos regulares.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : _showRawDebug
                    ? ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: res.reconstructedLines.length,
                        itemBuilder: (_, i) => SelectableText(
                          '${i + 1}: ${res.reconstructedLines[i]}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontFamily: 'monospace'),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. RESUMEN DEL ESTADO DE CUENTA
                            if (res.summary.hasAnyData) ...[
                              _buildSectionTitle('1. RESUMEN DEL ESTADO DE CUENTA (PÁGINA 1)'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Column(
                                  children: [
                                    if (res.summary.cutoffDateStr != null)
                                      _summaryRow('Fecha de corte', res.summary.cutoffDateStr!),
                                    if (res.summary.dueDateStr != null)
                                      _summaryRow('Fecha límite de pago', res.summary.dueDateStr!),
                                    if (res.summary.paymentNoInterest != null)
                                      _summaryRow(
                                        'Pago para no generar intereses',
                                        CurrencyFormat.formatMXN(res.summary.paymentNoInterest!),
                                        highlight: AppTheme.electricCyan,
                                      ),
                                    if (res.summary.regularBalance != null)
                                      _summaryRow('Saldo cargos regulares', CurrencyFormat.formatMXN(res.summary.regularBalance!)),
                                    if (res.summary.msiBalance != null)
                                      _summaryRow('Saldo cargos a meses', CurrencyFormat.formatMXN(res.summary.msiBalance!)),
                                    if (res.summary.totalDebt != null)
                                      _summaryRow(
                                        'Saldo deudor total',
                                        CurrencyFormat.formatMXN(res.summary.totalDebt!),
                                        highlight: AppTheme.alertCoral,
                                      ),
                                    if (res.summary.creditLimit != null)
                                      _summaryRow('Límite de crédito', CurrencyFormat.formatMXN(res.summary.creditLimit!)),
                                    if (res.summary.availableCredit != null)
                                      _summaryRow(
                                        'Crédito disponible',
                                        CurrencyFormat.formatMXN(res.summary.availableCredit!),
                                        highlight: AppTheme.emeraldGreen,
                                      ),
                                    const Divider(color: AppTheme.border, height: 18),
                                    SwitchListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        'Ya pagué este estado de cuenta (estado pasado)',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.amberGold),
                                      ),
                                      subtitle: Text(
                                        _alreadyPaidStatement
                                            ? 'Conserva tu saldo actual de la tarjeta; no lo sobrescribe.'
                                            : 'Sobrescribirá tu saldo con el Saldo deudor total del PDF.',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                      value: _alreadyPaidStatement,
                                      activeColor: AppTheme.amberGold,
                                      onChanged: (v) => setState(() => _alreadyPaidStatement = v),
                                    ),
                                    SwitchListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        'Sincronizar límite y fechas de corte/pago',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                      value: _syncCardSummary,
                                      activeColor: AppTheme.electricCyan,
                                      onChanged: (v) => setState(() => _syncCardSummary = v),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            if (_msiMatches.isNotEmpty || _regularMatches.isNotEmpty) ...[
                              _buildSectionTitle(
                                'COINCIDENCIAS DETECTADAS (${_msiMatches.length + _regularMatches.length})',
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.amberGold.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppTheme.amberGold.withOpacity(0.4),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Estos cargos coinciden en monto (pesos y centavos cercanos) y rango de fechas con movimientos ya registrados. Confirma si deseas asociarlos para complementar su información sin duplicarlos:',
                                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.35),
                                    ),
                                    const SizedBox(height: 8),
                                    ..._msiMatches.map((c) {
                                      return CheckboxListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        activeColor: AppTheme.emeraldGreen,
                                        value: c.associate,
                                        onChanged: (v) => setState(() => c.associate = v ?? true),
                                        title: Text(
                                          'MSI: ${c.existingPlan.displayTitle}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Edo. Cta.: ${c.row.description} (${CurrencyFormat.formatMXN(c.row.originalAmount)} • ${c.row.paidMonths}/${c.row.totalMonths})\n'
                                          'Registrado: ${CurrencyFormat.formatMXN(c.existingPlan.totalFinancedAmount)} • ${_fmtDate(c.existingPlan.startDate)} • '
                                          '${c.associate ? "Se asociará (no duplica)" : "Se importará aparte"}',
                                          style: const TextStyle(fontSize: 10.5, color: AppTheme.amberGold),
                                        ),
                                      );
                                    }),
                                    ..._regularMatches.map((c) {
                                      return CheckboxListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        activeColor: AppTheme.emeraldGreen,
                                        value: c.associate,
                                        onChanged: (v) => setState(() => c.associate = v ?? true),
                                        title: Text(
                                          c.existingTx.title,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Edo. Cta.: ${c.row.description} (${CurrencyFormat.formatMXN(c.row.amount)} • ${_fmtDate(c.row.opDate)})\n'
                                          'Registrado: ${CurrencyFormat.formatMXN(c.existingTx.amount)} • ${_fmtDate(c.existingTx.date)} • '
                                          '${c.associate ? "Se asociará (no duplica)" : "Se importará aparte"}',
                                          style: const TextStyle(fontSize: 10.5, color: AppTheme.amberGold),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // 2. COMPRAS Y CARGOS DIFERIDOS A MESES SIN INTERESES
                            _buildSectionTitle('2. COMPRAS DIFERIDAS A MESES (${res.msiRows.length})'),
                            const SizedBox(height: 8),
                            if (res.msiRows.isEmpty)
                              const Text(
                                'No se detectaron tablas de compras a meses.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Column(
                                  children: res.msiRows.map((m) {
                                    return CheckboxListTile(
                                      dense: true,
                                      activeColor: AppTheme.emeraldGreen,
                                      value: m.selected,
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              (m.customName != null && m.customName!.isNotEmpty)
                                                  ? m.customName!
                                                  : m.description,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: m.isCompleted ? AppTheme.textMuted : Colors.white,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 15, color: AppTheme.electricCyan),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: 'Poner nombre personalizado',
                                            onPressed: () => _editCustomNameDialog(
                                              m.description,
                                              m.customName,
                                              (val) => setState(() => m.customName = val),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        '${_fmtDate(m.date)} • Orig: ${CurrencyFormat.formatMXN(m.originalAmount)} • Pend: ${CurrencyFormat.formatMXN(m.pendingBalance)} • Pago ${m.paidMonths} de ${m.totalMonths}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: m.isCompleted ? AppTheme.textMuted : AppTheme.electricCyan,
                                        ),
                                      ),
                                      secondary: Text(
                                        '${CurrencyFormat.formatMXN(m.monthlyPayment)}/m',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.amberGold,
                                        ),
                                      ),
                                      onChanged: (v) => setState(() => m.selected = v ?? false),
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: 20),

                            // 3. CARGOS, ABONOS Y COMPRAS REGULARES
                            _buildSectionTitle('3. CARGOS Y ABONOS REGULARES (${res.regularRows.length})'),
                            const SizedBox(height: 8),
                            if (res.regularRows.isEmpty)
                              const Text(
                                'No se detectaron cargos regulares.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Column(
                                  children: res.regularRows.map((r) {
                                    return CheckboxListTile(
                                      dense: true,
                                      activeColor: AppTheme.emeraldGreen,
                                      value: r.selected,
                                      title: Text(
                                        r.description,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        'Op: ${_fmtDate(r.opDate)} • Cargo: ${_fmtDate(r.chargeDate)}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                      secondary: Text(
                                        '${r.isPayment ? "-" : "+"}${CurrencyFormat.formatMXN(r.amount)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: r.isPayment ? AppTheme.emeraldGreen : AppTheme.alertCoral,
                                        ),
                                      ),
                                      onChanged: (v) => setState(() => r.selected = v ?? false),
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                if (_isDraggingFile && res != null)
                  Positioned.fill(
                    child: Container(
                      color: AppTheme.background.withOpacity(0.82),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.electricCyan, width: 2),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.file_download_outlined, size: 48, color: AppTheme.electricCyan),
                              SizedBox(height: 10),
                              Text(
                                'Suelta aquí para cargar otro Estado de Cuenta',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (res != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cargos ya reflejados en el saldo actual', style: TextStyle(fontSize: 12, color: Colors.white)),
                    value: _alreadyInBalance,
                    activeColor: AppTheme.emeraldGreen,
                    onChanged: (v) => setState(() => _alreadyInBalance = v),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check),
                      label: Text(
                        'Importar ${res.msiRows.where((r) => r.selected).length + res.regularRows.where((r) => r.selected).length} seleccionados',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: _importSelected,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.7),
    );
  }

  Widget _summaryRow(String label, String value, {Color? highlight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: highlight ?? Colors.white),
          ),
        ],
      ),
    );
  }
}

