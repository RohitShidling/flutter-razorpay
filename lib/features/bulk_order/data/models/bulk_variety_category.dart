class BulkVarietyCategory {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int sortOrder;
  final int mealCount;

  BulkVarietyCategory({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.sortOrder = 0,
    this.mealCount = 0,
  });

  factory BulkVarietyCategory.fromJson(Map<String, dynamic> json) {
    return BulkVarietyCategory(
      id: '${json['id']}',
      name: '${json['name'] ?? ''}',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      mealCount: int.tryParse('${json['meal_count'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'sort_order': sortOrder,
        'meal_count': mealCount,
      };
}
