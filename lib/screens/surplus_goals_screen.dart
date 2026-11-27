import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';

class SurplusGoalsScreen extends StatelessWidget {
  final FinanceProvider provider;

  const SurplusGoalsScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.card,
        elevation: 0,
        title: const Text(
          'Prioridad de Metas (Excedente)',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          final order = List<String>.from(provider.surplusGoalOrder);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        color: AppTheme.emeraldGreen,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ordena qué hacer con tu dinero excedente una vez cubiertos tus pagos del periodo. La app te guiará hacia la primera meta activa e incompleta de esta lista.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'ARRASTRA O USA LAS FLECHAS PARA REORDENAR',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: order.length,
                    onReorder: (oldIndex, newIndex) {
                      final updated = List<String>.from(order);
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = updated.removeAt(oldIndex);
                      updated.insert(newIndex, item);
                      provider.updateSurplusGoalOrder(updated);
                    },
                    itemBuilder: (context, index) {
                      final keyId = order[index];
                      return _GoalPriorityTile(
                        key: ValueKey(keyId),
                        goalKey: keyId,
                        index: index,
                        provider: provider,
                        onMoveUp: index > 0
                            ? () {
                                final updated = List<String>.from(order);
                                final item = updated.removeAt(index);
                                updated.insert(index - 1, item);
                                provider.updateSurplusGoalOrder(updated);
                              }
                            : null,
                        onMoveDown: index < order.length - 1
                            ? () {
                                final updated = List<String>.from(order);
                                final item = updated.removeAt(index);
                                updated.insert(index + 1, item);
                                provider.updateSurplusGoalOrder(updated);
                              }
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GoalPriorityTile extends StatelessWidget {
  final String goalKey;
  final int index;
  final FinanceProvider provider;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _GoalPriorityTile({
    super.key,
    required this.goalKey,
    required this.index,
    required this.provider,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final _GoalMeta meta = _metaForKey(goalKey);
    final bool isEnabled = _isEnabled(goalKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEnabled
              ? meta.color.withOpacity(0.35)
              : AppTheme.border.withOpacity(0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isEnabled
                    ? meta.color.withOpacity(0.15)
                    : AppTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isEnabled ? meta.color : AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        meta.icon,
                        size: 16,
                        color: isEnabled ? meta.color : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          meta.title,
                          style: TextStyle(
                            color: isEnabled
                                ? AppTheme.textPrimary
                                : AppTheme.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta.subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (goalKey == 'emergencyFund')
                  Switch.adaptive(
                    value: provider.emergencyFundEnabled,
                    activeColor: AppTheme.electricCyan,
                    onChanged: (val) => provider.updateEmergencyFundEnabled(val),
                  )
                else if (goalKey == 'payDebtExtra')
                  Switch.adaptive(
                    value: provider.includeExtraDebtGoal,
                    activeColor: AppTheme.amberGold,
                    onChanged: (val) => provider.updateIncludeExtraDebtGoal(val),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Activa',
                      style: TextStyle(
                        color: AppTheme.emeraldGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      icon: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: onMoveUp != null
                            ? AppTheme.textSecondary
                            : AppTheme.border,
                        size: 20,
                      ),
                      onPressed: onMoveUp,
                      tooltip: 'Subir prioridad',
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: onMoveDown != null
                            ? AppTheme.textSecondary
                            : AppTheme.border,
                        size: 20,
                      ),
                      onPressed: onMoveDown,
                      tooltip: 'Bajar prioridad',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isEnabled(String key) {
    switch (key) {
      case 'emergencyFund':
        return provider.emergencyFundEnabled;
      case 'payDebtExtra':
        return provider.includeExtraDebtGoal;
      case 'investAndGrow':
      default:
        return true;
    }
  }

  _GoalMeta _metaForKey(String key) {
    switch (key) {
      case 'emergencyFund':
        return const _GoalMeta(
          title: 'Fondo de Emergencia',
          subtitle:
              'Completar tu meta de reserva antes de pasar al siguiente objetivo.',
          icon: Icons.shield_moon_outlined,
          color: AppTheme.electricCyan,
        );
      case 'payDebtExtra':
        return const _GoalMeta(
          title: 'Adelantar a Deuda de Tarjetas',
          subtitle:
              'Abonar extra a tarjetas además del pago del periodo. Desactívalo para pagar solo lo que toca cada mes.',
          icon: Icons.credit_score_outlined,
          color: AppTheme.amberGold,
        );
      case 'investAndGrow':
      default:
        return const _GoalMeta(
          title: 'Invertir / Ahorro Libre',
          subtitle:
              'Destinar tu excedente a inversión, crecimiento patrimonial o metas libres.',
          icon: Icons.trending_up_rounded,
          color: AppTheme.emeraldGreen,
        );
    }
  }
}

class _GoalMeta {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _GoalMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
