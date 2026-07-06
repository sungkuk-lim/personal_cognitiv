# GitHub Pages — 모담넷 홈페이지·정책 공개

**브랜드:** theNext_modamnet  
**GitHub 조직/계정:** `theNext-modamnet` (GitHub 사용자명에는 `_` 불가 → **하이픈** 사용)

**공개 URL (저장소 `theNext-modamnet/personal_cognitiv` 기준):**

```
https://thenext-modamnet.github.io/personal_cognitiv/
https://thenext-modamnet.github.io/personal_cognitiv/privacy.html
https://thenext-modamnet.github.io/personal_cognitiv/terms.html
https://thenext-modamnet.github.io/personal_cognitiv/user_guide.html
```

앱 기본 URL: `lib/core/app_urls.dart` (동일 주소)

---

## GitHub 조직 이전 (sungkuk-lim → theNext-modamnet)

코드·문서 URL은 이미 `theNext-modamnet` 기준으로 맞춰 두었습니다. **실제 사이트가 열리려면** GitHub에서 아래를 진행하세요.

1. https://github.com/organizations/plan → **Free** 조직 생성  
   - Organization name: **`theNext-modamnet`** (표시 이름은 `theNext_modamnet` 가능)
2. `sungkuk-lim/personal_cognitiv` → **Settings → General → Transfer ownership** → `theNext-modamnet` 조직으로 이전  
   (또는 조직에 새로 push 후 Pages만 활성화)
3. https://github.com/organizations/theNext-modamnet/settings/pages → **GitHub Actions** 소스 선택
4. `main` push 후 Actions에서 `Deploy GitHub Pages` 성공 확인

이전 전까지는 기존 `sungkuk-lim.github.io/...` URL도 동작할 수 있습니다. Play 등록은 **이전 완료 후** 새 URL을 사용하세요.

### URL을 더 짧게 (선택)

저장소 이름을 `theNext-modamnet.github.io`로 바꾸고 `docs/`를 루트에 두면:

```
https://thenext-modamnet.github.io/privacy.html
```

---

## 방법 A — GitHub Actions (권장)

1. GitHub 저장소 → **Settings → Pages**
2. **Build and deployment** → Source: **GitHub Actions**
3. `docs/` 변경 후 `main` 브랜치에 push
4. Actions 워크플로 `.github/workflows/pages.yml` 자동 배포

```powershell
cd d:\android\personal_cognitiv
.\scripts\deploy_pages.ps1
```

배포 완료: **Actions** 탭에서 `Deploy GitHub Pages` 확인

---

## 방법 B — 브랜치 배포 (수동)

1. https://github.com/theNext-modamnet/personal_cognitiv/settings/pages
2. Source: **Deploy from a branch**
3. Branch: **main** / Folder: **/docs**
4. Save

---

## gh CLI (선택)

```powershell
. .\scripts\use_gh.ps1
gh auth login
```

## 4. 로컬에서만 준비 (이미 완료)

- `docs/privacy.html` — 정책 본문
- `docs/user_guide.html` — 이용 가이드
- `docs/index.html` — 랜딩·링크 허브
- `docs/.nojekyll` — Jekyll 비활성화

## 5. 정책 수정 시

`docs/privacy.html` 수정 → commit → push → Pages 자동 갱신

Play Console **개인정보처리방침 URL:**  
`https://thenext-modamnet.github.io/personal_cognitiv/privacy.html`
