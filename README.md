# ABANDONED — Forsaken 스타일 비대칭 호러 (Roblox)

Roblox 게임 **Forsaken** 에서 영감을 받은 1 vs 다수 비대칭 서바이벌 호러 게임입니다.
살인마 1명이 생존자 전원을 쓰러뜨리거나, 생존자가 제한 시간까지 버티면 승리합니다.
맵·UI·이펙트를 모두 코드로 생성하므로 **빈 Baseplate 에 동기화만 하면 바로 플레이**할 수 있습니다.

> 캐릭터 이름·능력은 원작의 *아키타입*(막기형, 힐러, 코인 도박 총잡이, 분신, 글리치 살인마 등)만 참고한 오리지널입니다.

## 게임 규칙

| 항목 | 내용 |
| --- | --- |
| 살인마 선정 | 로비에서 쌓은 **악의(Malice)** 가 가장 높은 플레이어가 살인마. 살인마가 되면 0 으로 초기화, 나머지는 라운드마다 +1~3 |
| 생존자 승리 | 라운드 타이머(기본 4분)가 0이 될 때까지 1명 이상 생존 |
| 살인마 승리 | 생존자 전원 처치 |
| 발전기 | 근처에서 **F** → 번호 퍼즐(1→5 순서대로 클릭) 4단계 완료 시 수리. 완료할 때마다 타이머 **-25초** |
| 최후의 생존자 | 생존자가 1명 남으면 타이머가 최대 60초로 줄고 스태미나 완전 회복 |
| 스태미나 | Shift 로 달리면 소모, 0이 되면 탈진(35% 회복 전까지 달리기 불가) |
| 기타 | 점프 불가, 자연 체력 회복 없음, 맞으면 잠깐 가속, 사망 시 관전 모드 |
| 혼자 접속 | 봇 살인마(AI, 길찾기 + 능력 사용)와 대결 — 테스트용 |

## 조작

| 키 | 동작 |
| --- | --- |
| WASD | 이동 |
| Left Shift (홀드) | 달리기 |
| Q / E | 능력 1 / 능력 2 |
| 마우스 왼쪽 | (살인마) 기본 공격 |
| F | 발전기 수리 |
| 모바일 | 우하단 능력 슬롯 터치, "달리기" 토글 버튼 |

## 캐릭터

### 생존자
| 이름 | 체력 | Q | E |
| --- | --- | --- | --- |
| 러너 | 100 | 아드레날린 — 4초 +40% 속도, 스태미나 회복 | 육감 — 5초간 벽 너머 살인마 표시 |
| 싸움꾼 | 120 | 막기 — 1.2초 내 피격 시 피해 무효 + 살인마 3초 기절 | 주먹 — 근접 1.75초 기절 |
| 의무병 | 90 | 구급상자 — 동료 35 / 자신 25 회복 | 격려 — 주변 생존자 6초 +25% 속도 |
| 총잡이 | 85 | 동전 던지기 — 50% 확률로 행운 +1 (최대 3) | 사격 — 명중률 35%+20%×행운, 명중 시 3.5초 기절 / 실패 시 오발 |
| 검객 | 100 | 베기 — 근접 2.25초 기절 | 치킨 — 3초간 30 회복 |
| 유령 | 90 | 은신 — 5초 투명 + 15% 속도 | 분신 — 달려가는 분신 생성, 살인마가 때리면 둔화 |

### 살인마
| 이름 | 공격력 | Q | E |
| --- | --- | --- | --- |
| 할로우 | 30 | 부패의 가시 — 일직선 가시, 20 피해 + 둔화 | 글리치 스텝 — 전방 20칸 순간이동 |
| 도살자 | 25 | 분노 — 5초 +30% 속도 | 돌진 — 부딪히면 30 피해, 빗나가면 둔화 |
| 감시자 | 25 | 대량 감염 — 반경 22 광역 15 피해 + 3초 둔화 | 칼날 투척 — 투사체 25 피해 + 둔화 |

## 설치 / 실행 ([Rojo](https://rojo.space))

```bash
# Rojo 설치 (aftman / rokit / cargo 중 택1)
cargo install rojo

# 프로젝트 폴더에서
rojo serve
```

1. Roblox Studio 에서 **Baseplate** 템플릿을 새로 엽니다.
2. Rojo 플러그인에서 **Connect** (기본 포트 34872).
3. ▶ Play 로 테스트 — 혼자면 봇 살인마와, `Test > Clients and Servers` 로 2명 이상이면 플레이어끼리 대결합니다.

`rojo build -o Abandoned.rbxlx` 로 바로 열 수 있는 place 파일을 만들 수도 있습니다.

## 프로젝트 구조

```
default.project.json         Rojo 매핑
src/
├── shared/                  ReplicatedStorage.Shared
│   ├── Config.luau          밸런스·시간·맵 설정값
│   ├── Characters.luau      생존자/살인마 정의 (스탯, 능력)
│   └── Remotes.luau         RemoteEvent 생성/참조
├── server/                  ServerScriptService.Server
│   ├── init.server.luau     진입점
│   ├── RoundService.luau    게임 루프 (대기→인터미션→라운드→결과), 살인마 선정, 보상
│   ├── MapBuilder.luau      로비·경기장·조명 절차적 생성
│   ├── GeneratorService.luau 발전기 생성 / 퍼즐 단계 검증
│   ├── AbilityService.luau  모든 Q/E 능력 핸들러
│   ├── Combat.luau          히트박스, 피해, 기절, 살인마 기본 공격
│   ├── Movement.luau        서버 권위 이동속도 / 스태미나
│   ├── Status.luau          상태이상 (기절·둔화·가속·고정·방어·투명)
│   ├── State.luau           라운드 참가자 상태 저장소
│   ├── CharacterSetup.luau  역할별 외형 (살인마 붉은 눈·무기·윤곽선)
│   ├── BotKiller.luau       솔로용 AI 살인마
│   ├── LobbyService.luau    리더보드, 캐릭터 선택
│   ├── Visuals.luau         서버측 이펙트, 분신
│   └── Net.luau             서버→클라 알림 헬퍼
├── client/                  StarterPlayerScripts.Client
│   ├── init.client.luau     진입점, 알림 디스패치
│   ├── HUD.luau             타이머, 체력/스태미나, 능력 쿨다운
│   ├── CharacterSelect.luau 로비 캐릭터 선택 패널
│   ├── GeneratorPuzzle.luau 발전기 미니게임
│   ├── Controls.luau        키보드/게임패드/모바일 입력
│   ├── Spectate.luau        사망 후 관전
│   ├── Effects.luau         피격 플래시, 위치 노출 등
│   └── UI.luau              UI 헬퍼
└── character/Health.server.luau  기본 체력 회복 비활성화
```

## 확장 방법

- **새 캐릭터**: `Characters.luau` 에 정의를 추가하고(`Abilities.Q/E.Id`), `AbilityService.luau` 의 `Handlers` 에 같은 이름의 함수를 추가하면 됩니다. 선택 목록에 노출하려면 `SurvivorOrder` / `KillerOrder` 에도 추가하세요.
- **밸런스**: `Config.luau` 에서 라운드 시간, 발전기 수/단계, 스태미나 수치 등을 조정합니다.
- **음악/효과음**: 추격 음악·최후의 생존자 음악은 `client/Effects.luau` 의 `LastManStanding` 등에 `Sound` 를 추가해 넣을 수 있습니다 (본인 소유 또는 사용 가능한 오디오 ID 필요).
- **데이터 저장**: 현재 Malice / Wins 는 세션 내에서만 유지됩니다. 영구 저장이 필요하면 `LobbyService` 에 DataStoreService 를 연결하세요.

## 저장소 메모 (main 브랜치에서 병합)

```
PICKON/
├── .claude-plugin/
│   └── marketplace.json
└── plugins/
    └── 플러그인이름/
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/ ...
{
  "name": "pickon",
  "owner": { "name": "PICKON39" },
  "plugins": [
    {
      "name": "플러그인이름",
      "source": "./plugins/플러그인이름",
      "description": "플러그인 설명"
    }
  ]
}
```
