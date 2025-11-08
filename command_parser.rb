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

# ============================================
# command_parser.rb
# 상점봇 명령어 파서 및 분기 처리 (TAROT 데이터 포함)
# ============================================

module CommandParser
  TAROT_DATA = {
    "THE FOOL" => "순수한 마음으로 새로운 모험을 시작할 때야. 겁내지 말고 한 발 내딛어봐. 세상이 생각보다 넓고, 재밌는 일이 기다리고 있다네.",
    "THE MAGICIAN" => "손끝이 근질근질하지? 지금이 바로 시작할 때야. 네 안에 있는 재주를 믿어봐. 가진 걸 제대로 써먹으면 뭐든 이룰 수 있다네.",
    "THE HIGH PRIESTESS" => "입 다물고 눈 크게 떠야 할 때지. 눈에 보이지 않는 게 진짜인 법이야. 조용히 들여다보면 답이 보인다네.",
    "THE EMPRESS" => "이야, 풍요가 넘치는구먼. 지금 네가 하는 일이 곧 결실을 맺을 거야. 넉넉한 마음으로 챙기고 나눠보게.",
    "THE EMPEROR" => "기둥처럼 우뚝 설 때야. 네가 중심을 잡아야 세상이 돌아가지. 책임감 있게 밀어붙이게.",
    "THE HIEROPHANT" => "배움은 끝이 없지. 윗사람의 말에 귀 기울이고, 전통 속에서도 지혜를 찾아봐. 괜히 괴짜 흉내내다 후회하지 말고 말이야.",
    "THE LOVERS" => "선택의 길목에 섰구먼. 마음이 끌리는 쪽으로 가되, 나중에 후회 없게 하게. 사랑도 거래처럼, 신중해야 하는 법이야.",
    "THE CHARIOT" => "힘 좀 써야겠구먼. 기세 좋게 밀고 나가게. 다만, 성질만큼은 고삐를 단단히 잡고 말이지.",
    "STRENGTH" => "으르렁거릴 필요 없어. 부드럽게 다스리는 게 진짜 힘이지. 참는 자가 이긴다, 이 말 몰라?",
    "THE HERMIT" => "혼자 있고 싶을 땐 그래야 해. 등불 하나 들고 내면을 살펴보게. 조용한 시간 속에 길이 있다네.",
    "WHEEL OF FORTUNE" => "운명의 수레바퀴가 돌고 있구먼. 이번 판은 바람 잘 타면 대박이야. 망설이면 놓친다네.",
    "JUSTICE" => "냉정해야 할 때야. 감정은 빼고, 딱 맞는 균형을 찾아보게. 공정하게 굴면 손해 볼 일은 없을 거야.",
    "THE HANGED MAN" => "멈추는 것도 용기야. 고개를 거꾸로 들이밀면 보이지 않던 게 보일 거라네.",
    "DEATH" => "끝났다고 슬퍼하긴 이르지. 끝이 있어야 새 시작이 있거든. 손 털고 새로 가보자고.",
    "TEMPERANCE" => "이것도 조금, 저것도 조금. 중간이 제일이지. 급하게 굴면 화만 난다네.",
    "THE DEVIL" => "달콤한 유혹이 근처에 있구먼. 하지만 공짜는 없어. 스스로 꽁꽁 묶이지 말게.",
    "THE TOWER" => "갑자기 쾅 하고 무너질 수도 있어. 놀라지 말게. 다 부숴져야 새로 세울 수 있다네.",
    "THE STAR" => "이야, 별빛이 참 곱구먼. 아직 희망이 남았어. 고개 들고 계속 걸어가게.",
    "THE MOON" => "이상하게 찜찜하지? 착각일 수도 있네. 눈에 보이는 게 다가 아니야. 속단하긴 이르다네.",
    "THE SUN" => "햇살이 쨍하구먼. 잘하고 있어, 지금처럼 하면 된다네. 걱정 붙들어매게.",
    "JUDGEMENT" => "지금이 바로 결판의 순간이야. 과거를 정리하고 새로 태어날 차례라네.",
    "THE WORLD" => "모든 게 제자리에 돌아왔구먼. 고생 끝에 낙이 오는 법이지. 잘했네, 이제 한 숨 돌리게."
  }

  MAX_BETS_PER_DAY = 3

  def self.parse(mastodon_client, sheet_manager, notification)
    begin
      content = clean_html(notification.status.content)
      sender  = notification.account.acct
      display = notification.account.display_name.strip.empty? ? sender : notification.account.display_name.strip

      case content
      when /\[구매\/(.+?)\]/
        message = BuyCommand.new(sender, $1.strip, sheet_manager).execute

      when /\[양도\/(.+?)\/@(.+?)\]/
        message = TransferItemCommand.new(sender, $2.strip.split('@').first, $1.strip, sheet_manager).execute

      when /\[양도\/갈레온\/(\d+)\/@(.+?)\]/i
        amount = Regexp.last_match(1).to_i
        target = Regexp.last_match(2)

        player_rows = sheet_manager.read_range('player!A2:D')
        sender_row  = player_rows.find { |r| r[1]&.include?(sender) }
        target_row  = player_rows.find { |r| r[1]&.include?(target) }

        if sender_row.nil?
          mastodon_client.reply(notification, "이봐, 학생. 아직 가게 장부에 이름이 없네. 먼저 등록부터 해야지?")
          return
        elsif target_row.nil?
          mastodon_client.reply(notification, "그 이름은 내 장부에 없는데? 다시 한번 확인해보게, 학생.")
          return
        end

        sender_balance = sender_row[2].to_i
        if sender_balance < amount
          mastodon_client.reply(notification, "그 돈으론 택도 없어, 학생. 지갑 좀 채우고 오게나.")
          return
        end

        sender_row[2] = (sender_balance - amount).to_s
        target_row[2] = (target_row[2].to_i + amount).to_s

        sender_index = player_rows.index(sender_row) + 2
        target_index = player_rows.index(target_row) + 2

        sheet_manager.update_cell("player!C#{sender_index}", sender_row[2])
        sheet_manager.update_cell("player!C#{target_index}", target_row[2])

        sheet_manager.append_row("log!A:G", [
          Time.now.strftime('%Y-%m-%d %H:%M:%S'),
          "양도",
          sender,
          target,
          "#{amount}G",
          "갈레온 양도 완료"
        ])

        mastodon_client.reply(notification,
          "#{display}(@#{sender}) 학생이 머리띠를 곱게 싸서 보냈다네. #{target}(@#{target}) 그 학생한테 잘 전달해뒀지!"
        )

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
          message = "오늘은 그만해야지, 학생. 하루에 #{MAX_BETS_PER_DAY}번이면 충분하지 않겠나?"
        else
          message = BetCommand.new(sender, $1.to_i, sheet_manager).execute
          sheet_manager.log_command(sender, "BET", $1.to_i)
        end

      when /\[(주사위|d\d+)\]/i
        message = DiceCommand.run(mastodon_client, notification)

      when /\[(yes|no|yesno|ㅇㅇ|ㄴㄴ)\]/i
        message = YnCommand.run(mastodon_client, notification)

      when /\[(동전|coin)\]/i
        message = CoinCommand.run(mastodon_client, notification)

      else
        return
      end

      if message
        mastodon_client.reply(notification, message)
      end

    rescue => e
      puts "[에러] 명령어 처리 실패: #{e.message}"
      puts "  ↳ #{e.backtrace.first(3).join("\n  ↳ ")}"
    end
  end

  def self.clean_html(html)
    html.gsub(/<[^>]*>/, '').gsub('&nbsp;', ' ').strip
  end
end
