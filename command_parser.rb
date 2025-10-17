# command_parser.rb
require_relative 'commands/buy_command'
require_relative 'commands/transfer_item_command'
require_relative 'commands/transfer_galleons_command'
require_relative 'commands/use_item_command'
require_relative 'commands/pouch_command'
require_relative 'commands/tarot_command'
require_relative 'commands/bet_command'
require_relative 'commands/dice_command'
require_relative 'commands/coin_command'
require_relative 'commands/yn_command'

module CommandParser
  TAROT_DATA = {
    # 메이저 아르카나 (22장)
    "THE FOOL" => "순수한 마음으로 새로운 모험을 시작할 때입니다. 두려움 없이 미지의 세계로 발걸음을 내딛어보세요. 때로는 계획보다 직감을 따르는 것이 더 큰 기회를 가져다줄 수 있습니다.",
    "THE MAGICIAN" => "당신 안에 잠든 무한한 가능성이 깨어나고 있습니다. 의지력과 집중력으로 원하는 것을 현실로 만들어낼 수 있는 시기입니다. 자신감을 가지고 목표를 향해 나아가세요.",
    "THE HIGH PRIESTESS" => "논리보다는 직감을 믿어야 할 시간입니다. 내면의 목소리에 귀 기울이고, 숨겨진 진실을 발견할 수 있을 것입니다. 침묵 속에서 지혜를 찾아보세요.",
    "THE EMPRESS" => "창조와 풍요의 에너지가 당신을 둘러싸고 있습니다. 새로운 것을 만들어내거나 기존의 것을 키워나가는 데 최적의 시기입니다. 사랑과 보살핌의 마음을 나누어보세요.",
    "THE EMPEROR" => "안정된 기반 위에서 체계적으로 일을 진행할 때입니다. 리더십을 발휘하고 명확한 규칙과 질서를 만들어나가세요. 책임감 있는 결정이 성공을 이끌 것입니다.",
    "THE HIEROPHANT" => "전통적인 가치와 지혜에서 답을 찾을 수 있습니다. 스승이나 멘토의 조언을 구하거나, 기존의 방법을 따르는 것이 도움이 될 것입니다. 배움의 자세를 가져보세요.",
    "THE LOVERS" => "중요한 선택의 기로에 서 있습니다. 마음과 이성의 균형을 맞추어 신중하게 결정하세요. 진정한 사랑이나 깊은 유대감을 경험할 수 있는 시기이기도 합니다.",
    "THE CHARIOT" => "강한 의지력으로 어떤 장애물도 극복할 수 있습니다. 목표를 향해 전진할 때이지만, 감정을 통제하고 균형을 유지하는 것이 중요합니다. 승리가 눈앞에 있습니다.",
    "STRENGTH" => "부드러운 힘이 강한 힘을 이깁니다. 인내와 자비로운 마음으로 어려운 상황을 다스릴 수 있을 것입니다. 내면의 용기를 믿고 차분하게 대처해보세요.",
    "THE HERMIT" => "홀로 있는 시간이 필요합니다. 내면을 돌아보고 자신만의 진리를 찾아가는 여정에 있습니다. 고독 속에서 얻는 깨달음이 앞으로의 길을 밝혀줄 것입니다.",
    "WHEEL OF FORTUNE" => "인생의 큰 전환점에 서 있습니다. 운명의 바퀴가 돌아가며 새로운 기회와 변화를 가져다줄 것입니다. 변화의 흐름에 자연스럽게 몸을 맡겨보세요.",
    "JUSTICE" => "공정하고 균형 잡힌 판단이 필요한 시기입니다. 모든 선택에는 그에 따른 결과가 따릅니다. 진실과 정의를 추구하며 올바른 결정을 내려보세요.",
    "THE HANGED MAN" => "때로는 멈춤이 전진보다 현명할 수 있습니다. 새로운 관점에서 상황을 바라보고, 내적 성장을 위한 시간을 가져보세요. 희생이 더 큰 이득을 가져다줄 것입니다.",
    "DEATH" => "끝남과 동시에 새로운 시작이 옵니다. 과거에 얽매이지 말고 변화를 받아들이세요. 낡은 것들을 버리고 새로운 자신으로 태어날 수 있는 기회입니다.",
    "TEMPERANCE" => "극단을 피하고 중용의 길을 택하세요. 서로 다른 것들 사이에서 조화를 이루어내는 것이 핵심입니다. 인내심을 가지고 천천히 목표를 향해 나아가세요.",
    "THE DEVIL" => "물질적 욕망이나 나쁜 습관에 얽매여 있을 수 있습니다. 스스로 만든 사슬을 끊고 자유로워질 때입니다. 진정한 자아를 찾기 위해 용기를 내어보세요.",
    "THE TOWER" => "예상치 못한 변화나 충격적인 사건이 일어날 수 있습니다. 하지만 이는 새로운 기반을 쌓기 위한 과정입니다. 무너진 것에 연연하지 말고 더 견고한 미래를 준비하세요.",
    "THE STAR" => "어둠 속에서도 희망의 빛이 당신을 인도합니다. 꿈과 이상을 향해 나아갈 용기를 가지세요. 영감과 직감이 올바른 길을 보여줄 것입니다.",
    "THE MOON" => "혼란스럽고 불확실한 시기일 수 있습니다. 환상과 현실을 구분하고, 내면의 두려움과 마주해야 할 때입니다. 직감을 믿되 신중하게 행동하세요.",
    "THE SUN" => "밝고 긍정적인 에너지가 당신을 감싸고 있습니다. 성공과 기쁨, 행복이 가득한 시기입니다. 자신감을 가지고 당당하게 앞으로 나아가세요.",
    "JUDGEMENT" => "과거를 되돌아보고 새로운 각성을 경험할 때입니다. 용서와 화해를 통해 새로운 단계로 나아갈 수 있습니다. 내면의 소명에 귀를 기울여보세요.",
    "THE WORLD" => "하나의 큰 여정이 완성되고 새로운 시작을 준비할 때입니다. 성취감과 만족감을 느끼며, 더 큰 목표를 향해 나아갈 준비가 되었습니다.",

    # 완드(불) 수트 - 열정, 창조, 영감
    "ACE OF WANDS" => "새로운 창조적 에너지가 분출되고 있습니다. 열정적인 프로젝트나 모험을 시작하기에 완벽한 시기입니다.",
    "TWO OF WANDS" => "미래에 대한 계획을 세우고 있습니다. 더 넓은 세계로 나아갈 준비를 하며 장기적인 비전을 그려보세요.",
    "THREE OF WANDS" => "노력한 것들이 결실을 맺기 시작합니다. 확장과 성장의 기회가 찾아오니 적극적으로 활용하세요.",
    "FOUR OF WANDS" => "축하와 기쁨의 시간입니다. 안정된 기반 위에서 소중한 사람들과 행복을 나누어보세요.",
    "FIVE OF WANDS" => "경쟁과 갈등 상황에 직면했습니다. 건설적인 경쟁을 통해 자신을 발전시킬 기회로 삼으세요.",
    "SIX OF WANDS" => "승리와 인정을 받을 때입니다. 당신의 노력과 재능이 마침내 빛을 발하고 있습니다.",
    "SEVEN OF WANDS" => "자신의 신념을 지키기 위해 맞서야 할 때입니다. 포기하지 말고 끝까지 버텨내세요.",
    "EIGHT OF WANDS" => "빠른 변화와 진전이 예상됩니다. 기회를 놓치지 말고 신속하게 행동하세요.",
    "NINE OF WANDS" => "마지막 고비를 넘고 있습니다. 지금까지의 경험을 바탕으로 조금만 더 인내하면 성공이 기다리고 있습니다.",
    "TEN OF WANDS" => "무거운 책임과 부담을 지고 있습니다. 도움을 요청하거나 우선순위를 정리해보세요.",
    "PAGE OF WANDS" => "새로운 소식이나 기회가 찾아올 것입니다. 열린 마음으로 새로운 경험을 받아들여보세요.",
    "KNIGHT OF WANDS" => "충동적이고 열정적인 에너지가 강합니다. 모험을 추구하되 신중함도 잊지 마세요.",
    "QUEEN OF WANDS" => "자신감 넘치는 리더십을 발휘할 때입니다. 창조적 재능과 따뜻한 마음으로 사람들을 이끌어보세요.",
    "KING OF WANDS" => "비전을 현실로 만드는 강력한 의지력을 가지고 있습니다. 카리스마 있는 리더로서 큰 성과를 이룰 것입니다.",

    # 컵(물) 수트 - 감정, 사랑, 직감
    "ACE OF CUPS" => "새로운 사랑이나 깊은 감정적 연결이 시작됩니다. 마음을 열고 진정한 행복을 받아들여보세요.",
    "TWO OF CUPS" => "서로에 대한 깊은 이해와 조화로운 관계를 경험할 것입니다. 파트너십이나 우정이 더욱 돈독해집니다.",
    "THREE OF CUPS" => "친구들과의 즐거운 시간을 보낼 것입니다. 축하와 기쁨을 함께 나누며 인간관계의 소중함을 느끼세요.",
    "FOUR OF CUPS" => "현재 상황에 만족하지 못하고 있습니다. 새로운 기회를 놓치고 있는 것은 아닌지 돌아보세요.",
    "FIVE OF CUPS" => "실망과 상실감을 경험하고 있습니다. 하지만 아직 남아있는 소중한 것들에 주목해보세요.",
    "SIX OF CUPS" => "과거의 추억이나 어린 시절의 순수함을 그리워하고 있습니다. 향수와 그리움이 마음을 채웁니다.",
    "SEVEN OF CUPS" => "너무 많은 선택지 앞에서 혼란스러워하고 있습니다. 환상에 빠지지 말고 현실적인 판단을 하세요.",
    "EIGHT OF CUPS" => "현재의 상황을 떠나 새로운 길을 찾아야 할 때입니다. 용기를 내어 변화를 추구해보세요.",
    "NINE OF CUPS" => "소망이 이루어지는 행복한 시기입니다. 만족감과 성취감을 느끼며 감사한 마음을 가져보세요.",
    "TEN OF CUPS" => "가족이나 사랑하는 사람들과의 완벽한 행복을 경험할 것입니다. 사랑과 조화가 가득한 시간입니다.",
    "PAGE OF CUPS" => "직관적인 메시지나 창조적 영감이 찾아올 것입니다. 감성적이고 예술적인 활동에 도전해보세요.",
    "KNIGHT OF CUPS" => "로맨틱하고 이상주의적인 에너지가 강합니다. 감정에 따라 행동하되 현실감각도 유지하세요.",
    "QUEEN OF CUPS" => "깊은 공감능력과 직감으로 다른 사람들을 도울 수 있습니다. 자비롭고 이해심 많은 마음을 발휘하세요.",
    "KING OF CUPS" => "감정을 잘 다스리며 지혜로운 조언을 할 수 있습니다. 균형 잡힌 마음으로 주변을 이끌어보세요.",

    # 소드(바람) 수트 - 지성, 갈등, 소통
    "ACE OF SWORDS" => "새로운 아이디어나 통찰력이 번개처럼 떠오를 것입니다. 명확한 사고로 문제를 해결할 수 있습니다.",
    "TWO OF SWORDS" => "어려운 결정을 내려야 하는 상황입니다. 감정을 배제하고 이성적으로 판단해보세요.",
    "THREE OF SWORDS" => "상처받은 마음을 치유해야 할 때입니다. 슬픔을 받아들이고 시간을 두고 회복하세요.",
    "FOUR OF SWORDS" => "휴식과 명상이 필요합니다. 바쁜 일상에서 잠시 벗어나 마음의 평화를 찾아보세요.",
    "FIVE OF SWORDS" => "갈등과 대립 상황에서 승부를 가렸지만 상처도 남았습니다. 화해와 용서를 고려해보세요.",
    "SIX OF SWORDS" => "어려운 시기를 벗어나 평온한 곳으로 이동하고 있습니다. 과거를 뒤로하고 새로운 희망을 품으세요.",
    "SEVEN OF SWORDS" => "기만이나 속임수를 조심해야 합니다. 또는 창의적인 방법으로 문제를 해결해야 할 수도 있습니다.",
    "EIGHT OF SWORDS" => "스스로 만든 제약에 갇혀있다고 느낍니다. 해결책은 생각보다 가까이에 있을 수 있습니다.",
    "NINE OF SWORDS" => "걱정과 불안이 마음을 괴롭히고 있습니다. 대부분의 두려움은 실제보다 크게 느껴지는 것임을 기억하세요.",
    "TEN OF SWORDS" => "완전한 끝과 절망의 상황이지만, 이는 새로운 시작의 전조이기도 합니다.",
    "PAGE OF SWORDS" => "날카로운 지성과 호기심이 강합니다. 새로운 정보를 수집하고 소통의 기회를 활용하세요.",
    "KNIGHT OF SWORDS" => "빠르고 직접적인 행동을 취할 때입니다. 하지만 성급함으로 인한 실수는 조심하세요.",
    "QUEEN OF SWORDS" => "명확하고 객관적인 판단력을 발휘할 수 있습니다. 진실을 꿰뚫어보는 통찰력이 있습니다.",
    "KING OF SWORDS" => "논리적이고 공정한 리더십을 보여줄 때입니다. 지혜로운 결정으로 모든 이를 납득시킬 수 있습니다.",

    # 펜타클(흙) 수트 - 물질, 실용, 안정
    "ACE OF PENTACLES" => "새로운 물질적 기회나 안정적인 기반이 마련될 것입니다. 실용적인 계획을 세워보세요.",
    "TWO OF PENTACLES" => "여러 일을 동시에 처리하며 균형을 맞춰야 합니다. 우선순위를 정하고 유연하게 대처하세요.",
    "THREE OF PENTACLES" => "팀워크와 협력을 통해 훌륭한 결과를 만들어낼 수 있습니다. 전문성을 인정받을 기회입니다.",
    "FOUR OF PENTACLES" => "안정과 보안을 추구하지만 지나치게 움켜쥐지는 마세요. 적절한 투자와 나눔이 필요합니다.",
    "FIVE OF PENTACLES" => "물질적 어려움이나 소외감을 경험할 수 있습니다. 하지만 도움의 손길은 가까이에 있습니다.",
    "SIX OF PENTACLES" => "주고받는 관계에서 균형을 이루고 있습니다. 관대함과 감사의 마음을 나누어보세요.",
    "SEVEN OF PENTACLES" => "지금까지의 노력을 점검하고 평가할 시간입니다. 인내심을 가지고 결실을 기다려보세요.",
    "EIGHT OF PENTACLES" => "기술과 전문성을 기르기 위한 노력이 필요합니다. 꾸준한 연습과 학습을 통해 완벽을 추구하세요.",
    "NINE OF PENTACLES" => "자립과 성취를 통해 여유로운 삶을 누릴 수 있습니다. 그동안의 노력이 풍요로운 결실을 맺고 있습니다.",
    "TEN OF PENTACLES" => "가족과 함께 물질적 풍요와 전통을 누릴 수 있습니다. 세대를 이어가는 유산과 안정성이 있습니다.",
    "PAGE OF PENTACLES" => "새로운 학습 기회나 실용적인 계획이 시작됩니다. 성실하고 실용적인 접근이 성공의 열쇠입니다.",
    "KNIGHT OF PENTACLES" => "천천히 하지만 확실하게 목표를 향해 나아가고 있습니다. 성실함과 책임감이 인정받을 것입니다.",
    "QUEEN OF PENTACLES" => "실용적이면서도 너그러운 마음으로 주변을 돌볼 수 있습니다. 물질과 정신의 균형을 잘 맞추고 있습니다.",
    "KING OF PENTACLES" => "물질적 성공과 안정을 이룬 상태입니다. 풍부한 경험과 지혜로 다른 이들을 도울 수 있습니다."
  }

  def self.parse(mastodon_client, sheet_manager, mention)
    begin
      content = mention.status.content.gsub(/<[^>]*>/, '').strip
      sender_full = mention.account.acct
      
      # sender ID 정규화 - 다른 서버 호환성을 위해 도메인 부분 제거
      sender = sender_full.split('@').first
      
      puts "[상점봇] 처리 중: #{content} (from @#{sender_full} -> #{sender})"
      
      user = sheet_manager.get_player(sender)
      unless user
        puts "[무시] 학적부에 없는 사용자: #{sender}"
        return
      end

      case content
      when /\[구매\/(.+?)\]/
        item_name = $1.strip
        message = BuyCommand.new(sender, item_name, sheet_manager).execute
        mastodon_client.reply(mention, message) if message

      when /\[양도\/(.+?)\/@(.+?)\]/
        item_name = $1.strip
        receiver_full = $2.strip
        receiver = receiver_full.split('@').first
        message = TransferItemCommand.new(sender, receiver, item_name, sheet_manager).execute
        mastodon_client.reply(mention, message) if message

      when /\[양도\/갈레온\/(\d+)\/@(.+?)\]/
        amount = $1.to_i
        receiver_full = $2.strip
        receiver = receiver_full.split('@').first
        message = TransferGalleonsCommand.new(sender, receiver, amount, sheet_manager).execute
        mastodon_client.reply(mention, message) if message

      when /\[사용\/(.+?)\]/
        item_name = $1.strip
        message = UseItemCommand.new(sender, item_name, sheet_manager).execute
        mastodon_client.reply(mention, message) if message

      when /\[주머니\]/
        message = PouchCommand.new(sender, sheet_manager).execute
        mastodon_client.reply(mention, message) if message

      when /\[타로\]/
        message = TarotCommand.new(sender, TAROT_DATA, sheet_manager).execute
        mastodon_client.reply(mention, message) if message

      when /\[베팅\/(\d+)\]/
        amount = $1.to_i
        message = BetCommand.new(sender, amount, sheet_manager).execute
        mastodon_client.reply(mention, message) if message

      when /\[(\d+)D\]/
        sides = $1.to_i
        message = DiceCommand.new(sender, sides).execute
        mastodon_client.reply(mention, message) if message

      when /\[동전\]/
        message = CoinCommand.new(sender).execute
        mastodon_client.reply(mention, message) if message

      when /\[YN\]/i
        message = YnCommand.new(sender).execute
        mastodon_client.reply(mention, message) if message

      else
        puts "[무시] 인식되지 않은 명령어: #{content}"
      end

    rescue => e
      puts "[에러] 명령어 처리 실패: #{e.message}"
      puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
    end
  end
end
