# ============================================
# sheet_manager.rb (추가 메서드 포함 버전)
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
  # 로그 추가용 append
  # -----------------------------
  def append_row(range, values)
    body = Google::Apis::SheetsV4::ValueRange.new(values: [values])
    @service.append_spreadsheet_value(@sheet_id, range, body, value_input_option: 'USER_ENTERED')
    puts "[시트] 로그 추가 완료: #{values.inspect}"
  rescue => e
    puts "[에러] 로그 추가 실패: #{e.message}"
  end

  # ======================================================
  # ✅ 플레이어 검색 기능 (CommandParser에서 호출됨)
  # ======================================================
  def get_player(player_id)
    data = read_range('플레이어!A2:E') # 시트 구조에 맞게 조정
    headers = ['id', 'name', 'galleon', 'items', 'notes']

    data.each_with_index do |row, idx|
      next unless row[0] # 빈 행 제외
      if row[0].to_s.strip == player_id.to_s.strip
        player = Hash[headers.zip(row)]
        player['row_number'] = idx + 2 # 실제 행 번호 (A2부터 시작)
        return player
      end
    end
    nil # 없을 경우 nil 반환
  rescue => e
    puts "[에러] get_player 실패: #{e.message}"
    nil
  end
end
