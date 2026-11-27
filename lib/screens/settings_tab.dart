import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/currency_format.dart';
import '../core/utils/file_backup_helper.dart';
import '../main.dart' show kAppVersion;
import '../providers/finance_provider.dart';
import '../services/storage_service.dart';
import 'categories_screen.dart';
import 'funding_priority_screen.dart';
import 'surplus_goals_screen.dart';
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

  Future<void> _editEmergencyMonths() async {
    int selected = widget.provider.emergencyFundMonths;
    const options = [1, 2, 3, 6, 9, 12];
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: const Text(
            'Meta de Fondo de Emergencia',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Elige cuántos meses de gastos fijos quieres tener cubiertos como meta personal:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: options.map((m) {
                  final isSel = selected == m;
                  return ChoiceChip(
                    label: Text('$m ${m == 1 ? 'mes' : 'meses'}'),
                    selected: isSel,
                    selectedColor: AppTheme.electricCyan.withOpacity(0.28),
                    backgroundColor: AppTheme.surface,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setDialogState(() => selected = m),
                  );
                }).toList(),
              ),
            ],
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
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await widget.provider.updateEmergencyFundMonths(result);
      if (mounted) setState(() {});
    }
  }

  Future<void> _editSafetyCushion() async {
    final ctrl = TextEditingController(
      text: widget.provider.safetyCushion > 0
          ? widget.provider.safetyCushion.toStringAsFixed(0)
          : '0',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text(
          'Colchón mínimo de seguridad',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monto en pesos que quieres reservar sin tocar al calcular tu "Disponible Hoy" (déjalo en 0 si no deseas reserva extra):',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Colchón (MXN)',
                prefixText: '\$ ',
              ),
            ),
          ],
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
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final parsed =
                  double.tryParse(ctrl.text.trim().replaceAll(',', '')) ?? 0.0;
              Navigator.pop(ctx, parsed < 0 ? 0.0 : parsed);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) {
      await widget.provider.updateSafetyCushion(result);
      if (mounted) setState(() {});
    }
  }

  Future<void> _showAndroidDownloadDialog() async {
    const apkUrl =
        'https://github.com/Diegomerck/fmmf-releases/releases/latest/download/FMMF-latest.apk';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.emeraldGreen.withOpacity(0.35)),
        ),
        title: const Row(
          children: [
            Icon(Icons.android_rounded, color: AppTheme.emeraldGreen, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Descargar FMMF para Android',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Instala la app nativa en tu teléfono Android en 3 sencillos pasos:',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              _buildApkInstallStep(
                stepNumber: '1',
                title: 'Descarga el archivo APK',
                description:
                    'Toca "DESCARGAR AHORA" para bajar FMMF-latest.apk directamente a tu dispositivo.',
              ),
              const SizedBox(height: 10),
              _buildApkInstallStep(
                stepNumber: '2',
                title: 'Permite fuentes desconocidas',
                description:
                    'Si Android lo solicita, activa "Instalar apps desconocidas" para tu navegador o gestor de archivos.',
              ),
              const SizedBox(height: 10),
              _buildApkInstallStep(
                stepNumber: '3',
                title: 'Instala y abre FMMF',
                description:
                    'Abre el archivo descargado, presiona "Instalar" e inicia sesión con tu cuenta para sincronizar tus datos.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emeraldGreen,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text(
              'DESCARGAR AHORA',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final launched = await openExternalDownloadUrl(
                apkUrl,
                filename: 'FMMF-latest.apk',
              );
              if (mounted && !launched) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.electricCyan,
                    content: Text(
                      'Descarga disponible desde la versión web o GitHub Releases.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildApkInstallStep({
    required String stepNumber,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.emeraldGreen.withOpacity(0.16),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.emeraldGreen, width: 1.4),
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: const TextStyle(
              color: AppTheme.emeraldGreen,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
        _buildSectionHeader('Metas y Parámetros'),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.shield_moon_outlined,
                    color: AppTheme.electricCyan),
                title: const Text(
                  'Activar Meta de Fondo de Emergencia',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  widget.provider.emergencyFundEnabled
                      ? 'Calculando respaldo libre después de deudas'
                      : 'Desactivada en Resumen y Prioridades',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                value: widget.provider.emergencyFundEnabled,
                activeColor: AppTheme.emeraldGreen,
                onChanged: (val) async {
                  await widget.provider.updateEmergencyFundEnabled(val);
                  if (mounted) setState(() {});
                },
              ),
              if (widget.provider.emergencyFundEnabled) ...[
                const Divider(height: 1, color: AppTheme.border),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined,
                      color: AppTheme.electricCyan),
                  title: const Text(
                    'Meta de Fondo de Emergencia',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Objetivo actual: ${widget.provider.emergencyFundMonths} ${widget.provider.emergencyFundMonths == 1 ? 'mes' : 'meses'} de gastos fijos',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppTheme.textMuted),
                  onTap: _editEmergencyMonths,
                ),
              ],
              const Divider(height: 1, color: AppTheme.border),
              ListTile(
                leading: const Icon(Icons.flag_outlined,
                    color: AppTheme.emeraldGreen),
                title: const Text(
                  'Prioridad de Metas (Excedente)',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Ordena qué hacer con tu dinero sobrante',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SurplusGoalsScreen(provider: widget.provider),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: AppTheme.border),
              ListTile(
                leading: const Icon(Icons.lock_clock_outlined,
                    color: AppTheme.emeraldGreen),
                title: const Text(
                  'Colchón mínimo (Disponible Hoy)',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  widget.provider.safetyCushion > 0
                      ? 'Reservando ${CurrencyFormat.formatMXN(widget.provider.safetyCushion, includeDecimals: false)} sin tocar'
                      : 'Sin colchón extra (\$0)',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                onTap: _editSafetyCushion,
              ),
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
                leading: const Icon(Icons.category_outlined,
                    color: AppTheme.electricCyan),
                title: const Text(
                  'Categorías de Movimientos',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Agrega, edita o personaliza íconos y colores',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CategoriesScreen(provider: widget.provider),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: AppTheme.border),
              ListTile(
                leading: const Icon(Icons.low_priority_outlined,
                    color: AppTheme.amberGold),
                title: const Text(
                  'Prioridad para Cubrir Faltantes',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Elige qué ahorros sugerir primero o al final',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FundingPriorityScreen(provider: widget.provider),
                    ),
                  );
                },
              ),
              const Divider(height: 1, color: AppTheme.border),
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
        const SizedBox(height: 24),
        _buildSectionHeader('Aplicación y Versión'),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.android_rounded,
                    color: AppTheme.emeraldGreen),
                title: const Text(
                  'Descargar App para Android (APK)',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Descarga e instala la versión nativa directamente aquí',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.download_rounded, color: AppTheme.emeraldGreen),
                onTap: _showAndroidDownloadDialog,
              ),
              const Divider(height: 1, color: AppTheme.border),
              const ListTile(
                leading: Icon(Icons.info_outline,
                    color: AppTheme.electricCyan),
                title: Text(
                  'Versión de FMMF',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                trailing: Text(
                  'v$kAppVersion',
                  style: TextStyle(
                    color: AppTheme.electricCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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

