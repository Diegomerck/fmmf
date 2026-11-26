import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_format.dart';
import '../../models/account.dart';
import '../../providers/finance_provider.dart';

class YieldsTab extends StatelessWidget {
  final FinanceProvider provider;

  const YieldsTab({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final analysis = provider.analysis;
    final yieldAccounts = provider.accounts.where((a) => a.annualYieldRate > 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flagship Yield Hero Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.purpleGlow.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DINERO TRABAJANDO POR TI',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt, size: 12, color: AppTheme.emeraldGreen),
                          SizedBox(width: 4),
                          Text(
                            'Generando 24/7',
                            style: TextStyle(fontSize: 10, color: AppTheme.emeraldGreen, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '+${CurrencyFormat.formatMXN(analysis.monthlyPassiveYield)}',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  'estimado pasivo al mes sin trabajar',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(height: 18),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Al Año (Run-rate)', style: TextStyle(fontSize: 11, color: Colors.white60)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormat.formatMXN(analysis.annualPassiveRunRate, includeDecimals: false),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rendimiento Diario', style: TextStyle(fontSize: 11, color: Colors.white60)),
                          const SizedBox(height: 2),
                          Text(
                            '+${CurrencyFormat.formatMXN(analysis.monthlyPassiveYield / 30.4, includeDecimals: true)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Lazy Money Diagnostic
          if (analysis.lazyMoneyAmount > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.amberGold.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bedtime_outlined, color: AppTheme.amberGold, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Detector de Dinero Dormido (Lazy Cash)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.amberGold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tienes \$${CurrencyFormat.formatMXN(analysis.lazyMoneyAmount, includeDecimals: false)} en cuentas de cheques/nómina que no generan nada (0% de rendimiento).',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Costo de oportunidad perdido:', style: TextStyle(fontSize: 12, color: Colors.white)),
                        Text(
                          '-\$${(analysis.lazyMoneyAnnualLostYield / 12).toStringAsFixed(0)} MXN/mes',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.alertCoral),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Yield Accounts Breakdown
          const Text(
            'Tus Cuentas de Rendimiento',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 12),
          if (yieldAccounts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No has agregado cuentas de rendimiento aún.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ...yieldAccounts.map((acc) => _buildYieldAccountCard(acc)),
        ],
      ),
    );
  }

  Widget _buildYieldAccountCard(Account acc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                acc.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.purpleGlow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${CurrencyFormat.formatRate(acc.annualYieldRate)} Anual',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.purpleGlow),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(acc.institution, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Capital Invertido', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormat.formatMXN(acc.balance),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Rendimiento / Mes', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    '+${CurrencyFormat.formatMXN(acc.monthlyYieldGenerated)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.emeraldGreen),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

