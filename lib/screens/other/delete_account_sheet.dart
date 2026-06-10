import 'dart:async';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:car_maintenance_tracker/utils/snack_bar_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/car_provider.dart';
import '../../providers/task_provider.dart';
import '../auth/auth_gate.dart';
import '../../services/api_account_service.dart';

class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({super.key});

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final ApiAccountService _accountService = ApiAccountService();
  final _otpCtrl = TextEditingController();

  bool _isSendingOtp = false;
  bool _isDeleting = false;
  bool _otpSent = false;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCooldown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown == 0) {
        timer.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() => _isSendingOtp = true);
    try {
      await _accountService.sendDeleteOtp();
      if (mounted) {
        setState(() => _otpSent = true);
        _startResendTimer();
        showTopSnackBar(context, "Verification code sent to your email");
      }
    } on ApiException {
      if (mounted) {
        showTopSnackBar(context, "Failed to send verification code", type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _deleteAccount() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      showTopSnackBar(context, "Please enter the 6-digit code", type: SnackBarType.error);
      return;
    }
    setState(() => _isDeleting = true);
    try {
      await _accountService.deleteAccount(otp);
      if (mounted) {
        await context.read<AuthProvider>().logout();
        context.read<CarProvider>().clearCache();
        context.read<TaskProvider>().clearCache();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()), (route) => false,);
      }
    } on ApiException catch (e) {
      if (mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 32,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.delete_forever, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                "Delete Account",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This will permanently delete your account and all your data including cars, tasks and invoices. This action cannot be undone.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),

              if (!_otpSent) ...[
                // Send OTP button
                ElevatedButton(
                  onPressed: _isSendingOtp ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSendingOtp ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ) : const Text("Send Verification Code"),
                ),
              ] else ...[
                // OTP input
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                  ),
                  decoration: InputDecoration(
                    counterText: "",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.grey.shade50,
                    hintText: "••••••",
                    hintStyle: TextStyle(
                      letterSpacing: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Delete button
                ElevatedButton(
                  onPressed: _isDeleting ? null : _deleteAccount,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: _isDeleting ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ) : const Text("Delete My Account"),
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: _resendCooldown > 0 || _isSendingOtp ? null : _sendOtp,
                  child: _isSendingOtp ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ) : Text(_resendCooldown > 0 ? "Resend code in ${_resendCooldown}s" : "Resend code",),
                ),
              ],

              const SizedBox(height: 8),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}