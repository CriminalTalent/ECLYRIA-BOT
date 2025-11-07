# ============================================
# commands/coin_command.rb
# ============================================
# encoding: UTF-8
class CoinCommand
  def initialize(student_id)
    @student_id = student_id.gsub('@', '')
  end

  def execute
    return ["앞면", "뒷면"].sample
  end
end
