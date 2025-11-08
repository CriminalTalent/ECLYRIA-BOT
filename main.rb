# ============================================
# sheet_manager.rb
# Google Sheets 연동 관리 클래스 (상점봇 전용 통합 버전)
# ============================================

require 'google/apis/sheets_v4'

class SheetManager
  attr_reader :service, :sheet_id

  # -----------------------------
  # 초기화
  # -----------------------------
  def initialize(service, sheet_id)
    @service = service
    @sheet_id = sheet_id
  end

  # =====================================================
  # 🔹 기본 유틸
  # =====================================================
  def read_range(range)
    response = @service.get_spreadsheet_values(@sheet_id, range)
    response.values || []
  rescue => e
    puts "[에러] 시트 읽기 실패 (#{range}): #{e.message}"
    []
  end

  def write_range(range, values)
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
    @service.update_spreadsheet_value(
      @sheet_id,
      range,
      value_range,
      value_input_option: 'USER_ENTERED'
    )
    puts "[시트] #{range} 업데이트 완료"
  rescue => e
    puts "[에러] 시트 쓰기 실패 (#{range}): #{e.message}"
  end

  def append_row(range, values)
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: [values])
    @service.append_spreadsheet_value(
      @sheet_id,
      range,
      value_range,
      value_input_option: 'USER_ENTERED'
    )
    puts "[시트] 행 추가 완료: #{values.inspect}"
  rescue => e
    puts "[에러] 행 추가 실패: #{e.message}"
  end

  def update_cell(range, value)
    write_range(range, [[value]])
  end

  # =====================================================
  # 🔹 사용자 관련
  # =====================================================
  def find_user(user_id)
    clean_id = user_id.gsub('@', '')
    data = read_range("사용자!A:L")
    return nil if data.empty?

    headers = data.first
    data[1..].each_with_index do |row, i|
      id = (row[0] || '').gsub('@', '')
      next unless id == clean_id

      return {
        row_index: i + 2,  # 실제 시트 행 번호 (1-based)
        id: row[0],
        name: row[1],
        galleons: (row[2] || 0).to_i,
        items: row[3] || "",
        last_task: row[4],
        house: row[5],
        hp: (row[6] || 0).to_i,
        attack: (row[7] || 0).to_i,
        attendance: row[8],
        last_tarot: row[9],
        house_score: (row[10] || 0).to_i,
        last_bet_count: (row[11] || "0").to_i
      }
    end
    nil
  end

  def update_user(user_id, data = {})
    user = find_user(user_id)
    return false unless user

    row = user[:row_index]
    updated = [
      data[:id] || user[:id],
      data[:name] || user[:name],
      data[:galleons] || user[:galleons],
      data[:items] || user[:items],
      data[:last_task] || user[:last_task],
      data[:house] || user[:house],
      data[:hp] || user[:hp],
      data[:attack] || user[:attack],
      data[:attendance] || user[:attendance],
      data[:last_tarot] || user[:last_tarot],
      data[:house_score] || user[:house_score],
      data[:last_bet_count] || user[:last_bet_count]
    ]

    range = "사용자!A#{row}:L#{row}"
    write_range(range, [updated])
    true
  end

  def add_user_row(user_data)
    append_row("사용자!A:L", user_data)
  end

  # =====================================================
  # 🔹 아이템 관련 (이미지URL 포함)
  # =====================================================
  def read_items
    data = read_range("아이템!A:F")
    return [] if data.empty?

    headers = data.first
    puts "[INFO] 아이템 시트 헤더: #{headers.inspect}"

    data[1..].map do |row|
      next if row[0].to_s.strip.empty?
      {
        name: row[0].to_s.strip,
        description: row[1].to_s.strip,
        price: (row[2] || 0).to_i,
        for_sale: truthy?(row[3]),
        usable: truthy?(row[4]),
        image_url: (row[5] || "").strip
      }
    end.compact
  rescue => e
    puts "[에러] 아이템 시트 읽기 실패: #{e.message}"
    []
  end

  def find_item(item_name)
    items = read_items
    items.find { |i| i[:name] == item_name }
  end

  # =====================================================
  # 🔹 내부 유틸
  # =====================================================
  private

  def truthy?(val)
    return false if val.nil?
    str = val.to_s.strip.downcase
    str == 'true' || str == '1' || str.include?('✅') || str == 'yes'
  end
end
