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
package ConfigServer::Sanity;

use strict;
use lib '/usr/local/csf/lib';
use Fcntl qw(:DEFAULT :flock);
use Carp;
use ConfigServer::Config;

use Exporter qw(import);
our $VERSION     = 1.02;
our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(sanity);

my %sanity;
my %sanitydefault;
my $sanityfile = "/usr/local/csf/lib/sanity.txt";

open (my $IN, "<", $sanityfile);
flock ($IN, LOCK_SH);
my @data = <$IN>;
close ($IN);
chomp @data;
foreach my $line (@data) {
	my ($name,$value,$def) = split(/\=/,$line);
	$sanity{$name} = $value;
	$sanitydefault{$name} = $def;
}

my $config = ConfigServer::Config->loadconfig();
my %config = $config->config();

if ($config{IPSET}) {
	delete $sanity{"DENY_IP_LIMIT"};
	delete $sanitydefault{"DENY_IP_LIMIT"};
}

# end main
###############################################################################
# start sanity
sub sanity {
	my $sanity_item = shift;
	my $sanity_value = shift;
	my $insane = 0;

	$sanity_item =~ s/\s//g;
	$sanity_value =~ s/\s//g;

	if (defined $sanity{$sanity_item}) {
		$insane = 1;
		foreach my $check (split(/\|/,$sanity{$sanity_item})) {
			if ($check =~ /-/) {
				my ($from,$to) = split(/\-/,$check);
				if (($sanity_value >= $from) and ($sanity_value <= $to)) {$insane = 0}

			} else {
				if ($sanity_value eq $check) {$insane = 0}
			}
		}
		$sanity{$sanity_item} =~ s/\|/ or /g;
	}
	return ($insane,$sanity{$sanity_item},$sanitydefault{$sanity_item});
}
# end sanity
###############################################################################

1;