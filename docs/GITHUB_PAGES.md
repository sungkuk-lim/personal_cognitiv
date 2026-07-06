# GitHub Pages — 모담넷 홈페이지·정책 공개

**브랜드:** theNext_modamnet  
**GitHub 조직/계정 (목표):** `theNext-modamnet` (GitHub는 `_` 불가 → **하이픈**)

---

## 지금 바로 쓸 URL (조직 이전 전 · 동작 중)

저장소가 아직 `sungkuk-lim` 계정에 있으므로 **Play Console·앱 배포는 아래 주소를 사용**하세요.

```
https://sungkuk-lim.github.io/personal_cognitiv/
https://sungkuk-lim.github.io/personal_cognitiv/privacy.html
https://sungkuk-lim.github.io/personal_cognitiv/terms.html
https://sungkuk-lim.github.io/personal_cognitiv/user_guide.html
```

배포 방식: **Settings → Pages → Deploy from branch → main /docs** (이미 설정됨)

---

## 목표 URL (조직 이전 후)

```
https://thenext-modamnet.github.io/personal_cognitiv/
https://thenext-modamnet.github.io/personal_cognitiv/privacy.html
https://thenext-modamnet.github.io/personal_cognitiv/terms.html
```

앱 코드 기본값: `lib/core/app_urls.dart` (이전 완료 후 자동 일치)

---

## 나중에 할 일 — theNext-modamnet 조직 (본인 GitHub 로그인 필요)

1. https://github.com/organizations/plan → Free 조직 **`theNext-modamnet`** 생성
2. `personal_cognitiv` 저장소 → Settings → Transfer ownership → 조직으로 이전
3. 조직 저장소 → Settings → Pages → branch `main` / folder `docs`
4. Play Console URL을 `thenext-modamnet.github.io/...` 로 변경

> Cursor/CI에서 조직 생성·이전은 **대신 할 수 없습니다** (본인 계정 인증 필요).

---

## CI / Pages 워크플로

| 워크플로 | 역할 |
|----------|------|
| `flutter_ci.yml` | analyze + test (push 시) |
| `pages.yml` | **수동만** (`workflow_dispatch`) — branch 배포와 충돌 방지 |

`docs/` 수정 후 push하면 **branch Pages가 자동 갱신**됩니다. `pages.yml` Actions 배포는 조직 이전 후 필요 시 Settings에서 GitHub Actions 소스로 바꾼 뒤 수동 실행.

---

## 정책 수정 시

`docs/privacy.html` · `terms.html` 수정 → commit → push → 1~2분 후 반영
