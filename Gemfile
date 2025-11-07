# ============================================
# Gemfile for Mastodon Bots (Shop / Professor / Rumor)
# ============================================
source 'https://rubygems.org'
ruby '3.2.3'

# --- Core dependencies ---
gem 'dotenv', '~> 3.1'
gem 'json', '~> 2.7'
gem 'activesupport', '~> 7.1', require: 'active_support/all'

# --- Mastodon API ---
# 최신 mastodon-api gem은 Faraday 2.x 호환 이슈가 있어 버전 고정이 안정적
gem 'mastodon-api', '~> 1.2', require: 'mastodon'

# --- Google Sheets Integration ---
gem 'googleauth', '~> 1.9'
gem 'google-apis-sheets_v4', '~> 0.26'

# --- HTTP / Network ---
gem 'faraday', '~> 2.7'
gem 'nokogiri', '~> 1.15'

# --- Utility (optional but recommended) ---
gem 'time', '~> 0.2'   # Time formatting consistency for Ruby 3.x
