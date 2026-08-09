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
# start main
package ConfigServer::GetIPs;

use strict;
use lib '/usr/local/csf/lib';
use Carp;
use Socket;
use IPC::Open3;
use ConfigServer::Config;

# #
#	GetIPs.pm › Declare › Config
# #

my $config		= ConfigServer::Config->loadconfig();
my %config 		= $config->config();
my $ipv4reg 	= ConfigServer::Config->ipv4reg;
my $ipv6reg 	= ConfigServer::Config->ipv6reg;

# #
#	GetIPs.pm › IPv6 › Process Side
#	
#   Parse one side of an IPv6 address (the left or right part around "::")
#   into 16-bit hextet values.
#	
#   Accepts standard hex groups and an optional trailing embedded IPv4 chunk,
#   returns an arrayref of parsed hextets, [] for an empty side, or undef if
#	invalid.
#	
#	
#	Usage:				_ipv6_side( '2001:db8:0:1' );
# #

sub _ipv6_side
{
    my ( $side ) = @_;
    return [] if !defined( $side ) || $side eq '';

    my @parts = split /:/, $side, -1;
    return if grep { $_ eq '' } @parts; 		# empty chunks only valid via ::

    my @out;
    for ( my $i = 0; $i < @parts; $i++ )
    {
        my $p = $parts[$i];

        # IPv4 tail inside IPv6 (must be last in side)
        if ( $p =~ /^\d+\.\d+\.\d+\.\d+$/ )
        {
            return if $i != $#parts;
            my @o = split /\./, $p;
            return if grep { $_ !~ /^\d+$/ || $_ > 255 } @o;
            push @out, ( ( $o[0] << 8 ) | $o[1] ), ( ( $o[2] << 8 ) | $o[3] );
        }
        elsif ( $p =~ /^[0-9A-Fa-f]{1,4}$/ )
        {
            push @out, hex( $p );
        }
        else
        {
            return;
        }
    }

    return \@out;
}

sub _ipv6_hextets
{
    my ( $ip ) = @_;
    return if $ip =~ /::.*::/; # only one :: allowed

    my $has_double = ( $ip =~ /::/ ) ? 1 : 0;
    my ( $left, $right ) = split /::/, $ip, 2;

    my $l = _ipv6_side( $left );
    return if !defined( $l );

    my $r = defined( $right ) ? _ipv6_side( $right ) : [];
    return if !defined( $r );

    my @all;
    if ( $has_double )
    {
        my $missing = 8 - ( @$l + @$r );
        return if $missing < 1;
        @all = ( @$l, (0) x $missing, @$r );
    }
    else
    {
        @all = @$l;
        return if @all != 8;
    }

    return @all;
}

# #
#	GetIPs.pm › IP to Hostname
#	
#   Resolve hostname into all IP addresses (IPv4/IPv6).
#	
#   Tries external `host` command first (with timeout); if unavailable,
#   falls back to Perl DNS lookup and return list of IPs found.
#	
#	Migration:			csf 15.10; sub re-named from 'getips' to 'resolve'.
#	
#	Usage:				my @ips = ConfigServer::GetIPs::resolve( 'google.com' );
#						logfile( "IPList " . join( ', ', @ips ) );
#	
#						my ($ip) = ConfigServer::GetIPs::resolve( 'google.com' );
#						logfile( "IPList $ip" );
# #

sub resolve
{
	my $hostname = shift;
	my @ips;

	if ( -e $config{HOST} and -x $config{HOST} )
	{
		my $cmdpid;
		eval {
			local $SIG{__DIE__} 	= undef;
			local $SIG{'ALRM'} 		= sub { die };

			alarm( 10 );

			my ( $childin, $childout );
			$cmdpid = open3( $childin, $childout, $childout, $config{HOST}, "-W","5", $hostname );
			close $childin;
			my @results = <$childout>;
			waitpid ( $cmdpid, 0 );
			chomp @results;

			foreach my $line ( @results )
			{
				if ( $line =~ /($ipv4reg|$ipv6reg)/ )
				{
					push @ips, $1
				}
			}
	
			alarm( 0 );
		};

		alarm( 0 );

		if ( $cmdpid =~ /\d+/ and $cmdpid > 1 and kill( 0, $cmdpid ) )
		{
			kill( 9, $cmdpid )
		}
	}
	else
	{
		local $SIG{__DIE__} = undef;
		eval ( 'use Socket6;' );
		if ( $@ )
		{
			my @iplist;
			my ( undef, undef, undef, undef, @addrs ) = gethostbyname( $hostname );
			foreach ( @addrs )
			{
				push( @iplist,join( ".", unpack( "C4", $_ ) ) )
			}
			push @ips, $_ foreach( @iplist );
		}
		else
		{
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

# #
#	GetIPs.pm › Hexadecimal to IP
#	
#	Convert hexadecimal IP address into a human-readable IPv4 or IPv6 address.
#	Used for csf connection and process tracking.
#	
#	Migration:			Moved from lfd.pl::hex2ip in CSF v15.10.
#	
#   Examples (little-endian hex input):
#       0100007F                => 127.0.0.1
#       0101A8C0                => 192.168.1.1
#	
#   Hex string converted to bytes, then unpack("L*") splits it into
#   native-endian 32-bit unsigned:
#       1 word (4 bytes)        => treated as IPv4
#       4 words (16 bytes)      => treated as IPv6
#	
#	Usage:				logfile( "Hex2IP: 0100007F " . ConfigServer::GetIPs::hex2ip( '0100007F' ) );
#						logfile( "Hex2IP: 0101A8C0 " . ConfigServer::GetIPs::hex2ip( '0101A8C0' ) );
# #

sub hex2ip
{
    my $bin 	= pack "C*" => map hex, $_[0] =~ /../g;		# (C*) unsigned char (octet) / https://perldoc.perl.org/functions/pack
    my @l 		= unpack "L*", $bin;						# (L*) unsigned long value. using native byte order.

    if ( @l == 4 )
	{
        return join ':', map { sprintf "%x:%x", $_ >> 16, $_ & 0xffff } @l;
    }
    elsif ( @l == 1 )
	{
        return join '.', map { $_ >> 24, ($_ >> 16 ) & 0xff, ( $_ >> 8 ) & 0xff, $_ & 0xff } @l;
    }
}

# #
#	GetIPs.pm › IP to Hexadecimal
#	
#	Convert human-readable IP address into hexadecimal.
#	
#   IPv6 note:				If "::" is NOT used, the address must be full length
#							(exactly 8 hextets).
#	
#   						Example: "2001:db8:0:1" (invalid):
#							(only 4 hextets), ip2hex() returns undef.
#	
#   						Use either compressed form with "::"
#								(e.g. "2001:db8::1")
#   						or full form with 8 hextets
#								(e.g. "2001:db8:0:0:0:0:0:1").
#	
#	Examples (native-endian output):
#		127.0.0.1				=> 0100007F
#		192.168.1.1				=> 0101A8C0
#		2001:db8:0:0:0:0:0:1	=> B80D0120000000000000000001000000
#		::1						=> 00000000000000000000000001000000
#	
#	Returns:
#		8 hex characters		=> IPv4 address
#		32 hex characters		=> IPv6 address
#		undef					=> invalid or empty input
#	
#	Usage:				logfile( "IP2Hex: 127.0.0.1 " . ConfigServer::GetIPs::ip2hex( '127.0.0.1' ) );
#						logfile( "IP2Hex: 192.168.1.1 " . ConfigServer::GetIPs::ip2hex( '192.168.1.1' ) );
#						logfile( "IP2Hex: 2001:db8:0:0:0:0:0:1 " . ConfigServer::GetIPs::ip2hex( '2001:db8:0:0:0:0:0:1' ) );
# #

sub ip2hex
{
    my ( $ip ) = @_;
    return if !defined( $ip ) || $ip eq '';

    # IPv4
    if ( my @o = ( $ip =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ ) )
    {
        return if grep { $_ > 255 } @o;
        my $v4 = ( $o[0] << 24 ) | ( $o[1] << 16 ) | ( $o[2] << 8 ) | $o[3];
        return uc unpack( "H*", pack( "L", $v4 ) ); 	# native-endian
    }

    # IPv6
    my @h = _ipv6_hextets( $ip );
    return if @h != 8;

    my $hex = '';
    for ( my $i = 0; $i < 8; $i += 2 )
    {
        my $v = ( $h[$i] << 16 ) | $h[$i+1];
        $hex .= unpack( "H*", pack( "L", $v ) );   		# native-endian
    }

    return uc $hex;
}

# #
#	GetIPs.pm › IPv4 from IPv6
#	
#   Extract IPv4 from an IPv6 address by reading hextets 7 and 8,
#   then convert those 32 bits into dotted-quad format.
#	
#   Expects a full 8-hextet IPv6 string (expanded form).
#	
#	Migration:			Moved from lfd.pl::ipv4in6 in CSF v15.10.
#	Examples:			0000:0000:0000:0000:0000:ffff:c0a8:0101 => 192.168.1.1
#	Usage:				logfile( "ipv4in6: 0000:0000:0000:0000:0000:ffff:c0a8:0101  " . ConfigServer::GetIPs::ipv4in6( '0000:0000:0000:0000:0000:ffff:c0a8:0101 ' ) );
# #

sub ipv4in6
{
	my $in 		= $_[0];
	my @ipv6 	= split ( ":", $in );

	my $v6part1 = hex( $ipv6[ 6 ] );
	my $v6part2 = hex( $ipv6[ 7 ] );

	my $ip41=scalar( $v6part1>>8 );
	my $ip42=scalar( $v6part1&0xff );
	my $ip43=scalar( $v6part2>>8 );
	my $ip44=scalar( $v6part2&0xff );

	my $out = $ip41 . "." . $ip42 . "." . $ip43 . "." . $ip44;
	
	return $out;
}

1;