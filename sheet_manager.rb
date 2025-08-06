# sheet_manager.rb
require 'google_drive'

class SheetManager
  def initialize(spreadsheet)
    @spreadsheet = spreadsheet
  end

  def worksheet_by_title(title)
    @spreadsheet.worksheet_by_title(title)
  end

  # 사용자 시트에서 특정 사용자 정보 반환 (Hash)
  def get_player(student_id)
    ws = worksheet_by_title("사용자")
    (2..ws.num_rows).each do |row|
      return row_to_hash(ws, row) if ws[row, 1] == student_id
    end
    nil
  end

  # 사용자 정보 갱신
  def update_player(player_data)
    ws = worksheet_by_title("사용자")
    (2..ws.num_rows).each do |row|
      if ws[row, 1] == player_data["id"]
        ws[row, 2] = player_data["galleons"]
        ws[row, 3] = player_data["items"]
        ws[row, 4] = player_data["debt"]
        ws.save
        return true
      end
    end
    false
  end

  # 아이템 시트에서 특정 아이템 정보 반환 (Hash)
  def get_item(item_name)
    ws = worksheet_by_title("아이템")
    (2..ws.num_rows).each do |row|
      next unless ws[row, 4].to_s.strip.upcase == "TRUE"  # 판매중 여부
      return row_to_hash(ws, row) if ws[row, 1] == item_name
    end
    nil
  end

  # 타로 텍스트 불러오기
  def tarot_data
    ws = worksheet_by_title("타로로그")
    data = {}
    (2..ws.num_rows).each do |row|
      card = ws[row, 1]
      meaning = ws[row, 2]
      data[card] = meaning
    end
    data
  end

  private

  # 한 행을 헤더 기반 Hash로 변환
  def row_to_hash(ws, row)
    headers = ws.rows.first
    Hash[headers.each_with_index.map { |h, i| [h.strip, ws[row, i + 1]] }]
  end
end
