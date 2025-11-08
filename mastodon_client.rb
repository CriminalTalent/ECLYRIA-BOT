# ============================================
# mastodon_client.rb (HTTP 직접 호출 안정화 버전)
# ============================================

require 'http'
require 'json'
require 'dotenv'
Dotenv.load('.env')

class MastodonClient
  # ✅ 환경 변수 검증
  def self.validate_environment
    required = %w[MASTODON_BASE_URL MASTODON_TOKEN GOOGLE_SHEET_ID GOOGLE_APPLICATION_CREDENTIALS]
    missing = required.reject { |key| ENV[key] && !ENV[key].strip.empty? }

    if missing.any?
      puts "[환경변수 누락] #{missing.join(', ')}"
      return false
    end

    true
  end

  # ============================================
  # 초기화
  # ============================================
  def initialize(base_url:, token:)
    @base_url = base_url
    @token = token
    @http = HTTP.auth("Bearer #{@token}")
  end

  # ============================================
  # Mentions 가져오기
  # ============================================
  def get_mentions(limit: 20)
    res = @http.get("#{@base_url}/api/v1/notifications", params: { limit: limit })
    return [] unless res.status.success?

    JSON.parse(res.body.to_s).select { |n| n["type"] == "mention" }
  rescue => e
    puts "[에러] Mentions 불러오기 실패: #{e.message}"
    puts e.backtrace.first(3)
    []
  end

  # ============================================
  # 답글 전송
  # ============================================
  def reply(to_status, message)
    acct = to_status.dig("account", "acct")
    in_reply_to_id = to_status.dig("status", "id")
    text = "@#{acct} #{message}"

    puts "[마스토돈] → @#{acct} 에게 응답 전송"

    res = @http.post(
      "#{@base_url}/api/v1/statuses",
      json: {
        status: text,
        in_reply_to_id: in_reply_to_id,
        visibility: "unlisted"
      }
    )

    body = res.body.to_s.dup  # ⚙️ FrozenError 방지용
    if res.status.success?
      puts "[DEBUG] 응답 전송 성공 (#{message[0..40]})"
    else
      puts "[경고] 응답 실패 (HTTP #{res.status}): #{body}"
    end
  rescue => e
    puts "[에러] 응답 전송 중 예외 발생: #{e.message}"
    puts e.backtrace.first(3)
  end
end
