require_relative 'mastodon_client'
require 'google_drive'
require 'time'
require 'json'
require_relative 'features/tarot'
require_relative 'features/betting'

module CommandParser
  USERS_SHEET = '사용자'
  ITEMS_SHEET = '아이템'

  def self.parse(client, sheet, mention)
    content = mention.status.content.gsub(/<[^>]*>/, '')
    sender = mention.account.acct
    text = content.strip

    puts "처리 중인 멘션: #{text}"

    session = GoogleDrive::Session.from_config(ENV['GOOGLE_CREDENTIALS_PATH'])
    ws_users = sheet.worksheet_by_title(USERS_SHEET)
    ws_items = sheet.worksheet_by_title(ITEMS_SHEET)

    case text
    when /\[구매\/(.+?)\]/
      item_name = $1.strip
      handle_purchase(client, ws_users, ws_items, sender, item_name)

    when /\[양도\/(.+?)\/@(.+?)\]/
      item_name = $1.strip
      receiver = $2.strip
      handle_transfer(client, ws_users, ws_items, sender, receiver, item_name)

    when /\[양도\/갈레온\/@(.+?)\]/
      receiver = $1.strip
      handle_galleon_transfer(client, ws_users, sender, receiver)

    when /\[사용\/(.+?)\]/
      item_name = $1.strip
      handle_use(client, ws_users, ws_items, sender, item_name)

    when /\[주머니\]/
      handle_inventory(client, ws_users, sender)

    when /\[타로\]/
      Tarot.draw(client, sender)

    when /\[베팅\/(\d+)\]/
      amount = $1.to_i
      Betting.process(client, sheet, sender, amount)
    end
  end

  def self.find_user_row(ws, id)
    ws.rows.each_with_index do |row, idx|
      return idx + 1 if row[0] == id
    end
    nil
  end

  def self.find_item_row(ws, name)
    ws.rows.each_with_index do |row, idx|
      return ws.rows[idx] if row[0] == name && row[3].strip.upcase == 'TRUE'
    end
    nil
  end

  def self.handle_purchase(client, ws_users, ws_items, sender, item_name)
    user_row = find_user_row(ws_users, sender)
    item_row = find_item_row(ws_items, item_name)

    if !item_row
      client.reply(sender, "그런 물건은 없어요, 다른 걸 찾아보실래요?")
      return
    end

    unless item_row[3].strip.upcase == 'TRUE'
      client.reply(sender, "그건 지금은 판매하지 않아요, 미안해요~")
      return
    end

    price = item_row[1].to_i
    user_galleon = ws_users[user_row - 1][2].to_i

    if user_galleon < price
      client.reply(sender, "갈레온이 부족하네요~ 조금 더 모아서 오실래요?")
      return
    end

    ws_users[user_row - 1][2] = (user_galleon - price).to_s
    items = ws_users[user_row - 1][3]
    ws_users[user_row - 1][3] = items.empty? ? item_name : "#{items},#{item_name}"
    ws_users.save
    client.reply(sender, "#{item_name}를 구입하셨어요~ 잘 어울릴 거예요!")
  end

  def self.handle_transfer(client, ws_users, ws_items, sender, receiver, item_name)
    sender_row = find_user_row(ws_users, sender)
    receiver_row = find_user_row(ws_users, receiver)
    item_row = ws_items.rows.find { |row| row[0] == item_name }

    if !item_row || item_row[4].strip.upcase != 'TRUE'
      client.reply(sender, "그 물건은 양도할 수 없어요, 죄송해요~")
      return
    end

    items = ws_users[sender_row - 1][3].split(',')
    unless items.include?(item_name)
      client.reply(sender, "그 아이템은 가지고 계시지 않네요~")
      return
    end

    items.delete_at(items.index(item_name))
    ws_users[sender_row - 1][3] = items.join(',')
    recv_items = ws_users[receiver_row - 1][3]
    ws_users[receiver_row - 1][3] = recv_items.empty? ? item_name : "#{recv_items},#{item_name}"
    ws_users.save
    client.reply(sender, "#{item_name}를 #{receiver}님께 전해드렸어요~")
  end

  def self.handle_galleon_transfer(client, ws_users, sender, receiver)
    sender_row = find_user_row(ws_users, sender)
    receiver_row = find_user_row(ws_users, receiver)

    amount = 1
    sender_galleon = ws_users[sender_row - 1][2].to_i

    if sender_galleon < amount
      client.reply(sender, "갈레온이 부족해서 드릴 수 없어요~")
      return
    end

    ws_users[sender_row - 1][2] = (sender_galleon - amount).to_s
    recv_galleon = ws_users[receiver_row - 1][2].to_i
    ws_users[receiver_row - 1][2] = (recv_galleon + amount).to_s
    ws_users.save
    client.reply(sender, "갈레온을 #{receiver}님께 살짝 건네드렸어요~")
  end

  def self.handle_use(client, ws_users, ws_items, sender, item_name)
    user_row = find_user_row(ws_users, sender)
    item_row = ws_items.rows.find { |row| row[0] == item_name && row[5].strip.upcase == 'TRUE' }

    unless item_row
      client.reply(sender, "그 아이템은 사용할 수 없답니다~")
      return
    end

    items = ws_users[user_row - 1][3].split(',')
    unless items.include?(item_name)
      client.reply(sender, "그 아이템은 가지고 계시지 않네요~")
      return
    end

    effect = item_row[6]
    delete_after = item_row[7].strip.upcase == 'TRUE'

    if delete_after
      items.delete_at(items.index(item_name))
      ws_users[user_row - 1][3] = items.join(',')
    end

    ws_users.save
    client.reply(sender, effect.empty? ? "#{item_name}를 사용하셨어요~" : effect)
  end

  def self.handle_inventory(client, ws_users, sender)
    user_row = find_user_row(ws_users, sender)
    galleon = ws_users[user_row - 1][2]
    items = ws_users[user_row - 1][3]
    client.reply(sender, "지금 가진 갈레온은 #{galleon}개고요~ 소지품은 [#{items}] 있답니다~")
  end
end
