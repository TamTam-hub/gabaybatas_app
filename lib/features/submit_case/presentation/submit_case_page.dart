// ignore_for_file: deprecated_member_use

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/case_types.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gb_blue_header.dart';
import '../../../core/widgets/gb_dropdown.dart';
import '../../../core/validation/input_validators.dart';
import '../../about/data/profile_service.dart';
import '../../verification/data/residency_verification_service.dart';
import '../data/submit_case_service.dart';

class SubmitCasePage extends StatefulWidget {
  const SubmitCasePage({super.key, this.onSubmitted, this.initialCaseType});

  final ValueChanged<String>? onSubmitted;

  /// Case type to pre-select, e.g. when opened from a Legal Information article.
  final String? initialCaseType;

  @override
  State<SubmitCasePage> createState() => _SubmitCasePageState();
}

class _SubmitCasePageState extends State<SubmitCasePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _complainantAddress = TextEditingController();
  final _complainantLocation = TextEditingController();
  final _complainantAge = TextEditingController();
  final _complainedPerson = TextEditingController();
  final _respondentAddress = TextEditingController();
  final _respondentLocation = TextEditingController();
  final _contact = TextEditingController();
  final _description = TextEditingController();
  final ProfileService _profileService = ProfileService();
  final ResidencyVerificationService _verificationService =
      ResidencyVerificationService();
  final SubmitCaseService _submitCaseService = SubmitCaseService();
  final List<XFile> _evidenceImages = <XFile>[];
  XFile? _evidenceVideo;

  bool _isSubmitting = false;
  bool _isLoadingProfile = false;
  bool _isLoadingVerification = true;
  bool _showValidationErrors = false;
  ResidencyVerification? _verification;

  String _barangay = AppConfig.supportedBarangay;
  String _caseType = 'Public Disturbance';

  static const List<String> _caseTypes = kCaseTypes;
  static const int _maxEvidenceImages = 3;
  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const int _maxVideoBytes = 50 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    final initialType = widget.initialCaseType;
    if (initialType != null && _caseTypes.contains(initialType)) {
      _caseType = initialType;
    }
    _loadProfileDefaults();
    _loadVerification();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _complainantAddress.dispose();
    _complainantLocation.dispose();
    _complainantAge.dispose();
    _complainedPerson.dispose();
    _respondentAddress.dispose();
    _respondentLocation.dispose();
    _contact.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickEvidenceImages() async {
    if (_evidenceImages.length >= _maxEvidenceImages) {
      _showMessage('You can upload up to 3 evidence pictures.');
      return;
    }
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['jpg', 'jpeg', 'png', 'webp'],
    );
    if (!mounted) return;

    final remaining = _maxEvidenceImages - _evidenceImages.length;
    final selected = files.take(remaining).map((file) => file.xFile).toList();
    final valid = <XFile>[];
    for (final file in selected) {
      if (await file.length() > _maxImageBytes) {
        _showMessage('${file.name} is larger than 5 MB.');
      } else {
        valid.add(file);
      }
    }
    if (files.length > remaining) {
      _showMessage('Only 3 evidence pictures are allowed.');
    }
    setState(() => _evidenceImages.addAll(valid));
  }

  Future<void> _pickEvidenceVideo() async {
    if (_evidenceVideo != null) {
      _showMessage('Only 1 evidence video is allowed.');
      return;
    }
    final files = await FilePicker.pickFiles(type: FileType.video);
    if (!mounted || files.isEmpty) return;
    final file = files.single.xFile;
    if (await file.length() > _maxVideoBytes) {
      _showMessage('The evidence video must not exceed 50 MB.');
      return;
    }
    setState(() => _evidenceVideo = file);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadProfileDefaults() async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final profile = await _profileService.fetchProfile();
      if (!mounted || profile == null) return;

      setState(() {
        if (profile.name.isNotEmpty) {
          _fullName.text = profile.name;
        }
        if (profile.phone.isNotEmpty) {
          _contact.text = profile.phone;
        }
        _barangay = AppConfig.supportedBarangay;
      });
    } catch (_) {
      // Keep the form usable if profile lookup fails.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadVerification() async {
    try {
      final verification = await _verificationService.fetchLatest();
      if (!mounted) return;
      setState(() {
        _verification = verification;
        _isLoadingVerification = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _verification = null;
          _isLoadingVerification = false;
        });
      }
    }
  }

  /// Parts of the complaint statement filled in (names come from above).
  int get _statementPartsDone => <bool>[
        _fullName.text.trim().length >= 3,
        _complainantAge.text.trim().isNotEmpty,
        _complainantLocation.text.trim().isNotEmpty,
        _complainedPerson.text.trim().length >= 3,
        _respondentLocation.text.trim().isNotEmpty,
        _description.text.trim().length >= 10,
      ].where((done) => done).length;

  bool get _isResidentVerified =>
      _verification?.status.trim().toLowerCase() == 'approved';

  String get _verificationMessage {
    if (_isLoadingVerification) {
      return 'Checking residency verification...';
    }
    if (_isResidentVerified) {
      return 'Residency verified. You may submit a case.';
    }
    final status = _verification?.status.trim().toLowerCase();
    if (status == 'pending') {
      return 'Your residency verification is still under review.';
    }
    if (status == 'rejected' || status == 'resubmit') {
      return 'Please resubmit your residency verification before submitting a case.';
    }
    return 'Verify your residency before submitting a case.';
  }

  Future<void> _submitCase() async {
    if (_isSubmitting) return;

    if (!_isResidentVerified) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_verificationMessage)));
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() {
        _showValidationErrors = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _submitCaseService.submitCase(
        name: _fullName.text.trim(),
        complainantAddress: _complainantAddress.text.trim(),
        complainantLocation: _complainantLocation.text.trim(),
        complainantAge: _complainantAge.text.trim(),
        complainedPerson: _complainedPerson.text.trim(),
        respondentAddress: _respondentAddress.text.trim(),
        respondentLocation: _respondentLocation.text.trim(),
        barangay: _barangay,
        contact: _contact.text.trim(),
        caseType: _caseType,
        // The API builds the final complaint statement from this reason.
        description: _description.text.trim(),
        evidenceImagePaths: _evidenceImages.map((file) => file.path).toList(),
        evidenceVideoPath: _evidenceVideo?.path,
      );

      if (!mounted) return;

      final message =
          'Case ${result.referenceNumber} submitted successfully. Status: ${result.status}';
      widget.onSubmitted?.call(message);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Case submission failed. Please try again.'),
        ),
      );
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
    final selectedCaseType = _caseTypes.contains(_caseType)
        ? _caseType
        : _caseTypes.first;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GbBlueHeader(
            title: 'Submit a Case',
            showBack: true,
            onBack: () => Navigator.of(context).pop(),
            description:
                'Fill out the form below to submit your legal concern. We\'ll process it within 24 hours.',
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _isLoadingProfile
                  ? 'Loading profile details...'
                  : 'Use your profile details if available, then send your concern.',
              style: const TextStyle(color: Color(0xFF7D91B2)),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _isResidentVerified
                    ? const Color(0xFFEAF8EF)
                    : const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isResidentVerified
                      ? const Color(0xFFB8E2C5)
                      : const Color(0xFFF0D29B),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isResidentVerified
                          ? Icons.verified_outlined
                          : Icons.info_outline_rounded,
                      color: _isResidentVerified
                          ? const Color(0xFF168548)
                          : const Color(0xFFB06B00),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_verificationMessage)),
                  ],
                ),
              ),
            ),
          ),
          Form(
            key: _formKey,
            autovalidateMode: _showValidationErrors
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Column(
              children: [
                const _FieldLabel(
                  icon: Icons.person_outline_rounded,
                  label: 'Full Name',
                ),
                _InputShell(
                  child: TextFormField(
                    controller: _fullName,
                    enabled: !_isSubmitting,
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration(
                      hintText: 'Enter your full name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (value.trim().length < 3) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const _FieldLabel(
                  icon: Icons.home_outlined,
                  label: 'Complete Address of Complainant',
                ),
                _InputShell(
                  child: TextFormField(
                    controller: _complainantAddress,
                    enabled: !_isSubmitting,
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration(
                      hintText:
                          'House/Purok, Barangay Muñoz, Catbalogan City, Samar',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                ),
                const _FieldLabel(
                  icon: Icons.gavel_rounded,
                  label: 'Person Being Complained',
                ),
                _InputShell(
                  child: TextFormField(
                    controller: _complainedPerson,
                    enabled: !_isSubmitting,
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration(
                      hintText: 'Full name of respondent',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (value.trim().length < 3) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const _FieldLabel(
                  icon: Icons.home_work_outlined,
                  label: 'Complete Address of Respondent',
                ),
                _InputShell(
                  child: TextFormField(
                    controller: _respondentAddress,
                    enabled: !_isSubmitting,
                    onChanged: (_) => setState(() {}),
                    decoration: _fieldDecoration(
                      hintText:
                          'House/Purok, Barangay Muñoz, Catbalogan City, Samar',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                ),
                const _FieldLabel(
                  icon: Icons.call_outlined,
                  label: 'Contact Number',
                ),
                _InputShell(
                  child: TextFormField(
                    controller: _contact,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.phone,
                    decoration: _fieldDecoration(hintText: '+63 912 345 6789'),
                    validator: InputValidators.phone,
                  ),
                ),
                GbDropdownField(
                  label: 'Case Type',
                  icon: Icons.bookmark_border_rounded,
                  items: _caseTypes,
                  value: selectedCaseType,
                  enabled: !_isSubmitting,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _caseType = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
                if (selectedCaseType == kFamilyDisputeCaseType)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5E6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF0D29B)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFB06B00),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'If the complaint involves violence or abuse against a woman or child, it cannot go through barangay mediation (RA 9262). Please go directly to the Barangay VAW Desk or the PNP Women and Children Protection Desk.',
                              style: TextStyle(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const _FieldLabel(
                  icon: Icons.subject_rounded,
                  label: 'Reason of Complaint',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: _StatementProgress(
                    done: _statementPartsDone,
                    total: 6,
                  ),
                ),
                _StatementStep(
                  step: 1,
                  title: 'About you',
                  complete: _fullName.text.trim().length >= 3 &&
                      _complainantAge.text.trim().isNotEmpty &&
                      _complainantLocation.text.trim().isNotEmpty,
                  children: [
                    _LinkedValue(
                      label: 'Your name',
                      value: _fullName.text.trim(),
                      emptyHint: 'Enter your full name at the top of the form',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 96,
                          child: _StepTextField(
                            label: 'Age',
                            controller: _complainantAge,
                            hintText: 'e.g. 34',
                            enabled: !_isSubmitting,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            onChanged: (_) => setState(() {}),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StepTextField(
                            label: 'Your purok / area',
                            controller: _complainantLocation,
                            hintText: 'e.g. Purok 3',
                            enabled: !_isSubmitting,
                            onChanged: (_) => setState(() {}),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _StatementStep(
                  step: 2,
                  title: 'Who you are complaining about',
                  complete: _complainedPerson.text.trim().length >= 3 &&
                      _respondentLocation.text.trim().isNotEmpty,
                  children: [
                    _LinkedValue(
                      label: 'Their name',
                      value: _complainedPerson.text.trim(),
                      emptyHint:
                          'Enter their name in "Person Being Complained" above',
                    ),
                    const SizedBox(height: 12),
                    _StepTextField(
                      label: 'Their purok / area',
                      controller: _respondentLocation,
                      hintText: 'e.g. Purok 5',
                      enabled: !_isSubmitting,
                      onChanged: (_) => setState(() {}),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ],
                ),
                _StatementStep(
                  step: 3,
                  title: 'What happened?',
                  complete: _description.text.trim().length >= 10,
                  children: [
                    _StepTextField(
                      label: 'Reason of complaint',
                      controller: _description,
                      hintText:
                          'Describe what they did, when and where it happened.',
                      enabled: !_isSubmitting,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 1000,
                      showCounter: true,
                      onChanged: (_) => setState(() {}),
                      validator: (value) =>
                          value == null || value.trim().length < 10
                          ? 'Enter at least 10 characters'
                          : null,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tip: Detalyado nga rason han reklamo',
                      style: TextStyle(
                        color: Color(0xFF7D91B2),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
                _StatementPreview(
                  name: _fullName.text.trim(),
                  age: _complainantAge.text.trim(),
                  location: _complainantLocation.text.trim(),
                  respondent: _complainedPerson.text.trim(),
                  respondentLocation: _respondentLocation.text.trim(),
                  reason: _description.text.trim(),
                ),
                const _FieldLabel(
                  icon: Icons.attach_file_rounded,
                  label: 'Evidence (Optional)',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Add up to 3 pictures and 1 video. Pictures: 5 MB each maximum. Video: 50 MB maximum.',
                        style: TextStyle(color: Color(0xFF7D91B2)),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _pickEvidenceImages,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          'Add pictures (${_evidenceImages.length}/3)',
                        ),
                      ),
                      for (
                        var index = 0;
                        index < _evidenceImages.length;
                        index++
                      )
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.image_outlined),
                          title: Text(_evidenceImages[index].name),
                          trailing: IconButton(
                            tooltip: 'Remove picture',
                            onPressed: _isSubmitting
                                ? null
                                : () => setState(
                                    () => _evidenceImages.removeAt(index),
                                  ),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _pickEvidenceVideo,
                        icon: const Icon(Icons.video_library_outlined),
                        label: Text(
                          _evidenceVideo == null
                              ? 'Add video (0/1)'
                              : 'Replace video',
                        ),
                      ),
                      if (_evidenceVideo != null)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.videocam_outlined),
                          title: Text(_evidenceVideo!.name),
                          trailing: IconButton(
                            tooltip: 'Remove video',
                            onPressed: _isSubmitting
                                ? null
                                : () => setState(() => _evidenceVideo = null),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          _isSubmitting ||
                              _isLoadingVerification ||
                              !_isResidentVerified
                          ? null
                          : _submitCase,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isSubmitting ? 'Submitting...' : 'Submit Case',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0E2242),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A3A6B), size: 18),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Progress of the complaint statement, e.g. "4 of 6 parts done".
class _StatementProgress extends StatelessWidget {
  const _StatementProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final finished = done >= total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: finished ? const Color(0xFFEAF8EF) : const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                finished ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                color: finished
                    ? const Color(0xFF168548)
                    : const Color(0xFF1A3A6B),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  finished
                      ? 'Your complaint statement is complete.'
                      : 'Answer 3 short steps. We will write your complaint for you.',
                  style: const TextStyle(color: Color(0xFF49658F), height: 1.35),
                ),
              ),
              Text(
                '$done/$total',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: finished
                      ? const Color(0xFF168548)
                      : const Color(0xFF1A3A6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 6,
              backgroundColor: const Color(0xFFD9E4F7),
              color: finished
                  ? const Color(0xFF22A45D)
                  : const Color(0xFF1A3A6B),
            ),
          ),
        ],
      ),
    );
  }
}

/// A numbered step card of the complaint statement.
class _StatementStep extends StatelessWidget {
  const _StatementStep({
    required this.step,
    required this.title,
    required this.complete,
    required this.children,
  });

  final int step;
  final String title;
  final bool complete;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: complete ? const Color(0xFFB8E2C5) : const Color(0xFFD9E4F7),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E2242),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: complete
                      ? const Color(0xFF22A45D)
                      : const Color(0xFF1A3A6B),
                ),
                child: complete
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '$step',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// A value filled in elsewhere on the form, shown for reference.
class _LinkedValue extends StatelessWidget {
  const _LinkedValue({
    required this.label,
    required this.value,
    required this.emptyHint,
  });

  final String label;
  final String value;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            empty ? Icons.arrow_upward_rounded : Icons.person_outline_rounded,
            size: 18,
            color: empty ? const Color(0xFFB06B00) : const Color(0xFF1A3A6B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7D91B2)),
                ),
                const SizedBox(height: 2),
                Text(
                  empty ? emptyHint : value,
                  style: TextStyle(
                    fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
                    color: empty ? const Color(0xFFB06B00) : null,
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

/// Labelled input used inside the statement steps.
class _StepTextField extends StatelessWidget {
  const _StepTextField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.enabled,
    required this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.showCounter = false,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final bool showCounter;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF49658F),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            counterText: showCounter ? null : '',
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF1F6FF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: border(const Color(0xFFB9D0F5)),
            enabledBorder: border(const Color(0xFFB9D0F5)),
            focusedBorder: border(const Color(0xFF1A3A6B), 1.5),
          ),
        ),
      ],
    );
  }
}

/// Live preview of the complaint statement the barangay will receive.
class _StatementPreview extends StatelessWidget {
  const _StatementPreview({
    required this.name,
    required this.age,
    required this.location,
    required this.respondent,
    required this.respondentLocation,
    required this.reason,
  });

  final String name;
  final String age;
  final String location;
  final String respondent;
  final String respondentLocation;
  final String reason;

  @override
  Widget build(BuildContext context) {
    TextSpan blank(String value) => TextSpan(
          text: value.isEmpty ? '________' : value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: value.isEmpty
                ? const Color(0xFFB0BED3)
                : const Color(0xFF0E2242),
          ),
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E2B6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 18,
                color: Color(0xFFB06B00),
              ),
              SizedBox(width: 8),
              Text(
                'Your complaint will read:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: Color(0xFF334155),
                height: 1.55,
                fontSize: 14,
              ),
              children: [
                const TextSpan(text: 'Ako po hi '),
                blank(name),
                const TextSpan(text: ', '),
                blank(age),
                const TextSpan(text: ' anyos, ngan naukoy ha '),
                blank(location),
                const TextSpan(text: '. Ginrereklamo ko hi '),
                blank(respondent),
                const TextSpan(text: ', nga naukoy ha '),
                blank(respondentLocation),
                const TextSpan(text: ', tungod '),
                blank(reason),
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
}

class _InputShell extends StatelessWidget {
  const _InputShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E4F7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0E2242),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

InputDecoration _fieldDecoration({String? hintText}) {
  const noBorder = OutlineInputBorder(
    borderSide: BorderSide.none,
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  return InputDecoration(
    hintText: hintText,
    border: noBorder,
    enabledBorder: noBorder,
    focusedBorder: noBorder,
    errorBorder: noBorder,
    focusedErrorBorder: noBorder,
    filled: false,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 14),
  );
}
