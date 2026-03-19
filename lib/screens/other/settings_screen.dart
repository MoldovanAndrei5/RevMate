import 'package:car_maintenance_tracker/providers/car_provider.dart';
import 'package:car_maintenance_tracker/providers/task_provider.dart';
import 'package:car_maintenance_tracker/providers/theme_provider.dart';
import 'package:car_maintenance_tracker/screens/other/auth_gate.dart';
import 'package:car_maintenance_tracker/screens/other/reset_password_screen.dart';
import 'package:car_maintenance_tracker/widgets/bottom_navbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {

  const SettingsScreen({
    super.key,
  });

  void _openColorPicker(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    Color pickerColor = themeProvider.accentColor;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Pick a color"),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsv,
              onColorChanged: (color) {
                pickerColor = color;
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Select"),
              onPressed: () {
                themeProvider.setAccentColor(pickerColor);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text("Settings"), centerTitle: true,),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: SwitchListTile(
                secondary: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: themeProvider.isDarkMode ? Colors.amber : Theme.of(context).colorScheme.primary,
                ),
                title: const Text("Dark mode"),
                subtitle: Text(themeProvider.isDarkMode ? "Enabled" : "Disabled"),
                value: themeProvider.isDarkMode,
                onChanged: (bool value) {
                  themeProvider.toggleTheme();
                },
              ),
            ),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Icon(
                  Icons.color_lens,
                  color: themeProvider.accentColor,
                ),
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

            const SizedBox(height: 24),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_reset),
                    title: const Text("Reset password"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ResetPasswordScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text("Logout"),
                    onTap: () async {
                      await context.read<AuthProvider>().logout();
                      context.read<CarProvider>().clearCache();
                      context.read<TaskProvider>().clearCache();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthGate()),
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
      bottomNavigationBar: SafeArea(
        child: const BottomNavbarWidget(),
      ),
    );
  }
}