# ============================================
# commands/buy_command.rb (랜덤 메시지 기능 포함 완전판)
# ============================================
# encoding: UTF-8

class BuyCommand
  def initialize(student_id, item_name, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @item_name = item_name.strip
    @sheet_manager = sheet_manager
  end

  # --------------------------------------------
  # "/" 로 구분된 설명에서 랜덤 문장 뽑기
  # --------------------------------------------
  def pick_random_message(description)
    return "" if description.nil? || description.strip.empty?

    list = description.split("/").map(&:strip)
    list.reject!(&:empty?)
    return "" if list.empty?

    list.sample
  end

  def execute
    # --------------------------------------------
    # 1) 플레이어 정보 확인
    # --------------------------------------------
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "#{@student_id}(@#{@student_id})은(는) 아직 학생 등록이 안 되어 있어요~ 교수님께 가서 입학 먼저 하고 오세요!"
    end

    if player[:galleons].to_i < 0
      return "#{@student_id}(@#{@student_id})은(는) 빚이 있어서 구매가 안 돼요! 갈레온부터 갚고 오세요~"
    end

    # --------------------------------------------
    # 2) 아이템 정보 확인
    # --------------------------------------------
    item = @sheet_manager.find_item(@item_name)
    unless item
      return "#{@item_name}? 그건 우리 가게엔 없어요~ 다른 걸 한번 골라보세요!"
    end

    # 판매 여부: O, TRUE, YES, Y 허용
    for_sale = item[:for_sale].to_s.upcase
    unless ["O", "TRUE", "YES", "Y"].include?(for_sale)
      return "#{@item_name}은(는) 지금 판매 중이 아니에요~ 다음에 다시 찾아주세요!"
    end

    price = item[:price].to_i
    galleons = player[:galleons].to_i

    # --------------------------------------------
    # 3) 잔액 확인
    # --------------------------------------------
    if galleons < price
      return "#{@student_id}(@#{@student_id})은(는) 갈레온이 #{price - galleons}개 부족해요~ 지금 가진 건 #{galleons}개뿐이에요."
    end

    # --------------------------------------------
    # 4) 구매 처리
    # --------------------------------------------
    new_galleons = galleons - price
    inventory = player[:items].to_s.split(",").map(&:strip)
    inventory << @item_name

    @sheet_manager.update_user(@student_id, {
      galleons: new_galleons,
      items: inventory.join(",")
    })

    # --------------------------------------------
    # 5) 랜덤 설명 메시지 선택
    # --------------------------------------------
    random_msg = pick_random_message(item[:description])

    # 설명이 없으면 기본 멘트 출력
    if random_msg.empty?
      return "#{@student_id}(@#{@student_id})이(가) #{@item_name}을 샀어요! #{price}갈레온이에요~ 남은 돈은 #{new_galleons}갈레온이에요."
    else
      return "#{@student_id}(@#{@student_id})이(가) #{@item_name}을 샀어요!\n#{random_msg}"
    end
  end
end
