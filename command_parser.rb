# command_parser.rb
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
    "THE EMPEROR" => "권위와 안정을 상징하는 카드입니다.",
    "THE HIEROPHANT" => "전통과 교육을 상징하는 카드입니다.",
    "THE LOVERS" => "사랑과 선택을 의미하는 카드입니다.",
    "THE CHARIOT" => "의지와 승리를 나타내는 카드입니다.",
    "STRENGTH" => "내면의 힘과 용기를 의미하는 카드입니다.",
    "THE HERMIT" => "내면의 성찰과 지혜를 나타내는 카드입니다.",
    "WHEEL OF FORTUNE" => "운명의 변화를 의미하는 카드입니다.",
    "JUSTICE" => "공정함과 균형을 상징하는 카드입니다.",
    "THE HANGED MAN" => "희생과 새로운 관점을 의미하는 카드입니다.",
    "DEATH" => "변화와 재탄생을 상징하는 카드입니다.",
    "TEMPERANCE" => "절제와 조화를 의미하는 카드입니다.",
    "THE DEVIL" => "유혹과 속박을 나타내는 카드입니다.",
    "THE TOWER" => "급작스러운 변화를 의미하는 카드입니다.",
    "THE STAR" => "희망과 영감을 상징하는 카드입니다.",
    "THE MOON" => "환상과 불안을 나타내는 카드입니다.",
    "THE SUN" => "기쁨과 성공을 의미하는 카드입니다.",
    "JUDGEMENT" => "심판과 재생을 상징하는 카드입니다.",
    "THE WORLD" => "완성과 성취를 의미하는 카드입니다."
  }

  def self.parse(mastodon_client, sheet_manager, mention)
    begin
      content = mention.status.content.gsub(/<[^>]*>/, '').strip
      sender_full = mention.account.acct
      
      # sender ID 정규화 (@domain 부분 제거)
      sender = sender_full.split('@').first
      
      puts "[상점봇] 처리 중: #{content} (from @#{sender_full} -> #{sender})"
      
      # 사용자 확인
      user = sheet_manager.get_player(sender)
      unless user
        puts "[무시] 학적부에 없는 사용자: #{sender}"
        return
      end

      # 명령어 라우팅
      case content
      when /\[구매\/(.+?)\]/
        item_name = $1.strip
        message = BuyCommand.new(sender, item_name, sheet_manager).execute
        mastodon_client.reply(mention.status, message) if message
        
      when /\[양도\/(.+?)\/@(.+?)\]/
        item_name = $1.strip
        receiver = $2.strip
        message = TransferItemCommand.new(sender, receiver, item_name, sheet_manager).execute
        mastodon_client.reply(mention.status, message) if message
        
      when /\[양도\/갈레온\/(\d+)\/@(.+?)\]/
        amount = $1.to_i
        receiver = $2.strip
        message = TransferGalleonsCommand.new(sender, receiver, amount, sheet_manager).execute
        mastodon_client.reply(mention.status, message) if message
        
      when /\[사용\/(.+?)\]/
        item_name = $1.strip
        message = UseItemCommand.new(sender, item_name, sheet_manager).execute
        mastodon_client.reply(mention.status, message) if message
        
      when /\[주머니\]/
        message = PouchCommand.new(sender, sheet_manager).execute
        mastodon_client.reply(mention.status, message) if message
        
      when /\[타로\]/
        message = TarotCommand.new(sender, TAROT_DATA, sheet_manager).execute
        mastodon_client.reply(mention.status, message) if message
        
      when /\[베팅\/(\d+)\]/
        amount = $1.to_i
        message = BetCommand.new(sender, amount, sheet_manager).execute
        mastodon_client.reply(mention.status, message) if message
        
      when /\[100D\]/
        message = DiceCommand.new(sender, 100).execute
        mastodon_client.reply(mention.status, message) if message
        
      when /\[20D\]/
        message = DiceCommand.new(sender, 20).execute
        mastodon_client.reply(mention.status, message) if message
        
      when /\[동전\]/
        message = CoinCommand.new(sender).execute
        mastodon_client.reply(mention.status, message) if message
        
      when /\[YN\]/i
        message = YnCommand.new(sender).execute
        mastodon_client.reply(mention.status, message) if message
        
      else
        puts "[무시] 인식되지 않은 명령어: #{content}"
      end
      
    rescue => e
      puts "[에러] 명령어 처리 실패: #{e.message}"
      puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
    end
  end
end
