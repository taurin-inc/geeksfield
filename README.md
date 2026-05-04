# Geeksfield

로컬 Codex 로그인으로 이미지를 생성·관리하는 macOS 네이티브 앱.

- macOS 26 Tahoe 이상 (Liquid Glass UI)
- Swift 6, SwiftUI, Xcode 26+
- 샌드박스 + Developer ID 서명
- MIT License

## 프로젝트 열기

이 레포는 Xcode 프로젝트 파일(`.xcodeproj`)을 커밋하지 않습니다. 대신 [XcodeGen](https://github.com/yonaskolb/XcodeGen)의 `project.yml`에서 생성합니다.

```bash
brew install xcodegen
xcodegen generate
open Geeksfield.xcodeproj
```

## 상태

1단계 ~ 3단계 스캐폴딩 완료. 앱을 실행하면 온보딩에서 Codex 로그인을 확인한 뒤 사용 가능한 모델이 드롭다운에 표시됩니다.

## 모델 연결

- Codex: 터미널에서 `codex login`으로 로그인하면 앱이 로컬 `~/.codex/auth.json`을 확인해 Codex 이미지 생성을 사용할 수 있습니다.

이후 단계:

- 4단계: 3단 레이아웃 · Liquid Glass 적용
- 5단계: 이미지/채팅 공급자 구현
- 6단계: 인페인트, 내보내기

## 구조

자세한 폴더 설명과 설계 원칙은 `docs/`(예정) 및 각 폴더의 `README.md`(예정)를 참고하세요.
