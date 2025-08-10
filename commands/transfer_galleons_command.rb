# commands/transfer_galleons_command.rb
class TransferGalleonsCommand
  def initialize(from_id, to_id, amount, sheet_manager)
    @from_id = from_id
    @to_id = to_id
    @amount = amount.to_i
    @sheet_manager = sheet_manager
  end

  def execute
    return "양도할 갈레온 수는 1 갈레온 이상이어야 한단다." if @amount <= 0

    from = @sheet_manager.get_player(@from_id)
    to   = @sheet_manager.get_player(@to_id)

    unless from
      puts "[DEBUG] 보내는 사람 찾을 수 없음: #{@from_id}"
      return "보내는 사람(#{@from_id}) 정보가 없단다!"
    end
    
    unless to
      puts "[DEBUG] 받는 사람 찾을 수 없음: #{@to_id}"
      return "받는 사람(#{@to_id}) 정보가 없단다!"
    end
    
    return "자기 자신에게는 갈레온을 양도할 수 없단다!" if @from_id == @to_id

    if from[:galleons].to_i < 0
      return "갈레온이 마이너스 상태라 양도는 불가능하단다."
    end

    if from[:galleons].to_i < @amount
      return "갈레온이 부족하단다. 가진 갈레온은 #{from[:galleons]}뿐이야."
    end

    # 양도 처리
    original_from_galleons = from[:galleons]
    original_to_galleons = to[:galleons]
    
    from[:galleons] = original_from_galleons - @amount
    to[:galleons] = original_to_galleons + @amount

    # 두 플레이어 모두 업데이트
    from_result = @sheet_manager.update_player(from)
    to_result = @sheet_manager.update_player(to)
    
    unless from_result && to_result
      puts "[ERROR] 갈레온 양도 업데이트 실패"
      # 롤백 시도
      from[:galleons] = original_from_galleons
      to[:galleons] = original_to_galleons
      return "갈레온 양도 처리 중 오류가 발생했습니다."
    end

    puts "[DEBUG] 갈레온 양도 완료: #{@from_id}(#{original_from_galleons}→#{from[:galleons]}) → #{@to_id}(#{original_to_galleons}→#{to[:galleons]})"

    return "#{@amount}갈레온을 #{@to_id}학생에게 양도했단다.\n현재 잔액 #{from[:galleons]}갈레온"
  end
end
