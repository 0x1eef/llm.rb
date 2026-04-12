# frozen_string_literal: true

require_relative "../bench/runner"
Bench::Runner.load!(File.expand_path("..", __dir__))

desc "List available benchmarks"
task "benchmark:list" do
  puts Bench::Workload.names
end

desc "Run a benchmark for the current checkout or a target commit"
task :benchmark, [:name, :commit] do |_, args|
  Bench::Runner.run(
    name: args[:name] || "stream_parser",
    root: File.expand_path("..", __dir__),
    commit: args[:commit]
  )
end

task :becnhmark, [:name, :commit] do |_, args|
  Rake::Task[:benchmark].invoke(args[:name], args[:commit])
end
