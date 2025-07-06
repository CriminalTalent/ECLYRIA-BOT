require 'mastodon'
require 'json'
require 'dotenv'
Dotenv.load('.env')

module MastodonClient
  BASE_URL = ENV['MASTODON_BASE_URL']
  TOKEN = ENV['MASTODON_TOKEN']

  def self.client
    @client ||= Mastodon::REST::Client.new(base_url: BASE_URL, bearer_token: TOKEN)
  end

  def self.test_connection
    begin
      me = client.verify_credentials
      puts "   마스토돈 계정 확인 완료: @#{me.acct}"
      true
    rescue => e
      puts "   마스토돈 연결 실패: #{e.message}"
      false
    end
  end

  def self.reply(to_status, message)
    client.create_status("@#{to_status.account.acct} #{message}", {
      in_reply_to_id: to_status.id,
      visibility: 'public'
    })
  end

  def self.stream_mentions(since_id = nil)
    loop do
      begin
        options = { limit: 10 }
        options[:since_id] = since_id if since_id
        mentions = client.notifications(options).select { |n| n.type == 'mention' }

        mentions.each do |mention|
          yield mention if block_given?
          since_id = [since_id.to_i, mention.id.to_i].max.to_s
        end
        sleep 10
      rescue => e
        puts "[에러] 멘션 수신 실패: #{e.message}"
        sleep 30
      end
    end
  end
end
