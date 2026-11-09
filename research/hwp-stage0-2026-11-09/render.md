# Research evidence cards

truth_certified: false. Recorded evidence and reviewer judgments; no automatic truth or independence certification.

- Review state: needs_review
- Routes: literature, technical
- Question: macOS 네이티브 HWP/HWPX 편집기 개발 0단계: 공식 스펙·라이선스, 기존 구현의 상태, 첫 편집 단계, 통과 기준 수치의 근거는 무엇인가?

## Search and screening

- literature: 2 completed and 0 failed searches; 2 sources, 2 read in full or relevant sections, 0 abstract only
- technical: 29 completed and 1 failed searches; 39 sources, 37 read in full or relevant sections, 0 abstract only; 35 results reported by searches
- Evidence reviews by method: self 59

## c-spec — As of 2026-11-09 Hancom's download center offers the HWP 5.0 spec revision 1.3 \(stamped 2018-11-08\) plus 배포용 문서 rev 1.2, 수식 rev 1.3 and 차트 rev 1.2. Anyone may build on them, but the product must state '본 제품은 한글과컴퓨터의 한글 문서 파일\(.hwp\) 공개 문서를 참고하여 개발하였습니다.' in its UI, manual, help and source \(only in those that exist\), and the spec itself may only be redistributed unmodified.

- Status: supported
- Scope: Hancom download center page and HWP 5.0 PDF fetched 2026-11-09; the web page's wording \('한컴의 HWP 문서 파일'\) differs slightly from the PDF's \('한글과컴퓨터의 한글 문서 파일'\)
- Resolution: not recorded
- Next action: Before release, pick one attribution wording \(the PDF's, matching rhwp and hwp.js\) and put it in About window, help, manual and every source file header

### Evidence

- e-attr-web [supports, self]: [HWP·OWPML 문서 형식 공개 \| 한컴 다운로드 센터](https://www.hancom.com/support/downloadCenter/hwpOwpml)
  - Location: HWP 문서 파일 형식에 대한 사용권 및 저작권, paragraph 3; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 그러나 반드시 개발 결과물에 “본 제품은 한컴의 HWP 문서 파일\(.hwp\) 공개 문서를 참고하여 개발하였습니다.”라고 제품 내 유저인터페이스, 매뉴얼, 도움말 및 소스에 모두 기재하여야하며 제품이 이러한 구성물이 없을 시에는 존재하는 구성물에만 기재합니다.
  - Context: …. 그리고 본 문서 및 본 문서에 기재된 내용을 참고하여 개발한 결과물에 대한 모든 저작권은 결과물을 개발한 개인 또는 단체에 있을 것입니다.  **[passage]**  한컴은 본 문서 및 본 문서에 기재된 내용을 참고하여 개발한 개인 또는 단체의 결과물에 대해서 어떠한 정확성, 진실성도 보증하지 아니합니다. …
  - Review: Official page states the mandatory attribution sentence and the UI/manual/help/source placement, with fallback to existing parts
  - Preserved: [hancom-dl snapshot](snapshots/hancom-dl/47cee16094a310c0c2248877ff48b38ead1914ff8c66c38f7a5fd868c623783e.html)
- e-dist-web [partial, self]: [HWP·OWPML 문서 형식 공개 \| 한컴 다운로드 센터](https://www.hancom.com/support/downloadCenter/hwpOwpml)
  - Location: 사용권 및 저작권, paragraph 2; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 배포는 원 내용이 일체 수정되지 않은 원본 또는 복사본으로 제한됩니다. 원본 및 복사본은 한컴에서 제공하는 스펙의 최신 버전을 포함하고 있어야 합니다.
  - Context: … 것 외에 복사, 배포, 게재 및 본 문서에 기재되어 있는 내용을 사용하고자 하는 자는 한컴의 본 저작권을 충분히 인식하고 동의하여야 합니다.  **[passage]**  한컴은 한컴오피스 HWP 문서 파일\(.hwp\) 공개 문서에 따라 얻은 결과물을 기초로 또 다른 독점적, 배타적 권리를 취득하고 이를 한컴을 상…
  - Review: Supports only the unmodified-redistribution clause
  - Preserved: [hancom-dl snapshot](snapshots/hancom-dl/47cee16094a310c0c2248877ff48b38ead1914ff8c66c38f7a5fd868c623783e.html)
- e-specs-2014 [partial, self]: [HWP·OWPML 문서 형식 공개 \| 한컴 다운로드 센터](https://www.hancom.com/support/downloadCenter/hwpOwpml)
  - Location: 공유의 가치를 존중하는 열린 한컴, paragraph 2; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 추가로 2014년 10월 HWP 5.0 스펙의 보완 및 배포용 문서, 수식, 차트, 스펙을 공개하였습니다. 파일 형식이 공개된 안내 문서를 이용하여 누구나 다양한 2차 저작물을 만들 수 있습니다.
  - Context: …HWP 2002부터 시작하여 HWP 2014, HWP 2018까지 사용하고 있는 5.x 버전을 공개하였으며, HWPML도 같이 공개하였습니다.  **[passage]**  HWP의 개방형 문서 형식인 OWPML은 HWP 2018 버전부터 ".owpml" 확장자로 지원하고 있으며, 하위 버전은 HWP 2010 버전…
  - Review: Shows the companion specs were published \(2014-10\) and free reuse; no revision numbers
  - Preserved: [hancom-dl snapshot](snapshots/hancom-dl/47cee16094a310c0c2248877ff48b38ead1914ff8c66c38f7a5fd868c623783e.html)
- e-attr-pdf [supports, self]: [한글 문서 파일 형식 5.0 revision 1.3 \(PDF\)](https://cdn.hancom.com/link/docs/%ED%95%9C%EA%B8%80%EB%AC%B8%EC%84%9C%ED%8C%8C%EC%9D%BC%ED%98%95%EC%8B%9D_5.0_revision1.3.pdf)
  - Location: 저작권, p.1 \(text lines 135-140\); version: revision 1.3; read: relevant\_sections; capture: helper\_fetched
  - Passage/observation: 그러나 반드시 개발 결과물에 “본 제품은 한글과컴퓨터의 글 문서 파일\(.hwp\) 공개 문서를 참고하여 개발하였습니다.”라고 제품 내 사용자 인터페이스, 매뉴얼, 도움말 및 소스에 모두 기재하여야 하며
  - Context: … 그리고, 본 문서 및 본 문서에 기재된 내용을 참고하여 개발한 결과물에 대한 모든 저작권은 결과물을 개발한 개인 또는 단체에 있을 것입니다.  **[passage]**  제품이 이러한 구성물이 없을 시에는 존재하는 구성물에만 기재합니다. 한컴은 본 문서 및 본 문서에 기재된 내용을 참고하여 개발한 결과물에 대해…
  - Review: Spec PDF copyright page states the same obligation with the 한글과컴퓨터/한글 wording
  - Preserved: [hwp5-spec snapshot](snapshots/hwp5-spec/1d1da9e6fe22563ae2c5285bbbfc6762974fb7f002278084cbc11e5266bdc782.pdf)
- e-rev [partial, self]: [한글 문서 파일 형식 5.0 revision 1.3 \(PDF\)](https://cdn.hancom.com/link/docs/%ED%95%9C%EA%B8%80%EB%AC%B8%EC%84%9C%ED%8C%8C%EC%9D%BC%ED%98%95%EC%8B%9D_5.0_revision1.3.pdf)
  - Location: title page; version: revision 1.3; read: relevant\_sections; capture: helper\_fetched
  - Passage/observation: revision 1.3:20181108
  - Context: …글 문서 파일 구조 5.0 Hwp Document File Formats 5.0  **[passage]**  글 문서 파일 형식 5.0 차 례 저작권 ·······················································…
  - Review: Gives the HWP 5.0 revision and date only
  - Preserved: [hwp5-spec snapshot](snapshots/hwp5-spec/1d1da9e6fe22563ae2c5285bbbfc6762974fb7f002278084cbc11e5266bdc782.pdf)
- e-js-files [partial, self]: [한컴 다운로드 센터 HWP/OWPML 페이지 스크립트 \(파일 목록\)](https://www.hancom.com/_next/static/chunks/pages/support/downloadCenter/hwpOwpml-13756ec759c456c2.js)
  - Location: page script, fileList for HWP tab; version: unknown; read: relevant\_sections; capture: helper\_fetched
  - Passage/observation: hwpDocName:"한글문서파일형식\_배포용문서\_revision1.2.hwp",pdfDocName:"한글문서파일형식\_배포용문서\_revision1.2.pdf"\},\{title:e\("support-contents:hwpOwpml.hwpDocumentExpression"\),hwpDocName:"한글문서파일형식\_수식\_revision1.3.hwp"
  - Context: …0\_revision1.3.pdf"\},\{title:e\("support-contents:hwpOwpml.hwpDocumentDistribute"\), **[passage]** ,pdfDocName:"한글문서파일형식\_수식\_revision1.3.pdf"\},\{title:e\("support-contents:hwpOwpml.h…
  - Review: Page script lists 배포용 rev1.2 and 수식 rev1.3 file names; file names are the only revision evidence for these
  - Preserved: [hancom-js snapshot](snapshots/hancom-js/28d9771dc8751d8f1f1c3aded4f6350bd02fd10a9574a27be3870ba5e4bcd49c.txt)
- e-js-chart [partial, self]: [한컴 다운로드 센터 HWP/OWPML 페이지 스크립트 \(파일 목록\)](https://www.hancom.com/_next/static/chunks/pages/support/downloadCenter/hwpOwpml-13756ec759c456c2.js)
  - Location: page script, fileList for HWP tab; version: unknown; read: relevant\_sections; capture: helper\_fetched
  - Passage/observation: hwpDocName:"한글문서파일형식\_차트\_revision1.2.hwp"
  - Context: …일형식\_수식\_revision1.3.pdf"\},\{title:e\("support-contents:hwpOwpml.hwpDocumentChart"\), **[passage]** ,pdfDocName:"한글문서파일형식\_차트\_revision1.2.pdf"\}\],r=JSON.parse\(JSON.stringify\(e\("suppo…
  - Review: Page script lists 차트 rev1.2 file name
  - Preserved: [hancom-js snapshot](snapshots/hancom-js/28d9771dc8751d8f1f1c3aded4f6350bd02fd10a9574a27be3870ba5e4bcd49c.txt)

### Origin removal (recorded relations)

- Structure: single_origin
- Unknown origins: none
- Shared dependencies: none
- Basis SHA-256: 89c92cfe974bd792a701b92e4c35297131b93c446fd4e3c0b7c8a03ea77d536c
- Review selection: Only origin
- Exclude hancom-spec (disclosure); remaining supports: none; remaining counterevidence: none
  - Recorded judgment: unresolved (current, self); All support is Hancom's own disclosure. That is the right authority for its own terms, but no independent copy of the terms exists in the records \(rhwp and hwp.js repeat the attribution sentence, which corroborates practice only\)

## c-owpml — KS X 6101 \(OWPML\) was last revised on 2024-10-30 \(410 pages\) and is sold by the Korean Standards Association as a Korean PDF for 242,000원, while Hancom's HWP 5.0 spec still cites the 2011 edition.

- Status: supported
- Scope: KSSN catalog entry fetched 2026-11-09; whether the purchased standard ships an XSD, and its reuse license, were not checked
- Resolution: not recorded
- Next action: Buy or library-access KS X 6101:2024 and check whether XSD files are included and under what terms; otherwise derive a schema from Hancom-saved HWPX files

### Evidence

- e-kssn-hist [supports, self]: [KSSN 표준 상세 KS X 6101](https://www.kssn.net/search/stddetail.do?itemNo=K001010149626)
  - Location: 이력정보 표, rows 1-2; version: unknown; read: relevant\_sections; capture: helper\_fetched
  - Passage/observation: 2024-10-30 개정\(표준\) 사회적 요청에 의한 개정 KS X 6101상세보기 개방형 워드프로세서 마크업 언어\(OWPML\) 문서 구조 2018-11-08 개정\(구판\)
  - Context: …력정보 이력정보 표 표준번호 표준명 고시일 상태 고시사유 비고 KS X 6101상세보기 개방형 워드프로세서 마크업 언어\(OWPML\) 문서 구조  **[passage]**  수요조사 반영에 의한 개정 KS X 6101상세보기 개방형 워드프로세서 마크업 언어\(OWPML\) 문서 구조 2015-07-28 개정\(구판\) 국…
  - Review: History table: 2024-10-30 개정\(표준\) is the current edition, 2018-11-08 now 구판
  - Preserved: [kssn-6101 snapshot](snapshots/kssn-6101/65dbc9f157cd2734eb83709d54f0126dcaad7fa3ab15e9de7dbeb9b7e870c872.html)
- e-kssn-price [partial, self]: [KSSN 표준 상세 KS X 6101](https://www.kssn.net/search/stddetail.do?itemNo=K001010149626)
  - Location: 제공형태; version: unknown; read: relevant\_sections; capture: helper\_fetched
  - Passage/observation: \[한글\]PDF 242,000원
  - Context: …서 구조 발행일 : 2024-10-30 발행기관 : 한국표준협회 즐겨찾기 장바구니 담기 상품이 장바구니에 담겼습니다. 장바구니로 이동 제공형태  **[passage]**  \[한글\]PRINT 242,000원 상세정보 상세정보 표시 분야 정보\(X\) &gt; 전자문서·전자상거래 적용 범위 이 표준에서 규정하고 있는 개방형 …
  - Review: Price and Korean PDF format only
  - Preserved: [kssn-6101 snapshot](snapshots/kssn-6101/65dbc9f157cd2734eb83709d54f0126dcaad7fa3ab15e9de7dbeb9b7e870c872.html)
- e-kssn-pages [partial, self]: [KSSN 표준 상세 KS X 6101](https://www.kssn.net/search/stddetail.do?itemNo=K001010149626)
  - Location: 상세정보, 페이지수; version: unknown; read: relevant\_sections; capture: helper\_fetched
  - Passage/observation: 페이지수 410
  - Context: …시사유 사회적 요청에 의한 개정 KS심사기준 상세정보 - KS심사기준 표 발행일 상태 심사기준파일 사유 KS심사기준 정보가 존재하지 않습니다.  **[passage]**  이력정보 이력정보 표 표준번호 표준명 고시일 상태 고시사유 비고 KS X 6101상세보기 개방형 워드프로세서 마크업 언어\(OWPML\) 문서 구…
  - Review: Page count only
  - Preserved: [kssn-6101 snapshot](snapshots/kssn-6101/65dbc9f157cd2734eb83709d54f0126dcaad7fa3ab15e9de7dbeb9b7e870c872.html)
- e-ks2011-pdf [partial, self]: [한글 문서 파일 형식 5.0 revision 1.3 \(PDF\)](https://cdn.hancom.com/link/docs/%ED%95%9C%EA%B8%80%EB%AC%B8%EC%84%9C%ED%8C%8C%EC%9D%BC%ED%98%95%EC%8B%9D_5.0_revision1.3.pdf)
  - Location: 저작권, p.1; version: revision 1.3; read: relevant\_sections; capture: helper\_fetched
  - Passage/observation: 이러한 결과로 HWPML 스펙이 OWPML란 이름으로 한국산업표준\(KS X 6101:2011\)으로 제정되었습니다.
  - Context: …을 공개한 바 있습니다. 개방형 문서 표준화 및 코드 관련 위원회에도 적극적으로 참여하여 파일 형식의 표준화와 개방성을 위해 노력해 왔습니다.  **[passage]**  또한, 한컴오피스에서 기록물 장기보존 표준 포맷인 PDF/A-1의 지원과 ISO 국제 문서 형식인 ODF와 OOXML 파일 형식의 불러오기와 …
  - Review: Shows the HWP 5.0 spec cites KS X 6101:2011
  - Preserved: [hwp5-spec snapshot](snapshots/hwp5-spec/1d1da9e6fe22563ae2c5285bbbfc6762974fb7f002278084cbc11e5266bdc782.pdf)

### Origin removal (recorded relations)

- Structure: single_origin
- Unknown origins: none
- Shared dependencies: none
- Basis SHA-256: 86c25e360d9925d045a6d1d08ff9f75fdaecb06481186f983668c480100f09d0
- Review selection: Chosen second scenario: checks the claim does not depend on the Hancom citation
- Exclude hancom-spec (disclosure); remaining supports: e-kssn-hist; remaining counterevidence: none
  - Recorded judgment: retained (current, self); Removing Hancom's spec only drops the 'still cites 2011' part; the edition, price and page count remain from KSSN
- Exclude kssn-standard (disclosure); remaining supports: none; remaining counterevidence: none
  - Recorded judgment: unresolved (current, self); Without KSSN only the 2011 citation in Hancom's spec remains, which would support the opposite \(outdated\) edition. Edition date rests on one catalog

## c-rhwp — The rhwp project \(MIT; last push 2026-11-09; release v0.9.0 on 2026-11-08\) reports that it parses HWP 5.0 and HWPX, renders paragraphs, tables, equations, images and charts, saves edited HWP and saves HWPX/HML with semantic preservation, runs 3,400+ Rust tests with visual-regression CI, and has a cargo-fuzz harness that targets crashes, OOM and timeouts but not round-trip fidelity.

- Status: supported
- Scope: Author claims in README and fuzz/README at commit c9095c5 plus GitHub metadata; I did not build or run rhwp
- Resolution: Claim kept as the project's reported capability; the counterevidence shows saved-file fidelity to real 한글 has had defects \(some fixed\), so save correctness is not established by the README
- Next action: Build rhwp at v0.9.0 on this Mac, run its test suite and fuzz smoke, and round-trip a small corpus through real 한글

### Evidence

- e-rhwp-parse [partial, self]: [edwardkim/rhwp README.md @ c9095c5](https://raw.githubusercontent.com/edwardkim/rhwp/c9095c5f67632e6721e800ccc7fb43ea49d26682/README.md)
  - Location: 현재 이정표 v0.5.0 ~ v0.8.x; version: c9095c5f67632e6721e800ccc7fb43ea49d26682; read: full\_text; capture: helper\_fetched
  - Passage/observation: HWP 5.0 / HWPX 파서, 문단·표·수식·이미지·차트 렌더링
  - Context: …서에서 확인할 수 있습니다. \#\# 현재 이정표 \#\#\# v0.5.0 ~ v0.8.x — 뼈대 \(현재\) &gt; 역공학 완성, 읽기/쓰기 기반 구축 -  **[passage]**  - HML\(HWPML 2.9/2.91\) 가져오기: 본문·서식·표·사각형 글상자·지원 수식, loss-safe HML/HWP/HWPX 저장 - …
  - Review: Parsing and rendering scope only
  - Preserved: [rhwp-readme snapshot](snapshots/rhwp-readme/d56b4798ab49577d6e20d219613c349df60edbefd9d61b1a58c2ac238d5e4202.txt)
- e-rhwp-save [supports, self]: [edwardkim/rhwp README.md @ c9095c5](https://raw.githubusercontent.com/edwardkim/rhwp/c9095c5f67632e6721e800ccc7fb43ea49d26682/README.md)
  - Location: Features &gt; Output; version: c9095c5f67632e6721e800ccc7fb43ea49d26682; read: full\_text; capture: helper\_fetched
  - Passage/observation: 저장: HWP 편집 저장, HWPX/HML 의미 보존 저장, HWPX → HWP 변환 경로
  - Context: …ct\`\) - Canvas rendering \(WASM/Web\) + 명시 opt-in 문서 단위 Canvas2D/CanvasKit 자동 선택 -  **[passage]**  - Debug overlay \(paragraph/table boundaries + indices + y-coordinates\) \#\#\# Mult…
  - Review: README states HWP edit-save and HWPX/HML semantic-preserving save — the core write capability claimed; author claim, untested by me
  - Preserved: [rhwp-readme snapshot](snapshots/rhwp-readme/d56b4798ab49577d6e20d219613c349df60edbefd9d61b1a58c2ac238d5e4202.txt)
- e-rhwp-tests [partial, self]: [edwardkim/rhwp README.md @ c9095c5](https://raw.githubusercontent.com/edwardkim/rhwp/c9095c5f67632e6721e800ccc7fb43ea49d26682/README.md)
  - Location: 현재 이정표 v0.5.0 ~ v0.8.x; version: c9095c5f67632e6721e800ccc7fb43ea49d26682; read: full\_text; capture: helper\_fetched
  - Passage/observation: 3,400+ Rust 테스트 + studio 단위/e2e/시각 회귀 CI
  - Context: …nvas/CanvasKit 렌더링 \(WASM/Web\) - 웹 에디터 + hwpctl 호환 API \(30 Actions, Field API\) -  **[passage]**  &gt; HML은 실제 corpus로 확인된 HWPML 2.9/2.91 구조만 제한 지원합니다. 지원 범위의 수식은 &gt; 가져와 편집할 수 있고, 보…
  - Review: Test count and visual-regression CI only \(author claim\)
  - Preserved: [rhwp-readme snapshot](snapshots/rhwp-readme/d56b4798ab49577d6e20d219613c349df60edbefd9d61b1a58c2ac238d5e4202.txt)
- e-rhwp-meta [partial, self]: [GitHub API repos/edwardkim/rhwp \(fetched with gh, 2026-11-09\)](https://api.github.com/repos/edwardkim/rhwp)
  - Location: repository JSON: pushed\_at; version: unknown; read: full\_text; capture: downloaded
  - Passage/observation: "pushed\_at":"2026-11-09T02:50:40Z"
  - Context: …yments","created\_at":"2026-03-27T05:54:10Z","updated\_at":"2026-11-09T02:09:10Z", **[passage]** ,"git\_url":"git://github.com/edwardkim/rhwp.git","ssh\_url":"git@github.com:edwar…
  - Review: Last push date only
  - Preserved: [rhwp-api snapshot](snapshots/rhwp-api/4f7a435e0f2aacc5918c9bc31074ada76c6fffe59e89c35484fd5318f02aed8f.txt)
- e-rhwp-lic [partial, self]: [GitHub API repos/edwardkim/rhwp \(fetched with gh, 2026-11-09\)](https://api.github.com/repos/edwardkim/rhwp)
  - Location: repository JSON: license.spdx\_id; version: unknown; read: full\_text; capture: downloaded
  - Passage/observation: "spdx\_id":"MIT"
  - Context: …bled":false,"open\_issues\_count":460,"license":\{"key":"mit","name":"MIT License", **[passage]** ,"url":"https://api.github.com/licenses/mit","node\_id":"MDc6TGljZW5zZTEz"\},"allo…
  - Review: License only
  - Preserved: [rhwp-api snapshot](snapshots/rhwp-api/4f7a435e0f2aacc5918c9bc31074ada76c6fffe59e89c35484fd5318f02aed8f.txt)
- e-rhwp-rel [partial, self]: [GitHub API repos/edwardkim/rhwp/releases/latest \(fetched with gh, 2026-11-09\)](https://api.github.com/repos/edwardkim/rhwp/releases/latest)
  - Location: latest release JSON; version: unknown; read: full\_text; capture: downloaded
  - Passage/observation: "published\_at":"2026-11-08T11:02:05Z"
  - Context: …":false,"created\_at":"2026-11-08T10:09:35Z","updated\_at":"2026-11-08T13:20:03Z", **[passage]** ,"assets":\[\{"url":"https://api.github.com/repos/edwardkim/rhwp/releases/assets/7…
  - Review: Latest release date only; tag v0.9.0 is in the same JSON
  - Preserved: [rhwp-rel snapshot](snapshots/rhwp-rel/37054a9a0118b629d6a57dfd2b1929ea48c329cafe733380e2741eb8b66bad9d.txt)
- e-rhwp-fuzz [partial, self]: [edwardkim/rhwp fuzz/README.md @ c9095c5](https://raw.githubusercontent.com/edwardkim/rhwp/c9095c5f67632e6721e800ccc7fb43ea49d26682/fuzz/README.md)
  - Location: fuzz/README.md intro; version: c9095c5f67632e6721e800ccc7fb43ea49d26682; read: full\_text; capture: helper\_fetched
  - Passage/observation: 목적은 \*\*비정상·적대적 입력\*\*에 대한 크래시\(패닉/abort\) · 자원 고갈\(OOM\) · 무한루프\(타임아웃\) 검출입니다. 정상 입력의 왕복 정합성\(\#2740 영역\)은 이 인프라의 대상이 아닙니다.
  - Context: … + 임베드 WMF·OOXML 차트\)와 2순위 타깃 2개 \(\`parse\_equation\`·\`export\_svg\`, M03-13\)를 퍼징합니다.  **[passage]**  \#\# 하네스 목록 \| 타깃 \| 진입점 \| 위치 \| \|---\|---\|---\| \| \`parse\_hwp\` \| \`rhwp::parser::parse\_…
  - Review: Fuzz scope: crashes/OOM/timeouts, explicitly not round-trip fidelity
  - Preserved: [rhwp-fuzz snapshot](snapshots/rhwp-fuzz/aa7c9787e8a7191102e3d80b18650244addf34135f92200b68796163652133bf.txt)
- e-i8172 [contradicts, self]: [edwardkim/rhwp issue \#8172 \(GitHub API JSON\)](https://api.github.com/repos/edwardkim/rhwp/issues/8172)
  - Location: issue \#8172 body, 증상; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 를 넣은 문서를 HWP로 저장하면, 한컴 2024\(13.0.0.3901\)가 열 때
  - Context: …0\},"body":"\#\# 증상\\n\\n편집 API \`createShapeControl\`로 \*\*글상자\(\`shapeType: 'textbox'\`\)\*\* **[passage]**  \\"문서가 손상되었거나 변조되었을 수 있음\\"이라고 경고한다. 무인 변환은 거부된다\(\`HANCOM\_DOCUMENT\_OPEN\_REJECTED\`\)…
  - Review: Contradicts the implication that rhwp's HWP save is reliable: 한컴 2024 rejected HWP files with an edited textbox \(closed 2026-10-26\). Does not contradict the README statement itself
  - Preserved: [rhwp-i8172 snapshot](snapshots/rhwp-i8172/acea12a07cca1fb29e7eefd561b433f3e42591b2489193406ca1125736994732.txt)
- e-i2740-gate [contradicts, self]: [edwardkim/rhwp issue \#2740 \(GitHub API JSON\)](https://api.github.com/repos/edwardkim/rhwp/issues/2740)
  - Location: issue \#2740 body, 요약 \(preceded by: 기존 HWP5 왕복 게이트는 \`raw\_stream\` 바이트 재생\); version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 경로를 검사하고 있어서 \*\*직렬화기를 사실상 보지 않는다\*\* — 편집 후 저장 경로를 재현하니
  - Context: …보류 257행\*\*.\\r\\n\\r\\n그 과정에서 두 가지가 드러났다. \(1\) 기존 HWP5 왕복 게이트는 \`raw\_stream\` 바이트 재생\\r\\n **[passage]** \\r\\n481행이 나왔다. \(2\) 인벤토리 최대 항목\(173샘플\)은 결함이 아니라 \*\*task \#1633 의 의도된\\r\\n정규화\*\*였다 — 코드…
  - Review: Shows the HWP5 round-trip gate did not exercise the serializer \(July 2026\), so the test count did not cover save fidelity
  - Preserved: [rhwp-i2740 snapshot](snapshots/rhwp-i2740/dc766b780aabe090bfa139a984792ba8025b1f4fdd7c55250ef02e08b8c68d9d.txt)
- e-i4677-n [contradicts, self]: [edwardkim/rhwp issue \#4677 \(GitHub API JSON via gh\)](https://api.github.com/repos/edwardkim/rhwp/issues/4677)
  - Location: issue \#4677 body, 배경; version: unknown; read: full\_text; capture: downloaded
  - Passage/observation: 문서 163건\(185 문서×경로\)이 나왔다.
  - Context: …서, 저장 왕복 후 \*\*본문 텍스트가 실질적으로 소실\*\*되는\(content-loss:\\n공백·이스케이프를 무시해도 산출물 쪽 글자가 더 적음\)  **[passage]** \\nU+2007 삽입\(별도 이슈\)·순수 공백 차이는 이 분류에서 제외된 실질 소실이다.\\n\\n\#\# 실측\\n\\n경로별 분포: h2x 56 · x2…
  - Review: 163 documents lost body text after save round trips in the 10k Hancom-oracle sweep \(closed 2026-08-15\)
  - Preserved: [rhwp-i4677 snapshot](snapshots/rhwp-i4677/6f387c075db96ed43f54899dab127889ec03bdfbad7ef7b2b8005a7a3b9e7ede.txt)

### Origin removal (recorded relations)

- Structure: single_origin
- Unknown origins: none
- Shared dependencies: none
- Basis SHA-256: 42a007e13b2e3b5706de435c5b2a196b50db31fc1ba332e3be31353f1fe5d47e
- Review selection: Only origin
- Exclude rhwp (implementation); remaining supports: none; remaining counterevidence: none
  - Recorded judgment: unresolved (current, self); Every capability statement is the project's own; no independent build or run. The claim is phrased as 'reports' for that reason

## c-hop — HOP \(MIT\) is a Tauri 2 + Rust + TypeScript desktop app built on rhwp; it ships a signed/notarized macOS .dmg with Quick Look preview, and its developer docs state that HWPX saving is not offered in the UI and that autosave/recovery is not provided.

- Status: supported
- Scope: README and docs/DEVELOPMENT.md at commit 3cfb18b; HOP v0.4.5 \(2026-10-08\) is the latest release; not installed or run
- Resolution: Claim is about stated features/limits and stands; issue \#73 \(open, Windows, v0.3.1\) shows save fidelity in HOP is not guaranteed and must be tested
- Next action: Install HOP v0.4.5, open/save a few real documents, and reopen the saved files in real 한글

### Evidence

- e-hop-shell [supports, self]: [golbin/hop docs/DEVELOPMENT.md @ 3cfb18b](https://raw.githubusercontent.com/golbin/hop/3cfb18b49acd09b11064da4d1f6547aa68ec9981/docs/DEVELOPMENT.md)
  - Location: docs/DEVELOPMENT.md intro; version: 3cfb18b49acd09b11064da4d1f6547aa68ec9981; read: full\_text; capture: helper\_fetched
  - Passage/observation: HOP는 Tauri 2, Rust, TypeScript로 만든 macOS·Windows·Linux 문서 편집기다.
  - Context: …\# HOP 개발하기  **[passage]**  문서 엔진과 Studio는 읽기 전용 \`third\_party/rhwp\`를 사용한다. \#\# 시작하기 Corepack/pnpm, Rust, 해당 …
  - Review: Developer doc states the Tauri 2 + Rust + TypeScript stack and cross-platform scope; same doc says engine is third\_party/rhwp
  - Preserved: [hop-dev snapshot](snapshots/hop-dev/f94d537c908f58e4c5088ae2d40ddb43b626349567601f07f54dd287018cdc0a.txt)
- e-hop-limits [partial, self]: [golbin/hop docs/DEVELOPMENT.md @ 3cfb18b](https://raw.githubusercontent.com/golbin/hop/3cfb18b49acd09b11064da4d1f6547aa68ec9981/docs/DEVELOPMENT.md)
  - Location: 제품 동작과 제한; version: 3cfb18b49acd09b11064da4d1f6547aa68ec9981; read: full\_text; capture: helper\_fetched
  - Passage/observation: HWPX 저장은 제품 UI에서 지원하지 않는다.
  - Context: …꾸지는 않는다. \#\# 제품 동작과 제한 - HWP/HWPX 열기, 편집, HWP 저장·Save As, 검색 가능한 PDF 내보내기를 지원한다.  **[passage]**  - 암호 HWP는 암호 입력 후 열 수 있다. 원본의 암호를 조용히 제거하지 않도록 직접 저장은 차단하며, Save As에서 안내에 동의한 경…
  - Review: HWPX save not in product UI
  - Preserved: [hop-dev snapshot](snapshots/hop-dev/f94d537c908f58e4c5088ae2d40ddb43b626349567601f07f54dd287018cdc0a.txt)
- e-hop-noauto [partial, self]: [golbin/hop docs/DEVELOPMENT.md @ 3cfb18b](https://raw.githubusercontent.com/golbin/hop/3cfb18b49acd09b11064da4d1f6547aa68ec9981/docs/DEVELOPMENT.md)
  - Location: 제품 동작과 제한; version: 3cfb18b49acd09b11064da4d1f6547aa68ec9981; read: full\_text; capture: helper\_fetched
  - Passage/observation: 외부 파일 변경은 저장 전에 충돌 확인을 거친다. autosave/recovery는 제공하지 않는다.
  - Context: … 암호 없는 HWP를 별도로 저장한다. - native 문서 작업은 겹쳐 실행하지 않는다. 취소·오류 시 기존 문서와 미저장 상태를 보존하고,  **[passage]**  - Studio는 Canvas2D와 WASM mirror를 사용한다. native 파일/session과의 동기화는 bridge가 맡는다. - …
  - Review: No autosave/recovery
  - Preserved: [hop-dev snapshot](snapshots/hop-dev/f94d537c908f58e4c5088ae2d40ddb43b626349567601f07f54dd287018cdc0a.txt)
- e-hop-mac [partial, self]: [golbin/hop README.md @ 3cfb18b](https://raw.githubusercontent.com/golbin/hop/3cfb18b49acd09b11064da4d1f6547aa68ec9981/README.md)
  - Location: 다운로드; version: 3cfb18b49acd09b11064da4d1f6547aa68ec9981; read: full\_text; capture: helper\_fetched
  - Passage/observation: macOS 빌드는 signed/notarized \`.dmg\`입니다.
  - Context: …ux AUR \(\`hop-openhwp-bin\`\)\]\(https://aur.archlinux.org/packages/hop-openhwp-bin\)  **[passage]**  Homebrew를 통해서 설치할 수도 있습니다. Homebrew 패키지는 \[daeho-ro\]\(https://github.com/daeho-ro…
  - Review: Signed/notarized macOS dmg
  - Preserved: [hop-readme snapshot](snapshots/hop-readme/3a32e15bd59ccad94ebd3bf9f2c80b45d6dcf748ff84d80d126d123cfc65d1ab.txt)
- e-hop-ql [partial, self]: [golbin/hop README.md @ 3cfb18b](https://raw.githubusercontent.com/golbin/hop/3cfb18b49acd09b11064da4d1f6547aa68ec9981/README.md)
  - Location: 할 수 있는 일; version: 3cfb18b49acd09b11064da4d1f6547aa68ec9981; read: full\_text; capture: helper\_fetched
  - Passage/observation: macOS Finder의 Quick Look 미리보기·썸네일
  - Context: … 내보내기 \* 인쇄 다이얼로그 열기 \* 파일 드래그 앤 드롭으로 열기 \* \`.hwp\`, \`.hwpx\` 파일 연결 \* 여러 창에서 문서 열기 \*  **[passage]**  \* 글꼴·글자색 팔레트, 최근 사용한 색, 여러 쪽 모아 보기 \#\# 다운로드 최신 릴리즈는 아래 링크에서 받을 수 있습니다. \* \[macOS …
  - Review: Quick Look preview/thumbnail
  - Preserved: [hop-readme snapshot](snapshots/hop-readme/3a32e15bd59ccad94ebd3bf9f2c80b45d6dcf748ff84d80d126d123cfc65d1ab.txt)
- e-hop-meta [partial, self]: [GitHub API repos/golbin/hop \(fetched with gh, 2026-11-09\)](https://api.github.com/repos/golbin/hop)
  - Location: repository JSON: license.spdx\_id; version: unknown; read: full\_text; capture: downloaded
  - Passage/observation: "spdx\_id":"MIT"
  - Context: …abled":false,"open\_issues\_count":34,"license":\{"key":"mit","name":"MIT License", **[passage]** ,"url":"https://api.github.com/licenses/mit","node\_id":"MDc6TGljZW5zZTEz"\},"allo…
  - Review: License MIT
  - Preserved: [hop-api snapshot](snapshots/hop-api/cbae03aa0b426c974098434862e2ba9e7c38dfa6c3281cf78e2b6033d93b72be.txt)
- e-hop-i73 [contradicts, self]: [golbin/hop issue \#73 \(GitHub API JSON\)](https://api.github.com/repos/golbin/hop/issues/73)
  - Location: issue \#73 body, Steps to reproduce; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 3.기존 한글 클라이언트로 열면 파일이 깨진다고 안열리고 hop에서도 파일이 깨진다.
  - Context: … 에셋이 페이지를 이탈하는 문제\\n\\n\\n\#\#\# Steps to reproduce\\n\\n1.기존 hwp파일을 hop로 연다\\n2.저장을 한다\\n **[passage]** \\n\\n\\n\#\#\# Expected behavior\\n\\n파일을 저장하는 과정에서 특정 단어를 빼고 저장됨 ex\) \\\\;/\#등의 명령\\n\\n\#\#\#…
  - Review: Open user report: HWP saved by HOP 0.3.1 on Windows would not open in real 한글; the reporter says the rhwp demo did not show it. Contradicts reliable saving, not the stated feature list
  - Preserved: [hop-i73 snapshot](snapshots/hop-i73/114ad422027c15f1b04e00470d200b1cf2718d2702122067a10c8ee56ca1085c.txt)

### Origin removal (recorded relations)

- Structure: single_origin
- Unknown origins: none
- Shared dependencies: none
- Basis SHA-256: d9a431782aaf71b6b454bcc67afae23fc61bef6292f880f53b29efc52cd330bc
- Review selection: Chosen second scenario: the only counterevidence origin
- Exclude hop (implementation); remaining supports: none; remaining counterevidence: e-hop-i73
  - Recorded judgment: unresolved (current, self); Without the HOP repo only a user's contrary report remains; the feature/limit list rests entirely on HOP's own docs
- Exclude hop-user-73 (event); remaining supports: e-hop-shell; remaining counterevidence: none
  - Recorded judgment: retained (current, self); Removing the single user report leaves the stated features/limits unchanged; the report affects reliability, not the feature list

## c-mac — Hancom currently sells 한글 for macOS, which supports the latest three major macOS versions, so a Mac-native copy of real 한글 can be bought to verify files.

- Status: supported
- Scope: Hancom product page fetched 2026-11-09; whether the Mac edition lays out pages the same as the Windows editor was not checked
- Resolution: not recorded
- Next action: Check whether 한글 for macOS and Windows 한글 2024 give the same page count for a few corpus files before trusting the Mac copy as a reference

### Evidence

- e-mac-prod [supports, self]: [한글 for macOS \| 한컴오피스](https://www.hancom.com/product/office/forMac)
  - Location: page header; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 강화된 기능과 성능으로 새롭게 변화된 macOS용 한글을 경험해 보세요. 구매하기
  - Context: …macOS \| 한컴오피스 본문 바로가기 제품 오피스 macOS 한글 for macOS  **[passage]** 자주 묻는 질문 한글 for macOS 한글 for macOS 자유로운 글쓰기부터 업무용 문서 작업까지 내가 원하는 더 많은 것을 가능하게 주요…
  - Review: Official Mac product page with a purchase button for macOS 한글
  - Preserved: [hancom-mac snapshot](snapshots/hancom-mac/ed4420c553add1b5a0cab937338e016dd4d4b89a176303ed30dfd0bf4bab73c8.html)
- e-mac-os [partial, self]: [한글 for macOS \| 한컴오피스](https://www.hancom.com/product/office/forMac)
  - Location: 제품 사양 &gt; 운영 체제; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 운영 체제 최신 3개 버전의 주요 macOS
  - Context: …쉽고 빠르게 표 만들기 물품 분류나 구분을 위해 부착하는 라벨 만들기 및 인쇄 제품 사양 하드디스크 다운로드를 통한 전체 설치 시 2GB 이상  **[passage]**  \* 운영 체제 출시에 따라 사용 환경이 변경될 수 있습니다. \(자세한 내용은 홈페이지를 참고해 주세요.\) macOS에서 한글 시작하기 구매하기…
  - Review: Supported OS: latest three major macOS versions
  - Preserved: [hancom-mac snapshot](snapshots/hancom-mac/ed4420c553add1b5a0cab937338e016dd4d4b89a176303ed30dfd0bf4bab73c8.html)

### Origin removal (recorded relations)

- Structure: single_origin
- Unknown origins: none
- Shared dependencies: none
- Basis SHA-256: c5f5bd2c93cb203f2f971cb16f81ea3392a707b60d6600ea661884403a8ab595
- Review selection: Only origin
- Exclude hancom-mac-product (disclosure); remaining supports: none; remaining counterevidence: none
  - Recorded judgment: unresolved (current, self); Only Hancom's product page shows the Mac edition is on sale; no independent listing preserved \(App Store results were for the Viewer\)

## c-oracle — Hancom's own outputs differ by tool, version and print path: for one file 한글 2010 gave 14 pages and 한글 2020 gave 8; for another, Windows editors gave 35 pages and the Mac 한글 Viewer through the macOS print dialog gave 37. So a single Hancom PDF is not a reliable answer key; rhwp only treats a result as the answer when two Hancom versions agree.

- Status: supported
- Scope: Observations reported in the rhwp wiki \(PRs and issues from April 2026\), a few sample files; not reproduced by me
- Resolution: not recorded
- Next action: Reproduce on 2-3 corpus files: export PDFs from two Hancom versions and compare page counts and line breaks

### Evidence

- e-pdf-core [supports, self]: [rhwp wiki: 한컴-PDF-환경-의존성](https://raw.githubusercontent.com/wiki/edwardkim/rhwp/%ED%95%9C%EC%BB%B4-PDF-%ED%99%98%EA%B2%BD-%EC%9D%98%EC%A1%B4%EC%84%B1.md)
  - Location: 핵심 결론; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: \*\*한컴 PDF 출력은 정답지가 아닙니다.\*\* 동일 HWP 파일도 한컴 도구 종류 \(편집기 / Viewer\) 와 출력 경로 \(한컴 자체 PDF 출력 / OS 인쇄 시스템\) 에 따라 페이지 분할이 다릅니다.
  - Context: …\# 한컴 PDF 환경 의존성 — 정답지로 사용 불가 \#\# 핵심 결론  **[passage]**  PR/task 검증에서 "한컴 PDF 와 일치" 만으로 머지 결정할 수 없습니다. 이 페이지는 발견 정황과 후속 조치, 컨트리뷰터를 위한 안내…
  - Review: Wiki's core conclusion: Hancom PDF is not an answer key because pagination differs by tool and output path
  - Preserved: [rhwp-wiki-pdf snapshot](snapshots/rhwp-wiki-pdf/db48535e21898a6213384d8a9a7fc56e60628275891f7e9367dfd6a457cd13ce.txt)
- e-pdf-ver [partial, self]: [rhwp wiki: 한컴-PDF-환경-의존성](https://raw.githubusercontent.com/wiki/edwardkim/rhwp/%ED%95%9C%EC%BB%B4-PDF-%ED%99%98%EA%B2%BD-%EC%9D%98%EC%A1%B4%EC%84%B1.md)
  - Location: 발견 정황 III; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 같은 HWP 파일에서 \*\*한컴 2010 \(14쪽\) ↔ 한컴 2020 \(8쪽\) 가 6 페이지 차이\*\*.
  - Context: …/samples/exam\_eng-2020.pdf\) \| \*\*8 쪽\*\* \| \| \*\*rhwp v0.7.8\*\* \| \(현재 출력\) \| \*\*8 쪽\*\* \|  **[passage]**  \#\#\# 핵심 발견 1. \*\*한컴 2010 자체가 일부 케이스에서 부정확\*\*: 작업지시자 직접 검증 결과 — \*"이 샘플에서 2010 버전은 부…
  - Review: One file: 2010 gives 14 pages, 2020 gives 8
  - Preserved: [rhwp-wiki-pdf snapshot](snapshots/rhwp-wiki-pdf/db48535e21898a6213384d8a9a7fc56e60628275891f7e9367dfd6a457cd13ce.txt)
- e-pdf-mac [partial, self]: [rhwp wiki: 한컴-PDF-환경-의존성](https://raw.githubusercontent.com/wiki/edwardkim/rhwp/%ED%95%9C%EC%BB%B4-PDF-%ED%99%98%EA%B2%BD-%EC%9D%98%EC%A1%B4%EC%84%B1.md)
  - Location: 발견 정황 I table, row 3; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: \| 컨트리뷰터 \(@planet6897\) \| 한컴 한글 \*\*Viewer\*\* v1.31.7 \| macOS Sequoia 15.7.4 \| macOS 인쇄 다이얼로그 → PDF 저장 \| \*\*37쪽\*\* \|
  - Context: … \(@planet6897\) \| 한컴 \*\*2022\*\* \(편집기\) \| Windows 11 \| 한컴 자체 "PDF로 저장하기" \| \*\*35쪽\*\* \|  **[passage]**  같은 HWP, 같은 md5, 그러나 출력 경로별로 다른 PDF. \#\#\# 핵심 발견 - \*\*한컴 편집기 \(Windows\) 는 일관\*\*: 한컴 2…
  - Review: Mac Viewer + macOS print gives 37 pages \(Windows editors gave 35 in the same table\)
  - Preserved: [rhwp-wiki-pdf snapshot](snapshots/rhwp-wiki-pdf/db48535e21898a6213384d8a9a7fc56e60628275891f7e9367dfd6a457cd13ce.txt)
- e-pdf-proc [partial, self]: [rhwp wiki: 한컴-PDF-환경-의존성](https://raw.githubusercontent.com/wiki/edwardkim/rhwp/%ED%95%9C%EC%BB%B4-PDF-%ED%99%98%EA%B2%BD-%EC%9D%98%EC%A1%B4%EC%84%B1.md)
  - Location: 회귀 의심 시 권장 절차; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 2. \*\*두 버전이 일치\*\* 하면 정답지로 사용 가능
  - Context: …정합 한쪽 채택\*\* 룰 보강 \#\#\# 회귀 의심 시 권장 절차 1. 한컴 2010 + 한컴 2020 \(또는 한컴 2022\) 두 버전 PDF 확보  **[passage]**  3. \*\*두 버전이 다르면\*\*: - 어느 버전이 정확한지 작업지시자 또는 한컴 사용자 직접 검증 - rhwp 결과가 한 쪽과 정합하면 \*\*정답…
  - Review: The two-version agreement rule
  - Preserved: [rhwp-wiki-pdf snapshot](snapshots/rhwp-wiki-pdf/db48535e21898a6213384d8a9a7fc56e60628275891f7e9367dfd6a457cd13ce.txt)

### Origin removal (recorded relations)

- Structure: single_origin
- Unknown origins: none
- Shared dependencies: none
- Basis SHA-256: ada9dd323a8a3456f4c0769aecd161131eeef17db5b35f8d4aea7fc79ed36e29
- Review selection: Only origin
- Exclude rhwp (implementation); remaining supports: none; remaining counterevidence: none
  - Recorded judgment: narrowed (current, self); All observations come from rhwp contributors on a few sample files; not reproduced by me. Holds as 'observed by rhwp contributors', not as a measured rate

## c-roundtrip — A no-edit byte-identical round-trip test can pass while the serializer is untested: rhwp's HWP5 round-trip gate checked a raw-stream byte-replay path, and after re-running the edit-then-save path on a 429-document corpus it recorded 786 divergence rows, 103 of them defects \(July 2026; the passthrough was later restricted to unchanged sections\). Its later load/save sweep driving real 한글 2022 through COM on a 10k corpus found 163 documents losing body text after save round trips. A round trip alone does not prove the output is correct; the target application has to open it.

- Status: supported
- Scope: One project's measurement \(rhwp issue \#2740, July 2026\) plus one spreadsheet-project statement; generalisation to my app is my inference
- Resolution: not recorded
- Next action: Make the no-edit byte check only a smoke test; gate on an edit-path field sweep plus opening the saved files in real 한글

### Evidence

- e-i2740-raw [partial, self]: [edwardkim/rhwp issue \#2740 \(GitHub API JSON\)](https://api.github.com/repos/edwardkim/rhwp/issues/2740)
  - Location: issue \#2740 body, 요약; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 기존 HWP5 왕복 게이트는 \`raw\_stream\` 바이트 재생
  - Context: …다.\\r\\n분류는 \*\*결함 103행 / 의도된 정규화 426행 / 판단보류 257행\*\*.\\r\\n\\r\\n그 과정에서 두 가지가 드러났다. \(1\)  **[passage]** \\r\\n경로를 검사하고 있어서 \*\*직렬화기를 사실상 보지 않는다\*\* — 편집 후 저장 경로를 재현하니\\r\\n481행이 나왔다. \(2\) 인벤토리 …
  - Review: Names the raw\_stream byte replay path
  - Preserved: [rhwp-i2740 snapshot](snapshots/rhwp-i2740/dc766b780aabe090bfa139a984792ba8025b1f4fdd7c55250ef02e08b8c68d9d.txt)
- e-i2740-gate [supports, self]: [edwardkim/rhwp issue \#2740 \(GitHub API JSON\)](https://api.github.com/repos/edwardkim/rhwp/issues/2740)
  - Location: issue \#2740 body, 요약 \(preceded by: 기존 HWP5 왕복 게이트는 \`raw\_stream\` 바이트 재생\); version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 경로를 검사하고 있어서 \*\*직렬화기를 사실상 보지 않는다\*\* — 편집 후 저장 경로를 재현하니
  - Context: …보류 257행\*\*.\\r\\n\\r\\n그 과정에서 두 가지가 드러났다. \(1\) 기존 HWP5 왕복 게이트는 \`raw\_stream\` 바이트 재생\\r\\n **[passage]** \\r\\n481행이 나왔다. \(2\) 인벤토리 최대 항목\(173샘플\)은 결함이 아니라 \*\*task \#1633 의 의도된\\r\\n정규화\*\*였다 — 코드…
  - Review: States the HWP5 round-trip gate checked the raw\_stream replay path and effectively did not exercise the serializer
  - Preserved: [rhwp-i2740 snapshot](snapshots/rhwp-i2740/dc766b780aabe090bfa139a984792ba8025b1f4fdd7c55250ef02e08b8c68d9d.txt)
- e-i2740-corpus [partial, self]: [edwardkim/rhwp issue \#2740 \(GitHub API JSON\)](https://api.github.com/repos/edwardkim/rhwp/issues/2740)
  - Location: issue \#2740 body, 요약; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 실측\(§4\): 코퍼스 429개 문서를 3개 레인 794회 왕복시켜 발산 \*\*786행\*\*을 얻었다.
  - Context: …드 전수 스윕\*\*을 추가하고,\\r\\n현 상태를 baseline 으로 동결해 \*\*회귀만 실패하는 래칫\*\*으로 CI 에 오늘 넣는다.\\r\\n\\r\\n **[passage]** \\r\\n분류는 \*\*결함 103행 / 의도된 정규화 426행 / 판단보류 257행\*\*.\\r\\n\\r\\n그 과정에서 두 가지가 드러났다. \(1\) 기존…
  - Review: 429 docs, 794 round trips, 786 divergence rows; 103-defect split is in the next sentence of the same summary
  - Preserved: [rhwp-i2740 snapshot](snapshots/rhwp-i2740/dc766b780aabe090bfa139a984792ba8025b1f4fdd7c55250ef02e08b8c68d9d.txt)
- e-gnumeric [supports, self]: [Morten Welinder \(Gnumeric\) blog post on round-trip testing](https://blogs.gnome.org/mortenw/?p=312)
  - Location: paragraph 3; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: Note, that by itself a round-trip test does not guarantee that what we produce is correct. We could, hypothetically, have swapped division and multiplication are still gotten a perfect round-trip. To test that the generated files are correct one has to load the resulting sheet in Excel or LibreOffice
  - Context: …ot store arbitrary unicode; and xls/biff8 has a fixed sheet size of 64k-by-256.  **[passage]**  \(which, despite claims to the contrary, are what really defines xls/xlsx and od…
  - Review: Independent project: a perfect round trip does not prove correctness; the target app must open the output
  - Preserved: [gnumeric-rt snapshot](snapshots/gnumeric-rt/da22d8e2b6af0976bdb48c0cd1b85fad7af76d2557a96d5a88ec107daa3f274f.html)
- e-i4677-oracle [partial, self]: [edwardkim/rhwp issue \#4677 \(GitHub API JSON via gh\)](https://api.github.com/repos/edwardkim/rhwp/issues/4677)
  - Location: issue \#4677 body, 배경; version: unknown; read: full\_text; capture: downloaded
  - Passage/observation: 한글 2022 COM 오라클 load/save 전수검사\(10k 코퍼스, 하네스 \`tools/loadsave\_sweep/\`,
  - Context: …ed\_by":0,"total\_blocked\_by":0,"blocking":0,"total\_blocking":0\},"body":"\#\# 배경\\n\\n **[passage]** \\n총괄 이슈 참조\)에서, 저장 왕복 후 \*\*본문 텍스트가 실질적으로 소실\*\*되는\(content-loss:\\n공백·이스케이프를 무시해도 산출물 …
  - Review: Shows the method: 한글 2022 driven via COM as oracle over a 10k corpus
  - Preserved: [rhwp-i4677 snapshot](snapshots/rhwp-i4677/6f387c075db96ed43f54899dab127889ec03bdfbad7ef7b2b8005a7a3b9e7ede.txt)
- e-i4677-n [partial, self]: [edwardkim/rhwp issue \#4677 \(GitHub API JSON via gh\)](https://api.github.com/repos/edwardkim/rhwp/issues/4677)
  - Location: issue \#4677 body, 배경; version: unknown; read: full\_text; capture: downloaded
  - Passage/observation: 문서 163건\(185 문서×경로\)이 나왔다.
  - Context: …서, 저장 왕복 후 \*\*본문 텍스트가 실질적으로 소실\*\*되는\(content-loss:\\n공백·이스케이프를 무시해도 산출물 쪽 글자가 더 적음\)  **[passage]** \\nU+2007 삽입\(별도 이슈\)·순수 공백 차이는 이 분류에서 제외된 실질 소실이다.\\n\\n\#\# 실측\\n\\n경로별 분포: h2x 56 · x2…
  - Review: 163 documents \(185 document×path\) with real body-text loss
  - Preserved: [rhwp-i4677 snapshot](snapshots/rhwp-i4677/6f387c075db96ed43f54899dab127889ec03bdfbad7ef7b2b8005a7a3b9e7ede.txt)
- e-i4488-fix [partial, self]: [edwardkim/rhwp issue \#4488 \(GitHub API JSON via gh\)](https://api.github.com/repos/edwardkim/rhwp/issues/4488)
  - Location: issue \#4488 body, 완료 조건; version: unknown; read: full\_text; capture: downloaded
  - Passage/observation: 원본 byte-exact passthrough는 실제로 변경되지 않은 section에서만 유지된다.
  - Context: …한다.\\n\\n\#\# 완료 조건\\n\\n- 공개 저수준 parse→mutate→serialize 경로가 변경된 modeled IR을 저장한다.\\n-  **[passage]** \\n- 필드만 위한 별도 전역 순회를 만들지 않고, raw cache의 실제 소유자가 mutation identity 또는 검증을 책임진다.\\n…
  - Review: Later fix: byte-exact passthrough kept only for unchanged sections \(closed 2026-08-16\)
  - Preserved: [rhwp-i4488 snapshot](snapshots/rhwp-i4488/c27c2a9097c1eea15c793dd5f0cadd0eb5746fed34d5fe7d8b566a47f0cda56b.txt)

### Origin removal (recorded relations)

- Structure: multiple_origins
- Unknown origins: none
- Shared dependencies: none
- Basis SHA-256: 81fa381db6bdd30a5f56feb78c8126357d2fa8da62aa8d27882d9825435470d6
- Review selection: Chosen second scenario: the only independent origin
- Exclude gnumeric (disclosure); remaining supports: e-i2740-gate; remaining counterevidence: none
  - Recorded judgment: retained (current, self); Without Gnumeric the rhwp gate finding still shows the passthrough blind spot directly
- Exclude rhwp (implementation); remaining supports: e-gnumeric; remaining counterevidence: none
  - Recorded judgment: narrowed (current, self); Without rhwp only the Gnumeric statement remains: round trips do not prove correctness. The specific numbers \(786 rows, 103 defects, 163 docs\) depend on rhwp alone

## c-fuzz — OSS-Fuzz guidance judges fuzzing by seed-corpus coverage and regular sanitizer regression runs over the corpus, and says plateaus are common; the '24 hours or more, multiple trials' rule in Klees et al. 2018 is a recommendation for evaluating fuzzers, not a certification threshold for one target.

- Status: supported
- Scope: OSS-Fuzz ideal-integration page and FAQ fetched 2026-11-09; Klees et al. conclusions section
- Resolution: not recorded
- Next action: Define T as: at least 24h per parser target AND coverage plateau AND zero sanitizer findings on corpus replay, recorded with coverage plots

### Evidence

- e-oss-seed [supports, self]: [Ideal integration with OSS-Fuzz](https://google.github.io/oss-fuzz/advanced-topics/ideal-integration/)
  - Location: Summary list; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: Has a seed corpus with good code coverage.
  - Context: …in their RCS \(Git, SVN, etc\). Is built with the rest of the tests - no bit rot\!  **[passage]**  Has a dictionary, if applicable. Is continuously tested on the seed corpus with…
  - Review: Ideal integration criteria are framed around a seed corpus with good coverage, not hours
  - Preserved: [ossfuzz-ideal snapshot](snapshots/ossfuzz-ideal/7c2a1d0be83ffc9e8a97b16530cb2f1583a4d059735e758996715446c573953a.html)
- e-oss-reg [partial, self]: [Ideal integration with OSS-Fuzz](https://google.github.io/oss-fuzz/advanced-topics/ideal-integration/)
  - Location: Regression Testing; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: Fuzz targets should be regularly tested \(not necessarily fuzzed\!\) as a part of the project’s regression testing process.
  - Context: …ora, and fixing timeouts/out-of-memory bugs in your targets. Regression Testing  **[passage]**  One way to do so is to link the fuzz target with a simple standalone driver \(ex…
  - Review: Regression testing over the corpus
  - Preserved: [ossfuzz-ideal snapshot](snapshots/ossfuzz-ideal/7c2a1d0be83ffc9e8a97b16530cb2f1583a4d059735e758996715446c573953a.html)
- e-oss-plateau [partial, self]: [OSS-Fuzz Frequently Asked Questions](https://google.github.io/oss-fuzz/faq/)
  - Location: FAQ: fuzz target running for many days; version: unknown; read: relevant\_sections; capture: helper\_fetched
  - Passage/observation: It is common for fuzzers to plateau and stop finding new coverage or bugs.
  - Context: …ot covered. What if my fuzzer does not find new coverage or bugs after a while?  **[passage]**  Fuzz Introspector helps you evaluate your fuzzers' performance. It can help you…
  - Review: Plateaus are common
  - Preserved: [ossfuzz-faq snapshot](snapshots/ossfuzz-faq/92823683a8d099ac4efec512cd608b144bfe17a4c864fc96192b5c9744564d48.html)
- e-klees [partial, self]: [Klees et al., Evaluating Fuzz Testing \(CCS 2018, arXiv 1808.09700\)](https://arxiv.org/pdf/1808.09700)
  - Location: Section 9 Conclusions, recommendation list; version: unknown; read: relevant\_sections; capture: helper\_fetched
  - Passage/observation: timeouts of at least 24 hours, or else justification for less, with performance plotted over time.
  - Context: …consideration of various \(well documented\) seed choices including empty seed; •  **[passage]**  We see \(at least\) three important lines of future work. First, we believe there…
  - Review: 24h timeout recommendation; surrounding text \(printed context\) frames the list as elements of fuzz testing evaluations
  - Preserved: [klees2018 snapshot](snapshots/klees2018/c81da4dfe2bf814e3121097f87ad478f5fde2d38bf44d4966fe882f53cef0acb.pdf)
- e-klees-trials [partial, self]: [Klees et al., Evaluating Fuzz Testing \(CCS 2018, arXiv 1808.09700\)](https://arxiv.org/pdf/1808.09700)
  - Location: Section 9 Conclusions, recommendation list; version: unknown; read: relevant\_sections; capture: helper\_fetched
  - Passage/observation: multiple trials with statistical tests to distinguish distributions;
  - Context: …e recommend that fuzz testing evaluations should have the following elements: •  **[passage]**  • a range of benchmark target programs with known bugs \(e.g., LAVA-M, CGC, or o…
  - Review: Multiple trials with statistical tests, same evaluation list
  - Preserved: [klees2018 snapshot](snapshots/klees2018/c81da4dfe2bf814e3121097f87ad478f5fde2d38bf44d4966fe882f53cef0acb.pdf)

### Origin removal (recorded relations)

- Structure: single_origin
- Unknown origins: none
- Shared dependencies: none
- Basis SHA-256: ff4edc1aee51802a2fc010fb8a1c07781afc82108f4e0a3b527a90b930d6b050
- Review selection: Chosen second scenario
- Exclude klees2018 (study; design: survey of 32 fuzzing papers + experiments); remaining supports: e-oss-seed; remaining counterevidence: none
  - Recorded judgment: retained (current, self); Without Klees the OSS-Fuzz coverage/regression framing stands; only the 24-hour part drops
- Exclude ossfuzz (disclosure); remaining supports: none; remaining counterevidence: none
  - Recorded judgment: narrowed (current, self); Without OSS-Fuzz only Klees remains, which is about evaluating fuzzers; the OSS-Fuzz half of the claim would be unsupported

## c-libs — Other implementations: hwplib \(Apache-2.0\) reads and writes HWP but not encrypted files and has no image/PDF/HTML rendering; hwpxlib reads and writes HWPX; H2Orestart saves only to ODT; hwp-rs was last pushed in 2022-11 and hwp.js in 2025-01.

- Status: supported
- Scope: not recorded
- Resolution: not recorded
- Next action: not recorded

### Evidence

- e-hwplib-write [partial, self]: [neolord0/hwplib README.md @ 6746c27](https://raw.githubusercontent.com/neolord0/hwplib/6746c27f17ebf5277493206284aa32044a1839c4/README.md)
  - Location: 이 라이브러리에서 할 수 있는 일; version: 6746c27f17ebf5277493206284aa32044a1839c4; read: full\_text; capture: helper\_fetched
  - Passage/observation: 만들어진 객체를 파일로 저장 : Rewriting\_HWPFile, SimpleEditing\_HWPFile
  - Context: … 패키지에 샘플 참고.\) - 한글 파일을 읽어서 객체로 생성 : Reading\_HWP\_FromFile, Reading\_HWP\_FromURL -  **[passage]**  - 한글 파일에서 텍스트 추출 : Extracting\_Text, Extracting\_Text\_From\_Big\_File - 필드 텍스트 추출/설…
  - Review: hwplib can save objects to file
  - Preserved: [hwplib-readme snapshot](snapshots/hwplib-readme/7fe68f0352052d226e40082d72b9ab188d127a68f40b54ee1afb94649b51e593.txt)
- e-hwplib-no [partial, self]: [neolord0/hwplib README.md @ 6746c27](https://raw.githubusercontent.com/neolord0/hwplib/6746c27f17ebf5277493206284aa32044a1839c4/README.md)
  - Location: 아직 지원하지 않는 기능; version: 6746c27f17ebf5277493206284aa32044a1839c4; read: full\_text; capture: helper\_fetched
  - Passage/observation: 암호화된 HWP 파일에 대한 읽고 쓰기 - 이미지 파일, PDF 파일, HTML 파일로 변환
  - Context: …기, 밑줄 등의 글자모양 설정\(Inserting\_CharShape 참고\) \* 이 라이브러리는 다음의 기능을 아직\(??\) 지원하지 않습니다. -  **[passage]**  - 특정 페이지 내용 가져오기 나 전체 페이지 수를 구하기 \* 메이븐 레파지토리 설정 \`\`\`\{.xml\} &lt;dependency&gt; &lt;groupId…
  - Review: hwplib lacks encrypted-file support and rendering/conversion
  - Preserved: [hwplib-readme snapshot](snapshots/hwplib-readme/7fe68f0352052d226e40082d72b9ab188d127a68f40b54ee1afb94649b51e593.txt)
- e-hwpxlib-rw [partial, self]: [neolord0/hwpxlib README.md @ f9fd225](https://raw.githubusercontent.com/neolord0/hwpxlib/f9fd2255ac0fc57414e0b657d115e7de51d31c65/README.md)
  - Location: intro; version: f9fd2255ac0fc57414e0b657d115e7de51d31c65; read: full\_text; capture: helper\_fetched
  - Passage/observation: 이 라이브러리는 hwpx 파일을 읽고 쓸 수 있는 java 라이브러리 입니다.
  - Context: …\# hwpxlib 한글과 컴퓨터\(한컴\)에서 만든 워드프로세서 "한글"의 hwpx 파일에 대한 라이브러리입니다.&lt;br&gt;  **[passage]**  개인적인 취미 생활 또는 사회기여 활동 목적으로 시작한 hwplib, hwpxlib 프로젝트가 이 라이브러리를 기반으로 하는 상용 제품이 개발…
  - Review: hwpxlib reads and writes HWPX
  - Preserved: [hwpxlib-readme snapshot](snapshots/hwpxlib-readme/ba7f79475d36855f924d2af544ae20339ef560c94e0ab04e51c14beefc36bec5.txt)
- e-h2o [partial, self]: [ebandal/H2Orestart README.md @ 2a35d9e](https://raw.githubusercontent.com/ebandal/H2Orestart/2a35d9e1bf6fb67fcde4f4c42d89134d65f9df55/README.md)
  - Location: intro; version: 2a35d9e1bf6fb67fcde4f4c42d89134d65f9df55; read: full\_text; capture: helper\_fetched
  - Passage/observation: 저장은 ODT 형식으로만 저장할 수 있습니다.
  - Context: … 유형을 필터링하거나, - hwpx파일을 끌어오기를 하여 hwpx파일을 OpenDocumentText \(ODT\)형식으로 변환 할 수 있습니다.  **[passage]**  확장을 설치하면 LibreOffice headless 명령으로 한글파일을 PDF로 변환할 수 있습니다. \`\`\` 예1\) $ soffice.exe…
  - Review: H2Orestart saves only ODT
  - Preserved: [h2o-readme snapshot](snapshots/h2o-readme/a2de37cdfe90b5e9e7ca2e0342d341b71cf7f0d48056a0ff56684d376e691dc3.txt)
- e-hwprs [partial, self]: [GitHub API repos/hahnlee/hwp-rs \(fetched with gh, 2026-11-09\)](https://api.github.com/repos/hahnlee/hwp-rs)
  - Location: repository JSON: pushed\_at; version: unknown; read: full\_text; capture: downloaded
  - Passage/observation: "pushed\_at":"2022-11-11T10:35:15Z"
  - Context: …yments","created\_at":"2022-09-28T09:00:06Z","updated\_at":"2026-10-24T13:08:31Z", **[passage]** ,"git\_url":"git://github.com/hahnlee/hwp-rs.git","ssh\_url":"git@github.com:hahnl…
  - Review: hwp-rs last push 2022-11-11
  - Preserved: [hwprs-api snapshot](snapshots/hwprs-api/c38bc5c77e3d0b2efcd3b10a8266e61aeb8fb1a52dd2cd68054ea8f5e61591cb.txt)
- e-hwpjs [partial, self]: [GitHub API repos/hahnlee/hwp.js \(fetched with gh, 2026-11-09\)](https://api.github.com/repos/hahnlee/hwp.js)
  - Location: repository JSON: pushed\_at; version: unknown; read: full\_text; capture: downloaded
  - Passage/observation: "pushed\_at":"2025-01-10T10:35:42Z"
  - Context: …yments","created\_at":"2020-08-22T10:49:43Z","updated\_at":"2026-10-13T19:17:43Z", **[passage]** ,"git\_url":"git://github.com/hahnlee/hwp.js.git","ssh\_url":"git@github.com:hahnl…
  - Review: hwp.js last push 2025-01-10
  - Preserved: [hwpjs-api snapshot](snapshots/hwpjs-api/5ff9d1810b027f3d6f29b29be7e7ddfb4c35c29bc4f175bc1035557bb552c073.txt)

## c-dvc — Hancom's open-source DVC checks whether an HWPX document follows a defined form \(char/para shapes, tables, styles and so on\); it is a form-conformance checker, not an XML schema validator.

- Status: supported
- Scope: not recorded
- Resolution: not recorded
- Next action: not recorded

### Evidence

- e-dvc [supports, self]: [hancom-io/dvc README.md @ 19a985e](https://raw.githubusercontent.com/hancom-io/dvc/19a985ec047df629240cbcbe2cec17f19ad1a014/README.md)
  - Location: 개요; version: 19a985ec047df629240cbcbe2cec17f19ad1a014; read: full\_text; capture: helper\_fetched
  - Passage/observation: HWPX 문서의 내용이 정해진 형태로 작성이 되었는지를 검증하는 프로젝트 입니다.
  - Context: …\# HWPX 활용 예제 : 문서 적합성 검증 \(HWPX Document Validation Checker : DVC\) \#\# 개요 +  **[passage]**  + 특정 집단에서 사용이 허가되는 문서 서식이 있다면 해당 서식을 정의하고, 만들어 져 있는 문서가 해당 서식에 적합한지를 판단합니다. + 본…
  - Review: README describes validating a document against a defined form; the listed checks are formatting features, not schema
  - Preserved: [hancom-dvc snapshot](snapshots/hancom-dvc/a2a7b1e6df911fc44b2498abef20a8f8ca4d418fd66a185450bd80b8ffd5555c.txt)

## c-sec — Malicious documents use vulnerabilities, scripts, EPS and embedded OLE objects as attack vectors.

- Status: supported
- Scope: not recorded
- Resolution: not recorded
- Next action: not recorded

### Evidence

- e-kisc [supports, self]: [정보보호학회논문지 2019 문서형 악성코드 관련 논문 \(koreascience JAKO201926072346469\)](https://koreascience.kr/article/JAKO201926072346469.pdf)
  - Location: p.2 \(text lines 158-161\); version: unknown; read: relevant\_sections; capture: helper\_fetched
  - Passage/observation: 이용한 악성코드 공격에는 취약점, 스크립트, EPS \(Encapsulated PostScript\), 객체 삽입\(OLE;
  - Context: …유폴더를 통해 문서파일을 주고받는 경우가 많다는 특징을 이용하여 문서파일 내 데이터를 삽입 하는 형태로 공격 패턴이 변화하고 있다. 문서파일을  **[passage]**  정보보호학회논문지 \(2019. 8\) 861 Object Linking and Embedding\) 등의 방법이 존재한다. 이를 탐지하기 위해 가…
  - Review: Paper lists vulnerabilities, scripts, EPS and OLE as document-malware vectors
  - Preserved: [kisc2019-docmal snapshot](snapshots/kisc2019-docmal/7b9877412e6b0000ac74f0b4acb859d82882933d2a7a3b19498824543c9c1741.pdf)

## p-plan — Proposal: do not write a new HWP engine. Build a native AppKit macOS shell on rhwp's Rust core \(pinned tag, read-only upstream like HOP\), and put the depth into a verification harness: a provenance-tracked corpus, edit-path field sweeps, and automated reopening in two real Hancom versions. First target L1 \(text edits\) saved as HWP and HWPX, with L2 next.

- Status: proposed
- Scope: not recorded
- Resolution: not recorded
- Next action: not recorded

### Evidence

- e-rhwp-save [supports, self]: [edwardkim/rhwp README.md @ c9095c5](https://raw.githubusercontent.com/edwardkim/rhwp/c9095c5f67632e6721e800ccc7fb43ea49d26682/README.md)
  - Location: Features &gt; Output; version: c9095c5f67632e6721e800ccc7fb43ea49d26682; read: full\_text; capture: helper\_fetched
  - Passage/observation: 저장: HWP 편집 저장, HWPX/HML 의미 보존 저장, HWPX → HWP 변환 경로
  - Context: …ct\`\) - Canvas rendering \(WASM/Web\) + 명시 opt-in 문서 단위 Canvas2D/CanvasKit 자동 선택 -  **[passage]**  - Debug overlay \(paragraph/table boundaries + indices + y-coordinates\) \#\#\# Mult…
  - Review: rhwp already claims HWP/HWPX save, so the engine need not be rewritten
  - Preserved: [rhwp-readme snapshot](snapshots/rhwp-readme/d56b4798ab49577d6e20d219613c349df60edbefd9d61b1a58c2ac238d5e4202.txt)
- e-hop-limits [supports, self]: [golbin/hop docs/DEVELOPMENT.md @ 3cfb18b](https://raw.githubusercontent.com/golbin/hop/3cfb18b49acd09b11064da4d1f6547aa68ec9981/docs/DEVELOPMENT.md)
  - Location: 제품 동작과 제한; version: 3cfb18b49acd09b11064da4d1f6547aa68ec9981; read: full\_text; capture: helper\_fetched
  - Passage/observation: HWPX 저장은 제품 UI에서 지원하지 않는다.
  - Context: …꾸지는 않는다. \#\# 제품 동작과 제한 - HWP/HWPX 열기, 편집, HWP 저장·Save As, 검색 가능한 PDF 내보내기를 지원한다.  **[passage]**  - 암호 HWP는 암호 입력 후 열 수 있다. 원본의 암호를 조용히 제거하지 않도록 직접 저장은 차단하며, Save As에서 안내에 동의한 경…
  - Review: HOP does not offer HWPX save in UI: a concrete gap a new shell could fill
  - Preserved: [hop-dev snapshot](snapshots/hop-dev/f94d537c908f58e4c5088ae2d40ddb43b626349567601f07f54dd287018cdc0a.txt)
- e-hop-i73 [supports, self]: [golbin/hop issue \#73 \(GitHub API JSON\)](https://api.github.com/repos/golbin/hop/issues/73)
  - Location: issue \#73 body, Steps to reproduce; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 3.기존 한글 클라이언트로 열면 파일이 깨진다고 안열리고 hop에서도 파일이 깨진다.
  - Context: … 에셋이 페이지를 이탈하는 문제\\n\\n\\n\#\#\# Steps to reproduce\\n\\n1.기존 hwp파일을 hop로 연다\\n2.저장을 한다\\n **[passage]** \\n\\n\\n\#\#\# Expected behavior\\n\\n파일을 저장하는 과정에서 특정 단어를 빼고 저장됨 ex\) \\\\;/\#등의 명령\\n\\n\#\#\#…
  - Review: Save fidelity is where existing apps fail in practice, so verification is where depth pays
  - Preserved: [hop-i73 snapshot](snapshots/hop-i73/114ad422027c15f1b04e00470d200b1cf2718d2702122067a10c8ee56ca1085c.txt)
- e-i8172 [supports, self]: [edwardkim/rhwp issue \#8172 \(GitHub API JSON\)](https://api.github.com/repos/edwardkim/rhwp/issues/8172)
  - Location: issue \#8172 body, 증상; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 를 넣은 문서를 HWP로 저장하면, 한컴 2024\(13.0.0.3901\)가 열 때
  - Context: …0\},"body":"\#\# 증상\\n\\n편집 API \`createShapeControl\`로 \*\*글상자\(\`shapeType: 'textbox'\`\)\*\* **[passage]**  \\"문서가 손상되었거나 변조되었을 수 있음\\"이라고 경고한다. 무인 변환은 거부된다\(\`HANCOM\_DOCUMENT\_OPEN\_REJECTED\`\)…
  - Review: Real 한글 is the decisive check for saved files \(rejected file found only by opening in 한컴 2024\)
  - Preserved: [rhwp-i8172 snapshot](snapshots/rhwp-i8172/acea12a07cca1fb29e7eefd561b433f3e42591b2489193406ca1125736994732.txt)
- e-pdf-proc [supports, self]: [rhwp wiki: 한컴-PDF-환경-의존성](https://raw.githubusercontent.com/wiki/edwardkim/rhwp/%ED%95%9C%EC%BB%B4-PDF-%ED%99%98%EA%B2%BD-%EC%9D%98%EC%A1%B4%EC%84%B1.md)
  - Location: 회귀 의심 시 권장 절차; version: unknown; read: full\_text; capture: helper\_fetched
  - Passage/observation: 2. \*\*두 버전이 일치\*\* 하면 정답지로 사용 가능
  - Context: …정합 한쪽 채택\*\* 룰 보강 \#\#\# 회귀 의심 시 권장 절차 1. 한컴 2010 + 한컴 2020 \(또는 한컴 2022\) 두 버전 PDF 확보  **[passage]**  3. \*\*두 버전이 다르면\*\*: - 어느 버전이 정확한지 작업지시자 또는 한컴 사용자 직접 검증 - rhwp 결과가 한 쪽과 정합하면 \*\*정답…
  - Review: Motivates using two Hancom versions as the reference
  - Preserved: [rhwp-wiki-pdf snapshot](snapshots/rhwp-wiki-pdf/db48535e21898a6213384d8a9a7fc56e60628275891f7e9367dfd6a457cd13ce.txt)

## Pending review and access limits

- c-libs: supported label lacks support or contradiction resolution
- c-spec: stress judgment remains unresolved
- c-owpml: stress judgment remains unresolved
- c-rhwp: stress judgment remains unresolved
- c-hop: stress judgment remains unresolved
- c-mac: stress judgment remains unresolved
- pyhwp-readme: unavailable; limited source access
- msrc-office-sdl: unavailable; Article body not present in fetched HTML text \(likely client-rendered\); fuzzing figures not readable
