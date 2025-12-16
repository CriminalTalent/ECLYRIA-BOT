# ============================================
# commands/transfer_item_command.rb (양도 로직 개선)
# ============================================
class TransferItemCommand
  def initialize(sender, receiver, item_name, sheet_manager)
    @sender = sender.gsub('@', '')
    @receiver = receiver.gsub('@', '')
    @item_name = item_name.strip
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[TRANSFER] START from=#{@sender} to=#{@receiver} item=#{@item_name}"
    
    # -----------------------------------------
    # 1) 보내는 사람 확인
    # -----------------------------------------
    sender_user = @sheet_manager.find_user(@sender)
    unless sender_user
      puts "[TRANSFER] ERROR: sender not found (@#{@sender})"
      return "@#{@sender} 어머, 손님이 누구시더라? 입학부터 하고 오세요~"
    end

    # -----------------------------------------
    # 2) 받는 사람 확인
    # -----------------------------------------
    receiver_user = @sheet_manager.find_user(@receiver)
    unless receiver_user
      puts "[TRANSFER] ERROR: receiver not found (@#{@receiver})"
      return "@#{@sender} 어머나, @#{@receiver}님이 학교에 없는 것 같은데요?"
    end

    # -----------------------------------------
    # 3) 보내는 사람 인벤토리 확인
    # -----------------------------------------
    inventory = sender_user[:items].to_s.split(",").map(&:strip)
    unless inventory.include?(@item_name)
      puts "[TRANSFER] ERROR: item not in inventory"
      return "@#{@sender} 어? #{@item_name}은(는) 안 가지고 계신 것 같은데요?"
    end

    # -----------------------------------------
    # 4) 아이템 양도 가능 여부 확인
    #    - 아이템 시트에 없는 것(이벤트/선물) = 양도 가능
    #    - 아이템 시트에 있는 것 = transferable 체크
    # -----------------------------------------
    item = @sheet_manager.find_item(@item_name)
    
    if item
      # 아이템 시트에 등록된 경우
      puts "[TRANSFER] 아이템 정보 있음: #{item.inspect}"
      
      # transferable 플래그 확인
      transferable = item[:transferable]
      
      unless transferable
        puts "[TRANSFER] BLOCK: item not transferable"
        return "@#{@sender} #{@item_name}은(는) 양도할 수 없는 물건이에요."
      end
    else
      # 아이템 시트에 없는 경우 (이벤트/선물 등)
      puts "[TRANSFER] 아이템 정보 없음 → 양도 가능 (이벤트/선물 아이템)"
    end

    # -----------------------------------------
    # 5) 양도 처리
    # -----------------------------------------
    inventory.delete(@item_name)
    receiver_inventory = receiver_user[:items].to_s.split(",").map(&:strip)
    receiver_inventory << @item_name

    @sheet_manager.update_user(@sender, { items: inventory.join(",") })
    @sheet_manager.update_user(@receiver, { items: receiver_inventory.join(",") })

    puts "[TRANSFER] SUCCESS"
    return "@#{@sender} #{@item_name} 잘 전달했어요! @#{@receiver}님한테 줬어요~"
  end
end
