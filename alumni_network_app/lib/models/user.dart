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
  final String? profilePictureUrl;
  final String? currentStatus;
  final String? designation;
  final String? responsibilities;
  final bool isVerified;
  
  // Student specifically
  final String? educationalDetails;
  final String? resumeUrl;
  final String? interests;
  final String? skills;

  // Alumni specific fields
  final String? company;
  final String? jobTitle;
  final bool? mentorshipAvailable;
  final String? experienceSummary;

  // Inbox unread count (only populated in conversations list)
  final int unreadCount;

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
    this.profilePictureUrl,
    this.currentStatus,
    this.designation,
    this.responsibilities,
    this.isVerified = false,
    this.educationalDetails,
    this.resumeUrl,
    this.interests,
    this.skills,
    this.company,
    this.jobTitle,
    this.mentorshipAvailable,
    this.experienceSummary,
    this.unreadCount = 0,
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
      profilePictureUrl: json['profile_picture_url'],
      currentStatus: json['current_status'],
      designation: json['designation'],
      responsibilities: json['responsibilities'],
      isVerified: json['is_verified'] ?? false,
      educationalDetails: json['educational_details'],
      resumeUrl: json['resume_url'],
      interests: json['interests'],
      skills: json['skills'],
      company: json['company'],
      jobTitle: json['job_title'],
      mentorshipAvailable: json['mentorship_available'],
      experienceSummary: json['experience_summary'],
      unreadCount: json['unread_count'] ?? 0,
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
      'profile_picture_url': profilePictureUrl,
      'current_status': currentStatus,
      'designation': designation,
      'responsibilities': responsibilities,
      'is_verified': isVerified,
      'educational_details': educationalDetails,
      'resume_url': resumeUrl,
      'interests': interests,
      'skills': skills,
      'company': company,
      'job_title': jobTitle,
      'mentorship_available': mentorshipAvailable,
      'experience_summary': experienceSummary,
    };
  }
}
