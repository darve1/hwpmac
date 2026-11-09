// 본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// Filled with the frontmost document's paragraph styles when it opens.
    private let styleMenu = NSMenu(title: "스타일")

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
        fileMenu.addItem(withTitle: "PDF로 내보내기…", action: #selector(HwpDocument.exportPDF(_:)), keyEquivalent: "")
        fileMenu.addItem(withTitle: "HTML로 내보내기…", action: #selector(HwpDocument.exportHTML(_:)), keyEquivalent: "")
        fileMenu.addItem(withTitle: "Word 문서(.doc)로 내보내기…", action: #selector(HwpDocument.exportWord(_:)), keyEquivalent: "")
        fileMenu.addItem(.separator())
        // 한글의 편집 용지 (F7): the document's own paper and margins, not the printer's.
        let pageSetup = fileMenu.addItem(withTitle: "편집 용지…", action: #selector(PagesView.showPageSetup(_:)),
                                         keyEquivalent: String(utf16CodeUnits: [unichar(NSF7FunctionKey)], count: 1))
        pageSetup.keyEquivalentModifierMask = []
        fileMenu.addItem(withTitle: "인쇄…", action: #selector(NSDocument.printDocument(_:)), keyEquivalent: "p")
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
        editMenu.addItem(.separator())
        let copyFormat = editMenu.addItem(withTitle: "모양 복사", action: #selector(PagesView.copyFormat(_:)), keyEquivalent: "c")
        copyFormat.keyEquivalentModifierMask = [.command, .option]
        let pasteFormat = editMenu.addItem(withTitle: "모양 붙이기", action: #selector(PagesView.pasteFormat(_:)), keyEquivalent: "v")
        pasteFormat.keyEquivalentModifierMask = [.command, .option]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "찾기…", action: #selector(DocumentWindowController.showFind(_:)), keyEquivalent: "f")
        let replaceItem = editMenu.addItem(
            withTitle: "찾아 바꾸기…", action: #selector(DocumentWindowController.showReplace(_:)), keyEquivalent: "f"
        )
        replaceItem.keyEquivalentModifierMask = [.command, .option]
        editMenu.addItem(withTitle: "다음 찾기", action: #selector(DocumentWindowController.findNext(_:)), keyEquivalent: "g")
        editMenu.addItem(withTitle: "이전 찾기", action: #selector(DocumentWindowController.findPrevious(_:)), keyEquivalent: "G")
        let goTo = editMenu.addItem(withTitle: "쪽 찾아가기…", action: #selector(PagesView.showGoToPage(_:)), keyEquivalent: "g")
        goTo.keyEquivalentModifierMask = [.command, .option]
        addSubmenu(editMenu, titled: "편집", to: mainMenu)

        let formatMenu = NSMenu(title: "서식")
        formatMenu.addItem(withTitle: "굵게", action: #selector(PagesView.toggleBold(_:)), keyEquivalent: "b")
        formatMenu.addItem(withTitle: "기울임", action: #selector(PagesView.toggleItalic(_:)), keyEquivalent: "i")
        formatMenu.addItem(withTitle: "밑줄", action: #selector(PagesView.toggleUnderlineStyle(_:)), keyEquivalent: "u")
        formatMenu.addItem(withTitle: "취소선", action: #selector(PagesView.toggleStrikethrough(_:)), keyEquivalent: "")
        let effectsMenu = NSMenu(title: "글자 효과")
        effectsMenu.addItem(withTitle: "위 첨자", action: #selector(PagesView.toggleSuperscript(_:)), keyEquivalent: "")
        effectsMenu.addItem(withTitle: "아래 첨자", action: #selector(PagesView.toggleSubscript(_:)), keyEquivalent: "")
        effectsMenu.addItem(.separator())
        effectsMenu.addItem(withTitle: "양각", action: #selector(PagesView.toggleEmboss(_:)), keyEquivalent: "")
        effectsMenu.addItem(withTitle: "음각", action: #selector(PagesView.toggleEngrave(_:)), keyEquivalent: "")
        effectsMenu.addItem(withTitle: "외곽선", action: #selector(PagesView.toggleOutline(_:)), keyEquivalent: "")
        effectsMenu.addItem(.separator())
        effectsMenu.addItem(withTitle: "장평 넓게", action: #selector(PagesView.increaseCharRatio(_:)), keyEquivalent: "")
        effectsMenu.addItem(withTitle: "장평 좁게", action: #selector(PagesView.decreaseCharRatio(_:)), keyEquivalent: "")
        effectsMenu.addItem(withTitle: "자간 넓게", action: #selector(PagesView.increaseCharSpacing(_:)), keyEquivalent: "")
        effectsMenu.addItem(withTitle: "자간 좁게", action: #selector(PagesView.decreaseCharSpacing(_:)), keyEquivalent: "")
        addSubmenu(effectsMenu, titled: "글자 효과", to: formatMenu)
        formatMenu.addItem(.separator())
        let bigger = formatMenu.addItem(withTitle: "글자 크게", action: #selector(PagesView.increaseFontSize(_:)), keyEquivalent: "=")
        bigger.keyEquivalentModifierMask = [.command, .option]
        let smaller = formatMenu.addItem(withTitle: "글자 작게", action: #selector(PagesView.decreaseFontSize(_:)), keyEquivalent: "-")
        smaller.keyEquivalentModifierMask = [.command, .option]
        let characterShape = formatMenu.addItem(withTitle: "글자 모양…", action: #selector(PagesView.showCharacterShape(_:)),
                                                keyEquivalent: "l")
        characterShape.keyEquivalentModifierMask = [.command, .option]
        formatMenu.addItem(withTitle: "글꼴…", action: #selector(PagesView.showFontPanel(_:)), keyEquivalent: "t")
        formatMenu.addItem(withTitle: "글자 색…", action: #selector(PagesView.showTextColorPanel(_:)), keyEquivalent: "C")
        formatMenu.addItem(.separator())
        formatMenu.addItem(withTitle: "왼쪽 정렬", action: #selector(PagesView.alignLeft(_:)), keyEquivalent: "{")
        formatMenu.addItem(withTitle: "가운데 정렬", action: #selector(PagesView.alignCenter(_:)), keyEquivalent: "|")
        formatMenu.addItem(withTitle: "오른쪽 정렬", action: #selector(PagesView.alignRight(_:)), keyEquivalent: "}")
        formatMenu.addItem(withTitle: "양쪽 정렬", action: #selector(PagesView.alignJustified(_:)), keyEquivalent: "")
        formatMenu.addItem(withTitle: "배분 정렬", action: #selector(PagesView.alignDistributed(_:)), keyEquivalent: "")
        formatMenu.addItem(withTitle: "나눔 정렬", action: #selector(PagesView.alignSplit(_:)), keyEquivalent: "")
        let spacingMenu = NSMenu(title: "줄 간격")
        for percent in [100, 130, 160, 180, 200] {
            let item = spacingMenu.addItem(withTitle: "\(percent)%", action: #selector(PagesView.setLineSpacing(_:)), keyEquivalent: "")
            item.tag = percent
        }
        spacingMenu.addItem(.separator())
        spacingMenu.addItem(withTitle: "늘리기 (10%)", action: #selector(PagesView.increaseLineSpacing(_:)), keyEquivalent: "")
        spacingMenu.addItem(withTitle: "줄이기 (10%)", action: #selector(PagesView.decreaseLineSpacing(_:)), keyEquivalent: "")
        addSubmenu(spacingMenu, titled: "줄 간격", to: formatMenu)
        let paragraphShape = formatMenu.addItem(withTitle: "문단 모양…", action: #selector(PagesView.showParagraphShape(_:)),
                                                keyEquivalent: "t")
        paragraphShape.keyEquivalentModifierMask = [.command, .option]
        styleMenu.delegate = self
        addSubmenu(styleMenu, titled: "스타일", to: formatMenu)
        formatMenu.addItem(withTitle: "개요 수준 낮추기", action: #selector(PagesView.increaseOutlineLevel(_:)), keyEquivalent: "")
        formatMenu.addItem(withTitle: "개요 수준 높이기", action: #selector(PagesView.decreaseOutlineLevel(_:)), keyEquivalent: "")
        formatMenu.addItem(withTitle: "문단 번호", action: #selector(PagesView.toggleNumbering(_:)), keyEquivalent: "")
        formatMenu.addItem(withTitle: "글머리표", action: #selector(PagesView.toggleBullets(_:)), keyEquivalent: "")
        formatMenu.addItem(withTitle: "들여쓰기 늘리기", action: #selector(PagesView.increaseIndent(_:)), keyEquivalent: "]")
        formatMenu.addItem(withTitle: "들여쓰기 줄이기", action: #selector(PagesView.decreaseIndent(_:)), keyEquivalent: "[")
        addSubmenu(formatMenu, titled: "서식", to: mainMenu)

        let insertMenu = NSMenu(title: "입력")
        insertMenu.addItem(withTitle: "그림…", action: #selector(PagesView.insertPicture(_:)), keyEquivalent: "")
        insertMenu.addItem(.separator())
        insertMenu.addItem(withTitle: "하이퍼링크…", action: #selector(PagesView.editHyperlink(_:)), keyEquivalent: "k")
        insertMenu.addItem(withTitle: "하이퍼링크 지우기", action: #selector(PagesView.removeHyperlink(_:)), keyEquivalent: "")
        insertMenu.addItem(withTitle: "책갈피…", action: #selector(PagesView.addBookmark(_:)), keyEquivalent: "")
        insertMenu.addItem(.separator())
        let symbols = insertMenu.addItem(withTitle: "문자표…", action: #selector(PagesView.showSymbols(_:)), keyEquivalent: " ")
        symbols.keyEquivalentModifierMask = [.command, .control]
        addSubmenu(insertMenu, titled: "입력", to: mainMenu)

        let objectMenu = NSMenu(title: "개체")
        objectMenu.addItem(withTitle: "개체 속성…", action: #selector(PagesView.showObjectProperties(_:)), keyEquivalent: "")
        objectMenu.addItem(withTitle: "개체 지우기", action: #selector(PagesView.deleteSelectedObject(_:)), keyEquivalent: "")
        objectMenu.addItem(.separator())
        objectMenu.addItem(withTitle: "맨 앞으로", action: #selector(PagesView.bringObjectToFront(_:)), keyEquivalent: "")
        objectMenu.addItem(withTitle: "앞으로", action: #selector(PagesView.bringObjectForward(_:)), keyEquivalent: "")
        objectMenu.addItem(withTitle: "뒤로", action: #selector(PagesView.sendObjectBackward(_:)), keyEquivalent: "")
        objectMenu.addItem(withTitle: "맨 뒤로", action: #selector(PagesView.sendObjectToBack(_:)), keyEquivalent: "")
        objectMenu.addItem(.separator())
        objectMenu.addItem(withTitle: "오른쪽으로 90° 회전", action: #selector(PagesView.rotatePictureRight(_:)), keyEquivalent: "")
        objectMenu.addItem(withTitle: "왼쪽으로 90° 회전", action: #selector(PagesView.rotatePictureLeft(_:)), keyEquivalent: "")
        objectMenu.addItem(withTitle: "좌우 대칭", action: #selector(PagesView.flipPictureHorizontally(_:)), keyEquivalent: "")
        objectMenu.addItem(withTitle: "상하 대칭", action: #selector(PagesView.flipPictureVertically(_:)), keyEquivalent: "")
        addSubmenu(objectMenu, titled: "개체", to: mainMenu)

        let tableMenu = NSMenu(title: "표")
        tableMenu.addItem(withTitle: "표 만들기…", action: #selector(PagesView.insertTable(_:)), keyEquivalent: "")
        tableMenu.addItem(.separator())
        tableMenu.addItem(withTitle: "위에 줄 추가", action: #selector(PagesView.insertRowAbove(_:)), keyEquivalent: "")
        tableMenu.addItem(withTitle: "아래에 줄 추가", action: #selector(PagesView.insertRowBelow(_:)), keyEquivalent: "")
        tableMenu.addItem(withTitle: "왼쪽에 칸 추가", action: #selector(PagesView.insertColumnLeft(_:)), keyEquivalent: "")
        tableMenu.addItem(withTitle: "오른쪽에 칸 추가", action: #selector(PagesView.insertColumnRight(_:)), keyEquivalent: "")
        tableMenu.addItem(withTitle: "줄 지우기", action: #selector(PagesView.deleteRow(_:)), keyEquivalent: "")
        tableMenu.addItem(withTitle: "칸 지우기", action: #selector(PagesView.deleteColumn(_:)), keyEquivalent: "")
        tableMenu.addItem(withTitle: "줄/칸 추가…", action: #selector(PagesView.showInsertRowsColumns(_:)), keyEquivalent: "")
        tableMenu.addItem(.separator())
        tableMenu.addItem(withTitle: "오른쪽 셀과 합치기", action: #selector(PagesView.mergeCellRight(_:)), keyEquivalent: "")
        tableMenu.addItem(withTitle: "아래 셀과 합치기", action: #selector(PagesView.mergeCellDown(_:)), keyEquivalent: "")
        tableMenu.addItem(withTitle: "셀 나누기…", action: #selector(PagesView.splitCell(_:)), keyEquivalent: "")
        tableMenu.addItem(.separator())
        tableMenu.addItem(withTitle: "표 나누기", action: #selector(PagesView.splitTable(_:)), keyEquivalent: "")
        tableMenu.addItem(withTitle: "표 붙이기", action: #selector(PagesView.attachNextTable(_:)), keyEquivalent: "")
        tableMenu.addItem(.separator())
        tableMenu.addItem(withTitle: "표 지우기", action: #selector(PagesView.deleteTable(_:)), keyEquivalent: "")
        addSubmenu(tableMenu, titled: "표", to: mainMenu)

        let pageMenu = NSMenu(title: "쪽")
        let pageBreak = pageMenu.addItem(withTitle: "쪽 나누기", action: #selector(PagesView.insertPageBreak(_:)), keyEquivalent: "\r")
        pageBreak.keyEquivalentModifierMask = [.command]
        let columnBreak = pageMenu.addItem(withTitle: "단 나누기", action: #selector(PagesView.insertColumnBreak(_:)), keyEquivalent: "\r")
        columnBreak.keyEquivalentModifierMask = [.command, .shift]
        let columnMenu = NSMenu(title: "단")
        for (title, count) in [("하나", 1), ("둘", 2), ("셋", 3)] {
            columnMenu.addItem(withTitle: title, action: #selector(PagesView.setColumnCount(_:)), keyEquivalent: "").tag = count
        }
        columnMenu.addItem(.separator())
        columnMenu.addItem(withTitle: "다단 설정…", action: #selector(PagesView.showColumnSettings(_:)), keyEquivalent: "")
        addSubmenu(columnMenu, titled: "단", to: pageMenu)
        pageMenu.addItem(.separator())
        pageMenu.addItem(withTitle: "머리말…", action: #selector(PagesView.editHeader(_:)), keyEquivalent: "")
        pageMenu.addItem(withTitle: "꼬리말…", action: #selector(PagesView.editFooter(_:)), keyEquivalent: "")
        let numberMenu = NSMenu(title: "쪽 번호 넣기")
        for (title, tag) in [("위 왼쪽", -1), ("위 가운데", -2), ("위 오른쪽", -3), ("아래 왼쪽", 1), ("아래 가운데", 2), ("아래 오른쪽", 3)] {
            numberMenu.addItem(withTitle: title, action: #selector(PagesView.insertPageNumber(_:)), keyEquivalent: "").tag = tag
        }
        addSubmenu(numberMenu, titled: "쪽 번호 넣기", to: pageMenu)
        pageMenu.addItem(.separator())
        pageMenu.addItem(withTitle: "편집 용지…", action: #selector(PagesView.showPageSetup(_:)), keyEquivalent: "")
        addSubmenu(pageMenu, titled: "쪽", to: mainMenu)

        let viewMenu = NSMenu(title: "보기")
        viewMenu.addItem(withTitle: "실제 크기", action: #selector(DocumentWindowController.zoomToActualSize(_:)), keyEquivalent: "0")
        viewMenu.addItem(withTitle: "확대", action: #selector(DocumentWindowController.zoomIn(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "축소", action: #selector(DocumentWindowController.zoomOut(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "폭 맞춤", action: #selector(DocumentWindowController.zoomToFitWidth(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: "쪽 맞춤", action: #selector(DocumentWindowController.zoomToFitPage(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: "배율…", action: #selector(DocumentWindowController.showZoomPrompt(_:)), keyEquivalent: "")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "문단 부호", action: #selector(PagesView.toggleParagraphMarks(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: "조판 부호", action: #selector(PagesView.toggleControlCodes(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: "투명 선", action: #selector(PagesView.toggleTransparentBorders(_:)), keyEquivalent: "")
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

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === styleMenu else { return }
        menu.removeAllItems()
        let view = (NSApp.mainWindow?.windowController as? DocumentWindowController)?.pagesView
        let listing = view?.paragraphStyles()
        let styles = listing?.styles ?? []
        let current = listing?.current
        if styles.isEmpty {
            menu.addItem(withTitle: "문서를 편집할 때 쓸 수 있습니다", action: nil, keyEquivalent: "").isEnabled = false
        }
        for style in styles {
            let item = menu.addItem(withTitle: style.name, action: #selector(PagesView.applyStyle(_:)), keyEquivalent: "")
            item.tag = style.id
            item.state = style.id == current ? .on : .off
        }
    }

    private func addSubmenu(_ submenu: NSMenu, titled title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        menu.addItem(item)
    }
}
