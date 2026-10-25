import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gb_dropdown.dart';
import '../../about/data/profile_service.dart';
import '../../auth/data/auth_service.dart';
import '../../chat/data/chat_service.dart';
import '../../info/data/knowledge_base_service.dart';
import '../../notifications/data/notification_service.dart';
import '../../submit_case/data/submit_case_service.dart';
import '../../track/data/case_service.dart';

class ApiSmokeTestPage extends StatefulWidget {
  const ApiSmokeTestPage({super.key});

  @override
  State<ApiSmokeTestPage> createState() => _ApiSmokeTestPageState();
}

class _ApiSmokeTestPageState extends State<ApiSmokeTestPage> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final CaseService _caseService = CaseService();
  final NotificationService _notificationService = NotificationService();
  final ChatService _chatService = ChatService();
  final SubmitCaseService _submitCaseService = SubmitCaseService();
  final KnowledgeBaseService _knowledgeBaseService = KnowledgeBaseService();

  final TextEditingController _fullNameController = TextEditingController(
    text: 'Mobile API Tester',
  );
  final TextEditingController _ageController = TextEditingController(
    text: '28',
  );
  final TextEditingController _phoneController = TextEditingController(
    text: '+63 912 345 6789',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: 'Password123!',
  );

  bool _isRunning = false;
  String _generatedEmail = _buildGeneratedEmail();
  List<_StepResult> _results = const <_StepResult>[];

  String _selectedBarangay = AppConfig.supportedBarangay;

  static String _buildGeneratedEmail() {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'smoke.$stamp@gabaybatas.local';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _runSmokeTest() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _results = const <_StepResult>[];
    });

    final List<_StepResult> nextResults = <_StepResult>[];
    final String testEmail = _generatedEmail;
    List<ChatThread> threads = const <ChatThread>[];

    Future<bool> runStep(String title, Future<void> Function() action) async {
      try {
        await action();
        nextResults.add(_StepResult.success(title, 'OK'));
        if (mounted) {
          setState(() {
            _results = List<_StepResult>.from(nextResults);
          });
        }
        return true;
      } on ApiException catch (error) {
        nextResults.add(_StepResult.failure(title, error.message));
      } catch (error) {
        nextResults.add(_StepResult.failure(title, error.toString()));
      }

      if (mounted) {
        setState(() {
          _results = List<_StepResult>.from(nextResults);
        });
      }
      return false;
    }

    final bool registerOk = await runStep('1. Register ($testEmail)', () {
      return _authService.register(
        fullName: _fullNameController.text.trim(),
        age: _ageController.text.trim(),
        barangay: _selectedBarangay,
        contactNumber: _phoneController.text.trim(),
        email: testEmail,
        password: _passwordController.text,
        confirmPassword: _passwordController.text,
      );
    });

    if (registerOk) {
      final bool loginOk = await runStep('2. Login ($testEmail)', () {
        return _authService.login(
          email: testEmail,
          password: _passwordController.text,
        );
      });

      if (loginOk) {
        final bool fetchOk = await runStep('3. Fetch profile', () async {
          final data = await _profileService.fetchProfile();
          if (data == null) {
            throw ApiException('Profile response is empty.');
          }
        });

        if (fetchOk) {
          final bool profileUpdateOk = await runStep('4. Update profile', () {
            return _profileService.updateProfile(
              ProfileData(
                name: '${_fullNameController.text.trim()} API',
                email: testEmail,
                phone: _phoneController.text.trim(),
                age: _ageController.text.trim(),
                barangay: _selectedBarangay,
              ),
            );
          });

          if (profileUpdateOk) {
            await runStep('5. Submit case', () async {
              await _submitCaseService.submitCase(
                name: _fullNameController.text.trim(),
                complainantAddress:
                    'Smoke Test Address, Barangay Muñoz, Catbalogan City, Samar',
                complainantLocation: 'Barangay Muñoz',
                complainantAge: _ageController.text.trim(),
                complainedPerson: 'Smoke Test Respondent',
                respondentAddress:
                    'Respondent Address, Barangay Muñoz, Catbalogan City, Samar',
                respondentLocation: 'Barangay Muñoz',
                barangay: _selectedBarangay,
                contact: _phoneController.text.trim(),
                caseType: 'Public Disturbance',
                description:
                    'Smoke test case submission for backend validation.',
              );
            });

            await runStep('6. Search knowledge base', () async {
              await _knowledgeBaseService.searchArticles(search: 'property');
            });

            await runStep('7. List cases', () async {
              await _caseService.listCases(limit: 10, offset: 0);
            });

            await runStep('8. List notifications', () async {
              await _notificationService.listNotifications(
                limit: 10,
                offset: 0,
                unreadOnly: false,
              );
            });

            final bool threadsOk = await runStep(
              '9. List chat threads',
              () async {
                threads = await _chatService.listThreads(limit: 10, offset: 0);
              },
            );

            if (threadsOk) {
              if (threads.isNotEmpty) {
                await runStep('10. Load first thread messages', () async {
                  await _chatService.listMessages(
                    threadId: threads.first.threadId,
                    limit: 20,
                    offset: 0,
                  );
                });
              } else {
                nextResults.add(
                  _StepResult.success(
                    '10. Load first thread messages',
                    'Skipped (no threads available).',
                  ),
                );
                if (mounted) {
                  setState(() {
                    _results = List<_StepResult>.from(nextResults);
                  });
                }
              }
            }
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Smoke Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            title: 'Target Server',
            lines: <String>[
              'Base URL: ${AppConfig.apiBaseUrl}',
              'Register: ${AuthService.registerPath}',
              'Login: ${AuthService.loginPath}',
              'Profile (GET/PUT): ${ProfileService.profilePath}',
              'Submit case: ${SubmitCaseService.submitPath}',
              'Knowledge base: ${KnowledgeBaseService.path}',
              'Cases list: ${CaseService.listPath}',
              'Notifications: ${NotificationService.notificationsPath}',
              'Chat threads: ${ChatService.threadsPath}',
              'Chat messages: ${ChatService.messagesPath}',
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Test Payload',
            lines: const <String>[
              'A fresh email is generated each run to avoid duplicate-user conflicts.',
            ],
            child: Column(
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Age'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: GbDropdown(
                        items: AppConfig.supportedBarangays,
                        value: _selectedBarangay,
                        label: 'Barangay',
                        prefixIcon: Icons.location_on_outlined,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedBarangay = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Generated test email: $_generatedEmail',
                    style: const TextStyle(color: Color(0xFF4F678C)),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isRunning
                          ? null
                          : () {
                              setState(() {
                                _generatedEmail = _buildGeneratedEmail();
                              });
                            },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Generate New Email'),
                    ),
                    FilledButton.icon(
                      onPressed: _isRunning ? null : _runSmokeTest,
                      icon: _isRunning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        _isRunning
                            ? 'Running...'
                            : 'Run Integration Smoke Test',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: 'Results',
            lines: _results.isEmpty
                ? const <String>[
                    'No run yet. Tap "Run Integration Smoke Test" to start.',
                  ]
                : _results
                      .map(
                        (r) =>
                            '${r.ok ? 'PASS' : 'FAIL'} - ${r.title}: ${r.message}',
                      )
                      .toList(),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.lines, this.child});

  final String title;
  final List<String> lines;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: const TextStyle(color: Color(0xFF4F678C)),
              ),
            ),
          ),
          if (child != null) ...[const SizedBox(height: 8), child!],
        ],
      ),
    );
  }
}

class _StepResult {
  const _StepResult({
    required this.title,
    required this.message,
    required this.ok,
  });

  final String title;
  final String message;
  final bool ok;

  factory _StepResult.success(String title, String message) {
    return _StepResult(title: title, message: message, ok: true);
  }

  factory _StepResult.failure(String title, String message) {
    return _StepResult(title: title, message: message, ok: false);
  }
}
