import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/budget_commitment.dart';
import '../models/savings_rule.dart';
import '../models/recurring_income.dart';
import '../models/credit_installment.dart';
import '../models/imported_statement.dart';
import 'firestore_service.dart';

class StorageService {
  static const String _keyAccounts = 'fmmf_accounts';
  static const String _keyTransactions = 'fmmf_transactions';
  static const String _keyCommitments = 'fmmf_commitments';
  static const String _keySavingsRules = 'fmmf_savings_rules';
  static const String _keyPendingTransfers = 'fmmf_pending_transfers';
  static const String _keyRecurringIncomes = 'fmmf_recurring_incomes';
  static const String _keyPendingIncomes = 'fmmf_pending_incomes';
  static const String _keyPayOccurrences = 'fmmf_pay_occurrences';
  static const String _keyInstallmentPlans = 'fmmf_installment_plans';
  static const String _keyImportedStatements = 'fmmf_imported_statements';

  final SharedPreferences _prefs;
  FirestoreService? _firestore;
  String? _uid;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  /// Attaches user-scoped Cloud Firestore sync, migrating local data if cloud is empty.
  Future<void> attachCloudSync(User user, {FirestoreService? firestore}) async {
    _firestore = firestore ?? _firestore ?? FirestoreService();
    _uid = user.uid;
    await _firestore!.ensureUserProfile(user);
    final cloud = await _firestore!.loadAll(user.uid);
    if (cloud.isEmpty) {
      final local = CloudSnapshot(
        accounts: loadAccounts(),
        transactions: loadTransactions(),
        commitments: loadCommitments(),
        savingsRules: loadSavingsRules(),
        pendingTransfers: loadPendingTransfers(),
        recurringIncomes: loadRecurringIncomes(),
        pendingIncomes: loadPendingIncomes(),
        payOccurrences: loadPayOccurrences(),
        installmentPlans: loadInstallmentPlans(),
        importedStatements: loadImportedStatements(),
      );
      if (!local.isEmpty) {
        await _firestore!.saveAll(user.uid, local);
      }
    } else {
      await _writeLocalOnly(cloud);
    }
  }

  void detachCloudSync() {
    _uid = null;
    _firestore?.clearSessionCache();
  }

  Future<void> _writeLocalOnly(CloudSnapshot snapshot) async {
    await _prefs.setString(_keyAccounts, jsonEncode(snapshot.accounts.map((e) => e.toJson()).toList()));
    await _prefs.setString(_keyTransactions, jsonEncode(snapshot.transactions.map((e) => e.toJson()).toList()));
    await _prefs.setString(_keyCommitments, jsonEncode(snapshot.commitments.map((e) => e.toJson()).toList()));
    await _prefs.setString(_keySavingsRules, jsonEncode(snapshot.savingsRules.map((e) => e.toJson()).toList()));
    await _prefs.setString(_keyPendingTransfers, jsonEncode(snapshot.pendingTransfers.map((e) => e.toJson()).toList()));
    await _prefs.setString(_keyRecurringIncomes, jsonEncode(snapshot.recurringIncomes.map((e) => e.toJson()).toList()));
    await _prefs.setString(_keyPendingIncomes, jsonEncode(snapshot.pendingIncomes.map((e) => e.toJson()).toList()));
    await _prefs.setString(_keyPayOccurrences, jsonEncode(snapshot.payOccurrences.map((e) => e.toJson()).toList()));
    await _prefs.setString(_keyInstallmentPlans, jsonEncode(snapshot.installmentPlans.map((e) => e.toJson()).toList()));
    await _prefs.setString(_keyImportedStatements, jsonEncode(snapshot.importedStatements.map((e) => e.toJson()).toList()));
  }

  void _syncToCloud<T>(
    String collection,
    List<T> items,
    String Function(T) idOf,
    Map<String, dynamic> Function(T) toJson,
  ) {
    final firestore = _firestore;
    final uid = _uid;
    if (firestore == null || uid == null) return;
    unawaited(firestore.saveCollection<T>(uid, collection, items, idOf, toJson));
  }

  // --- ACCOUNTS ---
  List<Account> loadAccounts() {
    final raw = _prefs.getString(_keyAccounts);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAccounts(List<Account> accounts) async {
    final raw = jsonEncode(accounts.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyAccounts, raw);
    _syncToCloud<Account>(FirestoreService.colAccounts, accounts, (e) => e.id, (e) => e.toJson());
  }

  // --- TRANSACTIONS ---
  List<Transaction> loadTransactions() {
    final raw = _prefs.getString(_keyTransactions);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTransactions(List<Transaction> transactions) async {
    final raw = jsonEncode(transactions.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyTransactions, raw);
    _syncToCloud<Transaction>(FirestoreService.colTransactions, transactions, (e) => e.id, (e) => e.toJson());
  }

  // --- COMMITMENTS ---
  List<BudgetCommitment> loadCommitments() {
    final raw = _prefs.getString(_keyCommitments);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => BudgetCommitment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCommitments(List<BudgetCommitment> commitments) async {
    final raw = jsonEncode(commitments.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyCommitments, raw);
    _syncToCloud<BudgetCommitment>(FirestoreService.colCommitments, commitments, (e) => e.id, (e) => e.toJson());
  }

  // --- SAVINGS RULES ---
  List<SavingsRule> loadSavingsRules() {
    final raw = _prefs.getString(_keySavingsRules);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => SavingsRule.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSavingsRules(List<SavingsRule> rules) async {
    final raw = jsonEncode(rules.map((e) => e.toJson()).toList());
    await _prefs.setString(_keySavingsRules, raw);
    _syncToCloud<SavingsRule>(FirestoreService.colSavingsRules, rules, (e) => e.id, (e) => e.toJson());
  }

  // --- PENDING TRANSFERS ---
  List<PendingTransfer> loadPendingTransfers() {
    final raw = _prefs.getString(_keyPendingTransfers);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => PendingTransfer.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePendingTransfers(List<PendingTransfer> transfers) async {
    final raw = jsonEncode(transfers.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyPendingTransfers, raw);
    _syncToCloud<PendingTransfer>(FirestoreService.colPendingTransfers, transfers, (e) => e.id, (e) => e.toJson());
  }

  // --- RECURRING INCOMES ---
  List<RecurringIncome> loadRecurringIncomes() {
    final raw = _prefs.getString(_keyRecurringIncomes);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => RecurringIncome.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecurringIncomes(List<RecurringIncome> incomes) async {
    final raw = jsonEncode(incomes.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyRecurringIncomes, raw);
    _syncToCloud<RecurringIncome>(FirestoreService.colRecurringIncomes, incomes, (e) => e.id, (e) => e.toJson());
  }

  // --- PENDING INCOMES ---
  List<PendingIncome> loadPendingIncomes() {
    final raw = _prefs.getString(_keyPendingIncomes);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => PendingIncome.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePendingIncomes(List<PendingIncome> pending) async {
    final raw = jsonEncode(pending.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyPendingIncomes, raw);
    _syncToCloud<PendingIncome>(FirestoreService.colPendingIncomes, pending, (e) => e.id, (e) => e.toJson());
  }

  // --- SCHEDULED PAY OCCURRENCES ---
  List<ScheduledPayOccurrence> loadPayOccurrences() {
    final raw = _prefs.getString(_keyPayOccurrences);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => ScheduledPayOccurrence.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePayOccurrences(List<ScheduledPayOccurrence> occurrences) async {
    final raw = jsonEncode(occurrences.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyPayOccurrences, raw);
    _syncToCloud<ScheduledPayOccurrence>(FirestoreService.colPayOccurrences, occurrences, (e) => e.id, (e) => e.toJson());
  }

  // --- CREDIT INSTALLMENT PLANS (MSI / MCI) ---
  List<CreditInstallmentPlan> loadInstallmentPlans() {
    final raw = _prefs.getString(_keyInstallmentPlans);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => CreditInstallmentPlan.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveInstallmentPlans(List<CreditInstallmentPlan> plans) async {
    final raw = jsonEncode(plans.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyInstallmentPlans, raw);
    _syncToCloud<CreditInstallmentPlan>(FirestoreService.colInstallmentPlans, plans, (e) => e.id, (e) => e.toJson());
  }

  // --- IMPORTED STATEMENTS ---
  List<ImportedStatement> loadImportedStatements() {
    final raw = _prefs.getString(_keyImportedStatements);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => ImportedStatement.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveImportedStatements(List<ImportedStatement> statements) async {
    final raw = jsonEncode(statements.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyImportedStatements, raw);
    _syncToCloud<ImportedStatement>(FirestoreService.colImportedStatements, statements, (e) => e.id, (e) => e.toJson());
  }

  Future<void> clearAllData() async {
    await saveAccounts([]);
    await saveTransactions([]);
    await saveCommitments([]);
    await saveSavingsRules([]);
    await savePendingTransfers([]);
    await saveRecurringIncomes([]);
    await savePendingIncomes([]);
    await savePayOccurrences([]);
    await saveInstallmentPlans([]);
    await saveImportedStatements([]);
  }

  String exportBackupJson() {
    final payload = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': loadAccounts().map((e) => e.toJson()).toList(),
      'transactions': loadTransactions().map((e) => e.toJson()).toList(),
      'commitments': loadCommitments().map((e) => e.toJson()).toList(),
      'savingsRules': loadSavingsRules().map((e) => e.toJson()).toList(),
      'pendingTransfers': loadPendingTransfers().map((e) => e.toJson()).toList(),
      'recurringIncomes': loadRecurringIncomes().map((e) => e.toJson()).toList(),
      'pendingIncomes': loadPendingIncomes().map((e) => e.toJson()).toList(),
      'payOccurrences': loadPayOccurrences().map((e) => e.toJson()).toList(),
      'installmentPlans': loadInstallmentPlans().map((e) => e.toJson()).toList(),
      'importedStatements': loadImportedStatements().map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<bool> importBackupJson(String rawJson) async {
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      final accounts = (decoded['accounts'] as List? ?? [])
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList();
      final transactions = (decoded['transactions'] as List? ?? [])
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList();
      final commitments = (decoded['commitments'] as List? ?? [])
          .map((e) => BudgetCommitment.fromJson(e as Map<String, dynamic>))
          .toList();
      final savingsRules = (decoded['savingsRules'] as List? ?? [])
          .map((e) => SavingsRule.fromJson(e as Map<String, dynamic>))
          .toList();
      final pendingTransfers = (decoded['pendingTransfers'] as List? ?? [])
          .map((e) => PendingTransfer.fromJson(e as Map<String, dynamic>))
          .toList();
      final recurringIncomes = (decoded['recurringIncomes'] as List? ?? [])
          .map((e) => RecurringIncome.fromJson(e as Map<String, dynamic>))
          .toList();
      final pendingIncomes = (decoded['pendingIncomes'] as List? ?? [])
          .map((e) => PendingIncome.fromJson(e as Map<String, dynamic>))
          .toList();
      final payOccurrences = (decoded['payOccurrences'] as List? ?? [])
          .map((e) => ScheduledPayOccurrence.fromJson(e as Map<String, dynamic>))
          .toList();
      final installmentPlans = (decoded['installmentPlans'] as List? ?? [])
          .map((e) => CreditInstallmentPlan.fromJson(e as Map<String, dynamic>))
          .toList();
      final importedStatements = (decoded['importedStatements'] as List? ?? [])
          .map((e) => ImportedStatement.fromJson(e as Map<String, dynamic>))
          .toList();

      await saveAccounts(accounts);
      await saveTransactions(transactions);
      await saveCommitments(commitments);
      await saveSavingsRules(savingsRules);
      await savePendingTransfers(pendingTransfers);
      await saveRecurringIncomes(recurringIncomes);
      await savePendingIncomes(pendingIncomes);
      await savePayOccurrences(payOccurrences);
      await saveInstallmentPlans(installmentPlans);
      await saveImportedStatements(importedStatements);
      return true;
    } catch (_) {
      return false;
    }
  }
}

