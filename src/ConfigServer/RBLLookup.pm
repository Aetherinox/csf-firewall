###############################################################################
# Copyright (C) 2006-2025 Jonathan Michaelson
#
# https://github.com/waytotheweb/scripts
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <https://www.gnu.org/licenses>.
###############################################################################
## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
# start main
package ConfigServer::RBLLookup;

use strict;
use lib '/usr/local/csf/lib';
use Fcntl qw(:DEFAULT :flock);
use IPC::Open3;
use Net::IP;
use ConfigServer::Config;
use ConfigServer::CheckIP qw(checkip);

use Exporter qw(import);
our $VERSION     = 1.01;
our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(rbllookup);

my $config = ConfigServer::Config->loadconfig();
my %config = $config->config();
my $ipv4reg = ConfigServer::Config->ipv4reg;
my $ipv6reg = ConfigServer::Config->ipv6reg;

# end main
###############################################################################
# start rbllookup
sub rbllookup {
	my $ip = shift;
	my $rbl = shift;
	my %rblhits;
	my $netip;
	my $reversed_ip;
	my $timeout = 4;
	my $rblhit;
	my $rblhittxt;

	if (checkip(\$ip)) {
		eval {
			local $SIG{__DIE__} = undef;
			$netip = Net::IP->new($ip);
			$reversed_ip = $netip->reverse_ip();
		};
		
		if ($reversed_ip =~ /^(\S+)\.in-addr\.arpa/) {$reversed_ip = $1}
		if ($reversed_ip =~ /^(\S+)\s+(\S+)\.in-addr\.arpa/) {$reversed_ip = $2}
		if ($reversed_ip =~ /^(\S+)\.ip6\.arpa/) {$reversed_ip = $1}
		if ($reversed_ip =~ /^(\S+)\s+(\S+)\.ip6\.arpa/) {$reversed_ip = $2}

		if ($reversed_ip ne "") {
			my $lookup_ip = $reversed_ip.".".$rbl;

			my $cmdpid;
			eval {
				local $SIG{__DIE__} = undef;
				local $SIG{'ALRM'} = sub {die};
				alarm($timeout);
				my ($childin, $childout);
				$cmdpid = open3($childin, $childout, $childout, $config{HOST},"-t","A",$lookup_ip);
				close $childin;
				my @results = <$childout>;
				waitpid ($cmdpid, 0);
				chomp @results;
				if ($results[0] =~ /^${reversed_ip}.+ ($ipv4reg|$ipv6reg)$/) {$rblhit = $1}
				alarm(0);
			};
			alarm(0);
			if ($@) {$rblhit = "timeout"}
			if ($cmdpid =~ /\d+/ and $cmdpid > 1 and kill(0,$cmdpid)) {kill(9,$cmdpid)}

			if ($rblhit ne "") {
				if ($rblhit ne "timeout") {
					my $cmdpid;
					eval {
						local $SIG{__DIE__} = undef;
						local $SIG{'ALRM'} = sub {die};
						alarm($timeout);
						my ($childin, $childout);
						$cmdpid = open3($childin, $childout, $childout, $config{HOST},"-t","TXT",$lookup_ip);
						close $childin;
						my @results = <$childout>;
						waitpid ($cmdpid, 0);
						chomp @results;
						foreach my $line (@results) {
							if ($line =~ /^${reversed_ip}.+ "([^\"]+)"$/) {$rblhittxt .= "$1\n"}
						}
						alarm(0);
					};
					alarm(0);
					if ($cmdpid =~ /\d+/ and $cmdpid > 1 and kill(0,$cmdpid)) {kill(9,$cmdpid)}
				}
			}
		}
	}
	return ($rblhit,$rblhittxt);
}
# end rbllookup
###############################################################################

1;
