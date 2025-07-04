# bot/mastodon_client.rb
require 'mastodon'
require 'dotenv'

Dotenv.load(File.expand_path('../.env', __dir__))

puts "🧪 DEBUG ENV:"
puts "BASE_URL: #{ENV['MASTODON_BASE_URL'].inspect}"
puts "TOKEN: #{ENV['MASTODON_TOKEN']&.slice(0, 10)}..."

module MastodonClient
  def self.client
    @client ||= Mastodon::REST::Client.new(
      base_url: ENV['MASTODON_BASE_URL'],
      bearer_token: ENV['MASTODON_TOKEN']
    )
  end

  def self.listen_mentions
    mentions = client.notifications.select { |n| n.type == 'mention' }
    mentions.each { |mention| yield mention }
  end

  def self.reply(mention, message)
    acct = mention.account.acct
    client.create_status("@#{acct} #{message}", in_reply_to_id: mention.status.id)
  end
end
