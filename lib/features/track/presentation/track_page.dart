// ignore_for_file: deprecated_member_use

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:typed_data';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gb_blue_header.dart';
import '../../../core/widgets/gb_dropdown.dart';
import '../data/case_service.dart';

class TrackPage extends StatefulWidget {
  const TrackPage({super.key});

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _VideoEvidenceDialog extends StatefulWidget {
  const _VideoEvidenceDialog({
    required this.evidence,
    required this.uri,
    required this.headers,
  });

  final CaseEvidence evidence;
  final Uri uri;
  final Map<String, String> headers;

  @override
  State<_VideoEvidenceDialog> createState() => _VideoEvidenceDialogState();
}

class _VideoEvidenceDialogState extends State<_VideoEvidenceDialog> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialize;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      widget.uri,
      httpHeaders: widget.headers,
    );
    _initialize = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: FutureBuilder<void>(
        future: _initialize,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Unable to play this video. Please try again.'),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    }),
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.evidence.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProvideInfoSheet extends StatefulWidget {
  const _ProvideInfoSheet({required this.item, required this.onSuccess});

  final CaseSummary item;
  final VoidCallback onSuccess;

  @override
  State<_ProvideInfoSheet> createState() => _ProvideInfoSheetState();
}

class _ProvideInfoSheetState extends State<_ProvideInfoSheet> {
  final _infoController = TextEditingController();
  final _caseService = CaseService();
  final List<XFile> _evidenceImages = <XFile>[];
  XFile? _evidenceVideo;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _infoController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_evidenceImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can attach up to 3 pictures.')),
      );
      return;
    }
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['jpg', 'jpeg', 'png', 'webp'],
    );
    if (!mounted || files.isEmpty) return;
    final remaining = 3 - _evidenceImages.length;
    final selected = files.take(remaining).map((f) => f.xFile).toList();
    setState(() => _evidenceImages.addAll(selected));
  }

  Future<void> _pickVideo() async {
    final files = await FilePicker.pickFiles(type: FileType.video);
    if (!mounted || files.isEmpty) return;
    setState(() => _evidenceVideo = files.single.xFile);
  }

  Future<void> _submit() async {
    final info = _infoController.text.trim();
    if (info.isEmpty && _evidenceImages.isEmpty && _evidenceVideo == null) {
      setState(() {
        _errorMessage =
            'Please provide the requested details, clarification, or evidence files.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final caseIdToUse = widget.item.caseRowId > 0
          ? widget.item.caseRowId
          : widget.item.caseId;

      await _caseService.updateCase(
        caseId: caseIdToUse,
        additionalInfo: info,
        evidenceImagePaths: _evidenceImages.map((e) => e.path).toList(),
        evidenceVideoPath: _evidenceVideo?.path,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to submit your details right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Column(
        children: [
          const SizedBox(height: 12),
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
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                24 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFFD97706),
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Provide Additional Details',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Case: ${widget.item.referenceNumber.isNotEmpty ? widget.item.referenceNumber : 'C-${widget.item.caseIdDigits}'}',
                    style: const TextStyle(
                      color: Color(0xFF6A7FA3),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Barangay notice reminder
                  if (widget.item.missingItems.isNotEmpty ||
                      widget.item.reviewNotes.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Requested by Barangay Officer:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                              fontSize: 12.5,
                            ),
                          ),
                          if (widget.item.missingItems.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.item.missingItems,
                              style: const TextStyle(
                                color: Color(0xFF78350F),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (widget.item.reviewNotes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.item.reviewNotes,
                              style: const TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),

                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const Text(
                    'Additional Information / Clarification',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _infoController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText:
                          'Explain additional circumstances, witness details, or answer the barangay request...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Evidence Attachments
                  const Text(
                    'Attach New Evidence / Documents',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Upload photos, receipts, barangay clearance, or video clips.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _evidenceImages.length >= 3 ? null : _pickImages,
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: Text('Photos (${_evidenceImages.length}/3)'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _evidenceVideo != null ? null : _pickVideo,
                        icon: const Icon(Icons.videocam_outlined, size: 18),
                        label: Text(
                          _evidenceVideo != null
                              ? '1 Video Selected'
                              : 'Video (Max 1)',
                        ),
                      ),
                    ],
                  ),

                  // Selected files list
                  if (_evidenceImages.isNotEmpty || _evidenceVideo != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (int i = 0; i < _evidenceImages.length; i++)
                          Chip(
                            label: Text(
                              _evidenceImages[i].name,
                              style: const TextStyle(fontSize: 11),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() => _evidenceImages.removeAt(i));
                            },
                          ),
                        if (_evidenceVideo != null)
                          Chip(
                            avatar: const Icon(Icons.videocam, size: 14),
                            label: Text(
                              _evidenceVideo!.name,
                              style: const TextStyle(fontSize: 11),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() => _evidenceVideo = null);
                            },
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit Information to Barangay',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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

  Color _getBadgeBackgroundColor(CaseSummary item) {
    if (item.hasActionRequired) {
      return const Color(0xFFFEF3C7);
    }
    if (item.isUnderReview) {
      return const Color(0xFFEFF6FF);
    }
    if (item.isUnsettledOutcome) {
      return const Color(0xFFFEE2E2);
    }
    if (item.isSettledOutcome) {
      return const Color(0xFFD1FAE5);
    }
    if (item.isAccepted) {
      return const Color(0xFFECFDF5);
    }
    return const Color(0xFFEAF1FF);
  }

  Color _getBadgeTextColor(CaseSummary item) {
    if (item.hasActionRequired) {
      return const Color(0xFFB45309);
    }
    if (item.isUnderReview) {
      return const Color(0xFF1D4ED8);
    }
    if (item.isUnsettledOutcome) {
      return const Color(0xFFB91C1C);
    }
    if (item.isSettledOutcome) {
      return const Color(0xFF065F46);
    }
    if (item.isAccepted) {
      return const Color(0xFF047857);
    }
    return const Color(0xFF2F6EFF);
  }

  Widget _buildKpStepper(CaseSummary item) {
    final currentStep = item.progressStep;

    final steps = ['Filed', 'Review', 'Mediation', 'Resolution'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < currentStep
                          ? const Color(0xFF10B981)
                          : (i == currentStep
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: i < currentStep
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: i == currentStep
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == currentStep
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: i == currentStep
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (i < steps.length - 1)
              Container(
                width: 14,
                height: 2,
                color: i < currentStep
                    ? const Color(0xFF10B981)
                    : const Color(0xFFCBD5E1),
                margin: const EdgeInsets.only(bottom: 16),
              ),
          ],
        ],
      ),
    );
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

  void _openProvideInfoSheet(CaseSummary item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return _ProvideInfoSheet(
          item: item,
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Additional information submitted successfully! Your case is now under review.',
                ),
                backgroundColor: Color(0xFF059669),
              ),
            );
            _loadCases(reset: true);
          },
        );
      },
    );
  }

  void _openCaseDetails(CaseSummary item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        final details = item.description.trim().isEmpty
            ? 'No description provided.'
            : item.description.trim();

        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Column(
            children: [
              const SizedBox(height: 12),
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
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    24 + MediaQuery.of(sheetContext).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _caseIdDisplay(item),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getBadgeBackgroundColor(item),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.kpStatusDisplay.toUpperCase(),
                              style: TextStyle(
                                color: _getBadgeTextColor(item),
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Stepper
                      _buildKpStepper(item),
                      const SizedBox(height: 14),

                      if (item.residentUpdates.isNotEmpty) ...[
                        _ResidentUpdatesCard(updates: item.residentUpdates),
                        const SizedBox(height: 14),
                      ],

                      // Official Barangay Notice (if action required or notes exist)
                      if (item.hasActionRequired) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.assignment_late_rounded,
                                    color: Color(0xFFD97706),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Barangay Notice: Action Required',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E),
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.missingItems.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Missing / Required: ${item.missingItems}',
                                  style: const TextStyle(
                                    color: Color(0xFF78350F),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              if (item.reviewNotes.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Officer Notes: ${item.reviewNotes}',
                                  style: const TextStyle(
                                    color: Color(0xFF92400E),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.of(sheetContext).pop();
                                    _openProvideInfoSheet(item);
                                  },
                                  icon: const Icon(
                                    Icons.edit_note_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Provide Requested Info / Documents',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFD97706),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else if (item.reviewNotes.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFF16A34A),
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Barangay Review Notes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF166534),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.reviewNotes,
                                style: const TextStyle(
                                  color: Color(0xFF14532D),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Next Hearing Box
                      if (item.nextHearingDate.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Upcoming Hearing Scheduled',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E40AF),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.nextHearingDate}${item.nextHearingType.isNotEmpty ? ' (${item.nextHearingType})' : ''}',
                                      style: const TextStyle(
                                        color: Color(0xFF1D4ED8),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (item.nextHearingLocation.isNotEmpty)
                                      Text(
                                        'Location: ${item.nextHearingLocation}',
                                        style: const TextStyle(
                                          color: Color(0xFF3B82F6),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Details Section
                      _DetailRow(
                        label: 'Resident Name',
                        value: item.residentName,
                      ),
                      _DetailRow(
                        label: 'Person Being Complained',
                        value: item.complainedPerson,
                      ),
                      _DetailRow(label: 'Barangay', value: item.barangay),
                      _DetailRow(label: 'Contact', value: item.contact),
                      _DetailRow(label: 'Case Type', value: item.caseType),
                      _DetailRow(
                        label: 'Current Stage',
                        value: item.kpStageLabel,
                      ),
                      _DetailRow(
                        label: 'Status',
                        value: item.kpStatusDisplay,
                      ),
                      if (item.kpDispositionLabel.isNotEmpty)
                        _DetailRow(
                          label: 'Outcome',
                          value: item.kpDispositionLabel,
                        ),
                      const SizedBox(height: 10),
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        details,
                        style: const TextStyle(
                          color: Color(0xFF5F7396),
                          height: 1.45,
                        ),
                      ),

                      // Evidence Section
                      if (item.evidence.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Evidence',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        for (final evidence in item.evidence)
                          _EvidencePreview(evidence: evidence),
                      ],

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
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
          description:
              'Enter the 4-digit sequence from your case ID to check the latest progress and updates.',
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFD93025)),
            ),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _caseIdDisplay(item),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getBadgeBackgroundColor(item),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.kpStatusDisplay.toUpperCase(),
                              style: TextStyle(
                                color: _getBadgeTextColor(item),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Case Type: ${item.caseType}',
                        style: const TextStyle(color: Color(0xFF5F7396)),
                      ),
                      if (item.residentUpdates.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _ResidentUpdatesCard(updates: item.residentUpdates),
                      ],
                      if (item.hasActionRequired) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Color(0xFFD97706),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.missingItems.isNotEmpty
                                          ? 'Action Required: ${item.missingItems}'
                                          : (item.reviewNotes.isNotEmpty
                                              ? 'Barangay Note: ${item.reviewNotes}'
                                              : 'Action required by Barangay'),
                                      style: const TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => _openProvideInfoSheet(item),
                                  icon: const Icon(
                                    Icons.edit_note_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Provide Additional Info / Details',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFD97706),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (item.isUnderReview) ...[
                        const SizedBox(height: 6),
                        const Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: Color(0xFF3B82F6),
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Under review by Barangay Officer',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ] else if (item.isAccepted) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Color(0xFF059669),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.kpStageLabel.isNotEmpty
                                  ? item.kpStageLabel
                                  : 'Accepted for KP Proceedings',
                              style: const TextStyle(
                                color: Color(0xFF059669),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      const Text(
                        'Tap to view process timeline & details',
                        style: TextStyle(
                          color: Color(0xFF8AA0C1),
                          fontSize: 12,
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

class _EvidencePreview extends StatefulWidget {
  const _EvidencePreview({required this.evidence});

  final CaseEvidence evidence;

  @override
  State<_EvidencePreview> createState() => _EvidencePreviewState();
}

class _EvidencePreviewState extends State<_EvidencePreview> {
  final CaseService _caseService = CaseService();
  Future<Uint8List>? _bytes;

  @override
  void initState() {
    super.initState();
    if (widget.evidence.type == 'image' && widget.evidence.url.isNotEmpty) {
      _bytes = _caseService.loadEvidence(widget.evidence.url);
    }
  }

  Future<void> _openPreview() async {
    if (!mounted) return;
    if (widget.evidence.type == 'image' && _bytes != null) {
      final bytes = await _bytes!;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    final uri = _caseService.evidenceUri(widget.evidence.url);
    final headers = await _caseService.evidenceHeaders();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _VideoEvidenceDialog(
        evidence: widget.evidence,
        uri: uri,
        headers: headers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final evidence = widget.evidence;
    final sizeMb = evidence.size / (1024 * 1024);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _openPreview,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              if (_bytes != null)
                FutureBuilder<Uint8List>(
                  future: _bytes,
                  builder: (context, snapshot) => SizedBox(
                    width: 64,
                    height: 64,
                    child: snapshot.hasData
                        ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                        : const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                  ),
                )
              else
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: Icon(Icons.videocam_outlined, size: 32),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${evidence.name}\n${sizeMb.toStringAsFixed(1)} MB',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
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
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6A7FA3),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: const TextStyle(
                color: Color(0xFF22324F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _ResidentUpdatesCard extends StatelessWidget {
  const _ResidentUpdatesCard({required this.updates});

  final List<String> updates;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.reply_rounded,
                color: Color(0xFF2563EB),
                size: 19,
              ),
              SizedBox(width: 8),
              Text(
                'Your Submitted Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E40AF),
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ...updates.asMap().entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == updates.length - 1 ? 0 : 6,
                  ),
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}