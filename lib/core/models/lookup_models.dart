import 'package:flutter/material.dart';

class SchoolModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final bool hasLunchBoxPickup;
  final String? lunchBoxPickupTime;
  final double extraAmount;

  SchoolModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    this.hasLunchBoxPickup = false,
    this.lunchBoxPickupTime,
    this.extraAmount = 0.0,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['id'] is int ? json['id'].toString() : json['id'],
      name: json['name'],
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      hasLunchBoxPickup: json['has_lunch_box_pickup'] ?? false,
      lunchBoxPickupTime: json['lunch_box_pickup_time'],
      extraAmount: double.tryParse('${json['extra_amount'] ?? 0.0}') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'has_lunch_box_pickup': hasLunchBoxPickup,
      'lunch_box_pickup_time': lunchBoxPickupTime,
      'extra_amount': extraAmount,
    };
  }
}

class StandardModel {
  final int id;
  final String name;
  final String displayName;

  StandardModel({
    required this.id,
    required this.name,
    required this.displayName,
  });

  factory StandardModel.fromJson(Map<String, dynamic> json) {
    return StandardModel(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
    };
  }
}

class MealSizeModel {
  final int id;
  final String name;
  final String displayName;
  final int sortOrder;

  MealSizeModel({
    required this.id,
    required this.name,
    required this.displayName,
    this.sortOrder = 0,
  });

  factory MealSizeModel.fromJson(Map<String, dynamic> json) {
    return MealSizeModel(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'],
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'sort_order': sortOrder,
    };
  }

  /// Highest tier in the catalog (e.g. Large / Extra Large).
  static int? largestTierId(List<MealSizeModel> sizes) {
    if (sizes.isEmpty) return null;
    MealSizeModel? top;
    for (final s in sizes) {
      if (top == null || s.sortOrder > top.sortOrder || (s.sortOrder == top.sortOrder && s.id > top.id)) {
        top = s;
      }
    }
    return top?.id;
  }
}

class CorporateLocationModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final double extraAmount;

  CorporateLocationModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    this.extraAmount = 0.0,
  });

  factory CorporateLocationModel.fromJson(Map<String, dynamic> json) {
    return CorporateLocationModel(
      id: json['id'],
      name: json['name'],
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      extraAmount: double.tryParse('${json['extra_amount'] ?? 0.0}') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'extra_amount': extraAmount,
    };
  }
}

class StateModel {
  final int id;
  final String name;

  StateModel({required this.id, required this.name});

  factory StateModel.fromJson(Map<String, dynamic> json) {
    return StateModel(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class CityModel {
  final int id;
  final int stateId;
  final String name;

  CityModel({required this.id, required this.stateId, required this.name});

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: json['id'],
      stateId: json['state_id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'state_id': stateId,
      'name': name,
    };
  }
}

class CompanyModel {
  final int id;
  final int cityId;
  final String name;

  CompanyModel({required this.id, required this.cityId, required this.name});

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'],
      cityId: json['city_id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'city_id': cityId,
      'name': name,
    };
  }
}

class DivisionModel {
  final int id;
  final String name;

  DivisionModel({
    required this.id,
    required this.name,
  });

  factory DivisionModel.fromJson(Map<String, dynamic> json) {
    return DivisionModel(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class ContactUsModel {
  final String title;
  final String subtitle;
  final String email;
  final String phone;
  final String footer;
  final String appName;
  final String aboutTitle;
  final String aboutDescription;
  final String aboutFooter;
  final String licenseText;
  final String websiteUrl;
  final bool aboutActive;

  ContactUsModel({
    required this.title,
    required this.subtitle,
    required this.email,
    required this.phone,
    required this.footer,
    this.appName = 'Buuttii',
    this.aboutTitle = 'About Buuttii',
    this.aboutDescription = 'Buuttii helps parents, teachers, and professionals manage daily meal subscriptions, menus, and skips in one place.',
    this.aboutFooter = '',
    this.licenseText = '',
    this.websiteUrl = 'https://buuttii.com/',
    this.aboutActive = true,
  });

  factory ContactUsModel.fromJson(Map<String, dynamic> json) {
    return ContactUsModel(
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      footer: (json['footer'] ?? '').toString(),
      appName: (json['app_name'] ?? json['brand_name'] ?? 'Buuttii').toString(),
      aboutTitle: (json['about_title'] ?? json['aboutTitle'] ?? 'About ${json['app_name'] ?? json['brand_name'] ?? 'Buuttii'}').toString(),
      aboutDescription: (json['about_description'] ?? json['aboutDescription'] ?? 'Buuttii helps parents, teachers, and professionals manage daily meal subscriptions, menus, and skips in one place.').toString(),
      aboutFooter: (json['about_footer'] ?? json['aboutFooter'] ?? '').toString(),
      licenseText: (json['license_text'] ?? json['licenseText'] ?? '').toString(),
      websiteUrl: (json['website_url'] ?? json['websiteUrl'] ?? 'https://buuttii.com/').toString(),
      aboutActive: json['about_active'] != null 
          ? (json['about_active'] is bool 
              ? json['about_active'] as bool 
              : (json['about_active'] == 1 || json['about_active'].toString() == 'true' || json['about_active'].toString() == '1'))
          : true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'email': email,
      'phone': phone,
      'footer': footer,
      'app_name': appName,
      'about_title': aboutTitle,
      'about_description': aboutDescription,
      'about_footer': aboutFooter,
      'license_text': licenseText,
      'website_url': websiteUrl,
      'about_active': aboutActive,
    };
  }
}

class DeliveryTimeSettingsModel {
  final bool isEnabled;
  final String startTime;
  final String endTime;

  DeliveryTimeSettingsModel({
    required this.isEnabled,
    required this.startTime,
    required this.endTime,
  });

  factory DeliveryTimeSettingsModel.fromJson(Map<String, dynamic> json) {
    return DeliveryTimeSettingsModel(
      isEnabled: json['is_enabled'] ?? json['isEnabled'] ?? true,
      startTime: (json['start_time'] ?? json['startTime'] ?? '09:00').toString(),
      endTime: (json['end_time'] ?? json['endTime'] ?? '18:00').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_enabled': isEnabled,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  TimeOfDay? _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  bool allows(TimeOfDay time) {
    if (!isEnabled) return true;
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);
    if (start == null || end == null) return true;
    final current = time.hour * 60 + time.minute;
    final startM = start.hour * 60 + start.minute;
    final endM = end.hour * 60 + end.minute;
    return current >= startM && current <= endM;
  }

  TimeOfDay? get start => _parseTime(startTime);
  TimeOfDay? get end => _parseTime(endTime);
}

class AllowedAddressModel {
  final int id;
  final int stateId;
  final int cityId;
  final String addressLine;
  final String pincode;
  final bool isActive;

  AllowedAddressModel({
    required this.id,
    required this.stateId,
    required this.cityId,
    required this.addressLine,
    required this.pincode,
    this.isActive = true,
  });

  factory AllowedAddressModel.fromJson(Map<String, dynamic> json) {
    return AllowedAddressModel(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      stateId: json['state_id'] is String ? int.parse(json['state_id']) : json['state_id'],
      cityId: json['city_id'] is String ? int.parse(json['city_id']) : json['city_id'],
      addressLine: json['address_line'] ?? '',
      pincode: json['pincode'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'state_id': stateId,
      'city_id': cityId,
      'address_line': addressLine,
      'pincode': pincode,
      'is_active': isActive,
    };
  }
}

class LoginCarouselImageModel {
  final int id;
  final String imageUrl;
  final int displayOrder;

  LoginCarouselImageModel({
    required this.id,
    required this.imageUrl,
    required this.displayOrder,
  });

  factory LoginCarouselImageModel.fromJson(Map<String, dynamic> json) {
    return LoginCarouselImageModel(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      imageUrl: json['image_url'] ?? '',
      displayOrder: json['display_order'] is String ? int.parse(json['display_order']) : (json['display_order'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'display_order': displayOrder,
    };
  }
}
