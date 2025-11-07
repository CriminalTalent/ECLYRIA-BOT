# ============================================
# mastodon_client.rb (create_status 안정화 버전)
# ============================================
require 'mastodon'
require 'uri'
require 'json'
require 'dotenv'
Dotenv.load('.env')

class MastodonClient
  def initialize(base_url:, token:)
    @base_url = base_url
    @token = token
    @client = Mastodon::REST::Client.new(
      base_url: base_url,
      bearer_token: token
    )
    @streamer = nil
  end

  # -------------------------------
  # 스트리밍 관련
  # -------------------------------
  def get_streamer
    @streamer ||= Mastodon::Streaming::Client.new(
      base_url: @base_url,
      bearer_token: @token
    )
  rescue => e
    puts "[경고] 스트리밍 클라이언트 초기화 실패: #{e.message}"
    nil
  end

  def stream_user(&block)
    puts "[마스토돈] 멘션 스트리밍 시작..."
    streamer = get_streamer
    return unless streamer

    loop do
      begin
        streamer.user do |event|
          if event.is_a?(Mastodon::Notification) && event.type == 'mention'
            block.call(event)
          end
        end
      rescue => e
        puts "[에러] 스트리밍 중단됨: #{e.message}"
        puts e.backtrace.first(3)
        puts "[마스토돈] 5초 후 재연결 시도..."
        sleep 5
        retry
      end
    end
  end

  # -------------------------------
  # reply (Hash/Object 대응 + 응답검증)
  # -------------------------------
  def reply(to_status_or_acct, message, in_reply_to_id: nil)
    begin
      if to_status_or_acct.respond_to?(:account)
        account = to_status_or_acct.account
        acct = account.is_a?(Hash) ? account["acct"] : account.acct

        reply_to_id =
          if in_reply_to_id
            in_reply_to_id
          elsif to_status_or_acct.respond_to?(:id)
            to_status_or_acct.id
          elsif to_status_or_acct.is_a?(Hash)
            to_status_or_acct["id"]
          else
            nil
          end
      else
        acct = to_status_or_acct
        reply_to_id = in_reply_to_id
      end

      status_text = "@#{acct} #{message}".dup
      puts "[마스토돈] → @#{acct} 에게 응답 전송"

      raw_response = @client.perform_request_with_object(
        :post,
        '/api/v1/statuses',
        Mastodon::Status,
        { status: status_text, in_reply_to_id: reply_to_id, visibility: 'unlisted' }
      )

      if raw_response.respond_to?(:id)
        puts "[DEBUG] 답장 전송 완료: #{message[0..60]}"
      else
        puts "[경고] Mastodon 응답에 id가 없음 (비정상 응답)"
        puts "  ↳ 응답 내용: #{raw_response.inspect}"
      end
      raw_response
    rescue Mastodon::Error => e
      puts "[에러] 응답 전송 실패 (API 오류): #{e.message}"
      puts e.backtrace.first(3)
      nil
    rescue => e
      puts "[에러] 응답 전송 중 예외 발생: #{e.message}"
      puts e.backtrace.first(3)
      nil
    end
  end

  # -------------------------------
  # 공지 / 일반 포스트 / DM
  # -------------------------------
  def broadcast(message)
    begin
      puts "[마스토돈] → 전체 공지 전송"
      @client.create_status(message, visibility: 'public')
    rescue => e
      puts "[에러] 공지 전송 실패: #{e.message}"
    end
  end

  def say(message)
    begin
      puts "[마스토돈] → 일반 포스트 전송"
      @client.create_status(message, visibility: 'public')
    rescue => e
      puts "[에러] 포스트 전송 실패: #{e.message}"
    end
  end

  def dm(to_acct, message)
    begin
      puts "[마스토돈] → @#{to_acct} DM 전송"
      status_text = "@#{to_acct} #{message}".dup
      @client.create_status(status_text, visibility: 'direct')
    rescue => e
      puts "[에러] DM 전송 실패: #{e.message}"
    end
  end

  # -------------------------------
  # 인증 / 환경검증
  # -------------------------------
  def me
    @client.verify_credentials.acct
  rescue => e
    puts "[에러] 사용자 인증 실패: #{e.message}"
    nil
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

  def self.client
    @instance ||= new(
      base_url: ENV['MASTODON_BASE_URL'],
      token: ENV['MASTODON_TOKEN']
    )
  end
end
