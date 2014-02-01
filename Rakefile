# -*- ruby -*-
require "rake/clean"
require "rubygems/package_task"
require "rdoc/task"

file "extra/man/mlmmj-rbarchiver.1" => "extra/man/mlmmj-rbarchiver.1.ronn" do
  cd "extra/man" do
    sh "ronn -r --manual='General Commands Manual' --organization='mlmmj' mlmmj-rbarchiver.1.ronn"
  end
end

load "mlmmj-rbarchiver.gemspec"
Gem::PackageTask.new(GEMSPEC).define

RDoc::Task.new do |rt|
  rt.rdoc_files.include("README.md", "COPYING", "lib/**/*.rb")
  rt.main = "README.md"
end

desc "Generate the manpages"
task :man => "extra/man/mlmmj-rbarchiver.1"
