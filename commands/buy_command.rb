# ============================================
# commands/buy_command.rb
# ============================================
class BuyCommand
  def initialize(student_id, item_name, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @item_name = item_name.strip
    @sheet_manager = sheet_manager
  end

  def execute
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "어머, 우리 가게 처음이시네? 먼저 교수님한테 가서 입학부터 하고 와요~"
    end

    if player[:galleons].to_i < 0
      return "어머머, 빚이 있으면 안 돼요! 갈레온부터 갚고 오세요~"
    end

    item = @sheet_manager.find_item(@item_name)
    unless item
      return "어머, 그건 우리 가게에 없는데요? 다른 거 보실래요?"
    end

    # 판매 여부 확인: "O", "TRUE", "true", true 모두 허용
    for_sale = item[:for_sale].to_s.upcase
    unless ["O", "TRUE", "YES", "Y"].include?(for_sale)
      return "아이고, 그건 지금 안 팔아요~ 미안해요!"
    end

    price = item[:price].to_i
    galleons = player[:galleons].to_i

    if galleons < price
      return "어머나, 갈레온이 #{price - galleons}개 부족한데요? 지금 #{galleons}개 가지고 계시잖아요~"
    end

    # 구매 처리
    new_galleons = galleons - price
    inventory = player[:items].to_s.split(",").map(&:strip)
    inventory << @item_name

    @sheet_manager.update_user(@student_id, {
      galleons: new_galleons,
      items: inventory.join(",")
    })

    return "#{@item_name} 여기 있어요! #{price}갈레온이에요~ 남은 돈은 #{new_galleons}갈레온이고요!"
  end
end
