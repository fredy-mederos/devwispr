//
//  AppContainer.swift
//  DevWispr
//

import Foundation

@MainActor
final class AppContainer {
    let audioRecorder: AudioRecorder
    let transcriptionService: TranscriptionService
    let translationUseCase: TranslationUseCase
    let textInserter: TextInserter
    let historyStore: HistoryStore
    let permissionsManager: PermissionsManager
    let hotkeyManager: HotkeyManager
    let settingsStore: SettingsStore
    let languageDetector: LanguageDetector
    let recordingCoordinator: RecordingCoordinator
    let apiKeyManager: APIKeyManager
    let historyWindowController: HistoryWindowController
    let soundFeedbackService: SoundFeedbackService
    let updateChecker: UpdateChecker
    let analyticsService: AnalyticsService

    init(
        audioRecorder: AudioRecorder? = nil,
        transcriptionService: TranscriptionService? = nil,
        translationService: TranslationService? = nil,
        textInserter: TextInserter? = nil,
        historyStore: HistoryStore? = nil,
        permissionsManager: PermissionsManager? = nil,
        hotkeyManager: HotkeyManager? = nil,
        settingsStore: SettingsStore? = nil,
        languageDetector: LanguageDetector? = nil,
        updateChecker: UpdateChecker? = nil,
        analyticsService: AnalyticsService? = nil
    ) {
        let resolvedLanguageDetector = languageDetector ?? DefaultLanguageDetector()

        self.audioRecorder = audioRecorder ?? AVAudioRecorderService()
        self.settingsStore = settingsStore ?? UserDefaultsSettingsStore()
        self.languageDetector = resolvedLanguageDetector

        let resolvedSettingsStore = self.settingsStore
        let fallbackURL = URL(string: APIProvider.openAI.defaultBaseURL)!

        let baseURLProvider: () -> URL = {
            let provider = resolvedSettingsStore.apiProvider
            switch provider {
            case .openAI:
                return URL(string: provider.defaultBaseURL) ?? fallbackURL
            case .custom:
                if let custom = resolvedSettingsStore.customBaseURL, let url = URL(string: custom), !custom.isEmpty {
                    return url
                }
                return fallbackURL
            }
        }

        if transcriptionService != nil || translationService != nil {
            self.transcriptionService = transcriptionService ?? {
                let config = OpenAIClientConfiguration(
                    baseURLProvider: baseURLProvider,
                    apiKeyProvider: { resolvedSettingsStore.apiKey }
                )
                return OpenAITranscriptionService(client: OpenAIClient(configuration: config), languageDetector: resolvedLanguageDetector)
            }()
            self.translationUseCase = DefaultTranslationUseCase(
                service: translationService ?? {
                    let config = OpenAIClientConfiguration(
                        baseURLProvider: baseURLProvider,
                        apiKeyProvider: { resolvedSettingsStore.apiKey }
                    )
                    return OpenAITranslationService(client: OpenAIClient(configuration: config))
                }()
            )
        } else {
            let config = OpenAIClientConfiguration(
                baseURLProvider: baseURLProvider,
                apiKeyProvider: { resolvedSettingsStore.apiKey }
            )
            let openAIClient = OpenAIClient(configuration: config)
            self.transcriptionService = OpenAITranscriptionService(client: openAIClient, languageDetector: resolvedLanguageDetector)
            self.translationUseCase = DefaultTranslationUseCase(service: OpenAITranslationService(client: openAIClient))
        }

        self.textInserter = textInserter ?? ClipboardTextInserter()
        self.historyStore = historyStore ?? FileBackedHistoryStore()
        self.permissionsManager = permissionsManager ?? DefaultPermissionsManager()
        self.hotkeyManager = hotkeyManager ?? DefaultHotkeyManager()

        self.analyticsService = analyticsService ?? FirebaseAnalyticsService()

        self.apiKeyManager = APIKeyManager(
            settingsStore: self.settingsStore
        )

        self.recordingCoordinator = RecordingCoordinator(
            audioRecorder: self.audioRecorder,
            transcriptionService: self.transcriptionService,
            translationUseCase: self.translationUseCase,
            textInserter: self.textInserter,
            historyStore: self.historyStore,
            permissionsManager: self.permissionsManager,
            analyticsService: self.analyticsService
        )

        self.soundFeedbackService = DefaultSoundFeedbackService()
        self.updateChecker = updateChecker ?? GitHubUpdateChecker()
        self.historyWindowController = HistoryWindowController(historyStore: self.historyStore)
    }
}
