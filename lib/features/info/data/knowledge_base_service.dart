import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';

class LegalInformationItem {
  LegalInformationItem({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.filePath,
    required this.reference,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String content;
  final String category;
  final String filePath;
  final String reference;
  final String createdAt;

  bool get hasFile => filePath.trim().isNotEmpty;

  String get preview {
    final normalized = displayContent.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '';

    final sentenceEnd = normalized.indexOf('.');
    final rawPreview = sentenceEnd > 0
        ? normalized.substring(0, sentenceEnd + 1)
        : normalized;
    if (rawPreview.length <= 120) return rawPreview;
    return '${rawPreview.substring(0, 117).trimRight()}...';
  }

  String get displayContent => _LegalInformationContentFormatter.stripIntro(content);

  IconData get iconData => _LegalInformationIconMapper.fromTitle(title, category);

  factory LegalInformationItem.fromJson(Map<String, dynamic> json) {
    return LegalInformationItem(
      id: int.tryParse((json['id'] ?? '').toString()) ?? 0,
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      filePath: (json['file_path'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
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

      final haystack = '${item.title} ${item.content} ${item.category}'.toLowerCase();
      return haystack.contains(normalizedSearch);
    }).toList();

    return LegalInformationResult(total: filtered.length, items: filtered);
  }
}

class _LegalInformationIconMapper {
  static IconData fromTitle(String title, String category) {
    switch (title.toLowerCase()) {
      case 'public disturbance':
        return Icons.volume_up_rounded;
      case 'theft':
        return Icons.lock_outline_rounded;
      case 'physical injury':
        return Icons.medical_services_outlined;
      case 'property damage':
        return Icons.home_repair_service_outlined;
      case 'domestic dispute':
        return Icons.family_restroom_outlined;
      case 'threat or harassment':
        return Icons.warning_amber_rounded;
      case 'noise complaint':
        return Icons.volume_off_rounded;
      case 'boundary dispute':
        return Icons.fence_rounded;
    }

    switch (category.toLowerCase()) {
      case 'civil':
        return Icons.balance_outlined;
      case 'family':
        return Icons.family_restroom_outlined;
      case 'labor':
        return Icons.work_outline_rounded;
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
