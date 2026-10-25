import 'package:flutter_test/flutter_test.dart';
import 'package:gabaybatas_app/features/info/data/knowledge_base_service.dart';
import 'package:gabaybatas_app/services/legal_context_builder.dart';

LegalInformationItem _article(String title, {String content = '', String caseType = ''}) {
  return LegalInformationItem(
    id: 0,
    title: title,
    summary: '',
    content: content,
    category: caseType.isEmpty ? 'Guide' : 'Civil',
    offenseClass: '',
    reportTo: '',
    caseType: caseType,
    filePath: '',
    reference: '',
    createdAt: '',
  );
}

void main() {
  final articles = [
    _article('Where Should I Report?', content: 'Start with the barangay. Which barangay?'),
    _article('The Barangay Process Step by Step', content: 'Mediation lasts up to 15 days.'),
    _article('Getting Free Legal Help', content: 'Public Attorney\'s Office.'),
    _article('Unpaid Debt or Money Claim', caseType: 'Unpaid Debt or Money Claim'),
    _article('Noise Complaint', caseType: 'Noise Complaint'),
    _article('Theft', caseType: 'Theft'),
  ];

  List<String> titles(String message) => LegalContextBuilder.selectArticles(message, articles)
      .map((a) => a.title)
      .toList();

  test('matches everyday English, Filipino and Waray words', () {
    expect(titles('My neighbor will not pay his utang'), contains('Unpaid Debt or Money Claim'));
    expect(titles('Maingay ang karaoke ng kapitbahay'), contains('Noise Complaint'));
    expect(titles('Kinawat an akon cellphone'), contains('Theft'));
    expect(titles('Paano kumuha ng libreng abogado sa PAO?'), contains('Getting Free Legal Help'));
  });

  test('matches process and venue questions', () {
    expect(titles('How long is the mediation hearing?').first, 'The Barangay Process Step by Step');
    expect(titles('He lives in another barangay, where do I report?'), contains('Where Should I Report?'));
  });

  test('returns at most two articles and nothing for small talk', () {
    expect(titles('utang ingay kawat abogado').length, lessThanOrEqualTo(LegalContextBuilder.maxArticles));
    expect(titles('Hello, thank you!'), isEmpty);
  });
}
