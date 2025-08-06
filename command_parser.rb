# command_parser.rb
require_relative './commands/buy_command'
require_relative './commands/transfer_item_command'
require_relative './commands/transfer_galleons_command'
require_relative './commands/pouch_command'
require_relative './commands/use_item_command'
require_relative './commands/tarot_command'
require_relative './commands/bet_command'
require_relative './commands/dice_command'
require_relative './commands/coin_command'

class CommandParser
  def initialize(student_id, text, sheet_manager)
    @student_id = student_id
    @text = text.strip
    @sheet = sheet_manager
  end

  def parse
    case @text
    when /^구매\/(.+)$/
      item_name = $1.strip
      return BuyCommand.new(@student_id, item_name, @sheet).execute

    when /^양도\/(.+)\/@(.+)$/
      item_name, to_id = $1.strip, $2.strip
      return TransferItemCommand.new(@student_id, "@#{to_id}", item_name, @sheet).execute

    when /^양도\/갈레온\/@(.+)\/(\d+)$/
      to_id, amount = $1.strip, $2.to_i
      return TransferGalleonsCommand.new(@student_id, "@#{to_id}", amount, @sheet).execute

    when /^주머니$/
      return PouchCommand.new(@student_id, @sheet).execute

    when /^사용\/(.+)$/
      item_name = $1.strip
      return UseItemCommand.new(@student_id, item_name, @sheet).execute

    when /^타로$/
      return TarotCommand.new(@student_id).execute

    when /^베팅\/(\d+)$/
      amount = $1.to_i
      return BetCommand.new(@student_id, amount, @sheet).execute

    when /^(\d{1,3})D$/
      max = $1.to_i
      return DiceCommand.new(@student_id, max).execute

    when /^동전$/
      return CoinCommand.new(@student_id).execute

    else
      return "알 수 없는 명령어입니다. 올바른 형식으로 다시 입력해 주세요!"
    end
  end
end
