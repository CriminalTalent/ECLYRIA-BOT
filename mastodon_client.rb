# mastodon_client.rb
require 'net/http'
require 'json'
require 'uri'
require 'time'

class MastodonClient
  def initialize(base_url:, token:)
    @base_url = base_url.sub(%r{/\z}, '')
    @token    = token

    uri = URI(@base_url)
    @http = Net::HTTP.new(uri.host, uri.port)
    @http.use_ssl = (uri.scheme == "https")
    @http.keep_alive_timeout = 30

    @post_block_until = Time.at(0)
  end

  # ---------------------------
  # 🔐 인코딩 안전 helper
  # ---------------------------
  def safe_utf8(str)
    return "" if str.nil?
    s = str.to_s.dup

    # 1) 일단 UTF-8로 간주
    s.force_encoding('UTF-8')

    # 2) 깨진 인코딩이면 바이너리 기준으로 재인코딩
    unless s.valid_encoding?
      s = s.encode(
        'UTF-8',
        'binary',
        invalid: :replace,
        undef:   :replace,
        replace: '?'
      )
    end

    s
  rescue
    # 최악의 경우에도 에러 안 나게
    str.to_s
  end

  # ---------------------------
  # 공통 요청
  # ---------------------------
  def request(method:, path:, params: {}, form: nil)
    uri = URI.join(@base_url, path)
    uri.query = URI.encode_www_form(params) if method == :get && params.any?

    headers = { "Authorization" => "Bearer #{@token}" }

    req =
      case method
      when :get
        Net::HTTP::Get.new(uri, headers)
      when :post
        r = Net::HTTP::Post.new(uri, headers)
        r.set_form_data(form) if form
        r
      else
        raise "Unsupported method: #{method}"
      end

    res = @http.request(req)

    body =
      begin
        JSON.parse(res.body)
      rescue
        {}
      end

    [res, body]
  rescue => e
    puts "[HTTP 오류] #{e.class}: #{safe_utf8(e.message)}"
    [nil, { "error" => e.message }]
  end

  # ---------------------------
  # 글쓰기 / 답글
  # ---------------------------
  def post_status(text, reply_to_id: nil, visibility: "public")
    # 레이트리밋으로 막혀 있으면 스킵
    if Time.now < @post_block_until
      puts "[POST] rate limit 블록 중 (#{@post_block_until}) → 포스트 스킵"
      return { "error" => "post_blocked" }
    end

    form = {
      status: safe_utf8(text),
      visibility: visibility
    }
    form[:in_reply_to_id] = reply_to_id if reply_to_id

    res, body = request(
      method: :post,
      path: "/api/v1/statuses",
      form: form
    )

    if res
      limit     = res['x-ratelimit-limit']
      remaining = res['x-ratelimit-remaining']
      reset_raw = res['x-ratelimit-reset']

      puts "[POST DEBUG] code=#{res.code} limit=#{limit} remaining=#{remaining} reset=#{reset_raw}"

      if res.code == '429'
        # 글쓰기 리밋 걸렸을 때 블록 시간 설정
        if reset_raw
          begin
            reset_time = Time.parse(reset_raw)
            @post_block_until = reset_time
          rescue
            @post_block_until = Time.now + 600
          end
        else
          @post_block_until = Time.now + 600
        end
        puts "[POST 경고] 글쓰기 rate limit 도달 → #{@post_block_until} 까지 포스트 중단"

      elsif res.code.to_i >= 400
        body_str = safe_utf8(res.body)
        puts "[POST 오류] code=#{res.code} body=#{body_str}"
      end
    end

    body
  end

  def reply(status_obj, text, visibility: "public")
    reply_to_id =
      if status_obj.respond_to?(:id)
        status_obj.id
      elsif status_obj.is_a?(Hash)
        status_obj["id"] || status_obj[:id]
      else
        status_obj.to_s
      end

    post_status(text, reply_to_id: reply_to_id, visibility: visibility)
  end
end
