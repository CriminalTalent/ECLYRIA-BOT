# commands/bet_command.rb
# encoding: UTF-8
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
      return "#{@student_id}(@#{@student_id})은(는) 학적부에 없어요~ 교수님께 가서 등록 먼저 하세요."
    end

    today = Date.today.to_s
    last_bet_date = user[:last_bet_date].to_s
    last_bet_count = user[:last_bet_count].to_i rescue 0

    # 오늘 베팅 횟수 계산
    if last_bet_date == today
      bet_count = last_bet_count
    else
      bet_count = 0
    end

    if bet_count >= MAX_BETS_PER_DAY
      return "#{@student_id}(@#{@student_id})은(는) 오늘은 이미 #{MAX_BETS_PER_DAY}번이나 베팅했어요~ 내일 다시 도전해보세요!"
    end

    galleons = user[:galleons].to_i
    if galleons < 0
      return "#{@student_id}(@#{@student_id})은(는) 갈레온이 마이너스 상태라 베팅이 불가능해요."
    end

    if @amount < 1 || @amount > 20
      return "베팅은 1에서 20갈레온까지만 가능해요~"
    end

    if galleons < @amount
      return "갈레온이 부족해요. 지금은 #{galleons}개밖에 없어요."
    end

    # 베팅 실행
    multiplier = [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5].sample
    result = @amount * multiplier
    new_galleons = galleons + result
    new_bet_count = bet_count + 1

    # 사용자 정보 업데이트
    update_result = @sheet_manager.update_user(@student_id, {
      galleons: new_galleons,
      last_bet_date: today,
      last_bet_count: new_bet_count
    })

    unless update_result
      puts "[ERROR] 베팅 결과 업데이트 실패"
      return "베팅 처리 중 오류가 났어요. 잠시 후 다시 시도해 주세요."
    end

    # 결과 메시지 생성 (문체만 수정)
    if new_galleons < 0
      "#{@student_id}(@#{@student_id})이(가) #{@amount}갈레온을 걸었어요!\n결과는 ×#{multiplier}배, #{result >= 0 ? "+" : ""}#{result}갈레온이에요.\n지금 주머니엔 0갈레온, 빚 #{new_galleons.abs}갈레온이 생겼어요... (오늘 #{new_bet_count}/#{MAX_BETS_PER_DAY}회)"
    else
      "#{@student_id}(@#{@student_id})이(가) #{@amount}갈레온을 걸었어요!\n결과는 ×#{multiplier}배, #{result >= 0 ? "+" : ""}#{result}갈레온이에요.\n지금 주머니엔 #{new_galleons}갈레온이에요~ (오늘 #{new_bet_count}/#{MAX_BETS_PER_DAY}회)"
    end
  end
end
