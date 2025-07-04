# bot/mastodon_client.rb
require 'mastodon'

module MastodonClient
  @last_mention_id = nil

  def self.client
    @client ||= Mastodon::REST::Client.new(
      base_url: ENV['MASTODON_BASE_URL'],
      bearer_token: ENV['MASTODON_TOKEN']
    )
  end

  def self.listen_mentions
    begin
      # 마지막으로 확인한 멘션 이후의 새로운 멘션만 가져오기
      options = {}
      options[:since_id] = @last_mention_id if @last_mention_id

      notifications = client.notifications(options)
      mentions = notifications.select { |n| n.type == 'mention' }
      
      # 새로운 멘션이 있다면 마지막 ID 업데이트
      if mentions.any?
        @last_mention_id = mentions.first.id
        puts "새로운 멘션 #{mentions.size}개 발견!"
        
        mentions.reverse.each do |mention|
          yield mention if block_given?
        end
      else
        puts "새로운 멘션이 없습니다."
      end
      
    rescue => e
      puts "멘션 확인 중 오류 발생: #{e.message}"
      sleep 30 # 오류 발생 시 잠시 대기
    end
  end

  def self.reply(mention, message)
    begin
      acct = mention.account.acct
      status_id = mention.status.id
      
      response = client.create_status(
        "@#{acct} #{message}", 
        in_reply_to_id: status_id,
        visibility: 'public'
      )
      
      puts "#{acct}에게 답글 전송 완료: #{message}"
      response
      
    rescue => e
      puts "답글 전송 중 오류 발생: #{e.message}"
      nil
    end
  end

  def self.test_connection
    begin
      account = client.verify_credentials
      puts "✅ 마스토돈 연결 성공! 계정: @#{account.acct}"
      true
    rescue => e
      puts "❌ 마스토돈 연결 실패: #{e.message}"
      false
    end
  end
end
