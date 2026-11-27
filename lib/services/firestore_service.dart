import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/account.dart';
import '../models/budget_commitment.dart';
import '../models/credit_installment.dart';
import '../models/imported_statement.dart';
import '../models/movement_category.dart';
import '../models/recurring_income.dart';
import '../models/savings_rule.dart';
import '../models/transaction.dart';

/// Complete user-scoped snapshot loaded from Cloud Firestore.
class CloudSnapshot {
  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<BudgetCommitment> commitments;
  final List<SavingsRule> savingsRules;
  final List<PendingTransfer> pendingTransfers;
  final List<RecurringIncome> recurringIncomes;
  final List<PendingIncome> pendingIncomes;
  final List<ScheduledPayOccurrence> payOccurrences;
  final List<CreditInstallmentPlan> installmentPlans;
  final List<ImportedStatement> importedStatements;
  final List<MovementCategory> categories;
  final List<String> fundingPriorityIds;
  final int emergencyFundMonths;
  final bool emergencyFundEnabled;
  final double safetyCushion;
  final List<String> surplusGoalOrder;
  final bool includeExtraDebtGoal;

  static const List<String> defaultSurplusGoalOrder = [
    'emergencyFund',
    'investAndGrow',
    'payDebtExtra',
  ];

  const CloudSnapshot({
    required this.accounts,
    required this.transactions,
    required this.commitments,
    required this.savingsRules,
    required this.pendingTransfers,
    required this.recurringIncomes,
    required this.pendingIncomes,
    required this.payOccurrences,
    required this.installmentPlans,
    required this.importedStatements,
    this.categories = const [],
    this.fundingPriorityIds = const [],
    this.emergencyFundMonths = 3,
    this.emergencyFundEnabled = true,
    this.safetyCushion = 0.0,
    this.surplusGoalOrder = defaultSurplusGoalOrder,
    this.includeExtraDebtGoal = false,
  });

  bool get isEmpty =>
      accounts.isEmpty &&
      transactions.isEmpty &&
      commitments.isEmpty &&
      savingsRules.isEmpty &&
      pendingTransfers.isEmpty &&
      recurringIncomes.isEmpty &&
      pendingIncomes.isEmpty &&
      payOccurrences.isEmpty &&
      installmentPlans.isEmpty &&
      importedStatements.isEmpty &&
      categories.isEmpty;
}

/// Syncs user-scoped financial data under `users/{uid}/{collection}/{docId}`.
class FirestoreService {
  static const String colAccounts = 'accounts';
  static const String colTransactions = 'transactions';
  static const String colCommitments = 'commitments';
  static const String colSavingsRules = 'savingsRules';
  static const String colPendingTransfers = 'pendingTransfers';
  static const String colRecurringIncomes = 'recurringIncomes';
  static const String colPendingIncomes = 'pendingIncomes';
  static const String colPayOccurrences = 'payOccurrences';
  static const String colInstallmentPlans = 'installmentPlans';
  static const String colImportedStatements = 'importedStatements';
  static const String colCategories = 'categories';

  final FirebaseFirestore _db;
  final Map<String, Set<String>> _knownIds = {};

  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _sub(String uid, String name) =>
      _userDoc(uid).collection(name);

  Future<void> ensureUserProfile(User user) async {
    final docRef = _userDoc(user.uid);
    final existing = await docRef.get();
    final payload = <String, dynamic>{
      'uid': user.uid,
      if (user.email != null) 'email': user.email,
      if (user.displayName != null) 'displayName': user.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    await docRef.set(payload, SetOptions(merge: true));
  }

  Future<CloudSnapshot> loadAll(String uid) async {
    final userDocFuture = _userDoc(uid).get();
    final results = await Future.wait([
      _loadList(uid, colAccounts, Account.fromJson),
      _loadList(uid, colTransactions, Transaction.fromJson),
      _loadList(uid, colCommitments, BudgetCommitment.fromJson),
      _loadList(uid, colSavingsRules, SavingsRule.fromJson),
      _loadList(uid, colPendingTransfers, PendingTransfer.fromJson),
      _loadList(uid, colRecurringIncomes, RecurringIncome.fromJson),
      _loadList(uid, colPendingIncomes, PendingIncome.fromJson),
      _loadList(uid, colPayOccurrences, ScheduledPayOccurrence.fromJson),
      _loadList(uid, colInstallmentPlans, CreditInstallmentPlan.fromJson),
      _loadList(uid, colImportedStatements, ImportedStatement.fromJson),
      _loadList(uid, colCategories, MovementCategory.fromJson),
    ]);
    final userDoc = await userDocFuture;
    final userData = userDoc.data();
    final rawPriority = userData?['fundingPriorityIds'];
    final priorityIds = rawPriority is List
        ? rawPriority.whereType<String>().toList()
        : <String>[];
    final emergencyMonths =
        (userData?['emergencyFundMonths'] as num?)?.toInt() ?? 3;
    final emergencyEnabled =
        (userData?['emergencyFundEnabled'] as bool?) ?? true;
    final safetyCushion =
        (userData?['safetyCushion'] as num?)?.toDouble() ?? 0.0;
    final rawGoalOrder = userData?['surplusGoalOrder'];
    final surplusGoalOrder = rawGoalOrder is List && rawGoalOrder.isNotEmpty
        ? rawGoalOrder.whereType<String>().toList()
        : CloudSnapshot.defaultSurplusGoalOrder;
    final includeExtraDebtGoal =
        (userData?['includeExtraDebtGoal'] as bool?) ?? false;

    return CloudSnapshot(
      accounts: results[0] as List<Account>,
      transactions: results[1] as List<Transaction>,
      commitments: results[2] as List<BudgetCommitment>,
      savingsRules: results[3] as List<SavingsRule>,
      pendingTransfers: results[4] as List<PendingTransfer>,
      recurringIncomes: results[5] as List<RecurringIncome>,
      pendingIncomes: results[6] as List<PendingIncome>,
      payOccurrences: results[7] as List<ScheduledPayOccurrence>,
      installmentPlans: results[8] as List<CreditInstallmentPlan>,
      importedStatements: results[9] as List<ImportedStatement>,
      categories: results[10] as List<MovementCategory>,
      fundingPriorityIds: priorityIds,
      emergencyFundMonths: emergencyMonths,
      emergencyFundEnabled: emergencyEnabled,
      safetyCushion: safetyCushion,
      surplusGoalOrder: surplusGoalOrder,
      includeExtraDebtGoal: includeExtraDebtGoal,
    );
  }

  Future<List<T>> _loadList<T>(
    String uid,
    String collection,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final snap = await _sub(uid, collection).get();
    final ids = <String>{};
    final items = <T>[];
    for (final doc in snap.docs) {
      ids.add(doc.id);
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] ??= doc.id;
      items.add(fromJson(data));
    }
    _knownIds[collection] = ids;
    return items;
  }

  Future<void> saveFundingPriorityIds(String uid, List<String> ids) async {
    await _userDoc(uid).set(
      {
        'uid': uid,
        'fundingPriorityIds': ids,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveUserSettings(
    String uid, {
    int? emergencyFundMonths,
    bool? emergencyFundEnabled,
    double? safetyCushion,
    List<String>? surplusGoalOrder,
    bool? includeExtraDebtGoal,
  }) async {
    await _userDoc(uid).set(
      {
        'uid': uid,
        if (emergencyFundMonths != null)
          'emergencyFundMonths': emergencyFundMonths,
        if (emergencyFundEnabled != null)
          'emergencyFundEnabled': emergencyFundEnabled,
        if (safetyCushion != null) 'safetyCushion': safetyCushion,
        if (surplusGoalOrder != null) 'surplusGoalOrder': surplusGoalOrder,
        if (includeExtraDebtGoal != null)
          'includeExtraDebtGoal': includeExtraDebtGoal,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveAll(String uid, CloudSnapshot snapshot) async {
    await Future.wait([
      saveFundingPriorityIds(uid, snapshot.fundingPriorityIds),
      saveUserSettings(
        uid,
        emergencyFundMonths: snapshot.emergencyFundMonths,
        emergencyFundEnabled: snapshot.emergencyFundEnabled,
        safetyCushion: snapshot.safetyCushion,
        surplusGoalOrder: snapshot.surplusGoalOrder,
        includeExtraDebtGoal: snapshot.includeExtraDebtGoal,
      ),
      saveCollection<Account>(
          uid, colAccounts, snapshot.accounts, (e) => e.id, (e) => e.toJson()),
      saveCollection<Transaction>(uid, colTransactions, snapshot.transactions,
          (e) => e.id, (e) => e.toJson()),
      saveCollection<BudgetCommitment>(uid, colCommitments,
          snapshot.commitments, (e) => e.id, (e) => e.toJson()),
      saveCollection<SavingsRule>(uid, colSavingsRules, snapshot.savingsRules,
          (e) => e.id, (e) => e.toJson()),
      saveCollection<PendingTransfer>(uid, colPendingTransfers,
          snapshot.pendingTransfers, (e) => e.id, (e) => e.toJson()),
      saveCollection<RecurringIncome>(uid, colRecurringIncomes,
          snapshot.recurringIncomes, (e) => e.id, (e) => e.toJson()),
      saveCollection<PendingIncome>(uid, colPendingIncomes,
          snapshot.pendingIncomes, (e) => e.id, (e) => e.toJson()),
      saveCollection<ScheduledPayOccurrence>(uid, colPayOccurrences,
          snapshot.payOccurrences, (e) => e.id, (e) => e.toJson()),
      saveCollection<CreditInstallmentPlan>(uid, colInstallmentPlans,
          snapshot.installmentPlans, (e) => e.id, (e) => e.toJson()),
      saveCollection<ImportedStatement>(uid, colImportedStatements,
          snapshot.importedStatements, (e) => e.id, (e) => e.toJson()),
      saveCollection<MovementCategory>(uid, colCategories,
          snapshot.categories, (e) => e.id, (e) => e.toJson()),
    ]);
  }

  Future<void> saveCollection<T>(
    String uid,
    String collection,
    List<T> items,
    String Function(T) idOf,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final colRef = _sub(uid, collection);
    final previousIds = _knownIds[collection] ?? <String>{};
    final nextIds = <String>{};

    final ops = <void Function(WriteBatch)>[];
    for (final item in items) {
      final id = idOf(item);
      nextIds.add(id);
      final data = toJson(item);
      ops.add((batch) => batch.set(colRef.doc(id), data));
    }

    for (final oldId in previousIds) {
      if (!nextIds.contains(oldId)) {
        ops.add((batch) => batch.delete(colRef.doc(oldId)));
      }
    }

    // Commit in chunks under Firestore's 500-operation batch limit.
    const maxBatchOps = 400;
    for (var i = 0; i < ops.length; i += maxBatchOps) {
      final batch = _db.batch();
      final end = (i + maxBatchOps < ops.length) ? i + maxBatchOps : ops.length;
      for (var j = i; j < end; j++) {
        ops[j](batch);
      }
      await batch.commit();
    }

    _knownIds[collection] = nextIds;
  }

  void clearSessionCache() {
    _knownIds.clear();
  }
}

