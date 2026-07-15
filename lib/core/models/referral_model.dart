class ReferralRewardModel {
  final int id;
  final int mealsRewarded;
  final int mealsClaimed;
  final String status;
  final String? allocatedEntityType;
  final String? allocatedEntityId;
  final DateTime? allocatedAt;
  final DateTime createdAt;
  final String referredUsername;

  ReferralRewardModel({
    required this.id,
    required this.mealsRewarded,
    this.mealsClaimed = 0,
    required this.status,
    this.allocatedEntityType,
    this.allocatedEntityId,
    this.allocatedAt,
    required this.createdAt,
    required this.referredUsername,
  });

  factory ReferralRewardModel.fromJson(Map<String, dynamic> json) {
    return ReferralRewardModel(
      id: json['id'] as int,
      mealsRewarded: json['meals_rewarded'] as int,
      mealsClaimed: json['meals_claimed'] as int? ?? 0,
      status: json['status'] as String,
      allocatedEntityType: json['allocated_entity_type'] as String?,
      allocatedEntityId: json['allocated_entity_id'] as String?,
      allocatedAt: json['allocated_at'] != null
          ? DateTime.parse(json['allocated_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      referredUsername: json['referred_username'] as String? ?? 'User',
    );
  }

  int get mealsRemaining => mealsRewarded - mealsClaimed;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meals_rewarded': mealsRewarded,
      'meals_claimed': mealsClaimed,
      'status': status,
      'allocated_entity_type': allocatedEntityType,
      'allocated_entity_id': allocatedEntityId,
      'allocated_at': allocatedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'referred_username': referredUsername,
    };
  }
}
