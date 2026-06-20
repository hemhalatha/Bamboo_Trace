class AuthUser {
  AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.addressLine,
    this.city,
    this.district,
    this.state,
    this.pincode,
    this.landmark,
    this.profileComplete = false,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final String? phone;
  final String? addressLine;
  final String? city;
  final String? district;
  final String? state;
  final String? pincode;
  final String? landmark;
  final bool profileComplete;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      phone: json['phone']?.toString(),
      addressLine: json['addressLine']?.toString(),
      city: json['city']?.toString(),
      district: json['district']?.toString(),
      state: json['state']?.toString(),
      pincode: json['pincode']?.toString(),
      landmark: json['landmark']?.toString(),
      profileComplete: json['profileComplete'] == true,
    );
  }

  String get publicLocation {
    final parts = <String>[];
    for (final part in [city, district]) {
      final value = part?.trim();
      if (value != null && value.isNotEmpty) parts.add(value);
    }
    return parts.isEmpty ? 'Not specified' : parts.join(', ');
  }

  String get fullAddress {
    final parts = <String>[];
    for (final part in [addressLine, city, district, state, pincode, landmark]) {
      final value = part?.trim();
      if (value != null && value.isNotEmpty) parts.add(value);
    }
    return parts.isEmpty ? 'Not specified' : parts.join(', ');
  }
}
