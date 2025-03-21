# frozen_string_literal: true

require "llm"
require "webmock/rspec"

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include Module.new {
    def request_fixture(file)
      path = File.join(fixtures, "requests", file)
      File.read(path).chomp
    end

    def response_fixture(file)
      path = File.join(fixtures, "responses", file)
      File.read(path).chomp
    end
    alias_method :fixture, :response_fixture

    def fixtures
      File.join(__dir__, "fixtures")
    end
  }
end
