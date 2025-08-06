# commands/buy_command.rb
class BuyCommand
  def initialize(student_id, item_name, sheet)
    @student_id = student_id
    @item_name = item_name
    @sheet = sheet
  end

  def execute
    player = @sheet.get_player(@student_id)
    return "등록된 플레이어가 아니란다. 먼저 등록해줘야 해!" unless player

    if player["galleons"].to_i < 0
      return "갈레온이 마이너스 상태라 구매는 불가능하단다… 먼저 빚을 갚고 오렴!"
    end

    item = @sheet.get_item(@item_name)
    return "‘#{@item_name}’이라는 아이템은 상점에 없단다!" unless item

    price = item["price"].to_i
    galleons = player["galleons"].to_i

    if galleons < price
      return "갈레온이 부족하단다. 가진 돈: #{galleons}, 필요한 돈: #{price}"
    end

    # 갈레온 차감 및 아이템 추가
    player["galleons"] = galleons - price
    inventory = player["items"].to_s.split(",").map(&:strip)
    inventory << @item_name
    player["items"] = inventory.join(",")

    return "#{@item_name}을(를) #{price}갈레온에 구매했단다. 현재 잔액: #{player["galleons"]}갈레온"
  end
end
