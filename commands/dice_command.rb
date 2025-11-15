# commands/dice_command.rb
# encoding: UTF-8

class DiceCommand
  # HTML 태그 제거용 간단 유틸
  def self.clean_html(html)
    html.to_s.gsub(/<[^>]*>/, '').gsub('&nbsp;', ' ').strip
  end

  # 메인 진입점: CommandParser에서 호출
  # DiceCommand.run(mastodon_client, notification)
  def self.run(mastodon_client, notification)
    begin
      content_raw  = notification.dig("status", "content") || ""
      acct_info    = notification["account"] || {}
      sender_acct  = acct_info["acct"] || ""
      content      = clean_html(content_raw)

      # ----- 명령 파싱 -----
      # [주사위]    → 1d6
      # [d6], [d20] → 1d6, 1d20
      # [6d], [6D]  → 1d6 (d 앞/뒤 위치 뒤집힌 버전 허용)
      dice_count = 1
      dice_sides = 6

      case content
      when /\[주사위\]/i
        dice_count = 1
        dice_sides = 6
      when /\[(?:d(\d+)|(\d+)[dD])\]/i
        # d6 / d20 → $1
        # 6d / 6D  → $2
        faces = ($1 || $2).to_i
        dice_count = 1
        dice_sides = faces
      else
        # 여기에 들어오면 잘못된 형식
        text = "@#{sender_acct} 주사위 형식을 이해하지 못했어요. 예: [주사위], [d6], [6D]"
        reply_to_notification(mastodon_client, notification, text)
        return
      end

      # 방어적 제한 (너무 큰 수 방지)
      if dice_sides <= 0 || dice_sides > 100
        text = "@#{sender_acct} 그 정도 면수는 좀 무리인데… 1~100 사이로 굴려줘요."
        reply_to_notification(mastodon_client, notification, text)
        return
      end

      # ----- 주사위 굴리기 -----
      rolls = Array.new(dice_count) { rand(1..dice_sides) }
      total = rolls.sum

      # ----- 결과 문구 구성 (RP 톤 살짝) -----
      if dice_count == 1
        text = "@#{sender_acct} #{dice_sides}면 주사위를 굴려봤어요.\n" \
               "결과는… #{rolls.first}가 나왔네요."
      else
        text = "@#{sender_acct} #{dice_count}D#{dice_sides}를 굴려봤어요.\n" \
               "각각의 눈: #{rolls.join(', ')}\n" \
               "합계는 #{total} 입니다."
      end

      reply_to_notification(mastodon_client, notification, text)

    rescue => e
      puts "[DICE-ERROR] #{e.class} - #{e.message}"
      puts e.backtrace.first(3).join("\n  ↳ ")
    end
  end

  # 실제 답글 전송 헬퍼
  def self.reply_to_notification(mastodon_client, notification, text, visibility: "unlisted")
    return if text.nil? || text.to_s.strip.empty?

    status_id =
      if notification.is_a?(Hash)
        notification.dig("status", "id") || notification["id"]
      elsif notification.respond_to?(:status) && notification.status.respond_to?(:id)
        notification.status.id
      elsif notification.respond_to?(:id)
        notification.id
      else
        notification.to_s
      end

    mastodon_client.post_status(text, reply_to_id: status_id, visibility: visibility)
  end
end
