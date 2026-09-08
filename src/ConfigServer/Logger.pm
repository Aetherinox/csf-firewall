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
#   @updated            09.08.2026
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
#   @usage          perl -I. -MConfigServer::Logger -e "ConfigServer::Logger::tests_run()"
# #

# #
#   CheckIP › Changelog Notes
#   
#   @tag            15.11 [Logger::core->lazyload]
#   @change         ConfigServer::Logger previously loaded csf.conf as soon as
#                   the module was imported. This forced CSF to load the full
#                   config, even if the Logger did not need it.
#                   
#                   Config now loads only when needed via implementing a
#                   lazy loader.
#   
#                   Loaded config is also cached, csf.conf is only read once.
#   
#   @tag            15.11 [Logger::logfile()->refactor]
#   @change         Re-wrote logfile() to support normal, debug, and root logs.
# #

## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
package ConfigServer::Logger;

use strict;
use lib '/usr/local/csf/lib';
use Carp;
use Cwd qw( abs_path );
use Fcntl qw(:DEFAULT :flock);
use File::Basename qw( dirname );
use File::Path qw( make_path );
use Time::HiRes qw( gettimeofday tv_interval );
use ConfigServer::Config;

# #
#	Logger › Declare › Export
# #

use Exporter    qw( import );
our @EXPORT_OK  = qw( logfile );

# #
#	Logger › Declare › Version
# #

our $VERSION    = 15.11;

# #
#	Logger › Declare › Constants
#   
#   Windows         If manually testing this file on Windows; logs will be
#                   generated in the root project folder:
#                       ./tests
#   
#   Linux           Logs will be stored in:
#                       /var/log
# #

use constant HOSTNAME_DEFAULT   => "csf";
use constant LOGFILE_TEST_DIR   => dirname( dirname( abs_path( __FILE__ ) ) ) . '/tests/var/log';
use constant LOGFILE_DIR        => '/var/log';
use constant LOGFILE_DIR_SUB    => 'csf';
use constant LOGFILE_PROCESS    => 'lfd';
use constant LOGFILE_ROOT       => LOGFILE_DIR_SUB . '/lfd-root.log';
use constant LOGFILE_LFD        => 'lfd.log';
use constant LOGFILE_MESSENGER  => 'lfd_messenger.log';

# #
#   Constants › Generic
#   
#   The following constants can all be created in the same block
#   without a need for each other.
#   
#   Should really be no need to modify these.
# #

use constant
{
    DEBUG                   => 1,
    _PRINT_SEP_LENGTH       => 140
};

# #
#	Logger › Declare › Status
#   
#   Map numeric and string log statuses to their display value.
# #

my %STATUS_MAP =
(
	0       => 'FAIL',
	1       => 'OK',
	2       => 'WARN',
	3       => 'ABORT',
	4       => 'INFO',
	'fail'  => 'FAIL',
	'ok'    => 'OK',
	'warn'  => 'WARN',
	'abort' => 'ABORT',
	'info'  => 'INFO',
);

# #
#	Logger › Define › Colors
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
#   Helper › Debug Prints
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

sub _debug
{
    my ( $level, $code ) = @_;
    return if DEBUG < $level;

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
#   Logger › Config › Lazy Load
#   
#   Load csf.conf config file only when this module actually needs it.
#   
#   Prevent ConfigServer:Logger from immediately requiring the
#   config file.
#   
#   Cache the loaded config so it only needs to be read once.
#   
#   @tag            15.11 [Logger::core->lazyload]
# #

my %config;
my $config_loaded = 0;

sub _config_load
{
	return if $config_loaded;

    logfile( "root", "info", "Load CSF configuration" );

	my $config      = ConfigServer::Config->loadconfig();
	%config         = $config->config();
	$config_loaded  = 1;

    logfile( "root", "ok", "CSF configuration loaded" );

	return;
}

# #
#   Logger › Syslog › Lazy Load
#   
#   Load Sys::Syslog only when SYSLOG is enabled in csf.conf.
#   Skip load if Sys::Syslog has already been initialized.
#   
#   Set $sys_syslog when the module loads successfully.
# #

my $sys_syslog;

sub _syslog_load
{
    if ( sysopen( my $SYSLOG_LOGGED, "/run/lfd-syslog-logged", O_WRONLY | O_CREAT | O_EXCL ) )
    {
        close( $SYSLOG_LOGGED );
        logfile( "root", "info", "Syslog configuration; SYSLOG=$config{SYSLOG}" );
    }

	return if $sys_syslog;
	return if !$config{SYSLOG};

	eval( 'use Sys::Syslog;' ); ##no critic
    if ( !$@ )
    {
        $sys_syslog = 1
    }

    logfile( "root", "info", "\$sys_syslog = " . ( defined $sys_syslog ? $sys_syslog : "undef" ) );

	return;
}

# #
#   Logger › Hostname
#   
#   $hostname   = server01.configserver.dev
#   $hostshort  = server01
# #

my $hostname = HOSTNAME_DEFAULT;
if ( -e "/proc/sys/kernel/hostname" )
{
	open        ( my $IN, "<", "/proc/sys/kernel/hostname" );
	flock       ( $IN, LOCK_SH );
	$hostname   = <$IN>;
	chomp       $hostname;
	close       ( $IN );
}

# #
#   Get short hostname
#       server01.configserver.dev => server01
# #

my $hostshort   = ( split(/\./, $hostname ) )[ 0 ];

# #
#   Logger › Logfile
#   
#   Processes normal and debug logs which are written to the specified lfd log
#   file:
#       /var/log/lfd.log
#   
#   Messages are also transmitted to SYSLOG if the setting is enabled in the
#   /etc/csf/csf.conf config file:
#       SYSLOG = "1"
#   
#   An optional "DEBUG:X" argument ($type) can be passed to this subroutine
#   which allows for a log to be classified as a debug-only log. Each message
#   can be given a specific DEBUG::X level; where X is a value between 0 and 5.
#   The higher the debug level, the more verbose the logs:
#       logfile( "DEBUG:1", "info", "My Debug Message" );
#   
#   DEBUG:0 is always enabled, and is written using the normal log format.
#   DEBUG:1 - DEBUG:5 are only written when the configured DEBUG setting is
#   equal to or higher than the requested level. To change the DEBUG level, 
#   open /etc/csf/csf.conf and modify the setting:
#       DEBUG = "4"
#   
#   $status:        0   FAIL
#   (str|int)       1   OK
#                   2   WARN
#                   3   ABORT
#                   4   INFO                    (default if $status empty)
#   
#   $type:          0   Debug off               (Normal logs)
#   (str)           1   Debug lowest            (Debug logs)
#                   2   Debug low               (Verbose logs)
#                   3   Debug Medium
#                   4   Debug High
#                   5   Debug Highest
#   
#   Supported formats:
#       logfile( "Message" );                           # Normal, INFO
#       logfile( "warn", "Message" );                   # Normal, WARN
#       logfile( "normal", "info", "Message" );         # Normal
#       logfile( "root", "info", "Message" );           # Root only
#       logfile( "all", "ok", "Message" );              # Root + normal
#       logfile( "DEBUG:4", "info", "Message" );        # Debug level 4
#   
#   These two calls produce the same normal log format:
#       logfile( "DEBUG:0", "info", "Message" );
#       logfile( "info", "Message" );
#   
#   @tag            15.11 [Logger::logfile()->refactor]
# #

sub logfile
{
	my ( @args )    = @_;
	my $type        = "normal";
	my $logdir      = $^O eq "MSWin32" ? LOGFILE_TEST_DIR : LOGFILE_DIR;
    my $logdirsub   = LOGFILE_DIR_SUB;

    # #
    #   OS Detection:
    #       linux
    #       MSWin32
    # #

	if ( $^O eq "MSWin32" )
	{
		make_path( $logdir ) if !-d $logdir;
		make_path( "$logdir/$logdirsub" ) if !-d "$logdir/$logdirsub";
	}

	my $status      = 'info';
	my $message;

	if ( @args == 3 )
	{
		$type       = $args[ 0 ];
		$status     = $args[ 1 ];
		$message    = $args[ 2 ];
	}
	elsif ( @args == 2 )
	{
		$status     = $args[ 0 ];
		$message    = $args[ 1 ];
	}
	elsif ( @args == 1 )
	{
		$message    = $args[ 0 ];
	}

    # #
    #   Determine where the log originated.
    # #

	my @caller_direct   = caller( 0 );
	my $file            = $caller_direct[ 1 ] // 'unknown';
	my $line            = $caller_direct[ 2 ];
	my $sub             = ( caller( 1 ) )[ 3 ] // 'unknown';

	$file               =~ s{^.*/}{};
	$file               =~ s{\.pl$}{};
	$sub                =~ s{^.*::}{};
	my $source          = $file . ":" . $line . "->" . $sub . "()";

    # #
    #   Status Mapping
    # #

	$status             = lc $status if $status !~ /^\d+$/;
	$status             = $STATUS_MAP{ $status } // uc $status;

    # #
    #   Log Type
    # #

	my $target          = lc $type;
	my $debug_type      = "";
	my $debug_level;

	if ( $type =~ /^DEBUG:([0-5])$/i )
	{
		$debug_level    = $1;
		$target         = "normal";

		if ( $debug_level > 0 )
		{
			$debug_type = "DEBUG:$debug_level"
		}
	}

    # #
    #   Timestamp
    # #

	my @ts      = split( /\s+/, scalar localtime );
	if ( $ts[ 2 ] < 10 )
    {
        $ts[ 2 ] = " " . $ts[ 2 ]
    }

	my $root_line;
	my $normal_line;
	my $root_written    = 0;
	my $normal_written  = 0;

    # #
    #   Root Log
    #   
    #   Root-only logging intentionally does not load CSF config
    #   or Sys::Syslog.
    # #

	if ( $target eq "root" || $target eq "all" )
	{
		my $logfile_root = "$logdir/" . LOGFILE_ROOT;

		sysopen ( my $LOGFILE, $logfile_root, O_WRONLY | O_APPEND | O_CREAT ) or do
		{
			print STDERR "[ERROR] Unable to open log file [$logfile_root]: $!\n";
			return;
		};

		$root_line = "$ts[ 1 ] $ts[ 2 ] $ts[ 3 ] $hostshort " . LOGFILE_PROCESS . "[ $$ ] [ROOT] [$source] [$status]: $message\n";

		flock   ( $LOGFILE, LOCK_EX );
        print   $LOGFILE $root_line;
		close   ( $LOGFILE );

		$root_written = 1;

		if ( $target eq "root" )
		{
            # #
            #   See @tag for full list / description of each returned
            #   value:
            #   
            #   @tag            15.11 [Logger::logfile->returns]
            # #

			return
			{
				written         => 1,
				root_written    => 1,
				normal_written  => 0,
				suppressed      => 0,
				target          => $target,
				status          => $status,
				source          => $source,
				message         => $message,
				root_line       => $root_line,
			};
		}
	}

    # #
    #   Normal / Debug Log
    # #

	_config_load( );

	if ( defined $debug_level )
	{
		if ( ( $config{DEBUG} // 0 ) < $debug_level )
		{
            # #
            #   See @tag for full list / description of each returned
            #   value:
            #   
            #   @tag            15.11 [Logger::logfile->returns]
            # #

			return
			{
				written         => 0,
				root_written    => 0,
				normal_written  => 0,
				suppressed      => 1,
				target          => $target,
				status          => $status,
				source          => $source,
				message         => $message,
				debug_level     => $debug_level,
			};
		}
	}

	_syslog_load( );

	my $logfile = "$logdir/" . LOGFILE_LFD;
	if ( $< != 0 )
    {
        $logfile = "$logdir/" . LOGFILE_MESSENGER
    }
	
	sysopen ( my $LOGFILE, $logfile, O_WRONLY | O_APPEND | O_CREAT ) or do
	{
		print STDERR "[ERROR] Unable to open log file [$logfile]: $!\n";
		return;
	};

	$normal_line = "$ts[ 1 ] $ts[ 2 ] $ts[ 3 ] $hostshort " . LOGFILE_PROCESS . "[ $$ ] [$source] [$status]" . ( $debug_type ne "" ? " [$debug_type]" : "" ) . ": $message\n";

	flock   ( $LOGFILE, LOCK_EX );
    print   $LOGFILE $normal_line;
	close   ( $LOGFILE );

	$normal_written = 1;

	if ( $config{SYSLOG} and $sys_syslog )
    {
		eval {
			local $SIG{__DIE__} = undef;
			openlog ( LOGFILE_PROCESS, 'ndelay,pid', 'user' );
			syslog  ( 'info', $message );
			closelog( );
		}
	}

    # #
    #   Summary of what is returned
    #   
    #   @tag            15.11 [Logger::logfile->returns]
    #   written         Log was written to at least ONE log file.
    #                       0 = no
    #                       1 = yes
    #   
    #   root_written    Log was written to root /var/log/csf/lfd-root.log file
    #                       0 = no
    #                       1 = yes
    #   
    #   normal_written  Log was written to normal /var/log/lfd.log file.
    #                       0 = no
    #                       1 = yes
    #   
    #   suppressed      If log was blocked by DEBUG > LEVEL check
    #                       0 = message allowed
    #                       1 = message suppressed and not written
    #   
    #   target          Which log type that was written to:
    #                       - normal
    #                       - root
    #                       - all
    #   
    #   status          Final mapped status
    #                       Example:    status => "WARN",
    #   
    #   source          File:line where logfile() was called from.
    #                       Example:    "Logger.pm:454"
    #   
    #   message         Original message passed to logfile()
    #                       Example:    "[TEST] Root log only"
    #   
    #   debug_level     DEBUG level requested by caller:
    #                       Example:    3
    #                       Returns:    undef for a normal/root/all log
    #   
    #   root_line       Complete formatted log written to root log
    #                       Example:    "Sep  7 04:10:00 csf lfd[ 1234 ] [ROOT] [Logger.pm:454] [INFO]: Message\n"
    #                       Returns:    undef if no root log was written
    #   
    #   line            Complete formatted log that was written to normal log
    #                       Example:    "Sep  7 04:10:00 csf lfd[ 1234 ] [Logger.pm:454] [INFO]: Message\n"
    #                       Returns:    undef if no normal log was written
    # #

	return
	{
		written         => $root_written || $normal_written,
		root_written    => $root_written,
		normal_written  => $normal_written,
		suppressed      => 0,
		target          => $target,
		status          => $status,
		source          => $source,
		message         => $message,
		debug_level     => $debug_level,
		root_line       => $root_line,
		line            => $normal_line,
	};
}

# #
#   Logger › Tests › Messages
#   
#   Test each supported feature within this module and verify that the
#   correct result matches our expected value.
#   
#   Tests use a temp logger config; does not require loading CSF's 
#   config module.
#   
#   @note           If manually running tests from a Windows machine; 
#                   logs will be generated in csf root project folder.
#   
#   @todo           Maybe at some point; could write a test suite similar to
#                   Jest or Vitest to make testing more streamlined.
#   
#   @usage          perl -I. -MConfigServer::Logger -e "ConfigServer::Logger::tests_run()"
# #

sub tests_run
{
    my $package         = __PACKAGE__;
    my $sub_full        = ( caller( 0 ) )[3];
    my $sub_name        = $sub_full;
    $sub_name           =~ s/^.*:://;

    my $benchmark_start = [ gettimeofday ];
	my $tests_total     = 0;
	my $tests_passed    = 0;
	my $tests_failed    = 0;
    my $tests_tag       = "TEST";

    # #
    #   Tests › Check
    #   
    #   Store and display results for each of the tests specified.
    # #

	my $check = sub
	{
		my ( $condition, $name ) = @_;

		$tests_total++;
		if ( $condition )
		{
			$tests_passed++;

            print " ",
                $C{greenm},  "[PASS]     ",
                $C{greym},   $name,
                $C{reset},   "\n";
		}
		else
		{
			$tests_failed++;

            print " ",
                $C{redm},    "[FAIL]     ",
                $C{greym},   $name,
                $C{reset},   "\n";
		}
	};

	print "\n";

    print " ",
        $C{greym},      "Starting tests for ",
        $C{orangem},    "$sub_name():",
        $C{reset},      "\n\n";

    # #
    #   Tests › Root › Config Bypass
    #   
    #   Test root-only logging
    # #

	%config         = ();
	$config_loaded  = 0;

	my $result      = logfile( "root", "info", "[$tests_tag] Root config bypass" );
	$check->(
        defined $result && $result->{written} && $result->{root_written} && !$result->{normal_written},
        "Root target writes to root log only"
    );
	$check->( !$config_loaded, "Root target bypasses CSF config loading" );

    # #
    #   Tests › Config › Emulate
    #   
    #   Use temp logger config so tests can run without loading
    #       /etc/csf/csf.conf
    # #

	%config =
	(
		DEBUG   => 5,
		SYSLOG  => 0,
	);

	$config_loaded = 1;

    # #
    #   Tests › Legacy / Normal
    # #

	$result = logfile( "[$tests_tag] Legacy single argument" );
	$check->(
		defined $result && $result->{written} && $result->{normal_written} && $result->{status} eq "INFO" && $result->{message} eq "[$tests_tag] Legacy single argument",
		"Single argument defaults to normal log with INFO status"
	);

	$result = logfile( "warn", "[$tests_tag] Normal log with status" );
	$check->(
		defined $result && $result->{written} && $result->{normal_written} && $result->{status} eq "WARN",
		"Two arguments write normal log with supplied WARN status"
	);

	$result = logfile( "normal", "info", "[$tests_tag] Normal log with explicit type" );
	$check->(
		defined $result && $result->{written} && $result->{normal_written} && $result->{target} eq "normal" && $result->{status} eq "INFO",
		"Explicit normal target writes normal log with INFO status"
	);

    # #
    #   Tests › Log Targets
    # #

	$result = logfile( "root", "info", "[$tests_tag] Root log only" );
	$check->(
		defined $result && $result->{written} && $result->{root_written} && !$result->{normal_written} && $result->{target} eq "root",
		"Root target writes root log and skips normal log"
	);

	$result = logfile( "all", "info", "[$tests_tag] Root and normal log" );
	$check->(
        defined $result && $result->{written} && $result->{root_written} && $result->{normal_written} && $result->{target} eq "all",
		"All target writes both root and normal logs"
	);

    # #
    #   Tests › Status › String
    #   
    #   Test each one of our supported strings in $status; make
    #   sure it converts to the expected display value.
    # #

	my @status_string =
	(
		[ "fail",   "FAIL"  ],
		[ "ok",     "OK"    ],
		[ "warn",   "WARN"  ],
		[ "abort",  "ABORT" ],
		[ "info",   "INFO"  ],
	);

	foreach my $status_test ( @status_string )
	{
		my ( $input, $expected ) = @$status_test;
		$result = logfile( "normal", $input, "[$tests_tag] Status string: $expected" );
		$check->(
			defined $result && $result->{written} && $result->{status} eq $expected,
            "String status '$input' maps to '$expected'"
		);
	}

    # #
    #   Tests › Status › Integer
    #   
    #   Test each one of our supported integers in $status; make
    #   sure it converts to the expected display value.
    # #

	my @status_integer =
	(
		[ 0, "FAIL"     ],
		[ 1, "OK"       ],
		[ 2, "WARN"     ],
		[ 3, "ABORT"    ],
		[ 4, "INFO"     ],
	);

	foreach my $status_test ( @status_integer )
	{
		my ( $input, $expected ) = @$status_test;
		$result = logfile( "normal", $input, "[$tests_tag] Status integer: $expected" );
		$check->(
			defined $result && $result->{written} && $result->{status} eq $expected,
            "Integer status '$input' maps to '$expected'"
		);
	}

    # #
    #   Tests › Debug Levels
    #   
    #   Debug 0 looks entirely different from debug 1-5:
    #   
    #   DEBUG:0
    #       Desc:       Uses normal log formatting
    #       Demo:       Sep  7 10:31:11 configserver lfd[ 155328 ] [lfd:11452] [OK]: Message Here
    #   
    #   DEBUG:1-5
    #       Desc:       Shows [DEBUG:X] level
    #       Demo:       Sep  7 10:31:11 configserver lfd[ 155328 ] [lfd:11452] [OK] [DEBUG:1]: Message Here
    # #

	foreach my $level ( 0 .. 5 )
	{
		$result     = logfile( "DEBUG:$level", "info", "[$tests_tag] DEBUG:$level" );
		my $valid   = defined $result &&
                        $result->{written} &&
                        defined $result->{debug_level} &&
                        $result->{debug_level} == $level &&
                        defined $result->{line};

        # #
        #   Make sure log has the correct format:
        #       DEBUG level = 0:    return normal logs
        #       DEBUG level > 0:    return debug logs
        # #

		if ( $level == 0 )
		{
			$valid = $valid && $result->{line} !~ /\[DEBUG:/;
		}
		else
		{
			$valid = $valid && $result->{line} =~ /\[DEBUG:$level\]/;
		}

		$check->(
			$valid,
			$level == 0
				? "DEBUG:0 writes log without a [DEBUG:X] label"
				: "DEBUG:$level writes log with matching [DEBUG:$level] label"
		);
	}

    # #
    #   Tests › Debug Filtering
    #   
    #   DEBUG:1 and DEBUG:2:        written
    #   DEBUG:3:                    suppressed
    # #

	$config{DEBUG} = 2;

	$result = logfile( "DEBUG:1", "info", "[$tests_tag] DEBUG filter level 1" );
	$check->(
		defined $result && $result->{written} && !$result->{suppressed},
		"DEBUG=2 allows DEBUG:1 log to be written"
	);

	$result = logfile( "DEBUG:2", "info", "[$tests_tag] DEBUG filter level 2" );
	$check->(
		defined $result && $result->{written} && !$result->{suppressed},
		"DEBUG=2 allows matching DEBUG:2 log to be written"
	);

	$result = logfile( "DEBUG:3", "info", "[$tests_tag] DEBUG filter level 3" );
	$check->(
		defined $result && !$result->{written} && $result->{suppressed} && $result->{debug_level} == 3,
		"DEBUG=2 suppresses higher DEBUG:3 log"
	);

	$config{DEBUG} = 5;

    # #
    #   Tests › Case Insensitive
    # #

	$result = logfile( "NORMAL", "INFO", "[$tests_tag] Case insensitive normal/info" );
	$check->(
		defined $result && $result->{target} eq "normal" && $result->{status} eq "INFO",
		"Uppercase NORMAL target is normalized to normal"
	);

	$result = logfile( "debug:1", "OK", "[$tests_tag] Case insensitive debug/ok" );
	$check->(
		defined $result && $result->{written} && $result->{status} eq "OK" && $result->{debug_level} == 1,
		"Lowercase debug:1 and uppercase OK are accepted"
	);

	$result = logfile( "ROOT", "WARN", "[$tests_tag] Case insensitive root/warn" );
	$check->(
		defined $result && $result->{root_written} && $result->{status} eq "WARN" && $result->{target} eq "root",
		"Uppercase ROOT target is normalized and writes root log"
	);

	$result = logfile( "ALL", "OK", "[$tests_tag] Case insensitive all/ok" );
	$check->(
		defined $result && $result->{root_written} && $result->{normal_written} && $result->{status} eq "OK" && $result->{target} eq "all",
		"Uppercase ALL target writes both root and normal logs"
	);

    # #
    #   Tests › Log Metadata
    # #

	$result = logfile( "normal", "info", "[$tests_tag] Log metadata" );
	$check->(
		defined $result && defined $result->{source} && $result->{source} =~ /Logger\.pm:\d+$/,
		"Returned source contains Logger.pm filename and line number"
	);

	$check->(
		defined $result && defined $result->{line} && index( $result->{line}, LOGFILE_PROCESS . "[ $$ ]" ) >= 0,
		"Formatted log line contains process name and current PID"
	);

	$check->(
		defined $result && $result->{message} eq "[$tests_tag] Log metadata" && index( $result->{line}, "[$tests_tag] Log metadata" ) >= 0,
		"Original message is preserved in returned log line"
	);

    # #
    #   Tests › Output › Results
    # #

	print "\n";

    print " ", $C{greyd}, '-' x _PRINT_SEP_LENGTH, "\n";

    print " ",
        $C{greym},      "  Tests are now complete! ",
        $C{reset},      "\n";

    printf "     %s%-13s%s %s%5d%s\n",
        $C{bluem},      "Total:",
        $C{reset},
        $C{bluem},      $tests_total,
        $C{reset};

    printf "     %s%-13s%s %s%5d%s\n",
        $C{greenm},     "Passed:",
        $C{reset},
        $C{greenm},     $tests_passed,
        $C{reset};

    printf "     %s%-13s%s %s%5d%s\n",
        $C{redm},       "Failed:",
        $C{reset},
        $C{redm},       $tests_failed,
        $C{reset};

    print " ", $C{greyd}, '-' x _PRINT_SEP_LENGTH, "\n";

    print "\n";

    # #
    #   Tests › Output › Other
    # #

    my $include             = -e "./ConfigServer/Logger.pm" ? "." : "..";
    my $benchmark_elapsed   = tv_interval( $benchmark_start );
    my $logdir              = $^O eq "MSWin32" ? LOGFILE_TEST_DIR : LOGFILE_DIR;
    my $logfile_normal      = "$logdir/" . LOGFILE_LFD;
    my $logfile_root        = "$logdir/" . LOGFILE_ROOT;
    my $logfile_messenger   = "$logdir/" . LOGFILE_MESSENGER;

    printf "     %s%-16s%s %s%s%s\n",
        $C{greym},      "OS:",
        $C{reset},
        $C{orangem},    "$^O",
        $C{reset};

    printf "     %s%-16s%s %s%s%s\n",
        $C{greym},      "Subroutine:",
        $C{reset},
        $C{orangem},    "$sub_name()",
        $C{reset};

    printf "     %s%-16s%s %s%s%s\n",
        $C{greym},      "Command:",
        $C{reset},
        $C{orangem},    "perl -I$include -M$package -e \"$package\::$sub_name( )\"",
        $C{reset};

    printf "     %s%-16s%s %s%s%s\n",
        $C{greym},      "Normal Log:",
        $C{reset},
        $C{orangem},    $logfile_normal,
        $C{reset};

    printf "     %s%-16s%s %s%s%s\n",
        $C{greym},      "Root Log:",
        $C{reset},
        $C{orangem},    $logfile_root,
        $C{reset};

    printf "     %s%-16s%s %s%s%s\n",
        $C{greym},      "Messenger Log:",
        $C{reset},
        $C{orangem},    $logfile_messenger,
        $C{reset};

    printf "     %s%-16s%s %s%.4f seconds%s ( %s%.2f ms%s )\n",
        $C{greym},      "Elapsed:",
        $C{reset},
        $C{greenm},     $benchmark_elapsed,
        $C{reset},
        $C{greenm},     $benchmark_elapsed * 1000,
        $C{reset};

	print "\n";

	return $tests_failed == 0 ? 1 : 0;
}

1;