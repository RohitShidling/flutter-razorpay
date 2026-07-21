class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String category;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.payload,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      category: json['category'] ?? 'announcement',
      payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload']) : {},
      isRead: json['is_read'] == true,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
