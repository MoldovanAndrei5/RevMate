import 'package:car_maintenance_tracker/models/car_transfer.dart';
import 'package:car_maintenance_tracker/providers/car_provider.dart';
import 'package:car_maintenance_tracker/providers/task_provider.dart';
import 'package:car_maintenance_tracker/providers/theme_provider.dart';
import 'package:car_maintenance_tracker/screens/other/auth_gate.dart';
import 'package:car_maintenance_tracker/screens/other/reset_password_screen.dart';
import 'package:car_maintenance_tracker/services/api_transfer_service.dart';
import 'package:car_maintenance_tracker/widgets/bottom_navbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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

  @override
  void initState() {
    super.initState();
    _loadTransfers();
  }

  Future<void> _loadTransfers() async {
    setState(() => _loadingTransfers = true);
    try {
      final incomingRes = await _transferService.getIncomingTransfers();
      final outgoingRes = await _transferService.getOutgoingTransfers();
      if (mounted) {
        setState(() {
          _incoming = incomingRes.data ?? [];
          _outgoing = outgoingRes.data ?? [];
        });
      }
      await context.read<CarProvider>().fetchCars();
    } catch (e) {
      // offline — show empty
    } finally {
      if (mounted) setState(() => _loadingTransfers = false);
    }
  }

  Future<void> _acceptTransfer(CarTransferIncoming transfer) async {
    final success = await _transferService.acceptTransfer(transfer.transferUuid);
    if (success) {
      setState(() => _incoming.removeWhere(
              (t) => t.transferUuid == transfer.transferUuid));
      await context.read<CarProvider>().fetchCars();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${transfer.carName} has been transferred to you!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to accept transfer')),
        );
      }
    }
  }

  Future<void> _rejectTransfer(CarTransferIncoming transfer) async {
    final success = await _transferService.rejectTransfer(transfer.transferUuid);
    if (success) {
      setState(() => _incoming.removeWhere(
              (t) => t.transferUuid == transfer.transferUuid));
      await _loadTransfers();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reject transfer')),
        );
      }
    }
  }

  Future<void> _cancelTransfer(CarTransferOutgoing transfer) async {
    final success = await _transferService.cancelTransfer(transfer.transferUuid);
    if (success) {
      setState(() => _outgoing.removeWhere(
              (t) => t.transferUuid == transfer.transferUuid));
      await _loadTransfers();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel transfer')),
        );
      }
    }
  }

  void _openColorPicker(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    Color pickerColor = themeProvider.accentColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pick a color"),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hsv,
            onColorChanged: (color) => pickerColor = color,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              themeProvider.setAccentColor(pickerColor);
              Navigator.pop(context);
            },
            child: const Text("Select"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: SwitchListTile(
                secondary: Icon(
                  themeProvider.isDarkMode
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  color: themeProvider.isDarkMode
                      ? Colors.amber
                      : Theme.of(context).colorScheme.primary,
                ),
                title: const Text("Dark mode"),
                subtitle:
                Text(themeProvider.isDarkMode ? "Enabled" : "Disabled"),
                value: themeProvider.isDarkMode,
                onChanged: (_) => themeProvider.toggleTheme(),
              ),
            ),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Icon(Icons.color_lens,
                    color: themeProvider.accentColor),
                title: const Text("Pick accent color"),
                trailing: GestureDetector(
                  onTap: () => _openColorPicker(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: themeProvider.accentColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                onTap: () => _openColorPicker(context),
              ),
            ),

            const SizedBox(height: 24),

            // Transfers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    "Transfers",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                if (_loadingTransfers)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadTransfers,
                    tooltip: 'Refresh transfers',
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Incoming transfers
            if (_incoming.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  "Incoming",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: _incoming.asMap().entries.map((entry) {
                    final i = entry.key;
                    final t = entry.value;
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.swap_horiz,
                              color: Colors.green),
                          title: Text(
                            '${t.carYear} ${t.carMake} ${t.carModel}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                              'From ${t.senderFirstName} ${t.senderLastName}\n${t.senderEmail}'),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle,
                                    color: Colors.green),
                                tooltip: 'Accept',
                                onPressed: () => _acceptTransfer(t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel,
                                    color: Colors.red),
                                tooltip: 'Reject',
                                onPressed: () => _rejectTransfer(t),
                              ),
                            ],
                          ),
                        ),
                        if (i < _incoming.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Outgoing transfers
            if (_outgoing.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  "Outgoing",
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: _outgoing.asMap().entries.map((entry) {
                    final i = entry.key;
                    final t = entry.value;
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.swap_horiz,
                              color: Colors.orange),
                          title: Text(
                            '${t.carYear} ${t.carMake} ${t.carModel}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                              'To ${t.receiverFirstName} ${t.receiverLastName}\n${t.receiverEmail}'),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Cancel transfer',
                            onPressed: () => _cancelTransfer(t),
                          ),
                        ),
                        if (i < _outgoing.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (!_loadingTransfers &&
                _incoming.isEmpty &&
                _outgoing.isEmpty)
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: const ListTile(
                  leading: Icon(Icons.swap_horiz, color: Colors.grey),
                  title: Text("No pending transfers"),
                  subtitle: Text(
                      "Transfer a car from its details screen"),
                ),
              ),

            const SizedBox(height: 24),

            // Account
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                "Account",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_reset),
                    title: const Text("Reset password"),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ResetPasswordScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading:
                    const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text("Logout"),
                    onTap: () async {
                      await context.read<AuthProvider>().logout();
                      context.read<CarProvider>().clearCache();
                      context.read<TaskProvider>().clearCache();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const AuthGate()),
                            (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: BottomNavbarWidget(),
      ),
    );
  }
}