# ============================================
# commands/yn_command.rb
# ============================================
# encoding: UTF-8
class YnCommand
  def initialize(student_id)
    @student_id = student_id.gsub('@', '')
  end

  def execute
    # 단답형 응답: YES / NO / Maybe / Why not?
    return ["YES", "NO", "Maybe", "Why not?"].sample
  end
end
