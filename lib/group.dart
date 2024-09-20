class GroupMessage {
  final int messageId;
  final int groupId;
  final String groupName;
  final String senderId;
  final String senderName;
  final String messageContent;
  final String timestamp;

  GroupMessage(this.messageId, this.groupId, this.groupName, this.senderId,
      this.senderName, this.messageContent, this.timestamp);
}
