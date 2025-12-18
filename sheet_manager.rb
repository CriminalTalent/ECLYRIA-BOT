# sheet_manager.rb
require 'google/apis/sheets_v4'

class SheetManager
  USERS_SHEET = '사용자'.freeze
  ITEMS_SHEET = '아이템'.freeze
  DOLL_SHEET  = '특별한인형'.freeze
  SHOP_LOG_SHEET = '상점로그'.freeze

  def initialize(service, sheet_id)
    @service = service
    @sheet_id = sheet_id
  end

  # =========================
  # 기본 read / write / append
  # =========================
  def read(sheet, range = 'A:Z')
    r = "#{sheet}!#{range}"
    @service.get_spreadsheet_values(@sheet_id, r).values || []
  rescue
    []
  end

  def write(sheet, range, values)
    body = Google::Apis::SheetsV4::ValueRange.new(values: values)
    @service.update_spreadsheet_value(
      @sheet_id,
      "#{sheet}!#{range}",
      body,
      value_input_option: 'USER_ENTERED'
    )
  end

  def append(sheet, row)
    body = Google::Apis::SheetsV4::ValueRange.new(values: [row])
    @service.append_spreadsheet_value(
      @sheet_id,
      "#{sheet}!A:Z",
      body,
      value_input_option: 'USER_ENTERED'
    )
  end

  # =========================
  # 사용자
  # =========================
  def find_user(acct)
    acct = acct.to_s.gsub('@','').strip
    rows = read(USERS_SHEET, 'A:K')
    header = rows.first

    rows[1..].each_with_index do |row, i|
      next unless row[0]&.gsub('@','') == acct
      return build_user(header, row, i + 2)
    end
    nil
  end

  # ✅ 핵심 수정부
  def update_user(acct, *args)
    acct = acct.to_s.gsub('@','').strip
    rows = read(USERS_SHEET, 'A:K')

    updates =
      if args.length == 1 && args[0].is_a?(Hash)
        args[0]
      elsif args.length == 2
        { args[0].to_sym => args[1] }
      else
        raise ArgumentError, "update_user 인자 오류"
      end

    rows.each_with_index do |row, idx|
      next if idx == 0
      next unless row[0]&.gsub('@','') == acct

      updates.each do |key, value|
        col = {
          id: 0,
          name: 1,
          galleons: 2,
          items: 3,
          memo: 4,
          house: 5,
          last_bet_date: 6,
          bet_count: 7,
          attendance_date: 8,
          last_tarot_date: 9,
          house_score: 10
        }[key.to_sym]

        row[col] = value if col
      end

      write(USERS_SHEET, "A#{idx+1}:K#{idx+1}", [row])
      return true
    end
    false
  end

  def build_user(header, row, line)
    {
      row: line,
      id: row[0],
      name: row[1],
      galleons: row[2].to_i,
      items: row[3].to_s,
      memo: row[4],
      house: row[5]
    }
  end

  # =========================
  # 특별한 인형
  # =========================
  def get_random_doll
    rows = read(DOLL_SHEET, 'A:B')
    return nil if rows.size < 2
    rows[1..].sample.then do |r|
      { name: r[0], image_url: r[1] }
    end
  end

  def log(user, kind, detail = "")
    append(SHOP_LOG_SHEET, [
      Time.now.strftime('%Y-%m-%d %H:%M:%S'),
      user, kind, detail
    ])
  end
end
