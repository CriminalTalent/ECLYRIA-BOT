
# commands/coin_command.rb
class CoinCommand
  def initialize(student_id)
    @student_id = student_id
  end

  def execute
    result = ["앞면", "뒷면"].sample
    return "#{result}"
  end
end
