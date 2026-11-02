import 'package:flutter_test/flutter_test.dart';
import 'package:gabaybatas_app/core/update/update_service.dart';

Map<String, dynamic> release(String tag, {List<Map<String, dynamic>>? assets}) => {
      'tag_name': tag,
      'body': 'Bug fixes',
      'html_url': 'https://github.com/TamTam-hub/gabaybatas_app/releases/tag/$tag',
      'draft': false,
      'prerelease': false,
      'assets': assets ??
          [
            {'name': 'gabaybatas-$tag.apk', 'browser_download_url': 'https://example.com/$tag.apk'},
          ],
    };

void main() {
  group('isNewer compares version parts as numbers', () {
    test('newer patch, minor and major', () {
      expect(UpdateService.isNewer('1.0.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewer('1.1.0', '1.0.9'), isTrue);
      expect(UpdateService.isNewer('2.0.0', '1.9.9'), isTrue);
      expect(UpdateService.isNewer('1.0.10', '1.0.9'), isTrue);
    });
    test('same or older is not an update', () {
      expect(UpdateService.isNewer('1.0.1', '1.0.1'), isFalse);
      expect(UpdateService.isNewer('1.0.0', '1.0.1'), isFalse);
      expect(UpdateService.isNewer('1.0.1+5', '1.0.1'), isFalse);
      expect(UpdateService.isNewer('', '1.0.0'), isFalse);
    });
  });

  test('a newer release points to its APK', () {
    final update = UpdateService.updateFromRelease(release('v1.0.2'), '1.0.1');
    expect(update, isNotNull);
    expect(update!.version, '1.0.2');
    expect(update.downloadUrl, 'https://example.com/v1.0.2.apk');
    expect(update.notes, 'Bug fixes');
  });

  test('no APK attached falls back to the release page', () {
    final update = UpdateService.updateFromRelease(release('v1.0.2', assets: []), '1.0.1');
    expect(update!.downloadUrl, contains('/releases/tag/v1.0.2'));
  });

  test('the same version, drafts and pre-releases are ignored', () {
    expect(UpdateService.updateFromRelease(release('v1.0.1'), '1.0.1'), isNull);
    expect(UpdateService.updateFromRelease({...release('v9.0.0'), 'prerelease': true}, '1.0.1'), isNull);
    expect(UpdateService.updateFromRelease({...release('v9.0.0'), 'draft': true}, '1.0.1'), isNull);
  });
}
