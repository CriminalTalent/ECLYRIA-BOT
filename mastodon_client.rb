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
    
    notifications = body.is_a?(Array) ? body : []
    mention_notifications = notifications.select { |n| n["type"] == "mention" }
    
    rate_info = nil
    if res
      rate_info = {
        limit: res['x-ratelimit-limit'],
        remaining: res['x-ratelimit-remaining'],
        reset: res['x-ratelimit-reset']
      }
    end
    
    mention_notifications
  end

  # ---------------------------
  # 구글 드라이브 URL 변환
  # ---------------------------
  def convert_google_drive_url(url)
    # 형태 1: https://drive.google.com/file/d/FILE_ID/view
    if url =~ /drive\.google\.com\/file\/d\/([^\/]+)/
      file_id = $1
      return "https://drive.google.com/uc?export=download&id=#{file_id}"
    end
    
    # 형태 2: https://drive.google.com/open?id=FILE_ID
    if url =~ /drive\.google\.com\/open\?id=([^&]+)/
      file_id = $1
      return "https://drive.google.com/uc?export=download&id=#{file_id}"
    end
    
    # 형태 3: 이미 변환된 형태
    if url =~ /drive\.google\.com\/uc\?/
      return url
    end
    
    # 구글 드라이브가 아니면 원본 반환
    url
  end

  # ---------------------------
  # 미디어 업로드 (로컬 파일) - 인코딩 수정
  # ---------------------------
  def upload_media(file_path, description: nil)
    return nil unless File.exist?(file_path)

    uri = URI.join(@base_url, "/api/v2/media")
    boundary = SecureRandom.hex(16)
    
    # 파일 읽기
    file_content = File.binread(file_path)
    filename = File.basename(file_path)
    mime_type = case File.extname(file_path).downcase
                when '.jpg', '.jpeg' then 'image/jpeg'
                when '.png' then 'image/png'
                when '.gif' then 'image/gif'
                else 'application/octet-stream'
                end
    
    # 모든 파트를 바이너리로 생성
    body_parts = []
    
    # 파일 파트
    body_parts << "--#{boundary}\r\n".force_encoding('ASCII-8BIT')
    body_parts << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n".force_encoding('ASCII-8BIT')
    body_parts << "Content-Type: #{mime_type}\r\n\r\n".force_encoding('ASCII-8BIT')
    body_parts << file_content.force_encoding('ASCII-8BIT')
    body_parts << "\r\n".force_encoding('ASCII-8BIT')
    
    # description 파트 (옵션)
    if description
      body_parts << "--#{boundary}\r\n".force_encoding('ASCII-8BIT')
      body_parts << "Content-Disposition: form-data; name=\"description\"\r\n\r\n".force_encoding('ASCII-8BIT')
      body_parts << description.to_s.force_encoding('ASCII-8BIT')
      body_parts << "\r\n".force_encoding('ASCII-8BIT')
    end
    
    body_parts << "--#{boundary}--\r\n".force_encoding('ASCII-8BIT')
    
    # 바이너리로 조합
    body_str = body_parts.join(''.force_encoding('ASCII-8BIT'))
    
    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{@token}"
    req['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    req.body = body_str
    
    puts "[MEDIA] 업로드 시도: #{filename} (#{file_content.size} bytes)"
    
    res = @http.request(req)
    
    if res.code.to_i >= 200 && res.code.to_i < 300
      result = JSON.parse(res.body)
      media_id = result['id']
      puts "[MEDIA] 업로드 성공: #{media_id}"
      return media_id
    else
      puts "[MEDIA] 업로드 실패: code=#{res.code}"
      puts "[MEDIA] 응답: #{safe_utf8(res.body)}"
      return nil
    end
  rescue => e
    puts "[MEDIA 오류] #{e.class}: #{safe_utf8(e.message)}"
    puts e.backtrace.first(3).join("\n  ↳ ")
    nil
  end

  # ---------------------------
  # URL에서 이미지 다운로드 후 업로드
  # ---------------------------
  def upload_media_from_url(image_url, description: nil)
    begin
      # 구글 드라이브 URL 변환
      download_url = convert_google_drive_url(image_url)
      puts "[MEDIA-URL] 원본 URL: #{image_url}"
      puts "[MEDIA-URL] 다운로드 URL: #{download_url}"
      
      # 임시 파일 생성
      ext = File.extname(image_url).downcase
      ext = '.jpg' if ext.empty? || !['.jpg', '.jpeg', '.png', '.gif'].include?(ext)
      
      temp_file = Tempfile.new(['doll', ext])
      temp_file.binmode
      
      # URL에서 이미지 다운로드
      URI.open(download_url, 
               'User-Agent' => 'Mozilla/5.0',
               ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE) do |downloaded|
        temp_file.write(downloaded.read)
      end
      temp_file.rewind
      
      file_size = temp_file.size
      puts "[MEDIA-URL] 다운로드 완료: #{file_size} bytes"
      
      # 파일 크기 체크
      if file_size < 1024
        puts "[MEDIA-URL] 오류: 파일이 너무 작음 (#{file_size} bytes)"
        temp_file.close
        temp_file.unlink
        return nil
      end
      
      if file_size > 8 * 1024 * 1024
        puts "[MEDIA-URL] 오류: 파일이 너무 큼 (#{file_size} bytes)"
        temp_file.close
        temp_file.unlink
        return nil
      end
      
      # 업로드
      media_id = upload_media(temp_file.path, description: description)
      
      temp_file.close
      temp_file.unlink
      
      media_id
    rescue OpenURI::HTTPError => e
      puts "[MEDIA-URL HTTP 오류] #{e.message}"
      puts "[MEDIA-URL] 확인사항:"
      puts "  1. 구글 드라이브 공유 설정: '링크가 있는 모든 사용자'"
      puts "  2. URL이 정확한지 확인"
      nil
    rescue => e
      puts "[MEDIA-URL 오류] #{e.class}: #{safe_utf8(e.message)}"
      puts e.backtrace.first(3).join("\n  ↳ ")
      nil
    end
  end

  # ---------------------------
  # 글쓰기 / 답글 (미디어 지원 추가)
  # ---------------------------
  def post_status(text, reply_to_id: nil, visibility: "public", media_ids: [])
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
    
    # 미디어 ID 추가
    if media_ids && media_ids.any?
      media_ids.each_with_index do |media_id, idx|
        form["media_ids[#{idx}]"] = media_id
      end
    end

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

  def reply(status_obj, text, visibility: "public", media_ids: [])
    reply_to_id =
      if status_obj.respond_to?(:id)
        status_obj.id
      elsif status_obj.is_a?(Hash)
        status_obj["id"] || status_obj[:id]
      else
        status_obj.to_s
      end

    post_status(text, reply_to_id: reply_to_id, visibility: visibility, media_ids: media_ids)
  end
end
