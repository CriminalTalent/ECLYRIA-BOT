# sheet_manager.rb
require 'google/apis/sheets_v4'

class SheetManager
  attr_reader :service, :sheet_id

  USERS_SHEET = '사용자'.freeze
  ITEMS_SHEET = '아이템'.freeze
  DOLL_SHEET  = '특별한인형'.freeze
  SHOP_LOG    = '상점로그'.freeze

  def initialize(service, sheet_id)
    @service = service
    @sheet_id = sheet_id
    check_sheets
  end

  def check_sheets
    sheets = service.get_spreadsheet(sheet_id).sheets.map { |s| s.properties.title }
    puts "[SHEETS] 사용 가능한 시트: #{sheets.join(', ')}"
  rescue => e
    puts "[SHEETS 오류] #{e.message}"
  end

  # =====================
  # 기본 read / write
  # =====================
  def read(sheet, range = 'A:Z')
    service.get_spreadsheet_values(sheet_id, "#{sheet}!#{range}").values || []
  rescue
    []
  end

  def append(sheet, row)
    body = Google::Apis::SheetsV4::ValueRange.new(values: [row])
    service.append_spreadsheet_value(
      sheet_id,
      "#{sheet}!A:Z",
      body,
      value_input_option: 'USER_ENTERED'
    )
  end

  # =====================
  # 사용자
  # =====================
  def find_user(acct)
    acct = acct.gsub('@', '')
    rows = read(USERS_SHEET, 'A:K')
    rows[1..].each_with_index do |r, i|
      next unless r[0]&.gsub('@','') == acct
      return {
        row: i + 2,
        id: r[0],
        name: r[1],
        galleons: r[2].to_i,
        items: r[3].to_s
      }
    end
    nil
  end

  def update_user(user)
    write_row = [
      user[:id],
      user[:name],
      user[:galleons],
      user[:items]
    ]
    service.update_spreadsheet_value(
      sheet_id,
      "#{USERS_SHEET}!A#{user[:row]}:D#{user[:row]}",
      Google::Apis::SheetsV4::ValueRange.new(values: [write_row]),
      value_input_option: 'USER_ENTERED'
    )
  end

  # =====================
  # 아이템
  # =====================
  def find_item(item_name)
    rows = read(ITEMS_SHEET, 'A:F')
    rows[1..].each do |r|
      next if r[0].nil?
      next unless r[0].strip == item_name

      return {
        name: r[0].to_s.strip,
        description: r[1].to_s.strip,
        price: r[2].to_i,
        sellable: r[3].to_s == 'TRUE',
        usable: r[4].to_s == 'TRUE',
        image: r[5].to_s
      }
    end
    nil
  end

  # =====================
  # 특별한 인형
  # =====================
  def get_random_doll
    rows = read(DOLL_SHEET, 'A:B')
    dolls = rows[1..].map do |r|
      next if r[0].nil? || r[1].nil?
      { name: r[0], image_url: r[1] }
    end.compact
    dolls.sample
  end

  # =====================
  # 로그
  # =====================
  def log(kind, user, detail = '')
    append(SHOP_LOG, [
      Time.now.strftime('%Y-%m-%d %H:%M:%S'),
      kind, user, detail
    ])
  end
end
