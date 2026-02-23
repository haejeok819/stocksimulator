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
      allow read, write: if request.auth != null && request.auth.uid == uid; // uid 필드를 문서 데이터에 별도 저장하지 않아도 동작

      match /records/{docId} {
        allow read, write: if request.auth != null && request.auth.uid == uid; // uid 필드를 문서 데이터에 별도 저장하지 않아도 동작
      }

      match /game_point_ledger/{docId} {
        allow read, write: if request.auth != null && request.auth.uid == uid; // uid 필드를 문서 데이터에 별도 저장하지 않아도 동작
      }
    }
  }
}
```

추가 참고: 게임 포인트 지갑(`/users/{uid}`)과 `game_point_ledger`는 트랜잭션으로 갱신되므로, 규칙에서 `request.resource.data.uid == uid` 같은 필드 강제를 두면 쓰기가 거부될 수 있습니다.

## 4) 현재 앱 정책
- Android/iOS: 구글 로그인 실제 연동
- Windows/Web: Firebase 로그인 미사용(기존 정책 유지)

## 5) Windows 링크 에러(LNK2019/LNK2001) 대응
Firebase C++ 정적 라이브러리 링크 에러가 나면, 이 저장소 정책상 **Windows용 Firebase 플러그인을 제외한 로컬 fork**를 사용해야 합니다.

1. Pub cache에 Firebase 패키지가 존재하는 상태에서 아래 스크립트 실행
   ```bash
   ./scripts/prepare_firebase_nowindows_overrides.sh
   ```
2. `pubspec.yaml`의 `dependency_overrides`가 아래 경로를 가리키는지 확인
   - `third_party/firebase_core_nowindows`
   - `third_party/firebase_auth_nowindows`
   - `third_party/cloud_firestore_nowindows`
3. Windows 빌드 캐시 정리 후 재빌드
   - `flutter clean`
   - `flutter pub get`
   - `flutter run -d windows`

> 주의: 모바일(Android/iOS) 실제 로그인은 유지되고, Windows는 Firebase 네이티브 링크를 타지 않도록 설계되어 있습니다.
