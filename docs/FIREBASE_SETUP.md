# Firebase setup

LaMP signs people in with **Google** or a **phone number and code**, and stores which seat
each person holds in **Cloud Firestore**. This is what to do once, in the Firebase console and
on your machine, to make that work. The code is already in the app; it runs on a local
stand-in until these steps are done (debug builds only).

Package names: Android `com.lamp.bcolbd.lamp_flutter`, iOS `com.lamp.bcolbd.lampFlutter`.

## One person, once: the Firebase project

1. **Create the project.** console.firebase.google.com → Add project. Name it, for example,
   `lamp-bcolbd`. Turn Google Analytics off (not needed).
2. **Add teammates.** Project settings (gear) → Users and permissions → Add member → Editor.
3. **Turn on the sign-in methods.** Build → Authentication → Get started → Sign-in method:
   - **Google:** Enable, choose a project support email, Save.
   - **Phone:** Enable, Save.
4. **Add test phone numbers** (Phone → *Phone numbers for testing*), for example
   `+8801711204488` with code `123456`. Firebase sends no SMS for these, so they are free and
   need no billing. Use them for every demo and test. Add one number per person you want to
   sign in as.
5. **Create the database.** Build → Firestore Database → Create database → *Production mode*
   → pick a nearby region (for example `asia-south1`).

Real SMS to real phones is billed. Check Authentication → Usage and the project's plan before
depending on it, and prefer test numbers.

## Every developer, on their own machine

The Android app is identified to Firebase by its signing key's **fingerprint**. Each machine's
debug key is different, so each developer adds their own.

1. **Get your fingerprints** (Windows; use the JDK's `keytool`):

   ```bash
   keytool -list -v -alias androiddebugkey -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android -keypass android
   ```

   Copy the `SHA1` and `SHA256` lines.
2. **Add them.** Project settings → Your apps → the Android app (add it first if it is not
   there: package `com.lamp.bcolbd.lamp_flutter`) → *Add fingerprint*, once for SHA-1 and once
   for SHA-256.
3. **Windows only: turn on Developer Mode** (Settings → System → For developers). Flutter
   needs symlinks to build with plugins, and Firebase adds several.
4. **Log in and generate the config:**

   ```bash
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<your-project-id> --yes
   ```

   This writes `lib/firebase_options.dart`, `android/app/google-services.json` and
   `firebase.json`. Re-run it after adding fingerprints so `google-services.json` carries the
   Google client. Commit these files; they identify the project and are not secrets.
5. **Publish the database rules** (once per project, by whoever owns it):

   ```bash
   firebase deploy --only firestore:rules
   ```

   `firebase.json` must point at the rules file; `flutterfire configure` does not add that, so
   the setup adds a `"firestore": { "rules": "firestore.rules" }` entry.
6. **Run:** `flutter run --android-skip-build-dependency-validation`.

On the emulator, add a Google account (Settings → Passwords & accounts) to use Google sign-in.

## What lives where

| Thing | Where |
|---|---|
| Who someone is | Firebase Authentication (Google or phone) |
| Which seat they hold | Firestore `users/{uid}` |
| Which pharmacy / round is taken | Firestore `claims/{id}`, written once |
| The rules for all of it | `firestore.rules` |

Anyone can register as any role, including regulator or bank. Nothing verifies who they are.
That is a known prototype limit.

## If something fails

| Symptom | Likely cause |
|---|---|
| Google sign-in fails at once, "developer error" in the log | The SHA-1 is not added, or `google-services.json` predates it. Add it, re-run `flutterfire configure`, rebuild. |
| Phone sign-in says the app is not authorised | The SHA-1 / SHA-256 is missing for this machine. |
| A phone number does not accept `123456` | It is not listed under *Phone numbers for testing*, or it is written differently. Use the exact `+880…` form. |
| Registering fails with a generic message | The Firestore rules are not published yet (`firebase deploy --only firestore:rules`). |
| The build fails in a Firebase plugin with "compiled with an incompatible version of Kotlin" | The Kotlin Gradle plugin is too old. It is pinned in `android/settings.gradle.kts` (currently 2.3.0). |
| The build fails with "Using 'jvmTarget: String' is an error" | Kotlin 2.2+ removed `kotlinOptions`. `android/app/build.gradle.kts` already uses the `compilerOptions` form; do not put the old one back. |
| Gradle dies with "daemon disappeared unexpectedly" and an `hs_err_pid*.log` in `android/` | The machine ran out of memory. The log says "insufficient memory" and shows `AvailPageFile` near 0. Stop leftover build JVMs (`android\gradlew.bat --stop`, then end any `KotlinCompileDaemon` java process in Task Manager), close the emulator for the build, or enlarge the Windows pagefile. Heap limits are in `android/gradle.properties`. |
| The app starts on the local stand-in | Debug build with no `firebase_options.dart` configured. Run `flutterfire configure`. |
| Release build will not start | Firebase is not configured. Release builds never use the local stand-in. |
