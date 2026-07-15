class HomepageEntry {
  final String id;
  final String? entityId;
  final String? entityName;
  final String name;
  final String description;
  final int displayOrder;
  final bool isActive;

  HomepageEntry({
    required this.id,
    this.entityId,
    this.entityName,
    required this.name,
    required this.description,
    required this.displayOrder,
    required this.isActive,
  });

  factory HomepageEntry.fromJson(Map<String, dynamic> json) {
    return HomepageEntry(
      id: json['id'] as String,
      entityId: json['entity_id'] as String?,
      entityName: json['entity_name'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
      displayOrder: json['display_order'] as int,
      isActive: json['is_active'] as bool,
    );
  }
}
