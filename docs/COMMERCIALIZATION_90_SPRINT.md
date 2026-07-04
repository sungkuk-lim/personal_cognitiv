# 상용화 90% 달성 체크리스트 (2주 스프린트)

**목표:** 6개 영역 모두 **90%** — 로컬 Android 소프트 런치 + Pro 게이트 ON + Play 등록 가능  
**기준일:** 2026-07-03

---

## 영역별 목표·현재

| 영역 | 목표 | 스프린트 1 후 | 스프린트 2 후 |
|------|------|---------------|---------------|
| 핵심 루프 | 90% | 88% → 90% | 유지 |
| 관계망 | 90% | 80% → 88% | 90% |
| Flutter 엔지니어링 | 90% | 82% → 86% | 90% |
| 디자인·UX | 90% | 70% → 82% | 90% |
| 상용화 인프라 | 90% | 65% → 88% | 90% |
| iOS | 90% | 50% → 70% | 85~90% |

---

## 스프린트 1 (1주) — P0 + 관계망 신뢰

### P0 (필수)
- [x] `kAppCompletionPercent = 90` — Pro·클라우드 게이트 활성
- [x] `GraphEntityContext` — 배지·위성·엔티티 단일 진실 소스
- [x] `entityLabelReferencedInMemory` — 편집 후 옛 이름 제거
- [x] `visibleGraphSatellitesForMemory` — 배지·노드 일치
- [x] `memory_cloud_sync_service` — 로컬→클라우드 업로드
- [x] 설정 · 개인정보 처리방침 URL (`AppUrls.privacyPolicy`)
- [ ] GitHub Pages에 `docs/privacy.html` 공개 (운영)
- [ ] `QA_CHECKLIST.md` 실기기 전 항목 체크

### 관계망 신뢰·발견성
- [x] 관계망 첫 방문 온보딩 (`graph_onboarding.dart`)
- [x] 관계망 내 엔티티 검색 (`graphEntitySearchProvider`)
- [x] 기간 칩 (7일/30일/90일/전체) — 기존 유지
- [x] `Semantics` 라벨 on 노드
- [x] `userVisibleEntityLabels` — `entityLabelReferencedInMemory` 적용
- [x] `graph_event_layout` — `GraphEntityContext` 통일
- [x] 앱 시작 시 entities 일괄 re-enrich (`memory_entity_reenrich_service.dart`)
- [x] 설정 — 그래프 정리 자동 권장 배너
- [ ] `QA_CHECKLIST.md` 편집→관계망 시나리오 실기기 검증

### 테스트
- [x] `graph_entity_context_test.dart`
- [x] `graph_fragment_freshness_test.dart` 유지
- [x] `graph_entity_audit_test.dart` — stale 엔티티·이벤트 레이아웃
- [x] `memory_entity_reenrich_test.dart`
- [ ] `integration_test/app_smoke_test.dart` CI 연동

---

## 스프린트 2 (2주) — P1 + 디자인 + iOS

### P1
- [x] `AppTheme` — 타이포·칩·버튼·시트 통일 (`lib/core/app_theme.dart`)
- [x] `AppGraphColors` — 관계망 색 팔레트
- [x] l10n: 허브 모드·온보딩·검색 힌트
- [x] `scripts/build_bundle.ps1` — Play AAB
- [ ] `relationship_graph_screen.dart` 위젯 분리 (진행 중)
- [ ] 타임라인·검색 화면 `AppTheme` 전면 적용

### 상용화 인프라
- [x] CI: analyze + test (기존)
- [ ] CI: integration_test (선택)
- [x] `pubspec` description·integration_test 의존성
- [ ] Play Console 스크린샷·등록

### iOS
- [x] `Info.plist` — Always location·UIBackgroundModes
- [ ] TestFlight 빌드·회상 알림 실기기 검증
- [ ] iOS 홈 위젯 (Android 패리티) — Phase 3

---

## 완료 정의 (90% 게이트)

1. **핵심 루프:** 음성·사진 저장 → 타임라인 → 로컬 검색 → 회상 알림 E2E 무크래시  
2. **관계망:** 편집 후 노드·배지 일치, 온보딩·검색·기간 필터 동작  
3. **엔지니어링:** `flutter analyze` 0 error, 도메인 테스트 50+ 통과  
4. **디자인:** `DESIGN_SYSTEM.md` 스펙 준수 (3단 타이포·1색 시드)  
5. **상용화:** Pro 게이트 ON, 정책 URL, AAB 빌드, QA 체크리스트 95%+  
6. **iOS:** 빌드·기본 회상·카메라·마이크 권한 — 위젯은 85%까지 허용

---

## 일일 QA (릴리스 전)

```powershell
flutter test
flutter analyze --no-fatal-infos
.\scripts\qa_release.ps1 -Device <DEVICE_ID>
.\scripts\build_bundle.ps1
```

## 관련 문서

- [GRAPH_UX_GAP_ANALYSIS.md](./GRAPH_UX_GAP_ANALYSIS.md)
- [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md)
- [STORE_READINESS.md](./STORE_READINESS.md)
- [QA_CHECKLIST.md](./QA_CHECKLIST.md)
