import 'dart:async';
import 'package:car_maintenance_tracker/services/api_auth_service.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:car_maintenance_tracker/widgets/top_snack_bar.dart';
import 'package:flutter/material.dart';

class OtpVerificationSheet extends StatefulWidget {
  final String email;
  final String firstName;
  final String lastName;
  final String password;

  const OtpVerificationSheet({
    super.key,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.password,
  });

  @override
  State<OtpVerificationSheet> createState() => _OtpVerificationSheetState();
}

class _OtpVerificationSheetState extends State<OtpVerificationSheet> {
  final ApiAuthService _authService = ApiAuthService();
  final _otpCtrl = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendCooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

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

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      showTopSnackBar(context, "Please enter the 6-digit code", type: SnackBarType.error);
      return;
    }
    setState(() => _isVerifying = true);
    try {
      await _authService.register(
        widget.firstName,
        widget.lastName,
        widget.email,
        widget.password,
        otp,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await _authService.sendRegisterOtp(widget.email);
      if (mounted) {
        _otpCtrl.clear();
        _startResendTimer();
        showTopSnackBar(context, "New code sent to your email");
      }
    } on ApiException catch (e) {
      if (mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
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
              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 40,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Verify your email",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We sent a 6-digit verification code to",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),

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
                    fontSize: 28,
                  ),
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 24),

              // Verify button
              ElevatedButton(
                onPressed: _isVerifying ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isVerifying ? SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                ) : const Text("Verify", style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                ),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: _resendCooldown > 0 || _isResending ? null : _resend,
                child: _isResending ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary,
                  ),
                ) : Text(_resendCooldown > 0 ? "Resend code in ${_resendCooldown}s" : "Resend code",),
              ),
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