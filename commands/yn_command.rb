# commands/yn_command.rb

class YnCommand
  def initialize(student_id)
    @student_id = student_id
  end

  def execute
    ["YES", "NO", "Maybe", "Why not?"].sample
  end
end
