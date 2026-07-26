# MemoryOS 개인정보 처리방침

**최종 업데이트:** 2026년 7월  
**운영자:** theNext · 문의: imsk0126@gmail.com

웹 공개본: https://sungkuk-lim.github.io/personal_cognitiv/privacy.html

## 1. 수집하는 정보

| 항목 | 목적 | 보관 |
|------|------|------|
| 이메일·비밀번호 | 계정 인증 | Supabase (클라우드) |
| 음성·텍스트 기억 | 저장·AI 분류·검색 | 클라우드 또는 기기만(프라이버시/게스트) |
| 사진·동영상·썸네일 | 타임라인·회상 | 기기 + 클라우드 Storage (선택) |
| 위치(선택) | 기억 장소 태그·장소 회상 알림 | 기억 데이터·백그라운드 위치(허용 시) |
| 연락처(선택) | 관계망 사람 노드 아바타 | 기기에서만 읽기, 서버 미업로드 |
| 구독·결제 상태 | Pro 기능 제공 | RevenueCat·Google Play·Supabase |
| 크래시 로그 | 앱 안정성 | Firebase Crashlytics |
| 마이크·카메라 | 기억 입력 | 처리 후 원본은 저장하지 않음(썸네일만) |

## 2. 제3자 제공

- **Supabase**: 인증·데이터베이스·파일 저장
- **OpenAI**: 기억 분류·검색·사진 분석 (Edge Function 경유, 프라이버시/게스트 모드 제외)
- **Google Firebase**: 앱 안정성(Crashlytics) — 크래시·오류 로그 수집
- **RevenueCat / Google Play**: 구독 결제

## 3. 사용자 권리

- 설정에서 **프라이버시 모드**: 새 기억을 기기에만 저장
- **게스트 모드**: 로그인 없이 기기 전용 사용
- 계정 삭제: 앱 **설정 → 프라이버시·계정 → 계정 삭제** (또는 문의: imsk0126@gmail.com)

## 4. 보안

- 사용자별 Row Level Security(RLS)로 타인 기억 접근 차단
- OpenAI API 키는 서버(Edge Function)에만 보관

## 5. 문의

개인정보 관련 문의: imsk0126@gmail.com
