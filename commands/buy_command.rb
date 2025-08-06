# commands/buy_command.rb
class BuyCommand
  def initialize(student_id, item_name, sheet)
    @student_id = student_id
    @item_name = item_name
    @sheet = sheet
  end

  def execute
    player = @sheet.get_player(@student_id)
    return "학적부에 학생이 없는데? 교수님에게 가보렴." unless player

    if player["debt"].to_i > 0
      return "빚이 있으면 상점에서 물건을 살 수 없단다. 먼저 갚고 오렴."
    end

    item = @sheet.get_item(@item_name)
    return "‘#{@item_name}’이라는 아이템은 상점에 없단다!" unless item

    price = item["price"].to_i
    galleons = player["galleons"].to_i

    if galleons < price
      return "갈레온이 부족하단다. 보유 갈레온 #{galleons}"
    end

       # 구매 처리
    player["galleons"] = galleons - price
    inventory = player["items"].to_s.split(",").map(&:strip)
    inventory << @item_name
    player["items"] = inventory.join(",")

    # 시트에 반영
    @sheet.update_player(@student_id, player)

    return "#{@item_name}을(를) #{price}갈레온에 구매했단다. 현재 잔액: #{player["galleons"]}갈레온"
  end
end
