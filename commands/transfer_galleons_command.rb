# ============================================
# commands/transfer_galleons_command.rb (멘션 추가 버전)
# ============================================
class TransferGalleonsCommand
  def initialize(sender, receiver, amount, sheet_manager)
    @sender = sender.gsub('@', '')
    @receiver = receiver.gsub('@', '')
    @amount = amount
    @sheet_manager = sheet_manager
  end

  def execute
    sender_user = @sheet_manager.find_user(@sender)
    unless sender_user
      return "@#{@sender} 어머, 손님이 누구시더라? 입학부터 하고 오세요~"
    end

    if sender_user[:galleons].to_i < 0
      return "@#{@sender} 어머머, 빚쟁이는 돈 못 보내요! 갈레온부터 갚고 오세요~"
    end

    receiver_user = @sheet_manager.find_user(@receiver)
    unless receiver_user
      return "@#{@sender} 어머나, @#{@receiver}님이 학교에 없는 것 같은데요?"
    end

    if sender_user[:galleons].to_i < @amount
      return "@#{@sender} 어? 갈레온이 부족한데요? 지금 #{sender_user[:galleons]}개밖에 없잖아요~"
    end

    # 송금 처리
    new_sender = sender_user[:galleons].to_i - @amount
    new_receiver = receiver_user[:galleons].to_i + @amount

    @sheet_manager.update_user(@sender, { galleons: new_sender })
    @sheet_manager.update_user(@receiver, { galleons: new_receiver })

    return "@#{@sender} #{@amount}갈레온 잘 보냈어요! @#{@receiver}님한테 줬어요~ 남은 돈은 #{new_sender}갈레온!"
  end
end
