import 'package:flutter_test/flutter_test.dart';
import 'package:gabaybatas_app/features/track/data/case_service.dart';

CaseSummary _case(String kpStatus, Map<String, dynamic>? payment) {
  return CaseSummary.fromJson(<String, dynamic>{
    'case_row_id': 7,
    'case_id': 'C-0007',
    'reference_number': 'C-0007',
    'kp_status': kpStatus,
    'payment': payment,
    'evidence': <dynamic>[],
  });
}

void main() {
  group('filing fee', () {
    test('a case awaiting the fee with no payment yet needs one', () {
      final item = _case('awaiting_payment', <String, dynamic>{
        'required': true,
        'amount_label': '₱200',
        'status': 'none',
      });
      expect(item.needsPayment, isTrue);
      expect(item.paymentPending, isFalse);
      expect(item.kpStatusDisplay, 'Filing Fee Needed');
      expect(item.payment?.amountLabel, '₱200');
      expect(item.progressStep, 1);
    });

    test('a payment being checked does not ask to pay again', () {
      final item = _case('awaiting_payment', <String, dynamic>{
        'required': true,
        'amount_label': '₱200',
        'status': 'submitted',
      });
      expect(item.needsPayment, isFalse);
      expect(item.paymentPending, isTrue);
      expect(item.kpStatusDisplay, 'Payment Being Checked');
    });

    test('a rejected payment asks to pay again and keeps the reason', () {
      final item = _case('awaiting_payment', <String, dynamic>{
        'required': true,
        'amount_label': '₱200',
        'status': 'rejected',
        'reject_reason': 'The amount did not arrive.',
      });
      expect(item.needsPayment, isTrue);
      expect(item.payment?.rejectReason, 'The amount did not arrive.');
    });

    test('an accepted case with a verified payment needs nothing', () {
      final item = _case('accepted', <String, dynamic>{
        'required': false,
        'amount_label': '₱200',
        'status': 'verified',
      });
      expect(item.needsPayment, isFalse);
      expect(item.paymentPending, isFalse);
    });

    test('cases without a filing fee have no payment', () {
      final item = _case('mediation_scheduled', null);
      expect(item.payment, isNull);
      expect(item.needsPayment, isFalse);
    });

    test('payment details: amount digits for pasting in GCash', () {
      final info = PaymentInfo.fromJson(<String, dynamic>{
        'case_id': 'C-0007',
        'payment_required': true,
        'amount_label': '₱1,200',
        'account_name': 'Juan Dela Cruz',
        'number': '09170000000',
        'qr_available': true,
        'note': 'C-0007',
        'latest_payment': <String, dynamic>{
          'status': 'rejected',
          'reject_reason': 'Blurry screenshot',
        },
      });
      expect(info.amountDigits, '1200');
      expect(info.latestStatus, 'rejected');
      expect(info.latestRejectReason, 'Blurry screenshot');
      expect(info.qrAvailable, isTrue);
    });
  });
}
