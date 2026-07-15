class ChildModel {
  final String? id;
  final String name;
  final String rollNumber;
  final String schoolId;
  final int standardId;
  final int mealSizeId;
  final String mealTime;
  final String? schoolName;
  final String? standardName;
  final String? mealSizeName;
  final int? divisionId;
  final String? divisionName;
  final String? phoneNumber;

  ChildModel({
    this.id,
    required this.name,
    required this.rollNumber,
    required this.schoolId,
    required this.standardId,
    required this.mealSizeId,
    required this.mealTime,
    this.schoolName,
    this.standardName,
    this.mealSizeName,
    this.divisionId,
    this.divisionName,
    this.phoneNumber,
  });

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    return ChildModel(
      id: json['id'],
      name: json['name'],
      rollNumber: json['roll_number'] ?? json['rollNumber'],
      schoolId: json['school_id'] ?? json['schoolId'],
      standardId: json['standard_id'] ?? json['standardId'],
      mealSizeId: int.tryParse('${json['meal_size_id'] ?? json['mealSizeId'] ?? 0}') ?? 0,
      mealTime: json['meal_time'] ?? json['mealTime'],
      schoolName: json['school_name'],
      standardName: json['standard_name'],
      mealSizeName: json['meal_size_name'],
      divisionId: json['division_id'] ?? json['divisionId'],
      divisionName: json['division_name'],
      phoneNumber: json['phone_number']?.toString() ?? json['phoneNumber']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rollNumber': rollNumber,
      'roll_number': rollNumber,
      'schoolId': schoolId,
      'school_id': schoolId,
      'standardId': standardId,
      'standard_id': standardId,
      'mealSizeId': mealSizeId,
      'meal_size_id': mealSizeId,
      'mealTime': mealTime,
      'meal_time': mealTime,
      'school_name': schoolName,
      'standard_name': standardName,
      'meal_size_name': mealSizeName,
      'divisionId': divisionId,
      'division_id': divisionId,
      'division_name': divisionName,
      'phone_number': phoneNumber,
      'phoneNumber': phoneNumber,
    };
  }
}
