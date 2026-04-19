import 'package:flutter/material.dart';

import '../../../core/config/case_types.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gb_blue_header.dart';
import '../../../core/widgets/gb_dropdown.dart';
import '../../about/data/profile_service.dart';
import '../data/submit_case_service.dart';

class SubmitCasePage extends StatefulWidget {
  const SubmitCasePage({super.key});

  @override
  State<SubmitCasePage> createState() => _SubmitCasePageState();
}

class _SubmitCasePageState extends State<SubmitCasePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _complainedPerson = TextEditingController();
  final _contact = TextEditingController();
  final _description = TextEditingController();
  final ProfileService _profileService = ProfileService();
  final SubmitCaseService _submitCaseService = SubmitCaseService();

  bool _isSubmitting = false;
  bool _isLoadingProfile = false;
  bool _showValidationErrors = false;

  String _barangay = 'Barangay Mu\u00f1oz';
  String _caseType = 'Public Disturbance';

  static const List<String> _barangays = <String>[
    'Barangay Mu\u00f1oz',
    'Barangay San Pablo',
    'Barangay Burak',
    'Barangay 1',
    'Barangay 2',
    'Barangay 3',
    'Barangay 4',
    'Barangay 5',
  ];

  static const List<String> _caseTypes = kCaseTypes;

  @override
  void initState() {
    super.initState();
    _loadProfileDefaults();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _complainedPerson.dispose();
    _contact.dispose();
    _description.dispose();
    super.dispose();
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
        if (profile.barangay.isNotEmpty && _barangays.contains(profile.barangay)) {
          _barangay = profile.barangay;
        }
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

  Future<void> _submitCase() async {
    if (_isSubmitting) return;

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
        complainedPerson: _complainedPerson.text.trim(),
        barangay: _barangay,
        contact: _contact.text.trim(),
        caseType: _caseType,
        description: _description.text.trim(),
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Case submitted'),
            content: Text(
              'Your case was submitted successfully.\n\nCase ID: ${result.referenceNumber}\nStatus: ${result.status}',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      _description.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Case ${result.referenceNumber} submitted successfully.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Case submission failed. Please try again.')),
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
    final selectedBarangay = _barangays.contains(_barangay) ? _barangay : _barangays.first;
    final selectedCaseType = _caseTypes.contains(_caseType) ? _caseType : _caseTypes.first;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GbBlueHeader(
            title: 'Submit a Case',
            subtitle: 'Step 1 of 1',
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
          Form(
            key: _formKey,
            autovalidateMode:
                _showValidationErrors ? AutovalidateMode.always : AutovalidateMode.disabled,
            child: Column(
              children: [
                const _FieldLabel(icon: Icons.person_outline_rounded, label: 'Full Name'),
                _InputShell(
                  child: TextFormField(
                    controller: _fullName,
                    enabled: !_isSubmitting,
                    decoration: _fieldDecoration(hintText: 'Enter your full name'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                GbDropdownField(
                  label: 'Barangay',
                  icon: Icons.location_on_outlined,
                  items: _barangays,
                  value: selectedBarangay,
                  enabled: !_isSubmitting,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _barangay = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
                const _FieldLabel(
                  icon: Icons.gavel_rounded,
                  label: 'Person Being Complained',
                ),
                _InputShell(
                  child: TextFormField(
                    controller: _complainedPerson,
                    enabled: !_isSubmitting,
                    decoration: _fieldDecoration(hintText: 'Full name of respondent'),
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
                const _FieldLabel(icon: Icons.call_outlined, label: 'Contact Number'),
                _InputShell(
                  child: TextFormField(
                    controller: _contact,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.phone,
                    decoration: _fieldDecoration(hintText: '+63 912 345 6789'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (value.trim().length < 10) {
                        return 'Invalid';
                      }
                      return null;
                    },
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
                const _FieldLabel(icon: Icons.subject_rounded, label: 'Description'),
                _InputShell(
                  child: TextFormField(
                    controller: _description,
                    enabled: !_isSubmitting,
                    minLines: 5,
                    maxLines: 7,
                    decoration: _fieldDecoration(
                      hintText: 'Describe your legal concern in detail...',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (value.trim().length < 10) {
                        return 'Please add more details';
                      }
                      return null;
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Provide as much detail as possible to help us understand your case better.',
                    style: TextStyle(color: Color(0xFF7D91B2)),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submitCase,
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
                      label: Text(_isSubmitting ? 'Submitting...' : 'Submit Case'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1F49D8),
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
          Icon(icon, color: const Color(0xFF2F6EFF), size: 18),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
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
            color: Color(0x0D1F49D8),
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

