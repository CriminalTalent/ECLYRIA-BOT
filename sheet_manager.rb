# sheet_manager.rb (확장 버전)
class SheetManager
  attr_reader :service, :sheet_id

  def initialize(service, sheet_id)
    @service = service
    @sheet_id = sheet_id
  end

  def read_range(range)
    response = @service.get_spreadsheet_values(@sheet_id, range)
    response.values || []
  rescue => e
    puts "[에러] 시트 읽기 실패 (#{range}): #{e.message}"
    []
  end

  def update_cell(range, value)
    body = Google::Apis::SheetsV4::ValueRange.new(values: [[value]])
    @service.update_spreadsheet_value(@sheet_id, range, body, value_input_option: "RAW")
  rescue => e
    puts "[에러] 셀 업데이트 실패 (#{range}): #{e.message}"
  end

  def append_row(range, values)
    body = Google::Apis::SheetsV4::ValueRange.new(values: [values])
    @service.append_spreadsheet_value(@sheet_id, range, body, value_input_option: "USER_ENTERED")
  rescue => e
    puts "[에러] 로그 추가 실패: #{e.message}"
  end

  # -------------------------------
  # 플레이어 찾기
  # -------------------------------
  def find_user(student_id)
    data = read_range("사용자!A2:M")

    data.each_with_index do |row, idx|
      next if row[0].nil?
      if row[0].to_s.strip == student_id.to_s.strip
        return {
          id: row[0],
          name: row[1],
          galleons: row[2],
          items: row[3],
          row: idx + 2
        }
      end
    end
    nil
  end

  # -------------------------------
  # 플레이어 업데이트
  # -------------------------------
  def update_user(student_id, updates = {})
    user = find_user(student_id)
    return false unless user

    row = user[:row]

    updates.each do |k, v|
      case k
      when :galleons
        update_cell("사용자!C#{row}", v)
      when :items
        update_cell("사용자!D#{row}", v)
      end
    end
    true
  end

  # -------------------------------
  # 아이템 찾기
  #
  # A:이름 B:설명 C:가격 D:판매여부 E:사용가능 F:이미지URL
  # -------------------------------
  def find_item(item_name)
    rows = read_range("아이템!A2:F")

    rows.each do |r|
      next if r[0].nil?

      if r[0].to_s.strip == item_name.to_s.strip
        return {
          name: r[0],
          description: r[1],
          price: r[2],
          sellable: (r[3].to_s.strip == "TRUE"),
          usable: (r[4].to_s.strip == "TRUE"),
          image_url: r[5]
        }
      end
    end
    nil
  end
end
