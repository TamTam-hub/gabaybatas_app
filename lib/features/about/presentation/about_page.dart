import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/widgets/gb_blue_header.dart';
import '../../../core/widgets/gb_dialog.dart';
import '../../../core/validation/input_validators.dart';
import '../data/profile_service.dart';
import '../../auth/presentation/login_page.dart';
import '../../verification/presentation/residency_verification_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController(
    text: AppConfig.supportedBarangay,
  );

  String _selectedBarangay = AppConfig.supportedBarangay;
  bool _isEditingProfile = false;
  bool _isSavingProfile = false;
  bool _isLoadingProfile = false;
  String? _profileError;

  ProfileData? _loadedProfile;
  ProfileData? _editSnapshot;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _barangayController.dispose();
    super.dispose();
  }

  void _toggleEditProfile() {
    if (_isEditingProfile) {
      _restoreProfile(_editSnapshot);
      _editSnapshot = null;
    } else {
      final profile = _loadedProfile;
      if (profile == null) return;
      _editSnapshot = profile;
    }

    setState(() {
      _isEditingProfile = !_isEditingProfile;
    });
  }

  void _restoreProfile(ProfileData? profile) {
    if (profile == null) {
      return;
    }

    _applyProfile(profile);
  }

  void _applyProfile(ProfileData profile) {
    _nameController.text = profile.name;
    _emailController.text = profile.email;
    _phoneController.text = profile.phone;
    _ageController.text = profile.age;
    _barangayController.text = profile.barangay;
    _selectedBarangay = profile.barangay;
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });

    try {
      final profile = await _profileService.fetchProfile();
      if (!mounted) return;
      if (profile == null) {
        throw ApiException('Profile data was not returned by the server.');
      }

      setState(() {
        _loadedProfile = profile;
        _applyProfile(profile);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _profileError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileError = 'Unable to load your profile. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isSavingProfile) return;
    final isValid = _profileFormKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _isSavingProfile = true;
    });

    try {
      final updatedProfile = await _profileService.updateProfile(
        ProfileData(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          age: _ageController.text.trim(),
          barangay: _selectedBarangay,
        ),
      );

      if (!mounted) return;
      setState(() {
        _loadedProfile = updatedProfile;
        _applyProfile(updatedProfile);
        _editSnapshot = null;
        _isEditingProfile = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile update failed. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return GbDialog(
          icon: Icons.logout_rounded,
          title: 'Log out?',
          content: const Text(
            'You will need to sign in again to access your dashboard.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD93025),
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && context.mounted) {
      await SessionStore.clear();
      if (!context.mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(LoginPage.routeName, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const GbBlueHeader(
          title: 'Profile',
          description: 'Manage your account details and app information.',
        ),
        if (_profileError != null)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF2B8B5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFB3261E),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _profileError!,
                    style: const TextStyle(color: Color(0xFF8C1D18)),
                  ),
                ),
                TextButton(
                  onPressed: _isLoadingProfile ? null : _loadProfile,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 11,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2F6EFF), Color(0xFF1F49D8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _nameController.text,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 34 / 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _emailController.text,
                style: const TextStyle(color: Color(0xFF6D7E9A)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Resident • $_selectedBarangay',
                  style: const TextStyle(
                    color: Color(0xFF2F6EFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 11,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'My Information',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (_isEditingProfile)
                    TextButton.icon(
                      onPressed: _toggleEditProfile,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel'),
                    )
                  else
                    TextButton.icon(
                      onPressed: _loadedProfile == null || _isLoadingProfile
                          ? null
                          : _toggleEditProfile,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Form(
                key: _profileFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline_rounded,
                      enabled: _isEditingProfile,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    _ProfileField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.mail_outline_rounded,
                      enabled: _isEditingProfile,
                      keyboardType: TextInputType.emailAddress,
                      validator: InputValidators.email,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileField(
                            controller: _phoneController,
                            label: 'Contact Number',
                            icon: Icons.call_outlined,
                            enabled: _isEditingProfile,
                            keyboardType: TextInputType.phone,
                            validator: InputValidators.phone,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 100,
                          child: _ProfileField(
                            controller: _ageController,
                            label: 'Age',
                            icon: Icons.cake_outlined,
                            enabled: _isEditingProfile,
                            keyboardType: TextInputType.number,
                            validator: InputValidators.age,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _ProfileField(
                      controller: _barangayController,
                      label: 'Barangay',
                      icon: Icons.location_on_outlined,
                      enabled: false,
                    ),
                    if (_isEditingProfile) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSavingProfile ? null : _saveProfile,
                          icon: _isSavingProfile
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(
                            _isSavingProfile ? 'Saving...' : 'Save Changes',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ResidencyVerificationPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Verify Residency'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'About the App',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'GabayBatas is a mobile legal information and referral system designed to help residents submit cases and track progress through the barangay justice system.',
                style: TextStyle(color: Color(0xFF5F7396), height: 1.45),
              ),
              const SizedBox(height: 16),
              const Text(
                'Features',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const _Bullet(
                color: Color(0xFF15B84C),
                text: 'Submit legal cases and concerns',
              ),
              const _Bullet(
                color: Color(0xFF2F6EFF),
                text: 'Track case status in real-time',
              ),
              const _Bullet(
                color: Color(0xFF9B38FF),
                text: 'Access legal information and resources',
              ),
              const _Bullet(
                color: Color(0xFFFF6A00),
                text: 'AI-powered legal assistance chatbot',
              ),
              const SizedBox(height: 16),
              const Text(
                'Contact Information',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Barangay Muñoz\nCatbalogan City, Samar',
                style: TextStyle(color: Color(0xFF5F7396)),
              ),
              const SizedBox(height: 6),
              const Text(
                '+63 921 597 0666',
                style: TextStyle(color: Color(0xFF5F7396)),
              ),
              const SizedBox(height: 6),
              const Text(
                'christianalbos237@gmail.com',
                style: TextStyle(color: Color(0xFF5F7396)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FilledButton.icon(
            onPressed: () => _confirmLogout(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD93025),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log Out'),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9EC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF3D58B)),
          ),
          child: const Text(
            'Legal Disclaimer\nThis application provides general legal information and guidance. It does not constitute legal advice.',
            style: TextStyle(color: Color(0xFFB26400), height: 1.45),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Column(
            children: [
              Text(
                'Made with heart in Catbalogan City',
                style: TextStyle(color: Color(0xFF7C8EAA)),
              ),
              SizedBox(height: 4),
              Text(
                '© 2026 GabayBatas',
                style: TextStyle(color: Color(0xFF7C8EAA)),
              ),
              SizedBox(height: 4),
              Text(
                'Catbalogan City Government',
                style: TextStyle(color: Color(0xFF7C8EAA)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingProfile)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFF5F7396))),
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF8FAFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE5F5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE5F5)),
        ),
      ),
    );
  }
}
