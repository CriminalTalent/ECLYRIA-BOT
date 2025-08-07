# commands/tarot_command.rb
require "date"

class TarotCommand
  LUCKY_ITEMS = ["지팡이", "물약", "두루마리", "보석", "모자", "망토", "책", "열쇠"]
  LUCKY_COLORS = ["빨강", "파랑", "초록", "노랑", "보라", "주황", "하양", "검정"]
  LUCKY_PLACES = ["도서관", "정원", "탑", "호수", "숲", "광장", "교실", "기숙사"]

  def initialize(student_id, tarot_data, sheet)
    @student_id = student_id
    @tarot_data = tarot_data
    @sheet = sheet
  end

  def execute
    player = @sheet.get_player(@student_id)
    return "학적부에 없는 학생이구나, 교수님께 가보렴." unless player

    last_date = player[:last_tarot_date].to_s
    today = Date.today.to_s

    if last_date == today
      return "오늘은 이미 타로 카드를 뽑았단다~ 내일 다시 와줘!"
    end

    card = @tarot_data.keys.sample
    meaning = @tarot_data[card]
    lucky_item  = LUCKY_ITEMS.sample
    lucky_color = LUCKY_COLORS.sample
    lucky_place = LUCKY_PLACES.sample

    # 날짜 기록
    player[:last_tarot_date] = today
    @sheet.update_player(player)

    return <<~TEXT.strip
      오늘의 운세
      [#{card}]
      #{meaning}
      행운의 아이템: #{lucky_item}
      행운의 색: #{lucky_color}
      행운의 장소: #{lucky_place}
    TEXT
  end
end
