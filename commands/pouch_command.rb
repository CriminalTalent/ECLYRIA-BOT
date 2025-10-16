# ============================================
# commands/pouch_command.rb
# ============================================
class PouchCommand
  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "어머, 손님이 누구시더라? 입학부터 하고 오세요~"
    end

    galleons = player[:galleons].to_i
    items = player[:items].to_s.strip
    items = "없음" if items.empty?

    if galleons < 0
      return "갈레온: 0 (빚 #{galleons.abs})\n소지품: #{items}"
    else
      return "갈레온: #{galleons}\n소지품: #{items}"
    end
  end
end
