# commands/honeydukes_command.rb
# encoding: UTF-8

class HoneyDukesCommand
  POSITIVE_EVENTS = [
    { text: "온갖 맛이 나는 젤리를 득템했어요!", reward: 3 },
    { text: "초콜릿 개구리에서 레어 카드가 나왔어요!", reward: 5 },
    { text: "시식 코너에서 마음껏 맛봤어요!", reward: 2 },
    { text: "신상 사탕이 정말 맛있어요!", reward: 3 },
    { text: "구매 금액에 따라 사탕을 덤으로 받았어요!", reward: 4 },
    { text: "친구들에게 나눠줄 사탕을 샀어요. 인기 최고!", reward: 3 },
    { text: "페퍼 임프가 입안에서 톡톡 터져요!", reward: 2 },
    { text: "산 케틀 사탕이 신기해요! 입에서 김이 나요!", reward: 3 },
    { text: "피즈 위즈비가 공중에 떠오르게 해줘요!", reward: 3 },
    { text: "버터 너겟이 부드럽고 달콤해요!", reward: 2 },
    { text: "젤리 민달팽이가 꿈틀거려요. 재밌어요!", reward: 2 },
    { text: "드로블 최상급 블로잉검으로 풍선을 크게 만들었어요!", reward: 3 },
    { text: "코코아 열매로 만든 초콜릿이 진하고 맛있어요!", reward: 4 },
    { text: "이쑤시개 민트가 상쾌해요!", reward: 2 },
    { text: "포장이 예뻐서 선물용으로 딱이에요!", reward: 3 },
    { text: "한정판 사탕이 아직 남아있어요! 득템!", reward: 5 },
    { text: "단골 할인 쿠폰을 받았어요!", reward: 3 },
    { text: "사탕 조합 추천을 받아서 완벽한 선택을 했어요!", reward: 3 },
    { text: "허니듀크스 특제 초콜릿 세트를 샀어요!", reward: 6 },
    { text: "럭키 드로우에 당첨돼서 사탕을 공짜로 받았어요!", reward: 7 }
  ]

  NEGATIVE_EVENTS = [
    { text: "토하는 맛이 나는 젤리를 먹었어요... 으악!", loss: 2 },
    { text: "코피가 날 정도로 매운 사탕이었어요!", loss: 3 },
    { text: "너무 많이 사서 주머니가 텅 비었어요.", loss: 5 },
    { text: "사탕을 입에 너무 많이 넣어서 목이 막힐 뻔했어요!", loss: 2 },
    { text: "초콜릿이 녹아서 주머니가 더러워졌어요. 세탁비가...", loss: 3 },
    { text: "개구리 초콜릿이 뛰어나가 버렸어요!", loss: 2 },
    { text: "친구 것까지 사주게 됐어요. 지갑이...", loss: 6 },
    { text: "충동구매로 필요 없는 사탕을 너무 많이 샀어요.", loss: 4 },
    { text: "사탕 봉지가 찢어져서 바닥에 다 쏟아졌어요!", loss: 3 },
    { text: "이빨이 너무 아파요! 치과 가야 해요.", loss: 4 },
    { text: "유통기한 지난 사탕을 샀어요. 환불받아야 해요.", loss: 2 },
    { text: "딸기잼 맛인 줄 알았는데 흙 맛이었어요!", loss: 2 },
    { text: "사탕을 너무 먹어서 배탈이 났어요...", loss: 3 },
    { text: "비싼 초콜릿 세트를 떨어뜨려서 깨졌어요.", loss: 6 },
    { text: "껌을 씹다가 머리카락에 붙었어요. 잘라야 해요!", loss: 2 },
    { text: "사탕이 너무 딱딱해서 이가 부러질 뻔했어요!", loss: 3 },
    { text: "계산대에서 카드가 거부됐어요. 민망해요!", loss: 1 },
    { text: "친구가 원하는 사탕이 품절이에요. 미안해요.", loss: 1 },
    { text: "가격표를 잘못 봐서 예산 초과했어요!", loss: 5 },
    { text: "사탕 냄새에 취해 어지러워요. 쉬어야 해요.", loss: 2 }
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i

    if rand < 0.5
      event = POSITIVE_EVENTS.sample
      amount = event[:reward]
      new_galleons = current_galleons + amount
      
      message = "@#{@student_id} 허니듀크스를 방문했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 허니듀크스를 방문했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    return message
  end
end
