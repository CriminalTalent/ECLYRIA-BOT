# commands/bet_command.rb

require 'date'

class BetCommand
  MAX_BETS_PER_DAY = 3

  def initialize(student_id, amount, sheet)
    @student_id = student_id
    @amount = amount
    @sheet = sheet
  end

  def execute
    user = @sheet.get_player(@student_id)
    return "학적부에 없는 학생이구나, 교수님께 가보렴." unless user

    today = Date.today.to_s
    last_bet_date = user["마지막베팅일"].to_s
    bet_count = user["오늘베팅횟수"].to_i

    # 날짜가 다르면 베팅 횟수 리셋
    if last_bet_date != today
      bet_count = 0
    end

    if bet_count >= MAX_BETS_PER_DAY
      return "하루 베팅은 3회까지만 가능하단다~ 내일 다시 도전해 보렴!"
    end

    galleons = user["갈레온"].to_i
    if galleons < 0
      return "얘야, 갈레온이 마이너스 상태에서는 베팅이 불가능하단다."
    end

    if @amount < 1 || @amount > 20
      return "베팅은 1에서 20갈레온까지만 가능하단다~"
    end

    if galleons < @amount
      return "갈레온이 부족하단다. 가진 갈레온은 #{galleons}밖에 없구나."
    end

    multiplier = [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5].sample
    result = @amount * multiplier
    galleons += result

    user["갈레온"] = galleons
    user["마지막베팅일"] = today
    user["오늘베팅횟수"] = bet_count + 1

    if galleons < 0
      return "베팅 결과: #{@amount} × #{multiplier} = #{result}\n현재 갈레온 0 (빚 #{galleons.abs}갈레온 발생)"
    else
      return "베팅 결과: #{@amount} × #{multiplier} = #{result}\n현재 갈레온 #{galleons}갈레온"
    end
  end
end
