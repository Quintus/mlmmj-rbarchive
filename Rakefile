# -*- ruby -*-
require "rake/clean"
require "rubygems/package_task"
require "rdoc/task"

file "man/mlmmj-rbarchiver.1" => "extra/man-source/mlmmj-rbarchiver.1.ronn" do
  sh "ronn -r --manual='General Commands Manual' --organization='mlmmj' extra/man-source/mlmmj-rbarchiver.1.ronn"
  mv "extra/man-source/mlmmj-rbarchiver.1", "man"
end

load "mlmmj-rbarchiver.gemspec"
Gem::PackageTask.new(GEMSPEC).define

RDoc::Task.new do |rt|
  rt.rdoc_files.include("README.md", "COPYING", "lib/**/*.rb")
  rt.main = "README.md"
end

desc "Generate the manpages"
task :man => "man/mlmmj-rbarchiver.1"
