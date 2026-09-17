# Habit Tracker — Bug Fixes Applied

## Fixed in source

1. **App icon / app name**
   - Android launcher now uses a Habit Tracker vector icon.
   - Android label is `Habit Tracker`.
   - Flutter/web/desktop visible product names were updated where applicable.

2. **Notifications**
   - Added notification initialization and Android 13+ permission request.
   - Added Android scheduled-notification receivers and boot rescheduling.
   - Habit reminders are scheduled at **8:00 PM local device time** by default.
   - Daily habits repeat daily; specific-day habits repeat on selected weekdays.
   - Added a notification channel with high importance.

3. **Home redesign**
   - Added profile avatar to the welcome area.
   - Added a daily scratch-card quote at the top.
   - Reworked streak highlights into a compact momentum card.

4. **Progress ranges**
   - Week / Month / Year / All time calculations use different date windows and rhythm aggregation.

5. **Achievements**
   - Added additional milestones: 50/100 completion days, Habit Collector, and 100 Wins.
   - Updated profile achievement total.

6. **Profile / avatar persistence**
   - Profile name/avatar changes are backed by Hive and listened to by dependent screens.
   - Gallery images are copied into the app's private documents directory instead of relying on the original gallery path.
   - Added a larger Avatar Studio preset set with illustrated/emoji-style avatars.

7. **Themes**
   - Added: System default, Clean Light, Midnight Neon, Ocean Breeze, Forest Calm, Sunset Glow, Lavender.
   - System mode now correctly follows the Android system light/dark setting.
   - Light theme was rebuilt with a cleaner neutral background and readable surfaces.

8. **Navigation-bar overlap**
   - Main navigation no longer extends over screen content, preventing the bottom of cards/content from being hidden behind the navigation bar.

9. **First-run profile setup**
   - Removed the hardcoded testing name as the default profile.
   - Fresh installs now ask for the user's own name.
   - Existing installations carrying the old test name are migrated to the first-run profile setup when onboarding has not been completed.
   - The name is stored locally on the device.

10. **Loading screen**
    - Added rotation, scale, progress, and animated loading dots to make startup more responsive.

11. **Note deletion**
    - Fixed the nullable `copyWith` bug that prevented a note from being cleared.

12. **Seven selected weekdays**
    - Selecting all seven specific weekdays is normalized to `Every day`, with the weekday list cleared from the saved habit.

13. **Daily quotes**
    - Quotes are deterministic by date and persist after being revealed, so the same quote remains visible for that day and changes on the next day.

## Authentication note

The supplied project does **not contain a backend/authentication provider or account model**. A real Google/Apple/email sign-in system cannot be safely implemented without choosing an authentication/backend provider and supplying its project configuration. The hardcoded shared testing name has therefore been removed and replaced with local first-run profile setup, which prevents that name from appearing on fresh client installations.

## Build note

The available environment did not contain the Flutter SDK, so I could not run `flutter pub get`, `flutter analyze`, or produce a fresh APK here. Run `flutter pub get` before building the updated APK; this will update `pubspec.lock` for the newly added dependencies.
