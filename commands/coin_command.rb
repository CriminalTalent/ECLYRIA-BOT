# ============================================
# commands/coin_command.rb
# ============================================
# encoding: UTF-8
class CoinCommand
  def self.run(_mastodon_client, _notification)
    ["앞면", "뒷면"].sample
  end
end
