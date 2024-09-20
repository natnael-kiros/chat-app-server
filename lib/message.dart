class Message {
  final String messageId;
  final String senderUsername;
  final String recipientUsername;
  final String content;
  final String timestamp;
  final bool isRead;
  final bool isSent;

  Message(this.messageId, this.senderUsername, this.recipientUsername,
      this.content, this.timestamp, this.isRead, this.isSent);

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'senderUsername': senderUsername,
      'recipientUsername': recipientUsername,
      'content': content,
      'timestamp': timestamp,
      'isRead': isRead,
      'isSent': isSent,
    };
  }
}
