# ============================================
# sheet_manager.rb
# Google Sheets 연동 관리 클래스
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

  # -----------------------------
  # 범위 읽기
  # -----------------------------
  def read_range(range)
    response = @service.get_spreadsheet_values(@sheet_id, range)
    response.values || []
  rescue => e
    puts "[에러] 시트 읽기 실패 (#{range}): #{e.message}"
    []
  end

  # -----------------------------
  # 범위 쓰기 (RAW)
  # -----------------------------
  def write_range(range, values)
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
    @service.update_spreadsheet_value(
      @sheet_id,
      range,
      value_range,
      value_input_option: 'RAW'
    )
    puts "[시트] #{range} 업데이트 완료"
  rescue => e
    puts "[에러] 시트 쓰기 실패 (#{range}): #{e.message}"
  end

  # -----------------------------
  # 로그 기록용 append
  # -----------------------------
  def append_row(range, values)
    value_range = Google::Apis::SheetsV4::ValueRange.new(values: [values])
    @service.append_spreadsheet_value(
      @sheet_id,
      range,
      value_range,
      value_input_option: 'USER_ENTERED'
    )
    puts "[시트] 로그 추가 완료: #{values.inspect}"
  rescue => e
    puts "[에러] 로그 추가 실패: #{e.message}"
  end

  # -----------------------------
  # 특정 셀 업데이트 (단일)
  # -----------------------------
  def update_cell(range, value)
    write_range(range, [[value]])
  end
end
