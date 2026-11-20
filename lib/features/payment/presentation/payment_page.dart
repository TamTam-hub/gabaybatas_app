import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/gb_blue_header.dart';
import '../../track/data/case_service.dart';

/// Pay the filing fee through GCash, then send the receipt screenshot.
/// Pops with the barangay's message once the payment is sent.
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key, required this.caseId});

  /// The case number (for example C-0007).
  final String caseId;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static const int _maxImageBytes = 8 * 1024 * 1024;
  static const Color _navy = Color(0xFF1A4CA3);
  static const Color _ink = Color(0xFF1C2F52);
  static const Color _muted = Color(0xFF5F7396);

  final CaseService _service = CaseService();
  final TextEditingController _referenceController = TextEditingController();

  PaymentInfo? _info;
  Uint8List? _qr;
  String? _error;
  bool _isLoading = true;
  bool _isSending = false;
  XFile? _screenshot;
  Uint8List? _screenshotBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final info = await _service.loadPaymentInfo(widget.caseId);
      Uint8List? qr;
      if (info.qrAvailable) {
        try {
          qr = await _service.loadPaymentQr();
        } on ApiException {
          qr = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _info = info;
        _qr = qr;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(String value, String what) async {
    await Clipboard.setData(ClipboardData(text: value));
    _showMessage('$what copied.');
  }

  Future<void> _pickScreenshot() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['jpg', 'jpeg', 'png', 'webp'],
    );
    if (!mounted || files.isEmpty) return;
    final file = files.first.xFile;
    if (await file.length() > _maxImageBytes) {
      _showMessage('${file.name} is larger than 8 MB.');
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _screenshot = file;
      _screenshotBytes = bytes;
    });
  }

  Future<void> _submit() async {
    final file = _screenshot;
    if (file == null || _isSending) return;
    setState(() => _isSending = true);
    try {
      final message = await _service.submitPayment(
        caseId: widget.caseId,
        screenshotPath: file.path,
        referenceNumber: _referenceController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(message);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _showMessage(error.message);
    }
  }

  /// Saves the QR to the phone, so it can be uploaded in GCash's "Scan QR".
  Future<void> _downloadQr() async {
    final qr = _qr;
    if (qr == null) return;
    final isPng = qr.length > 4 && qr[0] == 0x89 && qr[1] == 0x50;
    try {
      final saved = await FilePicker.saveFile(
        fileName: 'GabayBatas-GCash-QR.${isPng ? 'png' : 'jpg'}',
        bytes: qr,
        mimeType: isPng ? 'image/png' : 'image/jpeg',
        dialogTitle: 'Save the GCash QR',
      );
      if (saved != null) _showMessage('QR code saved.');
    } catch (_) {
      _showMessage('Unable to save the QR code. Take a screenshot instead.');
    }
  }

  void _enlargeQr() {
    final qr = _qr;
    if (qr == null) return;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: InteractiveViewer(
                maxScale: 4,
                child: Image.memory(qr, fit: BoxFit.contain),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GbBlueHeader(
            title: 'Pay Filing Fee',
            showBack: true,
            onBack: () => Navigator.of(context).pop(),
            description:
                'Pay through GCash, then send a screenshot of the receipt. Your complaint is accepted once the barangay verifies the payment.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final info = _info;
    if (_error != null || info == null) {
      return _Notice(
        icon: Icons.wifi_off_rounded,
        color: const Color(0xFFB91C1C),
        background: const Color(0xFFFEF2F2),
        title: 'Unable to load the payment details',
        message: _error ?? 'Please try again.',
        action: TextButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    if (!info.paymentRequired) {
      return const _Notice(
        icon: Icons.check_circle_rounded,
        color: Color(0xFF047857),
        background: Color(0xFFECFDF5),
        title: 'No payment needed',
        message: 'This case does not need a filing fee right now.',
      );
    }
    if (info.latestStatus == 'submitted') {
      return const _Notice(
        icon: Icons.hourglass_top_rounded,
        color: Color(0xFF1D4ED8),
        background: Color(0xFFEFF6FF),
        title: 'Payment sent',
        message:
            'The barangay is checking your payment. Your complaint will be accepted once it is verified.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (info.latestStatus == 'rejected') ...[
          _Notice(
            icon: Icons.error_outline_rounded,
            color: const Color(0xFFB45309),
            background: const Color(0xFFFFFBEB),
            title: 'Your last payment was not verified',
            message: info.latestRejectReason.isNotEmpty
                ? '${info.latestRejectReason}\nPlease pay again and send the new receipt.'
                : 'Please pay again and send the new receipt.',
          ),
          const SizedBox(height: 14),
        ],
        _Card(
          heading: 'Send payment',
          children: [
            const Text('Amount to pay', style: TextStyle(color: _muted)),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    info.amountLabel,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1.1,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copy(info.amountDigits, 'Amount'),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy amount'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _navy,
                    side: const BorderSide(color: Color(0xFFB9D0F5)),
                    shape: const StadiumBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: _qr != null
                        ? GestureDetector(
                            onTap: _enlargeQr,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _qr!,
                                height: 260,
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'The QR code is not available. Send to the number below.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _muted),
                            ),
                          ),
                  ),
                  // Wraps onto two lines when the phone uses large text.
                  if (_qr != null)
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        children: [
                          TextButton.icon(
                            onPressed: _enlargeQr,
                            icon: const Icon(
                              Icons.open_in_full_rounded,
                              size: 18,
                            ),
                            label: const Text('Enlarge QR'),
                          ),
                          TextButton.icon(
                            onPressed: _downloadQr,
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Download QR'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  _InfoLine(label: 'Account name', value: info.accountName),
                  _InfoLine(
                    label: 'Mobile number',
                    value: info.number,
                    onCopy: () => _copy(info.number, 'Number'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'In GCash, scan or upload the QR, or send to the number above. Then take a screenshot of the receipt.',
              style: TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Card(
          heading: 'Upload screenshot',
          children: [
            InkWell(
              onTap: _isSending ? null : _pickScreenshot,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _screenshot != null
                        ? _navy
                        : const Color(0xFFB9D0F5),
                    width: 1.4,
                  ),
                ),
                child: _screenshotBytes != null
                    ? Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              _screenshotBytes!,
                              height: 220,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap to choose a different screenshot',
                            style: TextStyle(color: _navy, fontSize: 12.5),
                          ),
                        ],
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 26),
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: _navy,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Upload screenshot',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'The GCash receipt, JPG or PNG',
                              style: TextStyle(color: _muted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Reference number',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF49658F),
                    ),
                  ),
                ),
                Text('Optional', style: TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _referenceController,
              enabled: !_isSending,
              keyboardType: TextInputType.number,
              maxLength: 64,
              decoration: InputDecoration(
                hintText: 'e.g. 1234 567 891011',
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF1F6FF),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: _border(const Color(0xFFB9D0F5)),
                enabledBorder: _border(const Color(0xFFB9D0F5)),
                focusedBorder: _border(const Color(0xFF1F5BC4), 1.5),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _screenshot == null || _isSending ? null : _submit,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isSending ? 'Sending...' : 'Submit Payment'),
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            if (_screenshot == null) ...[
              const SizedBox(height: 8),
              const Text(
                'Add the screenshot first.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.heading, required this.children});

  final String heading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EAF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            heading.toUpperCase(),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Color(0xFF49658F),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value, this.onCopy});

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF5F7396), fontSize: 12.5),
          ),
          Row(
            children: [
              Flexible(
                child: Text(
                  value.isNotEmpty ? value : '—',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2F52),
                  ),
                ),
              ),
              if (onCopy != null && value.isNotEmpty)
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF3B4D6E),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
