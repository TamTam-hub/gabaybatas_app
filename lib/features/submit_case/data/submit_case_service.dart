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
    required String complainantAddress,
    required String complainantLocation,
    required String complainantAge,
    required String complainedPerson,
    required String respondentAddress,
    required String respondentLocation,
    required String barangay,
    required String contact,
    required String caseType,
    required String description,
    List<String> evidenceImagePaths = const <String>[],
    String? evidenceVideoPath,
  }) async {
    final response = await _apiClient.postMultipart(
      submitPath,
      fields: <String, String>{
        'name': name,
        'complainant_address': complainantAddress,
        'complainant_location': complainantLocation,
        'complainant_age': complainantAge,
        'complained_person': complainedPerson,
        'respondent_address': respondentAddress,
        'respondent_location': respondentLocation,
        'barangay': barangay,
        'contact': contact,
        'case_type': caseType,
        'description': description,
      },
      filePaths: <String, String>{
        if (evidenceVideoPath != null) 'evidence_video': evidenceVideoPath,
      },
      fileLists: <String, List<String>>{
        if (evidenceImagePaths.isNotEmpty)
          'evidence_images[]': evidenceImagePaths,
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
      'case_id':
          caseData['case_id'] ??
          caseData['reference_number'] ??
          caseData['id'] ??
          '',
      'reference_number':
          caseData['case_id'] ??
          caseData['reference_number'] ??
          caseData['id'] ??
          '',
      'status': caseData['status'] ?? '',
      'created_at': caseData['created_at'] ?? '',
    };

    return SubmitCaseResult.fromJson(normalized);
  }
}
