class Message {
  final int messageId;
  final int senderId;
  final int receiverId;
  final String content;
  final DateTime sentAt;

  Message({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.sentAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final rawSentAt = json['sent_at'] as String;
    final normalizedSentAt = rawSentAt.contains('Z') ||
            rawSentAt.contains('+') ||
            rawSentAt.lastIndexOf('-') > rawSentAt.indexOf('T')
        ? rawSentAt
        : '${rawSentAt}Z';

    return Message(
      messageId: json['message_id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      content: json['content'],
      sentAt: DateTime.parse(normalizedSentAt).toUtc(),
    );
  }

  DateTime get sentAtIst => sentAt.add(const Duration(hours: 5, minutes: 30));
}
