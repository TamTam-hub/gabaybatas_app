import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gb_blue_header.dart';
import '../data/knowledge_base_service.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final TextEditingController _searchController = TextEditingController();
  final KnowledgeBaseService _knowledgeBaseService = KnowledgeBaseService();

  Timer? _searchDebounce;
  int _searchGeneration = 0;

  List<LegalInformationItem> _articles = const <LegalInformationItem>[];

  bool _isLoadingArticles = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArticles({String? search}) async {
    final int currentGeneration = ++_searchGeneration;

    setState(() {
      _isLoadingArticles = true;
      _errorMessage = null;
    });

    try {
      final result = await _knowledgeBaseService.searchArticles(search: search);
      if (!mounted || currentGeneration != _searchGeneration) return;
      setState(() {
        _articles = result.items;
      });
    } on ApiException catch (error) {
      if (!mounted || currentGeneration != _searchGeneration) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted || currentGeneration != _searchGeneration) return;
      setState(() {
        _errorMessage = 'Could not load legal information.';
      });
    } finally {
      if (mounted && currentGeneration == _searchGeneration) {
        setState(() {
          _isLoadingArticles = false;
        });
      }
    }
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _loadArticles(search: _searchController.text);
    });
  }

  String _buildFileUrl(String filePath) {
    final trimmedPath = filePath.trim().replaceFirst(RegExp(r'^/+'), '');
    final rootUrl = AppConfig.apiBaseUrl.replaceAll('/api', '');
    final normalizedRoot = rootUrl.endsWith('/')
        ? rootUrl.substring(0, rootUrl.length - 1)
        : rootUrl;
    return '$normalizedRoot/$trimmedPath';
  }

  Future<void> _openDocument(String filePath) async {
    final target = _buildFileUrl(filePath);
    final uri = Uri.tryParse(target);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid file URL.')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open document.')),
      );
    }
  }

  void _openArticle(LegalInformationItem article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LegalInformationDetailPage(
          article: article,
          onViewDocument: article.hasFile
              ? () => _openDocument(article.filePath)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final articles = _articles;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GbBlueHeader(
          title: 'Legal Information',
          subtitle: '${articles.length} articles available',
          bottom: TextField(
            controller: _searchController,
            onChanged: (_) {
              setState(() {});
              _scheduleSearch();
            },
            decoration: InputDecoration(
              hintText: 'Search legal topics...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: const OutlineInputBorder(borderSide: BorderSide.none),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        _loadArticles();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingArticles)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFD93025)),
              textAlign: TextAlign.center,
            ),
          )
        else if (articles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Text(
              'No articles found for your search.',
              style: TextStyle(color: Color(0xFF6A7FA3)),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...articles.map(
            (article) => _InfoArticleCard(
              article: article,
              onTap: () => _openArticle(article),
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _InfoArticleCard extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _InfoArticleCard({
    required this.article,
    required this.onTap,
  });

  final LegalInformationItem article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2F6EFF),
                      Color.lerp(const Color(0xFF2F6EFF), Colors.black, 0.18)!,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2F6EFF).withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(article.iconData, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            article.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF8FA3C7)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(article.preview, style: const TextStyle(color: Color(0xFF6680A5), height: 1.35)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F6EFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _displayCategory(article.category),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalInformationDetailPage extends StatelessWidget {
  const _LegalInformationDetailPage({
    required this.article,
    this.onViewDocument,
  });

  final LegalInformationItem article;
  final VoidCallback? onViewDocument;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GbBlueHeader(
            title: article.title,
            subtitle: _displayCategory(article.category),
            showBack: true,
            onBack: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 14),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 5)),
              ],
            ),
            child: Text(
              article.displayContent,
              style: const TextStyle(color: Color(0xFF415A82), height: 1.45),
            ),
          ),
          if (article.reference.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD4E2FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reference',
                    style: TextStyle(
                      color: Color(0xFF2F6EFF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.reference,
                    style: const TextStyle(color: Color(0xFF415A82), height: 1.35),
                  ),
                ],
              ),
            ),
          ],
          if (onViewDocument != null) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton.icon(
                onPressed: onViewDocument,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('View Document'),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

String _displayCategory(String value) {
  if (value.trim().isEmpty) return 'General';
  return value
      .trim()
      .split(RegExp(r'\s+'))
      .map((part) {
        if (part.isEmpty) return part;
        return part[0].toUpperCase() + part.substring(1).toLowerCase();
      })
      .join(' ');
}