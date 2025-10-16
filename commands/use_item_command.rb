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

    item = @sheet_manager.get_item(@item_name)
    unless item
      return "어머나, 그 물건 정보가 없네요?"
    end

    unless item[:usable]
      return "아이고, 그건 사용하는 게 아니에요!"
    end

    # 소모품이면 제거
    if item[:consumable]
      inventory.delete(@item_name)
      @sheet_manager.update_user(@student_id, { items: inventory.join(",") })
    end

    effect = item[:effect].to_s.strip
    effect = "#{@item_name} 사용했어요!" if effect.empty?

    return effect
  end
end
