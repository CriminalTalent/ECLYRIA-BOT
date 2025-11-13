require 'net/http'
require 'json'
require 'uri'

class MastodonClient
  def initialize(base_url:, token:)
    @base_url = base_url
    @token = token
  end

  # ===========================
  # 🔥 기본 요청 공통 처리
  # ===========================
  def request(method:, path:, params: {})
    uri = URI.join(@base_url, path)
    uri.query = URI.encode_www_form(params) if method == :get && params.any?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"

    headers = {
      "Authorization" => "Bearer #{@token}"
    }

    begin
      response = http.request(request_object(method, uri, headers))
    rescue => e
      puts "[HTTP 오류] #{e.class}: #{e.message}"
      return [nil, {}]
    end

    # Rate-limit 헤더 수집
    rate_headers = {
      limit:    response["x-ratelimit-limit"],
      remaining: response["x-ratelimit-remaining"],
      reset:    response["x-ratelimit-reset"]
    }

    # JSON parse 시도
    body =
      begin
        JSON.parse(response.body)
      rescue
        {}
      end

    # 429 감지
    if response.code == "429"
      puts "[경고] 429 Too Many Requests"
      puts "응답: #{response.body}"
    end

    [body, rate_headers]
  end

  def request_object(method, uri, headers)
    case method
    when :get
      Net::HTTP::Get.new(uri, headers)
    when :post
      Net::HTTP::Post.new(uri, headers)
    else
      raise "Unsupported HTTP method #{method}"
    end
  end

  # ===========================
  # 🔥 멘션 읽기 (Headers 포함)
  # ===========================
  def get_mentions_with_headers(limit: 20, since_id: nil)
    params = { limit: limit }
    params[:since_id] = since_id if since_id

    path = "/api/v1/notifications"
    body, headers = request(method: :get, path: path, params: params)

    return [[], headers] unless body.is_a?(Array)

    mentions = body.select { |n| n["type"] == "mention" }

    [mentions, headers]
  end

  # ===========================
  # 🔥 답글쓰기
  # ===========================
  def post_status(status, reply_to_id: nil, visibility: "public")
    path = "/api/v1/statuses"
    uri = URI.join(@base_url, path)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"

    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{@token}"
    req.set_form_data({
      status: status,
      in_reply_to_id: reply_to_id,
      visibility: visibility
    })

    begin
      response = http.request(req)
      JSON.parse(response.body)
    rescue => e
      puts "[HTTP POST 오류] #{e.message}"
      {}
    end
  end
end
