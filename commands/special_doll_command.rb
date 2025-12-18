# commands/special_doll_command.rb
# 특별한 인형 뽑기 - 이미지 첨부 + 사용자 지급

class SpecialDollCommand
  def self.run(mastodon_client, sheet_manager, notification)
    begin
      account_info = notification["account"] || {}
      raw_sender   = account_info["acct"].to_s
      sender       = raw_sender.split('@').first # 서버 붙은 acct 정리
      status_id    = notification.dig("status", "id")

      unless status_id
        puts "[DOLL] ERROR: status_id를 찾을 수 없음"
        return
      end

      puts "[DOLL] 명령 실행: @#{sender}"

      # 1. 사용자 확인
      player = sheet_manager.find_user(sender)
      unless player
        mastodon_client.post_status(
          "@#{sender} 먼저 입학해주세요.",
          reply_to_id: status_id,
          visibility: "unlisted"
        )
        return
      end

      # 2. 랜덤 인형 가져오기
      doll = sheet_manager.get_random_doll
      unless doll
        mastodon_client.post_status(
          "인형 상자가 비어있거나 오류가 발생했습니다.",
          reply_to_id: status_id,
          visibility: "unlisted"
        )
        return
      end

      doll_name = doll[:name].to_s
      image_url = doll[:image_url].to_s

      puts "[DOLL] 선택된 인형: #{doll_name}"
      puts "[DOLL] 이미지 URL: #{image_url}"

      # 3. 이미지 업로드
      media_id = mastodon_client.upload_media_from_url(
        image_url,
        description: doll_name
      )

      unless media_id
        mastodon_client.post_status(
          "인형을 꺼내는 중 문제가 발생했습니다. 이미지를 확인해주세요.",
          reply_to_id: status_id,
          visibility: "unlisted"
        )
        return
      end

      puts "[DOLL] 이미지 업로드 성공: #{media_id}"

      # 4. 사용자 인벤토리 반영
      current_items = player[:items].to_s
        .split(',')
        .map(&:strip)
        .reject(&:empty?)

      current_items << doll_name

      sheet_manager.update_user(
        sender,
        items: current_items.join(',')
      )

      # 5. 답글 전송 (이미지 포함)
      message = "@#{sender} #{doll_name} 이 나왔다!"

      mastodon_client.post_status(
        message,
        reply_to_id: status_id,
        visibility: "unlisted",
        media_ids: [media_id]
      )

      puts "[DOLL] 지급 완료: #{doll_name}"

    rescue => e
      puts "[DOLL 오류] #{e.class}: #{e.message}"
      puts e.backtrace.first(5).join("\n  ↳ ")

      begin
        if status_id
          mastodon_client.post_status(
            "인형을 꺼내는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
            reply_to_id: status_id,
            visibility: "unlisted"
          )
        end
      rescue
        puts "[DOLL] 오류 메시지 전송 실패"
      end
    end
  end
end
