# ============================================
# commands/yn_command.rb
# ============================================
class YnCommand
  def initialize(student_id)
    @student_id = student_id.gsub('@', '')
  end

  def execute
    return ["YES", "NO", "Maybe", "Why not?"].sample
  end
end
