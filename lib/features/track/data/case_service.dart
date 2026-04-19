import '../../../core/network/api_client.dart';

class CaseSummary {
  CaseSummary({
    required this.caseRowId,
    required this.caseId,
    required this.referenceNumber,
    required this.residentName,
    required this.complainedPerson,
    required this.barangay,
    required this.contact,
    required this.caseType,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int caseRowId;
  final int caseId;
  final String referenceNumber;
  final String residentName;
  final String complainedPerson;
  final String barangay;
  final String contact;
  final String caseType;
  final String description;
  final String status;
  final String createdAt;
  final String updatedAt;

  String get caseIdDigits => referenceNumber.replaceAll(RegExp(r'\D'), '');

  factory CaseSummary.fromJson(Map<String, dynamic> json) {
    return CaseSummary(
      caseRowId: int.tryParse((json['case_row_id'] ?? json['case_id'] ?? '').toString()) ?? 0,
      caseId: int.tryParse((json['case_id'] ?? '').toString()) ?? 0,
      referenceNumber: (json['reference_number'] ?? '').toString(),
      residentName: (json['resident_name'] ?? '').toString(),
      complainedPerson: (json['complained_person'] ?? '').toString(),
      barangay: (json['barangay'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      caseType: (json['case_type'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }
}

class CaseListResult {
  CaseListResult({required this.total, required this.cases});

  final int total;
  final List<CaseSummary> cases;
}

class CaseService {
  CaseService({ApiClient? apiClient}) : _apiClient = apiClient ?? const ApiClient();

  final ApiClient _apiClient;

  static const String listPath = '/api/v1/cases_list.php';

  Future<CaseListResult> listCases({
    String? status,
    int limit = 10,
    int offset = 0,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }

    final params = query.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&');
    final response = await _apiClient.get('$listPath?$params', authenticated: true);

    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final list = data['cases'] is List ? data['cases'] as List : <dynamic>[];
    return CaseListResult(
      total: int.tryParse((data['total'] ?? list.length).toString()) ?? list.length,
      cases: list
          .whereType<Map<String, dynamic>>()
          .map(CaseSummary.fromJson)
          .toList(),
    );
  }
}