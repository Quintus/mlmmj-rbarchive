# -*- coding: utf-8 -*-
# This file is part of mlmmj-rbarchive.
#
# mlmmj-rbarchive makes a web archive from your mlmmj-archive.
# Copyright (C) 2013  Marvin Gülker
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "tempfile"
require "fileutils"
require "pathname"
require "erb"
require "mail"

begin
  require "rb-inotify"
rescue LoadError
end

# Namespace for this library.
module MlmmjArchiver

end

require_relative "mlmmj-archiver/version"
require_relative "mlmmj-archiver/archiver"
