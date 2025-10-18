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

    # 카테고리가 "소모품"인지 확인
    is_consumable = item[:category].to_s == "소모품"

    # 소모품이면 제거
    if is_consumable
      inventory.delete_at(inventory.index(@item_name))
      @sheet_manager.update_user(@student_id, { items: inventory.join(",") })
      return "#{@item_name}을(를) 사용했어요! (소모되었습니다)"
    else
      return "#{@item_name}은(는) 소모품이 아니에요!"
    end
  end
end
