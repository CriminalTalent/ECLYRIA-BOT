# commands/bet_command.rb
class BetCommand
  def initialize(student_id, amount, sheet)
    @student_id = student_id
    @amount = amount
    @sheet = sheet
  end

  def execute
    player = @sheet.get_player(@student_id)
    return "학적부에 없는 학생이구나, 교수님께 가보렴." unless player

    if player["galleons"].to_i < 0
      return "지금은 갈레온이 마이너스 상태야… 베팅은 나중에 시도해보자꾸나!"
    end

    if @amount < 1 || @amount > 10
      return "얘야, 베팅은 1에서 10갈레온까지만 가능하단다~"
    end

    if player["galleons"].to_i < @amount
      return "갈레온이 부족하단다~ 가진 만큼만 걸 수 있어!"
    end

    multiplier = [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5].sample
    result = @amount * multiplier
    player["galleons"] += result

    return "\n#{@amount}갈레온의 #{multiplier:+}배, 현재 잔액 #{player["galleons"]}갈레온"
  end
end

