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
        fileMenu.addItem(withTitle: "열기…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        // AppKit fills a submenu that contains the clearRecentDocuments: item.
        let recentMenu = NSMenu(title: "최근 사용 열기")
        recentMenu.addItem(withTitle: "메뉴 지우기", action: #selector(NSDocumentController.clearRecentDocuments(_:)), keyEquivalent: "")
        addSubmenu(recentMenu, titled: "최근 사용 열기", to: fileMenu)
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        addSubmenu(fileMenu, titled: "파일", to: mainMenu)

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

        return mainMenu
    }

    private func addSubmenu(_ submenu: NSMenu, titled title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        menu.addItem(item)
    }
}
