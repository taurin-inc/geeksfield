# geeksfield

이미지 생성 흐름을 가장 쉽게 확인하는 로컬 이미지 작업 공간입니다.

[최신 버전 다운로드](https://github.com/rapid-studio/geeksfield/releases)

## 데모

### 이미지 생성

<video src="docs/media/geeksfield-generate.mp4" controls muted playsinline></video>

[영상이 보이지 않으면 파일로 보기](docs/media/geeksfield-generate.mp4)

### 인페인트로 수정

<video src="docs/media/geeksfield-inpaint.mp4" controls muted playsinline></video>

[영상이 보이지 않으면 파일로 보기](docs/media/geeksfield-inpaint.mp4)

## 왜 만들었나요?

이미지 생성 히스토리를 매번 다시 탐색하고 기억하는 게 귀찮아서 만들었습니다.

AI로 이미지를 생성하다 보면, 마음에 들었던 보석 같은 이미지가 수많은 작업물 사이 어딘가에 묻혀버리고 맙니다. 특히 여러 소스를 한 번에 작업할 때는 기록을 탐색하는 일이 훨씬 더 힘들어집니다.

geeksfield는 이미지 생성 흐름을 쉽게 만들어주는 툴입니다. 한 번에 여러 이미지를 생성하고, 마음에 드는 결과는 레퍼런스로 이어가거나 인페인트로 일부만 수정할 수 있습니다. 작업 트리 내부에 히스토리가 모두 쌓이기 때문에, 나중에 다시 돌아와도 매번 번거롭게 추적하지 않아도 됩니다.

## 어떤 기능이 있나요?

- 별도의 추가 구독 없이, 내 Codex 계정을 사용합니다.
- 한 번의 프롬프트로 여러 이미지를 동시에 생성합니다.
- 내장된 채팅 UI로 AI에게 프롬프트 조언을 얻습니다.
- 원본 소스를 기준으로 파생된 이미지들을 작업 트리로 묶어서 확인합니다.
- 인페인트를 통해 특정 부분만 수정할 수 있습니다.

## 시작하기

1. [GitHub Releases](https://github.com/rapid-studio/geeksfield/releases)에서 최신 DMG를 다운로드합니다.
2. DMG를 열고 `geeksfield.app`을 Applications 폴더로 옮깁니다.
3. 터미널에서 Codex에 로그인합니다. 이미 로그인되어 있다면 geeksfield가 자동으로 인식합니다.

```bash
codex login
```

4. `geeksfield.app`을 실행합니다.

## 요구 사항

- macOS 26 이상
- 이미지 생성과 채팅 기능을 위한 로컬 Codex 로그인

## 개발과 기여

geeksfield는 이미지 생성 흐름을 더 편하게 만들기 위해 계속 다듬고 있습니다. 버그 제보, 사용하면서 막혔던 흐름, README나 문구 개선, UI 아이디어 등 모든 종류의 기여를 환영합니다.

## 라이선스

MIT. 자세한 내용은 [LICENSE](LICENSE)를 참고하세요.
