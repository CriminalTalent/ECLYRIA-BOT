# command_parser.rb
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
    # (이하 생략 — 동일 TAROT_DATA 유지)
  }

  def self.parse(mastodon_client, sheet_manager, mention)
    begin
      content = mention.status.content.gsub(/<[^>]*>/, '').strip
      content = content.force_encoding("UTF-8") # ★ 인코딩 강제 변환 추가
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
      puts "[에러] 명령어 처리 실패: #{e.message.force_encoding('UTF-8')}"
      puts "  ↳ #{e.backtrace.first(3).map { |l| l.force_encoding('UTF-8') }.join("\n  ↳ ")}"
    end
  end
end
