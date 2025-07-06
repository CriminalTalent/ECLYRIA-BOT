require 'dotenv'
Dotenv.load('.env')
require_relative 'mastodon_client'
require_relative 'command_parser'
require 'set'
require 'time'

puts "\nECLYRIA 마법용품점 기동 완료!"
puts "BASE_URL: #{ENV['MASTODON_BASE_URL']}"
puts "TOKEN 시작: #{ENV['MASTODON_TOKEN'][0..10]}..." if ENV['MASTODON_TOKEN']

# 환경변수 확인
puts "\n📦 환경변수 확인"
puts "  MASTODON_BASE_URL: #{ENV['MASTODON_BASE_URL']}"
puts "  GOOGLE_CREDENTIALS_PATH: #{ENV['GOOGLE_CREDENTIALS_PATH']}"
puts "  GOOGLE_SHEET_ID: #{ENV['GOOGLE_SHEET_ID']}"

# 시트 설정 확인
puts "\n📄 구글 시트 설정 확인 중..."
google_credentials = ENV['GOOGLE_CREDENTIALS_PATH']
google_sheet_id = ENV['GOOGLE_SHEET_ID']
google_available = false

if google_credentials && google_sheet_id
  puts "   인증 파일: #{google_credentials}"
  if File.exist?(google_credentials)
    puts "   인증 파일 존재 확인"
    google_available = true
  else
    puts "   ❌ 인증 파일이 존재하지 않습니다"
  end
  puts "   시트 ID: #{google_sheet_id[0..10]}..."
else
  puts "   ❌ .env에 시트 설정이 누락되었습니다"
end

# 마스토돈 연결
puts "\n🔗 마스토돈 연결 테스트 중..."
unless MastodonClient.test_connection
  puts "❌ 마스토돈 연결 실패! .env 파일의 설정을 확인하세요"
  exit 1
end
puts "✅ 마스토돈 서버 연결 성공"

# 구글 시트 연결
if google_available
  begin
    require 'google_drive'
    session = GoogleDrive::Session.from_service_account_key(google_credentials)
    spreadsheet = session.spreadsheet_by_key(google_sheet_id)
    puts "✅ 시트 제목: #{spreadsheet.title}"
    required_sheets = ['플레이어', 'shop_items']
    missing = required_sheets - spreadsheet.worksheets.map(&:title)
    if missing.empty?
      puts "✅ 모든 필수 워크시트 존재 확인"
    else
      puts "⚠️ 누락된 워크시트: #{missing.join(', ')}"
    end
  rescue => e
    puts "❌ 구글 시트 연결 실패: #{e.message}"
    google_available = false
  end
end

puts "\n🛍️ 상점봇 준비 완료. 멘션 수신 대기 중..."
puts "   예: [구매/포션], [주머니], [운세], [d6], [랜덤상자]"
puts "   🔗 구글 시트 연동: #{google_available ? '활성화' : '비활성화'}"

# 멘션 처리 상태
processed_mentions = Set.new
start_time = Time.now
mention_count = 0
error_count = 0
last_cleanup = Time.now

# 멘션 대기 루프
loop do
  begin
    MastodonClient.listen_mentions do |mention|
      mention_id = mention.status.id
      created_at_raw = mention.status.created_at rescue nil

      # 시작 이전 멘션 무시
      begin
        mention_time = created_at_raw ? Time.parse(created_at_raw.to_s) : nil
        if mention_time && mention_time < start_time
          puts "[스킵] 봇 시작 이전 멘션: #{mention_time.strftime('%H:%M:%S')}"
          processed_mentions.add(mention_id)
          next
        end
      rescue => e
        puts "[경고] 시간 파싱 실패: #{e.message}"
      end

      # 중복 멘션 방지
      next if processed_mentions.include?(mention_id)
      processed_mentions.add(mention_id)
      mention_count += 1

      # 멘션 정보 출력
      user_acct = mention.account.acct
      user_display = mention.account.display_name || user_acct
      content = mention.status.content.gsub(/<[^>]*>/, '').strip

      puts "\n📩 주문 ##{mention_count}"
      puts "   👤 고객: @#{user_acct} (#{user_display})"
      puts "   📝 주문 내용: #{content}"
      puts "   🆔 주문 ID: #{mention_id}"
      begin
        order_time = mention_time ? mention_time.strftime('%Y-%m-%d %H:%M') : '시간 미상'
      rescue => e
        puts "[경고] 주문 시간 파싱 실패: #{e.message}"
        order_time = '시간 미상'
      end
      puts "   🕐 주문 시간: #{order_time}"

      # 실제 처리
      begin
        CommandParser.handle(mention)
        puts "   ✅ 주문 처리 완료"
      rescue => e
        error_count += 1
        puts "   ❌ 주문 처리 오류: #{e.message}"
        MastodonClient.reply(mention, "#{user_display}님, 주문 처리 중 오류가 발생했습니다. 🙇‍♂️")
      end
    end

    # 주기적 정리
    if Time.now - last_cleanup > 3600
      old_size = processed_mentions.size
      processed_mentions.clear if old_size > 1000
      puts "🧹 멘션 ID #{old_size}개 정리 완료"
      last_cleanup = Time.now
    end

  rescue Interrupt
    puts "\n🛑 종료 요청 (Ctrl+C)"
    break
  rescue => e
    puts "💥 루프 오류: #{e.message}"
    sleep 10
  end

  sleep 5
end

# 종료 로그
puts "\n📊 주문 처리 리포트"
puts "   총 주문: #{mention_count}건"
puts "   오류: #{error_count}건"
puts "   성공률: #{mention_count > 0 ? ((mention_count - error_count) * 100.0 / mention_count).round(1) : 0}%"
puts "   시트 연동: #{google_available ? 'ON' : 'OFF'}"
puts "📦 봇 종료됨"
