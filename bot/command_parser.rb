# bot/command_parser.rb
require_relative 'mastodon_client'

module CommandParser
  def self.handle(mention)
    text = mention.status.content.gsub(/<[^>]*>/, '') # HTML 제거
    acct = mention.account.acct

    if text.include?('[출석]')
      MastodonClient.reply(mention, "📋 #{acct}님, 출석 확인했습니다! 좋은 하루 보내세요.")
    else
      MastodonClient.reply(mention, "❓ #{acct}님, 지원되지 않는 명령입니다.")
    end
  end
end
