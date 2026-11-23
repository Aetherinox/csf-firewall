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
#   @updated            11.20.2026
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

## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
package ConfigServer::Messenger;

# #
#   Declare › Use
# #

use strict;
use lib '/usr/local/csf/lib';
use Fcntl ( );
use POSIX ( );
use Socket ( );
use Sys::Hostname ( );
use File::Copy ( );
use JSON::Tiny ( );
use IO::Socket::INET ( );
use Net::CIDR::Lite ( );
use Net::IP ( );
use IPC::Open3 ( );
use ConfigServer::Config ( );
use ConfigServer::CheckIP ( );
use ConfigServer::Logger ( );
use ConfigServer::Aegis ( );
use ConfigServer::URLGet ( );
use ConfigServer::Slurp ( );
use ConfigServer::GetIPs ( );
use ConfigServer::GetEthDev ( );

# #
#	Declare › Export
# #

use Exporter    qw( import );
our @ISA         = qw( Exporter );
our @EXPORT_OK   = qw( );

# #
#	Declare › Version
# #

our $VERSION    = 15.11;

# #
#   Declare › Variables › Global
# #

my $slurpreg 	= ConfigServer::Slurp->slurpreg;
my $cleanreg 	= ConfigServer::Slurp->cleanreg;

# #
#   Declare › Variables › Config
# #

my $config      = ConfigServer::Config->loadconfig();
my %config 		= $config->config();
my $ipv4reg 	= ConfigServer::Config->ipv4reg;
my $ipv6reg 	= ConfigServer::Config->ipv6reg;

my $childproc;
my $hostname;
my %ips;
my $ipscidr6;
my %sslcerts;
my %sslkeys;
my %ssldomains;
my @ssldomainkeys;
my $webserver = "apache";
my $sslhost;
my $sslcert;
my $sslkey;
my $sslca;
my $osslcert;
my $osslkey;
my $osslca;
my $sslaliases;
my $litestart = 0;
my $ssldir = "/var/lib/csf/ssl/";
my $phphandler;
my $version = 1;
my $serverroot;

# #
#   Declare › Constants
#   
#   MESSENGER_RESTART_FAIL_MAX
#       Max number of rapid listener failures before LFD temp
#       disables that Messenger listener type.
#   
#   MESSENGER_RESTART_STABLE_SECS
#       Num of secs a restarted listener must be running before
#       LFD clears its failure count.
# #

use constant
{
    PACKAGE_NAME                    => __PACKAGE__,
    MESSENGER_RESTART_FAIL_MAX      => 3,
    MESSENGER_RESTART_STABLE_SECS   => 60,
    MESSENGER_V1_SOURCE             => "MessengerV1",
    MESSENGER_V2_SOURCE             => "MessengerV2",
    MESSENGER_V3_SOURCE             => "MessengerV3",
};

# #
#   Messenger › Init
#   
#   Create Messenger object, load setup required by selected 
#   Messenger version.
#   
#   Get server hostname, prep network / SSL files (if needed).
#   
#   @params     class           scalar      Messenger class name
#               ver             int         Messenger version
#   @return     self            hashref     Messenger object
# #

sub init
{
	my ( $class, $ver ) = @_;

	$version  = $ver;
	$hostname = "unknown";

	my $self = bless( {}, $class );

	# #
	#   $hostname used in Messenger warning pages, web server configs,
	#   and SSL filenames.
	# #

	{
		local $@;
		my $hostname_read = eval { Sys::Hostname::hostname( ) };

		if ( defined( $hostname_read ) )
		{
			$hostname_read =~ s/[\r\n]+\z//;
			$hostname = $hostname_read
				if $hostname_read ne "";
		}
	}

	if ( $version == 1 )
	{
		if ( $config{MESSENGER6} )
		{
			local $@;
			my $inet6_loaded = eval
			{
				require IO::Socket::INET6;
				1;
			};

			$config{MESSENGER6} = "0"
				if !$inet6_loaded;
		}

		$ipscidr6 = Net::CIDR::Lite->new;

		ConfigServer::Messenger::getethdev( );

		foreach my $ip ( split( /,/, $config{RECAPTCHA_NAT} ) )
		{
			$ip =~ s/\s*//g;
			next if $ip eq "";

			$ips{$ip} = 1;
		}
	}
	elsif ( $version == 3 )
	{
		foreach my $directory (
			$ssldir,
			$ssldir . "certs/",
			$ssldir . "keys/",
			$ssldir . "ca/",
		)
		{
			mkdir $directory
				if !-d $directory;
		}
	}
	
	return $self;
}

# #
#   Messenger › Throw › Error
#	
#	Log Messenger failuresl return failure status and reason.
#	
#	If only a reason is provided:
#       $version    all
#       $target     normal
#	
#	@usage		_throw_err( "Failure reason" );             # Messenger     ALL (all)
#				_throw_err( 2, "Failure reason" );          # MessengerV2   V2  (all)
#				_throw_err( 1, "Failure reason", "root" );  # MessengerV1   V1  (root)
#				_messenger_fail( 2, "Failure reason" );             # MessengerV2 failure
#				_messenger_fail( 1, "Failure reason", "root" );     # MessengerV1 failure
#	
#	@param      version     num|str     Messenger version (1, 2, 3, or All)
#	@param      ver             str|num     Messenger version (1, 2, 3, or All)
#	            reason		    str         failure reason
#               target		    str         log target:
#                                               normal, root, or all
#	@return					    num         failure status
#                                               1           failure logged
#							    str         failure reason
# #

sub _throw_err
{
	my ( $ver, $reason, $target ) = @_;

	if ( @_ == 1 )
	{
		$reason = $ver;
		$ver    = "all";
	}

	$ver = "all"
        if !defined( $ver ) or ref( $ver ) or !length( $ver );

	$ver = lc( $ver );

	$reason //= "Unknown Messenger failure";

	my $_target     = defined( $target ) && !ref( $target ) ? lc( $target ) : "";
	$target         = $_target =~ /\A(?:normal|root|all)\z/ ? $_target : "normal";
	my $ver_log     = $ver =~ /\A[123]\z/ ? "V$ver" : uc( $ver );

	ConfigServer::Logger::logfile( $target, "error", "[Messenger$ver_log] $reason" );

	return ( 1, $reason );
}

# #
#   Messenger › Start
#
#   Start Messenger version selected by init().
#   
#   @note:      Loaded from lfd.pl
#   
#   @usage      MessengerV1     my ( $status, $reason ) = $messenger1->start( $port, $user, $type );
#               MessengerV2     my ( $status, $reason ) = $messenger2->start();
#               MessengerV3     my ( $status, $reason ) = $messenger3->start();
#   
#   @params     self            hashref         Messenger object
#               port            int             MessengerV1:    listening port
#               user            str             MessengerV1:    user
#               type            str             MessengerV1:    message type (HTTPS HTML TEXT)
#
#   @return     status          int|undef       Messenger startup status
#                                                   0       startup succeeded
#                                                   1       startup failed
#                                                   undef   no status returned
#               reason          str|undef       startup result reason
#                                                   "none"  no supported ver selected
#                                                   undef   no reason returned
# #

sub start
{
	my ( $self, $port, $user, $type ) = @_;

	my $status;
	my $reason = "none";
	my $source;

	ConfigServer::Logger::logfile( "debug:1", "info",
		"[Messenger] Determining which Messenger version to use"
	);

	if ( $version == 1 )
	{
		$source = MESSENGER_V1_SOURCE;
		( $status, $reason ) = messenger( $port, $user, $type );
	}
	elsif ( $version == 2 )
	{
		$source = MESSENGER_V2_SOURCE;
		( $status, $reason ) = messengerv2( );
	}
	elsif ( $version == 3 )
	{
		$source = MESSENGER_V3_SOURCE;
		( $status, $reason ) = messengerv3( );
	}

	if ( defined( $source ) )
	{
		my $result = $status ? "Failure" : "Success";

		ConfigServer::Logger::logfile( "debug:1", "info",
			"[$source] Startup result [$result] [Reason: $reason]"
		);
	}

	return ( $status, $reason );
}

sub messenger
{

    ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V1_SOURCE . "] Initializing subroutine" );

	my $port 		= shift;
	my $user 		= shift;
	my $type 		= shift;
	my $oldtype 	= $type;
	my $server;
	my %sslcerts;
	my %sslkeys;

	$SIG{CHLD} 		= 'IGNORE';
	$SIG{INT} 		= \&childcleanup;
	$SIG{TERM} 		= \&childcleanup;
	$SIG{HUP} 		= \&childcleanup;
	$SIG{__DIE__} 	= sub { &childcleanup( @_ ); };

	$0 				= "lfd $type messenger";
	$childproc 		= "Messenger ($type)";

	if ( $type eq "HTTPS" )
	{
		eval {
			local $SIG{__DIE__} = undef;
			require IO::Socket::SSL;
		};

		my $start = 0;
		my $sslhost;
		my $sslcert;
		my $sslkey;
		my $sslaliases;
		my %messengerports;

		foreach my $serverports ( split(/\,/,$config{MESSENGER_HTTPS_IN}) )
		{
			$messengerports{$serverports} = 1
		}

		foreach my $file ( glob( $config{MESSENGER_HTTPS_CONF} ) )
		{
			if (-e $file) {
				foreach my $line (ConfigServer::Slurp::slurp($file)) {
					$line =~ s/\'|\"//g;
					if ($line =~ /^\s*<VirtualHost\s+[^\>]+>/) {
						$start = 1;
					}

					if ( $webserver eq "apache" and $start )
                    {
						if ($line =~ /\s*ServerName\s+(\w+:\/\/)?([a-zA-Z0-9\.\-]+)(:\d+)?/) {$sslhost = $2}
						if ($line =~ /\s*ServerAlias\s+(.*)/) {$sslaliases .= " ".$1}
						if ($line =~ /\s*SSLCertificateFile\s+(\S+)/) {
							my $match = $1;
							if (-e $match) {$sslcert = $match}
						}
						if ($line =~ /\s*SSLCertificateKeyFile\s+(\S+)/) {
							my $match = $1;
							if (-e $match) {$sslkey = $match}
						}
					}

					if ( ( $webserver eq "apache" and $line =~ /^\s*<\/VirtualHost\s*>/ ) )
					{
						$start = 0;
						if ( $sslhost ne "" and !ConfigServer::CheckIP::checkip( $sslhost ) and $sslcert ne "" )
						{
							$sslcerts{$sslhost} 	= $sslcert;
							if ( $sslkey eq "" ) 	{ $sslkey = $sslcert }
							$sslkeys{$sslhost} 		= $sslkey;

							foreach my $alias ( split( /\s+/, $sslaliases ) )
							{
								if ( $alias eq "" ) { next }
								if ( ConfigServer::CheckIP::checkip( $alias ) ) { next }
								if ( $alias =~ /^[a-zA-Z0-9\.\-]+$/ )
								{
									if ( $config{MESSENGER_HTTPS_SKIPMAIL} and $alias =~ /^mail\./ ) { next }

									$sslcerts{$alias} 	= $sslcert;
									$sslkeys{$alias} 	= $sslkey;
								}
							}
						}

						$sslhost 	= "";
						$sslcert 	= "";
						$sslkey 	= "";
						$sslaliases = "";
					}
				}
			}
		}

		# #
		#	Verify at least one SSL certificate was found
		# #

		if ( !keys %sslcerts )
		{
            return _throw_err( 1, "No SSL certs found in MESSENGER_HTTPS_CONF = \"$config{MESSENGER_HTTPS_CONF}\" (defined in /etc/csf/csf.conf)" );
		}

		# # 
		#	Load custom SSL key & cert
		#	
		#   The following options can be specified to provide a default fallback
		#   certificate to be used if either SNI is not supported or a hosted domain does
		#   not have an SSL certificate. If a fallback is not provided, one of the certs
		#   obtained from MESSENGER_HTTPS_CONF will be used
		#   
		#   This is used by MESSENGERV1 and MESSENGERV2 only
		# 
		#	MESSENGER_HTTPS_KEY = "/etc/pki/tls/private/localhost.key"
		#	MESSENGER_HTTPS_CRT = "/etc/pki/tls/certs/localhost.crt"
		# # 

		if ( -e $config{MESSENGER_HTTPS_KEY} )
		{
			$sslkeys{''} = $config{MESSENGER_HTTPS_KEY};
		}

		if ( -e $config{MESSENGER_HTTPS_CRT} )
		{
			$sslcerts{''} = $config{MESSENGER_HTTPS_CRT};
		}

		# #
		#	Debug Only - log SSL keys
		#	
		#	@example		SSL: [certificate name/index] [certificate file] [private key file]
		#					SSL: [localhost] [/etc/pki/tls/certs/localhost.crt] [/etc/pki/tls/private/localhost.key]
		# #

		if ( $config{DEBUG} >= 1 )
		{
			foreach my $key ( keys %sslcerts )
			{
				ConfigServer::Logger::logfile( "SSL: [$key] [$sslcerts{$key}] [$sslkeys{$key}]" );
			}
		}

		eval
		{
			local $SIG{__DIE__} = undef;
			if ( $config{MESSENGER6} )
			{
				$server = IO::Socket::SSL->new(
					Domain 			=> Socket::AF_INET6,
					LocalPort 		=> $port,
					Type 			=> Socket::SOCK_STREAM,
					ReuseAddr 		=> 1,
					Listen 			=> $config{MESSENGER_CHILDREN},
					SSL_server 		=> 1,
					SSL_use_cert 	=> 1,
					SSL_cert_file 	=> \%sslcerts,
					SSL_key_file 	=> \%sslkeys,
				) or &error( "MESSENGER: *Error* cannot open server on port $port: " . IO::Socket::SSL->errstr );
			}
			else
			{
				$server = IO::Socket::SSL->new(
					Domain 			=> Socket::AF_INET,
					LocalPort 		=> $port,
					Type 			=> Socket::SOCK_STREAM,
					ReuseAddr 		=> 1,
					Listen 			=> $config{MESSENGER_CHILDREN},
					SSL_server 		=> 1,
					SSL_use_cert 	=> 1,
					SSL_cert_file 	=> \%sslcerts,
					SSL_key_file 	=> \%sslkeys,
				) or &error( "MESSENGER: *Error* cannot open server on port $port: " . IO::Socket::SSL->errstr );
			}

			ConfigServer::Logger::logfile( "Messenger HTTPS Service started for " . scalar( keys %sslcerts ) . " domains" );
			$type = "HTML";
		};
	
		if ( $@ )
		{
			return _throw_err( 1, $@ );
		}
	}
	elsif ( $config{MESSENGER6} )
	{
		$server = IO::Socket::INET6->new(
			LocalPort 	=> $port, 
			Type 		=> Socket::SOCK_STREAM, 
			ReuseAddr 	=> 1, 
			Listen 		=> $config{MESSENGER_CHILDREN}) or &childcleanup(__LINE__,"*Error* cannot open server on port $port: $!");
	}
	else
	{
		$server = IO::Socket::INET->new(
			LocalPort 	=> $port, 
			Type 		=> Socket::SOCK_STREAM, 
			ReuseAddr 	=> 1, 
			Listen 		=> $config{MESSENGER_CHILDREN}) or &childcleanup(__LINE__,"*Error* cannot open server on port $port: $!");
	}

	my $index;
	if ( $type eq "HTML" and $config{RECAPTCHA_SITEKEY} ne "" )
    {
        $index = "/etc/csf/messenger/index.recaptcha.html"
    }
	elsif ( $type eq "HTML" )
    {
        $index = "/etc/csf/messenger/index.html"
    }
	else
    {
        $index = "/etc/csf/messenger/index.text"
    }

    ConfigServer::Logger::logfile( "debug:1", "info", "[reCAPTCHA] type [$type] detected - sitekey [" . ( $config{RECAPTCHA_SITEKEY} ne "" ? "provided" : "empty" ) . "] - using $index" );

	open (my $IN, "<", $index);
	flock ($IN, Fcntl::LOCK_SH);
	my @message = <$IN>;
	close ($IN);
	chomp @message;

	my %images;
	if ( $type eq "HTML" )
	{
		opendir (DIR, "/etc/csf/messenger");
		foreach my $file (readdir(DIR)) {
			if ($file =~ /\.(gif|png|jpg)$/) {
				open (my $IN, "<", "/etc/csf/messenger/$file");
				flock ($IN, Fcntl::LOCK_SH);
				my @data = <$IN>;
				close ($IN);
				chomp @data;
				foreach my $line (@data) {
					$images{$file} .= "$line\n";
				}
			}
		}
		closedir (DIR);
	}

	my $chldallow = $config{MESSENGER_CHILDREN};

	if ($oldtype eq "HTTPS") {
		open (my $STATUS,"<", "/proc/$$/status") or next;
		flock ($STATUS, Fcntl::LOCK_SH);
		my @status = <$STATUS>;
		close ($STATUS);
		chomp @status;
		my $vmsize = 0;
		my $vmrss = 0;
		foreach my $line ( @status )
        {
			if ($line =~ /^VmSize:\s+(\d+) kB$/) {$vmsize = $1}
			if ($line =~ /^VmRSS:\s+(\d+) kB$/) {$vmrss = $1}
		}

		ConfigServer::Logger::logfile("lfd $oldtype messenger using $vmrss kB of RSS memory at startup, adding up to $config{MESSENGER_CHILDREN} children = ".(($config{MESSENGER_CHILDREN} + 1) * $vmrss)." kB");
		ConfigServer::Logger::logfile("lfd $oldtype messenger using $vmsize kB of VIRT memory at startup, adding up to $config{MESSENGER_CHILDREN} children = ".(($config{MESSENGER_CHILDREN} + 1) * $vmsize)." kB");
	}

    # #
    #   If $user not empty; proceed
    # #

	if ( $user ne "" )
	{
		my ( undef, undef, $uid, $gid, undef, undef, undef, $homedir ) = getpwnam( $user );

		# #
		#	Reject root. Messenger must never run as uid/gid 0.
		# #

        if ( !defined $uid or !defined $gid or $uid <= 0 or $gid <= 0 )
        {
            return _throw_err( 1, "MESSENGER_USER must not be root (uid/gid 0) or invalid user specified [$user]" );
		}

        my ( $secured, $security_err ) = ConfigServer::Aegis::initialize(
            $uid,
            $gid,
            $server,
        );

        if ( !$secured )
        {
            return _throw_err( 1,
                "Unable to secure Messenger as MESSENGER_USER [$user] - stopping [$oldtype] Messenger: $security_err"
            );
        }

        # #
        #   Messenger › Start Log Re-route
        #   
        #   @note           From this point forward; Messenger will store logs in:
        #                       /var/log/lfd_messenger.log
        # #

        ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V1_SOURCE . "] " . "Messenger initialized securely as MESSENGER_USER [$user] ($uid:$gid)" );
    
		# #
		#	Messenger › Client › Connections
		#
        #   Accept incoming Messenger connections, fork child process to handle
        #   each client.
        #   
        #   Limit num of active child processes to $chldallow; defined in
        #   csf.conf as $config{MESSENGER_CHILDREN}.
        #   
        #   Each child processes the client req, handle html / reCAPTCHA (if
        #   enabled), sends response, closes connection. exit.
        #   
        #   Parent process keeps running; waits for the next client incoming
        #   connection.
        #   
        #   @test       Note:           Port 8887
        #               Command:        perl -MIO::Socket::SSL -e '$| = 1; my ( $host, $port, $children ) = @ARGV; my @clients; for my $i ( 1 .. ( $children + 1 ) ) { my $client = IO::Socket::SSL->new( PeerHost => $host, PeerPort => $port, SSL_verify_mode => 0, Timeout => 5 ) or die "Connection $i failed: " . IO::Socket::SSL::errstr() . "\n"; push @clients, $client; print "Connection $i opened\n"; select( undef, undef, undef, 0.2 ); } sleep 15;' 127.0.0.1 8887 20
        #                               sudo ss -ltnp | grep -E ':(8887|8888|8889)\b'
        #   
        #               Note:           Port 8889
        #               Command:        perl -MIO::Socket::INET -e '$| = 1; my ( $host, $port, $count ) = @ARGV; for my $i ( 1 .. $count ) { my $client = IO::Socket::INET->new( PeerHost => $host, PeerPort => $port, Proto => "tcp", Timeout => 5 ) or die "Connection $i failed: $!\n"; print "Connection $i opened\n"; close( $client ) or die "Connection $i close failed: $!\n"; }' 127.0.0.1 8889 21
        #                               sudo ss -ltnp | grep -E ':(8887|8888|8889)\b'
		# #

		my %children;
		while ( 1 )
		{
            # Trigger with telnet xx.xx.xx.xx 8889
            ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V1_SOURCE . "] $oldtype Messenger PID [$$] listening on [" . $server->sockhost( ) . ":" . $server->sockport( ) . "]" );
			while ( my $client = $server->accept( ) )
			{

                ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V1_SOURCE . "] $oldtype Messenger PID [$$] accepted client [" . $client->peerhost( ) . "]" );
				while ( scalar ( keys %children ) >= $chldallow )
				{

					# #
					#	Messenger › Client › Children › Cleanup
					#   
					#	Wait 1s; check each tracked child process.
                    #   
					#	Remove child PIDs that are no longer running so new
					#	client connections can use the available slots. Otherwise
                    #   we fill up the allowed slots.
					# #

					sleep 1;

					foreach my $pid ( keys %children )
                    {
						if ( !kill( 0, $pid ) )
                        {
                            ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V1_SOURCE . "] Client - Child PID [$pid] no longer running; removing from children list" );
                            delete $children{$pid}
                        }
					}

					$0          = "lfd $oldtype messenger (busy)";
				}

				$0              = "lfd $oldtype messenger";
				$SIG{CHLD}      = 'IGNORE';
				my $pid         = fork;
				$children{$pid} = 1;

				# #
				#	Messenger › Client › Child Process
				#   
                #   fork() returns 0 inside newly made child.
                #   
                #   Child handles accepted client connection, send the
                #   response, close the connection, exit.
				# #

                ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V1_SOURCE . "] Client - forked PID $pid" );

				if ( $pid == 0 )
				{
					eval
					{
						local $SIG{__DIE__}     = undef;
						local $SIG{'ALRM'}      = sub {die};
						alarm( 10 );

                        # #
                        #   Close Child Listener
                        #
                        #   Close the child process's inherited copy of the
                        #   server listener.
                        #   
                        #   Could fail if the socket / file descriptor is invalid,
                        #   already closed, or the server reports an error.
                        #   
                        #   @ref        https://perldoc.perl.org/POSIX#_exit
                        # #

                        ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V1_SOURCE . "] Client - Preparing child process for listener [" . $server->sockhost( ) . ":" . $server->sockport( ) . "]" );
						if ( !close( $server ) )
						{
							ConfigServer::Logger::logfile( "debug:1", "error", "[" . MESSENGER_V1_SOURCE . "] Client - " .
								"Failure! Failed to close inherited listener: $!"
							);

							POSIX::_exit( POSIX::EXIT_FAILURE( ) );
						}

                        # #
                        #   Child Listener Closed
                        #
                        #   close() succeeded. The child no longer holds a copy of
                        #   the server listener, parent process continues listening
                        #   for new clients.
                        # #

						ConfigServer::Logger::logfile( "debug:1", "ok", "[" . MESSENGER_V1_SOURCE . "] Client - Inherited listener closed successfully" );

                        # #
                        #   Isolate Child Descriptors
                        #
                        #   Keep only the accepted client and standard streams
                        #   open in the child process.
                        # #

						my ( $worker_caged, $worker_cage_err ) = ConfigServer::Aegis::fds_cage( $client );
						if ( !$worker_caged )
						{
							ConfigServer::Logger::logfile( "debug:1", "error", "[" . MESSENGER_V1_SOURCE . "] Client - Failure! Unable to cage descriptors: " .
								( defined( $worker_cage_err ) ? $worker_cage_err : "unknown error" )
							);

							POSIX::_exit( POSIX::EXIT_FAILURE( ) );
						}

						ConfigServer::Logger::logfile( "debug:1", "ok", "[" . MESSENGER_V1_SOURCE . "] Client - Descriptors isolated successfully" );
						$0 = "lfd $oldtype messenger client";

                        # #
                        #   Client Binary Mode
                        #
                        #   Put client socket into binary mode so data is sent
                        #   and received w/o text or newline conversion.
                        # #

						binmode $client;
						$| = 1;             # flush; dont buffer

                        my $firstline       = $type eq "TEXT" ? "TEXT mode (not required)" : "";
						my $hostaddress     = $client->sockhost( );
						my $peeraddress     = $client->peerhost( );
						$peeraddress        =~ s/^::ffff://;
						$hostaddress        =~ s/^::ffff://;

						ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V1_SOURCE . "] Client - Socket ready [Server: $hostaddress | Client: $peeraddress]" );

                        # #
                        #   @todo   Port Messenger Requests to module
                        # #

						if ( $type eq "HTML" )
						{
							while ( $firstline !~ /\n$/ )
							{
								my $char;
								$client->read( $char, 1 );
								$firstline .= $char;
								if ( $char eq "" )
                                {
                                    exit
                                }

								# #
								#	RFC 7230, Sec 3.1.1: recommends supporting at least 8000 octets.
								#		Prefix: 	GET /unblk?g-recaptcha-response=	= 32 bytes
								#		Suffix:  	HTTP/1.1\r\n						= 11 bytes			(\r\n = 2 bytes) (carriage return (0x0D)/line feed (0x0A))
								#		 												32 + 11 = 43 bytes
								#	
								#		Remaining for Recaptcha token					4053 bytes  (4096-43)
								#		Acceptable Limit								4096 bytes
								#	
                                #   @docs               Keep here until I migrate to https://docs.configserver.dev
								#	@since				v15.10
								#	@reference			https://datatracker.ietf.org/doc/html/rfc7230#autoid-17
								#						https://mothereff.in/byte-counter
								# #

								if ( length $firstline > 4096 )
								{
									last
								}
							}

							chomp $firstline;
							if ( $firstline =~ /\r$/ )
                            {
                                chop $firstline
                            }
						}

                        ConfigServer::Logger::logfile( "debug:1", "info", "Client connection [$peeraddress] [$firstline]" );

						my $error;
						my $success;
						my $failure;
						if ( ( $type eq "HTML" ) and ( $firstline =~ /^GET \/unblk\?g-recaptcha-response=(\S+)/i ) )
                        {
							my $recv    = $1;
							my $status  = 1;
							my $text;
							eval {
								local $SIG{__DIE__} = undef;
								eval( "no lib '/usr/local/csf/lib'" );
								my $urlget          = ConfigServer::URLGet->new( 2, "", $config{URLPROXY} );
								my $url             = "https://www.google.com/recaptcha/api/siteverify?secret=$config{RECAPTCHA_SECRET}&response=$recv";
								( $status, $text )  = $urlget->urlget( $url );
							};

							if ($status)
                            {
								ConfigServer::Logger::logfile( "debug:1", "error", "*Error*, ReCaptcha ($peeraddress): $text" );
								if ($config{DEBUG} >= 1) {
									if ($@) {$error .= "Error:".$@}
									if ($!) {$error .= "Error:".$!}
									$error .= " Error Status: $status";
								}
								$error .= "Unable to verify with Google reCAPTCHA";
							} else {
								my $resp  = JSON::Tiny::decode_json($text);
								if ($resp->{success}) {
									my $ip = $resp->{hostname};
									unless ($ip =~ /^($ipv4reg|$ipv6reg)$/) {$ip = (ConfigServer::GetIPs::getips($ip))[0]}
									if ($ips{$ip} or $ip eq $hostaddress or $ipscidr6->find($ip)) {
										if ( sysopen( my $UNBLOCK, "$homedir/unblock.txt", Fcntl::O_WRONLY() | Fcntl::O_APPEND() | Fcntl::O_CREAT() ) ) {
											flock($UNBLOCK, Fcntl::LOCK_EX);

											my $entry = "$peeraddress;$resp->{hostname};$ip\n";
											ConfigServer::Logger::logfile( "debug:1", "info", "ReCaptcha writing to [$homedir/unblock.txt]: $entry" );

											if ( print $UNBLOCK $entry ) {
												$success = 1;
                                                ConfigServer::Logger::logfile( "debug:1", "ok", "ReCaptcha ($peeraddress): [$resp->{hostname} ($ip)] requested unblock" );
											} else {
												$error .= "Unable to write to [$homedir/unblock.txt]: $!";
                                                ConfigServer::Logger::logfile( "debug:1", "error", "*Failed*, ReCaptcha unable to write to [$homedir/unblock.txt]: $!" );
											}

											close ($UNBLOCK);
										} else {
											$error .= "Unable to write to [$homedir/unblock.txt] (make sure that MESSENGER_USER has a home directory): $!";
                                            ConfigServer::Logger::logfile( "debug:1", "error", "*Failed*, ReCaptcha unable to open [$homedir/unblock.txt]: $!" );
										}
									} else {
										$error .= "Failed, [$resp->{hostname} ($ip)] does not appear to be hosted on this server.";
										ConfigServer::Logger::logfile( "debug:1", "error", "*Failed*, ReCaptcha ($peeraddress): [$resp->{hostname} ($ip)] does not appear to be hosted on this server" );
									}
								} else {
									$failure = 1;
									my @codes = @{$resp->{'error-codes'}};
									ConfigServer::Logger::logfile( "debug:1", "error", "*Failure*, ReCaptcha ($peeraddress): [$codes[0]]" );
								}
							}
						}
						if (($type eq "HTML") and ($firstline =~ /^GET\s+(\S*\/)?(\S*\.(gif|png|jpg))\s+/i)) {
							my $type = $3;
							if ( $type eq "jpg" ) { $type = "jpeg" }
							print $client "HTTP/1.1 200 OK\r\n";
							print $client "Content-type: image/$type\r\n";
							print $client "\r\n";
							print $client $images{$2};
						} else {
							if ($type eq "HTML") {
								print $client "HTTP/1.1 403 OK\r\n";
								print $client "Content-type: text/html\r\n";
								print $client "\r\n";
								foreach my $line (@message) {
									if ($line =~ /\[IPADDRESS\]/) {$line =~ s/\[IPADDRESS\]/$peeraddress/}
									if ($line =~ /\[HOSTNAME\]/) {$line =~ s/\[HOSTNAME\]/$hostname/}
									if ($line =~ /\[RECAPTCHA_SITEKEY\]/) {$line =~ s/\[RECAPTCHA_SITEKEY\]/$config{RECAPTCHA_SITEKEY}/}
									if ($line =~ /\[RECAPTCHA_ERROR=\"([^\"]+)\"\]/) {
										my $text = $1;
										if ($error ne "") {$line =~ s/\[RECAPTCHA_ERROR=\"([^\"]+)\"\]/$text $error/} else {$line =~ s/\[RECAPTCHA_ERROR=\"([^\"]+)\"\]//}
									}
									if ($line =~ /\[RECAPTCHA_SUCCESS=\"([^\"]+)\"\]/) {
										my $text = $1;
										if ($success) {$line =~ s/\[RECAPTCHA_SUCCESS=\"([^\"]+)\"\]/$text/} else {$line =~ s/\[RECAPTCHA_SUCCESS=\"([^\"]+)\"\]//}
									}
									if ($line =~ /\[RECAPTCHA_FAILURE=\"([^\"]+)\"\]/) {
										my $text = $1;
										if ($failure) {$line =~ s/\[RECAPTCHA_FAILURE=\"([^\"]+)\"\]/$text/} else {$line =~ s/\[RECAPTCHA_FAILURE=\"([^\"]+)\"\]//}
									}
									print $client "$line\r\n";
								}
								print $client "\r\n";
							} else {
								foreach my $line (@message) {
									if ($line =~ /\[IPADDRESS\]/) {$line =~ s/\[IPADDRESS\]/$peeraddress/}
									if ($line =~ /\[HOSTNAME\]/) {$line =~ s/\[HOSTNAME\]/$hostname/}
									print $client "$line ";
								}
								print $client "\n";
							}
						}

						ConfigServer::Logger::logfile( "debug:1", "ok", "[" . MESSENGER_V1_SOURCE . "] Client - $oldtype response completed [Client: $peeraddress]" );

						alarm(0);
					};
					shutdown ($client,2);
					$client->close();
					alarm(0);
					exit;
				}
				if ( $oldtype eq "HTTPS" )
                {
					$client->close( SSL_no_shutdown => 1 );
				} else {
					$client->close( );
				}
			}
		}
	}
	else
	{
        return _throw_err( 1, "MESSENGER_USER not configured - stopping $oldtype Messenger" );
	}

	return;
}

sub messengerv2
{
    ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V2_SOURCE . "] Initializing subroutine" );

	my ( undef, undef, $uid, $gid, undef, undef, undef, $homedir ) = getpwnam( $config{MESSENGER_USER} );

	# #
	#	Reject root. Messenger must never run as uid/gid 0.
	# #

    my $messenger_user = defined $config{MESSENGER_USER} && $config{MESSENGER_USER} ne "" ? $config{MESSENGER_USER} : "missing";
	if ( !defined $uid or !defined $gid or $uid <= 0 or $gid <= 0 )
	{
        return _throw_err(
            2,
            "MESSENGER_USER must specify a valid user with uid and gid greater than 0 " .
            "[Configured: $messenger_user]"
        );
	}

	if ( $homedir eq "" or $homedir eq "/" or $homedir =~ m[/etc/csf] )
	{
        return _throw_err( 2, "The home directory for $config{MESSENGER_USER} is not valid [$homedir]" );
	}

	if ( ! -e $homedir )
	{
        return _throw_err( 2, "The home directory for $config{MESSENGER_USER} does not exist [$homedir]" );
	}

    ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V2_SOURCE . "] Set chmod 711: $homedir" );
	system( "chmod", "711", $homedir );

	my $public_html = $homedir . "/public_html";
    ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V2_SOURCE . "] Declared public_html path: $public_html" );

	if ( !-e $public_html )
    {
		system( "mkdir", "-p", $public_html );
		system( "chown", "$config{MESSENGER_USER}:nobody", $public_html );
		system( "chmod", "711", $public_html );

        ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V2_SOURCE . "] Created public_html path: $public_html - chown:[$config{MESSENGER_USER}:nobody] - chmod:711" );
    }
    else
    {
        ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V2_SOURCE . "] Skip creating public_html path: $public_html - already exists" );
	}

	if ( !-e $public_html . "/.htaccess" )
	{
		open    (my $HTACCESS, ">", $public_html."/.htaccess");
		flock ($HTACCESS, Fcntl::LOCK_EX);
		print $HTACCESS "Require all granted\n";
		print $HTACCESS "DirectoryIndex index.php index.cgi index.html index.htm\n";
		print $HTACCESS "Options +FollowSymLinks +ExecCGI\n";
		print $HTACCESS "RewriteEngine On\n";
		print $HTACCESS "RewriteCond \%{REQUEST_FILENAME} !-f\n";
		print $HTACCESS "RewriteCond \%{REQUEST_FILENAME} !-d\n";
		print $HTACCESS "RewriteRule ^ /index.php [L,QSA]\n";
		system  ("chown","$config{MESSENGER_USER}:$config{MESSENGER_USER}",$public_html."/.htaccess");
		system  ("chmod","644",$public_html."/.htaccess");
	}

    # #
    #   @note           Messenger's apache index.php will be re-copied to apache public
    #                   folder if CSF is restarted.
    #   
    #                   NO $public_html/index.php" exists:
    #                       YES set RECAPTCHA_SITEKEY in csf.conf
    #                           copy /etc/csf/messenger/index.recaptcha.php     => $public_html/index.php
    #   
    #                       NO hasn't set RECAPTCHA_SITEKEY in csf.conf
    #                           copy /etc/csf/messenger/index.php               => $public_html/index.php
    #   
    #                   unblock.txt created only after user attempts to access
    #                   web server https://192.168.0.2:8887/
    # #

    # /home/csf/index.php DOES NOT exist
	if ( !-e $public_html . "/index.php" )
	{
        # csf.conf RECAPTCHA_SITEKEY not set
		if ( $config{RECAPTCHA_SITEKEY} )
		{
            ConfigServer::Logger::logfile( "debug:1", "info", "[reCAPTCHA] sitekey [" . ( $config{RECAPTCHA_SITEKEY} ne "" ? "provided" : "empty" ) . "] - Copying file (/etc/csf/messenger/index.recaptcha.php) => $public_html/index.php" );
			system( "cp", "/etc/csf/messenger/index.recaptcha.php", $public_html . "/index.php" );
		}
        # csf.conf RECAPTCHA_SITEKEY set
		else
		{
            ConfigServer::Logger::logfile( "debug:1", "info", "[reCAPTCHA] sitekey [" . ( $config{RECAPTCHA_SITEKEY} ne "" ? "provided" : "empty" ) . "] - Copying file (/etc/csf/messenger/index.php) => $public_html/index.php" );
			system( "cp", "/etc/csf/messenger/index.php", $public_html . "/index.php" );
		}

		system( "chown", "$config{MESSENGER_USER}:$config{MESSENGER_USER}", $public_html . "/index.php");
		system( "chmod", "644", $public_html . "/index.php" );
    }
    # /home/csf/index.php exists
    else
    {
        ConfigServer::Logger::logfile( "debug:1", "info", "[reCAPTCHA] sitekey [" . ( $config{RECAPTCHA_SITEKEY} ne "" ? "provided" : "empty" ) . "] - Found $public_html/index.php - skipping cp file from /etc/csf/messenger/" );
	}

    # #
    #   Apache Messenger php language file doesn't exist
    # #

	if ( !-e $homedir . "/en.php" )
    {
		system( "cp", "/etc/csf/messenger/en.php", $homedir . "/en.php" );
		system( "chown", "$config{MESSENGER_USER}:$config{MESSENGER_USER}", $homedir . "/en.php" );
		system( "chmod", "644", $homedir . "/en.php" );
	}

	open    ( my $CONF, ">", $homedir . "/recaptcha.php" );
	flock   ( $CONF, Fcntl::LOCK_EX );
	print $CONF "<?php\n";
	print $CONF "\$secret = '$config{RECAPTCHA_SECRET}';\n";
	print $CONF "\$sitekey = '$config{RECAPTCHA_SITEKEY}';\n";
	print $CONF "\$unblockfile = '$homedir/unblock.txt';\n";
	print $CONF "\$logfile = '/var/log/lfd_messenger.log';\n";
	print $CONF "?>\n";
	system  ( "chown", "$config{MESSENGER_USER}:$config{MESSENGER_USER}", $homedir . "/recaptcha.php" );
	system  ( "chmod", "600", $homedir . "/recaptcha.php" );
	
    # #
    #   Messenger v2
    #   
    #   OPEN /var/lib/csf/csf.conf
    #       missing file    => create
    #       existing file   => empty first, then write from scratch
    #   BUILD <Virtualhost>
    #       Generate apache http port :80 <VirtualHost> if MESSENGER_HTML_IN exists
    #       Generate apache https port :443 <VirtualHost> if MESSENGER_HTTPS_IN exists
    #   COPY /var/lib/csf/csf.conf => /etc/httpd/conf.d/csf.messenger.conf
    # #

	open    ( my $OUT, ">", "/var/lib/csf/csf.conf" );
	flock   ( $OUT, Fcntl::LOCK_EX );

    # #
    #   Messenger v2 > Build Apache <VirtualHost> - Port :80 http
    # #

	if ($config{MESSENGER_HTML_IN} ne "")
	{
		print $OUT "Listen 0.0.0.0:$config{MESSENGER_HTML}\n";
		if ($config{IPV6}) {print $OUT "Listen [::]:$config{MESSENGER_HTML}\n"}
		print $OUT "<VirtualHost *:$config{MESSENGER_HTML}>\n";
		print $OUT " ServerName $hostname\n";
		print $OUT " DocumentRoot $public_html\n";
		print $OUT " <Directory \"$homedir\">\n";
		print $OUT "  AllowOverride All\n";
		print $OUT " </Directory>\n";
		print $OUT " <IfModule suphp_module>\n";
		print $OUT "   suPHP_UserGroup $config{MESSENGER_USER} $config{MESSENGER_USER}\n";
		print $OUT " </IfModule>\n";
		print $OUT " <IfModule suexec_module>\n";
		print $OUT "   <IfModule !mod_ruid2.c>\n";
		print $OUT "     SuexecUserGroup $config{MESSENGER_USER} $config{MESSENGER_USER}\n";
		print $OUT "   </IfModule>\n";
		print $OUT " </IfModule>\n";
		print $OUT " <IfModule ruid2_module>\n";
		print $OUT "   RMode config\n";
		print $OUT "   RUidGid $config{MESSENGER_USER} $config{MESSENGER_USER}\n";
		print $OUT " </IfModule>\n";
		print $OUT " <IfModule mpm_itk.c>\n";
		print $OUT "   AssignUserID $config{MESSENGER_USER} $config{MESSENGER_USER}\n";
		print $OUT " </IfModule>\n";
		print $OUT " KeepAlive Off\n";
		print $OUT "</VirtualHost>\n";
	}

    # #
    #   Messenger v2 > Build Apache <VirtualHost> - Port :443 https
    # #

	if ($config{MESSENGER_HTTPS_IN} ne "") {
		my %sslcerts;
		my %sslkeys;
		my %ssldomains;
		my $start = 0;
		my $sslhost;
		my $sslcert;
		my $sslkey;
		my $sslaliases;
		my $ssldir = "/var/lib/csf/ssl/";
		unless (-d $ssldir) {
			mkdir $ssldir;
			mkdir $ssldir."certs/";
			mkdir $ssldir."keys/";
		}
		foreach my $file (glob($config{MESSENGER_HTTPS_CONF})) {
			if (-e $file) {
				foreach my $line (ConfigServer::Slurp::slurp($file)) {
					$line =~ s/\'|\"//g;
					if ($line =~ /^\s*<VirtualHost\s+[^\>]+>/) {
						$start = 1;
					}
					if ($webserver eq "apache" and $start) {
						if ($line =~ /\s*ServerName\s+(\w+:\/\/)?([a-zA-Z0-9\.\-]+)(:\d+)?/) {$sslhost = $2}
						if ($line =~ /\s*ServerAlias\s+(.*)/) {$sslaliases .= " ".$1}
						if ($line =~ /\s*SSLCertificateFile\s+(\S+)/) {
							my $match = $1;
							if (-e $match) {
								File::Copy::copy($match, $ssldir."certs/".$sslhost."\.crt");
								$sslcert = $ssldir."certs/".$sslhost."\.crt";
							}
						}
						if ($line =~ /\s*SSLCertificateKeyFile\s+(\S+)/) {
							my $match = $1;
							if (-e $match) {
								File::Copy::copy($match, $ssldir."keys/".$sslhost."\.key");
								$sslkey = $ssldir."keys/".$sslhost."\.key";
							}
						}
					}
					
					if (($webserver eq "apache" and $line =~ /^\s*<\/VirtualHost\s*>/)) {
						$start = 0;
						if ($sslhost ne "" and !ConfigServer::CheckIP::checkip($sslhost) and $sslcert ne "") {
							$ssldomains{$sslhost}{key} = $sslkey;
							$ssldomains{$sslhost}{aliases} = $sslaliases;
							$ssldomains{$sslhost}{cert} = $sslcert;
						}
						$sslhost = "";
						$sslcert = "";
						$sslkey = "";
						$sslaliases = "";
					}
				}
			}
		}
		if (scalar(keys %ssldomains < 1))
        {
            return _throw_err( 2, "No SSL domains found in MESSENGER_HTTPS_CONF location" );
		}

		print $OUT "Listen 0.0.0.0:$config{MESSENGER_HTTPS}\n";
		if ($config{IPV6}) {print $OUT "Listen [::]:$config{MESSENGER_HTTPS}\n"}
		if (-e $config{MESSENGER_HTTPS_KEY}) {
			print $OUT "<VirtualHost *:$config{MESSENGER_HTTPS}>\n";
			print $OUT " ServerName $hostname\n";
			print $OUT " DocumentRoot $public_html\n";
			print $OUT " UseCanonicalName Off\n";
			print $OUT " <Directory \"$homedir\">\n";
			print $OUT "  AllowOverride All\n";
			print $OUT " </Directory>\n";
			print $OUT " <IfModule suphp_module>\n";
			print $OUT "   suPHP_UserGroup $config{MESSENGER_USER} $config{MESSENGER_USER}\n";
			print $OUT " </IfModule>\n";
			print $OUT " <IfModule suexec_module>\n";
			print $OUT "   <IfModule !mod_ruid2.c>\n";
			print $OUT "     SuexecUserGroup $config{MESSENGER_USER} $config{MESSENGER_USER}\n";
			print $OUT "   </IfModule>\n";
			print $OUT " </IfModule>\n";
			print $OUT " <IfModule ruid2_module>\n";
			print $OUT "   RMode config\n";
			print $OUT "   RUidGid $config{MESSENGER_USER} $config{MESSENGER_USER}\n";
			print $OUT " </IfModule>\n";
			print $OUT " <IfModule mpm_itk.c>\n";
			print $OUT "   AssignUserID $config{MESSENGER_USER} $config{MESSENGER_USER}\n";
			print $OUT " </IfModule>\n";
			print $OUT " SSLEngine on\n";
			if (-e $config{MESSENGER_HTTPS_KEY}) {
				File::Copy::copy($config{MESSENGER_HTTPS_KEY}, $ssldir."keys/".$hostname."\.key");
				print $OUT " SSLCertificateKeyFile ".$ssldir."keys/".$hostname."\.key\n";
			}
			if (-e $config{MESSENGER_HTTPS_CRT}) {
				File::Copy::copy($config{MESSENGER_HTTPS_CRT}, $ssldir."certs/".$hostname."\.crt");
				print $OUT " SSLCertificateFile ".$ssldir."certs/".$hostname."\.crt\n";
			}
			print $OUT " SSLUseStapling off\n";
			print $OUT " KeepAlive Off\n";
			print $OUT "</VirtualHost>\n";
		}
	
		foreach my $key (keys %ssldomains) {
			if ($key eq "") {next}
			if ($key =~ /^\s+$/) {next}
			if (-e $ssldomains{$key}{cert}) {
				print $OUT "<VirtualHost *:$config{MESSENGER_HTTPS}>\n";
				print $OUT " ServerName $key\n";
				print $OUT " ServerAlias $ssldomains{$key}{aliases}\n";
				print $OUT " DocumentRoot $public_html\n";
				print $OUT " UseCanonicalName Off\n";
				print $OUT " <Directory \"$homedir\">\n";
				print $OUT "  AllowOverride All\n";
				print $OUT " </Directory>\n";
				print $OUT " <IfModule suphp_module>\n";
				print $OUT "   suPHP_UserGroup $config{MESSENGER_USER} $config{MESSENGER_USER}\n";
				print $OUT " </IfModule>\n";
				print $OUT " <IfModule suexec_module>\n";
				print $OUT "   <IfModule !mod_ruid2.c>\n";
				print $OUT "     SuexecUserGroup $config{MESSENGER_USER} $config{MESSENGER_USER}\n";
				print $OUT "   </IfModule>\n";
				print $OUT " </IfModule>\n";
				print $OUT " <IfModule ruid2_module>\n";
				print $OUT "   RMode config\n";
				print $OUT "   RUidGid $config{MESSENGER_USER} $config{MESSENGER_USER}\n";
				print $OUT " </IfModule>\n";
				print $OUT " <IfModule mpm_itk.c>\n";
				print $OUT "   AssignUserID $config{MESSENGER_USER} $config{MESSENGER_USER}\n";
				print $OUT " </IfModule>\n";
				print $OUT " SSLEngine on\n";
				if (-e $ssldomains{$key}{cert}) {print $OUT " SSLCertificateFile $ssldomains{$key}{cert}\n"}
				if (-e $ssldomains{$key}{key}) {print $OUT " SSLCertificateKeyFile $ssldomains{$key}{key}\n"}
				print $OUT " SSLUseStapling off\n";
				print $OUT " KeepAlive Off\n";
				print $OUT "</VirtualHost>\n";
			}
		}
	}
	close ($OUT);

    # #
    #   Messenger / Apache
    #   
    #   OPEN /var/lib/csf/csf.conf
    #       missing file    => create
    #       existing file   => empty first, then write from scratch
    #   BUILD <Virtualhost>
    #       Generate apache http port :80 <VirtualHost> if MESSENGER_HTML_IN exists
    #       Generate apache https port :443 <VirtualHost> if MESSENGER_HTTPS_IN exists
    #   COPY /var/lib/csf/csf.conf => /etc/httpd/conf.d/csf.messenger.conf
    # #

	system( "cp", "-f", "/var/lib/csf/csf.conf", "/etc/apache2/conf.d/csf.messenger.conf" );

	my ($childin, $childout);
	my $cmdpid 	= IPC::Open3::open3($childin, $childout, $childout, "/usr/sbin/apachectl", "configtest");
	my @data 	= <$childout>;

	waitpid ( $cmdpid, 0 );

	if (-e "/var/lib/csf/apachectl.error") {unlink("/var/lib/csf/apachectl.error")}

	my $ok = 0;
	foreach (@data)
	{
		if ($_ =~ /^Syntax OK/) {$ok = 1}
	}

	if ($ok) {
		system("/scripts/restartsrv_httpd");
		ConfigServer::Logger::logfile("MESSENGERV2: Started Apache MESSENGERV2 service using /etc/apache2/conf.d/csf.messenger.conf");
	} else {
		ConfigServer::Logger::logfile("*MESSENGERV2*: Unable to generate a valid Apache configuration, see /var/lib/csf/apachectl.error");
		if (-e "/etc/apache2/conf.d/csf.messenger.conf") {unlink("/etc/apache2/conf.d/csf.messenger.conf")}
		system("/scripts/restartsrv_httpd");
		
		open (my $ERROR, ">", "/var/lib/csf/apachectl.error");
		flock ($ERROR, Fcntl::LOCK_EX);
		foreach (@data) {print $ERROR $_}
		close ($ERROR);
	}

	return;
}

sub messengerv3
{
    ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V3_SOURCE . "] Initializing subroutine" );

	my ( undef, undef, $uid, $gid, undef, undef, undef, $homedir ) = getpwnam( $config{MESSENGER_USER} );

	# #
	#	Reject root. Messenger must never run as uid/gid 0.
	# #

    my $messenger_user = defined $config{MESSENGER_USER} && $config{MESSENGER_USER} ne "" ? $config{MESSENGER_USER} : "missing";
	if ( !defined $uid or !defined $gid or $uid <= 0 or $gid <= 0 )
	{
        return _throw_err(
            3,
            "MESSENGER_USER must specify a valid user with uid and gid greater than 0 [Configured: $messenger_user]"
        );
	}

	if ( $homedir eq "" or $homedir eq "/" or $homedir =~ m[/etc/csf] ) 
    {
        return _throw_err( 3, "The home directory for $config{MESSENGER_USER} is not valid [$homedir]" );
	}

	if ( ! -e $homedir )
	{
        return _throw_err( 3, "The home directory for $config{MESSENGER_USER} does not exist [$homedir]" );
	}

	my $public_html = $homedir . "/public_html";
    ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V3_SOURCE . "] Declared public_html path: $public_html" );

	if ( !-e $public_html )
    {
		system( "mkdir", "-p", $public_html );
		system( "chown", "$config{MESSENGER_USER}:$config{MESSENGERV3GROUP}", $public_html );
		system( "chmod", $config{MESSENGERV3PERMS}, $public_html );

        ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V3_SOURCE . "] Created public_html path: $public_html - chown:[$config{MESSENGER_USER}:$config{MESSENGERV3GROUP}] - chmod:$config{MESSENGERV3PERMS}" );
    }
    else
    {
        ConfigServer::Logger::logfile( "debug:1", "info", "[" . MESSENGER_V3_SOURCE . "] Skip creating public_html path: $public_html - already exists" );
	}

	if ( !-e $public_html . "/.htaccess" )
	{
		open    (my $HTACCESS, ">", $public_html."/.htaccess");
		flock ($HTACCESS, Fcntl::LOCK_EX);
		print $HTACCESS <<EOF;
Require all granted
DirectoryIndex index.php index.cgi index.html index.htm
#Options +FollowSymLinks +ExecCGI
RewriteEngine On
RewriteCond \%{REQUEST_FILENAME} !-f
RewriteCond \%{REQUEST_FILENAME} !-d
RewriteRule ^ /index.php [L,QSA]
EOF
		system("chown","$config{MESSENGER_USER}:$config{MESSENGER_USER}",$public_html."/.htaccess");
		system("chmod","644",$public_html."/.htaccess");
	}

	unless ( -e $public_html . "/index.php" )
	{
		if ($config{RECAPTCHA_SITEKEY})
		{
            ConfigServer::Logger::logfile( "debug:1", "info", "[reCAPTCHA] sitekey [" . ( $config{RECAPTCHA_SITEKEY} ne "" ? "provided" : "empty" ) . "] - Copying recaptcha file (/etc/csf/messenger/index.recaptcha.php) => $public_html/index.php" );
			system( "cp", "/etc/csf/messenger/index.recaptcha.php", $public_html . "/index.php" );
		}
		else
		{
            ConfigServer::Logger::logfile( "debug:1", "info", "[reCAPTCHA] sitekey [" . ( $config{RECAPTCHA_SITEKEY} ne "" ? "provided" : "empty" ) . "] - Copying recaptcha file (/etc/csf/messenger/index.php) => $public_html/index.php" );
			system( "cp", "/etc/csf/messenger/index.php" , $public_html . "/index.php" );
		}

		system( "chown", "$config{MESSENGER_USER}:$config{MESSENGER_USER}", $public_html . "/index.php" );
		system( "chmod", "644", $public_html . "/index.php" );
    }
    else
    {
        ConfigServer::Logger::logfile( "debug:1", "info", "[reCAPTCHA] sitekey [" . ( $config{RECAPTCHA_SITEKEY} ne "" ? "provided" : "empty" ) . "] - Found $public_html/index.php - skipping cp file from /etc/csf/messenger/" );
	}

	unless (-e $homedir."/en.php") {
		system("cp","/etc/csf/messenger/en.php",$homedir."/en.php");
		system("chown","$config{MESSENGER_USER}:$config{MESSENGER_USER}",$homedir."/en.php");
		system("chmod","644",$homedir."/en.php");
	}
	
	open ( my $CONF, ">", $homedir . "/recaptcha.php" );
	flock ( $CONF, Fcntl::LOCK_EX );
	print $CONF "<?php\n";
	print $CONF "\$secret = '$config{RECAPTCHA_SECRET}';\n";
	print $CONF "\$sitekey = '$config{RECAPTCHA_SITEKEY}';\n";
	print $CONF "\$unblockfile = '$homedir/unblock.txt';\n";
	print $CONF "\$logfile = '/var/log/lfd_messenger.log';\n";
	print $CONF "?>\n";
	system( "chown", "$config{MESSENGER_USER}:$config{MESSENGER_USER}", $homedir . "/recaptcha.php" );
	system( "chmod", "600", $homedir . "/recaptcha.php" );

	if ($config{MESSENGERV3WEBSERVER} eq "apache")
	{
		$webserver = "apache";
	}
	elsif ($config{MESSENGERV3WEBSERVER} eq "litespeed")
	{
		$webserver = "litespeed";
	}

	open (my $OUT, ">", "/var/lib/csf/csf.conf");
	flock ($OUT, Fcntl::LOCK_EX);

	if ($config{MESSENGERV3PHPHANDLER} ne "") {
		$phphandler = $config{MESSENGERV3PHPHANDLER};
	} else {
		my $file = "/etc/httpd/conf/extra/httpd-hostname.conf";
		if (-e $file) {
			foreach my $line (ConfigServer::Slurp::slurp($file)) {
				if ($line =~ /^\s*AddHandler\s+.+\s+\.php/) {
					$phphandler = $line;
					if ($config{DEBUG} >= 1) {ConfigServer::Logger::logfile("SSL: PHP Handler found in [$file]")}
				}
			}
		}
	}

	foreach my $line (ConfigServer::Slurp::slurp("/usr/local/csf/tpl/$webserver.main.txt")) {
		$line =~ s/\[PORT\]/$config{MESSENGER_HTML}/g;
		if ($line =~ /Listen \[::\]:/ and !$config{IPV6}) {next}
		$line =~ s/\[SERVERNAME\]/$hostname/g;
		$line =~ s/\[DOCUMENTROOT\]/$public_html/g;
		$line =~ s/\[DIRECTORY\]/$homedir/g;
		$line =~ s/\[USER\]/$config{MESSENGER_USER}/g;
		$line =~ s/\[PHPHANDLER\]/$phphandler/g;
		print $OUT $line."\n";
	}
	
	if ($config{MESSENGER_HTML_IN} ne "") {
		foreach my $line (ConfigServer::Slurp::slurp("/usr/local/csf/tpl/$webserver.http.txt")) {
			$line =~ s/\[PORT\]/$config{MESSENGER_HTML}/g;
			if ($line =~ /Listen \[::\]:/ and !$config{IPV6}) {next}
			$line =~ s/\[SERVERNAME\]/$hostname/g;
			$line =~ s/\[DOCUMENTROOT\]/$public_html/g;
			$line =~ s/\[DIRECTORY\]/$homedir/g;
			$line =~ s/\[USER\]/$config{MESSENGER_USER}/g;
			$line =~ s/\[PHPHANDLER\]/$phphandler/g;
			print $OUT $line."\n";
		}
	}

	if ($config{MESSENGER_HTTPS_IN} ne "") {
		if ($webserver eq "litespeed") {
			if ($config{MESSENGERV3HTTPS_CONF} =~ /(.*\/lsws\/)/) {
				$serverroot = $1;
			}
		}
		&conftree($config{MESSENGERV3HTTPS_CONF});
		if ($webserver eq "litespeed") {
			if ($sslhost ne "" and $osslcert ne "" and $ssldomains{$sslhost}{cert} eq "") {
				if (-e $osslcert) {
					$sslcert = $ssldir."certs/".$sslhost."\.crt";
					File::Copy::copy($osslcert, $ssldir."certs/".$sslhost."\.crt");
				}
				if (-e $osslkey) {
					$sslkey = $ssldir."keys/".$sslhost."\.key";
					File::Copy::copy($osslkey, $ssldir."keys/".$sslhost."\.key");
				}
				if (-e $osslca) {
					$sslca = $ssldir."ca/".$sslhost."\.ca";
					File::Copy::copy($osslca, $ssldir."ca/".$sslhost."\.ca");
				}
				$sslaliases =~ s/\$VH_NAME/$sslhost/;
				$ssldomains{$sslhost}{key} = $sslkey;
				$ssldomains{$sslhost}{aliases} = $sslaliases;
				$ssldomains{$sslhost}{cert} = $sslcert;
				$ssldomains{$sslhost}{ca} = $sslca;
				push @ssldomainkeys, $sslhost;

				$sslhost = "";
				$sslcert = "";
				$sslkey = "";
				$sslca = "";
				$osslcert = "";
				$osslkey = "";
				$osslca = "";
				$sslaliases = "";
			}
		}

		if ( scalar( keys %ssldomains < 1 ) )
        {
            return _throw_err( 1, "No SSL domains found in MESSENGERV3HTTPS_CONF location [$config{MESSENGERV3HTTPS_CONF}] for $webserver web server" );
		}

		my @virtualhost;
		my $start = 0;
		my $key = $ssldomainkeys[0];
		foreach my $line (ConfigServer::Slurp::slurp("/usr/local/csf/tpl/$webserver.https.txt")) {
			if ($line =~ /^\# Virtualhost start/) {$start = 1}
			if ($start) {
				if ($line =~ /^\# Virtualhost end/) {$start = 0}
				push @virtualhost, $line;
				next;
			}
			$line =~ s/\[SSLPORT\]/$config{MESSENGER_HTTPS}/g;
			if ($line =~ /Listen \[::\]:/ and !$config{IPV6}) {next}
			$line =~ s/\[SERVERNAME\]/$hostname/g;
			$line =~ s/\[DOCUMENTROOT\]/$public_html/g;
			$line =~ s/\[DIRECTORY\]/$homedir/g;
			$line =~ s/\[USER\]/$config{MESSENGER_USER}/g;
			$line =~ s/\[PHPHANDLER\]/$phphandler/g;
			if ($line =~ /[MAPS]/) {
				my $mapping;
				foreach my $map (@ssldomainkeys) {
					if (-e $ssldomains{$map}{cert}) {
						$mapping .= "map csfssl.${map} ${map}\n\t";
					}
				}
				$line =~ s/\[MAPS\]/$mapping/g;
			}
			if ($line =~ /\[SSLCERTIFICATEFILE\]/) {
				if ( -e $ssldomains{$key}{cert}) {
					$line =~ s/\[SSLCERTIFICATEFILE\]/$ssldomains{$key}{cert}/g;
				} else {next}
			}

			if ($line =~ /\[SSLCERTIFICATEKEYFILE\]/) {
				if (-e $ssldomains{$key}{key}) {
					$line =~ s/\[SSLCERTIFICATEKEYFILE\]/$ssldomains{$key}{key}/g;
				} else {next}
			}

			if ($line =~ /\[SSLCACERTIFICATEFILE\]/) {
				if (-e $ssldomains{$key}{ca}) {
					$line =~ s/\[SSLCACERTIFICATEFILE\]/$ssldomains{$key}{ca}/g;
				} else {next}
			}

			print $OUT $line."\n";
		}

        # #
        #   /usr/local/csf/tpl/apache.https.txt
        #       /etc/httpd/conf.d/csf.messenger.conf
        #       /var/lib/csf/csf.conf
        # #

		foreach my $key (@ssldomainkeys) {
			if ($key eq "") {next}
			if ($key =~ /^\s+$/) {next}
			if ($config{DEBUG} >= 1) {ConfigServer::Logger::logfile("SSL: Processing [$key]")}

			if (-e $ssldomains{$key}{cert}) {
				foreach (@virtualhost) {
					my $line = $_;
					$line =~ s/\[SSLPORT\]/$config{MESSENGER_HTTPS}/g;
					$line =~ s/\[SERVERNAME\]/$key/g;
					$line =~ s/\[SERVERALIAS\]/$ssldomains{$key}{aliases}/g;
					$line =~ s/\[DOCUMENTROOT\]/$public_html/g;
					$line =~ s/\[DIRECTORY\]/$homedir/g;
					$line =~ s/\[USER\]/$config{MESSENGER_USER}/g;
					$line =~ s/\[PHPHANDLER\]/$phphandler/g;

					if ($line =~ /\[SSLCERTIFICATEFILE\]/) {
						if ( -e $ssldomains{$key}{cert}) {
							$line =~ s/\[SSLCERTIFICATEFILE\]/$ssldomains{$key}{cert}/g;
						} else {next}
					}

					if ($line =~ /\[SSLCERTIFICATEKEYFILE\]/) {
						if (-e $ssldomains{$key}{key}) {
							$line =~ s/\[SSLCERTIFICATEKEYFILE\]/$ssldomains{$key}{key}/g;
						} else {next}
					}

					if ($line =~ /\[SSLCACERTIFICATEFILE\]/) {
						if (-e $ssldomains{$key}{ca}) {
							$line =~ s/\[SSLCACERTIFICATEFILE\]/$ssldomains{$key}{ca}/g;
						} else {next}
					}

					print $OUT $line."\n";
				}
			}
		}
	}
	close ($OUT);

	my $location;
	if (-d $config{MESSENGERV3LOCATION}) {
		system("cp","-f","/var/lib/csf/csf.conf",$config{MESSENGERV3LOCATION}."/csf.messenger.conf");
		$location = $config{MESSENGERV3LOCATION}."/csf.messenger.conf";
	}
	elsif (-f $config{MESSENGERV3LOCATION}) {
		my @conf = ConfigServer::Slurp::slurp($config{MESSENGERV3LOCATION});
		unless (grep {$_ =~ m[^Include /var/lib/csf/csf.conf]i} @conf) {
			sysopen (my $FILE, $config{MESSENGERV3LOCATION}, Fcntl::O_WRONLY() | Fcntl::O_APPEND() | Fcntl::O_CREAT() );
			flock ($FILE, Fcntl::LOCK_EX);
			if ($webserver eq "apache") {
				print $FILE "Include /var/lib/csf/csf.conf\n";
			}
			elsif ($webserver eq "litespeed") {
				print $FILE "include /var/lib/csf/csf.conf\n";
			}
			close ($FILE);
		}
		$location = $config{MESSENGERV3LOCATION};
	}
	else
    {
        return _throw_err( 3, "[$config{MESSENGERV3LOCATION}] is neither a directory nor a file. You must manually include /var/lib/csf/csf.conf into the $webserver configuration" );
	}

	if ($config{MESSENGERV3TEST} ne "") {
		my ($childin, $childout);
		my $cmdpid = IPC::Open3::open3($childin, $childout, $childout, $config{MESSENGERV3TEST});
		my @data = <$childout>;
		waitpid ($cmdpid, 0);

		if (-e "/var/lib/csf/messenger.error") {unlink("/var/lib/csf/messenger.error")}
		my $ok = 0;
		foreach (@data) {
			if ($_ =~ /^Syntax OK/) {$ok = 1}
		}
		if ($ok) {
			system($config{MESSENGERV3RESTART});
			ConfigServer::Logger::logfile("MESSENGERV3: Restarted $webserver MESSENGERV3 service using $location");
		} else {
			open (my $ERROR, ">", "/var/lib/csf/messenger.error");
			flock ($ERROR, Fcntl::LOCK_EX);
			foreach (@data) {print $ERROR $_}
			close ($ERROR);

			if (-d $config{MESSENGERV3LOCATION}) {
				unlink ($config{MESSENGERV3LOCATION}."/csf.messenger.conf");
			}
			elsif (-f $config{MESSENGERV3LOCATION}) {
				my @conf = ConfigServer::Slurp::slurp($config{MESSENGERV3LOCATION});
				if (grep {$_ =~ m[^Include /var/lib/csf/csf.conf]i} @conf) {
					sysopen (my $FILE, $config{MESSENGERV3LOCATION}, Fcntl::O_WRONLY() | Fcntl::O_CREAT() | Fcntl::O_TRUNC() );
					flock ($FILE, Fcntl::LOCK_EX);
					foreach my $line (@conf) {
						$line =~ s/$cleanreg//g;
						if ($line =~ m[^Include /var/lib/csf/csf.conf]i) {next}
						print $FILE $line."\n";
					}
					close ($FILE);
				}
			}

			system($config{MESSENGERV3RESTART});

			ConfigServer::Logger::logfile("*MESSENGERV3*: Unable to generate a valid $webserver configuration, see /var/lib/csf/messenger.error");
		}
	} else {
		system($config{MESSENGERV3RESTART});
		ConfigServer::Logger::logfile("MESSENGERV3: Restarted $webserver MESSENGERV3 service using $location");
	}
	return;
}

sub childcleanup
{
	$SIG{INT}       = 'IGNORE';
	$SIG{TERM}      = 'IGNORE';
	$SIG{HUP}       = 'IGNORE';

	my $line        = shift;
	my $message     = shift;

    # #
    #   @test           Note:           Trigger SHUTDOWN
    #                   Command:        sudo pkill -TERM -f '^lfd TEXT messenger$'
    # #

	if (($message eq "") and $line) {
		$message = "SHUTDOWN: Child $childproc: $line";
		$line = "";
	}

	$0 = "child - aborting";

	if ( $message )
    {
		if ( $line ne "" )
        {
            $message .= ", at line $line"
        }

		ConfigServer::Logger::logfile( "$message" );
	}

    exit;
}

sub getethdev
{
	my $ethdev = ConfigServer::GetEthDev->new();
	my %g_ipv4 = $ethdev->ipv4;
	my %g_ipv6 = $ethdev->ipv6;

	foreach my $key (keys %g_ipv4)
	{
		my $netip = Net::IP->new($key);
		my $type = $netip->iptype();
		if ($type eq "PUBLIC") {$ips{$key} = 1}
	}

	if ($config{IPV6}) {
		foreach my $key (keys %g_ipv6) {
			if ($key !~ m[::1/128]) {
				eval {
					local $SIG{__DIE__} = undef;
					$ipscidr6->add($key);
				};
			}
		}
	}
	return;
}

sub error
{
	my $error = shift;
	ConfigServer::Logger::logfile($error);
	exit;
}

sub conftree
{
	my $fileglob = shift;
	foreach my $file (glob($fileglob)) {
		if ($file =~ /csf\.messenger\.conf$/) {next}
		if ($file =~ /\/var\/lib\/csf\/csf.conf$/) {next}
		if (-e $file) {
			if ($config{DEBUG} >= 1) {ConfigServer::Logger::logfile("SSL: Processing [$file]")}
			my $start = 0;
			foreach my $line (ConfigServer::Slurp::slurp($file)) {
				if ($webserver eq "apache") {
					$line =~ s/\'|\"//g;
					if ($line =~ /^\s*ServerRoot\s+\"?(\S+)\"?/) {
						$serverroot = $1;
						unless (-d $serverroot) {$serverroot = ""}
					}
					if ($serverroot eq "" and -d "/etc/apache2") {$serverroot = "/etc/apache2"}
					if ($line =~ /^\s*Include\s+(\S+)/) {
						my $include = $1;
						if ($include !~ /^\//) {$include = "$serverroot/$include"}
						if ($config{DEBUG} >= 1) {ConfigServer::Logger::logfile("SSL: Including [$include]")}
						&conftree($include);
					}
					if ($line =~ /^\s*IncludeOptional\s+(\S+)/) {
						my $include = $1;
						if ($include !~ /^\//) {$include = "$serverroot/$include"}
						if ($config{DEBUG} >= 1) {ConfigServer::Logger::logfile("SSL: IncludeOptional [$include]")}
						&conftree($include);
					}
					if ($line =~ /^\s*<VirtualHost\s+[^\>]+>/) {
						$start = 1;
					}
					if ($start) {
						if ($line =~ /\s*ServerName\s+(\w+:\/\/)?([a-zA-Z0-9\.\-]+)(:\d+)?/) {$sslhost = $2}
						if ($line =~ /\s*ServerAlias\s+(.*)/) {$sslaliases .= " ".$1}
						if ($line =~ /\s*SSLCertificateFile\s+(\S+)/) {
							my $match = $1;
							if (-e $match) {
								$osslcert = $match;
								ConfigServer::Logger::logfile("SSL: Found [$sslhost] certificate in [$file]");
							}
						}
						if ($line =~ /\s*SSLCertificateKeyFile\s+(\S+)/) {
							my $match = $1;
							if (-e $match) {
								$osslkey = $match;
								ConfigServer::Logger::logfile("SSL: Found [$sslhost] key in [$file]");
							}
						}
						if ($line =~ /\s*SSLCACertificateFile\s+(\S+)/) {
							my $match = $1;
							if (-e $match) {
								$osslca = $match;
								ConfigServer::Logger::logfile("SSL: Found [$sslhost] ca bundle in [$file]");
							}
						}
					}
					
					if ($line =~ /^\s*<\/VirtualHost\s*>/) {
						$start = 0;
						if ($sslhost ne "" and !ConfigServer::CheckIP::checkip($sslhost) and $osslcert ne "") {
							if (-e $osslcert) {
								$sslcert = $ssldir."certs/".$sslhost."\.crt";
								File::Copy::copy($osslcert, $ssldir."certs/".$sslhost."\.crt");
							}
							if (-e $osslkey) {
								$sslkey = $ssldir."keys/".$sslhost."\.key";
								File::Copy::copy($osslkey, $ssldir."keys/".$sslhost."\.key");
							}
							if (-e $osslca) {
								$sslca = $ssldir."ca/".$sslhost."\.ca";
								File::Copy::copy($osslca, $ssldir."ca/".$sslhost."\.ca");
							}
							$ssldomains{$sslhost}{key} = $sslkey;
							$ssldomains{$sslhost}{aliases} = $sslaliases;
							$ssldomains{$sslhost}{cert} = $sslcert;
							$ssldomains{$sslhost}{ca} = $sslca;
							push @ssldomainkeys, $sslhost;
							if ($config{DEBUG} >= 1) {ConfigServer::Logger::logfile("SSL: Found [$sslhost] in [$file]")}
						}
						$sslhost = "";
						$sslcert = "";
						$sslkey = "";
						$sslca = "";
						$osslcert = "";
						$osslkey = "";
						$osslca = "";
						$sslaliases = "";
					}
				}
				elsif ($webserver eq "litespeed") {
					$line =~ s/\'|\"//g;
					if ($line =~ /^\s*include\s+(\S+)/) {
						my $include = $1;
						$include =~ s/\$SERVER_ROOT/$serverroot/;
						$include =~ s/\$VH_NAME/$sslhost/;
						if ($include !~ /^\//) {$include = "$serverroot/$include"}
						if ($config{DEBUG} >= 1) {ConfigServer::Logger::logfile("SSL: include [$include]")}
						&conftree($include);
					}
					if ($line =~ /^\s*configFile\s+(\S+)/) {
						my $include = $1;
						$include =~ s/\$SERVER_ROOT/$serverroot/;
						$include =~ s/\$VH_NAME/$sslhost/;
						if ($include !~ /^\//) {$include = "$serverroot/$include"}
						if ($config{DEBUG} >= 1) {ConfigServer::Logger::logfile("SSL: configFile [$include]")}
						&conftree($include);
					}
					if ($line =~ /^\s*virtualHost\s+([^\{]+)\s+\{/) {
						my $newsslhost = $1;
						if ($newsslhost ne "" and $config{DEBUG} >= 1) {ConfigServer::Logger::logfile("SSL: Found [$newsslhost] in [$file]")}
						if ($litestart == 1) {
							if ($sslhost ne "" and $osslcert ne "") {
								if (-e $osslcert) {
									$sslcert = $ssldir."certs/".$sslhost."\.crt";
									File::Copy::copy($osslcert, $ssldir."certs/".$sslhost."\.crt");
								}
								if (-e $osslkey) {
									$sslkey = $ssldir."keys/".$sslhost."\.key";
									File::Copy::copy($osslkey, $ssldir."keys/".$sslhost."\.key");
								}
								if (-e $osslca) {
									$sslca = $ssldir."ca/".$sslhost."\.ca";
									File::Copy::copy($osslca, $ssldir."ca/".$sslhost."\.ca");
								}
								$sslaliases =~ s/\$VH_NAME/$sslhost/;
								$ssldomains{$sslhost}{key} = $sslkey;
								$ssldomains{$sslhost}{aliases} = $sslaliases;
								$ssldomains{$sslhost}{cert} = $sslcert;
								$ssldomains{$sslhost}{ca} = $sslca;
								push @ssldomainkeys, $sslhost;

								$sslhost = "";
								$sslcert = "";
								$sslkey = "";
								$sslca = "";
								$osslcert = "";
								$osslkey = "";
								$osslca = "";
								$sslaliases = "";
							}
						}
						$litestart = 1;
						$sslhost = $newsslhost;
					}
					if ($litestart) {
						if ($line =~ /\s*vhDomain\s+(\w+:\/\/)?([a-zA-Z0-9\.\-]+)(:\d+)?/) {$sslhost = $2}
						if ($line =~ /\s*vhAliases\s+(.*)/) {$sslaliases .= " ".$1}
						if ($line =~ /\s*certFile\s+(\S+)/) {
							my $match = $1;
							if (-e $match) {
								$osslcert = $match;
								ConfigServer::Logger::logfile("SSL: Found [$sslhost] certificate in [$file]");
							}
						}
						if ($line =~ /\s*keyFile\s+(\S+)/) {
							my $match = $1;
							if (-e $match) {
								$osslkey = $match;
								ConfigServer::Logger::logfile("SSL: Found [$sslhost] key in [$file]");
							}
						}
					}
				}
			}
		}
	}
	return;
}

1;
