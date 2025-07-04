# bot/command_parser.rb
require_relative 'mastodon_client'
require 'csv'
require 'json'

module CommandParser
  ITEMS_CSV = 'items.csv'
  USERS_CSV = 'users.csv'
  RESPONSES_CSV = 'responses.csv'
  
  def self.handle(mention)
    text = mention.status.content
                   .gsub(/<[^>]*>/, '')
                   .strip
    
    acct = mention.account.acct
    display_name = mention.account.display_name || acct
    
    puts "처리 중인 멘션: #{text}"
    
    # CSV 파일에서 응답 찾기 (우선 처리)
    if File.exist?(RESPONSES_CSV)
      response = find_response_from_csv(text, display_name)
      if response
        MastodonClient.reply(mention, response)
        return
      end
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

  # CSV 응답 시스템
  def self.find_response_from_csv(text, display_name)
    return nil unless File.exist?(RESPONSES_CSV)
    
    begin
      responses = []
      
      CSV.foreach(RESPONSES_CSV, headers: true, encoding: 'UTF-8') do |row|
        # ON/OFF 체크
        next unless row['ON/OFF']&.strip&.downcase == 'on' || row['ON/OFF']&.strip == '✓'
        
        # 키워드 매칭
        keyword = row['인식 키워드']&.strip
        next unless keyword && text.include?(keyword.gsub(/[\[\]]/, ''))
        
        # 응답 텍스트
        response_text = row['답변 출력']&.strip || ''
        next if response_text.empty?
        
        # 이름 치환
        response_text = response_text.gsub(/\{name\}/, display_name)
        
        responses << response_text
      end
      
      responses.sample
      
    rescue => e
      puts "응답 CSV 파일 읽기 오류: #{e.message}"
      nil
    end
  end

  # 아이템 CSV 데이터 로드
  def self.load_items_data
    return {} unless File.exist?(ITEMS_CSV)
    
    items = {}
    begin
      CSV.foreach(ITEMS_CSV, headers: true, encoding: 'UTF-8') do |row|
        name = row['아이템명']&.strip
        next unless name && !name.empty?
        
        items[name] = {
          'price' => row['가격']&.to_i || 0,
          'description' => row['설명']&.strip || '',
          'purchasable' => row['구매가능']&.strip == '✓',
          'transferable' => row['양도가능']&.strip == '✓',
          'usable' => row['사용가능']&.strip == '✓',
          'effect' => row['사용효과']&.strip || '',
          'delete_on_use' => row['사용시 삭제됨']&.strip == '✓'
        }
      end
    rescue => e
      puts "아이템 CSV 파일 읽기 오류: #{e.message}"
    end
    
    items
  end

  # 사용자 CSV 데이터 로드
  def self.load_users_data
    return {} unless File.exist?(USERS_CSV)
    
    users = {}
    begin
      CSV.foreach(USERS_CSV, headers: true, encoding: 'UTF-8') do |row|
        id = row['ID']&.strip
        next unless id && !id.empty?
        
        users[id] = {
          'username' => row['유저명']&.strip || id,
          'galleons' => row['갈레온']&.to_i || 20,
          'items' => parse_items(row['소지품']),
          'notes' => row['비고']&.strip || ''
        }
      end
    rescue => e
      puts "사용자 CSV 파일 읽기 오류: #{e.message}"
    end
    
    users
  end

  # 사용자 CSV 데이터 저장
  def self.save_users_data(users_data)
    begin
      CSV.open(USERS_CSV, 'w', encoding: 'UTF-8') do |csv|
        csv << ['ID', '유저명', '갈레온', '소지품', '비고']
        
        users_data.each do |id, data|
          items_string = format_items(data['items'])
          csv << [
            id,
            data['username'],
            data['galleons'],
            items_string,
            data['notes']
          ]
        end
      end
    rescue => e
      puts "사용자 CSV 파일 저장 오류: #{e.message}"
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

    # 신규 유저 등록
    users_data[acct] = {
      'username' => new_name,
      'galleons' => 20,  
      'items' => {},
      'notes' => "#{Date.today} 입학"
    }
    
    save_users_data(users_data)

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
    save_users_data(users_data)

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
    
    save_users_data(users_data)

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
      "호그와트 마법용품점 시스템 정상 작동 중!\n등록된 학생: #{user_count}명\n판매 중인 용품: #{item_count}개\n#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}",
      "모든 시스템 정상! 활성 학생: #{user_count}명\n용품 종류: #{item_count}개\n#{Time.now.strftime('%Y년 %m월 %d일 %H시 %M분')}"
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
