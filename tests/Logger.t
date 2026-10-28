#!/usr/bin/env perl

# #
#   @app                ConfigServer Security & Firewall (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.dev
#   @docs               https://docs.configserver.dev
#   @download           https://download.configserver.dev
#   @repo               https://github.com/Aetherinox/csf-firewall
#   @copyright          Copyright (C) 2025-2027 Aetherinox
#                       Copyright (C) 2006-2025 Jonathan Michaelson
#                       Copyright (C) 2006-2025 Way to the Web Ltd.
#   @license            GPLv3
#   @updated            10.27.2026
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
#   Module › Usage & Notes
#   
#   Development notes and usage summary on using this module.
#   
#   COMMANDS:
#       -   Load module directly:
#           sudo perl -I. ConfigServer/Logger.pm
#   
#       -   Check module for syntax errors:
#           sudo perl -I. -c ConfigServer/Logger.pm
#   
#       -   Module docs:
#           perldoc -T ConfigServer/Logger.pm
#   
#       -   Run test suite:
#           sudo prove -I. -v tests/Logger.t
#   
#   
#   INSTALL:
#       Save this file in the git repo:
#           ./tests/Logger.t
#   
#       Run the USAGE commands below from the root of the git repo.
#   
#   
#   USAGE:
#       -   Windows
#           prove -Isrc -v tests/Logger.t
#   
#       -   Linux
#           sudo prove -I. -v tests/Logger.t
#   
#   
#   MODULES:
#       ConfigServer::Config()
#           /usr/local/csf/lib/ConfigServer/Config.pm
#   
#       ConfigServer::Logger()
#           /usr/local/csf/lib/ConfigServer/Logger.pm
#   
#       ConfigServer::Secrets()
#           /usr/local/csf/lib/ConfigServer/Secrets.pm
#   
#   
#   NOTES:
#       Tests support Windows and Linux, with a few notes:
#           -   Tests load local perl modules first. If unavailable,
#               load installed copies from /usr/local/csf/lib.
#   
#           -   Windows skips protected file tests and certain
#               Messenger tests.
#   
#           -   Depending on if you run these tests on Linux or
#               Windows, the path to the test logs will be different:
#   
#               Linux:      /var/log/lfd_test_<pid>.log             (absolute)
#                           /var/log/lfd_root_test_<pid>.log        (absolute)
#                           /var/log/lfd_messenger_test_<pid>.log   (absolute)
#   
#               Windows:    ./tests/var/log/lfd.log                 (relative)
#                           ./tests/var/log/lfd_root.log            (relative)
#                           ./tests/var/log/lfd_messenger.log       (relative)
#   
#           -   Linux expects /var/log/csf to already exist.
#   
#           -   Linux creates unique test logs under /var/log and
#               /var/log/csf. Run with sudo so the files can be
#               created and the Messenger tests can change uid/gid.
#   
#           -   Linux loads csf.conf and uses its DEBUG value.
#   
#           -   TESTS_KEEP_LOGS controls test log cleanup:
#                   0       Remove test logs
#                   1       Keep test logs
# #

# #
#   Declare › Package
# #

package main;

# #
#   Declare › Use
# #

# no strict 'vars';
use strict;
use warnings;
use utf8;
use Cwd         ( );
use Encode      ( );
use FindBin     ( );
use Fcntl       ( );
use File::Path  ( );
use File::Spec  ( );
use File::Temp  ( );
use Test::More;

# #
#   Logger.t › Core › Manually Load Modules
#   
#   These are commented out because I opted to change the loading 
#   order below, and load local copies first.
# #

# use ConfigServer::Secrets ( );
# use ConfigServer::Logger ( );
# use ConfigServer::Config;

# #
#   Logger.t › Core › Module Search Path
#   
#   Add project root to the front of Perl's module search path before
#   loading each CSF module.
#   
#   This makes sure tests use local copies of the modules instead of
#   matching the modules installed in /usr/local/csf/lib
# #

use lib "$FindBin::Bin/..";
use ConfigServer::Config ( );

use lib "$FindBin::Bin/..";
use ConfigServer::Secrets ( );

use lib "$FindBin::Bin/..";
use ConfigServer::Logger ( );

# #
#   Define › Constants
#   
#   TESTS_KEEP_LOGS
#       Determines if logs will remain in the /var/log folder after
#       tests are completed.
#           0       Delete messenger logs after tests completed
#           1       Do not delete logs after tests complete
#   
#   TESTS_CONFIG_FAKE
#       Defines whether a fake DEBUG config value should be used for
#       this test suite.
#       
#       Keep enabled so that tests use a known DEBUG level on Linux
#       and Windows. This tests both written and suppressed logs
#       without depending on csf.conf.
#   
#       Using the live config could send test messages to the real
#       system syslog when SYSLOG is enabled.
#           0       Linux uses real /etc/csf/csf.conf
#                   Windows uses TESTS_CONFIG_WINDOWS_DEBUG
#                       (Logger.pm DEBUG_LEVEL_MAX) 
#           1       Linux and Windows use TESTS_CONFIG_FAKE_DEBUG
#   
#   TESTS_CONFIG_FAKE_DEBUG
#       Defines the fake config DEBUG level to use for tests.
#   
#   TESTS_CONFIG_WINDOWS_DEBUG
#       Uses Logger.pm constant DEBUG_LEVEL_MAX as the expected DEBUG
#       level when running this test suite in Windows with fake
#       config disabled.
#           TESTS_CONFIG_FAKE => 0
#   
#   TESTS_TAG
#       Simple string that just shows within the log
#           Eg:     [TEST] This is a log example
#   
#   TESTS_LOG_STATUS_INFO
#       Status label used for 'info' messages.
#   
#   TESTS_LOG_STATUS_WARN
#       Status label used for 'warn' messages.
#   
#   TESTS_LOG_STATUS_OK
#       Status label used for 'ok' messages.
#   
#   TESTS_LOG_TARGET_ALL
#       Target used for 'all' messages. This target type sends logs
#       to both 'root' and 'normal'.
#   
#       All 'root' logs sent to:        /var/log/lfd_root.log
#       All 'normal' logs sent to:      /var/log/lfd.log
#   
#   TESTS_LOG_TARGET_ROOT
#       Target used for 'root' messages.
#       All 'root' logs sent to:        /var/log/lfd_root.log
#   
#   TESTS_LOG_TARGET_NORMAL
#       Target used for 'normal' messages.
#       All 'normal' logs sent to:      /var/log/lfd.log
# #

use constant
{
	TESTS_KEEP_LOGS             => 0,
    TESTS_CONFIG_FAKE           => 1,
    TESTS_CONFIG_FAKE_DEBUG     => 2,
    TESTS_CONFIG_WINDOWS_DEBUG  => ConfigServer::Logger::DEBUG_LEVEL_MAX( ),
	TESTS_TAG                   => "TEST",
    TESTS_LOG_STATUS_INFO       => "info",
    TESTS_LOG_STATUS_WARN       => "warn",
    TESTS_LOG_STATUS_OK         => "ok",
    TESTS_LOG_TARGET_ALL        => "all",
    TESTS_LOG_TARGET_ROOT       => "root",
    TESTS_LOG_TARGET_NORMAL     => "normal"
};

# #
#   Define › Colors
#   
#   @ref            https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
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
#   Define › Log Paths
#   
#   List of the log files that will be utilized with test suite.
#   
#   @note       I decided to support Windows, since I like to 
#               punish myself.
#   
#               These tests can be ran on Linux or Windows, 
#               however, Secure Messenger tests will be SKIPPED if
#               loading these tests from Windows, since those
#               tests require root gid/uid, and being able to drop
#               perms.
# #

my $tests_log_normal    = $^O eq "MSWin32" ? "$FindBin::Bin/var/log/lfd.log" : "/var/log/lfd_test_$$.log";
my $tests_log_root      = $^O eq "MSWin32" ? "$FindBin::Bin/var/log/lfd_root.log" : "/var/log/lfd_root_test_$$.log";
my $tests_log_msngr     = $^O eq "MSWin32" ? "$FindBin::Bin/var/log/lfd_messenger.log" : "/var/log/lfd_messenger_test_$$.log";

# #
#	Declare › Status › Labels
#   
#   Map log statuses to their display string. Specifying a status in
#   Logger::logfile() is optional, otherwise, defaults to 'info'.
#   
#   Status may be referenced by name or int:
#       0       fail
#       1       ok
#       2       warn
#       3       abort
#       4       info
# #

my %STATUS_MAP =
(
    0       => 'fail',
    1       => 'ok',
    2       => 'warn',
    3       => 'abort',
    4       => 'info',
    'fail'  => 'fail',
    'ok'    => 'ok',
    'warn'  => 'warn',
    'abort' => 'abort',
    'info'  => 'info',
);

# #
#	Declare › Status › Colors
#   
#   Colors associated with status labels defined in hash %STATUS_MAP
# #

my %STATUS_CLR =
(
    ok      => "\e[38;5;46m",
    fail    => "\e[38;5;196m",
    warn    => "\e[38;5;208m",
    abort   => "\e[38;5;198m",
    info    => "\e[38;5;33m",
);

# #
#   Declare › Module Imports
#   
#   Get external values from modules that are needed by the tests.
#   
#   REGISTRY_ENTRY_MAXIMUM
#       Max number of secret registry entries.
# #

my $registry_entries_max = ConfigServer::Secrets::REGISTRY_ENTRY_MAXIMUM( );

# #
#   Logger.t › Helpers › Note Field
#   
#   Formats the text that will show details about each test being ran.
#   Adds indentations relative to main test job.
#   
#   @usage      note( _note_field( 'Input', "$uuid_v4_input" ) );
#               note( _note_field( 'Result', "$uuid_v4_res" ) . " \n\n" );
#   
#   @eg         ok 124 - [Secrets] UUID4 tokens are redacted
#                   Input:    550e8400-e29b-41d4-a716-446655440000
#                   Result:   [REDACTED] 
#   
#   @params     name            scalar      Field name
#               value           scalar      Field value
#   @return                     str         Formatted note field
# #

sub _note_field
{
    my ( $name, $value ) = @_;

    $value      = defined( $value ) ? "$value" : 'undef';
    $value      =~ s/\r\n?/\n/g;
    $value      =~ s/\n\z//;

    my $prefix  = sprintf( '         %-10s', "$name:" );
    my $indent  = ' ' x length( $prefix );

    $value      =~ s/\n/\n$indent/g;

    return $prefix . $value;
}

# #
#   Logger.t › Core › Local Logs
#   
#   Specify log path depending on Windows vs Linux
#   
#   Linux:      /var/log/*
#   Windows:    ./tests/var/log/*
# #

File::Path::make_path( "$FindBin::Bin/var/log" )
	if $^O eq "MSWin32" and !-d "$FindBin::Bin/var/log";

# #
#   Logger.t › Core › Silent Warnings
#   
#   Silence warnings since we're replacing logger path subroutines
# #

no warnings 'redefine';

local *ConfigServer::Logger::_normal_log_path = sub
{
	return $tests_log_normal;
};

local *ConfigServer::Logger::_root_log_path = sub
{
	return $tests_log_root;
};

local *ConfigServer::Logger::_msngr_log_path = sub
{
	return $tests_log_msngr;
};

# #
#   Logger.t › Core › Load Config
#   
#   Depending on const TESTS_CONFIG_FAKE; load a fake csf config
#   DEBUG value; OR load the real DEBUG value from /etc/csf/csf.conf.
#   
#   Keep const TESTS_CONFIG_FAKE to 1 unless testing for some reason.
#   
#   TESTS_CONFIG_FAKE => 1:                                 (default)
#       Windows:    Uses DEBUG 2 (TESTS_CONFIG_FAKE_DEBUG)
#       Linux:      Uses DEBUG 2 (TESTS_CONFIG_FAKE_DEBUG)
#   
#   TESTS_CONFIG_FAKE => 0:
#       Windows:    Uses DEBUG 5 (TESTS_CONFIG_WINDOWS_DEBUG)
#       Linux:      Load real DEBUG setting from /etc/csf/csf.conf
# #

my $debug_config;

# Fake config DEBUG value
if ( TESTS_CONFIG_FAKE )
{
    $debug_config = TESTS_CONFIG_FAKE_DEBUG;
    ConfigServer::Logger::_config_load(
        {
            DEBUG => $debug_config,
        }
    );
}

# Windows: can't use real /etc/csf/csf.conf, force debug 5
elsif ( $^O eq "MSWin32" )
{
    $debug_config = TESTS_CONFIG_WINDOWS_DEBUG;
}

# Linux: use real /etc/csf/csf.conf
else
{
    my $config      = ConfigServer::Config->loadconfig();
    my %config      = $config->config();
    $debug_config   = $config{DEBUG} // 0;
}

# #
#   Logger.t › Core › Module List
#   
#   Print full list of all CSF modules and paths.
#   
#   @vars       $path_loaded        /tmp/csf/tests/../ConfigServer/Secrets.pm
#               $path_full          /tmp/csf/ConfigServer/Secrets.pm
#               $module             ConfigServer/Secrets.pm
# #

print STDERR "\n";
print STDERR "\n";
print STDERR "  ", $C{greyd}, '-' x 140, "\n";

my @modules_csf = sort grep
{
    /\AConfigServer\//
} keys( %INC );

for my $module ( @modules_csf )
{
    my $path_loaded     = $INC{$module};
    my $path_full       = Cwd::abs_path( $path_loaded );

    $path_full = $path_loaded
        if !defined( $path_full );

    diag(
        "$C{fucsial} [Module] " .
        "$C{yellowm}$module$C{greyl} => " .
        "$C{bluem}$path_full$C{reset}"
    );
}

# #
#   Logger.t › Tests › Root
#   
#   Make sure 'root' target writes only to the 'root' log and 
#   doesn't also write the same msg to the 'normal' log.
#   
#   Input:      logfile( "root", "info", "Root msg" );
#   Result:     root_written = 1, normal_written = 0
# #

my $root_write = ConfigServer::Logger::logfile(
    TESTS_LOG_TARGET_ROOT,
    TESTS_LOG_STATUS_INFO,
    "[" . TESTS_TAG . "] Root log only"
);

ok(
    defined $root_write &&
    $root_write->{written} &&
    $root_write->{root_written} &&
    !$root_write->{normal_written},
    "Root target writes to root log only"
);

note(
    _note_field(
        'Result',
        "written = " . ( defined( $root_write ) && defined( $root_write->{written} ) ? $root_write->{written} : "undef" ) . ", root_written = " . ( defined( $root_write ) && defined( $root_write->{root_written} ) ? $root_write->{root_written} : "undef" ) . ", normal_written = " . ( defined( $root_write ) && defined( $root_write->{normal_written} ) ? $root_write->{normal_written} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Normal › Legacy (1 Arg)
#   
#   Originally logfile() only accepted a single arg, the log message:
#       ConfigServer::Logger::logfile( "MESSAGE" );
#   
#   New logfile() sub accepts 3 args, (TARGET and STATUS optional):
#       ConfigServer::Logger::logfile( TARGET, STATUS, "MESSAGE" );
#   
#   This test makes sure if we call logfile() with a single arg,
#   it sets default values for TARGET and STATUS:
#       target = 'normal'
#       status = 'info'
#   
#   Input:      logfile( "msg" )
#   Result:     target = normal, status = info, normal_written = 1
#   
#   @note       logfile() can be called with 1, 2, or 3 args.
#               When using 1 arg; provide only the log msg.
# #

my $legacy_single_arg = ConfigServer::Logger::logfile(
    "[" . TESTS_TAG . "] Legacy single arg"
);

ok(
    defined $legacy_single_arg &&
    $legacy_single_arg->{written} &&
    $legacy_single_arg->{normal_written} &&
    $legacy_single_arg->{status} eq TESTS_LOG_STATUS_INFO &&
    $legacy_single_arg->{message} eq "[" . TESTS_TAG . "] Legacy single arg",
    "Single arg defaults to NORMAL target and INFO status"
);

note(
    _note_field(
        'Result',
        "written = " . ( defined( $legacy_single_arg->{written} ) ? $legacy_single_arg->{written} : "undef" ) . ", normal_written = " . ( defined( $legacy_single_arg->{normal_written} ) ? $legacy_single_arg->{normal_written} : "undef" ) . ", status = " . ( defined( $legacy_single_arg->{status} ) ? $legacy_single_arg->{status} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Normal › 2 Args
#   
#   Make sure if two args are passed to logfile(), call writes to
#   the normal log using the specified status.
#   
#   Input:      logfile( "warn", "msg" )
#   Result:     target = normal, status = WARN, normal_written = 1
#   
#   @note       logfile() can be called with 1, 2, or 3 args.
#               When using 1 arg; provide only the log msg.
# #

my $normal_warn_status = ConfigServer::Logger::logfile(
    TESTS_LOG_STATUS_WARN,
    "[" . TESTS_TAG . "] NORMAL target with WARN status"
);

ok(
    defined $normal_warn_status &&
    $normal_warn_status->{written} &&
    $normal_warn_status->{normal_written} &&
    $normal_warn_status->{status} eq TESTS_LOG_STATUS_WARN,
    "Two args with NORMAL target and WARN status"
);

note(
    _note_field(
        'Result',
        "written = " . ( defined( $normal_warn_status->{written} ) ? $normal_warn_status->{written} : "undef" ) . ", normal_written = " . ( defined( $normal_warn_status->{normal_written} ) ? $normal_warn_status->{normal_written} : "undef" ) . ", status = " . ( defined( $normal_warn_status->{status} ) ? $normal_warn_status->{status} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Normal › 3 Args
#   
#   Make sure an explicit normal target writes to the normal log
#   with the supplied info status.
#   
#   Input:      logfile( "normal", "info", "Test Message" );
#   Result:     target = normal, status = info, normal_written = 1
# #

my $normal_explicit_type = ConfigServer::Logger::logfile(
    TESTS_LOG_TARGET_NORMAL,
    TESTS_LOG_STATUS_INFO,
    "[" . TESTS_TAG . "] NORMAL target with explicit status"
);

ok(
    defined $normal_explicit_type &&
    $normal_explicit_type->{written} &&
    $normal_explicit_type->{normal_written} &&
    $normal_explicit_type->{target} eq TESTS_LOG_TARGET_NORMAL &&
    $normal_explicit_type->{status} eq TESTS_LOG_STATUS_INFO,
    "Explicit NORMAL target writes normal log with INFO status"
);

note(
    _note_field(
        'Result',
        "written = " . ( defined( $normal_explicit_type->{written} ) ? $normal_explicit_type->{written} : "undef" ) . ", normal_written = " . ( defined( $normal_explicit_type->{normal_written} ) ? $normal_explicit_type->{normal_written} : "undef" ) . ", target = " . ( defined( $normal_explicit_type->{target} ) ? $normal_explicit_type->{target} : "undef" ) . ", status = " . ( defined( $normal_explicit_type->{status} ) ? $normal_explicit_type->{status} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Log Targets › Root
#   
#   Make sure that the 'root' target writes only to the 'root' log,
#   and doesn't also write the same msg to the 'normal' log.
#   
#   Input:      logfile( "root", "info", "Test Message" );
#   Result:     root_written = 1, normal_written = 0, target = root
# #

my $root_log_target = ConfigServer::Logger::logfile(
    TESTS_LOG_TARGET_ROOT,
    TESTS_LOG_STATUS_INFO,
    "[" . TESTS_TAG . "] Root log only"
);

ok(
    defined $root_log_target &&
    $root_log_target->{written} &&
    $root_log_target->{root_written} &&
    !$root_log_target->{normal_written} &&
    $root_log_target->{target} eq TESTS_LOG_TARGET_ROOT,
    "ROOT target writes root log and skips normal log"
);

note(
    _note_field(
        'Result',
        "written = " . ( defined( $root_log_target ) && defined( $root_log_target->{written} ) ? $root_log_target->{written} : "undef" ) . ", root_written = " . ( defined( $root_log_target ) && defined( $root_log_target->{root_written} ) ? $root_log_target->{root_written} : "undef" ) . ", normal_written = " . ( defined( $root_log_target ) && defined( $root_log_target->{normal_written} ) ? $root_log_target->{normal_written} : "undef" ) . ", target = " . ( defined( $root_log_target ) && defined( $root_log_target->{target} ) ? $root_log_target->{target} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Log Targets › All
#   
#   Make sure that the 'all' target writes the same msg to both
#   'root' and 'normal' log types.
#   
#   Input:      logfile( "all", "info", "Test Message" );
#               logfile( "normal", "info", "Test Message" );
#   Result:     root_written = 1, normal_written = 1, target = all
# #

my $all_log_target = ConfigServer::Logger::logfile(
    TESTS_LOG_TARGET_ALL, TESTS_LOG_STATUS_INFO,
    "[" . TESTS_TAG . "] Root and normal log"
);

ok(
    defined $all_log_target &&
    $all_log_target->{written} &&
    $all_log_target->{root_written} &&
    $all_log_target->{normal_written} &&
    $all_log_target->{target} eq TESTS_LOG_TARGET_ALL,
    "All target writes both root and normal logs"
);

note(
    _note_field(
        'Result',
        "written = " . ( defined( $all_log_target ) && defined( $all_log_target->{written} ) ? $all_log_target->{written} : "undef" ) . ", root_written = " . ( defined( $all_log_target ) && defined( $all_log_target->{root_written} ) ? $all_log_target->{root_written} : "undef" ) . ", normal_written = " . ( defined( $all_log_target ) && defined( $all_log_target->{normal_written} ) ? $all_log_target->{normal_written} : "undef" ) . ", target = " . ( defined( $all_log_target ) && defined( $all_log_target->{target} ) ? $all_log_target->{target} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Status › Mapping
#   
#   Verify str and int status values change to expected label
#   and write successfully.
#   
#   @eg         String:     fail, ok, warn, abort, info
#               Int:        0, 1, 2, 3, 4
#               Result:     fail, ok, warn, abort, info
#   
#   @note       These tests are different from the status tests in
#               DebugLocal.t.
#   
#               X   DebugLocal.t checks the status displayed in captured
#                   terminal output after ansi colors are removed.
#   
#               >   Logger.t checks the returned status and plain log
#                   file line, and confirms ansi colors are not
#                   included.
# #

for my $input ( qw( fail ok warn abort info ), 0 .. 4 )
{
    my $expected      = $STATUS_MAP{ $input };
    my $status_type   = $input =~ /\A[0-9]+\z/
                            ? 'Integer'
                            : 'String';

    my $res = ConfigServer::Logger::logfile(
        TESTS_LOG_TARGET_NORMAL,
        $input,
        "[" . TESTS_TAG . "] Status " . lc( $status_type ) . ": $expected"
    );

    ok(
        defined $res &&
        $res->{written} &&
        $res->{status} eq $expected,
        "$status_type status '$input' maps to '$expected'"
    );

    note(
        _note_field(
            'Result',
            "input = " . $input . ", status = " . ( defined( $res ) && defined( $res->{status} ) ? $res->{status} : "undef" ) . ", written = " . ( defined( $res ) && defined( $res->{written} ) ? $res->{written} : "undef" ),
        ) .
        " \n\n"
    );
}

# #
#   Logger.t › Tests › Status › Color
#   
#   Verify each status is returned and written to the log line.
#   
#   Logger writes plain text to log files, so ansi colors are not
#   included.
#   
#   @eg         $res->{status}      ok
#               $res->{line}        Oct 18 06:14:02 csf lfd[ 3401597 ] [Logger.t::global:598] [ok]: [TEST] Status: ok
#   
#   @note       These tests are different from the status tests in
#               DebugLocal.t.
#   
#               X   DebugLocal.t verifies that terminal output includes the
#                   correct ansi color for each status.
#   
#               >   Logger.t verifies the status written to a log file
#                   and confirms that the ansi colors are not included.
# #

for my $status ( qw( fail ok warn abort info ) )
{
    my $res = ConfigServer::Logger::logfile(
        TESTS_LOG_TARGET_NORMAL,
        $status,
        "[" . TESTS_TAG . "] Status: $status",
    );

    is(
        $res->{status},
        $status,
        "Status '$status' is returned",
    );

    note(
        _note_field( 'Input', $status ) . "\n" .
        _note_field( 'Expected', $status ) . "\n" .
        _note_field(
            'Result',
            defined( $res ) && defined( $res->{status} )
                ? $res->{status}
                : "undef",
        ) .
        " \n\n"
    );

    like(
        $res->{line},
        qr/\[\Q$status\E\]/,
        "Status '$status' is written to the log line",
    );

    note(
        _note_field( 'Expected', "contains [$status]" ) . "\n" .
        _note_field(
            'Result',
            defined( $res ) && defined( $res->{line} )
                ? $res->{line}
                : "undef",
        ) .
        " \n\n"
    );

    unlike(
        $res->{line},
        qr/\e\[/,
        "Status '$status' does not add terminal color codes",
    );

    note(
        _note_field( 'Expected', 'no ansi color codes' ) . "\n" .
        _note_field(
            'Result',
            defined( $res ) &&
            defined( $res->{line} ) &&
            $res->{line} =~ /\e\[/
                ? "ansi color codes found"
                : "no ansi color codes",
        ) .
        " \n\n"
    );
}

# #
#   Logger.t › Tests › Debug Levels
#   
#   Use the DEBUG level currently configured in /etc/csf/csf.conf.
#       Levels equal to or below DEBUG should be written.
#       Levels above DEBUG should be suppressed.
#   
#   Input:      DEBUG:0
#   Result:     written = 1, suppressed = 0, no [DEBUG:X] label
#   
#   Input:      logfile( "DEBUG:0", "info", "Debug msg" );
#               logfile( "DEBUG:1", "info", "Debug msg" );
#               logfile( "DEBUG:2", "info", "Debug msg" );
#               logfile( "DEBUG:3", "info", "Debug msg" );
#               logfile( "DEBUG:4", "info", "Debug msg" );
#               logfile( "DEBUG:5", "info", "Debug msg" );
#   Result:     written = 0, suppressed = 1
# #

foreach my $level ( 0 .. 5 )
{
    my $res = ConfigServer::Logger::logfile(
        "DEBUG:$level",
        TESTS_LOG_STATUS_INFO,
        "[" . TESTS_TAG . "] DEBUG:$level"
    );

    if ( $level == 0 || $level <= $debug_config )
    {
        my $valid =     defined $res &&
                        $res->{written} &&
                        !$res->{suppressed} &&
                        defined $res->{debug_level} &&
                        $res->{debug_level} == $level &&
                        defined $res->{line};

        # #
        #   DEBUG level = 0:    write log without debug label.
        #   DEBUG level > 0:    include DEBUG:X label in formatted
        #                           log line.
        # #

        if ( $level == 0 )
        {
            $valid = $valid && $res->{line} !~ /\[DEBUG:/;
        }
        else
        {
            $valid = $valid && $res->{line} =~ /\[DEBUG:$level\]/;
        }

        ok(
            $valid, $level == 0
                ? "DEBUG:0 writes log without a [DEBUG:X] label"
                : "DEBUG:$level writes log with matching [DEBUG:$level] label"
        );

        note(
            _note_field(
                'Result',
                "level = " . $level . ", written = " . ( defined( $res->{written} ) ? $res->{written} : "undef" ) . ", suppressed = " . ( defined( $res->{suppressed} ) ? $res->{suppressed} : "undef" ) . ", debug_level = " . ( defined( $res->{debug_level} ) ? $res->{debug_level} : "undef" ),
            ) .
            " \n\n"
        );
    }
    else
    {
        ok(
            defined $res &&
            !$res->{written} &&
            $res->{suppressed} &&
            $res->{debug_level} == $level,
            "DEBUG:$level is suppressed when DEBUG=$debug_config"
        );

        note(
            _note_field(
                'Result',
                "level = " . $level . ", written = " . ( defined( $res->{written} ) ? $res->{written} : "undef" ) . ", suppressed = " . ( defined( $res->{suppressed} ) ? $res->{suppressed} : "undef" ) . ", debug_level = " . ( defined( $res->{debug_level} ) ? $res->{debug_level} : "undef" ),
            ) .
            " \n\n"
        );
    }
}

# #
#   Logger.t › Tests › Case Insensitive › Normal
#   
#   Verify uppercase target and status values are accepted and
#   normalize to their values.
#   
#   Input:      logfile( "NORMAL", "INFO", "msg" );
#   Result:     target = normal, status = info
# #

my $case_normal_res = ConfigServer::Logger::logfile(
    uc( TESTS_LOG_TARGET_NORMAL ),
    uc( TESTS_LOG_STATUS_INFO ),
    "[" . TESTS_TAG . "] Case insensitive normal/info"
);

ok(
    defined $case_normal_res &&
    $case_normal_res->{target} eq TESTS_LOG_TARGET_NORMAL &&
    $case_normal_res->{status} eq TESTS_LOG_STATUS_INFO,
    "Uppercase NORMAL target is normalized to normal"
);

note(
    _note_field(
        'Result',
        "target = " . ( defined( $case_normal_res->{target} ) ? $case_normal_res->{target} : "undef" ) . ", status = " . ( defined( $case_normal_res->{status} ) ? $case_normal_res->{status} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Case Insensitive › Debug
#   
#   Verify lowercase DEBUG target and uppercase status values
#   are accepted together.
#   
#   Input:      logfile( "debug:0", "OK", "OK msg" );
#   Result:     written = 1, debug_level = 0, status = ok
# #

my $case_debug_res = ConfigServer::Logger::logfile(
    "debug:0",
    uc( TESTS_LOG_STATUS_OK ),
    "[" . TESTS_TAG . "] Case insensitive debug/ok"
);

ok(
    defined $case_debug_res &&
    $case_debug_res->{written} &&
    $case_debug_res->{status} eq TESTS_LOG_STATUS_OK &&
    $case_debug_res->{debug_level} == 0,
    "Lowercase debug:0 and uppercase OK are accepted"
);

note(
    _note_field(
        'Result',
        "written = " . ( defined( $case_debug_res->{written} ) ? $case_debug_res->{written} : "undef" ) . ", debug_level = " . ( defined( $case_debug_res->{debug_level} ) ? $case_debug_res->{debug_level} : "undef" ) . ", status = " . ( defined( $case_debug_res->{status} ) ? $case_debug_res->{status} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Case Insensitive › Root
#   
#   Verify uppercase ROOT is normalized to the root target and writes
#   to the root log using the WARN status.
#   
#   Input:      logfile( "ROOT", "WARN", "Root msg" );
#   Result:     target = root, root_written = 1, status = warn
# #

my $case_root_res = ConfigServer::Logger::logfile(
    uc( TESTS_LOG_TARGET_ROOT ), uc( TESTS_LOG_STATUS_WARN ),
    "[" . TESTS_TAG . "] Case insensitive root/warn"
);

ok(
    defined $case_root_res &&
    $case_root_res->{root_written} &&
    $case_root_res->{status} eq TESTS_LOG_STATUS_WARN &&
    $case_root_res->{target} eq TESTS_LOG_TARGET_ROOT,
    "Uppercase ROOT target is normalized and writes root log"
);

note(
    _note_field(
        'Result',
        "target = " . ( defined( $case_root_res->{target} ) ? $case_root_res->{target} : "undef" ) . ", root_written = " . ( defined( $case_root_res->{root_written} ) ? $case_root_res->{root_written} : "undef" ) . ", status = " . ( defined( $case_root_res->{status} ) ? $case_root_res->{status} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Case Insensitive › All
#   
#   Make sure uppercase ALL is normalized to the 'all' target, and
#   writes.
#   
#   When using 'all', the same log msg is written to both
#   'root' and 'normal' logs.
#   
#   Input:      logfile( "ALL", "OK", "OK msg" );
#   Result:     target = all, root_written = 1, normal_written = 1
# #

my $case_all_res = ConfigServer::Logger::logfile(
    uc( TESTS_LOG_TARGET_ALL ), uc( TESTS_LOG_STATUS_OK ),
    "[" . TESTS_TAG . "] Case insensitive all/ok"
);

ok(
    defined $case_all_res &&
    $case_all_res->{root_written} &&
    $case_all_res->{normal_written} &&
    $case_all_res->{status} eq TESTS_LOG_STATUS_OK &&
    $case_all_res->{target} eq TESTS_LOG_TARGET_ALL,
    "Uppercase ALL target writes both root and normal logs"
);

note(
    _note_field(
        'Result',
        "target = " . ( defined( $case_all_res->{target} ) ? $case_all_res->{target} : "undef" ) . ", root_written = " . ( defined( $case_all_res->{root_written} ) ? $case_all_res->{root_written} : "undef" ) . ", normal_written = " . ( defined( $case_all_res->{normal_written} ) ? $case_all_res->{normal_written} : "undef" ) . ", status = " . ( defined( $case_all_res->{status} ) ? $case_all_res->{status} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Log Metadata
#   
#   When logs are written to file, we include several pieces of info
#   such as the module name, subroutine, and line number that ran the
#   code, all collectively known as metadata.
#   
#   This test verifies that logfile() returns the source file, line,
#   process name/PID, and the msg in the formatted log entry.
#   
#   @eg:        lfd[ 942790 ] [Sendmail.pm:134->relay()] [ERROR]: [Sendmail] Failed to send msg via sendmail binary: 256
#   
#   Input:      logfile( "normal", "info", "info msg" );
#   Result:     Logger.t:123::global
#   
#   @warn       Changing the structure of a log msg will break this
#               test. I already forgot it once. 
# #

my $log_metadata_res = ConfigServer::Logger::logfile(
    TESTS_LOG_TARGET_NORMAL, TESTS_LOG_STATUS_INFO,
    "[" . TESTS_TAG . "] Log metadata"
);

ok(
    defined $log_metadata_res &&
    defined $log_metadata_res->{source} &&
    $log_metadata_res->{source} =~ /\ALogger\.t::global:\d+\z/,              # Logger.t::global:741
    # $log_metadata_res->{source} =~ /Logger\.t:\d+::global$/,               # Logger.t:741::global
    "Returned source contains Logger.t filename and line number"
);

note(
    _note_field(
        'Result',
        "source = " . ( defined( $log_metadata_res ) && defined( $log_metadata_res->{source} ) ? $log_metadata_res->{source} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Metadata › Process
#   
#   Make sure the formatted log line contains the lfd process name, 
#   and the pid of the process running the test.
#   
#   Input:      Current PID = 12345
#   Result:     lfd[ 12345 ]
# #

ok(
    defined $log_metadata_res &&
    defined $log_metadata_res->{line} &&
    index( $log_metadata_res->{line}, "lfd[ $$ ]" ) >= 0,
    "Formatted log line contains process name and current PID"
);

note(
    _note_field(
        'Result',
        "pid = " . $$ . ", line = " . ( defined( $log_metadata_res ) && defined( $log_metadata_res->{line} ) ? $log_metadata_res->{line} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Metadata › Message
#   
#   Make sure the logger returns the original msg and includes that
#   msg inside the complete formatted log line.
#   
#   Input:      [TEST] Log metadata
#   Result:     Message remains unchanged in formatted log line
# #

ok(
    defined $log_metadata_res &&
    $log_metadata_res->{message} eq "[" . TESTS_TAG . "] Log metadata" &&
    index( $log_metadata_res->{line}, "[" . TESTS_TAG . "] Log metadata" ) >= 0,
    "Original msg is preserved in returned log line"
);

note(
    _note_field(
        'Result',
        "message = " . ( defined( $log_metadata_res ) && defined( $log_metadata_res->{message} ) ? $log_metadata_res->{message} : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Sanitization
#   
#   These tests run ConfigServer::Secrets module for CSF, which is
#   used to sanitize any logs passed through logfile().
#   
#   Sensitive segments found in urls are either redacted or removed
#   before they are written to a log, because obviously, it would
#   be bad to leak these.
#   
#   Tests PASS:     return 1
#   Tests FAIL:     return 0
#   
#   Several terms are used below for the various parts of a url that
#   are stripped of data; so an example with labels is provided:
#   
#   @note       URL Example:        https://user:password@configserver.dev/check?token=url-secret&mode=test#fragment-secret
#                   Scheme:             https
#                   Credentials:        user:password
#                   Host:               configserver.dev
#                   Path:               /check
#                   Query string:       token=url-secret&mode=test
#                   Param:              token
#                   Value:              url-secret
#                   Param:              mode
#                   Value:              test
#                   Fragment:           fragment-secret
#   
#               URL Param Example:
#                   Query flag:         ?token
#                   Valued param:       ?token=abcde
#                   Empty value param:  ?token=
# #

ConfigServer::Secrets::registry_clear( );

# #
#   Logger.t › Tests › Secrets › SPONSOR_LICENSE
#   
#   csf.conf setting SPONSOR_LICENSE classified as private / secret
#   
#   Input:      SPONSOR_LICENSE
#   Result:     1 (true)
# #

my $sponsor_license_private = ConfigServer::Secrets::is_config_secret( "SPONSOR_LICENSE" );

is(
	$sponsor_license_private,
	1,
	"[Secrets] SPONSOR_LICENSE is a secret csf.conf setting"
);

note(
    _note_field(
        'Result',
        ( defined( $sponsor_license_private ) ? $sponsor_license_private : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › UI_PASS
#   
#   csf.conf setting UI_PASS classified as private / secret
#   
#   Input:      UI_PASS
#   Result:     1 (true)
# #

my $ui_password_private = ConfigServer::Secrets::is_config_secret( "UI_PASS" );

is(
	$ui_password_private,
	1,
	"[Secrets] UI_PASS is a secret csf.conf setting"
);

note(
    _note_field(
        'Result',
        ( defined( $ui_password_private ) ? $ui_password_private : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Param › License Key › Remove
#   
#   Confirm that a license key passed through a url query is redacted.
#   
#   Input:      https://configserver.dev?licensekey=XXXX-XXX-XXX
#   Result:     https://configserver.dev
# #

my $license_url_remove = ConfigServer::Secrets::redact_obj_url( 'https://configserver.dev?licensekey=XXXX-XXX-XXX' );

is(
	$license_url_remove,
	'https://configserver.dev',
	"[Secrets] Sanitize licensekey param with Removal"
);

note(
    _note_field(
        'Result',
        "$license_url_remove",
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Param › License Key › Replace
#   
#   Confirm a license key passed through a url query is redacted.
#   
#   Input:      https://configserver.dev?licensekey=XXXX-XXX-XXX
#   Result:     https://configserver.dev?licensekey=[REDACTED]
# #

my $license_url_replace = ConfigServer::Secrets::redact_obj_url_replace( 'https://configserver.dev?licensekey=XXXX-XXX-XXX' );

is(
	$license_url_replace,
	'https://configserver.dev?licensekey=[REDACTED]',
	"[Secrets] Sanitize ?licensekey param with Redaction"
);

note(
    _note_field(
        'Result',
        "$license_url_replace",
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Public CSF Settings › Classification
#   
#   Make sure public csf.conf names are not treated as secrets.
#   
#   These values should remain visible, with no redactions or removals.
#   
#   Input:      RECAPTCHA_SITEKEY
#               MESSENGER_HTTPS_KEY
#               PORTS_HTPASSWD
#   
#   Result:     RECAPTCHA_SITEKEY   = 0
#               MESSENGER_HTTPS_KEY = 0
#               PORTS_HTPASSWD      = 0 
# #

my $recaptcha_sitekey       = ConfigServer::Secrets::is_config_secret( "RECAPTCHA_SITEKEY" );
my $messenger_https_key     = ConfigServer::Secrets::is_config_secret( "MESSENGER_HTTPS_KEY" );
my $ports_htpasswd          = ConfigServer::Secrets::is_config_secret( "PORTS_HTPASSWD" );

ok(
    !$recaptcha_sitekey &&
    !$messenger_https_key &&
    !$ports_htpasswd,
    "[Secrets] Non-secret csf.conf values remain visible"
);

note(
    _note_field(
        'RECAPTCHA_SITEKEY',
        defined( $recaptcha_sitekey ) ? $recaptcha_sitekey : "undef",
    ) . "\n" .
    _note_field(
        'MESSENGER_HTTPS_KEY',
        defined( $messenger_https_key ) ? $messenger_https_key : "undef",
    ) . "\n" .
    _note_field(
        'PORTS_HTPASSWD',
        defined( $ports_htpasswd ) ? $ports_htpasswd : "undef",
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › CSF Configuration › Secret Registration
#   
#   Register settings from a ghost csf config. Secret settings
#   are registered, settings that are public, are skipped.
#   
#   Input:      3 secret settings
#               2 public settings
#   
#   Result:     3 secret values registered
# #

my %sanitizer_config =
(
    UI_PASS                 => "test-ui-password",
    CLUSTER_KEY             => "test-cluster-secret",
    RECAPTCHA_SECRET        => "test-captcha-secret",
    RECAPTCHA_SITEKEY       => "public-site-key",
    MESSENGER_HTTPS_KEY     => "/etc/csf/messenger.key",
);

is(
    ConfigServer::Secrets::register_secrets( \%sanitizer_config ),
    3,
    "[Secrets] Only csf.conf settings classified as secrets are registered"
);

note(
    _note_field(
        'Result',
        "\n\n",
    )
);

# #
#   Logger.t › Tests › Secrets › Registered CSF Values › Exact-Value Redaction
#   
#   Input:      test-ui-password   test-cluster-secret   test-captcha-secret
#   Result:     [REDACTED] [REDACTED] [REDACTED]
#   Failure:    [REDACTED] test-cluster-secret [REDACTED]
# #

my $redacted_cluster = ConfigServer::Secrets::redact_obj_log(
    "test-ui-password test-cluster-secret test-captcha-secret"
);

unlike(
    $redacted_cluster,
    qr/test-(?:ui-password|cluster-secret|captcha-secret)/,
    "[Secrets] Registered CSF values are removed without requiring field labels"
);

note(
    _note_field(
        'Result',
        ( defined( $redacted_cluster ) ? $redacted_cluster : "undef" ),
    ) .
    " \n\n"
);

ConfigServer::Secrets::registry_clear( );

# #
#   Logger.t › Tests › Secrets › Quoted Password Assignment › Redaction
#   
#   Input:      password="secret"
#   Result:     password="[REDACTED]" 
# #

my $redacted_form_value = ConfigServer::Secrets::redact_obj_log( 'password="hidden value"' );

is(
    $redacted_form_value,
    'password="[REDACTED]"',
    "[Secrets] Quoted password assignment is redacted"
);

note(
    _note_field(
        'Result',
        ( defined( $redacted_form_value ) ? $redacted_form_value : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › CLI Access Token › Redaction
#   
#   Input:      --access-token command-secret
#   Result:     --access-token [REDACTED] 
# #

my $redacted_access_token = ConfigServer::Secrets::redact_obj_log( "--access-token command-secret" );

is(
    $redacted_access_token,
    "--access-token [REDACTED]",
    "[Secrets] CLI credential is redacted"
);

note(
    _note_field(
        'Result',
        ( defined( $redacted_access_token ) ? $redacted_access_token : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › XML Password › Redaction
#   
#   Input:      <password type="text">xml-secret</password>
#   Result:     <password type="text">[REDACTED]</password>
# #

my $redacted_xml_credential = ConfigServer::Secrets::redact_obj_log( '<password type="text">xml-secret</password>' );

is(
    $redacted_xml_credential,
    '<password type="text">[REDACTED]</password>',
    "[Secrets] XML credential is redacted"
);

note(
    _note_field(
        'Result',
        ( defined( $redacted_xml_credential ) ? $redacted_xml_credential : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Authorization Header › Selective Redaction
#   
#   In a string containing both the secret and public info, the
#   secret should be redacted, and the public info should stay visible.
#   
#   Input:      [Authorization: Bearer header-secret] [Status: 401]
#   Result:     [Authorization: [REDACTED]] [Status: 401] 
# #

my $redacted_authorization_bearer = ConfigServer::Secrets::redact_obj_log(
    "[Authorization: Bearer header-secret] [Status: 401]"
);

is(
    $redacted_authorization_bearer,
    "[Authorization: [REDACTED]] [Status: 401]",
    "[Secrets] Authorization is redacted while later diagnostics remain visible"
);

note(
    _note_field(
        'Result',
        ( defined( $redacted_authorization_bearer ) ? $redacted_authorization_bearer : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Public Setting
#   
#   csf.conf value RECAPTCHA_SITEKEY is public, its value should
#   not be redacted.
#   
#   Input:      RECAPTCHA_SITEKEY=public-site-key
#   Result:     RECAPTCHA_SITEKEY=public-site-key
# #

my $recaptcha_sitekey_public = ConfigServer::Secrets::redact_obj_log(
    "RECAPTCHA_SITEKEY=public-site-key"
);

is(
    $recaptcha_sitekey_public,
    "RECAPTCHA_SITEKEY=public-site-key",
    "[Secrets] Public RECAPTCHA_SITEKEY site key remains visible"
);

note(
    _note_field(
        'Result',
        ( defined( $recaptcha_sitekey_public ) ? $recaptcha_sitekey_public : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › URL Query Redaction
#   
#   Remove login credentials and the fragment, redacts secret query values,
#   and retains query values that are not classified as secret.
#   
#   Input:      https://operator:password@configserver.dev/check?token=url-secret&mode=test#fragment-secret
#   Result:     https://[REDACTED]@configserver.dev/check?token=[REDACTED]&mode=test 
# #

my $redacted_query_url = ConfigServer::Secrets::redact_obj_url_replace( 'https://operator:password@configserver.dev/check?token=url-secret&mode=test#fragment-secret' );

is(
	$redacted_query_url,
	'https://[REDACTED]@configserver.dev/check?token=[REDACTED]&mode=test',
	"[Secrets] Protect url credentials: replace"
);

note(
    _note_field(
        'Result',
        ( defined( $redacted_query_url ) ? $redacted_query_url : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › URL Query › Remove
#   
#   Passing a ?token= in a url will sanitize the token and remove it
#   completely.
#   
#   When filtering a url with USERNAME:PASSWORD at the beginning,
#   the original credentials are removed, and replaced with [REDACTED].
#   
#   Input:      https://operator:password@configserver.dev/check?token=url-secret&mode=test#fragment-secret
#   Result:     https://[REDACTED]@configserver.dev/check
# #

my $query_url_removed = ConfigServer::Secrets::redact_obj_url( 'https://operator:password@configserver.dev/check?token=url-secret&mode=test#fragment-secret' );

is(
	$query_url_removed,
	'https://[REDACTED]@configserver.dev/check',
	"[Secrets] Protect url credentials: remove"
);

note(
    _note_field(
        'Result',
        ( defined( $query_url_removed ) ? $query_url_removed : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › URL Query › Replaced
#   
#   Passing a ?token= in a url will sanitize the token and use
#   [REDACTED].
#   
#   When filtering a url with USERNAME:PASSWORD at the beginning,
#   the original creds are removed, and replaced with [REDACTED];
#   regardless of opting to remove the param, or replace it using:
#       redact_obj_url( )               Remove secret
#       redact_obj_url_replace( )       Replace secret with [REDACTED]
#   
#   Input:      https://operator:password@configserver.dev/check?token=url-secret&mode=test#fragment-secret
#   Result:     https://[REDACTED]@configserver.dev/check?token=[REDACTED]&mode=test
# #

my $query_url_replaced = ConfigServer::Secrets::redact_obj_url_replace( 'https://operator:password@configserver.dev/check?token=url-secret&mode=test#fragment-secret' );

is(
	$query_url_replaced,
	'https://[REDACTED]@configserver.dev/check?token=[REDACTED]&mode=test',
	"[Secrets] Protect url credentials: replace"
);

note(
    _note_field(
        'Result',
        ( defined( $query_url_replaced ) ? $query_url_replaced : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Redact URL query secret
#   
#   Input:      https://configserver.dev/check?%74oken=url-secret&mode=test
#   Result:     https://configserver.dev/check?%74oken=[REDACTED]&mode=test
# #

my $encoded_param_url = ConfigServer::Secrets::redact_obj_url_replace( 'https://configserver.dev/check?%74oken=url-secret&mode=test' );

is(
	$encoded_param_url,
	'https://configserver.dev/check?%74oken=[REDACTED]&mode=test',
	"[Secrets] Detect url encoded secret query names"
);

note(
    _note_field(
        'Result',
        ( defined( $encoded_param_url ) ? $encoded_param_url : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › RSA Private Key › Contents Removed
#   
#   Remove private GPG / RSA key from log messages and replace with a 
#   placeholder.
#   
#   Input:      test -----BEGIN RSA PRIVATE KEY-----
#   Result:     test [REDACTED PRIVATE KEY MATERIAL] 
# #

my $private_key_message = ConfigServer::Secrets::redact_obj_log(
    "test -----BEGIN RSA PRIVATE KEY-----\n" .
    "fake-private-material\n" .
    "-----END RSA PRIVATE KEY-----"
);

unlike(
    $private_key_message,
    qr/fake-private-material/,
    "[Secrets] Private-key contents are removed"
);

note(
    _note_field(
        'Result',
        ( defined( $private_key_message ) ? $private_key_message : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › RSA Private Key › Replacement Marker
#   
#   Detect / remove private key contents even when terminal escape
#   codes are used in a private key.
#   
#   Input:      -----BEGIN \e[31mOPENSSH\e[0m PRIVATE KEY-----
#   Result:     [REDACTED PRIVATE KEY MATERIAL]
# #

like(
    $private_key_message,
    qr/\[REDACTED PRIVATE KEY MATERIAL\]/,
    "[Secrets] Private-key replacement is identified in diagnostics"
);

note(
    _note_field(
        'Result',
        ( defined( $private_key_message ) ? $private_key_message : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › OpenSSH Private Key › Terminal Escape Protection
#   
#   Make sure that terminal escapes don't break private key
#   sanitization
#   
#   Input:      -----BEGIN \e[31mOPENSSH\e[0m PRIVATE KEY-----\nfake-private-material
#   Result:     [REDACTED PRIVATE KEY MATERIAL]
# #

my $private_key_escape = ConfigServer::Secrets::redact_obj_log(
    "-----BEGIN \e[31mOPENSSH\e[0m PRIVATE KEY-----\nfake-private-material"
);

is(
    $private_key_escape,
    "[REDACTED PRIVATE KEY MATERIAL]",
    "[Secrets] Terminal escapes cannot conceal a private key marker"
);

note(
    _note_field( 'Result', ( defined( $private_key_escape ) ? $private_key_escape : "undef" ) ) . " \n\n"
);

# #
#   Logger.t › Tests › Secrets › AWS Access Key › Redaction
#   
#   Input:      key AKIAABCDEFGHIJKLMNOP
#   Result:     key [REDACTED]
# #

my $aws_access_key = ConfigServer::Secrets::redact_obj_log( "key AKIAABCDEFGHIJKLMNOP" );

is(
    $aws_access_key,
    "key [REDACTED]",
    "[Secrets] Standalone AWS access key is redacted"
);

note(
    _note_field( 'Result', ( defined( $aws_access_key ) ? $aws_access_key : "undef" ) ) . " \n\n"
);

# #
#   Logger.t › Tests › Secrets › JSON Web Token › Redaction
#   
#   Input:      jwt eyJabcdefghijk.abcdefghijkl.abcdefghijklmnop
#   Result:     jwt [REDACTED]
# #

my $jwt_token = ConfigServer::Secrets::redact_obj_log( "jwt eyJabcdefghijk.abcdefghijkl.abcdefghijklmnop" );

is( $jwt_token, "jwt [REDACTED]", "[Secrets] Standalone JWT is redacted" );

note(
    _note_field( 'Result', ( defined( $jwt_token ) ? $jwt_token : "undef" ) ) . " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Log Control Chars › Removal
#   
#   Remove line breaks, tabs, terminal colors, and any other control
#   chars.
#   
#   Input:      first\nforged\rsecond\t\e[31mred\e[0m\0
#   Result:     first forged second red
# #

my $control_chars = ConfigServer::Secrets::redact_obj_log(
    "first\nforged\rsecond\t\e[31mred\e[0m\0"
);

is(
    $control_chars,
    "first forged second red",
    "[Secrets] Control chars cannot forge another log record"
);

note(
    _note_field( 'Result', ( defined( $control_chars ) ? $control_chars : "undef" ) ) . " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Unicode Log Message › Size Limit
#   
#   Create a huge msg with unicode chars, truncate it to the log
#   size limit, and make sure the resulting msg is still valid
#   text (which ends with [TRUNCATED]).
#   
#   Limit oversized unicode log msgs to the max log size.
#   
#   This test will output "snowman ☃" 20k times.
#   
#   Calculates 64 × 1024 = 65,536 chars
#   
#   Input:      snowman ☃ snowman ☃ snowman ☃ snowman ☃ [...]
#   Result:     snowman ☃ [...] [TRUNCATED]
# #

my $unicode_log_msg = ConfigServer::Secrets::redact_obj_log( "snowman ☃" x 20_000 );

ok(
    length( $unicode_log_msg ) <= ConfigServer::Secrets::LOG_BYTE_MAXIMUM() && $unicode_log_msg =~ / \[TRUNCATED\]\z/ &&
    eval
    {
        my $unicode_test = $unicode_log_msg;
        Encode::decode( "UTF-8", $unicode_test, Encode::FB_CROAK() );
        1;
    },
    "[Secrets] Oversized unicode log msg is bounded, marked, and valid utf8"
);

note(
    _note_field(
        'Result',
        ( defined( $unicode_log_msg ) ? substr( $unicode_log_msg, 0, 30 ) . "..." : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Invalid Log Message › Ref Rejection
#   
#   Reject things like an arrayref, which is passed as log messages.
#   Replace with an invalid error msg.
#   
#   Input:      []
#   Result:     [INVALID LOG MESSAGE]
# #

my $invalid_log_msg = ConfigServer::Secrets::redact_obj_log( [] );

is(
    $invalid_log_msg,
    "[INVALID LOG MESSAGE]",
    "[Secrets] Reference input is replaced with a safe diagnostic"
);

note(
    _note_field(
        'Result',
        ( defined( $invalid_log_msg ) ? $invalid_log_msg : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Cloudflare › Private Config Lines
#   
#   Remove secret values from CSF config lines while keeping
#   the config setting name visible.
#   
#   Input:      UI_PASS = visible-secret
#   Result:     UI_PASS = [REDACTED]
# #

my $secret_cfg_line = ConfigServer::Secrets::redact_obj_cfg_line( "UI_PASS = visible-secret" );

is(
    $secret_cfg_line,
    "UI_PASS = [REDACTED]",
    "[Secrets] Complete secret config value is redacted"
);

note(
    _note_field(
        'Result',
        ( defined( $secret_cfg_line ) ? $secret_cfg_line : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Cloudflare › Secret API Key
#   
#   Confirm CFAPIKEY is classified as a private setting name so its
#   associated value is redacted from sanitized output.
#   
#   Input:      CFAPIKEY
#   Result:     1 (private)
# #

my $cf_cfapikey = ConfigServer::Secrets::is_config_secret( "CFAPIKEY" );

is(
	$cf_cfapikey,
	1,
	"[Secrets] Cloudflare API-key field is classified as private"
);

note(
    _note_field(
        'Result',
        ( defined( $cf_cfapikey ) ? $cf_cfapikey : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Cloudflare › Redact API key
# #

my $cf_record = ConfigServer::Secrets::redact_obj_log(
	"DOMAIN:any:USER:test:CFACCOUNT:test\@example.com:" .
	"CFAPIKEY:12345abcdef6789"
);

is(
	$cf_record,
	"DOMAIN:any:USER:test:CFACCOUNT:test\@example.com:" .
	"CFAPIKEY:[REDACTED]",
	"[Secrets] Cloudflare API key is removed from a colon delimited record"
);

note(
    _note_field(
        'Result',
        ( defined( $cf_record ) ? $cf_record : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Protected File Line Endings
#   
#   Create a temp protected file which has each supported line ending,
#   then confirm read_lines( ) separates each entry.
#   
#   @note       This test is skipped on Windows since Perl does
#               not provide the O_NOFOLLOW file opening protection
#               required by read_file().
# #

# #
#   Skip protected file tests on Windows since O_NOFOLLOW is not
#   available. Count the tests automatically.
# #

subtest "Protected file tests" => sub
{
	plan skip_all => "Protected file tests require O_NOFOLLOW"
		if $^O eq "MSWin32";

    # #
    #   Define $path for temp file.
    #   
    #   This will be used for several tests to follow
    # #

	my ( $handle, $path ) = File::Temp::tempfile(
		"secrets-lines-XXXXXX",
		DIR         => File::Spec->tmpdir(),
		UNLINK      => 1,
	);

	binmode( $handle, ":raw" );

	print { $handle }
		"LF\n" .
		"CRLF\r\n" .
		"CR\r" .
		"VT\x0B" .
		"FF\f" .
		"NEL\x85" .
		"UTF8-NEL\xC2\x85" .
		"LS\xE2\x80\xA8" .
		"PS\xE2\x80\xA9" .
		"END";

	close( $handle );

	my @lines       = ConfigServer::Secrets::read_lines( $path );
	my $line_res    = "[" . join( "] [", @lines ) . "]";

	is_deeply(
		\@lines,
		[
			"LF",
			"CRLF",
			"CR",
			"VT",
			"FF",
			"NEL",
			"UTF8-NEL",
			"LS",
			"PS",
			"END",
		],
		"[Secrets] Supported line endings are recognized"
	);

	note(
		_note_field( 'Result', defined( $line_res ) ? $line_res : "undef" ) . " \n\n"
	);

	# #
    #   Logger.t › Tests › Secrets › Protected File Line Limit
	#   
    #   Read the same file with 3 line limit. Verify additional 
    #   lines cause the operation to stop and throw an error.
	# #

    my $lines_found = scalar( @lines );
    my $lines_max   = 3;
    my $lines_err   = "";

    eval
    {
        ConfigServer::Secrets::read_lines( $path, max_lines => $lines_max );
        1;
    } or $lines_err = $@;

    like(
        $lines_err,
        qr/Secret file has too many lines/,
        "[Secrets] Protected file line limit is enforced"
    );

    note( _note_field( 'Lines found', "$lines_found" ) );
    note( _note_field( 'Max allowed', "$lines_max" ) );
    note( _note_field( 'Result', ( $lines_err ne "" ? $lines_err : "no error" ) ) . " \n" );

	# #
    #   Logger.t › Tests › Secrets › Protected File Byte Limit
	#   
    #   Read the file with a byte limit smaller than its contents
    #   and confirm the reader rejects it before loading the file.
    #   
    #   Will fail since file exceeds max_bytes (8).
    #   
    #   Input:      File contains more than 8 bytes
    #               max_bytes => 8
    #   
    #   Result:     File is rejected with:
    #               "Secret file was found to be unsafe"
	# #

	my $byte_limit_err = "";

	eval
    {
		ConfigServer::Secrets::read_file(
			$path,
			max_bytes => 8,
		);
		1;
	} or $byte_limit_err = $@;

	like(
		$byte_limit_err,
		qr/Secret file was found to be unsafe/,
		"[Secrets] Protected file byte limit is enforced"
	);

	note(
	    _note_field(
	        'Result',
	        ( $byte_limit_err ne "" ? $byte_limit_err : "no error" ),
	    ) .
	    " \n"
	);

	# #
    #   Logger.t › Tests › Secrets › Protected File Perms
	#   
    #   Change the perms on a protected file so that other users can
    #   read it.
    #   
    #   Set the perms from 0600 => 0644. 
    #   With 0644, read_file() will reject the new perm setup.
    #   
    #   Restore the original perms to 0600 after the test is done.
    #   
    #   Input:      File perms: 0644
    #                   Owner:          read and write
    #                   Group:          read
    #                   Other users:    read
    #   
    #   Result:     File is rejected with:
    #                   "Secret file was found to be unsafe"
    #                   File perms are restored to 0600.
	# #

    chmod( 0644, $path )
        or die "Unable to change protected test file perms: $!";

    my $perm_found      = sprintf( "%04o", ( stat( $path ) )[ 2 ] & 07777 );
    my $perm_expect     = "0600";
    my $perm_err      = "";

    eval
    {
        ConfigServer::Secrets::read_file( $path );
        1;
    } or $perm_err = $@;

    chmod( 0600, $path )
        or die "Unable to restore protected test file perms: $!";

    like(
        $perm_err,
        qr/Secret file was found to be unsafe/,
        "[Secrets] Protected files reject unsafe perms"
    );

    note( _note_field( 'Perm found', "$perm_found" ) );
    note( _note_field( 'Perm expected',"$perm_expect" ) );
    note(
        _note_field(
            'Result',
            ( $perm_err ne "" ? $perm_err : "no error" ),
        ) .
        " \n"
    );

	# #
    #   Logger.t › Tests › Secrets › Protected File Symlink
	#   
	#   Point a symlink at the valid protected temp file and confirm
    #   read_file( ) / O_NOFOLLOW prevents the protected reader
    #   from opening the link.
    #   
    #   Input:      Symlink:    secrets-file-link
    #               Target:     valid protected secrets file
    #   
    #   Result:     Symlink is rejected with:
    #               "Secret file could not be opened and read:
    #               Too many levels of symbolic links"
    #               Test symlink is removed
	# #

	my $symlink_path = "$path-link";
	unlink( $symlink_path );

	symlink( $path, $symlink_path )
		or die "Unable to create protected file test symlink: $!";

	my $symlink_err = "";

	eval
    {
		ConfigServer::Secrets::read_file( $symlink_path );
		1;
	} or $symlink_err = $@;

	unlink( $symlink_path );

	like(
		$symlink_err,
		qr/Secret file could not be opened and read/,
		"[Secrets] Protected files reject symlinks"
	);

	note(
	    _note_field(
	        'Result',
	        ( $symlink_err ne "" ? $symlink_err : "no error" ),
	    ) .
	    " \n"
	);

	# #
    #   Logger.t › Tests › Secrets › Protected File Owner
    #   
    #   Specify an owner that is different from the file's real owner.
    #   
    #   read_file() should reject the ownership mismatch
    #   
    #   Input:      Actual file owner UID:  1000
    #               Required owner UID:     1001
    #   
    #   Result:     File is rejected with:
    #               "Secret file was found to be unsafe"
	# #

    # return 0 for test
	my $owner_actual    = ( stat( $path ) )[ 4 ];

    # return 1
	my $owner_wrong     = $owner_actual == 4_294_967_294 ? $owner_actual - 1 : $owner_actual + 1;
	my $owner_err       = "";

	eval
    {
		ConfigServer::Secrets::read_file( $path, owner => $owner_wrong );
		1;
	} or $owner_err = $@;

	like(
		$owner_err,
		qr/Secret file was found to be unsafe/,
		"[Secrets] Protected files reject an unexpected owner"
	);

    note( _note_field( 'Owner passed', "$owner_wrong" ) );
    note( _note_field( 'Owner expected', "$owner_actual" ) );
    note(
        _note_field(
            'Result',
            ( $owner_err ne "" ? $owner_err : "no error" ),
        ) .
        " \n"
    );

    # #
    #   Logger.t › Tests › Secrets › Protected File Hard Link
    #   
    #   Create second fs name for the protected file.
    #   Confirm read_file() rejects any files with more than
    #   one hard link.
    #   
    #   Input:      Filesystem links found: 2
    #               Maximum allowed:        1
    #   
    #   Result:     File is rejected with:
    #               "Secret file was found to be unsafe"
    # #

    my $hardlink_path = "${path}-hardlink";
    unlink( $hardlink_path );

    link( $path, $hardlink_path )
        or die "Unable to create protected file test hard link: $!";

    my $links_found     = ( stat( $path ) )[ 3 ];
    my $links_max       = ConfigServer::Secrets::FILE_HARDLINK_MAX();
    my $links_err       = "";

    eval
    {
        ConfigServer::Secrets::read_file( $path );
        1;
    } or $links_err = $@;

    unlink( $hardlink_path );

    like(
        $links_err,
        qr/Secret file was found to be unsafe/,
        "[Secrets] Protected files reject hard links"
    );

    note( _note_field( 'Links found', "$links_found" ) );
    note( _note_field( 'Max allowed', "$links_max" ) );
    note(
        _note_field(
            'Result',
            ( $links_err ne "" ? $links_err : "no error" ),
        ) .
        " \n"
    );

	# #
    #   Logger.t › Tests › Secrets › Protected File Parent Symlink
    #   
    #   Access protected file through a symlink dir and confirm
    #   read_file() rejects the parent path.
    #   
    #   Input:      Parent type found:    symbolic link
    #               Parent type expected: real directory
    #   
    #   Result:     File is rejected with:
    #               "Secret file parent path is unsafe, aborting for security"
	# #

    my $parent_root = File::Temp::tempdir(
        "secrets-parent-XXXXXX",
        DIR             => File::Spec->tmpdir(),
        CLEANUP         => 1,
    );

    my $real_parent     = "${parent_root}/real";
    my $link_parent     = "${parent_root}/link";

    mkdir( $real_parent, 0700 )
        or die "Unable to create protected test directory: $!";

    symlink( $real_parent, $link_parent )
        or die "Unable to create protected parent test symlink: $!";

    my $parent_file = "${real_parent}/secret.conf";

    sysopen(
        my $parent_handle,
        $parent_file,
        Fcntl::O_WRONLY() | Fcntl::O_CREAT() | Fcntl::O_EXCL(),
        0600,
    ) or die "Unable to create protected parent test file: $!";

    print { $parent_handle } "UI_PASS=private-value\n";

    close( $parent_handle )
        or die "Unable to close protected parent test file: $!";

    my $parent_type_found       = -l $link_parent ? "symbolic link" : "real directory";
    my $parent_type_expected    = "real directory";
    my $parent_err              = "";

    eval
    {
        ConfigServer::Secrets::read_file(
            "${link_parent}/secret.conf"
        );
        1;
    } or $parent_err = $@;

    like(
        $parent_err,
        qr/Secret file parent path is unsafe, aborting for security/,
        "[Secrets] Protected files reject symlink parent dirs"
    );

    note( _note_field( 'Parent type found', "$parent_type_found" ) );
    note( _note_field( 'Parent type expected', "$parent_type_expected" ) );
    note(
        _note_field(
            'Result',
            ( $parent_err ne "" ? $parent_err : "no error" ),
        ) .
        " \n"
    );

    # #
    #   Logger.t › Tests › Secrets › Protected File Parent Perms
    #   
    #   Place protected file in a dir writeable by every user
    #   and make sure read_file() rejects the unsafe parent
    #   dir.
    #   
    #   Input:      Parent perms found:     0777
    #               Parent perms expected:  0700
    #   
    #   Result:     File rejected with:
    #               "Secret file parent path is unsafe, aborting for security"
    # #

    my $unsafe_parent = File::Temp::tempdir(
        "secrets-writable-XXXXXX",
        DIR             => File::Spec->tmpdir(),
        CLEANUP         => 1,
    );

    my $unsafe_file = "${unsafe_parent}/secret.conf";

    sysopen(
        my $unsafe_handle,
        $unsafe_file,
        Fcntl::O_WRONLY() | Fcntl::O_CREAT() | Fcntl::O_EXCL(),
        0600,
    ) or die "Unable to create writable parent test file: $!";

    print { $unsafe_handle } "UI_PASS=private-value\n";

    close( $unsafe_handle )
        or die "Unable to close writable parent test file: $!";

    chmod( 0777, $unsafe_parent )
        or die "Unable to change protected parent perms: $!";

    my $perms_found     = sprintf( "%04o", ( stat( $unsafe_parent ) )[ 2 ] & 07777 );
    my $perms_expected  = "0700";
    my $perms_err       = "";

    eval
    {
        ConfigServer::Secrets::read_file( $unsafe_file );
        1;
    } or $perms_err   = $@;

    chmod( 0700, $unsafe_parent )
        or die "Unable to restore protected parent perms: $!";

    like(
        $perms_err,
        qr/Secret file parent path is unsafe, aborting for security/,
        "[Secrets] Protected files reject writable parent dirs"
    );

    note( _note_field( 'Parent perms found', "$perms_found" ) );
    note( _note_field( 'Parent perms expected', "$perms_expected" ) );
    note(
        _note_field(
            'Result',
            ( $perms_err ne "" ? $perms_err : "no error" ),
        ) .
        " \n"
    );

    # #
    #   Logger.t › Tests › Secrets › Protected File Type
    #   
    #   Pass a directory where read_file() requires a regular
    #   file. Confirm the directory is rejected before it is read.
    #   
    #   Input:      Type found:     directory
    #               Type expected:  regular file
    #   
    #   Result:     "Secret file was found to be unsafe"
    # #

    my $type_path = File::Temp::tempdir(
        "secrets-type-XXXXXX",
        DIR     => File::Spec->tmpdir(),
        CLEANUP => 1,
    );

    my $type_found     = "directory";
    my $type_expected  = "regular file";
    my $type_err     = "";

    eval
    {
        ConfigServer::Secrets::read_file( $type_path );
        1;
    } or $type_err = $@;

    like(
        $type_err,
        qr/Secret file was found to be unsafe/,
        "[Secrets] Protected file reads reject directories"
    );

    note( _note_field( 'Type found', "$type_found" ) );
    note( _note_field( 'Type expected', "$type_expected" ) );
    note(
        _note_field(
            'Result',
            ( $type_err ne "" ? $type_err : "no error" ),
        ) .
        " \n"
    );

    # #
    #   Logger.t › Tests › Secrets › Protected File Lock Limit
    #   
    #   Lock protected file in another process.
    #   Confirm read_file() stops after max num of
    #   attempts.
    #   
    #   Input:      Lock found:         Exclusive lock held
    #               Lock required:      Shared lock
    #               Maximum attempts:   20
    #   
    #   Result:     File read is rejected with:
    #               "Unable to lock protected secret file"
    # #

    my ( $locked_handle, $locked_path ) = File::Temp::tempfile(
        "secrets-locked-XXXXXX",
        DIR             => File::Spec->tmpdir(),
        UNLINK          => 1,
    );

    print { $locked_handle } "UI_PASS=private-value\n";

    close( $locked_handle )
        or die "Unable to close protected lock test file: $!";

    # #
    #   @note       child uses this pipe; tells the child when the
    #               lock is active.
    # #

    pipe( my $ready_reader, my $ready_writer )
        or die "Unable to create protected lock test pipe: $!";

    # #
    #   @note       parent uses this pipe; tells child when it
    #               can release the lock
    # #

    pipe( my $release_reader, my $release_writer )
        or die "Unable to create protected lock release pipe: $!";

    # parent [1226236], child [0]
    my $lock_process = fork( );

    die "Unable to create protected lock test process: $!"
        if !defined( $lock_process );

    # #
    #   Child process pid [0]
    # #

    if ( $lock_process == 0 )
    {
        close( $ready_reader );
        close( $release_writer );

        sysopen( my $child_handle, $locked_path, Fcntl::O_RDONLY() )
            or die "Unable to open protected lock test file: $!";

        flock( $child_handle, Fcntl::LOCK_EX() )
            or die "Unable to lock protected lock test file: $!";

        print { $ready_writer } "1";
        close( $ready_writer );

        my $release_signal = "";
        sysread( $release_reader, $release_signal, 1 );
        close( $release_reader );

        close( $child_handle );
        exit( 0 );
    }

    # #
    #   Only the parent process reaches this point
    # #

    close( $ready_writer );
    close( $release_reader );

    my $ready_signal = "";
    sysread ( $ready_reader, $ready_signal, 1 );
    close   ( $ready_reader );

    my $lock_found          = "exclusive lock held";
    my $lock_expected       = "available shared lock";
    my $lock_attempts_max   = ConfigServer::Secrets::LOCK_POLL_COUNT();
    my $lock_err            = "";

    eval {
        ConfigServer::Secrets::read_file( $locked_path );
        1;
    } or $lock_err = $@;

    print   { $release_writer } "1";
    close   ( $release_writer );
    waitpid ( $lock_process, 0 );

    like(
        $lock_err,
        qr/Secret file cannot be lock protected, aborting for security/,
        "[Secrets] Protected file locks stop after the bounded retry limit"
    );

    note( _note_field( 'Lock found', "$lock_found" ) );
    note( _note_field( 'Lock expected', "$lock_expected" ) );
    note( _note_field( 'Max attempts', "$lock_attempts_max" ) );
    note(
        _note_field(
            'Result',
            ( $lock_err ne "" ? $lock_err : "no error" ),
        ) .
        " \n"
    );

	# #
    #   Logger.t › Tests › Secrets › Protected File Parent Path
	#   
    #   Paths with ".." are rejected, because it moves into parent dir.
    #   
    #   Reject ".." to keep someone from reading files outside the
    #   allowed dir.
	#   
	#   Input:      /tmp/safechild/../secret.conf
	#   Result:     Secret file parent path is unsafe, abort
	# #

	my $path_test_root = File::Temp::tempdir(
		"secrets-parent-path-XXXXXX",
		DIR     => File::Spec->tmpdir(),
		CLEANUP => 1,
	);

	my $path_test_child = "${path_test_root}/child";
	my $path_test_file  = "${path_test_root}/secret.conf";

	mkdir( $path_test_child, 0700 )
		or die "Unable to create parent path test directory: $!";

	sysopen(
		my $path_test_handle,
		$path_test_file,
		Fcntl::O_WRONLY() | Fcntl::O_CREAT() | Fcntl::O_EXCL(),
		0600,
	) or die "Unable to create parent path test file: $!";

	print { $path_test_handle } "UI_PASS=private-value\n";
	close( $path_test_handle )
		or die "Unable to close parent path test file: $!";

	my $path_test_input = "${path_test_child}/../secret.conf";
	my $path_test_err   = "";

	eval
    {
		ConfigServer::Secrets::read_file( $path_test_input );
		1;
	} or $path_test_err = $@;

	like(
		$path_test_err,
		qr/Secret file parent path is unsafe, aborting for security/,
		"[Secrets] Protected file paths reject parent path"
	);

	note( _note_field( 'Path', "$path_test_input" ) );
	note(
	    _note_field(
	        'Result',
	        ( $path_test_err ne "" ? $path_test_err : "no error" ),
	    ) .
	    " \n"
	);

	# #
    #   Logger.t › Tests › Secrets › Protected File Descriptor Inheritance
	#   
	#   Confirm _set_close_on_exec() marks a protected file descriptor
	#   so another program can't inherit it through exec().
	#   
	#   Input:      Open protected file descriptor
	#   Result:     FD_CLOEXEC is enabled
	# #

	my ( $descriptor_handle, $descriptor_path ) = File::Temp::tempfile(
		"secrets-descriptor-XXXXXX",
		DIR    => File::Spec->tmpdir(),
		UNLINK => 1,
	);

	my $descriptor_protected    = ConfigServer::Secrets::_set_close_on_exec(
                                    $descriptor_handle
                                );
	my $descriptor_flags        = fcntl( $descriptor_handle, Fcntl::F_GETFD(), 0 );
	my $close_on_exec_found     = defined( $descriptor_flags ) &&
                                    ( $descriptor_flags & Fcntl::FD_CLOEXEC() )
                                    ? 1
                                        : 0;

	ok(
		$descriptor_protected && $close_on_exec_found,
		"[Secrets] Protected file descriptors are closed during exec"
	);

	note(
		_note_field(
			'Protection applied',
			$descriptor_protected ? 1 : 0,
		) . "\n" .
		_note_field( 'FD_CLOEXEC found', $close_on_exec_found ) .
		" \n"
	);

	close( $descriptor_handle )
		or die "Unable to close descriptor inheritance test file: $!";

	# #
    #   Logger.t › Tests › Secrets › Protected File Change Detection
	#   
	#   Inspect a protected file, change its size, and inspect it again.
	#   Confirm the second inspection detects that the file changed.
	#   
	#   Input:      File grows after its first inspection
	#   Result:     Second inspection returns undef
	# #

	my ( $change_handle, $change_path ) = File::Temp::tempfile(
		"secrets-change-XXXXXX",
		DIR    => File::Spec->tmpdir(),
		UNLINK => 1,
	);

	print { $change_handle } "UI_PASS=first-value\n";
	close( $change_handle )
		or die "Unable to close file change test file: $!";

	sysopen( my $change_reader, $change_path, Fcntl::O_RDONLY() )
		or die "Unable to open file change test reader: $!";

	my $change_owner        = ( stat( $change_reader ) )[ 4 ];
	my $initial_file_state  = ConfigServer::Secrets::_validate_secret_file(
                                $change_reader,
                                $change_path,
                                $change_owner,
                                ConfigServer::Secrets::FILE_BYTE_DEFAULT(),
                                undef,
                            );

	sysopen( my $change_writer, $change_path, Fcntl::O_WRONLY() | Fcntl::O_APPEND() )
		or die "Unable to open file change test writer: $!";

	print { $change_writer } "UI_PASS=second-value\n";
	close( $change_writer )
		or die "Unable to close file change test writer: $!";

	my $final_file_state    = ConfigServer::Secrets::_validate_secret_file(
                                $change_reader,
                                $change_path,
                                $change_owner,
                                ConfigServer::Secrets::FILE_BYTE_DEFAULT(),
                                $initial_file_state,
                            );

	ok(
		defined( $initial_file_state ) && !defined( $final_file_state ),
		"[Secrets] Protected file changes are detected after opening"
	);

	note(
		_note_field(
			'Initial inspection',
			defined( $initial_file_state ) ? "accepted" : "rejected",
		) . "\n" .
		_note_field(
			'Final inspection',
			defined( $final_file_state ) ? "accepted" : "rejected",
		) .
		" \n"
	);

	close( $change_reader )
		or die "Unable to close file change test reader: $!";

	done_testing( );
};

# #
#   Logger.t › Tests › Secrets › Name Normalization and Suffix Rules
#   
#   Confirm differently formatted secret names are normalized,
#   suffixes are detected, ordinary names remain public, and 
#   oversized names fail closed.
# #

my @secret_name_res = map {
	ConfigServer::Secrets::is_config_secret( $_ )
} (
	"--api-key",
	"API-Key",
	"DATABASE_PASSWORD",
	"MONKEY",
	"A" x ( $registry_entries_max + 1 ),
);

is_deeply(
	\@secret_name_res,
	[ 1, 1, 1, 0, 1 ],
	"[Secrets] Secret names are normalized and checked safely"
);

note(
	_note_field(
		'Result',
		"--api-key=$secret_name_res[ 0 ], " .
		"API-Key=$secret_name_res[ 1 ], " .
		"DATABASE_PASSWORD=$secret_name_res[ 2 ], " .
		"MONKEY=$secret_name_res[ 3 ], " .
		"oversized=$secret_name_res[ 4 ]",
	) .
	" \n\n"
);

# #
#   Logger.t › Tests › Secrets › Header Names
#   
#   Confirm header matching ignores caps and protects values used
#   by Cloudflare, AWS, api token, and CSRF auth headers.
# #

my $secret_header_res = ConfigServer::Secrets::redact_obj_log(
	"[api-key: first] " .
	"[CF-Access-Client-Secret: second] " .
	"[Cf-Access-Jwt-Assertion: third] " .
	"[X-Amz-Security-Token: fourth] " .
	"[x-api-token: fifth] " .
	"[X-CSRF-Token: sixth] " .
	"[Status: 200]"
);

is(
	$secret_header_res,
	"[api-key: [REDACTED]] " .
	"[CF-Access-Client-Secret: [REDACTED]] " .
	"[Cf-Access-Jwt-Assertion: [REDACTED]] " .
	"[X-Amz-Security-Token: [REDACTED]] " .
	"[x-api-token: [REDACTED]] " .
	"[X-CSRF-Token: [REDACTED]] " .
	"[Status: 200]",
	"[Secrets] Additional authentication header values are redacted"
);

note(
    _note_field(
        'Result',
        ( defined( $secret_header_res ) ? $secret_header_res : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Registry Exemption
#   
#   Confirm an exempt word is not registered for replacement in
#   normal text, while the same value is redacted when assigned to
#   UI_PASS.
# #

my $exempt_registered = ConfigServer::Secrets::register_secret( "UI_PASS", "changeme" );

my $placeholder_res = ConfigServer::Secrets::redact_obj_log(
	'Please changeme after installation; UI_PASS="changeme"'
);

is_deeply(
	[ $exempt_registered, $placeholder_res ],
	[ 0, 'Please changeme after installation; UI_PASS="[REDACTED]"' ],
	"[Secrets] Exemptions are only redacted in private fields"
);

note(
	_note_field(
		'Result',
		"registered = $exempt_registered, message = $placeholder_res",
	) .
	" \n\n"
);

# #
#   Logger.t › Tests › Secrets › Registered Value Size Limits
#   
#   Confirm register_secret() accepts values from 6 - 4,096 bytes and
#   rejects values immediately below or above those limits.
# #

my @secret_size_res = (
	ConfigServer::Secrets::register_secret( "API_KEY", "A" x 5 ),
	ConfigServer::Secrets::register_secret( "API_KEY", "B" x 6 ),
	ConfigServer::Secrets::register_secret( "API_KEY", "C" x 4_096 ),
	ConfigServer::Secrets::register_secret( "API_KEY", "D" x 4_097 ),
);

is_deeply(
	\@secret_size_res,
	[ 0, 1, 1, 0 ],
	"[Secrets] Registered secret byte limits are enforced"
);

note(
	_note_field(
		'Result',
		"5 bytes=$secret_size_res[ 0 ], " .
		"6 bytes=$secret_size_res[ 1 ], " .
		"4096 bytes=$secret_size_res[ 2 ], " .
		"4097 bytes=$secret_size_res[ 3 ]",
	) .
	" \n\n"
);

ConfigServer::Secrets::registry_clear( );

# #
#   Logger.t › Tests › Secrets › Multibyte Registered Value
#   
#   Confirm a 6 byte unicode secret is both accepted by
#   register_secret(), and is included in the exact redaction.
# #

my $multibyte_secret        = "\x{0100}\x{0101}\x{0102}";
my $multibyte_registered    = ConfigServer::Secrets::register_secret(
                                "API_KEY",
                                $multibyte_secret,
                            );
my $multibyte_res           = ConfigServer::Secrets::redact_obj_str(
                                "Value: $multibyte_secret"
                            );

is_deeply(
	[ $multibyte_registered, $multibyte_res ],
	[ 1, "Value: [REDACTED]" ],
	"[Secrets] Multibyte registered secrets are redacted"
);

note(
	_note_field(
		'Result',
		"registered = $multibyte_registered, message = $multibyte_res",
	) .
	" \n\n"
);

ConfigServer::Secrets::registry_clear( );

# #
#   Logger.t › Tests › Secrets › Registered Value with Control Character
#   
#   Confirm an exact secret containing a tab is redacted before log
#   control chars are changed into spaces.
# #

my $control_secret = "my\tsecret";
ConfigServer::Secrets::register_secret( "API_KEY", $control_secret );

my $control_secret_res = ConfigServer::Secrets::redact_obj_log(
	"Value: $control_secret"
);

is(
	$control_secret_res,
	"Value: [REDACTED]",
	"[Secrets] Registered secrets containing controls are redacted"
);

note(
    _note_field(
        'Result',
        ( defined( $control_secret_res ) ? $control_secret_res : "undef" ),
    ) .
    " \n\n"
);

ConfigServer::Secrets::registry_clear( );

# #
#   Logger.t › Tests › Secrets › Registry Entry Limit
#   
#   Register 257 unique values and confirm the oldest value is removed
#   while the newest value remains protected by redaction.
#   
#   Secrets.pm const REGISTRY_ENTRY_MAXIMUM only allows 256 max 
#   secrets to be registered.
# #

for my $secret_number ( 1 .. $registry_entries_max + 1 )
{
	ConfigServer::Secrets::register_secret(
		"API_KEY",
		sprintf( "registry-secret-%03d", $secret_number ),
	);
}

my $registry_limit_res = ConfigServer::Secrets::redact_obj_str(
	sprintf( "registry-secret-001 registry-secret-%03d", $registry_entries_max + 1 )
);

is(
	$registry_limit_res,
	"registry-secret-001 [REDACTED]",
	"[Secrets] Registry limit removes the oldest registered value"
);

note(
    _note_field(
        'Result',
        ( defined( $registry_limit_res ) ? $registry_limit_res : "undef" ),
    ) .
    " \n\n"
);

ConfigServer::Secrets::registry_clear( );

# #
#   Logger.t › Tests › Secrets › Clear Registered Values
#   
#   Confirm registry_clear() removes exact replacements from
#   memory so that previously registered text is no longer globally
#   redacted.
# #

ConfigServer::Secrets::register_secret( "API_KEY", "clear-me-csf-123" );

# #
#   @warn       Don't screw with the order:
#                   - Check value BEFORE clearing registry
#                   - Clear secret registry
#                   - Check value AFTER clearing registry
# #

my $registry_clear_before   = ConfigServer::Secrets::redact_obj_str( "Value: clear-me-csf-123" );
my $registry_cleared        = ConfigServer::Secrets::registry_clear( );
my $registry_clear_after    = ConfigServer::Secrets::redact_obj_str( "Value: clear-me-csf-123" );

is_deeply(
	[ $registry_cleared, $registry_clear_before, $registry_clear_after ],
	[ 1, "Value: [REDACTED]", "Value: clear-me-csf-123" ],
	"[Secrets] Registered secret values can be cleared"
);

note(
	_note_field(
		'Result',
		"cleared = $registry_cleared, " .
		"before = $registry_clear_before, " .
		"after = $registry_clear_after",
	) .
	" \n\n"
);

# #
#   Logger.t › Tests › Secrets › Structured and Nested URL Params
#   
#   Confirm bracketed param names and names encoded twice are decoded
#   for classification while their original speling remains in the
#   returned url.
# #

my $struct_param_url = ConfigServer::Secrets::redact_obj_url_replace(
    "https://configserver.dev/check?user%5Bpassword%5D=first&mode=test"
);

my $nested_param_url = ConfigServer::Secrets::redact_obj_url_replace(
    "https://configserver.dev/check?%2574oken=second&mode=test"
);

is_deeply(
	[ $struct_param_url, $nested_param_url ],
	[
		"https://configserver.dev/check?user%5Bpassword%5D=[REDACTED]&mode=test",
		"https://configserver.dev/check?%2574oken=[REDACTED]&mode=test",
	],
	"[Secrets] Encoded structured url secret names are recognized"
);

note(
    _note_field(
        'Result',
        "structured = $struct_param_url\n" .
        "nested     = $nested_param_url",
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › PGP Private Key
#   
#   Confirm the PGP private key label is recognized and all following
#   keys are replaced with KEY_MATERIAL_MASK.
# #

my $pgp_privatekey_res = ConfigServer::Secrets::redact_obj_log(
	"Before -----BEGIN PGP PRIVATE KEY BLOCK-----\n" .
	"fake-pgp-private-material\n" .
	"-----END PGP PRIVATE KEY BLOCK-----"
);

is(
	$pgp_privatekey_res,
	"Before [REDACTED PRIVATE KEY MATERIAL]",
	"[Secrets] PGP private key material is redacted"
);

note(
    _note_field(
        'Result',
        ( defined( $pgp_privatekey_res ) ? $pgp_privatekey_res : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Sanitization Scan Limit
#   
#   Confirm redact_obj_str() scams no more than 262,144 chars and adds 
#   the truncation marker when the supplied input exceeds that limit.
# #

my $scan_limit_res = ConfigServer::Secrets::redact_obj_str( "A" x 300_000 );

ok(
	length( $scan_limit_res ) == 262_156 &&
	$scan_limit_res =~ / \[TRUNCATED\]\z/,
	"[Secrets] Sanitization scan char limit is enforced"
);

note(
	_note_field(
		'Result',
		"chars = " . length( $scan_limit_res ) .
		", ending = " . substr( $scan_limit_res, -20 ),
	) .
	" \n\n"
);

# #
#   Logger.t › Tests › Secrets › Registered Values › Scan Boundary
#   
#   Place a registered secret across the sanitization scan limit.
#   Confirm truncation removes the complete secret instead of exposing
#   the part located before the boundary.
#   
#   Input:      ...AAAAcross-boundary-secret
#   Result:     ...AAAA [TRUNCATED]
#   
#   @warn       A broken boundary check could expose part of the
#               secret as "cross-boun [TRUNCATED]".
# #

ConfigServer::Secrets::registry_clear( );

my $boundary_secret = "cross-boundary-secret";
my $boundary_secret_registered = ConfigServer::Secrets::register_secret(
    "API_KEY",
    $boundary_secret,
);

my $scan_char_limit         = ConfigServer::Secrets::SCAN_CHARACTER_MAXIMUM();
my $boundary_secret_input   = ( "A" x ( $scan_char_limit - 10 ) ) . $boundary_secret;
my $boundary_secret_res     = ConfigServer::Secrets::redact_obj_str( $boundary_secret_input );

ok(
	$boundary_secret_registered &&
	index( $boundary_secret_res, $boundary_secret ) < 0 &&
	index( $boundary_secret_res, substr( $boundary_secret, 0, 10 ) ) < 0 &&
	$boundary_secret_res =~ / \[TRUNCATED\]\z/,
	"[Secrets] Truncation cannot expose part of a registered secret"
);

note( _note_field( 'Registered', "$boundary_secret_registered" ) );
note( _note_field( 'Ending', substr( $boundary_secret_res, -40 ) ) . " \n\n" );

ConfigServer::Secrets::registry_clear( );

# #
#   Logger.t › Tests › Secrets › Invalid Protected File Options
#   
#   Confirm reading a protected file rejects unknown / bad options,
#   relative paths, excessive byte limits, and owner ids outside
#   the supported range.
# #

my $protected_test_path = File::Spec->catfile( File::Spec->tmpdir(), "secrets-unused-$$" );
my @proctect_opt_err;

for my $protected_test (
	[ $protected_test_path, unsupported => 1 ],
	[ "relative-secret-file", max_bytes => 1 ],
	[ $protected_test_path . "\0suffix" ],
	[ $protected_test_path . ( "A" x ConfigServer::Secrets::PATH_BYTE_MAXIMUM() ) ],
	[ $protected_test_path, max_bytes => ConfigServer::Secrets::FILE_BYTE_MAXIMUM() + 1 ],
	[ $protected_test_path, owner => ConfigServer::Secrets::OWNER_UID_MAXIMUM() + 1 ],
)
{
	my ( $test_path, @test_options ) = @{$protected_test};
	my $err = "";

	eval {
		ConfigServer::Secrets::read_file( $test_path, @test_options );
		1;
	} or $err = $@;

	push @proctect_opt_err, $err;
}

ok(
    $proctect_opt_err[ 0 ] =~ /Secret file cannot be opened, a bad option was provided/ &&
    $proctect_opt_err[ 1 ] =~ /Secret file requires an absolute path/ &&
    $proctect_opt_err[ 2 ] =~ /Secret file path exceeds PATH_BYTE_MAXIMUM or contains control chars/ &&
    $proctect_opt_err[ 3 ] =~ /Secret file path exceeds PATH_BYTE_MAXIMUM or contains control chars/ &&
    $proctect_opt_err[ 4 ] =~ /Secret file size limit is not valid/ &&
    $proctect_opt_err[ 5 ] =~ /Secret file owner is not valid/,
	"[Secrets] Invalid protected file args are rejected"
);

note(
    _note_field(
        'Result',
        "unsupported = $proctect_opt_err[ 0 ]\n" .
        "relative    = $proctect_opt_err[ 1 ]\n" .
        "control     = $proctect_opt_err[ 2 ]\n" .
        "path size   = $proctect_opt_err[ 3 ]\n" .
        "max_bytes   = $proctect_opt_err[ 4 ]\n" .
        "owner       = $proctect_opt_err[ 5 ]",
    ) .
    " \n"
);

# #
#   Logger.t › Tests › Secrets › Invalid Protected File Line Limits
#
#   Confirm read_lines() rejects zero, excessive, non-numeric,
#   and reference values before attempting to open the file.
# #

my @line_limit_errs;

for my $line_limit ( 0, 262_145, "invalid", [] )
{
	my $line_limit_err = "";

	eval {
		ConfigServer::Secrets::read_lines(
			$protected_test_path,
			max_lines => $line_limit,
		);
		1;
	} or $line_limit_err = $@;

	push @line_limit_errs, $line_limit_err;
}

ok(
	!scalar( grep {
		$_ !~ /Secret file line limit is invalid/
	} @line_limit_errs ),
	"[Secrets] Invalid protected file line limits are rejected"
);

note(
    _note_field(
        'Result',
        "zero       = $line_limit_errs[ 0 ]\n" .
        "excessive  = $line_limit_errs[ 1 ]\n" .
        "nonnumeric = $line_limit_errs[ 2 ]\n" .
        "reference  = $line_limit_errs[ 3 ]",
    ) .
    " \n"
);

# #
#   Logger.t › Tests › Secrets › Text Sanitization › Terminal Escape Protection
#   
#   Make sure terminal color codes can't split a private field
#   name and prevent redact_obj_str() from recognizing it.
# #

my $password_escaped = ConfigServer::Secrets::redact_obj_str(
	"pass\e[31mword=hidden-value"
);

is(
	$password_escaped,
	"password=[REDACTED]",
	"[Secrets] Terminal escapes cannot conceal a private field name"
);

note(
    _note_field(
        'Result',
        ( defined( $password_escaped ) ? $password_escaped : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Private Key › Escapes
#   
#   Make sure terminal color codes can't split a private key
#   and expose the key material through redact_obj_str()   
# #

my $privatekey_escaped = ConfigServer::Secrets::redact_obj_str(
	"-----BEGIN \e[31mRSA\e[0m PRIVATE KEY-----\nprivate-material"
);

is(
	$privatekey_escaped,
	"[REDACTED PRIVATE KEY MATERIAL]",
	"[Secrets] Terminal escapes cannot conceal a private key marker from redact_obj_str()"
);

note(
    _note_field(
        'Result',
        ( defined( $privatekey_escaped ) ? $privatekey_escaped : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › URL Query › Deep Encoded Private Name
#   
#   Make sure repeated url encoding can't conceal the private
#   query name "token" when redact_obj_url_replace() keeps the
#   query string.
# #

my $encoded_url_deep = ConfigServer::Secrets::redact_obj_url_replace(
    "https://configserver.dev/?%252574oken=hidden-value&mode=test"
);

is(
	$encoded_url_deep,
	"https://configserver.dev/?%252574oken=[REDACTED]&mode=test",
	"[Secrets] Deep url encoding cannot conceal a private query name"
);

note(
    _note_field(
        'Result',
        ( defined( $encoded_url_deep ) ? $encoded_url_deep : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Auth Header › Closing Bracket Protection
#   
#   Make sure a closing bracket in a untrusted header value can't
#   expose the remaining of that value.
#   
#   Other diag fields remain
# #

my $bracketed_header = ConfigServer::Secrets::redact_obj_log(
	"[Authorization: first]hidden-rest] [Status: 401]"
);

is(
	$bracketed_header,
	"[Authorization: [REDACTED]] [Status: 401]",
	"[Secrets] A closing bracket cannot expose an authorization value suffix"
);

note(
    _note_field(
        'Result',
        ( defined( $bracketed_header ) ? $bracketed_header : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › URL Path › Secret Segment Redaction
#
#   Check if a secret placed directly inside a url path is removed.
#
#   _redact_url_path() checks each route against
#   %REGISTRY_SECRET_URL_ROUTES. When a route such as "reset" is
#   seen, the following path segment is treated as private.
#
#   Input:      https://configserver.dev/reset/private-token-value
#   Result:     https://configserver.dev/reset/[REDACTED]
# #

my $private_url_path = ConfigServer::Secrets::redact_obj_log(
	"https://configserver.dev/reset/private-token-value"
);

is(
	$private_url_path,
	"https://configserver.dev/reset/[REDACTED]",
	"[Secrets] Secret url path segments are redacted"
);

note(
    _note_field(
        'Result',
        ( defined( $private_url_path ) ? $private_url_path : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Registered Value › Control Char Registration
#   
#   Make sure a secret with a tab char is accepted by register_secret()
#   
#   Input:      API_KEY = "registered\tsecret"
#   Result:     1; secret accepted and registered for redaction
# #

my $registered_control_secret = ConfigServer::Secrets::register_secret(
	"API_KEY",
	"registered\tsecret",
);

ok(
	$registered_control_secret,
	"[Secrets] A registered secret containing a control character is accepted"
);

note(
    _note_field(
        'Result',
        ( defined( $registered_control_secret ) ? $registered_control_secret : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Registered Value › Redaction Before Control Flattening
#   
#   Confirm the registered value is masked before its tab is
#   converted to a normal space.
#   
#   Input:      value=registered\tsecret
#   Result:     value=[REDACTED]
# #

my $registered_control_res = ConfigServer::Secrets::redact_obj_log(
	"value=registered\tsecret"
);

is(
	$registered_control_res,
	"value=[REDACTED]",
	"[Secrets] Registered values are masked before controls are flattened"
);

note(
    _note_field(
        'Result',
        ( defined( $registered_control_res ) ? $registered_control_res : "undef" ),
    ) .
    " \n\n"
);

ConfigServer::Secrets::registry_clear( );

# #
#   Logger.t › Tests › Secrets › Registry Combined Byte Limit
#   
#   Fill the registry beyond constant REGISTRY_BYTE_MAXIMUM and
#   confirm the oldest large value is removed.
#   
#   Newest value should remain protected.
#   
#   Input:      65 secret values; contains 4,096 bytes each.
#               Combined size exceeds the 64 KB registry limit
#   
#   Result:     Oldest value removed; remains visible.
#               Newest value remains registered and is [REDACTED]
# #

my @byte_limit_val;

for my $byte_limit_num ( 1 .. 65 )
{
	my $byte_value = sprintf( "%04d", $byte_limit_num ) . ( "X" x 4092 );

	push @byte_limit_val, $byte_value;
	ConfigServer::Secrets::register_secret( "API_KEY", $byte_value );
}

my $oldest_large_value = ConfigServer::Secrets::redact_obj_str(
	$byte_limit_val[ 0 ]
);

is(
	$oldest_large_value,
	$byte_limit_val[ 0 ],
	"[Secrets] Registry byte limit removes the oldest registered value"
);

note(
	_note_field(
		'Result',
		"oldest value retained in output = " .
		( $oldest_large_value eq $byte_limit_val[ 0 ] ? "yes" : "no" ),
	) .
	" \n\n"
);

my $newest_large_value = ConfigServer::Secrets::redact_obj_str(
	$byte_limit_val[ -1 ]
);

is(
	$newest_large_value,
	"[REDACTED]",
	"[Secrets] Registry byte limit keeps the newest registered value"
);

note(
    _note_field(
        'Result',
        ( defined( $newest_large_value ) ? $newest_large_value : "undef" ),
    ) .
    " \n\n"
);

# #
#   Leave the registry empty so that these stress values can't
#   affect later tests.
# #

ConfigServer::Secrets::registry_clear( );

# #
#   Logger.t › Tests › Secrets › Invalid Public Inputs
#   
#   Pass missing values and arrayref to funcs that expect strings or
#   a config hash. Confirm each func rejects the invalid input 
#   without exposing data or terminating CSF.
#
#   Input:      undef       Missing value
#               []          arrayref instead of required value
#
#   Result:     Classification and registration funcs return 0
#               URL and text funcs return an empty string
#
#   @note       redact_obj_log() handles refs different.
#               It returns "[INVALID LOG MESSAGE]" and is tested
#               separately.
# #

my @invalid_secret_res = (

	# report failure using 0
	ConfigServer::Secrets::is_config_secret( undef ),
	ConfigServer::Secrets::is_config_secret( [] ),
	ConfigServer::Secrets::register_secret( "API_KEY", undef ),
	ConfigServer::Secrets::register_secret( "API_KEY", [] ),

    # register_secrets() requires a hashref, not an array
	ConfigServer::Secrets::register_secrets( [] ),

	# reject invalid input using an empty string
	ConfigServer::Secrets::redact_obj_url( undef ),
	ConfigServer::Secrets::redact_obj_url( [] ),
	ConfigServer::Secrets::redact_obj_url_replace( undef ),
	ConfigServer::Secrets::redact_obj_url_replace( [] ),
	ConfigServer::Secrets::redact_obj_str( [] ),
	ConfigServer::Secrets::redact_obj_cfg_line( [] ),
);

is_deeply(
	\@invalid_secret_res,
	[ 0, 0, 0, 0, 0, "", "", "", "", "", "" ],
	"[Secrets] Invalid public inputs are rejected safely"
);

note( _note_field( 'Failure results',"Five returned 0" ) );
note( _note_field( 'Empty string results',"Six returned an empty string" ) );
note(
    _note_field(
        'Result',
        "Invalid inputs handled safely",
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › CSF Settings › Explicit Setting Rules
#
#   Check every CSF setting listed in the module's explicit setting
#   registry.
#       return 1    Secret settings
#       return 0    Public settings
#
#   Input:      8 secret CSF setting names
#               3 public CSF setting names
#
#   Result:     Secret settings return 1
#               Public settings return 0
#
#   @note       Explicit public rules take priority over general
#               secret name rules:
#   
#               Eg: MESSENGER_HTTPS_KEY remains public even though
#               its name ends with "_KEY".
# #

my %csf_setting_res = map
{
	$_ => ConfigServer::Secrets::is_config_secret( $_ )
} qw(
	AT_PASSWD
	CFAPIKEY
	CLUSTER_KEY
	MM_LICENSE_KEY
	SPONSOR_LICENSE
	RECAPTCHA_SECRET
	ST_MYSQL_PASS
	UI_PASS
	MESSENGER_HTTPS_KEY
	PORTS_HTPASSWD
	RECAPTCHA_SITEKEY
);

# #
#   Compare all settings and results
# #

is_deeply(
	\%csf_setting_res,
	{
		AT_PASSWD           => 1,
		CFAPIKEY            => 1,
		CLUSTER_KEY         => 1,
		MM_LICENSE_KEY      => 1,
		SPONSOR_LICENSE     => 1,
		RECAPTCHA_SECRET    => 1,
		ST_MYSQL_PASS       => 1,
		UI_PASS             => 1,
		MESSENGER_HTTPS_KEY => 0,
		PORTS_HTPASSWD      => 0,
		RECAPTCHA_SITEKEY   => 0,
	},
	"[Secrets] Explicit CSF secret and public setting rules remain complete"
);

my @settings_secret = sort grep
{
	$csf_setting_res{$_}
} keys %csf_setting_res;

my @settings_public = sort grep
{
	!$csf_setting_res{$_}
} keys %csf_setting_res;

note(
    _note_field( 'Private (1)', join( ", ", @settings_secret ) ) . "\n" .
    _note_field( 'Public (0)', join( ", ", @settings_public ) ) . "\n" .
    _note_field(
        'Result',
        "All explicit CSF settings matched",
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Secrets › Secret Names › Suffix
#
#   Check setting names that end with recognized secret suffixes.
#   Each name must be classified as secret.
#
#   Input:      Setting names ending with suffixes such as:
#               _LICENSE_KEY, _ACCESS_KEY, _TOKEN, _PRIVATE_KEY,
#               _PASSWORD, _SIGNATURE, _SESSION_ID and _COOKIE
#
#   Result:     is_config_secret() returns 1
#               (for every name)
#
#   @note       This tests name classification only. It does not
#               register or redact values assigned to these names.
# #

# #
#   These are bogus setting names, not in the actual csf.conf.
#   These just test to make sure suffix detection works.
# #

my @suffix_names = qw(
	SERVICE_LICENSE_KEY
	DATABASE_ACCESS_KEY
	LOGIN_REFRESH_TOKEN
	OIDC_ID_TOKEN
	APP_CLIENT_SECRET
	TLS_PRIVATE_KEY
	REQUEST_AUTH_KEY
	USER_PASSPHRASE
	REQUEST_SIGNATURE
	FORM_CSRF_TOKEN
	FORM_G_RECAPTCHA_RESPONSE
	API_KEY
	APIKEY
	LICENSE
	LICENSE_KEY
	LICENSEKEY
	ACCESS_KEY
	ACCESSKEY
	ACCESS_TOKEN
	ACCESSTOKEN
	REFRESH_TOKEN
	REFRESHTOKEN
	ID_TOKEN
	IDTOKEN
	CLIENT_SECRET
	CLIENTSECRET
	PRIVATE_KEY
	PRIVATEKEY
	AUTH
	AUTHORIZATION
	AUTH_KEY
	CREDENTIAL
	PASSWORD
	PASSWD
	PASSPHRASE
	PWD
	TOKEN
	SECRET
	SECRETS
	KEY
	SIGNATURE
	AWSACCESSKEYID
	X_AMZ_SIGNATURE
	X_AMZ_CREDENTIAL
	SESSION
	SESSION_ID
	SESSIONID
	SESS_ID
	SESSID
	COOKIE
	CSRF_TOKEN
	G_RECAPTCHA_RESPONSE
);

my %suffix_res = map
{
	$_ => ConfigServer::Secrets::is_config_secret( $_ )
} @suffix_names;

my %suffix_expected = map
{
	$_ => 1
} @suffix_names;

is_deeply(
	\%suffix_res,
	\%suffix_expected,
	"[Secrets] Suffix settings are classified as secret"
);

for my $suffix_name ( @suffix_names )
{
	note(
		_note_field(
			$suffix_name,
			defined( $suffix_res{$suffix_name} )
				? $suffix_res{$suffix_name}
				: "undef",
		)
	);
}

note( "" );

# #
#   Logger.t › Tests › Secrets › Registered Values › Regex Char Handling
#
#   Register a secret containing chars that normally have special
#   meaning inside regex. 
#   
#   Confirm those chars are treated as normal text during
#   exact string/value redaction.
#
#   Registered: a.b[c](d)+?*
#
#   Input:      value=a.b[c](d)+?*
#   Result:     value=[REDACTED]
#
#   Input:      value=axb[c](d)+?*
#   Result:     value=axb[c](d)+?*
#
#   @note       The second value must remain visible because "x" does
#               not exactly match the period in the registered value.
# #

my $regex_secret_registered = ConfigServer::Secrets::register_secret(
	"API_KEY",
	"a.b[c](d)+?*",
);

my $regex_secret_exact = ConfigServer::Secrets::redact_obj_str( "value=a.b[c](d)+?*" );
my $regex_secret_near  = ConfigServer::Secrets::redact_obj_str( "value=axb[c](d)+?*" );

is_deeply(
	[
		$regex_secret_registered,
		$regex_secret_exact,
		$regex_secret_near,
	],
	[
		1,
		"value=[REDACTED]",
		"value=axb[c](d)+?*",
	],
	"[Secrets] Registered values containing regex chars match literally"
);

note( _note_field( 'Registered', "$regex_secret_registered" ) );
note( _note_field( 'Exact result', "$regex_secret_exact" ) );
note( _note_field( 'Near result', "$regex_secret_near" ) . " \n\n" );

ConfigServer::Secrets::registry_clear( );

# #
#   Logger.t › Tests › Secrets › Registered Values › Overlapping
#   
#   Register two secrets where the shorter value is also the beginning
#   of the longer value.
#   
#   Make sure the entire longer secret is replaced.
#   
#   Registered: secret-value
#               secret-value-extended
#   
#   Input:      secret-value-extended
#   Result:     [REDACTED]
#   
#   @warn       If the shorter value were matched first, the
#               result would screw up and incorrectly expose part
#               of the longer secret:
#                   [REDACTED]-extended
# #

my $secret_reg_short = ConfigServer::Secrets::register_secret(
    "API_KEY",
    "secret-value",
);

my $secret_reg_long = ConfigServer::Secrets::register_secret(
    "API_KEY",
    "secret-value-extended",
);

my $secret_overlap = ConfigServer::Secrets::redact_obj_str(
    "secret-value-extended"
);

is_deeply(
	[
		$secret_reg_short,
		$secret_reg_long,
		$secret_overlap,
	],
	[
		1,
		1,
		"[REDACTED]",
	],
	"[Secrets] Overlapping values are registered and the longest is fully redacted"
);

note( _note_field( 'Short value registered', "$secret_reg_short" ) );
note( _note_field( 'Long value registered', "$secret_reg_long" ) );
note( _note_field( 'Result', "$secret_overlap" ) . " \n\n" );

# #
#   Leave the registry empty so these values can't affect later tests.
# #

ConfigServer::Secrets::registry_clear( );

# #
#   Logger.t › Tests › Secrets › Field Assignments › Alternate Formats
#   
#   Pass multiple assignment formats through redact_obj_log().
#   Confirm values assigned to private field names are redacted while
#   an ordinary public field remains visible.
#   
#   Input:      password => 'one two'
#               token:bare
#               public=value
#   
#   Result:     password => '[REDACTED]'
#               token:[REDACTED]
#               public=value
#   
#   @note       Quotes around a secret value are kept.
#               Only the value in the quotes is replaced.
# #

my $assignment_input = q{password => 'one two'; token:bare; public=value};
my $assignment_res = ConfigServer::Secrets::redact_obj_log(
    $assignment_input
);

is(
	$assignment_res,
	q{password => '[REDACTED]'; token:[REDACTED]; public=value},
	"[Secrets] Alternate secret assignment formats are redacted"
);

note( _note_field( 'Input', "$assignment_input" ) );
note( _note_field( 'Result', "$assignment_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › Command Options › Value Boundarys
#   
#   Redact a quoted secret passed through a cli option.
#   
#   Make sure the sanitizer stops at the end of that option and
#   keeps the public option that follows it.
#   
#   Input:      --api-key="one two" --mode=public
#   Result:     --api-key="[REDACTED]" --mode=public
#   
#   @warn       "API-Key" may be used as an HTTP header or a
#               cli option:
#                   HTTP header:        API-Key: secret
#                   Command option:     --api-key="secret"
#   
#               The http header rule must ignore the cmd option.
#   
#               The cmd option rule must redact only its value
#               and preserve the option that follows it.
#   
#               Incorrect:  --api-key=[REDACTED]
#               Expected:   --api-key="[REDACTED]" --mode=public
# #

my $cmd_option_input = q{--api-key="one two" --mode=public};
my $cmd_option_res = ConfigServer::Secrets::redact_obj_log(
    $cmd_option_input
);

is(
	$cmd_option_res,
	q{--api-key="[REDACTED]" --mode=public},
	"[Secrets] Secret command option stops before the following public option"
);

note( _note_field( 'Input', "$cmd_option_input" ) );
note( _note_field( 'Result', "$cmd_option_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › URLs › Fragment Removal
#   
#   Pass a url containing a fragment but no query string through
#   redact_obj_url_replace().
#   
#   Since fragments are pretty useless in a log file, confirm
#   everything beginning with the "#" char is removed. These could
#   potentially contain secrets.
#   
#   Input:      https://configserver.dev/docs#private-location
#   Result:     https://configserver.dev/docs
#   
#   @note       redact_obj_url_replace() keeps safe query values,
#               but url fragments are always removed because they
#               may contain sensitive info. CSF doesn't do this
#               currently, but it's more-so precautionary. No
#               surprises later.
# #

my $frag_url_input = "https://configserver.dev/docs#private-location";
my $frag_url_res = ConfigServer::Secrets::redact_obj_url_replace(
    $frag_url_input
);

is(
	$frag_url_res,
	"https://configserver.dev/docs",
	"[Secrets] URL fragments are always removed"
);

note( _note_field( 'Input', "$frag_url_input" ) );
note( _note_field( 'Result', "$frag_url_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › URLs › Mixed Query Separators
#   
#   Pass url containing query params separated by both a semicolon
#   and ampersand through redact_obj_url_replace().
#   
#   Confirm secret param values are redacted while the public
#   param and original separators stay unchanged.
#   
#   Input:      token=one;mode=ok&api_key=two
#   Result:     token=[REDACTED];mode=ok&api_key=[REDACTED]
#   
#   @note       "token" and "api_key" are classified as secrets.
#               "mode" is public and remains visible.
# #

my $query_separator_input   = "https://configserver.dev/check?token=one;mode=ok&api_key=two";
my $query_separator_res     = ConfigServer::Secrets::redact_obj_url_replace( $query_separator_input );

is(
	$query_separator_res,
	"https://configserver.dev/check?token=[REDACTED];mode=ok&api_key=[REDACTED]",
	"[Secrets] Mixed url query separators are preserved safely"
);

note( _note_field( 'Input', "$query_separator_input" ) );
note( _note_field( 'Result', "$query_separator_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › URLs › Secret Query Flag
#   
#   Pass a url containing a secret query param without an equal
#   sign or assigned value through redact_obj_url_replace().
#   
#   Confirm the secret param name is recognized and receives a
#   redaction marker while the public param remains visible.
#   
#   Input:      https://configserver.dev/check?token&mode=ok
#   Result:     https://configserver.dev/check?token=[REDACTED]&mode=ok
#   
#   @note       "Query flag":   Param without an assigned value.
#                               No equal sign:
#                                   Query flag:         ?token
#                                   Valued param:       ?token=abcde
#                                   Empty value param:  ?token=
# #

my $query_flag_input    = "https://configserver.dev/check?token&mode=ok";
my $query_flag_res      = ConfigServer::Secrets::redact_obj_url_replace( $query_flag_input );

is(
	$query_flag_res,
	"https://configserver.dev/check?token=[REDACTED]&mode=ok",
	"[Secrets] Private url query flags are redacted"
);

note( _note_field( 'Input', "$query_flag_input" ) );
note( _note_field( 'Result', "$query_flag_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › URLs › Encoded Sensitive Route
#   
#   Pass a url with an encoded sensitive route through redact_obj_log().
#   Make sure the route is decoded and the path segment is redacted.
#   
#   Encoded route:  %52eset
#   Decoded route:  Reset
#   
#   Input:      https://configserver.dev/%52eset/account-code-123
#   Result:     https://configserver.dev/%52eset/[REDACTED]
#   
#   @note       "%52" = encoded form of uppercase "R"
#   
#               Route matching is case insensitive, so "Reset" and
#               "reset" are the same.
# #

my $encoded_route_input = "https://configserver.dev/%52eset/account-code-123";
my $encoded_route_res   = ConfigServer::Secrets::redact_obj_log( $encoded_route_input );

is(
	$encoded_route_res,
	"https://configserver.dev/%52eset/[REDACTED]",
	"[Secrets] Encoded sensitive URL routes cannot conceal the next segment"
);

note( _note_field( 'Input', "$encoded_route_input" ) );
note( _note_field( 'Result', "$encoded_route_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › URLs › Sensitive Route Registry
#   
#   Check every route that requires the following URL path segment
#   to be redacted. This fails if a required route is removed.
#   
#   @note[119]  !$is_route_secret keeps registered %REGISTRY_SECRET_SUFFIX
#               routes like 'auth', 'credential', 'secret', and 'token'
#               visible, while $redact_next_segment redacts the following value.
#                   Before:     https://configserver.dev/[REDACTED]/[REDACTED]
#                   Expected:   https://configserver.dev/auth/[REDACTED]
# #

my @route_secrets = qw(
	auth
	callback
	credential
	invite
	reset
	secret
	token
	verify
	webhook
);

my %route_secret_res = map
{
	my $route = $_;
	$route => ConfigServer::Secrets::redact_obj_log( "https://configserver.dev/${route}/account-code-123" )
} @route_secrets;

my %route_secret_expected = map
{
	$_ => "https://configserver.dev/${_}/[REDACTED]"
} @route_secrets;

is_deeply(
	\%route_secret_res,
	\%route_secret_expected,
	"[Secrets] Every sensitive URL route protects its following segment"
);

for my $route_secret ( @route_secrets )
{
	note(
		_note_field( $route_secret, $route_secret_res{$route_secret} )
	);
}

note( "" );

# #
#   Logger.t › Tests › Secrets › URLs › Public Route
#   
#   Pass a regular url path through redact_obj_log(). Confirm the
#   route and its path segment remain visible.
#   
#   Input:      https://configserver.dev/public/ordinary-value
#   Result:     https://configserver.dev/public/ordinary-value
#   
#   @note       "public" is not listed as a sensitive url route,
#               and "ordinary-value" is not recognized as a secret.
# #

my $route_public_input  = "https://configserver.dev/public/ordinary-value";
my $route_public_res    = ConfigServer::Secrets::redact_obj_log( $route_public_input );

is(
	$route_public_res,
	$route_public_input,
	"[Secrets] Public URL path segments remain visible"
);

note( _note_field( 'Input', "$route_public_input" ) );
note( _note_field( 'Result', "$route_public_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › HTTP Headers › Multiple Secret Values
#   
#   Pass several supported headers through redact_obj_log().
#   
#   Make sure each secret header value is redacted  while the public
#   values remains visible.
#   
#   Input:      Cookie: cookie-value
#               Proxy-Authorization: proxy-value
#               Set-Cookie: set-value
#               X-Auth-Key: auth-value
#               X-API-Key: api-value
#               X-Access-Token: token-value
#               X-XSRF-Token: xsrf-value
#               Status: 200
#   
#   Result:     [Cookie: [REDACTED]]
#               [Proxy-Authorization: [REDACTED]]
#               [Set-Cookie: [REDACTED]]
#               [X-Auth-Key: [REDACTED]]
#               [X-API-Key: [REDACTED]]
#               [X-Access-Token: [REDACTED]]
#               [X-XSRF-Token: [REDACTED]]
#               [Status: 200]
#   
#   @warn       Each closing bracket should end its own header only.
#               One secret header must not consume the fields 
#               after it.
# #

my $secret_headers_input        = "[Cookie: cookie-value] [Proxy-Authorization: proxy-value] " .
                                  "[Set-Cookie: set-value] [X-Auth-Key: auth-value] " .
                                  "[X-API-Key: api-value] [X-Access-Token: token-value] " .
                                  "[X-XSRF-Token: xsrf-value] [Status: 200]";

my $secret_headers_res          = ConfigServer::Secrets::redact_obj_log( $secret_headers_input );

my $secret_headers_expected     = "[Cookie: [REDACTED]] [Proxy-Authorization: [REDACTED]] " .
                                  "[Set-Cookie: [REDACTED]] [X-Auth-Key: [REDACTED]] " .
                                  "[X-API-Key: [REDACTED]] [X-Access-Token: [REDACTED]] " .
                                  "[X-XSRF-Token: [REDACTED]] [Status: 200]";

is(
	$secret_headers_res,
	$secret_headers_expected,
	"[Secrets] Secret headers are redacted independently"
);

# #
#   Show the heaters one per line in note because it's easier to
#   track; split at ] [
# #

for my $header ( split( /(?<=\]) (?=\[)/, $secret_headers_input ) )
{
	note( _note_field( 'Input', $header ) );
}

for my $header ( split( /(?<=\]) (?=\[)/, $secret_headers_res ) )
{
	note( _note_field( 'Result', $header ) );
}

note( "" );

# #
#   Logger.t › Tests › Secrets › Recognizable Tokens › Boundary Validation
#   
#   Pass complete / incomplete token patterns to redact_obj_log().
#   
#   Make sure AWS / JWT patterns are redacted while shorter near
#   matches aren't touched.
#   
#   AWS:        "AKIA" or "ASIA" followed by exactly 16 uppercase
#               letters or numbers.
#   
#   JWT:        First section begins with "eyJ" followed by at
#               least 8 chars. The next two sections must each
#               hav at least 8 chars.
#   
#   AWS Test:
#       Input:  ASIAABCeDEFGHIJKLMNOP
#       Match:  ASIA + 16 chars
#       Result: [REDACTED]
#   
#   JWT Test:
#       Input:  eyJabcdefgh.abcdefgh.abcdefgh
#       Match:  eyJ + 8 chars . 8 chars . 8 chars
#       Result: [REDACTED]
#   
#   Near JWT Test:
#       Input:  eyJshort.short.short
#       Match:  None - Sections are too short
#       Result: eyJshort.short.short
#   
#   @note       These tests check recognizable token formats.
#               They don't verify if a token is authentic.
# #

# #
#   Good tokens
# #

my $token_good_input    = "ASIAABCDEFGHIJKLMNOP eyJabcdefgh.abcdefgh.abcdefgh";
my $token_good_res      = ConfigServer::Secrets::redact_obj_log( $token_good_input );

# #
#   Bad tokens that don't match
# #

my $token_bad_input     = "AKIAABCDEFGHIJKLMNO eyJshort.short.short";
my $token_bad_res       = ConfigServer::Secrets::redact_obj_log( $token_bad_input );

is_deeply(
	[
		$token_good_res,
		$token_bad_res,
	],
	[
		"[REDACTED] [REDACTED]",
		"AKIAABCDEFGHIJKLMNO eyJshort.short.short",
	],
	"[Secrets] Recognizable token rules respect complete token boundaries"
);

note( _note_field( 'Recognized input', "$token_good_input" ) );
note( _note_field( 'Recognized result', "$token_good_res" ) );
note( _note_field( 'Near-match input', "$token_bad_input" ) );
note( _note_field( 'Near-match result', "$token_bad_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › UUID Tokens › V4
#   
#   Confirm uuid v4 token is redacted:
#       Input:  550e8400-e29b-41d4-a716-446655440000
#       Result: [REDACTED]
#   
#   @note       These tests recognize uuid structure. They do not
#               verify if a uuid string is valid
#   
#   @note       Some notes about UUID4 and UUID5 below for future
#               ref:
#   
#               Version         1st char of 3rd group
#               Variant         1st char of 4th group
#   
#               UUID:           550e8400-e29b-41d4-a716-446655440000
#                   Group 1:    550e8400
#                   Group 2:    e29b
#                   Group 3:    41d4            Version = 4
#                   Group 4:    a716            Variant = a
#                   Group 5:    446655440000
#   
#               Supported variants:
#                   8 = 1000
#                   9 = 1001
#                   a = 1010
#                   b = 1011
#   
#               UUID Versions:
#                   v4 = Random; 122 bits
#                   v5 = Deterministic; generated from a namespace
#                        UUID and name using SHA-1
# #

my $uuid_v4_input = "550e8400-e29b-41d4-a716-446655440000";
my $uuid_v4_res = ConfigServer::Secrets::_redact_tokens_uuid(
    $uuid_v4_input
);

is(
	$uuid_v4_res,
	"[REDACTED]",
	"[Secrets] UUID4 tokens are redacted"
);

note( _note_field( 'Input', "$uuid_v4_input" ) );
note( _note_field( 'Result', "$uuid_v4_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › UUID Tokens › V5
#   
#   Confirm a complete uuid v5 token is redacted:
#   Input:      cfbff0d1-9375-5685-968c-48ce8b15ae17
#   Result:     [REDACTED]
#   
#   @note       These tests recognize uuid structure. They do not
#               verify if a uuid string is valid
# #

my $uuid_v5_input = "cfbff0d1-9375-5685-968c-48ce8b15ae17";
my $uuid_v5_res = ConfigServer::Secrets::_redact_tokens_uuid(
    $uuid_v5_input
);

is(
	$uuid_v5_res,
	"[REDACTED]",
	"[Secrets] UUID5 tokens are redacted"
);

note( _note_field( 'Input', "$uuid_v5_input" ) );
note( _note_field( 'Result', "$uuid_v5_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › UUID Tokens › Uppercase
#   
#   Confirm uppercase uuid chars are recognized and redacted:
#   Input:      cfbff0d1-9375-5685-968c-48ce8b15ae17
#   Result:     [REDACTED]
#   
#   @note       These tests recognize uuid structure. They do not
#               verify if a uuid string is valid
# #

my $uuid_v5_upper_input = "CFBFF0D1-9375-5685-968C-48CE8B15AE17";
my $uuid_v5_upper_res = ConfigServer::Secrets::_redact_tokens_uuid(
    $uuid_v5_upper_input
);

is(
	$uuid_v5_upper_res,
	"[REDACTED]",
	"[Secrets] Uppercase UUID5 tokens are redacted"
);

note( _note_field( 'Input', "$uuid_v5_upper_input" ) );
note( _note_field( 'Result', "$uuid_v5_upper_res" ) ." \n\n" );

# #
#   Logger.t › Tests › Secrets › UUID Tokens › Unsupported Version
#   
#   Confirm if a uuid v1 identifier is not redacted.
#   Only uuid v4 and v5 are treated as tokens.
# #

my $uuid_v1_input = "6ba7b810-9dad-11d1-80b4-00c04fd430c8";
my $uuid_v1_res = ConfigServer::Secrets::_redact_tokens_uuid(
    $uuid_v1_input
);

is(
	$uuid_v1_res,
	$uuid_v1_input,
	"[Secrets] UUID1 identifiers remain visible"
);

note( _note_field( 'Input', "$uuid_v1_input" ) );
note( _note_field( 'Result', "$uuid_v1_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › UUID Tokens › Invalid Variant
#   
#   Confirm if uuid with an invalid variant is not redacted.
#   Valid variants must begin with 8, 9, a, or b.
#   
#   @note       How UUID variants work:
#   
#               Version         1st char of 3rd group
#             * Variant         1st char of 4th group
#   
#               UUID:           550e8400-e29b-41d4-a716-446655440000
#                   Group 1:    550e8400
#                   Group 2:    e29b
#                   Group 3:    41d4            Version = 4
#                   Group 4:    a716          * Variant = a
#                   Group 5:    446655440000
#   
#               Supported variants:
#                   8 = 1000
#                   9 = 1001
#                   a = 1010
#                   b = 1011
#   
#               UUID Versions:
#                   v4 = Random; 122 bits
#                   v5 = Deterministic; generated from a namespace
#                        UUID and name using SHA-1
# #

my $uuid_bad_input = "550e8400-e29b-41d4-7716-446655440000";
my $uuid_bad_res = ConfigServer::Secrets::_redact_tokens_uuid(
    $uuid_bad_input
);

is(
	$uuid_bad_res,
	$uuid_bad_input,
	"[Secrets] UUIDs with invalid variants remain visible"
);

note( _note_field( 'Input',"$uuid_bad_input" ) );
note( _note_field( 'Result', "$uuid_bad_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › UUID Tokens › Identifier Boundary
#
#   Confirm uuid text inside a larger identifier is not redacted.
# #

my $uuid_embedded_input = "x550e8400-e29b-41d4-a716-446655440000y";
my $uuid_embedded_res = ConfigServer::Secrets::_redact_tokens_uuid(
    $uuid_embedded_input
);

is(
	$uuid_embedded_res,
	$uuid_embedded_input,
	"[Secrets] UUID text embedded in identifiers remains visible"
);

note( _note_field( 'Input', "$uuid_embedded_input" ) );
note( _note_field( 'Result', "$uuid_embedded_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › UUID Tokens › Log Redaction
#   
#   Make sure redact_obj_log() applies uuid token redaction;
#   preserve the rest of the log msg.
# #

my $uuid_log_input = "Request 550e8400-e29b-41d4-a716-446655440000 failed";
my $uuid_log_res = ConfigServer::Secrets::redact_obj_log(
    $uuid_log_input
);

is(
	$uuid_log_res,
	"Request [REDACTED] failed",
	"[Secrets] Log applies uuid token redaction"
);

note( _note_field( 'Input', "$uuid_log_input" ) );
note( _note_field( 'Result', "$uuid_log_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › Configuration Lines › Public Setting
#   
#   Pass a known public CSF config line through redact_obj_cfg_line().
#   Make sure its setting name and value are not changed.
#   
#   Input:      RECAPTCHA_SITEKEY="public-key"
#   Result:     RECAPTCHA_SITEKEY="public-key"
#   
#   @note       RECAPTCHA_SITEKEY is classified as public.
#               Its value will stay visible even though the
#               setting name contains the word "KEY".
# #

my $public_config_input = q{RECAPTCHA_SITEKEY="public-key"};
my $public_config_res = ConfigServer::Secrets::redact_obj_cfg_line(
    $public_config_input
);

is(
	$public_config_res,
	$public_config_input,
	"[Secrets] Public CSF configuration lines remain visible"
);

note( _note_field( 'Input', "$public_config_input" ) );
note( _note_field( 'Result', "$public_config_res" ) . " \n\n" );

# #
#   Logger.t › Tests › Secrets › Log Messages › Exact Byte Limit
#   
#   Pass one msg using exactly LOG_BYTE_MAXIMUM and another
#   msg one byte more through redact_obj_log().
#   
#   Exact limit msg should complete without a issue.
#   
#   Oversized msg is shortened to remain within the limit. Should
#   end with the truncation marker.
#   
#   Byte limit: 65,536 bytes (64 KB)
#   
#   Input:      65,536 ascii chars
#   Result:     65,536 bytes; no truncation marker
#   
#   Input:      65,537 ascii chars
#   Result:     65,536 bytes; ends with " [TRUNCATED]"
#   
#   @note       Each "A" = one byte, the char and byte counts
#               are the same in this test.
#
#               The truncation marker is included in the final
#               65,536 byte limit
# #

my $bytes_max           = ConfigServer::Secrets::LOG_BYTE_MAXIMUM( );
my $log_exact_res       = ConfigServer::Secrets::redact_obj_log( "A" x $bytes_max );
my $log_over_res        = ConfigServer::Secrets::redact_obj_log( "A" x ( $bytes_max + 1 ) );

my $bytes_exact_found   = length( $log_exact_res );
my $bytes_over_found    = length( $log_over_res );
my $is_exact_truncated  = $log_exact_res =~ / \[TRUNCATED\]\z/ ? 1 : 0;
my $is_over_truncated   = $log_over_res =~ / \[TRUNCATED\]\z/ ? 1 : 0;

ok(
	$bytes_exact_found == $bytes_max &&
	!$is_exact_truncated &&
	$bytes_over_found == $bytes_max &&
	$is_over_truncated,
	"[Secrets] Log output enforces the byte limit at its exact boundary"
);

note( _note_field( 'Maximum bytes', "$bytes_max" ) );
note( _note_field( 'Exact input bytes', "$bytes_max" ) );
note( _note_field( 'Exact output bytes', "$bytes_exact_found" ) );
note( _note_field( 'Exact truncated', "$is_exact_truncated" ) );
note( _note_field( 'Oversized input bytes', $bytes_max + 1 ) );
note( _note_field( 'Oversized output bytes', "$bytes_over_found" ) );
note( _note_field( 'Oversized truncated', "$is_over_truncated" ) . " \n\n" );

# #
#   Show the messages in the output results so we can compare.
#   
#   Since each msg is 64 KB each, grab the first 20 chars of the
#   string, and last 20. This lets us  at least see the TRUNCATED
#   marker. That way we don't flood the terminal.
#   
#   Exact output msg:
#       AAAAAAAAAAAAAAAAAAAA ... AAAAAAAAAAAAAAAAAAAA
#   Oversized output msg:
#       AAAAAAAAAAAAAAAAAAAA ... AAAAAAAA [TRUNCATED]
# #

my $chars_limit = 20;

# #
#   Exact Byte Message
#       64 * 1024 B
# #

my $log_exact_preview = substr( $log_exact_res, 0, $chars_limit ) .
                        " ... " .
                        substr( $log_exact_res, -$chars_limit );

# #
#   Oversized Message
#       64 * 1024 + 1 B
# #

my $log_over_preview = substr( $log_over_res, 0, $chars_limit ) .
                        " ... " .
                        substr( $log_over_res, -$chars_limit );

note( _note_field( 'Exact output message', $log_exact_preview ) );
note( _note_field( 'Oversized output message', $log_over_preview ) );

note( "" );

# #
#   Logger.t › Tests › Messenger › Portable
#   
#   Verify Messenger log records contain only one complete log line.
#   A normal record is accepted, while embedded newlines are rejected.
#   
#   Input:      [TEST] Messenger password=fake-password
#   Result:     [TEST] Messenger password=[REDACTED]     (accepted)
#   
#   Input:      Invalid\nMessenger\nrecord\n
#   Result:     Rejected because it contains multiple lines
# #

my $msngr_portable_record   = ConfigServer::Secrets::redact_obj_log(
                                "[" . TESTS_TAG . "] Messenger password=fake-password"
                            ) . "\n";

my $portable_record_valid   = ConfigServer::Logger::_msngr_is_line_valid(
                                $msngr_portable_record
                            );

my $embedded_newlines_valid = ConfigServer::Logger::_msngr_is_line_valid(
                                "Invalid\nMessenger\nrecord\n"
                            );

ok(
	$portable_record_valid &&
	!$embedded_newlines_valid,
	"[Messenger] Record validation accepts one line and rejects embedded newlines"
);

note(
    _note_field(
        'Result',
        "valid record = " . ( defined( $portable_record_valid ) ? $portable_record_valid : "undef" ) . ", embedded newlines = " . ( defined( $embedded_newlines_valid ) ? $embedded_newlines_valid : "undef" ),
    ) .
    " \n\n"
);

# #
#   Logger.t › Tests › Messenger › Read / Write Log (Windows Only)
#   
#   The tests below requires the test to be ran on a Windows machine.
#   
#   Contains the tests:
#       Messenger › Windows › Write
#       Messenger › Windows › Read
#   
#   @note       Uses temp files within ./tests/var/log.
# #

SKIP:
{
	skip( "[Messenger] File test is only required on Windows \n", 2 ) if $^O ne "MSWin32";

	# #
    #   Logger.t › Tests › Messenger › Windows › Write
	#   
	#   Write a sanitized Messenger record to the local Windows test log.
	#   
	#   Input:      [TEST] Messenger password=[REDACTED]
	#   Result:     Record written successfully
	# #

	unlink( $tests_log_msngr );

	my ( $msngr_written, $msngr_write_err ) =
		ConfigServer::Logger::_log_add(
			$tests_log_msngr,
			$msngr_portable_record,
		);

	ok(
		$msngr_written,
		"[Messenger] Test record written to local log"
	);

	note(
	    _note_field(
	        'Result',
	        "written = " . ( defined( $msngr_written ) ? $msngr_written : "undef" ) . ", error = " . ( defined( $msngr_write_err ) ? $msngr_write_err : "undef" ),
	    ) .
	    " \n\n"
	);

	# #
    #   Logger.t › Tests › Messenger › Windows › Read
	#   
	#   Read the Messenger test log back and verify the complete
	#   sanitized record was saved correctly.
	#   
	#   Input:      [TEST] Messenger password=fake-password
	#   Result:     [TEST] Messenger password=[REDACTED]
	# #

	my $msngr_saved_record = "";
	if ( open( my $MESSENGER_TEST_LOG, "<", $tests_log_msngr ) )
	{
		binmode( $MESSENGER_TEST_LOG, ":raw" );
		local $/;

		$msngr_saved_record = <$MESSENGER_TEST_LOG> // "";

		close( $MESSENGER_TEST_LOG );
	}

	is(
		$msngr_saved_record,
		"[" . TESTS_TAG . "] Messenger password=[REDACTED]\n",
		"[Messenger] Test log contains the sanitized complete record"
	);

	note(
	    _note_field(
	        'Result',
	        ( defined( $msngr_saved_record ) ? $msngr_saved_record : "undef" ),
	    ) .
	    " \n\n"
	);
}

# #
#   Logger.t › Tests › Messenger › Secure Log (Linux Only)
#   
#   The tests below requires the test to be ran on a Linux machine.
#   Tests must be elevated to root since the log has to be chown'ed
#   to a non-root user.
#   
#   @note       Uses temp files within /var/log.
# #

SKIP:
{
    skip(
        "[Messenger] Log tests require Linux platform and root (0:0)",
        10
    ) if $^O eq "MSWin32" || $< != 0;

    # #
    #   Logger.t › Tests › Messenger › User
    #   
    #   Look to see if the device running this test has one of the following
    #   users (in order):
    #       - nobody
    #       - nfsnobody
    #   
    #   The account must be a non-root system account which can be 
    #   used for testing secure Messenger log ownership.
    #   
    #   Input:      nobody
    #   Result:     nobody (UID:GID)
    #   
    #   Input:      nobody unavailable
    #   Result:     Try nfsnobody instead
    #   
    #   @todo       Readd non root user lookup (see @note below)
    #   
    #   @note       Originally, functionality was added to search
    #               the system for the next non root user if the
    #               users 'nobody' and 'nfsnobody' did not exist.
    #   
    #               Removed it until this test file could be created
    #               just to ensure security.
    # #

    my ( $tests_user_msngr, undef, $tests_uid_msngr, $tests_gid_msngr ) = getpwnam( "nobody" );
    if ( !defined $tests_uid_msngr || !defined $tests_gid_msngr || $tests_uid_msngr <= 0 || $tests_gid_msngr <= 0 )
    {
        ( $tests_user_msngr, undef, $tests_uid_msngr, $tests_gid_msngr ) = getpwnam( "nfsnobody" );
    }

    my $tests_user_msngr_valid = defined $tests_user_msngr &&
                                    defined $tests_uid_msngr &&
                                    defined $tests_gid_msngr &&
                                    $tests_uid_msngr > 0 &&
                                    $tests_gid_msngr > 0 &&
                                    $tests_uid_msngr <= ConfigServer::Logger::LOG_OWNER_ID_MAX() &&
                                    $tests_gid_msngr <= ConfigServer::Logger::LOG_OWNER_ID_MAX();

    skip(
        "[Messenger] Log tests require nobody or nfsnobody",
        10
    ) if !$tests_user_msngr_valid;

    pass(
        "[Messenger] Test found non-root user [$tests_user_msngr] ($tests_uid_msngr:$tests_gid_msngr)"
    );

    note(
        _note_field(
            'Result',
            ( defined( $tests_user_msngr ) ? "$tests_user_msngr ($tests_uid_msngr:$tests_gid_msngr)" : "undef" ),
        ) .
        " \n\n"
    );

    # #
    #   Logger.t › Tests › Messenger › Paths
    #   
    #   Create unique test file paths using current process ID so
    #   that multiple test runs do not use the same Messenger log 
    #   files.
    #   
    #   Input:      PID 12345
    #   Result:     /var/log/lfd_messenger_symlink_12345.log
    # #

    my $tests_symlink_msngr = "/var/log/lfd_messenger_symlink_$$.log";
    my $tests_link_msngr    = "/var/log/lfd_messenger_link_$$.log";
    my $tests_msg_msngr     = "Messenger secure log test";
    my $tests_data_msngr    = "$tests_msg_msngr\n";

    note(
        _note_field(
            'Result',
            "symlink    = $tests_symlink_msngr\n" .
            "link       = $tests_link_msngr\n" .
            "message    = $tests_msg_msngr",
        ) .
        " \n\n"
    );

    # #
    #   Logger.t › Tests › Messenger › Cleanup
    #   
    #   Clean up / unlink any files left from an earlier test before
    #   starting.
    # #

    unlink( $tests_log_msngr );
    unlink( $tests_symlink_msngr );
    unlink( $tests_link_msngr );

    # #
    #   Logger.t › Tests › Messenger › Parent Validation
    #   
    #   Verify the Messenger log is only allowed inside a trusted
    #   parent dir.
    #   
    #   Rejects unsafe writable locations.
    #   
    #   Input:      /var/log/lfd_messenger_test.log
    #   Result:     Accepted
    #   
    #   Input:      /tmp/lfd_messenger_test.log
    #   Result:     Rejected
    # #

    my ( $parent_trusted_valid, $parent_trusted_err ) = ConfigServer::Logger::_msngr_path_validate(
        $tests_log_msngr
    );

    ok(
        $parent_trusted_valid,
        "[Messenger] Log accepts trusted /var/log parent"
    );

    note(
        _note_field(
            'Result',
            ( defined( $parent_trusted_valid ) ? $parent_trusted_valid : "undef" ) . ", error = " . ( defined( $parent_trusted_err ) ? $parent_trusted_err : "None" ),
        ) .
        " \n\n"
    );

    # #
    #   Logger.t › Tests › Messenger › Parent Validation › Rejected
    #   
    #   Verify the Messenger log rejects an unsafe writable parent
    #   dir, such as /tmp
    #   
    #   /tmp is usually world writable, meaning other users and
    #   processes can create files or symlinks there. This makes
    #   it unsafe for our Messenger audit log, which can store
    #   security sensitive info.
    #   
    #   Input:      /tmp/lfd_messenger_test.log
    #   Result:     Rejected
    # #

    my ( $parent_invalid, $parent_err ) = ConfigServer::Logger::_msngr_path_validate(
        "/tmp/lfd_messenger_test_$$.log"
    );

    ok(
        !$parent_invalid,
        "[Messenger] Log rejects writable /tmp parent"
    );

    note(
        _note_field(
            'Result',
            ( defined( $parent_invalid ) ? $parent_invalid : "undef" ) . ", error = " . ( defined( $parent_err ) ? $parent_err : "None" ),
        ) .
        " \n\n"
    );

    # #
    #   Logger.t › Tests › Messenger › Prepare
    #   
    #   Create / prepare Messenger audit log with the expected
    #   owner, gid/uid, perms, and a single hard link.
    #   
    #   Input:      /var/log/lfd_messenger_test.log
    #   Result:     Regular file owned by UID:GID with mode 0600
    # #

    my ( $prepared, $prepare_err ) = ConfigServer::Logger::_msngr_log_prepare(
        $tests_log_msngr,
        $tests_uid_msngr,
        $tests_gid_msngr,
    );

    ok( $prepared, "[Messenger] Log can be securely prepared" );

    note(
        _note_field(
            'Result',
            ( defined( $prepared ) ? $prepared : "undef" ) . ", error = " . ( defined( $prepare_err ) ? $prepare_err : "undef" ),
        ) .
        " \n\n"
    );

    # #
    #   Logger.t › Tests › Messenger › Prepare › File Status
    #   
    #   Verify the prepared Messenger log is a regular file, with 
    #   one hard link, the expected uid/gid, and chmod 0600 perms.
    #   
    #   Input:      Prepared Messenger log
    #   Result:     uid = 65534, gid = 65534, mode = 0600, links = 1
    # #

    my @msngr_log_status        = lstat( $tests_log_msngr );
    my $file_hardlinks_required = ConfigServer::Secrets::FILE_HARDLINK_MAX( );
    my $file_mode_mask          = ConfigServer::Logger::FILE_PERMS_MODE_MASK( );
    my $file_mode_required      = ConfigServer::Logger::MESSENGER_LOG_MODE( );

    ok(
        @msngr_log_status &&
        Fcntl::S_ISREG( $msngr_log_status[ 2 ] ) &&
        $msngr_log_status[ 3 ] == $file_hardlinks_required &&
        $msngr_log_status[ 4 ] == $tests_uid_msngr &&
        $msngr_log_status[ 5 ] == $tests_gid_msngr &&
        ( $msngr_log_status[ 2 ] & $file_mode_mask ) == $file_mode_required,
        "[Messenger] Log has correct owner, group, mode, and link count"
    );

    note(
        _note_field(
            'UID',
            @msngr_log_status
                ? $msngr_log_status[ 4 ]
                : "undef",
        ) . "\n" .
        _note_field(
            'GID',
            @msngr_log_status
                ? $msngr_log_status[ 5 ]
                : "undef",
        ) . "\n" .
        _note_field(
            'Mode',
            @msngr_log_status
                ? sprintf( "%04o", $msngr_log_status[ 2 ] & 07777 )
                : "undef",
        ) . "\n" .
        _note_field(
            'Links found',
            @msngr_log_status
                ? $msngr_log_status[ 3 ]
                : "undef",
        ) . "\n" .
        _note_field(
            'Links required',
            "$file_hardlinks_required",
        ) .
        " \n\n"
    );

    # #
    #   Logger.t › Tests › Messenger › Identity
    #   
    #   Root must NOT be allowed to use the non root Messenger append
    #   path.
    # #

    my ( $root_written, $root_err ) = ConfigServer::Logger::_msngr_log_append(
        $tests_log_msngr,
        $tests_uid_msngr,
        $tests_data_msngr,
    );

    ok(
        !$root_written,
        "[Messenger] Append rejects incorrect process identity"
    );

    note(
        _note_field(
            'Result',
            ( defined( $root_written ) ? $root_written : "undef" ) . ", error = " . ( defined( $root_err ) ? $root_err : "undef" ),
        ) .
        " \n\n"
    );

    # #
    #   Logger.t › Tests › Messenger › Child
    #   
    #   Fork a child, change to the Messenger uid/gid, then test
    #   the same append path used after Messenger drops root.
    # #

    my $msngr_child_test = sub
    {
        my ( $record, $expect_success ) = @_;
        my $pid = fork( );
        return 0 if !defined $pid;

        if ( $pid == 0 )
        {
            require POSIX;

            my $gid_res = POSIX::setgid( $tests_gid_msngr );
            POSIX::_exit( 125 ) if !defined $gid_res || $gid_res != 0;

            my $uid_res = POSIX::setuid( $tests_uid_msngr );
            POSIX::_exit( 125 ) if !defined $uid_res || $uid_res != 0;

            my ( $written ) = ConfigServer::Logger::_msngr_log_append(
                $tests_log_msngr,
                $tests_uid_msngr,
                $record,
            );

            my $success = $expect_success ? $written : !$written;

            POSIX::_exit( $success ? 0 : 1 );
        }

        waitpid( $pid, 0 );

        return ( $? >> 8 ) == 0;
    };

    # #
    #   Logger.t › Tests › Messenger › Child › Embedded Newlines
    #   
    #   make sure Messenger user can't append a log containing
    #   embedded newlines that could create multiple log entries.
    #   
    #   Input:      Invalid\nMessenger\nRecord\n
    #   Result:     Rejected
    # #

    my $embedded_newline_rejected = $msngr_child_test->(
        "Invalid\nMessenger\nRecord\n",
        0
    );

    ok(
        $embedded_newline_rejected,
        "[Messenger] Append rejects records containing embedded newlines"
    );

    note(
        _note_field(
            'Result',
            ( defined( $embedded_newline_rejected ) ? $embedded_newline_rejected : "undef" ),
        ) .
        " \n\n"
    );

    # #
    #   Logger.t › Tests › Messenger › Child › logfile()
    #   
    #   Make sure Messenger user can call logfile() after dropping
    #   root privileges and securely write to the Messenger log file.
    #   
    #   Input:      Messenger secure log test
    #   Result:     Log record written successfully
    # #

    my $msngr_logfile_pid = fork( );
    if ( !defined $msngr_logfile_pid )
    {
        ok( 0, "[Messenger] User can securely log through logfile()" );
        note( _note_field( 'Result', "fork failed" ) . " \n\n" );
    }
    elsif ( $msngr_logfile_pid == 0 )
    {
        require POSIX;

        my $gid_res = POSIX::setgid( $tests_gid_msngr );
        POSIX::_exit( 125 ) if !defined $gid_res || $gid_res != 0;

        my $uid_res = POSIX::setuid( $tests_uid_msngr );
        POSIX::_exit( 125 ) if !defined $uid_res || $uid_res != 0;

        my $log_res = ConfigServer::Logger::logfile(
            TESTS_LOG_TARGET_NORMAL,
            TESTS_LOG_STATUS_INFO,
            $tests_msg_msngr
        );

        POSIX::_exit( defined $log_res && $log_res->{written} && $log_res->{normal_written}
            ? 0
            : 1
        );
    }
    else
    {
        waitpid( $msngr_logfile_pid, 0 );

        my $msngr_logfile_written = ( $? >> 8 ) == 0;

        ok(
            $msngr_logfile_written,
            "[Messenger] User can securely log through logfile()"
        );

        note(
            _note_field(
                'Result',
                ( defined( $msngr_logfile_written ) ? $msngr_logfile_written : "undef" ),
            ) .
            " \n\n"
        );
    }

    # #
    #   Logger.t › Tests › Messenger › Written Data
    #   
    #   Read the Messenger log and verify logfile() wrote one
    #   complete and formatted record with log msg, status, and
    #   lfd pid.
    #   
    #   Input:      Messenger secure log test
    #   Result:     [INFO] ... lfd[ 12345 ] ... Messenger secure log test
    # #

    my $msngr_log_data = "";
    if ( open( my $MESSENGER_LOG_TEST, "<", $tests_log_msngr ) )
    {
        flock( $MESSENGER_LOG_TEST, Fcntl::LOCK_SH() );
        local $/;

        $msngr_log_data = <$MESSENGER_LOG_TEST> // "";

        close( $MESSENGER_LOG_TEST );
    }

    my $msngr_log_data_valid    = $msngr_log_data =~ /\Q$tests_msg_msngr\E\n\z/ &&
                                $msngr_log_data =~ /\[info\]/ &&
                                $msngr_log_data =~ /lfd\[\s*\d+\s*\]/;

    ok(
        $msngr_log_data_valid,
        "[Messenger] Logfile() writes complete formatted log record"
    );

    note(
        _note_field(
            'Result',
            ( defined( $msngr_log_data_valid ) ? $msngr_log_data_valid : "undef" ),
        ) .
        " \n\n"
    );

    # #
    #   Logger.t › Tests › Messenger › Symlink
    #   
    #   Verify symlink can't be substituted for the expected
    #   Messenger log file.
    #   
    #   Input:      /var/log/lfd_messenger_symlink.log => another file
    #   Result:     Rejected
    # #

    my $symlink_rejected = 0;
    my $symlink_err;

    if ( sysopen( my $MESSENGER_LINK_TEST, $tests_link_msngr, Fcntl::O_WRONLY() | Fcntl::O_CREAT() | Fcntl::O_EXCL(), 0600 ) )
    {
        close( $MESSENGER_LINK_TEST );

        if ( symlink( $tests_link_msngr, $tests_symlink_msngr ) )
        {
            my ( $symlink_prepared, $prepare_err ) = ConfigServer::Logger::_msngr_log_prepare(
                $tests_symlink_msngr,
                $tests_uid_msngr,
                $tests_gid_msngr,
            );

            $symlink_rejected   = !$symlink_prepared;
            $symlink_err      = $prepare_err;
        }
    }

    ok( $symlink_rejected, "[Messenger] Log rejects symlinks" );

    note(
        _note_field(
            'Result',
            ( defined( $symlink_rejected ) ? $symlink_rejected : "undef" ) . ", error = " . ( defined( $symlink_err ) ? $symlink_err : "undef" ),
        ) .
        " \n\n"
    );

    unlink( $tests_symlink_msngr );
    unlink( $tests_link_msngr );
}

# #
#   Logger.t › Core › Summary (Output)
#   
#   Display final test info and either remove or retain the temp log
#   files created during testing.
#   
#   @note       Test::More() => note() prefixes each diagnostic
#               printed line with a pound symbol (#).
#   
#               Using print() avoids this prefix in the summary.
#               Do not use print() for diagnostic output while tests
#               are running because the output order can change, 
#               screwing up what prints show where.
#   
#   @vars       $tests_i        arrayref    Num tests completed
#                                                       197
# #

my $tests_i = Test::More->builder->current_test;

print STDERR "\n\n";
print STDERR " $C{orangel}Test Summary$C{reset}\n";
print STDERR "   $C{greyl}Tests Run:                    $C{greenl}$tests_i$C{reset}\n";
print STDERR "   $C{greyl}Platform:                     $C{greenl}$^O$C{reset}\n";
print STDERR "   $C{greyl}Process ID:                   $C{greenl}" . $$ . "$C{reset}\n";
print STDERR "   $C{greyl}Keep Test Logs:               " .
    ( TESTS_KEEP_LOGS ? "$C{greenl}Yes" : "$C{redl}No" ) .
    "$C{reset}\n";

print STDERR "\n";
print STDERR " $C{orangel}Log Retention$C{reset}\n";
if ( !TESTS_KEEP_LOGS )
{
    my $normal_deleted      = !-e $tests_log_normal     || unlink( $tests_log_normal );
    my $root_deleted        = !-e $tests_log_root       || unlink( $tests_log_root );
    my $messenger_deleted   = !-e $tests_log_msngr  || unlink( $tests_log_msngr );

    print STDERR "   $C{orangel}Normal$C{greyl} test log:              " .
        ( $normal_deleted ? "$C{redl}Deleted" : "$C{redl}Delete Failed" ) .
        "$C{greyl} [$tests_log_normal]$C{reset}\n";

    print STDERR "   $C{orangel}Root$C{greyl} test log:                " .
        ( $root_deleted ? "$C{redl}Deleted" : "$C{redl}Delete Failed" ) .
        "$C{greyl} [$tests_log_root]$C{reset}\n";

    print STDERR "   $C{orangel}Messenger$C{greyl} test log:           " .
        ( $messenger_deleted ? "$C{redl}Deleted" : "$C{redl}Delete Failed" ) .
        "$C{greyl} [$tests_log_msngr]$C{reset}\n";
}
else
{
    print STDERR "   $C{yellowm}Normal$C{greyl} test log:              $C{greenl}Retained$C{greyl} [$tests_log_normal]$C{reset}\n";
    print STDERR "   $C{yellowm}Root$C{greyl} test log:                $C{greenl}Retained$C{greyl} [$tests_log_root]$C{reset}\n";
    print STDERR "   $C{yellowm}Messenger$C{greyl} test log:           $C{greenl}Retained$C{greyl} [$tests_log_msngr]$C{reset}\n";
}

print STDERR "\n";

done_testing( );
