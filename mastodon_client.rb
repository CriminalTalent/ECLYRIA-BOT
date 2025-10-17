# mastodon_client.rb
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

    # Streaming 클라이언트 초기화를 지연시킴
    @streamer = nil
  end

  # 스트리밍 클라이언트 초기화 (필요할 때만)
  def get_streamer
    @streamer ||= Mastodon::Streaming::Client.new(
      base_url: @base_url,
      bearer_token: @token
    )
  rescue => e
    puts "[경고] 스트리밍 클라이언트 초기화 실패: #{e.message}"
    nil
  end

  # 실시간 멘션 스트리밍 처리
  def stream_user(&block)
    puts "[마스토돈] 멘션 스트리밍 시작..."
    streamer = get_streamer
    return unless streamer

    streamer.user do |event|
      if event.is_a?(Mastodon::Notification) && event.type == 'mention'
        block.call(event)
      end
    end
  rescue => e
    puts "[에러] 스트리밍 중단됨: #{e.message}"
    sleep 5
    retry
  end

  # 멘션에 답글 작성 (mention 전체 객체 호환)
  def reply(mention, message)
    begin
      # mention이 전체 알림 객체일 경우 내부 status 접근
      status = mention.respond_to?(:status) ? mention.status : mention

      # 대상 정보 안전 추출
      acct = mention.account.acct rescue "unknown"
      in_reply_to_id = status.id rescue nil
      visibility = status.visibility rescue "public"

      puts "[마스토돈] → @#{acct} 에게 응답 전송"
      status_text = "@#{acct} #{message}".dup

      response = @client.create_status(
        status_text,
        {
          in_reply_to_id: in_reply_to_id,
          visibility: visibility
        }
      )
      puts "답장 전송 완료: #{message[0..50]}..."
      response
    rescue Mastodon::Error => e
      puts "[API 에러] Mastodon 요청 실패: #{e.message}"
      puts e.backtrace.first(3).join("\n")
      nil
    rescue => e
      puts "[에러] 응답 전송 실패: #{e.message}"
      nil
    end
  end

  # 전체 공지용 푸시
  def broadcast(message)
    begin
      puts "[마스토돈] → 전체 공지 전송"
      @client.create_status(
        message,
        visibility: 'public'
      )
    rescue => e
      puts "[에러] 공지 전송 실패: #{e.message}"
    end
  end

  # 일반 포스트 (상점봇용)
  def say(message)
    begin
      puts "[마스토돈] → 일반 포스트 전송"
      @client.create_status(
        message,
        visibility: 'public'
      )
    rescue => e
      puts "[에러] 포스트 전송 실패: #{e.message}"
    end
  end

  # DM 전송
  def dm(to_acct, message)
    begin
      puts "[마스토돈] → @#{to_acct} DM 전송"
      status_text = "@#{to_acct} #{message}".dup
      @client.create_status(
        status_text,
        visibility: 'direct'
      )
    rescue => e
      puts "[에러] DM 전송 실패: #{e.message}"
    end
  end

  def me
    @client.verify_credentials.acct
  end

  # 환경변수 검증 (기존 상점봇 메서드 유지)
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

  # 이전 방식과의 호환성을 위한 클래스 메서드
  def self.client
    @instance ||= new(
      base_url: ENV['MASTODON_BASE_URL'],
      token: ENV['MASTODON_TOKEN']
    )
  end
end
