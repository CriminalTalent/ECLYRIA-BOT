# ============================================
# sheet_manager.rb
# Google Sheets 데이터 관리 유틸
# ============================================
# encoding: UTF-8
require 'google/apis/sheets_v4'
require 'time'

class SheetManager
  attr_reader :service, :sheet_id

  def initialize(service, sheet_id)
    @service = service
    @sheet_id = sheet_id
  end

  # --------------------------------------------
  # 범위 읽기
  # --------------------------------------------
  def read_range(range)
    result = @service.get_spreadsheet_values(@sheet_id, range)
    result.values || []
  rescue => e
    puts "[에러] 시트 읽기 실패: #{range} (#{e.message})"
    []
  end

  # --------------------------------------------
  # 범위에 값 업데이트
  # --------------------------------------------
  def update_range(range, values)
    body = Google::Apis::SheetsV4::ValueRange.new(values: values)
    @service.update_spreadsheet_value(
      @sheet_id,
      range,
      body,
      value_input_option: 'USER_ENTERED'
    )
  rescue => e
    puts "[에러] 시트 업데이트 실패: #{range} (#{e.message})"
  end

  # --------------------------------------------
  # 단일 셀 업데이트
  # --------------------------------------------
  def update_cell(range, value)
    update_range(range, [[value]])
  end

  # --------------------------------------------
  # 행 추가 (로그 기록용)
  # --------------------------------------------
  def append_row(range, row_values)
    body = Google::Apis::SheetsV4::ValueRange.new(values: [row_values])
    @service.append_spreadsheet_value(
      @sheet_id,
      range,
      body,
      value_input_option: 'USER_ENTERED'
    )
  rescue => e
    puts "[에러] 행 추가 실패: #{range} (#{e.message})"
  end

  # --------------------------------------------
  # 플레이어 데이터 전체 업데이트
  # --------------------------------------------
  def update_player_row(player_name, updated_row)
    player_rows = read_range('사용자!A2:L')
    idx = player_rows.find_index { |r| r[0].to_s.strip == player_name.to_s.strip }
    if idx
      row_index = idx + 2
      range = "사용자!A#{row_index}:L#{row_index}"
      puts "[DEBUG] 전체 행 업데이트: #{range}"
      update_range(range, [updated_row])
    else
      puts "[경고] 플레이어 '#{player_name}' 데이터를 찾을 수 없습니다."
    end
  end

  # --------------------------------------------
  # 일일 명령어 횟수 확인 (예: BET 등)
  # --------------------------------------------
  def get_daily_count(user, date, type)
    log_rows = read_range('log!A:G')
    log_rows.count { |r| r[2] == user && r[0]&.start_with?(date) && r[1] == type }
  rescue => e
    puts "[에러] 일일 카운트 조회 실패: #{e.message}"
    0
  end

  # --------------------------------------------
  # 명령 로그 기록 (유저, 명령 타입, 추가정보)
  # --------------------------------------------
  def log_command(user, type, detail = nil)
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    append_row('log!A:G', [timestamp, type, user, '', detail, '', ''])
  rescue => e
    puts "[에러] 로그 기록 실패: #{e.message}"
  end

  # --------------------------------------------
  # 셀 한 칸 읽기
  # --------------------------------------------
  def read_cell(range)
    result = @service.get_spreadsheet_values(@sheet_id, range)
    (result.values || [[]]).flatten.first
  rescue => e
    puts "[에러] 셀 읽기 실패: #{range} (#{e.message})"
    nil
  end

  # --------------------------------------------
  # ✅ 추가: get_player (TarotCommand 등에서 사용)
  # --------------------------------------------
  def get_player(username)
    rows = read_range('사용자!A2:L')
    row = rows.find { |r| r[0].to_s.strip == username.to_s.strip || r[1].to_s.include?(username) }
    return nil unless row

    {
      id: row[0],
      display: row[1],
      galleons: row[2].to_i,
      items: row[3].to_s.split(','),
      last_action: row[4],
      house: row[5]
    }
  rescue => e
    puts "[에러] get_player 실패: #{e.message}"
    nil
  end

  # --------------------------------------------
  # ✅ 추가: find_user (Buy/TransferCommand 등에서 사용)
  # --------------------------------------------
  def find_user(username)
    rows = read_range('사용자!A2:L')
    rows.find { |r| r[0].to_s.strip == username.to_s.strip || r[1].to_s.include?(username) }
  rescue => e
    puts "[에러] find_user 실패: #{e.message}"
    nil
  end
end
