# HwpMac

macOS에서 한글 문서(.hwp, .hwpx)를 열고, 본문을 고치고, 저장하는 네이티브 앱입니다.
문서 엔진은 [rhwp](https://github.com/edwardkim/rhwp)(Rust, MIT)를 고정 버전으로 쓰고,
앱은 AppKit으로 만들었습니다.

본 제품은 한글과컴퓨터의 한글 문서 파일(.hwp) 공개 문서를 참고하여 개발하였습니다.
"한글", "한컴", "HWP", "HWPX"는 주식회사 한글과컴퓨터의 등록 상표이며, 이 프로젝트는
한글과컴퓨터와 제휴, 후원, 승인 관계가 없습니다.

## 할 수 있는 것

- .hwp/.hwpx 열기, 쪽 보기, 확대·축소, 전체 화면
- 본문 문단 편집(L1): 한글 조합 입력, 한자 변환, 삭제, 문단 나누기, 선택, 실행 취소·복귀, 복사·붙이기
- HWP/HWPX로 저장, 다른 이름으로 저장(형식 변환). 처음 원본을 덮어쓸 때 확인, rhwp가 보고한 손실은 쓰기 전에 표시
- Finder Quick Look 미리보기(앞 10쪽)와 아이콘 썸네일
- 문서 엔진을 파일 접근 권한이 없는 별도 샌드박스 프로세스(XPC)에서 실행. 엔진이 죽어도 앱은 남고 문서를 다시 엶
- Spotlight 가져오기 확장(아직 동작 미확인, 아래 '알려진 한계')

표 안 글자, 글상자, 개체가 든 문단, 머리말·꼬리말, 암호 문서는 아직 편집하지 못합니다.

## 빌드

필요한 것: Apple silicon Mac, Xcode 27 이상, Homebrew의 `rustup`과 `xcodegen`.

```sh
git submodule update --init          # third_party/rhwp (v0.9.0)
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
| `third_party/rhwp` | 문서 엔진(파싱, 조판, 렌더링, 편집, 저장). 수정하지 않는 업스트림 |
| `App/Sources/Engine` | rhwp 세션 래퍼(`RhwpSession`), 편집 상태(`DocumentEditor`), 전용 스레드 엔진(`DocumentEngine`), XPC 프로토콜(`EngineXPC`), Quick Look용 렌더러 |
| `App/Sources/UI` | NSDocument, XPC 클라이언트(`RemoteDocumentEngine`), 쪽 보기·편집 뷰(`PagesView`, NSTextInputClient), 메뉴, 도움말 |
| `Services/EngineService` | 문서 엔진 XPC 서비스. 샌드박스 권한 외에는 아무 권한도 없음 |
| `Extensions` | Quick Look 미리보기·썸네일, Spotlight 가져오기 확장 |
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
| 1. 견고성 | 375개 중 372개 열림(실패 3개는 암호 문서). 프로세스 충돌 0, 엔진이 끝나지 않은 문서 1개 | 퍼징: 아래 참고 |
| 2. 무손실(편집 경로) | 320개 문서에서 편집 → HWP·HWPX 저장 → 다시 열기, 넣은 글자 320/320 보존, 손실 보고 0 ([결과](verification/edit-sweep-2026-11-09/README.md)) | 필드 단위 비교는 rhwp CI에 의존 |
| 3. 진짜 한글로 다시 열기 | — | **미실시**: 한컴오피스 필요 |
| 4. 텍스트(CER) | — | **미실시**: 한글의 텍스트 내보내기 필요 |
| 5. 레이아웃 | — | **미실시**: 한컴 두 버전의 PDF 필요 |
| 6. HWPX 스키마 | — | **미실시**: KS X 6101:2024는 유료이고 XSD 포함 여부 미확인 |
| 7. 다른 구현과 비교 | — | 미실시 |
| 8. 성능 | 100쪽 이상 13개 문서 열기 p95 1.09초(엔진 기준, [결과](verification/open-timing-2026-11-09/results.json)). 키 입력 시 메인 스레드 사용 0.014ms 이하. 383쪽 문서에서 빠른 타자 후 반영까지 1.0초 | 엔진이 가끔 한 번 편집에 수십~수백 초 걸림(업스트림 문제) |
| 9. 플랫폼 | 앱·확장·엔진 서비스 샌드박스, Quick Look 썸네일(`qlmanage -t -x`로 확인), 미리보기 PDF 경로 확인 | 공증 **미실시**: Developer ID 필요. Spotlight 색인 미확인 |
| (3단계) 파서 격리 | 엔진을 권한 없는 XPC 서비스로 분리. 서비스를 `kill -9`해도 앱 생존 확인 | |

### 사용자에게 필요한 것

- **한컴오피스 한글**(Windows 한글 2018/2022/2024): 기준 3~4. 아래 절차는 준비돼 있고, 한글이
  설치된 Windows에서 실행만 하면 됩니다.
- **한컴 두 버전의 PDF**: 기준 5.
- **Apple Developer ID**: 공증과 배포.

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
- Spotlight 가져오기 확장은 등록(`pluginkit`, `mdimport -e`)되지만, 색인할 때 호출되는 것을 아직 보지 못했습니다.
  .hwp/.hwpx 형식을 이 앱이 소유(export)하지 않아서일 수 있습니다.
- XPC 서비스는 앱마다 한 프로세스라, 그 안에서 열린 여러 문서는 서비스가 죽으면 함께 다시 열립니다.
  엔진이 멈추기만 할 때(한 편집에 수백 초)는 UI는 살아 있지만 그 문서의 편집은 끝날 때까지 반영되지 않습니다.
- 자동 저장과 버전 기록을 켜지 않았습니다(원본 덮어쓰기를 확인받기 위해).
- NSTextInputClient의 범위는 문단 안 UTF-16 위치로, BMP 밖 글자에서는 근사치입니다.
