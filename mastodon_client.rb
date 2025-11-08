# ============================================
# mastodon_client.rb
# Mastodon API 래퍼 (v1.1.0 호환)
# ============================================
# encoding: UTF-8
require 'mastodon'
require 'json'
require 'time'

class MastodonClient
  attr_reader :base_url, :token, :client

  # -----------------------------
  # 초기화 및 환경 변수 검증
  # -----------------------------
  def initialize(base_url:, token:)
    @base_url = base_url
    @token = token

    @client = Mastodon::REST::Client.new(base_url: @base_url, bearer_token: @token)
  end

  def self.validate_environment
    required = %w[MASTODON_BASE_URL MASTODON_TOKEN GOOGLE_SHEET_ID GOOGLE_APPLICATION_CREDENTIALS]
    missing = required.select { |v| ENV[v].nil? || ENV[v].strip.empty? }
    if missing.any?
      puts "[환경오류] 누락된 환경 변수: #{missing.join(', ')}"
      return false
    end
    true
  end

  # -----------------------------
  # 상태(글) 작성
  # -----------------------------
  def post_status(message, visibility: 'unlisted', media_ids: nil)
    safe_message = message.to_s.dup.force_encoding('UTF-8')
    params = { status: safe_message, visibility: visibility }
    params[:media_ids] = media_ids if media_ids

    @client.create_status(**params)
    puts "[마스토돈] 게시 완료"
  rescue => e
    puts "[에러] 게시 실패: #{e.message}"
    puts e.backtrace.first(3)
  end

  # -----------------------------
  # 답글 작성
  # -----------------------------
  def reply(in_reply_to_id:, message:)
    safe_message = message.to_s.dup.force_encoding('UTF-8')
    begin
      @client.create_status(
        safe_message,
        in_reply_to_id: in_reply_to_id,
        visibility: 'unlisted'
      )
      puts "[마스토돈] → 답글 전송 완료"
    rescue => e
      puts "[에러] 응답 전송 중 예외 발생: #{e.message}"
      puts e.backtrace.first(3)
    end
  end

  # -----------------------------
  # 멘션 읽기
  # -----------------------------
  def fetch_mentions(limit: 20)
    response = @client.perform_request(:get, '/api/v1/notifications', { limit: limit })
    response.select { |n| n['type'] == 'mention' }
  rescue => e
    puts "[에러] 멘션 불러오기 실패: #{e.message}"
    []
  end

  # -----------------------------
  # 미디어 업로드 (이미지 등)
  # -----------------------------
  def upload_media(file_path, description: '')
    file = File.open(file_path)
    media = @client.upload_media(file, description: description)
    file.close
    media.id
  rescue => e
    puts "[에러] 미디어 업로드 실패: #{e.message}"
    nil
  end
end
