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

  def safe_utf8(str)
    return "" if str.nil?
    s = str.to_s.dup.force_encoding('UTF-8')
    s.valid_encoding? ? s : s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '?')
  rescue
    str.to_s
  end

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
        raise "Unsupported method"
      end

    res = @http.request(req)
    body = JSON.parse(res.body) rescue {}
    [res, body]
  rescue => e
    puts "[HTTP 오류] #{e.message}"
    [nil, {}]
  end

  def upload_media_from_url(image_url, description: nil)
    download_url = image_url.gsub(/\/view\?usp=sharing/, '')
                            .sub('/file/d/', '/uc?export=download&id=')

    ext = File.extname(download_url)
    ext = '.jpg' if ext.empty?

    Tempfile.create(['doll', ext]) do |file|
      file.binmode
      URI.open(download_url, 'User-Agent' => 'Mozilla/5.0') { |io| file.write(io.read) }
      file.rewind

      return upload_media(file.path, description: description)
    end
  rescue => e
    puts "[MEDIA-URL 오류] #{e.message}"
    nil
  end

  def upload_media(path, description: nil)
    uri = URI.join(@base_url, "/api/v2/media")
    boundary = SecureRandom.hex(16)

    file = File.binread(path)
    name = File.basename(path)

    body = []
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{name}\"\r\n"
    body << "Content-Type: image/jpeg\r\n\r\n"
    body << file
    body << "\r\n--#{boundary}--\r\n"

    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{@token}"
    req['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    req.body = body.join

    res = @http.request(req)
    return JSON.parse(res.body)['id'] if res.code.to_i.between?(200, 299)

    nil
  end

  def post_status(text, reply_to_id: nil, visibility: "public", media_ids: [])
    return if Time.now < @post_block_until

    form = { status: safe_utf8(text), visibility: visibility }
    form[:in_reply_to_id] = reply_to_id if reply_to_id

    media_ids.each_with_index { |id, i| form["media_ids[#{i}]"] = id }

    res, _ = request(method: :post, path: "/api/v1/statuses", form: form)

    if res&.code == '429'
      reset = res['x-ratelimit-reset']
      @post_block_until =
        begin
          reset ? Time.parse(reset) : Time.now + 600
        rescue
          Time.now + 600
        end
    end
  end

  def reply(status, text, visibility: "unlisted", media_ids: [])
    post_status(
      text,
      reply_to_id: status["id"],
      visibility: visibility,
      media_ids: media_ids
    )
  end
end
