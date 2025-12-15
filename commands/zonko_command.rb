# commands/zonko_command.rb
# encoding: UTF-8

class ZonkoCommand
  POSITIVE_EVENTS = [
    { text: "똥 폭탄을 샀어요! 장난치기 딱이에요!", reward: 3 },
    { text: "신상 장난감을 제일 먼저 구입했어요!", reward: 4 },
    { text: "딸꾹질 사탕이 정말 효과가 좋아요!", reward: 2 },
    { text: "가짜 지팡이로 친구를 놀렸어요. 성공!", reward: 2 },
    { text: "히컵 과자 세트를 샀어요! 재밌겠어요!", reward: 3 },
    { text: "웃음 가루를 득템했어요!", reward: 3 },
    { text: "폭죽 세트가 화려해 보여요!", reward: 4 },
    { text: "점원이 비밀 신상을 미리 보여줬어요!", reward: 5 },
    { text: "재고 정리 세일로 싸게 샀어요!", reward: 4 },
    { text: "물총이 물 대신 거품을 쏘아요! 신기해요!", reward: 3 },
    { text: "악취 풍선을 샀어요. 장난 성공 예감!", reward: 2 },
    { text: "마법 풍선껌이 엄청나게 크게 불어져요!", reward: 3 },
    { text: "색 변하는 먹물을 샀어요. 유용할 듯!", reward: 3 },
    { text: "숙제 자동 작성 깃펜(가짜)을 샀어요!", reward: 2 },
    { text: "친구 몰래 가짜 거미를 놓을 거예요!", reward: 2 },
    { text: "구매 금액에 따라 장난감을 하나 더 받았어요!", reward: 5 },
    { text: "종코가 직접 추천한 아이템이에요!", reward: 4 },
    { text: "한정판 딸꾹질 캔디를 구했어요!", reward: 6 },
    { text: "시식 코너에서 재밌는 효과를 체험했어요!", reward: 2 },
    { text: "신상 장난감 테스터로 선정됐어요!", reward: 7 }
  ]

  NEGATIVE_EVENTS = [
    { text: "똥 폭탄이 가방 안에서 터졌어요... 냄새가...", loss: 4 },
    { text: "장난감을 잘못 써서 혼났어요.", loss: 2 },
    { text: "가짜 지팡이가 진짜처럼 보여서 혼동했어요!", loss: 2 },
    { text: "딸꾹질 사탕을 실수로 먹었어요. 하루종일 딸꾹질!", loss: 3 },
    { text: "너무 많이 사서 휴대하기 불편해요.", loss: 3 },
    { text: "폭죽이 실내에서 터져서 난리났어요!", loss: 5 },
    { text: "장난감을 벌써 잃어버렸어요. 아까워요!", loss: 3 },
    { text: "친구에게 장난쳤다가 삐졌어요. 화해 선물 사야 해요.", loss: 4 },
    { text: "가짜 거미가 너무 리얼해서 본인이 놀랐어요!", loss: 2 },
    { text: "웃음 가루를 실수로 흡입했어요. 웃음이 멈추질 않아요!", loss: 3 },
    { text: "악취 풍선이 터져서 주변 사람들이 도망갔어요.", loss: 4 },
    { text: "장난치다가 물건을 깨뜨려서 배상했어요.", loss: 6 },
    { text: "물총에 물 대신 잉크가 들어있어서 옷을 버렸어요.", loss: 5 },
    { text: "가격이 생각보다 비싸서 예산 초과했어요!", loss: 4 },
    { text: "장난감이 고장났어요. 환불 안 돼요!", loss: 3 },
    { text: "교수님한테 걸려서 장난감을 압수당했어요.", loss: 5 },
    { text: "너무 많이 사서 용돈이 다 떨어졌어요.", loss: 6 },
    { text: "폭죽 보관을 잘못해서 다 터졌어요!", loss: 4 },
    { text: "장난감 사용법을 몰라서 망쳤어요.", loss: 2 },
    { text: "친구가 더 좋은 장난감을 샀어요. 질투나요!", loss: 2 }
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
      
      message = "@#{@student_id} 종코의 장난감 가게를 방문했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 종코의 장난감 가게를 방문했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    return message
  end
end
