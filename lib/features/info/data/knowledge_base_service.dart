import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ignore_for_file: deprecated_member_use

import '../../../core/network/api_client.dart';

/// One block of an article section: a paragraph, a bullet or a numbered step.
class LegalContentLine {
  const LegalContentLine.paragraph(this.text) : kind = 'paragraph', number = 0;
  const LegalContentLine.bullet(this.text) : kind = 'bullet', number = 0;
  const LegalContentLine.step(this.text, this.number) : kind = 'step';

  final String kind;
  final String text;
  final int number;
}

/// A "## Heading" section of an article.
class LegalSection {
  LegalSection(this.title, this.lines);

  final String title;
  final List<LegalContentLine> lines;
}

class LegalInformationItem {
  LegalInformationItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    required this.offenseClass,
    required this.reportTo,
    required this.caseType,
    required this.filePath,
    required this.reference,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String summary;
  final String content;
  final String category;
  final String offenseClass;
  final String reportTo;
  final String caseType;
  final String filePath;
  final String reference;
  final String createdAt;

  bool get hasFile => filePath.trim().isNotEmpty;

  bool get isGuide => category.trim().toLowerCase() == 'guide';

  /// Report-to text mentions the barangay (used for the green highlight).
  bool get startsAtBarangay => reportTo.toLowerCase().contains('barangay');

  String get preview {
    if (summary.trim().isNotEmpty) return summary.trim();
    final normalized = displayContent
        .replaceAll(RegExp(r'^##.*$', multiLine: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return '';
    final sentenceEnd = normalized.indexOf('.');
    final rawPreview = sentenceEnd > 0
        ? normalized.substring(0, sentenceEnd + 1)
        : normalized;
    if (rawPreview.length <= 120) return rawPreview;
    return '${rawPreview.substring(0, 117).trimRight()}...';
  }

  String get displayContent =>
      _LegalInformationContentFormatter.stripIntro(content);

  /// Sources, one per line.
  List<String> get references => reference
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  /// Article body split into "## Heading" sections. Articles without
  /// headings become a single untitled section.
  List<LegalSection> get sections {
    final result = <LegalSection>[];
    String? title;
    var lines = <LegalContentLine>[];

    void flush() {
      if (title != null || lines.isNotEmpty) {
        result.add(LegalSection(title ?? '', lines));
      }
    }

    for (final raw in displayContent.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('## ')) {
        flush();
        title = line.substring(3).trim();
        lines = <LegalContentLine>[];
        continue;
      }
      final step = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(line);
      if (line.startsWith('- ')) {
        lines.add(LegalContentLine.bullet(line.substring(2).trim()));
      } else if (step != null) {
        lines.add(
          LegalContentLine.step(step.group(2)!, int.parse(step.group(1)!)),
        );
      } else {
        lines.add(LegalContentLine.paragraph(line));
      }
    }
    flush();
    return result;
  }

  IconData get iconData =>
      _LegalInformationIconMapper.fromTitle(title, category);

  factory LegalInformationItem.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] ?? '').toString();
    return LegalInformationItem(
      id: int.tryParse(text('id')) ?? 0,
      title: text('title'),
      summary: text('summary'),
      content: text('content'),
      category: text('category'),
      offenseClass: text('offense_class'),
      reportTo: text('report_to'),
      caseType: text('case_type'),
      filePath: text('file_path'),
      reference: text('reference'),
      createdAt: text('created_at'),
    );
  }
}

class LegalInformationResult {
  LegalInformationResult({required this.total, required this.items});

  final int total;
  final List<LegalInformationItem> items;
}

class KnowledgeBaseService {
  KnowledgeBaseService({ApiClient? apiClient})
    : _apiClient = apiClient ?? const ApiClient();

  final ApiClient _apiClient;

  static const String path = '/api/get_legal_info.php';

  Future<LegalInformationResult> searchArticles({
    String? search,
    String? category,
  }) async {
    final response = await _apiClient.get(path);

    final dynamic listSource;
    if (response['data'] is List) {
      listSource = response['data'];
    } else if (response['items'] is List) {
      listSource = response['items'];
    } else {
      listSource = <dynamic>[];
    }

    final items = (listSource as List)
        .whereType<Map<String, dynamic>>()
        .map(LegalInformationItem.fromJson)
        .toList();

    final normalizedSearch = (search ?? '').trim().toLowerCase();
    final normalizedCategory = (category ?? '').trim().toLowerCase();

    final filtered = items.where((item) {
      if (normalizedCategory.isNotEmpty &&
          item.category.toLowerCase() != normalizedCategory) {
        return false;
      }

      if (normalizedSearch.isEmpty) {
        return true;
      }

      final haystack =
          '${item.title} ${item.summary} ${item.content} ${item.category} ${item.reference}'
              .toLowerCase();
      return haystack.contains(normalizedSearch);
    }).toList();

    return LegalInformationResult(total: filtered.length, items: filtered);
  }
}

/// Articles the resident saved, stored on the device by title.
class LegalBookmarkStore {
  static const String _key = 'legal_info_bookmarks';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  Future<Set<String>> toggle(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = (prefs.getStringList(_key) ?? const <String>[]).toSet();
    if (!saved.remove(title)) {
      saved.add(title);
    }
    await prefs.setStringList(_key, saved.toList());
    return saved;
  }
}

class _LegalInformationIconMapper {
  static IconData fromTitle(String title, String category) {
    switch (title.toLowerCase()) {
      case 'where should i report?':
        return Icons.alt_route_rounded;
      case 'classes of crimes and penalties':
        return Icons.stacked_bar_chart_rounded;
      case 'the barangay process step by step':
        return Icons.account_tree_outlined;
      case 'your rights at the barangay':
        return Icons.verified_user_outlined;
      case 'complaints the barangay cannot handle':
        return Icons.block_rounded;
      case 'getting free legal help':
        return Icons.support_agent_rounded;
      case 'public disturbance':
        return Icons.campaign_outlined;
      case 'theft':
        return Icons.lock_outline_rounded;
      case 'physical injury':
        return Icons.medical_services_outlined;
      case 'property damage':
        return Icons.home_repair_service_outlined;
      case 'family dispute (no violence)':
      case 'domestic dispute':
        return Icons.family_restroom_outlined;
      case 'threat or harassment':
        return Icons.warning_amber_rounded;
      case 'noise complaint':
        return Icons.volume_up_rounded;
      case 'boundary dispute':
        return Icons.fence_rounded;
      case 'unpaid debt or money claim':
        return Icons.payments_outlined;
      case 'oral defamation (slight)':
        return Icons.record_voice_over_outlined;
      case 'trespassing':
        return Icons.door_front_door_outlined;
      case 'rental dispute':
        return Icons.house_outlined;
      case 'swindling or estafa (small amount)':
        return Icons.money_off_rounded;
      case 'other dispute':
        return Icons.forum_outlined;
    }

    switch (category.toLowerCase()) {
      case 'guide':
        return Icons.menu_book_rounded;
      case 'civil':
        return Icons.balance_outlined;
      case 'family':
        return Icons.family_restroom_outlined;
      case 'property':
        return Icons.home_work_outlined;
      case 'criminal':
        return Icons.gavel_rounded;
      default:
        return Icons.menu_book_outlined;
    }
  }
}

class _LegalInformationContentFormatter {
  static String stripIntro(String content) {
    final normalized = content.trimLeft();
    final introPattern = RegExp(r'^What it is:\s*\n?', caseSensitive: false);
    return normalized.replaceFirst(introPattern, '');
  }
}
