import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/gb_blue_header.dart';
import '../../submit_case/presentation/submit_case_page.dart';

/// Where to bring a concern, decided by a few yes/no questions.
class _GuideOutcome {
  const _GuideOutcome({
    required this.office,
    required this.headline,
    required this.reason,
    required this.steps,
    required this.basis,
    required this.icon,
    required this.color,
    this.callEmergency = false,
    this.canSubmitCase = false,
  });

  final String office;
  final String headline;
  final String reason;
  final List<String> steps;
  final String basis;
  final IconData icon;
  final Color color;
  final bool callEmergency;
  final bool canSubmitCase;
}

class _GuideChoice {
  const _GuideChoice(this.label, {this.outcome});

  final String label;

  /// Null means "go to the next question".
  final _GuideOutcome? outcome;
}

class _GuideQuestion {
  const _GuideQuestion({
    required this.question,
    required this.help,
    required this.icon,
    required this.choices,
  });

  final String question;
  final String help;
  final IconData icon;
  final List<_GuideChoice> choices;
}

const _red = Color(0xFFD93025);
const _purple = Color(0xFF7B3FC4);
const _orange = Color(0xFFB06B00);
const _blue = Color(0xFF2F6EFF);
const _green = Color(0xFF168548);

const _emergency = _GuideOutcome(
  office: 'Call 911 or the nearest PNP station',
  headline: 'Get help now',
  reason:
      'When someone is in danger or a crime is happening, call the police first. The barangay process is for settling disputes, not emergencies.',
  steps: [
    'Call 911 or go to the nearest police station.',
    'Stay safe and keep away from the person causing harm.',
    'When it is safe, you may also inform the barangay.',
  ],
  basis: 'Emergency response is a police matter; RA 7160, Sec. 412(b) allows urgent cases to go directly to court.',
  icon: Icons.local_police_outlined,
  color: _red,
  callEmergency: true,
);

const _vawc = _GuideOutcome(
  office: 'Barangay VAW Desk or PNP Women and Children Protection Desk',
  headline: 'This is not for barangay mediation',
  reason:
      'Violence or abuse against a woman or her child is a VAWC case. Barangay officials are not allowed to mediate it, but the Barangay VAW Desk can issue a Barangay Protection Order right away.',
  steps: [
    'Go to the Barangay VAW Desk to ask for a Barangay Protection Order, or to the PNP Women and Children Protection Desk.',
    'Bring any proof you have: medical certificate, photos, messages, names of witnesses.',
    'For abuse of a child, you may also go to the city social welfare office.',
    'Call 911 if you are in immediate danger.',
  ],
  basis: 'RA 9262 (Anti-VAWC Act), Secs. 14 and 33; RA 7610 (child protection); RA 7160, Sec. 408.',
  icon: Icons.shield_outlined,
  color: _purple,
  callEmergency: true,
);

const _agency = _GuideOutcome(
  office: 'The proper government agency or the court',
  headline: 'The barangay cannot settle this',
  reason:
      'Complaints involving a corporation or other juridical person, the government, or a public officer acting in their official job are not covered by barangay conciliation.',
  steps: [
    'For complaints about products or services of a business, go to the Department of Trade and Industry (DTI).',
    'For complaints against a government office or official, go to the agency concerned or the court.',
    'You may ask the Public Attorney\'s Office (PAO) for free legal advice.',
  ],
  basis: 'RA 7160, Sec. 408(a) and (b); SC Administrative Circular No. 14-93.',
  icon: Icons.account_balance_outlined,
  color: _orange,
);

const _dole = _GuideOutcome(
  office: 'Department of Labor and Employment (DOLE)',
  headline: 'Work problems go to DOLE',
  reason:
      'Disputes between an employer and an employee, such as unpaid wages or illegal dismissal, are labor disputes and are not covered by barangay conciliation.',
  steps: [
    'Go to the nearest DOLE office and request assistance (Single Entry Approach).',
    'Bring your payslips, contract, ID and any messages with your employer.',
  ],
  basis: 'SC Administrative Circular No. 14-93; RA 10396 (Single Entry Approach).',
  icon: Icons.work_outline_rounded,
  color: _orange,
);

const _dar = _GuideOutcome(
  office: 'Department of Agrarian Reform (DAR)',
  headline: 'Farmland disputes go to the DAR',
  reason:
      'Disputes over agricultural land under agrarian reform are agrarian disputes and are not covered by barangay conciliation.',
  steps: [
    'Go to the Municipal or Provincial Agrarian Reform Office.',
    'Bring your land documents, certificates of land ownership award, and any agreements.',
  ],
  basis: 'SC Administrative Circular No. 14-93 (disputes under the Comprehensive Agrarian Reform Law).',
  icon: Icons.agriculture_outlined,
  color: _orange,
);

const _cyber = _GuideOutcome(
  office: 'PNP Anti-Cybercrime Group or NBI Cybercrime Division',
  headline: 'Online offenses may be cybercrimes',
  reason:
      'Threats, scams and defamation committed online may be punished under the Cybercrime Prevention Act, with heavier penalties than the same acts done offline.',
  steps: [
    'Take screenshots showing the account name, the message and the date.',
    'Report to the PNP Anti-Cybercrime Group or the NBI Cybercrime Division.',
    'If it is a minor problem with a neighbor, the barangay can still help you talk it out.',
  ],
  basis: 'RA 10175 (Cybercrime Prevention Act of 2012).',
  icon: Icons.wifi_tethering_error_rounded,
  color: _orange,
);

const _otherCity = _GuideOutcome(
  office: 'Usually the court or prosecutor, not the barangay',
  headline: 'Different city, different rule',
  reason:
      'Barangay conciliation covers people who live in the same city or municipality. The exception: if you live in adjoining barangays of different cities and both of you agree, the barangay may still handle it.',
  steps: [
    'If your barangays are next to each other and the other person agrees, you may file at the barangay.',
    'Otherwise, you may file your case directly with the court or the prosecutor.',
    'Ask the Public Attorney\'s Office (PAO) for free legal advice.',
  ],
  basis: 'RA 7160, Sec. 408(f); SALIGAN KP Handbook (2022), p. 26.',
  icon: Icons.location_city_outlined,
  color: _orange,
);

const _police = _GuideOutcome(
  office: 'PNP and the Office of the Prosecutor',
  headline: 'Serious crimes go to the police',
  reason:
      'Offenses punishable by more than 1 year in prison or a fine of more than ₱5,000 are not covered by barangay conciliation.',
  steps: [
    'Report to the nearest police station and have the incident recorded in the blotter.',
    'Get a medical certificate for injuries and keep all evidence.',
    'The police or the prosecutor will handle the complaint.',
  ],
  basis: 'RA 7160, Sec. 408(c); Revised Penal Code, Arts. 9 and 25–27.',
  icon: Icons.gavel_rounded,
  color: _red,
  callEmergency: true,
);

const _barangay = _GuideOutcome(
  office: 'Barangay Muñoz — Lupong Tagapamayapa',
  headline: 'Start at the barangay',
  reason:
      'Disputes and minor offenses between people living in the same city must go through barangay conciliation first, at the barangay where the other person lives (or where the land, workplace or school is). It is free, fast, and you do not need a lawyer. If your complaint is not covered after all, the barangay will tell you where to bring it.',
  steps: [
    'Submit your complaint in this app or at the Barangay Hall.',
    'The barangay summons the other person on the next working day.',
    'You meet before the Punong Barangay to try to settle within 15 days.',
  ],
  basis:
      'RA 7160, Secs. 408, 409 and 412; SC Administrative Circular No. 14-93.',
  icon: Icons.handshake_outlined,
  color: _green,
  canSubmitCase: true,
);

const _otherBarangay = _GuideOutcome(
  office: 'The barangay where the other person lives',
  headline: 'File where the other person lives',
  reason:
      'When you live in different barangays of the same city, the complaint is brought to the barangay where the person you are complaining about lives. If there are several of them, you may choose the barangay of any one of them.',
  steps: [
    'Go to the Barangay Hall of the barangay where the other person lives and ask for the Lupon Secretary.',
    'Bring a valid ID and any proof you have, such as photos, receipts, messages or names of witnesses.',
    'Exceptions: a dispute about land is filed where the land is located, and a dispute that arose at a workplace or school is filed in the barangay where that workplace or school is.',
  ],
  basis: 'RA 7160, Sec. 409(a)–(d); SALIGAN KP Handbook (2022).',
  icon: Icons.signpost_outlined,
  color: _blue,
);

const List<_GuideQuestion> _questions = [
  _GuideQuestion(
    question: 'Is someone in danger right now, or is a crime happening?',
    help: 'For example: an ongoing fight, a threat with a weapon, or a break-in.',
    icon: Icons.emergency_outlined,
    choices: [
      _GuideChoice('Yes', outcome: _emergency),
      _GuideChoice('No'),
    ],
  ),
  _GuideQuestion(
    question: 'Does it involve violence or abuse against a woman or a child?',
    help: 'Physical, sexual, psychological or economic abuse by a partner, or abuse of a child.',
    icon: Icons.shield_outlined,
    choices: [
      _GuideChoice('Yes', outcome: _vawc),
      _GuideChoice('No'),
    ],
  ),
  _GuideQuestion(
    question: 'Is the other party a company, store or government office?',
    help: 'Also choose Yes if it is a public officer acting in their official job.',
    icon: Icons.apartment_rounded,
    choices: [
      _GuideChoice('Yes', outcome: _agency),
      _GuideChoice('No, a private person'),
    ],
  ),
  _GuideQuestion(
    question: 'Is it about your work with an employer, or about farmland?',
    help: 'Unpaid wages, dismissal, or agrarian reform land.',
    icon: Icons.work_outline_rounded,
    choices: [
      _GuideChoice('About work', outcome: _dole),
      _GuideChoice('About farmland', outcome: _dar),
      _GuideChoice('No, it is something else'),
    ],
  ),
  _GuideQuestion(
    question: 'Did it happen online?',
    help: 'Through social media, chat, text or e-mail.',
    icon: Icons.phone_android_rounded,
    choices: [
      _GuideChoice('Yes', outcome: _cyber),
      _GuideChoice('No'),
    ],
  ),
  _GuideQuestion(
    question: 'Does the other person live in Catbalogan City?',
    help: 'You both need to live in the same city for barangay conciliation.',
    icon: Icons.location_on_outlined,
    choices: [
      _GuideChoice('Yes'),
      _GuideChoice('No', outcome: _otherCity),
    ],
  ),
  _GuideQuestion(
    question: 'Is it a serious crime?',
    help: 'Serious injuries, robbery, high-value theft, illegal drugs, rape or killing.',
    icon: Icons.report_gmailerrorred_rounded,
    choices: [
      _GuideChoice('Yes', outcome: _police),
      _GuideChoice('No, it is a dispute or minor offense'),
      _GuideChoice('Not sure'),
    ],
  ),
  _GuideQuestion(
    question: 'Does the other person live in Barangay Muñoz?',
    help:
        'The complaint is filed at the barangay where the person you are complaining about lives.',
    icon: Icons.home_outlined,
    choices: [
      _GuideChoice('Yes', outcome: _barangay),
      _GuideChoice(
        'No, but it is about land located in Barangay Muñoz',
        outcome: _barangay,
      ),
      _GuideChoice(
        'No, but it happened at a workplace or school in Barangay Muñoz',
        outcome: _barangay,
      ),
      _GuideChoice('No, they live in another barangay', outcome: _otherBarangay),
    ],
  ),
];

class ReportGuidePage extends StatefulWidget {
  const ReportGuidePage({super.key});

  @override
  State<ReportGuidePage> createState() => _ReportGuidePageState();
}

class _ReportGuidePageState extends State<ReportGuidePage> {
  final List<int> _history = <int>[];
  int _index = 0;
  _GuideOutcome? _outcome;

  void _choose(_GuideChoice choice) {
    setState(() {
      _history.add(_index);
      if (choice.outcome != null) {
        _outcome = choice.outcome;
      } else {
        _index++;
      }
    });
  }

  void _back() {
    if (_history.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _outcome = null;
      _index = _history.removeLast();
    });
  }

  void _restart() {
    setState(() {
      _history.clear();
      _index = 0;
      _outcome = null;
    });
  }

  Future<void> _callEmergency() async {
    final launched = await launchUrl(Uri(scheme: 'tel', path: '911'));
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone app. Dial 911.')),
      );
    }
  }

  void _submitCase() {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubmitCasePage(
          onSubmitted: (message) => messenger.showSnackBar(
            SnackBar(content: Text(message), backgroundColor: _green),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GbBlueHeader(
            title: 'Where should I report?',
            titleFontSize: 26,
            description: 'Answer a few quick questions to find the right office.',
            showBack: true,
            onBack: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 16),
          if (outcome == null)
            _buildQuestion(_questions[_index])
          else
            _buildOutcome(outcome),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuestion(_GuideQuestion q) {
    final progress = (_index + 1) / _questions.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${_index + 1} of ${_questions.length}',
                  style: const TextStyle(
                    color: Color(0xFF6A7FA3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_history.isNotEmpty)
                TextButton.icon(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Previous'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFD9E4F7),
              color: _blue,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF5FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(q.icon, color: _blue),
                ),
                const SizedBox(height: 14),
                Text(
                  q.question,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  q.help,
                  style: const TextStyle(color: Color(0xFF6680A5), height: 1.4),
                ),
                const SizedBox(height: 18),
                for (final choice in q.choices) ...[
                  _ChoiceButton(label: choice.label, onTap: () => _choose(choice)),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcome(_GuideOutcome o) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: o.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: o.color.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: o.color,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(o.icon, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        o.headline,
                        style: TextStyle(
                          color: o.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Go to',
                  style: TextStyle(color: Color(0xFF6A7FA3), fontSize: 12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  o.office,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  o.reason,
                  style: const TextStyle(color: Color(0xFF415A82), height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What to do',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < o.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: o.color,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            o.steps[i],
                            style: const TextStyle(
                              color: Color(0xFF415A82),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.menu_book_outlined, size: 16, color: _blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Legal basis: ${o.basis}',
                        style: const TextStyle(
                          color: Color(0xFF6680A5),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (o.callEmergency)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.icon(
                onPressed: _callEmergency,
                icon: const Icon(Icons.call_rounded),
                label: const Text('Call 911'),
                style: FilledButton.styleFrom(
                  backgroundColor: _red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          if (o.canSubmitCase)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.icon(
                onPressed: _submitCase,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Submit a Case'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1F49D8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Start over'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Change my last answer'),
          ),
          const SizedBox(height: 6),
          const Text(
            'This guide gives general information, not legal advice.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8FA3C7), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F6FF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFB9D0F5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F49D8),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8FA3C7)),
            ],
          ),
        ),
      ),
    );
  }
}
