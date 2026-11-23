PROJECT: VirtuSpace Smart Collaboration Platform for a college. Roles: student, teacher (faculty), innovator. Faculty guide student teams through 3-month project batches.

STACK LOCK (never change): Flutter + Dart Android app, Firebase Auth, Cloud Firestore, Firebase Storage, Firebase Cloud Messaging, Cloud Functions (Node.js 22, folder functions/), flutter_riverpod, and an OpenAI key stored as a Firebase secret for the 3 AI features. Do NOT add or suggest any other backend, language or framework (no Flask, Python, extra servers, web front end, go_router or other state managers). Allowed extra Flutter packages only: url_launcher, video_player, cached_network_image, and flutter_launcher_icons (dev).

ANDROID ONLY: the app targets Android (emulator and physical phone). Do not build, run or maintain web/Chrome, Linux or Windows targets and never run flutter run -d chrome. Native features (dart:io File, FCM, image_picker, file_picker) are fine.

NAMING: app name VirtuSpace, Dart package virtuspace, Android id com.virtuspace.app. Never use the words FinderX, finderr or BMSCE in code, UI text, docs or comments. Only exception: the Firebase project id finderr-x-bmsce in .firebaserc.

CONSISTENCY RULE: whenever a Firestore field, collection or Cloud Function changes, update in the SAME task: Dart model (fromMap/toMap), repository, providers, UI, firestore.rules (including hasAll/hasOnly lists), firestore.indexes.json, storage.rules, functions code, tests and the README schema. New fields are optional when reading old documents. File names are snake_case and match the class they contain; fix every import after any move or rename. Never leave TODO stubs, fake data or placeholder screens.

DEFINITION OF DONE for each task: flutter pub get, dart fix --apply, flutter analyze (zero errors), flutter test (pass). If functions/ changed also run npm install, npm run lint and npm test inside functions/. Run flutter build apk --debug only when a task says so or when pubspec.yaml or android/ files changed.

DEPLOY AUTOMATION: you may run terminal commands yourself. When firestore.rules, firestore.indexes.json or storage.rules changed, run: firebase deploy --only firestore:rules,firestore:indexes,storage. When functions/ changed, run: firebase deploy --only functions (needs the Blaze plan; if it fails with a billing or plan error, say so clearly and continue). Never commit secrets or *.apk. Keep android/app/google-services.json in the repo (Firebase client config is public) so every teammate can build.

END OF EVERY TASK print: files changed, new Firestore fields/collections, new Cloud Functions, and the manual steps required from me (keep that list as short as possible).
