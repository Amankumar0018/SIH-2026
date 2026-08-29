import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/models/emergency_enums.dart';
import '../../../../core/models/emergency_incident.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/widgets/emergency_map.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/secondary_button.dart';

class EmergencyTrackingScreen extends StatefulWidget {
  final EmergencyIncident incident;

  const EmergencyTrackingScreen({
    super.key,
    required this.incident,
  });

  @override
  State<EmergencyTrackingScreen> createState() => _EmergencyTrackingScreenState();
}

class _EmergencyTrackingScreenState extends State<EmergencyTrackingScreen> {
  late EmergencyIncident _currentIncident;
  StreamSubscription<EmergencyIncident>? _incidentSubscription;

  @override
  void initState() {
    super.initState();
    _currentIncident = widget.incident;
    
    // Check if the service already has an updated version in activeIncident
    final active = ServiceLocator.instance.emergencyService.activeIncident;
    if (active != null && active.id == _currentIncident.id) {
      _currentIncident = active;
    }

    _incidentSubscription = ServiceLocator.instance.emergencyService.incidentStream.listen((incidentUpdate) {
      if (incidentUpdate.id == _currentIncident.id && mounted) {
        setState(() {
          _currentIncident = incidentUpdate;
        });
      }
    });
  }

  @override
  void dispose() {
    _incidentSubscription?.cancel();
    super.dispose();
  }

  Color _getCategoryColor() {
    switch (_currentIncident.category) {
      case EmergencyCategory.medical:
        return AppColors.medicalEmergency;
      case EmergencyCategory.womenSafety:
        return AppColors.womenSafety;
      case EmergencyCategory.disaster:
        return AppColors.disasterManagement;
      case EmergencyCategory.campus:
        return AppColors.campusEmergency;
    }
  }

  void _confirmCancel() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Emergency?'),
        content: const Text(
          'Are you sure you want to cancel this emergency request? Responders will be notified to stand down.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep Active'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelEmergency();
            },
            child: const Text('Yes, Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _cancelEmergency() async {
    final result = await ServiceLocator.instance.emergencyService.cancelIncident(
      _currentIncident.id,
      reason: 'User cancelled from tracking screen',
    );
    if (result.isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency Alert Cancelled.'),
          backgroundColor: AppColors.secondaryLight,
        ),
      );
    }
  }

  Widget _buildStatusTimeline() {
    final statuses = [
      EmergencyStatus.created,
      EmergencyStatus.searching,
      EmergencyStatus.dispatched,
      EmergencyStatus.accepted,
      EmergencyStatus.inProgress,
      EmergencyStatus.resolved,
    ];

    if (_currentIncident.status == EmergencyStatus.cancelled) {
      return Container(
        padding: AppDimensions.paddingMd,
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: AppDimensions.borderRadiusMd,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel, color: AppColors.error),
            SizedBox(width: AppDimensions.spaceSm),
            Expanded(
              child: Text(
                'This emergency incident has been cancelled.',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final currentIndex = statuses.indexOf(_currentIncident.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: statuses.map((status) {
        final index = statuses.indexOf(status);
        final isCompleted = index < currentIndex;
        final isCurrent = index == currentIndex;
        final isPending = index > currentIndex;
        
        Color itemColor;
        if (isCompleted) {
          itemColor = AppColors.success;
        } else if (isCurrent) {
          itemColor = _getCategoryColor();
        } else {
          itemColor = Colors.grey;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPending ? Colors.transparent : itemColor,
                  border: isPending ? Border.all(color: Colors.grey) : null,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 16, color: AppColors.white)
                    : (isCurrent
                        ? const Icon(Icons.sync, size: 16, color: AppColors.white)
                        : null),
              ),
              const SizedBox(width: AppDimensions.spaceMd),
              Text(
                status.displayName,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : (isCompleted ? FontWeight.w500 : FontWeight.normal),
                  color: isPending ? Colors.grey : AppColors.textPrimaryLight,
                  fontSize: isCurrent ? 16 : 14,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResponderInfo() {
    if (_currentIncident.assignedResponderId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppDimensions.spaceLg),
        const Text(
          'Assigned Responder',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        AppCard(
          padding: AppDimensions.paddingLg,
          borderColor: _getCategoryColor().withValues(alpha: 0.3),
          backgroundColor: _getCategoryColor().withValues(alpha: 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping_rounded, color: _getCategoryColor(), size: 28),
                  const SizedBox(width: AppDimensions.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentIncident.assignedResponderName ?? 'Unknown Responder',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (_currentIncident.assignedResponderType != null)
                          Text(
                            _currentIncident.assignedResponderType!,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              const Divider(),
              const SizedBox(height: AppDimensions.spaceSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _currentIncident.assignedResponderPhone ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (_currentIncident.estimatedArrivalMinutes != null)
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 16, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          'ETA: ${_currentIncident.estimatedArrivalMinutes} min',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getCategoryColor();
    final isActive = _currentIncident.status.isActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Status'),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppDimensions.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: AppDimensions.paddingMd,
                decoration: BoxDecoration(
                  color: isActive ? color : Colors.grey,
                  borderRadius: AppDimensions.borderRadiusMd,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield, color: AppColors.white, size: 32),
                    const SizedBox(width: AppDimensions.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentIncident.category.displayName.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _currentIncident.intent,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLg),
              
              if (_currentIncident.latitude != null && _currentIncident.longitude != null) ...[
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Location Captured',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              'Lat: ${_currentIncident.latitude!.toStringAsFixed(4)}, Lng: ${_currentIncident.longitude!.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            if (_currentIncident.accuracy != null)
                              Text(
                                'Accuracy: ~${_currentIncident.accuracy!.toStringAsFixed(0)}m',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                EmergencyMap(
                  latitude: _currentIncident.latitude,
                  longitude: _currentIncident.longitude,
                  responderLatitude: _currentIncident.responderLatitude,
                  responderLongitude: _currentIncident.responderLongitude,
                  title: '${_currentIncident.category.displayName} Emergency Location',
                  markerColor: color,
                  height: 200,
                ),
              ],
              
              const SizedBox(height: AppDimensions.spaceLg),
              const Text(
                'Incident Timeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              _buildStatusTimeline(),

              _buildResponderInfo(),
              
              const SizedBox(height: AppDimensions.spaceXl),
              
              if (isActive)
                SecondaryButton(
                  label: 'Cancel Emergency',
                  onPressed: _confirmCancel,
                ),
                
              const SizedBox(height: AppDimensions.spaceLg),
              Center(
                child: Text(
                  'Incident ID: ${_currentIncident.id}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
