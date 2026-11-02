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
  static const int _maxPhotos = 3;

  final _infoController = TextEditingController();
  final _reasonController = TextEditingController();
  final _caseService = CaseService();
  final List<XFile> _newImages = <XFile>[];
  final Set<int> _removedEvidenceIds = <int>{};
  final Map<String, Future<Uint8List>> _newImageBytes =
      <String, Future<Uint8List>>{};
  XFile? _newVideo;
  ComplaintStatement? _statement;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<CaseEvidence> get _existingPhotos =>
      widget.item.evidence.where((e) => e.type != 'video').toList();

  CaseEvidence? get _existingVideo {
    for (final e in widget.item.evidence) {
      if (e.type == 'video') return e;
    }
    return null;
  }

  int get _photoCount =>
      _existingPhotos.where((e) => !_removedEvidenceIds.contains(e.id)).length +
      _newImages.length;

  bool get _reasonChanged =>
      _statement != null &&
      _reasonController.text.trim().isNotEmpty &&
      _reasonController.text.trim() != _statement!.reason.trim();

  @override
  void initState() {
    super.initState();
    _statement = ComplaintStatement.parse(widget.item.description);
    if (_statement != null) {
      _reasonController.text = _statement!.reason;
    }
  }

  @override
  void dispose() {
    _infoController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_photoCount >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can keep up to 3 photos. Remove one to add another.',
          ),
        ),
      );
      return;
    }
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['jpg', 'jpeg', 'png', 'webp'],
    );
    if (!mounted || files.isEmpty) return;
    final remaining = _maxPhotos - _photoCount;
    final selected = files.take(remaining).map((f) => f.xFile).toList();
    setState(() => _newImages.addAll(selected));
  }

  Future<void> _pickVideo() async {
    final files = await FilePicker.pickFiles(type: FileType.video);
    if (!mounted || files.isEmpty) return;
    setState(() => _newVideo = files.single.xFile);
  }

  void _toggleRemoved(CaseEvidence evidence) {
    setState(() {
      if (_removedEvidenceIds.contains(evidence.id)) {
        if (evidence.type != 'video' && _photoCount >= _maxPhotos) {
          _errorMessage =
              'You already have 3 photos. Remove a new photo first to keep this one.';
          return;
        }
        _removedEvidenceIds.remove(evidence.id);
      } else {
        _removedEvidenceIds.add(evidence.id);
      }
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    final info = _infoController.text.trim();
    final hasChanges =
        _reasonChanged ||
        info.isNotEmpty ||
        _newImages.isNotEmpty ||
        _newVideo != null ||
        _removedEvidenceIds.isNotEmpty;
    if (!hasChanges) {
      setState(() {
        _errorMessage = _statement != null
            ? 'Update your complaint reason or your photos before submitting.'
            : 'Please provide the requested details, clarification, or evidence files.';
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
        reason: _reasonChanged ? _reasonController.text.trim() : null,
        removeEvidenceIds: _removedEvidenceIds.toList(),
        evidenceImagePaths: _newImages.map((e) => e.path).toList(),
        evidenceVideoPath: _newVideo?.path,
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1F5BC4), width: 1.5),
      ),
    );
  }

  Widget _sectionTitle(String title, [String? subtitle]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _statementPreview(ComplaintStatement statement) {
    final reason = _reasonController.text.trim().isEmpty
        ? '________'
        : _reasonController.text.trim();
    const strong = TextStyle(
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A4CA3),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD9E4F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 17,
                color: Color(0xFFB06B00),
              ),
              SizedBox(width: 6),
              Text(
                'Your complaint will read:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: Color(0xFF334155),
                height: 1.5,
                fontSize: 13,
              ),
              children: [
                TextSpan(
                  text:
                      'Ako po hi ${statement.name}, ${statement.age} anyos, ngan naukoy ha ${statement.area}. '
                      'Ginrereklamo ko hi ${statement.respondent}, nga naukoy ha ${statement.respondentArea}, tungod ',
                ),
                TextSpan(text: reason, style: strong),
                const TextSpan(
                  text:
                      '. Karuyag ko unta ipatawag hiya ha barangay basi magkastorya kami hin maopay.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoTile({
    required Widget image,
    required VoidCallback onTap,
    bool removed = false,
    bool isNew = false,
  }) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Opacity(opacity: removed ? 0.35 : 1, child: image),
            ),
          ),
          if (isNew)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F5BC4),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (removed)
            const Positioned.fill(
              child: Center(
                child: Text(
                  'Removed',
                  style: TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: removed
                  ? const Color(0xFF1F5BC4)
                  : const Color(0xCC0F172A),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    removed ? Icons.undo_rounded : Icons.close_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addPhotoTile() {
    return SizedBox(
      width: 92,
      height: 92,
      child: Material(
        color: const Color(0xFFF1F5FD),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _pickImages,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFB9CCF0)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Color(0xFF1F5BC4),
                ),
                SizedBox(height: 4),
                Text(
                  'Add photo',
                  style: TextStyle(
                    color: Color(0xFF1F5BC4),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _videoRow() {
    final existing = _existingVideo;
    final String label;
    final VoidCallback? onRemove;
    if (_newVideo != null) {
      label = existing != null
          ? 'New video (replaces your earlier video): ${_newVideo!.name}'
          : 'New video: ${_newVideo!.name}';
      onRemove = () => setState(() => _newVideo = null);
    } else if (existing != null) {
      final removed = _removedEvidenceIds.contains(existing.id);
      label = removed ? 'Video removed: ${existing.name}' : existing.name;
      onRemove = () => _toggleRemoved(existing);
    } else {
      label = '';
      onRemove = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD9E4F7)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.videocam_outlined,
                  size: 18,
                  color: Color(0xFF1F5BC4),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onRemove,
                  icon: Icon(
                    existing != null &&
                            _newVideo == null &&
                            _removedEvidenceIds.contains(existing.id)
                        ? Icons.undo_rounded
                        : Icons.close_rounded,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: _pickVideo,
          icon: const Icon(Icons.videocam_outlined, size: 18),
          label: Text(
            existing != null || _newVideo != null
                ? 'Replace video'
                : 'Add video (max 1)',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final statement = _statement;
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
                  const Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFFD97706),
                        size: 26,
                      ),
                      SizedBox(width: 8),
                      Expanded(
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

                  if (statement != null) ...[
                    _sectionTitle(
                      'Reason for your complaint',
                      'Add the details the barangay asked for. Your complaint is rewritten with the new reason.',
                    ),
                    TextField(
                      controller: _reasonController,
                      maxLines: 5,
                      minLines: 3,
                      onChanged: (_) => setState(() {}),
                      decoration: _inputDecoration(
                        'Why are you filing this complaint?',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _statementPreview(statement),
                  ] else ...[
                    _sectionTitle('Additional Information / Clarification'),
                    TextField(
                      controller: _infoController,
                      maxLines: 5,
                      decoration: _inputDecoration(
                        'Explain additional circumstances, witness details, or answer the barangay request...',
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Evidence
                  _sectionTitle(
                    'Photos ($_photoCount/$_maxPhotos)',
                    'Your photos are kept. Remove any you want to replace, then add new ones.',
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final photo in _existingPhotos)
                        _photoTile(
                          image: _EvidenceThumbnail(evidence: photo),
                          removed: _removedEvidenceIds.contains(photo.id),
                          onTap: () => _toggleRemoved(photo),
                        ),
                      for (int i = 0; i < _newImages.length; i++)
                        _photoTile(
                          image: FutureBuilder<Uint8List>(
                            future: _newImageBytes.putIfAbsent(
                              _newImages[i].path,
                              _newImages[i].readAsBytes,
                            ),
                            builder: (context, snapshot) => snapshot.hasData
                                ? Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  )
                                : const ColoredBox(color: Color(0xFFE2E8F5)),
                          ),
                          isNew: true,
                          onTap: () => setState(() => _newImages.removeAt(i)),
                        ),
                      if (_photoCount < _maxPhotos) _addPhotoTile(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle('Video'),
                  _videoRow(),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1F5BC4),
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

/// Thumbnail of a photo already submitted with the case.
class _EvidenceThumbnail extends StatefulWidget {
  const _EvidenceThumbnail({required this.evidence});

  final CaseEvidence evidence;

  @override
  State<_EvidenceThumbnail> createState() => _EvidenceThumbnailState();
}

class _EvidenceThumbnailState extends State<_EvidenceThumbnail> {
  late final Future<Uint8List> _bytes = CaseService().loadEvidence(
    widget.evidence.url,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return ColoredBox(
          color: const Color(0xFFE2E8F5),
          child: snapshot.hasError
              ? const Icon(
                  Icons.broken_image_outlined,
                  color: Color(0xFF94A3B8),
                )
              : const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
        );
      },
    );
  }
}

class _TrackPageState extends State<TrackPage> {
  final TextEditingController _queryController = TextEditingController();
  final CaseService _caseService = CaseService();

  final List<CaseSummary> _cases = <CaseSummary>[];
  String _statusFilter = 'all';

  /// Filter label → status group understood by the cases API.
  static const Map<String, String> _statusFilters = <String, String>{
    'All cases': 'all',
    'Action needed': 'action_needed',
    'Under review': 'under_review',
    'Ongoing (hearings)': 'ongoing',
    'Resolved': 'resolved',
    'Not covered by KP': 'not_covered',
  };
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
        group: _statusFilter,
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

  /// Pull-to-refresh: reloads the first page but keeps the current list on
  /// screen until the new one arrives.
  Future<void> _refreshCases() async {
    if (_isLoading) return;
    try {
      final result = await _caseService.listCases(
        group: _statusFilter,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _error = null;
        _cases
          ..clear()
          ..addAll(result.cases);
        _offset = _cases.length;
        _total = result.total;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to refresh your cases right now.');
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
    return const Color(0xFF1F5BC4);
  }

  Widget _buildKpStepper(CaseSummary item) {
    final currentStep = item.progressStep;

    final steps = ['Filed', 'Review', 'Mediation', 'Resolution'];
    // A step shows a check once it is passed; Resolution shows one as soon as
    // the case reaches it (green once the case is concluded).
    bool checked(int i) =>
        i < currentStep || i == steps.length - 1 && i == currentStep;

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
                      color: i < currentStep || (checked(i) && item.isConcluded)
                          ? const Color(0xFF10B981)
                          : (i == currentStep
                                ? const Color(0xFF1F5BC4)
                                : const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: checked(i)
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
        final details = item.complaintStatement.isEmpty
            ? 'No description provided.'
            : item.complaintStatement;

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
                      const SizedBox(height: 18),

                      // From the barangay: status, requests, notes, hearing, referral
                      const _SectionLabel('From the barangay'),
                      if (item.statusMessage.isNotEmpty &&
                          !item.hasActionRequired) ...[
                        _StatusMessage(item: item),
                        const SizedBox(height: 10),
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
                        const SizedBox(height: 10),
                      ],

                      if (item.nextHearingDate.isNotEmpty) ...[
                        _HearingCard(item: item),
                        const SizedBox(height: 10),
                      ],
                      if (item.referralDestination.isNotEmpty)
                        _DetailRow(
                          label: 'Referred To',
                          value: item.referralDestination,
                        ),
                      if (item.referralDetails.isNotEmpty)
                        _DetailRow(
                          label: 'Barangay Notes',
                          value: item.referralDetails,
                        ),
                      const SizedBox(height: 10),

                      const _SectionLabel('Case details'),
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
                      _DetailRow(label: 'Status', value: item.kpStatusDisplay),
                      if (item.kpDispositionLabel.isNotEmpty)
                        _DetailRow(
                          label: 'Outcome',
                          value: item.kpDispositionLabel,
                        ),
                      const SizedBox(height: 10),

                      const _SectionLabel('Your complaint'),
                      Text(
                        details,
                        style: const TextStyle(
                          color: Color(0xFF5F7396),
                          height: 1.45,
                        ),
                      ),

                      // The barangay's review notes and the resident's replies, together
                      if ((!item.hasActionRequired &&
                              item.reviewNotes.isNotEmpty) ||
                          item.residentUpdates.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const _SectionLabel('Review notes & your updates'),
                        if (!item.hasActionRequired &&
                            item.reviewNotes.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF86EFAC),
                              ),
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
                          const SizedBox(height: 10),
                        ],
                        if (item.residentUpdates.isNotEmpty)
                          _ResidentUpdatesCard(updates: item.residentUpdates),
                      ],

                      if (item.evidence.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const _SectionLabel('Evidence'),
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

    return RefreshIndicator(
      onRefresh: _refreshCases,
      color: const Color(0xFF1F5BC4),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                      foregroundColor: const Color(0xFF1F5BC4),
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
              items: _statusFilters.keys.toList(),
              value: _statusFilters.entries
                  .firstWhere(
                    (entry) => entry.value == _statusFilter,
                    orElse: () => _statusFilters.entries.first,
                  )
                  .key,
              label: 'Filter by status',
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _statusFilter = _statusFilters[value] ?? 'all';
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
                        // The most important notice from the barangay:
                        // a request, then the next hearing, then the status.
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
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
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
                                    onPressed: () =>
                                        _openProvideInfoSheet(item),
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
                        ] else if (item.nextHearingDate.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _HearingCard(item: item, compact: true),
                        ] else if (item.statusMessage.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _StatusMessage(item: item, compact: true),
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
      ),
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

const List<String> _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const List<String> _weekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Mon d, yyyy" (with the weekday when [withWeekday]), or the raw text if it is not a date.
String _formatDate(String raw, {bool withWeekday = false}) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return raw;
  final text = '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
  return withWeekday ? '${_weekdayNames[date.weekday - 1]}, $text' : text;
}

/// "h:mm AM/PM" from "HH:mm[:ss]" or an ISO timestamp.
String _formatTime(String raw) {
  final parts = raw.contains('T')
      ? (DateTime.tryParse(raw)?.toLocal().toIso8601String().split('T').last ??
                '')
            .split(':')
      : raw.split(':');
  if (parts.length < 2) return raw;
  final hour = int.tryParse(parts[0]);
  final minute = parts[1].padLeft(2, '0');
  if (hour == null) return raw;
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$h12:$minute ${hour < 12 ? 'AM' : 'PM'}';
}

/// The next scheduled hearing, so the resident knows when to appear.
class _HearingCard extends StatelessWidget {
  const _HearingCard({required this.item, this.compact = false});

  final CaseSummary item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stageName = item.nextHearingType.isEmpty
        ? 'hearing'
        : '${item.nextHearingType} hearing';
    final (String title, String note) = switch (item.nextHearingPurposeType) {
      'explanation_complainant' => (
        'Hearing to explain your absence',
        'You missed a hearing. Come and explain why you were absent. If your reason is not accepted, your complaint will be dismissed.',
      ),
      'explanation_respondent' => (
        "Hearing on the respondent's absence",
        'The respondent missed a hearing and must explain why. You may attend.',
      ),
      'pangkat_constitution' => (
        'Meeting to choose the Pangkat',
        'Come to help choose the 3 Lupon members who will hear your case. If you do not agree, the Punong Barangay draws lots.',
      ),
      'execution' => (
        'Hearing on the motion for execution',
        'The barangay will ask why the settlement was not followed.',
      ),
      _ => (
        'Upcoming $stageName',
        'Please come on time. Bring any evidence or witnesses that support your side.',
      ),
    };
    final when = [
      _formatDate(item.nextHearingDate, withWeekday: true),
      if (item.nextHearingTime.isNotEmpty) _formatTime(item.nextHearingTime),
    ].join(' · ');
    final warning = item.nextHearingPurposeType == 'explanation_complainant';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB9CCF0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF1F5BC4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.event_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: warning
                        ? const Color(0xFFB45309)
                        : const Color(0xFF1A4CA3),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  when,
                  style: const TextStyle(
                    color: Color(0xFF173F8A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.nextHearingLocation.isNotEmpty)
                  Text(
                    item.nextHearingLocation,
                    style: const TextStyle(
                      color: Color(0xFF4A6491),
                      fontSize: 12,
                    ),
                  ),
                if (!compact || warning) ...[
                  const SizedBox(height: 6),
                  Text(
                    note,
                    style: const TextStyle(
                      color: Color(0xFF4A6491),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the current status means for the resident; a dismissal or an
/// unsettled ending is shown in a warning colour.
class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.item, this.compact = false});

  final CaseSummary item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final negative =
        item.isUnsettledOutcome || item.kpStatus.contains('noshow_complainant');
    final positive = item.isSettledOutcome;
    final color = negative
        ? const Color(0xFFB91C1C)
        : positive
        ? const Color(0xFF047857)
        : const Color(0xFF1A4CA3);
    final background = negative
        ? const Color(0xFFFEF2F2)
        : positive
        ? const Color(0xFFECFDF5)
        : const Color(0xFFF2F6FF);
    final icon = negative
        ? Icons.error_outline_rounded
        : positive
        ? Icons.check_circle_outline_rounded
        : Icons.info_outline_rounded;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.statusMessage,
              maxLines: compact ? 3 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small heading that groups the parts of an opened case.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF6A7FA3),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// What the resident sent back to the barangay, each with its date.
class _ResidentUpdatesCard extends StatelessWidget {
  const _ResidentUpdatesCard({required this.updates});

  final List<ResidentUpdate> updates;

  @override
  Widget build(BuildContext context) {
    final shown = updates.reversed.toList();
    return Container(
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
          Row(
            children: [
              const Icon(
                Icons.mark_chat_read_outlined,
                color: Color(0xFFB45309),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${updates.length} update${updates.length == 1 ? '' : 's'} sent',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          for (final update in shown) ...[
            const SizedBox(height: 8),
            if (update.eventAt.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Update · ${_formatDate(update.eventAt)} ${_formatTime(update.eventAt)}',
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              update.details,
              style: const TextStyle(
                color: Color(0xFF422006),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
