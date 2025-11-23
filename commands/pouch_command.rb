# ============================================
# commands/pouch_command.rb (간결한 출력)
# ============================================
# encoding: UTF-8
class PouchCommand
  MAX_LENGTH = 450  # 마스토돈 글자 수 제한 (여유 있게)

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "@#{@student_id} 아직 학적부에 없어요~ 교수님께 가서 등록 먼저 하세요!"
    end

    galleons = player[:galleons].to_i
    items_raw = player[:items].to_s.strip

    # 아이템 중복 카운트
    if items_raw.empty?
      items_display = "없음"
      item_counts = {}
    else
      items_array = items_raw.split(",").map(&:strip)
      item_counts = Hash.new(0)
      items_array.each { |item| item_counts[item] += 1 }

      # "아이템명 x개" 형식으로 표시
      items_display = item_counts.map do |item, count|
        count > 1 ? "#{item} x#{count}" : item
      end.join(", ")
    end

    # 기본 메시지 구성 (멘션 + 간결하게)
    base_message = "@#{@student_id}\n갈레온: #{galleons}개\n아이템: "

    # 글자 수 체크 및 분할
    if (base_message + items_display).length <= MAX_LENGTH
      # 한 번에 전송 가능
      return base_message + items_display
    else
      # 여러 메시지로 분할
      item_list = item_counts.map do |item, count|
        count > 1 ? "#{item} x#{count}" : item
      end

      messages = []
      messages << base_message

      temp_items = []
      item_list.each do |item_str|
        test_line = (temp_items + [item_str]).join(", ")

        if test_line.length > MAX_LENGTH
          # 현재까지 모은 아이템 출력
          messages << temp_items.join(", ") unless temp_items.empty?
          temp_items = [item_str]
        else
          temp_items << item_str
        end
      end

      # 마지막 남은 아이템
      messages << temp_items.join(", ") unless temp_items.empty?

      # 첫 메시지에 아이템 시작
      messages[0] += messages[1] if messages.length > 1
      messages.delete_at(1) if messages.length > 1

      return messages
    end
  end
end
```

이제 출력이 이렇게 바뀝니다:

**Before:**
```
@Test 주머니를 열었어요~
갈레온: 999개
아이템: 없음
```

**After:**
```
@Test
갈레온: 999개
아이템: 없음
