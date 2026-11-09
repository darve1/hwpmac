# 웹 한글 편집기 기능 대비표

기준: rhwp-studio(rhwp v0.9.0, c9095c5)의 명령 목록 `rhwp-studio/src/command/commands/*.ts`,
160개. 같은 rhwp 엔진으로 만든 웹 편집기이므로, 이 앱이 그 명령을 얼마나 갖췄는지를 셉니다.

- **됨**: 메뉴나 단축키로 쓸 수 있습니다. 편집·서식·찾기·표 명령은 `Tests/HwpMacTests`와
  rhwp 쪽 `native_host` 테스트로 엔진 동작을 확인합니다. 열기·최근 문서·인쇄처럼 macOS가
  제공하는 부분은 따로 테스트하지 않습니다.
- **부분**: 쓸 수 있지만 웹 편집기보다 범위가 좁습니다(비고 참고).
- **아직**: 없습니다.

| 묶음 | 됨 | 부분 | 아직 | 계 |
| --- | ---: | ---: | ---: | ---: |
| 편집 | 13 | 0 | 4 | 17 |
| 파일 | 13 | 1 | 0 | 14 |
| 서식 | 31 | 0 | 5 | 36 |
| 입력 | 12 | 1 | 13 | 26 |
| 쪽 | 13 | 0 | 9 | 22 |
| 표 | 13 | 1 | 13 | 27 |
| 하이퍼링크 | 3 | 0 | 0 | 3 |
| 보기 | 8 | 0 | 6 | 14 |
| 도구 | 0 | 0 | 1 | 1 |
| **합계** | **106** | **3** | **51** | **160** |

## 편집

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| edit:undo, edit:redo | 됨 | |
| edit:cut, edit:copy, edit:paste | 됨 | 일반 텍스트. 표 셀 안에서도 됩니다. |
| edit:select-all | 됨 | 표 셀 안에서는 그 셀의 글자 전체 |
| edit:find, edit:find-replace, edit:find-again | 됨 | 본문과 표 셀(중첩 포함). 글상자·수식 안은 찾지 않습니다. |
| edit:delete | 됨 | Delete 키 |
| edit:format-copy, edit:format-paste | 됨 | 모양 복사(⌥⌘C)·모양 붙이기(⌥⌘V): 캐럿 자리의 글자·문단 모양을 고른 글자·문단에 |
| edit:compare-documents, edit:document-history | 아직 | |
| edit:goto | 됨 | 쪽 찾아가기(⌥⌘G) |
| field:edit, field:remove | 아직 | |

## 파일

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| file:new-doc, file:open, file:open-recent, file:clear-recent | 됨 | |
| file:save, file:save-as, file:save-as-hwp, file:save-as-hwpx | 됨 | |
| file:print | 됨 | |
| file:print-to-pdf | 부분 | PDF로 내보내기와 인쇄 → PDF. rhwp 벡터 PDF라 한 번에 256쪽까지(웹 편집기는 브라우저 인쇄로 모든 쪽) |
| file:page-setup | 됨 | 편집 용지(F7): 용지 종류·방향·크기·여백. 캐럿이 있는 구역에 적용 |
| file:export-html, file:export-doc | 됨 | HTML로, Word 문서(.doc, HTML 기반)로 내보내기. 웹 편집기와 같이 구역별 HTML 조각을 묶습니다. |
| file:about | 됨 | HwpMac 정보: 버전, 출처 표기, 상표 고지, rhwp 라이선스 |

## 서식

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| format:bold, format:italic, format:underline, format:strikethrough | 됨 | |
| format:font-size-increase, format:font-size-decrease | 됨 | 1pt씩 |
| format:align-left, -center, -right, -justify | 됨 | |
| format:line-spacing | 됨 | 100·130·160·180·200% |
| format:char-shape | 됨 | 글자 모양…(⌥⌘L): 글꼴, 크기, 장평, 자간, 글자·음영 색, 속성. 언어별 글꼴·테두리·그림자는 아직입니다. |
| format:para-shape | 됨 | 문단 모양…(⌥⌘T): 정렬, 왼쪽·오른쪽 여백, 첫 줄 들여쓰기·내어쓰기, 줄 간격 종류와 값, 문단 위·아래 간격. 탭·테두리·개요 수준은 아직입니다. |
| format:emboss, engrave, outline, superscript, subscript | 됨 | 서식 → 글자 효과. 위/아래 첨자, 양각/음각은 서로 배타 |
| format:line-spacing-decrease, -increase | 됨 | 10%씩, 5~500% |
| format:char-ratio-*, format:char-spacing-* | 됨 | 1%씩. 장평 50~200%, 자간 −50~50% |
| format:align-distribute, format:align-split | 됨 | 배분·나눔 정렬 |
| format:toggle-numbering, format:toggle-bullet | 됨 | 문서의 첫 문단 번호 정의, 글머리표 ● |
| format:apply-style | 됨 | 서식 → 스타일: 문서의 문단 스타일(본문과 바깥 표 셀) |
| format:level-increase, format:level-decrease | 됨 | 개요 수준 낮추기·높이기(개요 1~7 스타일 사이) |
| format:style-dialog | 아직 | 스타일 정의 고치기 |
| format:apply-bullet, para-num-shape, bullet-shape | 아직 | 글머리표 문자·번호 모양 고르기 |
| format:object-properties | 아직 | |

## 표

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| table:create | 됨 | 줄·칸 개수 입력 |
| table:insert-row-above, -below, table:insert-col-left, -right | 됨 | |
| table:delete-row, table:delete-col | 됨 | 마지막 줄·칸이면 표를 지웁니다. |
| table:cell-split | 됨 | N줄 × M칸 |
| table:delete | 됨 | |
| table:cell-merge | 부분 | 오른쪽/아래 셀과 합치기. 여러 셀을 블록으로 골라 합치기는 아직입니다. |
| (셀 안 글자 편집, Tab/Shift-Tab 이동) | 됨 | 웹 편집기의 기본 동작. 마지막 셀에서 Tab은 줄을 추가합니다. |
| table:cell-props, table:border-each, table:border-one | 아직 | |
| table:insert-row-col | 됨 | 줄/칸 추가…: 위·아래·왼쪽·오른쪽, 개수(한 번의 실행 취소) |
| table:delete-row-col | 됨 | 줄 지우기·칸 지우기 메뉴 |
| table:transpose-copy, table:transpose-paste | 아직 | |
| table:split, table:attach | 됨 | 표 나누기(캐럿 줄부터 새 표), 표 붙이기(사이에 빈 문단만 있을 때) |
| table:caption-toggle | 아직 | |
| table:cell-height-equal, table:cell-width-equal | 아직 | 웹 편집기에서도 등록만 되어 있고 동작하지 않습니다(`execute() {}`). |
| table:formula, table:block-formula, table:thousand-sep, table:decimal-add, table:decimal-remove | 아직 | |

줄·칸 편집은 본문에 놓인 표에만 됩니다. 표 안의 표(중첩 표)는 글자 편집만 됩니다.

## 쪽

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| page:setup | 됨 | file:page-setup과 같은 편집 용지 |
| page:break, page:column-break | 됨 | ⌘Return, ⇧⌘Return. 본문에서만 |
| page:page-border | 아직 | |
| page:header-create, page:footer-create, page:headerfooter-delete | 됨 | 쪽 → 머리말…/꼬리말…: 양쪽·짝수·홀수 쪽별 글자 편집 대화상자. 쪽 위에서 바로 고치지는 않습니다. |
| page:insert-field-pagenum, -totalpage, -filename | 됨 | 머리말/꼬리말 대화상자의 넣기 단추 |
| page:apply-hf-template | 됨 | 쪽 → 쪽 번호 넣기(위·아래 × 왼쪽·가운데·오른쪽) |
| page:headerfooter-close, -prev, -next | 아직 | 쪽 위 편집 모드용 |
| page:hide-headerfooter, page:hide-current, page:new-page-num | 아직 | |
| page:hide | 아직 | |
| page:col-left, page:col-right, page:col-settings | 됨 | 쪽 → 단: 하나·둘·셋, 다단 설정…(개수, 간격 mm). 웹 편집기처럼 왼쪽·오른쪽 단 우세는 둘 다 같은 2단입니다. |
| page:section-settings | 아직 | 구역 설정 |

## 입력

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| insert:bookmark | 됨 | 입력 → 책갈피…(본문 캐럿 자리) |
| insert:symbols | 됨 | 입력 → 문자표…(⌃⌘Space, macOS 문자 보기) |
| insert:image | 됨 | 입력 → 그림…: 캐럿 자리에 떠 있는 그림(한글 기본처럼 글자처럼 취급 아님), 본문 폭에 맞춰 줄임. PNG·JPEG·GIF·BMP·TIFF는 그대로, 그 밖(HEIC 등)은 PNG로 |
| insert:picture-delete | 됨 | 그림·도형을 눌러 고른 뒤 Delete, 또는 개체 → 개체 지우기 |
| insert:arrange-front, -forward, -backward, -back | 됨 | 개체 → 맨 앞으로·앞으로·뒤로·맨 뒤로. 웹 편집기처럼 도형에만 됩니다. |
| insert:rotate-cw, rotate-ccw, flip-horz, flip-vert | 됨 | 개체 → 90° 회전, 좌우·상하 대칭(그림) |
| insert:picture-props | 부분 | 개체 속성…: 너비·높이(비율 유지)만. 위치·배치·자르기·효과는 아직 |
| insert:shape, textbox, equation, chart-data-edit, equation-edit | 아직 | 개체 넣기 |
| insert:footnote, endnote, note-close, endnote-shape | 아직 | 각주·미주 |
| insert:field | 아직 | 누름틀 |
| insert:caption-toggle, group-shapes, ungroup-shapes | 아직 | |

## 하이퍼링크

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| insert:hyperlink | 됨 | 입력 → 하이퍼링크…(⌘K): 고른 글자에 웹 주소 |
| hyperlink:edit, hyperlink:remove | 됨 | 캐럿이 링크 안에 있을 때 주소 고치기·지우기(글자는 남음) |

## 도구

tool:options(환경 설정)는 아직입니다.

## 보기

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| view:zoom-in, view:zoom-out | 됨 | 실제 크기도 있습니다. |
| view:zoom-dialog, zoom-fit-page, zoom-fit-width | 됨 | 보기 → 배율…, 쪽 맞춤, 폭 맞춤 |
| view:para-mark, view:ctrl-mark, view:border-transparent | 됨 | 보기 → 문단 부호, 조판 부호, 투명 선(화면에만, 인쇄·PDF에는 안 나옴) |
| view:form-mode, toggle-clip, toggle-grid, grid-settings | 아직 | |
| view:toolbox-basic, view:toolbox-format | 아직 | 도구 상자 |
