# frozen_string_literal: true

if url = ENV["REDIS_URL"]
  require "sidekiq"
  require "sidekiq/web"

  Sidekiq.configure_client do |config|
    config.redis = {url:}
  end

  Sidekiq.configure_server do |config|
    config.redis = {url:}
  end
end
