import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gb_blue_header.dart';
import '../../../core/widgets/gb_dropdown.dart';
import '../data/case_service.dart';

class TrackPage extends StatefulWidget {
  const TrackPage({super.key});

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  final TextEditingController _queryController = TextEditingController();
  final CaseService _caseService = CaseService();

  final List<CaseSummary> _cases = <CaseSummary>[];
  String _statusFilter = 'all';
  int _offset = 0;
  int _total = 0;
  bool _isLoading = false;
  String? _error;

  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadCases(reset: true);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadCases({required bool reset}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) {
        _offset = 0;
        _cases.clear();
      }
    });

    try {
      final result = await _caseService.listCases(
        status: _statusFilter,
        limit: _pageSize,
        offset: _offset,
      );

      if (!mounted) return;
      setState(() {
        _cases.addAll(result.cases);
        _offset = _cases.length;
        _total = result.total;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load your cases right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _caseIdDisplay(CaseSummary item) {
    if (item.referenceNumber.isNotEmpty) {
      return item.referenceNumber;
    }
    if (item.caseIdDigits.isNotEmpty) {
      return 'C-${item.caseIdDigits}';
    }
    return 'N/A';
  }

  bool _matchesSearch(CaseSummary item, String query) {
    if (query.isEmpty) return true;

    final reference = item.referenceNumber.toLowerCase();
    final caseIdDigits = item.caseIdDigits;
    final queryDigits = query.replaceAll(RegExp(r'\D'), '');

    if (reference.contains(query)) {
      return true;
    }

    if (queryDigits.length == 4) {
      return caseIdDigits.endsWith(queryDigits);
    }

    if (queryDigits.isNotEmpty) {
      return caseIdDigits.contains(queryDigits);
    }

    return false;
  }

  List<CaseSummary> get _visibleCases {
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) return _cases;
    return _cases.where((c) => _matchesSearch(c, query)).toList();
  }

  bool get _canLoadMore => _cases.length < _total;

  void _openCaseDetails(CaseSummary item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        final details = item.description.trim().isEmpty ? 'No description provided.' : item.description.trim();

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.of(sheetContext).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(_caseIdDisplay(item), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _DetailRow(label: 'Resident Name', value: item.residentName),
              _DetailRow(label: 'Person Being Complained', value: item.complainedPerson),
              _DetailRow(label: 'Barangay', value: item.barangay),
              _DetailRow(label: 'Contact', value: item.contact),
              _DetailRow(label: 'Case Type', value: item.caseType),
              _DetailRow(label: 'Status', value: item.status.replaceAll('_', ' ').toUpperCase()),
              const SizedBox(height: 10),
              const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(details, style: const TextStyle(color: Color(0xFF5F7396), height: 1.45)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _queryController.text.trim();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GbBlueHeader(
          title: 'Track Your Case',
          subtitle: 'Status lookup',
          description: 'Enter the 4-digit sequence from your case ID to check the latest progress and updates.',
          bottom: Column(
            children: [
              TextField(
                controller: _queryController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter Case ID digits (e.g., 1234)',
                  hintStyle: const TextStyle(color: Color(0xFF8EA0BF)),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search Case'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2F6EFF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GbDropdown(
            items: const ['All statuses', 'Pending', 'In Progress', 'Resolved'],
            value: _statusFilter == 'all' ? 'All statuses' : _statusFilter,
            label: 'Filter by status',
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _statusFilter = value == 'All statuses' ? 'all' : value;
              });
              _loadCases(reset: true);
            },
          ),
        ),
        const SizedBox(height: 10),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFD93025))),
          ),
        if (_isLoading && _cases.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_isLoading && _visibleCases.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              searchQuery.isEmpty
                  ? 'No cases found yet for this account.'
                  : 'No cases match "$searchQuery".',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6A7FA3)),
            ),
          ),
        ..._visibleCases.map(
          (item) => Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              elevation: 2,
              shadowColor: const Color(0x12000000),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openCaseDetails(item),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_caseIdDisplay(item), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Case Type: ${item.caseType}', style: const TextStyle(color: Color(0xFF5F7396))),
                      const SizedBox(height: 4),
                      Text('Tap to view your submitted details', style: const TextStyle(color: Color(0xFF8AA0C1), fontSize: 12.5)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.status.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(color: Color(0xFF2F6EFF), fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_canLoadMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => _loadCases(reset: false),
              child: Text(_isLoading ? 'Loading...' : 'Load more'),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(color: Color(0xFF6A7FA3), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value.isEmpty ? 'N/A' : value, style: const TextStyle(color: Color(0xFF22324F), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
