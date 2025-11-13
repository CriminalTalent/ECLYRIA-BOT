# ============================================
# sheet_manager.rb (BuyCommand 완전 호환 버전)
# ============================================
require 'google/apis/sheets_v4'

class SheetManager
  attr_reader :service, :sheet_id

  def initialize(service, sheet_id)
    @service = service
    @sheet_id = sheet_id
  end

  # -----------------------------
  # 시트 범위 읽기
  # -----------------------------
  def read_range(range)
    response = @service.get_spreadsheet_values(@sheet_id, range)
    response.values || []
  rescue => e
    puts "[에러] 시트 읽기 실패 (#{range}): #{e.message}"
    []
  end

  # -----------------------------
  # 특정 셀 업데이트
  # -----------------------------
  def update_cell(range, value)
    write_range(range, [[value]])
  end

  def write_range(range, values)
    body = Google::Apis::SheetsV4::ValueRange.new(values: values)
    @service.update_spreadsheet_value(@sheet_id, range, body, value_input_option: 'RAW')
  rescue => e
    puts "[에러] 시트 쓰기 실패 (#{range}): #{e.message}"
  end

  # -----------------------------
  # 로그 append
  # -----------------------------
  def append_row(range, values)
    body = Google::Apis::SheetsV4::ValueRange.new(values: [values])
    @service.append_spreadsheet_value(@sheet_id, range, body, value_input_option: 'USER_ENTERED')
    puts "[시트] 로그 추가 완료: #{values.inspect}"
  rescue => e
    puts "[에러] 로그 추가 실패: #{e.message}"
  end

  # ======================================================
  # ✅ 플레이어 찾기
  # A:id / B:name / C:galleons / D:items / E:notes
  # ======================================================
  def find_user(student_id)
    data = read_range("player!A2:E")

    data.each_with_index do |row, idx|
      next if row[0].nil?

      if row[0].to_s.strip == student_id.to_s.strip
        return {
          id: row[0],
          name: row[1],
          galleons: row[2],
          items: row[3],
          notes: row[4],
          row: idx + 2
        }
      end
    end
    nil
  rescue => e
    puts "[에러] find_user 실패: #{e.message}"
    nil
  end

  # ======================================================
  # ✅ 유저 정보 업데이트
  # galleons / items 만 갱신 (나머지 보존)
  # ======================================================
  def update_user(student_id, updates = {})
    user = find_user(student_id)
    return unless user

    row = user[:row]

    updates.each do |key, value|
      case key
      when :galleons
        update_cell("player!C#{row}", value)
      when :items
        update_cell("player!D#{row}", value)
      end
    end
  rescue => e
    puts "[에러] update_user 실패: #{e.message}"
  end

  # ======================================================
  # ✅ 아이템 찾기 (shop_items)
  # A:name / B:description / C:price / D:for_sale / E:use_ok / F:image_url
  # ======================================================
  def find_item(item_name)
    data = read_range("shop_items!A2:F")

    data.each do |row|
      next if row[0].nil?

      if row[0].to_s.strip == item_name.to_s.strip
        return {
          name: row[0],
          description: row[1],
          price: row[2],
          for_sale: row[3],
          can_use: row[4],
          image_url: row[5]
        }
      end
    end

    nil
  rescue => e
    puts "[에러] find_item 실패: #{e.message}"
    nil
  end
end
