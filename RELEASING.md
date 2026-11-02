# Releasing a new version of the GabayBatas app

Installed apps check GitHub Releases of this repository when they open. When a
release with a higher version is published, residents see **Update available**
and download the new APK from the release.

## Before the first release on a computer

- The release signing key lives outside the repository, in
  `C:\Users\ACER\gabaybatas-signing\`. Keep at least two backups of that folder.
  Every release must be signed with the same key, or phones refuse the update.
- `android/key.properties` points to the key. It is git-ignored; never commit it,
  the `.jks` file, or the key password.

## Steps for each release

1. **Raise the version** in `pubspec.yaml`. Both numbers go up:
   `version: 1.0.1+2` → `version: 1.0.2+3`
   (`1.0.2` is shown to residents; `+3` is Android's build number and must always increase).
2. **Check and build:**
   ```
   flutter analyze
   flutter test
   flutter build apk --release
   ```
   The APK is `build/app/outputs/flutter-apk/app-release.apk`.
3. **Commit and push** the changes.
4. **Publish the release on GitHub:** repository → **Releases** → **Draft a new release**
   - **Tag:** `v1.0.2` (the same version as `pubspec.yaml`, with a `v`)
   - **Title:** `GabayBatas 1.0.2`
   - **Description:** what changed, in plain words. Residents see it in the update prompt.
   - **Attach** the APK, renamed to `gabaybatas-v1.0.2.apk`
   - Leave **Set as a pre-release** unticked, then **Publish release**.
5. Open the app on a phone with the previous version: the update prompt should appear.
   (Profile → **Check for updates** checks on demand.)

## Notes

- Drafts and pre-releases are ignored by the update check, so a release can be
  prepared as a draft and published when ready.
- The app talks to `https://gabaybatas.com` in release builds and to the laptop
  (XAMPP) in debug builds (`lib/core/config/app_config.dart`).
