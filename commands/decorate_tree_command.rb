# commands/decorate_tree_command.rb
# encoding: UTF-8

class DecorateTreeCommand
  POSITIVE_EVENTS = [
    { text: "루모스 주문으로 완벽하게 장식했어요!", reward: 5 },
    { text: "기숙사 색깔로 통일해서 예뻐요!", reward: 4 },
    { text: "마법 장식들이 반짝반짝해요!", reward: 3 },
    { text: "트리 별을 꼭대기에 레비오사로 띄웠어요. 완성!", reward: 4 },
    { text: "기숙사 친구들이 예쁘다고 칭찬했어요!", reward: 3 },
    { text: "페어리 가루가 반짝반짝해요!", reward: 2 },
    { text: "오너먼트를 균형있게 배치했어요!", reward: 3 },
    { text: "에버라스팅 촛불이 따뜻해 보여요!", reward: 3 },
    { text: "금색 리본을 예쁘게 감았어요!", reward: 2 },
    { text: "장식 솜씨를 칭찬받았어요!", reward: 4 },
    { text: "호그와트 테마로 통일감있게 꾸몄어요!", reward: 5 },
    { text: "손수 만든 마법 장식을 달아서 특별해요!", reward: 4 },
    { text: "기숙사 친구들이 함께 도와줘서 재밌었어요!", reward: 3 },
    { text: "트리 콘테스트에서 점수를 받았어요!", reward: 6 },
    { text: "앤티크 마법 장식으로 고급스럽게 꾸몄어요!", reward: 5 },
    { text: "촛불 배치가 완벽해요!", reward: 3 },
    { text: "솔방울로 자연스럽게 장식했어요!", reward: 3 },
    { text: "금색과 은색 조합이 우아해요!", reward: 4 },
    { text: "마법 생물 인형들을 달아서 귀엽게 꾸몄어요!", reward: 3 },
    { text: "호그와트 최고의 크리스마스 트리예요!", reward: 7 }
  ]

  NEGATIVE_EVENTS = [
    { text: "장식을 달다가 떨어뜨려서 깨졌어요!", loss: 5 },
    { text: "마법 조명선이 엉켜서 정리하는 데 시간이 걸렸어요.", loss: 2 },
    { text: "장식이 너무 많아서 트리가 기울었어요!", loss: 4 },
    { text: "기숙사 색깔이 섞여서 이상해요. 실패!", loss: 2 },
    { text: "빗자루에서 떨어질 뻔했어요!", loss: 3 },
    { text: "촛불 하나가 나가서 전체가 꺼졌어요!", loss: 4 },
    { text: "다이애건 앨리에서 장식을 너무 많이 샀어요!", loss: 6 },
    { text: "트리 별을 달다가 손을 다쳤어요.", loss: 3 },
    { text: "크럽이 장식을 다 떨어뜨렸어요!", loss: 5 },
    { text: "장식 배치가 불균형해 보여요.", loss: 2 },
    { text: "가지가 부러져서 장식을 다시 해야 해요!", loss: 4 },
    { text: "가시에 찔려서 피가 났어요!", loss: 3 },
    { text: "장식이 부족해서 호그스미드에 다시 가야 해요.", loss: 3 },
    { text: "높은 곳에서 레비오사 실수로 어지러웠어요!", loss: 2 },
    { text: "리본이 삐뚤삐뚤 걸렸어요. 다시 해야 해요.", loss: 2 },
    { text: "트리를 너무 화려하게 꾸며서 촌스러워요.", loss: 3 },
    { text: "장식 중에 멀티주스 약 묻은 게 섞여있었어요!", loss: 4 },
    { text: "마법 배터리가 부족해서 추가로 사야 해요.", loss: 3 },
    { text: "장식하다가 트리가 넘어졌어요!", loss: 6 },
    { text: "밤새워 꾸미느라 너무 지쳤어요.", loss: 2 }
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[DECORATE_TREE] START user=#{@student_id}"
    
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i

    if rand < 0.5
      event = POSITIVE_EVENTS.sample
      amount = event[:reward]
      new_galleons = current_galleons + amount
      
      message = "@#{@student_id} 크리스마스 트리를 꾸몄어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "+#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    else
      event = NEGATIVE_EVENTS.sample
      amount = event[:loss]
      new_galleons = current_galleons - amount
      
      message = "@#{@student_id} 크리스마스 트리를 꾸몄어요!\n\n"
      message += "#{event[:text]}\n\n"
      message += "-#{amount}G\n"
      message += "현재 잔액: #{new_galleons}G"
    end

    @sheet_manager.update_user(@student_id, { galleons: new_galleons })
    
    puts "[DECORATE_TREE] SUCCESS"
    return message
  end
end
