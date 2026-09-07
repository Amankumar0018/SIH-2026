import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/models/emergency_enums.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/section_header.dart';

/// Central Home Dashboard for Pukaar emergency platform.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // SOS State
  int _sosCountdown = 0;
  Timer? _sosTimer;
  bool _isSosActive = false;
  String? _activeSosIncidentId;

  // Location details
  String _locationStatus = 'Checking GPS...';
  String? _coordinates;
  bool _locationEnabled = false;

  // User profile & capabilities
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await ServiceLocator.instance.authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  void _fetchLocation() async {
    final locationService = ServiceLocator.instance.locationService;
    final enabled = await locationService.isLocationServiceEnabled();
    if (enabled) {
      final result = await locationService.getCurrentLocation();
      if (result.isSuccess) {
        final loc = result.data!;
        setState(() {
          _locationEnabled = true;
          _locationStatus = 'GPS Active • High Accuracy';
          _coordinates = '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}';
        });
      } else {
        setState(() {
          _locationStatus = 'Unable to fetch coordinates';
        });
      }
    } else {
      setState(() {
        _locationStatus = 'Location services disabled';
      });
    }
  }

  void _triggerSosCountdown() {
    setState(() {
      _sosCountdown = 3;
      _isSosActive = false;
    });

    _sosTimer?.cancel();
    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sosCountdown > 1) {
        setState(() {
          _sosCountdown--;
        });
      } else {
        setState(() {
          _sosCountdown = 0;
          _isSosActive = true;
        });
        _sosTimer?.cancel();

        // Dispatch immediate SOS alert via Emergency Engine Foundation
        ServiceLocator.instance.emergencyService
            .createIncident(
              category: EmergencyCategory.womenSafety,
              intent: 'Immediate SOS Panic Trigger',
              priority: EmergencyPriority.critical,
            )
            .then((result) {
              if (result.isSuccess && result.data != null) {
                _activeSosIncidentId = result.data!.id;
              }
            });
      }
    });
  }

  void _cancelSos() {
    _sosTimer?.cancel();

    if (_activeSosIncidentId != null) {
      ServiceLocator.instance.emergencyService.cancelIncident(
        _activeSosIncidentId!,
        reason: 'User cancelled SOS',
      );
      _activeSosIncidentId = null;
    }

    setState(() {
      _sosCountdown = 0;
      _isSosActive = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Alert Aborted Safely.'),
        backgroundColor: AppColors.secondaryLight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showResponderAccess = _currentUser == null || _currentUser!.isResponder;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_rounded, color: AppColors.primary),
            const SizedBox(width: AppDimensions.spaceSm),
            Text(
              AppStrings.appName,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          if (showResponderAccess)
            IconButton(
              icon: const Icon(Icons.badge_outlined),
              tooltip: 'Responder Dashboard',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final authService = ServiceLocator.instance.authService;
                final user = await authService.getCurrentUser();
                if (user != null && !user.isResponder) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Access Denied: Responder role required.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                  return;
                }
                navigator.pushNamed(AppRoutes.responderDashboard).then((_) {
                  _fetchLocation();
                  _loadCurrentUser();
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile).then((_) {
              _fetchLocation();
              _loadCurrentUser();
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppDimensions.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dual / Responder Banner
              if (_currentUser != null && _currentUser!.isResponder) ...[
                AppCard(
                  backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                  borderColor: theme.colorScheme.primary.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.responderDashboard).then((_) {
                      _fetchLocation();
                      _loadCurrentUser();
                    });
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUser!.isDual
                                  ? 'Dual Role Active (Citizen + Responder)'
                                  : 'Responder Account Active',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Text(
                              'Tap to open Responder Dashboard & view incident dispatches',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
              ],

              // Location status banner
              _buildLocationBanner(theme),
              const SizedBox(height: AppDimensions.spaceMd),

              // SOS Trigger Area
              _buildSosWidget(theme),
              const SizedBox(height: AppDimensions.spaceLg),

              // Emergency Pillars
              const SectionHeader(
                title: 'Select Emergency Category',
                subtitle: 'Directly open specific triage incident routing',
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              _buildCategoryGrid(context),
              const SizedBox(height: AppDimensions.spaceLg),

              // Quick Access Profile Utilities
              const SectionHeader(
                title: 'Preparedness & Health ID',
                subtitle: 'Information available for local medical responders',
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.emergencyContacts),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.contacts_rounded, color: AppColors.secondaryLight),
                          const SizedBox(height: AppDimensions.spaceSm),
                          Text(
                            AppStrings.emergencyContacts,
                            style: theme.textTheme.titleLarge?.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: AppDimensions.space2xs),
                          Text(
                            'Manage trusted contacts',
                            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                  Expanded(
                    child: AppCard(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.medicalId),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.favorite_rounded, color: AppColors.primary),
                          const SizedBox(height: AppDimensions.spaceSm),
                          Text(
                            AppStrings.medicalId,
                            style: theme.textTheme.titleLarge?.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: AppDimensions.space2xs),
                          Text(
                            'Blood group & allergies',
                            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBanner(ThemeData theme) {
    return AppCard(
      backgroundColor: _locationEnabled
          ? AppColors.success.withValues(alpha: 0.08)
          : AppColors.warning.withValues(alpha: 0.08),
      borderColor: _locationEnabled
          ? AppColors.success.withValues(alpha: 0.2)
          : AppColors.warning.withValues(alpha: 0.2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceMd,
        vertical: AppDimensions.spaceSm,
      ),
      child: Row(
        children: [
          Icon(
            _locationEnabled ? Icons.location_on : Icons.location_off,
            color: _locationEnabled ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _locationStatus,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (_coordinates != null)
                  Text(
                    'Coordinates: $_coordinates',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _fetchLocation,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildSosWidget(ThemeData theme) {
    if (_sosCountdown > 0) {
      return Container(
        padding: AppDimensions.paddingLg,
        decoration: BoxDecoration(
          color: AppColors.warning,
          borderRadius: AppDimensions.borderRadiusLg,
        ),
        child: Column(
          children: [
            const Text(
              'BROADCASTING IN...',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            Text(
              '$_sosCountdown',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 60,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.warning,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _cancelSos,
              child: const Text(
                'CANCEL DISPATCH',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }

    if (_isSosActive) {
      return Container(
        padding: AppDimensions.paddingLg,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppDimensions.borderRadiusLg,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                const Text(
                  'SOS BROADCAST ACTIVE',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            const Text(
              'Your location is being updated live.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _cancelSos,
              child: const Text(
                'DEACTIVATE SOS ALERT',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: AppDimensions.paddingLg,
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: AppDimensions.borderRadiusLg,
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'IMMEDIATE EMERGENCY BROADCAST',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          GestureDetector(
            onTap: _triggerSosCountdown,
            child: Container(
              width: AppDimensions.sosButtonSize,
              height: AppDimensions.sosButtonSize,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'SOS',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          const Text(
            'Tap and hold/press SOS to notify all local emergency rescue teams immediately.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildServiceCard(
                context,
                title: AppStrings.medicalEmergency,
                icon: Icons.medical_services_rounded,
                color: AppColors.medicalEmergency,
              ),
            ),
            const SizedBox(width: AppDimensions.spaceSm),
            Expanded(
              child: _buildServiceCard(
                context,
                title: AppStrings.womenSafety,
                icon: Icons.shield_rounded,
                color: AppColors.womenSafety,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        Row(
          children: [
            Expanded(
              child: _buildServiceCard(
                context,
                title: AppStrings.disasterManagement,
                icon: Icons.warning_rounded,
                color: AppColors.disasterManagement,
              ),
            ),
            const SizedBox(width: AppDimensions.spaceSm),
            Expanded(
              child: _buildServiceCard(
                context,
                title: AppStrings.campusEmergency,
                icon: Icons.school_rounded,
                color: AppColors.campusEmergency,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.emergencyIntent,
          arguments: title,
        );
      },
      padding: AppDimensions.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: AppDimensions.paddingSm,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppDimensions.borderRadiusSm,
            ),
            child: Icon(icon, color: color, size: AppDimensions.iconMd),
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Report Incident',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              Icon(Icons.chevron_right, size: 14, color: color),
            ],
          ),
        ],
      ),
    );
  }
}
