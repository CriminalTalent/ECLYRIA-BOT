require_relative 'mastodon_client'
require_relative 'commands/buy_command'
require_relative 'commands/transfer_item_command'
require_relative 'commands/transfer_galleons_command'
require_relative 'commands/use_item_command'
require_relative 'commands/pouch_command'
require_relative 'commands/tarot_command'
require_relative 'commands/bet_command'
require_relative 'commands/dice_command'
require_relative 'commands/coin_command'
require_relative 'commands/yn_command'

module CommandParser
  USERS_SHEET = '사용자'
  ITEMS_SHEET = '아이템'

  def self.parse(client, sheet, mention)
    begin
      content = MastodonClient.clean_content(mention.status.content)
      sender = mention.account.acct
      text = content.strip

      ws_users = sheet.worksheet_by_title(USERS_SHEET)
      ws_items = sheet.worksheet_by_title(ITEMS_SHEET)

      user_row = find_user_row(ws_users, sender)
      return unless user_row

      case text
      when /\[구매\/(.+?)\]/
        item_name = $1.strip
        message = BuyCommand.new(sender, item_name, sheet).execute
        MastodonClient.reply(mention.status, message)

      when /\[양도\/(.+?)\/@(.+?)\]/
        item_name = $1.strip
        receiver = $2.strip
        message = TransferItemCommand.new(sender, receiver, item_name, sheet).execute
        MastodonClient.reply(mention.status, message)

      when /\[양도\/갈레온\/@(.+?)\]/
        receiver = $1.strip
        message = TransferGalleonsCommand.new(sender, receiver, sheet).execute
        MastodonClient.reply(mention.status, message)

      when /\[사용\/(.+?)\]/
        item_name = $1.strip
        message = UseItemCommand.new(sender, item_name, sheet).execute
        MastodonClient.reply(mention.status, message)

      when /\[주머니\]/
        message = PouchCommand.new(sender, sheet).execute
        MastodonClient.reply(mention.status, message)

      when /\[타로\]/
        message = TarotCommand.new(sender, sheet).execute
        MastodonClient.reply(mention.status, message)

      when /\[베팅\/(\d+)\]/
        amount = $1.to_i
        message = BetCommand.new(sender, amount, sheet).execute
        MastodonClient.reply(mention.status, message)

      when /\[100D\]/
        message = DiceCommand.new(sender, 100).execute
        MastodonClient.reply(mention.status, message)

      when /\[20D\]/
        message = DiceCommand.new(sender, 20).execute
        MastodonClient.reply(mention.status, message)

      when /\[동전\]/
        message = CoinCommand.new(sender).execute
        MastodonClient.reply(mention.status, message)

      when /\[YN\]/i
        message = YnCommand.new(sender).execute
        MastodonClient.reply(mention.status, message)

      else
        # 알려지지 않은 명령어는 무시
        puts "[무시됨] 알 수 없는 명령어: #{text}"
      end

    rescue => e
      puts "[오류] 명령어 처리 실패: #{e.message}"
      puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
    end
  end

  def self.find_user_row(ws_users, id)
    (2..ws_users.num_rows).each do |row|
      return row if ws_users[row, 1] == id
    end
    nil
  end
end
