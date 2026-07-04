# 모담넷(MemoryOS) 디자인 시스템 — 최소 스펙 (1페이지)

**구현:** `lib/core/app_theme.dart` · `lib/core/graph_theme.dart` (색은 `AppGraphColors`)

---

## 1. 색 (Color)

| 토큰 | 용도 | 값 |
|------|------|-----|
| `colorSchemeSeed` | 앱 전역 (설정에서 변경 가능) | 기본 `Colors.deepPurple` |
| `AppGraphColors.person` | 사람 노드 | `#E91E63` |
| `AppGraphColors.place` | 장소 노드 | `#00897B` |
| `AppGraphColors.memory` | 기억 허브 | `#5C6BC0` |
| `AppGraphColors.semanticEdge` | AI 유사 링크 | `#7E57C2` |
| `AppGraphColors.relationEdge` | 관계 라벨 엣지 | `#2E7D32` |
| `AppGraphColors.bridgeEdge` | 클러스터 브리지 | `#FFB300` |

**규칙:** 화면 UI는 `Theme.of(context).colorScheme` 우선. 그래프만 `AppGraphColors` 허용.

---

## 2. 타이포 (Typography)

Material 3 `textTheme` + 아래 오버라이드 (`AppTheme.theme`):

| 스타일 | 크기 | 용도 |
|--------|------|------|
| `headlineSmall` | M3 기본 | 온보딩 제목 |
| `titleLarge` | M3 + w700 | 시트 제목 |
| `bodyLarge` | 16px | 타임라인 본문 |
| `bodyMedium` | 15px | 설정·가이드 |
| `labelLarge` | w600 | 칩·버튼 |
| `labelSmall` | 11px | 메타·날짜 |

### 관계망 노드 (최소 가독)

| 요소 | API | 크기 |
|------|-----|------|
| 노드 제목 | `AppTheme.graphNodeTitle` | 11~12px |
| 노드 메타 | `AppTheme.graphNodeMeta` | 10px |

**규칙:** 그래프 노드에 9px 미만 금지. `textScaleFactor` 대응은 Phase 2.

---

## 3. 모서리 (Radius)

| 토큰 | 값 | 용도 |
|------|-----|------|
| `AppTheme.radiusSheet` | 24 | 바텀 시트 |
| `AppTheme.radiusCard` | 16 | 카드 |
| `AppTheme.radiusChip` | 12 | 칩·버튼·입력 |

---

## 4. 컴포넌트

| 컴포넌트 | 스펙 |
|----------|------|
| **FilledButton** | padding 20×14, radius 12 |
| **Card** | elevation 0, outline `outlineVariant` |
| **Chip** | radius 12 |
| **TextField** | filled, radius 12, `surfaceContainerHighest` |
| **BottomSheet** | drag handle, top radius 24 |
| **SnackBar** | floating, radius 12 |

---

## 5. 시트 패턴

- 온보딩·설정 가이드·관계망 온보딩: `showModalBottomSheet` + `AppTheme.radiusSheet`
- 긴 정책·도움말: `DraggableScrollableSheet` initial 0.85
- AI 노드 시트: transparent (기존 유지)

---

## 6. l10n

- 사용자 문자열: `lib/l10n/translations.dart` only
- `localeCode == 'ko' ? ... : ...` 인라인 **금지** (그래프 허브 모드 등 정리 완료)

---

## 7. 적용 체크리스트 (화면별)

| 화면 | AppTheme | l10n | 그래프 색 |
|------|----------|------|-----------|
| app.dart | ✅ | — | — |
| relationship_graph_screen | ✅ 부분 | ✅ | ✅ |
| memory_card | ⬜ | ✅ | — |
| cognitive_search_screen | ⬜ | ⬜ | — |
| settings_screen | ⬜ | ✅ | — |
| onboarding_sheet | ✅ | ✅ | — |

**스프린트 2:** 타임라인·검색·설정 나머지 `Theme.of(context).textTheme` 전환.

---

## 8. 다크 모드

- `AppTheme.theme(brightness: dark)` — Material 3 자동
- 그래프 노드 onPhoto: 흰색 텍스트 고정 (가독)
