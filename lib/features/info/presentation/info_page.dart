// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/main_shell.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gb_blue_header.dart';
import '../../submit_case/presentation/submit_case_page.dart';
import '../data/knowledge_base_service.dart';
import 'report_guide_page.dart';

const _blue = Color(0xFF2F6EFF);
const _green = Color(0xFF168548);
const _orange = Color(0xFFB06B00);
const _muted = Color(0xFF6680A5);
const _body = Color(0xFF415A82);

/// Category filters shown as chips; "saved" shows bookmarked articles.
const List<String> _filters = <String>['all', 'criminal', 'civil', 'family', 'saved'];

class InfoPage extends StatefulWidget {
  const InfoPage({super.key, this.knowledgeBaseService});

  /// Optional data source (defaults to the website API).
  final KnowledgeBaseService? knowledgeBaseService;

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final TextEditingController _searchController = TextEditingController();
  late final KnowledgeBaseService _knowledgeBaseService =
      widget.knowledgeBaseService ?? KnowledgeBaseService();
  final LegalBookmarkStore _bookmarkStore = LegalBookmarkStore();

  Timer? _searchDebounce;
  int _searchGeneration = 0;

  List<LegalInformationItem> _articles = const <LegalInformationItem>[];
  List<LegalInformationItem> _allArticles = const <LegalInformationItem>[];
  Set<String> _bookmarks = <String>{};
  String _filter = 'all';

  bool _isLoadingArticles = false;
  String? _errorMessage;

  bool get _isSearching => _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadArticles();
    _loadBookmarks();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    try {
      final saved = await _bookmarkStore.load();
      if (mounted) setState(() => _bookmarks = saved);
    } catch (_) {
      // Bookmarks are optional; keep the page usable without them.
    }
  }

  Future<bool> _toggleBookmark(String title) async {
    final saved = await _bookmarkStore.toggle(title);
    if (mounted) setState(() => _bookmarks = saved);
    return saved.contains(title);
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
        if ((search ?? '').trim().isEmpty) {
          _allArticles = result.items;
        }
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
    final uri = Uri.tryParse(_buildFileUrl(filePath));
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid file URL.')));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open document.')));
    }
  }

  void _openArticle(LegalInformationItem article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LegalInformationDetailPage(
          article: article,
          isSaved: _bookmarks.contains(article.title),
          onToggleSaved: () => _toggleBookmark(article.title),
          onViewDocument: article.hasFile
              ? () => _openDocument(article.filePath)
              : null,
        ),
      ),
    );
  }

  void _openGuide() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ReportGuidePage()));
  }

  void _openSources() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SourcesPage(articles: _allArticles),
      ),
    );
  }

  List<LegalInformationItem> get _guides =>
      _allArticles.where((a) => a.isGuide).toList();

  List<LegalInformationItem> get _filteredTopics {
    final topics = _articles.where((a) => !a.isGuide);
    switch (_filter) {
      case 'all':
        return topics.toList();
      case 'saved':
        return _articles.where((a) => _bookmarks.contains(a.title)).toList();
      default:
        return topics
            .where((a) => a.category.toLowerCase() == _filter)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GbBlueHeader(
          title: 'Legal Information',
          subtitle: 'Know your rights · Find the right office',
          bottom: TextField(
            controller: _searchController,
            onChanged: (_) {
              setState(() {});
              _scheduleSearch();
            },
            decoration: InputDecoration(
              hintText: 'Search a topic, law or article...',
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
        const SizedBox(height: 14),
        if (_isLoadingArticles && _allArticles.isEmpty)
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
        else if (_isSearching)
          ..._buildSearchResults()
        else
          ..._buildHome(),
        const SizedBox(height: 16),
      ],
    );
  }

  List<Widget> _buildSearchResults() {
    if (_articles.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Text(
            'No articles found for your search.',
            style: TextStyle(color: Color(0xFF6A7FA3)),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    return [
      _SectionHeading(
        title: '${_articles.length} result${_articles.length == 1 ? '' : 's'}',
      ),
      ..._articles.map(
        (article) => _InfoArticleCard(
          article: article,
          isSaved: _bookmarks.contains(article.title),
          onTap: () => _openArticle(article),
        ),
      ),
    ];
  }

  List<Widget> _buildHome() {
    final topics = _filteredTopics;
    return [
      _ReportGuideBanner(onTap: _openGuide),
      if (_guides.isNotEmpty) ...[
        const _SectionHeading(
          title: 'Guides',
          subtitle: 'Learn how the barangay justice system works',
        ),
        SizedBox(
          height: 128,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _guides.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _GuideTile(
              article: _guides[i],
              onTap: () => _openArticle(_guides[i]),
            ),
          ),
        ),
      ],
      const _SectionHeading(
        title: 'Case Types',
        subtitle: 'What each complaint means and where to bring it',
      ),
      SizedBox(
        height: 42,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final key = _filters[i];
            final label = key == 'saved'
                ? 'Saved (${_bookmarks.length})'
                : key[0].toUpperCase() + key.substring(1);
            return ChoiceChip(
              label: Text(label),
              avatar: key == 'saved'
                  ? Icon(
                      Icons.bookmark_rounded,
                      size: 16,
                      color: _filter == key ? Colors.white : _blue,
                    )
                  : null,
              selected: _filter == key,
              showCheckmark: false,
              selectedColor: _blue,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: _filter == key ? Colors.white : const Color(0xFF1F49D8),
                fontWeight: FontWeight.w600,
              ),
              side: const BorderSide(color: Color(0xFFD4E2FF)),
              onSelected: (_) => setState(() => _filter = key),
            );
          },
        ),
      ),
      const SizedBox(height: 6),
      if (topics.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Text(
            _filter == 'saved'
                ? 'No saved articles yet. Tap "Save" on an article to keep it here.'
                : 'No articles in this category.',
            style: const TextStyle(color: Color(0xFF6A7FA3)),
            textAlign: TextAlign.center,
          ),
        )
      else
        ...topics.map(
          (article) => _InfoArticleCard(
            article: article,
            isSaved: _bookmarks.contains(article.title),
            onTap: () => _openArticle(article),
          ),
        ),
      const SizedBox(height: 10),
      _DisclaimerCard(onSourcesTap: _openSources),
    ];
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(color: _muted, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _ReportGuideBanner extends StatelessWidget {
  const _ReportGuideBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF168548), Color(0xFF0F6B3A)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.alt_route_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where should I report?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Answer a few quick questions to find the right office: barangay, police, VAW Desk and more.',
                        style: TextStyle(color: Color(0xFFDDF5E6), height: 1.35),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.article, required this.onTap});

  final LegalInformationItem article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD9E4F7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF5FF),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(article.iconData, color: _blue, size: 20),
                ),
                const Spacer(),
                Text(
                  article.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoArticleCard extends StatelessWidget {
  const _InfoArticleCard({
    required this.article,
    required this.isSaved,
    required this.onTap,
  });

  final LegalInformationItem article;
  final bool isSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reportColor = article.startsAtBarangay ? _green : _orange;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _blue,
                        Color.lerp(_blue, Colors.black, 0.18)!,
                      ],
                    ),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                          if (isSaved)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.bookmark_rounded, color: _blue, size: 18),
                            ),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF8FA3C7)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.preview,
                        style: const TextStyle(color: _muted, height: 1.35),
                      ),
                      if (article.reportTo.trim().isNotEmpty && !article.isGuide) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.place_outlined, size: 15, color: reportColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                article.reportTo,
                                style: TextStyle(
                                  color: reportColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      _CategoryBadge(category: article.category),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _displayCategory(category),
        style: const TextStyle(
          color: Color(0xFF1F49D8),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({required this.onSourcesTap});

  final VoidCallback onSourcesTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0E2B6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _orange, size: 18),
              SizedBox(width: 6),
              Text('About this information', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'GabayBatas gives general legal information based on Philippine laws and the Katarungang Pambarangay handbooks. It is not legal advice. For advice on your situation, visit the Public Attorney\'s Office (PAO) or a lawyer.',
            style: TextStyle(color: _body, height: 1.4, fontSize: 13),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onSourcesTap,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Sources used'),
          ),
        ],
      ),
    );
  }
}

class _LegalInformationDetailPage extends StatefulWidget {
  const _LegalInformationDetailPage({
    required this.article,
    required this.isSaved,
    required this.onToggleSaved,
    this.onViewDocument,
  });

  final LegalInformationItem article;
  final bool isSaved;
  final Future<bool> Function() onToggleSaved;
  final VoidCallback? onViewDocument;

  @override
  State<_LegalInformationDetailPage> createState() =>
      _LegalInformationDetailPageState();
}

class _LegalInformationDetailPageState
    extends State<_LegalInformationDetailPage> {
  late bool _saved = widget.isSaved;

  Future<void> _toggleSaved() async {
    final saved = await widget.onToggleSaved();
    if (!mounted) return;
    setState(() => _saved = saved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved ? 'Saved to your articles.' : 'Removed from saved articles.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _fileComplaint() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubmitCasePage(
          initialCaseType: widget.article.caseType,
          onSubmitted: (message) => messenger.showSnackBar(
            SnackBar(content: Text(message), backgroundColor: _green),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final isReportGuide = article.title.toLowerCase() == 'where should i report?';
    final isLegalHelp = article.title.toLowerCase() == 'getting free legal help';
    final references = article.references;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GbBlueHeader(
            title: article.title,
            titleFontSize: 25,
            subtitle: _displayCategory(article.category),
            showBack: true,
            onBack: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    article.preview,
                    style: const TextStyle(color: _body, height: 1.4),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _toggleSaved,
                  icon: Icon(
                    _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: 18,
                  ),
                  label: Text(_saved ? 'Saved' : 'Save'),
                ),
              ],
            ),
          ),
          if (!article.isGuide &&
              (article.offenseClass.isNotEmpty || article.reportTo.isNotEmpty))
            _AtAGlance(article: article),
          for (final section in article.sections) _SectionCard(section: section),
          if (references.isNotEmpty) _ReferencesCard(references: references),
          const SizedBox(height: 14),
          if (isLegalHelp) const _AskAiCard(),
          if (isReportGuide)
            _WideButton(
              icon: Icons.alt_route_rounded,
              label: 'Open the "Where should I report?" guide',
              color: _green,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportGuidePage()),
              ),
            ),
          if (article.caseType.trim().isNotEmpty)
            _WideButton(
              icon: Icons.send_rounded,
              label: 'File this complaint',
              color: const Color(0xFF1F49D8),
              onPressed: _fileComplaint,
            ),
          if (widget.onViewDocument != null)
            _WideButton(
              icon: Icons.picture_as_pdf_outlined,
              label: 'View Document',
              color: _blue,
              onPressed: widget.onViewDocument!,
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              'General legal information, not legal advice.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8FA3C7), fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AtAGlance extends StatelessWidget {
  const _AtAGlance({required this.article});

  final LegalInformationItem article;

  @override
  Widget build(BuildContext context) {
    final reportColor = article.startsAtBarangay ? _green : _orange;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E4F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('At a glance', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (article.offenseClass.isNotEmpty)
            _GlanceRow(
              icon: Icons.category_outlined,
              label: 'Class',
              value: article.offenseClass,
              color: _blue,
            ),
          if (article.reportTo.isNotEmpty) ...[
            const SizedBox(height: 8),
            _GlanceRow(
              icon: Icons.place_outlined,
              label: 'Where to report',
              value: article.reportTo,
              color: reportColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _GlanceRow extends StatelessWidget {
  const _GlanceRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final LegalSection section;

  IconData get _icon {
    final t = section.title.toLowerCase();
    if (t.contains('what it is')) return Icons.info_outline_rounded;
    if (t.contains('example')) return Icons.lightbulb_outline_rounded;
    if (t.contains('bring')) return Icons.folder_open_outlined;
    if (t.contains('where to report') || t.contains('report')) return Icons.place_outlined;
    if (t.contains('happens next') || t.contains('step') || t.contains('filing')) {
      return Icons.timeline_rounded;
    }
    if (t.contains('right')) return Icons.verified_user_outlined;
    if (t.contains('important') || t.contains('violence')) return Icons.warning_amber_rounded;
    if (t.contains('not covered') || t.contains('cannot')) return Icons.block_rounded;
    if (t.contains('penalt') || t.contains('fine') || t.contains('class')) {
      return Icons.stacked_bar_chart_rounded;
    }
    return Icons.article_outlined;
  }

  bool get _isWarning {
    final t = section.title.toLowerCase();
    return t.contains('important') || t.contains('violence');
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isWarning ? _orange : _blue;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isWarning ? const Color(0xFFFFF8EC) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isWarning ? const Color(0xFFF0D29B) : const Color(0xFFE6EDF9),
        ),
        boxShadow: _isWarning
            ? null
            : const [
                BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, color: accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          for (final line in section.lines) _ContentLine(line: line, accent: accent),
        ],
      ),
    );
  }
}

class _ContentLine extends StatelessWidget {
  const _ContentLine({required this.line, required this.accent});

  final LegalContentLine line;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(color: _body, height: 1.45);
    switch (line.kind) {
      case 'bullet':
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 8),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
              ),
              Expanded(child: Text(line.text, style: textStyle)),
            ],
          ),
        );
      case 'step':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: accent,
                child: Text(
                  '${line.number}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(line.text, style: textStyle)),
            ],
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(line.text, style: textStyle),
        );
    }
  }
}

class _ReferencesCard extends StatelessWidget {
  const _ReferencesCard({required this.references});

  final List<String> references;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4E2FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_outlined, color: _blue, size: 18),
              SizedBox(width: 8),
              Text(
                'Legal references',
                style: TextStyle(color: _blue, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < references.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}.',
                      style: const TextStyle(color: _blue, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      references[i],
                      style: const TextStyle(color: _body, height: 1.35, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

/// Shortcut to the AI Chatbot tab, with a reminder that it is not a lawyer.
class _AskAiCard extends StatelessWidget {
  const _AskAiCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB9D0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.smart_toy_outlined, color: _blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Still have questions?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ask the GabayBatas AI to explain the barangay process, your options, or where to go next.',
            style: TextStyle(color: _body, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF0E2B6)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: _orange, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'GabayBatas AI is not a lawyer. Its answers are general information only and are not legal advice. For advice on your own case, consult the Public Attorney\'s Office (PAO) or a lawyer.',
                    style: TextStyle(color: _body, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => MainShell.openTab(context, MainShell.chatTab),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Ask GabayBatas AI'),
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every source cited in the Legal Information articles.
class _SourcesPage extends StatelessWidget {
  const _SourcesPage({required this.articles});

  final List<LegalInformationItem> articles;

  @override
  Widget build(BuildContext context) {
    final sources = <String>{
      for (final a in articles) ...a.references,
    }.toList()
      ..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GbBlueHeader(
            title: 'Sources Used',
            titleFontSize: 26,
            subtitle: '${sources.length} laws, rules, cases and handbooks',
            showBack: true,
            onBack: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 10),
          if (sources.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No sources loaded.', textAlign: TextAlign.center),
            )
          else
            _ReferencesCard(references: sources),
          const SizedBox(height: 24),
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
