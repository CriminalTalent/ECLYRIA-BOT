# commands/special_doll_command.rb
# 특별한 인형 뽑기 - 이미지 첨부

class SpecialDollCommand
  def self.run(mastodon_client, sheet_manager, notification)
    begin
      account_info = notification["account"] || {}
      sender = account_info["acct"] || ""
      status_id = notification.dig("status", "id")

      unless status_id
        puts "[DOLL] ERROR: status_id를 찾을 수 없음"
        return
      end

      puts "[DOLL] 명령 실행: @#{sender}"

      # 1. 시트에서 랜덤 인형 가져오기
      doll = sheet_manager.get_random_doll

      unless doll
        puts "[DOLL] ERROR: 인형 데이터를 가져올 수 없음"
        error_message = "인형 상자가 비어있거나 오류가 발생했습니다."
        mastodon_client.post_status(
          error_message,
          reply_to_id: status_id,
          visibility: "unlisted"
        )
        return
      end

      doll_name = doll[:name]
      image_url = doll[:image_url]

      puts "[DOLL] 선택된 인형: #{doll_name}"
      puts "[DOLL] 이미지 URL: #{image_url}"

      # 2. 이미지 업로드
      media_id = mastodon_client.upload_media_from_url(
        image_url,
        description: doll_name
      )

      unless media_id
        puts "[DOLL] ERROR: 이미지 업로드 실패"
        error_message = "인형을 꺼내는 중 문제가 발생했습니다. 이미지를 확인해주세요."
        mastodon_client.post_status(
          error_message,
          reply_to_id: status_id,
          visibility: "unlisted"
        )
        return
      end

      puts "[DOLL] 이미지 업로드 성공: #{media_id}"

      # 3. 답글 작성 (이미지 첨부)
      message = "@#{sender} #{doll_name} 이 나왔다!"
      
      mastodon_client.post_status(
        message,
        reply_to_id: status_id,
        visibility: "unlisted",
        media_ids: [media_id]
      )

      puts "[DOLL] 답글 전송 완료: #{doll_name}"

    rescue => e
      puts "[DOLL 오류] #{e.class}: #{e.message}"
      puts e.backtrace.first(5).join("\n  ↳ ")
      
      # 최종 안전장치 - 오류 발생 시 사용자에게 알림
      begin
        if status_id
          mastodon_client.post_status(
            "인형을 꺼내는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
            reply_to_id: status_id,
            visibility: "unlisted"
          )
        end
      rescue
        puts "[DOLL] 오류 메시지 전송도 실패"
      end
    end
  end
end
```

**주요 기능:**

1. ✅ **시트에서 랜덤 인형 선택**
   - `sheet_manager.get_random_doll()` 호출
   - 인형 이름과 이미지 URL 추출

2. ✅ **이미지 업로드**
   - `mastodon_client.upload_media_from_url()` 사용
   - 구글 드라이브 URL 자동 변환
   - 업로드 실패 시 에러 메시지

3. ✅ **이미지 첨부 답글**
   - `@사용자 {인형이름} 이 나왔다!` 형식
   - `media_ids` 파라미터로 이미지 첨부
   - `unlisted` visibility

4. ✅ **에러 처리**
   - 시트 비어있음
   - 이미지 업로드 실패
   - 최종 안전장치로 사용자에게 오류 알림

**사용 방법:**
```
@Store [특별한 인형]
@Store [특별한인형]
```

**응답 예시:**
```
@사용자 테디베어 이 나왔다!
[이미지 첨부]
