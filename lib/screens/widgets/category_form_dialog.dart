import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/movement_category.dart';

/// Opens a dialog to create or edit a [MovementCategory] with icon, color, scope, and keyword pickers.
Future<MovementCategory?> showCategoryFormDialog(
  BuildContext context, {
  MovementCategory? existing,
  bool initialIsIncome = false,
  bool allowTypeToggle = true,
}) {
  return showDialog<MovementCategory>(
    context: context,
    builder: (ctx) => _CategoryFormDialog(
      existing: existing,
      initialIsIncome: initialIsIncome,
      allowTypeToggle: allowTypeToggle,
    ),
  );
}

class _CategoryFormDialog extends StatefulWidget {
  final MovementCategory? existing;
  final bool initialIsIncome;
  final bool allowTypeToggle;

  const _CategoryFormDialog({
    required this.existing,
    required this.initialIsIncome,
    required this.allowTypeToggle,
  });

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _keywordCtrl;
  late bool _isExpense;
  late bool _isIncome;
  late String _selectedHex;
  late int _selectedIconCode;
  late List<String> _keywords;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _keywordCtrl = TextEditingController();
    _isIncome = existing?.isIncome ?? widget.initialIsIncome;
    _isExpense = existing?.isExpense ?? !widget.initialIsIncome;
    if (!_isExpense && !_isIncome) {
      _isExpense = true;
    }
    _selectedHex = existing?.colorHex ??
        (_isIncome && !_isExpense
            ? MovementCategory.colorPaletteHex[3]
            : MovementCategory.colorPaletteHex[0]);
    _selectedIconCode = existing?.iconCodePoint ??
        (_isIncome && !_isExpense
            ? Icons.attach_money.codePoint
            : Icons.category.codePoint);
    _keywords = List<String>.from(existing?.keywords ?? const []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keywordCtrl.dispose();
    super.dispose();
  }

  void _addKeywordFromInput() {
    final parts = _keywordCtrl.text
        .split(',')
        .map(MovementCategory.normalizeText)
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return;
    setState(() {
      for (final p in parts) {
        if (!_keywords.contains(p)) {
          _keywords.add(p);
        }
      }
      _keywordCtrl.clear();
    });
  }

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return AppTheme.emeraldGreen;
    return Color(cleaned.length == 6 ? (0xFF000000 | value) : value);
  }

  IconData _resolveIcon(int codePoint) {
    for (final icon in MovementCategory.iconOptions) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final previewColor = _parseHex(_selectedHex);
    final previewIcon = _resolveIcon(_selectedIconCode);
    final previewName = _nameCtrl.text.trim().isEmpty
        ? 'Nueva categoría'
        : _nameCtrl.text.trim();

    final isOnlyExpense = _isExpense && !_isIncome;
    final isOnlyIncome = _isIncome && !_isExpense;
    final isBoth = _isExpense && _isIncome;

    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: Text(
        existing == null ? 'Nueva Categoría' : 'Editar Categoría',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: previewColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: previewColor.withOpacity(0.55)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(previewIcon, size: 18, color: previewColor),
                        const SizedBox(width: 8),
                        Text(
                          previewName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la categoría',
                    hintText: 'ej. Gimnasio, Mascotas, Renta',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe un nombre'
                      : null,
                ),
                if (widget.allowTypeToggle) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Disponible en',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Gasto')),
                          selected: isOnlyExpense,
                          selectedColor:
                              AppTheme.alertCoral.withOpacity(0.25),
                          backgroundColor: AppTheme.surface,
                          labelStyle: TextStyle(
                            color: isOnlyExpense
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setState(() {
                            _isExpense = true;
                            _isIncome = false;
                          }),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Ingreso')),
                          selected: isOnlyIncome,
                          selectedColor:
                              AppTheme.emeraldGreen.withOpacity(0.25),
                          backgroundColor: AppTheme.surface,
                          labelStyle: TextStyle(
                            color: isOnlyIncome
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setState(() {
                            _isExpense = false;
                            _isIncome = true;
                          }),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Ambos')),
                          selected: isBoth,
                          selectedColor:
                              AppTheme.electricCyan.withOpacity(0.25),
                          backgroundColor: AppTheme.surface,
                          labelStyle: TextStyle(
                            color: isBoth
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setState(() {
                            _isExpense = true;
                            _isIncome = true;
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Palabras clave (auto-categoría)',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'No distingue mayúsculas ni acentos (ej. uber, didi, costco).',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _keywordCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Agregar palabra (ej. uber)',
                          hintStyle: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                          isDense: true,
                          filled: true,
                          fillColor: AppTheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                        ),
                        onSubmitted: (_) => _addKeywordFromInput(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _addKeywordFromInput,
                      icon: const Icon(Icons.add_circle,
                          color: AppTheme.electricCyan),
                      tooltip: 'Agregar palabra clave',
                    ),
                  ],
                ),
                if (_keywords.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _keywords.map((kw) {
                      return InputChip(
                        label: Text(
                          kw,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                        backgroundColor: AppTheme.surface,
                        side: BorderSide(
                            color: AppTheme.electricCyan.withOpacity(0.45)),
                        deleteIconColor: AppTheme.textSecondary,
                        onDeleted: () =>
                            setState(() => _keywords.remove(kw)),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Color',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: MovementCategory.colorPaletteHex.map((hex) {
                    final color = _parseHex(hex);
                    final isSelected = hex == _selectedHex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedHex = hex),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2.5)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Ícono',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MovementCategory.iconOptions.map((icon) {
                    final isSelected = icon.codePoint == _selectedIconCode;
                    return GestureDetector(
                      onTap: () => setState(
                          () => _selectedIconCode = icon.codePoint),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? previewColor.withOpacity(0.22)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? previewColor
                                : AppTheme.border,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: isSelected
                              ? previewColor
                              : AppTheme.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emeraldGreen,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            // Include any pending text in the keyword input if user forgot to tap +
            final pending = _keywordCtrl.text
                .split(',')
                .map(MovementCategory.normalizeText)
                .where((e) => e.isNotEmpty);
            final finalKeywords = <String>{..._keywords, ...pending}.toList();
            final cat = MovementCategory(
              id: existing?.id ??
                  'cat_${DateTime.now().microsecondsSinceEpoch}',
              name: _nameCtrl.text.trim(),
              isExpense: _isExpense,
              isIncome: _isIncome,
              iconCodePoint: _selectedIconCode,
              colorHex: _selectedHex,
              keywords: finalKeywords,
            );
            Navigator.pop(context, cat);
          },
          child: Text(existing == null ? 'Crear' : 'Guardar'),
        ),
      ],
    );
  }
}
