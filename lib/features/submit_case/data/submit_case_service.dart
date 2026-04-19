import '../../../core/network/api_client.dart';

class SubmitCaseResult {
  SubmitCaseResult({
    required this.caseId,
    required this.referenceNumber,
    required this.status,
    required this.createdAt,
  });

  final int caseId;
  final String referenceNumber;
  final String status;
  final String createdAt;

  factory SubmitCaseResult.fromJson(Map<String, dynamic> json) {
    return SubmitCaseResult(
      caseId: int.tryParse((json['case_id'] ?? '').toString()) ?? 0,
      referenceNumber: (json['reference_number'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class SubmitCaseService {
  SubmitCaseService({ApiClient? apiClient})
    : _apiClient = apiClient ?? const ApiClient();

  final ApiClient _apiClient;

  static const String submitPath = '/api/v1/cases_submit.php';

  Future<SubmitCaseResult> submitCase({
    required String name,
    required String complainedPerson,
    required String barangay,
    required String contact,
    required String caseType,
    required String description,
  }) async {
    final response = await _apiClient.post(
      submitPath,
      body: <String, dynamic>{
        'name': name,
        'complained_person': complainedPerson,
        'barangay': barangay,
        'contact': contact,
        'case_type': caseType,
        'description': description,
      },
      authenticated: true,
    );

    final payload = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;

    final caseData = payload['case'] is Map<String, dynamic>
        ? payload['case'] as Map<String, dynamic>
        : payload;

    final normalized = <String, dynamic>{
      'case_id': caseData['case_id'] ?? caseData['reference_number'] ?? caseData['id'] ?? '',
      'reference_number': caseData['case_id'] ?? caseData['reference_number'] ?? caseData['id'] ?? '',
      'status': caseData['status'] ?? '',
      'created_at': caseData['created_at'] ?? '',
    };

    return SubmitCaseResult.fromJson(normalized);
  }
}
