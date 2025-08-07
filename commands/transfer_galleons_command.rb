# commands/transfer_galleons_command.rb
class TransferGalleonsCommand
  def initialize(from_id, to_id, amount, sheet)
    @from_id = from_id
    @to_id = to_id
    @amount = amount.to_i
    @sheet = sheet
  end

  def execute
    return "양도할 갈레온 수는 1 갈레온 이상이어야 한단다." if @amount <= 0

    from = @sheet.get_player(@from_id)
    to   = @sheet.get_player(@to_id)

    return "보내는 사람(#{@from_id}) 정보가 없단다!" unless from
    return "받는 사람(#{@to_id}) 정보가 없단다!" unless to
    return "자기 자신에게는 갈레온을 양도할 수 없단다!" if @from_id == @to_id

    if from[:galleons].to_i < 0
      return "갈레온이 마이너스 상태라 양도는 불가능하단다."
    end

    if from[:galleons].to_i < @amount
      return "갈레온이 부족하단다."
    end

    # 양도 처리
    from[:galleons] -= @amount
    to[:galleons]   += @amount

    @sheet.update_player(from)
    @sheet.update_player(to)

    return "#{@amount}갈레온을 #{@to_id}학생에게 양도\n현재 잔액 #{from[:galleons]}갈레온"
  end
end
