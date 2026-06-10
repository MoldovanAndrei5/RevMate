class Car {
  final String? carUuid;
  final int? userId;
  final String name;
  final String make;
  final String model;
  final int year;
  final String vin;
  final int mileage;
  final String licensePlate;
  final String? imageKey;
  final String? imageUrl;
  final int isSynced;
  final int isDeleted;

  Car({
    this.carUuid,
    this.userId,
    required this.name,
    required this.make,
    required this.model,
    required this.year,
    required this.vin,
    required this.mileage,
    required this.licensePlate,
    this.imageKey,
    this.imageUrl,
    this.isSynced = 0,
    this.isDeleted = 0,
  });

  Car copyWith({
    String? carUuid,
    int? userId,
    String? name,
    String? make,
    String? model,
    int? year,
    String? vin,
    int? mileage,
    String? licensePlate,
    String? imageKey,
    String? imageUrl,
    int? isSynced,
    int? isDeleted,
  }) {
    return Car(
      carUuid: carUuid ?? this.carUuid,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      vin: vin ?? this.vin,
      mileage: mileage ?? this.mileage,
      licensePlate: licensePlate ?? this.licensePlate,
      imageKey: imageKey ?? this.imageKey,
      imageUrl: imageUrl ?? this.imageUrl,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (carUuid != null) "car_uuid": carUuid,
      if (userId != null) "user_id": userId,
      "name": name,
      "make": make,
      "model": model,
      "year": year,
      "vin": vin,
      "mileage": mileage,
      "license_plate": licensePlate,
      "image_key": imageKey,
      "is_synced": isSynced,
      "is_deleted": isDeleted,
    };
  }

  factory Car.fromMap(Map<String, Object?> map) {
    return Car(
      carUuid: map["car_uuid"] != null ? map["car_uuid"] as String : "0",
      userId: map["user_id"] != null ? (map["user_id"] as num).toInt() : 0,
      name: map["name"] as String,
      make: map["make"] as String,
      model: map["model"] as String,
      year: (map["year"] as num).toInt(),
      vin: map["vin"] as String,
      mileage: (map["mileage"] as num).toInt(),
      licensePlate: map["license_plate"] as String,
      imageKey: map["image_key"] as String?,
      imageUrl: map["image_url"] as String?,
      isSynced: map["is_synced"] != null ? (map["is_synced"] as num).toInt() : 1,
      isDeleted: map["is_deleted"] != null ? (map["is_deleted"] as num).toInt() : 0,
    );
  }
}