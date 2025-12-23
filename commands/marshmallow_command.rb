# commands/marshmallow_command.rb
# encoding: UTF-8

class MarshmallowCommand
  POSITIVE_EVENTS = [
    { text: "완벽하게 노릇노릇 구워졌어요!", reward: 4 },
    { text: "겉은 바삭, 속은 쫀득해요. 최고!", reward: 5 },
    { text: "마시멜로우가 황금빛으로 빛나요!", reward: 3 },
    { text: "친구들이 맛있다고 칭찬했어요!", reward: 3 },
    { text: "초콜릿과 함께 먹으니 환상이에요!", reward: 4 },
    { text: "한 입 베어물자 달콤함이 퍼져요!", reward: 2 },
    { text: "크래커에 끼워먹으니 더 맛있어요!", reward: 3 },
    { text: "마시멜로우 굽기 대회에서 1등했어요!", reward: 6 },
    { text: "불에 살짝 그을린 향이 좋아요!", reward: 2 },
    { text: "여러 개 한꺼번에 구웠어요. 대박!", reward: 5 },
    { text: "친구들과 나눠먹으니 더 맛있어요!", reward: 3 },
    { text: "적당한 온도로 천천히 구웠어요!", reward: 4 },
    { text: "달콤한 향이 주변에 퍼져요!", reward: 2 },
    { text: "막대기에 예쁘게 꽂혀서 먹기 좋아요!", reward: 2 },
    { text: "겨울밤에 먹는 마시멜로우는 최고예요!", reward: 3 },
    { text: "마시멜로우가 빵빵하게 부풀었어요!", reward: 2 },
    { text: "구운 마시멜로우로 핫초코를 만들었어요!", reward: 4 },
    { text: "따뜻한 마시멜로우가 입 안에서 녹아요!", reward: 3 },
    { text: "비법을 터득했어요. 마시멜로우 마스터!", reward: 5 },
    { text: "완벽한 타이밍에 빼냈어요. 프로예요!", reward: 6 }
  ]

  NEGATIVE_EVENTS = [
    { text: "마시멜로우가 새까맣게 타버렸어요!", loss: 3 },
    { text: "불에 떨어뜨렸어요. 아까워요!", loss: 4 },
    { text: "녹은 마시멜로우가 손에 묻었어요. 끈적!", loss: 2 },
    { text: "막대기가 부러져서 못 구웠어요.", loss: 2 },
    { text: "너무 가까이 대서 순식간에 탔어요!", loss: 3 },
    { text: "바람이 불어서 불이 꺼졌어요.", loss: 2 },
    { text: "마시멜로우를 너무 많이 먹어서 배탈났어요.", loss: 4 },
    { text: "옷에 마시멜로우가 묻어서 세탁해야 해요.", loss: 3 },
    { text: "친구가 제껴서 불에 떨어뜨렸어요!", loss: 3 },
    { text: "마시멜로우가 너무 딱딱해서 못 먹겠어요.", loss: 2 },
    { text: "불조절을 못해서 다 태웠어요.", loss: 4 },
    { text: "마시멜로우를 너무 오래 구워서 막대기에 눌러붙었어요!", loss: 2 },
    { text: "연기를 너무 많이 마셔서 기침이 나요!", loss: 2 },
    { text: "마시멜로우가 불꽃처럼 타올랐어요. 놀랐어요!", loss: 3 },
    { text: "덜 익어서 맛이 이상해요.", loss: 2 },
    { text: "마시멜로우가 녹아서 바닥에 떨어졌어요!", loss: 3 },
    { text: "막대기에 가시가 박혀서 손을 다쳤어요.", loss: 4 },
    { text: "너무 뜨거워서 입천장을 데었어요!", loss: 3 },
    { text: "마시멜로우가 폭발했어요! 왜지?", loss: 5 },
    { text: "다 구웠는데 누가 가져갔어요!", loss: 4 }
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[MARSHMALLOW] START user=#{@student_id}"
    
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i

    if rand < 0.5
      event = POSITIVE_EVENTS.sample
      amount = event[:reward]
      new_galleons = current_galleons + amount
      
      message = "@#{@student_id} 마시멜로우를 구웠어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 마시멜로우를 구웠어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    
    puts "[MARSHMALLOW] SUCCESS"
    return message
  end
end
