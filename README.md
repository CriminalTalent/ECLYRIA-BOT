# 호그와트 마법용품점 봇

마스토돈 기반의 호그와트 테마 상점 및 미니게임 봇입니다. 구글 시트와 연동하여 아이템 구매, 갈레온 관리, 베팅 게임 등을 제공합니다.

## 주요 기능

### 🏪 상점 시스템
- **아이템 구매**: 마법용품 구매 및 관리
- **갈레온 시스템**: 게임 내 화폐 관리
- **아이템 양도**: 사용자 간 아이템 및 갈레온 교환
- **인벤토리**: 보유 아이템 및 갈레온 확인

### 🎮 미니게임
- **베팅 시스템**: 1-20 갈레온 베팅 (하루 3회 제한, x-5~+5 배수)
- **주사위**: 20면, 100면 주사위
- **점술**: YES/NO 간단 점술
- **타로카드**: 78장 타로카드 운세 (행운의 색상, 물건 포함)
- **동전 던지기**: 앞면/뒷면

### 📊 구글 시트 연동
- 실시간 사용자 데이터 동기화
- 아이템 정보 관리
- 자동 응답 시스템
- 베팅 횟수 및 날짜 추적

## 설치 및 설정

### 1. 필요한 패키지 설치

```bash
# Gemfile 생성
bundle init

# Gemfile에 다음 추가:
# gem 'mastodon-api', require: 'mastodon'
# gem 'google_drive'
# gem 'dotenv'

bundle install
```

### 2. 환경 변수 설정

`.env` 파일을 생성하고 다음 내용을 입력:

```env
# 마스토돈 설정
MASTODON_BASE_URL=https://your-mastodon-instance.com
MASTODON_TOKEN=your_access_token_here

# 구글 시트 설정
GOOGLE_CREDENTIALS_PATH=/path/to/your/service-account-key.json
GOOGLE_SHEET_ID=your_google_sheet_id_here
```

### 3. 마스토돈 토큰 발급

1. 마스토돈 계정 설정 → 개발 → 새 애플리케이션
2. 권한: `read`, `write` 설정
3. 액세스 토큰 복사하여 `.env`에 설정

### 4. 구글 시트 설정

#### 4.1 서비스 계정 생성
1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. 프로젝트 생성 또는 선택
3. Google Sheets API 활성화
4. 서비스 계정 생성 및 JSON 키 다운로드

#### 4.2 구글 시트 생성
다음 워크시트들을 포함한 구글 시트 생성:

**사용자 시트:**
| A (아이디) | B (이름) | C (갈레온) | D (아이템) | E (메모) | F (기숙사) | G (마지막베팅일) | H (오늘베팅횟수) |
|------------|----------|------------|------------|----------|------------|------------------|------------------|

**아이템 시트:**
| A (이름) | B (가격) | C (설명) | D (구매가능) | E (양도가능) | F (사용가능) | G (효과) | H (사용시삭제) |
|----------|----------|----------|-------------|-------------|-------------|----------|----------------|

**응답 시트:**
| A (ON/OFF) | B (키워드) | C (응답) |
|------------|------------|----------|

#### 4.3 권한 설정
- 서비스 계정 이메일을 구글 시트에 편집자로 공유

## 사용법

### 봇 실행
```bash
ruby main.rb
```

### 상점 명령어

```
[상점]                           # 상점 목록 보기
[구매/아이템명]                  # 아이템 구매
[주머니]                         # 갈레온 & 소지품 확인
[사용/아이템명]                  # 아이템 사용
[양도/아이템명/@상대ID]          # 아이템 양도
[양도/갈레온/금액/@상대ID]       # 갈레온 양도
```

### 미니게임 명령어

```
[베팅/금액]                      # 베팅 (1-20G, 하루 3회)
[20D]                            # 20면 주사위
[100D]                           # 100면 주사위
[yn]                             # YES/NO 점술
[운세]                           # 타로카드 운세
[동전] 또는 [동전던지기]         # 동전 던지기
```

## 구글 시트 구조

### 아이템 시트 예시
```
이름         | 가격 | 설명              | 구매가능 | 양도가능 | 사용가능 | 효과                    | 사용시삭제
체력포션     | 10   | 체력을 회복합니다 | ✓        | ✓        | ✓        | 체력 +20               | ✓
마법지팡이   | 50   | 강력한 마법지팡이 | ✓        | ✓        |          | 마법 공격력 증가       |
황금스니치   | 100  | 퀴디치 황금스니치 | ✓        |          |          | 행운의 상징            |
```

### 응답 시트 예시
```
ON/OFF | 키워드        | 응답
ON     | 안녕         | {name}님 안녕하세요! 마법용품점에 오신 것을 환영합니다!
ON     | 고마워       | {name}님, 또 오세요!
✓      | 추천         | 오늘의 추천 아이템은 체력포션입니다!
```

## 베팅 시스템

- **제한**: 하루 3회, 1-20 갈레온
- **결과**: x-5 ~ x+5 배수 (총 11가지)
  - **x0**: 무승부 (원금 반환)
  - **x1~x5**: 승리 (배수만큼 추가 획득)
  - **x-1~x-5**: 패배 (베팅금 + 배수만큼 손실)
- **빚 시스템**: 갈레온이 음수가 되면 갚기 전까지 구매 제한

## 파일 구조

```
shop-bot/
├── main.rb                 # 봇 실행 파일
├── bot/
│   ├── command_parser.rb   # 명령어 처리
│   └── mastodon_client.rb  # 마스토돈 API 클라이언트
├── .env                    # 환경 변수 (git에 포함하지 말 것)
├── Gemfile                 # Ruby 의존성
└── README.md              # 이 파일
```

## 트러블슈팅

### 구글 시트 연결 실패
- 서비스 계정 JSON 파일 경로 확인
- 시트 ID 확인 (URL에서 `/d/` 뒤의 긴 문자열)
- 서비스 계정에 시트 편집 권한 부여 확인

### 마스토돈 연결 실패
- BASE_URL에 `https://` 포함 여부 확인
- 액세스 토큰의 `read`, `write` 권한 확인
- 인스턴스별 API 제한 확인

### 베팅이 작동하지 않음
- 사용자 시트에 `마지막베팅일`, `오늘베팅횟수` 컬럼 존재 확인
- 날짜 형식이 `YYYY-MM-DD` 인지 확인

## 개발자 정보

- **타겟 플랫폼**: 마스토돈 (ActivityPub)
- **언어**: Ruby
- **데이터베이스**: Google Sheets
- **테마**: 해리포터 호그와트

## 라이센스

MIT License

---

문의사항이나 버그 신고는 이슈로 등록해주세요!
