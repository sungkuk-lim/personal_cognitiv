# GitHub Pages — 개인정보 처리방침 공개

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
```

Play Console **개인정보 처리방침 URL**에 위 주소를 입력하세요.

## 4. 로컬에서만 준비 (이미 완료)

- `docs/privacy.html` — 정책 본문
- `docs/index.html` — privacy.html 로 리다이렉트
- `docs/.nojekyll` — Jekyll 비활성화

## 5. 정책 수정 시

`docs/privacy.html` 수정 → commit → push → Pages 자동 갱신
