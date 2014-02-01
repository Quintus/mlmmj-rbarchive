mlmmj-rbarchive
===============

Small Ruby program for properly archiving a mlmmj-managed
mailinglist.

Requirements
------------

* [Ruby](http://ruby-lang.org) 1.9.3+
* [MHonArc](http://mhonarc.org)
* The `mail` gem
* The `paint` gem

Usage
-----

You can choose between using mlmmj-rbarchive as a library or as a
commandline program.

### Commandline ###

The `mlmmj-rbarchiver` program allows to process any given mlmmj ML
directory directly into a browsable HTML mailinglist archive. It is
intended to be run regularly from Cron so it is able to cumulatively
add any new messages delivered to your ML to the HTML archive.

An example call may look like this:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ mlmmj-rbarchiver -i /var/spool/mlmmj/mymailinglist -o /var/www/mlarchive
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This will take all mails found in
`/var/spool/mlmmj/mymailinglist/archive` and output them to
`/var/www/mlarchive/mymailinglist` in a month-year-ordered
format. Note you still have to provide a toplevel `index.html`
yourself.

The program features a good number of commandline options; run it with
`-h` to get a summary. For styling you might especially be interested
in the `-s` option. You might also use a configuration file with `-c`
that allows you to specify some options once and for all; see the
`rbarchiver.conf` file in the `extra/` directory for an example of how
it could look like.

### Library ###

To use it as a library, first create a new archiver:

~~~~~~~~~~~~~~~~~~~~~~~ ruby
require "mlmmj-archiver"

a = MlmmjArchiver::Archiver.new("output", # Target directory for all the messages
                                header: "<p>My ML archive</p>", # HTML to display at the top
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

After having prepared all existing mail, you can now watch the ML’s
+archive+ directories for changes rather than running the
Archiver#preprocess_mlmmj_mails! method periodically:

~~~~~~~~~~~~~~~~~~~~~~~ ruby
a.watch_mlmmj_mails!
~~~~~~~~~~~~~~~~~~~~~~~

Note that the above only works if you have the `rb-inotify` gem
installed. Finally, start the conversion process:

~~~~~~~~~~~~~~~~~~~~~~~ ruby
a.archive!
~~~~~~~~~~~~~~~~~~~~~~~

You can run this periodically if you want, already processed
messages will not be processed again, only new messages are
added to the web archive.

#### I want more output! ####

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
Copyright (C) 2013-2014  Marvin Gülker

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
