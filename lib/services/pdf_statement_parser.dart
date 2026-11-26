import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ParsedStatementSummary {
  final String? cutoffDateStr;
  final DateTime? cutoffDate;
  final int? cutoffDay;
  final String? dueDateStr;
  final int? dueDay;
  final double? paymentNoInterest;
  final double? regularBalance;
  final double? msiBalance;
  final double? totalDebt;
  final double? creditLimit;
  final double? availableCredit;

  const ParsedStatementSummary({
    this.cutoffDateStr,
    this.cutoffDate,
    this.cutoffDay,
    this.dueDateStr,
    this.dueDay,
    this.paymentNoInterest,
    this.regularBalance,
    this.msiBalance,
    this.totalDebt,
    this.creditLimit,
    this.availableCredit,
  });

  bool get hasAnyData =>
      totalDebt != null ||
      paymentNoInterest != null ||
      creditLimit != null ||
      cutoffDateStr != null;
}

class ParsedMsiRow {
  final DateTime date;
  final String description;
  String? customName;
  final double originalAmount;
  final double pendingBalance;
  final double monthlyPayment;
  final int paidMonths;
  final int totalMonths;
  bool selected;

  ParsedMsiRow({
    required this.date,
    required this.description,
    this.customName,
    required this.originalAmount,
    required this.pendingBalance,
    required this.monthlyPayment,
    required this.paidMonths,
    required this.totalMonths,
    this.selected = true,
  });

  bool get isCompleted => paidMonths >= totalMonths;
}

class ParsedRegularRow {
  final DateTime opDate;
  final DateTime chargeDate;
  final String description;
  String? customName;
  final double amount;
  final bool isPayment; // '-' abono vs '+' cargo
  bool selected;

  ParsedRegularRow({
    required this.opDate,
    required this.chargeDate,
    required this.description,
    this.customName,
    required this.amount,
    this.isPayment = false,
    this.selected = true,
  });
}

class ParsedStatementResult {
  final ParsedStatementSummary summary;
  final List<ParsedMsiRow> msiRows;
  final List<ParsedRegularRow> regularRows;
  final List<String> reconstructedLines;

  const ParsedStatementResult({
    required this.summary,
    required this.msiRows,
    required this.regularRows,
    required this.reconstructedLines,
  });
}

class PdfStatementParser {
  static const Map<String, int> _esMonths = {
    'ene': 1, 'feb': 2, 'mar': 3, 'abr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'ago': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dic': 12,
  };

  static DateTime? parseDate(String s) {
    final esMatch = RegExp(r'(\d{1,2})[\-/]([a-zA-Z]{3})[\-/](\d{2,4})').firstMatch(s.trim());
    if (esMatch != null) {
      final d = int.tryParse(esMatch.group(1)!);
      final mo = _esMonths[esMatch.group(2)!.toLowerCase()];
      var y = int.tryParse(esMatch.group(3)!);
      if (d != null && mo != null && y != null) {
        if (y < 100) y += 2000;
        return DateTime(y, mo, d);
      }
    }
    final numMatch = RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})').firstMatch(s.trim());
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

  static DateTime shiftMonths(DateTime date, int deltaMonths) {
    final totalMonths = date.year * 12 + (date.month - 1) + deltaMonths;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = (totalMonths % 12) + 1;
    final maxDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = date.day > maxDay ? maxDay : date.day;
    return DateTime(targetYear, targetMonth, targetDay);
  }

  static DateTime subtractMonths(DateTime date, int months) =>
      shiftMonths(date, -months);

  static DateTime addMonths(DateTime date, int months) =>
      shiftMonths(date, months);

  static double? _parseMoney(String s) {
    final cleaned = s.replaceAll(RegExp(r'[\$\s,]'), '');
    return double.tryParse(cleaned);
  }

  /// Extracts visual rows from a PDF by grouping TextLines with matching Y coordinates.
  static List<String> extractVisualRowsFromPdf(Uint8List bytes) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    final List<String> allRows = [];

    for (int p = 0; p < document.pages.count; p++) {
      final List<TextLine> textLines = extractor.extractTextLines(startPageIndex: p, endPageIndex: p);
      if (textLines.isEmpty) continue;

      // Sort top-to-bottom first
      textLines.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

      // Group into horizontal rows (Y tolerance = 4.5 pts)
      final List<List<TextLine>> rowGroups = [];
      for (final tl in textLines) {
        if (tl.text.trim().isEmpty) continue;
        bool added = false;
        for (final group in rowGroups) {
          if ((group.first.bounds.top - tl.bounds.top).abs() <= 4.5) {
            group.add(tl);
            added = true;
            break;
          }
        }
        if (!added) {
          rowGroups.add([tl]);
        }
      }

      for (final group in rowGroups) {
        group.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
        final joined = group.map((e) => e.text.trim()).where((s) => s.isNotEmpty).join('  ');
        if (joined.isNotEmpty) {
          allRows.add(joined);
        }
      }
    }

    document.dispose();
    return allRows;
  }

  static ParsedStatementResult parseLines(List<String> lines) {
    String? cutoffDateStr;
    DateTime? cutoffDate;
    int? cutoffDay;
    String? dueDateStr;
    int? dueDay;
    double? paymentNoInterest;
    double? regularBalance;
    double? msiBalance;
    double? totalDebt;
    double? creditLimit;
    double? availableCredit;

    final List<ParsedMsiRow> msiRows = [];
    final List<ParsedRegularRow> regularRows = [];

    final dateRegex = RegExp(r'\b\d{1,2}[\-/](?:[a-zA-Z]{3}|\d{1,2})[\-/]\d{2,4}\b');
    final moneyRegex = RegExp(r'\$\s*([\d,]+\.\d{2})');

    for (final line in lines) {
      final lower = line.toLowerCase();

      // --- 1. Summary Fields ---
      if (lower.contains('fecha de corte') && cutoffDateStr == null) {
        final m = dateRegex.firstMatch(line);
        if (m != null) {
          cutoffDateStr = m.group(0);
          cutoffDate = parseDate(cutoffDateStr!);
          cutoffDay = cutoffDate?.day;
        }
      } else if ((lower.contains('fecha límite de pago') || lower.contains('fecha limite de pago')) && dueDateStr == null) {
        final m = dateRegex.firstMatch(line);
        if (m != null) {
          dueDateStr = m.group(0);
          dueDay = parseDate(dueDateStr!)?.day;
        }
      } else if (lower.contains('pago para no generar intereses') && paymentNoInterest == null) {
        final m = moneyRegex.firstMatch(line);
        if (m != null) paymentNoInterest = _parseMoney(m.group(1)!);
      } else if (lower.contains('saldo cargos regulares') && regularBalance == null) {
        final m = moneyRegex.firstMatch(line);
        if (m != null) regularBalance = _parseMoney(m.group(1)!);
      } else if (lower.contains('saldo cargos a meses') && msiBalance == null) {
        final m = moneyRegex.firstMatch(line);
        if (m != null) msiBalance = _parseMoney(m.group(1)!);
      } else if (lower.contains('saldo deudor total') && totalDebt == null) {
        final m = moneyRegex.firstMatch(line);
        if (m != null) totalDebt = _parseMoney(m.group(1)!);
      } else if ((lower.contains('límite de crédito') || lower.contains('limite de credito')) && creditLimit == null) {
        final m = moneyRegex.firstMatch(line);
        if (m != null) creditLimit = _parseMoney(m.group(1)!);
      } else if ((lower.contains('crédito disponible') || lower.contains('credito disponible')) && availableCredit == null) {
        final m = moneyRegex.firstMatch(line);
        if (m != null) availableCredit = _parseMoney(m.group(1)!);
      }

      // --- 2. Check for Transaction/MSI rows starting with a date ---
      final dates = dateRegex.allMatches(line).toList();
      if (dates.isEmpty) continue;

      final firstDateMatch = dates.first;
      if (firstDateMatch.start > 10) continue; // Dates in tables are at the start of the row

      final monies = moneyRegex.allMatches(line).toList();

      // Case A: Regular Charge/Payment row (2 dates at start: opDate, chargeDate + 1 money amount)
      if (dates.length >= 2 && monies.isNotEmpty) {
        final opDate = parseDate(dates[0].group(0)!);
        final chargeDate = parseDate(dates[1].group(0)!);
        if (opDate != null && chargeDate != null) {
          final lastMoney = monies.last;
          final amount = _parseMoney(lastMoney.group(1)!);
          if (amount != null && amount > 0) {
            final between = line.substring(dates[1].end, lastMoney.start).trim();
            final isPayment = between.endsWith('-') || between.contains('ABONO');
            final cleanDesc = between.replaceAll(RegExp(r'[+\-]\s*$'), '').trim();

            // Skip monthly MSI billing lines like "001 de 003" already in the MSI table
            if (RegExp(r'\b\d{3}\s+de\s+\d{3}\b', caseSensitive: false).hasMatch(cleanDesc)) {
              continue;
            }

            if (cleanDesc.isNotEmpty) {
              regularRows.add(ParsedRegularRow(
                opDate: opDate,
                chargeDate: chargeDate,
                description: cleanDesc,
                amount: amount,
                isPayment: isPayment,
                selected: true,
              ));
            }
          }
          continue;
        }
      }

      // Case B: MSI Table row (1 date at start + 3 money amounts + "X de Y")
      if (dates.length == 1 && monies.length >= 3) {
        final opDate = parseDate(firstDateMatch.group(0)!);
        final ratioMatch = RegExp(r'\b(\d{1,2})\s+de\s+(\d{1,2})\b', caseSensitive: false)
            .firstMatch(line.substring(monies[2].end));
        if (opDate != null && ratioMatch != null) {
          final orig = _parseMoney(monies[0].group(1)!) ?? 0.0;
          final pend = _parseMoney(monies[1].group(1)!) ?? 0.0;
          final req = _parseMoney(monies[2].group(1)!) ?? 0.0;
          final paid = int.tryParse(ratioMatch.group(1)!) ?? 0;
          final total = int.tryParse(ratioMatch.group(2)!) ?? 1;
          final desc = line.substring(firstDateMatch.end, monies[0].start).trim();

          if (orig > 0 && total >= 2 && desc.isNotEmpty) {
            // Banamex prints a recent cycle date (sometimes 1-5 days before cycleStart)
            // for carried-over MSI plans instead of their original purchase date.
            // Anchor the current installment inside the statement cycle before shifting
            // back by (paid - 1) months.
            DateTime originDate = opDate;
            if (paid >= 1) {
              if (cutoffDate == null) {
                originDate = paid > 1 ? subtractMonths(opDate, paid - 1) : opDate;
              } else {
                final cycleStart = subtractMonths(cutoffDate, 1);
                final windowStart = cycleStart.subtract(const Duration(days: 5));
                if (opDate.isAfter(windowStart) && !opDate.isAfter(cutoffDate)) {
                  final anchor = !opDate.isAfter(cycleStart)
                      ? cycleStart.add(const Duration(days: 1))
                      : opDate;
                  originDate = paid > 1 ? subtractMonths(anchor, paid - 1) : anchor;
                }
              }
            }

            msiRows.add(ParsedMsiRow(
              date: originDate,
              description: desc,
              originalAmount: orig,
              pendingBalance: pend,
              monthlyPayment: req,
              paidMonths: paid,
              totalMonths: total,
              selected: true,
            ));
          }
        }
      }
    }

    return ParsedStatementResult(
      summary: ParsedStatementSummary(
        cutoffDateStr: cutoffDateStr,
        cutoffDate: cutoffDate,
        cutoffDay: cutoffDay,
        dueDateStr: dueDateStr,
        dueDay: dueDay,
        paymentNoInterest: paymentNoInterest,
        regularBalance: regularBalance,
        msiBalance: msiBalance,
        totalDebt: totalDebt,
        creditLimit: creditLimit,
        availableCredit: availableCredit,
      ),
      msiRows: msiRows,
      regularRows: regularRows,
      reconstructedLines: lines,
    );
  }
}

