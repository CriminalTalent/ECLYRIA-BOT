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
    
    puts "💬 처리 중인 멘션: #{text}"
    
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
    when /\[출석\]/i, /출석/i
      handle_attendance(mention, acct, display_name)
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
        
        # 응답 텍스트 조합
        response_part1 = row['출석 응답 내용']&.strip || ''
        response_part2 = row['답변 출력']&.strip || ''
        
        combined_response = [response_part1, response_part2]
                          .reject(&:empty?)
                          .join(' ')
                          .gsub(/\{name\}/, display_name)
        
        responses << combined_response unless combined_response.empty?
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
          'galleons' => row['갈레온']&.to_i || 100,
          'items' => parse_items(row['소지품']),
          'notes' => row['비고']&.strip || '',
          'last_attendance' => nil
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

  # 사용자 데이터 가져오기/생성
  def self.get_user(acct)
    users_data = load_users_data
    
    unless users_data[acct]
      users_data[acct] = {
        'username' => acct,
        'galleons' => 100,
        'items' => {},
        'notes' => '신규 가입자',
        'last_attendance' => nil
      }
      save_users_data(users_data)
    end
    
    [users_data, users_data[acct]]
  end

  # 구매 처리
  def self.handle_purchase(mention, acct, display_name, item_name)
    item_name = item_name.strip
    items_data = load_items_data
    users_data, user_info = get_user(acct)

    unless items_data[item_name]
      MastodonClient.reply(mention, "❌ '#{item_name}'은(는) 존재하지 않는 아이템입니다!")
      return
    end

    item = items_data[item_name]
    
    unless item['purchasable']
      MastodonClient.reply(mention, "❌ '#{item_name}'은(는) 구매할 수 없는 아이템입니다!")
      return
    end

    price = item['price']
    
    if user_info['galleons'] < price
      MastodonClient.reply(mention, "💸 갈레온이 부족합니다! 필요: #{price}G, 보유: #{user_info['galleons']}G")
      return
    end

    # 구매 처리
    user_info['galleons'] -= price
    user_info['items'][item_name] = (user_info['items'][item_name] || 0) + 1
    save_users_data(users_data)

    MastodonClient.reply(mention, "✅ #{display_name}님이 '#{item_name}'을(를) #{price}G에 구매했습니다!\n#{item['description']}\n💰 잔여 갈레온: #{user_info['galleons']}G")
  end

  # 아이템 양도 처리
  def self.handle_transfer_item(mention, acct, display_name, item_name, target_acct)
    item_name = item_name.strip
    target_acct = target_acct.strip.gsub('@', '')
    
    items_data = load_items_data
    users_data, sender = get_user(acct)
    
    unless items_data[item_name]
      MastodonClient.reply(mention, "❌ '#{item_name}'은(는) 존재하지 않는 아이템입니다!")
      return
    end

    unless items_data[item_name]['transferable']
      MastodonClient.reply(mention, "❌ '#{item_name}'은(는) 양도할 수 없는 아이템입니다!")
      return
    end
    
    unless sender['items'][item_name] && sender['items'][item_name] > 0
      MastodonClient.reply(mention, "❌ '#{item_name}'을(를) 보유하고 있지 않습니다!")
      return
    end

    # 받는 사람 데이터 로드/생성
    unless users_data[target_acct]
      users_data[target_acct] = {
        'username' => target_acct,
        'galleons' => 100,
        'items' => {},
        'notes' => '양도를 통해 가입',
        'last_attendance' => nil
      }
    end
    receiver = users_data[target_acct]

    # 양도 처리
    sender['items'][item_name] -= 1
    sender['items'].delete(item_name) if sender['items'][item_name] == 0
    receiver['items'][item_name] = (receiver['items'][item_name] || 0) + 1
    
    save_users_data(users_data)

    MastodonClient.reply(mention, "🎁 #{display_name}님이 @#{target_acct}님에게 '#{item_name}'을(를) 양도했습니다!\n#{items_data[item_name]['description']}")
  end

  # 갈레온 양도 처리
  def self.handle_transfer_galleon(mention, acct, display_name, amount, target_acct)
    target_acct = target_acct.strip.gsub('@', '')
    
    users_data, sender = get_user(acct)
    
    if sender['galleons'] < amount
      MastodonClient.reply(mention, "💸 갈레온이 부족합니다! 보유: #{sender['galleons']}G")
      return
    end

    # 받는 사람 데이터 로드/생성
    unless users_data[target_acct]
      users_data[target_acct] = {
        'username' => target_acct,
        'galleons' => 100,
        'items' => {},
        'notes' => '송금을 통해 가입',
        'last_attendance' => nil
      }
    end
    receiver = users_data[target_acct]

    # 양도 처리
    sender['galleons'] -= amount
    receiver['galleons'] += amount
    
    save_users_data(users_data)

    MastodonClient.reply(mention, "💰 #{display_name}님이 @#{target_acct}님에게 #{amount}G를 양도했습니다!\n잔여 갈레온: #{sender['galleons']}G")
  end

  # 인벤토리 확인
  def self.handle_inventory(mention, acct, display_name)
    users_data, user_info = get_user(acct)
    
    inventory_text = "🎒 #{display_name}님의 주머니\n"
    inventory_text += "💰 갈레온: #{user_info['galleons']}G\n\n"
    inventory_text += "📦 소지품:\n"
    
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
    item_name = item_name.strip
    items_data = load_items_data
    users_data, user_info = get_user(acct)

    unless items_data[item_name]
      MastodonClient.reply(mention, "❌ '#{item_name}'은(는) 존재하지 않는 아이템입니다!")
      return
    end

    unless user_info['items'][item_name] && user_info['items'][item_name] > 0
      MastodonClient.reply(mention, "❌ '#{item_name}'을(를) 보유하고 있지 않습니다!")
      return
    end

    item = items_data[item_name]
    unless item['usable']
      MastodonClient.reply(mention, "❌ '#{item_name}'은(는) 사용할 수 없는 아이템입니다!")
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
      "✨ #{display_name}님이 '#{item_name}'을(를) 사용했습니다!\n🎯 효과: #{effect}",
      "🌟 '#{item_name}' 사용 완료! #{effect}",
      "⚡ #{display_name}님의 '#{item_name}' 사용! #{effect} 발동!"
    ]
    
    MastodonClient.reply(mention, use_messages.sample)
  end

  # 상점 보기
  def self.handle_shop(mention, acct, display_name)
    items_data = load_items_data
    
    if items_data.empty?
      MastodonClient.reply(mention, "🏪 현재 상점에 판매 중인 아이템이 없습니다!")
      return
    end
    
    shop_text = "🏪 ECLYRIA 상점\n\n"
    items_data.each do |item, data|
      next unless data['purchasable']
      
      usable_mark = data['usable'] ? "🔄" : "📦"
      transfer_mark = data['transferable'] ? "🎁" : "🔒"
      
      shop_text += "#{usable_mark}#{transfer_mark} #{item}: #{data['price']}G\n"
      shop_text += "   └ #{data['description']}\n\n"
    end
    shop_text += "💡 구매: [구매/아이템명]"

    MastodonClient.reply(mention, shop_text)
  end

  # 출석 (갈레온 보상 추가)
  def self.handle_attendance(mention, acct, display_name)
    users_data, user_info = get_user(acct)
    
    today = Date.today.to_s
    
    if user_info['last_attendance'] == today
      MastodonClient.reply(mention, "❌ #{display_name}님은 오늘 이미 출석했습니다!")
      return
    end

    # 출석 보상
    reward = rand(10..30)
    user_info['galleons'] += reward
    user_info['last_attendance'] = today
    save_users_data(users_data)

    attendance_messages = [
      "📋 #{display_name}님 출석 완료! 🎁 보상: #{reward}G\n💰 총 갈레온: #{user_info['galleons']}G",
      "✅ #{display_name}님의 출석을 확인했어요! 💰 #{reward}G 획득!\n잔액: #{user_info['galleons']}G",
      "🌟 #{display_name}님 출석! 오늘의 보상 #{reward}G를 받으세요! 💰#{user_info['galleons']}G"
    ]
    
    MastodonClient.reply(mention, attendance_messages.sample)
  end

  def self.handle_greeting(mention, acct, display_name)
    greeting_responses = [
      "안녕하세요 #{display_name}님! 👋 ECLYRIA 모험에 오신 것을 환영합니다!",
      "반가워요 #{display_name}님! 😊 오늘은 어떤 모험을 떠나볼까요?",
      "🌟 #{display_name}님! 상점에서 아이템도 구경해보세요! [상점]",
      "🎮 #{display_name}님 안녕하세요! [주머니]로 소지품을 확인해보세요!"
    ]
    
    MastodonClient.reply(mention, greeting_responses.sample)
  end

  def self.handle_help(mention, acct, display_name)
    help_text = <<~HELP
      🤖 ECLYRIA RPG 봇 사용법:
      
      🎮 게임 명령어:
      📋 [출석] - 출석 체크 (갈레온 보상)
      🏪 [상점] - 아이템 상점 보기
      🛒 [구매/아이템명] - 아이템 구매
      🎒 [주머니] - 갈레온 & 소지품 확인
      🔄 [사용/아이템명] - 아이템 사용
      🎁 [양도/아이템명/@상대ID] - 아이템 양도
      💰 [양도/갈레온/금액/@상대ID] - 갈레온 양도
      
      💡 기본 명령어:
      👋 안녕 - 인사
      ❓ 도움말 - 이 메시지
      📊 상태 - 봇 상태
    HELP
    
    MastodonClient.reply(mention, help_text)
  end

  def self.handle_status(mention, acct, display_name)
    users_data = load_users_data
    items_data = load_items_data
    
    user_count = users_data.keys.length
    item_count = items_data.keys.length
    
    status_messages = [
      "🟢 ECLYRIA RPG 봇 정상 작동 중!\n👥 등록된 모험가: #{user_count}명\n🏪 상점 아이템: #{item_count}개\n⏰ #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}",
      "✅ 모든 시스템 정상! 🎮 활성 플레이어: #{user_count}명\n📦 아이템 종류: #{item_count}개\n📅 #{Time.now.strftime('%Y년 %m월 %d일 %H시 %M분')}"
    ]
    
    MastodonClient.reply(mention, status_messages.sample)
  end

  def self.handle_unknown(mention, acct, display_name, text)
    unknown_responses = [
      "🤔 #{display_name}님, 알 수 없는 명령어예요! '도움말'로 게임 사용법을 확인해보세요!",
      "❓ #{display_name}님, RPG 명령어가 궁금하시면 '도움말'을 입력해주세요!",
      "🎮 #{display_name}님, 게임 명령어 형식이 맞지 않아요! 예: [구매/체력포션]"
    ]
    
    MastodonClient.reply(mention, unknown_responses.sample)
  end
end
