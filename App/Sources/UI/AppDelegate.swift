// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    @objc func showAbout(_ sender: Any?) {
        let credits = """
        본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

        "한글", "한컴", "HWP", "HWPX"는 주식회사 한글과컴퓨터의 등록 상표입니다. \
        이 앱은 한글과컴퓨터와 제휴, 후원, 승인 관계가 없습니다.

        문서 엔진: rhwp (MIT License, Copyright (c) 2025-2026 Edward Kim)
        """
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: credits, attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            ]),
        ])
    }

    @objc func showHelp(_ sender: Any?) {
        HelpWindowController.shared.showWindow(sender)
    }

    private func makeMainMenu() -> NSMenu {
        let appName = ProcessInfo.processInfo.processName
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "\(appName) 정보", action: #selector(showAbout(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "\(appName) 가리기", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(
            withTitle: "기타 가리기", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "모두 보기", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "\(appName) 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        addSubmenu(appMenu, titled: appName, to: mainMenu)

        let fileMenu = NSMenu(title: "파일")
        fileMenu.addItem(withTitle: "새 문서", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "열기…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        // AppKit fills a submenu that contains the clearRecentDocuments: item.
        let recentMenu = NSMenu(title: "최근 사용 열기")
        recentMenu.addItem(withTitle: "메뉴 지우기", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "")
        addSubmenu(recentMenu, titled: "최근 사용 열기", to: fileMenu)
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(withTitle: "저장", action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        fileMenu.addItem(withTitle: "다른 이름으로 저장…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "문서 엔진 다시 시작", action: #selector(DocumentWindowController.restartEngine(_:)), keyEquivalent: "")
        addSubmenu(fileMenu, titled: "파일", to: mainMenu)

        // Undo/redo/copy/cut/paste resolve to PagesView through the responder chain.
        let editMenu = NSMenu(title: "편집")
        editMenu.addItem(withTitle: "실행 취소", action: #selector(PagesView.undo(_:)), keyEquivalent: "z")
        editMenu.addItem(withTitle: "실행 복귀", action: #selector(PagesView.redo(_:)), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "오려두기", action: #selector(PagesView.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "복사하기", action: #selector(PagesView.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "붙이기", action: #selector(PagesView.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "전체 선택", action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a")
        addSubmenu(editMenu, titled: "편집", to: mainMenu)

        let viewMenu = NSMenu(title: "보기")
        viewMenu.addItem(withTitle: "실제 크기", action: #selector(DocumentWindowController.zoomToActualSize(_:)), keyEquivalent: "0")
        viewMenu.addItem(withTitle: "확대", action: #selector(DocumentWindowController.zoomIn(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "축소", action: #selector(DocumentWindowController.zoomOut(_:)), keyEquivalent: "-")
        addSubmenu(viewMenu, titled: "보기", to: mainMenu)

        let windowMenu = NSMenu(title: "윈도우")
        windowMenu.addItem(withTitle: "최소화", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "확대/축소", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        addSubmenu(windowMenu, titled: "윈도우", to: mainMenu)
        NSApp.windowsMenu = windowMenu

        let helpMenu = NSMenu(title: "도움말")
        helpMenu.addItem(withTitle: "\(appName) 도움말", action: #selector(showHelp(_:)), keyEquivalent: "?")
        addSubmenu(helpMenu, titled: "도움말", to: mainMenu)
        NSApp.helpMenu = helpMenu

        return mainMenu
    }

    private func addSubmenu(_ submenu: NSMenu, titled title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        menu.addItem(item)
    }
}
