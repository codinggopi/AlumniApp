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
    return Message(
      messageId: json['message_id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      content: json['content'],
      sentAt: DateTime.parse(json['sent_at']).toLocal(),
    );
  }
}
