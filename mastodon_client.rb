# mastodon_client.rb
require 'mastodon'
require 'json'
require 'dotenv'
Dotenv.load('.env')

class MastodonClient
  def initialize
    @base_url = ENV['MASTODON_BASE_URL']
    @token = ENV['MASTODON_TOKEN']
    @client = Mastodon::REST::Client.new(
      base_url: @base_url,
      bearer_token: @token
    )
    @streamer = Mastodon::Streaming::Client.new(
      base_url: @base_url,
      bearer_token: @token
    )
  end

  def self.client
    @instance ||= new
  end

  def stream_user(&block)
    puts "멘션 스트리밍 시작..."
    @streamer.user do |event|
      if event.is_a?(Mastodon::Notification) && event.type == 'mention'
        block.call(event)
      end
    end
  rescue => e
    puts "스트리밍 중단됨: #{e.message}"
    sleep 5
    retry
  end

  def reply(to_status, message)
    begin
      response = @client.create_status(
        "@#{to_status.account.acct} #{message}",
        {
          in_reply_to_id: to_status.id,
          visibility: 'public'
        }
      )
      puts "답장 전송: @#{to_status.account.acct} - #{message[0..50]}..."
      response
    rescue => e
      puts "답장 전송 실패: #{e.message}"
      nil
    end
  end

  def self.validate_environment
    base_url = ENV['MASTODON_BASE_URL']
    token = ENV['MASTODON_TOKEN']
    
    missing_vars = []
    missing_vars << 'MASTODON_BASE_URL' if base_url.nil? || base_url.empty?
    missing_vars << 'MASTODON_TOKEN' if token.nil? || token.empty?
    
    if missing_vars.any?
      puts "필수 환경변수 누락: #{missing_vars.join(', ')}"
      puts ".env 파일을 확인해주세요."
      return false
    end
    
    true
  end
end
