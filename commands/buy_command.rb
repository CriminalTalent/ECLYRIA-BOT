# ============================================
# commands/buy_command.rb (최종 안정화 버전)
# ============================================

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

    return "구매 형식이 잘못되었어요. 예: 구매/빵" unless @item_name

    # -----------------------------------------
    # 1) 플레이어 조회
    # -----------------------------------------
    player = @sheet_manager.find_user(@student_id)
    unless player
      puts "[BUY] ERROR: player not found"
      return "#{@student_id}님은 아직 학적부에 등록되지 않았어요. 교수님께 가서 등록부터 하고 오세요."
    end

    galleons = player[:galleons].to_i
    inventory = player[:items].to_s.split(",").map(&:strip)

    # -----------------------------------------
    # 2) 아이템 정보 가져오기
    # -----------------------------------------
    item = @sheet_manager.find_item(@item_name)
    unless item
      puts "[BUY] ERROR: item not found"
      return "#{@item_name}? 그런 물건은 상점에 없어요."
    end
    
    # 랜덤 설명 처리 -------------------------------------
    description_raw = item[:description].to_s
    
    # 설명 내에 "A/B/C" 형태가 있으면 랜덤 선택
    description =
      if description_raw.include?("/")
        choices = description_raw.split("/").map(&:strip)
        choices.sample  # ← 여기서 랜덤 선택됨!
      else
        description_raw
      end
    
    # D열 판매가능 여부 (sellable 키)
    raw_flag = item[:sellable]
    sellable = (raw_flag == true || raw_flag.to_s.strip.upcase == "TRUE")
    
    unless sellable
      puts "[BUY] BLOCK: item not for sale (sellable=#{raw_flag.inspect})"
      return "#{@item_name}은(는) 지금은 판매하지 않는 물건이에요."
    end
    
    price = item[:price].to_i


    # -----------------------------------------
    # 3) 잔액 확인
    # -----------------------------------------
    if galleons < price
      puts "[BUY] FAIL: not enough galleons"
      return "갈레온이 부족해요. 지금은 #{galleons}개밖에 없어요."
    end

    # -----------------------------------------
    # 4) 구매 처리
    # -----------------------------------------
    new_galleons = galleons - price
    inventory << @item_name
    new_items = inventory.join(",")

    @sheet_manager.update_user(@student_id, {
      galleons: new_galleons,
      items: new_items
    })

    puts "[BUY] UPDATED: galleons=#{new_galleons}, items=#{new_items}"

    # -----------------------------------------
    # 5) 결과 메시지 (RP 톤)
    # -----------------------------------------
    "#{@item_name}을(를) 구매했어요. 남은 금액은 #{new_galleons}갈레온이에요."
  end
end
