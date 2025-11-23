# ============================================
# sheet_manager.rb (수정 버전 - 디버깅 강화)
# Google Sheets A1 기반 읽기/쓰기/append 지원
# ============================================
require 'google/apis/sheets_v4'

class SheetManager
  attr_reader :service, :sheet_id

  USERS_SHEET      = '사용자'.freeze
  PROFESSOR_SHEET  = '교수'.freeze
  SHOP_LOG_SHEET   = '상점로그'.freeze
  ITEMS_SHEET      = '아이템'.freeze  # ← 실제 시트명으로 수정

  def initialize(service, sheet_id)
    @service  = service
    @sheet_id = sheet_id
    
    # 초기화 시 시트 목록 확인
    check_sheets
  end

  # ============================================================
  # 시트 목록 확인 (디버깅용)
  # ============================================================
  def check_sheets
    begin
      spreadsheet = service.get_spreadsheet(sheet_id)
      sheet_names = spreadsheet.sheets.map { |s| s.properties.title }
      puts "[SHEETS] 사용 가능한 시트: #{sheet_names.join(', ')}"
      
      # 필수 시트 확인
      required = [USERS_SHEET, ITEMS_SHEET]
      missing = required - sheet_names
      
      if missing.any?
        puts "[경고] 누락된 시트: #{missing.join(', ')}"
      end
    rescue => e
      puts "[SHEETS-CHECK 오류] #{e.message}"
    end
  end

  # ------------------------------
  # 기본 read/write/append
  # ------------------------------
  def read(sheet_name, a1 = 'A:Z')
    range = a1_range(sheet_name, a1)
    result = service.get_spreadsheet_values(sheet_id, range)
    result.values || []
  rescue => e
    puts "[READ 오류] 시트: #{sheet_name}, 범위: #{a1}, 에러: #{e.message}"
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

  # ============================================================
  # 사용자 찾기 (상점/교수/전투 시스템 공통)
  # ============================================================
  def find_user(acct)
    rows = read(USERS_SHEET)
    return nil if rows.empty?
    
    header = rows.first || []
    puts "[FIND_USER] 헤더: #{header.inspect}"

    # "사용자 ID" 또는 "A" 컬럼 찾기
    id_col = header.index("사용자 ID") || header.index("A") || 0
    
    puts "[FIND_USER] ID 컬럼 인덱스: #{id_col}"

    rows[1..].each do |r|
      next if r.nil? || r[id_col].nil?
      if r[id_col].to_s.strip == acct.to_s.strip
        puts "[FIND_USER] 찾음: #{acct}"
        return convert_user_row(header, r)
      end
    end
    
    puts "[FIND_USER] 못 찾음: #{acct}"
    nil
  end

  # ============================================================
  # 사용자 업데이트 (해시 → 열 기준 업데이트)
  # ============================================================
  def update_user(acct, updates)
    rows = read(USERS_SHEET)
    header = rows.first || []

    # "사용자 ID" 또는 "A" 컬럼 찾기
    id_col = header.index("사용자 ID") || header.index("A") || 0
    
    rows.each_with_index do |row, idx|
      next if idx == 0
      next unless row[id_col].to_s.strip == acct.to_s.strip

      updates.each do |key, value|
        # 영어 키를 한글 헤더로 변환
        header_name = case key.to_sym
                      when :id then header[0]  # 첫 번째 컬럼 (사용자 ID)
                      when :name then "B"
                      when :galleons then "C"
                      when :items then "D"
                      when :last_bet_date then "마지막베팅날짜"
                      when :bet_count then "마지막베팅횟수"
                      when :house then "기숙사"
                      when :hp then "HP"
                      when :attack then "공격력"
                      when :attendance_date then "출석날짜"
                      when :last_tarot_date then "마지막타로날짜"
                      when :house_points then "기숙사점수"
                      else key.to_s
                      end

        col = header.index(header_name)
        next unless col

        row[col] = value
      end

      write(USERS_SHEET, "A#{idx+1}:Z#{idx+1}", [row])
      puts "[UPDATE_USER] 업데이트 완료: #{acct}, #{updates.inspect}"
      return true
    end
    false
  end

  # ============================================================
  # 아이템 찾기 (디버깅 강화)
  # ============================================================
  def find_item(item_name)
    rows = read(ITEMS_SHEET)
    
    if rows.empty?
      puts "[FIND_ITEM] ERROR: '#{ITEMS_SHEET}' 시트가 비어있거나 존재하지 않음"
      return nil
    end
    
    header = rows.first || []
    puts "[FIND_ITEM] 헤더: #{header.inspect}"
    puts "[FIND_ITEM] 검색 아이템: #{item_name}"

    # A열 = 아이템명
    name_col = 0
    
    puts "[FIND_ITEM] 아이템명 컬럼 인덱스: #{name_col}"

    rows[1..].each_with_index do |r, idx|
      next if r.nil? || r[name_col].nil?
      
      row_item_name = r[name_col].to_s.strip
      puts "[FIND_ITEM] 행 #{idx+2}: #{row_item_name}"
      
      if row_item_name == item_name.to_s.strip
        puts "[FIND_ITEM] 찾음: #{item_name}"
        result = convert_item_row(header, r)
        puts "[FIND_ITEM] 결과: #{result.inspect}"
        return result
      end
    end
    
    puts "[FIND_ITEM] 못 찾음: #{item_name}"
    nil
  end

  # ============================================================
  # 행(row) → 해시 변환 (사용자)
  # ============================================================
  def convert_user_row(header, row)
    {
      id: row[0],           # A: 사용자 ID
      name: row[1],         # B: 이름
      galleons: row[2],     # C: 갈레온
      items: row[3],        # D: 아이템
      house: row[4],        # E: 기숙사
      # 필요한 다른 컬럼들 추가
      last_bet_date: row[10],
      bet_count: row[11],
      last_tarot_date: row[12]
    }
  end

  # ============================================================
  # 행(row) → 해시 변환 (아이템)
  # ============================================================
  def convert_item_row(header, row)
    {
      name: row[0],         # A: 아이템명
      description: row[1],  # B: 설명
      price: row[2],        # C: 가격
      sellable: row[3],     # D: 판매여부 (체크박스)
      usable: row[4],       # E: 사용 및 양도가능 (체크박스)
      image_url: row[5]     # F: 아미지URL
    }
  end

  # ============================================================
  # A1 → 시트명!A1 자동 보정
  # ============================================================
  def a1_range(sheet_name, a1)
    if a1.include?('!')
      a1
    else
      "#{sheet_name}!#{a1}"
    end
  end

  # ============================================================
  # 로그 기록 (상점 로그)
  # ============================================================
  def log_command(user, kind, value = nil, detail = "")
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    row = [timestamp, kind, user, value.to_s, detail.to_s]
    append(SHOP_LOG_SHEET, row)
  rescue => e
    puts "[로그 오류] #{e.message}"
  end
end
