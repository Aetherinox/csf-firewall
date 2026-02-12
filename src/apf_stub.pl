#!/usr/bin/perl
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
#   @updated            02.12.2026
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
# #

use strict;
use warnings;

my @cmd = @ARGV;

if ($cmd[0] eq "-a" or $cmd[0] eq "--allow") {
	$cmd[0] = "--add";
	system("csf",@cmd);
}
elsif ($cmd[0] eq "-d" or $cmd[0] eq "--deny") {
	$cmd[0] = "--deny";
	system("csf",@cmd);
}
elsif ($cmd[0] eq "-u" or $cmd[0] eq "--remove" or $cmd[0] eq "--unban") {
	$cmd[1] =~ s/\^|\$//g;
	$cmd[0] = "--addrm";
	system("csf",@cmd);
	$cmd[0] = "--denyrm";
	system("csf",@cmd);
	$cmd[0] = "--temprm";
	system("csf",@cmd);
}
elsif ($cmd[0] eq "-s" or $cmd[0] eq "--start") {
	$cmd[0] = "--start";
	system("csf",@cmd);
}
elsif ($cmd[0] eq "-f" or $cmd[0] eq "--flush" or $cmd[0] eq "--stop") {
	$cmd[0] = "--stop";
	system("csf",@cmd);
}
elsif ($cmd[0] eq "-r" or $cmd[0] eq "--restart") {
	$cmd[0] = "--restart";
	system("csf",@cmd);
}
elsif ($cmd[0] eq "-l" or $cmd[0] eq "--list") {
	$cmd[0] = "--status";
	system("csf",@cmd);
} else {
	print "Unknown command, please use csf directly instead of this apf stub\n";
}

exit;
