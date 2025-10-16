# ============================================
# commands/dice_command.rb
# ============================================
class DiceCommand
  def initialize(student_id, sides)
    @student_id = student_id.gsub('@', '')
    @sides = sides
  end

  def execute
    return "#{rand(1..@sides)}"
  end
end
