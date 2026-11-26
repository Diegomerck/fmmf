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
              'Desglose de Safe-to-Spend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Incluye tus cuentas de liquidez y ahorros destinados a tarjetas o gastos. Tus ahorros protegidos no se tocan aquí.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            _row('Liquidez operativa y fondos asignados', totalLiquidCash, AppTheme.emeraldGreen),
            const SizedBox(height: 8),
            _row('− Pago del mes en Tarjetas de Crédito', -totalDebt, AppTheme.alertCoral),
            if (pendingCommitments > 0) ...[
              const SizedBox(height: 8),
              _row('− Gastos Fijos Mensuales pendientes', -pendingCommitments, AppTheme.amberGold),
            ],
            if (safetyCushion > 0) ...[
              const SizedBox(height: 8),
              _row('− Colchón de seguridad mínimo', -safetyCushion, AppTheme.amberGold),
            ],
            const Divider(color: AppTheme.border, height: 24),
            _row('= Disponible Seguro (Safe-to-Spend)', safeToSpend, AppTheme.electricCyan, bold: true),
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

  @override
  Widget build(BuildContext context) {
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border.withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.electricCyan.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.electricCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.electricCyan.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: AppTheme.electricCyan),
                        SizedBox(width: 4),
                        Text(
                          'SAFE-TO-SPEND',
                          style: TextStyle(
                            color: AppTheme.electricCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
              IconButton(
                icon: const Icon(Icons.bolt, color: AppTheme.emeraldGreen, size: 26),
                tooltip: 'Registro Rápido',
                onPressed: onQuickAdd,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormat.formatMXN(safeToSpend),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Disponible real descontando deudas, cortes de tarjeta y gastos fijos.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Patrimonio Neto',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormat.formatMXN(netWorth, includeDecimals: false),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: Colors.white12),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rendimiento Pasivo / Mes',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+${CurrencyFormat.formatMXN(monthlyPassiveYield, includeDecimals: false)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.emeraldGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
