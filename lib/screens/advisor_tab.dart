import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/financial_insight.dart';
import '../../providers/finance_provider.dart';

class AdvisorTab extends StatelessWidget {
  final FinanceProvider provider;

  const AdvisorTab({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final analysis = provider.analysis;

    // Calculate dynamic health score
    int score = 65;
    if (analysis.savingsRate >= 20) score += 15;
    if (analysis.runwayMonths >= 3) score += 10;
    if (analysis.monthlyPassiveYield >= 500) score += 10;
    if (analysis.totalDebt > analysis.totalLiquidCash) score -= 20;
    score = score.clamp(10, 100);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const Text(
                        '/ 100',
                        style: TextStyle(fontSize: 9, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SUPER ASESOR FINANCIERO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 0.8),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Diagnóstico en Tiempo Real',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Basado en tus hábitos de gasto, reservas de emergencia y rendimientos pasivos.',
                        style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Key metrics row
          Row(
            children: [
              Expanded(
                child: _buildAdvisorStat(
                  'Supervivencia / Runway',
                  '${analysis.runwayMonths.toStringAsFixed(1)} meses',
                  Icons.shield_outlined,
                  AppTheme.electricCyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAdvisorStat(
                  'Tasa de Ahorro',
                  '${analysis.savingsRate.toStringAsFixed(0)}%',
                  Icons.trending_up,
                  AppTheme.emeraldGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section Insights
          const Text(
            'Recomendaciones y Acciones',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 12),
          ...analysis.insights.map((insight) => _buildInsightCard(insight)),
        ],
      ),
    );
  }

  Widget _buildAdvisorStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(FinancialInsight insight) {
    Color cardColor = AppTheme.electricCyan;
    IconData icon = Icons.info_outline;

    if (insight.type == InsightType.opportunity) {
      cardColor = AppTheme.amberGold;
      icon = Icons.auto_awesome;
    } else if (insight.type == InsightType.warning) {
      cardColor = AppTheme.alertCoral;
      icon = Icons.warning_amber_rounded;
    } else if (insight.type == InsightType.praise) {
      cardColor = AppTheme.emeraldGreen;
      icon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: cardColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cardColor),
                ),
              ),
              if (insight.highlightMetric != null)
                Text(
                  insight.highlightMetric!,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.message,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }
}
