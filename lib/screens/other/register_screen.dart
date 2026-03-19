import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _firstCtrl, decoration: const InputDecoration(labelText: "First Name")),
            TextField(controller: _lastCtrl, decoration: const InputDecoration(labelText: "Last Name")),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: "Password"), obscureText: true),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () async {
                final success = await auth.register(
                  _firstCtrl.text,
                  _lastCtrl.text,
                  _emailCtrl.text,
                  _passCtrl.text,
                );

                if (success) {
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Registration failed")),
                  );
                }
              },
              child: const Text("Register"),
            )
          ],
        ),
      ),
    );
  }
}