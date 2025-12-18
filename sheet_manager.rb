# sheet_manager.rb
# 상점봇 전용 SheetManager (구매 / 특별한 인형 지원)

require 'google/apis/sheets_v4'

class SheetManager
  attr_reader :service, :sheet_id

  USERS_SHEET     = '사용자'.freeze
  ITEMS_SHEET     = '아이템'.freeze
  SHOP_LOG_SHEET  = '상점로그'.freeze
  DOLL_SHEET      = '특별한인형'.freeze

  def initialize(service, sheet_id)
    @service  = service
    @sheet_id = sheet_id
    check_sheets
  end

  # =========================
  # 시트 확인
  # =========================
  def check_sheets
    spreadsheet = service.get_spreadsheet(sheet_id)
    sheet_names = spreadsheet.sheets.map { |s| s.properties.title }
    puts "[SHEETS] 사용 가능한 시트: #{sheet_names.join(', ')}"
  rescue => e
    puts "[SHEETS-CHECK 오류] #{e.message}"
  end

  # =========================
  # 기본 I/O
  # =========================
  def read(sheet, a1 = 'A:Z')
    range = a1_range(sheet, a1)
    service.get_spreadsheet_values(sheet_id, range).values || []
  rescue => e
    puts "[READ 오류] #{sheet} #{a1}: #{e.message}"
    []
  end

  def write(sheet, a1, values)
    range = a1_range(sheet, a1)
    body  = Google::Apis::SheetsV4::ValueRange.new(values: values)
    service.update_spreadsheet_value(
      sheet_id,
      range,
      body,
      value_input_option: 'USER_ENTERED'
    )
  end

  def append(sheet, row)
    range = a1_range(sheet, 'A:Z')
    body  = Google::Apis::SheetsV4::ValueRange.new(values: [row])
    service.append_spreadsheet_value(
      sheet_id,
      range,
      body,
      value_input_option: 'USER_ENTERED'
    )
  end

  # =========================
  # 사용자
  # =========================
  def find_user(acct)
    key = acct.to_s.gsub('@','').strip
    rows = read(USERS_SHEET, 'A:K')
    return nil if rows.size < 2

    rows[1..].each_with_index do |r, i|
      next if r.nil? || r[0].nil?
      return convert_user_row(r, i + 2) if r[0].to_s.gsub('@','').strip == key
    end
    nil
  end

  # BUY / DOLL 공용
  def get_player(acct)
    find_user(acct)
  end

  def update_user(acct, updates)
    key  = acct.to_s.gsub('@','').strip
    rows = read(USERS_SHEET, 'A:K')
    return false if rows.size < 2

    rows.each_with_index do |row, idx|
      next if idx == 0 || row.nil? || row[0].nil?
      next unless row[0].to_s.gsub('@','').strip == key

      updates.each do |k, v|
        col = {
          id: 0, name: 1, galleons: 2, items: 3, memo: 4,
          house: 5, last_bet_date: 6, bet_count: 7,
          attendance_date: 8, last_tarot_date: 9, house_score: 10
        }[k.to_sym]
        row[col] = v if col
      end

      write(USERS_SHEET, "A#{idx+1}:K#{idx+1}", [row])
      return true
    end
    false
  end

  def update_player(player)
    update_user(player[:id], items: player[:items], galleons: player[:galleons])
  end

  # =========================
  # 아이템 (구매 핵심)
  # =========================
  def find_item(item_name)
    rows = read(ITEMS_SHEET, 'A:Z')
    return nil if rows.size < 2

    rows[1..].each do |row|
      next if row.nil? || row[0].nil?
      next unless row[0].to_s.strip == item_name

      return {
        name: row[0].to_s.strip,
        price: row[1].to_i,
        description: row[2].to_s,
        usable: row[3].to_s,
        raw: row
      }
    end
    nil
  end

  # =========================
  # 특별한 인형
  # =========================
  def get_random_doll
    rows = read(DOLL_SHEET, 'A:B')
    return nil if rows.size < 2

    rows[1..].map do |r|
      next if r.nil? || r[0].nil? || r[1].nil?
      { name: r[0].to_s.strip, image_url: r[1].to_s.strip }
    end.compact.sample
  rescue => e
    puts "[DOLL 오류] #{e.message}"
    nil
  end

  # =========================
  # 로그
  # =========================
  def log_command(user, kind, value = nil, detail = "")
    append(SHOP_LOG_SHEET, [
      Time.now.strftime('%Y-%m-%d %H:%M:%S'),
      kind, user, value.to_s, detail.to_s
    ])
  rescue => e
    puts "[LOG 오류] #{e.message}"
  end

  # =========================
  # 유틸
  # =========================
  def convert_user_row(row, index)
    {
      row: index,
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
end
