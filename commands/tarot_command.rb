require "date"

class TarotCommand
  def initialize(student_id, tarot_data, sheet)
    @student_id = student_id
    @tarot_data = tarot_data
    @sheet = sheet
  end

  def execute
    player = @sheet.get_player(@student_id)
    return "학적부에 없는 학생이구나, 교수님께 가보렴." unless player

    last_date = player["last_tarot_date"].to_s
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
    player["last_tarot_date"] = today

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

