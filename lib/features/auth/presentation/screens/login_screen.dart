import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';

/// User authentication screen for Pukaar platform with mock OTP validation.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  // OTP Resend Timer
  Timer? _timer;
  int _timerSeconds = 30;
  bool _canResend = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _timerSeconds = 30;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 1) {
        setState(() {
          _timerSeconds--;
        });
      } else {
        setState(() {
          _canResend = true;
          _timer?.cancel();
        });
      }
    });
  }

  void _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ServiceLocator.instance.authService;
    final result = await authService.sendOtp(_mobileController.text.trim());

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      setState(() {
        _isOtpSent = true;
      });
      _startResendTimer();
    } else {
      setState(() {
        _errorMessage = result.errorMessage;
      });
    }
  }

  void _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'OTP must be 6 digits.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ServiceLocator.instance.authService;
    final result = await authService.verifyOtp(_mobileController.text.trim(), otp);

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      if (!mounted) return;
      final profile = result.data!;
      if (profile.name.trim().isEmpty) {
        // New user, redirect to Register with their phone number pre-filled
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.register,
          arguments: _mobileController.text.trim(),
        );
      } else {
        // Registered user, go home
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } else {
      setState(() {
        _errorMessage = result.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppDimensions.paddingLg,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimensions.spaceMd),
                Text(
                  _isOtpSent ? 'Verify OTP' : 'Emergency Login',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceXs),
                Text(
                  _isOtpSent
                      ? 'Enter the 6-digit mock code sent to ${_mobileController.text}.'
                      : 'Provide your mobile number to sign in or create a Pukaar profile.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppDimensions.spaceXl),
                if (_errorMessage != null) ...[
                  AppCard(
                    backgroundColor: theme.colorScheme.errorContainer,
                    borderColor: theme.colorScheme.error,
                    padding: AppDimensions.paddingSm,
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),
                ],
                AppCard(
                  child: Column(
                    children: [
                      if (!_isOtpSent) ...[
                        TextFormField(
                          controller: _mobileController,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            prefixIcon: Icon(Icons.phone_android_rounded),
                            hintText: 'e.g. 9876543210',
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().length < 10) {
                              return 'Please enter a valid 10-digit mobile number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.spaceLg),
                        PrimaryButton(
                          label: 'Get OTP',
                          isLoading: _isLoading,
                          onPressed: _handleSendOtp,
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _otpController,
                          decoration: const InputDecoration(
                            labelText: 'Verification OTP Code',
                            prefixIcon: Icon(Icons.lock_clock_rounded),
                            hintText: 'Enter 123456 for Mock demo',
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),
                        const SizedBox(height: AppDimensions.spaceMd),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _canResend ? 'Did not receive code?' : 'Resend in ${_timerSeconds}s',
                              style: theme.textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: _canResend ? _handleSendOtp : null,
                              child: Text(
                                'Resend OTP',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _canResend ? theme.colorScheme.primary : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spaceLg),
                        PrimaryButton(
                          label: 'Verify & Login',
                          isLoading: _isLoading,
                          onPressed: _handleVerifyOtp,
                        ),
                        const SizedBox(height: AppDimensions.spaceSm),
                        SecondaryButton(
                          label: 'Change Number',
                          onPressed: () {
                            setState(() {
                              _isOtpSent = false;
                              _otpController.clear();
                              _errorMessage = null;
                            });
                            _timer?.cancel();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceLg),
                if (!_isOtpSent)
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, AppRoutes.home);
                    },
                    child: const Text(AppStrings.quickAccess),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
