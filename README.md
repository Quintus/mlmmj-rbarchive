mlmmj-rbarchive
===============

Small Ruby program for properly archiving a mlmmj-managed
mailinglist.

Requirements
------------

* [Ruby](http://ruby-lang.org) 1.9.3+
* [MHonArc](http://mhonarc.org)

Usage
-----

This is currently just a library, so no fancy commandline options. You
can incorporate it in your program and provide commandline options
yourself if you want.

Create a new archiver:

~~~~~~~~~~~~~~~~~~~~~~~ ruby
require "archiver"
# or
require_relative "./archiver"

a = Archiver.new("mailcache", # Cache directory for mails sorted by month for easier processing
                 "output", # Target directory for all the messages
                 header: "<p>My ML archive</p>", # HTML to display at the top
                 searchtarget: "/my-search", # Link target for the "search" link
                 stylefile: "/stylesheets/archive.css") # CSS stylesheet to reference from the HTML files
~~~~~~~~~~~~~~~~~~~~~~~

This will create an archiver that places the resulting HTML files
below a directory `output` below the current directory. To actually
add an mlmmj ML do the following:

~~~~~~~~~~~~~~~~~~~~~~~ ruby
a << "/var/spool/mlmmj/my-ml
~~~~~~~~~~~~~~~~~~~~~~~

Note you don’t have to specify the "archive" directory below `my-ml`
manually. Next, create an empty file `my-ml/control/webarchive`. This
signals mlmmj-rbarchive that you really want this ML to be processed;
without this file, the directory is skipped even though you have added
it to the archiver.

You can now preprocess the mails into a hierarchical year-month
directory structure so that before the messages get passed to MHonArc
they are already nicely sorted:

~~~~~~~~~~~~~~~~~~~~~~~ ruby
a.preprocess_mlmmj_mails!
~~~~~~~~~~~~~~~~~~~~~~~

Finally, start the conversion process:

~~~~~~~~~~~~~~~~~~~~~~~ ruby
a.archive!
~~~~~~~~~~~~~~~~~~~~~~~

You can run this periodically if you want, already processed
messages will not be processed again, only new messages are
added to the web archive.

I want more output!
-------------------

Do this before you start adding mailinglists to the
archiver:

~~~~~~~~~~~~~~~~~~~~~~~ ruby
a.debug_mode = true
~~~~~~~~~~~~~~~~~~~~~~~

Docs?
-----

To get a more thorough documentation, run this:

~~~~~~~~~~~~~~~~~~~~~~~
$ rdoc archiver.rb
~~~~~~~~~~~~~~~~~~~~~~~

You will then end up with some more detailed docs in a directory `doc`
below the current working directory.

License
-------

mlmmj-rbarchive makes a web archive from your mlmmj-archive.
Copyright (C) 2013  Marvin Gülker

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

The MHonArc template file is based on mlmmj-archiver by Andreas Schneider,
which can be found here: http://git.cryptomilk.org/projects/mlmmj-webarchiver.git.
It is GPL-copyrighted free software, hence this is also GPL’ed free software.
