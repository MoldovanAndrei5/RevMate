class Invoice {
  final String invoiceUuid;
  final String taskUuid;
  final String fileKey;
  final String fileName;
  final String fileType;
  final int fileSize;
  final DateTime uploadedAt;

  Invoice({
    required this.invoiceUuid,
    required this.taskUuid,
    required this.fileKey,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.uploadedAt,
  });

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      invoiceUuid: map['invoice_uuid'] as String,
      taskUuid: map['task_uuid'] as String,
      fileKey: map['file_key'] as String,
      fileName: map['file_name'] as String,
      fileType: map['file_type'] as String,
      fileSize: (map['file_size'] as num).toInt(),
      uploadedAt: DateTime.parse(map['uploaded_at'] as String),
    );
  }
}