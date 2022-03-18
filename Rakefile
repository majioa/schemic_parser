#!/usr/bin/env ruby

require "cucumber/rake/task"
require "bundler/gem_tasks"

Cucumber::Rake::Task.new do |t|
   t.cucumber_opts = %w{--format progress}
end

task :default => :cucumber
