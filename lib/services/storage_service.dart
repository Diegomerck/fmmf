import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/budget_commitment.dart';
import '../models/savings_rule.dart';
import '../models/recurring_income.dart';
import '../models/credit_installment.dart';
import '../models/imported_statement.dart';
import '../models/movement_category.dart';
import 'firestore_service.dart';

enum CloudSyncStatus { idle, syncing, synced, error }

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
  static const String _keyCategories = 'fmmf_categories';
  static const String _keyCategoryKeywordCounts = 'fmmf_category_keyword_counts';
  static const String _keyFundingPriorityIds = 'fmmf_funding_priority_ids';
  static const String _keyEmergencyFundMonths = 'fmmf_emergency_fund_months';
  static const String _keyEmergencyFundEnabled = 'fmmf_emergency_fund_enabled';
  static const String _keySafetyCushion = 'fmmf_safety_cushion';
  static const String _keySurplusGoalOrder = 'fmmf_surplus_goal_order';
  static const String _keyIncludeExtraDebtGoal = 'fmmf_include_extra_debt_goal';
  static const String _keyPendingCloudSync = 'fmmf_pending_cloud_sync';

  final SharedPreferences _prefs;
  FirestoreService? _firestore;
  String? _uid;
  int _inFlightSyncs = 0;

  final ValueNotifier<CloudSyncStatus> syncStatus =
      ValueNotifier<CloudSyncStatus>(CloudSyncStatus.idle);
  String? lastSyncError;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  CloudSnapshot _buildLocalSnapshot() => CloudSnapshot(
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
        categories: loadCategories(),
        fundingPriorityIds: loadFundingPriorityIds(),
        emergencyFundMonths: loadEmergencyFundMonths(),
        emergencyFundEnabled: loadEmergencyFundEnabled(),
        safetyCushion: loadSafetyCushion(),
        surplusGoalOrder: loadSurplusGoalOrder(),
        includeExtraDebtGoal: loadIncludeExtraDebtGoal(),
      );

  /// Attaches user-scoped Cloud Firestore sync, migrating local or pending data if needed.
  Future<void> attachCloudSync(User user, {FirestoreService? firestore}) async {
    _firestore = firestore ?? _firestore ?? FirestoreService();
    _uid = user.uid;
    syncStatus.value = CloudSyncStatus.syncing;
    lastSyncError = null;
    try {
      await _firestore!.ensureUserProfile(user);
      final hasPendingLocal = _prefs.getBool(_keyPendingCloudSync) ?? false;
      final cloud = await _firestore!.loadAll(user.uid);
      final local = _buildLocalSnapshot();

      if ((cloud.isEmpty || hasPendingLocal) && !local.isEmpty) {
        await _firestore!.saveAll(user.uid, local);
        await _prefs.setBool(_keyPendingCloudSync, false);
      } else if (!cloud.isEmpty && !hasPendingLocal) {
        await _writeLocalOnly(cloud);
      }
      syncStatus.value = CloudSyncStatus.synced;
    } catch (e) {
      lastSyncError = e.toString();
      syncStatus.value = CloudSyncStatus.error;
      rethrow;
    }
  }

  void detachCloudSync() {
    _uid = null;
    _firestore?.clearSessionCache();
    syncStatus.value = CloudSyncStatus.idle;
    lastSyncError = null;
  }

  Future<bool> retryCloudSync() async {
    final firestore = _firestore;
    final uid = _uid;
    if (firestore == null || uid == null) return false;
    syncStatus.value = CloudSyncStatus.syncing;
    lastSyncError = null;
    try {
      await firestore.saveAll(uid, _buildLocalSnapshot());
      await _prefs.setBool(_keyPendingCloudSync, false);
      syncStatus.value = CloudSyncStatus.synced;
      return true;
    } catch (e) {
      lastSyncError = e.toString();
      syncStatus.value = CloudSyncStatus.error;
      return false;
    }
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
    await _prefs.setString(_keyCategories, jsonEncode(snapshot.categories.map((e) => e.toJson()).toList()));
    await _prefs.setString(_keyFundingPriorityIds, jsonEncode(snapshot.fundingPriorityIds));
    await _prefs.setInt(_keyEmergencyFundMonths, snapshot.emergencyFundMonths);
    await _prefs.setBool(_keyEmergencyFundEnabled, snapshot.emergencyFundEnabled);
    await _prefs.setDouble(_keySafetyCushion, snapshot.safetyCushion);
    await _prefs.setString(_keySurplusGoalOrder, jsonEncode(snapshot.surplusGoalOrder));
    await _prefs.setBool(_keyIncludeExtraDebtGoal, snapshot.includeExtraDebtGoal);
  }

  Future<void> _syncToCloud<T>(
    String collection,
    List<T> items,
    String Function(T) idOf,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final firestore = _firestore;
    final uid = _uid;
    if (firestore == null || uid == null) return;

    await _prefs.setBool(_keyPendingCloudSync, true);
    _inFlightSyncs++;
    syncStatus.value = CloudSyncStatus.syncing;
    lastSyncError = null;
    try {
      await firestore.saveCollection<T>(uid, collection, items, idOf, toJson);
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      if (_inFlightSyncs == 0 && lastSyncError == null) {
        await _prefs.setBool(_keyPendingCloudSync, false);
        syncStatus.value = CloudSyncStatus.synced;
      }
    } catch (e) {
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      lastSyncError = e.toString();
      syncStatus.value = CloudSyncStatus.error;
    }
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
    await _syncToCloud<Account>(FirestoreService.colAccounts, accounts, (e) => e.id, (e) => e.toJson());
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
    await _syncToCloud<Transaction>(FirestoreService.colTransactions, transactions, (e) => e.id, (e) => e.toJson());
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
    await _syncToCloud<BudgetCommitment>(FirestoreService.colCommitments, commitments, (e) => e.id, (e) => e.toJson());
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
    await _syncToCloud<SavingsRule>(FirestoreService.colSavingsRules, rules, (e) => e.id, (e) => e.toJson());
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
    await _syncToCloud<PendingTransfer>(FirestoreService.colPendingTransfers, transfers, (e) => e.id, (e) => e.toJson());
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
    await _syncToCloud<RecurringIncome>(FirestoreService.colRecurringIncomes, incomes, (e) => e.id, (e) => e.toJson());
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
    await _syncToCloud<PendingIncome>(FirestoreService.colPendingIncomes, pending, (e) => e.id, (e) => e.toJson());
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
    await _syncToCloud<ScheduledPayOccurrence>(FirestoreService.colPayOccurrences, occurrences, (e) => e.id, (e) => e.toJson());
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
    await _syncToCloud<CreditInstallmentPlan>(FirestoreService.colInstallmentPlans, plans, (e) => e.id, (e) => e.toJson());
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
    await _syncToCloud<ImportedStatement>(FirestoreService.colImportedStatements, statements, (e) => e.id, (e) => e.toJson());
  }

  // --- MOVEMENT CATEGORIES ---
  List<MovementCategory> loadCategories() {
    final raw = _prefs.getString(_keyCategories);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => MovementCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCategories(List<MovementCategory> categories) async {
    final raw = jsonEncode(categories.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyCategories, raw);
    await _syncToCloud<MovementCategory>(
      FirestoreService.colCategories,
      categories,
      (e) => e.id,
      (e) => e.toJson(),
    );
  }

  Map<String, int> loadCategoryKeywordCounts() {
    final raw = _prefs.getString(_keyCategoryKeywordCounts);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveCategoryKeywordCounts(Map<String, int> counts) async {
    await _prefs.setString(_keyCategoryKeywordCounts, jsonEncode(counts));
  }

  // --- FUNDING PRIORITY ---
  List<String> loadFundingPriorityIds() {
    final raw = _prefs.getString(_keyFundingPriorityIds);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveFundingPriorityIds(List<String> ids) async {
    await _prefs.setString(_keyFundingPriorityIds, jsonEncode(ids));
    final firestore = _firestore;
    final uid = _uid;
    if (firestore == null || uid == null) return;
    await _prefs.setBool(_keyPendingCloudSync, true);
    _inFlightSyncs++;
    syncStatus.value = CloudSyncStatus.syncing;
    lastSyncError = null;
    try {
      await firestore.saveFundingPriorityIds(uid, ids);
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      if (_inFlightSyncs == 0 && lastSyncError == null) {
        await _prefs.setBool(_keyPendingCloudSync, false);
        syncStatus.value = CloudSyncStatus.synced;
      }
    } catch (e) {
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      lastSyncError = e.toString();
      syncStatus.value = CloudSyncStatus.error;
    }
  }

  // --- USER GOALS & PARAMETERS ---
  int loadEmergencyFundMonths() => _prefs.getInt(_keyEmergencyFundMonths) ?? 3;

  Future<void> saveEmergencyFundMonths(int months) async {
    await _prefs.setInt(_keyEmergencyFundMonths, months);
    final firestore = _firestore;
    final uid = _uid;
    if (firestore == null || uid == null) return;
    await _prefs.setBool(_keyPendingCloudSync, true);
    _inFlightSyncs++;
    syncStatus.value = CloudSyncStatus.syncing;
    lastSyncError = null;
    try {
      await firestore.saveUserSettings(uid, emergencyFundMonths: months);
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      if (_inFlightSyncs == 0 && lastSyncError == null) {
        await _prefs.setBool(_keyPendingCloudSync, false);
        syncStatus.value = CloudSyncStatus.synced;
      }
    } catch (e) {
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      lastSyncError = e.toString();
      syncStatus.value = CloudSyncStatus.error;
    }
  }

  bool loadEmergencyFundEnabled() =>
      _prefs.getBool(_keyEmergencyFundEnabled) ?? true;

  Future<void> saveEmergencyFundEnabled(bool enabled) async {
    await _prefs.setBool(_keyEmergencyFundEnabled, enabled);
    final firestore = _firestore;
    final uid = _uid;
    if (firestore == null || uid == null) return;
    await _prefs.setBool(_keyPendingCloudSync, true);
    _inFlightSyncs++;
    syncStatus.value = CloudSyncStatus.syncing;
    lastSyncError = null;
    try {
      await firestore.saveUserSettings(uid, emergencyFundEnabled: enabled);
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      if (_inFlightSyncs == 0 && lastSyncError == null) {
        await _prefs.setBool(_keyPendingCloudSync, false);
        syncStatus.value = CloudSyncStatus.synced;
      }
    } catch (e) {
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      lastSyncError = e.toString();
      syncStatus.value = CloudSyncStatus.error;
    }
  }

  double loadSafetyCushion() => _prefs.getDouble(_keySafetyCushion) ?? 0.0;

  Future<void> saveSafetyCushion(double amount) async {
    await _prefs.setDouble(_keySafetyCushion, amount);
    final firestore = _firestore;
    final uid = _uid;
    if (firestore == null || uid == null) return;
    await _prefs.setBool(_keyPendingCloudSync, true);
    _inFlightSyncs++;
    syncStatus.value = CloudSyncStatus.syncing;
    lastSyncError = null;
    try {
      await firestore.saveUserSettings(uid, safetyCushion: amount);
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      if (_inFlightSyncs == 0 && lastSyncError == null) {
        await _prefs.setBool(_keyPendingCloudSync, false);
        syncStatus.value = CloudSyncStatus.synced;
      }
    } catch (e) {
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      lastSyncError = e.toString();
      syncStatus.value = CloudSyncStatus.error;
    }
  }

  List<String> loadSurplusGoalOrder() {
    final raw = _prefs.getString(_keySurplusGoalOrder);
    if (raw == null) return List<String>.from(CloudSnapshot.defaultSurplusGoalOrder);
    try {
      final list = jsonDecode(raw) as List;
      final parsed = list.whereType<String>().toList();
      return parsed.isEmpty
          ? List<String>.from(CloudSnapshot.defaultSurplusGoalOrder)
          : parsed;
    } catch (_) {
      return List<String>.from(CloudSnapshot.defaultSurplusGoalOrder);
    }
  }

  Future<void> saveSurplusGoalOrder(List<String> order) async {
    await _prefs.setString(_keySurplusGoalOrder, jsonEncode(order));
    final firestore = _firestore;
    final uid = _uid;
    if (firestore == null || uid == null) return;
    await _prefs.setBool(_keyPendingCloudSync, true);
    _inFlightSyncs++;
    syncStatus.value = CloudSyncStatus.syncing;
    lastSyncError = null;
    try {
      await firestore.saveUserSettings(uid, surplusGoalOrder: order);
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      if (_inFlightSyncs == 0 && lastSyncError == null) {
        await _prefs.setBool(_keyPendingCloudSync, false);
        syncStatus.value = CloudSyncStatus.synced;
      }
    } catch (e) {
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      lastSyncError = e.toString();
      syncStatus.value = CloudSyncStatus.error;
    }
  }

  bool loadIncludeExtraDebtGoal() =>
      _prefs.getBool(_keyIncludeExtraDebtGoal) ?? false;

  Future<void> saveIncludeExtraDebtGoal(bool include) async {
    await _prefs.setBool(_keyIncludeExtraDebtGoal, include);
    final firestore = _firestore;
    final uid = _uid;
    if (firestore == null || uid == null) return;
    await _prefs.setBool(_keyPendingCloudSync, true);
    _inFlightSyncs++;
    syncStatus.value = CloudSyncStatus.syncing;
    lastSyncError = null;
    try {
      await firestore.saveUserSettings(uid, includeExtraDebtGoal: include);
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      if (_inFlightSyncs == 0 && lastSyncError == null) {
        await _prefs.setBool(_keyPendingCloudSync, false);
        syncStatus.value = CloudSyncStatus.synced;
      }
    } catch (e) {
      _inFlightSyncs = (_inFlightSyncs - 1).clamp(0, 9999);
      lastSyncError = e.toString();
      syncStatus.value = CloudSyncStatus.error;
    }
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
    await saveCategories([]);
    await saveFundingPriorityIds([]);
    await saveEmergencyFundMonths(3);
    await saveEmergencyFundEnabled(true);
    await saveSafetyCushion(0.0);
    await saveSurplusGoalOrder(CloudSnapshot.defaultSurplusGoalOrder);
    await saveIncludeExtraDebtGoal(false);
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
      'categories': loadCategories().map((e) => e.toJson()).toList(),
      'fundingPriorityIds': loadFundingPriorityIds(),
      'emergencyFundMonths': loadEmergencyFundMonths(),
      'emergencyFundEnabled': loadEmergencyFundEnabled(),
      'safetyCushion': loadSafetyCushion(),
      'surplusGoalOrder': loadSurplusGoalOrder(),
      'includeExtraDebtGoal': loadIncludeExtraDebtGoal(),
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
      final categories = (decoded['categories'] as List? ?? [])
          .map((e) => MovementCategory.fromJson(e as Map<String, dynamic>))
          .toList();
      final fundingPriorityIds =
          (decoded['fundingPriorityIds'] as List? ?? [])
              .whereType<String>()
              .toList();
      final emergencyFundMonths =
          (decoded['emergencyFundMonths'] as num?)?.toInt() ?? 3;
      final emergencyFundEnabled =
          (decoded['emergencyFundEnabled'] as bool?) ?? true;
      final safetyCushion =
          (decoded['safetyCushion'] as num?)?.toDouble() ?? 0.0;
      final rawGoalOrder = decoded['surplusGoalOrder'];
      final surplusGoalOrder = rawGoalOrder is List && rawGoalOrder.isNotEmpty
          ? rawGoalOrder.whereType<String>().toList()
          : List<String>.from(CloudSnapshot.defaultSurplusGoalOrder);
      final includeExtraDebtGoal =
          (decoded['includeExtraDebtGoal'] as bool?) ?? false;

      final snapshot = CloudSnapshot(
        accounts: accounts,
        transactions: transactions,
        commitments: commitments,
        savingsRules: savingsRules,
        pendingTransfers: pendingTransfers,
        recurringIncomes: recurringIncomes,
        pendingIncomes: pendingIncomes,
        payOccurrences: payOccurrences,
        installmentPlans: installmentPlans,
        importedStatements: importedStatements,
        categories: categories,
        fundingPriorityIds: fundingPriorityIds,
        emergencyFundMonths: emergencyFundMonths,
        emergencyFundEnabled: emergencyFundEnabled,
        safetyCushion: safetyCushion,
        surplusGoalOrder: surplusGoalOrder,
        includeExtraDebtGoal: includeExtraDebtGoal,
      );

      await _writeLocalOnly(snapshot);
      if (_firestore != null && _uid != null) {
        await _prefs.setBool(_keyPendingCloudSync, true);
        await retryCloudSync();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

