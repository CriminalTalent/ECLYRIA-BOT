# command_parser.rb
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
  TAROT_DATA = {
    "THE FOOL" => "새로운 시작을 의미하는 카드입니다.",
    "THE MAGICIAN" => "의지력과 능력을 상징하는 카드입니다.",
    "THE HIGH PRIESTESS" => "직관과 신비를 나타내는 카드입니다.",
    "THE EMPRESS" => "풍요와 모성을 의미하는 카드입니다.",
    "THE EMPEROR" => "권위와 안정을 상징하는 카드입니다."
  }

  def self.parse(client, sheet, mention)
    begin
      content = mention.status.content.gsub(/<[^>]*>/, '').strip
      sender = mention.account.acct
      text = content.strip

      # 사용자 확인
      user = sheet.get_player(sender)
      return unless user

      case text
      when /\[구매\/(.+?)\]/
        item_name = $1.strip
        message = BuyCommand.new(sender, item_name, sheet).execute
        client.reply(mention.status, message) if message
        
      when /\[양도\/(.+?)\/@(.+?)\]/
        item_name = $1.strip
        receiver = $2.strip
        message = TransferItemCommand.new(sender, receiver, item_name, sheet).execute
        client.reply(mention.status, message) if message
        
      when /\[양도\/갈레온\/(\d+)\/@(.+?)\]/
        amount = $1.to_i
        receiver = $2.strip
        message = TransferGalleonsCommand.new(sender, receiver, amount, sheet).execute
        client.reply(mention.status, message) if message
        
      when /\[사용\/(.+?)\]/
        item_name = $1.strip
        message = UseItemCommand.new(sender, item_name, sheet).execute
        client.reply(mention.status, message) if message
        
      when /\[주머니\]/
        message = PouchCommand.new(sender, sheet).execute
        client.reply(mention.status, message) if message
        
      when /\[타로\]/
        message = TarotCommand.new(sender, TAROT_DATA, sheet).execute
        client.reply(mention.status, message) if message
        
      when /\[베팅\/(\d+)\]/
        amount = $1.to_i
        message = BetCommand.new(sender, amount, sheet).execute
        client.reply(mention.status, message) if message
        
      when /\[100D\]/
        message = DiceCommand.new(sender, 100).execute
        client.reply(mention.status, message) if message
        
      when /\[20D\]/
        message = DiceCommand.new(sender, 20).execute
        client.reply(mention.status, message) if message
        
      when /\[동전\]/
        message = CoinCommand.new(sender).execute
        client.reply(mention.status, message) if message
        
      when /\[YN\]/i
        message = YnCommand.new(sender).execute
        client.reply(mention.status, message) if message
        
      else
        puts "[무시됨] 알 수 없는 명령어: #{text}"
      end
      
    rescue => e
      puts "[오류] 명령어 처리 실패: #{e.message}"
      puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
    end
  end
end
