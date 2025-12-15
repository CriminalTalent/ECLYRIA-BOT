# commands/pickup_command.rb
# encoding: UTF-8

class PickupCommand
  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[PICKUP] START user=#{@student_id}"
    
    # 플레이어 확인
    player = @sheet_manager.find_user(@student_id)
    unless player
      puts "[PICKUP] ERROR: player not found (@#{@student_id})"
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    current_galleons = player[:galleons].to_i
    puts "[PICKUP] 현재 갈레온: #{current_galleons}"

    # 50% 확률로 양수 또는 음수 그룹 선택
    if rand < 0.5
      # 양수: 1~5 갈레온
      amount = rand(1..5)
      message_type = "주웠다"
    else
      # 음수: -1~-10 갈레온
      amount = -rand(1..10)
      message_type = "빼앗겼다"
    end

    # 새 갈레온 계산
    new_galleons = current_galleons + amount

    puts "[PICKUP] 금액: #{amount}, 새 갈레온: #{new_galleons}"

    # 업데이트
    @sheet_manager.update_user(@student_id, {
      galleons: new_galleons
    })

    # 결과 메시지
    if amount > 0
      message = "@#{@student_id} 갈레온을 주웠다! +#{amount}G\n"
    else
      message = "@#{@student_id} 양아치가 빼앗아갔다! #{amount}G\n"
    end
    message += "현재 잔액: #{new_galleons} G"

    puts "[PICKUP] SUCCESS: #{message}"
    return message
  end
end
