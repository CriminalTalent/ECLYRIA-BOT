# commands/snowman_command.rb
# encoding: UTF-8

class SnowmanCommand
  POSITIVE_EVENTS = [
    { text: "완벽한 눈사람을 만들었어요! 모두가 감탄했어요!", reward: 5 },
    { text: "눈사람이 정말 귀엽게 완성됐어요!", reward: 3 },
    { text: "적당한 크기의 눈사람이에요. 괜찮은데요?", reward: 2 },
    { text: "눈사람에 장식을 예쁘게 달았어요!", reward: 3 },
    { text: "친구들과 함께 만들어서 재밌었어요!", reward: 3 },
    { text: "눈사람 콘테스트에서 상을 탔어요!", reward: 6 },
    { text: "눈 뭉치기가 수월했어요. 눈 질이 좋아요!", reward: 2 },
    { text: "눈사람에 모자를 씌웠더니 멋져요!", reward: 2 },
    { text: "당근 코가 딱 맞게 들어갔어요!", reward: 2 },
    { text: "눈사람이 생각보다 크게 만들어졌어요!", reward: 4 },
    { text: "눈사람 만들기 재능이 있는 것 같아요!", reward: 3 },
    { text: "사진 찍기 딱 좋은 눈사람이에요!", reward: 2 },
    { text: "마법으로 눈사람을 움직이게 만들었어요!", reward: 5 },
    { text: "눈사람 가족을 만들었어요. 사랑스러워요!", reward: 4 },
    { text: "길가는 사람들이 칭찬했어요!", reward: 3 },
    { text: "눈사람이 균형 잡혀서 안정적이에요!", reward: 2 },
    { text: "돌멩이 눈알이 생생해 보여요!", reward: 2 },
    { text: "빗자루 팔을 만들었더니 진짜 같아요!", reward: 3 },
    { text: "나뭇가지로 웃는 입을 만들었어요. 귀여워요!", reward: 2 },
    { text: "눈사람 만들기 신기록을 세웠어요!", reward: 7 }
  ]

  NEGATIVE_EVENTS = [
    { text: "눈사람이 무너졌어요... 다시 만들어야 해요.", loss: 2 },
    { text: "너무 추워서 손이 꽁꽁 얼었어요!", loss: 3 },
    { text: "눈사람을 만들다가 넘어졌어요. 옷이 다 젖었어요!", loss: 3 },
    { text: "눈사람이 삐뚤빼뚤해요. 실패!", loss: 2 },
    { text: "장갑을 잃어버렸어요. 새로 사야 해요.", loss: 4 },
    { text: "눈이 너무 질어서 만들기 힘들어요.", loss: 2 },
    { text: "눈사람이 너무 작아요. 아쉬워요.", loss: 1 },
    { text: "누군가 제 눈사람을 무너뜨렸어요!", loss: 3 },
    { text: "손이 시려서 중간에 포기했어요.", loss: 2 },
    { text: "눈 뭉치다가 손가락을 다쳤어요!", loss: 3 },
    { text: "눈사람 머리가 자꾸 떨어져요. 짜증나요!", loss: 2 },
    { text: "옷에 눈이 잔뜩 묻어서 세탁해야 해요.", loss: 3 },
    { text: "코로 쓸 당근을 잃어버렸어요!", loss: 1 },
    { text: "눈사람이 햇빛에 빨리 녹았어요. 허무해요.", loss: 2 },
    { text: "눈싸움하다가 눈사람이 망가졌어요!", loss: 2 },
    { text: "장식품을 떨어뜨려서 깨졌어요.", loss: 4 },
    { text: "눈사람이 무서워 보여요. 실패작이에요.", loss: 2 },
    { text: "친구 눈사람이 더 멋있어요. 질투나요!", loss: 1 },
    { text: "눈사람 만들다 감기에 걸렸어요. 약값이...", loss: 5 },
    { text: "눈이 부족해서 작은 눈사람밖에 못 만들었어요.", loss: 2 }
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[SNOWMAN] START user=#{@student_id}"
    
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i

    if rand < 0.5
      event = POSITIVE_EVENTS.sample
      amount = event[:reward]
      new_galleons = current_galleons + amount
      
      message = "@#{@student_id} 호그스미드에서 눈사람을 굴렸어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 호그스미드에서 눈사람을 굴렸어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    
    puts "[SNOWMAN] SUCCESS"
    return message
  end
end
