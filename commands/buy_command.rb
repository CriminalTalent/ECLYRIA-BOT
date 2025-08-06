# commands/buy_command.rb
class BuyCommand
  def initialize(student_id, item_name, sheet)
    @student_id = student_id
    @item_name = item_name.strip
    @sheet = sheet
  end

  def execute
    player = @sheet.get_player(@student_id)
    return "학적부에 없는 학생이구나, 교수님께 가보렴." unless player

    if player["galleons"].to_i < 0
      return "갈레온이 마이너스 상태라 구매는 불가능하단다… 먼저 빚을 갚고 오렴!"
    end

    item = @sheet.get_item(@item_name)
    return nil unless item  # 아이템 없음 → 조용히 무시

    unless item["구매가능"].to_s.strip.downcase == "true"
      return nil  # 구매 불가 아이템 → 조용히 무시
    end

    price = item["price"].to_i
    galleons = player["galleons"].to_i

    if galleons < price
      return "갈레온이 부족하단다. 네가 가진 갈레온은 #{galleons} 이야."
    end

    # 갈레온 차감 및 아이템 추가
    player["galleons"] = galleons - price
    inventory = player["items"].to_s.split(",").map(&:strip)
    inventory << @item_name
    player["items"] = inventory.join(",")

    return "#{@item_name}을(를) #{price}갈레온에 구매했단다. 남은 갈레온은 #{player["galleons"]}갈레온 이란다."
  end
end
