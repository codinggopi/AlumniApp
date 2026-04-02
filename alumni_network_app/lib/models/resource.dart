class AppResource {
  final int resourceId;
  final int createdBy;
  final String title;
  final String? description;
  final String resourceType; // 'document' or 'link'
  final String url;
  final String targetAudience;
  final DateTime createdAt;

  AppResource({
    required this.resourceId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.resourceType,
    required this.url,
    required this.targetAudience,
    required this.createdAt,
  });

  factory AppResource.fromJson(Map<String, dynamic> json) {
    return AppResource(
      resourceId: json['resource_id'],
      createdBy: json['created_by'],
      title: json['title'],
      description: json['description'],
      resourceType: json['resource_type'],
      url: json['url'],
      targetAudience: json['target_audience'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resource_id': resourceId,
      'created_by': createdBy,
      'title': title,
      'description': description,
      'resource_type': resourceType,
      'url': url,
      'target_audience': targetAudience,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
