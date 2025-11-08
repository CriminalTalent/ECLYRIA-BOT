# ============================================
# command_parser.rb
# 상점봇 명령어 파서 및 분기 처리
# ============================================

require_relative 'commands/coin_command'
require_relative 'commands/dice_command'
require_relative 'commands/yn_command'

class CommandParser
  # -----------------------------------------
  # Mentions 감지 및 명령어 처리
  # -----------------------------------------
  def self.parse(mastodon_client, sheet_manager, notification)
    content = clean_html(notification.status.content)
    sender  = notification.account.acct
    display = notification.account.display_name.strip.empty? ? sender : notification.account.display_name.strip

    case content
    # -------------------------------------
    # 주사위 / YES-NO / 동전 명령어
    # -------------------------------------
    when /\[(주사위|d\d+)\]/i
      DiceCommand.run(mastodon_client, notification)

    when /\[(yes|no|yesno|ㅇㅇ|ㄴㄴ)\]/i
      YnCommand.run(mastodon_client, notification)

    when /\[(동전|coin)\]/i
      CoinCommand.run(mastodon_client, notification)

    # -------------------------------------
    # 갈레온 양도 명령어
    # -------------------------------------
    when /\[양도\/갈레온\/(\d+)\/@([\w\.\-\_]+)\]/i
      amount = Regexp.last_match(1).to_i
      target = Regexp.last_match(2)

      player_rows = sheet_manager.read_range('player!A2:D')
      sender_row  = player_rows.find { |r| r[1]&.include?(sender) }
      target_row  = player_rows.find { |r| r[1]&.include?(target) }

      if sender_row.nil?
        mastodon_client.reply(notification, "당신은 등록되지 않은 사용자입니다.")
        return
      elsif target_row.nil?
        mastodon_client.reply(notification, "수신자가 존재하지 않습니다.")
        return
      end

      sender_balance = sender_row[2].to_i
      if sender_balance < amount
        mastodon_client.reply(notification, "보유 금액이 부족합니다.")
        return
      end

      # 금액 이동
      sender_row[2] = (sender_balance - amount).to_s
      target_row[2] = (target_row[2].to_i + amount).to_s

      # 시트 반영
      sender_index = player_rows.index(sender_row) + 2
      target_index = player_rows.index(target_row) + 2

      sheet_manager.update_cell("player!C#{sender_index}", sender_row[2])
      sheet_manager.update_cell("player!C#{target_index}", target_row[2])

      # 로그 기록
      sheet_manager.append_row("log!A:G", [
        Time.now.strftime('%Y-%m-%d %H:%M:%S'),
        "양도",
        sender,
        target,
        "#{amount}G",
        "갈레온 양도 완료"
      ])

      # 출력 메시지
      mastodon_client.reply(
        notification,
        "#{display}(@#{sender}) 머리띠 잘 전달했어요! #{target}(@#{target})님한테 줬어요~"
      )

    # -------------------------------------
    # 기타 명령어 또는 비해당 메시지
    # -------------------------------------
    else
      return
    end
  end

  # -----------------------------------------
  # HTML 제거용 헬퍼
  # -----------------------------------------
  def self.clean_html(html)
    html.gsub(/<[^>]*>/, '').gsub('&nbsp;', ' ').strip
  end
end
