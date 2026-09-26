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
#   @updated            09.26.2026
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
#   @usage          perl -I. -MConfigServer::CheckIP -e "ConfigServer::CheckIP::tests_checkip()"
# #

# #
#   CheckIP › Summary
#   
#   This module contains the following subs:
#   
#   1.  checkip():
#           Check for valid ipv4 and ipv6 addresses.
#           Does not require IPv4 addresses to be flagged as 'PUBLIC'.
#   
#   2.  cccheckip():
#           Check for valid ipv4 and ipv6 addresses.
#           IPv4 addresses must be flagged by Net::IP as 'PUBLIC', or rejected.
#           Similar to checkip(); but performs an additional check on
#               IPv4 addresses using Net::IP.
#   
#   3.  tests_checkip():
#           Test suite to test functionality for subs in this module.
#           Used to generate the list of ipv4 and ipv6 output examples
#               in the subroutine comments.
# #

# #
#   CheckIP › Changelog Notes
#   
#   @tag            15.11 [CheckIP::core->cidr-prefix]
#   @change         CIDR prefix /0 treated as false by Perl and bypassed the
#                   CIDR range check.
#                       checkip( '192.168.1.1/0' )  => pass / returned 4 (int)
#                       checkip( '2001:db8::1/0' )  => pass / returned 6 (int)
#                   
#                   /0 prefix used directly in firewall rules could match entire
#                   IPv4 or IPv6 address space, potentially blocking all IPs.
#                       IPv4:       Firewall Rule:  44.252.80.5/0
#                                   Blocks:         0.0.0.0 - 255.255.255.255
#   
#                       IPv6:       Firewall Rule:  2001:db8::1/0
#                                   Blocks:         0000:0000:0000:0000:0000:0000:0000:0000
#                                                   ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
#   
#                   CSF >= v15.11 validates provided CIDR values, rejects
#                   IPv4 and IPv6 /0 prefix lengths.
#                       CSF <= v15.10:      if ( $cidr )
#                       CSF >= v15.11:      if ( $cidr ne "" )
# #

## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
package ConfigServer::CheckIP;

use strict;
use lib '/usr/local/csf/lib';
use Carp;
use Net::IP;
use Time::HiRes qw( gettimeofday tv_interval );
use ConfigServer::Config;

# #
#	CheckIP › Declare › Export
# #

use Exporter    qw( import );
our @EXPORT_OK  = qw( checkip cccheckip );

# # 
#	CheckIP › Declare › Version
# #

our $VERSION    = 15.11;

# #
#   CheckIP › Declare › IP Regex
# #

my $ipv4reg     = ConfigServer::Config->ipv4reg;
my $ipv6reg     = ConfigServer::Config->ipv6reg;

# #
#	CheckIP › Constants › Generic
#   
#   The following constants can all be created in the same block
#   without a need for each other.
#   
#   Should really be no need to modify these.
# #

use constant
{
    _PRINT_SEP_LENGTH       => 140
};

# #
#	CheckIP › Define › Colors
# #

my %C =
(
    reset               => "\e[0m",
    bold                => "\e[1m",
    dim                 => "\e[2m",
	white               => "\e[37m",
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
	greend   	        => "\e[38;5;22m",

	strength_poor       => "\e[38;5;197m",
	strength_weak       => "\e[38;5;202m",
	strength_ok         => "\e[38;5;214m",
	strength_good      	=> "\e[38;5;184m",
	strength_strong    	=> "\e[38;5;47m",
	strength_excellent 	=> "\e[38;5;40m",
	strength_insane     => "\e[38;5;28m"
);

# #
#	CheckIP › Helper › Debug Prints
#   
#   Handles debug prints a little differently than standard prints.
#   
#   Does not run specified code unless DEBUG level is set high enough.
#   
#   See @note below about potential performance issue.
#   
#   @note           Code inside the callback is NOT executed when DEBUG
#                   is lower than the defined debug level.
#   
#                   For debug calls inside very large loops; use outer
#                   ( DEBUG >= level ) check to avoid calling
#                   sub _debug() millions of times; impacting 
#                   performance.
#   
#   @usage          _debug( 1, sub
#                   {
#                       my ( $print ) = @_;
#                       $print->(
#                           $C{white},      "Debug message"
#                       );
#                   });
#   
#   @param          level           num         minimum DEBUG level required
#   @param          code            code        callback containing debug-only code
#                                                   receives $print callback
#   @return                                     undef
# #

my $debug;

sub _debug
{
    my ( $level, $code ) = @_;

    # #
    #   $debug not defined; grab the setting from csf.conf
    #       DEBUG = "1"
    # #

    if ( !defined $debug )
    {
        $debug = ConfigServer::Config->getsingle( "DEBUG" ) // 0;
    }

    return if $debug < $level;

    my $print = sub
    {
        my ( @message ) = @_;
        print STDERR " ",
            $C{purpled},    "[DEBUG]",
            $C{greyd},      "[",
            $C{purpled},    $level,
            $C{greyd},      "] ",
            @message,
            $C{reset},      "\n";
    };

    $code->( $print );

    return;
}

# #
#   CheckIP › Subroutine › checkip()
#   
#   Validate IPv4 and IPv6 addresses.
#   
#   Reject IPv4 127.0.0.1, IPv6 ::1, invalid addresses, and invalid
#   CIDR prefix lengths.
#   
#   Accepts string or scalarref.
#   Accepts standard notation and CIDR notation (optional)
#       CIDR can only have digits.
#   
#   @ranges         ipv4                    /1 - /32
#                   ipv6                    /1 - /128
#   
#   @checkip()      127.0.0.1               0       (reject / LOOPBACK)
#                   192.168.1.1             4       (accept / PRIVATE)
#                   172.16.0.1              4       (accept / PRIVATE)
#                   10.0.0.1                4       (accept / PRIVATE)
#                   8.8.8.8                 4       (accept / PUBLIC)
#                   8.8.8.8/0               0       (reject / INVALID)
#                   8.8.8.8/32              4       (accept / PUBLIC)
#                   1.1.1.1                 4       (accept / PUBLIC)
#                   169.254.1.1             4       (accept / LINK-LOCAL)
#                   224.0.0.1               4       (accept / MULTICAST)
#                   ::1                     0       (reject / LOOPBACK)
#                   2001:db8::1             6       (accept / DOCUMENTATION)
#                   2001:db8::1/0           0       (reject / INVALID)
#                   2001:db8::/64           6       (accept / DOCUMENTATION)
#                   2001:db8::1/64          6       (accept / INVALID)
#                   2606:4700:4700::1111    6       (accept / GLOBAL-UNICAST)
#                   2001:4860:4860::8888    6       (accept / GLOBAL-UNICAST)
#                   fc00::1                 6       (accept / UNIQUE-LOCAL-UNICAST)
#                   fd00::1                 6       (accept / UNIQUE-LOCAL-UNICAST)
#                   fe80::1                 6       (accept / LINK-LOCAL-UNICAST)
#                   ff02::1                 6       (accept / MULTICAST)
#   
#   @param          ipin            str|scalarref   v4 / v6 address or CIDR to validate
#   @return                         num             IP validation status
#                                                   0   = invalid / reject
#                                                   4   = valid IPv4 / accept
#                                                   6   = valid IPv6 / accept
# #

sub checkip
{
	my $ipin    = shift;
	my $ret     = 0;
	my $ipref   = 0;
	my $ip;
	my $cidr;

    # #
    #   Input › Parse IP or CIDR
    #   
    #   Accept both a string or scalarref.
    #   
    #   Split IP from CIDR prefix (optional); track when passed by ref.
    # #

	if ( ref $ipin )
    {
		( $ip, $cidr )  = split( /\//, ${$ipin} );
		$ipref          = 1;
	}
    else
    {
		( $ip, $cidr )  = split( /\//, $ipin );
	}

    # #
    #   $ip modified later, preserve original IP
    #   
    #   $ipv6reg condition removes all colons and leading zeros
    #   from $ip
    # # 

	my $testip = $ip;

    # #
    #   CIDR value provided; must only have digits
    # #

	if ( $cidr ne "" )
    {
		if ( $cidr !~ /^\d+$/ )
        {
            return 0
        }
	}

    # #
    #   IPv4 › Regex
    # #

	if ( $ip =~ /^$ipv4reg$/ )
    {
		$ret = 4;

        # #
        #   IPv4 › CIDR Prefix Length
        #   
        #   Reject prefix lower than /1
        #   Reject prefix higher than /32
        #   
        #   @note       See [15.11 [CheckIP::core->cidr-prefix]]
        # #

		if ( $cidr ne "" )
        {
			if ( $cidr < 1 || $cidr > 32 )
            {
                return 0
            }
		}

        # #
        #   IPv4 › Reject Localhost loopback address
        # #

		if ( $ip eq "127.0.0.1" )
        {
            return 0
        }
	}

    # #
    #   IPv6 › Regex
    # #

	if ( $ip =~ /^$ipv6reg$/ )
    {
		$ret = 6;

        # #
        #   IPv6 › CIDR Prefix Length
        #   
        #   Reject prefix lower than /1
        #   Reject prefix higher than /128
        #   
        #   @note       See [15.11 [CheckIP::core->cidr-prefix]]
        # #

		if ( $cidr ne "" )
        {
            if ( $cidr < 1 || $cidr > 128 )
            {
                return 0
            }
		}

        # #
        #   IPv6 › Reject loopback address ::1
        # #

		$ip =~ s/://g;          # remove all colons
		$ip =~ s/^0*//g;        # remove leading zeros
		if ( $ip eq "1" )
        {
            return 0
        }

        # #
        #   IPv6 › Scalar Reference
        #   
        #   If passed by reference, shorten IPv6 address using Net::IP
        #   Update original value; preserve CIDR if provided.
        # #

		if ( $ipref )
        {
			eval {
				local $SIG{__DIE__} = undef;
				my $netip           = Net::IP->new( $testip );
				my $myip            = $netip->short( );

				if ( $myip ne "" )
                {
					if ( $cidr eq "" )
                    {
						${$ipin} = $myip;
					}
                    else
                    {
						${$ipin} = $myip . "/" . $cidr;
					}
				}
			};

            # #
            #   IPv6 › Net::IP Threw an Error
            # #

			if ( $@ )
            {
                return 0
            }
		}
	}

	return $ret;
}

# #
#   CheckIP › Subroutine › cccheckip()
#   
#   Validate IPv4 and IPv6 addresses.
#   
#   Reject IPv4 127.0.0.1, IPv6 ::1, invalid addresses, and invalid
#   CIDR prefix lengths.
#   
#   IPv4 addresses must also be flagged as PUBLIC by Net::IP.
#   IPv6 addresses do not simply return PUBLIC by Net::IP.
#   
#   Accepts string or scalarref.
#   Accepts standard notation and CIDR notation (optional)
#       CIDR can only have digits.
#   
#   @ranges         ipv4                    /1 - /32
#                   ipv6                    /1 - /128
#   
#   @cccheckip()    127.0.0.1               0       (reject / LOOPBACK)
#                   192.168.1.1             0       (reject / PRIVATE)
#                   172.16.0.1              0       (reject / PRIVATE)
#                   10.0.0.1                0       (reject / PRIVATE)
#                   8.8.8.8                 4       (accept / PUBLIC)
#                   8.8.8.8/0               0       (reject / INVALID)
#                   8.8.8.8/32              4       (accept / PUBLIC)
#                   1.1.1.1                 4       (accept / PUBLIC)
#                   169.254.1.1             0       (reject / LINK-LOCAL)
#                   224.0.0.1               0       (reject / MULTICAST)
#                   ::1                     0       (reject / LOOPBACK)
#                   2001:db8::1             6       (accept / DOCUMENTATION)
#                   2001:db8::1/0           0       (reject / INVALID)
#                   2001:db8::/64           6       (accept / DOCUMENTATION)
#                   2001:db8::1/64          6       (accept / INVALID)
#                   2606:4700:4700::1111    6       (accept / GLOBAL-UNICAST)
#                   2001:4860:4860::8888    6       (accept / GLOBAL-UNICAST)
#                   fc00::1                 6       (accept / UNIQUE-LOCAL-UNICAST)
#                   fd00::1                 6       (accept / UNIQUE-LOCAL-UNICAST)
#                   fe80::1                 6       (accept / LINK-LOCAL-UNICAST)
#                   ff02::1                 6       (accept / MULTICAST)
#   
#                   List below generated from sub { tests_checkip }
#                       perl -I. -MConfigServer::CheckIP -e "ConfigServer::CheckIP::tests_checkip()"
#   
#   @param          ipin            str|scalarref   v4 / v6 address or CIDR to validate
#   @return                         num             IP validation status
#                                                   0   = invalid / reject
#                                                   4   = valid IPv4 / accept
#                                                   6   = valid IPv6 / accept
# #

sub cccheckip
{
	my $ipin    = shift;
	my $ret     = 0;
	my $ipref   = 0;
	my $ip;
	my $cidr;

    # #
    #   Input › Parse IP or CIDR
    #   
    #   Accept both a string or scalarref.
    #   
    #   Split IP from CIDR prefix (optional); track when passed by ref.
    # #

	if ( ref $ipin )
    {
		( $ip, $cidr )  = split( /\//, ${$ipin} );
		$ipref          = 1;
	}
    else
    {
		( $ip, $cidr )  = split( /\//, $ipin );
	}

    # #
    #   $ip modified later, preserve original IP
    #   
    #   $ipv6reg condition removes all colons and leading zeros
    #   from $ip
    # # 

	my $testip = $ip;

    # #
    #   CIDR value provided; must only have digits
    # #

	if ( $cidr ne "" )
    {
		if ( $cidr !~ /^\d+$/ )
        {
            return 0
        }
	}

    # #
    #   IPv4 › Regex
    # #

	if ( $ip =~ /^$ipv4reg$/ )
    {
		$ret = 4;

        # #
        #   IPv4 › CIDR Prefix Length
        #   
        #   Reject prefix lower than /1
        #   Reject prefix higher than /32
        #   
        #   @note       See [15.11 [CheckIP::core->cidr-prefix]]
        # #

		if ( $cidr ne "" )
        {
			if ( $cidr < 1 || $cidr > 32 )
            {
                return 0
            }
		}

        # #
        #   IPv4 › Reject Localhost loopback address
        # #

		if ( $ip eq "127.0.0.1" )
        {
            return 0
        }

		my $type;

		eval {
			local $SIG{__DIE__} = undef;
			my $netip           = Net::IP->new( $testip );
			$type               = $netip->iptype( );
		};

        # #
        #   IPv4 › Net::IP Threw an Error
        # #

		if ( $@ )
        {
            return 0
        }
    
		if ( $type ne "PUBLIC" )
        {
            return 0
        }
	}

    # #
    #   IPv6 › Regex
    # #

	if ( $ip =~ /^$ipv6reg$/ )
    {
		$ret = 6;

        # #
        #   IPv6 › CIDR Prefix Length
        #   
        #   Reject prefix lower than /1
        #   Reject prefix higher than /128
        #   
        #   @note       See [15.11 [CheckIP::core->cidr-prefix]]
        # #

		if ( $cidr ne "" )
        {
            if ( $cidr < 1 || $cidr > 128 )
            {
                return 0
            }
		}

        # #
        #   IPv6 › Reject loopback address ::1
        # #

		$ip =~ s/://g;          # remove all colons
		$ip =~ s/^0*//g;        # remove leading zeros
		if ( $ip eq "1" )
        {
            return 0
        }

        # #
        #   IPv6 › Scalar Reference
        #   
        #   If passed by reference, shorten IPv6 address using Net::IP
        #   Update original value; preserve CIDR if provided.
        # #

		if ( $ipref )
        {
			eval {
				local $SIG{__DIE__} = undef;
				my $netip           = Net::IP->new( $testip );
				my $myip            = $netip->short( );

				if ( $myip ne "" )
                {
					if ( $cidr eq "" )
                    {
						${$ipin} = $myip;
					}
                    else
                    {
						${$ipin} = $myip . "/" . $cidr;
					}
				}
			};

            # #
            #   IPv6 › Net::IP Threw an Error
            # #

			if ( $@ )
            {
                return 0
            }
		}
	}

	return $ret;
}

# #
#   CheckIP › Tests
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
#   @usage          perl -I. -MConfigServer::CheckIP -e "ConfigServer::CheckIP::tests_checkip()"
# #

sub tests_checkip
{

    my $package     = __PACKAGE__;
    my $sub_full    = ( caller( 0 ) )[3];
    my $sub_name    = $sub_full;
    $sub_name       =~ s/^.*:://;

    my $benchmark_start = [ gettimeofday ];
    print "\n\n";

    # #
    #   Use the same list defined in cccheckip() comment; just so I
    #   can copy/paste the updated list if I add/change an IP.
    # #

    my @ips =
    (
        '127.0.0.1',
        '192.168.1.1',
        '172.16.0.1',
        '10.0.0.1',
        '8.8.8.8',
        '8.8.8.8/0',
        '8.8.8.8/32',
        '1.1.1.1',
        '169.254.1.1',
        '224.0.0.1',

        '::1',
        '2001:db8::1',
        '2001:db8::1/0',
        '2001:db8::/64',
        '2001:db8::1/64',
        '2606:4700:4700::1111',
        '2001:4860:4860::8888',
        'fc00::1',
        'fd00::1',
        'fe80::1',
        'ff02::1',
    );

    print $C{greym}, "# # ", $C{reset}, "\n";

    # #
    #   Process › sub checkip()
    #   
    #   Run each ip in the array through the subroutine checkip() and 
    #   get the detected flags and validation status.
    #   
    #   Unlike sub cccheckip(), checkip() does not require IPv4
    #   addresses to be classified as 'PUBLIC' by Net::IP.
    # #

    my $first = 1;
    foreach my $ip ( @ips )
    {
        my $netip       = Net::IP->new( $ip );
        my $type        = $netip ? $netip->iptype( ) : "INVALID";
        my $check_ip    = $ip;
        my $checkip     = checkip( \$check_ip );
        my $status      = $checkip ? "accept" : "reject";
        my $prefix      = $first ? "#   \@checkip()      " : "#                   ";
        my $color       = $checkip ? $C{greenl} : $C{redl};

        printf "%s%s%s%s%-24s%s%s%-8d%s%s(%s / %s)%s\n",
            $C{greym},      $prefix,
            $C{reset},
            $C{fucsial},    $ip,
            $C{reset},
            $color,         $checkip,
            $C{reset},
            $color,         $status, $type,
            $C{reset};

        $first = 0;
    }

    print $C{greym}, "#   ", $C{reset}, "\n";

    # #
    #   Process › sub cccheckip()
    #   
    #   Run each ip in the array through the subroutine cccheckip() and 
    #   get the detected flags and validation status.
    #   
    #   IPv4 addresses are classified using Net::IP and must be
    #   flagged as 'PUBLIC' to be accepted.
    # #

    $first = 1;
    foreach my $ip ( @ips )
    {
        my $netip       = Net::IP->new( $ip );
        my $type        = $netip ? $netip->iptype( ) : "INVALID";
        my $ccip        = $ip;
        my $cccheckip   = cccheckip( \$ccip );
        my $status      = $cccheckip ? "accept" : "reject";
        my $prefix      = $first ? "#   \@cccheckip()    " : "#                   ";
        my $color       = $cccheckip ? $C{greenl} : $C{redl};

        printf "%s%s%s%s%-24s%s%s%-8d%s%s(%s / %s)%s\n",
            $C{greym},      $prefix,
            $C{reset},
            $C{fucsial},    $ip,
            $C{reset},
            $color,         $cccheckip,
            $C{reset},
            $color,         $status, $type,
            $C{reset};

        $first = 0;
    }

    print $C{greym}, "#   ", $C{reset}, "\n";

    # #
    #   I'm lazy; print the command to re-generate the list.
    # #

    my $include             = -e "./ConfigServer/CheckIP.pm" ? "." : "..";
    my $benchmark_elapsed   = tv_interval( $benchmark_start );
    printf "%s%-16s%s %s%s%s\n",
        $C{greym},      "#   \@usage         ",
        $C{reset},
        $C{orangem},    "perl -I$include -M$package -e \"$package\::$sub_name( )\"",
        $C{reset};
    print $C{greym}, "# # ", $C{reset}, "\n";

    print "\n\n";

    printf "    %s%-15s%s %s%s%s\n",
        $C{greym},      "OS:",
        $C{reset},
        $C{orangem},    "$^O",
        $C{reset};

    printf "    %s%-15s%s %s%s%s\n",
        $C{greym},      "Subroutine:",
        $C{reset},
        $C{orangem},    "$sub_name()",
        $C{reset};

    printf "    %s%-15s%s %s%s%s\n",
        $C{greym},      "Command:",
        $C{reset},
        $C{orangem},    "perl -I$include -M$package -e \"$package\::$sub_name( )\"",
        $C{reset};

    printf "    %s%-15s%s %s%.4f seconds%s ( %s%.2f ms%s )\n",
        $C{greym},      "Elapsed:",
        $C{reset},
        $C{greenm},     $benchmark_elapsed,
        $C{reset},
        $C{greenm},     $benchmark_elapsed * 1000,
        $C{reset};

    print "\n\n";
}

1;