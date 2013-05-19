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
  MRC_TEMPLATE = ERB.new(DATA.read)

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

# The MHonArc RC file template below is heavily based on the mlmmj-webarchiver
# perl program by Andreas Schneider.
__END__
<!-- Autogenerated MHonArc RC file, do not touch -->
<!-- ------------------------------------------------------------------	-->
<!-- TLEVELS:								-->
<!--									-->
<!-- TLEVELS defines the maximum number of nested listings in a thread	-->
<!-- index. Any threads that go over TLEVELS in depth are flattened to	-->
<!-- the value of TLEVELS. This resource is helpful in preventing huge	-->
<!-  indentations in deep threads which may cause text to be squished	-->
<!-- on the right-side of an HTML viewer.				-->
<!--									-->

<TLEVELS>
<%= tlevels %>
</TLEVELS>

<!-- ------------------------------------------------------------------	-->
<!-- MIMEALTPREFS:							-->
<!--									-->
<!-- With MIMEALTPREFS, you can tell MHonArc to use the text/plain	-->
<!-- entity (if it exists) over the text/html part with the following	-->
<!-- setting:								-->

<MIMEALTPREFS>
text/plain
text/html
</MIMEALTPREFS>

<!-- ------------------------------------------------------------------	-->
<!-- NOMAILTO:								-->
<!--									-->
<!-- If the MAILTO resource is on, mail addresses in message headers	-->
<!-- will be converted into mailto URL links as defined by the		-->
<!-- MAILTOURL resource.						-->
<!--									-->

<NOMAILTO>
</NOMAILTO>

<!-- ------------------------------------------------------------------	-->
<!-- MHPATTERN:								-->
<!--									-->
<!-- This is needed to have MHonArc grok maildir folders		-->
<!--									-->

<MHPATTERN>
^[^\.]
</MHPATTERN>

<!-- ------------------------------------------------------------------	-->
<!-- TIDXFNAME:								-->
<!--									-->
<!-- Name of the threads index file					-->
<!--									-->

<TIDXFNAME>
index.html
</TIDXFNAME>

<!-- ------------------------------------------------------------------	-->
<!-- IDXFNAME:								-->
<!--									-->
<!-- Name of the message index file					-->
<!--									-->

<IDXFNAME>
seq.html
</IDXFNAME>

<!-- ------------------------------------------------------------------	-->
<!-- MSGPREFIX:								-->
<!--									-->
<!-- Prefix for message files						-->
<!--									-->

<MSGPREFIX>
00
</MSGPREFIX>

<!-- ------------------------------------------------------------------	-->
<!-- NODOC:								-->
<!--									-->
<!-- Remove link to MHonArc documentation from bottom of pages		-->
<!--									-->

<NODOC>
</NODOC>

<SPAMMODE>

<!-- ------------------------------------------------------------------	-->
<!-- CHECKNOARCHIVE:							-->
<!--									-->
<!-- If CHECKNOARCHIVE is set, MHonArc will check each message for the	-->
<!-- "no archive" flag. If present, MHonArc will not add the message to	-->
<!-- the archive. MHonArc looks for one of the following in a message	-->
<!-- header to determine if message should not be archived:		-->
<!--									-->
<!--     X-no-archive: yes						-->
<!--     Restrict: no-external-archive					-->
<!--									-->
<!-- If either header field is present with the given value, and	-->
<!-- CHECKNOARCHIVE is set, MHonArc will skip the message.		-->
<!--									-->

<%= checknoarchive %>

<!-- ------------------------------------------------------------------	-->
<!-- FIELDORDER:							-->
<!--									-->
<!-- The FIELDORDER resource allows you to control the order the	-->
<!-- message header fields appear in the HTML output.			-->
<!--									-->
<!-- If -extra- is not specified, then only the fields listed will be	-->
<!-- displayed.								-->

<FIELDORDER>
subject
from
reply-to
date
to
cc
</FIELDORDER>

<!-- ------------------------------------------------------------------	-->
<!-- HTMLEXT:								-->
<!--									-->
<!-- HTMLEXT defines the extension for all HTML files generated by	-->
<!-- MHonArc.								-->
<!--									-->

<HTMLEXT>
html
</HTMLEXT>


<!-- ------------------------------------------------------------------ -->
<!-- MSGPGBEGIN, MSGPGEND:                                              -->
<!--                                                                    -->
<!-- MSGPGBEGIN defines the beginning markup of each message page. It   -->
<!-- allows you to redefine the opening HTML element, HEAD element,     -->
<!-- TITLE element, opening BODY element, etc.                          -->
<!--                                                                    -->
<!-- MSGPGEND defines the ending markup of each message page.           -->
<!--                                                                    -->

<MSGPGBEGIN>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="en">
<head>
 <title>$SUBJECTNA$</title>
 <link rel="stylesheet" type="text/css" media="screen" href="<%= stylefile %>">
</head>
<body>
 <div id="banner">
  <div id="header">
   <%= header %>
  </div>
  <div id="topnav">
   <a href="/">home</a>
   |
   <a href="..">month and year index</a>
   |
   <a href="$TIDXFNAME$#$MSGNUM$">thread index</a>
   |
   <a href="$IDXFNAME$#$MSGNUM$">date index</a>
   |
   <a href="<%= searchtarget %>">search</a>
  </div>
 </div>
 <div id="mailinglists">
  <div id="main">
</MSGPGBEGIN>

<MSGPGEND>
   <!-- FIXME <address>Archive administrator: postmaster@mlmmj-webarchiver</address> -->
  </div>
 </div>
</body>
</html>
</MSGPGEND>


<!-- ------------------------------------------------------------------ -->
<!-- IDXPGBEGIN, IDXPGEND:                                              -->
<!--                                                                    -->
<!-- The IDXPGBEGIN resource defines the beginning markup for the main  -->
<!-- index page. I.e. You can control the opening <HTML> tag, the HEAD  -->
<!-- element contents, the opening <BODY> tag, etc. Therefore, if you   -->
<!-- are not satisfied with the default behavior of how the TITLE       -->
<!-- resource is used, or have other needs that require control over    -->
<!-- the beginning markup, you can set the IDXPGBEGIN resource to what  -->
<!-- you desire.                                                        -->
<!--                                                                    -->
<!-- The IDXPGEND resource defines the end markup for the main index    -->
<!-- page.                                                              -->

<IDXPGBEGIN>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="en">
<head>
 <title>$IDXTITLE$</title>
 <link rel="stylesheet" type="text/css" media="screen" href="<%= stylefile %>">
</head>
<body>
</IDXPGBEGIN>

<IDXPGEND>
</body>
</html>
</IDXPGEND>


<!-- ------------------------------------------------------------------ -->
<!-- TIDXPGBEGIN, TIDXPGEND                                             -->
<!--                                                                    -->
<!-- The TIDXPGBEGIN resource defines the beginning markup for the      -->
<!-- thread index pages. I.e. You can control the opening <HTML> tag,   -->
<!-- the HEAD element contents, the opening <BODY> tag, etc. Therefore, -->
<!-- if you are not satisfied with the default behavior of how the      -->
<!-- TTITLE resource is used, or have other needs that require control  -->
<!-- on the beginning markup, you can set the TIDXPGBEGIN resource to   -->
<!-- what you desire.                                                   -->
<!--                                                                    -->
<!-- The TIDXPGEND resource defines the end markup for the thread index -->
<!-- pages.                                                             -->
<!--                                                                    -->

<TIDXPGBEGIN>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="en">
<head>
 <title>$TIDXTITLE$</title>
 <link rel="stylesheet" type="text/css" media="screen" href="<%= stylefile %>">
</head>
<body>
</TIDXPGBEGIN>

<TIDXPGEND>
</body>
</html>
</TIDXPGEND>

<!-- ------------------------------------------------------------------ -->
<!-- LISTBEGIN, LITEMPLATE, LISTEND:                                    -->
<!--                                                                    -->
<!-- The LISTBEGIN resource specifies the markup to begin the message   -->
<!-- list. This resource works in conjuction with LITEMPLATE and        -->
<!-- LISTEND resources to format the main index page(es).               -->
<!--                                                                    -->
<!-- The LITEMPLATE resource specifies the markup for an entry in the   -->
<!-- main index message list. This resource works in conjuction with    -->
<!-- LITEMPLATE and LISTEND resources to format the main index page(es) -->
<!-- http://www.mhonarc.org/MHonArc/doc/resources/litemplate.html       -->
<!--                                                                    -->
<!-- The LISTEND resource specifies the markup to end the message list  -->
<!-- in the main index. This resource works in conjuction with          -->
<!-- LISTBEGIN and LITEMPLATE resources to format the main index        -->
<!-- page(es).                                                          -->
<!--                                                                    -->

<LISTBEGIN>
 <div id="banner">
  <div id="header">
    <%= header %>
  </div>
  <div id="topnav">
   <a href="/">home</a>
   |
   <a href="..">month and year index</a>
   |
   <a href="$TIDXFNAME$">thread index</a>
   |
   <a href="$IDXFNAME$">date index</a>
   |
   <a href="<%= searchtarget %>">search</a>
  </div>
 </div>
 <div id="mailinglists">
  <div id="main">
<h1>Date Index</h1>
<div id="didx">
<ul>
</LISTBEGIN>

<LITEMPLATE>
<li><strong>$SUBJECT$</strong> $MSGLOCALDATE(CUR;%Y-%m-%d %H:%M)$
<ul>
<li><em>From</em>: $FROM$</li></ul>
</li>
</LITEMPLATE>

<LISTEND>
</ul>
</div>
   <!-- FIXME <address>Archive administrator: postmaster@mlmmj-webarchiver</address> -->
  </div>
 </div>
</LISTEND>


<!-- ------------------------------------------------------------------ -->
<!-- THEAD, TFOOT                                                       -->
<!--                                                                    -->
<!-- THEAD defines the header markup of thread index pages. It is also  -->
<!-- responsible for defining the opening markup for the thread         -->
<!-- listings.                                                          -->
<!--                                                                    -->
<!-- TFOOT defines the footer markup of thread index pages. It is also  -->
<!-- responsible for defining the closing markup for the thread listing -->
<!--                                                                    -->

<THEAD>
 <div id="banner">
  <div id="header">
    <%= header %>
  </div>
  <div id="topnav">
   <a href="/">home</a>
   |
   <a href="..">month and year index</a>
   |
   <a href="$TIDXFNAME$">thread index</a>
   |
   <a href="$IDXFNAME$">date index</a>
   |
   <a href="<%= searchtarget %>">search</a>
  </div>
 </div>
 <div id="mailinglists">
  <div id="main">
<h1>Thread Index</h1>
<div id="tidx">
<ul>
</THEAD>

<TFOOT>
</ul> 
</div>
   <address>Archive administrator: <%= archiveadmin %></address>
  </div>
 </div>
</TFOOT>
 
<!-- ------------------------------------------------------------------ -->
<!-- BOTLINKS                                                           -->
<!--                                                                    -->
<!-- BOTLINKS defines the markup for the links at the bottom of a       -->
<!-- message page. Its usage is analagous to the TOPLINKS resource, but -->
<!-- tends to be more verbose. However, you can define the resource     -->
<!-- anyway you desire.                                                 -->
<!--                                                                    -->

<BOTLINKS>
<!-- No BOTLINKS -->
</BOTLINKS>

<!-- ------------------------------------------------------------------ -->
<!-- FOLUPBEGIN, FOLUPLITXT and FOLUPEND                                -->
<!--                                                                    -->
<!-- FOLUPBEGIN defines the markup to start the explicit follow-up      -->
<!-- links after the message body on a message page.                    -->
<!--                                                                    -->
<!-- FOLUPLITXT defines the markup for an entry in the explicit         -->
<!-- follow-up links list after the message body on a message page.     -->
<!--                                                                    -->
<!-- FOLUPEND defines the ending markup for the the explicit follow-up  -->
<!-- links after the message body on a message page.                    -->
<!--                                                                    -->

<FOLUPBEGIN>
<div id="followups">
<table>
 <caption>Follow-Ups:</caption>
</FOLUPBEGIN>
 
<FOLUPLITXT>
 <tr><td>$SUBJECT$</td><td>$FROM$</td></tr>
</FOLUPLITXT>

<FOLUPEND>
</table>
</div>
</FOLUPEND>

<!-- ------------------------------------------------------------------ -->
<!-- REFSBEGIN, REFSLITXT and REFSEND                                   -->
<!--                                                                    -->
<!-- REFSBEGIN defines the markup to start the explicit reference links -->
<!-- after the message body on a message page.                          -->
<!--                                                                    -->
<!-- REFSLITXT defines the markup for an entry in the explicit          -->
<!-- reference links list after the message body on a message page.     -->
<!--                                                                    -->
<!-- REFSEND defines the ending markup for the the explicit reference   -->
<!-- links after the message body on a message page.                    -->
<!--                                                                    -->

<REFSBEGIN>
<div id="references">
<table>
 <caption>References:</caption>
</REFSBEGIN>
 
<REFSLITXT>
 <tr><td>$SUBJECT$</td><td>$FROM$</td></tr>
</REFSLITXT>

<REFSEND>
</table>
</div>
</REFSEND>

<!-- ------------------------------------------------------------------ -->
<!-- SUBJECTHEADER:                                                     -->
<!--                                                                    -->
<!-- SUBJECTHEADER defines the markup for the main subject line above   -->
<!-- the message header of message pages.                               -->
<!--                                                                    -->
 
<SUBJECTHEADER>
<h1>$SUBJECTNA$</h1>
<div id="toplinks">
 <div id="threadtoplinks">
  $BUTTON(TPREV)$ | $BUTTON(TNEXT)$
 </div>
 <div id="datetoplinks">
  $BUTTON(PREV)$ | $BUTTON(NEXT)$
 </div>
</div>
</SUBJECTHEADER>

<!-- Thread element -->
<!-- Add dates to every line in the thread view -->
<TLiTxt>
<li><strong>$SUBJECT$</strong>,
<em>$FROMNAME$</em>, $MSGLOCALDATE(CUR;%Y-%m-%d %H:%M)$
</TLiTxt>

<TTopBegin>
<li><strong>$SUBJECT$</strong>,
<em>$FROMNAME$</em>, $MSGLOCALDATE(CUR;%Y-%m-%d %H:%M)$
</TTopBegin>

<TSingleTxt>
<li><strong>$SUBJECT$</strong>,
<em>$FROMNAME$</em>, $MSGLOCALDATE(CUR;%d.%m %H:%M)$
</TSingleTxt>
