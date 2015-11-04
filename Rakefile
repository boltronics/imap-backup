#!/usr/bin/env rake
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
Dir.glob('lib/tasks/*.rake').each { |r| load r}

task :default => :spec

RSpec::Core::RakeTask.new do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

if RUBY_VERSION < '1.9'
  RSpec::Core::RakeTask.new('spec:coverage') do |t|
    t.pattern   = 'spec/**/*_spec.rb'
    t.rcov      = true
    t.rcov_opts = ['--exclude', 'spec/,/gems/,vendor/']
  end
end
