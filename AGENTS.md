# AGENTS.md

이 문서는 AI 코딩 에이전트(Claude Code, Cursor, Codex 등)가 이 저장소에서 안전하고 일관되게 작업하기 위한 단일 가이드입니다. 사람 기여자는 [CONTRIBUTING.md](CONTRIBUTING.md)와 [RELEASING.md](RELEASING.md)를 함께 참고하세요.

## Project at a glance

- macOS 네이티브 SwiftUI 이미지 생성 워크스페이스.
- Swift 6, `SWIFT_STRICT_CONCURRENCY: complete`, macOS 26+, Xcode 26+.
- 외부 의존성: Sparkle (auto-update, exact version 2.9.1), 로컬 `codex login` 세션 (이미지/채팅 기능).
- 배포: Mac App Store 외부, Developer ID 서명 + 공증 + Sparkle appcast (GitHub Pages).

## Build & run

이 저장소는 생성된 Xcode 프로젝트를 커밋하지 않습니다. `project.yml` (XcodeGen) 으로 생성합니다.

```bash
brew install xcodegen        # 1회
xcodegen generate            # project.yml 변경 후 매번
open Geeksfield.xcodeproj
```

- `project.yml`을 수정한 PR은 반드시 `xcodegen generate`로 재생성해 빌드를 검증하세요.
- 생성된 `Geeksfield.xcodeproj/`는 절대 커밋하지 마세요 (`.gitignore`에 포함).
- 이미지/채팅 기능을 로컬에서 검증하려면 `codex login`이 필요합니다. 에이전트는 자동으로 로그인할 수 없습니다 — 해당 경로는 사람 검증 단계로 분리하고 PR 본문에 명시하세요.

## Tests & lint

- 현재 테스트 타깃과 SwiftLint/swift-format 설정이 없습니다. 새로 추가할 경우 `project.yml`의 `targets:` 아래에 등록해야 빌드에 포함됩니다.
- 정적 검증은 Xcode의 Swift 6 strict concurrency가 사실상의 lint 역할을 합니다. 빌드 경고를 무시하지 마세요.

## Branching & PRs

- `dev` = 통합 브랜치. 모든 기능/수정 PR은 `dev`를 base로 엽니다.
- `main` = 릴리스 전용. push 시 GitHub Actions release 워크플로가 트리거됩니다.
- `main`을 base로 한 PR이 `dev`에서 오지 않은 경우 [`.github/workflows/main-pr-gate.yml`](.github/workflows/main-pr-gate.yml)이 자동으로 닫습니다. 즉 feature 브랜치 → `main` 직행은 차단됩니다.
- 일반 브랜치가 `dev`로 머지되면 [`.github/workflows/dev-branch-cleanup.yml`](.github/workflows/dev-branch-cleanup.yml)이 해당 head 브랜치를 삭제합니다.
- `dev` → `main` 릴리스 PR은 머지 후에도 `dev` 브랜치를 유지합니다. GitHub 저장소의 전역 `Automatically delete head branches` 설정은 꺼둡니다.
- `main` 릴리스 PR의 허용 머지 방식은 merge commit입니다 (`main` branch ruleset). 릴리스 머지 커밋은 `main`에만 생기며 `dev`에는 자동으로 되돌아가지 않습니다.
- PR 본문에는 [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md)의 verification 체크리스트를 채우세요.

## Versioning & release

- 릴리스 직전 `project.yml`의 두 값을 갱신:
  - `MARKETING_VERSION` — 공개 버전 (예: `0.1.4`).
  - `CURRENT_PROJECT_VERSION` — Sparkle 빌드 번호 (단조 증가).
- 자세한 절차는 [RELEASING.md](RELEASING.md). 에이전트는 릴리스를 직접 트리거하지 마세요 — maintainer 권한입니다.

## Repository layout

| 경로 | 책임 |
|---|---|
| `Geeksfield/AppState/` | `@MainActor` `AppState`, `ErrorBus`, `ModelRegistry` — 단일 상태 컨테이너. |
| `Geeksfield/Auth/` | `KeychainStore` (sandbox 내부 JSON), `CodexAuthStore` (`~/.codex/auth.json` 읽기). |
| `Geeksfield/Chat/` | `ChatOrchestrator` + `CodexChatProvider` (SSE 스트리밍). |
| `Geeksfield/Discovery/` | 모델 카탈로그/검색. |
| `Geeksfield/Export/` | 이미지 내보내기. |
| `Geeksfield/Features/` | SwiftUI 화면 단위 — Chat, Gallery, ImageDetail, Onboarding, Prompt, Settings, Sidebar. |
| `Geeksfield/Generation/` | `GenerationOrchestrator` + `CodexImageProvider` (병렬 슬롯, 인페인팅). |
| `Geeksfield/Localization/` | `String+L10n.swift` 등 다국어 리소스. |
| `Geeksfield/Models/` | 도메인 모델 (`ImageMetadata`, `Project`, ...). |
| `Geeksfield/Storage/` | 로컬 우선 I/O — `ImageStore`, `MetadataStore`, `ThumbnailStore`, `ChatLogStore`, `ReferenceStore`. |

## Conventions

### Concurrency
- 화면·상태 클래스는 `@MainActor final class`. 단일 `AppState`가 도메인을 모음.
- 네트워크/파일 I/O는 `async` 메서드. 콜백/델리게이트 새로 만들지 마세요.
- 병렬 작업은 `withThrowingTaskGroup`을 사용 (예: `GenerationOrchestrator.execute`, `CodexImageProvider.generate`). 직렬 `for await` 루프는 비파괴적 사후처리에만 허용.
- `DispatchQueue.main.async`는 SwiftUI view-update 사이클 회피 같은 명확한 사유가 있을 때만 (예: `MultilineTextEditor.swift`).

### Error handling
- 사용자에게 보일 에러는 반드시 `ErrorBus.report(error, title:)`을 통해 전달. ad-hoc alert를 새로 만들지 마세요.
- 비치명적 로깅·썸네일 실패 등은 `try?`로 무시 가능. 단, 결제/저장/네트워크 본 흐름은 절대 `try?`로 삼키지 마세요.

### Storage
- 사용자 데이터(프로젝트/이미지/메타데이터/참조 이미지)는 sandbox container에 저장. 경로 구성은 `Geeksfield/Storage/`의 기존 헬퍼만 사용 (`AppPaths.swift`).
- API 키는 의도적으로 macOS Keychain이 아닌 sandbox-private JSON에 저장 (사유는 `KeychainStore.swift` 상단 주석 참고). 폴백 경로(/tmp 등)를 추가하지 마세요.

## Security guardrails (절대 위반 금지)

1. **시크릿 커밋 금지** — `.p12`, `.p8`, Sparkle EdDSA private key, App Store Connect 키, 어떤 형태의 토큰/패스워드도 커밋·diff에 포함되어서는 안 됩니다. 발견 시 즉시 작업 중단하고 사용자에게 보고.
2. **엔타이틀먼트 확장 시 정당화 필수** — `Geeksfield/Geeksfield.entitlements` 또는 `project.yml`의 entitlements 블록에 권한을 추가하는 PR은 반드시 사유를 본문에 명시. 임의로 sandbox·hardened runtime을 끄지 마세요.
3. **HTTP 강제 금지** — `NSAllowsArbitraryLoads = true`, hardened runtime 비활성, 코드 서명 우회는 절대 금지.
4. **시크릿 로깅 금지** — Bearer 토큰, 액세스 토큰, API 키를 로그·에러 메시지에 직접 출력하지 마세요. SSE 응답 본문도 길이 제한(현재 2,000자) 유지.
5. **외부 PR 자동 릴리스 금지** — release workflow 변경, 공개 환경 추가, push-to-main 자동화는 maintainer 검토 필수.
6. **AI 에이전트가 만드는 PR**도 `release` GitHub Environment의 시크릿(`APPLE_CERTIFICATE_BASE64` 등)을 절대 참조하지 마세요. 워크플로 수정 시 secret 노출 가능성을 한 번 더 검토하세요.

## Footguns

- **`project.yml` 수정 후 재생성 누락** — 빌드 실패 또는 (더 위험하게) stale 프로젝트로 빌드. 항상 `xcodegen generate` 후 빌드 확인.
- **Sparkle 키 mismatch** — `Info.plist`의 `SUPublicEDKey`와 워크플로의 `SPARKLE_PRIVATE_KEY`가 일치하지 않으면 사용자 측에서 update가 silent 실패. 키 회전은 별도 이슈로 다루고 검증 단계 추가.
- **Codex 의존 기능** — 이미지 생성·채팅은 로컬 `codex login` 세션이 있어야 동작. CI에서는 검증 불가. UI 회귀는 사람이 수동 확인.
- **릴리스 파이프라인 ~90분** — main push 후 archive → notarize app → DMG → notarize DMG 파이프라인. 빠른 hotfix가 어렵다는 점을 PR 시점에 고려.
- **macOS 26+ / Xcode 26+ 전용** — 하위 호환 추가 PR은 `project.yml`의 deployment target과 동시에 모든 사용 API를 검토.

## When stuck, ask

이 가이드에 답이 없는 결정(외부 의존성 추가, 권한 확장, 릴리스 절차 변경, 데이터 모델 마이그레이션)은 임의로 진행하지 말고 PR 또는 이슈로 사람에게 위임하세요.
