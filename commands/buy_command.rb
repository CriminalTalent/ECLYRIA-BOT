# commands/buy_command.rb
class BuyCommand
  def initialize(student_id, item_name, sheet_manager)
    @student_id = student_id
    @item_name = item_name.strip
    @sheet_manager = sheet_manager
  end

  def execute
    player = @sheet_manager.get_player(@student_id)
    unless player
      puts "[DEBUG] 플레이어 찾을 수 없음: #{@student_id}"
      return "학적부에 없는 학생이구나, 교수님께 가보렴."
    end

    if player[:galleons].to_i < 0
      return "갈레온이 마이너스 상태라 구매는 불가능하단다… 먼저 빚을 갚고 오렴!"
    end

    item = @sheet_manager.get_item(@item_name)
    unless item
      puts "[DEBUG] 아이템 찾을 수 없음: #{@item_name}"
      return nil  # 아이템 없음 → 조용히 무시
    end

    unless item[:purchasable]
      puts "[DEBUG] 구매 불가 아이템: #{@item_name}"
      return nil  # 구매 불가 아이템 → 조용히 무시
    end

    price = item[:price].to_i
    galleons = player[:galleons].to_i

    if galleons < price
      return "갈레온이 부족하단다. 네가 가진 갈레온은 #{galleons} 이야."
    end

    # 갈레온 차감 및 아이템 추가
    player[:galleons] = galleons - price
    inventory = player[:items].to_s.split(",").map(&:strip)
    inventory << @item_name
    player[:items] = inventory.join(",")

    # 시트 업데이트
    update_result = @sheet_manager.update_player(player)
    unless update_result
      puts "[ERROR] 플레이어 업데이트 실패"
      return "구매 처리 중 오류가 발생했습니다."
    end

    return "#{@item_name}을(를) #{price}갈레온에 구매했단다. 남은 갈레온은 #{player[:galleons]}갈레온 이란다."
  end
end
