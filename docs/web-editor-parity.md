# 웹 한글 편집기 기능 대비표

기준: rhwp-studio(rhwp v0.9.0, c9095c5)의 명령 목록 `rhwp-studio/src/command/commands/*.ts`,
160개. 같은 rhwp 엔진으로 만든 웹 편집기이므로, 이 앱이 그 명령을 얼마나 갖췄는지를 셉니다.

- **됨**: 메뉴나 단축키로 쓸 수 있습니다. 편집·서식·찾기·표 명령은 `Tests/HwpMacTests`와
  rhwp 쪽 `native_host` 테스트로 엔진 동작을 확인합니다. 열기·최근 문서·인쇄처럼 macOS가
  제공하는 부분은 따로 테스트하지 않습니다.
- **부분**: 쓸 수 있지만 웹 편집기보다 범위가 좁습니다(비고 참고).
- **아직**: 없습니다.

표는 `scripts/parity-count.py`로 셉니다. 스크립트에 명령마다 상태가 적혀 있고, 웹 편집기 명령 목록과
맞지 않으면 실패합니다.

| 묶음 | 됨 | 부분 | 아직 | 계 |
| --- | ---: | ---: | ---: | ---: |
| 편집 | 14 | 0 | 3 | 17 |
| 파일 | 13 | 1 | 0 | 14 |
| 서식 | 32 | 0 | 4 | 36 |
| 입력 | 13 | 2 | 11 | 26 |
| 쪽 | 19 | 0 | 3 | 22 |
| 표 | 19 | 3 | 5 | 27 |
| 하이퍼링크 | 3 | 0 | 0 | 3 |
| 보기 | 11 | 0 | 3 | 14 |
| 도구 | 0 | 1 | 0 | 1 |
| **합계** | **124** | **7** | **29** | **160** |

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
| field:remove | 됨 | 편집 → 누름틀 지우기(캐럿이 본문 필드 안에 있을 때) |
| field:edit | 아직 | 누름틀 속성 고치기 |

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
| format:apply-bullet | 됨 | 서식 → 글머리표 모양: ● ○ ■ □ ◆ ◇ ▶ ✓ ※ - |
| format:para-num-shape, bullet-shape | 아직 | 번호·글머리표 모양 대화상자 |
| format:object-properties | 부분 | 개체 → 개체 속성…(그림·도형): 너비·높이, 회전, 캡션, 도형의 선 색·굵기와 채우기 색. 위치·배치·자르기·효과와 표 개체 속성은 아직(표는 셀 속성…) |

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
| table:cell-props | 됨 | 표 → 셀 속성…: 배경색, 세로 정렬, 안 여백(mm) |
| table:border-one | 부분 | 셀 속성…의 테두리: 네 변 모두 실선 또는 모두 없음만 |
| table:border-each | 부분 | 변마다 다른 선 종류·굵기·색은 아직 |
| table:insert-row-col | 됨 | 줄/칸 추가…: 위·아래·왼쪽·오른쪽, 개수(한 번의 실행 취소) |
| table:delete-row-col | 됨 | 줄 지우기·칸 지우기 메뉴 |
| table:transpose-copy, table:transpose-paste | 아직 | |
| table:split, table:attach | 됨 | 표 나누기(캐럿 줄부터 새 표), 표 붙이기(사이에 빈 문단만 있을 때) |
| table:caption-toggle | 부분 | 표 → 캡션 넣기/빼기: 한글처럼 "표 N" 번호 캡션을 표 아래에 붙입니다. 캡션 글자는 아직 고치지 못합니다. |
| table:cell-height-equal, table:cell-width-equal | 아직 | 웹 편집기에서도 등록만 되어 있고 동작하지 않습니다(`execute() {}`). |
| table:formula, table:block-formula | 됨 | 표 → 계산식…(식과 결과 형식), 쉬운 계산식(위쪽·왼쪽 합계·평균·곱). 셀 글자를 고치면 표의 계산식을 다시 계산합니다. |
| table:thousand-sep, table:decimal-add, table:decimal-remove | 됨 | 표 → 세 자리 쉼표, 자릿수 늘리기·줄이기(웹 편집기와 같은 규칙: 줄이기는 끝자리를 버림) |

줄·칸 편집은 본문에 놓인 표에만 됩니다. 표 안의 표(중첩 표)는 글자 편집만 됩니다.

## 쪽

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| page:setup | 됨 | file:page-setup과 같은 편집 용지 |
| page:break, page:column-break | 됨 | ⌘Return, ⇧⌘Return. 본문에서만 |
| page:page-border | 됨 | 쪽 → 쪽 테두리/배경…: 네 변 선(없음·실선·점선·이중선)과 색, 배경색 |
| page:header-create, page:footer-create, page:headerfooter-delete | 됨 | 쪽 → 머리말…/꼬리말…: 양쪽·짝수·홀수 쪽별 글자 편집 대화상자. 쪽 위에서 바로 고치지는 않습니다. |
| page:insert-field-pagenum, -totalpage, -filename | 됨 | 머리말/꼬리말 대화상자의 넣기 단추 |
| page:apply-hf-template | 됨 | 쪽 → 쪽 번호 넣기(위·아래 × 왼쪽·가운데·오른쪽) |
| page:headerfooter-close, -prev, -next | 아직 | 쪽 위 편집 모드용 |
| page:hide-headerfooter, page:hide-current | 됨 | 쪽 → 감추기…의 머리말·꼬리말. 문서에 감추기 컨트롤로 저장됩니다(웹 편집기의 hide-current는 세션 안에서만 감춤). |
| page:new-page-num | 됨 | 쪽 → 새 쪽 번호…: 캐럿이 있는 쪽부터 다시 매김 |
| page:hide | 됨 | 쪽 → 감추기…: 머리말·꼬리말·바탕쪽·쪽 테두리·쪽 배경·쪽 번호 |
| page:col-left, page:col-right, page:col-settings | 됨 | 쪽 → 단: 하나·둘·셋, 다단 설정…(개수, 간격 mm). 웹 편집기처럼 왼쪽·오른쪽 단 우세는 둘 다 같은 2단입니다. |
| page:section-settings | 됨 | 쪽 → 구역 설정…: 시작 쪽 번호, 첫 쪽에서 감출 것, 기본 탭 간격 |

## 입력

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| insert:bookmark | 됨 | 입력 → 책갈피…(본문 캐럿 자리) |
| insert:symbols | 됨 | 입력 → 문자표…(⌃⌘Space, macOS 문자 보기) |
| insert:image | 됨 | 입력 → 그림…: 캐럿 자리에 떠 있는 그림(한글 기본처럼 글자처럼 취급 아님), 본문 폭에 맞춰 줄임. PNG·JPEG·GIF·BMP·TIFF는 그대로, 그 밖(HEIC 등)은 PNG로 |
| insert:picture-delete | 됨 | 그림·도형을 눌러 고른 뒤 Delete, 또는 개체 → 개체 지우기 |
| insert:arrange-front, -forward, -backward, -back | 됨 | 개체 → 맨 앞으로·앞으로·뒤로·맨 뒤로. 웹 편집기처럼 도형에만 됩니다. |
| insert:rotate-cw, rotate-ccw, flip-horz, flip-vert | 됨 | 개체 → 90° 회전, 좌우·상하 대칭(그림·도형) |
| insert:picture-props | 부분 | 개체 속성…: 너비·높이(비율 유지), 회전, 캡션. 위치·배치·자르기·효과는 아직 |
| insert:shape | 됨 | 입력 → 도형: 사각형, 타원, 직선(30×20mm, 캐럿 자리에 글 앞으로). 고르기·지우기·순서 바꾸기 됨 |
| insert:textbox | 부분 | 빈 글상자를 넣을 수 있지만 안의 글자는 아직 고치지 못합니다. |
| insert:equation, chart-data-edit, equation-edit | 아직 | |
| insert:footnote, endnote, note-close, endnote-shape | 아직 | 각주·미주 |
| insert:field | 아직 | 누름틀 |
| insert:caption-toggle | 부분 | 개체 → 캡션 넣기/빼기(그림·도형): 아래쪽 "그림 N" 캡션, 폭 30mm·간격 3mm(웹 편집기 기본값). 캡션 글자는 아직 고치지 못합니다. |
| insert:group-shapes, ungroup-shapes | 됨 | 개체를 고른 뒤 Shift-클릭으로 더 고르고 개체 → 개체 묶기. 묶음을 고르고 개체 풀기(한 단계) |

## 하이퍼링크

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| insert:hyperlink | 됨 | 입력 → 하이퍼링크…(⌘K): 고른 글자에 웹 주소 |
| hyperlink:edit, hyperlink:remove | 됨 | 캐럿이 링크 안에 있을 때 주소 고치기·지우기(글자는 남음) |

## 도구

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| tool:options | 부분 | HwpMac → 설정…(⌘,): 복구용 자동 저장과 간격. 웹 편집기의 글꼴 탭(대표 글꼴, 최근 글꼴 수)은 macOS 글꼴 패널이 대신하며 따로 없습니다. |

## 보기

| 명령 | 상태 | 비고 |
| --- | --- | --- |
| view:zoom-in, view:zoom-out | 됨 | 실제 크기도 있습니다. |
| view:zoom-dialog, zoom-fit-page, zoom-fit-width | 됨 | 보기 → 배율…, 쪽 맞춤, 폭 맞춤 |
| view:para-mark, view:ctrl-mark, view:border-transparent | 됨 | 보기 → 문단 부호, 조판 부호, 투명 선(화면에만, 인쇄·PDF에는 안 나옴) |
| view:toggle-clip | 됨 | 보기 → 쪽 밖 내용 자르기 |
| view:toggle-grid | 됨 | 보기 → 격자 보기: 본문 모서리에서 시작하는 격자를 화면에만 그립니다(문서는 그대로). |
| view:grid-settings | 부분 | 보기 → 격자 설정…: 모양(점·가로줄·세로줄·둘 다)과 가로·세로 간격(1~100mm). 개체를 격자에 맞추기(자석)와 기준점·오프셋은 아직 — 개체 끌어 옮기기가 아직 없습니다. |
| view:form-mode | 아직 | 양식 모드(누름틀만 입력) |
| view:toolbox-basic, view:toolbox-format | 됨 | 창의 도구 상자(저장·실행 취소·찾기·인쇄, 글자·정렬·목록·표·그림). 보기 → 도구 상자 보기·사용자화 |
