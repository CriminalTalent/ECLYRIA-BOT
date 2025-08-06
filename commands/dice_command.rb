# commands/dice_command.rb
class DiceCommand
  def initialize(student_id, max)
    @student_id = student_id
    @max = max.to_i
  end

  def execute
    if @max < 2 || @max > 100
      return "주사위는 2 이상 100 이하 숫자까지만 가능하단다~"
    end

    result = rand(1..@max)
    return "#{result}"
  end
end

