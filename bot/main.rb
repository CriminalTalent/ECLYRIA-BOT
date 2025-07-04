require 'dotenv'
Dotenv.load(File.expand_path('../.env', __dir__))
require_relative 'mastodon_client'
require_relative 'command_parser'

puts "✅ 호그와트 마법용품점 봇 기동 완료!"
puts "📡 BASE_URL: #{ENV['MASTODON_BASE_URL']}"
puts "🔐 TOKEN 시작: #{ENV['MASTODON_TOKEN'][0..10]}..." if ENV['MASTODON_TOKEN']

# 구글 시트 설정 확인
puts "\n📊 구글 시트 설정 확인 중..."
google_credentials = ENV['GOOGLE_CREDENTIALS_PATH']
google_sheet_id = ENV['GOOGLE_SHEET_ID']

if google_credentials && google_sheet_id
  puts "   ✓ 인증 파일: #{google_credentials}"
  
  if File.exist?(google_credentials)
    puts "   ✓ 인증 파일 존재 확인"
  else
    puts "   ❌ 인증 파일 없음: #{google_credentials}"
    puts "      Google Cloud Console에서 서비스 계정 JSON 키를 다운로드하세요"
  end
  
  puts "   ✓ 시트 ID: #{google_sheet_id[0..10]}..."
else
  puts "   ❌ 구글 시트 설정이 .env 파일에 없습니다"
  puts "      GOOGLE_CREDENTIALS_PATH와 GOOGLE_SHEET_ID를 설정하세요"
end

# 마스토돈 연결 테스트
puts "\n🔌 마스토돈 연결 테스트 중..."
unless MastodonClient.test_connection
  puts "❌ 마스토돈 연결 실패! .env 파일의 설정을 확인하세요"
  exit 1
end

# 구글 시트 연결 테스트
puts "\n📊 구글 시트 연결 테스트 중..."
begin
  require 'google_drive'
  
  if File.exist?(google_credentials)
    session = GoogleDrive::Session.from_service_account_key(google_credentials)
    spreadsheet = session.spreadsheet_by_key(google_sheet_id)
    
    puts "✅ 구글 시트 연결 성공!"
    puts "   📄 시트 제목: #{spreadsheet.title}"
    
    # 워크시트들 확인
    worksheets = spreadsheet.worksheets
    puts "   📋 워크시트 목록:"
    worksheets.each_with_index do |ws, idx|
      puts "      #{idx + 1}. #{ws.title} (#{ws.num_rows}행 #{ws.num_cols}열)"
    end
    
    # 필요한 워크시트들 확인
    required_sheets = ['아이템', '사용자', '응답']
    missing_sheets = required_sheets - worksheets.map(&:title)
    
    if missing_sheets.empty?
      puts "   ✅ 필요한 워크시트 모두 존재"
    else
      puts "   ⚠️  누락된 워크시트: #{missing_sheets.join(', ')}"
      puts "      구글 시트에 해당 워크시트들을 생성해주세요"
    end
    
  else
    puts "❌ 인증 파일이 없습니다: #{google_credentials}"
  end
  
rescue => e
  puts "❌ 구글 시트 연결 실패: #{e.message}"
  puts "   인증 설정이나 시트 권한을 확인해주세요"
  puts "   계속 진행하되, 구글 시트 기능은 제한될 수 있습니다"
end

puts "\n🎭 호그와트 마법용품점 개점!"
puts "🔔 멘션 수신 대기 중..."
puts "   명령어 예시: [입학/해리포터], [상점], [주머니]"
puts "   종료하려면 Ctrl+C를 누르세요"

# 봇 실행 통계
start_time = Time.now
mention_count = 0
error_count = 0

loop do
  begin
    MastodonClient.listen_mentions do |mention|
      begin
        mention_count += 1
        puts "\n📨 멘션 ##{mention_count} 처리 중..."
        
        CommandParser.handle(mention)
        
      rescue => e
        error_count += 1
        puts "❌ 멘션 처리 오류 ##{error_count}: #{e.message}"
        puts "   사용자: @#{mention.account.acct rescue 'unknown'}"
        puts "   내용: #{mention.status.content.gsub(/<[^>]*>/, '').strip rescue 'unknown'}"
        puts "   #{e.backtrace.first(3).join("\n   ")}"
        
        # 심각한 오류 시 사용자에게 알림
        begin
          MastodonClient.reply(mention, "죄송합니다. 일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요. 🔧")
        rescue
          puts "   응답 전송도 실패했습니다"
        end
      end
    end
    
  rescue Interrupt
    puts "\n\n🛑 봇 종료 중..."
    uptime = Time.now - start_time
    hours = (uptime / 3600).to_i
    minutes = ((uptime % 3600) / 60).to_i
    
    puts "📊 운영 통계:"
    puts "   ⏱️  운영 시간: #{hours}시간 #{minutes}분"
    puts "   📨 처리한 멘션: #{mention_count}개"
    puts "   ❌ 오류 발생: #{error_count}개"
    puts "   📈 성공률: #{mention_count > 0 ? ((mention_count - error_count) * 100.0 / mention_count).round(1) : 0}%"
    
    puts "🏰 호그와트 마법용품점 문을 닫습니다. 안녕히 계세요!"
    break
    
  rescue => e
    error_count += 1
    puts "❌ 연결 오류 ##{error_count}: #{e.message}"
    puts "   #{e.class}: #{e.backtrace.first}"
    puts "🔄 15초 후 재연결 시도..."
    sleep 15
  end
  
  sleep 15
end
