# sheet_manager.rb
require 'google/apis/sheets_v4'

class SheetManager
  PLAYER_COLUMNS = {
    id: 1,
    name: 2,
    galleons: 3,
    items: 4,
    memo: 5,
    house: 6,
    last_bet_date: 7,
    bet_count: 8,
    attendance_date: 9,
    last_tarot_date: 10
  }

  ITEM_COLUMNS = {
    name: 1,
    price: 2,
    description: 4,
    purchasable: 5,
    transferable: 6,
    usable: 7,
    effect: 8,
    consumable: 9
  }

  def initialize(sheets_service, spreadsheet_id)
    @service = sheets_service
    @spreadsheet_id = spreadsheet_id
  end

  def get_player(user_id)
    range = "사용자!A:J"
    begin
      response = @service.get_spreadsheet_values(@spreadsheet_id, range)
      values = response.values || []
      
      values.each_with_index do |row, index|
        next if index == 0 # 헤더 스킵
        if row[0] == user_id
          return {
            row: index + 1,
            id: user_id,
            name: row[1],
            galleons: (row[2] || 0).to_i,
            items: (row[3] || "").to_s,
            memo: row[4],
            house: row[5],
            last_bet_date: row[6],
            bet_count: (row[7] || 0).to_i,
            attendance_date: row[8],
            last_tarot_date: row[9]
          }
        end
      end
    rescue => e
      puts "플레이어 조회 오류: #{e.message}"
    end
    nil
  end

  def update_player_field(row, field_sym, value)
    col = PLAYER_COLUMNS[field_sym]
    return unless col
    
    range = "사용자!#{('A'.ord + col - 1).chr}#{row + 1}"
    value_range = Google::Apis::SheetsV4::ValueRange.new
    value_range.values = [[value]]
    
    begin
      @service.update_spreadsheet_value(
        @spreadsheet_id,
        range,
        value_range,
        value_input_option: 'RAW'
      )
    rescue => e
      puts "플레이어 필드 업데이트 오류: #{e.message}"
    end
  end

  def update_player(player)
    row = player[:row]
    range = "사용자!A#{row + 1}:J#{row + 1}"
    
    values = [
      player[:id],
      player[:name],
      player[:galleons],
      player[:items],
      player[:memo],
      player[:house],
      player[:last_bet_date],
      player[:bet_count],
      player[:attendance_date],
      player[:last_tarot_date]
    ]
    
    value_range = Google::Apis::SheetsV4::ValueRange.new
    value_range.values = [values]
    
    begin
      @service.update_spreadsheet_value(
        @spreadsheet_id,
        range,
        value_range,
        value_input_option: 'RAW'
      )
    rescue => e
      puts "플레이어 업데이트 오류: #{e.message}"
    end
  end

  def get_item(item_name)
    range = "아이템!A:I"
    begin
      response = @service.get_spreadsheet_values(@spreadsheet_id, range)
      values = response.values || []
      
      values.each_with_index do |row, index|
        next if index == 0 # 헤더 스킵
        if row[0] == item_name
          return {
            row: index + 1,
            name: item_name,
            price: (row[1] || 0).to_i,
            description: row[3],
            purchasable: (row[4] || "").to_s.strip.upcase == 'TRUE',
            transferable: (row[5] || "").to_s.strip.upcase == 'TRUE',
            usable: (row[6] || "").to_s.strip.upcase == 'TRUE',
            effect: row[7],
            consumable: (row[8] || "").to_s.strip.upcase == 'TRUE'
          }
        end
      end
    rescue => e
      puts "아이템 조회 오류: #{e.message}"
    end
    nil
  end

  def add_item_to_inventory(items_str, item_name)
    items = items_str.to_s.split(',').map(&:strip)
    items << item_name
    items.join(',')
  end

  def remove_item_from_inventory(items_str, item_name)
    items = items_str.to_s.split(',').map(&:strip)
    items.delete(item_name)
    items.join(',')
  end
end
