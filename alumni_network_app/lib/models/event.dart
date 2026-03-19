class Event {
  final int eventId;
  final String title;
  final String? description;
  final String? date;
  final String? location;
  final String category;
  final DateTime createdAt;

  Event({
    required this.eventId,
    required this.title,
    this.description,
    this.date,
    this.location,
    required this.category,
    required this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      eventId: json['event_id'],
      title: json['title'],
      description: json['description'],
      date: json['date'],
      location: json['location'],
      category: json['category'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
