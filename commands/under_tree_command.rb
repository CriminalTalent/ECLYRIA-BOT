# commands/under_tree_command.rb
# encoding: UTF-8

class UnderTreeCommand
  POSITIVE_EVENTS = [
    { text: "트리 아래 선물이 가득해요!", reward: 5 },
    { text: "반짝이는 조명이 아름다워요!", reward: 2 },
    { text: "선물 상자에 제 이름이 적혀있어요!", reward: 4 },
    { text: "트리 향기가 방 안 가득해요!", reward: 2 },
    { text: "장식들이 반짝반짝 빛나요. 예뻐요!", reward: 3 },
    { text: "트리 아래에서 가족 사진을 찍었어요!", reward: 3 },
    { text: "작은 선물을 발견했어요. 누가 놓았을까요?", reward: 4 },
    { text: "트리 불빛이 로맨틱해요!", reward: 2 },
    { text: "트리 아래서 소원을 빌었어요!", reward: 3 },
    { text: "크리스마스 분위기가 물씬 나요!", reward: 3 },
    { text: "오너먼트가 햇빛에 반짝여요!", reward: 2 },
    { text: "트리 별이 반짝이며 빛나요!", reward: 3 },
    { text: "포장된 선물들이 색색이 예뻐요!", reward: 2 },
    { text: "트리 아래서 편안하게 쉬었어요!", reward: 3 },
    { text: "친구들과 트리 앞에서 추억을 만들었어요!", reward: 4 },
    { text: "트리 장식을 만지작거리니 재밌어요!", reward: 2 },
    { text: "크리스마스 음악을 들으며 행복해요!", reward: 3 },
    { text: "트리 밑에서 숨은 선물을 찾았어요!", reward: 5 },
    { text: "트리가 완벽하게 장식되어 있어요!", reward: 4 },
    { text: "가장 행복한 크리스마스예요!", reward: 6 }
  ]

  NEGATIVE_EVENTS = [
    { text: "트리가 넘어질 뻔했어요!", loss: 3 },
    { text: "장식을 건드려서 떨어뜨렸어요. 깨졌어요!", loss: 5 },
    { text: "트리 전구가 고장나서 교체해야 해요.", loss: 4 },
    { text: "발에 장식이 걸려서 넘어졌어요!", loss: 3 },
    { text: "트리 가지에 옷이 걸려서 찢어졌어요.", loss: 3 },
    { text: "반려동물이 트리를 쓰러뜨렸어요!", loss: 6 },
    { text: "트리 물을 엎질렀어요. 바닥이 다 젖었어요!", loss: 4 },
    { text: "장식이 너무 많아서 트리가 기울었어요.", loss: 2 },
    { text: "전구선이 엉켜서 풀다가 끊어졌어요!", loss: 5 },
    { text: "트리에서 솔잎이 너무 많이 떨어져요.", loss: 2 },
    { text: "트리 아래 선물이 없어요. 슬퍼요.", loss: 1 },
    { text: "장식 하나가 발에 밟혀서 깨졌어요!", loss: 4 },
    { text: "고양이가 트리를 타고 올라가요. 위험해요!", loss: 3 },
    { text: "트리 별이 떨어져서 부러졌어요.", loss: 4 },
    { text: "전선에 걸려 넘어질 뻔했어요!", loss: 2 },
    { text: "트리 밑에 물이 새서 바닥이 상했어요.", loss: 5 },
    { text: "장식을 정리하다가 손을 베었어요!", loss: 3 },
    { text: "트리가 말라서 솔잎이 우수수 떨어져요.", loss: 3 },
    { text: "전구가 합선되어서 교체 비용이...", loss: 6 },
    { text: "트리를 옮기다가 허리를 삐끗했어요!", loss: 4 }
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[UNDER_TREE] START user=#{@student_id}"
    
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i

    if rand < 0.5
      event = POSITIVE_EVENTS.sample
      amount = event[:reward]
      new_galleons = current_galleons + amount
      
      message = "@#{@student_id} 트리 아래를 확인했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 트리 아래를 확인했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    
    puts "[UNDER_TREE] SUCCESS"
    return message
  end
end
