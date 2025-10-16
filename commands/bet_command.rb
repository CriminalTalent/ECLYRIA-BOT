# commands/bet_command.rb
require 'date'

class BetCommand
  MAX_BETS_PER_DAY = 3
  
  def initialize(student_id, amount, sheet_manager)
    @student_id = student_id
    @amount = amount
    @sheet_manager = sheet_manager
  end
  
  def execute
    user = @sheet_manager.get_player(@student_id)
    unless user
      puts "[DEBUG] 플레이어 찾을 수 없음: #{@student_id}"
      return "학적부에 없는 학생이구나, 교수님께 가보렴."
    end
    
    today = Date.today.to_s
    last_bet_date = user[:last_bet_date].to_s
    bet_count = user[:bet_count].to_i
    
    # 날짜가 다르면 베팅 횟수 리셋
    if last_bet_date != today
      bet_count = 0
    end
    
    if bet_count >= MAX_BETS_PER_DAY
      return "얘야, 오늘은 이미 3번이나 베팅했구나! 내일 다시 와보렴."
    end
    
    galleons = user[:galleons].to_i
    if galleons < 0
      return "갈레온이 마이너스일 때는 베팅할 수 없단다. 먼저 빚을 갚고 오렴."
    end
    
    if @amount < 1 || @amount > 20
      return "얘야, 베팅은 1갈레온에서 20갈레온 사이로만 할 수 있단다."
    end
    
    if galleons < @amount
      return "갈레온이 모자라는구나. 지금 가진 건 #{galleons}갈레온뿐이란다."
    end
    
    # 베팅 실행
    multiplier = [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5].sample
    result = @amount * multiplier
    new_galleons = galleons + result
    
    # 사용자 정보 업데이트
    user[:galleons] = new_galleons
    user[:last_bet_date] = today
    user[:bet_count] = bet_count + 1
    
    update_result = @sheet_manager.update_player(user)
    unless update_result
      puts "[ERROR] 베팅 결과 업데이트 실패"
      return "얘야, 무언가 문제가 생겼구나. 다시 시도해보렴."
    end
    
    # 결과 메시지 생성
    if new_galleons < 0
      return "오호! #{@amount} × #{multiplier} = #{result:+d}갈레온이구나.\n지금 갈레온은 0이고, #{new_galleons.abs}갈레온의 빚이 생겼단다."
    else
      return "오호! #{@amount} × #{multiplier} = #{result:+d}갈레온이구나.\n이제 #{new_galleons}갈레온을 가지고 있단다."
    end
  end
end
