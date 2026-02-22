# Firebase Google Login 설정 체크리스트

## 1) Firebase 콘솔
1. Firebase 프로젝트 생성
2. Authentication > Sign-in method > Google 활성화
3. Android 앱 등록 (패키지명 확인)
4. Android SHA-1 / SHA-256 등록 (debug/release 권장)
5. iOS 사용 시 앱 등록 및 `GoogleService-Info.plist` 준비

## 2) FlutterFire 설정
1. `firebase login`
2. `dart pub global activate flutterfire_cli`
3. 프로젝트 루트에서 `flutterfire configure`
4. 산출물 확인
   - `lib/firebase_options.dart` (생성 권장)
   - `android/app/google-services.json`
   - (iOS) `ios/Runner/GoogleService-Info.plist`

## 3) Firestore Rules (최소)
```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;

      match /records/{docId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }
  }
}
```

## 4) 현재 앱 정책
- Android/iOS: 구글 로그인 실제 연동
- Windows/Web: Firebase 로그인 미사용(기존 정책 유지)
