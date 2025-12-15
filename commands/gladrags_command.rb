# commands/gladrags_command.rb
# encoding: UTF-8

class GladragsCommand
  POSITIVE_EVENTS = [
    { text: "완벽한 사이즈의 로브를 발견했어요!", reward: 3 },
    { text: "계절 할인 행사 중이에요! 덤으로 스카프를 받았어요!", reward: 5 },
    { text: "점원이 친절하게 코디를 도와줬어요. 멋져 보여요!", reward: 2 },
    { text: "새로 입고된 드레스 로브가 딱 맞아요!", reward: 4 },
    { text: "명품 장갑을 특가에 구입했어요!", reward: 3 },
    { text: "마법으로 자동 수선되는 옷을 샀어요. 실용적이에요!", reward: 4 },
    { text: "유행하는 디자인의 모자를 발견했어요!", reward: 3 },
    { text: "방한용 망토가 따뜻하고 좋아요!", reward: 3 },
    { text: "은실로 수놓은 로브를 득템했어요!", reward: 6 },
    { text: "사이즈가 딱 맞는 구두를 찾았어요!", reward: 2 },
    { text: "색상이 마음에 쏙 드는 로브예요!", reward: 3 },
    { text: "고급 벨벳 재질의 옷이 기분 좋아요!", reward: 4 },
    { text: "친구들이 옷발 좋다고 칭찬했어요!", reward: 2 },
    { text: "1+1 행사로 스카프를 하나 더 받았어요!", reward: 5 },
    { text: "점원이 추천한 옷이 정말 잘 어울려요!", reward: 3 },
    { text: "마법 방수 기능이 있는 망토예요!", reward: 4 },
    { text: "고급스러운 은색 단추가 달린 로브예요!", reward: 4 },
    { text: "겨울 신상이 먼저 입고되어 득템했어요!", reward: 5 },
    { text: "포인트 적립으로 다음에 할인받을 수 있어요!", reward: 2 },
    { text: "한정판 디자인을 구매했어요. 특별해요!", reward: 7 }
  ]

  NEGATIVE_EVENTS = [
    { text: "사이즈를 잘못 골라서 교환해야 해요... 배송비가...", loss: 2 },
    { text: "입어보다가 단추를 떨어뜨렸어요. 배상해야 해요.", loss: 3 },
    { text: "로브에 커피를 쏟았어요! 세탁비를 내야 해요.", loss: 4 },
    { text: "거울 앞에서 너무 오래 고민하다 문 닫는 시간이 됐어요.", loss: 1 },
    { text: "마음에 드는 옷이 품절이에요. 아쉬워요.", loss: 1 },
    { text: "가격표를 잘못 봤어요. 생각보다 비싸요!", loss: 5 },
    { text: "친구와 같은 옷을 샀어요. 민망해요...", loss: 2 },
    { text: "충동구매한 모자가 집에 가보니 이상해요.", loss: 3 },
    { text: "할인 행사가 내일부터라고 해요. 아까워요!", loss: 2 },
    { text: "새 구두가 발에 안 맞아서 물집이 생겼어요.", loss: 3 },
    { text: "옷을 입다가 실밥이 풀렸어요. 수선비가...", loss: 2 },
    { text: "색깔이 생각과 달라요. 환불 수수료를 물어야 해요.", loss: 3 },
    { text: "더 예쁜 옷을 나중에 발견했어요. 후회돼요.", loss: 2 },
    { text: "망토가 너무 길어서 계단에서 밟고 넘어질 뻔했어요!", loss: 2 },
    { text: "유행 지난 디자인을 샀어요. 친구들이 웃었어요.", loss: 3 },
    { text: "세탁했더니 색이 바랬어요... 실망이에요.", loss: 4 },
    { text: "같은 옷을 더 싸게 파는 곳을 발견했어요. 억울해요!", loss: 3 },
    { text: "장갑 한 짝을 가게에 두고 왔어요. 찾으러 가야 해요.", loss: 1 },
    { text: "사이즈가 애매해서 결국 맞춤 수선을 맡겼어요.", loss: 5 },
    { text: "로브를 입다가 지팡이에 걸려 찢어졌어요!", loss: 6 }
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[GLADRAGS] START user=#{@student_id}"
    
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i

    # 50% 확률로 긍정/부정
    if rand < 0.5
      event = POSITIVE_EVENTS.sample
      amount = event[:reward]
      new_galleons = current_galleons + amount
      
      message = "@#{@student_id} 글래드래그스 마법사 옷가게를 방문했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 글래드래그스 마법사 옷가게를 방문했어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    
    puts "[GLADRAGS] SUCCESS"
    return message
  end
end
