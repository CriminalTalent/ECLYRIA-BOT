# commands/pickup_command.rb
# encoding: UTF-8

class PickupCommand
  POSITIVE_EVENTS = [
    { text: "길에서 갈레온을 주웠어요!", reward: 3 },
    { text: "반짝이는 동전을 발견했어요!", reward: 2 },
    { text: "누군가 떨어뜨린 지갑을 주웠어요. 주인에게 돌려주니 사례금을 받았어요!", reward: 5 },
    { text: "눈 속에 묻힌 금화를 찾았어요!", reward: 4 },
    { text: "행운의 날이에요! 갈레온을 여러 개 주웠어요!", reward: 5 },
    { text: "골목에서 갈레온 주머니를 발견했어요!", reward: 4 },
    { text: "우체통 아래에 동전이 떨어져 있었어요!", reward: 2 },
    { text: "의자 밑에서 갈레온을 찾았어요!", reward: 2 },
    { text: "친구가 용돈을 나눠줬어요. 고마워요!", reward: 3 },
    { text: "분수대 근처에서 동전을 건졌어요!", reward: 3 },
    { text: "바닥에 떨어진 갈레온이 눈에 띄었어요!", reward: 2 },
    { text: "가게 앞에서 잔돈을 주웠어요!", reward: 2 },
    { text: "공중전화 밑에서 동전을 찾았어요!", reward: 1 },
    { text: "누군가 선물로 갈레온을 줬어요!", reward: 4 },
    { text: "벤치 밑에서 갈레온을 발견했어요!", reward: 2 },
    { text: "눈 치우다가 동전을 발견했어요!", reward: 2 },
    { text: "길거리에서 갈레온이 굴러왔어요!", reward: 3 },
    { text: "주머니를 뒤졌더니 잊고 있던 갈레온이 나왔어요!", reward: 3 },
    { text: "계단에서 갈레온을 주웠어요. 럭키!", reward: 2 },
    { text: "우연히 복권에 당첨됐어요!", reward: 6 }
  ]

  NEGATIVE_EVENTS = [
    { text: "양아치가 갈레온을 빼앗아갔어요!", loss: 3 },
    { text: "소매치기를 당했어요! 갈레온을 잃었어요!", loss: 5 },
    { text: "주머니에 구멍이 나서 갈레온을 떨어뜨렸어요!", loss: 4 },
    { text: "친구에게 갈레온을 빌려줬는데 안 갚아요...", loss: 3 },
    { text: "길에서 넘어져서 갈레온이 하수구로 떨어졌어요!", loss: 4 },
    { text: "사기꾼에게 속아서 갈레온을 잃었어요!", loss: 6 },
    { text: "돈 센다가 바람에 날아갔어요!", loss: 3 },
    { text: "지갑을 잃어버렸어요. 안에 갈레온이...", loss: 5 },
    { text: "주머니를 털렸어요. 조심해야 하는데...", loss: 4 },
    { text: "갈레온을 떨어뜨렸는데 찾을 수가 없어요!", loss: 3 },
    { text: "누군가 부딪혀서 갈레온을 떨어뜨렸어요!", loss: 2 },
    { text: "어두워서 지갑을 놓고 왔어요.", loss: 4 },
    { text: "친구 빚을 갚아야 해요. 어쩔 수 없어요.", loss: 3 },
    { text: "갈레온인 줄 알았는데 가짜 동전이었어요!", loss: 1 },
    { text: "길에서 넘어져서 갈레온이 흩어졌어요!", loss: 2 },
    { text: "주머니가 찢어져서 갈레온을 잃었어요!", loss: 3 },
    { text: "누군가 제 갈레온을 몰래 가져갔어요!", loss: 4 },
    { text: "도박에서 져서 갈레온을 날렸어요...", loss: 5 },
    { text: "잃어버린 줄 알았던 갈레온이 진짜 없어졌어요!", loss: 3 },
    { text: "바람에 모자가 날아가서 쫓다가 갈레온을 떨어뜨렸어요!", loss: 2 }
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[PICKUP] START user=#{@student_id}"
    
    # 플레이어 확인
    player = @sheet_manager.find_user(@student_id)
    unless player
      puts "[PICKUP] ERROR: player not found (@#{@student_id})"
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i
    puts "[PICKUP] 현재 갈레온: #{current_galleons}"

    # 50% 확률로 긍정 또는 부정
    if rand < 0.5
      # 긍정 이벤트
      event = POSITIVE_EVENTS.sample
      amount = event[:reward]
      new_galleons = current_galleons + amount
      
      message = "@#{@student_id} #{event[:text]}\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      # 부정 이벤트
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} #{event[:text]}\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    puts "[PICKUP] 금액: #{amount > 0 ? '+' : '-'}#{amount.abs}, 새 갈레온: #{new_galleons}"

    # 업데이트
    @sheet_manager.update_user(@student_id, {
      galleons: new_galleons
    })

    puts "[PICKUP] SUCCESS: #{message[0..50]}..."
    return message
  end
end
