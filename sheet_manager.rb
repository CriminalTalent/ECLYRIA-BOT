# sheet_manager.rb (상점봇 전용 - 열 매핑 수정 버전)
require 'google/apis/sheets_v4'

class SheetManager
  attr_reader :service, :sheet_id

  USERS_SHEET      = '사용자'.freeze
  PROFESSOR_SHEET  = '교수'.freeze
  SHOP_LOG_SHEET   = '상점로그'.freeze
  ITEMS_SHEET      = '아이템'.freeze

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
      
      if missing.any?
        puts "[경고] 누락된 시트: #{missing.join(', ')}"
      end
    rescue => e
      puts "[SHEETS-CHECK 오류] #{e.message}"
    end
  end

  # 기본 read 메서드
  def read(sheet_name, a1 = 'A:Z')
    range = a1_range(sheet_name, a1)
    result = service.get_spreadsheet_values(sheet_id, range)
    result.values || []
  rescue => e
    puts "[READ 오류] 시트: #{sheet_name}, 범위: #{a1}, 에러: #{e.message}"
    []
  end

  # 기본 write 메서드
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

  # 기본 append 메서드
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

  # 사용자 찾기
  def find_user(acct)
    clean_acct = acct.to_s.gsub('@', '').strip
    rows = read(USERS_SHEET, 'A:K')
    return nil if rows.empty?
    
    header = rows.first || []
    puts "[FIND_USER] 검색 ID: #{clean_acct}"

    rows[1..].each_with_index do |r, idx|
      next if r.nil? || r[0].nil?
      row_id = r[0].to_s.gsub('@', '').strip
      
      if row_id == clean_acct
        puts "[FIND_USER] 찾음: #{clean_acct} (행: #{idx+2})"
        return convert_user_row(header, r, idx + 1)
      end
    end
    
    puts "[FIND_USER] 못 찾음: #{clean_acct}"
    nil
  end

  # 사용자 업데이트
  def update_user(acct, updates)
    clean_acct = acct.to_s.gsub('@', '').strip
    rows = read(USERS_SHEET, 'A:K')
    header = rows.first || []

    rows.each_with_index do |row, idx|
      next if idx == 0
      next if row.nil? || row[0].nil?
      
      row_id = row[0].to_s.gsub('@', '').strip
      next unless row_id == clean_acct

      updates.each do |key, value|
        col = case key.to_sym
              when :id then 0
              when :name then 1
              when :galleons then 2
              when :items then 3
              when :memo then 4
              when :house then 5
              when :last_bet_date then 6
              when :bet_count then 7
              when :attendance_date then 8
              when :last_tarot_date then 9
              when :house_score then 10
              else nil
              end
        
        if col
          while row.length <= col
            row << ""
          end
          row[col] = value
        end
      end

      write(USERS_SHEET, "A#{idx+1}:K#{idx+1}", [row])
      puts "[UPDATE_USER] 업데이트 완료: #{clean_acct}"
      return true
    end
    
    puts "[UPDATE_USER] 실패: #{clean_acct} 찾을 수 없음"
    false
  end

  # 아이템 찾기
  def find_item(item_name)
    rows = read(ITEMS_SHEET, 'A:E')
    
    if rows.empty?
      puts "[FIND_ITEM] ERROR: '#{ITEMS_SHEET}' 시트가 비어있음"
      return nil
    end
    
    header = rows.first || []
    puts "[FIND_ITEM] 검색 아이템: #{item_name}"

    rows[1..].each_with_index do |r, idx|
      next if r.nil? || r[0].nil?
      
      row_item_name = r[0].to_s.strip
      
      if row_item_name == item_name.to_s.strip
        puts "[FIND_ITEM] 찾음: #{item_name} (행: #{idx+2})"
        result = convert_item_row(header, r)
        return result
      end
    end
    
    puts "[FIND_ITEM] 못 찾음: #{item_name}"
    nil
  end

  # 사용자 행 변환
  def convert_user_row(header, row, row_index)
    {
      row: row_index,
      id: row[0].to_s.strip,
      name: row[1].to_s.strip,
      galleons: (row[2] || 0).to_i,
      items: (row[3] || "").to_s.strip,
      memo: (row[4] || "").to_s.strip,
      house: (row[5] || "").to_s.strip,
      last_bet_date: (row[6] || "").to_s.strip,
      bet_count: (row[7] || 0).to_i,
      attendance_date: (row[8] || "").to_s.strip,
      last_tarot_date: (row[9] || "").to_s.strip,
      house_score: (row[10] || 0).to_i
    }
  end

  # 아이템 행 변환 (수정됨)
  def convert_item_row(header, row)
    # A열: 아이템명
    # B열: 설명 (긴 텍스트)
    # C열: 가격
    # D열: 판매여부 (체크박스)
    # E열: 사용 및 양도가능 (체크박스)
    
    price_value = row[2].to_s.strip
    price = price_value.empty? ? 0 : price_value.to_i
    
    # B열: 설명
    description = (row[1] || "").to_s.strip
    
    # D열: 판매여부
    sellable_value = row[3]
    sellable = (sellable_value == true || sellable_value.to_s.strip.upcase == "TRUE")
    
    # E열: 사용 및 양도가능
    usable_value = row[4]
    usable = (usable_value == true || usable_value.to_s.strip.upcase == "TRUE")
    
    {
      name: row[0].to_s.strip,
      price: price,
      description: description,
      sellable: sellable,
      usable: usable,
      purchasable: sellable,
      transferable: true,
      effect: "",
      consumable: usable
    }
  end

  # A1 범위 생성
  def a1_range(sheet_name, a1)
    if a1.include?('!')
      a1
    else
      "#{sheet_name}!#{a1}"
    end
  end

  # 상점 로그 기록
  def log_command(user, kind, value = nil, detail = "")
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    row = [timestamp, kind, user, value.to_s, detail.to_s]
    append(SHOP_LOG_SHEET, row)
  rescue => e
    puts "[로그 오류] #{e.message}"
  end
end
