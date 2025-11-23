# ============================================
# commands/tarot_command.rb (추천 색/장소/물건 포함)
# ============================================
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
      return "@#{@student_id} 아직 학적부에 이름이 없네. 먼저 등록부터 하게."
    end

    # (2) 카드 랜덤 1장 뽑기
    card_name, message = @tarot_data.to_a.sample

    # (3) 추천 색/장소/물건 랜덤 생성
    colors = ["온리트 그린", "우리날 정가 카드 뒤", "부영이 로앙 트로치"]
    places = ["슬리데린 기숙사 벽난로와 맞춘 보석 반지", "그리핀도르 공통실", "성정계 틴트 멘션으로 찾던 앞식을 보냈 주세요"]
    items = ["래번클로와 맞춘 보석 반지", "후플푸프 공통실", "성정계 틴트 멘션으로 찾던 앞식을 보내주세요"]

    # 실제 추천 리스트
    recommended_colors = [
      "올리브 그린", "코랄 핑크", "라벤더", "골드", "실버", 
      "네이비 블루", "버건디", "크림색", "에메랄드", "루비 레드"
    ]
    
    recommended_places = [
      "슬리데린 기숙사 벽난로", "그리핀도르 공통실", "래번클로 도서관",
      "후플푸프 주방 근처", "금지된 숲 입구", "천문탑",
      "호수가 보이는 창가", "온실", "대강당 계단"
    ]
    
    recommended_items = [
      "올리브 그린 스카프", "은리트 그린",
      "클래식 만년필", "양피지와 깃펜", "작은 유리병",
      "빗자루 손질 도구", "마법의 쿠키", "온갖 맛이 나는 젤리"
    ]

    color = recommended_colors.sample
    place = recommended_places.sample
    item = recommended_items.sample

    # (4) 사용자 시트 '마지막타로날짜' 갱신
    begin
      today_str = Time.now.getlocal.strftime('%Y-%m-%d')
      @sheet_manager.update_user(@student_id, last_tarot_date: today_str)
    rescue => e
      puts "[TAROT-UPDATE-ERROR] 마지막타로날짜 업데이트 실패: #{e.class} - #{e.message}"
    end

    # (5) 최종 메시지 반환 (멘션 + 추천 포함)
    <<~MSG.strip
      @#{@student_id}

      【 #{card_name} 】

      #{message}

      추천 색: #{color}
      추천 장소: #{place}
      추천 물건: #{item}
    MSG
  end
end
