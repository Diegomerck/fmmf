import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';

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
    required this.onQuickAdd,
  });

  void _showBreakdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Desglose de Margen Libre',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              lowestTimelineDate != null
                  ? 'Es el saldo más bajo de tus próximos 45 días (el ${lowestTimelineDate!.day}/${lowestTimelineDate!.month} en "Por Fechas") tras sumar cobros y restar pagos.'
                  : 'Calculado con tu dinero actual menos tus pagos próximos.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            _row('Liquidez operativa hoy', totalLiquidCash, AppTheme.emeraldGreen),
            const SizedBox(height: 8),
            _row(
              '− Reservado para cubrir fechas próximas',
              -((totalLiquidCash - lowestTimelineBalance).clamp(0.0, double.infinity)),
              AppTheme.alertCoral,
            ),
            if (safetyCushion > 0) ...[
              const SizedBox(height: 8),
              _row('− Colchón de seguridad mínimo', -safetyCushion, AppTheme.amberGold),
            ],
            const Divider(color: AppTheme.border, height: 24),
            _row('= Margen Libre', safeToSpend, AppTheme.electricCyan, bold: true),
            const SizedBox(height: 14),
          ],
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
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.bolt, color: AppTheme.emeraldGreen, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Registro Rápido',
                onPressed: onQuickAdd,
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

  Widget _buildNextGoalBanner() {
    final String stepTitle;
    final String stepBody;
    final Color color;
    final IconData icon;
    final double monthlyExtra =
        projectedEndOfMonthBuffer > 0 ? projectedEndOfMonthBuffer : 0.0;
    final String activeGoalKey = _resolveActiveGoalKey();

    if (activeGoalKey == 'payDebtExtra') {
      stepTitle = 'Siguiente acción';
      if (monthlyExtra > 0) {
        final targetText = highestDebtCardName != null
            ? ' (prioriza $highestDebtCardName)'
            : '';
        final afterDebt =
            (totalAllDebt - monthlyExtra).clamp(0.0, double.infinity);
        stepBody =
            'Puedes abonar +${CurrencyFormat.formatMXN(monthlyExtra, includeDecimals: false)} extra este mes$targetText y bajar tu deuda a ${CurrencyFormat.formatMXN(afterDebt, includeDecimals: false)}.';
      } else {
        stepBody =
            'Enfócate en cubrir tus pagos del mes (${CurrencyFormat.formatMXN(totalDebt + pendingCommitments, includeDecimals: false)}) antes de usar tus ahorros.';
      }
      color = AppTheme.amberGold;
      icon = Icons.bolt_rounded;
    } else if (activeGoalKey == 'emergencyFund') {
      stepTitle = 'Siguiente acción';
      stepBody = monthlyExtra > 0
          ? 'Destina +${CurrencyFormat.formatMXN(monthlyExtra, includeDecimals: false)} de tu excedente de este mes a tu Fondo de Emergencia.'
          : 'Mantén tus gastos bajo control para seguir sumando a tu meta de respaldo.';
      color = AppTheme.electricCyan;
      icon = Icons.shield_moon_outlined;
    } else {
      stepTitle = 'Siguiente acción';
      stepBody = monthlyExtra > 0
          ? 'Tus pagos del periodo están considerados. Tu excedente (+${CurrencyFormat.formatMXN(monthlyExtra, includeDecimals: false)}) está listo para inversión.'
          : 'Pagos del periodo al día. Todo ingreso extra irá directo a crecimiento.';
      color = AppTheme.emeraldGreen;
      icon = Icons.trending_up_rounded;
    }

    return Container(
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
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                  TextSpan(text: stepBody),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthVerdictBanner() {
    final bool hasMidMonthDip =
        lowestTimelineBalance < -0.5 && lowestTimelineDate != null;
    final bool isCovered = !hasMidMonthDip && projectedEndOfMonthBuffer >= 0;
    final Color tone = isCovered
        ? AppTheme.emeraldGreen
        : (canCoverWithReserves ? AppTheme.amberGold : AppTheme.alertCoral);
    final IconData icon = isCovered
        ? Icons.check_circle_outline
        : (canCoverWithReserves
            ? Icons.savings_outlined
            : Icons.warning_amber_rounded);

    final String text;
    if (hasMidMonthDip) {
      text =
          'Ojo con las fechas: el ${lowestTimelineDate!.day}/${lowestTimelineDate!.month} tendrías un faltante temporal de ${CurrencyFormat.formatMXN(-lowestTimelineBalance, includeDecimals: false)} antes de tu siguiente cobro (mira "Por Fechas" abajo).';
    } else if (isCovered) {
      if (upcomingIncome > 0) {
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
