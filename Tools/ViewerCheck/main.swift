// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.
//
// Opens files in Hancom Office HWP Viewer (Mac App Store, free) and reads its
// windows through the Accessibility API, to judge whether 한글's own viewer
// opens each file. The viewer shows no error for a file it cannot read: it
// opens a blank "빈 문서" window instead, so a file counts as opened only when
// a window titled after it appears. Needs Accessibility permission for the
// terminal. Prints one JSON line per file.
//
// With --stats it also brings the viewer to the front (its menus only work
// there), opens 파일 > 문서 정보… > 문서 통계 and records Hancom's counts:
// characters, paragraphs, pages, tables/pictures/text boxes and so on.
//
// --activate brings the viewer to the front when it opens each file: on a
// busy or idle-for-long session it may not open documents in the background.
//
// --wait N gives the viewer N seconds (default 30) to show the document; large
// files on a busy machine can need more.
//
// usage: hwpmac-viewer-check [--stats] [--wait N] <file>...

import AppKit
import ApplicationServices

let viewerBundle = "com.haansoft.HancomOfficeViewer.Mac"
let viewerPath = "/Applications/Hancom Office HWP Viewer.app"

guard AXIsProcessTrusted() else {
    FileHandle.standardError.write(Data("Accessibility permission is required.\n".utf8))
    exit(77)
}

func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value as? T
}

/// Visible strings under `element`, depth-limited.
func texts(in element: AXUIElement, depth: Int = 0, into result: inout [String]) {
    guard depth < 12, result.count < 200 else { return }
    for name in [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute] {
        if let text: String = attribute(element, name as String), !text.isEmpty, text.count < 300 {
            result.append(text)
        }
    }
    for child: AXUIElement in attribute(element, kAXChildrenAttribute as String) ?? [] {
        texts(in: child, depth: depth + 1, into: &result)
    }
}

/// The first button under `element` titled `title`.
func button(titled title: String, in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    guard depth < 12 else { return nil }
    if (attribute(element, kAXRoleAttribute as String) as String?) == kAXButtonRole as String,
       (attribute(element, kAXTitleAttribute as String) as String?) == title {
        return element
    }
    for child: AXUIElement in attribute(element, kAXChildrenAttribute as String) ?? [] {
        if let found = button(titled: title, in: child, depth: depth + 1) { return found }
    }
    return nil
}

func runningViewer() -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: viewerBundle).first
}

func wait(_ seconds: TimeInterval) {
    RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
}

/// Quits normally, so the next launch does not ask to restore windows after
/// an unexpected quit; forces only if the viewer does not exit.
func quitViewer() {
    for app in NSRunningApplication.runningApplications(withBundleIdentifier: viewerBundle) {
        app.terminate()
    }
    var deadline = Date(timeIntervalSinceNow: 8)
    while runningViewer() != nil, Date() < deadline { wait(0.2) }
    for app in NSRunningApplication.runningApplications(withBundleIdentifier: viewerBundle) {
        app.forceTerminate()
    }
    deadline = Date(timeIntervalSinceNow: 5)
    while runningViewer() != nil, Date() < deadline { wait(0.2) }
}

/// The first element under `element` titled `title`.
func findElement(titled title: String, in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    guard depth < 12 else { return nil }
    if (attribute(element, kAXTitleAttribute as String) as String?) == title { return element }
    for child: AXUIElement in attribute(element, kAXChildrenAttribute as String) ?? [] {
        if let found = findElement(titled: title, in: child, depth: depth + 1) { return found }
    }
    return nil
}

/// The 문서 통계 labels, in the order the viewer lists them before their values.
let statisticsLabels = ["글자(공백 포함)", "글자(공백 제외)", "글자에 포함된 한자 수", "낱말", "줄", "문단", "쪽",
                        "원고지(200자 기준)", "표, 그림, 글상자"]

/// Opens 파일 > 문서 정보… > 문서 통계 in the frontmost viewer and reads the counts.
func readStatistics(_ app: NSRunningApplication) -> [String: Int]? {
    app.activate()
    wait(1)
    let element = AXUIElementCreateApplication(app.processIdentifier)
    guard let menuBar: AXUIElement = attribute(element, kAXMenuBarAttribute as String),
          let item = findElement(titled: "문서 정보…", in: menuBar)
    else { return nil }
    AXUIElementPerformAction(item, kAXPressAction as CFString)
    var info: AXUIElement?
    let deadline = Date(timeIntervalSinceNow: 5)
    while info == nil, Date() < deadline {
        wait(0.3)
        let windows: [AXUIElement] = attribute(element, kAXWindowsAttribute as String) ?? []
        info = windows.first { (attribute($0, kAXTitleAttribute as String) as String?) == "문서 정보" }
    }
    guard let info, let tab = findElement(titled: "문서 통계", in: info) else { return nil }
    AXUIElementPerformAction(tab, kAXPressAction as CFString)
    wait(0.8)
    var strings: [String] = []
    texts(in: info, into: &strings)
    if let ok = findElement(titled: "확인", in: info) {
        AXUIElementPerformAction(ok, kAXPressAction as CFString)
    }
    // Labels come first, then the values in the same order.
    guard let last = strings.firstIndex(of: statisticsLabels.last!) else { return nil }
    let values = strings[(last + 1)...].compactMap { Int($0.replacingOccurrences(of: ",", with: "")) }
    guard values.count >= statisticsLabels.count else { return nil }
    return Dictionary(uniqueKeysWithValues: zip(statisticsLabels, values))
}

func check(_ file: URL, statistics: Bool, windowWait: TimeInterval, activate: Bool) -> [String: Any] {
    quitViewer()
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = activate
    // Don't restore windows from earlier runs.
    configuration.arguments = ["-ApplePersistenceIgnoreState", "YES"]
    let launched = DispatchSemaphore(value: 0)
    NSWorkspace.shared.open([file], withApplicationAt: URL(fileURLWithPath: viewerPath), configuration: configuration) { _, _ in
        launched.signal()
    }
    _ = launched.wait(timeout: .now() + 20)

    let stem = file.deletingPathExtension().lastPathComponent
    var windowTitles: [String] = []
    var dialogTexts: [String] = []
    var dismissedRestorePrompt = false
    let deadline = Date(timeIntervalSinceNow: windowWait)
    repeat {
        wait(0.5)
        guard let app = runningViewer() else { continue }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        let windows: [AXUIElement] = attribute(element, kAXWindowsAttribute as String) ?? []
        windowTitles = windows.compactMap { attribute($0, kAXTitleAttribute as String) }
        dialogTexts = []
        for window in windows {
            let subrole: String = attribute(window, kAXSubroleAttribute as String) ?? ""
            if subrole.contains("Dialog") {
                texts(in: window, into: &dialogTexts)
                // A leftover "reopen windows after an unexpected quit?" prompt is
                // about the viewer, not this file: answer it and keep waiting.
                if let dontReopen = button(titled: "다시 열지 않음", in: window) {
                    AXUIElementPerformAction(dontReopen, kAXPressAction as CFString)
                    dismissedRestorePrompt = true
                    dialogTexts = []
                }
            }
            for sheet: AXUIElement in attribute(window, "AXSheets") ?? [] {
                texts(in: sheet, into: &dialogTexts)
            }
        }
        if windowTitles.contains(where: { $0.contains(stem) }) || !dialogTexts.isEmpty { break }
    } while Date() < deadline

    let opened = windowTitles.contains { $0.contains(stem) } && dialogTexts.isEmpty
    var counts: [String: Int]?
    if statistics, opened, let app = runningViewer() {
        counts = readStatistics(app)
    }
    var visible: [String] = []
    if let app = runningViewer() {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        for window: AXUIElement in attribute(element, kAXWindowsAttribute as String) ?? [] {
            texts(in: window, into: &visible)
        }
    }
    let result: [String: Any] = [
        "file": file.lastPathComponent,
        "opened": opened,
        "statistics": counts ?? NSNull(),
        "windowTitles": windowTitles,
        "dialog": dialogTexts,
        "dismissedRestorePrompt": dismissedRestorePrompt,
        "sampleText": Array(visible.prefix(8)),
    ]
    quitViewer()
    return result
}

let statistics = CommandLine.arguments.contains("--stats")
let activate = CommandLine.arguments.contains("--activate")
var paths = Array(CommandLine.arguments.dropFirst()).filter { $0 != "--stats" && $0 != "--activate" }
var windowWait: TimeInterval = 30
if let flag = paths.firstIndex(of: "--wait"), paths.indices.contains(flag + 1), let seconds = TimeInterval(paths[flag + 1]) {
    windowWait = seconds
    paths.removeSubrange(flag...(flag + 1))
}
for path in paths {
    let result = check(URL(fileURLWithPath: path), statistics: statistics, windowWait: windowWait, activate: activate)
    let json = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    print(String(decoding: json, as: UTF8.self))
    fflush(stdout)
}
