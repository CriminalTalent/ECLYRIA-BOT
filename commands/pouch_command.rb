# commands/pouch_command.rb
class PouchCommand
  MAX_LENGTH = 450  # 마스토돈 글자 수 제한 (여유 있게)

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "학적부에 없는 학생이구나, 교수님께 가보렴."
    end

    galleons = player[:galleons].to_i
    items_raw = player[:items].to_s.strip

    # 아이템 중복 카운트
    if items_raw.empty?
      items_display = "없음"
    else
      items_array = items_raw.split(",").map(&:strip)
      item_counts = Hash.new(0)
      items_array.each { |item| item_counts[item] += 1 }
      
      # "아이템명 x개" 형식으로 표시
      items_display = item_counts.map do |item, count|
        count > 1 ? "#{item} x#{count}" : item
      end.join(", ")
    end

    # 기본 메시지 구성
    base_message = "갈레온: #{galleons}개\n아이템: "
    
    # 글자 수 체크 및 분할
    messages = []
    current_message = base_message.dup
    
    if (base_message + items_display).length <= MAX_LENGTH
      # 한 번에 전송 가능
      return base_message + items_display
    else
      # 여러 메시지로 분할
      item_list = item_counts.map do |item, count|
        count > 1 ? "#{item} x#{count}" : item
      end
      
      messages << base_message
      
      temp_items = []
      item_list.each do |item_str|
        test_line = (temp_items + [item_str]).join(", ")
        
        if test_line.length > MAX_LENGTH
          # 현재까지 모은 아이템 출력
          messages << temp_items.join(", ") unless temp_items.empty?
          temp_items = [item_str]
        else
          temp_items << item_str
        end
      end
      
      # 마지막 남은 아이템
      messages << temp_items.join(", ") unless temp_items.empty?
      
      # 첫 메시지에 아이템 시작
      messages[0] += messages[1]
      messages.shift
      
      return messages
    end
  end
end
