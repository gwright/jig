# -*- ruby -*-

require 'rubygems'
require 'hoe'
require 'spec/rake/spectask'
require './lib/jig.rb'

Hoe.new('jig', Jig::VERSION) do |p|
  p.rubyforge_name = 'jig'
  p.summary = 'A Jig is a data structure that supports construction and manipulation of strings with hierarchical structure.'
  p.description = p.paragraphs_of('README.txt', 2..5).join("\n\n")
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.author = "Gary R. Wright"
  p.email = "gwright@rubyforge.org"
  p.url = "http://jig.rubyforge.org"
end

task :spec do
	sh "spec -f s #{FileList['test/*spec.rb']}"
end

desc "Run rcov with rSpec"
Spec::Rake::SpecTask.new('rcov-rspec') do |t|
  t.spec_files = FileList['test/*spec.rb']
  t.rcov = true
end

# RCOV command, run as though from the commandline.  Amend as required or perhaps move to config/environment.rb?
RCOV = "rcov"

desc "generate a unit test coverage report in coverage/unit; see coverage/unit/index.html afterwards"
task :rcov do
  tests = FileList['test/test_*.rb']
  sh "#{RCOV} -Ilib #{tests}"
end



# vim: syntax=Ruby
