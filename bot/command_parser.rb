# bot/command_parser.rb
require_relative 'mastodon_client'
require 'google_drive'
require 'json'

module CommandParser
  # 구글 시트 워크시트 이름
  ITEMS_SHEET = '아이템'
  USERS_SHEET = '사용자'
  RESPONSES_SHEET = '응답'
  
  def self.handle(mention)
    text = mention.status.content
                   .gsub(/<[^>]*>/, '')
                   .strip
    
    acct = mention.account.acct
    display_name = mention.account.display_name || acct
    
    puts "처리 중인 멘션: #{text}"
    
    # 구글 시트에서 응답 찾기 (우선 처리)
    begin
      response = find_response_from_sheet(text, display_name)
      if response
        MastodonClient.reply(mention, response)
        return
      end
    rescue => e
      puts "응답 시트 확인 중 오류: #{e.message}"
    end
    
    # 게임 명령어 처리
    case text
    when /^\[구매\/(.+)\]$/i
      handle_purchase(mention, acct, display_name, $1)
    when /^\[양도\/(.+)\/@(.+)\]$/i
      handle_transfer_item(mention, acct, display_name, $1, $2)
    when /^\[양도\/갈레온\/(\d+)\/@(.+)\]$/i
      handle_transfer_galleon(mention, acct, display_name, $1.to_i, $2)
    when /^\[주머니\]$/i
      handle_inventory(mention, acct, display_name)
    when /^\[사용\/(.+)\]$/i
      handle_use_item(mention, acct, display_name, $1)
    when /^\[상점\]$/i
      handle_shop(mention, acct, display_name)
    when /^\[베팅\/(\d+)\]$/i
      handle_betting(mention, acct, display_name, $1.to_i)
    when /^\[20D\]$/i
      handle_dice_20(mention, acct, display_name)
    when /^\[100D\]$/i
      handle_dice_100(mention, acct, display_name)
    when /^\[yn\]$/i
      handle_yes_no_simple(mention, acct, display_name)
    when /^\[운세\]$/i
      handle_tarot_fortune(mention, acct, display_name)
    when /^\[동전\]$/i, /^\[동전던지기\]$/i
      handle_coin_flip(mention, acct, display_name)

    else
      handle_unknown(mention, acct, display_name, text)
    end
  end

  private

  # 구글 시트 클라이언트
  def self.google_client
    @google_client ||= begin
      credentials_path = ENV['GOOGLE_CREDENTIALS_PATH']
      unless File.exist?(credentials_path)
        raise "구글 인증 파일을 찾을 수 없습니다: #{credentials_path}"
      end
      
      puts "구글 시트에 연결 중..."
      GoogleDrive::Session.from_service_account_key(credentials_path)
    end
  end

  # 구글 스프레드시트 가져오기
  def self.spreadsheet
    @spreadsheet ||= begin
      sheet_id = ENV['GOOGLE_SHEET_ID']
      google_client.spreadsheet_by_key(sheet_id)
    end
  end

  # 구글 시트 응답 시스템
  def self.find_response_from_sheet(text, display_name)
    begin
      worksheet = spreadsheet.worksheet_by_title(RESPONSES_SHEET)
      return nil unless worksheet
      
      responses = []
      
      # 헤더 행 스킵하고 데이터 행들 확인
      (2..worksheet.num_rows).each do |row|
        on_off = worksheet[row, 1]&.strip
        keyword = worksheet[row, 2]&.strip
        response_text = worksheet[row, 3]&.strip
        
        # ON/OFF 체크
        next unless on_off&.downcase == 'on' || on_off == '✓'
        
        # 키워드 매칭
        next unless keyword && text.include?(keyword.gsub(/[\[\]]/, ''))
        
        # 응답 텍스트 확인
        next if response_text.nil? || response_text.empty?
        
        # 이름 치환
        response_text = response_text.gsub(/\{name\}/, display_name)
        
        responses << response_text
      end
      
      responses.sample
      
    rescue => e
      puts "응답 시트 읽기 오류: #{e.message}"
      nil
    end
  end

  # 아이템 데이터 로드
  def self.load_items_data
    begin
      worksheet = spreadsheet.worksheet_by_title(ITEMS_SHEET)
      return {} unless worksheet
      
      items = {}
      
      # 헤더 행 스킵하고 데이터 행들 읽기
      (2..worksheet.num_rows).each do |row|
        name = worksheet[row, 1]&.strip
        next unless name && !name.empty?
        
        items[name] = {
          'price' => worksheet[row, 2]&.to_i || 0,
          'description' => worksheet[row, 3]&.strip || '',
          'purchasable' => worksheet[row, 4]&.strip == '✓',
          'transferable' => worksheet[row, 5]&.strip == '✓',
          'usable' => worksheet[row, 6]&.strip == '✓',
          'effect' => worksheet[row, 7]&.strip || '',
          'delete_on_use' => worksheet[row, 8]&.strip == '✓'
        }
      end
      
      puts "아이템 #{items.size}개 로드됨"
      items
      
    rescue => e
      puts "아이템 시트 읽기 오류: #{e.message}"
      {}
    end
  end

  # 사용자 데이터 로드
  def self.load_users_data
    begin
      worksheet = spreadsheet.worksheet_by_title(USERS_SHEET)
      return {} unless worksheet
      
      users = {}
      
      # 헤더 행 스킵하고 데이터 행들 읽기
      (2..worksheet.num_rows).each do |row|
        id = worksheet[row, 1]&.strip
        next unless id && !id.empty?
        
        users[id] = {
          'username' => worksheet[row, 2]&.strip || id,
          'galleons' => worksheet[row, 3]&.to_i || 20,
          'items' => parse_items(worksheet[row, 4]),
          'notes' => worksheet[row, 5]&.strip || ''
        }
      end
      
      puts "사용자 #{users.size}명 로드됨"
      users
      
    rescue => e
      puts "사용자 시트 읽기 오류: #{e.message}"
      {}
    end
  end

  # 사용자 데이터 저장
  def self.save_users_data(users_data)
    begin
      worksheet = spreadsheet.worksheet_by_title(USERS_SHEET)
      return unless worksheet
      
      puts "사용자 데이터 저장 중..."
      
      # 헤더 확인 및 추가
      if worksheet[1, 7].nil? || worksheet[1, 7].strip.empty?
        worksheet[1, 7] = '마지막베팅일'
      end
      if worksheet[1, 8].nil? || worksheet[1, 8].strip.empty?
        worksheet[1, 8] = '오늘베팅횟수'
      end
      
      # 기존 데이터 모두 삭제 (헤더 제외)
      if worksheet.num_rows > 1
        worksheet.delete_rows(2, worksheet.num_rows)
      end
      
      # 새 데이터 추가
      row_num = 2
      users_data.each do |id, data|
        items_string = format_items(data['items'])
        
        worksheet[row_num, 1] = id
        worksheet[row_num, 2] = data['username']
        worksheet[row_num, 3] = data['galleons']
        worksheet[row_num, 4] = items_string
        worksheet[row_num, 5] = data['notes']
        worksheet[row_num, 6] = data['house'] || ''
        worksheet[row_num, 7] = data['last_bet_date'] || ''
        worksheet[row_num, 8] = data['today_bet_count'] || 0
        
        row_num += 1
      end
      
      # 시트 저장
      worksheet.save
      puts "사용자 데이터 저장 완료"
      
    rescue => e
      puts "사용자 시트 저장 오류: #{e.message}"
    end
  end

  # 구매 처리 (빚 상태 체크 포함)
  def self.handle_purchase(mention, acct, display_name, item_name)
    return unless check_user_registration(mention, acct, display_name)
    
    item_name = item_name.strip
    items_data = load_items_data
    users_data, user_info = get_user(acct)

    unless items_data[item_name]
      MastodonClient.reply(mention, "'#{item_name}'은(는)이 뭐야? 난 그런거 취급안해요!")
      return
    end

    item = items_data[item_name]
    
    unless item['purchasable']
      MastodonClient.reply(mention, "'#{item_name}'이건 안팔아요~")
      return
    end

    price = item['price']
    
    # 빚이 있으면 구매 제한
    if user_info['galleons'] < 0
      MastodonClient.reply(mention, "빚을 먼저 갚아야 합니다! 빚: #{user_info['galleons'].abs}G")
      return
    end
    
    if user_info['galleons'] < price
      MastodonClient.reply(mention, "학생! 갈레온이 없잖아? 필요: #{price}G, 보유: #{user_info['galleons']}G")
      return
    end

    # 구매 처리
    user_info['galleons'] -= price
    user_info['items'][item_name] = (user_info['items'][item_name] || 0) + 1
    
    # 개별 사용자 업데이트 (더 효율적)
    update_user_data(acct, user_info)

    MastodonClient.reply(mention, "#{display_name}님이 '#{item_name}'을(를) #{price}G에 사갔다네! 고마워~\n#{item['description']}\n잔여 갈레온: #{user_info['galleons']}G")
  end

  # 특정 사용자 데이터만 업데이트 (베팅 정보 포함)
  def self.update_user_data(acct, user_data)
    begin
      worksheet = spreadsheet.worksheet_by_title(USERS_SHEET)
      return unless worksheet
      
      # 헤더 확인 및 추가
      if worksheet[1, 7].nil? || worksheet[1, 7].strip.empty?
        worksheet[1, 7] = '마지막베팅일'
      end
      if worksheet[1, 8].nil? || worksheet[1, 8].strip.empty?
        worksheet[1, 8] = '오늘베팅횟수'
      end
      
      # 사용자 행 찾기
      user_row = nil
      (2..worksheet.num_rows).each do |row|
        if worksheet[row, 1]&.strip == acct
          user_row = row
          break
        end
      end
      
      return unless user_row
      
      # 데이터 업데이트
      items_string = format_items(user_data['items'])
      
      worksheet[user_row, 2] = user_data['username']
      worksheet[user_row, 3] = user_data['galleons']
      worksheet[user_row, 4] = items_string
      worksheet[user_row, 5] = user_data['notes']
      worksheet[user_row, 6] = user_data['house'] || ''
      worksheet[user_row, 7] = user_data['last_bet_date'] || ''
      worksheet[user_row, 8] = user_data['today_bet_count'] || 0
      
      worksheet.save
      puts "사용자 데이터 업데이트됨: #{user_data['username']}"
      
    rescue => e
      puts "사용자 데이터 업데이트 오류: #{e.message}"
    end
  end

  # 아이템 문자열 파싱 (예: "체력포션x2,철검x1")
  def self.parse_items(items_string)
    return {} unless items_string && !items_string.strip.empty?
    
    items = {}
    items_string.split(',').each do |item_entry|
      if item_entry.match(/(.+?)x(\d+)/)
        item_name = $1.strip
        count = $2.to_i
        items[item_name] = count if count > 0
      end
    end
    items
  end

  # 아이템 딕셔너리를 문자열로 변환
  def self.format_items(items_hash)
    return '' if items_hash.empty?
    
    items_hash.map { |name, count| "#{name}x#{count}" }.join(',')
  end

  # 사용자 데이터 가져오기 (등록된 사용자만)
  def self.get_user(acct)
    users_data = load_users_data
    
    unless users_data[acct]
      return [nil, nil]  # 미등록 사용자
    end
    
    [users_data, users_data[acct]]
  end

  # 미등록 사용자 체크
  def self.check_user_registration(mention, acct, display_name)
    users_data, user_info = get_user(acct)
    
    if user_info.nil?
      unregistered_messages = [
        "#{display_name}님은 호그와트 학적부에서 확인되지 않습니다.\n교수봇에서 [입학/이름]으로 등록해주세요!",
        "#{display_name}님은 미등록 학생입니다.\n먼저 교수봇에서 입학 절차를 밟아주세요!"
      ]
      
      MastodonClient.reply(mention, unregistered_messages.sample)
      return false
    end
    
    true
  end

  # 아이템 양도 처리
  def self.handle_transfer_item(mention, acct, display_name, item_name, target_acct)
    return unless check_user_registration(mention, acct, display_name)
    
    item_name = item_name.strip
    target_acct = target_acct.strip.gsub('@', '')
    
    items_data = load_items_data
    users_data, sender = get_user(acct)
    
    unless items_data[item_name]
      MastodonClient.reply(mention, "'#{item_name}'은(는) 존재하지 않는 아이템입니다!")
      return
    end

    unless items_data[item_name]['transferable']
      MastodonClient.reply(mention, "'#{item_name}'은(는) 양도할 수 없는 아이템입니다!")
      return
    end
    
    unless sender['items'][item_name] && sender['items'][item_name] > 0
      MastodonClient.reply(mention, "'#{item_name}'을(를) 보유하고 있지 않습니다!")
      return
    end

    # 받는 사람이 등록된 사용자인지 확인
    unless users_data[target_acct]
      MastodonClient.reply(mention, "@#{target_acct}님은 호그와트 학적부에서 확인되지 않습니다.\n교수봇에서 먼저 입학 절차를 밟아주세요!")
      return
    end
    receiver = users_data[target_acct]

    # 양도 처리
    sender['items'][item_name] -= 1
    sender['items'].delete(item_name) if sender['items'][item_name] == 0
    receiver['items'][item_name] = (receiver['items'][item_name] || 0) + 1
    
    # 전체 사용자 데이터 저장 (양도는 두 명이 관련되므로)
    users_data[acct] = sender
    users_data[target_acct] = receiver
    save_users_data(users_data)

    MastodonClient.reply(mention, "#{display_name}님이 @#{target_acct}님에게 '#{item_name}'을(를) 양도했습니다!\n#{items_data[item_name]['description']}")
  end

  # 갈레온 양도 처리 (빚 상태 체크 포함)
  def self.handle_transfer_galleon(mention, acct, display_name, amount, target_acct)
    return unless check_user_registration(mention, acct, display_name)
    
    target_acct = target_acct.strip.gsub('@', '')
    
    users_data, sender = get_user(acct)
    
    # 빚이 있으면 양도 제한
    if sender['galleons'] < 0
      MastodonClient.reply(mention, "빚을 먼저 갚아야 합니다! 빚: #{sender['galleons'].abs}G")
      return
    end
    
    if sender['galleons'] < amount
      MastodonClient.reply(mention, "갈레온이 부족합니다! 보유: #{sender['galleons']}G")
      return
    end

    # 받는 사람이 등록된 사용자인지 확인
    unless users_data[target_acct]
      MastodonClient.reply(mention, "@#{target_acct}님은 호그와트 학적부에서 확인되지 않습니다.\n교수봇에서 먼저 입학 절차를 밟아주세요!")
      return
    end
    receiver = users_data[target_acct]

    # 양도 처리
    sender['galleons'] -= amount
    receiver['galleons'] += amount
    
    # 전체 사용자 데이터 저장 (양도는 두 명이 관련되므로)
    users_data[acct] = sender
    users_data[target_acct] = receiver
    save_users_data(users_data)

    MastodonClient.reply(mention, "#{display_name}님이 @#{target_acct}님에게 #{amount}G를 양도했습니다!\n잔여 갈레온: #{sender['galleons']}G")
  end

  # 인벤토리 확인 (빚 상태 포함)
  def self.handle_inventory(mention, acct, display_name)
    return unless check_user_registration(mention, acct, display_name)
    
    users_data, user_info = get_user(acct)
    
    inventory_text = "#{display_name}님의 주머니\n"
    
    if user_info['galleons'] >= 0
      inventory_text += "갈레온: #{user_info['galleons']}G\n"
    else
      inventory_text += "갈레온: #{user_info['galleons']}G\n빚: #{user_info['galleons'].abs}G (갈레온을 벌어서 갚으세요!)\n"
    end
    
    # 베팅 정보
    today = Date.today.strftime('%Y-%m-%d')
    if user_info['last_bet_date'] == today
      remaining_bets = 3 - user_info['today_bet_count']
      inventory_text += "오늘 남은 베팅: #{remaining_bets}회\n"
    else
      inventory_text += "오늘 남은 베팅: 3회\n"
    end
    
    inventory_text += "\n소지품:\n"
    
    if user_info['items'].empty?
      inventory_text += "   (비어있음)"
    else
      user_info['items'].each do |item, count|
        inventory_text += "   • #{item} x#{count}\n"
      end
    end

    MastodonClient.reply(mention, inventory_text)
  end

  # 아이템 사용
  def self.handle_use_item(mention, acct, display_name, item_name)
    return unless check_user_registration(mention, acct, display_name)
    
    item_name = item_name.strip
    items_data = load_items_data
    users_data, user_info = get_user(acct)

    unless items_data[item_name]
      MastodonClient.reply(mention, "'#{item_name}'은(는) 존재하지 않는 아이템입니다!")
      return
    end

    unless user_info['items'][item_name] && user_info['items'][item_name] > 0
      MastodonClient.reply(mention, "'#{item_name}'을(를) 보유하고 있지 않습니다!")
      return
    end

    item = items_data[item_name]
    unless item['usable']
      MastodonClient.reply(mention, "'#{item_name}'은(는) 사용할 수 없는 아이템입니다!")
      return
    end

    # 아이템 사용 처리
    if item['delete_on_use']
      user_info['items'][item_name] -= 1
      user_info['items'].delete(item_name) if user_info['items'][item_name] == 0
    end
    
    # 개별 사용자 업데이트
    update_user_data(acct, user_info)

    effect = item['effect'].empty? ? item['description'] : item['effect']
    
    use_messages = [
      "'#{item_name}' 사용 했습니다! #{effect}",
    ]
    
    MastodonClient.reply(mention, use_messages.sample)
  end

  # 상점 보기
  def self.handle_shop(mention, acct, display_name)
    items_data = load_items_data
    
    if items_data.empty?
      MastodonClient.reply(mention, "어머나, 지금은 팔 물건이 하나도 없네요!")
      return
    end
    
    shop_text = "어서와요! 무슨 마법용품을 찾으시나요?\n\n"
    items_data.each do |item, data|
      next unless data['purchasable']
      
      shop_text += "#{item}: #{data['price']}갈레온\n"
      shop_text += "   - #{data['description']}\n\n"
    end
    shop_text += "구매하시려면 [구매/용품명] 하시면 됩니다"

    MastodonClient.reply(mention, shop_text)
  end

  # 베팅 기능 (새로운 곱셈 시스템)
  def self.handle_betting(mention, acct, display_name, bet_amount)
    return unless check_user_registration(mention, acct, display_name)
    
    users_data, user_info = get_user(acct)
    today = Date.today.strftime('%Y-%m-%d')
    
    # 하루 베팅 횟수 체크
    if user_info['last_bet_date'] != today
      # 새로운 날이면 카운트 리셋
      user_info['last_bet_date'] = today
      user_info['today_bet_count'] = 0
    end
    
    if user_info['today_bet_count'] >= 3
      MastodonClient.reply(mention, "오늘은 이미 3번 베팅하셨습니다! 내일 다시 도전하세요!")
      return
    end
    
    # 베팅 금액 제한 (1-20갈레온)
    if bet_amount < 1
      MastodonClient.reply(mention, "최소 베팅 금액은 1갈레온입니다!")
      return
    end
    
    if bet_amount > 20
      MastodonClient.reply(mention, "최대 베팅 금액은 20갈레온입니다!")
      return
    end
    
    # 베팅 결과 (-5부터 +5까지 11가지)
    multipliers = [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5]
    result_multiplier = multipliers.sample
    
    # 베팅 횟수 증가
    user_info['today_bet_count'] += 1
    remaining_bets = 3 - user_info['today_bet_count']
    
    # 갈레온 변화 계산
    if result_multiplier == 0
      # 무승부 (원금 그대로)
      galleon_change = 0
      user_info['galleons'] = user_info['galleons'] - bet_amount + bet_amount  # 동일
      
      result_message = "무승부! 베팅 금액이 그대로 돌아왔습니다.\n잔여 갈레온: #{user_info['galleons']}G\n오늘 남은 베팅: #{remaining_bets}회"
      
    elsif result_multiplier > 0
      # 승리 (양수 배수)
      winnings = bet_amount * result_multiplier
      user_info['galleons'] = user_info['galleons'] - bet_amount + bet_amount + winnings
      
      win_messages = [
        "대박! x#{result_multiplier} 성공!",
        "운이 좋으시네요!",
        "훌륭한 승리입니다!"
      ]
      
      debt_status = user_info['galleons'] < 0 ? "\n빚: #{user_info['galleons'].abs}G" : ""
      result_message = "#{win_messages.sample} #{bet_amount}G -> +#{winnings}G 획득!\n잔여 갈레온: #{user_info['galleons']}G#{debt_status}\n오늘 남은 베팅: #{remaining_bets}회"
      
    else
      # 패배 (음수 배수)
      loss_amount = bet_amount * result_multiplier.abs
      user_info['galleons'] = user_info['galleons'] - bet_amount - loss_amount
      
      lose_messages = [
        "아쉽네요!",
        "이번엔 운이 없었어요.",
        "다음엔 행운을!"
      ]
      
      debt_warning = ""
      if user_info['galleons'] < 0
        debt_warning = "\n빚이 생겼습니다! 갈레온을 벌어서 갚으세요!"
      end
      
      debt_status = user_info['galleons'] < 0 ? "\n빚: #{user_info['galleons'].abs}G" : ""
      result_message = "#{lose_messages.sample} x#{result_multiplier} -> #{bet_amount}G + #{loss_amount}G = #{bet_amount + loss_amount}G 손실!\n잔여 갈레온: #{user_info['galleons']}G#{debt_status}#{debt_warning}\n오늘 남은 베팅: #{remaining_bets}회"
    end
    
    # 갈레온 및 베팅 정보 업데이트
    update_user_data(acct, user_info)
    
    MastodonClient.reply(mention, result_message)
  end

  # 20면 주사위
  def self.handle_dice_20(mention, acct, display_name)
    result = rand(20) + 1
    
    special_messages = {
      1 => "크리티컬 실패!",
      20 => "크리티컬 성공!"
    }
    
    message = "#{display_name}님의 D20 주사위: #{result}"
    message += "\n#{special_messages[result]}" if special_messages[result]
    
    MastodonClient.reply(mention, message)
  end

  # 100면 주사위
  def self.handle_dice_100(mention, acct, display_name)
    result = rand(100) + 1
    
    special_messages = {
      1 => "최악의 운!",
      100 => "전설적인 운!"
    }
    
    rank = case result
           when 1..10 then "매우 나쁨"
           when 11..30 then "나쁨"
           when 31..50 then "보통"
           when 51..70 then "좋음"
           when 71..90 then "매우 좋음"
           when 91..99 then "최상급"
           when 100 then "전설급"
           end
    
    message = "#{display_name}님의 D100 주사위: #{result}\n등급: #{rank}"
    message += "\n#{special_messages[result]}" if special_messages[result]
    
    MastodonClient.reply(mention, message)
  end

  # 간단한 예/아니오 (YES/NO 두 가지만)
  def self.handle_yes_no_simple(mention, acct, display_name)
    # YES/NO 두 가지만
    answers = ["YES", "NO"]
    answer = answers.sample
    emoji = answer == "YES" ? "O" : "X"
    
    response = "#{display_name}님의 점술 결과:\n\n#{emoji} **#{answer}**"
    
    MastodonClient.reply(mention, response)
  end

  # 타로카드 운세 (메이저 + 마이너 아르카나 전체 78장)
  def self.handle_tarot_fortune(mention, acct, display_name)
    # 메이저 아르카나 22장
    major_arcana = [
      { name: "바보 (The Fool)", meaning: "새로운 시작과 무한한 가능성이 열립니다. 용기를 내어 첫걸음을 내디디세요!" },
      { name: "마법사 (The Magician)", meaning: "당신의 의지와 능력으로 모든 것을 이룰 수 있습니다. 자신감을 가지세요!" },
      { name: "여교황 (The High Priestess)", meaning: "직감과 내면의 목소리에 귀 기울이세요. 지혜로운 판단의 시간입니다." },
      { name: "여황제 (The Empress)", meaning: "풍요로움과 창조력이 넘치는 하루입니다. 사랑과 아름다움이 함께합니다." },
      { name: "황제 (The Emperor)", meaning: "리더십과 권위가 빛나는 날입니다. 당당하게 자신의 길을 걸어가세요." },
      { name: "교황 (The Hierophant)", meaning: "전통과 지식이 도움이 됩니다. 멘토나 선배의 조언을 구해보세요." },
      { name: "연인 (The Lovers)", meaning: "소중한 인연과 조화로운 관계가 기다립니다. 선택의 순간이 올 수 있어요." },
      { name: "전차 (The Chariot)", meaning: "목표를 향해 힘차게 나아가세요. 의지력과 결단력이 승리를 가져다줍니다." },
      { name: "힘 (Strength)", meaning: "내면의 힘과 용기가 어려움을 극복하게 해줍니다. 부드러운 강함을 발휘하세요." },
      { name: "은둔자 (The Hermit)", meaning: "홀로만의 시간이 필요합니다. 내면을 돌아보고 진정한 답을 찾아보세요." },
      { name: "운명의 바퀴 (Wheel of Fortune)", meaning: "운명의 전환점이 다가옵니다. 변화를 두려워하지 말고 기회를 잡으세요!" },
      { name: "정의 (Justice)", meaning: "공정함과 균형이 중요한 하루입니다. 올바른 판단으로 좋은 결과를 얻을 거예요." },
      { name: "매달린 사람 (The Hanged Man)", meaning: "다른 관점에서 세상을 바라보세요. 잠시 멈춤이 새로운 깨달음을 줍니다." },
      { name: "죽음 (Death)", meaning: "끝은 새로운 시작입니다. 변화와 재탄생의 에너지가 당신을 감쌉니다." },
      { name: "절제 (Temperance)", meaning: "균형과 조화가 필요한 때입니다. 서두르지 말고 차근차근 진행하세요." },
      { name: "악마 (The Devil)", meaning: "유혹에 흔들리지 말고 진정한 자유를 추구하세요. 속박에서 벗어날 때입니다." },
      { name: "탑 (The Tower)", meaning: "급격한 변화가 올 수 있지만, 이는 더 나은 미래를 위한 과정입니다." },
      { name: "별 (The Star)", meaning: "희망과 영감이 가득한 하루입니다. 꿈을 향해 나아가며 밝은 미래를 그려보세요." },
      { name: "달 (The Moon)", meaning: "직감과 상상력이 높아지는 시기입니다. 꿈과 환상 속에서 답을 찾을 수 있어요." },
      { name: "태양 (The Sun)", meaning: "기쁨과 성공이 가득한 날입니다. 긍정적인 에너지로 모든 일이 잘 풀릴 거예요!" },
      { name: "심판 (Judgement)", meaning: "과거를 정리하고 새롭게 태어나는 시간입니다. 용서와 화해의 기회가 옵니다." },
      { name: "세계 (The World)", meaning: "완성과 성취의 순간입니다. 모든 노력이 결실을 맺으며 새로운 사이클이 시작됩니다." }
    ]

    # 마이너 아르카나 56장 (완드 수트 - 불의 원소)
    wands_cards = [
      { name: "완드 에이스", meaning: "새로운 창조적 에너지가 솟아납니다. 열정적인 시작을 하세요!" },
      { name: "완드 2", meaning: "미래 계획을 세우기 좋은 때입니다. 장기적 비전을 가지세요." },
      { name: "완드 3", meaning: "협력과 팀워크가 성공을 가져다줍니다. 주변 사람들과 소통하세요." },
      { name: "완드 4", meaning: "안정된 기반 위에서 축하할 일이 생깁니다. 성취를 즐기세요!" },
      { name: "완드 5", meaning: "경쟁과 갈등이 있지만 건설적인 결과를 낳을 것입니다." },
      { name: "완드 6", meaning: "승리와 인정을 받는 날입니다. 자신감을 가지고 앞으로 나아가세요!" },
      { name: "완드 7", meaning: "도전에 맞서 방어하며 당신의 위치를 지켜내세요." },
      { name: "완드 8", meaning: "빠른 진전과 소식이 있을 것입니다. 준비를 단단히 하세요." },
      { name: "완드 9", meaning: "마지막 관문 앞에서 인내심이 필요합니다. 포기하지 마세요!" },
      { name: "완드 10", meaning: "무거운 책임감이 있지만 끝까지 해내면 큰 보상이 따릅니다." },
      { name: "완드 페이지", meaning: "새로운 소식이나 기회가 찾아옵니다. 열린 마음으로 받아들이세요." },
      { name: "완드 나이트", meaning: "모험과 여행의 기운이 있습니다. 용기를 내어 새로운 곳으로!" },
      { name: "완드 퀸", meaning: "따뜻함과 창조성으로 주변을 이끌어가는 날입니다." },
      { name: "완드 킹", meaning: "리더십과 카리스마가 빛나는 하루입니다. 당당하게 이끌어가세요!" }
    ]

    # 컵 수트 (물의 원소 - 감정, 사랑, 관계)
    cups_cards = [
      { name: "컵 에이스", meaning: "새로운 감정과 사랑이 시작됩니다. 마음을 열어보세요!" },
      { name: "컵 2", meaning: "깊은 유대감과 파트너십이 형성됩니다. 소중한 관계를 대화하세요." },
      { name: "컵 3", meaning: "친구들과의 즐거운 시간이 기다립니다. 축하하고 함께 웃으세요!" },
      { name: "컵 4", meaning: "현재에 만족하지 말고 새로운 기회를 찾아보세요." },
      { name: "컵 5", meaning: "실망스러운 일이 있어도 아직 희망은 남아있습니다." },
      { name: "컵 6", meaning: "과거의 좋은 추억이 현재에 행복을 가져다줍니다." },
      { name: "컵 7", meaning: "여러 선택지 중에서 현실적인 것을 골라야 할 때입니다." },
      { name: "컵 8", meaning: "더 높은 목표를 향해 떠날 때입니다. 현재를 벗어나 성장하세요." },
      { name: "컵 9", meaning: "소원이 이루어지는 행복한 하루입니다. 만족감을 느끼세요!" },
      { name: "컵 10", meaning: "가족과 공동체의 행복이 가득한 날입니다. 함께하는 기쁨을 누리세요." },
      { name: "컵 페이지", meaning: "감성적이고 직관적인 메시지가 찾아옵니다. 마음의 소리를 들어보세요." },
      { name: "컵 나이트", meaning: "로맨틱하고 상상력이 풍부한 하루입니다. 꿈꾸는 것을 두려워하지 마세요." },
      { name: "컵 퀸", meaning: "직감과 공감능력이 뛰어난 날입니다. 다른 사람의 마음을 이해해보세요." },
      { name: "컵 킹", meaning: "감정적 균형과 지혜로 상황을 현명하게 이끌어가세요." }
    ]

    # 소드 수트 (공기의 원소 - 지성, 소통, 갈등)
    swords_cards = [
      { name: "소드 에이스", meaning: "명확한 사고와 새로운 아이디어가 떠오릅니다. 진실을 추구하세요!" },
      { name: "소드 2", meaning: "어려운 결정 앞에서 균형감각이 필요합니다. 신중하게 선택하세요." },
      { name: "소드 3", meaning: "마음의 상처가 있어도 치유의 시간이 올 것입니다." },
      { name: "소드 4", meaning: "휴식과 명상이 필요한 시간입니다. 재충전하세요." },
      { name: "소드 5", meaning: "갈등이 있어도 결국 더 나은 이해로 이어질 것입니다." },
      { name: "소드 6", meaning: "어려운 상황에서 벗어나 평화로운 곳으로 이동하는 때입니다." },
      { name: "소드 7", meaning: "전략적 사고로 목표를 달성할 수 있습니다. 계획을 세우세요." },
      { name: "소드 8", meaning: "제한된 상황이지만 창의적 해결책이 있습니다." },
      { name: "소드 9", meaning: "걱정이 많아도 실제로는 두려워할 일이 아닙니다. 용기를 내세요." },
      { name: "소드 10", meaning: "끝은 새로운 시작입니다. 절망보다는 희망에 집중하세요." },
      { name: "소드 페이지", meaning: "새로운 정보나 메시지가 도착합니다. 주의 깊게 들어보세요." },
      { name: "소드 나이트", meaning: "빠르고 결단력 있는 행동이 필요한 때입니다." },
      { name: "소드 퀸", meaning: "명확한 판단력과 독립성이 빛나는 하루입니다." },
      { name: "소드 킹", meaning: "지적 능력과 공정함으로 상황을 이끌어가세요." }
    ]

    # 펜타클 수트 (땅의 원소 - 물질, 돈, 건강)
    pentacles_cards = [
      { name: "펜타클 에이스", meaning: "새로운 물질적 기회나 건강한 시작이 옵니다!" },
      { name: "펜타클 2", meaning: "균형잡힌 자원 관리가 필요합니다. 우선순위를 정하세요." },
      { name: "펜타클 3", meaning: "팀워크와 기술 향상으로 좋은 결과를 얻을 것입니다." },
      { name: "펜타클 4", meaning: "안정성을 추구하되 너무 움켜쥐지는 마세요." },
      { name: "펜타클 5", meaning: "일시적 어려움이 있어도 도움의 손길이 있을 것입니다." },
      { name: "펜타클 6", meaning: "나눔과 베풂이 더 큰 풍요를 가져다줍니다." },
      { name: "펜타클 7", meaning: "인내심을 갖고 기다리면 노력의 결실을 볼 수 있습니다." },
      { name: "펜타클 8", meaning: "기술과 숙련도를 높이는 데 집중하세요. 연습이 완벽을 만듭니다." },
      { name: "펜타클 9", meaning: "독립성과 자급자족의 즐거움을 누리는 하루입니다." },
      { name: "펜타클 10", meaning: "가족과 물질적 안정이 함께하는 풍요로운 날입니다." },
      { name: "펜타클 페이지", meaning: "새로운 학습 기회나 실용적인 소식이 옵니다." },
      { name: "펜타클 나이트", meaning: "성실함과 근면함으로 목표에 한 걸음씩 다가가세요." },
      { name: "펜타클 퀸", meaning: "실용적 지혜와 너그러움으로 풍요를 창조하세요." },
      { name: "펜타클 킹", meaning: "물질적 성공과 안정된 리더십을 발휘하는 날입니다." }
    ]

    # 모든 카드 합치기
    all_cards = major_arcana + wands_cards + cups_cards + swords_cards + pentacles_cards

    # 랜덤 색깔 풀
    random_colors = [
      "빨간색", "파란색", "노란색", "초록색", "보라색", "주황색", "분홍색", "검은색", "흰색", "회색",
      "연두색", "하늘색", "청록색", "자주색", "갈색", "은색", "금색", "연분홍색", "연보라색", "진파란색",
      "올리브색", "라벤더색", "로즈골드", "코랄색", "민트색", "복숭아색", "카키색", "베이지색", "와인색", "네이비색"
    ]

    # 랜덤 아이템 풀
    random_items = [
      "반지", "목걸이", "팔찌", "시계", "열쇠고리", "향수", "꽃", "촛불", "책", "펜", "노트", "우산", "모자", "가방",
      "마스크", "선글라스", "스카프", "양말", "신발", "장갑", "거울", "빗", "립밤", "손수건", "동전", "사탕", "초콜릿",
      "차", "커피", "물병", "과일", "견과류", "쿠키", "꽃다발", "식물", "돌멩이", "조개껍질", "깃털", "별 스티커",
      "하트 스티커", "나비 브로치", "곰인형", "열쇠", "카드", "사진", "편지", "스마트폰", "이어폰", "충전기"
    ]

    # 추가 행운 아이템들 (보너스용)
    bonus_items = [
      "마스크 착용", "향수 뿌리기", "음악 듣기", "차 한 잔", "산책하기", "미소 짓기", "감사 인사", "깊은 숨쉬기", 
      "스트레칭", "일기 쓰기", "명상하기", "따뜻한 물 마시기", "친구에게 연락", "정리정돈", "독서", "그림 그리기",
      "노래 부르기", "춤추기", "요리하기", "운동하기", "일찍 자기", "일찍 일어나기", "창문 열기", "식물에 물주기"
    ]

    # 랜덤으로 카드, 색깔, 아이템 선택
    selected_card = all_cards.sample
    random_color = random_colors.sample
    random_item = random_items.sample
    bonus_item = bonus_items.sample

    response = <<~TAROT
      #{display_name}님의 오늘의 타로
      
      **#{selected_card[:name]}**
      
      **해석**: #{selected_card[:meaning]}
      
      **행운의 색**: #{random_color}
      **행운의 물건**: #{random_item}
      **보너스 추천**: #{bonus_item}
      
      오늘 하루도 행운이 가득하길!
    TAROT

    MastodonClient.reply(mention, response)
  end

  # 동전 던지기
  def self.handle_coin_flip(mention, acct, display_name)
    result = rand(2) == 0 ? "앞면" : "뒷면"
    emoji = result == "앞면" ? "O" : "X"
    
    flip_messages = [
      "동전이 빙글빙글... #{emoji} #{result}!",
      "띵! #{emoji} #{result}이 나왔습니다!",
      "#{emoji} 결과는... #{result}!"
    ]
    
    response = "#{display_name}님의 동전던지기:\n#{flip_messages.sample}"
    
    MastodonClient.reply(mention, response)
  end



  def self.handle_unknown(mention, acct, display_name, text)
    unknown_responses = [
      "#{display_name}님, 알 수 없는 명령어입니다!",
      "#{display_name}님, 명령어 형식이 맞지 않습니다! 예: [구매/체력포션], [베팅/15], [운세]",
      "#{display_name}님, 상점 이용이나 미니게임을 즐겨보세요!"
    ]
    
    MastodonClient.reply(mention, unknown_responses.sample)
  end
end
