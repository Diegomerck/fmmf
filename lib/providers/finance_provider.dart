import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/budget_commitment.dart';
import '../models/savings_rule.dart';
import '../models/recurring_income.dart';
import '../models/credit_installment.dart';
import '../models/imported_statement.dart';
import '../models/movement_category.dart';
import '../services/storage_service.dart';
import '../services/advisor_engine.dart';

class FinanceProvider extends ChangeNotifier {
  final StorageService _storage;

  List<Account> _accounts = [];
  List<Transaction> _transactions = [];
  List<BudgetCommitment> _commitments = [];
  List<SavingsRule> _savingsRules = [];
  List<PendingTransfer> _pendingTransfers = [];
  List<RecurringIncome> _recurringIncomes = [];
  List<PendingIncome> _pendingIncomes = [];
  List<ScheduledPayOccurrence> _payOccurrences = [];
  List<CreditInstallmentPlan> _installmentPlans = [];
  List<ImportedStatement> _importedStatements = [];
  List<MovementCategory> _categories = [];
  Map<String, int> _categoryKeywordCounts = {};
  List<String> _fundingPriorityIds = [];
  int _emergencyFundMonths = 3;
  bool _emergencyFundEnabled = true;
  double _safetyCushion = 0.0;
  List<String> _surplusGoalOrder = const [
    'emergencyFund',
    'investAndGrow',
    'payDebtExtra',
  ];
  bool _includeExtraDebtGoal = false;

  AdvisorAnalysis? _analysis;

  FinanceProvider(this._storage) {
    loadData();
  }

  List<Account> get accounts => _accounts;
  List<Transaction> get transactions => _transactions;
  List<BudgetCommitment> get commitments => _commitments;
  List<SavingsRule> get savingsRules => _savingsRules;
  List<PendingTransfer> get pendingTransfers => _pendingTransfers;
  List<RecurringIncome> get recurringIncomes => _recurringIncomes;
  List<PendingIncome> get pendingIncomes => _pendingIncomes;
  List<ScheduledPayOccurrence> get payOccurrences => _payOccurrences;
  List<CreditInstallmentPlan> get installmentPlans => _installmentPlans;
  List<ImportedStatement> get importedStatements => _importedStatements;
  List<MovementCategory> get categories => _categories;
  List<MovementCategory> get expenseCategories =>
      _categories.where((c) => c.isExpense).toList();
  List<MovementCategory> get incomeCategories =>
      _categories.where((c) => c.isIncome).toList();
  List<String> get fundingPriorityIds => _fundingPriorityIds;
  int get emergencyFundMonths => _emergencyFundMonths;
  bool get emergencyFundEnabled => _emergencyFundEnabled;
  double get safetyCushion => _safetyCushion;
  List<String> get surplusGoalOrder => _surplusGoalOrder;
  bool get includeExtraDebtGoal => _includeExtraDebtGoal;

  /// Non-credit-card accounts included in general finances, ordered by user's funding priority.
  List<Account> get orderedFundingAccounts {
    final candidates = _accounts
        .where((a) => a.includeInGeneralFinances && a.type != AccountType.creditCard)
        .toList();
    final idxMap = <String, int>{
      for (int i = 0; i < _fundingPriorityIds.length; i++)
        _fundingPriorityIds[i]: i,
    };
    candidates.sort((a, b) {
      final aIdx = idxMap[a.id];
      final bIdx = idxMap[b.id];
      if (aIdx != null && bIdx != null) return aIdx.compareTo(bIdx);
      if (aIdx != null) return -1;
      if (bIdx != null) return 1;
      int defaultRank(Account acc) {
        if (acc.purpose == AccountPurpose.debtPayment ||
            acc.purpose == AccountPurpose.fixedExpenses) {
          return 0;
        }
        if (acc.purpose == AccountPurpose.general) return 1;
        if (acc.type == AccountType.investment) return 3;
        return 2;
      }

      final r = defaultRank(a).compareTo(defaultRank(b));
      if (r != 0) return r;
      return b.balance.compareTo(a.balance);
    });
    return candidates;
  }

  MovementCategory? categoryByName(String name, {bool? isIncome}) {
    final normalized = name.trim().toLowerCase();
    for (final cat in _categories) {
      if (isIncome == true && !cat.isIncome) continue;
      if (isIncome == false && !cat.isExpense) continue;
      if (cat.name.trim().toLowerCase() == normalized) return cat;
    }
    for (final cat in _categories) {
      if (cat.name.trim().toLowerCase() == normalized) return cat;
    }
    return null;
  }

  /// Matches a movement description against user-configured & auto-learned category keywords.
  /// Prefers the longest matching keyword so multi-word phrases (e.g. "uber eats") win over shorter ones.
  MovementCategory? matchCategoryByKeywords(String description, {bool? isIncome}) {
    final normalizedDesc = MovementCategory.normalizeText(description);
    if (normalizedDesc.isEmpty) return null;

    MovementCategory? bestCategory;
    int bestLength = 0;

    for (final cat in _categories) {
      if (isIncome == true && !cat.isIncome) continue;
      if (isIncome == false && !cat.isExpense) continue;
      for (final rawKw in cat.keywords) {
        final kw = MovementCategory.normalizeText(rawKw);
        if (kw.isEmpty) continue;
        final pattern = RegExp('(^|[^a-z0-9])${RegExp.escape(kw)}([^a-z0-9]|\$)');
        if (pattern.hasMatch(normalizedDesc) && kw.length > bestLength) {
          bestLength = kw.length;
          bestCategory = cat;
        }
      }
    }
    return bestCategory;
  }

  List<ScheduledPayOccurrence> getOccurrencesForIncome(String incomeId) {
    final list = _payOccurrences.where((o) => o.incomeId == incomeId).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  List<ScheduledPayOccurrence> get duePayOccurrences {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final list = _payOccurrences
        .where((o) => o.status == PayOccurrenceStatus.projected && !o.date.isAfter(endOfToday))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
  AdvisorAnalysis get analysis =>
      _analysis ??
      AdvisorEngine.analyze(
        accounts: _accounts,
        transactions: _transactions,
        commitments: _commitments,
        installmentPlans: _installmentPlans,
      );

  void loadData() {
    _accounts = _storage.loadAccounts();
    final defaultHexCount = _accounts.where((a) => a.colorHex.toUpperCase() == '#10B981').length;
    if (defaultHexCount > 1) {
      _accounts = [
        for (int i = 0; i < _accounts.length; i++)
          _accounts[i].copyWith(
            colorHex: Account.colorPaletteHex[i % Account.colorPaletteHex.length],
          ),
      ];
      _storage.saveAccounts(_accounts);
    }
    _transactions = _storage.loadTransactions();
    _commitments = _storage.loadCommitments();
    _savingsRules = _storage.loadSavingsRules();
    _pendingTransfers = _storage.loadPendingTransfers();
    _recurringIncomes = _storage.loadRecurringIncomes();
    _pendingIncomes = _storage.loadPendingIncomes();
    _payOccurrences = _storage.loadPayOccurrences();
    _installmentPlans = _storage.loadInstallmentPlans();
    _importedStatements = _storage.loadImportedStatements();
    _categories = _storage.loadCategories();
    if (_categories.isEmpty) {
      _categories = MovementCategory.defaultCategories();
      _storage.saveCategories(_categories);
    }
    _categoryKeywordCounts = _storage.loadCategoryKeywordCounts();
    _fundingPriorityIds = _storage.loadFundingPriorityIds();
    _emergencyFundMonths = _storage.loadEmergencyFundMonths();
    _emergencyFundEnabled = _storage.loadEmergencyFundEnabled();
    _safetyCushion = _storage.loadSafetyCushion();
    _surplusGoalOrder = _storage.loadSurplusGoalOrder();
    _includeExtraDebtGoal = _storage.loadIncludeExtraDebtGoal();

    // Remove any legacy pending transfers mistakenly triggered by credit card payments/abonos
    final beforePtCount = _pendingTransfers.length;
    _pendingTransfers.removeWhere((pt) {
      if (pt.sourceTransactionId == null) return false;
      final srcTx = _transactions.where((t) => t.id == pt.sourceTransactionId).firstOrNull;
      if (srcTx == null) return false;
      if (srcTx.category == 'Pago Tarjeta') return true;
      final srcAcc = _accounts.where((a) => a.id == srcTx.accountId).firstOrNull;
      return srcAcc?.type == AccountType.creditCard;
    });
    if (_pendingTransfers.length != beforePtCount) {
      _storage.savePendingTransfers(_pendingTransfers);
    }

    for (final inc in _recurringIncomes) {
      _ensureAnnualScheduleForIncome(inc);
    }
    evaluatePeriodicRules();
    _recalculate();
  }

  void _recalculate() {
    _analysis = AdvisorEngine.analyze(
      accounts: _accounts,
      transactions: _transactions,
      commitments: _commitments,
      installmentPlans: _installmentPlans,
      recurringIncomes: _recurringIncomes,
      scheduledOccurrences: _payOccurrences,
      fundingPriorityIds: _fundingPriorityIds,
      emergencyFundMonths: _emergencyFundMonths,
      emergencyFundEnabled: _emergencyFundEnabled,
      safetyCushion: _safetyCushion,
    );
    notifyListeners();
  }

  // --- ADD TRANSACTION WITH SMART ACCOUNT BALANCE UPDATE ---
  Future<String> addTransaction({
    required String title,
    required double amount,
    required MovementType type,
    required String category,
    required String accountId,
    String? targetAccountId,
    DateTime? date,
    DateTime? billingDate,
    String? note,
    String? linkedOccurrenceId,
    String? sourceTransactionId,
    String? savingsRuleId,
    bool skipBalanceUpdate = false,
    bool triggerSavingsRules = true,
  }) async {
    final newTx = Transaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      amount: amount,
      type: type,
      category: category,
      accountId: accountId,
      targetAccountId: targetAccountId,
      date: date ?? DateTime.now(),
      billingDate: billingDate,
      balanceApplied: !skipBalanceUpdate,
      note: note,
      linkedOccurrenceId: linkedOccurrenceId,
      sourceTransactionId: sourceTransactionId,
      savingsRuleId: savingsRuleId,
    );

    _transactions.insert(0, newTx);

    // Update account balances unless this is a historical record already reflected in current balance
    if (!skipBalanceUpdate) {
      _accounts = _accounts.map((acc) {
        if (acc.id == accountId) {
          if (acc.type == AccountType.creditCard) {
            // If paying with credit card, debt increases on expense, decreases on income/payment
            if (type == MovementType.expense) {
              return acc.copyWith(balance: acc.balance + amount);
            } else if (type == MovementType.income) {
              return acc.copyWith(balance: (acc.balance - amount).clamp(0.0, double.infinity));
            }
          } else {
            // Normal bank/cash account
            if (type == MovementType.expense) {
              return acc.copyWith(balance: acc.balance - amount);
            } else if (type == MovementType.income || type == MovementType.yieldAccrual) {
              return acc.copyWith(balance: acc.balance + amount);
            } else if (type == MovementType.transfer) {
              return acc.copyWith(balance: acc.balance - amount);
            }
          }
        } else if (acc.id == targetAccountId && type == MovementType.transfer) {
          if (acc.type == AccountType.creditCard) {
            // Paying a credit card reduces its utilized debt
            return acc.copyWith(balance: (acc.balance - amount).clamp(0.0, double.infinity));
          }
          return acc.copyWith(balance: acc.balance + amount);
        }
        return acc;
      }).toList();
    }

    await _storage.saveTransactions(_transactions);
    await _storage.saveAccounts(_accounts);

    // Trigger income-based savings routing rules (never on credit card abonos/payments)
    final txAccount = _accounts.where((a) => a.id == accountId).firstOrNull;
    final isCreditCardPayment =
        txAccount?.type == AccountType.creditCard || category == 'Pago Tarjeta';
    if (triggerSavingsRules &&
        !isCreditCardPayment &&
        type == MovementType.income &&
        amount > 0) {
      bool addedPending = false;
      for (final rule in _savingsRules) {
        if (!rule.isActive || rule.frequency != RoutingFrequency.onIncome) continue;
        if (rule.sourceAccountId != null && rule.sourceAccountId != accountId) continue;
        final sourceId = rule.sourceAccountId ?? accountId;
        final targetExists = _accounts.any((a) => a.id == rule.targetAccountId);
        final sourceExists = _accounts.any((a) => a.id == sourceId);
        if (!targetExists || !sourceExists || sourceId == rule.targetAccountId) continue;

        final suggested = amount * (rule.percentage / 100.0);
        if (suggested > 0) {
          _pendingTransfers.insert(
            0,
            PendingTransfer(
              id: 'pt_${DateTime.now().millisecondsSinceEpoch}_${rule.id}',
              ruleId: rule.id,
              ruleName: rule.name,
              sourceAccountId: sourceId,
              targetAccountId: rule.targetAccountId,
              suggestedAmount: suggested,
              reason: '${rule.percentage.toStringAsFixed(0)}% de "$title"',
              createdAt: DateTime.now(),
              sourceTransactionId: newTx.id,
            ),
          );
          addedPending = true;
        }
      }
      if (addedPending) {
        await _storage.savePendingTransfers(_pendingTransfers);
      }
    }

    _recalculate();
    return newTx.id;
  }

  // --- SMART NATURAL QUICK-ENTRY PARSER ---
  /// Allows instant data logging:
  /// Examples:
  /// - "250 Tacos Nu"
  /// - "45 Cafe"
  /// - "18500 Sueldo BBVA"
  /// - "$120 Uber"
  Future<bool> parseAndAddQuickEntry(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _accounts.isEmpty) return false;

    // Regular expression to extract amount: matches optional $, decimals, commas
    final amountRegex = RegExp(r'^\$?(\d+(?:\.\d+)?|\d+(?:,\d{3})*(?:\.\d+)?)\s*(.*)$');
    final match = amountRegex.firstMatch(trimmed);

    if (match == null) return false;

    final amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
    final double? parsedAmount = double.tryParse(amountStr);
    if (parsedAmount == null || parsedAmount <= 0) return false;

    final remainder = (match.group(2) ?? '').trim();
    final tokens = remainder.split(RegExp(r'\s+'));

    // Determine target account by searching keywords
    Account? matchedAccount;
    for (final acc in _accounts) {
      final nameLower = acc.name.toLowerCase();
      final instLower = acc.institution.toLowerCase();
      for (final t in tokens) {
        final tLower = t.toLowerCase();
        if (tLower.length >= 2 && (nameLower.contains(tLower) || instLower.contains(tLower))) {
          matchedAccount = acc;
          break;
        }
      }
      if (matchedAccount != null) break;
    }

    // Default account fallback
    final targetAccount = matchedAccount ??
        _accounts.firstWhere(
          (a) => a.type == AccountType.checking || a.type == AccountType.cash,
          orElse: () => _accounts.first,
        );

    // Remove account name token from title if matched
    final titleTokens = tokens.where((t) {
      final tLower = t.toLowerCase();
      if (matchedAccount != null) {
        if (matchedAccount.name.toLowerCase().contains(tLower) ||
            matchedAccount.institution.toLowerCase().contains(tLower)) {
          return false;
        }
      }
      return true;
    }).toList();

    String title = titleTokens.join(' ').trim();
    if (title.isEmpty) title = 'Gasto Rápido';

    // Guess category and movement type
    final titleLower = title.toLowerCase();
    MovementType type = MovementType.expense;
    String category = 'Varios';

    final matchedExpenseCat = matchCategoryByKeywords(title, isIncome: false);
    final matchedIncomeCat = matchCategoryByKeywords(title, isIncome: true);

    if (matchedIncomeCat != null && matchedExpenseCat == null) {
      type = MovementType.income;
      category = matchedIncomeCat.name;
    } else if (matchedExpenseCat != null) {
      type = MovementType.expense;
      category = matchedExpenseCat.name;
    } else if (titleLower.contains('sueldo') ||
        titleLower.contains('nómina') ||
        titleLower.contains('nomina') ||
        titleLower.contains('ingreso') ||
        titleLower.contains('pago') && parsedAmount > 3000) {
      type = MovementType.income;
      category = 'Ingreso';
    } else if (titleLower.contains('taco') ||
        titleLower.contains('comida') ||
        titleLower.contains('cena') ||
        titleLower.contains('cafe') ||
        titleLower.contains('café') ||
        titleLower.contains('restaurante') ||
        titleLower.contains('pizza')) {
      category = 'Comida';
    } else if (titleLower.contains('uber') ||
        titleLower.contains('didi') ||
        titleLower.contains('gasolina') ||
        titleLower.contains('metro') ||
        titleLower.contains('caseta')) {
      category = 'Transporte';
    } else if (titleLower.contains('super') ||
        titleLower.contains('walmart') ||
        titleLower.contains('oxxo') ||
        titleLower.contains('costco') ||
        titleLower.contains('chedraui')) {
      category = 'Supermercado';
    } else if (titleLower.contains('luz') ||
        titleLower.contains('agua') ||
        titleLower.contains('internet') ||
        titleLower.contains('gas')) {
      category = 'Servicios';
    } else if (titleLower.contains('cine') ||
        titleLower.contains('netflix') ||
        titleLower.contains('spotify') ||
        titleLower.contains('fiesta')) {
      category = 'Entretenimiento';
    }

    await addTransaction(
      title: title,
      amount: parsedAmount,
      type: type,
      category: category,
      accountId: targetAccount.id,
      date: DateTime.now(),
    );

    return true;
  }

  // --- ACCOUNTS MANAGEMENT ---
  Future<void> addAccount(Account account) async {
    _accounts.add(account);
    await _storage.saveAccounts(_accounts);
    _recalculate();
  }

  Future<void> updateAccount(Account updated) async {
    _accounts = _accounts.map((a) => a.id == updated.id ? updated : a).toList();
    await _storage.saveAccounts(_accounts);
    _recalculate();
  }

  Future<void> deleteAccount(String accountId) async {
    _accounts.removeWhere((a) => a.id == accountId);
    await _storage.saveAccounts(_accounts);
    _recalculate();
  }

  /// Records a confirmed pay-stub contribution to a Fondo de Ahorro / locked fund
  /// without touching bank liquidity (already deducted from gross payroll).
  Future<void> addSavingsFundContribution(String accountId, double amount) async {
    if (amount <= 0) return;
    final idx = _accounts.indexWhere((a) => a.id == accountId);
    if (idx == -1) return;
    final acc = _accounts[idx];
    _accounts[idx] = acc.copyWith(balance: acc.balance + amount);
    await _storage.saveAccounts(_accounts);
    _recalculate();
  }

  /// Liberates a Fondo de Ahorro: multiplies accumulated balance by [contributionMultiplier],
  /// deposits the total into [targetAccountId] (or [acc.releaseTargetAccountId]),
  /// and resets the fund balance to 0 for the next cycle.
  Future<void> releaseSavingsFund(String accountId, {String? targetAccountId}) async {
    final idx = _accounts.indexWhere((a) => a.id == accountId);
    if (idx == -1) return;
    final acc = _accounts[idx];
    final payout = acc.projectedReleaseAmount;
    final destId = targetAccountId ?? acc.releaseTargetAccountId;

    _accounts[idx] = acc.copyWith(balance: 0.0);
    await _storage.saveAccounts(_accounts);

    if (destId != null && payout > 0 && _accounts.any((a) => a.id == destId)) {
      await addTransaction(
        title: 'Liberación ${acc.name}',
        amount: payout,
        type: MovementType.income,
        category: 'Fondo de Ahorro',
        accountId: destId,
        date: DateTime.now(),
        triggerSavingsRules: false,
      );
    } else {
      _recalculate();
    }
  }

  /// Estimates average monthly spending for a category over up to the last 90 days.
  double averageMonthlySpendForCategory(String categoryName) {
    final target = categoryName.trim().toLowerCase();
    if (target.isEmpty) return 0.0;
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 90));
    final matching = _transactions.where((t) =>
        t.type == MovementType.expense &&
        t.category.trim().toLowerCase() == target &&
        !t.date.isBefore(cutoff)).toList();
    if (matching.isEmpty) return 0.0;
    final total = matching.fold<double>(0.0, (s, t) => s + t.amount);
    final earliest = matching.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final spanDays = now.difference(earliest).inDays.clamp(1, 90);
    final months = (spanDays / 30.0).clamp(1.0, 3.0);
    return total / months;
  }

  Future<void> renameOrMergeBank(String fromBank, String toBank) async {
    final target = toBank.trim();
    if (target.isEmpty) return;
    final fromLower = fromBank.trim().toLowerCase();

    _accounts = _accounts.map((a) {
      final current = a.institution.trim();
      final matches = current.toLowerCase() == fromLower ||
          (fromLower == 'personal' && current.isEmpty);
      return matches ? a.copyWith(institution: target) : a;
    }).toList();

    await _storage.saveAccounts(_accounts);
    _recalculate();
  }

  // --- TRANSACTION MANAGEMENT ---
  Future<void> updateTransaction(Transaction updated) async {
    final idx = _transactions.indexWhere((t) => t.id == updated.id);
    if (idx == -1) return;
    final old = _transactions[idx];
    _transactions[idx] = updated;

    final diff = updated.amount - old.amount;
    if (old.balanceApplied && diff.abs() > 0.0001) {
      _accounts = _accounts.map((acc) {
        if (acc.id == updated.accountId) {
          if (acc.type == AccountType.creditCard) {
            if (updated.type == MovementType.expense) {
              return acc.copyWith(balance: (acc.balance + diff).clamp(0.0, double.infinity));
            } else if (updated.type == MovementType.income) {
              return acc.copyWith(balance: (acc.balance - diff).clamp(0.0, double.infinity));
            }
          } else {
            if (updated.type == MovementType.expense || updated.type == MovementType.transfer) {
              return acc.copyWith(balance: acc.balance - diff);
            } else if (updated.type == MovementType.income || updated.type == MovementType.yieldAccrual) {
              return acc.copyWith(balance: acc.balance + diff);
            }
          }
        } else if (acc.id == updated.targetAccountId && updated.type == MovementType.transfer) {
          if (acc.type == AccountType.creditCard) {
            return acc.copyWith(balance: (acc.balance - diff).clamp(0.0, double.infinity));
          }
          return acc.copyWith(balance: acc.balance + diff);
        }
        return acc;
      }).toList();
      await _storage.saveAccounts(_accounts);
    }

    await _storage.saveTransactions(_transactions);
    _recalculate();
  }

  Future<void> deleteTransaction(String txId) async {
    final idx = _transactions.indexWhere((t) => t.id == txId);
    if (idx == -1) return;
    final tx = _transactions[idx];
    _transactions.removeAt(idx);

    // Revert balance change on the account only if it was applied
    if (tx.balanceApplied) {
      _accounts = _accounts.map((acc) {
        if (acc.id == tx.accountId) {
          if (acc.type == AccountType.creditCard) {
            if (tx.type == MovementType.expense) {
              return acc.copyWith(balance: (acc.balance - tx.amount).clamp(0.0, double.infinity));
            } else if (tx.type == MovementType.income) {
              return acc.copyWith(balance: acc.balance + tx.amount);
            }
          } else {
            if (tx.type == MovementType.expense || tx.type == MovementType.transfer) {
              return acc.copyWith(balance: acc.balance + tx.amount);
            } else if (tx.type == MovementType.income || tx.type == MovementType.yieldAccrual) {
              return acc.copyWith(balance: acc.balance - tx.amount);
            }
          }
        } else if (acc.id == tx.targetAccountId && tx.type == MovementType.transfer) {
          return acc.copyWith(balance: acc.balance - tx.amount);
        }
        return acc;
      }).toList();
    }

    await _storage.saveTransactions(_transactions);
    await _storage.saveAccounts(_accounts);

    // Un-confirm any linked pay occurrence
    bool occChanged = false;
    _payOccurrences = _payOccurrences.map((o) {
      if (o.id == tx.linkedOccurrenceId || o.linkedTransactionId == tx.id) {
        occChanged = true;
        return o.copyWith(status: PayOccurrenceStatus.projected, clearLinkedTransaction: true);
      }
      return o;
    }).toList();
    if (occChanged) {
      await _storage.savePayOccurrences(_payOccurrences);
    }

    // Remove any still-pending transfers spawned by this transaction
    final beforePt = _pendingTransfers.length;
    _pendingTransfers.removeWhere((p) => p.sourceTransactionId == tx.id);
    if (_pendingTransfers.length != beforePt) {
      await _storage.savePendingTransfers(_pendingTransfers);
    }

    // Also delete any already-confirmed savings transfers spawned by this transaction
    final childTransferIds = _transactions
        .where((t) => t.sourceTransactionId == tx.id)
        .map((t) => t.id)
        .toList();
    for (final childId in childTransferIds) {
      await deleteTransaction(childId);
    }

    _recalculate();
  }

  // --- COMMITMENT ACTIONS ---
  Future<void> addCommitment(BudgetCommitment commitment) async {
    _commitments.add(commitment);
    await _storage.saveCommitments(_commitments);
    _recalculate();
  }

  Future<void> updateCommitment(BudgetCommitment updated) async {
    _commitments = _commitments.map((c) => c.id == updated.id ? updated : c).toList();
    await _storage.saveCommitments(_commitments);
    _recalculate();
  }

  Future<void> deleteCommitment(String commitmentId) async {
    _commitments.removeWhere((c) => c.id == commitmentId);
    await _storage.saveCommitments(_commitments);
    _recalculate();
  }

  Future<void> toggleCommitmentPaid(String commitmentId) async {
    _commitments = _commitments.map((c) {
      if (c.id == commitmentId) {
        return c.copyWith(isPaidThisMonth: !c.isPaidThisMonth);
      }
      return c;
    }).toList();

    await _storage.saveCommitments(_commitments);
    _recalculate();
  }

  // --- SAVINGS ROUTING RULES & PENDING TRANSFERS ---
  void evaluatePeriodicRules() {
    final now = DateTime.now();
    bool rulesChanged = false;
    bool pendingChanged = false;

    _savingsRules = _savingsRules.map((rule) {
      if (!rule.isActive || rule.frequency == RoutingFrequency.onIncome || rule.fixedAmount <= 0) {
        return rule;
      }

      final sourceId = rule.sourceAccountId;
      if (sourceId == null ||
          !_accounts.any((a) => a.id == sourceId) ||
          !_accounts.any((a) => a.id == rule.targetAccountId)) {
        return rule;
      }

      bool isDue = false;
      final last = rule.lastTriggeredAt;
      if (last == null) {
        isDue = true;
      } else {
        switch (rule.frequency) {
          case RoutingFrequency.daily:
            isDue = last.year != now.year || last.month != now.month || last.day != now.day;
            break;
          case RoutingFrequency.weekly:
            isDue = now.difference(last).inDays >= 7;
            break;
          case RoutingFrequency.monthly:
            isDue = last.year != now.year || last.month != now.month;
            break;
          case RoutingFrequency.yearly:
            isDue = last.year != now.year;
            break;
          case RoutingFrequency.onIncome:
            break;
        }
      }

      if (isDue) {
        final periodLabel = switch (rule.frequency) {
          RoutingFrequency.daily => 'Ahorro diario',
          RoutingFrequency.weekly => 'Ahorro semanal',
          RoutingFrequency.monthly => 'Ahorro mensual',
          RoutingFrequency.yearly => 'Ahorro anual',
          RoutingFrequency.onIncome => '',
        };
        _pendingTransfers.insert(
          0,
          PendingTransfer(
            id: 'pt_${now.millisecondsSinceEpoch}_${rule.id}',
            ruleId: rule.id,
            ruleName: rule.name,
            sourceAccountId: sourceId,
            targetAccountId: rule.targetAccountId,
            suggestedAmount: rule.fixedAmount,
            reason: periodLabel,
            createdAt: now,
          ),
        );
        rulesChanged = true;
        pendingChanged = true;
        return rule.copyWith(lastTriggeredAt: now);
      }

      return rule;
    }).toList();

    if (rulesChanged) _storage.saveSavingsRules(_savingsRules);
    if (pendingChanged) _storage.savePendingTransfers(_pendingTransfers);
  }

  Future<void> addSavingsRule(SavingsRule rule) async {
    _savingsRules.add(rule);
    await _storage.saveSavingsRules(_savingsRules);
    evaluatePeriodicRules();
    _recalculate();
  }

  Future<void> updateSavingsRule(SavingsRule updated) async {
    _savingsRules = _savingsRules.map((r) => r.id == updated.id ? updated : r).toList();
    await _storage.saveSavingsRules(_savingsRules);
    evaluatePeriodicRules();
    _recalculate();
  }

  Future<void> deleteSavingsRule(String ruleId) async {
    _savingsRules.removeWhere((r) => r.id == ruleId);
    _pendingTransfers.removeWhere((p) => p.ruleId == ruleId);
    await _storage.saveSavingsRules(_savingsRules);
    await _storage.savePendingTransfers(_pendingTransfers);
    _recalculate();
  }

  Future<void> confirmPendingTransfer(String pendingId, {double? customAmount}) async {
    final idx = _pendingTransfers.indexWhere((p) => p.id == pendingId);
    if (idx == -1) return;
    final pending = _pendingTransfers[idx];
    final amountToMove = customAmount ?? pending.suggestedAmount;

    _pendingTransfers.removeAt(idx);
    await _storage.savePendingTransfers(_pendingTransfers);

    if (amountToMove > 0) {
      await addTransaction(
        title: 'Ahorro: ${pending.ruleName}',
        amount: amountToMove,
        type: MovementType.transfer,
        category: 'Ahorro',
        accountId: pending.sourceAccountId,
        targetAccountId: pending.targetAccountId,
        note: pending.reason,
        sourceTransactionId: pending.sourceTransactionId,
        savingsRuleId: pending.ruleId,
      );
    } else {
      _recalculate();
    }
  }

  Future<void> skipPendingTransfer(String pendingId) async {
    _pendingTransfers.removeWhere((p) => p.id == pendingId);
    await _storage.savePendingTransfers(_pendingTransfers);
    _recalculate();
  }

  // --- RECURRING INCOMES ---
  void evaluateScheduledIncomes() {
    final now = DateTime.now();
    bool incomesChanged = false;
    bool pendingChanged = false;

    _recurringIncomes = _recurringIncomes.map((inc) {
      if (!inc.isActive || inc.amount <= 0) return inc;
      if (!_accounts.any((a) => a.id == inc.accountId)) return inc;
      if (_pendingIncomes.any((p) => p.incomeId == inc.id)) return inc;

      bool isDue = false;
      final last = inc.lastLoggedAt;
      final expectedDay = inc.payDay.clamp(1, 31);

      switch (inc.frequency) {
        case IncomeFrequency.monthly:
          if (now.day >= expectedDay &&
              (last == null || last.year != now.year || last.month != now.month)) {
            isDue = true;
          }
          break;
        case IncomeFrequency.biweekly:
          if (last == null) {
            // If never logged and payDay has already arrived this month (or any day if payDay <= now.day)
            if (now.day >= expectedDay) isDue = true;
          } else {
            final bool sameMonth = last.year == now.year && last.month == now.month;
            final bool lastInFirstHalf = last.day <= 15;
            final bool nowInSecondHalf = now.day > 15;
            if (!sameMonth || (lastInFirstHalf && nowInSecondHalf) || now.difference(last).inDays >= 14) {
              isDue = true;
            }
          }
          break;
        case IncomeFrequency.weekly:
          if (last == null || now.difference(last).inDays >= 7) {
            isDue = true;
          }
          break;
        case IncomeFrequency.daily:
          if (last == null || last.year != now.year || last.month != now.month || last.day != now.day) {
            isDue = true;
          }
          break;
        case IncomeFrequency.yearly:
          if (last == null || last.year != now.year) {
            isDue = true;
          }
          break;
        case IncomeFrequency.custom:
          break;
      }

      if (isDue) {
        _pendingIncomes.insert(
          0,
          PendingIncome(
            id: 'pi_${now.millisecondsSinceEpoch}_${inc.id}',
            incomeId: inc.id,
            name: inc.name,
            accountId: inc.accountId,
            suggestedAmount: inc.amount,
            category: inc.category,
            expectedDate: DateTime(now.year, now.month, expectedDay),
            reason: 'Pago programado (Día $expectedDay) — confirma si lo recibiste',
          ),
        );
        incomesChanged = true;
        pendingChanged = true;
        return inc.copyWith(lastLoggedAt: now);
      }

      return inc;
    }).toList();

    if (incomesChanged) _storage.saveRecurringIncomes(_recurringIncomes);
    if (pendingChanged) _storage.savePendingIncomes(_pendingIncomes);
  }

  void _ensureAnnualScheduleForIncome(RecurringIncome inc, {List<DateTime>? customDates}) {
    final existing = _payOccurrences.where((o) => o.incomeId == inc.id).toList();
    if (existing.isNotEmpty && customDates == null) return;

    if (customDates != null) {
      // Replace projected occurrences with custom dates while preserving confirmed/skipped history
      _payOccurrences.removeWhere(
        (o) => o.incomeId == inc.id && o.status == PayOccurrenceStatus.projected,
      );
    }

    final now = DateTime.now();
    final List<ScheduledPayOccurrence> generated = [];

    if (inc.frequency == IncomeFrequency.custom && customDates != null) {
      for (final d in customDates) {
        final normalized = DateTime(d.year, d.month, d.day);
        final alreadyExists = _payOccurrences.any(
          (o) =>
              o.incomeId == inc.id &&
              o.date.year == normalized.year &&
              o.date.month == normalized.month &&
              o.date.day == normalized.day,
        );
        if (!alreadyExists) {
          generated.add(ScheduledPayOccurrence(
            id: 'occ_${inc.id}_${normalized.year}_${normalized.month}_${normalized.day}',
            incomeId: inc.id,
            date: normalized,
            amount: inc.amount,
          ));
        }
      }
    } else if (inc.frequency == IncomeFrequency.daily) {
      // Next 30 days
      DateTime cursor = DateTime(now.year, now.month, now.day);
      for (int i = 0; i < 30; i++) {
        generated.add(ScheduledPayOccurrence(
          id: 'occ_${inc.id}_${cursor.year}_${cursor.month}_${cursor.day}',
          incomeId: inc.id,
          date: cursor,
          amount: inc.amount,
        ));
        cursor = cursor.add(const Duration(days: 1));
      }
    } else if (inc.frequency == IncomeFrequency.biweekly) {
      // Generate 12 months (24 quincenas) starting from current month
      for (int mOffset = 0; mOffset < 12; mOffset++) {
        final targetMonthDate = DateTime(now.year, now.month + mOffset, 1);
        final daysInMonth = DateTime(targetMonthDate.year, targetMonthDate.month + 1, 0).day;
        final q1Day = inc.payDay.clamp(1, 15);
        final q2Day = daysInMonth;

        final d1 = DateTime(targetMonthDate.year, targetMonthDate.month, q1Day);
        final d2 = DateTime(targetMonthDate.year, targetMonthDate.month, q2Day);

        generated.add(ScheduledPayOccurrence(
          id: 'occ_${inc.id}_${d1.year}_${d1.month}_${d1.day}',
          incomeId: inc.id,
          date: d1,
          amount: inc.amount,
        ));
        generated.add(ScheduledPayOccurrence(
          id: 'occ_${inc.id}_${d2.year}_${d2.month}_${d2.day}',
          incomeId: inc.id,
          date: d2,
          amount: inc.amount,
        ));
      }
    } else if (inc.frequency == IncomeFrequency.monthly) {
      for (int mOffset = 0; mOffset < 12; mOffset++) {
        final targetMonthDate = DateTime(now.year, now.month + mOffset, 1);
        final daysInMonth = DateTime(targetMonthDate.year, targetMonthDate.month + 1, 0).day;
        final day = inc.payDay.clamp(1, daysInMonth);
        final d = DateTime(targetMonthDate.year, targetMonthDate.month, day);
        generated.add(ScheduledPayOccurrence(
          id: 'occ_${inc.id}_${d.year}_${d.month}_${d.day}',
          incomeId: inc.id,
          date: d,
          amount: inc.amount,
        ));
      }
    } else if (inc.frequency == IncomeFrequency.yearly) {
      for (int yOffset = 0; yOffset < 2; yOffset++) {
        final d = DateTime(now.year + yOffset, now.month, inc.payDay.clamp(1, 28));
        generated.add(ScheduledPayOccurrence(
          id: 'occ_${inc.id}_${d.year}_${d.month}_${d.day}',
          incomeId: inc.id,
          date: d,
          amount: inc.amount,
        ));
      }
    } else if (inc.frequency == IncomeFrequency.weekly) {
      DateTime cursor = DateTime(now.year, now.month, now.day);
      for (int w = 0; w < 52; w++) {
        generated.add(ScheduledPayOccurrence(
          id: 'occ_${inc.id}_${cursor.year}_${cursor.month}_${cursor.day}',
          incomeId: inc.id,
          date: cursor,
          amount: inc.amount,
        ));
        cursor = cursor.add(const Duration(days: 7));
      }
    }

    _payOccurrences.addAll(generated);
    _storage.savePayOccurrences(_payOccurrences);
  }

  Future<void> addRecurringIncome(RecurringIncome income, {List<DateTime>? customDates}) async {
    _recurringIncomes.add(income);
    await _storage.saveRecurringIncomes(_recurringIncomes);
    _ensureAnnualScheduleForIncome(income, customDates: customDates);
    _recalculate();
  }

  Future<void> updateRecurringIncome(RecurringIncome updated, {List<DateTime>? customDates}) async {
    _recurringIncomes = _recurringIncomes.map((i) => i.id == updated.id ? updated : i).toList();
    await _storage.saveRecurringIncomes(_recurringIncomes);
    _ensureAnnualScheduleForIncome(updated, customDates: customDates);
    _recalculate();
  }

  Future<void> deleteRecurringIncome(String incomeId) async {
    _recurringIncomes.removeWhere((i) => i.id == incomeId);
    _pendingIncomes.removeWhere((p) => p.incomeId == incomeId);
    _payOccurrences.removeWhere((o) => o.incomeId == incomeId);
    await _storage.saveRecurringIncomes(_recurringIncomes);
    await _storage.savePendingIncomes(_pendingIncomes);
    await _storage.savePayOccurrences(_payOccurrences);
    _recalculate();
  }

  Future<void> updatePayOccurrence(ScheduledPayOccurrence updated) async {
    final idx = _payOccurrences.indexWhere((o) => o.id == updated.id);
    if (idx == -1) return;
    final oldOcc = _payOccurrences[idx];
    var finalUpdated = updated;

    // If this occurrence was already confirmed, propagate changes to the linked transaction, account balance, and pending transfers
    if (finalUpdated.status == PayOccurrenceStatus.confirmed) {
      final inc = _recurringIncomes.where((i) => i.id == finalUpdated.incomeId).firstOrNull;
      int txIdx = -1;

      if (oldOcc.linkedTransactionId != null) {
        txIdx = _transactions.indexWhere((t) => t.id == oldOcc.linkedTransactionId);
      } else if (inc != null) {
        // Fallback for legacy occurrences confirmed before linking was added
        txIdx = _transactions.indexWhere(
          (t) =>
              t.type == MovementType.income &&
              t.accountId == inc.accountId &&
              t.title.startsWith(inc.name),
        );
      }

      if (txIdx != -1) {
        final oldTx = _transactions[txIdx];
        final delta = finalUpdated.amount - oldTx.amount;
        final newTitle = inc != null
            ? (finalUpdated.note != null && finalUpdated.note!.isNotEmpty
                ? '${inc.name} (${finalUpdated.note})'
                : inc.name)
            : oldTx.title;

        _transactions[txIdx] = oldTx.copyWith(
          title: newTitle,
          amount: finalUpdated.amount,
          date: finalUpdated.date,
          linkedOccurrenceId: finalUpdated.id,
        );
        finalUpdated = finalUpdated.copyWith(linkedTransactionId: oldTx.id);

        if (delta != 0) {
          _accounts = _accounts.map((acc) {
            if (acc.id == oldTx.accountId) {
              if (acc.type == AccountType.creditCard) {
                return acc.copyWith(balance: (acc.balance - delta).clamp(0.0, double.infinity));
              } else {
                return acc.copyWith(balance: acc.balance + delta);
              }
            }
            return acc;
          }).toList();
        }

        // 1) Update any still-pending savings transfers triggered by this transaction
        bool ptChanged = false;
        _pendingTransfers = _pendingTransfers.map((pt) {
          if (pt.sourceTransactionId == oldTx.id) {
            final rule = _savingsRules.where((r) => r.id == pt.ruleId).firstOrNull;
            if (rule != null && rule.frequency == RoutingFrequency.onIncome) {
              ptChanged = true;
              return pt.copyWith(
                suggestedAmount: finalUpdated.amount * (rule.percentage / 100.0),
                reason: '${rule.percentage.toStringAsFixed(0)}% de "$newTitle"',
              );
            }
          }
          return pt;
        }).toList();

        // 2) Update any ALREADY-CONFIRMED savings transfer transactions linked to this income
        for (int tIdx = 0; tIdx < _transactions.length; tIdx++) {
          final transferTx = _transactions[tIdx];
          if (transferTx.type != MovementType.transfer || transferTx.category != 'Ahorro') continue;

          SavingsRule? matchedRule;
          if (transferTx.sourceTransactionId == oldTx.id && transferTx.savingsRuleId != null) {
            matchedRule = _savingsRules.where((r) => r.id == transferTx.savingsRuleId).firstOrNull;
          } else if (transferTx.sourceTransactionId == null) {
            // Legacy fallback: match by rule name & source account
            matchedRule = _savingsRules
                .where((r) =>
                    r.frequency == RoutingFrequency.onIncome &&
                    transferTx.title == 'Ahorro: ${r.name}' &&
                    transferTx.targetAccountId == r.targetAccountId)
                .firstOrNull;
          }

          if (matchedRule != null && matchedRule.frequency == RoutingFrequency.onIncome) {
            final newTransferAmount = finalUpdated.amount * (matchedRule.percentage / 100.0);
            final transferDelta = newTransferAmount - transferTx.amount;

            _transactions[tIdx] = transferTx.copyWith(
              amount: newTransferAmount,
              date: finalUpdated.date,
              sourceTransactionId: oldTx.id,
              savingsRuleId: matchedRule.id,
            );

            if (transferDelta != 0) {
              _accounts = _accounts.map((acc) {
                if (acc.id == transferTx.accountId) {
                  return acc.copyWith(balance: acc.balance - transferDelta);
                } else if (acc.id == transferTx.targetAccountId) {
                  return acc.copyWith(balance: acc.balance + transferDelta);
                }
                return acc;
              }).toList();
            }
          }
        }

        await _storage.saveTransactions(_transactions);
        await _storage.saveAccounts(_accounts);
        if (ptChanged) {
          await _storage.savePendingTransfers(_pendingTransfers);
        }
      }
    }

    _payOccurrences[idx] = finalUpdated;
    await _storage.savePayOccurrences(_payOccurrences);
    _recalculate();
  }

  Future<void> confirmPayOccurrence(
    String occId, {
    double? customAmount,
    DateTime? actualDate,
    bool alreadyInBalance = false,
  }) async {
    final idx = _payOccurrences.indexWhere((o) => o.id == occId);
    if (idx == -1) return;
    final occ = _payOccurrences[idx];
    final inc = _recurringIncomes.where((i) => i.id == occ.incomeId).firstOrNull;
    if (inc == null) return;

    final finalAmount = customAmount ?? occ.amount;
    final finalDate = actualDate ?? occ.date;

    String? txId;
    if (finalAmount > 0) {
      txId = await addTransaction(
        title: occ.note != null && occ.note!.isNotEmpty ? '${inc.name} (${occ.note})' : inc.name,
        amount: finalAmount,
        type: MovementType.income,
        category: inc.category,
        accountId: inc.accountId,
        date: finalDate,
        linkedOccurrenceId: occ.id,
        skipBalanceUpdate: alreadyInBalance,
        triggerSavingsRules: !alreadyInBalance,
      );
    }

    final currentIdx = _payOccurrences.indexWhere((o) => o.id == occId);
    if (currentIdx != -1) {
      _payOccurrences[currentIdx] = _payOccurrences[currentIdx].copyWith(
        amount: finalAmount,
        date: finalDate,
        status: PayOccurrenceStatus.confirmed,
        linkedTransactionId: txId,
      );
      await _storage.savePayOccurrences(_payOccurrences);
      _recalculate();
    }
  }

  Future<void> skipPayOccurrence(String occId) async {
    final idx = _payOccurrences.indexWhere((o) => o.id == occId);
    if (idx == -1) return;
    _payOccurrences[idx] = _payOccurrences[idx].copyWith(status: PayOccurrenceStatus.skipped);
    await _storage.savePayOccurrences(_payOccurrences);
    _recalculate();
  }

  Future<void> unconfirmPayOccurrence(String occId) async {
    final idx = _payOccurrences.indexWhere((o) => o.id == occId);
    if (idx == -1) return;
    final occ = _payOccurrences[idx];

    if (occ.linkedTransactionId != null) {
      await deleteTransaction(occ.linkedTransactionId!);
    }

    final currentIdx = _payOccurrences.indexWhere((o) => o.id == occId);
    if (currentIdx != -1) {
      _payOccurrences[currentIdx] = _payOccurrences[currentIdx].copyWith(
        status: PayOccurrenceStatus.projected,
        clearLinkedTransaction: true,
      );
      await _storage.savePayOccurrences(_payOccurrences);
      _recalculate();
    }
  }

  Future<void> confirmPendingIncome(String pendingId, {double? customAmount}) async {
    final idx = _pendingIncomes.indexWhere((p) => p.id == pendingId);
    if (idx == -1) return;
    final pending = _pendingIncomes[idx];
    final amountToLog = customAmount ?? pending.suggestedAmount;

    _pendingIncomes.removeAt(idx);
    await _storage.savePendingIncomes(_pendingIncomes);

    if (amountToLog > 0) {
      await addTransaction(
        title: pending.name,
        amount: amountToLog,
        type: MovementType.income,
        category: pending.category,
        accountId: pending.accountId,
        date: DateTime.now(),
      );
    } else {
      _recalculate();
    }
  }

  Future<void> skipPendingIncome(String pendingId) async {
    _pendingIncomes.removeWhere((p) => p.id == pendingId);
    await _storage.savePendingIncomes(_pendingIncomes);
    _recalculate();
  }

  Future<void> logRecurringIncomeNow(String incomeId, {double? customAmount}) async {
    final idx = _recurringIncomes.indexWhere((i) => i.id == incomeId);
    if (idx == -1) return;
    final inc = _recurringIncomes[idx];
    final amountToLog = customAmount ?? inc.amount;
    if (amountToLog <= 0) return;

    _recurringIncomes[idx] = inc.copyWith(lastLoggedAt: DateTime.now());
    await _storage.saveRecurringIncomes(_recurringIncomes);

    await addTransaction(
      title: inc.name,
      amount: amountToLog,
      type: MovementType.income,
      category: inc.category,
      accountId: inc.accountId,
      date: DateTime.now(),
    );
  }

  // --- CREDIT INSTALLMENT PLANS (MSI / MCI) ---
  List<CreditInstallmentPlan> getPlansForCard(String cardId) {
    final list = _installmentPlans.where((p) => p.accountId == cardId).toList();
    list.sort((a, b) => b.startDate.compareTo(a.startDate));
    return list;
  }

  double getCardRevolvingBalance(String cardId) {
    final card = _accounts.where((a) => a.id == cardId).firstOrNull;
    if (card == null) return 0.0;
    final msiRemaining = _installmentPlans
        .where((p) => p.accountId == cardId && !p.isCompleted)
        .fold<double>(0.0, (sum, p) => sum + p.remainingBalance);
    return (card.balance - msiRemaining).clamp(0.0, card.balance);
  }

  double getCardMonthlyPaymentDue(String cardId) {
    final card = _accounts.where((a) => a.id == cardId).firstOrNull;
    if (card == null) return 0.0;

    if (card.manualMonthlyDueOverride != null && card.manualMonthlyDueAt != null) {
      final overrideAt = card.manualMonthlyDueAt!;
      double delta = 0.0;
      for (final t in _transactions) {
        if (!t.date.isAfter(overrideAt)) continue;
        if (t.type == MovementType.expense &&
            t.accountId == card.id &&
            t.category != 'Estado de Cuenta' &&
            t.category != 'Compras a Meses') {
          delta += t.amount;
        } else if ((t.type == MovementType.transfer && t.targetAccountId == card.id) ||
            (t.type == MovementType.income && t.accountId == card.id)) {
          delta -= t.amount;
        }
      }
      for (final p in _installmentPlans) {
        if (p.accountId == card.id && !p.isCompleted && p.startDate.isAfter(overrideAt)) {
          delta += p.monthlyInstallment;
        }
      }
      return (card.manualMonthlyDueOverride! + delta).clamp(0.0, double.infinity);
    }

    final revolving = getCardRevolvingBalance(cardId);
    final msiMonthly = _installmentPlans
        .where((p) => p.accountId == cardId && !p.isCompleted)
        .fold<double>(0.0, (sum, p) => sum + p.monthlyInstallment);
    return (revolving + msiMonthly).clamp(0.0, card.balance);
  }

  Future<void> setCardManualMonthlyDue(String cardId, double? amount) async {
    _accounts = _accounts.map((acc) {
      if (acc.id == cardId) {
        if (amount == null) {
          return acc.copyWith(clearManualMonthlyDue: true);
        }
        return acc.copyWith(
          manualMonthlyDueOverride: amount,
          manualMonthlyDueAt: DateTime.now(),
        );
      }
      return acc;
    }).toList();
    await _storage.saveAccounts(_accounts);
    _recalculate();
  }

  Future<String> addInstallmentPlan(CreditInstallmentPlan plan, {bool isNewPurchase = false}) async {
    _installmentPlans.add(plan);
    await _storage.saveInstallmentPlans(_installmentPlans);

    if (isNewPurchase) {
      await addTransaction(
        title: '${plan.displayTitle} (${plan.totalMonths} ${plan.isInterestFree ? "MSI" : "MCI"})',
        amount: plan.totalFinancedAmount,
        type: MovementType.expense,
        category: 'Compras a Meses',
        accountId: plan.accountId,
        date: plan.startDate,
      );
    } else {
      _recalculate();
    }
    return plan.id;
  }

  Future<void> updateInstallmentPlan(CreditInstallmentPlan updated) async {
    _installmentPlans = _installmentPlans.map((p) => p.id == updated.id ? updated : p).toList();
    await _storage.saveInstallmentPlans(_installmentPlans);
    _recalculate();
  }

  Future<void> deleteInstallmentPlan(String planId, {bool revertBalance = false}) async {
    final idx = _installmentPlans.indexWhere((p) => p.id == planId);
    if (idx == -1) return;
    final plan = _installmentPlans[idx];
    _installmentPlans.removeAt(idx);
    await _storage.saveInstallmentPlans(_installmentPlans);

    if (revertBalance) {
      _accounts = _accounts.map((acc) {
        if (acc.id == plan.accountId) {
          return acc.copyWith(balance: (acc.balance - plan.remainingBalance).clamp(0.0, double.infinity));
        }
        return acc;
      }).toList();
      await _storage.saveAccounts(_accounts);
    }
    _recalculate();
  }

  Future<void> payCreditCardMonthly(String cardId, String fromAccountId, double amountPaid) async {
    if (amountPaid <= 0) return;
    final card = _accounts.where((a) => a.id == cardId).firstOrNull;
    if (card == null) return;

    await addTransaction(
      title: 'Pago Tarjeta ${card.name}',
      amount: amountPaid,
      type: MovementType.transfer,
      category: 'Pago Tarjeta',
      accountId: fromAccountId,
      targetAccountId: cardId,
    );

    // Advance 1 month on active MSI/MCI plans for this card
    bool plansChanged = false;
    _installmentPlans = _installmentPlans.map((p) {
      if (p.accountId == cardId && !p.isCompleted) {
        plansChanged = true;
        return p.copyWith(paidMonths: p.paidMonths + 1);
      }
      return p;
    }).toList();

    if (plansChanged) {
      await _storage.saveInstallmentPlans(_installmentPlans);
      _recalculate();
    }
  }

  // --- IMPORTED STATEMENTS HISTORY ---
  List<ImportedStatement> getStatementsForCard(String cardId) {
    final list = _importedStatements.where((s) => s.accountId == cardId).toList();
    list.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return list;
  }

  Future<void> addImportedStatement(ImportedStatement statement) async {
    _importedStatements.insert(0, statement);
    await _storage.saveImportedStatements(_importedStatements);
    _recalculate();
  }

  Future<void> deleteImportedStatement(String statementId) async {
    final idx = _importedStatements.indexWhere((s) => s.id == statementId);
    if (idx == -1) return;
    final stmt = _importedStatements[idx];

    _installmentPlans.removeWhere((p) => stmt.importedPlanIds.contains(p.id));
    _transactions.removeWhere((t) => stmt.importedTransactionIds.contains(t.id));
    _importedStatements.removeAt(idx);

    await _storage.saveInstallmentPlans(_installmentPlans);
    await _storage.saveTransactions(_transactions);
    await _storage.saveImportedStatements(_importedStatements);
    _recalculate();
  }

  Future<void> clearCardStatementData(String cardId) async {
    _installmentPlans.removeWhere((p) => p.accountId == cardId);
    _transactions.removeWhere((t) => t.accountId == cardId && t.category == 'Estado de Cuenta');
    _importedStatements.removeWhere((s) => s.accountId == cardId);

    await _storage.saveInstallmentPlans(_installmentPlans);
    await _storage.saveTransactions(_transactions);
    await _storage.saveImportedStatements(_importedStatements);
    _recalculate();
  }

  // --- CATEGORY MANAGEMENT ---
  Future<void> addCategory(MovementCategory category) async {
    _categories.add(category);
    await _storage.saveCategories(_categories);
    notifyListeners();
  }

  Future<void> updateCategory(MovementCategory updated) async {
    final idx = _categories.indexWhere((c) => c.id == updated.id);
    if (idx == -1) return;
    final old = _categories[idx];
    _categories[idx] = updated;
    await _storage.saveCategories(_categories);

    if (old.name != updated.name) {
      bool txChanged = false;
      _transactions = _transactions.map((tx) {
        if (tx.category == old.name) {
          txChanged = true;
          return tx.copyWith(category: updated.name);
        }
        return tx;
      }).toList();
      if (txChanged) {
        await _storage.saveTransactions(_transactions);
      }
    }
    _recalculate();
  }

  Future<void> deleteCategory(String categoryId) async {
    _categories.removeWhere((c) => c.id == categoryId);
    _categoryKeywordCounts.removeWhere((k, _) => k.startsWith('$categoryId::'));
    await _storage.saveCategories(_categories);
    await _storage.saveCategoryKeywordCounts(_categoryKeywordCounts);
    notifyListeners();
  }

  Future<void> addKeywordToCategory(String categoryId, String rawKeyword) async {
    final kw = MovementCategory.normalizeText(rawKeyword);
    if (kw.isEmpty) return;
    final idx = _categories.indexWhere((c) => c.id == categoryId);
    if (idx == -1) return;
    final cat = _categories[idx];
    if (cat.keywords.contains(kw)) return;
    _categories[idx] = cat.copyWith(keywords: [...cat.keywords, kw]);
    await _storage.saveCategories(_categories);
    notifyListeners();
  }

  Future<void> removeKeywordFromCategory(String categoryId, String rawKeyword) async {
    final kw = MovementCategory.normalizeText(rawKeyword);
    final idx = _categories.indexWhere((c) => c.id == categoryId);
    if (idx == -1) return;
    final cat = _categories[idx];
    final next = cat.keywords.where((k) => k != kw).toList();
    if (next.length == cat.keywords.length) return;
    _categories[idx] = cat.copyWith(keywords: next);
    await _storage.saveCategories(_categories);
    notifyListeners();
  }

  /// Tracks word -> category usage and automatically promotes a word to a category keyword
  /// once the user pairs them [autoLearnThreshold] times (default 3).
  /// Returns the list of newly learned keywords.
  Future<List<String>> recordCategoryUsageAndAutoLearn({
    required String description,
    required String categoryName,
    required bool isIncome,
    int autoLearnThreshold = 3,
  }) async {
    final cat = categoryByName(categoryName, isIncome: isIncome);
    if (cat == null) return const [];

    final words = MovementCategory.extractCandidateWords(description);
    if (words.isEmpty) return const [];

    final existingScopeKeywords = _categories
        .where((c) => isIncome ? c.isIncome : c.isExpense)
        .expand((c) => c.keywords)
        .toSet();

    final learned = <String>[];
    bool countsChanged = false;
    final updatedKeywords = List<String>.from(cat.keywords);

    for (final word in words) {
      if (existingScopeKeywords.contains(word) || updatedKeywords.contains(word)) {
        continue;
      }
      final key = '${cat.id}::$word';
      final nextCount = (_categoryKeywordCounts[key] ?? 0) + 1;
      countsChanged = true;
      if (nextCount >= autoLearnThreshold) {
        updatedKeywords.add(word);
        _categoryKeywordCounts.remove(key);
        learned.add(word);
      } else {
        _categoryKeywordCounts[key] = nextCount;
      }
    }

    if (learned.isNotEmpty) {
      final idx = _categories.indexWhere((c) => c.id == cat.id);
      if (idx != -1) {
        _categories[idx] = cat.copyWith(keywords: updatedKeywords);
        await _storage.saveCategories(_categories);
      }
    }
    if (countsChanged) {
      await _storage.saveCategoryKeywordCounts(_categoryKeywordCounts);
    }
    if (learned.isNotEmpty) {
      notifyListeners();
    }
    return learned;
  }

  // --- FUNDING PRIORITY & USER GOALS ---
  Future<void> updateFundingPriority(List<String> orderedIds) async {
    _fundingPriorityIds = List<String>.from(orderedIds);
    await _storage.saveFundingPriorityIds(_fundingPriorityIds);
    _recalculate();
  }

  Future<void> updateEmergencyFundMonths(int months) async {
    _emergencyFundMonths = months.clamp(1, 24);
    await _storage.saveEmergencyFundMonths(_emergencyFundMonths);
    _recalculate();
  }

  Future<void> updateEmergencyFundEnabled(bool enabled) async {
    _emergencyFundEnabled = enabled;
    await _storage.saveEmergencyFundEnabled(enabled);
    _recalculate();
  }

  Future<void> updateSafetyCushion(double amount) async {
    _safetyCushion = amount < 0 ? 0.0 : amount;
    await _storage.saveSafetyCushion(_safetyCushion);
    _recalculate();
  }

  Future<void> updateSurplusGoalOrder(List<String> order) async {
    _surplusGoalOrder = List<String>.from(order);
    await _storage.saveSurplusGoalOrder(_surplusGoalOrder);
    notifyListeners();
  }

  Future<void> updateIncludeExtraDebtGoal(bool include) async {
    _includeExtraDebtGoal = include;
    await _storage.saveIncludeExtraDebtGoal(include);
    notifyListeners();
  }

  // --- BACKUP & RESET ---
  ValueNotifier<CloudSyncStatus> get syncStatus => _storage.syncStatus;
  String? get lastSyncError => _storage.lastSyncError;
  Future<bool> retryCloudSync() => _storage.retryCloudSync();

  String exportBackupJson() => _storage.exportBackupJson();

  Future<bool> importBackupJson(String rawJson) async {
    final ok = await _storage.importBackupJson(rawJson);
    if (ok) loadData();
    return ok;
  }

  Future<void> clearAllData() async {
    await _storage.clearAllData();
    loadData();
  }
}
