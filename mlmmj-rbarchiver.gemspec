# -*- coding: utf-8 -*-
load "lib/mlmmj-archiver/version.rb"

GEMSPEC = Gem::Specification.new do |s|
  s.name = "mlmmj-rbarchiver"
  s.version = MlmmjArchiver::VERSION.dup
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = ">= 2.0.0"

  s.author = "Marvin Gülker"
  s.email = "quintus@quintilianus.eu"
  s.homepage = "http://quintus.github.io/mlmmj-rbarchiver"
  s.license = "GPL"
  s.summary = "HTML archive generator for mlmmj mailinglists."
  s.description =<<-EOF
mlmmj-rbarchiver is a wrapper program around mhonarc (http://mhonarc.org)
that allows you to generate a nice HTML email archive for you mlmmj-managed
mailinglists. The resulting directory is split up by year and month, so
it is easily navigatable.

This gem contains both a program intended to be run by cron(8) for
processing your mailinglist(s) and a library that can be used to
archive mailinglists programmatically.
  EOF

  s.files = Dir["bin/*"] +
    Dir["data/*"] +
    ["extra/archive.css", "extra/rbarchiver.conf", "extra/man/mlmmj-rbarchiver.1"] +
    Dir["lib/**/*.rb"] +
    ["README.md", "COPYING"]
  s.executables = ["mlmmj-rbarchiver"]

  s.add_runtime_dependency("mail", "~> 2.5.0")
  s.add_runtime_dependency("paint", "~> 0.8.0")
  s.add_development_dependency("ronn", "~> 0.7.0")
  s.requirements << "mhonarc (http://www.mhonarc.org)" << "mlmmj (http://www.mlmmj.org)"

  s.extra_rdoc_files = ["README.md", "COPYING"]
  s.rdoc_options << "-m" << "README.md"
end
