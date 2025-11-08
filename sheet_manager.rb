# ============================================
# sheet_manager.rb (통합 안정화 + 이미지URL 완전판)
# ============================================
require 'google/apis/sheets_v4'

class SheetManager
  def initialize(sheets_service, sheet_id)
    @service = sheets_service
    @sheet_id = sheet_id
    @worksheets_cache = {}
  end

  # -------------------------------
  # 기본 읽기 / 쓰기 / 추가
  # -------------------------------
  def read_values(range)
    @service.get_spreadsheet_values(@sheet_id, range).values
  rescue => e
    puts "시트 읽기 오류: #{e.message}"
    []
  end

  def update_values(range, values)
    puts "[DEBUG] 업데이트 시도: 범위=#{range}, 값=#{values.inspect}"
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
    result = @service.update_spreadsheet_value(@sheet_id, range, value_range, value_input_option: 'USER_ENTERED')
    puts "[DEBUG] 업데이트 결과: #{result.updated_cells}개 셀 업데이트됨"
    result
  rescue => e
    puts "시트 쓰기 오류: #{e.message}"
    puts e.backtrace.first(3)
    nil
  end

  def append_values(range, values)
    puts "[DEBUG] 추가 시도: 범위=#{range}, 값=#{values.inspect}"
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
    result = @service.append_spreadsheet_value(@sheet_id, range, value_range, value_input_option: 'USER_ENTERED')
    puts "[DEBUG] 추가 결과: #{result.updated_rows}개 행 추가됨"
    result
  rescue => e
    puts "시트 추가 오류: #{e.message}"
    nil
  end

  def worksheet_by_title(title)
    @worksheets_cache[title] ||= WorksheetWrapper.new(self, title)
  end

  def worksheet(title)
    worksheet_by_title(title)
  end

  # -------------------------------
  # 사용자 관련 (변경 없음)
  # -------------------------------
  def find_user(user_id)
    clean_user_id = user_id.gsub('@', '')
    values = read_values("사용자!A:L")
    return nil if values.nil? || values.empty?

    headers = values[0]
    ensure_last_bet_count_column(headers)

    values.each_with_index do |row, index|
      next if index == 0
      row_id = (row[0] || "").gsub('@', '')
      if row_id == clean_user_id
        return {
          sheet_row: index + 1,
          id: row[0],
          name: row[1],
          galleons: row[2].to_i,
          items: row[3] || "",
          last_bet_date: row[4],
          house: row[5],
          hp: row[6].to_i,
          attack: row[7].to_i,
          attendance_date: row[8],
          last_tarot_date: row[9],
          house_score: row[10].to_i,
          last_bet_count: (row[11] || "0").to_i
        }
      end
    end
    nil
  end

  def update_user(user_id, data = {})
    user = find_user(user_id)
    return false unless user
    sheet_row = user[:sheet_row]
    row_data = [
      data[:id] || user[:id],
      data[:name] || user[:name],
      data[:galleons] || user[:galleons],
      data[:items] || user[:items],
      data[:last_bet_date] || user[:last_bet_date],
      data[:house] || user[:house],
      data[:hp] || user[:hp],
      data[:attack] || user[:attack],
      data[:attendance_date] || user[:attendance_date],
      data[:last_tarot_date] || user[:last_tarot_date],
      data[:house_score] || user[:house_score],
      data[:last_bet_count] || user[:last_bet_count]
    ]
    range = "사용자!A#{sheet_row}:L#{sheet_row}"
    update_values(range, [row_data])
    true
  end

  # -------------------------------
  # 아이템 관련 (이미지URL 포함 확장)
  # -------------------------------
  def read_items
    values = read_values("아이템!A:F")
    return [] if values.nil? || values.empty?

    headers = values[0]
    puts "[INFO] 아이템 시트 헤더 확인: #{headers.inspect}"

    values[1..].map do |row|
      next if row[0].to_s.strip.empty?
      {
        name: row[0].to_s.strip,
        description: row[1].to_s.strip,
        price: (row[2] || 0).to_i,
        for_sale: (row[3].to_s.strip == 'TRUE' || row[3].include?('✅')),
        usable: (row[4].to_s.strip == 'TRUE' || row[4].include?('✅')),
        image_url: (row[5] || "").strip
      }
    end.compact
  rescue => e
    puts "[에러] 아이템 시트 읽기 실패: #{e.message}"
    []
  end

  def find_item(item_name)
    read_items.find { |i| i[:name] == item_name }
  end

  # -------------------------------
  # L열(마지막 베팅횟수) 자동 생성
  # -------------------------------
  def ensure_last_bet_count_column(headers)
    unless headers.include?("마지막베팅횟수")
      puts "[INFO] '마지막베팅횟수' 열이 없어 자동으로 추가합니다."
      headers << "마지막베팅횟수"
      update_values("사용자!A1:L1", [headers])
    end
  rescue => e
    puts "[ERROR] L열 자동 생성 실패: #{e.message}"
  end

  # -------------------------------
  # 내부 유틸
  # -------------------------------
  private

  def number_to_column_letter(col_num)
    result = ""
    while col_num > 0
      col_num -= 1
      result = ((col_num % 26) + 65).chr + result
      col_num /= 26
    end
    result
  end
end

# ============================================
# WorksheetWrapper (변경 없음)
# ============================================
class WorksheetWrapper
  def initialize(sheet_manager, title)
    @sheet_manager = sheet_manager
    @title = title
    @data = nil
    load_data
  end

  def load_data
    @data = @sheet_manager.read_values("#{@title}!A:Z")
    @data ||= []
  end

  def save; true; end
  def num_rows; load_data; @data.length; end
  def rows; load_data; @data; end

  def [](row, col)
    load_data
    return nil if row < 1 || row > @data.length
    return nil if col < 1 || col > (@data[row-1]&.length || 0)
    @data[row-1][col-1]
  end

  def []=(row, col, value)
    load_data
    while @data.length < row; @data << []; end
    while @data[row-1].length < col; @data[row-1] << ""; end
    @data[row-1][col-1] = value
    range = "#{@title}!#{number_to_column_letter(col)}#{row}"
    @sheet_manager.update_values(range, [[value]])
  end

  def update_cell(row, col, value)
    range = "#{@title}!#{number_to_column_letter(col)}#{row}"
    @sheet_manager.update_values(range, [[value]])
    load_data
  end

  def insert_rows(at_row, rows_data)
    range = "#{@title}!A#{at_row}"
    @sheet_manager.append_values(range, rows_data)
    load_data
  end

  private

  def number_to_column_letter(col_num)
    result = ""
    while col_num > 0
      col_num -= 1
      result = ((col_num % 26) + 65).chr + result
      col_num /= 26
    end
    result
  end
end
