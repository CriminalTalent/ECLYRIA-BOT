require 'mastodon'
require 'json'
require 'dotenv'
Dotenv.load('.env')

module MastodonClient
  BASE_URL = ENV['MASTODON_BASE_URL']
  TOKEN = ENV['MASTODON_TOKEN']

  def self.client
    @client ||= Mastodon::REST::Client.new(
      base_url: BASE_URL, 
      bearer_token: TOKEN
    )
  end

  def self.test_connection
    begin
      me = client.verify_credentials
      puts "   마스토돈 계정 확인 완료: @#{me.acct}"
      puts "   서버: #{BASE_URL}"
      true
    rescue => e
      puts "   마스토돈 연결 실패: #{e.message}"
      false
    end
  end

  def self.reply(to_status, message)
    begin
      response = client.create_status(
        "@#{to_status.account.acct} #{message}", 
        {
          in_reply_to_id: to_status.id,
          visibility: 'public'
        }
      )
      puts "[답장] 답장 전송: @#{to_status.account.acct} - #{message[0..50]}..."
      response
    rescue => e
      puts "[오류] 답장 전송 실패: #{e.message}"
      nil
    end
  end

  def self.post_status(message, options = {})
    begin
      response = client.create_status(message, options)
      puts "[게시] 상태 게시: #{message[0..50]}..."
      response
    rescue => e
      puts "[오류] 상태 게시 실패: #{e.message}"
      nil
    end
  end

  def self.get_mentions(since_id = nil, limit = 10)
    begin
      options = { limit: limit }
      options[:since_id] = since_id if since_id
      
      notifications = client.notifications(options)
      mentions = notifications.select { |n| n.type == 'mention' }
      
      puts "[멘션] 멘션 #{mentions.size}개 수신" if mentions.size > 0
      mentions
    rescue => e
      puts "[오류] 멘션 수신 실패: #{e.message}"
      []
    end
  end

  def self.stream_mentions(since_id = nil)
    puts "[스트림] 멘션 스트리밍 시작..."
    current_since_id = since_id
    
    loop do
      begin
        mentions = get_mentions(current_since_id)
        
        mentions.each do |mention|
          yield mention if block_given?
          current_since_id = [current_since_id.to_i, mention.id.to_i].max.to_s
        end
        
        sleep 10
      rescue => e
        puts "[오류] 스트리밍 에러: #{e.message}"
        puts "[대기] 30초 후 재시도..."
        sleep 30
      end
    end
  end

  def self.get_account_info(username)
    begin
      account = client.search(username, resolve: true)[:accounts].first
      return account
    rescue => e
      puts "[오류] 계정 정보 조회 실패: #{e.message}"
      nil
    end
  end

  def self.clean_content(content)
    # HTML 태그 제거
    content.gsub(/<[^>]*>/, '').strip
  end

  def self.validate_environment
    missing_vars = []
    missing_vars << 'MASTODON_BASE_URL' if BASE_URL.nil? || BASE_URL.empty?
    missing_vars << 'MASTODON_TOKEN' if TOKEN.nil? || TOKEN.empty?
    
    if missing_vars.any?
      puts "[오류] 필수 환경변수 누락: #{missing_vars.join(', ')}"
      puts "   .env 파일을 확인해주세요."
      return false
    end
    
    true
  end
end
