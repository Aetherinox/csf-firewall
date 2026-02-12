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
## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)

package ConfigServer::AbuseIP;

use strict;
use lib '/usr/local/csf/lib';
use Carp;
use IPC::Open3;
use Net::IP;
use ConfigServer::Config;
use ConfigServer::CheckIP qw(checkip);

use Exporter qw(import);
our $VERSION     = 1.03;
our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(abuseip);

my $abusemsg 	= 'Abuse Contact for [ip]: [[contact]]

The Abuse Contact of this report was provided by the Abuse Contact DB by abusix.com. abusix.com does not maintain the content of the database. All information which we pass out, derives from the RIR databases and is processed for ease of use. If you want to change or report non working abuse contacts please contact the appropriate RIR. If you have any further question, contact abusix.com directly via email (info@abusix.com). Information about the Abuse Contact Database can be found here:

https://abusix.com/global-reporting/abuse-contact-db

abusix.com is neither responsible nor liable for the content or accuracy of this message.';

my $config = ConfigServer::Config->loadconfig();
my %config = $config->config();

# #
#   abuseip
#	
#   Performs an AbuseIPDB-style abuse contact lookup for a given IP address.
#	
#   Validates the IP, converts it into a reverse-DNS format
#   (IPv4 or IPv6), and queries Abusix via DNS TXT records to retrieve
#   an abuse contact address.
#	
#   If an abuse contact is found, a formatted message is returned using
#	the configured abuse template.
#	
#   @param   ip      IP address to check (IPv4 or IPv6)
#   @return          abuse contact, formatted message (if any found)
# #

sub abuseip
{
	my $ip = shift;
	my $abuse = "";
	my $netip;
	my $reversed_ip;

	if ( checkip(\$ip) )
	{

		# #
		#   Attempt to create a Net::IP object and generate a reverse-DNS formatted
		#   address. Any fatal errors are trapped so invalid IPs do not terminate
		#   execution.
		# #

		eval
		{
			local $SIG{__DIE__} = undef;
			$netip 			= Net::IP->new( $ip );
			$reversed_ip 	= $netip->reverse_ip( );
		};
		
		# #
		#   Normalize the reverse IP by stripping common DNS suffixes.
		#   Handles both IPv4 (in-addr.arpa) and IPv6 (ip6.arpa) formats,
		#   including cases where additional data may precede the suffix.
		# #

		if ( $reversed_ip =~ /^(\S+)\.in-addr\.arpa/)
		{
			$reversed_ip = $1
		}

		if ( $reversed_ip =~ /^(\S+)\s+(\S+)\.in-addr\.arpa/)
		{
			$reversed_ip = $2
		}

		if ( $reversed_ip =~ /^(\S+)\.ip6\.arpa/)
		{
			$reversed_ip = $1
		}

		if ( $reversed_ip =~ /^(\S+)\s+(\S+)\.ip6\.arpa/)
		{
			$reversed_ip = $2
		}

		if ( $reversed_ip ne "" )
		{
			$reversed_ip .= ".abuse-contacts.abusix.org";

			my $cmdpid;
			eval
			{
				local $SIG{__DIE__} = undef;
				local $SIG{'ALRM'} = sub { die };
	
				alarm( 10 );
				my ( $childin, $childout );
				$cmdpid = open3( $childin, $childout, $childout, $config{HOST},"-W","5","-t","TXT",$reversed_ip );
				close $childin;
				my @results = <$childout>;
				waitpid ( $cmdpid, 0 );
				chomp @results;
				if ( $results[ 0 ] =~ /^${reversed_ip}.+"(.*)"$/ )
				{
					$abuse = $1
				}
				alarm( 0 );
			};
	
			alarm( 0 );
			if ( $cmdpid =~ /\d+/ and $cmdpid > 1 and kill( 0, $cmdpid ) )
			{
				kill( 9, $cmdpid )
			}

			if ( $abuse ne "" )
			{
				my $msg 	= $abusemsg;
				$msg 		=~ s/\[ip\]/$ip/g;
				$msg 		=~ s/\[contact\]/$abuse/g;

				return $abuse, $msg;
			}
		}
	}
}

1;
