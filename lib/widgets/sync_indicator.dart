import 'package:car_maintenance_tracker/utils/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_service.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (context, sync, _) {
        if (sync.lastSyncError != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(sync.lastSyncError!),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          });
        }

        if (sync.isSyncing) {
          return const Padding(
            padding: EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          );
        }

        if (!ConnectivityState().isServiceAvailable) {
          return const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Tooltip(
              message: "Offline: changes will sync when connected",
              child: Icon(
                Icons.cloud_off_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}