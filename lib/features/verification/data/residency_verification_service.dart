import '../../../core/network/api_client.dart';

class ResidencyVerification {
  ResidencyVerification({
    required this.id,
    required this.fullName,
    required this.dateOfBirth,
    required this.completeAddress,
    required this.barangay,
    required this.governmentIdType,
    required this.governmentIdLast4,
    required this.status,
    required this.reviewerNote,
    required this.createdAt,
  });

  final int id;
  final String fullName;
  final String dateOfBirth;
  final String completeAddress;
  final String barangay;
  final String governmentIdType;
  final String governmentIdLast4;
  final String status;
  final String reviewerNote;
  final String createdAt;

  factory ResidencyVerification.fromJson(Map<String, dynamic> json) {
    return ResidencyVerification(
      id: int.tryParse((json['verification_id'] ?? '').toString()) ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      dateOfBirth: (json['date_of_birth'] ?? '').toString(),
      completeAddress: (json['complete_address'] ?? '').toString(),
      barangay: (json['barangay'] ?? '').toString(),
      governmentIdType: (json['government_id_type'] ?? '').toString(),
      governmentIdLast4: (json['government_id_last4'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      reviewerNote: (json['reviewer_note'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class ResidencyVerificationService {
  ResidencyVerificationService({ApiClient? apiClient})
      : _apiClient = apiClient ?? const ApiClient();

  final ApiClient _apiClient;

  static const String path = '/api/v1/residency_verification.php';

  Future<ResidencyVerification?> fetchLatest() async {
    final response = await _apiClient.get(path, authenticated: true);
    final source = response['data'];
    if (source is! Map<String, dynamic>) return null;
    return ResidencyVerification.fromJson(source);
  }

  Future<ResidencyVerification> submit({
    required String fullName,
    required String dateOfBirth,
    required String completeAddress,
    required String barangay,
    required String governmentIdType,
    required String governmentIdLast4,
    required String idDocumentPath,
    required String proofOfResidencePath,
  }) async {
    final response = await _apiClient.postMultipart(
      path,
      authenticated: true,
      fields: <String, String>{
        'full_name': fullName,
        'date_of_birth': dateOfBirth,
        'complete_address': completeAddress,
        'barangay': barangay,
        'government_id_type': governmentIdType,
        'government_id_last4': governmentIdLast4,
      },
      filePaths: <String, String>{
        'id_document': idDocumentPath,
        'proof_of_residence': proofOfResidencePath,
      },
    );

    final source = response['data'];
    if (source is! Map<String, dynamic>) {
      throw StateError('Verification submission returned no data.');
    }
    return ResidencyVerification.fromJson(source);
  }
}