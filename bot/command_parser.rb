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
    when /^\[입학\/(.+)\]$/i
      handle_enrollment(mention, acct, display_name, $1)
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
    when /안녕/i, /hello/i, /hi/i
      handle_greeting(mention, acct, display_name)
    when /도움말/i, /help/i
      handle_help(mention, acct, display_name)
    when /상태/i, /status/i
      handle_status(mention, acct, display_name)
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
      
      puts "📊 구글 시트에 연결 중..."
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
      
      puts "📦 아이템 #{items.size}개 로드됨"
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
      
      puts "👥 사용자 #{users.size}명 로드됨"
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
      
      puts "💾 사용자 데이터 저장 중..."
      
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
        
        row_num += 1
      end
      
      # 시트 저장
      worksheet.save
      puts "✅ 사용자 데이터 저장 완료"
      
    rescue => e
      puts "사용자 시트 저장 오류: #{e.message}"
    end
  end

  # 새 사용자를 시트에 추가 (더 효율적)
  def self.add_new_user(acct, user_data)
    begin
      worksheet = spreadsheet.worksheet_by_title(USERS_SHEET)
      return unless worksheet
      
      # 마지막 행에 새 사용자 추가
      new_row = worksheet.num_rows + 1
      items_string = format_items(user_data['items'])
      
      worksheet[new_row, 1] = acct
      worksheet[new_row, 2] = user_data['username']
      worksheet[new_row, 3] = user_data['galleons']
      worksheet[new_row, 4] = items_string
      worksheet[new_row, 5] = user_data['notes']
      
      worksheet.save
      puts "✅ 신규 사용자 추가됨: #{user_data['username']}"
      
    rescue => e
      puts "신규 사용자 추가 오류: #{e.message}"
    end
  end

  # 특정 사용자 데이터만 업데이트 (더 효율적)
  def self.update_user_data(acct, user_data)
    begin
      worksheet = spreadsheet.worksheet_by_title(USERS_SHEET)
      return unless worksheet
      
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
      
      worksheet.save
      puts "✅ 사용자 데이터 업데이트됨: #{user_data['username']}"
      
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
        "#{display_name}학생을 찾을 수 없습니다.\n✨ [입학/이름]으로 학적부에 이름을 새겨주세요.",
      ]
      
      MastodonClient.reply(mention, unregistered_messages.sample)
      return false
    end
    
    true
  end

  # 신규 유저 입학 처리
  def self.handle_enrollment(mention, acct, display_name, new_name)
    new_name = new_name.strip
    users_data = load_users_data
    
    # 이미 등록된 사용자인지 확인
    if users_data[acct]
      current_name = users_data[acct]['username']
      MastodonClient.reply(mention, "#{display_name}님은 이미 '#{current_name}' 이름으로 등록되어 있습니다.")
      return
    end

    # 신규 유저 데이터
    user_data = {
      'username' => new_name,
      'galleons' => 20,  
      'items' => {},
      'notes' => "#{Date.today} 입학"
    }
    
    # 구글 시트에 직접 추가 (더 효율적)
    add_new_user(acct, user_data)

    welcome_messages = [
      "#{new_name}학생 호그와트 입학생임을 확인했습니다\n 열차에 탑승해주세요."
    ]
    
    MastodonClient.reply(mention, welcome_messages.sample)
  end

  # 구매 처리
  def self.handle_purchase(mention, acct, display_name, item_name)
    return unless check_user_registration(mention, acct, display_name)
    
    item_name = item_name.strip
    items_data = load_items_data
    users_data, user_info = get_user(acct)

    unless items_data[item_name]
      MastodonClient.reply(mention, "❌ '#{item_name}'은(는)이 뭐야? 난 그런거 취급안해요!")
      return
    end

    item = items_data[item_name]
    
    unless item['purchasable']
      MastodonClient.reply(mention, "'#{item_name}'이건 안팔아요~")
      return
    end

    price = item['price']
    
    if user_info['galleons'] < price
      MastodonClient.reply(mention, "학생! 갈레온이 없잖아? 필요: #{price}G, 보유: #{user_info['galleons']}G")
      return
    end

    # 구매 처리
    user_info['galleons'] -= price
    user_info['items'][item_name] = (user_info['items'][item_name] || 0) + 1
    
    # 개별 사용자 업데이트 (더 효율적)
    update_user_data(acct, user_info)

    MastodonClient.reply(mention, "#{display_name}님이 '#{item_name}'을(를) #{price}G에 사갔다네! 고마워~\n#{item['description']}\n💰 잔여 갈레온: #{user_info['galleons']}G")
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
      MastodonClient.reply(mention, "@#{target_acct}님은 호그와트 학적부에서 확인되지 않습니다.")
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

  # 갈레온 양도 처리
  def self.handle_transfer_galleon(mention, acct, display_name, amount, target_acct)
    return unless check_user_registration(mention, acct, display_name)
    
    target_acct = target_acct.strip.gsub('@', '')
    
    users_data, sender = get_user(acct)
    
    if sender['galleons'] < amount
      MastodonClient.reply(mention, "갈레온이 부족합니다! 보유: #{sender['galleons']}G")
      return
    end

    # 받는 사람이 등록된 사용자인지 확인
    unless users_data[target_acct]
      MastodonClient.reply(mention, "@#{target_acct}님은 호그와트 학적부에서 확인되지 않습니다.")
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

  # 인벤토리 확인
  def self.handle_inventory(mention, acct, display_name)
    return unless check_user_registration(mention, acct, display_name)
    
    users_data, user_info = get_user(acct)
    
    inventory_text = "#{display_name}님의 주머니\n"
    inventory_text += "갈레온: #{user_info['galleons']}G\n\n"
    inventory_text += "소지품:\n"
    
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

  def self.handle_greeting(mention, acct, display_name)
    greeting_responses = [
      "안녕하세요 #{display_name}! 호그와트에서 멋진 학교생활을 보내시길 바랍니다.",
    ]
    
    MastodonClient.reply(mention, greeting_responses.sample)
  end

  def self.handle_help(mention, acct, display_name)
    help_text = <<~HELP

      신규 입학:
      [입학/원하는이름] - 호그와트 입학 
      
      학교 상점 이용:
       [상점] - 마법용품점 보기
       [구매/아이템명] - 용품 구매
       [주머니] - 갈레온 & 소지품 확인
       [사용/아이템명] - 마법용품 사용
       [양도/아이템명/@상대ID] - 용품 양도
       [양도/갈레온/금액/@상대ID] - 갈레온 양도

      
       입학하지 않으면 학교 시설을 이용할 수 없습니다!
    HELP
    
    MastodonClient.reply(mention, help_text)
  end

  def self.handle_status(mention, acct, display_name)
    users_data = load_users_data
    items_data = load_items_data
    
    user_count = users_data.keys.length
    item_count = items_data.keys.length
    
    status_messages = [
      "호그와트 마법용품점 시스템 정상 작동 중!\n📊 구글 시트 연동 활성화\n등록된 학생: #{user_count}명\n판매 중인 용품: #{item_count}개\n#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}",
      "모든 시스템 정상! 📊 실시간 시트 동기화\n활성 학생: #{user_count}명\n용품 종류: #{item_count}개\n#{Time.now.strftime('%Y년 %m월 %d일 %H시 %M분')}"
    ]
    
    MastodonClient.reply(mention, status_messages.sample)
  end

  def self.handle_unknown(mention, acct, display_name, text)
    unknown_responses = [
      "#{display_name}님, 알 수 없는 명령어입니다! '도움말'을 확인해보세요!",
      "#{display_name}님, 명령어가 궁금하시면 '도움말'을 입력해주세요!",
      "#{display_name}님, 명령어 형식이 맞지 않습니다! 예: [구매/체력포션]"
    ]
    
    MastodonClient.reply(mention, unknown_responses.sample)
  end
end
