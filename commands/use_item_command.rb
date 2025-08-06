# commands/use_item_command.rb
class UseItemCommand
  def initialize(student_id, item_name, sheet)
    @student_id = student_id
    @item_name = item_name.strip
    @sheet = sheet
  end

  def execute
    player = @sheet.get_player(@student_id)
    return "학적부에 없는 학생이구나, 교수님께 가보렴." unless player

    inventory = player["items"].to_s.split(",").map(&:strip)

    unless inventory.include?(@item_name)
      return "‘#{@item_name}’은(는) 네 소지품에 없단다."
    end

    item = @sheet.get_item(@item_name)
    return "‘#{@item_name}’이라는 물건을 찾을 수 없단다." unless item

    unless item["사용가능"].to_s.downcase == "true"
      return "‘#{@item_name}’은(는) 사용할 수 없는 물건이란다!"
    end

    effect_message = item["효과"].to_s.strip
    effect_message = "‘#{@item_name}’을(를) 사용!" if effect_message.empty?

    if item["사용시삭제"].to_s.downcase == "true"
      inventory.delete(@item_name)
      player["items"] = inventory.join(",")
    end

    return "#{effect_message}"
  end
end

