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
    # -----------------------------------------
    # 1) 플레이어 정보 확인
    # -----------------------------------------
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "#{@student_id}(@#{@student_id})은(는) 아직 학생 등록이 안 되어 있어요~ 교수님께 가서 입학 먼저 하고 오세요!"
    end

    inventory = player[:items].to_s.split(",").map(&:strip)

    unless inventory.include?(@item_name)
      return "#{@item_name}… 그건 지금 주머니 안에 없어요."
    end

    # -----------------------------------------
    # 2) 아이템 정보 확인
    # -----------------------------------------
    item = @sheet_manager.find_item(@item_name)
    unless item
      return "#{@item_name}? 그런 물건 정보는 찾을 수 없어요."
    end

    # 시트 E열: 사용/양도 가능
    can_use = item[:can_use].to_s.strip.upcase == "TRUE"

    unless can_use
      return "#{@item_name}은(는) 사용하는 물건이 아니에요~"
    end

    # -----------------------------------------
    # 3) 인벤토리에서 제거
    # -----------------------------------------
    inventory.delete_at(inventory.index(@item_name))
    @sheet_manager.update_user(@student_id, {
      items: inventory.join(",")
    })

    # -----------------------------------------
    # 4) 설명 랜덤 출력 기능
    # -----------------------------------------
    raw_desc = item[:description].to_s.strip

    if raw_desc.empty?
      desc = nil
    else
      parts = raw_desc.include?("/") ? raw_desc.split("/").map(&:strip) : [raw_desc]
      desc = parts.sample
    end

    # -----------------------------------------
    # 5) 결과 출력 (RP 톤)
    # -----------------------------------------
    if desc
      return "#{@student_id}(@#{@student_id})이(가) #{item[:name]}을(를) 사용했어요.\n#{desc}"
    else
      return "#{@student_id}(@#{@student_id})이(가) #{item[:name]}을(를) 사용했어요!"
    end
  end
end
