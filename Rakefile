# -*- ruby -*-

require 'rubygems'
require 'hoe'
require 'spec/rake/spectask'
require './lib/jig.rb'

Hoe.new('jig', Jig::VERSION) do |p|
  p.rubyforge_name = 'jig'
  p.summary = 'a data structure that supports construction and manipulation of strings with hierarchical structure'
  p.description = p.paragraphs_of('README.txt', 2..5).join("\n\n")
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/)[1..-1]
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
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
