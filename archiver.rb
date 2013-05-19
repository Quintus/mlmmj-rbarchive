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

# Archiver class. Point it to a target directory you want to place your web
# archive under, add some MLs to process and start the process via #archive!.
# You have some influence over the used (temporary) MHonArc RC file by specifying
# some arguments to ::new.
class Archiver

  # Path relative to ML root containing the mails
  ARCHIVE_DIR  = "archive"
  # Path relative to ML root containing the file that
  # requests the web archiving.
  CONTROL_FILE = "control/webarchive".freeze
  # Path to the +mhonarc+ executable.
  MHONARC = "/usr/bin/mhonarc"
  # Default values for the MHonArc RC file.
  MRC_DEFAULTS = {
    :header => "<p>ML archive</p>",
    :tlevels => 8,
    :archiveadmin => "postmaster@example.org",
    :checknoarchive => true,
    :searchtarget => "/search",
    :stylefile => "/archive.css"
  }.freeze
  # Template for generating the temporary MHonArc RC file.
  MRC_TEMPLATE = ERB.new(File.read(File.join(File.expand_path(File.dirname(__FILE__)), "mhonarc-rc.erb")))

  # Create a new Archiver that stores its mails below
  # the given +target+ directory. +rc_args+ allows
  # the customization of the used MHonArc RC file.
  # It is a hash that takes the following arguments
  # (the values in parentheses denote the default values)
  # [header ("<p>ML archive</p>")]
  #   HTML header to prepend to every page. $IDXTITLE$ is replaced
  #   by the title of the respective index.
  # [tlevels (8)]
  #   Number of levels to nest threads before flattening.
  # [archiveadmin (postmaster@example.org)]
  #   E-Mail address of the archive administrator.
  # [checknoarchive (true)]
  #  If set, adds <CHECKNOARCHIVE> to the rc file. Otherwise
  #  adds <NOCHECKNOARCHIVE>.
  # [searchtarget ("/search")]
  #   Target for the "search" link.
  # [stylefile ("/archive.css")]
  #   CSS style file to reference from the outputted HTML pages.
  def initialize(target, rc_args = {})
    @target_dir   = Pathname.new(target).expand_path
    @mailinglists = []
    @mutex        = Mutex.new
    @rc_args      = MRC_DEFAULTS.merge(rc_args)
    @debug        = false
  end

  # Enable/disable debugging output.
  def debug_mode=(val)
    @debug = val
  end

  # True if debugging output is enabled, see #debug_mode=.
  def debug_mode?
    @debug
  end

  # Add a mlmmj ML directory to process.
  def add_ml(path)
    dir = Pathname.new(path).expand_path
    debug("Adding ML directory: #{dir}")

    @mailinglists.push(dir)
  end

  # Like #add_ml, but returns +self+ for method chaining.
  def <<(path)
    add_ml(path)
    self
  end

  # Process all the mails in all the directories.
  def archive!
    @mutex.synchronize do
      rcpath = generate_rcfile

      @mailinglists.each do |path|
        control_file = path + CONTROL_FILE
        next unless control_file.file?

        process_ml(path + ARCHIVE_DIR, @target_dir + path.basename, rcpath)
      end
    end
  end

  private
  # [header ("<p>ML archive</p>")]
  #   HTML header to prepend to every page. $IDXTITLE$ is replaced
  #   by the title of the respective index.
  # [tlevels (8)]
  #   Number of levels to nest threads before flattening.
  # [archiveadmin (postmaster@example.org)]
  #   E-Mail address of the archive administrator.
  # [checknoarchive (true)]
  #  If set, adds <CHECKNOARCHIVE> to the rc file. Otherwise
  #  adds <NOCHECKNOARCHIVE>.
  # [searchtarget ("/search")]
  #   Target for the "search" link.
  # [stylefile ("/archive.css")]
  # Generate an RC file for MHonArc and return the path to it.
  def generate_rcfile
    tempfile = Tempfile.new("archive-mhonarc")
    rcpath   = tempfile.path
    at_exit{File.delete(rcpath)}

    debug "Generating MhonArc RC file at #{rcpath}"

    header         = @rc_args[:headers]
    tlevels        = @rc_args[:tlevels]
    archiveadmin   = @rc_args[:archiveadmin]
    checknoarchive = @rc_args[:checknoarchive] ? "<CHECKNOARCHIVE>" : "<CHECKNOARCHIVE>\n<NOCHECKNOARCHIVE>"
    searchtarget   = @rc_args[:searchtarget]
    stylefile      = @rc_args[:stylefile]

    mrc = MRC_TEMPLATE.result(binding)
    tempfile.write(mrc)

    rcpath
  end

  # Process all mails in +mail_dir+ and output an HTML
  # directory structure in +archive_dir+. +rcpath+ is the
  # path to an MHonArc RC file to use.
  def process_ml(mail_dir, archive_dir, rcpath)
    debug "Processing ML directory #{mail_dir} ===> #{archive_dir}"

    # Create the target directory
    archive_dir.mkpath unless archive_dir.directory?

    # Prepare the mails
    result     = collect_messages(mail_dir)
    target_dir = split_messages_into_month_dirs(result)

    # Let mhonarc process them
    target_dir.each_child do |yeardir|
      yeardir.each_child do |monthdir|
        mhonarc(monthdir, archive_dir + sprintf("%04d/%02d", yeardir.basename.to_s.to_i, monthdir.basename.to_s.to_i), rcpath)
      end
    end
  end

  # Collect the mails in the given directory in a nested hash like this:
  #   {year1 => {month1 => [...], month2 => [...]}, year2 => {...}}
  def collect_messages(mail_dir)
    hsh = Hash.new{|hsh, k| hsh[k] = Hash.new{|hsh2, k2| hsh2[k2] = []}}

    debug "Collecting messages in #{mail_dir}"

    mail_dir.each_child do |path|
      next unless path.file?

      mail = Mail.read(path)
      hsh[mail.date.year][mail.date.month] << path
    end

    hsh
  end

  # Takes the result of #collect_messages and writes the messages
  # out to a directory structure like this:
  #   2013/
  #     1/
  #       msg1
  #     2/
  #       msg1
  #       msg2
  #   ...
  def split_messages_into_month_dirs(hsh)
    tmpdir = Pathname.new(Dir.mktmpdir("archive"))
    at_exit{tmpdir.rmtree}

    debug "Splitting into year-month directories"

    hsh.each_pair do |year, months|
      year_dir = tmpdir + year.to_s
      year_dir.mkdir

      months.each do |month, messages|
        month_dir = year_dir + month.to_s
        month_dir.mkdir

        messages.each do |msgpath|
          FileUtils.cp(msgpath, month_dir)
        end
      end
    end

    tmpdir
  end

  # Run mhonarc over the +source+ directory and place the
  # results in +rel_target+ which is a path relative to
  # the +target+ passed to ::new. +rcpath+ is the path to
  # an MHonArc RC file to use.
  def mhonarc(source, rel_target, rcpath)
    target = @target_dir + rel_target
    target.mkpath unless target.directory?

    cmd = "#{MHONARC} -rcfile '#{rcpath}' -outdir '#{target}' -add '#{source}'"
    debug "Executing: #{cmd}"
    system(cmd)
  end

  # Prints +str+ onto stdout via #puts if #debug_mode?.
  def debug(str)
    puts str if debug_mode?
  end

end

if __FILE__ == $0
  a = Archiver.new("output",
                   header: "<p>My Test ML archives</p>",
                   searchtarget: "../../search",
                   stylefile: "../../../archive.css"
                   )
  a.debug_mode = true
  a << "test-ml"
  a.archive!
end
