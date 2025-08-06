# mastodon_shop_bot.py
import re
import random
from datetime import datetime
from mastodon import Mastodon
import gspread
from oauth2client.service_account import ServiceAccountCredentials

# ============================
# 0. 환경 설정 및 초기화
# ============================
scope = ["https://spreadsheets.google.com/feeds", "https://www.googleapis.com/auth/drive"]
credentials = ServiceAccountCredentials.from_json_keyfile_name("credentials.json", scope)
gc = gspread.authorize(credentials)
sheet = gc.open_by_key("구글시트ID")
student_ws = sheet.worksheet("플레이어")
item_ws = sheet.worksheet("아이템")
log_ws = sheet.worksheet("상점로그")

mastodon = Mastodon(
    access_token="마스토돈_ACCESS_TOKEN",
    api_base_url="https://your.server.domain"
)

# ============================
# 1. 설정값 및 상수
# ============================
FEATURES = {
    "tarot": True,
    "dice": True,
    "lucky_pouch": True,
    "item_transfer": True,
    "item_use": True,
    "pouch": True,
    "shop_buy": True,
    "card": True,
    "envelope": True
}
# 전체 78장 타로 카드 (메이저 + 마이너 아르카나 포함)
TAROT_MEANINGS = {}

# 메이저 아르카나 카드
major_arcana = [
    ("바보 (The Fool)", "이 카드는 무언가를 새롭게 시작하려는 너에게 나타나는 징조란다. 두려움 없이 나아가도 괜찮지만, 때때로 신중함도 필요하단다."),
    ("마법사 (The Magician)", "너의 손 안엔 무한한 가능성이 있어. 원하는 걸 이루려면 의지를 다지고 집중해야 한단다."),
    ("여사제 (The High Priestess)", "겉으로 보이는 것만 믿지 마렴. 내면의 소리에 귀 기울이고, 아직 드러나지 않은 진실을 기다려보자."),
    ("황후 (The Empress)", "풍요와 창조의 에너지야. 네가 사랑하거나 기르는 모든 것이 자라고 있어."),
    ("황제 (The Emperor)", "질서와 구조, 책임감이 필요한 시기야. 자신의 권위와 리더십을 신뢰해도 좋아."),
    ("교황 (The Hierophant)", "전통적인 지혜와 조언을 구하렴. 제도나 규칙 속에서 중요한 메시지를 얻을 수 있어."),
    ("연인 (The Lovers)", "사랑, 관계, 선택에 대한 카드야. 네 마음을 따르되, 책임도 함께 생각해야 해."),
    ("전차 (The Chariot)", "강한 의지와 결단력으로 밀고 나가야 해. 주저하지 말고 나아가렴."),
    ("힘 (Strength)", "진정한 힘은 부드러움에서 나와. 인내와 용기로 상황을 다뤄야 해."),
    ("은둔자 (The Hermit)", "혼자만의 시간이 필요해. 내면의 지혜를 찾고, 서두르지 마."),
    ("운명의 수레바퀴 (Wheel of Fortune)", "운명이 바뀌는 시기야. 네가 통제할 수 없는 흐름을 받아들이는 것도 필요해."),
    ("정의 (Justice)", "균형과 진실의 카드야. 공정함을 잊지 마렴, 네 행동엔 결과가 따를 거야."),
    ("매달린 사람 (The Hanged Man)", "잠시 멈춰야 할 시기야. 새로운 시각이 필요한 때란다."),
    ("죽음 (Death)", "두려워 마렴. 죽음은 끝이 아니라 새로운 시작이야. 오래된 것과 이별할 용기를 가져야 할 때란다."),
    ("절제 (Temperance)", "극단에서 벗어나 조화를 이루려 노력해보자. 지금은 균형이 중요해."),
    ("악마 (The Devil)", "무언가에 얽매여 있는 건 아닐까? 중독이나 집착을 내려놓을 용기가 필요해."),
    ("탑 (The Tower)", "갑작스러운 변화가 있을 수 있어. 무너지더라도, 그 자리에 더 나은 것이 세워질 거야."),
    ("별 (The Star)", "희망의 빛이 비추고 있어. 다시 꿈꿀 수 있어, 얘야."),
    ("달 (The Moon)", "혼란스러울 수 있어도 괜찮아. 불확실함 속에서도 본능을 믿어봐."),
    ("태양 (The Sun)", "밝고 긍정적인 에너지가 가득하단다. 성공과 기쁨의 징조야."),
    ("심판 (Judgement)", "자신을 돌아볼 시간이야. 과거의 행동이 지금을 만든단다."),
    ("세계 (The World)", "한 여정이 끝났고, 너는 한 단계 성장했어. 이제는 축하할 시간이지. 다음 장을 기대해도 좋아.")
]

# 마이너 아르카나 카드 (슈트별 숫자 + 궁정 포함)
minor_descriptions = {
    "완드": {
        1: "새로운 아이디어와 영감이 떠오르는 시작의 순간이란다.",
        2: "결정을 내리기 위한 계획과 선택의 시간이지.",
        3: "기대한 결과가 천천히 다가오고 있어.",
        4: "안정감과 축하의 시기로, 기쁨을 나눌 수 있단다.",
        5: "작은 경쟁이나 갈등이 생길 수 있어, 침착하게 대응해보자.",
        6: "승리와 인정의 카드란다. 수고한 만큼 보상이 따를 거야.",
        7: "네 입장을 지켜야 할 때란다. 방어에 힘을 쏟아보자.",
        8: "빠른 변화와 소식이 다가오고 있어. 마음의 준비를 하자.",
        9: "지금까지 잘 견뎌왔단다. 조금만 더 힘내렴.",
        10: "책임이 무거울 수 있어도, 곧 끝이 보일 거야."
    },
    "컵": {
        1: "새로운 감정의 시작이야. 사랑이나 우정이 피어날 수 있어.",
        2: "조화롭고 균형 잡힌 관계의 탄생이야.",
        3: "친구들과 기쁨을 나누는 시간, 축하할 일이 있단다.",
        4: "무언가 만족스럽지 않다면, 잠시 쉬어가도 괜찮아.",
        5: "잃은 것에 집중하지 말고, 남은 것에 감사하자.",
        6: "추억이나 과거의 인연이 다시 나타날 수 있어.",
        7: "선택의 카드란다. 눈앞의 환상에 속지 않도록 조심해.",
        8: "무언가를 떠날 결심이 필요한 시기야.",
        9: "바람이 이뤄지는 카드야. 지금의 만족을 즐겨봐.",
        10: "감정적으로 충만한 행복이 너를 기다리고 있어."
    },
    "소드": {
        1: "진실과 지성이 번뜩이는 시작의 칼날이야.",
        2: "선택을 미루고 있다면, 이젠 결정해야 할 때야.",
        3: "슬픔이나 실망이 따를 수 있지만, 치유도 함께 온단다.",
        4: "휴식과 회복이 필요해. 잠시 멈춰서 숨을 돌려보렴.",
        5: "승리처럼 보여도 상처가 남을 수 있는 갈등이야.",
        6: "더 나은 곳을 향한 이주나 변화가 찾아오고 있어.",
        7: "모략이나 속임수에 주의해야 해.",
        8: "두려움에 스스로를 가두고 있는 건 아닐까? 용기를 내보자.",
        9: "불안과 걱정이 많아질 수 있어. 누군가에게 털어놓아도 괜찮아.",
        10: "어두운 시간은 끝나가고 있어. 새로운 시작이 올 거란다."
    },
    "펜타클": {
        1: "물질적 기회가 열리는 시작의 카드야.",
        2: "균형 잡힌 재정 관리가 중요해.",
        3: "협업을 통해 성과를 낼 수 있어.",
        4: "지나친 집착은 오히려 손해를 부를 수 있어.",
        5: "경제적 어려움이 있어도 도움을 받을 수 있을 거야.",
        6: "주는 것과 받는 것의 균형을 생각해보자.",
        7: "기다림의 카드야. 노력의 결과는 곧 나타날 거야.",
        8: "꾸준한 노력이 쌓이는 시기란다.",
        9: "물질적 안정과 우아한 독립이 조화를 이루는 카드야.",
        10: "가족, 유산, 장기적인 안정이 중요해지는 시기야."
    }
}

for suit, values in minor_descriptions.items():
    for num, description in values.items():
        name = f"{suit} {num if num != 1 else '에이스'}"
        TAROT_MEANINGS[name] = description
    for court in ["페이지", "기사", "여왕", "왕"]:
        name = f"{suit}의 {court}"
        TAROT_MEANINGS[name] = f"{suit}의 {court} 카드는 그 속성에 따라 사람의 성격이나 역할을 상징한단다."

TAROT_MEANINGS.update(dict(major_arcana))

# ============================
# 행운 요소
# ============================
LUCKY_ITEMS = ["마법 지팡이", "은빛 부엉이 펜", "님부스2000", "진실의 부적", "마법의 쿠키", "작은 수정병", "행운의 돌", "별무늬 손수건", "시간의 시계", "비밀 노트", "고양이 인형", "반짝이는 브로치", "마법약 병", "깃털 펜촉", "고대 동전", "하트 모양 캔디", "행운의 열쇠", "꿈의 향수", "빛나는 물방울", "부엉이 배지"]
LUCKY_COLORS = ["하늘색", "은색", "핑크빛 노랑", "푸른 회색", "딸기 우유색", "라벤더색", "짙은 녹색", "초코 브라운", "연보라", "밝은 금색", "선홍색", "하늘 회색", "코랄 오렌지", "은회색", "진청색", "민트", "보라분홍", "갈색", "연남색", "파란 회색"]
LUCKY_PLACES = ["도서관 창가", "마법 약초 정원", "그리핀도르 벽난로 앞", "비밀 계단 아래", "기억의 분수대", "천문대 옥상", "고양이 조각상 근처", "연회장 테라스", "지하실 통로", "달빛 내리는 복도", "변신술 교실", "빛나는 거울 앞", "금지된 숲 입구", "마법 식물 온실", "시간탑 아래", "오래된 교장실 문 앞", "작은 도서실 구석", "점술 탑", "슬리데린 연못", "부엉이 탑"]

# ============================
# 타로 핸들러
# ============================
def handle_tarot(student_id):
    card = random.choice(list(TAROT_MEANINGS.keys()))
    meaning = TAROT_MEANINGS[card]
    lucky_item = random.choice(LUCKY_ITEMS)
    lucky_color = random.choice(LUCKY_COLORS)
    lucky_place = random.choice(LUCKY_PLACES)
    return f"[{card}]\n{meaning}\n\n오늘의 행운 아이템: {lucky_item}\n행운의 색: {lucky_color}\n행운의 장소: {lucky_place}"

# ============================
# 봉투 핸들러 (1~10갈레온 베팅, -5~5배 랜덤)
# ============================
import random

def handle_bet(student_id: str, amount: int, player_data: dict, transaction_log: list) -> str:
    if amount < 1 or amount > 10:
        return "얘야, 베팅은 1에서 10갈레온까지만 가능하단다~"

    if student_id not in player_data:
        return "어머, 낯선 얼굴이구나? 먼저 등록부터 해줘야 상점 이용이 가능하단다."

    student = player_data[student_id]

    if student.get("debt", 0) > 0:
        return "미안하지만, 빚이 있으면 상점 이용은 어렵단다… 먼저 갚고 오렴."

    current_galleons = student.get("galleons", 0)
    if current_galleons < amount:
        return "갈레온이 부족하단다~ 가진 만큼만 걸 수 있어!"

    # 베팅 결과: -5 ~ +5 중 하나
    multiplier = random.choice([-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5])
    change = amount * multiplier
    new_balance = current_galleons + change

    if new_balance < 0:
        student["galleons"] = 0
        student["debt"] = abs(new_balance)
        outcome_msg = f"{amount}갈레온의 {multiplier:+}배, 현재 잔액: 0 (빚 {abs(new_balance)}갈레온)"
    else:
        student["galleons"] = new_balance
        student["debt"] = 0
        outcome_msg = f"{amount}갈레온의 {multiplier:+}배, 현재 잔액: {new_balance}갈레온"

    # 기록 남기기
    transaction_log.append({
        "type": "bet",
        "student_id": student_id,
        "amount": amount,
        "multiplier": multiplier,
        "result": change,
        "new_balance": student["galleons"],
        "debt": student.get("debt", 0)
    })

    return f"베팅 결과!\n{outcome_msg}"


# ============================
# 4. 유틸리티 함수 (미구현 예시)
# ============================
def get_player_sheet():
    return player_ws.get_all_records(empty2zero=False, head=1, default_blank="")

def update_player_sheet(df):
    pass  # 시트 업데이트 로직 작성 필요

def get_shop_sheet():
    return item_ws.get_all_records(empty2zero=False, head=1, default_blank="")

def get_lucky_log():
    return log_ws.get_all_records(empty2zero=False, head=1, default_blank="")

def append_lucky_log(row):
    pass  # 로그 시트에 append하는 코드 작성 필요

def add_item(inventory, item):
    # 문자열 형태의 소지품에 추가
    items = inventory.split(',') if inventory else []
    items.append(item)
    return ','.join(items)

def remove_item(inventory, item):
    items = inventory.split(',')
    if item in items:
        items.remove(item)
    return ','.join(items)
