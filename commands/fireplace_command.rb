# commands/fireplace_command.rb
# encoding: UTF-8

class FireplaceCommand
  POSITIVE_EVENTS = [
    { text: "휴게실 난로 앞이 따뜻하고 포근해요!", reward: 3 },
    { text: "타닥타닥 소리를 들으며 쉬었어요.", reward: 2 },
    { text: "따뜻한 담요를 덮고 있으니 천국이에요!", reward: 4 },
    { text: "핫 버터비어를 마시며 불을 보니 행복해요!", reward: 3 },
    { text: "마법사 체스를 두며 여유를 즐겼어요!", reward: 3 },
    { text: "난로 열기에 손이 녹았어요. 기분 좋아요!", reward: 2 },
    { text: "기숙사 친구들과 둘러앉아 이야기를 나눴어요!", reward: 4 },
    { text: "장작이 타는 마법 향이 좋아요!", reward: 2 },
    { text: "크룩생크와 함께 난로 앞에서 낮잠을 잤어요!", reward: 3 },
    { text: "발을 쬐니 시린 발이 따뜻해졌어요!", reward: 2 },
    { text: "마법 라디오로 음악을 들으며 쉬었어요!", reward: 3 },
    { text: "마시멜로우를 구우며 즐거운 시간을 보냈어요!", reward: 4 },
    { text: "따뜻함에 스트레스가 풀렸어요!", reward: 3 },
    { text: "난로 앞에서 부엉이에게 보낼 편지를 썼어요!", reward: 3 },
    { text: "불꽃을 보며 명상을 했어요. 평온해요!", reward: 4 },
    { text: "크리스마스 장식이 불빛에 반짝여요!", reward: 2 },
    { text: "펌킨 주스를 마시며 여유를 즐겼어요!", reward: 3 },
    { text: "난로 불빛이 낭만적이에요!", reward: 2 },
    { text: "기숙사 식구들과 함께 행복한 시간을 보냈어요!", reward: 5 },
    { text: "완벽한 호그와트 겨울밤이에요!", reward: 6 }
  ]

  NEGATIVE_EVENTS = [
    { text: "너무 가까이 앉아서 너무 더워요!", loss: 2 },
    { text: "플루 가루 연기가 역류해서 기침이 나요!", loss: 3 },
    { text: "불꽃이 튀어서 로브에 구멍이 났어요!", loss: 4 },
    { text: "졸다가 담요를 불에 가까이 대서 탔어요!", loss: 5 },
    { text: "장작을 너무 많이 넣어서 열기가 과해요!", loss: 2 },
    { text: "굴뚝 청소를 안 해서 냄새가 나요!", loss: 2 },
    { text: "재가 날려서 로브가 더러워졌어요.", loss: 3 },
    { text: "너무 오래 있어서 얼굴이 빨개졌어요!", loss: 2 },
    { text: "목이 말라서 물을 사러 가야 해요.", loss: 1 },
    { text: "화상을 입을 뻔했어요. 조심해야 해요!", loss: 3 },
    { text: "마법 장작이 떨어져서 다이애건 앨리에서 사야 해요!", loss: 4 },
    { text: "불이 꺼져서 인센디오로 다시 피워야 해요. 귀찮아요!", loss: 2 },
    { text: "너무 더워서 땀을 뻘뻘 흘렸어요!", loss: 2 },
    { text: "소파에 그을음이 묻었어요. 청소 주문이...", loss: 3 },
    { text: "장작 연기 때문에 눈이 따가워요!", loss: 2 },
    { text: "졸다가 불 끄는 걸 깜빡했어요. 위험했어요!", loss: 4 },
    { text: "난로 청소하다가 재를 다 쏟았어요!", loss: 3 },
    { text: "너무 뜨거워서 회복 물약을 사야 해요.", loss: 4 },
    { text: "장작이 터지면서 물건이 망가졌어요!", loss: 5 },
    { text: "굴뚝 청소를 해야 하는데 비용이...", loss: 6 }
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[FIREPLACE] START user=#{@student_id}"
    
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i

    if rand < 0.5
      event = POSITIVE_EVENTS.sample
      amount = event[:reward]
      new_galleons = current_galleons + amount
      
      message = "@#{@student_id} 난로 앞에서 시간을 보냈어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 난로 앞에서 시간을 보냈어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    
    puts "[FIREPLACE] SUCCESS"
    return message
  end
end
