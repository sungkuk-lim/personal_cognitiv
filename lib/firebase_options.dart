// Firebase 설정 파일입니다.
// 실제 프로젝트 연동: `dart run flutterfire_cli:flutterfire configure` 실행 후 이 파일이 자동 갱신됩니다.
// 또는 Firebase Console에서 android/app/google-services.json 을 다운로드하세요.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('MemoryOS는 Android를 우선 지원합니다.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('이 플랫폼은 Firebase를 지원하지 않습니다.');
    }
  }

  // google-services.json 과 동일한 값이어야 합니다 (flutterfire configure로 자동 맞춤)

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCIm7Qpo9OCGyE3UVtUKHo6Ssxk12LLAdo',
    appId: '1:736018937253:android:754a565bdd93fda868244c',
    messagingSenderId: '736018937253',
    projectId: 'memoryos-personal-cognitiv',
    storageBucket: 'memoryos-personal-cognitiv.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyPlaceholder-REPLACE-WITH-FLUTTERFIRE',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'memoryos-personal-cognitiv',
    storageBucket: 'memoryos-personal-cognitiv.firebasestorage.app',
    iosBundleId: 'com.theNext.personalCognitive',
  );
}
