import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/file_backup_helper.dart';
import '../../models/account.dart';
import '../../models/credit_installment.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';

class _ParsedStatementRow {
  final String title;
  final double amount;
  final DateTime date;
  final int? msiMonths;
  final int? msiPaid;
  bool selected = true;

  _ParsedStatementRow({
    required this.title,
    required this.amount,
    required this.date,
    this.msiMonths,
    this.msiPaid,
  });
}

class StatementImportSheet extends StatefulWidget {
  final FinanceProvider provider;
  final Account card;

  const StatementImportSheet({
    super.key,
    required this.provider,
    required this.card,
  });

  @override
  State<StatementImportSheet> createState() => _StatementImportSheetState();
}

class _StatementImportSheetState extends State<StatementImportSheet> {
  final TextEditingController _pasteCtrl = TextEditingController();
  final List<_ParsedStatementRow> _rows = [];
  bool _alreadyInBalance = true;
  bool _syncCardSummaryFromPdf = true;

  double? _detectedTotalDebt;
  double? _detectedCreditLimit;
  int? _detectedCutoffDay;
  int? _detectedDueDay;
  String? _loadedFileName;

  static const Map<String, int> _esMonths = {
    'ene': 1, 'feb': 2, 'mar': 3, 'abr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'ago': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dic': 12,
  };

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseStatementDate(String s) {
    // 1) dd-mmm-yyyy (e.g., 16-oct-2026, 05-nov-2026)
    final esMatch = RegExp(r'^(\d{1,2})[\-/]([a-zA-Z]{3})[\-/](\d{2,4})$').firstMatch(s.trim());
    if (esMatch != null) {
      final d = int.tryParse(esMatch.group(1)!);
      final mStr = esMatch.group(2)!.toLowerCase();
      final mo = _esMonths[mStr];
      var y = int.tryParse(esMatch.group(3)!);
      if (d != null && mo != null && y != null) {
        if (y < 100) y += 2000;
        return DateTime(y, mo, d);
      }
    }

    // 2) dd/mm/yyyy or dd-mm-yyyy
    final numMatch = RegExp(r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})$').firstMatch(s.trim());
    if (numMatch != null) {
      final d = int.tryParse(numMatch.group(1)!);
      final mo = int.tryParse(numMatch.group(2)!);
      var y = int.tryParse(numMatch.group(3)!);
      if (d != null && mo != null && y != null) {
        if (y < 100) y += 2000;
        if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, mo, d);
        }
      }
    }
    return null;
  }

  double? _parseMoney(String s) {
    final cleaned = s.replaceAll(RegExp(r'[\$\s,]'), '');
    return double.tryParse(cleaned);
  }

  void _parseRawText(String raw) {
    final lines = raw.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final List<_ParsedStatementRow> parsedMsi = [];
    final List<_ParsedStatementRow> parsedRegular = [];

    double? totalDebt;
    double? creditLimit;
    int? cutoffDay;
    int? dueDay;

    // 1. Scan summary fields from CONDUSEF / Banamex Universal PDF
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      if (lower.contains('saldo deudor total')) {
        final m = RegExp(r'\$\s*([\d,]+\.\d{2})').firstMatch(line) ??
            (i + 1 < lines.length ? RegExp(r'\$\s*([\d,]+\.\d{2})').firstMatch(lines[i + 1]) : null);
        if (m != null) totalDebt = _parseMoney(m.group(1)!);
      } else if (lower.contains('límite de crédito') || lower.contains('limite de credito')) {
        final m = RegExp(r'\$\s*([\d,]+\.\d{2})').firstMatch(line) ??
            (i + 1 < lines.length ? RegExp(r'\$\s*([\d,]+\.\d{2})').firstMatch(lines[i + 1]) : null);
        if (m != null) creditLimit = _parseMoney(m.group(1)!);
      } else if (lower.contains('fecha de corte')) {
        final m = RegExp(r'(\d{1,2})[\-/]([a-zA-Z]{3}|\d{1,2})[\-/]\d{2,4}').firstMatch(line);
        if (m != null) cutoffDay = int.tryParse(m.group(1)!);
      } else if (lower.contains('fecha límite de pago') || lower.contains('fecha limite de pago')) {
        final m = RegExp(r'(\d{1,2})[\-/]([a-zA-Z]{3}|\d{1,2})[\-/]\d{2,4}').firstMatch(line);
        if (m != null) dueDay = int.tryParse(m.group(1)!);
      }
    }

    // 2. Parse MSI Table rows & Regular rows
    for (final line in lines) {
      // Banamex MSI table row: "05-nov-2026 AMAZON A MESES ... $947.36 $631.57 $315.79 1 de 3 NA"
      final msiLineMatch = RegExp(
        r'^(\d{1,2}[\-/][a-zA-Z0-9]{2,3}[\-/]\d{2,4})\s+(.+?)\s+\$?([\d,]+\.\d{2})\s+\$?([\d,]+\.\d{2})\s+\$?([\d,]+\.\d{2})\s+(\d{1,2})\s+de\s+(\d{1,2})',
        caseSensitive: false,
      ).firstMatch(line);

      if (msiLineMatch != null) {
        final date = _parseStatementDate(msiLineMatch.group(1)!) ?? DateTime.now();
        final desc = msiLineMatch.group(2)!.trim();
        final origAmt = _parseMoney(msiLineMatch.group(3)!) ?? 0.0;
        final paid = int.tryParse(msiLineMatch.group(6)!) ?? 0;
        final total = int.tryParse(msiLineMatch.group(7)!) ?? 1;

        if (origAmt > 0 && total >= 2 && paid < total) {
          parsedMsi.add(_ParsedStatementRow(
            title: desc,
            amount: origAmt,
            date: date,
            msiMonths: total,
            msiPaid: paid,
          ));
        }
        continue;
      }

      // Banamex Regular Charge row: "07-nov-2026 09-nov-2026 COSTCO SAN ANTONIO ... + $3,520.40"
      final regChargeMatch = RegExp(
        r'^(\d{1,2}[\-/][a-zA-Z0-9]{2,3}[\-/]\d{2,4})\s+(\d{1,2}[\-/][a-zA-Z0-9]{2,3}[\-/]\d{2,4})\s+(.+?)\s+\+\s*\$?([\d,]+\.\d{2})$',
      ).firstMatch(line);

      if (regChargeMatch != null) {
        final date = _parseStatementDate(regChargeMatch.group(1)!) ?? DateTime.now();
        final desc = regChargeMatch.group(3)!.trim();
        final amt = _parseMoney(regChargeMatch.group(4)!) ?? 0.0;

        // Skip installment billing lines like "001 de 003" already captured in MSI table
        if (RegExp(r'\b\d{3}\s+de\s+\d{3}\b', caseSensitive: false).hasMatch(desc)) {
          continue;
        }
        if (amt > 0) {
          parsedRegular.add(_ParsedStatementRow(
            title: desc,
            amount: amt,
            date: date,
          ));
        }
        continue;
      }

      // Generic CSV / fallback parser
      final parts = line.split(RegExp(r'[,\t;]'));
      if (parts.length >= 2) {
        double? amount;
        String? title;
        DateTime date = DateTime.now();

        for (int i = parts.length - 1; i >= 0; i--) {
          final val = _parseMoney(parts[i]);
          if (val != null && val > 0) {
            amount = val;
            final rest = parts.sublist(0, i).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            if (rest.isNotEmpty) {
              final maybeDate = _parseStatementDate(rest.first);
              if (maybeDate != null && rest.length > 1) {
                date = maybeDate;
                title = rest.sublist(1).join(' ');
              } else {
                title = rest.join(' ');
              }
            }
            break;
          }
        }

        if (amount != null && title != null && title.isNotEmpty) {
          final lower = title.toLowerCase();
          if (lower == 'concepto' || lower == 'descripcion' || lower == 'descripción') continue;

          int? msiMonths;
          int? msiPaid;
          final ratioMatch = RegExp(r'(\d{1,2})\s*(?:/|de)\s*(\d{1,2})', caseSensitive: false).firstMatch(title);
          if (ratioMatch != null) {
            final p = int.tryParse(ratioMatch.group(1)!);
            final tot = int.tryParse(ratioMatch.group(2)!);
            if (p != null && tot != null && tot >= 3 && tot <= 48 && p <= tot) {
              msiPaid = p;
              msiMonths = tot;
            }
          }

          parsedRegular.add(_ParsedStatementRow(
            title: title,
            amount: amount,
            date: date,
            msiMonths: msiMonths,
            msiPaid: msiPaid,
          ));
        }
      }
    }

    setState(() {
      _detectedTotalDebt = totalDebt;
      _detectedCreditLimit = creditLimit;
      _detectedCutoffDay = cutoffDay;
      _detectedDueDay = dueDay;
      _rows
        ..clear()
        ..addAll(parsedMsi)
        ..addAll(parsedRegular);
    });
  }

  Future<void> _pickFile() async {
    final result = await pickStatementFile(accept: '.pdf,.csv,.txt');
    if (result == null) return;

    String extracted = '';
    if (result.name.toLowerCase().endsWith('.pdf')) {
      try {
        final document = PdfDocument(inputBytes: result.bytes);
        extracted = PdfTextExtractor(document).extractText();
        document.dispose();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.alertCoral,
              content: Text('No se pudo leer el PDF: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } else {
      extracted = result.text ?? '';
    }

    if (extracted.trim().isNotEmpty) {
      setState(() => _loadedFileName = result.name);
      _pasteCtrl.text = extracted;
      _parseRawText(extracted);
    }
  }

  Future<void> _importSelected() async {
    // 1. Optionally update card balance / limit / cutoff / due date from PDF summary
    if (_syncCardSummaryFromPdf && (_detectedTotalDebt != null || _detectedCreditLimit != null)) {
      final currentCard = widget.provider.accounts.firstWhere((a) => a.id == widget.card.id);
      await widget.provider.updateAccount(
        currentCard.copyWith(
          balance: _detectedTotalDebt ?? currentCard.balance,
          creditLimit: _detectedCreditLimit ?? currentCard.creditLimit,
          cutoffDay: _detectedCutoffDay ?? currentCard.cutoffDay,
          paymentDueDay: _detectedDueDay ?? currentCard.paymentDueDay,
        ),
      );
    }

    // 2. Import selected MSI plans and regular charges
    final selectedRows = _rows.where((r) => r.selected).toList();
    for (final r in selectedRows) {
      if (r.msiMonths != null && r.msiMonths! >= 2) {
        await widget.provider.addInstallmentPlan(
          CreditInstallmentPlan(
            id: 'msi_${DateTime.now().millisecondsSinceEpoch}_${r.title.hashCode}_${r.amount.toInt()}',
            accountId: widget.card.id,
            title: r.title,
            principalAmount: r.amount,
            totalMonths: r.msiMonths!,
            paidMonths: r.msiPaid ?? 0,
            startDate: r.date,
          ),
          isNewPurchase: !_alreadyInBalance,
        );
      } else {
        await widget.provider.addTransaction(
          title: r.title,
          amount: r.amount,
          type: MovementType.expense,
          category: 'Estado de Cuenta',
          accountId: widget.card.id,
          date: r.date,
          skipBalanceUpdate: _alreadyInBalance,
        );
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.emeraldGreen,
          content: Text('${selectedRows.length} movimiento(s)/plan(es) importados a ${widget.card.name}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Importar Estado de Cuenta • ${widget.card.name}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sube tu Estado de Cuenta en PDF (Banamex / Nu / CONDUSEF) o CSV/TXT. Todo se procesa localmente en tu dispositivo.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.electricCyan.withOpacity(0.18),
                      foregroundColor: AppTheme.electricCyan,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: Text(
                      _loadedFileName ?? 'Subir PDF / CSV / TXT',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _pickFile,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.emeraldGreen,
                    side: BorderSide(color: AppTheme.emeraldGreen.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _parseRawText(_pasteCtrl.text),
                  child: const Text('Analizar texto', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _pasteCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 11, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'O pega aquí texto copiado de tu estado de cuenta...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            if (_detectedTotalDebt != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.electricCyan.withOpacity(0.4)),
                ),
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Resumen detectado: Saldo ${CurrencyFormat.formatMXN(_detectedTotalDebt!)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.electricCyan),
                  ),
                  subtitle: Text(
                    'Actualizar saldo${_detectedCreditLimit != null ? ", límite (${CurrencyFormat.formatMXN(_detectedCreditLimit!, includeDecimals: false)})" : ""} y fechas de corte/pago.',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  value: _syncCardSummaryFromPdf,
                  activeColor: AppTheme.electricCyan,
                  onChanged: (v) => setState(() => _syncCardSummaryFromPdf = v),
                ),
              ),
            ],

            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Cargos ya incluidos en el saldo actual', style: TextStyle(fontSize: 13, color: Colors.white)),
                subtitle: const Text(
                  'Actívalo para no duplicar la deuda actual de tu tarjeta.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                value: _alreadyInBalance,
                activeColor: AppTheme.emeraldGreen,
                onChanged: (v) => setState(() => _alreadyInBalance = v),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _rows.length,
                  itemBuilder: (ctx, i) {
                    final r = _rows[i];
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.emeraldGreen,
                      value: r.selected,
                      title: Text(r.title, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      subtitle: Text(
                        r.msiMonths != null
                            ? '${r.msiPaid}/${r.msiMonths} MSI • ${r.date.day}/${r.date.month}/${r.date.year}'
                            : 'Contado • ${r.date.day}/${r.date.month}/${r.date.year}',
                        style: TextStyle(
                          fontSize: 11,
                          color: r.msiMonths != null ? AppTheme.electricCyan : AppTheme.textMuted,
                        ),
                      ),
                      secondary: Text(
                        CurrencyFormat.formatMXN(r.amount),
                        style: const TextStyle(color: AppTheme.alertCoral, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      onChanged: (v) => setState(() => r.selected = v ?? false),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(
                    'Importar ${_rows.where((r) => r.selected).length} elementos',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: _importSelected,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
