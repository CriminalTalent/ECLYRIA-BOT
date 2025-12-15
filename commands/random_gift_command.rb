# commands/random_gift_command.rb
class RandomGiftCommand
  GIFTS = [
    # 마법 아이템 (20개)
    "마법 물약병", "수정 구슬", "은빛 부적", "보호 목걸이", "마법 반지",
    "투명 망토 조각", "시간의 모래시계", "예언의 수정", "마법 거울",
    "룬 문자 돌", "마법 지팡이 홀더", "마나석", "정화의 촛불",
    "소원의 별", "마법 나침반", "행운의 클로버", "변신 가루",
    "텔레포트 가루", "마법 가방", "차원의 열쇠",
    
    # 문구류 (20개)
    "불사조 깃펜", "용 가죽 노트", "마법 잉크", "자동 필기 깃펜",
    "사라지는 잉크", "편지지 세트", "밀랍 인장", "양피지 두루마리",
    "책갈피", "마법 자", "지우개", "연필 세트", "만년필",
    "스케치북", "메모장", "포스트잇", "클립 세트", "스탬프",
    "폴더", "필통",
    
    # 장난감/게임 (20개)
    "마법사 체스말", "폭발 스냅 카드", "미니 피규어", "마법 카드",
    "요요", "팽이", "구슬 세트", "마법 주사위", "퍼즐",
    "인형", "미니카", "블록", "보드게임", "트레이딩 카드",
    "스티커", "배지", "키링", "자석", "칼레이도스코프", "탄성공",
    
    # 의류/액세서리 (40개)
    "목도리", "머플러", "스카프", "장갑", "벙어리장갑", "털모자",
    "비니", "헤어밴드", "머리띠", "리본", "헤어핀", "머리끈",
    "뱃지", "브로치", "핀", "단추", "패치", "와펜",
    "팔찌", "발찌", "목걸이", "귀걸이", "반지", "반지(은)",
    "반지(금)", "헤어클립", "머리빗", "거울", "손수건",
    "파우치", "동전지갑", "카드지갑", "열쇠고리", "스트랩",
    "양말", "레그워머", "암워머", "귀마개", "마스크", "안대"
  ].freeze

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[RANDOM_GIFT] START user=#{@student_id}"
    
    # 사용자 검색
    user = @sheet_manager.find_user(@student_id)
    unless user
      puts "[RANDOM_GIFT] USER NOT FOUND: #{@student_id}"
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    # 갈레온 마이너스 체크
    if user[:galleons].to_i < 0
      return "@#{@student_id} 갈레온이 마이너스 상태라 선물을 받을 수 없어요."
    end

    # 랜덤 선물 선택
    gift = GIFTS.sample

    # 인벤토리 추가
    current_items = user[:items].to_s.split(",").map(&:strip).reject(&:empty?)
    current_items << gift
    new_items = current_items.join(",")

    # 시트 업데이트
    @sheet_manager.update_user(@student_id, { items: new_items })

    puts "[RANDOM_GIFT] SUCCESS user=#{@student_id} gift=#{gift}"

    "@#{@student_id} 랜덤 선물을 받았어요!\n\n#{gift}\n\n주머니에 추가되었어요!"
  rescue => e
    puts "[RANDOM_GIFT][ERROR] #{e.class}: #{e.message}"
    "@#{@student_id} 선물을 받는 도중 문제가 생겼어요. 잠시 후 다시 시도해주세요."
  end
end
