# commands/gift_box_command.rb
# encoding: UTF-8

class GiftBoxCommand
  POSITIVE_EVENTS = [
    { text: "완벽하게 포장된 마법 선물이에요!", reward: 5 },
    { text: "상자 안에 작은 상자가 또 있어요! 마법 트릭!", reward: 4 },
    { text: "금색 리본이 저절로 반짝반짝 빛나요!", reward: 3 },
    { text: "원하던 마법 아이템이 들어있어요!", reward: 6 },
    { text: "움직이는 포장지가 너무 예뻐요!", reward: 2 },
    { text: "상자를 흔들어보니 요정 소리가 나요!", reward: 2 },
    { text: "무거운 상자예요. 기대돼요!", reward: 4 },
    { text: "암브로시우스의 향기가 나요!", reward: 3 },
    { text: "상자 안에 쪽지와 함께 갈레온이 들어있어요!", reward: 7 },
    { text: "포장을 뜯는 순간 페어리 가루가 튀어나와요!", reward: 2 },
    { text: "저절로 풀리는 마법 리본이에요!", reward: 2 },
    { text: "깜짝 선물이 여러 개 들어있어요!", reward: 5 },
    { text: "집요정표 쿠키 상자예요. 맛있겠어요!", reward: 3 },
    { text: "호그스미드 한정판 상품이 들어있어요!", reward: 6 },
    { text: "기숙사 친구가 보낸 선물이에요. 감동!", reward: 4 },
    { text: "상자 안에서 마법 풍선이 튀어나왔어요!", reward: 2 },
    { text: "페어리 가루가 날려요. 예뻐요!", reward: 2 },
    { text: "음악 상자 주문이 걸린 선물이에요!", reward: 4 },
    { text: "확장 주문이 걸린 포켓에 보너스가 있어요!", reward: 5 },
    { text: "대박! 거인이 보낸 초대형 선물이에요!", reward: 8 }
  ]

  NEGATIVE_EVENTS = [
    { text: "빈 상자예요... 소멸 주문이었나봐요.", loss: 2 },
    { text: "포장을 뜯다가 가시 주문에 손을 베었어요!", loss: 3 },
    { text: "상자에 잠금 주문이 걸려서 못 열었어요!", loss: 2 },
    { text: "떨어뜨려서 안의 물건이 깨졌어요...", loss: 5 },
    { text: "마법 리본이 꽁꽁 묶여서 포기했어요.", loss: 2 },
    { text: "상자 안에 또 상자... 무한 확장 주문이에요!", loss: 1 },
    { text: "포장지가 끈끈이 주문이라 짜증나요!", loss: 2 },
    { text: "상자에 물 주문이 걸려서 망가졌어요.", loss: 4 },
    { text: "받고 싶지 않은 물건이에요... 용 똥?", loss: 3 },
    { text: "누군가 이미 뜯어본 흔적이 있어요!", loss: 4 },
    { text: "상자 안에서 폭스럭 냄새가 나요!", loss: 2 },
    { text: "잠금 주문이 너무 강력해서 못 열었어요.", loss: 2 },
    { text: "상자를 열었더니 비명 소리가 났어요!", loss: 3 },
    { text: "배송 중 피브즈가 망가뜨렸어요!", loss: 5 },
    { text: "주소가 잘못 써져서 다른 사람 거였어요!", loss: 6 },
    { text: "유통기한 지난 마법 물약이 들어있어요.", loss: 4 },
    { text: "상자에 폭스럭이 들어있어요! 으악!", loss: 3 },
    { text: "가짜 선물 상자였어요. 쌍둥이 형제 장난감!", loss: 4 },
    { text: "너무 기대했는데 별거 없어요. 실망!", loss: 2 },
    { text: "상자가 터지면서 마법 연기가 퍼졌어요!", loss: 5 }
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
