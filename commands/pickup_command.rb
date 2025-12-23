# commands/pickup_command.rb
# encoding: UTF-8

class PickupCommand
  POSITIVE_EVENTS = [
    { text: "양말 속에 버티봇 모든맛 콩이 가득해요!", reward: 3 },
    { text: "초콜릿 개구리를 발견했어요! 카드도 들어있어요!", reward: 4 },
    { text: "작은 마법 주머니가 들어있어요!", reward: 5 },
    { text: "펌킨 파이 한 조각이 들어있어요. 따뜻해요!", reward: 2 },
    { text: "반짝이는 은빛 리본을 찾았어요!", reward: 2 },
    { text: "미니 빗자루 장식이 들어있어요. 귀여워요!", reward: 3 },
    { text: "움직이는 마법 인형을 발견했어요!", reward: 4 },
    { text: "크리스마스 카드와 함께 갈레온이 들어있어요!", reward: 5 },
    { text: "따뜻한 손난로 마법이 걸린 돌이 들어있어요!", reward: 3 },
    { text: "집요정이 만든 쿠키를 넣어줬어요!", reward: 2 },
    { text: "마법 사탕 지팡이를 발견했어요!", reward: 3 },
    { text: "에버라스팅 촛불이 들어있어요!", reward: 2 },
    { text: "작은 금색 스니치 장식이 들어있어요. 딸랑딸랑!", reward: 2 },
    { text: "예쁜 마법 스티커 세트를 받았어요!", reward: 2 },
    { text: "허니듀크스 캐러멜이 가득해요!", reward: 3 },
    { text: "눈사람 키링을 발견했어요!", reward: 2 },
    { text: "호그와트 문장 배지를 받았어요!", reward: 2 },
    { text: "작은 편지와 함께 갈레온이 들어있어요!", reward: 6 },
    { text: "미니 마법사 모자가 들어있어요!", reward: 3 },
    { text: "금화 모양 초콜릿이 가득해요! 대박!", reward: 7 }
  ]

  NEGATIVE_EVENTS = [
    { text: "양말에 구멍이 나서 선물이 떨어졌어요!", loss: 3 },
    { text: "용 똥이 들어있어요... 장난이었나봐요!", loss: 2 },
    { text: "양말이 너무 작아서 선물이 안 들어갔어요.", loss: 1 },
    { text: "니플러가 양말을 물고 달아났어요!", loss: 4 },
    { text: "양말을 잘못 걸어서 떨어뜨렸어요.", loss: 2 },
    { text: "너무 무거워서 양말이 찢어졌어요!", loss: 3 },
    { text: "양말 속 사탕이 다 녹아버렸어요...", loss: 2 },
    { text: "폭스럭이 들어있어요! 으악!", loss: 2 },
    { text: "빈 양말이에요. 실망이에요.", loss: 1 },
    { text: "누군가 먼저 가져갔어요!", loss: 5 },
    { text: "양말이 난로에 너무 가까워서 타버렸어요!", loss: 4 },
    { text: "기숙사 친구가 제 양말을 가져갔어요. 억울해요!", loss: 3 },
    { text: "양말이 뒤집혀서 선물이 다 쏟아졌어요!", loss: 3 },
    { text: "크럽이 양말을 물어뜯었어요...", loss: 4 },
    { text: "양말을 잘못 건 곳에 걸어서 못 찾았어요.", loss: 2 },
    { text: "닉슬리가 양말 속 선물을 먹어버렸어요!", loss: 4 },
    { text: "양말이 너무 낡아서 찢어졌어요.", loss: 2 },
    { text: "쌍둥이 형제가 장난으로 양말을 숨겼어요!", loss: 2 },
    { text: "양말에 눈이 들어와서 다 젖었어요.", loss: 3 },
    { text: "부엉이가 잘못 배달했나봐요...", loss: 1 }
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[PICKUP] START user=#{@student_id}"
    
    player = @sheet_manager.find_user(@student_id)
    unless player
      puts "[PICKUP] ERROR: player not found (@#{@student_id})"
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i
    puts "[PICKUP] 현재 갈레온: #{current_galleons}"

    if rand < 0.5
      event = POSITIVE_EVENTS.sample
      amount = event[:reward]
      new_galleons = current_galleons + amount
      
      message = "@#{@student_id} #{event[:text]}\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} #{event[:text]}\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    puts "[PICKUP] 금액: #{amount > 0 ? '+' : '-'}#{amount.abs}, 새 갈레온: #{new_galleons}"

    @sheet_manager.update_user(@student_id, {
      galleons: new_galleons
    })

    puts "[PICKUP] SUCCESS: #{message[0..50]}..."
    return message
  end
end
