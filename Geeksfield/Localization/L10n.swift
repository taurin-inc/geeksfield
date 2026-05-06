import Foundation

enum Language: String, CaseIterable, Codable, Sendable, Hashable {
    case korean = "ko"
    case english = "en"

    var displayName: String {
        switch self {
        case .korean: return "한국어"
        case .english: return "English"
        }
    }
}

/// All UI strings keyed by `Language`. The struct value is cheap to recompute,
/// so we hold one instance on `AppState` and pass it through SwiftUI views.
struct L10n: Sendable, Equatable {
    let lang: Language

    /// Reads the persisted language from UserDefaults. For non-View call sites
    /// that don't have the AppState environment (errors, services).
    @MainActor
    static var current: L10n {
        let raw = UserDefaults.standard.string(forKey: "geeksfield.language") ?? Language.korean.rawValue
        return L10n(lang: Language(rawValue: raw) ?? .korean)
    }

    private func t(_ ko: String, _ en: String) -> String {
        lang == .korean ? ko : en
    }

    var locale: Locale {
        switch lang {
        case .korean: return Locale(identifier: "ko_KR")
        case .english: return Locale(identifier: "en_US")
        }
    }

    func dateTime(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .year()
                .month()
                .day()
                .hour()
                .minute()
                .locale(locale)
        )
    }

    func time(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .hour()
                .minute()
                .locale(locale)
        )
    }

    func relativeDate(_ date: Date) -> String {
        date.formatted(
            Date.RelativeFormatStyle(presentation: .named)
                .locale(locale)
        )
    }

    // MARK: Common
    var done: String { t("완료", "Done") }
    var cancel: String { t("취소", "Cancel") }
    var ok: String { t("확인", "OK") }
    var delete: String { t("삭제", "Delete") }
    var deleteImage: String { t("삭제하기", "Delete") }
    var save: String { t("저장하기", "Save") }
    var close: String { t("닫기", "Close") }
    var edit: String { t("수정", "Edit") }
    var create: String { t("만들기", "Create") }
    var refresh: String { t("새로고침", "Refresh") }
    var error: String { t("오류", "Error") }
    var none: String { t("없음", "None") }
    var name: String { t("이름", "Name") }

    // MARK: Sidebar
    var projects: String { t("프로젝트", "Projects") }
    var defaultProjectName: String { t("내 프로젝트", "My Project") }
    var newProject: String { t("새 프로젝트", "New Project") }
    var renameProject: String { t("이름 변경", "Rename") }
    var exportProject: String { t("프로젝트 내보내기", "Export Project") }
    var noProjects: String { t("프로젝트 없음", "No Projects") }
    var startWithPlus: String { t("툴바의 + 버튼으로 시작하세요", "Start with the + button in the toolbar") }
    var settings: String { t("설정", "Settings") }
    var connected: String { t("연결됨", "Connected") }
    var notConnected: String { t("미연결", "Not connected") }

    // MARK: Settings
    var settingsSubtitle: String { t("Codex 연결과 앱 기본 설정을 관리합니다.", "Manage your Codex connection and app preferences.") }
    var settingsApiKeys: String { t("연결", "Connections") }
    var settingsModels: String { t("모델", "Models") }
    var settingsAdvanced: String { t("고급", "Advanced") }
    var settingsGeneral: String { t("일반", "General") }
    var language: String { t("언어", "Language") }
    var updates: String { t("업데이트", "Updates") }

    // Connections section
    var getKey: String { t("키 발급", "Get key") }
    var enterToReplace: String { t("새 키로 교체하려면 입력", "Enter to replace existing key") }
    var replaceAndVerify: String { t("교체 & 검증", "Replace & Verify") }
    var saveAndVerify: String { t("저장 & 검증", "Save & Verify") }
    var deleteSavedKey: String { t("저장된 키 삭제", "Delete saved key") }
    var saved: String { t("저장됨", "Saved") }
    var enterAndSaveKey: String { t("키를 입력하고 저장하세요.", "Enter and save your key.") }
    var verifying: String { t("검증 중…", "Verifying…") }
    func validKeyModelCount(_ n: Int) -> String {
        t("유효한 키 · 모델 \(n)개", "Valid key · \(n) models")
    }
    var verificationFailed: String { t("검증 실패", "Verification failed") }
    var codexLoginDetected: String { t("Codex 로그인 감지됨", "Codex login detected") }
    var codexLoginMissing: String { t("터미널에서 codex login을 먼저 실행하세요.", "Run codex login in Terminal first.") }
    var codexUsesSubscription: String { t("Codex 구독 로그인 사용", "Uses your Codex subscription login") }
    var checkCodexLogin: String { t("로그인 확인", "Check Login") }

    // Advanced
    var modelDiscovery: String { "Model discovery" }
    var showUnknownModels: String { t("알 수 없는 모델도 표시", "Show unknown models") }
    var lastRefreshed: String { t("마지막 새로고침", "Last refreshed") }

    // Models catalog
    var noModelsYet: String { t("아직 모델이 없습니다", "No models yet") }
    var connectKeyFirst: String { t("Codex 로그인을 먼저 연결하세요.", "Connect Codex login first.") }
    var discoveredModels: String { "Discovered models" }

    // MARK: Chat
    var noAvailableModels: String { t("사용 가능한 모델 없음", "No available models") }
    var chatModel: String { t("채팅 모델", "Chat Model") }
    var codexChat: String { t("Codex 채팅", "Codex Chat") }
    var chatUsesCodex: String { t("프롬프트를 다듬거나 다음 이미지를 함께 구상하세요.", "Refine prompts or shape the next image together.") }
    var codexLoginRequired: String { t("Codex 로그인 필요", "Codex login required") }
    var showChatPanel: String { t("대화 패널 보이기", "Show chat panel") }
    var hideChatPanel: String { t("대화 패널 숨기기", "Hide chat panel") }
    var chats: String { t("채팅", "Chats") }
    var newChat: String { t("새 채팅", "New Chat") }
    var chatHistory: String { t("채팅 목록", "Chat history") }
    var startConversation: String { t("무엇을 만들지 함께 정리해보세요", "Shape what to create next") }
    var chooseModelThenMessage: String { t("메시지를 입력하세요.", "Enter a message.") }
    var message: String { t("메시지", "Message") }
    var chatModelRequired: String { t("채팅 모델 필요", "Chat model required") }
    var enterKeyInSettings: String { t("설정 > 연결에서 Codex 로그인을 먼저 확인하세요.", "Check Codex login in Settings > Connections first.") }
    var pickChatModelAbove: String { t("위 모델 메뉴에서 채팅 모델을 선택하세요.", "Select a chat model from the menu above.") }

    // MARK: Gallery
    var generating: String { t("생성 중…", "Generating…") }
    var failed: String { t("실패", "Failed") }
    var selectAProject: String { t("프로젝트를 선택하세요", "Select a project") }
    var pickProjectFromSidebar: String { t("왼쪽 사이드바에서 프로젝트를 고르거나 새로 만드세요.", "Pick a project from the sidebar or create a new one.") }
    var noImagesYet: String { t("아직 이미지가 없습니다", "No images yet") }
    var tryFromPromptBar: String { t("아래 프롬프트 바에서 생성해 보세요.", "Try generating from the prompt bar below.") }
    var all: String { t("전체", "All") }
    var picked: String { t("북마크", "Picked") }
    var pickedToggle: String { t("북마크", "Pick") }
    var pickedClear: String { t("북마크 해제", "Unpick") }

    // MARK: ImageDetail
    var regenerate: String { t("다시 만들기", "Regenerate") }
    var retryGeneration: String { t("다시 생성하기", "Regenerate") }
    var useAsReference: String { t("레퍼런스로 사용", "Use as Reference") }
    var useAsBase: String { t("기준으로 이어가기", "Use as Base") }
    var baseImage: String { t("기준 이미지", "Base Image") }
    var continueFromHere: String { t("이 이미지로 이어가기", "Continue From Here") }
    var currentImage: String { t("현재 이미지", "Current Image") }
    var selectedImage: String { t("선택한 이미지", "Selected Image") }
    var workTree: String { t("작업 트리", "Work Tree") }
    var sameRun: String { t("같은 시안", "Same Run") }
    var parentImage: String { t("부모 이미지", "Parent Image") }
    var childImages: String { t("파생 이미지", "Child Images") }
    var iterationBoard: String { t("작업 보드", "Board") }
    var iterationThread: String { t("작업 흐름", "Thread") }
    var more: String { t("더보기", "More") }
    var variants: String { t("시안", "Variants") }
    var requests: String { t("요청", "Requests") }
    var reference: String { t("레퍼런스", "Reference") }
    var generationFailed: String { t("생성 실패", "Generation failed") }
    var failureSection: String { t("실패", "Failure") }
    var unknownFailureReason: String {
        t("실패 이유를 확인할 수 없습니다.", "No failure reason is available.")
    }
    var prompt: String { "Prompt" }
    var information: String { t("정보", "Information") }
    var overview: String { t("개요", "Overview") }
    func referenceCount(_ n: Int) -> String {
        t("레퍼런스 \(n)", "Reference \(n)")
    }
    var infoModel: String { t("모델", "Model") }
    var infoProvider: String { t("제공자", "Provider") }
    var infoSize: String { t("크기", "Size") }
    var infoAspect: String { t("비율", "Aspect") }
    var infoSeed: String { "Seed" }
    var infoCreated: String { t("생성 시각", "Created") }
    var emptyPrompt: String { t("(빈 프롬프트)", "(empty prompt)") }
    var copy: String { "Copy" }
    var copyImage: String { t("복사하기", "Copy Image") }
    var copied: String { t("복사됨", "Copied") }

    // MARK: ReferencePicker
    var addExternal: String { t("외부 추가…", "Add external…") }
    func attachedCount(_ n: Int) -> String {
        t("첨부됨 (\(n))", "Attached (\(n))")
    }
    var pickFromProjectImages: String { t("프로젝트 내 이미지에서 선택", "Pick from project images") }
    var noImagesYetSentence: String { t("아직 이미지가 없습니다.", "No images yet.") }

    // MARK: Inpaint
    var inpaint: String { t("인페인트", "Inpaint") }
    var brush: String { t("브러시", "Brush") }
    var reset: String { t("초기화", "Reset") }
    var originalImageNotFound: String { t("원본 이미지를 찾을 수 없습니다", "Original image not found") }
    var editInstruction: String { t("수정 지시", "Edit instructions") }
    var maskCreationFailed: String { t("마스크 생성 실패", "Mask creation failed") }
    var modelLabel: String { t("모델", "Model") }
    var chooseModel: String { t("모델 선택", "Choose model") }

    // MARK: PromptBar
    var generate: String { t("생성", "Generate") }
    var imageCategory: String { t("이미지", "Image") }
    var chatCategory: String { t("채팅", "Chat") }
    var promptPlaceholder: String { t("무엇을 그릴까요?", "Describe the scene you imagine") }
    var sizeLabel: String { t("크기", "Size") }
    var aspectLabel: String { t("비율", "Aspect") }
    func imageCount(_ n: Int) -> String { t("\(n)장", "\(n) images") }
    var promptRequired: String { t("프롬프트 필요", "Prompt required") }
    var enterWhatToDraw: String { t("무엇을 그릴지 입력하세요.", "Enter what you want to draw.") }
    var projectRequired: String { t("프로젝트 선택 필요", "Project required") }
    var pickProjectOrCreate: String { t("왼쪽 사이드바에서 프로젝트를 선택하거나 + 버튼으로 새로 만드세요.", "Select a project from the sidebar or create one with the + button.") }
    var imageModelRequired: String { t("이미지 모델 필요", "Image model required") }
    var pickImageModel: String { t("왼쪽 모델 메뉴에서 모델을 선택하세요.", "Select a model from the model menu.") }

    // MARK: LocalImage
    func fileNotFound(_ name: String) -> String {
        t("파일을 찾을 수 없습니다: \(name)", "File not found: \(name)")
    }
    var imageDecodeFailed: String { t("이미지 디코딩 실패", "Image decoding failed") }
    func readFailed(_ msg: String) -> String {
        t("읽기 실패: \(msg)", "Read failed: \(msg)")
    }

    // MARK: App menu / updates
    var checkForUpdates: String { t("업데이트 확인…", "Check for Updates…") }

    // MARK: AppState error titles
    var imageGenerationFailed: String { t("이미지 생성 실패", "Image generation failed") }
    var interruptedGenerationReason: String {
        t(
            "앱이 재시작되어 이전 생성 작업을 이어갈 수 없습니다. 다시 생성해 주세요.",
            "The app restarted before this generation completed. Please generate it again."
        )
    }
    var staleGenerationReason: String {
        t(
            "생성 응답 시간이 너무 오래 걸려 작업을 중단했습니다. 다시 시도해 주세요.",
            "Generation took too long and was stopped. Please try again."
        )
    }
    var referenceAddFailed: String { t("레퍼런스 추가 실패", "Failed to add reference") }
    var inpaintFailed: String { t("인페인트 실패", "Inpaint failed") }
    var cannotReadOriginal: String { t("원본 이미지를 읽을 수 없습니다.", "Cannot read original image.") }
    var exportFailed: String { t("내보내기 실패", "Export failed") }
    var projectExportFailed: String { t("프로젝트 내보내기 실패", "Project export failed") }
    var regenerateFailed: String { t("다시 만들기 실패", "Regenerate failed") }
    var modelNotFound: String { t("모델을 찾을 수 없습니다.", "Model not found.") }

    // MARK: Export
    var exportUserCancelled: String { t("사용자가 취소했습니다.", "User cancelled.") }
    func exportSourceMissing(_ path: String) -> String {
        t("원본 파일이 없습니다: \(path)", "Source file missing: \(path)")
    }
    var exportSaveHere: String { t("여기에 저장", "Save here") }

    // MARK: Onboarding
    var welcome: String { t("환영합니다", "Welcome") }
    var onboardingSubtitle: String { t("Codex 로그인을 연결하고 시작하세요.", "Connect Codex login to get started.") }
    var getStarted: String { t("시작하기", "Get Started") }
    var skipForNow: String { t("나중에", "Skip for now") }
}
