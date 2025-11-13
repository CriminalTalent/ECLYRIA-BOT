# buy_command.rb (시트 구조에 완전 호환된 최신 버전)
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

    # 1) 플레이어 조회
    player = @sheet_manager.find_user(@student_id)
    unless player
      puts "[BUY] ERROR: player not found"
      return "#{@student_id}님은 아직 학적부에 등록되지 않았어요! 교수님께 가서 등록 먼저 하세요."
    end

    galleons = player[:galleons].to_i
    inventory = player[:items] ? player[:items].split(",") : []

    # 2) 아이템 정보 찾기
    item = @sheet_manager.find_item(@item_name)
    unless item
      puts "[BUY] ERROR: item not found"
      return "[에러] 해당 아이템을 찾을 수 없습니다: #{@item_name}"
    end

    # 판매 여부 체크
    unless item[:sellable]
      puts "[BUY] ERROR: item not sellable"
      return "[구매 불가] 이 아이템은 상점에서 판매되지 않습니다."
    end

    price = item[:price].to_i

    # 3) 잔액 체크
    if galleons < price
      puts "[BUY] FAIL: not enough galleons"
      return "[구매 실패] 보유 갈레온이 부족합니다. (현재 #{galleons}개)"
    end

    # 4) 인벤토리 추가
    inventory << @item_name
    new_items = inventory.join(",")

    # 5) 시트 업데이트
    update_ok = @sheet_manager.update_user(@student_id, {
      galleons: galleons - price,
      items: new_items
    })

    unless update_ok
      puts "[BUY] ERROR: update failed"
      return "[에러] 구매 처리 중 오류가 발생했습니다."
    end

    puts "[BUY] UPDATED: galleons=#{galleons - price}, items=#{new_items}"

    # 6) 성공 메시지
    "[구매 완료] #{@item_name}을(를) 구입했습니다! (남은 금액: #{galleons - price}갈레온)"
  end
end
