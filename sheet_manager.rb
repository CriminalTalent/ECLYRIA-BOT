# sheet_manager.rb (상점봇 전용 - 특별한인형 기능 추가)
require 'google/apis/sheets_v4'

class SheetManager
  attr_reader :service, :sheet_id

  USERS_SHEET      = '사용자'.freeze
  PROFESSOR_SHEET  = '교수'.freeze
  SHOP_LOG_SHEET   = '상점로그'.freeze
  ITEMS_SHEET      = '아이템'.freeze
  DOLL_SHEET       = '특별한인형'.freeze

  def initialize(service, sheet_id)
    @service  = service
    @sheet_id = sheet_id
    check_sheets
  end

  # 시트 목록 확인
  def check_sheets
    begin
      spreadsheet = service.get_spreadsheet(sheet_id)
      sheet_names = spreadsheet.sheets.map { |s| s.properties.title }
      puts "[SHEETS] 사용 가능한 시트: #{sheet_names.join(', ')}"
      
      required = [USERS_SHEET, ITEMS_SHEET]
      missing = required - sheet_names
      
      puts "[경고] 누락된 시트: #{missing.join(', ')}" if missing.any?
    rescue => e
      puts "[SHEETS-CHECK 오류] #{e.message}"
    end
  end

  # =========================
  # 기본 read / write / append
  # =========================
  def read(sheet_name, a1 = 'A:Z')
    range = a1_range(sheet_name, a1)
    result = service.get_spreadsheet_values(sheet_id, range)
    result.values || []
  rescue => e
    puts "[READ 오류] #{sheet_name} #{a1} : #{e.message}"
    []
  end

  def write(sheet_name, a1, values)
    range = a1_range(sheet_name, a1)
    body = Google::Apis::SheetsV4::ValueRange.new(values: values)
    service.update_spreadsheet_value(
      sheet_id,
      range,
      body,
      value_input_option: 'USER_ENTERED'
    )
  end

  def append(sheet_name, row)
    range = a1_range(sheet_name, 'A:Z')
    body = Google::Apis::SheetsV4::ValueRange.new(values: [row])
    service.append_spreadsheet_value(
      sheet_id,
      range,
      body,
      value_input_option: 'USER_ENTERED'
    )
  end

  # =========================
  # 사용자 처리
  # =========================
  def find_user(acct)
    clean_acct = acct.to_s.gsub('@', '').strip
    rows = read(USERS_SHEET, 'A:K')
    return nil if rows.empty?

    header = rows.first
    rows[1..].each_with_index do |r, idx|
      next if r.nil? || r[0].nil?
      return convert_user_row(header, r, idx + 1) if r[0].to_s.gsub('@','').strip == clean_acct
    end
    nil
  end

  # ✅ special_doll_command 호환용
  def get_player(acct)
    find_user(acct)
  end

  def update_user(acct, updates)
    clean_acct = acct.to_s.gsub('@', '').strip
    rows = read(USERS_SHEET, 'A:K')
    header = rows.first || []

    rows.each_with_index do |row, idx|
      next if idx == 0 || row.nil? || row[0].nil?
      next unless row[0].to_s.gsub('@','').strip == clean_acct

      updates.each do |key, value|
        col = {
          id: 0, name: 1, galleons: 2, items: 3, memo: 4,
          house: 5, last_bet_date: 6, bet_count: 7,
          attendance_date: 8, last_tarot_date: 9, house_score: 10
        }[key.to_sym]

        next unless col
        row[col] = value
      end

      write(USERS_SHEET, "A#{idx+1}:K#{idx+1}", [row])
      return true
    end
    false
  end

  # ✅ special_doll_command 호환용
  def update_player(player)
    update_user(player[:id], items: player[:items])
  end

  # =========================
  # 특별한 인형
  # =========================
  def get_random_doll
    rows = read(DOLL_SHEET, 'A:B')
    return nil if rows.length < 2

    dolls = rows[1..].map do |r|
      next if r.nil? || r[0].nil? || r[1].nil?
      { name: r[0].to_s.strip, image_url: r[1].to_s.strip }
    end.compact

    dolls.sample
  rescue => e
    puts "[DOLL 오류] #{e.message}"
    nil
  end

  # =========================
  # 변환 유틸
  # =========================
  def convert_user_row(header, row, row_index)
    {
      row: row_index,
      id: row[0].to_s.strip,
      name: row[1].to_s.strip,
      galleons: row[2].to_i,
      items: row[3].to_s.strip,
      memo: row[4].to_s.strip,
      house: row[5].to_s.strip,
      last_bet_date: row[6].to_s.strip,
      bet_count: row[7].to_i,
      attendance_date: row[8].to_s.strip,
      last_tarot_date: row[9].to_s.strip,
      house_score: row[10].to_i
    }
  end

  def a1_range(sheet, a1)
    a1.include?('!') ? a1 : "#{sheet}!#{a1}"
  end

  def log_command(user, kind, value = nil, detail = "")
    append(SHOP_LOG_SHEET, [
      Time.now.strftime('%Y-%m-%d %H:%M:%S'),
      kind, user, value.to_s, detail.to_s
    ])
  rescue => e
    puts "[로그 오류] #{e.message}"
  end
end
