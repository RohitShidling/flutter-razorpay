class BulkDeliveryAddress {
  final int? id;
  final String label;
  final int stateId;
  final int cityId;
  final String addressLine;
  final String? pincode;
  final String? stateName;
  final String? cityName;
  final bool isDefault;
  final String? deliveryTime;
  final String? phoneNumber;
  final String? altPhoneNumber;

  const BulkDeliveryAddress({
    this.id,
    this.label = '',
    required this.stateId,
    required this.cityId,
    required this.addressLine,
    this.pincode,
    this.stateName,
    this.cityName,
    this.isDefault = false,
    this.deliveryTime,
    this.phoneNumber,
    this.altPhoneNumber,
  });

  Map<String, dynamic> toApiPayload() => {
        if (id != null) 'saved_address_id': id,
        if (label.trim().isNotEmpty) 'label': label.trim(),
        'stateId': stateId,
        'cityId': cityId,
        'address': addressLine,
        'pincode': (pincode != null && pincode!.trim().isNotEmpty) ? pincode!.trim() : null,
        'deliveryTime': (deliveryTime != null && deliveryTime!.trim().isNotEmpty)
            ? deliveryTime!.trim()
            : null,
        'phoneNumber': (phoneNumber != null && phoneNumber!.trim().isNotEmpty)
            ? phoneNumber!.trim()
            : null,
        'altPhoneNumber': (altPhoneNumber != null && altPhoneNumber!.trim().isNotEmpty)
            ? altPhoneNumber!.trim()
            : null,
      };

  String get formatted {
    final parts = <String>[
      addressLine.trim(),
      if (cityName != null && cityName!.isNotEmpty) cityName!,
      if (stateName != null && stateName!.isNotEmpty) stateName!,
      if (pincode != null && pincode!.trim().isNotEmpty) pincode!.trim(),
    ];
    return parts.join(', ');
  }

  bool get isComplete =>
      stateId > 0 && cityId > 0 && addressLine.trim().length >= 5;

  bool get hasDeliveryTime =>
      deliveryTime != null && deliveryTime!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'stateId': stateId,
        'cityId': cityId,
        'addressLine': addressLine,
        'pincode': pincode,
        'stateName': stateName,
        'cityName': cityName,
        'isDefault': isDefault,
        'deliveryTime': deliveryTime,
        'phoneNumber': phoneNumber,
        'altPhoneNumber': altPhoneNumber,
      };

  factory BulkDeliveryAddress.fromJson(Map<String, dynamic> json) {
    return BulkDeliveryAddress(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}'),
      label: json['label']?.toString() ?? '',
      stateId:
          int.tryParse('${json['stateId'] ?? json['state_id']}') ?? 0,
      cityId:
          int.tryParse('${json['cityId'] ?? json['city_id']}') ?? 0,
      addressLine: json['addressLine']?.toString() ??
          json['address_line']?.toString() ??
          '',
      pincode: json['pincode']?.toString(),
      stateName: json['stateName']?.toString() ??
          json['state_name']?.toString(),
      cityName:
          json['cityName']?.toString() ?? json['city_name']?.toString(),
      isDefault:
          json['isDefault'] == true || json['is_default'] == true,
      deliveryTime: json['deliveryTime']?.toString() ??
          json['delivery_time']?.toString(),
      phoneNumber: json['phoneNumber']?.toString() ??
          json['phone_number']?.toString(),
      altPhoneNumber: json['altPhoneNumber']?.toString() ??
          json['alt_phone_number']?.toString(),
    );
  }
}
