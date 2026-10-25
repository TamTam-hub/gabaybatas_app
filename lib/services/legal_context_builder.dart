// ignore_for_file: deprecated_member_use

import 'dart:async';

import '../features/info/data/knowledge_base_service.dart';

/// Picks the Legal Information articles that match a resident's question so
/// the AI can answer from the same content the app shows.
class LegalContextBuilder {
  LegalContextBuilder({KnowledgeBaseService? knowledgeBaseService})
    : _knowledgeBaseService = knowledgeBaseService ?? KnowledgeBaseService();

  final KnowledgeBaseService _knowledgeBaseService;

  /// Articles are loaded once per app session and shared by every chat.
  static Future<List<LegalInformationItem>>? _cache;

  static const int maxArticles = 2;
  static const int _maxContentLength = 1800;

  /// Starts loading the articles in the background (e.g. when the chat opens).
  void preload() {
    unawaited(_articles());
  }

  Future<List<LegalInformationItem>> _articles() {
    return _cache ??= _knowledgeBaseService
        .searchArticles()
        .then((result) => result.items)
        .catchError((Object _) {
          // Retry on the next question instead of caching the failure.
          _cache = null;
          return <LegalInformationItem>[];
        });
  }

  /// Approved app content for [message], or an empty string when nothing
  /// matches or the articles cannot be loaded quickly.
  Future<String> buildContext(String message, {String previousQuestion = ''}) async {
    final List<LegalInformationItem> articles;
    try {
      articles = await _articles().timeout(const Duration(seconds: 4));
    } on TimeoutException {
      return '';
    }
    var picked = selectArticles(message, articles);
    // Follow-up questions ("what if he does not come?") rarely name the topic.
    if (picked.isEmpty && previousQuestion.trim().isNotEmpty) {
      picked = selectArticles(previousQuestion, articles);
    }
    if (picked.isEmpty) return '';

    final buffer = StringBuffer();
    for (final article in picked) {
      buffer.writeln('ARTICLE: ${article.title}');
      if (article.offenseClass.trim().isNotEmpty) {
        buffer.writeln('Class: ${article.offenseClass.trim()}');
      }
      if (article.reportTo.trim().isNotEmpty) {
        buffer.writeln('Report to: ${article.reportTo.trim()}');
      }
      var content = article.displayContent.trim();
      if (content.length > _maxContentLength) {
        content = '${content.substring(0, _maxContentLength).trimRight()}...';
      }
      buffer.writeln(content);
      final references = article.references;
      if (references.isNotEmpty) {
        buffer.writeln('Sources: ${references.join('; ')}');
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  /// Ranks [articles] by how well they match [message]. Pure, so it can be
  /// unit tested without the network.
  static List<LegalInformationItem> selectArticles(
    String message,
    List<LegalInformationItem> articles,
  ) {
    final text = message.toLowerCase();
    final words = _words(text);
    if (words.isEmpty) return const <LegalInformationItem>[];

    final scored = <MapEntry<LegalInformationItem, int>>[];
    for (final article in articles) {
      final title = article.title.toLowerCase();
      var score = 0;

      for (final entry in _topicKeywords.entries) {
        if (entry.key != title) continue;
        for (final keyword in entry.value) {
          if (keyword.contains(' ') ? text.contains(keyword) : words.contains(keyword)) {
            score += 6;
          }
        }
      }

      final titleWords = _words(title);
      final bodyWords = _words(
        '${article.summary} ${article.caseType} ${article.content}'.toLowerCase(),
      );
      for (final word in words) {
        if (titleWords.contains(word)) score += 4;
        if (bodyWords.contains(word)) score += 1;
      }

      if (score >= 6) scored.add(MapEntry(article, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(maxArticles).map((entry) => entry.key).toList();
  }

  static Set<String> _words(String text) => RegExp(r"[a-zñ0-9']+")
      .allMatches(text)
      .map((match) => match.group(0)!)
      .where((word) => word.length >= 3 && !_stopWords.contains(word))
      .toSet();

  static const Set<String> _stopWords = {
    'the', 'and', 'for', 'are', 'was', 'what', 'how', 'can', 'who', 'you',
    'your', 'with', 'this', 'that', 'there', 'they', 'them', 'have', 'has',
    'from', 'not', 'but', 'will', 'should', 'would', 'about', 'when', 'his',
    'her', 'him', 'our', 'does', 'did', 'into', 'any', 'all', 'case', 'cases',
    'barangay', 'complaint', 'file', 'filed', 'filing', 'other', 'person',
    'ang', 'mga', 'nga', 'han', 'hin', 'kay', 'ako', 'ano', 'para', 'akon',
    'naman', 'lang', 'kung', 'may', 'yung', 'siya', 'niya', 'ito', 'iya',
    'ini', 'adto', 'dito', 'diin', 'paano', 'saan', 'pwede', 'puwede',
  };

  /// Everyday words (English, Filipino and Waray) that point to an article,
  /// keyed by the lower-case article title.
  static const Map<String, List<String>> _topicKeywords = {
    'where should i report?': [
      'where', 'report', 'saan', 'diin', 'police', 'pulis', 'office', 'venue',
      'which barangay', 'another barangay', 'ibang barangay', 'iba nga barangay',
      'dole', 'dar', 'dti', 'nbi', '911',
    ],
    'classes of crimes and penalties': [
      'penalty', 'penalties', 'prison', 'jail', 'kulong', 'priso', 'felony',
      'felonies', 'grave', 'fine', 'multa', 'arresto', 'prision', 'years',
    ],
    'the barangay process step by step': [
      'process', 'proseso', 'step', 'steps', 'hearing', 'mediation',
      'conciliation', 'pangkat', 'lupon', 'summons', 'patawag', 'settlement',
      'kasunduan', 'areglo', 'arbitration', 'certification', 'cfa', 'repudiate',
      'repudiation', 'execution', 'comply', 'appear', 'absent', 'sumipot',
      'umabot', 'days', 'adlaw', 'araw', 'how long', 'kp form', 'form',
    ],
    'your rights at the barangay': [
      'rights', 'right', 'karapatan', 'lawyer', 'abogado', 'abugado',
      'language', 'unfair', 'forced', 'prescription', 'prescriptive',
    ],
    'complaints the barangay cannot handle': [
      'cannot', 'not covered', 'covered', 'reject', 'rejected', 'company',
      'corporation', 'government', 'official', 'labor', 'agrarian', 'detained',
      'habeas', 'injunction', 'different city', 'ibang lungsod',
    ],
    'getting free legal help': [
      'pao', 'free', 'libre', 'lawyer', 'abogado', 'abugado', 'attorney',
      'ibp', 'legal aid', 'advice', 'indigency',
    ],
    'public disturbance': [
      'disturbance', 'gulo', 'eskandalo', 'scandal', 'drunk', 'lasing',
      'hubog', 'alarm',
    ],
    'theft': [
      'theft', 'steal', 'stole', 'stolen', 'nakaw', 'ninakaw', 'kawat',
      'kinawat', 'nangawat', 'magnanakaw',
    ],
    'physical injury': [
      'injury', 'injuries', 'hit', 'punch', 'punched', 'suntok', 'sinuntok',
      'bugbog', 'binugbog', 'samad', 'pinalo', 'sinapak', 'fight', 'away',
      'medical', 'sugat',
    ],
    'property damage': [
      'damage', 'damaged', 'broke', 'broken', 'sira', 'sinira', 'guba',
      'ginuba', 'mischief', 'vandal',
    ],
    'family dispute (no violence)': [
      'family', 'pamilya', 'asawa', 'sibling', 'kapatid', 'bugto',
      'inheritance', 'mana', 'relatives', 'kamag-anak', 'domestic',
    ],
    'threat or harassment': [
      'threat', 'threaten', 'threatened', 'banta', 'pinagbantaan', 'hulga',
      'harass', 'harassment', 'vexation', 'coercion', 'takot',
    ],
    'noise complaint': [
      'noise', 'noisy', 'ingay', 'maingay', 'kasaba', 'karaoke', 'videoke',
      'loud', 'music', 'tugtog',
    ],
    'boundary dispute': [
      'boundary', 'land', 'lupa', 'fence', 'bakod', 'lot', 'property line',
      'hangganan', 'utlan',
    ],
    'unpaid debt or money claim': [
      'debt', 'utang', 'owe', 'owes', 'loan', 'pautang', 'bayad', 'pay',
      'paid', 'unpaid', 'money', 'kwarta', 'pera', 'collect', 'singil',
    ],
    'oral defamation (slight)': [
      'defamation', 'slander', 'chismis', 'tsismis', 'insult', 'insulted',
      'paninirang', 'pakaraw', 'ininsulto', 'mura', 'minura', 'libel',
    ],
    'trespassing': [
      'trespass', 'trespassing', 'pumasok', 'sumulod', 'enter', 'entered',
      'squatter', 'intruder',
    ],
    'rental dispute': [
      'rent', 'rental', 'renta', 'upa', 'abang', 'landlord', 'tenant',
      'boarder', 'evict', 'eviction', 'palayas',
    ],
    'swindling or estafa (small amount)': [
      'estafa', 'swindling', 'scam', 'scammed', 'budol', 'niloko', 'gin-ilad',
      'fraud', 'deceived', 'online seller',
    ],
  };
}
