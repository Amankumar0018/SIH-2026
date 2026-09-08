import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/models/emergency_enums.dart';
import '../../../../core/models/emergency_incident.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/widgets/emergency_map.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../widgets/ai_incident_card.dart';

/// Central Dashboard Screen for Emergency Responders to view active incidents,
/// accept dispatches, and update response progress.
class ResponderDashboardScreen extends StatefulWidget {
  const ResponderDashboardScreen({super.key});

  @override
  State<ResponderDashboardScreen> createState() => _ResponderDashboardScreenState();
}

class _ResponderDashboardScreenState extends State<ResponderDashboardScreen> {
  List<EmergencyIncident> _activeIncidents = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<EmergencyIncident>? _streamSubscription;
  EmergencyLocation? _responderDeviceLocation;

  @override
  void initState() {
    super.initState();
    _fetchActiveIncidents();
    _fetchResponderDeviceLocation();

    // Listen to real-time incident stream updates
    _streamSubscription = ServiceLocator.instance.emergencyService.incidentStream.listen((_) {
      if (mounted) {
        _fetchActiveIncidents();
      }
    });
  }

  Future<void> _fetchResponderDeviceLocation() async {
    try {
      final locResult = await ServiceLocator.instance.locationService.getCurrentLocation();
      if (locResult.isSuccess && locResult.data != null && mounted) {
        setState(() {
          _responderDeviceLocation = locResult.data;
        });
      }
    } catch (_) {
      // Graceful fallback if location is unavailable or denied
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchActiveIncidents() async {
    final result = await ServiceLocator.instance.emergencyService.getActiveIncidents();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess && result.data != null) {
        _activeIncidents = result.data!;
        _errorMessage = null;
      } else {
        _errorMessage = result.errorMessage ?? 'Failed to load active incidents.';
      }
    });
  }

  void _navigateToHome() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  Color _getCategoryColor(EmergencyCategory category) {
    switch (category) {
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

  Future<void> _handleAcceptIncident(EmergencyIncident incident) async {
    String defaultResponderName;
    String defaultResponderType;
    String defaultPhone;

    switch (incident.category) {
      case EmergencyCategory.medical:
        defaultResponderName = 'Trauma Rescue Team #1';
        defaultResponderType = 'ALS Ambulance Patrol';
        defaultPhone = '102';
        break;
      case EmergencyCategory.womenSafety:
        defaultResponderName = 'Safety Patrol Unit Alpha';
        defaultResponderType = 'Rapid Safety Escort';
        defaultPhone = '1091';
        break;
      case EmergencyCategory.disaster:
        defaultResponderName = 'Rescue Team 07';
        defaultResponderType = 'Disaster Management Unit';
        defaultPhone = '1070';
        break;
      case EmergencyCategory.campus:
        defaultResponderName = 'Campus Security Patrol #1';
        defaultResponderType = 'University Safety Officer';
        defaultPhone = '112';
        break;
    }

    final result = await ServiceLocator.instance.emergencyService.updateIncidentStatus(
      incident.id,
      EmergencyStatus.accepted,
      responderId: 'RESP_${incident.category.name.toUpperCase()}_01',
      responderName: defaultResponderName,
      responderType: defaultResponderType,
      responderPhone: defaultPhone,
      etaMinutes: 5,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Incident #${incident.id.split('_').last} Accepted.'),
          backgroundColor: AppColors.success,
        ),
      );
      _fetchActiveIncidents();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to accept incident.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleStartResponse(EmergencyIncident incident) async {
    final result = await ServiceLocator.instance.emergencyService.updateIncidentStatus(
      incident.id,
      EmergencyStatus.inProgress,
      etaMinutes: 0,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Response started. Incident status set to In Progress.'),
          backgroundColor: AppColors.success,
        ),
      );
      _fetchActiveIncidents();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to start response.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleResolveIncident(EmergencyIncident incident) async {
    final result = await ServiceLocator.instance.emergencyService.updateIncidentStatus(
      incident.id,
      EmergencyStatus.resolved,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incident marked as Resolved.'),
          backgroundColor: AppColors.success,
        ),
      );
      _fetchActiveIncidents();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to resolve incident.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildStatusChip(EmergencyStatus status, Color categoryColor) {
    Color chipBg;
    Color chipText;

    switch (status) {
      case EmergencyStatus.created:
      case EmergencyStatus.searching:
        chipBg = AppColors.warning.withValues(alpha: 0.15);
        chipText = AppColors.warning;
        break;
      case EmergencyStatus.dispatched:
        chipBg = AppColors.info.withValues(alpha: 0.15);
        chipText = AppColors.info;
        break;
      case EmergencyStatus.accepted:
        chipBg = categoryColor.withValues(alpha: 0.15);
        chipText = categoryColor;
        break;
      case EmergencyStatus.inProgress:
        chipBg = AppColors.primary.withValues(alpha: 0.15);
        chipText = AppColors.primary;
        break;
      case EmergencyStatus.resolved:
        chipBg = AppColors.success.withValues(alpha: 0.15);
        chipText = AppColors.success;
        break;
      case EmergencyStatus.cancelled:
        chipBg = AppColors.error.withValues(alpha: 0.15);
        chipText = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: TextStyle(
          color: chipText,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildIncidentCard(EmergencyIncident incident) {
    final theme = Theme.of(context);
    final categoryColor = _getCategoryColor(incident.category);

    return AppCard(
      borderColor: categoryColor.withValues(alpha: 0.3),
      padding: AppDimensions.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Category Badge & Status Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.shield, color: categoryColor, size: 20),
                  const SizedBox(width: AppDimensions.spaceXs),
                  Text(
                    incident.category.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: categoryColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              _buildStatusChip(incident.status, categoryColor),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),

          // Intent Title
          Text(
            incident.intent,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXs),

          // Location details
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  incident.latitude != null && incident.longitude != null
                      ? 'Lat: ${incident.latitude!.toStringAsFixed(4)}, Lng: ${incident.longitude!.toStringAsFixed(4)}'
                      : 'Location Pending / GPS Unavailable',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),

          // Map visualization
          EmergencyMap(
            latitude: incident.latitude,
            longitude: incident.longitude,
            responderLatitude: _responderDeviceLocation?.latitude ?? incident.responderLatitude,
            responderLongitude: _responderDeviceLocation?.longitude ?? incident.responderLongitude,
            title: '${incident.category.displayName} Alert Map',
            markerColor: categoryColor,
            height: 160,
          ),
          const SizedBox(height: AppDimensions.spaceSm),

          // ID and Timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID: ${incident.id}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                'Priority: ${incident.priority.displayName}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
              ),
            ],
          ),

          // AI Incident Intelligence (if available)
          if (incident.aiIntelligence != null) ...[
            const SizedBox(height: AppDimensions.spaceSm),
            AIIncidentCard(intelligence: incident.aiIntelligence!),
          ],

          // Assigned Responder Info if present
          if (incident.assignedResponderName != null) ...[
            const SizedBox(height: AppDimensions.spaceSm),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppColors.secondary),
                const SizedBox(width: 4),
                Text(
                  'Assigned: ${incident.assignedResponderName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                if (incident.estimatedArrivalMinutes != null) ...[
                  const Spacer(),
                  Text(
                    'ETA: ${incident.estimatedArrivalMinutes} min',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.warning),
                  ),
                ],
              ],
            ),
          ],

          const SizedBox(height: AppDimensions.spaceMd),

          // Contextual Action Buttons
          if (incident.status == EmergencyStatus.created ||
              incident.status == EmergencyStatus.searching ||
              incident.status == EmergencyStatus.dispatched)
            PrimaryButton(
              backgroundColor: categoryColor,
              label: 'Accept Incident Response',
              onPressed: () => _handleAcceptIncident(incident),
            )
          else if (incident.status == EmergencyStatus.accepted)
            PrimaryButton(
              backgroundColor: AppColors.primary,
              label: 'Start Response (In Progress)',
              onPressed: () => _handleStartResponse(incident),
            )
          else if (incident.status == EmergencyStatus.inProgress)
            PrimaryButton(
              backgroundColor: AppColors.success,
              label: 'Mark Incident Resolved',
              onPressed: () => _handleResolveIncident(incident),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Return to Citizen Home',
          onPressed: _navigateToHome,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.badge, color: AppColors.primary),
            const SizedBox(width: AppDimensions.spaceSm),
            Text(
              'Responder Dashboard',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Switch to Citizen View',
            onPressed: _navigateToHome,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Incidents',
            onPressed: _fetchActiveIncidents,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchActiveIncidents,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: AppDimensions.paddingLg,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            const SizedBox(height: AppDimensions.spaceSm),
                            Text(_errorMessage!, textAlign: TextAlign.center),
                            const SizedBox(height: AppDimensions.spaceMd),
                            ElevatedButton(
                              onPressed: _fetchActiveIncidents,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _activeIncidents.isEmpty
                      ? ListView(
                          padding: AppDimensions.paddingLg,
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
                                  const SizedBox(height: AppDimensions.spaceMd),
                                  const Text(
                                    'No Active Emergencies',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: AppDimensions.spaceXs),
                                  const Text(
                                    'All emergency requests are currently clear or resolved.',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppDimensions.spaceLg),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.home),
                                    label: const Text('Return to Citizen Home'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.secondary,
                                      foregroundColor: AppColors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                    onPressed: _navigateToHome,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: AppDimensions.paddingMd,
                          itemCount: _activeIncidents.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppDimensions.spaceMd),
                          itemBuilder: (context, index) {
                            return _buildIncidentCard(_activeIncidents[index]);
                          },
                        ),
        ),
      ),
    );
  }
}
