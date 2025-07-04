require 'dotenv'
Dotenv.load(File.expand_path('../.env', __dir__))
require_relative 'mastodon_client'
require_relative 'command_parser'

puts "✅ 호그와트 마법용품점 봇 기동 완료!"
puts "📡 BASE_URL: #{ENV['MASTODON_BASE_URL']}"
puts "🔐 TOKEN 시작: #{ENV['MASTODON_TOKEN'][0..10]}..." if ENV['MASTODON_TOKEN']
puts "🏪 CSV 파일 확인 중..."

# CSV 파일들 확인
csv_files = {
  'items.csv' => '아이템 데이터',
  'users.csv' => '사용자 데이터', 
  'responses.csv' => '응답 데이터'
}

csv_files.each do |file, desc|
  if File.exist?(file)
    puts "   ✓ #{desc}: #{file}"
  else
    puts "   ⚠️  #{desc}: #{file} (파일 없음)"
  end
end

puts "🚀 멘션 수신 대기 중..."

loop do
  begin
    MastodonClient.listen_mentions do |mention|
      begin
        CommandParser.handle(mention)
      rescue => e
        puts "❌ 멘션 처리 오류: #{e.message}"
        puts e.backtrace.first(3).join("\n")
      end
    end
  rescue => e
    puts "❌ 연결 오류: #{e.message}"
    puts "🔄 15초 후 재연결 시도..."
  end
  
  sleep 15
end
