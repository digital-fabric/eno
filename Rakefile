# frozen_string_literal: true

task :default => [:doc, :test]
task :doc => :yard
task :test do
  exec 'ruby test/run.rb'
end

require 'yard'
# YARD_FILES = FileList['ext/extralite/extralite.c', 'lib/extralite.rb', 'lib/sequel/adapters/extralite.rb']

YARD::Rake::YardocTask.new do |t|
  # t.files   = YARD_FILES
  t.options = %w(-o doc --readme README.md)
end

task :release do
  require_relative './lib/eno/version'
  version = Eno::VERSION
  
  puts 'Building eno...'
  `gem build eno.gemspec`

  puts "Pushing eno #{version}..."
  `gem push eno-#{version}.gem`

  puts "Cleaning up..."
  `rm *.gem`
end
