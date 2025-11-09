# ============================================
# mastodon_client.rb
# Mastodon API Wrapper (HTTP 안정 + RateLimit 완전 버전)
# ============================================
# encoding: UTF-8
require 'mastodon'
require 'json'
require 'net/http'
require 'uri'

class MastodonClient
  attr_reader :base_url, :token, :client

  def initialize(base_url:, token:)
    @base_url = base_url
    @token = token
    @client = Mastodon::REST::Client.new(base_url: base_url, bearer_token: token)
  end

  # --------------------------------------------
  # 환경 변수 검증
  # --------------------------------------------
  def self.validate_environment
    required = %w[MASTODON_BASE_URL MASTODON_TOKEN GOOGLE_SHEET_ID]
    missing = required.select { |v| ENV[v].nil? || ENV[v].strip.empty? }
    missing.empty?
  end

  # --------------------------------------------
  # Mentions 가져오기 (since_id 지원)
  # --------------------------------------------
  def get_mentions(limit: 20, since_id: nil)
    uri = URI.join(@base_url, '/api/v1/notifications')
    params = { limit: limit }
    params[:since_id] = since_id if since_id
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@token}"

    response = Net::HTTP.start(uri.hostname, uri.port,
                               use_ssl: uri.scheme == 'https') do |http|
      http.read_timeout = 15
      http.open_timeout = 5
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      puts "[HTTP 오류] #{response.code} #{response.message}"
      puts "응답 본문: #{response.body}"
      return []
    end

    JSON.parse(response.body)
  rescue => e
    puts "[에러] Mentions 가져오기 실패: #{e.message}"
    []
  end

  # --------------------------------------------
  # 마스토돈에 새 글 작성 (Toot)
  # --------------------------------------------
  def post(status)
    @client.create_status(status)
    puts "[마스토돈] 게시 완료 → #{status[0..40]}..."
  rescue => e
    puts "[에러] 게시 실패: #{e.message}"
  end

  # --------------------------------------------
  # 멘션에 대한 답글 작성
  # --------------------------------------------
  def reply(notification, message)
    status = notification["status"] || notification.status
    account = notification["account"] || notification.account
    acct = account["acct"] rescue account.acct
    in_reply_to_id = status["id"] rescue status.id
    content = "@#{acct} #{message}"

    @client.create_status(content, in_reply_to_id: in_reply_to_id)
    puts "[마스토돈] → @#{acct} 에게 응답 전송"
    puts "[DEBUG] 응답 전송 성공 (#{message[0..50]})"
  rescue => e
    puts "[에러] 응답 전송 실패: #{e.message}"
  end

  # --------------------------------------------
  # 직접 호출용 API 요청 (필요시)
  # --------------------------------------------
  def perform_request(method, path, params = {})
    uri = URI.join(@base_url, path)
    uri.query = URI.encode_www_form(params) if method == :get && !params.empty?

    request = case method
              when :get
                Net::HTTP::Get.new(uri)
              when :post
                Net::HTTP::Post.new(uri)
              else
                raise "지원되지 않는 HTTP 메서드: #{method}"
              end

    request['Authorization'] = "Bearer #{@token}"
    request['Content-Type'] = 'application/json'
    request.body = params.to_json if method == :post

    response = Net::HTTP.start(uri.hostname, uri.port,
                               use_ssl: uri.scheme == 'https') do |http|
      http.read_timeout = 15
      http.open_timeout = 5
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      puts "[HTTP 오류] #{response.code} #{response.message}"
      puts "응답 본문: #{response.body}"
      return nil
    end

    JSON.parse(response.body)
  rescue => e
    puts "[에러] perform_request 실패: #{e.message}"
    nil
  end

  # --------------------------------------------
  # 하위호환용: get_mentions_with_headers (RateLimit 대응)
  # --------------------------------------------
  def get_mentions_with_headers(limit: 20, since_id: nil)
    uri = URI.join(@base_url, '/api/v1/notifications')
    params = { limit: limit }
    params[:since_id] = since_id if since_id
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@token}"

    response = Net::HTTP.start(uri.hostname, uri.port,
                               use_ssl: uri.scheme == 'https') do |http|
      http.read_timeout = 15
      http.open_timeout = 5
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      puts "[HTTP 오류] #{response.code} #{response.message}"
      puts "응답 본문: #{response.body}"
      return [[], {}]
    end

    headers = {
      'x-ratelimit-limit' => response['x-ratelimit-limit'],
      'x-ratelimit-remaining' => response['x-ratelimit-remaining'],
      'x-ratelimit-reset' => response['x-ratelimit-reset']
    }
    data = JSON.parse(response.body)
    [data, headers]
  rescue => e
    puts "[에러] get_mentions_with_headers 실패: #{e.message}"
    [[], {}]
  end
end
