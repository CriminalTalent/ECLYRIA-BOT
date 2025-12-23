# commands/gift_box_command.rb
# encoding: UTF-8

class GiftBoxCommand
  POSITIVE_EVENTS = [
    { text: "완벽하게 포장된 선물이에요!", reward: 5 },
    { text: "상자 안에 작은 상자가 또 있어요! 서프라이즈!", reward: 4 },
    { text: "금색 리본이 반짝반짝 빛나요!", reward: 3 },
    { text: "원하던 선물이 들어있어요!", reward: 6 },
    { text: "포장지가 너무 예뻐서 아까워요!", reward: 2 },
    { text: "상자를 흔들어보니 소리가 좋아요!", reward: 2 },
    { text: "무거운 상자예요. 기대돼요!", reward: 4 },
    { text: "향기가 좋은 선물이에요!", reward: 3 },
    { text: "상자 안에 쪽지와 함께 돈이 들어있어요!", reward: 7 },
    { text: "포장을 뜯는 순간이 제일 설레요!", reward: 2 },
    { text: "리본을 푸는 재미가 있어요!", reward: 2 },
    { text: "깜짝 선물이 여러 개 들어있어요!", reward: 5 },
    { text: "수제 쿠키 상자예요. 맛있겠어요!", reward: 3 },
    { text: "한정판 상품이 들어있어요!", reward: 6 },
    { text: "친구가 보낸 선물이에요. 감동!", reward: 4 },
    { text: "상자 안에 풍선이 튀어나왔어요!", reward: 2 },
    { text: "반짝이 가루가 날려요. 예뻐요!", reward: 2 },
    { text: "음악이 나오는 선물 상자예요!", reward: 4 },
    { text: "숨겨진 포켓에 보너스가 있어요!", reward: 5 },
    { text: "대박! 초대형 선물이에요!", reward: 8 }
  ]

  NEGATIVE_EVENTS = [
    { text: "빈 상자예요... 장난이었나봐요.", loss: 2 },
    { text: "포장을 뜯다가 손을 베었어요!", loss: 3 },
    { text: "상자가 너무 단단해서 못 열었어요!", loss: 2 },
    { text: "떨어뜨려서 안의 물건이 깨졌어요...", loss: 5 },
    { text: "리본이 너무 꽁꽁 묶여서 포기했어요.", loss: 2 },
    { text: "상자 안에 또 상자... 끝없이 나와요!", loss: 1 },
    { text: "포장지가 너무 많아서 짜증나요!", loss: 2 },
    { text: "상자가 물에 젖어서 망가졌어요.", loss: 4 },
    { text: "받고 싶지 않은 선물이에요...", loss: 3 },
    { text: "누군가 먼저 뜯어본 흔적이 있어요!", loss: 4 },
    { text: "상자 안에서 이상한 냄새가 나요!", loss: 2 },
    { text: "포장 테이프가 너무 강력해서 못 뜯었어요.", loss: 2 },
    { text: "상자를 열었더니 깜짝 상자였어요!", loss: 3 },
    { text: "선물이 부서져 있었어요. 배송 사고!", loss: 5 },
    { text: "주소가 잘못 써져서 다른 사람 거였어요!", loss: 6 },
    { text: "유통기한 지난 물건이 들어있어요.", loss: 4 },
    { text: "상자에 벌레가 들어있어요! 으악!", loss: 3 },
    { text: "가짜 선물 상자였어요. 속았어요!", loss: 4 },
    { text: "너무 기대했는데 별거 없어요. 실망!", loss: 2 },
    { text: "상자가 터지면서 내용물이 날아갔어요!", loss: 5 }
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[GIFT_BOX] START user=#{@student_id}"
    
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i

    if rand < 0.5
      event = POSITIVE_EVENTS.sample
      amount = event[:reward]
      new_galleons = current_galleons + amount
      
      message = "@#{@student_id} 선물상자를 열었어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 선물상자를 열었어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    
    puts "[GIFT_BOX] SUCCESS"
    return message
  end
end
