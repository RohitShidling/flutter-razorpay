import 'package:meal_app/core/utils/money_format.dart';

class SubscriptionModel {
  final String id;
  final String planName;
  final String price;
  final String priceWithSaturday;
  final String priceWithoutSaturday;
  final bool saturdayOptionEnabled;
  final String billingCycle;
  final int durationDays;
  final int? durationDaysWithSaturday;
  final int? durationDaysWithoutSaturday;
  final int trialDays;
  final List<String> features;
  final int displayOrder;
  final bool? isActive;
  final int? mealSizeId;

  SubscriptionModel({
    required this.id,
    required this.planName,
    required this.price,
    required this.priceWithSaturday,
    required this.priceWithoutSaturday,
    required this.saturdayOptionEnabled,
    required this.billingCycle,
    required this.durationDays,
    this.durationDaysWithSaturday,
    this.durationDaysWithoutSaturday,
    required this.trialDays,
    required this.features,
    required this.displayOrder,
    this.isActive,
    this.mealSizeId,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'],
      planName: json['plan_name'],
      price: MoneyFormat.display(json['price']),
      priceWithSaturday: MoneyFormat.display(json['price_with_saturday'] ?? json['price'] ?? '0'),
      priceWithoutSaturday: MoneyFormat.display(json['price_without_saturday'] ?? json['price'] ?? '0'),
      saturdayOptionEnabled: json['saturday_option_enabled'] == null ? true : json['saturday_option_enabled'] == true,
      billingCycle: json['billing_cycle'],
      durationDays: int.tryParse('${json['duration_days'] ?? 0}') ?? 0,
      durationDaysWithSaturday: json['duration_days_with_saturday'] == null
          ? null
          : int.tryParse('${json['duration_days_with_saturday']}'),
      durationDaysWithoutSaturday: json['duration_days_without_saturday'] == null
          ? null
          : int.tryParse('${json['duration_days_without_saturday']}'),
      trialDays: int.tryParse('${json['trial_days'] ?? 0}') ?? 0,
      features: ((json['features'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      displayOrder: int.tryParse('${json['display_order'] ?? 0}') ?? 0,
      isActive: json['is_active'],
      mealSizeId: json['meal_size_id'] == null ? null : int.tryParse('${json['meal_size_id']}'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plan_name': planName,
        'price': price,
        'price_with_saturday': priceWithSaturday,
        'price_without_saturday': priceWithoutSaturday,
        'saturday_option_enabled': saturdayOptionEnabled,
        'billing_cycle': billingCycle,
        'duration_days': durationDays,
        'duration_days_with_saturday': durationDaysWithSaturday,
        'duration_days_without_saturday': durationDaysWithoutSaturday,
        'trial_days': trialDays,
        'features': features,
        'display_order': displayOrder,
        'is_active': isActive,
        'meal_size_id': mealSizeId,
      };
}
