# GitHub Pages — 모담넷 홈페이지·정책 공개

**공개 URL (저장소 `sungkuk-lim/personal_cognitiv` 기준):**

```
https://sungkuk-lim.github.io/personal_cognitiv/
https://sungkuk-lim.github.io/personal_cognitiv/privacy.html
https://sungkuk-lim.github.io/personal_cognitiv/terms.html
https://sungkuk-lim.github.io/personal_cognitiv/user_guide.html
```

앱 기본 URL: `lib/core/app_urls.dart` (동일 주소)

---

## 방법 A — GitHub Actions (권장)

1. GitHub 저장소 → **Settings → Pages**
2. **Build and deployment** → Source: **GitHub Actions**
3. `docs/` 변경 후 `main` 브랜치에 push
4. Actions 워크플로 `.github/workflows/pages.yml` 자동 배포

```powershell
cd d:\android\personal_cognitiv
git add docs/ .github/workflows/pages.yml
git commit -m "docs: update site and enable Pages workflow"
git push origin main
```

배포 완료: **Actions** 탭에서 `Deploy GitHub Pages` 확인

---

## 방법 B — 브랜치 배포 (수동)

1. https://github.com/sungkuk-lim/personal_cognitiv/settings/pages
2. Source: **Deploy from a branch**
3. Branch: **main** / Folder: **/docs**
4. Save

---

## 1. GitHub CLI (gh) 준비

설치 후 `gh` 명령이 안 되면 **PowerShell을 새로 열거나** 아래 실행:

```powershell
. .\scripts\use_gh.ps1
```

또는 전체 경로:

```powershell
& "C:\Program Files\GitHub CLI\gh.exe" auth login
```

## 2. GitHub 로그인 (최초 1회)

```powershell
. .\scripts\use_gh.ps1
gh auth login
# GitHub.com → HTTPS → Login with a web browser
```

## 3. 저장소 생성 및 푸시

```powershell
cd d:\android\personal_cognitiv

gh repo create personal_cognitiv --public --source=. --remote=origin --push
```

이미 원격이 있으면:

```powershell
git remote add origin https://github.com/YOUR_USER/personal_cognitiv.git
git push -u origin main
```

## 3. Pages 활성화

1. https://github.com/YOUR_USER/personal_cognitiv/settings/pages
2. **Build and deployment** → Source: **Deploy from a branch**
3. Branch: **main** / Folder: **/docs**
4. Save

1~2분 후 접속:

```
https://YOUR_USER.github.io/personal_cognitiv/privacy.html
https://YOUR_USER.github.io/personal_cognitiv/user_guide.html
https://YOUR_USER.github.io/personal_cognitiv/
```

Play Console **개인정보 처리방침 URL**에 privacy 주소를 입력하세요.  
앱 **환경설정 → 모담넷 이용 가이드 → 웹에서 보기**는 `user_guide.html` 주소를 사용합니다 (`lib/core/app_urls.dart`의 `USER_GUIDE_URL`로 변경 가능).

## 4. 로컬에서만 준비 (이미 완료)

- `docs/privacy.html` — 정책 본문
- `docs/user_guide.html` — 이용 가이드 (기능·관계망·환경설정)
- `docs/index.html` — 가이드·개인정보 링크 허브
- `docs/.nojekyll` — Jekyll 비활성화

## 5. 정책 수정 시

`docs/privacy.html` 수정 → commit → push → Pages 자동 갱신
