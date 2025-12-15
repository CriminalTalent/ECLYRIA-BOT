# commands/puddifoot_command.rb
# encoding: UTF-8

class PuddifootCommand
  POSITIVE_EVENTS = [
    { text: "따뜻한 차와 함께 맛있는 케이크를 먹었어요!", reward: 2 },
    { text: "단골 손님 할인을 받았어요!", reward: 3 },
    { text: "오늘의 특별 메뉴가 정말 맛있어요!", reward: 3 },
    { text: "차 한 잔이 서비스예요! 부인이 친절하시네요.", reward: 2 },
    { text: "분위기 좋은 창가 자리를 잡았어요!", reward: 2 },
    { text: "신메뉴 시식 이벤트에 당첨됐어요!", reward: 4 },
    { text: "사탕이 든 홍차가 달콤하고 좋아요!", reward: 2 },
    { text: "친구와 함께 즐거운 티타임을 가졌어요!", reward: 3 },
    { text: "스콘이 갓 구워져서 따뜻해요!", reward: 2 },
    { text: "예쁜 찻잔에 담긴 차가 기분을 좋게 해요!", reward: 2 },
    { text: "레몬 케이크가 입에서 살살 녹아요!", reward: 3 },
    { text: "포장 서비스로 집에 가져갈 수 있어요!", reward: 2 },
    { text: "발렌타인 데이 특별 메뉴가 로맨틱해요!", reward: 4 },
    { text: "부인이 특별히 큰 조각을 주셨어요!", reward: 3 },
    { text: "쿠폰을 사용해서 저렴하게 먹었어요!", reward: 3 },
    { text: "따뜻한 실내가 추운 날씨를 잊게 해줘요!", reward: 2 },
    { text: "친구들과 수다 떨며 즐거운 시간을 보냈어요!", reward: 2 },
    { text: "핑크색 장식이 정말 귀여워요!", reward: 2 },
    { text: "오늘만 2+1 행사예요! 럭키!", reward: 5 },
    { text: "부인이 추천한 블렌딩 차가 환상적이에요!", reward: 4 }
  ]

  NEGATIVE_EVENTS = [
    { text: "차를 쏟았어요! 테이블보를 더럽혔어요.", loss: 3 },
    { text: "케이크가 너무 달아서 체했어요...", loss: 2 },
    { text: "분홍색 천지라 조금 민망해요.", loss: 1 },
    { text: "너무 붐벼서 자리가 없어요. 기다려야 해요.", loss: 1 },
    { text: "메뉴판을 잘못 봐서 비싼 걸 시켰어요!", loss: 5 },
    { text: "연인들만 가득해서 혼자 있기 외로워요.", loss: 2 },
    { text: "차가 너무 뜨거워서 혀를 데었어요!", loss: 2 },
    { text: "찻잔을 떨어뜨려서 깨뜨렸어요. 배상비가...", loss: 6 },
    { text: "과식해서 배가 아파요. 소화제를 사야 해요.", loss: 3 },
    { text: "케이크에 크림이 코에 묻었어요. 창피해요!", loss: 1 },
    { text: "주문을 잘못해서 원하는 메뉴가 안 나왔어요.", loss: 2 },
    { text: "계산할 때 지갑을 안 가져온 걸 깨달았어요!", loss: 4 },
    { text: "옆 테이블 손님과 부딪혀서 차를 쏟았어요.", loss: 3 },
    { text: "예약이 필요한 시간대였어요. 못 들어갔어요.", loss: 1 },
    { text: "달콤한 향에 취해 너무 많이 시켰어요!", loss: 5 },
    { text: "가격이 생각보다 비싸서 놀랐어요!", loss: 4 },
    { text: "친구 것까지 계산하게 됐어요. 어쩌다 보니...", loss: 6 },
    { text: "의자가 불안정해서 비틀거렸어요. 놀랐어요!", loss: 1 },
    { text: "핑크색 분위기에 압도당해 어지러워요.", loss: 2 },
    { text: "디저트를 떨어뜨려서 다시 주문해야 해요.", loss: 4 }
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
      
      message = "@#{@student_id} 푸디풋 부인의 찻집을 방문했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 푸디풋 부인의 찻집을 방문했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    return message
  end
end
