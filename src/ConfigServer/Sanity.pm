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
#   @updated            03.05.2026
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
package ConfigServer::Sanity;

use strict;
use lib '/usr/local/csf/lib';
use Fcntl qw(:DEFAULT :flock);
use Carp;
use ConfigServer::Config;

# #
#	Sanity.pm › Declare › Version
# #

our $VERSION 	= 15.10;

# #
#	URLGet.pm › Declare › Config
# #

my $config_obj	= ConfigServer::Config->loadconfig();
my %config 		= $config_obj->config();

# #
#	Sanity.pm › Declare › Generic
# #

my %sanity_current;
my %sanity_default;
my $sanity_file = "/usr/local/csf/lib/sanity.txt";

# #
#	Sanity.pm › Open /etc/csf/sanity.txt
# #

{
    open my $IN, '<', $sanity_file or croak "Cannot open $sanity_file: $!";
    flock $IN, LOCK_SH;
    chomp( my @data = <$IN> );
    close $IN;

    for my $line ( @data )
	{
        my ( $name, $value, $def ) 	= split /=/, $line, 3;
        $sanity_current{$name}	= $value;
        $sanity_default{$name}	= $def;
    }
}

# #
#	Sanity.pm › Remove DENY_IP_LIMIT if IPSET enabled
# #

if ( $config{IPSET} )
{
	delete $sanity_current{"DENY_IP_LIMIT"};
	delete $sanity_default{"DENY_IP_LIMIT"};
}

# #
#	Sanity.pm › Sanity
# #

sub sanity
{
	my $ident		= shift;
	my $value 		= shift;
	my $insane		= 0;

	$ident 			=~ s/\s//g;
	$value 			= '' unless defined $value;
	$value 			=~ s/\s//g;

	if ( defined $sanity_current{$ident} )
	{
		$insane = 1;
		foreach my $check ( split(/\|/, $sanity_current{$ident} ) )
		{
			if ($check =~ /-/)
			{
				my ( $from,$to) = split( /\-/, $check );
				if ( ( $value >= $from ) and ( $value <= $to ) ) { $insane = 0 }
			}
			else
			{
				if ( $value eq $check) { $insane = 0 }
			}
		}
	
		$sanity_current{$ident} =~ s/\|/ or /g;
	}

	return ( $insane, $sanity_current{$ident}, $sanity_default{$ident} );
}

1;