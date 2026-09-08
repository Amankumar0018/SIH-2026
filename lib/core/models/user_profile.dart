/// User emergency profile containing details critical for responders.
class UserProfile {
  final String name;
  final String mobileNumber;
  final String role;
  final String? token;
  final String? email;
  final int? age;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String? bloodGroup;
  final String? allergies;
  final String? medications;

  const UserProfile({
    required this.name,
    required this.mobileNumber,
    this.role = 'citizen',
    this.token,
    this.email,
    this.age,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.bloodGroup,
    this.allergies,
    this.medications,
  });

  /// Check if user has responder capabilities (either primary responder or dual role)
  bool get isResponder {
    final r = role.toLowerCase();
    return r == 'responder' || r == 'dual' || r.contains('responder');
  }

  /// Check if user has dual capabilities (both citizen & responder)
  bool get isDual => role.toLowerCase() == 'dual';

  /// All authenticated users have citizen emergency capabilities
  bool get isCitizen => true;

  UserProfile copyWith({
    String? name,
    String? mobileNumber,
    String? role,
    String? token,
    bool clearToken = false,
    String? email,
    int? age,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? bloodGroup,
    String? allergies,
    String? medications,
  }) {
    return UserProfile(
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      role: role ?? this.role,
      token: clearToken ? null : (token ?? this.token),
      email: email ?? this.email,
      age: age ?? this.age,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
    );
  }

  UserProfile withoutToken() => copyWith(clearToken: true);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'mobileNumber': mobileNumber,
      'role': role,
      'email': email,
      'age': age,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'medications': medications,
    };
    if (token != null) {
      map['token'] = token;
    }
    return map;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      mobileNumber: json['mobileNumber'] as String? ?? '',
      role: json['role'] as String? ?? 'citizen',
      token: json['token'] as String?,
      email: json['email'] as String?,
      age: json['age'] as int?,
      emergencyContactName: json['emergencyContactName'] as String? ?? '',
      emergencyContactPhone: json['emergencyContactPhone'] as String? ?? '',
      bloodGroup: json['bloodGroup'] as String?,
      allergies: json['allergies'] as String?,
      medications: json['medications'] as String?,
    );
  }
}
