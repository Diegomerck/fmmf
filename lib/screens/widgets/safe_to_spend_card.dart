import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../services/advisor_engine.dart';

class SafeToSpendCard extends StatelessWidget {
  final double safeToSpend;
  final double netWorth;
  final double monthlyPassiveYield;
  final double totalLiquidCash;
  final double totalDebt;
  final double pendingCommitments;
  final double safetyCushion;
  final double upcomingIncome;
  final double projectedEndOfMonthBuffer;
  final bool canCoverWithReserves;
  final DateTime? nextPaydayDate;
  final double obligationsBeforeNextPayday;
  final double lowestTimelineBalance;
  final DateTime? lowestTimelineDate;
  final double totalAllDebt;
  final bool emergencyFundEnabled;
  final int emergencyFundMonths;
  final double runwayMonths;
  final String? highestDebtCardName;
  final double netEmergencyReserves;
  final double emergencyGoalAmount;
  final List<String> surplusGoalOrder;
  final bool includeExtraDebtGoal;
  final GoalTimelineEstimate? emergencyGoalEstimate;
  final GoalTimelineEstimate? emergencyGoalFocusedEstimate;
  final GoalTimelineEstimate? debtGoalEstimate;
  final GoalTimelineEstimate? debtGoalFocusedEstimate;
  final bool simpleMode;
  final bool hasEmergencyAccountLinked;
  final List<String> emergencyAccountNames;
  final ValueChanged<double>? onTransferToEmergencyFund;
  final VoidCallback? onOpenAccountsTab;
  final VoidCallback? onOpenEmergencyFund;
  final VoidCallback onQuickAdd;

  const SafeToSpendCard({
    super.key,
    required this.safeToSpend,
    required this.netWorth,
    required this.monthlyPassiveYield,
    required this.totalLiquidCash,
    required this.totalDebt,
    this.pendingCommitments = 0.0,
    this.safetyCushion = 0.0,
    this.upcomingIncome = 0.0,
    this.projectedEndOfMonthBuffer = 0.0,
    this.canCoverWithReserves = false,
    this.nextPaydayDate,
    this.obligationsBeforeNextPayday = 0.0,
    this.lowestTimelineBalance = 0.0,
    this.lowestTimelineDate,
    this.totalAllDebt = 0.0,
    this.emergencyFundEnabled = true,
    this.emergencyFundMonths = 3,
    this.runwayMonths = 0.0,
    this.highestDebtCardName,
    this.netEmergencyReserves = 0.0,
    this.emergencyGoalAmount = 0.0,
    this.surplusGoalOrder = const ['emergencyFund', 'investAndGrow', 'payDebtExtra'],
    this.includeExtraDebtGoal = false,
    this.emergencyGoalEstimate,
    this.emergencyGoalFocusedEstimate,
    this.debtGoalEstimate,
    this.debtGoalFocusedEstimate,
    this.simpleMode = false,
    this.hasEmergencyAccountLinked = false,
    this.emergencyAccountNames = const [],
    this.onTransferToEmergencyFund,
    this.onOpenAccountsTab,
    this.onOpenEmergencyFund,
    required this.onQuickAdd,
  });

  void _showBreakdown(BuildContext context) {
    final String activeGoalKey = _resolveActiveGoalKey();
    final double remaining =
        (emergencyGoalAmount - netEmergencyReserves).clamp(0.0, double.infinity);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Text(
              'Desglose de tu Meta y Mes',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Resumen directo de los números que ves en tu tarjeta principal.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            if (activeGoalKey == 'emergencyFund') ...[
              _row('Meta ($emergencyFundMonths meses)', emergencyGoalAmount,
                  Colors.white),
              const SizedBox(height: 8),
              _row('− Fondo de Emergencia apartado', -netEmergencyReserves,
                  AppTheme.emeraldGreen),
              const SizedBox(height: 4),
              Text(
                hasEmergencyAccountLinked
                    ? 'Cuentas asignadas: ${emergencyAccountNames.join(', ')}'
                    : 'Ninguna cuenta asignada en Cuentas (\$0).',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              _row('= Te falta para completar', remaining, AppTheme.electricCyan,
                  bold: true),
              const Divider(color: AppTheme.border, height: 22),
            ] else if (activeGoalKey == 'payDebtExtra') ...[
              _row('Deuda total en tarjetas (incluye MSI)', totalAllDebt,
                  AppTheme.amberGold,
                  bold: true),
              const Divider(color: AppTheme.border, height: 22),
            ],
            _row('Tu dinero total hoy', totalLiquidCash, AppTheme.textPrimary),
            if (upcomingIncome > 0) ...[
              const SizedBox(height: 8),
              _row('+ Ingresos por cobrar este mes', upcomingIncome,
                  AppTheme.emeraldGreen),
            ],
            const SizedBox(height: 8),
            _row(
              '− Por pagar este mes (tarjetas y fijos)',
              -(totalDebt + pendingCommitments),
              AppTheme.alertCoral,
            ),
            if (safetyCushion > 0) ...[
              const SizedBox(height: 8),
              _row('− Colchón de seguridad mínimo', -safetyCushion,
                  AppTheme.amberGold),
            ],
            const Divider(color: AppTheme.border, height: 22),
            _row(
              '= Balance proyectado del mes',
              projectedEndOfMonthBuffer,
              projectedEndOfMonthBuffer >= 0
                  ? AppTheme.emeraldGreen
                  : AppTheme.alertCoral,
              bold: true,
            ),
            const Divider(color: AppTheme.border, height: 22),
            const Text(
              'Ventana de fechas (próximos 45 días)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (nextPaydayDate != null) ...[
              _row(
                'Pagos antes de tu cobro (${nextPaydayDate!.day}/${nextPaydayDate!.month})',
                -obligationsBeforeNextPayday,
                obligationsBeforeNextPayday > totalLiquidCash
                    ? AppTheme.alertCoral
                    : AppTheme.textSecondary,
              ),
              const SizedBox(height: 6),
            ],
            _row(
              lowestTimelineDate != null
                  ? 'Saldo más bajo (el ${lowestTimelineDate!.day}/${lowestTimelineDate!.month})'
                  : 'Saldo más bajo proyectado',
              lowestTimelineBalance,
              lowestTimelineBalance >= 0
                  ? AppTheme.emeraldGreen
                  : AppTheme.alertCoral,
            ),
            const SizedBox(height: 6),
            _row(
              '= Libre sin afectar fechas',
              safeToSpend,
              AppTheme.electricCyan,
              bold: true,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      ),
    );
  }

  Widget _row(String label, double val, Color color, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              color: bold ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
        Text(
          CurrencyFormat.formatMXN(val),
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  String _resolveActiveGoalKey() {
    for (final key in surplusGoalOrder) {
      if (key == 'emergencyFund') {
        if (emergencyFundEnabled &&
            emergencyGoalAmount > 0 &&
            netEmergencyReserves < emergencyGoalAmount) {
          return 'emergencyFund';
        }
      } else if (key == 'payDebtExtra') {
        if (includeExtraDebtGoal && totalAllDebt > 0) {
          return 'payDebtExtra';
        }
      } else if (key == 'investAndGrow') {
        return 'investAndGrow';
      }
    }
    return 'investAndGrow';
  }

  @override
  Widget build(BuildContext context) {
    final String activeGoalKey = _resolveActiveGoalKey();

    final String badgeText;
    final Color badgeColor;
    final IconData badgeIcon;
    final String heroFigure;
    final String heroSubtitle;

    if (activeGoalKey == 'payDebtExtra') {
      badgeText = 'META ACTIVA • ADELANTAR DEUDA';
      badgeColor = AppTheme.amberGold;
      badgeIcon = Icons.credit_score_outlined;
      heroFigure = CurrencyFormat.formatMXN(totalAllDebt);
      heroSubtitle = 'Deuda total en tarjetas (incluye MSI).';
    } else if (activeGoalKey == 'emergencyFund') {
      final remaining =
          (emergencyGoalAmount - netEmergencyReserves).clamp(0.0, double.infinity);
      badgeText = 'META ACTIVA • FONDO DE EMERGENCIA';
      badgeColor = AppTheme.electricCyan;
      badgeIcon = Icons.shield_moon_outlined;
      heroFigure = CurrencyFormat.formatMXN(remaining);
      heroSubtitle =
          'Te falta para completar tu meta de $emergencyFundMonths ${emergencyFundMonths == 1 ? 'mes' : 'meses'}.';
    } else {
      badgeText = 'META ACTIVA • INVERTIR Y CRECER';
      badgeColor = AppTheme.emeraldGreen;
      badgeIcon = Icons.trending_up_rounded;
      final investable =
          projectedEndOfMonthBuffer > 0 ? projectedEndOfMonthBuffer : 0.0;
      heroFigure = CurrencyFormat.formatMXN(investable);
      heroSubtitle = 'Excedente proyectado del mes listo para invertir.';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border.withOpacity(0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badgeColor.withOpacity(0.45)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 14, color: badgeColor),
                          const SizedBox(width: 4),
                          Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => _showBreakdown(context),
                      child: const Text(
                        'Ver desglose',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    if (activeGoalKey == 'emergencyFund' &&
                        onOpenEmergencyFund != null)
                      InkWell(
                        onTap: onOpenEmergencyFund,
                        child: const Text(
                          'Detalle del fondo',
                          style: TextStyle(
                            color: AppTheme.electricCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            heroFigure,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            heroSubtitle,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          if (activeGoalKey == 'emergencyFund' ||
              activeGoalKey == 'payDebtExtra') ...[
            const SizedBox(height: 10),
            _buildGoalTimelineSection(
              context,
              activeGoalKey: activeGoalKey,
              accentColor: badgeColor,
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Por Pagar Este Mes',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormat.formatMXN(
                        totalDebt + pendingCommitments,
                        includeDecimals: false,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.alertCoral,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tarjetas y fijos pendientes',
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 34, color: Colors.white12),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu Dinero Total',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormat.formatMXN(totalLiquidCash, includeDecimals: false),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Saldo en débito, efectivo y pagos',
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMonthVerdictBanner(),
          const SizedBox(height: 8),
          _buildNextGoalBanner(),
        ],
      ),
    );
  }

  Widget _buildGoalTimelineSection(
    BuildContext context, {
    required String activeGoalKey,
    required Color accentColor,
  }) {
    final bool isEmergency = activeGoalKey == 'emergencyFund';
    final GoalTimelineEstimate? currentPace =
        isEmergency ? emergencyGoalEstimate : debtGoalEstimate;
    final GoalTimelineEstimate? focusedPace =
        isEmergency ? emergencyGoalFocusedEstimate : debtGoalFocusedEstimate;

    final double? progress = isEmergency && emergencyGoalAmount > 0
        ? (netEmergencyReserves / emergencyGoalAmount).clamp(0.0, 1.0)
        : null;

    String formatScenarioEta(GoalTimelineEstimate? est) {
      if (est == null || est.expectedMonthlyIncome <= 0) {
        return 'Sin ingresos recurrentes';
      }
      if (est.monthsToGoal == null) {
        return 'Sin excedente proyectado';
      }
      final monthsText = _formatMonthsDuration(est.monthsToGoal!);
      final dateText = est.estimatedCompletionDate != null
          ? ' (${_formatMonthYear(est.estimatedCompletionDate!)})'
          : '';
      return '$monthsText$dateText';
    }

    final bool hasIncome =
        currentPace != null && currentPace.expectedMonthlyIncome > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progress != null) ...[
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.white.withOpacity(0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: currentPace != null && focusedPace != null
              ? () => _showGoalTimelineBreakdown(
                    context,
                    currentPace: currentPace,
                    focusedPace: focusedPace,
                    isEmergency: isEmergency,
                    accentColor: accentColor,
                  )
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withOpacity(0.25)),
            ),
            child: !hasIncome
                ? Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 15, color: accentColor),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Registra tus ingresos recurrentes para estimar el tiempo de tu meta.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  )
                : simpleMode
                    ? Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 14, color: accentColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Meta estimada en ${formatScenarioEta(currentPace)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: AppTheme.textSecondary.withOpacity(0.8),
                          ),
                        ],
                      )
                    : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 14, color: accentColor),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              '¿En cuánto tiempo llegas?',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: AppTheme.textSecondary.withOpacity(0.8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _scenarioLine(
                        dotColor: AppTheme.amberGold,
                        label: 'A tu ritmo actual:',
                        value: formatScenarioEta(currentPace),
                        savingsPerMonth: currentPace.estimatedMonthlySavings,
                      ),
                      const SizedBox(height: 4),
                      _scenarioLine(
                        dotColor: AppTheme.emeraldGreen,
                        label: 'Pagando solo fijos y MSI:',
                        value: formatScenarioEta(focusedPace),
                        savingsPerMonth:
                            focusedPace?.estimatedMonthlySavings ?? 0.0,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _scenarioLine({
    required Color dotColor,
    required String label,
    required String value,
    required double savingsPerMonth,
  }) {
    final savingsText = savingsPerMonth > 0
        ? ' • ~${CurrencyFormat.formatMXN(savingsPerMonth, includeDecimals: false)}/mes'
        : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                height: 1.3,
              ),
              children: [
                TextSpan(text: '$label '),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (savingsText.isNotEmpty)
                  TextSpan(
                    text: savingsText,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showGoalTimelineBreakdown(
    BuildContext context, {
    required GoalTimelineEstimate currentPace,
    required GoalTimelineEstimate focusedPace,
    required bool isEmergency,
    required Color accentColor,
  }) {
    String etaText(GoalTimelineEstimate e) {
      if (e.monthsToGoal == null) return 'Sin excedente mensual';
      final d = e.estimatedCompletionDate != null
          ? ' (${_formatMonthYear(e.estimatedCompletionDate!)})'
          : '';
      return '${_formatMonthsDuration(e.monthsToGoal!)}$d';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEmergency
                    ? 'Dos Escenarios • Fondo de Emergencia'
                    : 'Dos Escenarios • Liquidar Deuda',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEmergency
                    ? 'Te faltan ${CurrencyFormat.formatMXN(currentPace.targetAmount)} para tu meta de $emergencyFundMonths meses.'
                    : 'Deuda total actual: ${CurrencyFormat.formatMXN(currentPace.targetAmount)}.',
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.amberGold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.amberGold.withOpacity(0.28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Si sigues gastando igual (ritmo actual)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.amberGold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Incluye tus gastos fijos, MSI y el promedio de tus compras recientes.',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    _row('Ingreso mensual', currentPace.expectedMonthlyIncome,
                        AppTheme.emeraldGreen),
                    const SizedBox(height: 4),
                    _row('− Gasto promedio', -currentPace.estimatedMonthlySpend,
                        AppTheme.alertCoral),
                    const SizedBox(height: 4),
                    _row('= Ahorro/mes', currentPace.estimatedMonthlySavings,
                        AppTheme.amberGold,
                        bold: true),
                    const SizedBox(height: 6),
                    Text(
                      'Tiempo estimado: ${etaText(currentPace)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.emeraldGreen.withOpacity(0.28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '2. Modo enfocado (pagando solo fijos y MSI)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.emeraldGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Si frenas compras extra y solo cubres tus compromisos y mensualidades actuales.',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    _row('Ingreso mensual', focusedPace.expectedMonthlyIncome,
                        AppTheme.emeraldGreen),
                    const SizedBox(height: 4),
                    _row('− Fijos y MSI', -focusedPace.estimatedMonthlySpend,
                        AppTheme.alertCoral),
                    const SizedBox(height: 4),
                    _row('= Ahorro/mes', focusedPace.estimatedMonthlySavings,
                        AppTheme.emeraldGreen,
                        bold: true),
                    const SizedBox(height: 6),
                    Text(
                      'Tiempo estimado: ${etaText(focusedPace)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMonthsDuration(double months) {
    if (months < 1.0) return 'menos de 1 mes';
    final int rounded = months.ceil();
    if (rounded < 12) {
      return '~$rounded ${rounded == 1 ? 'mes' : 'meses'}';
    }
    final int years = rounded ~/ 12;
    final int remMonths = rounded % 12;
    final yearText = '$years ${years == 1 ? 'año' : 'años'}';
    if (remMonths == 0) return '~$yearText';
    return '~$yearText y $remMonths ${remMonths == 1 ? 'mes' : 'meses'}';
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${months[date.month - 1]}. ${date.year}';
  }

  Widget _buildNextGoalBanner() {
    final String stepTitle;
    final String stepBody;
    final Color color;
    final IconData icon;
    final double monthlyExtra =
        projectedEndOfMonthBuffer > 0 ? projectedEndOfMonthBuffer : 0.0;
    final double true45DayFree =
        monthlyExtra > 0 ? safeToSpend.clamp(0.0, monthlyExtra) : 0.0;
    final double cashSafeBeforePayday =
        (totalLiquidCash - obligationsBeforeNextPayday - safetyCushion)
            .clamp(0.0, double.infinity);
    final double safeToday =
        cashSafeBeforePayday.clamp(0.0, true45DayFree);
    final bool needsToWaitForPayday =
        nextPaydayDate != null && monthlyExtra > 0 && safeToday + 1 < true45DayFree;
    final bool reservedForNextMonth =
        monthlyExtra > 0 && true45DayFree + 1 < monthlyExtra;

    String timeframeNote() {
      if (reservedForNextMonth) {
        final reserveAmt = monthlyExtra - true45DayFree;
        if (true45DayFree <= 0) {
          return ' Reserva este monto para cubrir tus pagos de inicio del próximo mes antes de tu siguiente cobro.';
        }
        return ' De ese monto, reserva ${CurrencyFormat.formatMXN(reserveAmt, includeDecimals: false)} para pagos de inicio del próximo mes (libres reales: ${CurrencyFormat.formatMXN(true45DayFree, includeDecimals: false)}).';
      }
      if (needsToWaitForPayday) {
        final d = '${nextPaydayDate!.day}/${nextPaydayDate!.month}';
        if (safeToday >= 100) {
          return ' Hoy puedes mover hasta ${CurrencyFormat.formatMXN(safeToday, includeDecimals: false)}; el resto espera a tu cobro del $d.';
        }
        return ' Hazlo después de recibir tu cobro del $d.';
      }
      return '';
    }

    final String activeGoalKey = _resolveActiveGoalKey();
    VoidCallback? bannerTap;
    String? actionChipLabel;

    if (activeGoalKey == 'payDebtExtra') {
      stepTitle = 'Siguiente acción';
      if (monthlyExtra > 0) {
        final targetText = highestDebtCardName != null
            ? ' (prioriza $highestDebtCardName)'
            : '';
        final allocatable = true45DayFree > 0 ? true45DayFree : monthlyExtra;
        final afterDebt =
            (totalAllDebt - allocatable).clamp(0.0, double.infinity);
        stepBody =
            'Puedes abonar +${CurrencyFormat.formatMXN(allocatable, includeDecimals: false)} extra este mes$targetText y bajar tu deuda a ${CurrencyFormat.formatMXN(afterDebt, includeDecimals: false)}.${timeframeNote()}';
      } else {
        stepBody =
            'Enfócate en cubrir tus pagos del mes (${CurrencyFormat.formatMXN(totalDebt + pendingCommitments, includeDecimals: false)}) antes de usar tus ahorros.';
      }
      color = AppTheme.amberGold;
      icon = Icons.bolt_rounded;
    } else if (activeGoalKey == 'emergencyFund') {
      stepTitle = 'Siguiente acción';
      if (!hasEmergencyAccountLinked) {
        stepBody =
            'Marca una cuenta en Cuentas como "Fondo de Emergencia" para apartar tu dinero ahí.';
        bannerTap = onOpenAccountsTab;
        actionChipLabel = onOpenAccountsTab != null ? 'Ir a Cuentas' : null;
      } else if (monthlyExtra > 0) {
        final allocatable = true45DayFree > 0 ? true45DayFree : monthlyExtra;
        stepBody = reservedForNextMonth && true45DayFree <= 0
            ? 'Aunque cierras el mes con +${CurrencyFormat.formatMXN(monthlyExtra, includeDecimals: false)}, guárdalos por ahora: los necesitarás para pagos de inicio del próximo mes.'
            : 'Destina +${CurrencyFormat.formatMXN(allocatable, includeDecimals: false)} a tu Fondo de Emergencia.${timeframeNote()}';
        if (!(reservedForNextMonth && true45DayFree <= 0) &&
            onTransferToEmergencyFund != null) {
          final double defaultTransfer =
              safeToday >= 100 ? safeToday : allocatable;
          bannerTap = () => onTransferToEmergencyFund!(defaultTransfer);
          actionChipLabel = 'Apartar';
        }
      } else {
        stepBody =
            'Mantén tus gastos bajo control para seguir sumando a tu meta de respaldo.';
      }
      color = AppTheme.electricCyan;
      icon = Icons.shield_moon_outlined;
    } else {
      stepTitle = 'Siguiente acción';
      stepBody = monthlyExtra > 0
          ? 'Tus pagos del periodo están considerados. Tu excedente (+${CurrencyFormat.formatMXN(true45DayFree > 0 ? true45DayFree : monthlyExtra, includeDecimals: false)}) está listo para inversión.${timeframeNote()}'
          : 'Pagos del periodo al día. Todo ingreso extra irá directo a crecimiento.';
      color = AppTheme.emeraldGreen;
      icon = Icons.trending_up_rounded;
    }

    return InkWell(
      onTap: bannerTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.3,
                  ),
                  children: [
                    TextSpan(
                      text: '$stepTitle • ',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, color: color),
                    ),
                    TextSpan(text: stepBody),
                  ],
                ),
              ),
            ),
            if (actionChipLabel != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  actionChipLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthVerdictBanner() {
    final bool hasMidMonthDip =
        lowestTimelineBalance < -0.5 && lowestTimelineDate != null;
    final bool isCovered = !hasMidMonthDip && projectedEndOfMonthBuffer >= 0;
    final double true45DayFree = projectedEndOfMonthBuffer > 0
        ? safeToSpend.clamp(0.0, projectedEndOfMonthBuffer)
        : 0.0;
    final bool needsReserveForNextMonth =
        isCovered && projectedEndOfMonthBuffer > 0 && true45DayFree + 1 < projectedEndOfMonthBuffer;
    final Color tone = isCovered
        ? (needsReserveForNextMonth ? AppTheme.amberGold : AppTheme.emeraldGreen)
        : (canCoverWithReserves ? AppTheme.amberGold : AppTheme.alertCoral);
    final IconData icon = isCovered
        ? (needsReserveForNextMonth
            ? Icons.schedule_rounded
            : Icons.check_circle_outline)
        : (canCoverWithReserves
            ? Icons.savings_outlined
            : Icons.warning_amber_rounded);

    final String text;
    if (hasMidMonthDip) {
      text =
          'Ojo con las fechas: el ${lowestTimelineDate!.day}/${lowestTimelineDate!.month} tendrías un faltante temporal de ${CurrencyFormat.formatMXN(-lowestTimelineBalance, includeDecimals: false)} antes de tu siguiente cobro (mira "Por Fechas" abajo).';
    } else if (isCovered) {
      if (needsReserveForNextMonth) {
        final reserveAmt = projectedEndOfMonthBuffer - true45DayFree;
        text =
            'Tu mes cierra con +${CurrencyFormat.formatMXN(projectedEndOfMonthBuffer, includeDecimals: false)}, pero ${CurrencyFormat.formatMXN(reserveAmt, includeDecimals: false)} se ocuparán en pagos de inicio del próximo mes antes de tu siguiente cobro. Libres reales: ${CurrencyFormat.formatMXN(true45DayFree, includeDecimals: false)}.';
      } else if (upcomingIncome > 0 && nextPaydayDate != null) {
        final d = '${nextPaydayDate!.day}/${nextPaydayDate!.month}';
        text =
            'Tu cobro del $d (${CurrencyFormat.formatMXN(upcomingIncome, includeDecimals: false)}) llega a tiempo para tus tarjetas y fijos: quedarían +${CurrencyFormat.formatMXN(projectedEndOfMonthBuffer, includeDecimals: false)} libres a partir del $d.';
      } else if (upcomingIncome > 0) {
        text =
            'Tu mes está cubierto: quedarían +${CurrencyFormat.formatMXN(projectedEndOfMonthBuffer, includeDecimals: false)} libres al recibir tus ${CurrencyFormat.formatMXN(upcomingIncome, includeDecimals: false)} por cobrar.';
      } else {
        text =
            'Tu mes está cubierto con +${CurrencyFormat.formatMXN(projectedEndOfMonthBuffer, includeDecimals: false)} libres.';
      }
    } else if (canCoverWithReserves) {
      text =
          'Faltan ${CurrencyFormat.formatMXN(-projectedEndOfMonthBuffer, includeDecimals: false)} con ingresos del mes, pero puedes cubrirlo con tus reservas de respaldo.';
    } else {
      text =
          'Faltan ${CurrencyFormat.formatMXN(-projectedEndOfMonthBuffer, includeDecimals: false)} para cubrir tus pendientes de este mes.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withOpacity(0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: tone),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.92),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
