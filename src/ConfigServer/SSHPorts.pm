# #
#   @app                ConfigServer Security & Firewall (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.dev
#   @docs               https://docs.configserver.dev
#   @download           https://download.configserver.dev
#   @repo               https://github.com/Aetherinox/csf-firewall
#   @copyright          Copyright (C) 2025-2026 Aetherinox
#   @license            GPLv3
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
#   Detects the TCP port(s) the SSH daemon listens on.
#
#   Older code only read "Port" from /etc/ssh/sshd_config. Current distros
#   (Debian 12/13, Ubuntu 22.04+, Plesk, cloud images) usually set the port in
#   /etc/ssh/sshd_config.d/*.conf or use systemd socket activation, so the
#   custom port was missed and admins could be locked out once TESTING was
#   turned off.
#
#   Sources, in order:
#       1. sshd -T (effective config; resolves Include and Match defaults)
#       2. sshd_config plus any Include'd files (Port / ListenAddress)
#       3. systemd ssh.socket / sshd.socket ListenStream overrides
# #

package ConfigServer::SSHPorts;

use strict;
use warnings;
use File::Glob qw(bsd_glob);
use Exporter qw(import);

our $VERSION   = 1.00;
our @EXPORT_OK = qw(sshports);

sub _valid_port
{
	my $port = shift;
	return ( defined $port and $port =~ /^\d+$/ and $port > 0 and $port < 65536 );
}

sub _from_sshd_t
{
	my %ports;
	foreach my $bin ( "/usr/sbin/sshd", "/usr/bin/sshd", "/sbin/sshd" )
	{
		next unless -x $bin;
		my @out = `$bin -T 2>/dev/null`;
		next if $?;
		foreach my $line ( @out )
		{
			if ( $line =~ /^port\s+(\d+)\s*$/i ) { $ports{$1} = 1 }
			elsif ( $line =~ /^listenaddress\s+\S*:(\d+)\s*$/i ) { $ports{$1} = 1 }
		}
		last;
	}
	return keys %ports;
}

sub _parse_config
{
	my ( $file, $ports, $seen, $depth ) = @_;
	return if $depth > 8 or $seen->{$file}++;

	open( my $IN, "<", $file ) or return;
	my @lines = <$IN>;
	close( $IN );

	foreach my $line ( @lines )
	{
		$line =~ s/#.*$//;
		$line =~ s/^\s+|\s+$//g;
		next if $line eq "";

		# Settings inside a Match block only apply conditionally; stop there
		last if $line =~ /^Match\s/i;

		if ( $line =~ /^Port\s*=?\s*(\d+)$/i )
		{
			$ports->{$1} = 1;
		}
		elsif ( $line =~ /^ListenAddress\s+\S*:(\d+)$/i )
		{
			$ports->{$1} = 1;
		}
		elsif ( $line =~ /^Include\s+(.+)$/i )
		{
			foreach my $pattern ( split( /\s+/, $1 ) )
			{
				$pattern = "/etc/ssh/$pattern" unless $pattern =~ m{^/};
				foreach my $inc ( sort( bsd_glob( $pattern ) ) )
				{
					_parse_config( $inc, $ports, $seen, $depth + 1 );
				}
			}
		}
	}
	return;
}

sub _from_socket_units
{
	my %ports;
	my @files;
	foreach my $unit ( "ssh.socket", "sshd.socket" )
	{
		foreach my $dir ( "/etc/systemd/system", "/run/systemd/system", "/run/systemd/generator", "/usr/lib/systemd/system", "/lib/systemd/system" )
		{
			push @files, "$dir/$unit" if -f "$dir/$unit";
			push @files, sort( bsd_glob( "$dir/$unit.d/*.conf" ) );
		}
	}

	foreach my $file ( @files )
	{
		open( my $IN, "<", $file ) or next;
		while ( my $line = <$IN> )
		{
			# An empty ListenStream= resets earlier values in drop-ins
			if ( $line =~ /^\s*ListenStream\s*=\s*$/ ) { %ports = () }
			elsif ( $line =~ /^\s*ListenStream\s*=\s*(?:\S*:)?(\d+)\s*$/ ) { $ports{$1} = 1 }
		}
		close( $IN );
	}
	return keys %ports;
}

# #
#   Returns a sorted, de-duplicated list of SSH ports. Falls back to 22.
# #

sub sshports
{
	my %ports = map { $_ => 1 } _from_sshd_t();

	unless ( %ports )
	{
		_parse_config( "/etc/ssh/sshd_config", \%ports, {}, 0 );
	}

	# Socket activation overrides sshd's own Port setting
	my @socket = _from_socket_units();
	if ( @socket and ( -e "/etc/systemd/system/sockets.target.wants/ssh.socket" or -e "/etc/systemd/system/sockets.target.wants/sshd.socket" ) )
	{
		%ports = map { $_ => 1 } @socket;
	}

	my @ports = sort { $a <=> $b } grep { _valid_port( $_ ) } keys %ports;
	@ports = ( "22" ) unless @ports;
	return @ports;
}

1;
