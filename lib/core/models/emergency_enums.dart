/// Core emergency categorization pillars supported by Pukaar.
enum EmergencyCategory {
  medical,
  womenSafety,
  disaster,
  campus;

  /// User-friendly label for presentation.
  String get displayName {
    switch (this) {
      case EmergencyCategory.medical:
        return 'Medical Emergency';
      case EmergencyCategory.womenSafety:
        return "Women's Safety";
      case EmergencyCategory.disaster:
        return 'Disaster Management';
      case EmergencyCategory.campus:
        return 'Campus Emergency';
    }
  }

  /// Parses category from UI text or backend string keys.
  static EmergencyCategory fromString(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized.contains('medic')) {
      return EmergencyCategory.medical;
    } else if (normalized.contains('women') || normalized.contains('safety')) {
      return EmergencyCategory.womenSafety;
    } else if (normalized.contains('disaster')) {
      return EmergencyCategory.disaster;
    } else if (normalized.contains('campus')) {
      return EmergencyCategory.campus;
    }
    return EmergencyCategory.medical;
  }
}

/// Lifecycle status for an active or resolved emergency incident.
enum EmergencyStatus {
  created,
  searching,
  dispatched,
  accepted,
  inProgress,
  resolved,
  cancelled;

  /// User-friendly status label.
  String get displayName {
    switch (this) {
      case EmergencyStatus.created:
        return 'Incident Created';
      case EmergencyStatus.searching:
        return 'Searching Nearest Responders';
      case EmergencyStatus.dispatched:
        return 'Responder Dispatched';
      case EmergencyStatus.accepted:
        return 'Responder Accepted';
      case EmergencyStatus.inProgress:
        return 'Rescue In Progress';
      case EmergencyStatus.resolved:
        return 'Resolved';
      case EmergencyStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Helper to check if an incident is currently active.
  bool get isActive => this != EmergencyStatus.resolved && this != EmergencyStatus.cancelled;

  static EmergencyStatus fromString(String value) {
    return EmergencyStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().trim(),
      orElse: () => EmergencyStatus.created,
    );
  }
}

/// Triage severity level for emergency incident prioritization.
enum EmergencyPriority {
  low,
  medium,
  high,
  critical;

  String get displayName {
    switch (this) {
      case EmergencyPriority.low:
        return 'Low';
      case EmergencyPriority.medium:
        return 'Medium';
      case EmergencyPriority.high:
        return 'High';
      case EmergencyPriority.critical:
        return 'Critical';
    }
  }

  static EmergencyPriority fromString(String value) {
    return EmergencyPriority.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().trim(),
      orElse: () => EmergencyPriority.high,
    );
  }
}
