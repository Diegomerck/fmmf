import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/file_backup_helper.dart';
import '../providers/finance_provider.dart';
import '../services/storage_service.dart';
import 'widgets/confirm_delete_dialog.dart';

class SettingsTab extends StatefulWidget {
  final FinanceProvider provider;
  final String? userEmail;
  final VoidCallback onOpenSetupWizard;
  final Future<void> Function()? onSignOut;

  const SettingsTab({
    super.key,
    required this.provider,
    required this.onOpenSetupWizard,
    this.userEmail,
    this.onSignOut,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _dangerExpanded = false;

  Future<void> _exportBackup() async {
    final jsonStr = widget.provider.exportBackupJson();
    final now = DateTime.now();
    final dateTag =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await downloadJsonFile('fmmf_respaldo_$dateTag.json', jsonStr);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.emeraldGreen,
          content: Text('Archivo descargado: fmmf_respaldo_$dateTag.json'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _importBackup() async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: '¿Importar respaldo?',
      message:
          'Al restaurar un respaldo JSON se reemplazarán tus datos actuales con los del archivo.',
      confirmLabel: 'Continuar',
    );
    if (!confirmed || !mounted) return;

    final pickedContent = await pickJsonFileContent();
    if (pickedContent != null) {
      final ok = await widget.provider.importBackupJson(pickedContent.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ok ? AppTheme.emeraldGreen : AppTheme.alertCoral,
            content: Text(
              ok
                  ? 'Respaldo importado correctamente.'
                  : 'Archivo JSON inválido.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text(
          'Importar Respaldo (JSON)',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
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
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final ok = await widget.provider.importBackupJson(ctrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor:
                        ok ? AppTheme.emeraldGreen : AppTheme.alertCoral,
                    content: Text(
                      ok
                          ? 'Respaldo restaurado correctamente.'
                          : 'JSON inválido. Verifica el respaldo.',
                    ),
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

  Future<void> _confirmSignOut() async {
    if (widget.onSignOut == null) return;
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: '¿Cerrar sesión?',
      message:
          'Tus datos permanecen guardados de forma segura en tu cuenta de la nube.',
      confirmLabel: 'Cerrar sesión',
    );
    if (confirmed) {
      await widget.onSignOut!();
    }
  }

  Future<void> _confirmClearAllData() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final matches = ctrl.text.trim().toUpperCase() == 'BORRAR';
          return AlertDialog(
            backgroundColor: AppTheme.card,
            title: const Text(
              '¿Borrar todos los datos?',
              style: TextStyle(
                color: AppTheme.alertCoral,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Se eliminarán permanentemente todas tus cuentas, movimientos, gastos fijos, planes MSI, reglas de ahorro y calendario. Esta acción no se puede deshacer.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Escribe BORRAR para confirmar:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'BORRAR',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertCoral,
                  foregroundColor: Colors.white,
                ),
                onPressed: matches ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Sí, borrar todo'),
              ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();

    if (confirmed == true) {
      await widget.provider.clearAllData();
      if (mounted) {
        widget.onOpenSetupWizard();
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _buildSectionHeader('Cuenta'),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.verified_user_outlined,
                    color: AppTheme.emeraldGreen),
                title: const Text(
                  'Sesión sincronizada',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  widget.userEmail ?? 'Modo local',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: ValueListenableBuilder<CloudSyncStatus>(
                  valueListenable: widget.provider.syncStatus,
                  builder: (context, status, _) {
                    if (status == CloudSyncStatus.error) {
                      return TextButton.icon(
                        onPressed: () => widget.provider.retryCloudSync(),
                        icon: const Icon(Icons.sync_problem,
                            size: 16, color: AppTheme.alertCoral),
                        label: const Text('Reintentar',
                            style: TextStyle(
                                color: AppTheme.alertCoral, fontSize: 12)),
                      );
                    }
                    if (status == CloudSyncStatus.syncing) {
                      return const Text('Sincronizando...',
                          style: TextStyle(
                              color: AppTheme.electricCyan, fontSize: 12));
                    }
                    if (status == CloudSyncStatus.synced) {
                      return const Text('En la nube',
                          style: TextStyle(
                              color: AppTheme.emeraldGreen, fontSize: 12));
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              if (widget.onSignOut != null) ...[
                const Divider(height: 1, color: AppTheme.border),
                ListTile(
                  leading:
                      const Icon(Icons.logout, color: AppTheme.textSecondary),
                  title: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppTheme.textMuted),
                  onTap: _confirmSignOut,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Configuración y Respaldos'),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              ListTile(
                leading:
                    const Icon(Icons.auto_fix_high, color: AppTheme.amberGold),
                title: const Text(
                  'Asistente de Configuración',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Configura tus cuentas iniciales paso a paso',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                onTap: widget.onOpenSetupWizard,
              ),
              const Divider(height: 1, color: AppTheme.border),
              ListTile(
                leading: const Icon(Icons.download_outlined,
                    color: AppTheme.electricCyan),
                title: const Text(
                  'Exportar Respaldo (JSON)',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Descarga una copia de toda tu información',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                onTap: _exportBackup,
              ),
              const Divider(height: 1, color: AppTheme.border),
              ListTile(
                leading: const Icon(Icons.upload_outlined,
                    color: AppTheme.emeraldGreen),
                title: const Text(
                  'Importar Respaldo (JSON)',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Restaura un archivo JSON guardado previamente',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                onTap: _importBackup,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildSectionHeader('Zona de Peligro'),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.alertCoral.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.alertCoral.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.alertCoral),
                title: const Text(
                  'Opciones destructivas',
                  style: TextStyle(
                    color: AppTheme.alertCoral,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Despliega para restablecer o borrar datos',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: Icon(
                  _dangerExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppTheme.alertCoral,
                ),
                onTap: () =>
                    setState(() => _dangerExpanded = !_dangerExpanded),
              ),
              if (_dangerExpanded) ...[
                Divider(
                    height: 1, color: AppTheme.alertCoral.withOpacity(0.25)),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined,
                      color: AppTheme.alertCoral),
                  title: const Text(
                    'Borrar Todos los Datos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Elimina cuentas, movimientos y planes de forma permanente',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppTheme.alertCoral),
                  onTap: _confirmClearAllData,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

