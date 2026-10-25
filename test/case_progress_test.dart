import 'package:flutter_test/flutter_test.dart';
import 'package:gabaybatas_app/features/track/data/case_service.dart';

/// Builds a case the way the website API returns it.
CaseSummary caseWith(String kpStatus, String kpStage, {String disposition = ''}) {
  return CaseSummary.fromJson({
    'case_row_id': 1,
    'reference_number': 'C-0001',
    'kp_status': kpStatus,
    'kp_stage': kpStage,
    'kp_disposition': disposition,
    'kp_disposition_label': disposition.isEmpty ? '' : 'Outcome label',
    'evidence': <dynamic>[],
  });
}

void main() {
  group('Resident progress stepper (0 Filed, 1 Review, 2 Mediation, 3 Resolution)', () {
    final expected = <List<Object>>[
      ['filed', 'intake', 0],
      ['under_review', 'intake', 1],
      ['additional_info_required', 'intake', 1],
      ['accepted', 'intake', 1],
      ['mediation_scheduled', 'mediation', 2],
      ['mediation_noshow_complainant', 'mediation', 2],
      ['pangkat_constitution', 'conciliation', 2],
      ['conciliation_ongoing', 'conciliation', 2],
      ['conciliation_noshow_respondent', 'conciliation', 2],
      ['arbitration_hearing', 'arbitration', 2],
      ['mediation_settled', 'mediation', 3],
      ['arbitration_awarded', 'arbitration', 3],
      ['settlement_repudiation', 'settlement', 3],
      ['settlement_final', 'settlement', 3],
      ['compliance_monitoring', 'compliance', 3],
      ['execution_pending', 'execution', 3],
      ['execution_completed', 'execution', 3],
      ['certified_to_court', 'disposition', 3],
      ['dismissed', 'disposition', 3],
      ['closed', 'disposition', 3],
      ['not_eligible', 'intake', 3],
    ];
    for (final row in expected) {
      test('${row[0]} -> step ${row[2]}', () {
        expect(caseWith(row[0] as String, row[1] as String).progressStep, row[2]);
      });
    }
  });

  test('outcome groups used for badge colours', () {
    expect(caseWith('certified_to_court', 'disposition').isUnsettledOutcome, isTrue);
    expect(caseWith('dismissed', 'disposition').isUnsettledOutcome, isTrue);
    expect(caseWith('closed', 'disposition').isSettledOutcome, isTrue);
    expect(caseWith('conciliation_settled', 'conciliation').isSettledOutcome, isTrue);
    expect(caseWith('mediation_ongoing', 'mediation').isSettledOutcome, isFalse);
  });

  test('new statuses have readable labels and disposition is parsed', () {
    expect(caseWith('conciliation_noshow_respondent', 'conciliation').kpStatusDisplay,
        'Respondent Absent (Conciliation)');
    final concluded = caseWith('certified_to_court', 'disposition', disposition: 'cfa_conciliation_failed');
    expect(concluded.kpDisposition, 'cfa_conciliation_failed');
    expect(concluded.kpDispositionLabel, isNotEmpty);
  });
}
