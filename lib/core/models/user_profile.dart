/// User emergency profile containing details critical for responders.
class UserProfile {
  final String name;
  final String mobileNumber;
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
    this.email,
    this.age,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.bloodGroup,
    this.allergies,
    this.medications,
  });

  UserProfile copyWith({
    String? name,
    String? mobileNumber,
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
      email: email ?? this.email,
      age: age ?? this.age,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mobileNumber': mobileNumber,
      'email': email,
      'age': age,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'medications': medications,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      mobileNumber: json['mobileNumber'] as String? ?? '',
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
