# commands/tarot_command.rb
require "date"

class TarotCommand
  LUCKY_ITEMS = ["지팡이", "물약", "두루마리", "보석", "모자", "망토", "책", "열쇠", "목걸이", "반지", "수정구", "깃털펜"]
  LUCKY_COLORS = ["빨강", "파랑", "초록", "노랑", "보라", "주황", "하양", "검정", "은색", "금색", "분홍", "갈색"]
  LUCKY_PLACES = ["도서관", "정원", "탑", "호수", "숲", "광장", "교실", "기숙사", "식당", "복도", "계단", "발코니"]

  def initialize(student_id, tarot_data, sheet_manager)
    @student_id = student_id
    @tarot_data = tarot_data
    @sheet_manager = sheet_manager
  end

  def execute
    player = @sheet_manager.get_player(@student_id)
    unless player
      puts "[DEBUG] 플레이어 찾을 수 없음: #{@student_id}"
      return "학적부에 없는 학생이구나, 교수님께 가보렴."
    end

    # 타로카드 뽑기 (제한 없음)
    card = @tarot_data.keys.sample
    meaning = @tarot_data[card]
    lucky_item  = LUCKY_ITEMS.sample
    lucky_color = LUCKY_COLORS.sample
    lucky_place = LUCKY_PLACES.sample

    # 마지막 타로 날짜만 기록 (제한 목적이 아닌 통계 목적)
    today = Date.today.to_s
    player[:last_tarot_date] = today
    update_result = @sheet_manager.update_player(player)
    unless update_result
      puts "[ERROR] 타로 날짜 업데이트 실패"
      return "타로 카드 기록 중 오류가 발생했습니다."
    end

    puts "[DEBUG] 타로 카드 뽑기 완료: #{@student_id} - #{card}"

    return <<~TEXT.strip
 
      [#{card}]
      #{meaning}
      
      행운의 아이템: #{lucky_item}
      행운의 색: #{lucky_color}
      행운의 장소: #{lucky_place}
      
    TEXT
  end
end
