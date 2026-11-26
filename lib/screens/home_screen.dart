import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/file_backup_helper.dart';
import '../providers/finance_provider.dart';
import 'accounts_tab.dart';
import 'dashboard_tab.dart';
import 'plan_tab.dart';
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                color: AppTheme.card,
                onSelected: (value) async {
                  if (value == 'wizard') {
                    setState(() => _showSetupWizard = true);
                  } else if (value == 'export') {
                    final jsonStr = widget.provider.exportBackupJson();
                    final now = DateTime.now();
                    final dateTag =
                        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                    await downloadJsonFile('fmmf_respaldo_$dateTag.json', jsonStr);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppTheme.emeraldGreen,
                          content: Text('Archivo descargado: fmmf_respaldo_$dateTag.json'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } else if (value == 'import') {
                    final pickedContent = await pickJsonFileContent();
                    if (pickedContent != null) {
                      final ok = await widget.provider.importBackupJson(pickedContent.trim());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: ok ? AppTheme.emeraldGreen : AppTheme.alertCoral,
                            content: Text(ok ? 'Respaldo importado correctamente.' : 'Archivo JSON inválido.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } else if (context.mounted) {
                      final ctrl = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppTheme.card,
                          title: const Text('Importar Respaldo (JSON)', style: TextStyle(color: Colors.white, fontSize: 16)),
                          content: TextField(
                            controller: ctrl,
                            maxLines: 6,
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Pega aquí el JSON exportado...',
                              hintStyle: const TextStyle(color: AppTheme.textMuted),
                              filled: true,
                              fillColor: AppTheme.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, foregroundColor: Colors.white),
                              onPressed: () async {
                                final ok = await widget.provider.importBackupJson(ctrl.text.trim());
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: ok ? AppTheme.emeraldGreen : AppTheme.alertCoral,
                                      content: Text(ok ? 'Respaldo restaurado correctamente.' : 'JSON inválido. Verifica el respaldo.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Restaurar'),
                            ),
                          ],
                        ),
                      );
                    }
                  } else if (value == 'clear') {
                    if (!context.mounted) return;
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.card,
                        title: const Text('¿Borrar todos los datos?', style: TextStyle(color: Colors.white, fontSize: 16)),
                        content: const Text(
                          'Se eliminarán todas tus cuentas, movimientos, reglas de ahorro y calendario. Esta acción no se puede deshacer.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertCoral, foregroundColor: Colors.white),
                            onPressed: () async {
                              await widget.provider.clearAllData();
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                setState(() => _showSetupWizard = true);
                              }
                            },
                            child: const Text('Sí, borrar todo'),
                          ),
                        ],
                      ),
                    );
                  } else if (value == 'logout' && widget.onSignOut != null) {
                    await widget.onSignOut!();
                  }
                },
                itemBuilder: (context) => [
                  if (widget.userEmail != null)
                    PopupMenuItem(
                      enabled: false,
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 16, color: AppTheme.emeraldGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.userEmail!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'wizard',
                    child: Row(
                      children: [
                        Icon(Icons.auto_fix_high, size: 18, color: AppTheme.amberGold),
                        SizedBox(width: 8),
                        Text('Asistente de Configuración', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.download_outlined, size: 18, color: AppTheme.electricCyan),
                        SizedBox(width: 8),
                        Text('Exportar Respaldo (JSON)', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: Row(
                      children: [
                        Icon(Icons.upload_outlined, size: 18, color: AppTheme.emeraldGreen),
                        SizedBox(width: 8),
                        Text('Importar Respaldo (JSON)', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever_outlined, size: 18, color: AppTheme.alertCoral),
                        SizedBox(width: 8),
                        Text('Borrar Todos los Datos', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (widget.onSignOut != null)
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 18, color: AppTheme.textSecondary),
                          SizedBox(width: 8),
                          Text('Cerrar Sesión', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                ],
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
