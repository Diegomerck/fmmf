import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/movement_category.dart';
import '../providers/finance_provider.dart';
import 'widgets/category_form_dialog.dart';
import 'widgets/confirm_delete_dialog.dart';

class CategoriesScreen extends StatefulWidget {
  final FinanceProvider provider;

  const CategoriesScreen({super.key, required this.provider});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _showIncome = false;

  Future<void> _addCategory() async {
    final created = await showCategoryFormDialog(
      context,
      initialIsIncome: _showIncome,
    );
    if (created != null) {
      await widget.provider.addCategory(created);
    }
  }

  Future<void> _editCategory(MovementCategory category) async {
    final updated = await showCategoryFormDialog(
      context,
      existing: category,
    );
    if (updated != null) {
      await widget.provider.updateCategory(updated);
    }
  }

  Future<void> _deleteCategory(MovementCategory category) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: '¿Eliminar categoría?',
      message:
          'Se eliminará "${category.name}" de tus opciones. Los movimientos ya registrados conservarán su etiqueta.',
    );
    if (confirmed) {
      await widget.provider.deleteCategory(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Categorías de Movimientos'),
        backgroundColor: AppTheme.surface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.emeraldGreen,
        foregroundColor: Colors.black,
        onPressed: _addCategory,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nueva Categoría',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.provider,
        builder: (context, _) {
          final items = _showIncome
              ? widget.provider.incomeCategories
              : widget.provider.expenseCategories;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            'Gastos (${widget.provider.expenseCategories.length})',
                          ),
                        ),
                        selected: !_showIncome,
                        selectedColor: AppTheme.alertCoral.withOpacity(0.25),
                        backgroundColor: AppTheme.card,
                        labelStyle: TextStyle(
                          color: !_showIncome
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _showIncome = false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            'Ingresos (${widget.provider.incomeCategories.length})',
                          ),
                        ),
                        selected: _showIncome,
                        selectedColor: AppTheme.emeraldGreen.withOpacity(0.25),
                        backgroundColor: AppTheme.card,
                        labelStyle: TextStyle(
                          color: _showIncome
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _showIncome = true),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay categorías en esta sección.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final cat = items[index];
                          final color = cat.color;
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: ListTile(
                              onTap: () => _editCategory(cat),
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.16),
                                child: Icon(
                                  cat.iconData,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                cat.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                cat.keywords.isEmpty
                                    ? cat.scopeLabel
                                    : '${cat.scopeLabel} • ${cat.keywords.take(3).join(", ")}${cat.keywords.length > 3 ? " (+${cat.keywords.length - 3})" : ""}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18, color: AppTheme.electricCyan),
                                    tooltip: 'Editar',
                                    onPressed: () => _editCategory(cat),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: AppTheme.alertCoral),
                                    tooltip: 'Eliminar',
                                    onPressed: () => _deleteCategory(cat),
                                  ),
                                ],
                              ),
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

