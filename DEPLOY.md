# MemoryOS 배포 가이드

## 1. Supabase SQL 실행

```bash
supabase db query --linked -f supabase/migrations/001_user_rls.sql
supabase db query --linked -f supabase/migrations/002_drop_legacy_policies.sql
supabase db query --linked -f supabase/migrations/003_memory_images_storage.sql
```

또는 Supabase SQL Editor에서 위 파일들을 순서대로 실행하세요.

## 2. Edge Function 배포 (API 키 보호)

```bash
supabase secrets set OPENAI_API_KEY=sk-...
supabase functions deploy openai-proxy
```

## 3. Flutter 빌드

```powershell
.\scripts\run_dev.ps1
```

또는:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key \
  --dart-define=USE_EDGE_PROXY=true
```

## 4. Android 릴리스 APK

```powershell
.\scripts\create_keystore.ps1
copy android\key.properties.example android\key.properties
# key.properties 비밀번호 수정 후
.\scripts\run_dev.ps1 -Release
```

## 5. 커스텀 SMTP (이메일 한도 해결)

Supabase 기본 이메일은 **시간당 2통** 제한이 있습니다.

1. [Resend](https://resend.com) 또는 SendGrid 등 SMTP 계정 생성
2. Supabase → **Authentication** → **SMTP Settings**
3. **Enable Custom SMTP** → Host, Port, Username, Password, Sender 입력
4. 개발 중에는 **Confirm email OFF** 권장

## 6. 기능 요약

- 로그인 / **게스트 모드** (기기 전용, 로그인 없이)
- RLS + Edge Function API 보호
- 선제적 회상 (포그라운드 + **백그라운드 15분 주기**)
- 썸네일 **Supabase Storage 백업** (재설치 후 복원)
- 프라이버시 모드, 대화형 검색, 회상 탭
- 설정 → **개인정보 처리방침**
- GitHub Actions CI (`flutter analyze` + `test`)

## 7. 기존 데이터

RLS 적용 후 `user_id`가 NULL인 행은 보이지 않습니다. 필요 시 본인 UUID로 UPDATE 하세요.
