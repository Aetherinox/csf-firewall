# #
#   @app                ConfigServer Security & Firewall (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.dev
#   @docs               https://docs.configserver.dev
#   @download           https://download.configserver.dev
#   @repo               https://github.com/Aetherinox/csf-firewall
#   @copyright          Copyright (C) 2025-2026 Aetherinox
#                       Copyright (C) 2006-2025 Jonathan Michaelson
#                       Copyright (C) 2006-2025 Way to the Web Ltd.
#   @license            GPLv3
#   @updated            09.27.2026
#   @linter             <ConfigServer::Linter>1.01:1:1:0:1:1:1:1:1
#   
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or (at
#   your option) any later version.
#   
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#   General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, see <https://www.gnu.org/licenses>.
#   
#   @commands       Load the Secrets module directly:
#                       perl -I. ConfigServer/Secrets.pm
#
#                   Check the Secrets module for syntax errors:
#                       perl -I. -c ConfigServer/Secrets.pm
#
#                   Display perl module docs:
#                       perldoc -T ConfigServer/Secrets.pm
#
#                   Run Logger test suite, including Secrets tests:
#                       prove -I. -v tests/Logger.t
#
#                   Show absolute path to loaded Secrets module:
#                       sudo perl -I. -MConfigServer::Secrets -MCwd -e 'print Cwd::abs_path($INC{q{ConfigServer/Secrets.pm}}), qq{\n};'
#   
#                   Show which Secrets module Logger loaded, check
#                   sub exists:
#                       sudo perl -I. -MConfigServer::Logger -e 'print $INC{q{ConfigServer/Secrets.pm}}, qq{\n}; print ConfigServer::Secrets->can(q{redact_obj_field}) ? qq{FOUND\n} : qq{MISSING\n};'
#
#                   Load local Secrets module before Logger, test
#                   /var/log is trusted dir:
#                       sudo perl -I. -MConfigServer::Secrets -MConfigServer::Logger -e 'my $trusted = ConfigServer::Logger::_logger_directory_is_trusted(q{/var/log}); print defined($trusted) ? $trusted : q{undef}, qq{\n};'
# #

# #
#   Declare › Package
# #

package ConfigServer::Secrets;

# #
#   Declare › Use
# #

use strict;
use warnings;
use Carp ();
use Encode ();
use Errno ();
use Exporter qw( import );
use Fcntl ();
use File::Spec ();
use POSIX ();
use utf8 ();