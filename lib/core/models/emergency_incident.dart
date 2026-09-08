import 'ai_intelligence.dart';
import 'emergency_enums.dart';

/// Central domain model representing an emergency incident lifecycle in Pukaar.
class EmergencyIncident {
  /// Unique incident identifier.
  final String id;

  /// Identifier of the citizen user or session who triggered the incident.
  final String userId;

  /// Primary emergency category pillar.
  final EmergencyCategory category;

  /// Specific emergency intent/type subcategory (e.g., 'Ambulance', 'Harassment', 'Fire').
  final String intent;

  /// Incident latitude at time of trigger (nullable).
  final double? latitude;

  /// Incident longitude at time of trigger (nullable).
  final double? longitude;

  /// Accurate GPS accuracy radius in meters if provided (nullable).
  final double? accuracy;

  /// Timestamp when the incident was created.
  final DateTime timestamp;

  /// Triage priority score / level.
  final EmergencyPriority priority;

  /// Real-time lifecycle status of the incident.
  final EmergencyStatus status;

  // --- Prepared extension fields for future Responder / GIS dispatch ---

  /// Identifier of the matched responder unit (e.g., Ambulance unit ID, Patrol car ID).
  final String? assignedResponderId;

  /// Human-readable name of the responder or service team.
  final String? assignedResponderName;

  /// Direct contact phone for the assigned responder unit.
  final String? assignedResponderPhone;

  /// Type designation of the responder (e.g., 'Paramedic', 'Police Officer', 'Fire Brigade').
  final String? assignedResponderType;

  /// Live responder latitude coordinate.
  final double? responderLatitude;

  /// Live responder longitude coordinate.
  final double? responderLongitude;

  /// Estimated time of arrival (ETA) in minutes.
  final int? estimatedArrivalMinutes;

  /// Optional contextual incident notes or dispatcher triage remarks.
  final String? notes;

  /// Optional AI incident intelligence and responder guidance metadata.
  final AIIntelligence? aiIntelligence;

  const EmergencyIncident({
    required this.id,
    required this.userId,
    required this.category,
    required this.intent,
    this.latitude,
    this.longitude,
    this.accuracy,
    required this.timestamp,
    this.priority = EmergencyPriority.high,
    this.status = EmergencyStatus.created,
    this.assignedResponderId,
    this.assignedResponderName,
    this.assignedResponderPhone,
    this.assignedResponderType,
    this.responderLatitude,
    this.responderLongitude,
    this.estimatedArrivalMinutes,
    this.notes,
    this.aiIntelligence,
  });

  /// Creates a copy of this incident with modified fields.
  EmergencyIncident copyWith({
    String? id,
    String? userId,
    EmergencyCategory? category,
    String? intent,
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
    EmergencyPriority? priority,
    EmergencyStatus? status,
    String? assignedResponderId,
    String? assignedResponderName,
    String? assignedResponderPhone,
    String? assignedResponderType,
    double? responderLatitude,
    double? responderLongitude,
    int? estimatedArrivalMinutes,
    String? notes,
    AIIntelligence? aiIntelligence,
  }) {
    return EmergencyIncident(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      intent: intent ?? this.intent,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignedResponderId: assignedResponderId ?? this.assignedResponderId,
      assignedResponderName: assignedResponderName ?? this.assignedResponderName,
      assignedResponderPhone: assignedResponderPhone ?? this.assignedResponderPhone,
      assignedResponderType: assignedResponderType ?? this.assignedResponderType,
      responderLatitude: responderLatitude ?? this.responderLatitude,
      responderLongitude: responderLongitude ?? this.responderLongitude,
      estimatedArrivalMinutes: estimatedArrivalMinutes ?? this.estimatedArrivalMinutes,
      notes: notes ?? this.notes,
      aiIntelligence: aiIntelligence ?? this.aiIntelligence,
    );
  }

  /// Serializes to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'category': category.name,
      'intent': intent,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'priority': priority.name,
      'status': status.name,
      'assignedResponderId': assignedResponderId,
      'assignedResponderName': assignedResponderName,
      'assignedResponderPhone': assignedResponderPhone,
      'assignedResponderType': assignedResponderType,
      'responderLatitude': responderLatitude,
      'responderLongitude': responderLongitude,
      'estimatedArrivalMinutes': estimatedArrivalMinutes,
      'notes': notes,
      if (aiIntelligence != null) 'aiIntelligence': aiIntelligence!.toJson(),
    };
  }

  /// Deserializes from JSON map.
  factory EmergencyIncident.fromJson(Map<String, dynamic> json) {
    return EmergencyIncident(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      category: EmergencyCategory.fromString(json['category'] as String? ?? 'medical'),
      intent: json['intent'] as String? ?? 'General Emergency',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      priority: EmergencyPriority.fromString(json['priority'] as String? ?? 'high'),
      status: EmergencyStatus.fromString(json['status'] as String? ?? 'created'),
      assignedResponderId: json['assignedResponderId'] as String?,
      assignedResponderName: json['assignedResponderName'] as String?,
      assignedResponderPhone: json['assignedResponderPhone'] as String?,
      assignedResponderType: json['assignedResponderType'] as String?,
      responderLatitude: (json['responderLatitude'] as num?)?.toDouble(),
      responderLongitude: (json['responderLongitude'] as num?)?.toDouble(),
      estimatedArrivalMinutes: json['estimatedArrivalMinutes'] as int?,
      notes: json['notes'] as String?,
      aiIntelligence: json['aiIntelligence'] != null && json['aiIntelligence'] is Map<String, dynamic>
          ? AIIntelligence.fromJson(json['aiIntelligence'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  String toString() {
    return 'EmergencyIncident(id: $id, user: $userId, category: ${category.name}, intent: $intent, status: ${status.name}, priority: ${priority.name})';
  }
}
