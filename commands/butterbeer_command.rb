# commands/butterbeer_command.rb
# encoding: UTF-8

class ButterbeerCommand
  POSITIVE_EVENTS = [
    { text: "따뜻한 버터맥주가 몸을 녹여줬어요. 기분이 좋아졌어요!", reward: 3 },
    { text: "달콤한 향이 입안 가득 퍼졌어요. 행복해요!", reward: 2 },
    { text: "거품이 콧수염처럼 남았어요. 친구들이 웃었어요!", reward: 2 },
    { text: "버터맥주를 마시니 추위가 싹 가셨어요!", reward: 3 },
    { text: "오늘의 버터맥주는 유난히 달콤하네요.", reward: 2 },
    { text: "마담 로스메르타가 특별히 많이 따라줬어요!", reward: 4 },
    { text: "따뜻한 버터맥주 한 잔에 모든 피로가 풀렸어요.", reward: 3 },
    { text: "친구들과 건배하니 더 맛있는 것 같아요!", reward: 3 },
    { text: "버터맥주 특유의 달콤한 여운이 오래 남았어요.", reward: 2 },
    { text: "창가 자리에서 눈 내리는 풍경을 보며 마셨어요!", reward: 3 },
    { text: "오늘만 특별 할인이에요! 한 잔 더 마셨어요!", reward: 4 },
    { text: "로스메르타 부인이 레시피 비법을 살짝 알려줬어요!", reward: 3 },
    { text: "버터맥주를 마시니 기분이 몽글몽글해요!", reward: 2 },
    { text: "딱 적당한 온도였어요. 완벽해요!", reward: 2 },
    { text: "친구가 한 잔 쏘겠다고 해요! 럭키!", reward: 5 },
    { text: "단골 손님 서비스로 쿠키를 받았어요!", reward: 3 },
    { text: "삼선술집 분위기가 정말 좋아요!", reward: 2 },
    { text: "버터맥주 거품이 완벽한 크림 같아요!", reward: 2 },
    { text: "마시다가 유명한 마법사를 봤어요! 사인받았어요!", reward: 4 },
    { text: "버터맥주 맛 콘테스트에서 1등을 했어요!", reward: 6 }
  ]

  NEGATIVE_EVENTS = [
    { text: "버터맥주를 쏟아서 옷이 끈적해졌어요!", loss: 3 },
    { text: "너무 뜨거워서 혀를 데었어요!", loss: 2 },
    { text: "거품이 코에 들어가서 재채기가 멈추지 않아요!", loss: 2 },
    { text: "과음해서 배가 아파요. 소화제를 사야 해요.", loss: 3 },
    { text: "친구 것까지 계산하게 됐어요. 어쩌다 보니...", loss: 5 },
    { text: "마시다가 체해서 기분이 안 좋아요.", loss: 2 },
    { text: "가격이 생각보다 비싸요! 지갑이...", loss: 4 },
    { text: "달콤해서 계속 마셨더니 이가 아파요!", loss: 3 },
    { text: "버터맥주가 미지근해요. 실망이에요.", loss: 2 },
    { text: "옆 테이블 손님이 제 버터맥주를 엎질렀어요!", loss: 3 },
    { text: "주문을 잘못해서 안 맞는 메뉴가 나왔어요.", loss: 2 },
    { text: "너무 붐벼서 자리가 없어요. 서서 마셨어요.", loss: 1 },
    { text: "머그잔을 깨뜨려서 배상해야 해요!", loss: 5 },
    { text: "계산할 때 지갑을 안 가져온 걸 깨달았어요!", loss: 4 },
    { text: "버터맥주 맛이 평소보다 이상해요.", loss: 2 },
    { text: "친구가 저한테 버터맥주를 쏘라고 졸라요...", loss: 4 },
    { text: "너무 달아서 속이 거북해요.", loss: 2 },
    { text: "마시다가 옷에 흘렸어요. 세탁비가...", loss: 3 },
    { text: "주문한 게 너무 늦게 나와서 식었어요!", loss: 2 },
    { text: "버터맥주를 마시고 두드러기가 났어요. 알레르기!", loss: 4 }
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[BUTTERBEER] START user=#{@student_id}"
    
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i

    if rand < 0.5
      event = POSITIVE_EVENTS.sample
      amount = event[:reward]
      new_galleons = current_galleons + amount
      
      message = "@#{@student_id} 삼선술집에서 버터맥주를 마셨어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 삼선술집에서 버터맥주를 마셨어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    
    puts "[BUTTERBEER] SUCCESS"
    return message
  end
end
