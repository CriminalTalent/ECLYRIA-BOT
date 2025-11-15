class TarotCommand
  def initialize(student_id, tarot_data, sheet_manager)
    @student_id    = student_id.to_s.gsub('@', '')
    @tarot_data    = tarot_data
    @sheet_manager = sheet_manager
  end

  def execute
    # (1) 플레이어 확인
    player = @sheet_manager.find_user(@student_id)
    unless player
      return "#{@student_id}(@#{@student_id}) 학생, 아직 학적부에 이름이 없네. 먼저 등록부터 하게."
    end

    # (2) 카드 랜덤 1장 뽑기
    card_name, message = @tarot_data.to_a.sample

    # (3) 사용자 시트 '마지막타로날짜' 갱신
    begin
      today_str = Time.now.getlocal.strftime('%Y-%m-%d')
      @sheet_manager.update_user(@student_id, last_tarot_date: today_str)
    rescue => e
      puts "[TAROT-UPDATE-ERROR] 마지막타로날짜 업데이트 실패: #{e.class} - #{e.message}"
    end

    # (4) 최종 메시지 반환
    <<~MSG.strip
      #{@student_id}(@#{@student_id}) 학생이 카드를 한 장 뽑았네...

      【 #{card_name} 】

      #{message}
    MSG
  end
end
