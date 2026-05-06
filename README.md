# geeksfield

geeksfield는 Codex 로그인 기반으로 이미지를 생성하고, 결과를 프로젝트 단위로 정리하며, 인페인팅과 반복 작업을 이어갈 수 있는 macOS 네이티브 이미지 작업 공간입니다.

SwiftUI로 만들어졌고, 생성 이미지와 메타데이터를 로컬 우선 방식으로 저장합니다. 앱은 Mac App Store 밖에서 배포되며 Developer ID 서명, 공증, Sparkle 자동 업데이트를 사용합니다.

<!-- TODO: 첫 공개용 스크린샷을 추가한 뒤 아래 주석을 실제 이미지로 바꾸세요.
![geeksfield main window](docs/images/main-window.png)
-->

## 주요 기능

- macOS에 맞춘 네이티브 이미지 생성 인터페이스
- 기존 `codex login` 세션을 사용하는 로컬 Codex 인증
- 프로젝트 단위 이미지, 메타데이터, 참조 이미지, 채팅 기록 관리
- 생성 결과를 기반으로 한 반복 작업, 인페인팅, 내보내기 흐름
- 서명된 릴리스, 공증된 다운로드, Sparkle 기반 자동 업데이트

## 빠른 시작

### 앱 설치

1. [GitHub Releases](https://github.com/rapid-studio/geeksfield/releases)에서 최신 `geeksfield-vX.Y.Z.dmg`를 다운로드합니다.
2. DMG를 열고 `geeksfield.app`을 Applications 폴더로 옮깁니다.
3. 이미지 생성과 채팅 기능을 사용하려면 터미널에서 Codex에 로그인합니다.

```bash
codex login
```

4. `geeksfield.app`을 실행합니다.

DMG는 최초 설치용입니다. 앱 설치 후 자동 업데이트는 릴리스의 `.zip` 에셋을 사용합니다.

### 요구 사항

- macOS 26 이상
- 이미지 생성과 채팅 기능을 위한 로컬 Codex 로그인

## 개발 환경

이 저장소는 생성된 Xcode 프로젝트를 커밋하지 않습니다. `project.yml`에서 프로젝트를 생성한 뒤 Xcode로 엽니다.

```bash
brew install xcodegen
xcodegen generate
open Geeksfield.xcodeproj
```

개발 중 이미지 생성과 채팅 기능을 확인하려면 로컬 Codex 로그인이 필요합니다.

```bash
codex login
```

### 개발 요구 사항

- macOS 26 이상
- Xcode 26 이상
- Swift 6
- XcodeGen
- 이미지 생성과 채팅 기능을 위한 로컬 Codex 로그인

## 데이터와 저장 방식

geeksfield는 로컬 우선 방식으로 프로젝트를 관리합니다. 프로젝트에는 생성 이미지, 이미지 메타데이터, 참조 이미지, 반복 작업 기록, 채팅 기록이 함께 저장됩니다.

앱은 Codex 인증 상태를 확인하기 위해 로컬 `codex login` 세션을 사용합니다. 앱은 샌드박스를 켠 상태로 동작하며, 필요한 인증 정보와 사용자가 선택한 파일을 중심으로 접근하도록 설계되어 있습니다.

## 업데이트

geeksfield는 Sparkle을 통해 자동 업데이트를 제공합니다. 업데이트 구조는 [docs/updater.md](docs/updater.md)에 정리되어 있습니다.

릴리스는 maintainer가 진행합니다. 절차는 [RELEASING.md](RELEASING.md)를 참고하세요.

## 프로젝트 상태

geeksfield는 초기 공개 버전이며 활발히 개발 중입니다. 이미지 생성, 인페인팅, 프로젝트 저장, 업데이트 흐름은 공개 릴리스가 안정화되는 동안 빠르게 바뀔 수 있습니다.

## 기여하기

기여하기 전에 [CONTRIBUTING.md](CONTRIBUTING.md)를 읽어 주세요. AI 코딩 에이전트와 함께 작업한다면 [AGENTS.md](AGENTS.md)도 함께 참고합니다.

기본 원칙은 다음과 같습니다.

- 기능과 수정 PR은 `dev` 브랜치를 대상으로 엽니다.
- `main` 브랜치는 릴리스용으로 사용합니다.
- PR은 리뷰하기 쉬운 크기로 유지합니다.
- 앱 코드 변경 시 Xcode에서 로컬 빌드를 확인합니다.
- 생성된 Xcode 프로젝트 파일은 커밋하지 않습니다.

## 보안

보안 이슈는 [SECURITY.md](SECURITY.md)에 따라 제보해 주세요.

## 라이선스

MIT. 자세한 내용은 [LICENSE](LICENSE)를 참고하세요.
