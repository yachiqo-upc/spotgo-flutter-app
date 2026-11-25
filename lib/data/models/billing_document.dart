import 'billing_types.dart';

/// `DocumentView` (contract §3.1) — a locally registered receipt or invoice.
class BillingDocument {
  const BillingDocument({
    required this.documentId,
    required this.paymentId,
    required this.documentType,
    required this.documentNumber,
    required this.series,
    required this.legalName,
    required this.taxData,
    required this.issuedAt,
    required this.status,
  });

  factory BillingDocument.fromJson(Map<String, dynamic> row) =>
      BillingDocument(
        documentId: row['documentId'] as String,
        paymentId: row['paymentId'] as String? ?? '',
        documentType: BillingDocumentType.parse(row['documentType']),
        documentNumber: row['documentNumber'] as String? ?? '',
        series: row['series'] as String? ?? '',
        legalName: row['legalName'] as String? ?? '',
        taxData: row['taxData'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(row['taxData'] as Map)
            : const <String, dynamic>{},
        issuedAt: DateTime.parse(row['issuedAt'] as String),
        status: BillingDocumentStatus.parse(row['status']),
      );

  final String documentId;
  final String paymentId;
  final BillingDocumentType documentType;
  final String documentNumber;
  final String series;
  final String legalName;

  /// Free-form `snake_case` object: `{"document_type", "document_number"}`.
  final Map<String, dynamic> taxData;
  final DateTime issuedAt;
  final BillingDocumentStatus status;

  String get reference => '$series-$documentNumber';

  String get taxNumber =>
      '${taxData['document_type'] ?? ''} ${taxData['document_number'] ?? ''}'
          .trim();
}
