# ============================================
# sheet_manager.rb (안정화 버전)
# Google Sheets A1 기반 읽기/쓰기/append 지원
# ============================================
require 'google/apis/sheets_v4'

class SheetManager
  attr_reader :service, :sheet_id

  USERS_SHEET      = '사용자'.freeze
  PROFESSOR_SHEET  = '교수'.freeze
  SHOP_LOG_SHEET   = '상점로그'.freeze

  def initialize(service, sheet_id)
    @service  = service
    @sheet_id = sheet_id
  end

  # ------------------------------
  # 기본 read/write/append
  # ------------------------------
  def read(sheet_name, a1 = 'A:Z')
    range = a1_range(sheet_name, a1)
    result = service.get_spreadsheet_values(sheet_id, range)
    result.values || []
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
    header = rows.first || []

    # "사용자 ID" 컬럼 찾기
    id_col = header.index("사용자 ID") || header.index("id") || header.index("ID") || header.index("acct")
    return nil unless id_col

    rows[1..].each do |r|
      next if r.nil? || r[id_col].nil?
      return convert_user_row(header, r) if r[id_col].to_s.strip == acct.to_s.strip
    end
    nil
  end

  # ============================================================
  # 사용자 업데이트 (해시 → 열 기준 업데이트)
  # ============================================================
  def update_user(acct, updates)
    rows = read(USERS_SHEET)
    header = rows.first || []

    # "사용자 ID" 컬럼 찾기
    id_col = header.index("사용자 ID") || header.index("id") || header.index("ID") || header.index("acct")
    return false unless id_col

    rows.each_with_index do |row, idx|
      next if idx == 0
      next unless row[id_col].to_s.strip == acct.to_s.strip

      updates.each do |key, value|
        # 영어 키를 한글 헤더로 변환
        header_name = case key.to_sym
                      when :id then "사용자 ID"
                      when :name then "이름"
                      when :galleons then "갈레온"
                      when :items then "아이템"
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
      return true
    end
    false
  end

  # ============================================================
  # 아이템 찾기
  # ============================================================
  def find_item(item_name)
    rows = read('상품')
    header = rows.first || []

    name_col = header.index("상품명") || header.index("이름") || header.index("name")
    return nil unless name_col

    rows[1..].each do |r|
      next if r.nil? || r[name_col].nil?
      if r[name_col].to_s.strip == item_name.to_s.strip
        return convert_item_row(header, r)
      end
    end
    nil
  end

  # ============================================================
  # 행(row) → 해시 변환 (사용자)
  # ============================================================
  def convert_user_row(header, row)
    data = {}
    header.each_with_index do |h, i|
      # 한글 헤더를 영어 키로 변환
      key = case h
            when "사용자 ID" then :id
            when "이름" then :name
            when "갈레온" then :galleons
            when "아이템" then :items
            when "마지막베팅날짜" then :last_bet_date
            when "마지막베팅횟수" then :bet_count
            when "기숙사" then :house
            when "HP" then :hp
            when "공격력" then :attack
            when "출석날짜" then :attendance_date
            when "마지막타로날짜" then :last_tarot_date
            when "기숙사점수" then :house_points
            else h.to_sym
            end
      data[key] = row[i]
    end
    data
  end

  # ============================================================
  # 행(row) → 해시 변환 (아이템)
  # ============================================================
  def convert_item_row(header, row)
    data = {}
    header.each_with_index do |h, i|
      # 아이템 헤더를 영어 키로 변환
      key = case h
            when "상품명" then :name
            when "가격" then :price
            when "설명" then :description
            when "판매가능" then :sellable
            when "사용가능" then :usable
            else h.to_sym
            end
      data[key] = row[i]
    end
    data
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
