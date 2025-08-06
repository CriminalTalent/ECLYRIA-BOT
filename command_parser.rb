import datetime
import random

# 주요 타로 카드 (메이저 아르카나) 22장
TAROT_MEANINGS = {
    "바보 (The Fool)": "무언가를 새롭게 시작하려는 너에게 나타나는 징조야. 두려움 없이 나아가도 괜찮지만, 때때로 신중함도 필요하지.",
    "마법사 (The Magician)": "너의 손 안엔 무한한 가능성이 있어. 원하는 걸 이루려면 의지를 다지고 집중해야 한단다.",
    "여사제 (The High Priestess)": "겉으로 보이는 것만 믿지 마렴. 내면의 소리에 귀 기울이고, 아직 드러나지 않은 진실을 기다려보자.",
    "여왕 (The Empress)": "풍요와 따뜻함을 의미한단다. 지금은 돌보거나 돌봄 받는 관계가 중요해.",
    "황제 (The Emperor)": "질서와 구조, 책임감이 필요해. 지금은 감정보다 이성이 우선일 수 있어.",
    "교황 (The Hierophant)": "전통이나 규범을 따르거나, 누군가의 조언을 듣는 것이 좋을지도 몰라.",
    "연인 (The Lovers)": "선택의 기로에 있을지도 몰라. 감정과 책임 사이에서 균형을 잡아야 해.",
    "전차 (The Chariot)": "지금의 너는 승리를 향해 나아가고 있어. 결단력과 집중이 중요해.",
    "힘 (Strength)": "진짜 힘은 온화함과 인내에서 나와. 억누르는 것보다 이해하려 해봐.",
    "은둔자 (The Hermit)": "혼자 있는 시간이 필요한 시기야. 내면의 빛을 따라가보자.",
    "운명의 수레바퀴 (Wheel of Fortune)": "세상은 끊임없이 변해. 지금은 변화의 흐름에 몸을 맡기는 것도 좋아.",
    "정의 (Justice)": "균형과 공정함이 필요한 순간이야. 너의 선택이 책임을 동반할 수도 있어.",
    "매달린 사람 (The Hanged Man)": "일시적인 정체는 새로운 관점을 가져다줄 수 있어. 성급하게 판단하지 마.",
    "죽음 (Death)": "두려워 마. 죽음은 끝이 아니라 새로운 시작이야. 오래된 것과 이별할 용기를 가져야 할 때란다.",
    "절제 (Temperance)": "모든 것은 균형이 필요해. 급하지 않게, 조화롭게 가보자.",
    "악마 (The Devil)": "무언가에 얽매여 있는 건 아닌지 돌아봐야 해. 해방이 필요할지도 몰라.",
    "탑 (The Tower)": "갑작스러운 변화가 있을 수 있어. 무너짐 뒤에 진실이 드러날지도 몰라.",
    "별 (The Star)": "희망을 잃지 마렴. 너는 빛나는 가능성을 가진 사람이야.",
    "달 (The Moon)": "불확실함과 착각에 주의해야 해. 직관을 믿되, 냉정함도 잊지 마.",
    "태양 (The Sun)": "밝고 긍정적인 에너지가 너를 감싸고 있어. 지금은 빛날 수 있는 시기야.",
    "심판 (Judgement)": "과거의 선택이 다시 떠오를 수 있어. 스스로를 돌아보고 정화할 시간이지.",
    "세계 (The World)": "한 여정이 끝났고, 너는 한 단계 성장했어. 이제는 축하할 시간이지. 다음 장을 기대해도 좋아."
}

TAROT_CARDS = list(TAROT_MEANINGS.keys())

# 행운 요소 리스트 (랜덤 추천용)
LUCKY_ITEMS = [
    "깨끗하게 깎은 깃펜", "호그와트에서 잘 마르는 수건", "작은 나무단검",
    "다 쓴 깃펜", "낡은 성적표", "초콜릿 개구리", "비밀의 지도 조각",
    "낡은 손수건", "반쯤 부러진 마법 지팡이", "작은 유리병",
    "조용히 울리는 종", "양피지 조각", "비밀 상자 열쇠", "고대 주문서 페이지", "반쯤 닳은 퀴디치 초대권"
]

LUCKY_COLORS = [
    "짙은 자주색", "청록색", "은빛 회색", "버터 노랑", "푸른 연기색",
    "은은한 갈색", "복숭아빛 핑크", "맑은 하늘색", "초록빛 회색", "진한 곤색",
    "우유빛 흰색", "회갈색", "연보라", "짙은 남색", "보랏빛 회색"
]

LUCKY_PLACES = [
    "북쪽 탑", "비밀 통로", "도서관 맨 안쪽 열람실", "용의 골짜기 벽화 앞",
    "금지된 숲 가장자리", "기숙사 공용실 창가", "수업이 없는 빈 교실",
    "사라진 계단 근처", "천문대 망원경 옆", "작은 식물 온실",
    "지하의 긴 복도 끝", "기숙사 침대 아래", "봉인된 창고 앞",
    "허둥지둥 모자 선반 뒤", "2층 화장실 뒤 벽"
]

def draw_tarot_card():
    card = random.choice(TAROT_CARDS)
    meaning = TAROT_MEANINGS[card]
    return card, meaning

def draw_lucky_item():
    return random.choice(LUCKY_ITEMS)

def draw_lucky_color():
    return random.choice(LUCKY_COLORS)

def draw_lucky_place():
    return random.choice(LUCKY_PLACES)

  from mastodon import Mastodon
import re
import random
from tarot_data import TAROT_CARDS, TAROT_MEANINGS
from tarot_system import draw_tarot_card, draw_lucky_item, draw_lucky_color, draw_lucky_place

# 환경 변수 등은 따로 로드한다고 가정
MASTODON_API_BASE = "https://your-instance.example"
ACCESS_TOKEN = "your-access-token"

mastodon = Mastodon(access_token=ACCESS_TOKEN, api_base_url=MASTODON_API_BASE)

# 기능 ON/OFF
TAROT_ENABLED = True
DICE_ENABLED = True

# 학생 등록 여부 확인용 - Google Sheets와 연동되어야 함
REGISTERED_STUDENTS = {"@student1@example.com", "@student2@example.com"}  # 임시 예시

def is_registered(account_acct):
    return account_acct in REGISTERED_STUDENTS

def handle_mention(notification):
    content = notification["status"]["content"]
    acct = notification["account"]["acct"]
    status_id = notification["status"]["id"]

    if not is_registered(acct):
        mastodon.status_post(
            f"이봐, 넌 학적부에 이름이 없잖아. 내 가게는 아무나 들여보내지 않아.",
            in_reply_to_id=status_id,
            visibility='unlisted'
        )
        return

    text = re.sub(r'<[^>]+>', '', content).strip()

    if TAROT_ENABLED and "[운세]" in text:
        card, meaning = draw_tarot_card()
        item = draw_lucky_item()
        color = draw_lucky_color()
        place = draw_lucky_place()
        mastodon.status_post(
            f"오늘 네가 뽑은 타로는 [{card}]야. {meaning} "
            f"운 좋은 아이템은 \"{item}\", 색은 \"{color}\", 장소는 \"{place}\"야. 참고해두는 게 좋을 거야.",
            in_reply_to_id=status_id,
            visibility='unlisted'
        )
        return

    dice_match = re.search(r'\[d(\d+)\]', text)
    if DICE_ENABLED and dice_match:
        sides = int(dice_match.group(1))
        if sides > 1:
            result = random.randint(1, sides)
            mastodon.status_post(
                f"{result}",
                in_reply_to_id=status_id,
                visibility='unlisted'
            )
        else:
            mastodon.status_post(
                f"주사위는 최소 2면 이상이어야 굴릴 수 있어.",
                in_reply_to_id=status_id,
                visibility='unlisted'
            )
        return
