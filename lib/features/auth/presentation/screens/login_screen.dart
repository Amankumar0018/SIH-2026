import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';

/// Comprehensive Authentication Screen for Pukaar supporting Sign In and Sign Up
/// across both Backend (Password / REST) and Mock (OTP) modes.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sign In Form Controllers
  final _signInFormKey = GlobalKey<FormState>();
  final _signInMobileController = TextEditingController();
  final _signInPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _obscureSignInPassword = true;

  // OTP Resend Timer
  Timer? _timer;
  int _timerSeconds = 30;
  bool _canResend = false;

  // Sign Up Form Controllers
  final _signUpFormKey = GlobalKey<FormState>();
  final _signUpNameController = TextEditingController();
  final _signUpMobileController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpContactNameController = TextEditingController();
  final _signUpContactPhoneController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpAgeController = TextEditingController();
  final _signUpBloodGroupController = TextEditingController();
  bool _obscureSignUpPassword = true;
  String _selectedRole = 'citizen'; // 'citizen', 'responder', 'dual'

  // Shared state
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isBackendMode => ServiceLocator.instance.useBackendApi;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInMobileController.dispose();
    _signInPasswordController.dispose();
    _otpController.dispose();
    _signUpNameController.dispose();
    _signUpMobileController.dispose();
    _signUpPasswordController.dispose();
    _signUpContactNameController.dispose();
    _signUpContactPhoneController.dispose();
    _signUpEmailController.dispose();
    _signUpAgeController.dispose();
    _signUpBloodGroupController.dispose();
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
        });
        timer.cancel();
      }
    });
  }

  void _handlePasswordLogin() async {
    if (!_signInFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _signInMobileController.text.trim();
    final password = _signInPasswordController.text.trim();

    final result = await ServiceLocator.instance.authService.loginWithPassword(
      phone,
      password,
    );

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      if (!mounted) return;
      _navigateHome();
    } else {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Sign in failed. Please verify credentials.';
      });
    }
  }

  void _handleSendOtp() async {
    if (!_signInFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _signInMobileController.text.trim();
    final result = await ServiceLocator.instance.authService.sendOtp(phone);

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
        _errorMessage = result.errorMessage ?? 'Failed to send OTP.';
      });
    }
  }

  void _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit OTP code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _signInMobileController.text.trim();
    final result = await ServiceLocator.instance.authService.verifyOtp(phone, otp);

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      if (!mounted) return;
      _navigateHome();
    } else {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Invalid OTP code.';
      });
    }
  }

  void _quickFill(String phone, String password) {
    _signInMobileController.text = phone;
    _signInPasswordController.text = password;
  }

  void _navigateHome() {
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  void _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = UserProfile(
      name: _signUpNameController.text.trim(),
      mobileNumber: _signUpMobileController.text.trim(),
      emergencyContactName: _signUpContactNameController.text.trim(),
      emergencyContactPhone: _signUpContactPhoneController.text.trim(),
      email: _signUpEmailController.text.trim().isNotEmpty
          ? _signUpEmailController.text.trim()
          : null,
      age: int.tryParse(_signUpAgeController.text.trim()),
      bloodGroup: _signUpBloodGroupController.text.trim().isNotEmpty
          ? _signUpBloodGroupController.text.trim()
          : null,
      role: _selectedRole,
    );

    final result = await ServiceLocator.instance.authService.registerUser(
      user,
      password: _isBackendMode ? _signUpPasswordController.text.trim() : null,
    );

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created & signed in successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Registration failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ServiceLocator.instance.localizationService.localizations;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.language_rounded),
            tooltip: 'Change Language / भाषा बदलें / भाषा बदला',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.languageSelection);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          tabs: [
            Tab(text: l10n.signIn, icon: const Icon(Icons.login_rounded)),
            Tab(text: l10n.signUp, icon: const Icon(Icons.person_add_outlined)),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppDimensions.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              SizedBox(
                height: 520,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSignInTab(theme),
                    _buildSignUpTab(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInTab(ThemeData theme) {
    final l10n = ServiceLocator.instance.localizationService.localizations;

    return SingleChildScrollView(
      child: Form(
        key: _signInFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isOtpSent ? 'Verify OTP Code' : 'Welcome Back',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceXs),
            Text(
              _isOtpSent
                  ? 'Enter the 6-digit mock code sent to ${_signInMobileController.text}.'
                  : _isBackendMode
                      ? 'Sign in with your registered mobile number and password.'
                      : 'Provide your mobile number to sign in.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            if (_isBackendMode) ...[
              AppCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _signInMobileController,
                      decoration: InputDecoration(
                        labelText: l10n.mobileNumber,
                        prefixIcon: const Icon(Icons.phone_android_rounded),
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
                    const SizedBox(height: AppDimensions.spaceMd),
                    TextFormField(
                      controller: _signInPasswordController,
                      obscureText: _obscureSignInPassword,
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureSignInPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() {
                            _obscureSignInPassword = !_obscureSignInPassword;
                          }),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.spaceLg),
                    PrimaryButton(
                      label: l10n.signIn,
                      isLoading: _isLoading,
                      onPressed: _handlePasswordLogin,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              // Dev Quick Fill
              AppCard(
                backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUICK DEV LOGIN',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _quickFill('9876543210', 'password123'),
                            child: const Text('Citizen', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _quickFill('9000000000', 'responder123'),
                            child: const Text('Responder', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _quickFill('9999999999', 'dual123'),
                            child: const Text('Dual', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            if (!_isBackendMode) ...[
              AppCard(
                child: Column(
                  children: [
                    if (!_isOtpSent) ...[
                      TextFormField(
                        controller: _signInMobileController,
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
            ],

            const SizedBox(height: AppDimensions.spaceSm),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, AppRoutes.home);
              },
              child: const Text(AppStrings.quickAccess),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpTab(ThemeData theme) {
    final l10n = ServiceLocator.instance.localizationService.localizations;

    return SingleChildScrollView(
      child: Form(
        key: _signUpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create Pukaar Profile',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceXs),
            Text(
              'Register your details for local emergency safety dispatches.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _signUpNameController,
                    decoration: InputDecoration(
                      labelText: '${l10n.fullName} *',
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Full name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),
                  TextFormField(
                    controller: _signUpMobileController,
                    decoration: InputDecoration(
                      labelText: '${l10n.mobileNumber} *',
                      prefixIcon: const Icon(Icons.phone_android_rounded),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().length < 10) {
                        return 'Valid 10-digit mobile number required';
                      }
                      return null;
                    },
                  ),
                  if (_isBackendMode) ...[
                    const SizedBox(height: AppDimensions.spaceMd),
                    TextFormField(
                      controller: _signUpPasswordController,
                      obscureText: _obscureSignUpPassword,
                      decoration: InputDecoration(
                        labelText: '${l10n.password} *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureSignUpPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() {
                            _obscureSignUpPassword = !_obscureSignUpPassword;
                          }),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spaceLg),
                  Text(
                    'Select Profile Capability / Role *',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppDimensions.spaceXs),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.person, size: 16),
                        label: const Text('Citizen'),
                        selected: _selectedRole == 'citizen',
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedRole = 'citizen');
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.badge, size: 16),
                        label: const Text('Responder'),
                        selected: _selectedRole == 'responder',
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedRole = 'responder');
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.star_rounded, size: 16),
                        label: const Text('Dual (Both)'),
                        selected: _selectedRole == 'dual',
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedRole = 'dual');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spaceLg),
                  Text(
                    '${l10n.emergencyContactName} *',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  TextFormField(
                    controller: _signUpContactNameController,
                    decoration: InputDecoration(
                      labelText: '${l10n.emergencyContactName} *',
                      prefixIcon: const Icon(Icons.contacts_outlined),
                      hintText: 'e.g. Spouse / Parent',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Emergency contact name required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),
                  TextFormField(
                    controller: _signUpContactPhoneController,
                    decoration: InputDecoration(
                      labelText: '${l10n.emergencyContactPhone} *',
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().length < 10) {
                        return 'Valid contact mobile number required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.spaceLg),
                  PrimaryButton(
                    label: l10n.language.name == 'hindi'
                        ? 'खाता बनाएं (रजिस्टर)'
                        : (l10n.language.name == 'marathi'
                            ? 'खाते तयार करा (नोंदणी)'
                            : 'Create Account & Sign In'),
                    isLoading: _isLoading,
                    onPressed: _handleSignUp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
