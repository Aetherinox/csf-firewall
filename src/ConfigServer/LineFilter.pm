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
#   @updated            11.27.2026
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

# #
#   Declare › Package
# #

package ConfigServer::LineFilter;

# #
#   Declare › Use
# #

use strict;
use warnings;
use ConfigServer::CheckIP ( );
use ConfigServer::Logger ( );
use ConfigServer::Validate ( );

# #
#	Declare › Version
# #

our $VERSION    = 15.11;

# #
#   Linefilter › Filter Rules › Reject
#
#   Log if/why an advanced firewall rule was rejected.
#
#   @params     line            scalar|undef   Firewall rule
#               name            scalar         Invalid field name
#   @return     result          undef          No parsed rule
#               error           scalar         Invalid field name
# #

sub _parse_reject
{
	my ( $line, $name ) = @_;

	my $rule    = defined( $line ) && !ref( $line ) ? $line : "unavailable";
	$rule       =~ s/\n|\r//g;

	ConfigServer::Logger::logfile(
		"normal",
		"warn",
		"LineFilter (Rejected): line=[ $rule ] invalid field=[ $name ]",
	);

	return ( undef, $name );
}

# #
#   Linefilter › Filter Rules › Parse
#
#   Parse and validate single advanced firewall rule without applying
#   to iptables.
#
#   Owner fields checked before IP field, because owner rule may
#   leave the IP field empty, or ignore unused invalid IP field.
#
#   @params     line            scalar          Firewall rule
#   @return     result          hashref|undef   Parsed rule or undef
#               error           scalar|undef    Invalid field name or undef
# #

sub parse_advanced_rule
{
	my ( $line ) = @_;

	return _parse_reject( $line, "rule" )
		if !defined( $line ) or ref( $line ) or $line eq "";

	$line =~ s/\n|\r//g;
	$line = lc( $line );
	$line =~ s/:/|/g
		if $line !~ /\|/;

	ConfigServer::Logger::logfile( "debug:0", "info", "LineFilter (Parsing): line=[ $line ]" );

	my $sip;
	my $dip;
	my $sport;
	my $dport;
	my $protocol = "-p tcp";
	my $inout;
	my $from = 0;
	my $uid;
	my $gid;
	my $iptype;

    # #
    #   Advanced rule format (5 fields):
    #       protocol|direction|port|IP addr|UID or GID owner
    #   
    #       0   Protocol            'tcp', 'udp', 'icmp'
    #       1   Direction           'in', 'out'
    #       2   Port                'd=22', 's=1024:65535', 'd=80,443'
    #       3   IP addr             'd=192.0.2.10', 's=198.51.100.20'
    #       4   UID or GID owner    'u=957', 'g=957', 'u=root', 'g=wheel'
    #   
    #   Parser Order:
    #       1.  Protocol from index 0
    #       2.  Check direction through index 1         ($index < 2)
    #       3.  Check port through index 2              ($index < 3)
    #       4.  Check UID or GID through index 4        ($index < 5)
    #       5.  Check IP addr through index 3           ($index < 4)
    #   
    #   Accepted rules:
    #       tcp|in|d=443|s=192.0.2.10       TCP port and src ip4 addr
    #       udp|out|d=53|d=198.51.100.53    UDP port and dest ip4 addr
    #       tcp|out|d=22||u=974             UID owner at index 4
    #       tcp|out|d=22||g=974             GID owner at index 4
    #   
    #   Rejected rules:
    #       tcp|in|d=70000|s=192.0.2.10     Port outside range
    #       tcp|out|d=22|d=not-an-ip        Invalid dest IP without owner
    #       tcp|out|d=22||u=root;test       UID owner has invalid chars
    #       tcp|out|d=22||g=root;test       GID owner has invalid chars
    #       tcp|out|d=22||u=                UID owner empty
    #       tcp|out|d=22||g=                GID owner empty
    #   
    #   @note       UID or GID fields are validated before the IP field.
    #               lfd.pl validates UID/GID owner fields, but does NOT apply owner firewall rules.
    #               lfd.pl applies IP/CIDR and IP/port rules (via sub iptablescmd())
    #               csf.pl applies UID/GID firewall rules (via sub syscommand())
    #               Both lfd.pl/csf.pl use the same sub LineFilter::parse_advanced_rule().
    # #

	my @fields = split( /\|/, $line );
	if ( defined( $fields[ 0 ] ) and $fields[ 0 ] eq "tcp" )
	{
		$protocol   = "-p tcp";
		$from       = 1;
	}
	elsif ( defined( $fields[ 0 ] ) and $fields[ 0 ] eq "udp" )
	{
		$protocol   = "-p udp";
		$from       = 1;
	}
	elsif ( defined( $fields[ 0 ] ) and $fields[ 0 ] eq "icmp" )
	{
		$protocol   = "-p icmp";
		$from       = 1;
	}

	for ( my $index = $from; $index < 2; $index++ )
	{
		next
			if !defined( $fields[ $index ] );

		if ( $fields[ $index ] eq "out" )
		{
			$inout  = "out";
			$from   = $index + 1;
			last;
		}
		elsif ( $fields[ $index ] eq "in" )
		{
			$inout  = "in";
			$from   = $index + 1;
			last;
		}
	}

	for ( my $index = $from; $index < 3; $index++ )
	{
		next
			if !defined( $fields[ $index ] );

		if ( $fields[ $index ] =~ /d=(.*)/ )
		{
			my $port = $1;
			return _parse_reject( $line, "port" )
				if !ConfigServer::Validate::validate_port( $port );

			$dport = "--dport $port";
			$dport =~ s/_/:/g;
			$dport = "--icmp-type $port"
				if $protocol eq "-p icmp";
			$dport = "-m multiport $dport"
				if $dport =~ /,/;
			$from = $index + 1;
			last;
		}
		elsif ( $fields[ $index ] =~ /s=(.*)/ )
		{
			my $port = $1;
			return _parse_reject( $line, "port" )
				if !ConfigServer::Validate::validate_port( $port );

			$sport = "--sport $port";
			$sport =~ s/_/:/g;
			$sport = "--icmp-type $port"
				if $protocol eq "-p icmp";
			$sport = "-m multiport $sport"
				if $sport =~ /,/;
			$from = $index + 1;
			last;
		}
	}

	for ( my $index = $from; $index < 5; $index++ )
	{
		next
			if !defined( $fields[ $index ] );

		if ( $fields[ $index ] =~ /u=(.*)/ )
		{
			my $owner = $1;
			return _parse_reject( $line, "owner" )
				if !ConfigServer::Validate::validate_owner( $owner );

			$uid = "--uid-owner $owner";
			last;
		}
		elsif ( $fields[ $index ] =~ /g=(.*)/ )
		{
			my $owner = $1;
			return _parse_reject( $line, "owner" )
				if !ConfigServer::Validate::validate_owner( $owner );

			$gid = "--gid-owner $owner";
			last;
		}
	}

	for ( my $index = $from; $index < 4; $index++ )
	{
		next
			if !defined( $fields[ $index ] );

		if ( $fields[ $index ] =~ /d=(.*)/ )
		{
			my $ip      = $1;
			my $status  = ConfigServer::CheckIP::checkip( \$ip );

			last
				if !$status and ( $uid or $gid );

			return _parse_reject( $line, "dest ip" )
				if !$status;

			$iptype     = $status;
			$dip        = "-d $ip";
			last;
		}
		elsif ( $fields[ $index ] =~ /s=(.*)/ )
		{
			my $ip      = $1;
			my $status  = ConfigServer::CheckIP::checkip( \$ip );

			last
				if !$status and ( $uid or $gid );

			return _parse_reject( $line, "src ip" )
				if !$status;

			$iptype = $status;
			$sip    = "-s $ip";

			last;
		}
	}

	ConfigServer::Logger::logfile(
		"debug:1",
		"info",
		"LINEFILTER (Result): " .
		"line=[" . ( defined( $line ) ? $line : "undef" ) . "] " .
		"fields=[" . join( " | ", map { defined( $_ ) ? $_ : "undef" } @fields ) . "] " .
		"from=[" . ( defined( $from ) ? $from : "undef" ) . "] " .
		"protocol=[" . ( defined( $protocol ) ? $protocol : "undef" ) . "] " .
		"inout=[" . ( defined( $inout ) ? $inout : "undef" ) . "] " .
		"dport=[" . ( defined( $dport ) ? $dport : "undef" ) . "] " .
		"sport=[" . ( defined( $sport ) ? $sport : "undef" ) . "] " .
		"dip=[" . ( defined( $dip ) ? $dip : "undef" ) . "] " .
		"sip=[" . ( defined( $sip ) ? $sip : "undef" ) . "] " .
		"uid=[" . ( defined( $uid ) ? $uid : "undef" ) . "] " .
		"gid=[" . ( defined( $gid ) ? $gid : "undef" ) . "] " .
		"iptype=[" . ( defined( $iptype ) ? $iptype : "undef" ) . "]",
	);

	return (
		{
			line        => $line,
			fields      => \@fields,
			from        => $from,
			protocol    => $protocol,
			inout       => $inout,
			dport       => $dport,
			sport       => $sport,
			dip         => $dip,
			sip         => $sip,
			uid         => $uid,
			gid         => $gid,
			iptype      => $iptype,
		},
		undef,
	);
}

1;
