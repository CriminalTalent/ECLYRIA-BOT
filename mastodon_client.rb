# mastodon_client.rb
require 'net/http'
require 'json'
require 'uri'
require 'time'
require 'open-uri'
require 'tempfile'
require 'openssl'
require 'securerandom'

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

  # -------------------------
  # UTF-8 안전 처리
  # -------------------------
  def safe_utf8(str)
    return "" if str.nil?
    s = str.to_s.dup.force_encoding('UTF-8')
    s.valid_encoding? ? s : s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '?')
  rescue
    str.to_s
  end

  # -------------------------
  # 기본 HTTP 요청
  # -------------------------
  def request(method:, path:, params: {}, form: nil)
    uri = URI.join(@base_url, path)
    uri.query = URI.encode_www_form(params) if method == :get && params.any?

    headers = {
      "Authorization" => "Bearer #{@token}"
    }

    req =
      case method
      when :get
        Net::HTTP::Get.new(uri, headers)
      when :post
        r = Net::HTTP::Post.new(uri, headers)
        r.set_form_data(form) if form
        r
      else
        raise "Unsupported method"
      end

    res = @http.request(req)
    body = JSON.parse(res.body) rescue {}
    [res, body]
  rescue => e
    puts "[HTTP ERROR] #{e.class}: #{e.message}"
    [nil, {}]
  end

  # -------------------------
  # URL → 미디어 업로드 (PNG 대응)
  # -------------------------
  def upload_media_from_url(image_url, description: nil)
    download_url =
      image_url
        .gsub(/\/view\?usp=sharing/, '')
        .sub('/file/d/', '/uc?export=download&id=')

    ext = File.extname(download_url)
    ext = '.png' if ext.empty?

    Tempfile.create(['doll', ext]) do |file|
      file.binmode
      URI.open(download_url, 'User-Agent' => 'Mozilla/5.0') do |io|
        file.write(io.read)
      end
      file.rewind

      upload_media(file.path, description: description)
    end
  rescue => e
    puts "[MEDIA-URL ERROR] #{e.class}: #{e.message}"
    nil
  end

  # -------------------------
  # 로컬 파일 → Mastodon 업로드
  # -------------------------
  def upload_media(path, description: nil)
    uri = URI.join(@base_url, "/api/v2/media")
    boundary = SecureRandom.hex(16)

    file_data = File.binread(path)
    filename  = File.basename(path)

    content_type =
      case File.extname(path).downcase
      when '.png' then 'image/png'
      when '.jpg', '.jpeg' then 'image/jpeg'
      else 'application/octet-stream'
      end

    body = []
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
    body << "Content-Type: #{content_type}\r\n\r\n"
    body << file_data
    body << "\r\n--#{boundary}--\r\n"

    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{@token}"
    req['Content-Type']  = "multipart/form-data; boundary=#{boundary}"
    req.body = body.join

    res = @http.request(req)
    return JSON.parse(res.body)['id'] if res.code.to_i.between?(200, 299)

    puts "[MEDIA ERROR] 업로드 실패: #{res.code}"
    nil
  rescue => e
    puts "[MEDIA ERROR] #{e.class}: #{e.message}"
    nil
  end

  # -------------------------
  # 상태(post) 전송 (이미지 첨부 핵심)
  # -------------------------
  def post_status(text, reply_to_id: nil, visibility: "public", media_ids: [])
    return if Time.now < @post_block_until

    form = {
      status: safe_utf8(text),
      visibility: visibility
    }
    form[:in_reply_to_id] = reply_to_id if reply_to_id

    # ⭐ Mastodon 방식 (중요)
    media_ids.each do |id|
      form["media_ids[]"] = id
    end

    res, _ = request(method: :post, path: "/api/v1/statuses", form: form)

    if res&.code == '429'
      reset = res['x-ratelimit-reset']
      @post_block_until =
        begin
          reset ? Time.parse(reset) : Time.now + 600
        rescue
          Time.now + 600
        end
      puts "[POST] rate limit → #{@post_block_until} 까지 중단"
    end
  end

  # -------------------------
  # reply 헬퍼
  # -------------------------
  def reply(status, text, visibility: "unlisted", media_ids: [])
    post_status(
      text,
      reply_to_id: status["id"],
      visibility: visibility,
      media_ids: media_ids
    )
  end
end
