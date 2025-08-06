require_relative 'commands/buy_command'
require_relative 'commands/transfer_item_command'
require_relative 'commands/transfer_galleons_command'
require_relative 'commands/use_item_command'
require_relative 'commands/pouch_command'
require_relative 'commands/tarot_command'
require_relative 'commands/bet_command'
require_relative 'commands/dice_command'
require_relative 'commands/coin_command'
require_relative 'mastodon_client'

module CommandParser
  def self.parse(client, sheet_manager, mention)
    begin
      content = MastodonClient.clean_content(mention.status.content)
      sender = mention.account.acct
      text = content.strip

      case text
      when /\[구매\/(.+?)\]/
        item = $1.strip
        result = BuyCommand.new(sender, item, sheet_manager).execute

      when /\[양도\/(.+?)\/@(.+?)\]/
        item = $1.strip
        to = "@#{$2.strip}"
        result = TransferItemCommand.new(sender, to, item, sheet_manager).execute

      when /\[양도\/갈레온\/@(.+?)\/(\d+)\]/
        to = "@#{$1.strip}"
        amount = $2.to_i
        result = TransferGalleonsCommand.new(sender, to, amount, sheet_manager).execute

      when /\[사용\/(.+?)\]/
        item = $1.strip
        result = UseItemCommand.new(sender, item, sheet_manager).execute

      when /\[주머니\]/
        result = PouchCommand.new(sender, sheet_manager).execute

      when /\[타로\]/
        tarot_data = sheet_manager.tarot_data
        result = TarotCommand.new(sender, tarot_data, sheet_manager).execute

      when /\[베팅\/(\d+)\]/
        amount = $1.to_i
        result = BetCommand.new(sender, amount, sheet_manager).execute

      when /\[(\d{1,3})D\]/
        max = $1.to_i
        result = DiceCommand.new(sender, max).execute

      when /\[동전\]/
        result = CoinCommand.new(sender).execute

      else
        result = "#{sender}님, 알 수 없는 명령어입니다. 다시 확인해 보세요."
      end

      client.reply(mention.status, result) if result && !result.empty?

    rescue => e
      puts "[에러] 명령어 처리 실패: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
end
