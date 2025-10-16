# ============================================
# commands/coin_command.rb
# ============================================
class CoinCommand
  def initialize(student_id)
    @student_id = student_id.gsub('@', '')
  end

  def execute
    return ["앞", "뒤"].sample
  end
end
