class Internship {
  final int internshipId;
  final int postedBy;
  final String postedByName;
  final String companyName;
  final String roleTitle;
  final String? description;
  final String? location;
  final String? duration;
  final String? stipend;
  final String? skillsRequired;
  final String? applyDeadline;
  final int seatsAvailable;
  final String status;
  final DateTime createdAt;

  Internship({
    required this.internshipId,
    required this.postedBy,
    this.postedByName = 'Unknown',
    required this.companyName,
    required this.roleTitle,
    this.description,
    this.location,
    this.duration,
    this.stipend,
    this.skillsRequired,
    this.applyDeadline,
    required this.seatsAvailable,
    required this.status,
    required this.createdAt,
  });

  factory Internship.fromJson(Map<String, dynamic> json) {
    return Internship(
      internshipId: json['internship_id'],
      postedBy: json['posted_by'],
      postedByName: json['posted_by_name'] ?? 'Unknown',
      companyName: json['company'] ?? json['company_name'],
      roleTitle: json['role_title'],
      description: json['description'],
      location: json['location'],
      duration: json['duration'],
      stipend: json['stipend'],
      skillsRequired: json['required_skills'] ?? json['skills_required'],
      applyDeadline: json['deadline'] ?? json['apply_deadline'],
      seatsAvailable: json['seats'] ?? json['seats_available'] ?? 1,
      status: json['status'] ?? 'open',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class InternshipApplication {
  final int applicationId;
  final int internshipId;
  final int studentId;
  final String? coverNote;
  final String? resumeUrl;
  final String status;
  final DateTime appliedAt;

  InternshipApplication({
    required this.applicationId,
    required this.internshipId,
    required this.studentId,
    this.coverNote,
    this.resumeUrl,
    required this.status,
    required this.appliedAt,
  });

  factory InternshipApplication.fromJson(Map<String, dynamic> json) {
    return InternshipApplication(
      applicationId: json['application_id'],
      internshipId: json['internship_id'],
      studentId: json['student_id'],
      coverNote: json['cover_note'],
      resumeUrl: json['resume_url'],
      status: json['status'],
      appliedAt: DateTime.parse(json['applied_at']),
    );
  }
}
