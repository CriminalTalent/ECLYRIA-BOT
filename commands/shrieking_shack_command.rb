# commands/shrieking_shack_command.rb
# encoding: UTF-8

class ShriekingShackCommand
  POSITIVE_EVENTS = [
    { text: "용감하게 안을 들여다봤어요! 친구들이 박수쳤어요!", reward: 5 },
    { text: "담력 시험을 통과했어요! 자랑스러워요!", reward: 4 },
    { text: "오두막 근처에서 오래된 동전을 발견했어요!", reward: 6 },
    { text: "귀신은 없었어요. 안심이에요!", reward: 2 },
    { text: "친구들과 함께여서 무섭지 않았어요!", reward: 3 },
    { text: "으스스한 분위기가 짜릿했어요!", reward: 3 },
    { text: "오두막 주변에서 희귀한 약초를 찾았어요!", reward: 5 },
    { text: "괴담의 진실을 알게 됐어요. 흥미로워요!", reward: 4 },
    { text: "밤에 왔는데 생각보다 덜 무서웠어요!", reward: 3 },
    { text: "사진을 찍어서 인증샷을 남겼어요!", reward: 2 },
    { text: "용기를 내서 문 앞까지 갔어요!", reward: 4 },
    { text: "달빛 아래 오두막이 신비로워 보였어요!", reward: 3 },
    { text: "친구가 겁을 먹었지만 제가 위로했어요!", reward: 3 },
    { text: "근처에서 반짝이는 무언가를 주웠어요!", reward: 5 },
    { text: "오두막 괴담으로 재밌는 이야기를 만들었어요!", reward: 2 },
    { text: "무서운 척하다가 오히려 재밌었어요!", reward: 3 },
    { text: "오두막 역사를 배워서 지식이 늘었어요!", reward: 3 },
    { text: "친구들과 떠들썩하게 즐거운 시간을 보냈어요!", reward: 4 },
    { text: "무서운 소리는 바람 소리였어요. 웃겼어요!", reward: 2 },
    { text: "전설적인 장소에 왔다는 게 뿌듯해요!", reward: 4 }
  ]

  NEGATIVE_EVENTS = [
    { text: "너무 무서워서 비명을 질렀어요!", loss: 2 },
    { text: "도망치다가 넘어져서 다쳤어요. 치료비가...", loss: 4 },
    { text: "친구를 놀라게 하려다 오히려 제가 놀랐어요!", loss: 2 },
    { text: "괴담에 겁을 먹어서 밤새 못 잤어요...", loss: 3 },
    { text: "오두막 근처에서 소지품을 잃어버렸어요!", loss: 5 },
    { text: "으스스한 분위기에 압도당해 도망쳤어요.", loss: 2 },
    { text: "친구들이 저를 두고 먼저 도망갔어요. 배신감!", loss: 2 },
    { text: "바닥이 울퉁불퉁해서 발목을 삐었어요!", loss: 4 },
    { text: "어두워서 길을 잃었어요. 택시 타야 해요.", loss: 5 },
    { text: "무서워서 심장이 두근거려요. 진정제 필요해요.", loss: 3 },
    { text: "괜히 왔어요. 무서워만 하고 별거 없어요.", loss: 1 },
    { text: "옷이 나무에 걸려 찢어졌어요!", loss: 3 },
    { text: "진흙에 빠져서 신발이 더러워졌어요.", loss: 2 },
    { text: "친구 도시락을 떨어뜨려서 배상해야 해요.", loss: 4 },
    { text: "나뭇가지에 얼굴을 긁혔어요. 아파요!", loss: 3 },
    { text: "귀신이 나올까봐 너무 무서웠어요!", loss: 2 },
    { text: "소문만 듣고 왔는데 실망이에요. 시간 낭비!", loss: 2 },
    { text: "지팡이를 떨어뜨렸는데 찾을 수가 없어요!", loss: 6 },
    { text: "밤 늦게까지 있다가 야단맞았어요.", loss: 3 },
    { text: "무서운 소리에 놀라 소리질러서 목이 아파요.", loss: 2 }
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
      
      message = "@#{@student_id} 악쓰는 오두막을 방문했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 악쓰는 오두막을 방문했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    return message
  end
end
