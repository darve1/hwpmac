# HwpMac

macOS에서 한글 문서(.hwp, .hwpx)를 열고, 본문을 고치고, 저장하는 네이티브 앱입니다.
문서 엔진은 [rhwp](https://github.com/edwardkim/rhwp)(Rust, MIT) v0.9.0에 네이티브 편집 동작을 더한
[포크 브랜치](https://github.com/darve1/rhwp/tree/hwpmac/native-actions)를 고정해 쓰고,
앱은 AppKit으로 만들었습니다.

본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.
"한글", "한컴", "HWP", "HWPX"는 주식회사 한글과컴퓨터의 등록 상표이며, 이 프로젝트는
한글과컴퓨터와 제휴, 후원, 승인 관계가 없습니다.

## 할 수 있는 것

- .hwp/.hwpx 열기, 새 빈 문서, 쪽 보기, 확대·축소, 전체 화면
- 본문 문단 편집(L1): 한글 조합 입력, 한자 변환, 삭제, 문단 나누기, 선택, 실행 취소·복귀, 복사·붙이기
- 글자·문단 서식(L2): 굵게·기울임·밑줄·취소선, 위/아래 첨자, 양각·음각·외곽선, 글자 크기·글꼴·색,
  장평·자간, 정렬(배분·나눔 포함), 줄 간격, 들여쓰기, 문단 번호·글머리표
- 찾기·바꾸기·모두 바꾸기(본문과 표 셀)
- 표(L3): 표 만들기, 셀 안 글자 편집과 서식, Tab/Shift-Tab 셀 이동, 줄·칸 추가·삭제, 셀 합치기·나누기,
  표 나누기·붙이기, 셀 속성(배경·정렬·안 여백·테두리), 계산식과 쉬운 계산식, 세 자리 쉼표, 캡션, 표 지우기
- 개체: 그림·도형(사각형·타원·직선·빈 글상자) 넣기, 눌러 고르기, 지우기, 순서, 회전·대칭, 개체 속성
  (크기·회전·캡션, 도형의 선·채우기), Shift-클릭으로 여러 개 골라 묶기·풀기
- 쪽: 쪽·단 나누기, 다단, 편집 용지(용지·방향·여백), 구역 설정, 쪽 테두리/배경, 감추기, 새 쪽 번호,
  머리말·꼬리말 글자와 쪽 번호·전체 쪽 수·파일 이름 필드, 쪽 번호 넣기
- 보기: 문단 부호, 조판 부호, 투명 선, 쪽 밖 내용 자르기, 격자, 쪽 맞춤·폭 맞춤, 쪽 이동
- 각주·미주(넣기·고치기·지우기, 각주 모양·미주 모양), 수식(한글 수식 문법으로 넣기·고치기),
  누름틀(넣기·채우기·고치기)과 양식 모드(누름틀만 입력, Tab으로 이동).
  글자처럼 취급하는 표·그림·수식이 든 문단도 편집
- 하이퍼링크, 책갈피, 문자표, 스타일(적용·편집·추가·삭제)과 개요 수준, 문단 번호 모양, 모양 복사, HTML·Word(HTML 기반 .doc) 내보내기, 복구용 자동 저장
- 인쇄, PDF로 내보내기(rhwp 벡터 PDF, 256쪽까지)
- HWP/HWPX로 저장, 다른 이름으로 저장(형식 변환). 처음 원본을 덮어쓸 때 확인, rhwp가 보고한 손실은 쓰기 전에 표시
- Finder Quick Look 미리보기(앞 10쪽)와 아이콘 썸네일
- 문서 엔진을 파일 접근 권한이 없는 별도 샌드박스 프로세스(XPC)에서 실행. 엔진이 죽어도 앱은 남고 문서를 다시 엶
- Spotlight 본문 검색: 앱에 들어 있는 Spotlight importer 플러그인이 rhwp로 본문과 쪽 수를 읽음

웹 한글 편집기(rhwp-studio)의 명령 160개 가운데 138개가 되고 11개는 일부만 됩니다. 명령별 상태는
[기능 대비표](docs/web-editor-parity.md)에 있습니다. 문서 비교·이력, 차트 데이터, 표 셀 블록 선택(행/열 바꿈 등),
글상자·캡션 안 글자 편집, 쪽 위에서 바로 고치는 머리말·꼬리말, 암호 문서는 아직 안 됩니다.

## 빌드

필요한 것: Apple silicon Mac, Xcode 27 이상, Homebrew의 `rustup`과 `xcodegen`.

```sh
git submodule update --init          # third_party/rhwp (darve1/rhwp, hwpmac/native-actions)
./scripts/build-native.sh            # rhwp FFI(Skia 렌더링) → build/native/lib
xcodegen generate                    # project.yml → HwpMac.xcodeproj
xcodebuild -project HwpMac.xcodeproj -scheme HwpMac -configuration Release \
  -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Release/HwpMac.app
```

테스트: `xcodebuild -project HwpMac.xcodeproj -scheme HwpMac -derivedDataPath build/DerivedData test`

### 배포 서명

로컬 빌드는 임시(ad-hoc) 서명이고 hardened runtime이 꺼져 있습니다. 임시 서명끼리는 팀 ID가
없어서 hardened runtime이 따로 서명된 rhwp dylib를 거부하기 때문입니다. 배포하려면
`project.yml`에서 `DEVELOPMENT_TEAM`, `CODE_SIGN_IDENTITY: Developer ID Application`,
`ENABLE_HARDENED_RUNTIME: YES`로 바꾸고(앱·확장·dylib가 같은 팀으로 서명됨), Release로
빌드한 뒤 `xcrun notarytool submit`과 `xcrun stapler staple`을 실행합니다. 아직 해 보지 않았습니다.

## 구조

| 위치 | 역할 |
| --- | --- |
| `third_party/rhwp` | 문서 엔진(파싱, 조판, 렌더링, 편집, 저장). v0.9.0에 네이티브 편집 동작(서식, 찾기, 표 셀 편집, 표·쪽·머리말·개체 동작)을 더한 [darve1/rhwp](https://github.com/darve1/rhwp/tree/hwpmac/native-actions)의 `hwpmac/native-actions` |
| `App/Sources/Engine` | rhwp 세션 래퍼(`RhwpSession`), 편집 상태(`DocumentEditor`), 전용 스레드 엔진(`DocumentEngine`), XPC 프로토콜(`EngineXPC`), Quick Look용 렌더러 |
| `App/Sources/UI` | NSDocument, XPC 클라이언트(`RemoteDocumentEngine`), 쪽 보기·편집 뷰(`PagesView`, NSTextInputClient), 메뉴, 도움말 |
| `Services/EngineService` | 문서 엔진 XPC 서비스. 샌드박스 권한 외에는 아무 권한도 없음 |
| `Extensions` | Quick Look 미리보기·썸네일 확장 |
| `Importers/SpotlightImporter` | Spotlight importer 플러그인(.mdimporter, `Contents/Library/Spotlight`) |
| `Tools` | 검증 도구: 쪽 렌더(`hwpmac-render-snapshot`), 편집 경로 검사(`hwpmac-edit-check`), 입력 지연(`hwpmac-latency`) |
| `scripts` | 네이티브 빌드, 코퍼스 편집 검사, 열기 시간 측정 |
| `research` | 0단계 근거 조사 기록(출처 사본과 인용) |
| `verification` | 측정 결과 |

앱은 문서 파일을 읽어 그 바이트만 XPC 서비스(`EngineService`)로 보냅니다. 서비스는 파일·네트워크
권한 없이 파싱, 조판, 편집, 직렬화를 하고 상태(JSON), 쪽 픽셀, 저장할 바이트를 돌려줍니다. 악성 문서가
파서를 장악해도 그 프로세스 밖의 파일에는 닿지 못하고, 엔진이 죽으면 앱이 알리고 문서를 다시 엽니다.
(`HWPMAC_IN_PROCESS_ENGINE=1`이면 앱 안에서 돌립니다.)

rhwp 세션은 연 스레드에서만 쓸 수 있고, 편집할 때마다 문서 전체의 쪽 나누기를 다시 합니다.
그래서 서비스 안에서도 문서마다 전용 스레드(`EngineThread`)에서 엔진을 돌리고, UI는 기다리지 않습니다.
엔진이 바쁜 동안 들어온 입력은 한 번에 합쳐 적용하고, 엔진이 느리면 조합 중인 글자와 아직
반영되지 않은 글자를 캐럿 자리에 바로 그립니다.

## 검증 현황

처음 정한 통과 기준과 2026-11-09 측정값입니다. 코퍼스는 rhwp 저장소의 샘플 375개입니다.

| 기준 | 측정 | 상태 |
| --- | --- | --- |
| 1. 견고성 | 375개 중 372개 열림(실패 3개는 암호 문서). 프로세스 충돌 0, 엔진이 끝나지 않은 문서 1개. 퍼징 스모크: HWP·HWPX 파서 각 15분(ASan), 129만 회 실행에 발견 0 ([결과](verification/fuzz-smoke-2026-11-09/README.md)) | T(대상마다 24시간, 커버리지 정체) **미달** |
| 2. 무손실(편집 경로) | 320개 문서에서 편집 → HWP·HWPX 저장 → 다시 열기, 넣은 글자 320/320 보존, 손실 보고 0 ([결과](verification/edit-sweep-2026-11-09/README.md)) | 필드 단위 비교는 rhwp CI에 의존 |
| 2a. 무손실(개체 문단·표 셀) | 개체·필드가 든 문단도 편집하게 된 뒤 같은 375개: 346개 편집 → 저장 → 다시 열기, 346/346 보존, 손실 보고 0 ([결과](verification/edit-sweep-objects-2026-11-10/README.md)). 글자처럼 취급하는 표·그림·수식·각주가 든 문단까지 편집하게 된 뒤: 371개 편집, HWP·HWPX 각 371/371 보존, 손실 보고 0 ([결과](verification/edit-sweep-inline-2026-11-10/README.md)). 표 셀 편집 186개, 셀 글자 186/186 보존, 손실 보고 0 ([결과](verification/edit-sweep-cells-2026-11-10/README.md)) | 이 저장본들의 한글 Viewer 확인은 **아직**(사용자가 말할 때 실행) |
| 2b. 무손실(서식) | 같은 320개 문서에서 L1 편집 + 굵게·빨강·가운데 정렬 → HWP·HWPX 저장 → 다시 열어 속성 확인: 320/320, 손실 보고 0 ([결과](verification/edit-sweep-format-2026-11-10/README.md)) | |
| 3. 진짜 한글로 다시 열기 | 한글 Viewer 12.31.9(Mac): 저장본 1,264개 중 1,261개(99.8%) 열림. 실패 3건은 모두 HWP 출력(HWP 3.0 원본 2건, 변경 추적 문서 편집 후 1건), 같은 문서의 HWPX는 열림 ([결과](verification/hancom-viewer-2026-11-09/README.md)). 서식 저장본: 632개 중 630개 열림, 실패 2건은 위와 같은 문서 ([결과](verification/hancom-viewer-format-2026-11-10/README.md)) | Windows 한글 편집기로는 미실시. Viewer는 열리는지만 보며 서식이 같게 보이는지는 비교하지 않음 |
| 4. 텍스트·개체 | 한글 Viewer의 문서 통계(표본 57개 문서): 저장본 225/225가 원본과 글자 수·문단·표·그림·글상자 수 일치(편집본은 넣은 만큼만 차이) ([결과](verification/hancom-statistics-2026-11-10/README.md)) | 개수 비교라 글자 단위 CER은 아님. Windows 한글 미실시 |
| 5. 레이아웃(쪽 수) | 같은 표본에서 편집 전 저장본 113/114가 원본과 쪽 수 일치(불일치 1건은 HWP 3.0 원본의 HWPX 저장) | Viewer 한 종류 기준. 한컴 두 버전 비교 미실시 |
| 6. HWPX 스키마 | — | **미실시**: KS X 6101:2024는 유료이고 XSD 포함 여부 미확인 |
| 7. 다른 구현과 비교 | — | 미실시 |
| 8. 성능 | 100쪽 이상 13개 문서 열기 p95 1.09초(엔진 기준, [결과](verification/open-timing-2026-11-09/results.json)). 키 입력 시 메인 스레드 사용 0.014ms 이하. 383쪽 문서에서 빠른 타자 후 반영까지 1.0초 | 엔진이 가끔 한 번 편집에 수십~수백 초 걸림(업스트림 문제) |
| 9. 플랫폼 | 앱·확장·엔진 서비스 샌드박스, Quick Look 썸네일(`qlmanage -t -x`로 확인), 미리보기 PDF 경로 확인, Spotlight: 새 파일이 약 15초 안에 본문·쪽 수와 함께 색인되고 `mdfind`로 본문 검색됨 | 공증: 해당 없음(GitHub 소스 배포로 결정) |
| (3단계) 파서 격리 | 엔진을 권한 없는 XPC 서비스로 분리. 서비스를 `kill -9`해도 앱 생존 확인 | |

### 사용자에게 필요한 것

- **Windows 한글**(2018/2022/2024): 기준 4와 Windows 편집기 기준의 3. 아래 절차는 준비돼 있고, 한글이
  설치된 Windows에서 실행만 하면 됩니다. (Mac 한글 Viewer로 하는 검사는 `scripts/viewer-sweep.py`.)
- **한컴 두 버전의 PDF**: 기준 5.
- 공증은 하지 않습니다. 이 프로젝트는 GitHub에서 소스로 배포하고, 각자 빌드합니다.

### 진짜 한글로 검증하기 (기준 3, 4)

rhwp의 `tools/loadsave_sweep/oracle_run.ps1`은 설치된 한글을 COM으로 조작해 파일마다 열기 성공 여부,
한글이 뽑은 본문, 쪽 수, 개체 수를 기록합니다. 편집 검사 결과를 그 입력 형식으로 묶습니다.

```sh
# 1. Mac: 문서마다 원본 + 이 앱 경로로 저장한 4개(편집 전/후 × HWP/HWPX)를 묶음
python3 scripts/edit-sweep.py build/DerivedData/Build/Products/Debug/hwpmac-edit-check build/edit-check 180 \
  third_party/rhwp/samples/*.hwp third_party/rhwp/samples/*.hwpx
python3 scripts/oracle-bundle.py bundle build/edit-check build/edit-check/inputs.list0 build/oracle-bundle 'C:\hwpmac-oracle'
```

`build/oracle-bundle`(2026-11-09 기준 320개 문서, 1,600개 파일, 1.3GB)을 Windows의 `C:\hwpmac-oracle`로
복사하고, rhwp 저장소에서 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\loadsave_sweep\oracle_run.ps1 `
  -HwpVersion 2022 -TaskPath C:\hwpmac-oracle\oracle_tasks.tsv -OutDir C:\hwpmac-oracle\oracle_2022 -HideWindow
powershell -NoProfile -File tools\hangul_version_oracle\restore_com_default.ps1
```

결과(`oracle_2022\result.tsv`)를 Mac으로 가져와 판정합니다. 저장본이 한글에서 열리는지, 편집하지 않은
저장본이 원본과 같은 글자 수·개체를 갖는지, 편집한 저장본은 넣은 글자만큼만 달라졌는지 셉니다.

```sh
python3 scripts/oracle-bundle.py judge build/oracle-bundle result.tsv
```

## 알려진 한계

- Apple silicon 전용(rhwp 라이브러리를 arm64로만 빌드).
- XPC 서비스는 앱마다 한 프로세스라, 그 안에서 열린 여러 문서는 서비스가 죽으면 함께 다시 열립니다.
  엔진이 한 편집에 15초 넘게 걸리면 창에 알리고, **파일 → 문서 엔진 다시 시작**으로 서비스를 끝낼 수 있습니다.
  그러면 저장하지 않은 편집은 사라지고 문서는 디스크에서 다시 열립니다. launchd가 서비스를 다시 띄우기까지
  10초쯤 걸릴 수 있습니다.
- 자동 저장과 버전 기록을 켜지 않았습니다(원본 덮어쓰기를 확인받기 위해).
- NSTextInputClient의 범위는 문단 안 UTF-16 위치로, BMP 밖 글자에서는 근사치입니다.

## 라이선스

이 저장소의 코드는 [PolyForm Noncommercial License 1.0.0](LICENSE.md)을 따릅니다. 개인 사용, 연구, 교육,
비영리 단체 등 **비상업적 목적**으로는 사용, 수정, 배포할 수 있고, 상업적으로 쓰려면 별도 허락이 필요합니다.
OSI가 승인한 오픈소스 라이선스가 아니라 소스 공개(source-available) 라이선스입니다.

- 문서 엔진 rhwp(`third_party/rhwp`)는 MIT License이며 그 저장소의 라이선스를 따릅니다.
- `research/`의 원본 사본(논문, 웹페이지 등)은 저작권 때문에 저장소에 넣지 않았습니다. 출처 URL과 인용문,
  해시는 기록에 남아 있습니다.

