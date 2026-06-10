class CarTransferIncoming {
  final String transferUuid;
  final String senderEmail;
  final String senderFirstName;
  final String senderLastName;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String carName;
  final String carMake;
  final String carModel;
  final int carYear;

  CarTransferIncoming({
    required this.transferUuid,
    required this.senderEmail,
    required this.senderFirstName,
    required this.senderLastName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.carName,
    required this.carMake,
    required this.carModel,
    required this.carYear,
  });

  factory CarTransferIncoming.fromMap(Map<String, dynamic> map) {
    return CarTransferIncoming(
      transferUuid: map["transfer_uuid"] as String,
      senderEmail: map["sender_email"] as String,
      senderFirstName: map["sender_first_name"] as String,
      senderLastName: map["sender_last_name"] as String,
      status: map["status"] as String,
      createdAt: DateTime.parse(map["created_at"] as String),
      expiresAt: DateTime.parse(map["expires_at"] as String),
      carName: map["car_name"] as String,
      carMake: map["car_make"] as String,
      carModel: map["car_model"] as String,
      carYear: (map["car_year"] as num).toInt(),
    );
  }
}

class CarTransferOutgoing {
  final String transferUuid;
  final String carUuid;
  final String receiverEmail;
  final String receiverFirstName;
  final String receiverLastName;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String carName;
  final String carMake;
  final String carModel;
  final int carYear;

  CarTransferOutgoing({
    required this.transferUuid,
    required this.carUuid,
    required this.receiverEmail,
    required this.receiverFirstName,
    required this.receiverLastName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.carName,
    required this.carMake,
    required this.carModel,
    required this.carYear,
  });

  factory CarTransferOutgoing.fromMap(Map<String, dynamic> map) {
    return CarTransferOutgoing(
      transferUuid: map["transfer_uuid"] as String,
      carUuid: map["car_uuid"] as String,
      receiverEmail: map["receiver_email"] as String,
      receiverFirstName: map["receiver_first_name"] as String,
      receiverLastName: map["receiver_last_name"] as String,
      status: map["status"] as String,
      createdAt: DateTime.parse(map["created_at"] as String),
      expiresAt: DateTime.parse(map["expires_at"] as String),
      carName: map["car_name"] as String,
      carMake: map["car_make"] as String,
      carModel: map["car_model"] as String,
      carYear: (map["car_year"] as num).toInt(),
    );
  }
}