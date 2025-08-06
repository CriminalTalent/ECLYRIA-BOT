# commands/pouch_command.rb
class PouchCommand
  def initialize(student_id, sheet)
    @student_id = student_id
    @sheet = sheet
  end

  def execute
    player = @sheet.get_player(@student_id)
    return "학적부에 없는 학생이구나, 교수님께 가보렴." unless player

    galleons = player["galleons"]
    items = player["items"].to_s.strip

    if items.empty?
      return <<~TEXT.strip
        이름: #{player["name"]}
        갈레온: #{galleons}
      TEXT
    end

    item_list = items.split(",").map(&:strip).join(", ")

    return <<~TEXT.strip
      이름: #{player["name"]}
      갈레온: #{galleons}
      소지품: #{item_list}
    TEXT
  end
end

