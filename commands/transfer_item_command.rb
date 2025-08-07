# commands/transfer_item_command.rb
class TransferItemCommand
  def initialize(from_id, to_id, item_name, sheet)
    @from_id = from_id
    @to_id = to_id
    @item_name = item_name.strip
    @sheet = sheet
  end

  def execute
    return nil if @from_id == @to_id

    from = @sheet.get_player(@from_id)
    to = @sheet.get_player(@to_id)
    return nil unless from && to

    from_items = from[:items].to_s.split(",").map(&:strip)
    return "'#{@item_name}'은(는) 네 소지품에 없단다!" unless from_items.include?(@item_name)

    item = @sheet.get_item(@item_name)
    return nil unless item

    unless item[:transferable]
      return nil 
    end

    # 아이템 이동 처리
    from_items.delete(@item_name)
    to_items = to[:items].to_s.split(",").map(&:strip)
    to_items << @item_name

    from[:items] = from_items.join(",")
    to[:items] = to_items.join(",")

    @sheet.update_player(from)
    @sheet.update_player(to)

    return "'#{@item_name}'을(를) #{@to_id}학생에게 양도"
  end
end
