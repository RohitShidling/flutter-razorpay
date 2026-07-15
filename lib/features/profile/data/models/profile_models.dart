class TeacherProfileModel {
  final String? id;
  final String name;
  final String schoolCollegeName;
  // AUDIT-056: Stable school identifier — use this for surcharge lookups instead of name.
  final String? schoolId;
  final String city;
  final String state;
  final String location;
  final String status;
  final int? mealSizeId;
  final String? mealTime;
  final int? standardId;
  final String? standardName;
  final int? divisionId;
  final String? divisionName;
  final String? phoneNumber;

  TeacherProfileModel({
    this.id,
    required this.name,
    required this.schoolCollegeName,
    this.schoolId,
    required this.city,
    required this.state,
    required this.location,
    this.status = 'active',
    this.mealSizeId,
    this.mealTime,
    this.standardId,
    this.standardName,
    this.divisionId,
    this.divisionName,
    this.phoneNumber,
  });

  factory TeacherProfileModel.fromJson(Map<String, dynamic> json) {
    final parsedId = json['id'] ??
        json['teacher_id'] ??
        json['profile_id'] ??
        json['entity_id'];
    return TeacherProfileModel(
      id: parsedId?.toString(),
      name: json['name']?.toString() ?? '',
      schoolCollegeName: json['school_college_name']?.toString() ??
          json['schoolCollegeName']?.toString() ??
          '',
      // AUDIT-056: Capture stable school_id for ID-based surcharge lookup.
      schoolId: json['school_id']?.toString() ?? json['schoolId']?.toString(),
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      mealSizeId: json['meal_size_id'] is int
          ? json['meal_size_id'] as int
          : int.tryParse('${json['meal_size_id'] ?? json['mealSizeId'] ?? ''}'),
      mealTime: json['meal_time']?.toString() ?? json['mealTiming']?.toString(),
      standardId: json['standard_id'] is int
          ? json['standard_id'] as int
          : int.tryParse('${json['standard_id'] ?? json['standardId'] ?? ''}'),
      standardName: json['standard_name']?.toString(),
      divisionId: json['division_id'] is int
          ? json['division_id'] as int
          : int.tryParse('${json['division_id'] ?? json['divisionId'] ?? ''}'),
      divisionName: json['division_name']?.toString(),
      phoneNumber: json['phone_number']?.toString() ?? json['phoneNumber']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'school_college_name': schoolCollegeName,
      'school_id': schoolId,
      'schoolId': schoolId,
      'city': city,
      'state': state,
      'location': location,
      'status': status,
      'meal_size_id': mealSizeId,
      'meal_time': mealTime,
      'standard_id': standardId,
      'standardId': standardId,
      'standard_name': standardName,
      'division_id': divisionId,
      'divisionId': divisionId,
      'division_name': divisionName,
      'phone_number': phoneNumber,
      'phoneNumber': phoneNumber,
    };
  }
}

class ProfessionalProfileModel {
  final String? id;
  final String name;
  final String companyName;
  final String corporateLocationId;
  final String city;
  final String state;
  final String lunchTime;
  final String? corporateLocationName;
  final int? mealSizeId;
  final String? phoneNumber;

  ProfessionalProfileModel({
    this.id,
    required this.name,
    required this.companyName,
    required this.corporateLocationId,
    required this.city,
    required this.state,
    required this.lunchTime,
    this.corporateLocationName,
    this.mealSizeId,
    this.phoneNumber,
  });

  factory ProfessionalProfileModel.fromJson(Map<String, dynamic> json) {
    final parsedId = json['id'] ??
        json['professional_id'] ??
        json['profile_id'] ??
        json['entity_id'];
    return ProfessionalProfileModel(
      id: parsedId?.toString(),
      name: json['name'],
      companyName: json['company_name'],
      corporateLocationId: json['corporate_location_id'],
      city: json['city'],
      state: json['state'],
      lunchTime: json['lunch_time'],
      corporateLocationName: json['corporate_location_name'],
      mealSizeId: json['meal_size_id'],
      phoneNumber: json['phone_number']?.toString() ?? json['phoneNumber']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company_name': companyName,
      'corporate_location_id': corporateLocationId,
      'corporate_location_name': corporateLocationName,
      'city': city,
      'state': state,
      'lunch_time': lunchTime,
      'meal_size_id': mealSizeId,
      'phone_number': phoneNumber,
      'phoneNumber': phoneNumber,
    };
  }
}
