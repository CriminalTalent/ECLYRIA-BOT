# commands/bet_command.rb
# encoding: UTF-8
require 'date'

class BetCommand
  MAX_BETS_PER_DAY = 3

  def initialize(student_id, amount, sheet_manager)
    @student_id    = student_id       # 예: "Test"
    @amount        = amount.to_i
    @sheet_manager = sheet_manager
  end

  def execute
    # 1) 사용자 정보 가져오기 (get_player → find_user 로 변경)
    user = @sheet_manager.find_user(@student_id)
    unless user
      puts "[DEBUG] 플레이어 찾을 수 없음: #{@student_id}"
      return "#{@student_id}(@#{@student_id})은(는) 학적부에 없어요~ 교수님께 가서 등록 먼저 하세요."
    end

    # 2) 오늘 날짜 / 마지막 베팅 정보 -------------------------
    today          = Date.today.to_s
    last_bet_date  = user[:last_bet_date].to_s      rescue ""
    last_bet_count = user[:last_bet_count].to_i     rescue 0

    # 오늘 베팅 횟수 계산
    bet_count =
      if last_bet_date == today
        last_bet_count
      else
        0
      end

    if bet_count >= MAX_BETS_PER_DAY
      return "#{@student_id}(@#{@student_id})은(는) 오늘은 이미 #{MAX_BETS_PER_DAY}번이나 베팅했어요~ 내일 다시 도전해보세요!"
    end

    # 3) 잔액 / 베팅 금액 검증 -------------------------------
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

    # 4) 베팅 실행 ------------------------------------------
    multiplier = [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5].sample
    result      = @amount * multiplier
    new_galleons = galleons + result
    new_bet_count = bet_count + 1

    # 5) 사용자 정보 업데이트 (잔액 + 마지막베팅날짜/횟수) ----
    update_result = @sheet_manager.update_user(
      @student_id,
      {
        galleons:        new_galleons,
        last_bet_date:   today,
        last_bet_count:  new_bet_count
      }
    )

    unless update_result
      puts "[ERROR] 베팅 결과 업데이트 실패"
      return "베팅 처리 중 오류가 났어요. 잠시 후 다시 시도해 주세요."
    end

    # 6) 결과 메시지 ----------------------------------------
    if new_galleons < 0
      "#{@student_id}(@#{@student_id})이(가) #{@amount}갈레온을 걸었어요!\n" \
      "결과는 ×#{multiplier}배, #{result >= 0 ? '+' : ''}#{result}갈레온이에요.\n" \
      "지금 주머니엔 0갈레온, 빚 #{new_galleons.abs}갈레온이 생겼어요... " \
      "(오늘 #{new_bet_count}/#{MAX_BETS_PER_DAY}회)"
    else
      "#{@student_id}(@#{@student_id})이(가) #{@amount}갈레온을 걸었어요!\n" \
      "결과는 ×#{multiplier}배, #{result >= 0 ? '+' : ''}#{result}갈레온이에요.\n" \
      "지금 주머니엔 #{new_galleons}갈레온이에요~ " \
      "(오늘 #{new_bet_count}/#{MAX_BETS_PER_DAY}회)"
    end
  end
end
