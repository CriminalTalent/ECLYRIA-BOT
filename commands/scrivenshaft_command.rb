# commands/scrivenshaft_command.rb
# encoding: UTF-8

class ScrivenshaftCommand
  POSITIVE_EVENTS = [
    { text: "완벽한 깃펜을 발견했어요! 쓰기 편해요!", reward: 3 },
    { text: "자동 맞춤법 교정 잉크를 샀어요!", reward: 4 },
    { text: "양피지 묶음이 세일 중이에요!", reward: 3 },
    { text: "깃펜 손질 키트를 득템했어요!", reward: 2 },
    { text: "은빛 잉크가 반짝반짝 빛나요! 예뻐요!", reward: 3 },
    { text: "점원이 깃펜 사용법을 친절히 알려줬어요!", reward: 2 },
    { text: "고급 양피지 세트를 저렴하게 샀어요!", reward: 4 },
    { text: "특제 사라지는 잉크를 얻었어요!", reward: 5 },
    { text: "깃펜 홀더가 세트로 포함돼 있어요!", reward: 3 },
    { text: "두루마리 케이스가 가죽으로 돼서 고급스러워요!", reward: 4 },
    { text: "빨강 잉크가 정말 선명해요!", reward: 2 },
    { text: "한정판 공작 깃털 펜을 샀어요!", reward: 6 },
    { text: "깃펜 시험 코너에서 마음에 드는 걸 찾았어요!", reward: 3 },
    { text: "단골 할인 쿠폰을 받았어요!", reward: 3 },
    { text: "수입산 깃펜이 품질이 정말 좋아요!", reward: 4 },
    { text: "지우개 잉크가 실수를 깔끔히 지워줘요!", reward: 3 },
    { text: "양피지 재질이 부드러워서 쓰기 좋아요!", reward: 2 },
    { text: "깃털이 정말 풍성하고 예뻐요!", reward: 3 },
    { text: "1+1 행사로 깃펜을 하나 더 받았어요!", reward: 5 },
    { text: "점원 추천 깃펜이 완벽해요!", reward: 4 }
  ]

  NEGATIVE_EVENTS = [
    { text: "잉크를 쏟아서 옷이 더러워졌어요!", loss: 3 },
    { text: "깃펜이 부러졌어요. 다시 사야 해요.", loss: 4 },
    { text: "비싼 깃펜을 충동구매했어요. 후회돼요.", loss: 5 },
    { text: "양피지가 찢어지기 쉬워서 짜증나요.", loss: 2 },
    { text: "잉크가 잘 안 나와서 답답해요!", loss: 2 },
    { text: "깃털이 가렵고 간지러워요!", loss: 1 },
    { text: "잉크병을 떨어뜨려 깨뜨렸어요. 배상비가...", loss: 5 },
    { text: "깃펜이 너무 뻣뻣해서 쓰기 불편해요.", loss: 2 },
    { text: "양피지를 너무 많이 사서 들고 가기 힘들어요.", loss: 3 },
    { text: "잉크가 번져서 쓴 글씨가 망가졌어요.", loss: 2 },
    { text: "사려던 깃펜이 품절이에요. 아쉬워요!", loss: 1 },
    { text: "가격표를 잘못 봐서 예산 초과했어요!", loss: 4 },
    { text: "깃펜 색깔이 생각과 달라요. 실망이에요.", loss: 2 },
    { text: "잉크 냄새가 너무 독해서 어지러워요.", loss: 2 },
    { text: "깃펜을 가방에 넣었다가 잉크가 샜어요!", loss: 4 },
    { text: "깃털 알레르기가 있는 걸 깜빡했어요. 재채기!", loss: 3 },
    { text: "고급 양피지를 샀는데 진짜 차이를 모르겠어요.", loss: 3 },
    { text: "깃펜 끝이 빨리 뭉개져요. 품질이 별로예요.", loss: 3 },
    { text: "친구 것과 헷갈려서 바꿔 가져갔어요!", loss: 2 },
    { text: "세일 기간을 하루 놓쳤어요. 아까워요!", loss: 2 }
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
      
      message = "@#{@student_id} 스크리븐샤프트의 깃펜 가게를 방문했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 스크리븐샤프트의 깃펜 가게를 방문했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    return message
  end
end
