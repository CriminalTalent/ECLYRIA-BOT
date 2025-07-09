require_relative 'mastodon_client'
require 'google_drive'
require 'time'
require 'json'
# require_relative 'features/tarot'
# require_relative 'features/betting'

module CommandParser
  USERS_SHEET = '사용자'
  ITEMS_SHEET = '아이템'

  def self.parse(client, sheet, mention)
    begin
      content = MastodonClient.clean_content(mention.status.content)
      sender = mention.account.acct
      text = content.strip

      puts "[파싱] 처리 중인 멘션: #{text}"
      puts "   발신자: @#{sender}"

      # 구글 시트 워크시트 가져오기
      begin
        ws_users = sheet.worksheet_by_title(USERS_SHEET)
        ws_items = sheet.worksheet_by_title(ITEMS_SHEET)
      rescue => e
        puts "[오류] 워크시트 접근 실패: #{e.message}"
        MastodonClient.reply(mention.status, "어머, 지금 뭔가 문제가 있네~ 잠깐 있다가 다시 와봐!")
        return
      end

      # 사용자 등록 확인
      unless ensure_user_exists(ws_users, sender)
        MastodonClient.reply(mention.status, "어머, 처음 보는 얼굴이네? 교수님께 가서 [입학/#{sender}]로 입학 절차부터 밟고 와~")
        return
      end

      # 명령어 파싱
      case text
      when /\[구매\/(.+?)\]/
        item_name = $1.strip
        handle_purchase(ws_users, ws_items, mention, sender, item_name)

      when /\[양도\/(.+?)\/@(.+?)\]/
        item_name = $1.strip
        receiver = $2.strip
        handle_transfer(ws_users, ws_items, mention, sender, receiver, item_name)

      when /\[양도\/갈레온\/@(.+?)\]/
        receiver = $1.strip
        handle_galleon_transfer(ws_users, mention, sender, receiver)

      when /\[사용\/(.+?)\]/
        item_name = $1.strip
        handle_use(ws_users, ws_items, mention, sender, item_name)

      when /\[주머니\]/
        handle_inventory(ws_users, mention, sender)

      when /\[타로\]/
        handle_tarot(mention, sender)

      when /\[베팅\/(\d+)\]/
        amount = $1.to_i
        handle_betting(ws_users, mention, sender, amount)

      when /\[100D\]/
        handle_dice(mention, sender, 100)

      when /\[20D\]/
        handle_dice(mention, sender, 20)

      when /\[도움말\]/, /\[명령어\]/
        handle_help(mention)

      else
        puts "[무시] 알 수 없는 명령어: #{text}"
        MastodonClient.reply(mention.status, "#{sender}님, 알 수 없는 명령어입니다! [도움말] 쳐보세요!")
      end

    rescue => e
      puts "[오류] 명령어 파싱 중 오류: #{e.message}"
      puts "   스택 트레이스: #{e.backtrace.first(3).join('\n   ')}"
      MastodonClient.reply(mention.status, "어머, 뭔가 잘못됐네? 다시 해보렴~")
    end
  end

  def self.ensure_user_exists(ws_users, sender)
    user_row = find_user_row(ws_users, sender)
    return true if user_row

    # 새 사용자는 교수님께 가서 입학 절차 밟도록 안내
    false
  end

  def self.find_user_row(ws_users, id)
    (1..ws_users.num_rows).each do |row|
      return row if ws_users[row, 1] == id
    end
    nil
  end

  def self.find_item_row(ws_items, name)
    (1..ws_items.num_rows).each do |row|
      if ws_items[row, 1] == name && ws_items[row, 4].to_s.strip.upcase == 'TRUE'
        return row
      end
    end
    nil
  end

  def self.handle_purchase(ws_users, ws_items, mention, sender, item_name)
    puts "[구매] 구매 요청: #{item_name} (#{sender})"
    
    user_row = find_user_row(ws_users, sender)
    item_row = find_item_row(ws_items, item_name)

    unless item_row
      puts "[거절] 존재하지 않는 아이템: #{item_name}"
      MastodonClient.reply(mention.status, "어머, 그런 건 여기 없는데? 다른 거 찾아보렴~")
      return
    end

    unless ws_items[item_row, 4].to_s.strip.upcase == 'TRUE'
      puts "[거절] 판매 불가 아이템: #{item_name}"
      MastodonClient.reply(mention.status, "아이고, 그건 지금 안 팔아~ 다른 거 어때?")
      return
    end

    price = ws_items[item_row, 2].to_i
    user_galleon = ws_users[user_row, 3].to_i

    if user_galleon < price
      puts "[거절] 갈레온 부족: #{user_galleon} < #{price}"
      MastodonClient.reply(mention.status, "얘야, 돈이 모자라네~ 더 모아서 와야겠어!")
      return
    end

    begin
      # 갈레온 차감
      ws_users[user_row, 3] = (user_galleon - price).to_s
      
      # 아이템 추가
      current_items = ws_users[user_row, 4].to_s
      new_items = current_items.empty? ? item_name : "#{current_items},#{item_name}"
      ws_users[user_row, 4] = new_items
      
      ws_users.save
      
      puts "[완료] 구매 성공: #{item_name} (#{price}갈레온)"
      MastodonClient.reply(mention.status, "자, #{item_name} 여기 있어~ 잘 쓰렴!")
    rescue => e
      puts "[오류] 구매 처리 실패: #{e.message}"
      MastodonClient.reply(mention.status, "어머, 뭔가 잘못됐네? 다시 해보렴~")
    end
  end

  def self.handle_transfer(ws_users, ws_items, mention, sender, receiver, item_name)
    puts "[양도] 아이템 양도: #{item_name} (#{sender} -> #{receiver})"
    
    sender_row = find_user_row(ws_users, sender)
    receiver_row = find_user_row(ws_users, receiver)

    unless receiver_row
      puts "[거절] 수신자 없음: #{receiver}"
      MastodonClient.reply(mention.status, "어머, 그 사람 모르겠는데? 먼저 와서 등록해달라고 해~")
      return
    end

    # 아이템 양도 가능성 확인
    item_found = false
    (1..ws_items.num_rows).each do |row|
      if ws_items[row, 1] == item_name
        item_found = true
        if ws_items[row, 5].to_s.strip.upcase != 'TRUE'
          puts "[거절] 양도 불가 아이템: #{item_name}"
          MastodonClient.reply(mention.status, "아이고, 그건 남한테 줄 수 없어~ 규칙이라서 어쩔 수 없네!")
          return
        end
        break
      end
    end

    unless item_found
      puts "[거절] 존재하지 않는 아이템: #{item_name}"
      MastodonClient.reply(mention.status, "그런 건 없는데? 뭔 소리야~")
      return
    end

    # 소지 확인
    sender_items = ws_users[sender_row, 4].to_s.split(',')
    unless sender_items.include?(item_name)
      puts "[거절] 미소지 아이템: #{item_name}"
      MastodonClient.reply(mention.status, "얘야, 그거 너한테 없잖아? 확인해보렴~")
      return
    end

    begin
      # 발신자에서 아이템 제거
      sender_items.delete_at(sender_items.index(item_name))
      ws_users[sender_row, 4] = sender_items.join(',')
      
      # 수신자에게 아이템 추가
      receiver_items = ws_users[receiver_row, 4].to_s
      new_receiver_items = receiver_items.empty? ? item_name : "#{receiver_items},#{item_name}"
      ws_users[receiver_row, 4] = new_receiver_items
      
      ws_users.save
      
      puts "[완료] 양도 성공: #{item_name}"
      MastodonClient.reply(mention.status, "자, #{item_name} #{receiver}한테 전해줬어~ 고마워하더라!")
    rescue => e
      puts "[오류] 양도 처리 실패: #{e.message}"
      MastodonClient.reply(mention.status, "어머, 뭔가 잘못됐네? 다시 해보렴~")
    end
  end

  def self.handle_galleon_transfer(ws_users, mention, sender, receiver)
    puts "[양도] 갈레온 양도: #{sender} -> #{receiver}"
    
    sender_row = find_user_row(ws_users, sender)
    receiver_row = find_user_row(ws_users, receiver)

    unless receiver_row
      puts "[거절] 수신자 없음: #{receiver}"
      MastodonClient.reply(mention.status, "어머, 그 사람 모르겠는데? 먼저 와서 등록해달라고 해~")
      return
    end

    amount = 1
    sender_galleon = ws_users[sender_row, 3].to_i

    if sender_galleon < amount
      puts "[거절] 갈레온 부족: #{sender_galleon} < #{amount}"
      MastodonClient.reply(mention.status, "얘야, 돈이 없잖아~ 어떻게 줘?")
      return
    end

    begin
      # 발신자 갈레온 차감
      ws_users[sender_row, 3] = (sender_galleon - amount).to_s
      
      # 수신자 갈레온 증가
      receiver_galleon = ws_users[receiver_row, 3].to_i
      ws_users[receiver_row, 3] = (receiver_galleon + amount).to_s
      
      ws_users.save
      
      puts "[완료] 갈레온 양도 성공: #{amount}갈레온"
      MastodonClient.reply(mention.status, "자, #{receiver}한테 갈레온 전해줬어~ 고맙다고 하더라!")
    rescue => e
      puts "[오류] 갈레온 양도 실패: #{e.message}"
      MastodonClient.reply(mention.status, "어머, 뭔가 잘못됐네? 다시 해보렴~")
    end
  end

  def self.handle_use(ws_users, ws_items, mention, sender, item_name)
    puts "[사용] 아이템 사용: #{item_name} (#{sender})"
    
    user_row = find_user_row(ws_users, sender)
    
    # 아이템 사용 가능성 확인
    item_row = nil
    (1..ws_items.num_rows).each do |row|
      if ws_items[row, 1] == item_name && ws_items[row, 6].to_s.strip.upcase == 'TRUE'
        item_row = row
        break
      end
    end

    unless item_row
      puts "[거절] 사용 불가 아이템: #{item_name}"
      MastodonClient.reply(mention.status, "그건 못 써~ 장식용이야!")
      return
    end

    # 소지 확인
    user_items = ws_users[user_row, 4].to_s.split(',')
    unless user_items.include?(item_name)
      puts "[거절] 미소지 아이템: #{item_name}"
      MastodonClient.reply(mention.status, "얘야, 그거 너한테 없잖아? 확인해보렴~")
      return
    end

    begin
      effect = ws_items[item_row, 7].to_s
      delete_after_use = ws_items[item_row, 8].to_s.strip.upcase == 'TRUE'

      if delete_after_use
        user_items.delete_at(user_items.index(item_name))
        ws_users[user_row, 4] = user_items.join(',')
      end

      ws_users.save
      
      response_message = effect.empty? ? "자, #{item_name} 잘 썼네~" : effect
      puts "[완료] 아이템 사용 성공: #{item_name}"
      MastodonClient.reply(mention.status, response_message)
    rescue => e
      puts "[오류] 아이템 사용 실패: #{e.message}"
      MastodonClient.reply(mention.status, "어머, 뭔가 잘못됐네? 다시 해보렴~")
    end
  end

  def self.handle_inventory(ws_users, mention, sender)
    puts "[조회] 인벤토리 조회: #{sender}"
    
    user_row = find_user_row(ws_users, sender)
    galleon = ws_users[user_row, 3].to_i
    items = ws_users[user_row, 4].to_s
    
    item_display = items.empty? ? "없음" : items
    
    if galleon < 0
      galleon_display = "빚이 #{galleon.abs}갈레온"
    else
      galleon_display = "#{galleon}갈레온"
    end
    
    puts "[완료] 인벤토리 조회 성공"
    MastodonClient.reply(mention.status, "지금 #{galleon_display} 있고, 물건은 [#{item_display}] 가지고 있네~")
  end

  def self.handle_tarot(mention, sender)
    puts "[타로] 타로 카드 뽑기: #{sender}"
    
    # 78장의 타로 카드 (메이저 아르카나 22장 + 마이너 아르카나 56장)
    major_arcana = [
      { name: "바보", desc: "새로운 시작과 순수한 마음으로 모험을 떠나세요" },
      { name: "마법사", desc: "의지와 집중력으로 원하는 것을 이룰 수 있어요" },
      { name: "여사제", desc: "직감과 내면의 지혜에 귀 기울이세요" },
      { name: "여황제", desc: "풍요와 창조의 에너지가 넘쳐나요" },
      { name: "황제", desc: "안정과 질서, 리더십이 필요한 때예요" },
      { name: "교황", desc: "전통과 가르침을 통해 성장하세요" },
      { name: "연인", desc: "중요한 선택과 사랑의 기운이 있어요" },
      { name: "전차", desc: "강인한 의지로 목표를 향해 나아가세요" },
      { name: "힘", desc: "내면의 힘과 용기가 필요해요" },
      { name: "은자", desc: "자신만의 길을 찾는 시간이에요" },
      { name: "운명의 수레바퀴", desc: "변화와 새로운 기회가 찾아와요" },
      { name: "정의", desc: "균형과 공정함이 중요해요" },
      { name: "매달린 사람", desc: "새로운 관점으로 상황을 바라보세요" },
      { name: "죽음", desc: "끝과 새로운 시작, 변화의 때예요" },
      { name: "절제", desc: "조화와 균형이 필요한 시기예요" },
      { name: "악마", desc: "유혹과 속박에서 벗어나세요" },
      { name: "탑", desc: "급격한 변화와 깨달음이 올 거예요" },
      { name: "별", desc: "희망과 영감이 가득한 시간이에요" },
      { name: "달", desc: "착각과 환상을 조심하세요" },
      { name: "태양", desc: "기쁨과 성공이 기다리고 있어요" },
      { name: "심판", desc: "각성과 새로운 깨달음의 시간이에요" },
      { name: "세계", desc: "완성과 성취, 새로운 시작이 함께해요" }
    ]
    
    minor_arcana = [
      # 완드 (불) 14장
      { name: "완드 에이스", desc: "새로운 열정과 창조적 에너지가 시작돼요" },
      { name: "완드 2", desc: "계획과 미래에 대한 비전이 필요해요" },
      { name: "완드 3", desc: "확장과 성장의 기회가 있어요" },
      { name: "완드 4", desc: "축하와 안정된 기반이 마련돼요" },
      { name: "완드 5", desc: "경쟁과 갈등 상황에 있어요" },
      { name: "완드 6", desc: "승리와 인정을 받게 돼요" },
      { name: "완드 7", desc: "도전에 맞서 방어할 때예요" },
      { name: "완드 8", desc: "빠른 변화와 진전이 있어요" },
      { name: "완드 9", desc: "인내와 지구력이 필요해요" },
      { name: "완드 10", desc: "부담과 책임감이 클 때예요" },
      { name: "완드 잭", desc: "모험과 자유로운 정신이 필요해요" },
      { name: "완드 기사", desc: "행동력과 추진력을 발휘하세요" },
      { name: "완드 퀸", desc: "따뜻한 리더십과 창조력이 빛나요" },
      { name: "완드 킹", desc: "비전과 리더십으로 이끌어가세요" },
      
      # 컵 (물) 14장
      { name: "컵 에이스", desc: "새로운 감정과 사랑이 시작돼요" },
      { name: "컵 2", desc: "조화로운 관계와 파트너십이 중요해요" },
      { name: "컵 3", desc: "친구들과의 즐거운 시간이 있어요" },
      { name: "컵 4", desc: "만족하지 못하고 새로운 기회를 찾아야 해요" },
      { name: "컵 5", desc: "실망과 슬픔이 있지만 희망도 남아있어요" },
      { name: "컵 6", desc: "과거의 추억과 향수가 밀려와요" },
      { name: "컵 7", desc: "많은 선택지 중에서 현실적인 것을 골라야 해요" },
      { name: "컵 8", desc: "현재 상황을 떠나 새로운 길을 찾아야 해요" },
      { name: "컵 9", desc: "만족과 소원 성취의 시간이에요" },
      { name: "컵 10", desc: "가족과 행복한 관계가 이루어져요" },
      { name: "컵 잭", desc: "감성적이고 창의적인 메시지가 와요" },
      { name: "컵 기사", desc: "감정과 직감을 따라 행동하세요" },
      { name: "컵 퀸", desc: "직관과 감정의 지혜가 필요해요" },
      { name: "컵 킹", desc: "감정적 성숙함과 균형이 중요해요" },
      
      # 소드 (공기) 14장
      { name: "소드 에이스", desc: "새로운 아이디어와 명확한 사고가 필요해요" },
      { name: "소드 2", desc: "어려운 결정 앞에서 균형을 잡아야 해요" },
      { name: "소드 3", desc: "마음의 상처와 이별의 아픔이 있어요" },
      { name: "소드 4", desc: "휴식과 회복의 시간이 필요해요" },
      { name: "소드 5", desc: "갈등과 패배감이 있지만 배움도 있어요" },
      { name: "소드 6", desc: "어려운 상황에서 벗어나 안전한 곳으로 가요" },
      { name: "소드 7", desc: "교묘한 전략과 신중함이 필요해요" },
      { name: "소드 8", desc: "제약과 한계 상황에 갇혀있어요" },
      { name: "소드 9", desc: "걱정과 불안감이 클 때예요" },
      { name: "소드 10", desc: "끝과 새로운 시작, 변화의 때예요" },
      { name: "소드 잭", desc: "날카로운 관찰력과 정보 수집이 필요해요" },
      { name: "소드 기사", desc: "빠른 행동과 결단력을 발휘하세요" },
      { name: "소드 퀸", desc: "냉정한 판단과 독립성이 중요해요" },
      { name: "소드 킹", desc: "공정한 판단과 리더십을 발휘하세요" },
      
      # 펜타클 (대지) 14장
      { name: "펜타클 에이스", desc: "새로운 물질적 기회와 시작이 와요" },
      { name: "펜타클 2", desc: "균형과 우선순위를 정하는 시간이에요" },
      { name: "펜타클 3", desc: "협력과 팀워크로 성과를 내세요" },
      { name: "펜타클 4", desc: "안정과 보수적인 접근이 필요해요" },
      { name: "펜타클 5", desc: "경제적 어려움이 있지만 도움이 올 거예요" },
      { name: "펜타클 6", desc: "나눔과 베풂의 기쁨이 있어요" },
      { name: "펜타클 7", desc: "인내와 꾸준한 노력이 결실을 맺어요" },
      { name: "펜타클 8", desc: "기술과 실력을 연마하는 시간이에요" },
      { name: "펜타클 9", desc: "물질적 성취와 독립성을 얻어요" },
      { name: "펜타클 10", desc: "가족과 전통, 안정된 기반이 중요해요" },
      { name: "펜타클 잭", desc: "새로운 학습과 실용적인 기회가 와요" },
      { name: "펜타클 기사", desc: "성실함과 책임감으로 목표를 달성하세요" },
      { name: "펜타클 퀸", desc: "현실적인 지혜와 풍요로운 마음이 필요해요" },
      { name: "펜타클 킹", desc: "물질적 성공과 안정된 리더십이 중요해요" }
    ]
    
    # 전체 78장의 카드
    all_cards = major_arcana + minor_arcana
    selected_card = all_cards.sample
    
    # 행운의 요소들
   lucky_colors = ["빨간색", "파란색", "노란색", "초록색", "보라색", "주황색", "분홍색", "하얀색", "검은색", "금색", "은색", "갈색"]
    lucky_items = ["마법지팡이", "깃털펜", "양피지", "가마솥", "빗자루", "마법약", "초콜릿 개구리", "버터맥주", "마법사 체스", "교과서", "망원경", "부엉이", "마법 거울", "시간 모래시계", "황금 스니치", "마법 열쇠", "갈레온", "편지"]
    lucky_places = ["도서관", "대강당", "그리핀도르 기숙사", "슬리데린 기숙사", "래번클로 기숙사", "후플푸프 기숙사", "변신술 교실", "마법약 교실", "점술 교실", "허니듀크 과자가게", "스리 브룸스틱스", "올리밴더 지팡이 가게", "퀴디치 경기장", "해그리드 오두막", "온실", "요구의 방", "교장실", "병동"]

    
    selected_color = lucky_colors.sample
    selected_item = lucky_items.sample
    selected_place = lucky_places.sample
    
    puts "[완료] 타로 카드 선택: #{selected_card[:name]}"
    
    tarot_result = <<~TAROT
      어머, #{selected_card[:name]} 카드가 나왔네!
      
      이게 뭔 뜻이냐면#{selected_card[:desc]}
      
      오늘 너한테 좋은 건:
      행운의 색: #{selected_color}
      행운의 물건: #{selected_item}
      행운의 장소: #{selected_place}
      
      잘 새겨들어~
    TAROT
    
    MastodonClient.reply(mention.status, tarot_result)
  end

  def self.handle_betting(ws_users, mention, sender, amount)
    puts "[베팅] 베팅 요청: #{amount}갈레온 (#{sender})"
    
    # 베팅 금액 제한 (1~20갈레온)
    if amount < 1 || amount > 20
      puts "[거절] 베팅 금액 범위 초과: #{amount}"
      MastodonClient.reply(mention.status, "얘야, 베팅은 1갈레온부터 20갈레온까지만 해! 너무 많이 걸면 안 돼~")
      return
    end
    
    user_row = find_user_row(ws_users, sender)
    user_galleon = ws_users[user_row, 3].to_i

    if user_galleon < amount
      puts "[거절] 갈레온 부족: #{user_galleon} < #{amount}"
      MastodonClient.reply(mention.status, "돈이 없잖아~ 어떻게 베팅해?")
      return
    end

    begin
      # 베팅 결과: -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5 (총 11가지)
      multipliers = [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5]
      multiplier = multipliers.sample
      
      # 결과 계산
      result = amount * multiplier
      new_galleon = user_galleon + result
      
      ws_users[user_row, 3] = new_galleon.to_s
      ws_users.save
      
      if multiplier > 0
        puts "[완료] 베팅 성공: #{multiplier}배 (#{result:+d}갈레온)"
        MastodonClient.reply(mention.status, "어머, 대박이네! #{multiplier}배 떴어~ #{result:+d}갈레온으로 총 #{new_galleon}갈레온 됐네!")
      elsif multiplier == 0
        puts "[완료] 베팅 무승부: 0배 (#{result}갈레온)"
        MastodonClient.reply(mention.status, "어머, 본전이야~ 그대로 #{new_galleon}갈레온이네!")
      else
        puts "[완료] 베팅 실패: #{multiplier}배 (#{result}갈레온)"
        if new_galleon < 0
          MastodonClient.reply(mention.status, "아이고, #{multiplier}배로 #{result}갈레온 날렸네~ 빚이 #{new_galleon.abs}갈레온이나 됐어!")
        else
          MastodonClient.reply(mention.status, "아이고, #{multiplier}배로 #{result}갈레온 날렸네~ 이제 #{new_galleon}갈레온 남았어!")
        end
      end
      
    rescue => e
      puts "[오류] 베팅 처리 실패: #{e.message}"
      MastodonClient.reply(mention.status, "어머, 뭔가 잘못됐네? 다시 해보렴~")
    end
  end

  def self.handle_help(mention)
    puts "[도움말] 도움말 요청"
    
    help_text = <<~HELP
      얘야, 여기 동네 마법용품점 사용법이야:
      
      [구매/아이템명] - 물건 사기
      [양도/아이템명/@사용자] - 물건 넘기기
      [양도/갈레온/@사용자] - 돈 넘기기
      [사용/아이템명] - 물건 쓰기
      [주머니] - 내 돈이랑 물건 보기
      [타로] - 타로카드 뽑기 (78장)
      [베팅/금액] - 도박하기 (1~20갈레온)
      [도움말] - 이 설명서
      
      베팅은 -5배부터 +5배까지 나와~
      조심해서 해야 돼! 빚질 수도 있어!
    HELP
    
    puts "[완료] 도움말 전송"
    MastodonClient.reply(mention.status, help_text)
  end
end
