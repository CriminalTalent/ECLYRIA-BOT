# commands/pouch_command.rb
class PouchCommand
  def initialize(student_id, sheet_manager)
    @student_id = student_id
    @sheet_manager = sheet_manager
  end

  def execute
    player = @sheet_manager.get_player(@student_id)
    unless player
      puts "[DEBUG] 플레이어 찾을 수 없음: #{@student_id}"
      return "학적부에 없는 학생이구나, 교수님께 가보렴."
    end

    galleons = player[:galleons]
    items = player[:items].to_s.strip
    
    # 갈레온 표시 (부채 상태 고려)
    galleon_display = if galleons < 0
      "#{galleons} (빚: #{galleons.abs}갈레온)"
    else
      "#{galleons}"
    end

    if items.empty?
      return <<~TEXT.strip
        이름: #{player[:name]}
        갈레온: #{galleon_display}
        소지품: 없음
      TEXT
    end

    # 아이템 목록 정리 (중복 제거 및 개수 계산)
    item_list = items.split(",").map(&:strip)
    item_counts = Hash.new(0)
    item_list.each { |item| item_counts[item] += 1 }
    
    formatted_items = item_counts.map do |item, count|
      count > 1 ? "#{item} x#{count}" : item
    end.join(", ")

    return <<~TEXT.strip
      이름: #{player[:name]}
      갈레온: #{galleon_display}
      소지품: #{formatted_items}
    TEXT
  end
end
