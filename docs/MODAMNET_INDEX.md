# 모담넷(MemoryOS) 문서 색인

**시작:** [TOTAL.md](TOTAL.md) — SaaS·Play·무료/Pro·관계망 AI·홈페이지 **종합**

---

## 상용화 · 비즈니스

| 문서 | 내용 |
|------|------|
| [TOTAL.md](TOTAL.md) | 요금·입금·영수증·Play·95% 기준 |
| [PLAY_CONSOLE_SETUP.md](PLAY_CONSOLE_SETUP.md) | Play 구독·정산 단계별 |
| [SAAS_SETUP.md](SAAS_SETUP.md) | RevenueCat·Supabase·쿼터 기술 설정 |
| [STORE_READINESS.md](STORE_READINESS.md) | 스토어 문구·스크린샷·카테고리 |
| [PLAY_STORE_AND_SAAS_MASTER_GUIDE.md](PLAY_STORE_AND_SAAS_MASTER_GUIDE.md) | **95%→출시→SaaS 종합 실행 가이드** |
| [SOFT_LAUNCH_7DAY.md](SOFT_LAUNCH_7DAY.md) | 출시 7일 일정 |
| [COMMERCIALIZATION_90_SPRINT.md](COMMERCIALIZATION_90_SPRINT.md) | 90% 스프린트 체크리스트 |

## QA · 배포

| 문서 | 내용 |
|------|------|
| [QA_CHECKLIST.md](QA_CHECKLIST.md) | 실기기 QA |
| [DEPLOY.md](../DEPLOY.md) | Supabase SQL·Edge·빌드 |
| [GITHUB_PAGES.md](GITHUB_PAGES.md) | 정책 URL 배포 |

## 제품 · UX

| 문서 | 내용 |
|------|------|
| [MODAMNET_USER_GUIDE.md](MODAMNET_USER_GUIDE.md) | 사용자 가이드 |
| [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) | 테마·타이포 |
| [GRAPH_VISION_CHECKLIST.md](GRAPH_VISION_CHECKLIST.md) | 관계망 비전 |
| [GRAPH_UX_GAP_ANALYSIS.md](GRAPH_UX_GAP_ANALYSIS.md) | 관계망 UX 갭 |

## 법적 · 정책

| 문서 | 내용 |
|------|------|
| [PRIVACY_POLICY.md](PRIVACY_POLICY.md) | 개인정보 처리방침 원문 |
| [privacy.html](privacy.html) | Play용 HTML |
| [terms.html](terms.html) | 이용약관 HTML |

## 인프라

| 문서 | 내용 |
|------|------|
| [FIREBASE_SETUP.md](FIREBASE_SETUP.md) | Crashlytics |

---

## 코드 기준점

| 항목 | 위치 |
|------|------|
| 완성도 95% | `lib/core/app_maturity.dart` |
| Pro 쿼터 | `lib/core/subscription_config.dart` |
| 무료/Pro 게이트 | `requiresProCloudForCloudFeatures` |
| 관계망 AI 스위치 | `settings_screen.dart` + `settings_plan_cards.dart` |
| Paywall | `lib/features/subscription/paywall_sheet.dart` |
