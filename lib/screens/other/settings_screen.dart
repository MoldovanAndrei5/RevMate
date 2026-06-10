import 'package:car_maintenance_tracker/models/car_transfer.dart';
import 'package:car_maintenance_tracker/providers/car_provider.dart';
import 'package:car_maintenance_tracker/providers/task_provider.dart';
import 'package:car_maintenance_tracker/providers/theme_provider.dart';
import 'package:car_maintenance_tracker/screens/auth/auth_gate.dart';
import 'package:car_maintenance_tracker/screens/other/delete_account_sheet.dart';
import 'package:car_maintenance_tracker/screens/auth/reset_password_screen.dart';
import 'package:car_maintenance_tracker/screens/other/stats_screen.dart';
import 'package:car_maintenance_tracker/services/api_transfer_service.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:car_maintenance_tracker/utils/connectivity_state.dart';
import 'package:car_maintenance_tracker/utils/snack_bar_helper.dart';
import 'package:car_maintenance_tracker/widgets/bottom_navbar_widget.dart';
import 'package:car_maintenance_tracker/widgets/sync_indicator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiTransferService _transferService = ApiTransferService();

  List<CarTransferIncoming> _incoming = [];
  List<CarTransferOutgoing> _outgoing = [];
  bool _loadingTransfers = false;

  static const List<Color> _accentColors = [
    Colors.blue,
    Color(0xFF0D47A1),
    Colors.indigo,
    Colors.purple,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _loadTransfers();
  }

  Future<void> _loadTransfers() async {
    setState(() => _loadingTransfers = true);
    try {
      final incomingTransfers = await _transferService.getIncomingTransfers();
      final outgoingTransfers = await _transferService.getOutgoingTransfers();
      if (mounted) {
        setState(() {
          _incoming = incomingTransfers;
          _outgoing = outgoingTransfers;
        });
      }
      await context.read<CarProvider>().fetchCars();
    } on ApiException catch (_) {
      if (mounted) {
        showTopSnackBar(context, "No internet connection", type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _loadingTransfers = false);
    }
  }

  Future<void> _acceptTransfer(CarTransferIncoming transfer) async {
    try {
      await _transferService.acceptTransfer(transfer.transferUuid);
      setState(() => _incoming.removeWhere((t) => t.transferUuid == transfer.transferUuid));
      await context.read<CarProvider>().fetchCars();
      if (mounted) {
        showTopSnackBar(context, "${transfer.carName} was transferred to you!");
      }
    } on ApiException catch (e) {
      if (mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    }
  }

  Future<void> _rejectTransfer(CarTransferIncoming transfer) async {
    try {
      await _transferService.rejectTransfer(transfer.transferUuid);
      setState(() => _incoming.removeWhere((t) => t.transferUuid == transfer.transferUuid));
      await _loadTransfers();
    } on ApiException catch (e) {
      if (mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    }
  }

  Future<void> _cancelTransfer(CarTransferOutgoing transfer) async {
    try {
      await _transferService.cancelTransfer(transfer.transferUuid);
      setState(() => _outgoing.removeWhere((t) => t.transferUuid == transfer.transferUuid));
      await _loadTransfers();
    } on ApiException catch (e) {
      if (mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    }
  }

  void _showColorPicker(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose accent color"),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _accentColors.map((color) {
            final isSelected = themeProvider.accentColor == color;
            return GestureDetector(
              onTap: () {
                themeProvider.setAccentColor(color);
                Navigator.pop(context);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 3,
                  ) : null,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        actions: const [SyncIndicator()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance
            _sectionHeader(context, "Appearance"),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: themeProvider.isDarkMode ? Colors.amber : Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text("Dark mode"),
                    subtitle: Text(themeProvider.isDarkMode ? "Enabled" : "Disabled"),
                    value: themeProvider.isDarkMode,
                    onChanged: (_) => themeProvider.toggleTheme(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.palette_outlined,
                      color: themeProvider.accentColor,
                    ),
                    title: const Text("Accent color"),
                    subtitle: const Text("Choose app accent color"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: themeProvider.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _showColorPicker(context, themeProvider),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Transfers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionHeader(context, "Transfers"),
                if (_loadingTransfers)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _loadTransfers,
                    tooltip: "Refresh transfers",
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_incoming.isNotEmpty) ...[
              _subSectionHeader(context, "Incoming"),
              const SizedBox(height: 6),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _incoming.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final t = _incoming[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_downward_rounded, color: Colors.green, size: 18),
                      ),
                      title: Text(
                        "${t.carYear} ${t.carMake} ${t.carModel}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("From ${t.senderFirstName} ${t.senderLastName}\n${t.senderEmail}"),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                            tooltip: "Accept",
                            onPressed: () => _acceptTransfer(t),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                            tooltip: "Reject",
                            onPressed: () => _rejectTransfer(t),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (_outgoing.isNotEmpty) ...[
              _subSectionHeader(context, "Outgoing"),
              const SizedBox(height: 6),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _outgoing.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final t = _outgoing[index];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward_rounded, color: Colors.orange, size: 18),
                      ),
                      title: Text(
                        "${t.carYear} ${t.carMake} ${t.carModel}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("To ${t.receiverFirstName} ${t.receiverLastName}\n${t.receiverEmail}"),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.red),
                        tooltip: "Cancel transfer",
                        onPressed: () => _cancelTransfer(t),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (!_loadingTransfers && _incoming.isEmpty && _outgoing.isEmpty)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(Icons.swap_horiz_rounded, color: Colors.grey.shade400),
                  title: const Text("No pending transfers"),
                  subtitle: const Text("Transfer a car from its details screen"),
                ),
              ),

            const SizedBox(height: 24),

            // Account
            _sectionHeader(context, "Account"),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (!ConnectivityState().isServiceAvailable) {
                    showTopSnackBar(context, "Statistics require internet connection", type: SnackBarType.error);
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
                },
                icon: const Icon(Icons.bar_chart),
                label: const Text("Account Statistics"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.lock_reset_rounded, color: Theme.of(context).colorScheme.primary),
                    title: const Text("Reset password"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.orange),
                    title: const Text("Logout"),
                    onTap: () async {
                      await context.read<AuthProvider>().logout();
                      context.read<CarProvider>().clearCache();
                      context.read<TaskProvider>().clearCache();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AuthGate()), (route) => false,
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                    title: const Text(
                      "Delete account",
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      isDismissible: false,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) => const DeleteAccountSheet(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: BottomNavbarWidget(),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _subSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.grey,
        ),
      ),
    );
  }
}