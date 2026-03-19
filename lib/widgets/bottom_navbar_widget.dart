import 'package:flutter/material.dart';
import 'package:car_maintenance_tracker/screens/car/car_list_screen.dart';
import 'package:car_maintenance_tracker/screens/task/task_list_screen.dart';
import 'package:car_maintenance_tracker/screens/other/settings_screen.dart';

class BottomNavbarWidget extends StatelessWidget {
  const BottomNavbarWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        TextButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CarListScreen()),
            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_car),
              const Text("Cars"),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TaskListScreen()),
            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.task),
              const Text("Tasks"),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen()),
            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings),
              const Text("Settings"),
            ],
          ),
        ),
      ],
    );
  }
}