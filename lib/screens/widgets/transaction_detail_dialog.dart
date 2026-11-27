import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import 'category_form_dialog.dart';
import 'confirm_delete_dialog.dart';

/// Opens a compact dialog showing transaction details with Edit and Delete actions.
Future<void> showTransactionDetailDialog(
  BuildContext context,
  FinanceProvider provider,
  Transaction tx,
) async {
  final sourceAcc =
      provider.accounts.where((a) => a.id == tx.accountId).firstOrNull;
  final targetAcc = tx.targetAccountId == null
      ? null
      : provider.accounts.where((a) => a.id == tx.targetAccountId).firstOrNull;

  final titleCtrl = TextEditingController(text: tx.title);
  final amountCtrl = TextEditingController(text: tx.amount.toStringAsFixed(2));
  final noteCtrl = TextEditingController(text: tx.note ?? '');
  final formKey = GlobalKey<FormState>();

  bool isEditing = false;
  bool isBusy = false;
  DateTime selectedDate = tx.date;
  String selectedCategory = tx.category;

  String typeLabel(MovementType type) {
    switch (type) {
      case MovementType.income:
        return 'Ingreso';
      case MovementType.expense:
        return 'Gasto';
      case MovementType.transfer:
        return 'Transferencia';
      case MovementType.yieldAccrual:
        return 'Rendimiento';
    }
  }

  Color typeColor(MovementType type) {
    switch (type) {
      case MovementType.income:
      case MovementType.yieldAccrual:
        return AppTheme.emeraldGreen;
      case MovementType.transfer:
        return AppTheme.electricCyan;
      case MovementType.expense:
        return AppTheme.alertCoral;
    }
  }

  String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final accent = typeColor(tx.type);
        final isPositive = tx.type == MovementType.income ||
            tx.type == MovementType.yieldAccrual;

        return AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.border),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          title: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.4)),
                ),
                child: Text(
                  typeLabel(tx.type),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isEditing ? Icons.visibility_outlined : Icons.edit_outlined,
                  size: 20,
                  color: AppTheme.electricCyan,
                ),
                tooltip: isEditing ? 'Ver detalle' : 'Editar movimiento',
                onPressed: isBusy
                    ? null
                    : () => setDialogState(() => isEditing = !isEditing),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppTheme.alertCoral,
                ),
                tooltip: 'Eliminar movimiento',
                onPressed: isBusy
                    ? null
                    : () async {
                        final confirmed = await showConfirmDeleteDialog(
                          ctx,
                          title: '¿Eliminar movimiento?',
                          message:
                              'Se eliminará "${tx.title}" (${CurrencyFormat.formatMXN(tx.amount)}) y se revertirá su efecto en el saldo de la cuenta.',
                        );
                        if (!confirmed) return;
                        setDialogState(() => isBusy = true);
                        await provider.deleteTransaction(tx.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: isEditing
                ? Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: titleCtrl,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration:
                                const InputDecoration(labelText: 'Concepto'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Escribe un concepto'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Monto (MXN)',
                              prefixText: '\$ ',
                            ),
                            validator: (v) {
                              final parsed =
                                  double.tryParse((v ?? '').replaceAll(',', ''));
                              if (parsed == null || parsed <= 0) {
                                return 'Ingresa un monto válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Categoría',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 38,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                ...(isPositive
                                        ? provider.incomeCategories
                                        : provider.expenseCategories)
                                    .map((cat) {
                                  final isSelected =
                                      cat.name == selectedCategory;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      avatar: Icon(
                                        cat.iconData,
                                        size: 15,
                                        color: isSelected
                                            ? Colors.white
                                            : cat.color,
                                      ),
                                      label: Text(cat.name),
                                      selected: isSelected,
                                      selectedColor:
                                          cat.color.withOpacity(0.32),
                                      backgroundColor: AppTheme.surface,
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                      onSelected: (_) => setDialogState(
                                          () => selectedCategory = cat.name),
                                    ),
                                  );
                                }),
                                ActionChip(
                                  avatar: const Icon(Icons.add,
                                      size: 16, color: AppTheme.electricCyan),
                                  label: const Text('Nueva'),
                                  backgroundColor: AppTheme.surface,
                                  side: BorderSide(
                                      color: AppTheme.electricCyan
                                          .withOpacity(0.45)),
                                  labelStyle: const TextStyle(
                                    color: AppTheme.electricCyan,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onPressed: () async {
                                    final created =
                                        await showCategoryFormDialog(
                                      ctx,
                                      initialIsIncome: isPositive,
                                      allowTypeToggle: false,
                                    );
                                    if (created != null) {
                                      await provider.addCategory(created);
                                      setDialogState(() =>
                                          selectedCategory = created.name);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration:
                                  const InputDecoration(labelText: 'Fecha'),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formatDate(selectedDate),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                  ),
                                  const Icon(Icons.calendar_today_outlined,
                                      size: 16,
                                      color: AppTheme.textSecondary),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: noteCtrl,
                            maxLines: 2,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                                labelText: 'Nota (opcional)'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${isPositive ? "+" : (tx.type == MovementType.transfer ? "" : "-")}${CurrencyFormat.formatMXN(tx.amount)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isPositive
                              ? AppTheme.emeraldGreen
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _DetailRow(
                        label: 'Cuenta',
                        value: sourceAcc?.name ?? 'Cuenta',
                      ),
                      if (targetAcc != null)
                        _DetailRow(
                          label: 'Destino',
                          value: targetAcc.name,
                        ),
                      _DetailRow(label: 'Categoría', value: tx.category),
                      _DetailRow(label: 'Fecha', value: formatDate(tx.date)),
                      if (tx.note != null && tx.note!.trim().isNotEmpty)
                        _DetailRow(label: 'Nota', value: tx.note!.trim()),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: isBusy ? null : () => Navigator.pop(ctx),
              child: const Text('Cerrar',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            if (isEditing)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  foregroundColor: Colors.black,
                ),
                onPressed: isBusy
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final amount = double.parse(
                            amountCtrl.text.trim().replaceAll(',', ''));
                        final trimmedNote = noteCtrl.text.trim();
                        setDialogState(() => isBusy = true);
                        await provider.updateTransaction(
                          tx.copyWith(
                            title: titleCtrl.text.trim(),
                            amount: amount,
                            category: selectedCategory,
                            date: selectedDate,
                            note: trimmedNote.isEmpty ? null : trimmedNote,
                          ),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Guardar'),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.electricCyan.withOpacity(0.18),
                  foregroundColor: AppTheme.electricCyan,
                  elevation: 0,
                ),
                onPressed: isBusy
                    ? null
                    : () => setDialogState(() => isEditing = true),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
              ),
          ],
        );
      },
    ),
  );

  titleCtrl.dispose();
  amountCtrl.dispose();
  noteCtrl.dispose();
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

