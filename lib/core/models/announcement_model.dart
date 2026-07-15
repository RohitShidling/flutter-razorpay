class AnnouncementModel {
  final String id;
  final String title;
  final String message;
  final DateTime startDate;
  final DateTime endDate;
  final String displayLocation;
  final int priority;
  final DateTime? createdAt;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    required this.startDate,
    required this.endDate,
    required this.displayLocation,
    required this.priority,
    this.createdAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      startDate: DateTime.parse(json['start_date'] as String? ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['end_date'] as String? ?? DateTime.now().toIso8601String()),
      displayLocation: json['display_location'] as String? ?? 'home',
      priority: json['priority'] as int? ?? 1,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'display_location': displayLocation,
      'priority': priority,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }
}
