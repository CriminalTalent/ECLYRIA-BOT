# encoding: UTF-8
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
  # ==========================================================
  # TAROT 카드 전체 데이터 (완전 보존)
  # ==========================================================
  TAROT_DATA = {
    # 메이저 아르카나 (22장)
    "THE FOOL" => "순수한 마음으로 새로운 모험을 시작할 때입니다. 두려움 없이 미지의 세계로 발걸음을 내딛어보세요. 때로는 계획보다 직감을 따르는 것이 더 큰 기회를 가져다줄 수 있습니다.",
    "THE MAGICIAN" => "당신 안에 잠든 무한한 가능성이 깨어나고 있습니다. 의지력과 집중력으로 원하는 것을 현실로 만들어낼 수 있는 시기입니다. 자신감을 가지고 목표를 향해 나아가세요.",
    "THE HIGH PRIESTESS" => "논리보다는 직감을 믿어야 할 시간입니다. 내면의 목소리에 귀 기울이고, 숨겨진 진실을 발견할 수 있을 것입니다. 침묵 속에서 지혜를 찾아보세요.",
    "THE EMPRESS" => "창조와 풍요의 에너지가 당신을 둘러싸고 있습니다. 새로운 것을 만들어내거나 기존의 것을 키워나가는 데 최적의 시기입니다. 사랑과 보살핌의 마음을 나누어보세요.",
    "THE EMPEROR" => "안정된 기반 위에서 체계적으로 일을 진행할 때입니다. 리더십을 발휘하고 명확한 규칙과 질서를 만들어 나가세요. 책임감 있는 결정이 성공을 이끌 것입니다.",
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
    "THE DEVIL" => "물질적 욕망이나 중독적인 패턴에서 벗어날 때입니다. 스스로를 옭아매는 사슬을 끊고 진정한 자유를 찾아보세요. 유혹에 현명하게 대처하세요.",
    "THE TOWER" => "급격한 변화가 다가오고 있습니다. 허울뿐인 것들이 무너지며 진실이 드러날 것입니다. 위기를 기회로 바꾸어 더 단단한 기반을 만들어가세요.",
    "THE STAR" => "희망의 빛이 어둠을 밝히고 있습니다. 긍정적인 에너지로 가득 찬 시기이며, 꿈을 향해 나아갈 수 있습니다. 믿음을 잃지 말고 계속 전진하세요.",
    "THE MOON" => "불확실함과 착각이 당신을 혼란스럽게 할 수 있습니다. 겉으로 보이는 것보다 더 깊은 진실이 숨어 있을 수 있습니다. 직관을 믿되 조심스럽게 나아가세요.",
    "THE SUN" => "성공과 기쁨이 가득한 시기입니다. 모든 것이 밝게 빛나며 긍정적인 에너지가 넘칩니다. 자신감을 가지고 당당하게 세상에 자신을 드러내보세요.",
    "JUDGEMENT" => "과거를 정리하고 새로운 시작을 준비할 때입니다. 자신을 객관적으로 평가하고 필요한 변화를 받아들이세요. 부활과 재탄생의 기회가 왔습니다.",
    "THE WORLD" => "한 사이클이 완성되며 성취감을 느낄 수 있습니다. 목표를 달성하고 새로운 여정을 시작할 준비가 되어 있습니다. 완성과 통합의 순간을 즐기세요.",

    # 완드 (14장)
    "ACE OF WANDS" => "새로운 열정과 창의적 에너지가 폭발하는 시기입니다. 용기를 내어 새로운 프로젝트를 시작해보세요.",
    "TWO OF WANDS" => "미래를 계획하고 큰 그림을 그릴 때입니다. 가능성을 탐색하며 다음 단계를 준비하세요.",
    "THREE OF WANDS" => "노력의 결실이 보이기 시작합니다. 멀리 내다보며 확장과 성장을 준비하세요.",
    "FOUR OF WANDS" => "축하와 기쁨의 시간입니다. 성취를 축하하고 안정감을 느끼세요.",
    "FIVE OF WANDS" => "경쟁과 갈등이 있을 수 있지만, 이를 통해 성장할 기회를 얻게 됩니다.",
    "SIX OF WANDS" => "승리와 인정을 받는 순간입니다. 자신감을 가지고 성과를 자랑스럽게 여기세요.",
    "SEVEN OF WANDS" => "도전과 방어가 필요한 시기입니다. 자신의 입장을 굳건히 지키세요.",
    "EIGHT OF WANDS" => "빠른 진전과 변화가 일어납니다. 속도감 있게 움직이며 기회를 잡으세요.",
    "NINE OF WANDS" => "거의 다 왔지만 마지막 힘을 내야 합니다. 포기하지 말고 끝까지 버티세요.",
    "TEN OF WANDS" => "과중한 책임감을 느낄 수 있습니다. 부담을 나누고 도움을 요청하세요.",
    "PAGE OF WANDS" => "새로운 소식이나 기회가 찾아옵니다. 호기심을 가지고 탐험해보세요.",
    "KNIGHT OF WANDS" => "열정적이고 모험적인 에너지가 넘칩니다. 대담하게 행동하되 무모하지 않게 주의하세요.",
    "QUEEN OF WANDS" => "자신감과 카리스마가 빛을 발하는 시기입니다. 리더십을 발휘하세요.",
    "KING OF WANDS" => "비전과 영감으로 주변을 이끕니다. 강력한 리더십으로 목표를 달성하세요.",

    # 컵 (14장)
    "ACE OF CUPS" => "새로운 사랑과 감정적 충만함이 찾아옵니다. 마음을 열고 받아들이세요.",
    "TWO OF CUPS" => "조화로운 관계와 파트너십이 형성됩니다. 상호 이해와 존중이 깊어집니다.",
    "THREE OF CUPS" => "기쁨과 축하의 순간입니다. 친구들과 함께 행복을 나누세요.",
    "FOUR OF CUPS" => "무관심이나 불만족을 느낄 수 있습니다. 새로운 관점으로 주변을 다시 살펴보세요.",
    "FIVE OF CUPS" => "상실과 실망을 경험할 수 있지만, 여전히 남아 있는 것에 집중하세요.",
    "SIX OF CUPS" => "과거의 추억과 향수가 떠오릅니다. 순수함과 행복했던 시절을 회상하세요.",
    "SEVEN OF CUPS" => "많은 선택지 앞에서 혼란스러울 수 있습니다. 현실적으로 생각하며 신중히 결정하세요.",
    "EIGHT OF CUPS" => "더 나은 것을 찾아 떠날 때입니다. 과거를 뒤로하고 새로운 여정을 시작하세요.",
    "NINE OF CUPS" => "소원이 이루어지는 행복한 순간입니다. 만족과 기쁨을 누리세요.",
    "TEN OF CUPS" => "가족과 사랑하는 이들과의 완벽한 조화를 이룹니다. 행복이 가득한 시기입니다.",
    "PAGE OF CUPS" => "감정적인 메시지나 새로운 감정이 싹트는 시기입니다. 직관을 따르세요.",
    "KNIGHT OF CUPS" => "낭만적이고 이상주의적인 에너지가 넘칩니다. 감정을 표현하고 꿈을 추구하세요.",
    "QUEEN OF CUPS" => "공감과 직관이 강한 시기입니다. 감정을 이해하고 돌보는 역할을 하세요.",
    "KING OF CUPS" => "감정적 성숙함과 균형을 이룹니다. 지혜롭고 차분하게 감정을 다스리세요.",

    # 검 (14장)
    "ACE OF SWORDS" => "명확한 사고와 새로운 아이디어가 떠오릅니다. 진실을 추구하고 결단을 내리세요.",
    "TWO OF SWORDS" => "어려운 결정을 내려야 합니다. 균형을 유지하며 신중히 선택하세요.",
    "THREE OF SWORDS" => "마음의 상처와 슬픔을 경험할 수 있습니다. 치유의 시간이 필요합니다.",
    "FOUR OF SWORDS" => "휴식과 회복이 필요합니다. 잠시 멈추고 에너지를 재충전하세요.",
    "FIVE OF SWORDS" => "갈등과 패배를 경험할 수 있습니다. 승리보다 중요한 것이 무엇인지 생각해보세요.",
    "SIX OF SWORDS" => "어려움을 뒤로하고 더 나은 곳으로 이동합니다. 변화를 받아들이고 앞으로 나아가세요.",
    "SEVEN OF SWORDS" => "전략과 계획이 필요합니다. 조심스럽게 행동하되 정직함을 잊지 마세요.",
    "EIGHT OF SWORDS" => "제한과 두려움에 갇혀 있다고 느낄 수 있습니다. 스스로를 해방시키세요.",
    "NINE OF SWORDS" => "걱정과 불안이 마음을 무겁게 합니다. 도움을 요청하고 긍정적으로 생각하세요.",
    "TEN OF SWORDS" => "끝과 종결의 순간입니다. 고통스럽지만 새로운 시작을 준비하세요.",
    "PAGE OF SWORDS" => "호기심과 경계심이 필요한 시기입니다. 정보를 수집하고 조심스럽게 행동하세요.",
    "KNIGHT OF SWORDS" => "빠르고 결단력 있는 행동이 필요합니다. 목표를 향해 직진하되 충동적이지 않게 주의하세요.",
    "QUEEN OF SWORDS" => "명확한 사고와 독립성이 빛을 발합니다. 객관적이고 공정하게 판단하세요.",
    "KING OF SWORDS" => "지적이고 논리적인 접근이 필요합니다. 진실과 정의를 추구하며 리드하세요.",

    # 펜타클 (14장)
    "ACE OF PENTACLES" => "새로운 재정적 기회나 물질적 시작이 찾아옵니다. 현실적 목표를 세우세요.",
    "TWO OF PENTACLES" => "균형과 유연성이 필요합니다. 여러 일을 조화롭게 관리하세요.",
    "THREE OF PENTACLES" => "협력과 팀워크로 성과를 이룹니다. 전문성을 인정받는 시기입니다.",
    "FOUR OF PENTACLES" => "안정과 보안을 추구하지만 지나치게 집착하지 않도록 주의하세요.",
    "FIVE OF PENTACLES" => "어려움과 결핍을 느낄 수 있습니다. 도움을 요청하고 희망을 잃지 마세요.",
    "SIX OF PENTACLES" => "베풂과 나눔의 시기입니다. 관대함과 공정함으로 균형을 이루세요.",
    "SEVEN OF PENTACLES" => "인내심을 가지고 결실을 기다리세요. 지금까지의 노력을 평가하고 다음 단계를 계획하세요.",
    "EIGHT OF PENTACLES" => "성실하게 일하고 기술을 연마하세요. 노력이 곧 성과로 이어질 것입니다.",
    "NINE OF PENTACLES" => "독립과 풍요를 누립니다. 자신의 성취를 즐기고 감사하세요.",
    "TEN OF PENTACLES" => "장기적인 안정과 물질적 풍요를 이룹니다. 가족과 전통의 가치를 소중히 여기세요.",
    "PAGE OF PENTACLES" => "새로운 학습과 실용적인 기회가 찾아옵니다. 성실하게 시작하세요.",
    "KNIGHT OF PENTACLES" => "꾸준함과 책임감으로 목표를 향해 나아갑니다. 인내심을 가지고 계속하세요.",
    "QUEEN OF PENTACLES" => "실용적이고 양육적인 에너지가 넘칩니다. 풍요와 안정을 창조하세요.",
    "KING OF PENTACLES" => "재정적 성공과 안정을 이룹니다. 현명한 관리와 리더십을 발휘하세요."
  }

  MAX_BETS_PER_DAY = 3

  def self.parse(mastodon_client, sheet_manager, mention)
    begin
      content = mention.status.content.force_encoding('UTF-8').gsub(/<[^>]*>/, '').strip
      sender_full = mention.account.acct.force_encoding('UTF-8')
      sender = sender_full.split('@').first

      puts "[상점봇] 처리 중: #{content} (from @#{sender_full} -> #{sender})"

      user = sheet_manager.get_player(sender)
      unless user
        puts "[무시] 학적부에 없는 사용자: #{sender}"
        return
      end

      message = nil

      case content
      when /\[구매\/(.+?)\]/
        message = BuyCommand.new(sender, $1.strip, sheet_manager).execute
      when /\[양도\/(.+?)\/@(.+?)\]/
        message = TransferItemCommand.new(sender, $2.strip.split('@').first, $1.strip, sheet_manager).execute
      when /\[양도\/갈레온\/(\d+)\/@(.+?)\]/
        message = TransferGalleonsCommand.new(sender, $2.strip.split('@').first, $1.to_i, sheet_manager).execute
      when /\[사용\/(.+?)\]/
        message = UseItemCommand.new(sender, $1.strip, sheet_manager).execute
      when /\[주머니\]/
        message = PouchCommand.new(sender, sheet_manager).execute
      when /\[타로\]/
        message = TarotCommand.new(sender, TAROT_DATA, sheet_manager).execute
      when /\[베팅\/(\d+)\]/
        today = Time.now.strftime('%Y-%m-%d')
        bet_count = sheet_manager.get_daily_count(sender, today, "BET")
        if bet_count >= MAX_BETS_PER_DAY
          message = "오늘은 더 이상 베팅할 수 없습니다. (최대 #{MAX_BETS_PER_DAY}회)"
        else
          message = BetCommand.new(sender, $1.to_i, sheet_manager).execute
          sheet_manager.log_command(sender, "BET", $1.to_i)
        end
      when /\[(\d+)D\]/
        message = DiceCommand.new(sender, $1.to_i).execute
        sheet_manager.log_command(sender, "DICE", $1.to_i)
      when /\[동전\]/
        message = CoinCommand.new(sender).execute
        sheet_manager.log_command(sender, "COIN", nil)
      when /\[YN\]/i
        message = YnCommand.new(sender).execute
        sheet_manager.log_command(sender, "YN", nil)
      else
        puts "[무시] 인식되지 않은 명령어: #{content}"
        return
      end

      if message
        result = mastodon_client.reply(mention.status, message)
        if result
          puts "[DEBUG] 답글 전송 완료"
          sheet_manager.log_command(sender, "REPLY", content)
        else
          puts "[경고] 답글 전송 실패 (HTTP 오류)"
        end
      end

    rescue => e
      puts "[에러] 명령어 처리 실패: #{e.message}"
      puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
    end
  end
end
