import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/finance_provider.dart';
import '../../services/storage_service.dart';

/// Displays the live Firebase cloud sync status icon in the top-right AppBar.
class CloudSyncBadge extends StatelessWidget {
  final FinanceProvider provider;

  const CloudSyncBadge({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CloudSyncStatus>(
      valueListenable: provider.syncStatus,
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
              icon: const Icon(
                Icons.cloud_off_outlined,
                color: AppTheme.alertCoral,
              ),
              tooltip: 'Error de sincronización (toca para reintentar)',
              onPressed: () => provider.retryCloudSync(),
            );
          case CloudSyncStatus.synced:
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Tooltip(
                message: 'Sincronizado en la nube',
                child: Icon(
                  Icons.cloud_done_outlined,
                  size: 20,
                  color: AppTheme.emeraldGreen,
                ),
              ),
            );
          case CloudSyncStatus.idle:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

