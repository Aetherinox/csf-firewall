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
package ConfigServer::GetIPs;

use strict;
use lib '/usr/local/csf/lib';
use Carp;
use Socket;
use IPC::Open3;
use ConfigServer::Config;

use Exporter qw(import);
our $VERSION     = 1.03;
our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(getips);

my $config = ConfigServer::Config->loadconfig();
my %config = $config->config();
my $ipv4reg = ConfigServer::Config->ipv4reg;
my $ipv6reg = ConfigServer::Config->ipv6reg;

# end main
###############################################################################
# start getips
sub getips {
	my $hostname = shift;
	my @ips;

	if (-e $config{HOST} and -x $config{HOST}) {
		my $cmdpid;
		eval {
			local $SIG{__DIE__} = undef;
			local $SIG{'ALRM'} = sub {die};
			alarm(10);
			my ($childin, $childout);
			$cmdpid = open3($childin, $childout, $childout, $config{HOST},"-W","5",$hostname);
			close $childin;
			my @results = <$childout>;
			waitpid ($cmdpid, 0);
			chomp @results;

			foreach my $line (@results) {
				if ($line =~ /($ipv4reg|$ipv6reg)/) {push @ips, $1}
			}
			alarm(0);
		};
		alarm(0);
		if ($cmdpid =~ /\d+/ and $cmdpid > 1 and kill(0,$cmdpid)) {kill(9,$cmdpid)}
	} else {
		local $SIG{__DIE__} = undef;
		eval ('use Socket6;');
		if ($@) {
			my @iplist;
			my (undef, undef, undef, undef, @addrs) = gethostbyname($hostname);
			foreach (@addrs) {push(@iplist,join(".",unpack("C4", $_)))}
			push @ips,$_ foreach(@iplist);
		} else {
			eval ('
				use Socket6;
				my @res = getaddrinfo($hostname, undef, AF_UNSPEC, SOCK_STREAM);
				while(scalar(@res)>=5){
					my $saddr;
					(undef, undef, undef, $saddr, undef, @res) = @res;
					my ($host, undef) = getnameinfo($saddr,NI_NUMERICHOST | NI_NUMERICSERV);
					push @ips,$host;

				}
			');
		}
	}

	return @ips;
}
# end getips
###############################################################################

1;