import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../providers/finance_provider.dart';
import '../services/storage_service.dart';
import 'accounts_tab.dart';
import 'dashboard_tab.dart';
import 'plan_tab.dart';
import 'settings_tab.dart';
import 'setup_wizard_screen.dart';
import 'transactions_tab.dart';
import 'widgets/quick_entry_sheet.dart';

class HomeScreen extends StatefulWidget {
  final FinanceProvider provider;
  final String? userEmail;
  final Future<void> Function()? onSignOut;

  const HomeScreen({
    super.key,
    required this.provider,
    this.userEmail,
    this.onSignOut,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _showSetupWizard = false;
  bool _checkedInitialSetup = false;

  @override
  void initState() {
    super.initState();
    _showSetupWizard = widget.provider.accounts.isEmpty;
    _checkedInitialSetup = true;
  }

  @override
  Widget build(BuildContext context) {
    if (_checkedInitialSetup && _showSetupWizard) {
      return SetupWizardScreen(
        provider: widget.provider,
        onComplete: () => setState(() => _showSetupWizard = false),
      );
    }

    final titles = [
      'FMMF',
      'Movimientos',
      'Cuentas',
      'Plan y Asesor',
      'Ajustes',
    ];

    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final List<Widget> tabs = [
          DashboardTab(
            provider: widget.provider,
            onNavigateToTab: (index) => setState(() => _currentIndex = index),
          ),
          TransactionsTab(provider: widget.provider),
          AccountsTab(provider: widget.provider),
          PlanTab(provider: widget.provider),
          SettingsTab(
            provider: widget.provider,
            userEmail: widget.userEmail,
            onOpenSetupWizard: () => setState(() => _showSetupWizard = true),
            onSignOut: widget.onSignOut,
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldGreen.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'FMMF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.emeraldGreen,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  titles[_currentIndex],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            actions: [
              ValueListenableBuilder<CloudSyncStatus>(
                valueListenable: widget.provider.syncStatus,
                builder: (context, status, _) {
                  switch (status) {
                    case CloudSyncStatus.syncing:
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.electricCyan,
                            ),
                          ),
                        ),
                      );
                    case CloudSyncStatus.error:
                      return IconButton(
                        icon: const Icon(Icons.cloud_off_outlined,
                            color: AppTheme.alertCoral),
                        tooltip: 'Error de sincronización (toca para reintentar)',
                        onPressed: () async {
                          final ok = await widget.provider.retryCloudSync();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: ok
                                    ? AppTheme.emeraldGreen
                                    : AppTheme.alertCoral,
                                content: Text(
                                  ok
                                      ? 'Datos sincronizados con la nube.'
                                      : 'No se pudo sincronizar: ${widget.provider.lastSyncError ?? ''}',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      );
                    case CloudSyncStatus.synced:
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Tooltip(
                          message: 'Sincronizado en la nube',
                          child: Icon(Icons.cloud_done_outlined,
                              size: 20, color: AppTheme.emeraldGreen),
                        ),
                      );
                    case CloudSyncStatus.idle:
                      return const SizedBox.shrink();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.bolt, color: AppTheme.emeraldGreen),
                tooltip: 'Nuevo Movimiento',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => QuickEntrySheet(provider: widget.provider),
                  );
                },
              ),
            ],
          ),
          body: tabs[_currentIndex],
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              backgroundColor: AppTheme.surface,
              selectedItemColor: AppTheme.emeraldGreen,
              unselectedItemColor: AppTheme.textMuted,
              selectedFontSize: 11,
              unselectedFontSize: 10,
              type: BottomNavigationBarType.fixed,
              onTap: (index) => setState(() => _currentIndex = index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Resumen',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long),
                  label: 'Movimientos',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_outlined),
                  activeIcon: Icon(Icons.account_balance),
                  label: 'Cuentas',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.event_note_outlined),
                  activeIcon: Icon(Icons.event_note),
                  label: 'Plan',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Ajustes',
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppTheme.emeraldGreen,
            foregroundColor: Colors.white,
            elevation: 6,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, size: 28),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => QuickEntrySheet(provider: widget.provider),
              );
            },
          ),
        );
      },
    );
  }
}
