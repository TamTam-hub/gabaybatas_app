// ignore_for_file: deprecated_member_use

import '../../../core/network/api_client.dart';
import 'dart:typed_data';

class CaseTimelineItem {
  const CaseTimelineItem({
    required this.stage,
    required this.status,
    required this.eventType,
    required this.title,
    required this.details,
    required this.eventAt,
  });

  final String stage;
  final String status;
  final String eventType;
  final String title;
  final String details;
  final String eventAt;

  factory CaseTimelineItem.fromJson(Map<String, dynamic> json) {
    return CaseTimelineItem(
      stage: (json['stage'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      eventType: (json['event_type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      details: (json['details'] ?? '').toString(),
      eventAt: (json['event_at'] ?? '').toString(),
    );
  }
}
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
    this.kpStatus = 'filed',
    this.kpStage = 'intake',
    this.kpStageLabel = 'Filed / Review',
    this.kpDisposition = '',
    this.kpDispositionLabel = '',
    this.reviewDecision = '',
    this.reviewNotes = '',
    this.missingItems = '',
    this.residentUpdates = const <String>[],
    this.timeline = const <CaseTimelineItem>[],
    this.nextHearingDate = '',
    this.nextHearingType = '',
    this.nextHearingLocation = '',
    required this.createdAt,
    required this.updatedAt,
    required this.evidence,
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
  final String kpStatus;
  final String kpStage;
  final String kpStageLabel;
  final String kpDisposition;
  final String kpDispositionLabel;
  final String reviewDecision;
  final String reviewNotes;
  final String missingItems;
  final List<String> residentUpdates;
  final List<CaseTimelineItem> timeline;
  final String nextHearingDate;
  final String nextHearingType;
  final String nextHearingLocation;
  final String createdAt;
  final String updatedAt;
  final List<CaseEvidence> evidence;

  String get caseIdDigits => referenceNumber.replaceAll(RegExp(r'\D'), '');

  bool get hasActionRequired =>
      kpStatus == 'additional_info_required';

  bool get isUnderReview => kpStatus == 'under_review';

  bool get isAccepted =>
      kpStatus == 'accepted' || kpStatus.startsWith('mediation_');

  /// The case has reached its legal conclusion at the barangay.
  bool get isConcluded => const {
        'not_eligible',
        'referred',
        'certified_to_court',
        'dismissed',
        'closed',
      }.contains(kpStatus);

  /// Concluded without a barangay settlement (not covered, dismissed, or
  /// certified to file in court).
  bool get isUnsettledOutcome => const {
        'not_eligible',
        'dismissed',
        'certified_to_court',
      }.contains(kpStatus);

  /// A settlement or award has been reached (including its finality,
  /// compliance and execution phases).
  bool get isSettledOutcome => const {
        'mediation_settled',
        'conciliation_settled',
        'arbitration_awarded',
        'settlement_repudiation',
        'settlement_final',
        'compliance_monitoring',
        'execution_pending',
        'execution_completed',
        'closed',
      }.contains(kpStatus);

  /// Progress step for the resident stepper:
  /// 0 Filed, 1 Review, 2 Mediation (hearings), 3 Resolution.
  int get progressStep {
    const hearingStages = {'mediation', 'conciliation', 'arbitration'};
    if (isConcluded || isSettledOutcome) {
      return 3;
    }
    if (hearingStages.contains(kpStage) && kpStatus != 'accepted') {
      return 2;
    }
    if (kpStatus != 'filed') {
      return 1;
    }
    return 0;
  }

  String get kpStatusDisplay {
    switch (kpStatus) {
      case 'filed':
        return 'Filed / Pending Review';
      case 'under_review':
        return 'Under Review';
      case 'additional_info_required':
        return 'Additional Info Required';
      case 'accepted':
        return 'Accepted for KP';
      case 'referred':
        return 'Referred';
      case 'not_eligible':
        return 'Not Eligible for KP';
      case 'mediation_scheduled':
        return 'Mediation Scheduled';
      case 'mediation_ongoing':
        return 'Mediation Ongoing';
      case 'mediation_settled':
        return 'Settled in Mediation';
      case 'mediation_noshow_complainant':
        return 'Complainant Absent (Mediation)';
      case 'pangkat_constitution':
        return 'Pangkat Constitution';
      case 'conciliation_scheduled':
        return 'Conciliation Scheduled';
      case 'conciliation_ongoing':
        return 'Conciliation Ongoing';
      case 'conciliation_settled':
        return 'Settled in Conciliation';
      case 'conciliation_noshow_complainant':
        return 'Complainant Absent (Conciliation)';
      case 'conciliation_noshow_respondent':
        return 'Respondent Absent (Conciliation)';
      case 'arbitration_agreed':
        return 'Arbitration Agreed';
      case 'arbitration_hearing':
        return 'Arbitration Hearing';
      case 'arbitration_awarded':
        return 'Arbitration Awarded';
      case 'settlement_repudiation':
        return 'Repudiation Window (10-Day)';
      case 'settlement_final':
        return 'Settlement Final & Executory';
      case 'compliance_monitoring':
        return 'Compliance Monitoring';
      case 'execution_pending':
        return 'Execution Pending';
      case 'execution_completed':
        return 'Execution Completed';
      case 'certified_to_court':
        return 'Certified to File in Court';
      case 'dismissed':
        return 'Dismissed';
      case 'closed':
        return 'Closed';
      default:
        return kpStatus.isNotEmpty
            ? kpStatus.replaceAll('_', ' ').toUpperCase()
            : status.toUpperCase();
    }
  }

  factory CaseSummary.fromJson(Map<String, dynamic> json) {
    return CaseSummary(
      caseRowId:
          int.tryParse(
            (json['case_row_id'] ?? json['case_id'] ?? '').toString(),
          ) ??
          0,
      caseId: int.tryParse((json['case_id'] ?? '').toString()) ?? 0,
      referenceNumber: (json['reference_number'] ?? '').toString(),
      residentName: (json['resident_name'] ?? '').toString(),
      complainedPerson: (json['complained_person'] ?? '').toString(),
      barangay: (json['barangay'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      caseType: (json['case_type'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      kpStatus: (json['kp_status'] ?? 'filed').toString(),
      kpStage: (json['kp_stage'] ?? 'intake').toString(),
      kpStageLabel: (json['kp_stage_label'] ?? 'Filed / Review').toString(),
      kpDisposition: (json['kp_disposition'] ?? '').toString(),
      kpDispositionLabel: (json['kp_disposition_label'] ?? '').toString(),
      reviewDecision: (json['review_decision'] ?? '').toString(),
      reviewNotes: (json['review_notes'] ?? '').toString(),
      missingItems: (json['missing_items'] ?? '').toString(),
      residentUpdates: (json['resident_updates'] is List
              ? json['resident_updates'] as List
              : const <dynamic>[])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      timeline: (json['timeline'] is List
              ? json['timeline'] as List
              : const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(CaseTimelineItem.fromJson)
          .toList(),
      nextHearingDate: ((json['next_hearing'] is Map)
              ? json['next_hearing']['date'] ?? ''
              : '')
          .toString(),
      nextHearingType: ((json['next_hearing'] is Map)
              ? json['next_hearing']['stage'] ?? ''
              : '')
          .toString(),
      nextHearingLocation: ((json['next_hearing'] is Map)
              ? json['next_hearing']['location'] ?? ''
              : '')
          .toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      evidence:
          (json['evidence'] is List
                  ? json['evidence'] as List
                  : const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(CaseEvidence.fromJson)
              .toList(),
    );
  }
}

class CaseEvidence {
  const CaseEvidence({
    required this.id,
    required this.type,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.url,
  });

  final int id;
  final String type;
  final String name;
  final String mimeType;
  final int size;
  final String url;

  factory CaseEvidence.fromJson(Map<String, dynamic> json) => CaseEvidence(
    id: int.tryParse('${json['id'] ?? 0}') ?? 0,
    type: '${json['type'] ?? ''}',
    name: '${json['name'] ?? 'Evidence'}',
    mimeType: '${json['mime_type'] ?? ''}',
    size: int.tryParse('${json['size'] ?? 0}') ?? 0,
    url: '${json['url'] ?? ''}',
  );
}

class CaseListResult {
  CaseListResult({required this.total, required this.cases});

  final int total;
  final List<CaseSummary> cases;
}

class CaseService {
  CaseService({ApiClient? apiClient})
    : _apiClient = apiClient ?? const ApiClient();

  final ApiClient _apiClient;

  static const String listPath = '/api/v1/cases_list.php';

  Future<Uint8List> loadEvidence(String path) {
    return _apiClient.getBytes(path, authenticated: true);
  }

  Uri evidenceUri(String path) => _apiClient.buildUri(path);

  Future<Map<String, String>> evidenceHeaders() {
    return _apiClient.requestHeaders(authenticated: true);
  }

  Future<CaseListResult> listCases({
    String? status,
    int limit = 10,
    int offset = 0,
  }) async {
    final query = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (status != null && status.isNotEmpty && status != 'all') {
      query['status'] = status;
    }

    final params = query.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    final response = await _apiClient.get(
      '$listPath?$params',
      authenticated: true,
    );

    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final list = data['cases'] is List ? data['cases'] as List : <dynamic>[];
    return CaseListResult(
      total:
          int.tryParse((data['total'] ?? list.length).toString()) ??
          list.length,
      cases: list
          .whereType<Map<String, dynamic>>()
          .map(CaseSummary.fromJson)
          .toList(),
    );
  }

  Future<Map<String, dynamic>> updateCase({
    required int caseId,
    String? additionalInfo,
    String? complainedPerson,
    List<String> evidenceImagePaths = const <String>[],
    String? evidenceVideoPath,
  }) async {
    final response = await _apiClient.postMultipart(
      '/api/v1/cases_update.php',
      fields: <String, String>{
        'case_id': caseId.toString(),
        if (additionalInfo != null && additionalInfo.trim().isNotEmpty)
          'additional_info': additionalInfo.trim(),
        if (complainedPerson != null && complainedPerson.trim().isNotEmpty)
          'complained_person': complainedPerson.trim(),
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

    return response;
  }
}
