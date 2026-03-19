class User {
  final int userId;
  final String email;
  final String fullName;
  final String role;
  final String? phone;
  final String? department;
  final int? graduationYear;
  final String? city;
  final String? bio;
  final bool isVerified;

  User({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.role,
    this.phone,
    this.department,
    this.graduationYear,
    this.city,
    this.bio,
    this.isVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      email: json['email'],
      fullName: json['full_name'],
      role: json['role'],
      phone: json['phone'],
      department: json['department'],
      graduationYear: json['graduation_year'],
      city: json['city'],
      bio: json['bio'],
      isVerified: json['is_verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'full_name': fullName,
      'role': role,
      'phone': phone,
      'department': department,
      'graduation_year': graduationYear,
      'city': city,
      'bio': bio,
      'is_verified': isVerified,
    };
  }
}
