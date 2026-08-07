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
package ConfigServer::URLGet;

use strict;
use warnings;
use lib '/usr/local/csf/lib';
use Fcntl qw(:DEFAULT :flock);
use Carp;
use IPC::Open3;
use ConfigServer::Config;
use ConfigServer::Logger;

# #
#	URLGet.pm › Declare › Version
# #

our $VERSION 	= 15.10;

# #
#	URLGet.pm › Declare › Config
# #

my $config		= ConfigServer::Config->loadconfig();
my %config 		= $config->config();

# #
#	URLGet.pm › Declare › Generic
# #

my $agent 		= "ConfigServer $VERSION";
my $option 		= 1;
my $proxy 		= "";
$SIG{PIPE} 		= 'IGNORE';

# #
#	URLGet.pm › Redact sensitive query params
#	
#	Prevent license/API secrets from being exposed in URLs.
#	Case-insensitive.
#	
#	Monitored params:		key, license, secret, secrets
#	Example:				https://url.tld/?license=key-here => https://domain.tld/?license=REDACTED
# #

sub _url_sanitize
{
	my ( $url ) = @_;
	return '' unless defined $url && $url ne '';

	my $safe = $url;

	$safe =~ s{
		([?&#])
		(key|license|secret|secrets|token|access_token|refresh_token|apikey|api_key|auth|authorization|password|passwd|pwd)
		=
		([^&#]*)
	}{$1$2=REDACTED}gix;

	return $safe;
}

# #
#	URLGet.pm › Method › HTTP::Tiny (1)
# #

sub _method_tiny
{
	my $url 		= shift;
	my $file 		= shift;
	my $quiet 		= shift;
	my $status		= 0;
	my $timeout		= 1200;

	if ( $proxy eq "" ) { undef $proxy }

	my $ua = HTTP::Tiny->new(
		'agent' 	=> $agent,
		'timeout' 	=> 300,
		'proxy' 	=> $proxy
		);
	
	my $res;
	my $text;

	( $status, $text ) = eval
	{
		local $SIG{__DIE__} 	= undef;
		local $SIG{'ALRM'} 		= sub { die "Download timeout after $timeout seconds" };
	
		alarm( $timeout );

		if ( $file )
		{
			local $|=1;
			my $expected_length;
			my $bytes_received 	= 0;
			my $per 			= 0;
			my $oldper 			= 0;
	
			open ( my $OUT, ">", "$file\.tmp" ) or return ( 1, "Unable to open $file\.tmp: $!" );
			flock ( $OUT, LOCK_EX );
			binmode ( $OUT );

			$res = $ua->request( 'GET', $url,
			{
				data_callback => sub
				{
					my( $chunk, $res ) = @_;
					$bytes_received += length( $chunk );
	
					if ( !defined $expected_length )
					{
						$expected_length = $res->{headers}->{ 'content-length' } or 0;
					}
	
					if ( $expected_length )
					{
						my $per = int( 100 * $bytes_received / $expected_length );
						if ( ( int( $per / 5 ) == $per / 5 ) and ( $per != $oldper ) and !$quiet )
						{
							print "...$per\%\n";
							$oldper = $per;
						}
					}
					else
					{
						if ( ! $quiet ) { print "." }
					}
	
					print $OUT $chunk;
				}
			});

			close ( $OUT );
			if ( ! $quiet ) { print "\n" }
		}
		else
		{
			$res = $ua->request( 'GET', $url );
		}

		alarm( 0 );

		if ( $res->{success} )
		{
			if ( $file )
			{
				rename ( "$file\.tmp","$file" ) or return ( 1, "Unable to rename $file\.tmp to $file: $!" );
				return ( 0, $file );
			}
			else
			{
				return ( 0, $res->{content} );
			}
		}
		else
		{
			my $reason 						= $res->{reason};
			if ( $res->{status} == 599 )	{ $reason = $res->{content} }
			( $status, $text ) 				= _method_curlwget( $url, $file, $quiet, $reason );

			return ( $status, $text );
		}
	};

	alarm( 0 );

	if ( $@ ) { return ( 1, $@ ) }
	return ( $status, $text );
}

# #
#	URLGet.pm › Method › LWP::UserAgent (2)
# #

sub _method_lwp
{
	my $url 		= shift;
	my $file 		= shift;
	my $quiet 		= shift;
	my $status 		= 0;
	my $timeout		= 300;
	my $ua 			= LWP::UserAgent->new;

	$ua->agent( $agent );
	$ua->timeout( 30 );

	if ( $proxy ne "" ) { $ua->proxy( [ 'http', 'https' ], $proxy ) }

	# #
	#	use LWP::ConnCache;
	#	my $cache = LWP::ConnCache->new;
	#	$cache->total_capacity([1]);
	#	$ua->conn_cache($cache);
	# #

	my $req = HTTP::Request->new( GET => $url );
	my $res;
	my $text;

	( $status, $text ) = eval
	{
		local $SIG{ __DIE__ } 	= undef;
		local $SIG{'ALRM'} 		= sub { die "Download timeout after $timeout seconds" };
	
		alarm( $timeout );
	
		if ( $file )
		{
			local $|=1;
			my $expected_length;
			my $bytes_received 	= 0;
			my $per 			= 0;
			my $oldper 			= 0;
	
			open ( my $OUT, ">", "$file\.tmp" ) or return ( 1, "Unable to open $file\.tmp: $!" );
			flock ( $OUT, LOCK_EX );
			binmode ( $OUT );

			$res = $ua->request( $req,
				sub {
				my( $chunk, $res ) = @_;
				$bytes_received += length( $chunk );

				if ( !defined $expected_length )
				{
					$expected_length = $res->content_length or 0
				}

				if ( $expected_length )
				{
					my $per = int( 100 * $bytes_received / $expected_length );
					if ( ( int( $per / 5 ) == $per / 5 ) and ( $per != $oldper ) and !$quiet )
					{
						print "...$per\%\n";
						$oldper = $per;
					}
				}
				else
				{
					if ( ! $quiet ) { print "." }
				}

				print $OUT $chunk;
			});

			close ( $OUT );

			if ( ! $quiet ) { print "\n" }
		}
		else
		{
			$res = $ua->request( $req );
		}

		alarm( 0 );

		if ( $res->is_success )
		{
			if ( $file )
			{
				rename ( "$file\.tmp","$file" ) or return ( 1, "Unable to rename $file\.tmp to $file: $!" );
				return ( 0, $file );
			}
			else
			{
				return ( 0, $res->content );
			}
		}
		else
		{
			( $status, $text ) = _method_curlwget( $url, $file, $quiet, $res->message );
			return ( $status, $text );
		}
	};

	alarm( 0 );

	if ( $@ )
	{
		return ( 1, $@ );
	}
	if ( $text )
	{
		return ( $status, $text );
	}
	else
	{
		return ( 1, "Download timeout after $timeout seconds" );
	}
}

# #
#	URLGet.pm › Method › CURL/WGET (3)
# #

sub _method_curlwget
{
	my $url 		= shift;
	my $file 		= shift;
	my $quiet 		= shift;
	my $errormsg 	= shift;
	my @cmd;
	my $cmd_label;

	# #
	#	@note		v15.10		Build argv as list, not a shell string.
	#							open3(@argv) execs directly and skips /bin/sh, so URLs/paths
	#							with spaces or shell metacharacters cannot inject commands.
	# #

	if ( -e $config{CURL} )
	{
		$cmd_label = $config{CURL};

		ConfigServer::Logger::logfile( __PACKAGE__ . " :: Running config(CURL) = $cmd_label to process url" ) if $config{DEBUG};

		@cmd = $file
			? ( $config{CURL}, '-kLf', '-m', '120', '-o', "$file.tmp", $url )
			: ( $config{CURL}, '-skLf', '-m', '120', $url );
	}
	elsif ( -e $config{WGET} )
	{
		$cmd_label = $config{WGET};

		ConfigServer::Logger::logfile( __PACKAGE__ . " :: Running config(WGET) = $cmd_label to process url" ) if $config{DEBUG};

		@cmd = $file
			? ( $config{WGET}, '-T', '120', '-O', "$file.tmp", $url )
			: ( $config{WGET}, '-qT', '120', '-O-', $url );
	}

	if ( @cmd )
	{
		ConfigServer::Logger::logfile(
			__PACKAGE__ . " :: CMD [" . join( ' ', map { _url_sanitize( $_ ) } @cmd ) . "]"
		) if $config{DEBUG};

		my ( $childin, $childout );
		my $cmdpid = IPC::Open3::open3( $childin, $childout, $childout, @cmd );
		my @output = <$childout>;
		waitpid( $cmdpid, 0 );
		my $exit = ( $? == -1 ) ? -1 : ( $? >> 8 );


		ConfigServer::Logger::logfile(
			__PACKAGE__ . " :: exit=$exit bytes=" . length( join( '', @output ) )
			. " file_exists=" . ( ( $file && -e "$file.tmp" ) ? 1 : 0 )
			. " out=[" . _url_sanitize( join( '', @output ) ) . "]"
		) if $config{DEBUG};

		if ( $file )
		{
			if ( !( $quiet and $option != 3 ) )
			{
				print "Using fallback [$cmd_label]\n";
				print @output;
			}

			if ( -e "$file.tmp" )
			{
				rename ( "$file.tmp", "$file" ) or return ( 1, "Unable to rename $file.tmp to $file: $!" );
				return ( 0, $file );
			}
			else
			{
				if ( $option == 3 )
				{
					return (
						1,
						"Unable to download: ["
						. join( ' ', map { _url_sanitize($_) } @cmd )
						. "]"
						. _url_sanitize( join( "", @output ) )
					);
				}
				else
				{
					return ( 1, "Unable to download: " . _url_sanitize( $errormsg ) );
				}
			}
		}
		else
		{
			if ( scalar @output > 0 )
			{
				return ( 0, join( "", @output ) );
			}
			else
			{
				if ( $option == 3 )
				{
					return (
						1,
						"Unable to download: ["
						. join( ' ', map { _url_sanitize($_) } @cmd )
						. "]"
						. _url_sanitize( join( "", @output ) )
					);
				}
				else
				{
					return ( 1, "Unable to download: " . _url_sanitize( $errormsg ) );
				}
			}
		}
	}

	my $detail = $option == 3 ? "" : ": " . _url_sanitize( $errormsg );
	return ( 1, "Unable to download (CURL/WGET also not present, see csf.conf) $detail" );
}

# #
#	URLGet.pm › new
# #

sub new
{
	my $class 	= shift;
	$option		= shift;
	$agent 		= shift;
	$proxy 		= shift;
	my $self 	= {};

	bless $self, $class;

	if ( $option == 3 )
	{
		return $self;
	}
	elsif ( $option ==  2)
	{
		eval ( 'use LWP::UserAgent;' ); ##no critic
		if ( $@ ) { return undef }
	}
	else
	{
		eval
		{
			local $SIG{__DIE__} = undef;
			eval ( 'use HTTP::Tiny;' ); ##no critic
		};
	}

	return $self;
}

# #
#	URLGet.pm › Route
#	
#	Routes a URL download request to the appropriate HTTP method based on the global
#	$option value.
#	
#	Options:
#		1. Perl module HTTP::Tiny
#		2. Perl module LWP::UserAgent
#		3. CURL/WGET (set location at the bottom of csf.conf if installed)
#	
#	All methods take a URL, output file path, and quiet flag.
# #

sub _route_url
{
	my ( $url, $file, $quiet ) = @_;
	$file //= '';
	my $url_sanitized = _url_sanitize( $url );

	if ( $option == 3 )
	{
		ConfigServer::Logger::logfile( __PACKAGE__ . " :: Routing method curl/wget ($option) on url $url_sanitized from file $file" ) if $config{DEBUG};
		return _method_curlwget( $url, $file, $quiet );
	}
	elsif ( $option == 2 )
	{
		ConfigServer::Logger::logfile( __PACKAGE__ . " :: Routing method LWP::UserAgent ($option) on url $url_sanitized from file $file" ) if $config{DEBUG};
		return _method_lwp( $url, $file, $quiet );
	}
	else
	{
		ConfigServer::Logger::logfile( __PACKAGE__ . " :: Routing method HTTP::Tiny ($option) on url $url_sanitized from file $file" ) if $config{DEBUG};
		return _method_tiny( $url, $file, $quiet );
	}
}

# #
#	Wrapper; runs a given reference and returns ($status, $text) result.
#	
#	If $timeout is a positive integer, code will be interrupted return a failure status
#	if it doesn't complete in time.
#	
#	If $timeout missing; code runs normally with no time limit.
# #

sub _with_alarm_timeout
{
	my ( $timeout, $code, $url ) = @_;  		# $url is optional third argument; only used for logging
	my $url_sanitized = _url_sanitize( $url );

	# No timeout; legacy behavior
	if ( !defined $timeout or $timeout !~ /^\d+$/ or $timeout <= 0 )
	{
		ConfigServer::Logger::logfile( __PACKAGE__ . " :: No valid timeout provided; execute using default behavior without alarm protection or timeout." ) if $config{DEBUG};
		return $code->();
	}

	my ( $status, $text );

	eval
	{
		local $SIG{ALRM} = sub { die "timeout\n" };
		alarm( $timeout );

		( $status, $text ) = $code->();
		alarm( 0 );
		1;
	}
	or do
	{
		my $err = $@ || 'unknown error';
		alarm( 0 );

		if ( $err eq "timeout\n" )
		{
			ConfigServer::Logger::logfile(
				__PACKAGE__ . " :: TIMEOUT after $timeout seconds for URL $url_sanitized"
			) if $config{DEBUG};
		}
		else
		{
			ConfigServer::Logger::logfile(
				__PACKAGE__ . " :: ERROR fetching URL $url_sanitized :: $err"
			) if $config{DEBUG};
		}

		return ( 1, "Request failed or timed out: " . _url_sanitize( $err ) );
	};

	ConfigServer::Logger::logfile( __PACKAGE__ . " :: Completed Request for URL $url_sanitized in under $timeout seconds" ) if $config{DEBUG};

	return ( $status, $text );
}

# #
#	URLGet.pm › Get
# #

sub urlget
{
	my $self 	= shift;
	my $url  	= shift;

	if ( !defined $url )
	{
		carp "url not specified";
		return;
	}

	my $url_sanitized = _url_sanitize( $url );

	ConfigServer::Logger::logfile( __PACKAGE__ . " :: Start Request for url $url_sanitized" ) if $config{DEBUG};

	my %p;
	if ( @_ and ref( $_[0] ) eq 'HASH' )
	{
		%p = %{ shift() };
	}
	else
	{
		@p{qw(file quiet timeout)} = @_;
	}

	my ( $status, $text ) = _with_alarm_timeout(
		$p{timeout},
		sub { _route_url( $url, $p{file}, $p{quiet} ) },
		$url
	);

	ConfigServer::Logger::logfile(
		__PACKAGE__ . " :: Completed Request for url $url_sanitized"
	) if $config{DEBUG};

	return ( $status, $text );
}

1;