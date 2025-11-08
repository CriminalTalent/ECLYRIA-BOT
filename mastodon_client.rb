# ============================================
# mastodon_client.rb (최종 안정화 + 이미지 자동 인식형)
# ============================================
require 'mastodon'
require 'uri'
require 'open-uri'
require 'tempfile'
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
  # reply (응답 파싱 강화)
  # -------------------------------
  def reply(to_status_or_acct, message, in_reply_to_id: nil, image_url: nil)
    begin
      acct, reply_to_id = extract_acct_info(to_status_or_acct, in_reply_to_id)
      status_text = "@#{acct} #{message}".dup
      puts "[마스토돈] → @#{acct} 에게 응답 전송"

      media_ids = []
      if image_url && !image_url.strip.empty?
        media_id = upload_image(image_url)
        media_ids << media_id if media_id
      end

      response = @client.create_status(status_text, {
        in_reply_to_id: reply_to_id,
        visibility: 'unlisted',
        media_ids: media_ids.compact
      })

      if response.respond_to?(:id)
        puts "[DEBUG] 답장 전송 완료: #{message[0..60]}"
      elsif response.is_a?(Hash) && response["id"]
        puts "[DEBUG] 답장 전송 완료 (Hash): #{response["id"]}"
      else
        puts "[경고] Mastodon 응답 구조 이상 (id 없음)"
        puts "  ↳ #{response.inspect[0..200]}"
      end
      response
    rescue Mastodon::Error => e
      puts "[에러] 응답 전송 실패 (API 오류): #{e.message}"
      nil
    rescue => e
      puts "[에러] 응답 전송 중 예외 발생: #{e.message}"
      nil
    end
  end

  # -------------------------------
  # 공지 / 일반 포스트 / DM
  # -------------------------------
  def broadcast(message, image_url: nil)
    post_with_optional_image(message, visibility: 'public', image_url:)
  end

  def say(message, image_url: nil)
    post_with_optional_image(message, visibility: 'public', image_url:)
  end

  def dm(to_acct, message, image_url: nil)
    begin
      puts "[마스토돈] → @#{to_acct} DM 전송"
      status_text = "@#{to_acct} #{message}".dup
      media_ids = []
      if image_url && !image_url.strip.empty?
        media_id = upload_image(image_url)
        media_ids << media_id if media_id
      end
      @client.create_status(status_text, visibility: 'direct', media_ids: media_ids.compact)
    rescue => e
      puts "[에러] DM 전송 실패: #{e.message}"
    end
  end

  # -------------------------------
  # 이미지 업로드 (URL 또는 로컬 경로 자동 인식)
  # -------------------------------
  def upload_image(image_source)
    begin
      if image_source.start_with?('http')
        puts "[이미지] URL 업로드 시도: #{image_source}"
        Tempfile.create(['img', File.extname(image_source)]) do |temp|
          URI.open(image_source) { |r| temp.write(r.read) }
          temp.rewind
          media = @client.upload_media(temp)
          return media.id
        end
      elsif File.exist?(image_source)
        puts "[이미지] 로컬 파일 업로드 시도: #{image_source}"
        File.open(image_source, 'rb') do |file|
          media = @client.upload_media(file)
          return media.id
        end
      else
        puts "[경고] 이미지 경로 또는 URL이 유효하지 않습니다: #{image_source}"
        nil
      end
    rescue => e
      puts "[에러] 이미지 업로드 실패: #{e.message}"
      nil
    end
  end

  # -------------------------------
  # 내부 유틸
  # -------------------------------
  def extract_acct_info(obj, reply_id)
    if obj.respond_to?(:account)
      account = obj.account
      acct = account.is_a?(Hash) ? account["acct"] : account.acct
      reply_to_id = reply_id || (obj.respond_to?(:id) ? obj.id : nil)
    else
      acct = obj
      reply_to_id = reply_id
    end
    [acct, reply_to_id]
  end

  def post_with_optional_image(message, visibility: 'public', image_url: nil)
    begin
      media_ids = []
      if image_url && !image_url.strip.empty?
        media_id = upload_image(image_url)
        media_ids << media_id if media_id
      end

      @client.create_status(message, visibility:, media_ids:)
    rescue => e
      puts "[에러] 포스트 전송 실패: #{e.message}"
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
