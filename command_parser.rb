require 'mastodon'
require 'dotenv/load'
require 'google_drive'
require 'json'
require 'date'

# 구글 드라이브 세션 생성
session = GoogleDrive::Session.from_config("config.json")
spreadsheet = session.spreadsheet_by_title(ENV['SHEET_TITLE'])

# 설정 시트, 학생 시트 로드
settings_ws = spreadsheet.worksheet_by_title("설정")
students_ws = spreadsheet.worksheet_by_title("학생")

# 설정값 가져오기
def get_setting(ws, key)
  row = ws.rows.find { |r| r[0] == key }
  row ? row[1].strip.upcase : "OFF"
end

# 사용자 ID 확인
def registered_student?(students_ws, acct)
  students_ws.rows.any? { |row| row[1] == acct }
end

# 명령어 감지
def parse_command(content)
  command = content[/\[(.*?)\]/, 1]
  command&.strip
end

# 주사위 기능
def roll_dice(command)
  if command.match?(/^d\d+$/i)
    max = command[1..].to_i
    return nil if max <= 0
    rand(1..max).to_s
  end
end

# 행운 요소 목록
LUCKY_ITEMS = %w[
  마법사의지팡이 개구리초콜릿 투명망토 스니치 축소망원경
  마법약세트 노루발장화 뿡빵사탕 부엉이엽서 님부스2000
  빗자루비누 호그와트담요 전기랜턴 반딧불병 주문백과
]

LUCKY_COLORS = %w[
  붉은색 푸른색 노란색 초록색 보라색 회색 흰색 검은색
  주황색 하늘색 남색 분홍색 연두색 자홍색 갈색
]

LUCKY_PLACES = %w[
  금지된숲 점술교실 교수연구실 도서관 기숙사휴게실
  마법교실 천문탑 호그스미드 비밀통로 화장실유령방
  부엉이탑 연회장 고성입구 지하던전 창고
]

TAROT_MEANINGS = {
  "바보 (The Fool)" => "이 카드는 무언가를 새롭게 시작하려는 너에게 나타나는 징조야. 두려움 없이 나아가도 괜찮지만, 때때로 신중함도 필요하지.",
  "마법사 (The Magician)" => "너의 손 안엔 무한한 가능성이 있어. 원하는 걸 이루려면 의지를 다지고 집중해야 한단다.",
  "여사제 (The High Priestess)" => "겉으로 보이는 것만 믿지 마렴. 내면의 소리에 귀 기울이고, 아직 드러나지 않은 진실을 기다려보자.",
  "여황제 (The Empress)" => "풍요와 따뜻함의 기운이 감돌아. 지금은 돌보고 키우는 일에 집중해보렴.",
  "황제 (The Emperor)" => "질서와 책임감이 중요한 시기야. 감정보다 이성을 따르는 것이 유리해.",
  "교황 (The Hierophant)" => "전통적인 방식이나 조언자의 말을 따르는 것이 도움이 될 수 있어.",
  "연인 (The Lovers)" => "중요한 선택의 기로에 서 있구나. 마음이 이끄는 대로 가는 것도 나쁘지 않아.",
  "전차 (The Chariot)" => "집중력과 의지를 다해 앞으로 나아가자. 네가 길을 정하면 누구도 막을 수 없어.",
  "힘 (Strength)" => "진짜 힘은 부드러움 속에 있어. 인내심과 자기 조절이 관건이야.",
  "은둔자 (The Hermit)" => "조용히 자신을 돌아보는 시간이 필요해. 내면의 지혜를 찾을 수 있을 거야.",
  "운명의 수레바퀴 (Wheel of Fortune)" => "운명의 흐름이 바뀌고 있어. 지금의 변화는 우연이 아닌 필연이란다.",
  "정의 (Justice)" => "균형과 공정함이 필요한 때야. 네 선택에 책임질 준비가 되어 있니?",
  "매달린 사람 (The Hanged Man)" => "지금은 멈추고 다른 시각에서 세상을 바라볼 때야. 희생이 필요한 순간일 수도 있어.",
  "죽음 (Death)" => "두려워 마. 죽음은 끝이 아니라 새로운 시작이야. 오래된 것과 이별할 용기를 가져야 할 때란다.",
  "절제 (Temperance)" => "지금은 조화와 균형이 중요해. 감정과 상황을 절제하고 조율해봐.",
  "악마 (The Devil)" => "무언가에 얽매여 있진 않니? 집착이나 욕망에서 벗어날 때가 되었어.",
  "탑 (The Tower)" => "갑작스러운 변화가 다가와. 무너진 후에야 진짜 기초를 세울 수 있어.",
  "별 (The Star)" => "희망과 치유의 시기야. 별처럼 작은 빛이지만, 너를 올바른 방향으로 이끌어줄 거야.",
  "달 (The Moon)" => "혼란스럽고 불확실한 기운이 있어. 직관을 믿고 한걸음씩 나아가자.",
  "태양 (The Sun)" => "모든 것이 밝게 빛나는 시기야. 기쁨과 성공이 가까이에 있어.",
  "심판 (Judgement)" => "과거를 돌아보고, 지금의 선택이 새로운 삶을 여는 계기가 될 거야.",
  "세계 (The World)" => "한 여정이 끝났고, 너는 한 단계 성장했어. 이제는 축하할 시간이지. 다음 장을 기대해도 좋아.",

  # 완드 계열
  "완드 1 (Ace of Wands)" => "무언가 새로운 열정이 생겼구나. 지금 시작하면 에너지가 넘칠 거야.",
  "완드 2 (Two of Wands)" => "선택의 기로에 있어. 지금 너는 더 넓은 세상을 바라보고 있어.",
  "완드 3 (Three of Wands)" => "기다림 끝에 좋은 소식이 있을 거야. 노력한 만큼 결과가 따라올 거야.",
  "완드 4 (Four of Wands)" => "축하와 안정의 기운이야. 주변 사람들과 기쁨을 나눠보자.",
  "완드 5 (Five of Wands)" => "작은 갈등이 생길 수 있어. 경쟁 속에서 네 자리를 지켜봐.",
  "완드 6 (Six of Wands)" => "성공과 인정을 받을 시기야. 자랑스러워해도 좋아.",
  "완드 7 (Seven of Wands)" => "지금은 자신의 입장을 지켜야 할 때야. 흔들리지 말고 버텨보자.",
  "완드 8 (Eight of Wands)" => "모든 것이 빠르게 흘러가고 있어. 기회를 잡으려면 재빨리 움직여야 해.",
  "완드 9 (Nine of Wands)" => "지쳤지만, 아직 포기하지 마. 마지막 한 걸음이 남았어.",
  "완드 10 (Ten of Wands)" => "너무 많은 걸 짊어지고 있진 않니? 짐을 나눠야 해.",
  "완드 시종 (Page of Wands)" => "새로운 모험이 널 부르고 있어. 호기심을 따라가 보자.",
  "완드 기사 (Knight of Wands)" => "열정이 넘치는 시기야. 하지만 충동적인 행동은 피하자.",
  "완드 여왕 (Queen of Wands)" => "당당하고 매력적인 에너지가 너에게 있어. 자신감을 가져도 돼.",
  "완드 왕 (King of Wands)" => "리더십이 필요한 순간이야. 네 비전과 추진력을 보여줘.",

  # 컵 계열
  "컵 1 (Ace of Cups)" => "새로운 감정의 시작이야. 사랑이나 영감이 흘러들고 있어.",
  "컵 2 (Two of Cups)" => "좋은 인연이 다가오고 있어. 상호 이해와 감정의 교류가 중심이야.",
  "컵 3 (Three of Cups)" => "친구들과의 즐거운 시간이 기다리고 있어. 함께하는 기쁨을 누려봐.",
  "컵 4 (Four of Cups)" => "무언가에 실증을 느끼고 있진 않니? 새로운 기회를 놓치지 않도록 주의를 기울여.",
  "컵 5 (Five of Cups)" => "슬픔 속에서도 아직 남아 있는 것이 있어. 뒤돌아보면 희망이 보여.",
  "컵 6 (Six of Cups)" => "추억이나 과거로부터 오는 따뜻함이 있어. 순수한 감정을 떠올려봐.",
  "컵 7 (Seven of Cups)" => "선택의 순간이야. 하지만 현실과 환상을 잘 구분해야 해.",
  "컵 8 (Eight of Cups)" => "무언가를 뒤로하고 떠나야 할 때야. 감정적 결단이 필요해.",
  "컵 9 (Nine of Cups)" => "소원이 이루어질 수 있는 시기야. 만족과 성취감을 느낄 수 있어.",
  "컵 10 (Ten of Cups)" => "감정적 안정과 가족적 행복이 찾아와. 따뜻한 공동체의 기운이야.",
  "컵 시종 (Page of Cups)" => "창의력과 감수성이 높아졌어. 예술적 영감이나 새로운 감정이 시작돼.",
  "컵 기사 (Knight of Cups)" => "낭만적인 제안이 들어올 수 있어. 감정을 솔직하게 표현해보자.",
  "컵 여왕 (Queen of Cups)" => "감정에 귀 기울이는 게 중요해. 직관과 공감능력을 믿어도 좋아.",
  "컵 왕 (King of Cups)" => "감정의 균형을 잘 잡고 있어. 타인에게 좋은 조언자가 되어줄 수 있어.",

  # 검 계열
  "소드 1 (Ace of Swords)" => "진실이 드러나는 시기야. 명확한 사고와 결단이 필요해.",
  "소드 2 (Two of Swords)" => "결정을 미루고 있진 않니? 눈을 가린 채선 현실을 바꿀 수 없어.",
  "소드 3 (Three of Swords)" => "상처받은 마음이 보이네. 아픔을 인정하고 회복하는 게 중요해.",
  "소드 4 (Four of Swords)" => "휴식이 필요해. 잠시 멈추고 충전하자.",
  "소드 5 (Five of Swords)" => "갈등 속에서 네가 얻는 건 무엇일까? 이기려는 욕심을 내려놔도 돼.",
  "소드 6 (Six of Swords)" => "변화의 시간이야. 익숙한 것을 떠나야 할지도 몰라.",
  "소드 7 (Seven of Swords)" => "모든 걸 솔직하게 말하지 않는 누군가가 있어. 또는 너 자신이 숨기고 있는 게 있을지도.",
  "소드 8 (Eight of Swords)" => "스스로를 가두고 있진 않니? 너를 억제하는 건 네 마음일지도 몰라.",
  "소드 9 (Nine of Swords)" => "불안과 걱정이 너를 잠 못 들게 해. 하지만 그것들이 모두 현실은 아니야.",
  "소드 10 (Ten of Swords)" => "끝은 고통스럽지만, 새로운 시작도 가능해. 더는 내려갈 곳이 없단 걸 기억해.",
  "소드 시종 (Page of Swords)" => "호기심과 지적 에너지가 강해졌어. 정보 수집과 분석에 집중해봐.",
  "소드 기사 (Knight of Swords)" => "빠른 결단과 행동이 필요한 순간이야. 하지만 타인을 배려하는 것도 잊지 말자.",
  "소드 여왕 (Queen of Swords)" => "이성적이고 냉철한 판단이 빛나는 시기야. 감정에 휘둘리지 마.",
  "소드 왕 (King of Swords)" => "지혜롭고 공정한 리더가 되어야 해. 지금은 논리적인 접근이 필요해.",

  # 펜타클 계열
  "펜타클 1 (Ace of Pentacles)" => "현실적인 기회가 손에 들어왔어. 재정적 안정이나 실질적인 성취를 기대해도 좋아.",
  "펜타클 2 (Two of Pentacles)" => "여러 가지를 juggling 중이구나. 균형 감각이 필요해.",
  "펜타클 3 (Three of Pentacles)" => "협업의 힘이 중요한 시기야. 네 실력을 다른 사람과 함께 발휘해봐.",
  "펜타클 4 (Four of Pentacles)" => "너무 움켜쥐고 있지 않니? 때론 나눔이 더 큰 풍요를 가져와.",
  "펜타클 5 (Five of Pentacles)" => "결핍과 외로움을 느낄 수 있어. 도움을 청해도 괜찮아.",
  "펜타클 6 (Six of Pentacles)" => "주는 것과 받는 것의 균형이 필요해. 나눔이 중요한 키워드야.",
  "펜타클 7 (Seven of Pentacles)" => "노력의 결실을 기다리는 시간이지. 조급해하지 말고 인내심을 가져봐.",
  "펜타클 8 (Eight of Pentacles)" => "꾸준한 노력이 실력을 완성시켜. 기술을 연마하고 있어야 할 때야.",
  "펜타클 9 (Nine of Pentacles)" => "혼자서도 만족할 만큼 이뤄냈어. 자립과 여유를 즐겨도 돼.",
  "펜타클 10 (Ten of Pentacles)" => "가족, 유산, 긴 시간의 결실 같은 안정감이 주어져. 미래를 위한 기초가 탄탄해.",
  "펜타클 시종 (Page of Pentacles)" => "새로운 실용적 목표를 설정하기에 좋아. 공부나 일에 집중해봐.",
  "펜타클 기사 (Knight of Pentacles)" => "성실함과 끈기가 필요해. 느리지만 꾸준히 가는 것이 옳아.",
  "펜타클 여왕 (Queen of Pentacles)" => "현실적이면서도 따뜻한 보살핌의 기운이 있어. 가정과 재정 둘 다 잘 챙길 수 있어.",
  "펜타클 왕 (King of Pentacles)" => "부와 안정의 상징이야. 신뢰받는 리더가 되기 좋은 시기야."
}

def tarot_reading
  card = TAROT_CARDS.sample
  meaning = TAROT_MEANINGS[card] || "이 카드는 특별한 의미를 지니고 있어요. 스스로 해석해보세요."
  item = LUCKY_ITEMS.sample
  color = LUCKY_COLORS.sample
  place = LUCKY_PLACES.sample

  result = []
  result << "오늘의 타로카드는 #{card}입니다."
  result << "의미: #{meaning}"
  result << "행운의 아이템: #{item}"
  result << "행운의 색깔: #{color}"
  result << "행운의 장소: #{place}"
  result.join("\n")
end

# 마스토돈 API 초기화
client = Mastodon::REST::Client.new(base_url: ENV['MASTODON_BASE_URL'], bearer_token: ENV['ACCESS_TOKEN'])

# 멘션 확인 후 응답
loop do
  begin
    notifications = client.notifications

    notifications.each do |notification|
      next unless notification.type == 'mention'
      acct = notification.account.acct
      content = notification.status.content.gsub(/<[^>]*>/, '') # HTML 제거
      command = parse_command(content)
      next unless command

      # 등록 여부 확인
      unless registered_student?(students_ws, acct)
        client.create_status("@#{acct} 학생명부에 이름이 없어. 학적이 등록되지 않은 학생은 물건을 살 수 없단다.", in_reply_to_id: notification.status.id, visibility: "direct")
        next
      end

      case command
      when /^d\d+$/i
        if get_setting(settings_ws, "주사위") == "ON"
          result = roll_dice(command)
          client.create_status("@#{acct} 굴린 결과는 #{result}이란다.", in_reply_to_id: notification.status.id, visibility: "direct") if result
        end
      when "타로"
        if get_setting(settings_ws, "타로") == "ON"
          result = tarot_reading
          client.create_status("@#{acct}\n#{result}", in_reply_to_id: notification.status.id, visibility: "direct")
        end
      end

      client.clear_notifications
    end

  rescue => e
    puts "오류 발생: #{e.message}"
    sleep 10
  end

  sleep 15
end