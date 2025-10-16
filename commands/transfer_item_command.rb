# ============================================
# commands/transfer_item_command.rb
# ============================================
class TransferItemCommand
  def initialize(sender, receiver, item_name, sheet_manager)
    @sender = sender.gsub('@', '')
    @receiver = receiver.gsub('@', '')
    @item_name = item_name.strip
    @sheet_manager = sheet_manager
  end

  def execute
    sender_user = @sheet_manager.find_user(@sender)
    unless sender_user
      return "어머, 손님이 누구시더라? 입학부터 하고 오세요~"
    end

    receiver_user = @sheet_manager.find_user(@receiver)
    unless receiver_user
      return "어머나, 받는 사람이 학교에 없는 것 같은데요?"
    end

    inventory = sender_user[:items].to_s.split(",").map(&:strip)
    unless inventory.include?(@item_name)
      return "어? #{@item_name}은(는) 안 가지고 계신 것 같은데요?"
    end

    # 양도 처리
    inventory.delete(@item_name)
    receiver_inventory = receiver_user[:items].to_s.split(",").map(&:strip)
    receiver_inventory << @item_name

    @sheet_manager.update_user(@sender, { items: inventory.join(",") })
    @sheet_manager.update_user(@receiver, { items: receiver_inventory.join(",") })

    return "#{@item_name} 잘 전달했어요! @#{@receiver}님한테 줬어요~"
  end
end
