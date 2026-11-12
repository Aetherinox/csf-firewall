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
#   @updated            11.05.2026
#   
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#   General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, see <https://www.gnu.org/licenses>.
#   
#   @commands       Load module directly:
#                       sudo perl -I. ConfigServer/CheckIP.pm
#   
#                   Check module for syntax errors:
#                       sudo  perl -I. -c ConfigServer/CheckIP.pm
#   
#                   Module docs:
#                       perldoc -T ConfigServer/CheckIP.pm
#   
#                   Run test suite:
#                       sudo prove -I. -v tests/CheckIP.t
#   
#                   Locate modules:
#                       sudo perl -I. -MConfigServer::CheckIP -e 'print qq{CheckIP: $INC{"ConfigServer/CheckIP.pm"}\nConfig:  $INC{"ConfigServer/Config.pm"}\nNet::IP: $INC{"Net/IP.pm"}\n};'
# #

# #
#   Declare › Package
# #

## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
package ConfigServer::CheckIP;

# #
#   Declare › Use
# #

use strict;
use lib '/usr/local/csf/lib';
use Carp;
use Net::IP qw( );
use ConfigServer::Config;
use Time::HiRes qw( );
use Math::BigInt qw( );

# #
#	Declare › Export
# #

use Exporter qw( import );
our @EXPORT_OK = qw( checkip cccheckip );

# #
#	Declare › Version
# #

our $VERSION    = 15.11;

# #
#   Declare › IP Regex
# #

my $ipv4address = ConfigServer::Config->ipv4address;
my $ipv6address = ConfigServer::Config->ipv6address;

# #
#   Declare › Colors
#   
#   @ref        https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
# #

my %C =
(
    reset               => "\e[0m",
    bold                => "\e[1m",
    dim                 => "\e[2m",
	white               => "\e[97m",
	greyl               => "\e[38;5;245m",
	greym               => "\e[90m",
	greyd               => "\e[38;5;236m",
	redl                => "\e[38;5;210m",
	redm   		        => "\e[38;5;203m",
	redd                => "\e[31m",
	purplel             => "\e[38;5;177m",
	purplem  	        => "\e[38;5;201m",
	purpled             => "\e[38;5;90m",
	bluel               => "\e[38;5;75m",
	bluem               => "\e[38;5;33m",
	blued               => "\e[38;5;25m",
    fucsial             => "\e[38;5;198m",
    fucsiam             => "\e[38;5;197m",
    fucsiad             => "\e[38;5;161m",
	orangel   	        => "\e[38;5;214m",
	orangem   	        => "\e[38;5;208m",
	oranged   	        => "\e[38;5;166m",
	yellowl   	        => "\e[38;5;229m",
	yellowm   	        => "\e[38;5;226m",
	yellowd   	        => "\e[38;5;220m",
	greenl              => "\e[38;5;120m",
	greenm		        => "\e[32m",
	greend   	        => "\e[38;5;22m"
);

# #
#   Declare › Constants › IP Addr
#   
#   IP_LENGTH_MAX
#       Max chars allowed in complete IP value. Both v4 and v6.
#   
#   IP_ADDRESS_CHARS
#       Allowed chars in the addr portion before full validation.
#   
#   IPV6_ZONE_ID
#       IPv6 zone ID with 1 to 15 allowed chars.
#       First char cannot be a period or hyphen.
#   
#       Linux IFNAMSIZ allows 16 bytes, including the ending null byte.
#       This leaves 15 bytes for the zone ID.
#           Ref:    https://github.com/torvalds/linux/blob/master/include/uapi/linux/if.h
#   
#   IPTYPE_CHARS
#       Allowed chars in the addr type returned by addr_iptype().
#   
#   CIDR_PREFIX
#       Decimal CIDR prefix without leading zeros.
#   
#   IPV4_BITS
#       Total bits in an IPv4 addr.
#   
#   IPV6_BITS
#       Total bits in an IPv6 addr.
#   
#   IPV4_FAMILY
#       Net::IP family value for IPv4.
#   
#   IPV6_FAMILY
#       Net::IP family value for IPv6.
# #

use constant IP_LENGTH_MAX      => 256;
use constant IP_ADDRESS_CHARS   => qr/[0-9A-Fa-f:.]+/;
use constant IPV6_ZONE_ID       => qr/[A-Za-z0-9_][A-Za-z0-9_.-]{0,14}/;        # https://github.com/torvalds/linux/blob/master/include/uapi/linux/if.h
use constant IPTYPE_CHARS       => qr/[A-Z0-9-]+/;
use constant CIDR_PREFIX        => qr/(?:0|[1-9][0-9]{0,2})/;
use constant IPV4_BITS          => 32;
use constant IPV6_BITS          => 128;
use constant IPV4_FAMILY        => 4;
use constant IPV6_FAMILY        => 6;

# #
#   Declare › IP Type Ranges
#   
#   IP types used in Net::IP. Store binary prefixes so that
#   addr_parse() can define an IP type.
#   
#   Prefixes sorted from longest => shortest.
#   
#   @ref        https://metacpan.org/release/MANU/Net-IP-1.26/source/IP.pm
# #

my %iptype_ipv4_ranges =
(
    '00000000'                          => 'PRIVATE',       # 0/8
    '00001010'                          => 'PRIVATE',       # 10/8
    '0110010001'                        => 'SHARED',        # 100.64/10
    '01111111'                          => 'LOOPBACK',      # 127.0/8
    '1010100111111110'                  => 'LINK-LOCAL',    # 169.254/16
    '101011000001'                      => 'PRIVATE',       # 172.16/12
    '110000000000000000000000'          => 'RESERVED',      # 192.0.0/24
    '110000000000000000000010'          => 'TEST-NET',      # 192.0.2/24
    '110000000101100001100011'          => '6TO4-RELAY',    # 192.88.99.0/24 
    '1100000010101000'                  => 'PRIVATE',       # 192.168/16
    '110001100001001'                   => 'RESERVED',      # 198.18/15
    '110001100011001101100100'          => 'TEST-NET',      # 198.51.100/24
    '110010110000000001110001'          => 'TEST-NET',      # 203.0.113/24
    '1110'                              => 'MULTICAST',     # 224/4
    '1111'                              => 'RESERVED',      # 240/4
    '11111111111111111111111111111111'  => 'BROADCAST',     # 255.255.255.255/32
);

my %iptype_ipv6_ranges =
(
    '00000000'                                          => 'RESERVED',                  # ::/8
    ( '0' x 128 )                                       => 'UNSPECIFIED',               # ::/128
    ( '0' x 127 ) . '1'                                 => 'LOOPBACK',                  # ::1/128
    ( '0' x  80 ) . ( '1' x 16 )                        => 'IPV4MAP',                   # ::FFFF:0:0/96
    '00000001'                                          => 'RESERVED',                  # 0100::/8
    '0000000100000000' . ( '0' x 48 )                   => 'DISCARD',                   # 0100::/64
    '0000001'                                           => 'RESERVED',                  # 0200::/7
    '000001'                                            => 'RESERVED',                  # 0400::/6
    '00001'                                             => 'RESERVED',                  # 0800::/5
    '0001'                                              => 'RESERVED',                  # 1000::/4
    '001'                                               => 'GLOBAL-UNICAST',            # 2000::/3
    '0010000000000001' . ( '0' x 16 )                   => 'TEREDO',                    # 2001::/32
    '00100000000000010000000000000010' . ( '0' x 16 )   => 'BMWG',                      # 2001:0002::/48            
    '00100000000000010000110110111000'                  => 'DOCUMENTATION',             # 2001:DB8::/32
    '0010000000000001000000000001'                      => 'ORCHID',                    # 2001:10::/28
    '0010000000000010'                                  => '6TO4',                      # 2002::/16
    '010'                                               => 'RESERVED',                  # 4000::/3
    '011'                                               => 'RESERVED',                  # 6000::/3
    '100'                                               => 'RESERVED',                  # 8000::/3
    '101'                                               => 'RESERVED',                  # A000::/3
    '110'                                               => 'RESERVED',                  # C000::/3
    '1110'                                              => 'RESERVED',                  # E000::/4
    '11110'                                             => 'RESERVED',                  # F000::/5
    '111110'                                            => 'RESERVED',                  # F800::/6
    '1111110'                                           => 'UNIQUE-LOCAL-UNICAST',      # FC00::/7
    '111111100'                                         => 'RESERVED',                  # FE00::/9
    '1111111010'                                        => 'LINK-LOCAL-UNICAST',        # FE80::/10
    '1111111011'                                        => 'RESERVED',                  # FEC0::/10
    '11111111'                                          => 'MULTICAST',                 # FF00::/8
);

# #
#   CheckIP › Sort IP Types
#   
#   Sort prefixes from longest => shortest.
# #

my @iptype_ipv4_prefixes = sort { length( $b ) <=> length( $a ) }
	keys( %iptype_ipv4_ranges );

my @iptype_ipv6_prefixes = sort { length( $b ) <=> length( $a ) }
	keys( %iptype_ipv6_ranges );

# #
#   CheckIP › Addr › Fast Checkip
#
#   Accept plain text IPv4 / IPv6 addrs, with or without a CIDR prefix,
#   without calling addr_parse().
#
#   addr_parse() builds up to 3 Net::IP objects per CIDR, plus
#   reverse_ip() and intip(), and checkip() / cccheckip() use none of
#   it. csf and lfd call checkip() for every line of every CC_* / ASN
#   zone, so with large CC_DENY lists that adds minutes to every
#   csf -r and lfd restart.
#
#   Runs the same Net::IP steps that Net::IP->new() runs for a single
#   addr ( ip_get_version, ip_expand_address, ip_iptobin ), and the
#   same checks addr_parse() and _checkip_validate() run on the result.
#
#   Only returns accepted addrs. Anything else ( rejected, loopback,
#   non-PUBLIC with require_public_ip, zone id, IPv4 mapped IPv6,
#   binary / hex / decimal input ) returns undef, and the caller falls
#   back to addr_parse(), so rejects are unchanged.
#
#   @params     ip              str                     v4, v6, or CIDR IP to validate
#               opts            hashref                 Parser and validation options
#   @return                     hashref|undef           Accepted IP
#                                                           family              4 or 6
#                                                           addr_zone_cidr      same value as addr_parse()
#                                                       undef   Not accepted, use addr_parse()
# #

sub _checkip_fast
{
	my ( $ip, $opts ) = @_;

	my $input_format    = defined( $opts->{input_format} )
                            ? $opts->{input_format}
                            : "auto";

	return
		if ref( $input_format ) or
		   ( $input_format ne "auto" and $input_format ne "text" ) or
		   length( $ip ) > IP_LENGTH_MAX;

    # #
    #   Addr must have a period or colon, so `auto` input_format
    #   always handles it as text.
    # #

	my ( $addr, $cidr ) =
        $ip =~ m{\A(@{[ IP_ADDRESS_CHARS ]})(?:/(@{[ CIDR_PREFIX ]}))?\z};

	return
		if !defined( $addr ) or $addr !~ /[.:]/;

	my $family = index( $addr, ":" ) >= 0 ? IPV6_FAMILY : IPV4_FAMILY;
	my $bits_count = $family == IPV4_FAMILY ? IPV4_BITS : IPV6_BITS;

	return
		if $family == IPV4_FAMILY and $addr !~ /\A$ipv4address\z/;

	return
		if $family == IPV6_FAMILY and $addr !~ /\A$ipv6address\z/;

	return
		if defined( $cidr ) and
		   ( $cidr > $bits_count or $cidr == 0 );

	my $version = Net::IP::ip_get_version( $addr );
	return
		if !$version or $version != $family;

	my $addr_full = Net::IP::ip_expand_address( $addr, $family );
	return
		if !defined( $addr_full );

	my $binip = Net::IP::ip_iptobin( $addr_full, $family );
	return
		if !defined( $binip ) or length( $binip ) != $bits_count;

	my $addr_only = $family == IPV4_FAMILY
                        ? Net::IP::ip_compress_v4_prefix( $addr_full, IPV4_BITS )
                        : Net::IP::ip_compress_address( $addr_full, $family );

	my $addr_regex = $family == IPV4_FAMILY ? $ipv4address : IP_ADDRESS_CHARS;
	return
		if !defined( $addr_only ) or $addr_only !~ /\A$addr_regex\z/ or
		   $addr_full !~ /\A$addr_regex\z/;

	$addr_only = lc( $addr_only )
		if $family == IPV6_FAMILY;

	my $iptype = addr_iptype( $binip, $family );
	return
		if !defined( $iptype ) or
		   $iptype eq "IPV4MAP" or
		   ( $family == IPV4_FAMILY and $addr_only =~ /\A127\./ ) or
		   ( $family == IPV6_FAMILY and $addr_only eq "::1" ) or
		   ( $opts->{require_public_ip} and
		     $family == IPV4_FAMILY and $iptype ne "PUBLIC" );

	return
	{
		family              => $family,
		addr_zone_cidr      => defined( $cidr ) ? "$addr_only/$cidr" : $addr_only,
	};
}

# #
#   CheckIP › Addr › Validate Checkip
#   
#   Shared IP validation for checkip() and cccheckip(). All IPs will
#   route through here first.
#   
#   Parse ipv4, ipv6, or cidr using addr_parse(). Reject invalid
#   values and lookback addresses. Normalize accepted scalarref 
#   input.
#   
#   checkip()   Rejects:    IPv4 Loopback       127.0.0.0/8
#                           IPv6 loopback       ::1
#                           IPv4 CIDR prefix    /33+
#                           IPv6 CIDR prefix    /129+
#                           CIDR prefix /0      No (unless allow_prefix_zero => 1 )
#                           Invalid addresses
#   
#   cccheckip() Rejects:    IPv4 Loopback       127.0.0.0/8
#                           IPv6 loopback       ::1
#                           IPv4 CIDR prefix    /33+
#                           IPv6 CIDR prefix    /129+
#                           CIDR prefix /0      No (unless allow_prefix_zero => 1 )
#                           Invalid addresses
#   
#   @params     ipin            str|scalarref|undef     v4, v6, or CIDR IP to validate
#               opts            hashref|undef           (Optional) Parser options
#                   allow_prefix_zero                       Allow /0 CIDR prefix
#                   allow_zone_id                           Allow link-local IPv6 zone ID
#                   allow_scope_id                          Alias for allow_zone_id
#                   input_format                            Input type: auto, text, binary, hex, or decimal
#                   require_public_ip                   Require PUBLIC IPv4 type
#   
#   @return                     int                     IP validation status
#                                                           0           Invalid or rejected
#                                                           4           Valid IPv4
#                                                           6           Valid IPv6
# #

sub _checkip_validate
{
	my ( $ipin, $opts ) = @_;

	$opts = {}
		if !defined( $opts );

	return 0
		if ref( $opts ) ne "HASH" or !defined( $ipin );

	my $value;
	if ( ref( $ipin ) eq "SCALAR" )
	{
		return 0
			if !defined( ${$ipin} );

		$value = ${$ipin};
	}
	elsif ( ref( $ipin ) )
	{
		return 0;
	}
	else
	{
		$value = $ipin;
	}

	my $fast = _checkip_fast( $value, $opts );
	if ( defined( $fast ) )
	{
		${$ipin} = $fast->{addr_zone_cidr}
			if ref( $ipin ) eq "SCALAR";

		return $fast->{family};
	}

	my $parsed = addr_parse( $value, $opts );
	return 0
		if !defined( $parsed ) or _is_addr_loopback( $parsed );

	return 0
		if $opts->{require_public_ip} and
		   $parsed->{family} == IPV4_FAMILY and
		   $parsed->{iptype} ne "PUBLIC";

    # #
    #   scalarref $ipin: Allows both family int AND converted IP in
    #   standard notation.
    #   
    #   checkip() or cccheckip() returns the family int:
    #       0, 4, or 6.
    #   
    #   scalarref stores converted IP:
    #       $ip = "8.8.8.8";
    #   
    #   Eg:     my $ip      = "134744072";
    #           my $family  = checkip( \$ip );
    #       
    #           $ip         = "8.8.8.8";
    #           $family     = 4;
    # #

	${$ipin} = $parsed->{addr_zone_cidr}
		if ref( $ipin ) eq "SCALAR";

	return $parsed->{family};
}

# #
#   CheckIP › Addr › checkip()
#   
#   Validate IPv4 and IPv6 addresses.
#   
#   IPs can be specified as one of the following below. Input format
#   is 'auto' unless option 'input_format' is set:
#   
#   Formats:    Text:               8.8.8.8
#               Hexadecimal:        08080808
#               Binary:             00001000000010000000100000001000
#               Decimal:            134744072
#   
#   Accepts:    All non loopback IPv4 addrs
#               All non loopback IPv6 addrs
#               IPv4 CIDR prefix    /1 - /32, or /0     (when enabled)
#               IPv6 CIDR prefix    /1 - /128, or /0    (when enabled)
#   
#   Rejects:    IPv4 loopback       127.0.0.0/8
#               IPv6 loopback       ::1
#               IPv4 map loopback   ::ffff:127.0.0.0/104
#               IPv4 CIDR prefix    /33+
#               IPv6 CIDR prefix    /129+
#               CIDR prefix /0      No; Unless allow_prefix_zero => 1
#               Invalid addresses
#   
#   Eg          192.168.1.1     4   (accept / PRIVATE)
#               172.16.0.1      4   (accept / PRIVATE)
#               10.0.0.1        4   (accept / PRIVATE)
#               8.8.8.8/0       0   (reject / PREFIX ZERO DISALLOWED)
#               169.254.1.1     4   (accept / LINK-LOCAL)
#               224.0.0.1       4   (accept / MULTICAST)
#   
#   Tests       List above generated from sub { tests_checkip }
#                   perl -I. -MConfigServer::CheckIP -e "ConfigServer::CheckIP::tests_checkip()"
#   
#   @params     ipin            str|scalarref|undef     v4, v6, or CIDR IP to validate
#               opts            hashref|undef           (Optional) Parser and validation options
#                   allow_prefix_zero                       Allow /0 CIDR prefix
#                   allow_zone_id                           Allow link-local IPv6 zone ID
#                   allow_scope_id                          Alias for allow_zone_id
#                   input_format                            Input type: auto, text, binary, hex, or decimal
#                   require_public_ip                       Require PUBLIC IPv4 type
#   @return                     int                     IP validation status
#                                                           0           Invalid or rejected
#                                                           4           Valid IPv4
#                                                           6           Valid IPv6
# #

sub checkip
{
	my ( $ipin, $opts ) = @_;

	$opts = {}
		if !defined( $opts );

	return 0
		if ref( $opts ) ne "HASH";

    # #
    #   @note       $ipin has not yet been converted if client passes
    #               IP in bin / hex / int format.
    # #

	return _checkip_validate( $ipin, $opts );
}

# #
#   CheckIP › Addr › cccheckip()
#   
#   Validate IPv4 and IPv6 addresses.
#   
#   IPs can be specified as one of the following below. Input format
#   is 'auto' unless option 'input_format' is set:
#   
#   Formats:    Text:               8.8.8.8
#               Hexadecimal:        08080808
#               Binary:             00001000000010000000100000001000
#               Decimal:            134744072
#   
#   Accepts:    IPv4 addrs marked PUBLIC by addr_iptype()
#               All non loopback IPv6 addrs
#               IPv4 CIDR prefix    /1 - /32, or /0     (when enabled)
#               IPv6 CIDR prefix    /1 - /128, or /0    (when enabled)
#   
#   Rejects:    IPv4 addrs not marked PUBLIC by addr_iptype()
#               IPv4 loopback       127.0.0.0/8
#               IPv6 loopback       ::1
#               IPv4 map loopback   ::ffff:127.0.0.0/104
#               IPv4 CIDR prefix    /33+
#               IPv6 CIDR prefix    /129+
#               CIDR prefix /0      No; Unless allow_prefix_zero => 1
#               Invalid addresses
#   
#   Eg          192.168.1.1     0   (reject / PRIVATE)
#               172.16.0.1      0   (reject / PRIVATE)
#               10.0.0.1        0   (reject / PRIVATE)
#               8.8.8.8/0       0   (reject / PREFIX ZERO DISALLOWED)
#               169.254.1.1     0   (reject / LINK-LOCAL)
#               224.0.0.1       0   (reject / MULTICAST)
#   
#   Tests       List above generated from sub { tests_checkip }
#                   perl -I. -MConfigServer::CheckIP -e "ConfigServer::CheckIP::tests_checkip()"
#   
#   @params     ipin            str|scalarref|undef     v4, v6, or CIDR IP to validate
#               opts            hashref|undef           (Optional) Parser and validation options
#                   allow_prefix_zero                       Allow /0 CIDR prefix
#                   allow_zone_id                           Allow link-local IPv6 zone ID
#                   allow_scope_id                          Alias for allow_zone_id
#                   input_format                            Input type: auto, text, binary, hex, or decimal
#                   require_public_ip                       Always enabled by cccheckip()
#   @return                     int                     IP validation status
#                                                           0           Invalid or rejected
#                                                           4           Valid IPv4
#                                                           6           Valid IPv6
# #

sub cccheckip
{
	my ( $ipin, $opts ) = @_;

	$opts = {}
		if !defined( $opts );

	return 0
		if ref( $opts ) ne "HASH";

	my %cc_opts = %{$opts};
	$cc_opts{require_public_ip} = 1;

    # #
    #   @note       $ipin has not yet been converted if client passes
    #               IP in binary / hex / int format.
    # #

	return _checkip_validate( $ipin, \%cc_opts );
}

# #
#   CheckIP › Addr › Binary to IP
#   
#   Convert 32 or 128 bit binary addr to normal IP notation.
#   
#   Detect IP family (4 or 6) from the binary length unless 
#   family is manually supplied.
#   
#   @params     binip           str|undef       Binary v4 or v6 addr
#               family          int|undef       (Optional) IP family: 4 or 6
#   @return     address         str|undef       Converted IP addr
#                                                   str             Normal IP text
#                                                   undef           Invalid binary or family
# #

sub addr_bin_to_ip
{
	my ( $binip, $family ) = @_;

	return
		if !defined( $binip ) or ref( $binip ) or
		   $binip !~ /\A[01]+\z/;

	if ( defined( $family ) )
	{
		return
			if ref( $family ) or ( $family ne IPV4_FAMILY and $family ne IPV6_FAMILY );
	}
	elsif ( length( $binip ) == IPV4_BITS )
	{
		$family = IPV4_FAMILY;
	}
	elsif ( length( $binip ) == IPV6_BITS )
	{
		$family = IPV6_FAMILY;
	}
	else
	{
		return;
	}

	my $bits = $family == IPV4_FAMILY ? IPV4_BITS : IPV6_BITS;
	return
		if length( $binip ) != $bits;

	my $addr;

	{
		local $SIG{__DIE__};
		local $@;

		$addr = eval
		{
			my $converted   = Net::IP::ip_bintoip( $binip, $family );
			my $netip       = defined( $converted )
                                ? Net::IP->new( $converted, $family )
                                : undef;

			defined( $netip ) and $netip->version( ) == $family
				? $netip->short( )
				: undef;
		};
	}

	return
		if !defined( $addr ) or ref( $addr ) or $addr eq "";

	my $addr_regex = $family == IPV4_FAMILY ? $ipv4address : $ipv6address;
	return
		if $addr !~ /\A(?:$addr_regex)\z/;

	return $family == IPV6_FAMILY ? lc( $addr ) : $addr;
}

# #
#   CheckIP › Addr › Hexadecimal to IP
#   
#   Convert 8 or 32 character hexadecimal addr to normal IP notation.
#   
#   Detect IP family (4 or 6) from the hexadecimal length unless 
#   family is manually supplied.
#   
#   @params     hexip           str|undef       Hexadecimal v4 or v6 addr
#               family          int|undef       (Optional) IP family: 4 or 6
#   @return     address         str|undef       Converted IP addr
#                                                   str             Normal IP text
#                                                   undef           Invalid hexadecimal or family
# #

sub addr_hex_to_ip
{
	my ( $hexip, $family ) = @_;

	return
		if !defined( $hexip ) or ref( $hexip ) or $hexip !~ /\A[0-9A-Fa-f]+\z/;

	if ( defined( $family ) )
	{
		return
			if ref( $family ) or ( $family ne IPV4_FAMILY and $family ne IPV6_FAMILY );
	}
	elsif ( length( $hexip ) == IPV4_BITS / 4 )
	{
		$family = IPV4_FAMILY;
	}
	elsif ( length( $hexip ) == IPV6_BITS / 4 )
	{
		$family = IPV6_FAMILY;
	}
	else
	{
		return;
	}

	my $hex_chars = $family == IPV4_FAMILY ? IPV4_BITS / 4 : IPV6_BITS / 4;
	return
		if length( $hexip ) != $hex_chars;

	my $binip = unpack( "B*", pack( "H*", $hexip ) );
	return addr_bin_to_ip( $binip, $family );
}

# #
#   CheckIP › Addr › Decimal to IP
#   
#   Convert decimal addr to normal IP notation.
#   
#   Detect IP family (4 or 6) from the hexadecimal length unless 
#   family is manually supplied.
#   
#   @params     intip           str|undef       Decimal v4 or v6 addr
#               family          int|undef       (Optional) IP family: 4 or 6
#   @return     address         str|undef       Converted IP addr
#                                                   str             Normal IP text
#                                                   undef           Invalid decimal or family
# #

sub addr_int_to_ip
{
	my ( $intip, $family ) = @_;

	return
		if !defined( $intip ) or ref( $intip ) or $intip !~ /\A(?:0|[1-9][0-9]*)\z/;

	if ( defined( $family ) )
	{
		return
			if ref( $family ) or ( $family ne IPV4_FAMILY and $family ne IPV6_FAMILY );
	}

	my $int_value   = Math::BigInt->new( $intip );
	return
		if $int_value->is_nan( ) or $int_value->is_neg( );

	my $ipv4_max    = Math::BigInt->new( 2 )->bpow( IPV4_BITS )->bdec( );
	my $ipv6_max    = Math::BigInt->new( 2 )->bpow( IPV6_BITS )->bdec( );

	if ( !defined( $family ) )
	{
		if ( $int_value->bcmp( $ipv4_max ) <= 0 )
		{
			$family = IPV4_FAMILY;
		}
		elsif ( $int_value->bcmp( $ipv6_max ) <= 0 )
		{
			$family = IPV6_FAMILY;
		}
		else
		{
			return;
		}
	}

	my $max_int = $family == IPV4_FAMILY ? $ipv4_max : $ipv6_max;
	return
		if $int_value->bcmp( $max_int ) > 0;

	my $bits    = $family == IPV4_FAMILY ? IPV4_BITS : IPV6_BITS;
	my $binip   = $int_value->as_bin( );
	$binip      =~ s/\A0b//;

	return
		if $binip !~ /\A[01]+\z/ or length( $binip ) > $bits;

	$binip = ( "0" x ( $bits - length( $binip ) ) ) . $binip;

	return addr_bin_to_ip( $binip, $family );
}

# #
#   CheckIP › Addr › Parse
#   
#   Validate and normalize v4 or v6 addresses.
#   
#   If CIDR prefix supplied, calculate network range, first and last
#   address, masks, bit count, etc.
#   
#   All opts disabled by default.
#   
#   input_format
#       Set the format of the supplied IP.
#   
#       Default:        Auto
#       Options:        auto, hexadecimal, decimal, binary, text
#       Eg:             addr_parse( "c0000201/24", { input_format => "hex" } );
#   
#   allow_zone_id, allow_scope_id                    ( fe80::1%eth0 )
#       Allow ipv6 ip with type 'LINK-LOCAL-UNICAST' to include the
#       network interface used to reach it.
#   
#       Options:        0, 1
#       Eg:             addr_parse( "fe80::1%eth0/64", { allow_zone_id => 1 } );
#   
#   allow_prefix_zero                               ( /0 cidr prefix )
#       Allow /0 CIDR prefix
#   
#       Options:        0, 1
#       Eg:             addr_parse( "192.0.2.10/0", { allow_prefix_zero => 1 } );
#   
#   @ref        https://metacpan.org/pod/Net::IP
#   
#   @params     ip                  str|undef           v4, v6, or CIDR IP to parse
#               opts                hashref|undef       (Optional) Parser options
#                   allow_prefix_zero                       Allow /0 CIDR prefix
#                   allow_zone_id                           Allow link-local IPv6 zone ID
#                   allow_scope_id                          Alias for allow_zone_id
#                   input_format                            Input type: auto, text, binary, hex, or decimal
#   @return                         hashref|undef       Parsed IP result
#                                                           hashref     Valid parsed IP
#                                                           undef       Invalid IP or opts
# #

sub addr_parse
{
	my ( $ip, $opts ) = @_;

	$opts = {}
		if !defined( $opts );

	return
		if !defined( $ip ) or ref( $ip ) or
		   ref( $opts ) ne "HASH" or $ip eq "" or
		   length( $ip ) > IP_LENGTH_MAX;

    # #
    #   Convert binary, hexadecimal, or decimal
    #   
    #   `auto` detection checks which type of IP was input. Output
    #    IP in standard notion (x.x.x.x).
    # #

	my $input_format    = defined( $opts->{input_format} )
                            ? $opts->{input_format}
                            : "auto";

	return
		if ref( $input_format ) or
		   ( $input_format ne "auto" and
		     $input_format ne "text" and
		     $input_format ne "binary" and
		     $input_format ne "hex" and
		     $input_format ne "decimal" );

	if ( $input_format ne "text" )
	{
		my @input_parts = split( /\//, $ip, -1 );
		return
			if @input_parts > 2;

		my ( $input_addr, $input_cidr ) = @input_parts;
		return
			if !defined( $input_addr ) or $input_addr eq "";

		my $convert_format = $input_format;
		if ( $convert_format eq "auto" )
		{
			if ( $input_addr =~ /\A[01]+\z/ and
			     ( length( $input_addr ) == IPV4_BITS or
			       length( $input_addr ) == IPV6_BITS ) )
			{
				$convert_format = "binary";
			}
			elsif ( $input_addr =~ /\A[0-9A-Fa-f]+\z/ and
			        ( length( $input_addr ) == IPV4_BITS / 4 or
			          length( $input_addr ) == IPV6_BITS / 4 ) )
			{
				$convert_format = "hex";
			}
			elsif ( $input_addr =~ /\A(?:0|[1-9][0-9]*)\z/ )
			{
				$convert_format = "decimal";
			}
			else
			{
				$convert_format = "text";
			}
		}

		my $converted_addr = $convert_format eq "binary"
			? addr_bin_to_ip( $input_addr )
			: $convert_format eq "hex"
				? addr_hex_to_ip( $input_addr )
				: $convert_format eq "decimal"
					? addr_int_to_ip( $input_addr )
					: $input_addr;

		return
			if !defined( $converted_addr );

		if ( $convert_format ne "text" )
		{
			$ip     = $converted_addr;
			$ip     .= "/" . $input_cidr
				        if @input_parts == 2;
		}
	}

    # #
    #   Allow Zone id / Scope alias
    #   
    #   @ref        https://rfc-editor.org/rfc/rfc4007.html
    #               https://ip.network/tools/ipv6-zone-id
    #               https://networkingtoolbox.net/ip-address-convertor/notation/zone-id
    # #

	my $allow_zone_id = $opts->{allow_zone_id} || $opts->{allow_scope_id};

	my ( $addr, $zone_id, $cidr ) = 
        $ip =~ m{\A(@{[ IP_ADDRESS_CHARS ]})(?:%(@{[ IPV6_ZONE_ID ]}))?(?:/(@{[ CIDR_PREFIX ]}))?\z};

	return
		if !defined( $addr );

	my $family = index( $addr, ":" ) >= 0 ? IPV6_FAMILY : IPV4_FAMILY;
	return
		if defined( $zone_id ) and
		   ( !$allow_zone_id or $family != IPV6_FAMILY );

	if ( $family == IPV4_FAMILY )
	{
		my ( $addr_valid ) = $addr =~ /\A($ipv4address)\z/;
		return
			if !defined( $addr_valid );

		$addr = $addr_valid;
	}
	else
	{
		my ( $addr_valid ) = $addr =~ /\A($ipv6address)\z/;
		return
			if !defined( $addr_valid );

		$addr = $addr_valid;
	}

	if ( defined( $cidr ) )
	{
		my $cidr_max = $family == IPV4_FAMILY ? IPV4_BITS : IPV6_BITS;
		return
			if $cidr > $cidr_max or
			   ( $cidr == 0 and !$opts->{allow_prefix_zero} );

		$cidr = 0 + $cidr;
	}

	my $parsed;

	{
		local $SIG{__DIE__};
		local $@;

		$parsed = eval
		{
			my $netip           = Net::IP->new( $addr, $family );
			my $is_parsed       = defined( $netip ) ? 1 : 0;
			my $addr_full       = $is_parsed ? $netip->ip( ) : undef;
			my $binip           = $is_parsed ? $netip->binip( ) : undef;
			my $iptype          = $is_parsed ? addr_iptype( $binip ) : undef;
			my $reverse_ip      = $is_parsed ? $netip->reverse_ip( ) : undef;
			my $intip           = $is_parsed ? $netip->intip( ) : undef;

			# #
			#   @bug        Net::IP 1.26 can return undef from intip()
            #               for all zero ipv4 or v6 addr. Use zero
            #               only when binip() confirms every addr bit
            #               is zero.
			#   
			#               https://sources.debian.org/patches/libnet-ip-perl/1.26-4/
			# #

			$intip = "0"
				if $is_parsed and !defined( $intip ) and
				   defined( $binip ) and $binip =~ /\A0+\z/;

			my ( $addr_first, $addr_first_full, $addr_netmask );
			my ( $addr_last, $addr_last_full );
			my $is_first_address;

			if ( $is_parsed and defined( $cidr ) )
			{
				my $addr_binary = $binip;
				my $bits_count  = $family == IPV4_FAMILY ? IPV4_BITS : IPV6_BITS;
				my $bits_host   = $bits_count - $cidr;

				$is_parsed      = defined( $addr_binary ) and
                                    length( $addr_binary ) == $bits_count ? 1 : 0;

				if ( $is_parsed )
				{
					my $network_binary  = substr( $addr_binary, 0, $cidr ) .
                                            ( "0" x $bits_host );
					my $last_binary     = substr( $addr_binary, 0, $cidr ) .
                                            ( "1" x $bits_host );
					my $netmask_binary  = ( "1" x $cidr ) . ( "0" x $bits_host );
					my $network_raw     = Net::IP::ip_bintoip( $network_binary, $family );
					my $last_raw        = Net::IP::ip_bintoip( $last_binary, $family );
					my $netmask_raw     = Net::IP::ip_bintoip( $netmask_binary, $family );
					my $network_ip      = defined( $network_raw )
                                            ? Net::IP->new( $network_raw, $family )
                                            : undef;

					my $last_ip         = defined( $last_raw )
                                            ? Net::IP->new( $last_raw, $family )
                                            : undef;

					$is_parsed = (
						defined( $network_ip ) and
						defined( $last_ip ) and
						defined( $netmask_raw )
					) ? 1 : 0;

					if ( $is_parsed )
					{
						$addr_first             = $network_ip->short( );
						$addr_first_full        = $network_ip->ip( );
						$addr_netmask           = $netmask_raw;
						$addr_last              = $last_ip->short( );
						$addr_last_full         = $last_ip->ip( );
						$is_first_address       = $addr_binary eq $network_binary ? 1 : 0;
					}
				}
			}

			$is_parsed
				? {
					family              => $netip->version( ),
					address             => $netip->short( ),
					addr_full           => $addr_full,
					iptype              => $iptype,
					binip               => $binip,
					reverse_ip          => $reverse_ip,
					intip               => $intip,
					addr_first          => $addr_first,
					addr_first_full     => $addr_first_full,
					addr_netmask        => $addr_netmask,
					addr_last           => $addr_last,
					addr_last_full      => $addr_last_full,
					is_first_address    => $is_first_address,
				  }
				: undef;
		};
	}

	return
		if ref( $parsed ) ne "HASH" or
		   !defined( $parsed->{family} ) or
		   $parsed->{family} ne $family or
		   !defined( $parsed->{address} ) or
		   !defined( $parsed->{addr_full} ) or
		   !defined( $parsed->{iptype} );

	return
		if !defined( $parsed->{binip} ) or
		   !defined( $parsed->{reverse_ip} ) or
		   !defined( $parsed->{intip} );

	my $addr_regex      = $family == IPV4_FAMILY ? $ipv4address : IP_ADDRESS_CHARS;
	my ( $addr_only )   = $parsed->{address} =~ /\A($addr_regex)\z/;
	my ( $addr_full )   = $parsed->{addr_full} =~ /\A($addr_regex)\z/;
	my ( $iptype )      = $parsed->{iptype} =~ /\A(@{[ IPTYPE_CHARS ]})\z/;
	my ( $binip )       = $parsed->{binip} =~ /\A([01]+)\z/;
	my ( $reverse_ip )  = $parsed->{reverse_ip} =~ /\A([A-Za-z0-9.-]+)\z/;
	my $intip_raw       = "" . $parsed->{intip};
	my ( $intip )       = $intip_raw =~ /\A([0-9]+)\z/;
	my $bits_count      = $family == IPV4_FAMILY ? IPV4_BITS : IPV6_BITS;

	return
		if !defined( $addr_only ) or !defined( $addr_full ) or
		   !defined( $iptype ) or
		   !defined( $binip ) or length( $binip ) != $bits_count or
		   !defined( $reverse_ip ) or !defined( $intip );

	$addr_only = lc( $addr_only )
		if $family == IPV6_FAMILY;

	$addr_full = lc( $addr_full )
		if $family == IPV6_FAMILY;

	my $is_loopback_address = (
		( $family == IPV4_FAMILY and $addr_only =~ /\A127\./ ) or
		( $family == IPV6_FAMILY and $addr_only eq "::1" )
	) ? 1 : 0;

    # #
    #   @bug        ipv4 loopbacks can also be written as an ipv4 mapped
    #               ipv6 addr (eg: ::ffff:127.0.0.1), which is parsed
    #               as ipv6. A normal ipv4 loopback check will miss it.
    #   
    #               Extract embedded ipv4 addr from either a dotted
    #               or hexadecimal format. Reject mapped 127.0.0.0/8
    #               loopback range.
    #   
    #   @test       Note:           Test IPv4-mapped IPv6 loopback addrs
    #               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::CheckIP -e 'for my $test ([q{::ffff:127.0.0.1},1],[q{::ffff:127.42.10.5},1],[q{0:0:0:0:0:ffff:7f00:1},1],[q{::ffff:126.255.255.255},0],[q{::ffff:128.0.0.0},0],[q{::ffff:192.0.2.1},0]) { my ($ip,$expected) = @{$test}; my $parsed = ConfigServer::CheckIP::addr_parse($ip); die qq{Failed: addr_parse returned undef for [$ip]\n} if !defined($parsed); my $returned = $parsed->{is_loopback_address}; my $from_string = ConfigServer::CheckIP::_is_addr_loopback($ip); my $from_parsed = ConfigServer::CheckIP::_is_addr_loopback($parsed); die qq{Failed: $ip return field [$returned], expected [$expected]\n} if $returned != $expected; die qq{Failed: $ip string input [$from_string], expected [$expected]\n} if $from_string != $expected; die qq{Failed: $ip parsed input [$from_parsed], expected [$expected]\n} if $from_parsed != $expected; my $status = $returned ? q{LOOPBACK} : q{Not loopback}; printf "%-39s => %-22s type=%-8s %s\n",$ip,$parsed->{address},$parsed->{iptype},$status; }'
    # #

	my $embedded_ipv4 = addr_get_embedded_v4( $parsed );
	$is_loopback_address = 1
		if defined( $embedded_ipv4 ) and $embedded_ipv4 =~ /\A127\./;

    # #
    #   @bug        Some Net::IP versions remove trailing zero octets
    #               when creating ipv4 reverse name:
    #                   Incorrect:  192.0.2.0 => "2.0.192.in-addr.arpa."
    #                   Correct:    192.0.2.0 => "0.2.0.192.in-addr.arpa."
    #   
    #               Build reverse name from all 4 validated ipv4 octets.
    #   
    #               https://sources.debian.org/patches/libnet-ip-perl/1.26-4/ip_reverse.patch/
    #               https://sources.debian.org/src/libnet-ip-perl/1.26-3/IP.pm/
    #   
    #   @test       Note:           Test reverse IP patch
    #               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::CheckIP -e 'for my $test ([q{192.0.2.0/24},q{0.2.0.192.in-addr.arpa.}],[q{192.0.2.10/24},q{10.2.0.192.in-addr.arpa.}],[q{192.0.2.255/24},q{255.2.0.192.in-addr.arpa.}],[q{10.0.0.0/8},q{0.0.0.10.in-addr.arpa.}],[q{10.0.0.1/8},q{1.0.0.10.in-addr.arpa.}],[q{10.10.0.0/16},q{0.0.10.10.in-addr.arpa.}],[q{172.16.0.0/12},q{0.0.16.172.in-addr.arpa.}],[q{192.168.0.0/16},q{0.0.168.192.in-addr.arpa.}],[q{169.254.0.0/16},q{0.0.254.169.in-addr.arpa.}],[q{100.64.0.0/10},q{0.0.64.100.in-addr.arpa.}],[q{127.0.0.1/8},q{1.0.0.127.in-addr.arpa.}],[q{203.0.113.0/24},q{0.113.0.203.in-addr.arpa.}],[q{198.51.100.0/24},q{0.100.51.198.in-addr.arpa.}],[q{1.0.0.0},q{0.0.0.1.in-addr.arpa.}],[q{1.2.0.0},q{0.0.2.1.in-addr.arpa.}],[q{1.2.3.0},q{0.3.2.1.in-addr.arpa.}],[q{1.2.3.4},q{4.3.2.1.in-addr.arpa.}],[q{8.8.8.8},q{8.8.8.8.in-addr.arpa.}],[q{0.0.0.0},q{0.0.0.0.in-addr.arpa.}],[q{255.255.255.255},q{255.255.255.255.in-addr.arpa.}]) { my ($ip,$expected) = @{$test}; my $res = ConfigServer::CheckIP::addr_parse($ip); my $got = defined($res) ? $res->{reverse_ip} : q{undef}; my $status = $got eq $expected ? q{OK} : q{FAILED}; printf "%-20s => %-36s %s\n",$ip,$got,$status; die qq{Failed: $ip returned [$got], expected [$expected]\n} if $got ne $expected; }'
    # #

	$reverse_ip = join( ".", reverse( split( /\./, $addr_only ) ), "in-addr", "arpa." )
		if $family == IPV4_FAMILY;

	my ( $addr_first, $addr_first_full, $addr_first_int );
	my ( $addr_last, $addr_last_full, $addr_last_int );
	my ( $addr_netmask, $addr_wildcard_mask );
	my ( $bits_host, $addr_range_count );
	my ( $is_first_address, $is_last_address );

	if ( defined( $cidr ) )
	{
		for my $field (
			"addr_first", "addr_first_full", "addr_netmask",
			"addr_last", "addr_last_full"
		)
		{
			return
				if !defined( $parsed->{$field} );

			my ( $field_valid ) = $parsed->{$field} =~ /\A($addr_regex)\z/;
			return
				if !defined( $field_valid );

			$parsed->{$field}   = $family == IPV6_FAMILY
                                    ? lc( $field_valid )
                                    : $field_valid;
		}

		return
			if !defined( $parsed->{is_first_address} ) or $parsed->{is_first_address} !~ /\A[01]\z/;

		$addr_first             = $parsed->{addr_first};
		$addr_first_full        = $parsed->{addr_first_full};
		$addr_last              = $parsed->{addr_last};
		$addr_last_full         = $parsed->{addr_last_full};
		$addr_netmask           = $parsed->{addr_netmask};
		$bits_host              = ( $family == IPV4_FAMILY ? IPV4_BITS : IPV6_BITS ) - $cidr;

		my $network_binary      = substr( $binip, 0, $cidr ) . ( "0" x $bits_host );
		my $last_binary         = substr( $binip, 0, $cidr ) . ( "1" x $bits_host );

		$addr_first_int         = Math::BigInt->from_bin( "0b$network_binary" )->bstr( );
		$addr_last_int          = Math::BigInt->from_bin( "0b$last_binary" )->bstr( );
		$addr_range_count       = Math::BigInt->new( 2 )->bpow( $bits_host )->bstr( );
		$is_first_address       = $parsed->{is_first_address};
		$is_last_address        = $binip eq $last_binary ? 1 : 0;

		if ( $family == IPV4_FAMILY )
		{
			my @netmask_octets  = split( /\./, $addr_netmask );
			$addr_wildcard_mask = join( ".", map { 255 - $_ } @netmask_octets );
		}
	}

	return
		if defined( $zone_id ) and $iptype ne "LINK-LOCAL-UNICAST";

	my $addr_zone_cidr = join(
		"",
		$addr_only,
		defined( $zone_id ) ? "%$zone_id" : "",
		defined( $cidr ) ? "/$cidr" : "",
	);

	my $addr_network_cidr = defined( $cidr )
		? "$addr_first/$cidr"
		: undef;

	my $addr_range_short = defined( $cidr )
		? "$addr_first - $addr_last"
		: undef;

	my $addr_range_full = defined( $cidr )
		? "$addr_first_full - $addr_last_full"
		: undef;

    # #
    #   address (str)
    #       Short ip addr without cidr or zone id.
    #       Eg:     addr_parse( "2001:db8::1" )
    #               address = "2001:db8::1"
    #   
    #   addr_full (str)
    #       Full ip addr without cidr or zone id.
    #       Eg:     addr_parse( "2001:db8::1" )
    #               addr_full = "2001:0db8:0000:0000:0000:0000:0000:0001"
    #   
    #   addr_zone_cidr (str)
    #       Short ip addr; includes zone id and cidr when supplied.
    #   
    #       Eg:     addr_parse( "fe80::1%eth0/64", { allow_zone_id => 1 } )
    #               addr_zone_cidr = "fe80::1%eth0/64"
    #       Eg:     addr_parse( "fe80::1%eth0/64", { allow_zone_id => 0 } )
    #               IP:     "fe80::1%eth0/64"
    #               Status: DENIED
    #               return: undef
    #   
    #   family (int)
    #       IPv4 = 4
    #       IPv6 = 6
    #   
    #       Eg:     addr_parse( "192.0.2.10" )
    #               family = 4
    #   
    #   cidr (int|undef)
    #       CIDR prefix number (eg: 24)
    #       CIDR prefix required OR returns undef.
    #   
    #       Eg:     addr_parse( "10.0.0.1/8" )
    #               cidr = 8
    #   
    #   zone_id (str|undef)                         (Zone AKA Scope id)
    #       IPv6 zone id (eg: eth0).
    #       Zone id required OR returns undef.
    #       Requires option 'allow_scope_id'.
    #   
    #       Eg:     addr_parse( "fe80::1%eth0" )
    #               zone_id = undef <none>
    #       Eg:     addr_parse( "fe80::1%eth0", { allow_scope_id => 1 } )
    #               zone_id = "eth0"
    #   
    #   iptype (str)
    #       Addr type returned by addr_iptype():
    #           PUBLIC,
    #           PRIVATE,
    #           LOOPBACK,
    #           TEST-NET,
    #           DOCUMENTATION,
    #           LINK-LOCAL-UNICAST.
    #   
    #       List of ipv4 and ipv6 IP types:
    #           https://metacpan.org/release/MANU/Net-IP-1.26/source/IP.pm
    #   
    #       Eg:     addr_parse( "192.0.2.10" )
    #               iptype = "TEST-NET"
    #   
    #   binip (str)
    #       IP addr as binary digits.
    #       IPv4 (32 digits)
    #       IPv6 (128 digits).
    #   
    #       Eg:     addr_parse( "192.0.2.10" )
    #               binip = "11000000000000000000001000001010"
    #   
    #   reverse_ip (str)
    #       Reverse DNS name for ip. Does not perform DNS lookup.
    #   
    #       Eg:     addr_parse( "192.0.2.10" )
    #               reverse_ip = "10.2.0.192.in-addr.arpa."
    #   
    #   intip (str)
    #       IP addr as decimal int. Return as str since IPv6 values
    #       can exceed Perl's int range / limit.
    #   
    #       Eg:     addr_parse( "192.0.2.10" )
    #               intip = "3221225994"
    #   
    #   addr_network_cidr (str|undef)
    #       First addr in CIDR range with prefix.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "192.0.2.10/24" )
    #               addr_network_cidr = "192.0.2.0/24"
    #       Eg:     addr_parse( "2001:db8::1/1" )
    #               addr_network_cidr = "::/1"
    #   
    #   addr_netmask (str|undef)
    #       Network mask created from CIDR.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "10.0.0.1/8" )
    #               addr_netmask = "255.0.0.0"
    #       Eg:     addr_parse( "2001:db8::1/1" )
    #               addr_netmask = "8000:0000:0000:0000:0000:0000:0000:0000"
    #   
    #   addr_wildcard_mask (str|undef)
    #       Inverse IPv4 network mask. Returns undef for IPv6.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "10.0.0.1/29" )
    #               addr_wildcard_mask = "0.0.0.7"
    #   
    #   addr_first (str|undef)
    #       First addr in CIDR network.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "192.0.2.10/24" )
    #               addr_first = "192.0.2.0"
    #   
    #   addr_first_int (str|undef)
    #       First addr in CIDR network as decimal.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "10.0.0.1/29" )
    #               addr_first_int = "167772160"
    #   
    #   addr_last (str|undef)
    #       Final addr in CIDR network.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "192.0.2.10/24" )
    #               addr_last = "192.0.2.255"
    #       Eg:     addr_parse( "10.0.0.1/8" )
    #               addr_last = "10.255.255.255"
    #   
    #   addr_last_int (str|undef)
    #       Final addr in CIDR network as decimal.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "10.0.0.1/29" )
    #               addr_last_int = "167772167"
    #   
    #   addr_range_short (str|undef)
    #       First and final addr in the CIDR network using the short
    #       addr format. 
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "2001:db8::1/64" )
    #               addr_range_short =
    #                   "2001:db8:: - 2001:db8::ffff:ffff:ffff:ffff"
    #   
    #   addr_range_full (str|undef)
    #       First and final addr in the CIDR network using the full
    #       addr format.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "10.0.0.1/29" )
    #               addr_range_full = "10.0.0.0 - 10.0.0.7"
    #   
    #   addr_range_count (str|undef)
    #       Total num of IP addrs in CIDR range. Return as decimal str
    #       since IPv6 counts exceed Perl int range/limit.
    #       Includes every addr in range.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "192.0.2.10/24" )
    #               addr_range_count = "256"
    #       Eg:     addr_parse( "2001:db8::1/64" )
    #               addr_range_count = "18446744073709551616"
    #   
    #   bits_mask (int|undef)
    #       Num of addr bits used by CIDR prefix. Same value as cidr.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "192.0.2.10/24" )
    #               bits_mask = 24
    #   
    #   bits_host (int|undef)
    #       Num of addr bits outside CIDR prefix.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "10.0.0.1/8" )
    #               bits_host = 24
    #   
    #   is_first_address (int|undef)
    #       Return 1: addr is first addr in its CIDR network.
    #       Return 0: addr is another addr in the network.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "10.0.0.1/8" )
    #               is_first_address = 0
    #       Eg:     addr_parse( "192.0.2.0/24" )
    #               is_first_address = 1
    #   
    #   is_last_address (int|undef)
    #       Return 1: addr is last addr in its CIDR network.
    #       Return 0: addr is another addr in the network.
    #       CIDR prefix required OR return undef.
    #   
    #       Eg:     addr_parse( "10.0.0.7/29" )
    #               is_last_address = 1
    #   
    #   is_loopback_address (int)
    #       Return 1: if IPv4 (127.0.0.0/8), IPv6 (::1), or an
    #       IPv4 mapped IPv6 addr containing IPv4 (127.0.0.0/8).
    #       Return 0: any other valid addr.
    #   
    #       Eg:     addr_parse( "127.42.10.5" )
    #               is_loopback_address = 1
    #       Eg:     addr_parse( "::1" )
    #               is_loopback_address = 1
    #       Eg:     addr_parse( "192.0.2.10" )
    #               is_loopback_address = 0
    # #

	return
    {
		address             => $addr_only,              # fe80::1                                       short ip with no cidr or zone id
		addr_full           => $addr_full,              # fe80:0000:0000:0000:0000:0000:0000:0001       full ip with no cidr or zone id
		addr_zone_cidr      => $addr_zone_cidr,         # fe80::1%eth0/64                               ip with zone id and cidr
		family              => $family,                 # 6                                             4 or 6
		cidr                => $cidr,                   # 64                                            /1 - /128
		zone_id             => $zone_id,                # eth0                                          ipv6 zone / scope id (eg: fe80::1%eth0)
		iptype              => $iptype,                 # LINK-LOCAL-UNICAST                            List at https://metacpan.org/release/MANU/Net-IP-1.26/source/IP.pm
		binip               => $binip,                  # 11111110100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001
		reverse_ip          => $reverse_ip,             # 1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.e.f.ip6.arpa.
		intip               => $intip,                  # 338288524927261089654018896841347694593
		addr_network_cidr   => $addr_network_cidr,      # fe80::/64
		addr_netmask        => $addr_netmask,           # ffff:ffff:ffff:ffff:0000:0000:0000:0000
		addr_wildcard_mask  => $addr_wildcard_mask,     # <undef>                                       only ipv4
		addr_first          => $addr_first,             # fe80::
		addr_first_int      => $addr_first_int,         # 338288524927261089654018896841347694592
		addr_last           => $addr_last,              # fe80::ffff:ffff:ffff:ffff
		addr_last_int       => $addr_last_int,          # 338288524927261089672465640915057246207
		addr_range_short    => $addr_range_short,       # fe80:: - fe80::ffff:ffff:ffff:ffff
		addr_range_full     => $addr_range_full,        # fe80:0000:0000:0000:0000:0000:0000:0000 - fe80:0000:0000:0000:ffff:ffff:ffff:ffff
		addr_range_count    => $addr_range_count,       # 18446744073709551616
		bits_mask           => $cidr,                   # 64
		bits_host           => $bits_host,              # 64
		is_first_address    => $is_first_address,       # 0
		is_last_address     => $is_last_address,        # 0
		is_loopback_address => $is_loopback_address,    # 0
	};
}

# #
#   CheckIP › Addr › Get Embedded IPv4
#   
#   Get ipv4 addr inside ipv4 mapped ipv6 addr:
#       ::ffff:192.0.2.1    =>   192.0.2.1
#   
#   Accept IP in a string, or hashref from addr_parse():
#       'String':
#           my $ipv4 = ConfigServer::CheckIP::addr_get_embedded_v4(
#               "::ffff:192.0.2.1",
#           );
#   
#       'Hashref':
#           my $parsed = ConfigServer::CheckIP::addr_parse(
#               "::ffff:192.0.2.1",
#           );
#           my $ipv4 = ConfigServer::CheckIP::addr_get_embedded_v4(
#               $parsed,
#           );
#   
#   Accept ipv4 mapped ipv6 written in either format:
#       IPv6 with dotted ipv4 tail:
#           my $ipv4 = ConfigServer::CheckIP::addr_get_embedded_v4(
#               "::ffff:192.0.2.1",
#           );
#           print "$ipv4\n";       # 192.0.2.1
#   
#       IPv6 using only hexadecimal groups:
#           my $ipv4 = ConfigServer::CheckIP::addr_get_embedded_v4(
#               "0:0:0:0:0:ffff:c000:201",
#           );
#           print "$ipv4\n";       # 192.0.2.1
#   
#   @params     input           str|hashref|undef   IP str or parsed hash
#   @return     address         str|undef           Embedded IPv4 addr
#                                                       str         IPv4 addr
#                                                       undef       No embedded IPv4
# #

sub addr_get_embedded_v4
{
	my ( $input ) = @_;

	my $parsed;
	if ( ref( $input ) eq "HASH" )
	{
		$parsed = $input;
	}
	elsif ( defined( $input ) and !ref( $input ) )
	{
		$parsed = addr_parse( $input );
	}
	else
	{
		return;
	}

	return
		if ref( $parsed ) ne "HASH" or
		   !defined( $parsed->{family} ) or ref( $parsed->{family} ) or
		   $parsed->{family} ne IPV6_FAMILY;

	my $binip = $parsed->{binip};
	return
		if !defined( $binip ) or ref( $binip ) or
		   $binip !~ /\A[01]+\z/ or length( $binip ) != IPV6_BITS;

	my $iptype = addr_iptype( $binip, IPV6_FAMILY );
	return
		if !defined( $iptype ) or $iptype ne "IPV4MAP";

	my $ipv4_binary     = substr( $binip, IPV6_BITS - IPV4_BITS, IPV4_BITS );
	my @octets          = map { oct( "0b$_" ) } $ipv4_binary =~ /([01]{8})/g;

	return
		if @octets != 4;

	return join( ".", @octets );
}

# #
#   CheckIP › Addr › Is Loopback
#   
#   Check if IP is v4 or v6 loopback address.
#   
#   IPv4 loopback:  127.0.0.0/8
#   IPv6 loopback:  ::1
#   
#   @params     input           str|hashref     IP (str) or parsed (hash) from addr_parse()
#   @return     is_loopback     int             Loopback result
#                                                   1           Loopback addr
#                                                   0           Invalid / other addr
# #

sub _is_addr_loopback
{
	my ( $input ) = @_;

	my $parsed;
	if ( ref( $input ) eq "HASH" )
	{
		$parsed = $input;
	}
	elsif ( defined( $input ) and !ref( $input ) )
	{
		$parsed = addr_parse( $input );
	}
	else
	{
		return 0;
	}

	return 0
		if ref( $parsed ) ne "HASH";

	my $is_loopback = $parsed->{is_loopback_address};
	return 0
		if !defined( $is_loopback ) or ref( $is_loopback ) or
		   $is_loopback !~ /\A[01]\z/;

	return 0 + $is_loopback;
}

# #
#   CheckIP › Addr › Get IP Type
#   
#   Return IP type for a validated binary IPv4 or IPv6 addr.
#   
#   Check longest prefix first so a specific range overrides any
#   larger range that has it.
#   
#   v4 addrs without a matching special range are PUBLIC.
#   
#   @params     binip           str         Binary v4 or v6 addr
#               family          int|undef   (Optional) v4 or v6 family
#   @return     iptype          str|undef   IP type result
#                                               str         Matching IP type
#                                               undef       Invalid binary IP or family
# #

sub addr_iptype
{
	my ( $binip, $family ) = @_;

	return
		if !defined( $binip ) or ref( $binip ) or $binip !~ /\A[01]+\z/;

	if ( defined( $family ) )
	{
		return
			if ref( $family ) or ( $family ne IPV4_FAMILY and $family ne IPV6_FAMILY );
	}
	elsif ( length( $binip ) == IPV4_BITS )
	{
		$family = IPV4_FAMILY;
	}
	elsif ( length( $binip ) == IPV6_BITS )
	{
		$family = IPV6_FAMILY;
	}
	else
	{
		return;
	}

	my $bits = $family == IPV4_FAMILY ? IPV4_BITS : IPV6_BITS;
	return
		if length( $binip ) != $bits;

	my $ranges      = $family == IPV4_FAMILY
                        ? \%iptype_ipv4_ranges
                        : \%iptype_ipv6_ranges;

	my $prefixes    = $family == IPV4_FAMILY
                        ? \@iptype_ipv4_prefixes
                        : \@iptype_ipv6_prefixes;

	for my $prefix ( @{$prefixes} )
	{
		return $ranges->{$prefix}
			if index( $binip, $prefix ) == 0;
	}

	return "PUBLIC"
		if $family == IPV4_FAMILY;

	return;
}

# #
#   CheckIP › Tests
#   
#   Runs tests on checkip() and cccheckip() subs. Builds a list of
#   IPs to test with, and output a list that is used in the comments
#   of the two subs that can be copied/pasted.
#   
#   Only used by the developer to make life easier. End-user does not
#   need to mess with this.
#   
#   Runs sub { checkip() }:
#       Check for valid ipv4 and ipv6 addresses.
#       Does not require IPv4 addresses to be flagged as 'PUBLIC'.
#   
#   Runs sub { cccheckip() }:
#       Check for valid ipv4 and ipv6 addresses.
#       IPv4 addresses must be flagged by Net::IP as 'PUBLIC', or rejected.
#   
#   @tag            15.11 [CheckIP::tests_checkip()->new]
#   @usage          sudo perl -I. -MConfigServer::CheckIP -e "ConfigServer::CheckIP::tests_checkip()"
# #

sub tests_checkip
{
    my $package     = __PACKAGE__;
    my $sub_full    = ( caller( 0 ) )[3];
    my $sub_name    = $sub_full;
    $sub_name       =~ s/^.*:://;

    my $bench_start = [ Time::HiRes::gettimeofday ];
    print "\n\n";

    # #
    #   Use the same list defined in cccheckip() comment; just so I
    #   can copy/paste the updated list if I add/change an IP.
    #   
    #   Each item contains the IP, expected checkip() result, and
    #   expected cccheckip() result.
    # #

    my @ips =
    (
        [ '127.0.0.1',                  0,           0 ],
        [ '192.168.1.1',                IPV4_FAMILY, 0 ],
        [ '172.16.0.1',                 IPV4_FAMILY, 0 ],
        [ '10.0.0.1',                   IPV4_FAMILY, 0 ],
        [ '8.8.8.8',                    IPV4_FAMILY, IPV4_FAMILY ],
        [ '8.8.8.8/0',                  0,           0 ],
        [ '8.8.8.8/32',                 IPV4_FAMILY, IPV4_FAMILY ],
        [ '1.1.1.1',                    IPV4_FAMILY, IPV4_FAMILY ],
        [ '169.254.1.1',                IPV4_FAMILY, 0 ],
        [ '224.0.0.1',                  IPV4_FAMILY, 0 ],

        [ '::1',                        0,           0 ],
        [ '2001:db8::1',                IPV6_FAMILY, IPV6_FAMILY ],
        [ '2001:db8::1/0',              0,           0 ],
        [ '2001:db8::/64',              IPV6_FAMILY, IPV6_FAMILY ],
        [ '2001:db8::1/64',             IPV6_FAMILY, IPV6_FAMILY ],
        [ '2606:4700:4700::1111',       IPV6_FAMILY, IPV6_FAMILY ],
        [ '2001:4860:4860::8888',       IPV6_FAMILY, IPV6_FAMILY ],
        [ 'fc00::1',                    IPV6_FAMILY, IPV6_FAMILY ],
        [ 'fd00::1',                    IPV6_FAMILY, IPV6_FAMILY ],
        [ 'fe80::1',                    IPV6_FAMILY, IPV6_FAMILY ],
        [ 'ff02::1',                    IPV6_FAMILY, IPV6_FAMILY ],
    );

    my @failures;

    print $C{greym}, "# # ", $C{reset}, "\n";

    # #
    #   Process › sub checkip()
    #   
    #   Run each ip in the array through the subroutine checkip() and 
    #   get the detected flags and validation status.
    #   
    #   Unlike sub cccheckip(), checkip() does not require IPv4
    #   addresses to be classified as 'PUBLIC' by addr_iptype().
    # #

    my $first = 1;
    foreach my $test ( @ips )
    {
        my ( $ip, $expected ) = @{$test}[ 0, 1 ];
        my ( $addr )        = split( /\//, $ip, 2 );
        my $parsed          = addr_parse( $addr );

        # #
        #   List of possible ipv4 and ipv6 value types:
        #   
        #   @ref        https://metacpan.org/release/MANU/Net-IP-1.26/source/IP.pm
        # #

        my $type            = ref( $parsed ) eq "HASH" ? $parsed->{iptype} : "INVALID";

        $type = "PREFIX ZERO DISALLOWED"
            if $ip =~ m{/0\z};

        my $check_res       = checkip( $ip );
        my $status          = $check_res ? "accept" : "reject";
        my $result          = "($status / $type)";
        my $test_status     = $check_res == $expected ? "PASS" : "FAIL";
        my $prefix          = $first ? "#   \@checkip    " : "#               ";
        my $color           = $check_res ? $C{greenl} : $C{redm};
        my $test_color      = $test_status eq "PASS" ? $C{greenl} : $C{redm};

        printf "%s%s%s%s%-24s%s%s%-8d%s%s%-35s%s%s%s%s\n",
            $C{greym},      $prefix,
            $C{reset},
            $C{greyl},      $ip,
            $C{reset},
            $color,         $check_res,
            $C{reset},
            $color,         $result,
            $C{reset},
            $test_color,    $test_status,
            $C{reset};

        push( @failures, qq{checkip("$ip") returned $check_res, expected $expected} )
            if $test_status eq "FAIL";

        $first = 0;
    }

    print $C{greym}, "#   ", $C{reset}, "\n";

    # #
    #   Process › sub cccheckip()
    #   
    #   Run each ip in the array through the subroutine cccheckip() and 
    #   get the detected flags and validation status.
    #   
    #   IPv4 addresses are classified using addr_iptype() and must be
    #   flagged as 'PUBLIC' to be accepted.
    # #

    $first = 1;
    foreach my $test ( @ips )
    {
        my ( $ip, $expected ) = @{$test}[ 0, 2 ];
        my ( $addr )        = split( /\//, $ip, 2 );
        my $parsed          = addr_parse( $addr );
        my $type            = ref( $parsed ) eq "HASH" ? $parsed->{iptype} : "INVALID";

        $type = "PREFIX ZERO DISALLOWED"
            if $ip =~ m{/0\z};

        my $ccip            = $ip;
        my $cccheckip       = cccheckip( \$ccip );
        my $status          = $cccheckip ? "accept" : "reject";
        my $result          = "($status / $type)";
        my $test_status     = $cccheckip == $expected ? "PASS" : "FAIL";
        my $prefix          = $first ? "#   \@cccheckip  " : "#               ";
        my $color           = $cccheckip ? $C{greenl} : $C{redm};
        my $test_color      = $test_status eq "PASS" ? $C{greenl} : $C{redm};

        printf "%s%s%s%s%-24s%s%s%-8d%s%s%-35s%s%s%s%s\n",
            $C{greym},      $prefix,
            $C{reset},
            $C{greyl},      $ip,
            $C{reset},
            $color,         $cccheckip,
            $C{reset},
            $color,         $result,
            $C{reset},
            $test_color,    $test_status,
            $C{reset};

        push( @failures, qq{cccheckip("$ip") returned $cccheckip, expected $expected} )
            if $test_status eq "FAIL";

        $first = 0;
    }

    print $C{greym}, "#   ", $C{reset}, "\n";

    if ( @failures )
    {
        die join( "\n", @failures ), "\n";
    }

    # #
    #   I'm lazy; print the command to re-generate the list.
    # #

    my $include             = -e "./ConfigServer/CheckIP.pm" ? "." : "..";
    my $benchmark_elapsed   = Time::HiRes::tv_interval( $bench_start );
    printf "%s%-15s%s %s%s%s\n",
        $C{greym},      "# \@usage",
        $C{reset},
        $C{orangem},    "perl -I$include -M$package -e \"$package\::$sub_name( )\"",
        $C{reset};
    print $C{greym}, "# # ", $C{reset}, "\n";

    print "\n\n";

    printf "     %s%-10s%s %s%s%s\n",
        $C{greym},      "OS:",
        $C{reset},
        $C{orangem},    "$^O",
        $C{reset};

    printf "     %s%-10s%s %s%s%s\n",
        $C{greym},      "Sub:",
        $C{reset},
        $C{orangem},    "$sub_name()",
        $C{reset};

    printf "     %s%-10s%s %s%s%s\n",
        $C{greym},      "Command:",
        $C{reset},
        $C{orangem},    "perl -I$include -M$package -e \"$package\::$sub_name( )\"",
        $C{reset};

    printf "     %s%-10s%s %s%.4f seconds%s ( %s%.2f ms%s )\n",
        $C{greym},      "Elapsed:",
        $C{reset},
        $C{greenm},     $benchmark_elapsed,
        $C{reset},
        $C{greenm},     $benchmark_elapsed * 1000,
        $C{reset};

    print "\n\n";
}

1;