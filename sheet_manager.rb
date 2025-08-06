# sheet_manager.rb

require 'google_drive'

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

  def initialize(session, spreadsheet_id)
    @spreadsheet = session.spreadsheet_by_key(spreadsheet_id)
    @ws_users = @spreadsheet.worksheet_by_title('사용자')
    @ws_items = @spreadsheet.worksheet_by_title('아이템')
  end

  # ================================
  # 사용자 관련
  # ================================
  def get_player(user_id)
    (2..@ws_users.num_rows).each do |row|
      if @ws_users[row, PLAYER_COLUMNS[:id]] == user_id
        return {
          row: row,
          id: user_id,
          name: @ws_users[row, PLAYER_COLUMNS[:name]],
          galleons: @ws_users[row, PLAYER_COLUMNS[:galleons]].to_i,
          items: @ws_users[row, PLAYER_COLUMNS[:items]].to_s,
          memo: @ws_users[row, PLAYER_COLUMNS[:memo]],
          house: @ws_users[row, PLAYER_COLUMNS[:house]],
          last_bet_date: @ws_users[row, PLAYER_COLUMNS[:last_bet_date]],
          bet_count: @ws_users[row, PLAYER_COLUMNS[:bet_count]].to_i,
          attendance_date: @ws_users[row, PLAYER_COLUMNS[:attendance_date]],
          last_tarot_date: @ws_users[row, PLAYER_COLUMNS[:last_tarot_date]]
        }
      end
    end
    nil
  end

  def update_player_field(row, field_sym, value)
    col = PLAYER_COLUMNS[field_sym]
    return unless col
    @ws_users[row, col] = value
    @ws_users.save
  end

  def update_player(player)
    row = player[:row]
    PLAYER_COLUMNS.each do |key, col|
      next unless player.key?(key)
      @ws_users[row, col] = player[key]
    end
    @ws_users.save
  end

  # ================================
  # 아이템 관련
  # ================================
  def get_item(item_name)
    (2..@ws_items.num_rows).each do |row|
      if @ws_items[row, ITEM_COLUMNS[:name]] == item_name
        return {
          row: row,
          name: item_name,
          price: @ws_items[row, ITEM_COLUMNS[:price]].to_i,
          description: @ws_items[row, ITEM_COLUMNS[:description]],
          purchasable: @ws_items[row, ITEM_COLUMNS[:purchasable]].to_s.strip.upcase == 'TRUE',
          transferable: @ws_items[row, ITEM_COLUMNS[:transferable]].to_s.strip.upcase == 'TRUE',
          usable: @ws_items[row, ITEM_COLUMNS[:usable]].to_s.strip.upcase == 'TRUE',
          effect: @ws_items[row, ITEM_COLUMNS[:effect]],
          consumable: @ws_items[row, ITEM_COLUMNS[:consumable]].to_s.strip.upcase == 'TRUE'
        }
      end
    end
    nil
  end

  # ================================
  # 인벤토리 처리
  # ================================
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
