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
      return "하루 베팅은 3회까지만 가능하단다~ 내일 다시 도전해 보렴!"
    end
    
    galleons = user[:galleons].to_i
    if galleons < 0
      return "얘야, 갈레온이 마이너스 상태에서는 베팅이 불가능하단다."
    end
    
    if @amount < 1 || @amount > 20
      return "베팅은 1에서 20갈레온까지만 가능하단다~"
    end
    
    if galleons < @amount
      return "갈레온이 부족하단다. 가진 갈레온은 #{galleons}밖에 없구나."
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
      return "베팅 처리 중 오류가 발생했습니다."
    end
    
    # 결과 메시지 생성
    if new_galleons < 0
      return "베팅 결과: #{@amount} × #{multiplier} = #{result:+d}\n현재 갈레온 0 (빚 #{new_galleons.abs}갈레온 발생)"
    else
      return "베팅 결과: #{@amount} × #{multiplier} = #{result:+d}\n현재 갈레온 #{new_galleons}갈레온"
    end
  end
end
