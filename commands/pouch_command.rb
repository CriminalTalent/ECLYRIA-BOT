# encoding: UTF-8
class PouchCommand
  MAX_LENGTH = 450

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 없어요~"
    end

    galleons = player[:galleons].to_i
    items_raw = player[:items].to_s.strip

    if items_raw.empty?
      items_display = "없음"
    else
      items_array = items_raw.split(",").map(&:strip)
      item_counts = Hash.new(0)
      items_array.each { |item| item_counts[item] += 1 }

      items_display = item_counts.map do |item, count|
        count > 1 ? "#{item} x#{count}" : item
      end.join(", ")
    end

    "@#{@student_id}\n갈레온: #{galleons}개\n아이템: #{items_display}"
  end
end
