# buy_command.rb
class BuyCommand
  def initialize(content, student_id, sheet_manager)
    @content = content
    @student_id = student_id
    @sheet_manager = sheet_manager
    parse
  end

  def parse
    # 예: [구매/온갖 맛이 나는 젤리]
    match = @content.match(/\[구매\/(.+?)\]/)
    @item_name = match[1].strip if match
  end

  def execute
    puts "[BUY] START user=#{@student_id}, item=#{@item_name}"

    return "[알림] 구매 형식이 올바르지 않습니다. 예: [구매/빵]" unless @item_name

    # 1) 유저 찾기
    player = @sheet_manager.find_user(@student_id)
    unless player
      puts "[BUY] ERROR: player not found"
      return "[에러] 플레이어 정보를 찾을 수 없습니다."
    end
    puts "[BUY] FOUND PLAYER: #{player.inspect}"

    # 유저 정보
    row = player[:row]
    galleons = player[:galleons].to_i
    inventory = player[:items] ? player[:items].split(",") : []

    # 2) 아이템 찾기
    item = @sheet_manager.find_item(@item_name)
    unless item
      puts "[BUY] ERROR: item not found"
      return "[에러] 해당 아이템을 찾을 수 없습니다: #{@item_name}"
    end
    puts "[BUY] FOUND ITEM: #{item.inspect}"

    price = item[:price].to_i

    # 3) 돈이 부족한지 체크
    if galleons < price
      puts "[BUY] FAIL: not enough galleons (#{galleons} < #{price})"
      return "[구매 실패] 보유 갈레온이 부족합니다."
    end

    # 4) 인벤토리 추가
    inventory << @item_name

    # 5) 시트 업데이트
    new_galleons = galleons - price
    @sheet_manager.update_user(row, new_galleons, inventory.join(","))

    puts "[BUY] UPDATED: galleons=#{new_galleons}, items=#{inventory.join(",")}"

    # 6) 성공 메시지
    "[구매 완료] #{@item_name}을(를) 구입했습니다! (남은 금액: #{new_galleons}갈레온)"
  end
end
