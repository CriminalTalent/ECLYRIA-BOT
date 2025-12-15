# commands/random_gift_command.rb
# encoding: UTF-8

class RandomGiftCommand
  GIFTS = [
    # 마법 아이템 (20개)
    "작은 물약병", "깃털 부적", "수정 구슬", "마법 동전", "행운의 돌멩이",
    "반짝이는 가루", "작은 두루마리", "마법 종이학", "빛나는 구슬", "수호 부적",
    "작은 거울", "마법 리본", "별가루 주머니", "달빛 구슬", "요정 가루",
    "마법 스티커", "빛나는 돌", "작은 수정", "마법 열쇠", "신비한 깃털",
    
    # 문구류 (20개)
    "깃펜", "잉크병", "양피지", "작은 노트", "책갈피",
    "스탬프", "편지지", "봉투", "스티커", "엽서",
    "메모지", "색연필", "크레용", "지우개", "자",
    "클립", "스탬프 패드", "리본", "스티커 세트", "색종이",
    
    # 장난감/게임 (20개)
    "작은 피규어", "마법 카드", "미니 체스", "주사위", "팽이",
    "요요", "공", "미니 인형", "작은 로봇", "장난감 빗자루",
    "작은 망원경", "나침반", "호루라기", "비눗방울", "마법 풍선",
    "미니 퍼즐", "작은 북", "종", "썰매", "눈송이 장식",
    
    # 의류/액세서리 (40개)
    "스카프", "장갑", "모자", "머리띠", "목도리",
    "뱃지", "핀", "브로치", "반지", "팔찌",
    "목걸이", "귀걸이", "헤어핀", "머리끈", "손수건",
    "양말", "벨트", "넥타이", "리본", "머플러",
    "숄", "베레모", "비니", "털모자", "귀마개",
    "장갑 세트", "니트 장갑", "가죽 장갑", "팔찌 세트", "발찌",
    "초커", "펜던트", "로켓", "체인", "코르사주",
    "타이핀", "커프스", "시계줄", "키링", "가방 고리"
  ]

  def initialize(student_id, sheet_manager)
    @student_id = student_id.gsub('@', '')
    @sheet_manager = sheet_manager
  end

  def execute
    puts "[GIFT] START user=#{@student_id}"
    
    # 플레이어 확인
    player = @sheet_manager.find_user(@student_id)
    unless player
      puts "[GIFT] ERROR: player not found (@#{@student_id})"
      return "@#{@student_id} 아직 학적부에 등록되지 않았어요."
    end

    # 100개 중 랜덤 선택
    gift = GIFTS.sample
    puts "[GIFT] 선택된 선물: #{gift}"

    # 현재 아이템 목록 가져오기
    current_items = player[:items].to_s.split(',').map(&:strip)
    current_items << gift
    new_items = current_items.join(',')

    puts "[GIFT] 기존 아이템: #{player[:items]}"
    puts "[GIFT] 새 아이템: #{new_items}"

    # 아이템 업데이트
    @sheet_manager.update_user(@student_id, {
      items: new_items
    })

    message = "@#{@student_id} 랜덤 선물 상자를 열었어요!\n"
    message += "#{gift}을(를) 받았어요!"

    puts "[GIFT] SUCCESS: #{message}"
    return message
  end
end
