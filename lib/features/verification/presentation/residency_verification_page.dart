// ignore_for_file: deprecated_member_use

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gb_blue_header.dart';
import '../data/residency_verification_service.dart';

class ResidencyVerificationPage extends StatefulWidget {
  const ResidencyVerificationPage({super.key});

  @override
  State<ResidencyVerificationPage> createState() =>
      _ResidencyVerificationPageState();
}

class _ResidencyVerificationPageState extends State<ResidencyVerificationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ResidencyVerificationService _service = ResidencyVerificationService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _last4Controller = TextEditingController();

  static const List<String> _idTypes = [
    'Philippine National ID',
    'Driver\'s License',
    'Passport',
    'Voter\'s ID',
    'Other government ID',
  ];

  String _barangay = AppConfig.supportedBarangay;
  String? _idType;
  XFile? _idDocument;
  XFile? _proofDocument;
  ResidencyVerification? _verification;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadVerification();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    _last4Controller.dispose();
    super.dispose();
  }

  Future<void> _loadVerification() async {
    try {
      final result = await _service.fetchLatest();
      if (!mounted) return;
      setState(() {
        _verification = result;
        if (result != null) {
          _nameController.text = result.fullName;
          _birthDateController.text = result.dateOfBirth;
          _addressController.text = result.completeAddress;
          _last4Controller.text = result.governmentIdLast4;
          _barangay = AppConfig.supportedBarangay;
          _idType = _idTypes.contains(result.governmentIdType)
              ? result.governmentIdType
              : null;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDocument({required bool governmentId}) async {
    final source = await showModalBottomSheet<_DocumentSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Open camera'),
                subtitle: const Text('Take a picture now'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_DocumentSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Choose from files'),
                subtitle: const Text('Select a JPG or PNG picture'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_DocumentSource.files),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted || source == null) return;

    XFile? selectedFile;
    if (source == _DocumentSource.camera) {
      try {
        final image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (image != null) {
          selectedFile = image;
        }
      } on PlatformException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unable to open camera: ${error.message ?? 'camera unavailable'}',
              ),
            ),
          );
        }
      }
    } else {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      if (files.isNotEmpty) {
        selectedFile = files.single.xFile;
      }
    }

    if (!mounted) return;
    if (selectedFile == null && source == _DocumentSource.camera) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No picture was captured. Please try again or choose a file.',
          ),
        ),
      );
      return;
    }
    if (selectedFile == null) return;
    setState(() {
      if (governmentId) {
        _idDocument = selectedFile;
      } else {
        _proofDocument = selectedFile;
      }
    });
  }

  Future<void> _selectBirthDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDate: DateTime(1997),
    );
    if (selected == null || !mounted) return;
    final month = selected.month.toString().padLeft(2, '0');
    final day = selected.day.toString().padLeft(2, '0');
    _birthDateController.text = '${selected.year}-$month-$day';
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final idPath = _idDocument?.path;
    final proofPath = _proofDocument?.path;
    if (idPath == null || proofPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please attach your valid ID and Barangay Indigency picture.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _service.submit(
        fullName: _nameController.text.trim(),
        dateOfBirth: _birthDateController.text.trim(),
        completeAddress: _addressController.text.trim(),
        barangay: _barangay,
        governmentIdType: _idType!,
        governmentIdLast4: _last4Controller.text.trim(),
        idDocumentPath: idPath,
        proofOfResidencePath: proofPath,
      );
      if (!mounted) return;
      setState(() => _verification = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification submitted for review.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submission failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _canSubmit =>
      _verification == null ||
      _verification!.status.toLowerCase() == 'rejected' ||
      _verification!.status.toLowerCase() == 'resubmit';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GbBlueHeader(
            title: 'Verify Residency',
            subtitle: 'Resident verification',
            description:
                'Submit your details and documents for barangay review.',
            showBack: true,
            onBack: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 14),
          if (_verification != null) _StatusCard(verification: _verification!),
          if (_canSubmit) _buildForm(),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Resident details',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: _required,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _birthDateController,
              readOnly: true,
              onTap: _selectBirthDate,
              decoration: const InputDecoration(
                labelText: 'Date of birth',
                prefixIcon: Icon(Icons.cake_outlined),
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 10),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Barangay',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              child: Text(AppConfig.supportedBarangay),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Complete address',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.home_outlined),
              ),
              validator: _required,
            ),
            const SizedBox(height: 18),
            const Text(
              'Government ID',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _idType,
              decoration: const InputDecoration(
                labelText: 'ID type',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: _idTypes
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _idType = value),
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _last4Controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Last four digits of ID (optional)',
                prefixIcon: Icon(Icons.pin_outlined),
                counterText: '',
              ),
              validator: (value) =>
                  value != null &&
                      value.isNotEmpty &&
                      !RegExp(r'^\d{4}$').hasMatch(value)
                  ? 'Enter exactly four numbers'
                  : null,
            ),
            const SizedBox(height: 10),
            _DocumentPicker(
              label: 'Government ID picture',
              file: _idDocument,
              onTap: () => _pickDocument(governmentId: true),
            ),
            const SizedBox(height: 10),
            _DocumentPicker(
              label: 'Barangay Indigency picture',
              file: _proofDocument,
              onTap: () => _pickDocument(governmentId: false),
            ),
            const SizedBox(height: 14),
            const Text(
              'Your documents are private and will only be used by authorized barangay reviewers.',
              style: TextStyle(color: Color(0xFF607A9E), height: 1.35),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_submitting ? 'Submitting...' : 'Submit for review'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.verification});

  final ResidencyVerification verification;

  @override
  Widget build(BuildContext context) {
    final status = verification.status.toLowerCase();
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected' || status == 'resubmit';
    final color = isApproved
        ? const Color(0xFF168548)
        : isRejected
        ? const Color(0xFFC43D35)
        : const Color(0xFFB06B00);
    final title = isApproved
        ? 'Residency verified'
        : isRejected
        ? 'Resubmission required'
        : 'Verification pending';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isApproved
                ? Icons.verified_outlined
                : isRejected
                ? Icons.error_outline
                : Icons.hourglass_top_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (verification.reviewerNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(verification.reviewerNote),
                ],
                if (!isRejected) ...[
                  const SizedBox(height: 4),
                  Text(
                    isApproved
                        ? 'Your residency has been verified. You can now submit cases.'
                        : 'Barangay staff will review your submission.',
                    style: const TextStyle(color: Color(0xFF607A9E)),
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

class _DocumentPicker extends StatelessWidget {
  const _DocumentPicker({
    required this.label,
    required this.file,
    required this.onTap,
  });

  final String label;
  final XFile? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        file == null
            ? Icons.attach_file_rounded
            : Icons.check_circle_outline_rounded,
      ),
      label: Text(
        file == null ? 'Attach $label' : file!.name,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

enum _DocumentSource { camera, files }
