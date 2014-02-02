# -*- ruby -*-
require "rake/clean"
require "rubygems/package_task"
require "rdoc/task"

file "man/mlmmj-rbarchiver.1" => "extra/man-source/mlmmj-rbarchiver.1.ronn" do
  sh "ronn -r --manual='General Commands Manual' --organization='mlmmj' extra/man-source/mlmmj-rbarchiver.1.ronn"
  mv "extra/man-source/mlmmj-rbarchiver.1", "man"
end

file "html/man/mlmmj-rbarchiver.1.html" => "extra/man-source/mlmmj-rbarchiver.1.ronn" do |t|
  mkdir_p "html/man" unless File.directory?("html/man")

  source = t.prerequisites.first

  sh "ronn -5 --manual='General Commands Manual' --organization='mlmmj' #{source}"
  mv source.sub(/.ronn$/, ".html"), t.name

  # Fix invalid charset
  str = File.read(t.name)
  str.gsub!("value='text/html;charset=utf8'", "content='text/html; charset=UTF-8'")
  open(t.name, "w"){|f| f.write(str)}
end

load "mlmmj-rbarchiver.gemspec"
Gem::PackageTask.new(GEMSPEC).define

RDoc::Task.new do |rt|
  rt.rdoc_files.include("README.md", "COPYING", "lib/**/*.rb")
  rt.main = "README.md"
end

desc "Generate the HTML docs"
task :docs => [:rdoc, "html/man/mlmmj-rbarchiver.1.html"]

desc "Generate the manpages"
task :man => ["man/mlmmj-rbarchiver.1"]
