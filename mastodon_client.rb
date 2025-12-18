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

  # ---------------------------
  # 인코딩 안전 helper
  # ---------------------------
  def safe_utf8(str)
    return "" if str.nil?
    s = str.to_s.dup
    s.force_encoding('UTF-8')

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
  # 알림(멘션) 가져오기
  # ---------------------------
  def notifications(limit: 40)
    res, body = request(
      method: :get,
      path: "/api/v1/notifications",
      params: { limit: limit }
    )

    return [] unless body.is_a?(Array)

    body.select { |n| n["type"] == "mention" }
  end

  # ---------------------------
  # 구글 드라이브 URL 변환
  # ---------------------------
  def convert_google_drive_url(url)
    return url if url.nil?

    if url =~ /drive\.google\.com\/file\/d\/([^\/]+)/
      return "https://drive.google.com/uc?export=download&id=#{$1}"
    end

    if url =~ /drive\.google\.com\/open\?id=([^&]+)/
      return "https://drive.google.com/uc?export=download&id=#{$1}"
    end

    return url if url.include?("drive.google.com/uc?")
    url
  end

  # ---------------------------
  # 미디어 업로드 (로컬 파일)
  # ---------------------------
  def upload_media(file_path, description: nil)
    return nil unless File.exist?(file_path)

    uri = URI.join(@base_url, "/api/v2/media")
    boundary = SecureRandom.hex(16)

    file_content = File.binread(file_path)
    filename = File.basename(file_path)

    mime_type =
      case File.extname(file_path).downcase
      when '.jpg', '.jpeg' then 'image/jpeg'
      when '.png' then 'image/png'
      when '.gif' then 'image/gif'
      else 'application/octet-stream'
      end

    body_parts = []

    body_parts << "--#{boundary}\r\n".b
    body_parts << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n".b
    body_parts << "Content-Type: #{mime_type}\r\n\r\n".b
    body_parts << file_content.b
    body_parts << "\r\n".b

    if description
      body_parts << "--#{boundary}\r\n".b
      body_parts << "Content-Disposition: form-data; name=\"description\"\r\n\r\n".b
      body_parts << description.to_s.b
      body_parts << "\r\n".b
    end

    body_parts << "--#{boundary}--\r\n".b
    body = body_parts.join

    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{@token}"
    req['Content-Type']  = "multipart/form-data; boundary=#{boundary}"
    req.body = body

    puts "[MEDIA] 업로드 시도: #{filename} (#{file_content.size} bytes)"
    res = @http.request(req)

    if res.code.to_i.between?(200, 299)
      json = JSON.parse(res.body)
      puts "[MEDIA] 업로드 성공: #{json['id']}"
      json['id']
    else
      puts "[MEDIA] 업로드 실패: code=#{res.code}"
      puts "[MEDIA] 응답: #{safe_utf8(res.body)}"
      nil
    end
  rescue => e
    puts "[MEDIA 오류] #{e.class}: #{safe_utf8(e.message)}"
    puts e.backtrace.first(3).join("\n  ↳ ")
    nil
  end

  # ---------------------------
  # URL 이미지 다운로드 후 업로드
  # ---------------------------
  def upload_media_from_url(image_url, description: nil)
    download_url = convert_google_drive_url(image_url)
    puts "[MEDIA-URL] 다운로드: #{download_url}"

    ext = File.extname(download_url)
    ext = '.jpg' unless %w[.jpg .jpeg .png .gif].include?(ext)

    file = Tempfile.new(['media', ext])
    file.binmode

    URI.open(
      download_url,
      'User-Agent' => 'Mozilla/5.0',
      ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE
    ) { |f| file.write(f.read) }

    file.rewind
    size = file.size

    if size < 1024 || size > 8 * 1024 * 1024
      puts "[MEDIA-URL] 크기 오류: #{size} bytes"
      file.close!
      return nil
    end

    media_id = upload_media(file.path, description: description)
    file.close!
    media_id
  rescue => e
    puts "[MEDIA-URL 오류] #{e.class}: #{safe_utf8(e.message)}"
    puts e.backtrace.first(3).join("\n  ↳ ")
    nil
  end

  # ---------------------------
  # 글쓰기 / 답글
  # ---------------------------
  def post_status(text, reply_to_id: nil, visibility: "public", media_ids: [])
    if Time.now < @post_block_until
      puts "[POST] rate limit 차단 중 → 스킵"
      return { "error" => "rate_limited" }
    end

    form = {
      status: safe_utf8(text),
      visibility: visibility
    }
    form[:in_reply_to_id] = reply_to_id if reply_to_id

    media_ids.each_with_index do |id, i|
      form["media_ids[#{i}]"] = id
    end

    res, body = request(
      method: :post,
      path: "/api/v1/statuses",
      form: form
    )

    if res&.code == '429'
      reset = res['x-ratelimit-reset']
      @post_block_until =
        reset ? Time.parse(reset) rescue Time.now + 600 : Time.now + 600
      puts "[POST] rate limit → #{@post_block_until} 까지 중단"
    end

    body
  end

  def reply(status_obj, text, visibility: "public", media_ids: [])
    reply_to_id =
      status_obj.is_a?(Hash) ? status_obj["id"] : status_obj.respond_to?(:id) ? status_obj.id : status_obj

    post_status(
      text,
      reply_to_id: reply_to_id,
      visibility: visibility,
      media_ids: media_ids
    )
  end
end
