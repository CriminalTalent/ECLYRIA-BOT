require 'http'
require 'json'

module MastodonClient
  @last_mention_id = nil

  def self.headers
    {
      'Authorization' => "Bearer #{ENV['MASTODON_TOKEN']}",
      'Content-Type' => 'application/json'
    }
  end

  def self.base_url
    ENV['MASTODON_BASE_URL']
  end

  def self.listen_mentions
    begin
      url = "#{base_url}/api/v1/notifications"
      params = { types: ['mention'] }
      params[:since_id] = @last_mention_id if @last_mention_id
      
      response = HTTP.headers(headers).get(url, params: params)
      
      if response.status == 200
        notifications = JSON.parse(response.body)
        mentions = notifications.select { |n| n['type'] == 'mention' }
        
        if mentions.any?
          @last_mention_id = mentions.first['id']
          puts "새로운 주문 #{mentions.size}개 도착!"
          
          mentions.reverse.each do |mention_data|
            mention = OpenStruct.new(
              id: mention_data['id'],
              account: OpenStruct.new(
                acct: mention_data['account']['acct']
              ),
              status: OpenStruct.new(
                id: mention_data['status']['id'],
                content: mention_data['status']['content']
              )
            )
            
            acct = mention.account.acct
            content = mention.status.content.gsub(/<[^>]*>/, '').strip
            puts "   @#{acct}: #{content}"
            
            yield mention if block_given?
          end
        else
          print "."
        end
      else
        puts "API 오류: #{response.status}"
      end
      
    rescue => e
      puts "주문 확인 중 오류: #{e.message}"
      puts "   #{e.class}: #{e.backtrace.first}"
      sleep 30
    end
  end

  def self.reply(mention, message)
    begin
      acct = mention.account.acct
      status_id = mention.status.id
      
      url = "#{base_url}/api/v1/statuses"
      data = {
        status: "@#{acct} #{message}",
        in_reply_to_id: status_id,
        visibility: 'public'
      }
      
      response = HTTP.headers(headers).post(url, json: data)
      
      if response.status == 200
        puts "@#{acct}에게 상품 정보 전달 완료"
        JSON.parse(response.body)
      else
        puts "답글 전송 실패: #{response.status} - #{response.body}"
        nil
      end
      
    rescue => e
      puts "답글 전송 중 오류: #{e.message}"
      puts "   대상: @#{acct rescue 'unknown'}"
      puts "   메시지 길이: #{message.length rescue 0}자"
      nil
    end
  end

  def self.test_connection
    begin
      url = "#{base_url}/api/v1/accounts/verify_credentials"
      response = HTTP.headers(headers).get(url)
      
      if response.status == 200
        account = JSON.parse(response.body)
        puts "마스토돈 서버 연결 성공!"
        puts "   상점 계정: @#{account['acct']}"
        puts "   상점명: #{account['display_name']}"
        puts "   고객 수: #{account['followers_count']}명"
        true
      else
        puts "서버 연결 실패: HTTP #{response.status}"
        puts "   응답: #{response.body}"
        false
      end
    rescue => e
      puts "서버 연결 실패: #{e.message}"
      puts "   #{e.class}"
      false
    end
  end

  def self.post_status(message, visibility: 'public')
    begin
      url = "#{base_url}/api/v1/statuses"
      data = {
        status: message,
        visibility: visibility
      }
      
      response = HTTP.headers(headers).post(url, json: data)
      
      if response.status == 200
        puts "상점 공지사항 게시 완료"
        JSON.parse(response.body)
      else
        puts "상점 공지사항 게시 실패: #{response.status}"
        nil
      end
    rescue => e
      puts "상점 공지사항 게시 실패: #{e.message}"
      nil
    end
  end

  def self.get_recent_mentions(limit: 10)
    begin
      url = "#{base_url}/api/v1/notifications"
      params = { types: ['mention'], limit: limit }
      
      response = HTTP.headers(headers).get(url, params: params)
      
      if response.status == 200
        notifications = JSON.parse(response.body)
        mentions = notifications.select { |n| n['type'] == 'mention' }
        
        puts "최근 주문 #{mentions.size}개:"
        mentions.each_with_index do |mention, index|
          acct = mention['account']['acct']
          content = mention['status']['content'].gsub(/<[^>]*>/, '').strip
          created_at = mention['created_at']
          puts "   #{index + 1}. @#{acct} (#{created_at}): #{content[0..50]}#{'...' if content.length > 50}"
        end
        
        mentions
      else
        puts "최근 주문 조회 실패: #{response.status}"
        []
      end
    rescue => e
      puts "최근 주문 조회 실패: #{e.message}"
      []
    end
  end
end

# OpenStruct 클래스 정의 (Ruby 표준 라이브러리)
require 'ostruct'