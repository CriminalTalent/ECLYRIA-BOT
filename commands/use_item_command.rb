# ============================================
# commands/use_item_command.rb
# ============================================
# encoding: UTF-8
class UseItemCommand
  def initialize(student_id, item_name, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @item_name = item_name.strip
    @sheet_manager = sheet_manager
  end

  def execute
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "#{@student_id}(@#{@student_id})은(는) 아직 학생 등록이 안 되어 있어요~ 교수님께 가서 입학 먼저 하고 오세요!"
    end

    inventory = player[:items].to_s.split(",").map(&:strip)
    unless inventory.include?(@item_name)
      return "#{@student_id}(@#{@student_id})은(는) #{@item_name}을(를) 가지고 있지 않아요~"
    end

    item = @sheet_manager.find_item(@item_name)
    unless item
      return "#{@item_name}? 그런 물건 정보는 없네요~"
    end

    # E열 "사용 및 양도가능" 체크박스 확인
    is_consumable_str = item[:category].to_s.upcase
    is_consumable = ["TRUE", "O", "YES", "Y"].include?(is_consumable_str)

    unless is_consumable
      return "#{@item_name}은(는) 사용할 수 없는 아이템이에요~"
    end

    # 소모품이면 제거
    inventory.delete_at(inventory.index(@item_name))
    @sheet_manager.update_user(@student_id, { items: inventory.join(",") })

    # B열 설명 출력
    description = item[:description].to_s.strip
    if description.empty?
      return "#{@student_id}(@#{@student_id})이(가) #{@item_name}을(를) 사용했어요!"
    else
      return "#{@student_id}(@#{@student_id})이(가) #{@item_name}을(를) 사용했어요!\n#{description}"
    end
  end
end
