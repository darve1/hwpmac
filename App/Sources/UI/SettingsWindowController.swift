// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

/// 환경 설정. The web editor's options are about fonts (macOS lists installed
/// fonts by itself) and the recovery autosave; this window has the latter.
@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    /// UserDefaults keys.
    static let autosaveEnabledKey = "RecoveryAutosaveEnabled"
    static let autosaveMinutesKey = "RecoveryAutosaveMinutes"

    private let autosave = NSButton(checkboxWithTitle: "복구용 자동 저장", target: nil, action: nil)
    private let minutes = NSTextField()
    private let stepper = NSStepper()

    /// Applies the stored setting; called at launch and on every change.
    static func applyAutosave() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [autosaveEnabledKey: true, autosaveMinutesKey: 5])
        let enabled = defaults.bool(forKey: autosaveEnabledKey)
        let minutes = min(max(defaults.integer(forKey: autosaveMinutesKey), 1), 60)
        NSDocumentController.shared.autosavingDelay = enabled ? TimeInterval(minutes * 60) : 0
    }

    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 150),
                              styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.title = "환경 설정"
        super.init(window: window)

        let defaults = UserDefaults.standard
        autosave.state = defaults.bool(forKey: Self.autosaveEnabledKey) ? .on : .off
        autosave.target = self
        autosave.action = #selector(changed(_:))
        stepper.minValue = 1
        stepper.maxValue = 60
        stepper.integerValue = defaults.integer(forKey: Self.autosaveMinutesKey)
        stepper.target = self
        stepper.action = #selector(changed(_:))
        minutes.integerValue = stepper.integerValue
        minutes.isEditable = false
        minutes.widthAnchor.constraint(equalToConstant: 40).isActive = true
        let interval = NSStackView(views: [NSTextField(labelWithString: "간격:"), minutes, stepper,
                                           NSTextField(labelWithString: "분")])
        let note = NSTextField(wrappingLabelWithString:
            "앱이 갑자기 끝나도 편집 중인 문서를 다시 열 수 있게 문서 밖에 복구본을 둡니다. 원본 파일은 저장할 때만 바뀝니다. "
            + "큰 문서는 복구본을 만드는 동안 잠깐 멈출 수 있어 간격을 길게 두면 좋습니다.")
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = 380
        let stack = NSStackView(views: [autosave, interval, note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        window.contentView = stack
        window.center()
        update()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func update() {
        minutes.integerValue = stepper.integerValue
        stepper.isEnabled = autosave.state == .on
    }

    @objc private func changed(_ sender: Any?) {
        UserDefaults.standard.set(autosave.state == .on, forKey: Self.autosaveEnabledKey)
        UserDefaults.standard.set(stepper.integerValue, forKey: Self.autosaveMinutesKey)
        update()
        Self.applyAutosave()
    }
}
