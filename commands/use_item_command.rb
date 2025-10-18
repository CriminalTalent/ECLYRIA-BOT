# ============================================
# commands/use_item_command.rb
# ============================================
class UseItemCommand
  def initialize(student_id, item_name, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @item_name = item_name.strip
    @sheet_manager = sheet_manager
  end

  def execute
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "어머, 손님이 누구시더라? 입학부터 하고 오세요~"
    end

    inventory = player[:items].to_s.split(",").map(&:strip)
    unless inventory.include?(@item_name)
      return "어? #{@item_name}은(는) 안 가지고 계신 것 같은데요?"
    end

    item = @sheet_manager.find_item(@item_name)
    unless item
      return "어머나, 그 물건 정보가 없네요?"
    end

    # E열 "사용 및 양도가능" 체크박스 확인
    # category 필드가 체크되어 있으면 소모품
    is_consumable_str = item[:category].to_s.upcase
    is_consumable = ["TRUE", "O", "YES", "Y"].include?(is_consumable_str)

    # 소모품이면 제거
    if is_consumable
      inventory.delete_at(inventory.index(@item_name))
      @sheet_manager.update_user(@student_id, { items: inventory.join(",") })
      return "#{@item_name}을(를) 사용했어요! (소모되었습니다)"
    else
      return "#{@item_name}은(는) 사용할 수 없는 아이템이에요!"
    end
  end
end
