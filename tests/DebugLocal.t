#!/usr/bin/env perl

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
#           sudo perl -I. ConfigServer/DebugLocal.pm
#   
#       -   Check module for syntax errors:
#           sudo perl -I. -c ConfigServer/DebugLocal.pm
#   
#       -   Module docs:
#           perldoc -T ConfigServer/DebugLocal.pm
#   
#       -   Run test suite:
#           sudo prove -I. -v tests/DebugLocal.t
#   
#   
#   INSTALL:
#       Save this file in the git repo:
#           ./tests/DebugLocal.t
#   
#       Run the USAGE commands below from the root of the git repo.
#   
#   
#   USAGE:
#       -   Windows
#           prove -Isrc -v tests/DebugLocal.t
#   
#       -   Linux
#           sudo prove -I. -v tests/DebugLocal.t
#   
#   
#   MODULES:
#       ConfigServer::DebugLocal()
#           /usr/local/csf/lib/ConfigServer/DebugLocal.pm
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
#           -   The main test process uses DEBUG=2. Separate child
#               processes load the module with DEBUG values 0 - 5.
#               This is required because DEBUG is a compile-time
#               constant inside ConfigServer::DebugLocal.
#   
#           -   These tests support running them on both Linux and
#               Windows, however, some of the tests may be skipped
#               when using windows env. I recommend running the
#               full suite on Linux.
# #

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
use File::Temp  ( );
use Test::More;

# #
#   Define › Constants
#   
#   TESTS_DEBUG_LEVEL
#       Enables detailed STDERR outputs for tests.
#       DEBUG constant accepts value from 0 to 5:
#           0       Normal logs
#           1       Normal debug logs
#           2       Verbose debug logs
#           3       Trace debug logs
#           4       Prolix debug logs
#           5       Specialized logs
#   
#   TESTS_OUT_CHAR_MAX
#       Expected max debug output chars
#   
#   TESTS_ITEM_MAX
#       Expected max num of debug items
#   
#   TESTS_SECRET
#       Registered value used for redaction tests
#   
#   TESTS_TMP_FILE
#       Prefix used for the temp file that stores debug output from a
#       child process. Tests read this file to check the output.
#   
#   TESTS_TMP_DELETE
#       If temp test output files are deleted after being read.
#           (1)     Delete temp files
#           (0)     Keep temp files
# #

use constant
{
    TESTS_DEBUG_LEVEL           => 2,
    TESTS_OUT_CHAR_MAX          => 16 * 1024,
    TESTS_ITEM_MAX              => 256,
    TESTS_SECRET                => 'debuglocal-test-secret-974',
    TESTS_TMP_FILE              => 'csf-debuglocal-',
    TESTS_TMP_DELETE            => 1
};

# #
#   DebugLocal.t › Core › Child Setup
#   
#   Run debug and redact checks in a child process before main
#   tests are started. Save child's output to a test file, then
#   exit without running rest of the test suite.
#   
#   Must be placed before:
#       ConfigServer::Secrets ( )
#       ConfigServer::DebugLocal ( )
#   
#   Test output file:
#       /tmp/csf-debuglocal-level-xxxxx.log
#   
#   For the main test process, use DEBUG=2 before we load
#       ConfigServer::DebugLocal()
# #

BEGIN
{
    if ( $ENV{CONFIGSERVER_DEBUG_TEST_CHILD} )
    {
        if ( defined( $ENV{CONFIGSERVER_DEBUG_TEST_OUTPUT} ) )
        {
            open( STDERR, '>', $ENV{CONFIGSERVER_DEBUG_TEST_OUTPUT} )
                or die "Unable to open child debug output: $!\n";
        }

        unshift( @INC, $ENV{CONFIGSERVER_DEBUG_TEST_ROOT} )
            if defined( $ENV{CONFIGSERVER_DEBUG_TEST_ROOT} );

        require ConfigServer::DebugLocal;
        require ConfigServer::Secrets;

        my $test_secret = $ENV{CONFIGSERVER_DEBUG_TEST_SECRET};

        ConfigServer::Secrets::register_secret(
            'DEBUG_TEST_SECRET',
            $test_secret,
        );

        for my $level ( 0 .. 5 )
        {
            ConfigServer::DebugLocal::log( $level, "DEBUG_LEVEL_OUTPUT_$level" );
        }

        ConfigServer::DebugLocal::log(
            $ENV{DEBUG},
            "DEBUG_SECRET_OUTPUT_$test_secret",
        );

        my $singleize_secret = ConfigServer::DebugLocal::log_singleize(
            [ secret_name => $test_secret ],
        );

        print STDERR
            "DEBUG_GETOPTS_OUTPUT_$singleize_secret\n";

        my $dump_secret = ConfigServer::DebugLocal::dump(
            { secret_name => $test_secret },
        );

        $dump_secret =~ s/\r\n?|\n/ /g;

        print STDERR
            "DEBUG_DUMP_OUTPUT_$dump_secret\n";

        exit( 0 );
    }

    $ENV{DEBUG} = TESTS_DEBUG_LEVEL;
}

# #
#   DebugLocal.t › Core › Manually Load Modules
#   
#   These are commented out because I opted to change the loading 
#   order below, and load local copies first.
# #

# use ConfigServer::Secrets ( );
# use ConfigServer::DebugLocal ( );
# use ConfigServer::Config;

# #
#   DebugLocal.t › Core › Module Search Path
#   
#   Add project root to the front of Perl's module search path before
#   loading each CSF module.
#   
#   This makes sure tests use local copies of the modules instead of
#   matching the modules installed in /usr/local/csf/lib
# #

use lib "$FindBin::Bin/..";
use ConfigServer::Secrets ( );

use lib "$FindBin::Bin/..";
use ConfigServer::DebugLocal ( );

# #
#   Define › Colors
#   
#   @ref            https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
# #

my %C =
(
    reset       => "\e[0m",
    greyl       => "\e[38;5;245m",
    greyd       => "\e[38;5;236m",
    redl        => "\e[38;5;210m",
    fucsial     => "\e[38;5;198m",
    orangel     => "\e[38;5;214m",
    yellowm     => "\e[38;5;226m",
    greenl      => "\e[38;5;120m",
    bluem       => "\e[38;5;33m",
);

# #
#	Declare › Status › Labels
#   
#   Map log statuses to their display string. Specifying a status in
#   DebugLocal::log() is optional, otherwise, defaults to 'info'.
#
#   Status may be referenced by str (name) or id (int):
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
#   DebugLocal.t › Helpers › Note Field
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
#   DebugLocal.t › Helpers › Utf8 Bytes
#   
#   Convert decoded text to utf8 bytes for byte comparisons.
#   
#   @usage      my $bytes = _utf8_bytes( "€" );
#   @params     value           str         Input text or bytes
#   @return                     str         Byte string
# #

sub _utf8_bytes
{
    my ( $value ) = @_;

    return utf8::is_utf8( $value )
        ? Encode::encode( 'UTF-8', $value )
        : $value;
}

# #
#   DebugLocal.t › Helpers › Child Debug Level
#   
#   Load ConfigServer::DebugLocal in a separate process with one assigned
#   DEBUG level, get STDERR and child's exit status.
#   
#   @usage      my ( $exit_status, $stderr ) = _run_debug_level( 5 );
#   @params     level           int         Debug level 0 - 5
#   @return     status          int         Child exit status
#               output          str         Child STDERR
# #

sub _run_debug_level
{
    my ( $level ) = @_;

    # #
    #   @var        $test_root      /home/csf/development
    #               $test_file      /home/csf/development/tests/DebugLocal.t
    # #

    my $test_root = Cwd::abs_path( "$FindBin::Bin/.." );
    $test_root = "$FindBin::Bin/.."
        if !defined( $test_root );

    my $test_file = Cwd::abs_path( $0 );
    $test_file = $0
        if !defined( $test_file );

    # warn( "[DebugLocal.t] \$test_root: $test_root \n" );
    # warn( "[DebugLocal.t] \$test_file: $test_file \n" );

    # #
    #   @vars       $output_handle      GLOB
    #               $output_path        /tmp/csf-debuglocal-level-aKlQpM.log
    # #

    my ( $output_handle, $output_path ) = File::Temp::tempfile(
        TESTS_TMP_FILE . 'level-XXXXXX',
        SUFFIX  => '.log',
        TMPDIR  => 1,
        UNLINK  => 0,
    );

  # warn( "[DebugLocal.t] \$output_path: $output_path \n" );

    close( $output_handle );

    # #
    #   @vars       $ENV{DEBUG}         4
    #   @consts     TESTS_SECRET        debug-test-secret-974
    # #

    local %ENV                              = %ENV;
    $ENV{DEBUG}                             = $level;
    $ENV{CONFIGSERVER_DEBUG_TEST_CHILD}     = 1;
    $ENV{CONFIGSERVER_DEBUG_TEST_ROOT}      = $test_root;
    $ENV{CONFIGSERVER_DEBUG_TEST_OUTPUT}    = $output_path;
    $ENV{CONFIGSERVER_DEBUG_TEST_SECRET}    = TESTS_SECRET;

    # #
    #   @vars       $^X                 /usr/bin/perl
    #               $res                0
    #               $ch_exit_status     0 [exit status (success)]
    # #

    my $res             = system( $^X, $test_file );
    my $ch_exit_status  = $res == -1 ? 255 : $res >> 8;

    # warn( "[DebugLocal.t] \$ch_exit_status: $ch_exit_status \n" );

    # #
    #   @vars       $read_handle        GLOB
    #               $out                [5]BEGIN:104 [info] => DEBUG_LEVEL_OUTPUT_5
    # #

    open( my $read_handle, '<', $output_path )
        or die "Unable to read child debug output: $!\n";

    local $/;
    my $out = <$read_handle> // '';

    close( $read_handle );

    unlink( $output_path )
        if TESTS_TMP_DELETE;

    return ( $ch_exit_status, $out );
}

# #
#   DebugLocal.t › Helpers › Error State
#   
#   Set perl error state vals, run callback, return the values
#   from before and after the callback to compare.
#   
#   $@          Last eval err (EVAL_ERROR)
#   $!          Last file / os err num (ERRNO)
#   $^E         Extended os err (EXTENDED_OS_ERROR)
#   $?          Last child process status (CHILD_ERROR)
#   
#   @ref        https://perldoc.perl.org/perlvar
#   
#   @usage      my ( $err_before, $err_after ) = _err_states( sub { ConfigServer::DebugLocal::log_capture( TESTS_DEBUG_LEVEL, 'error state test' ) } );
#   @params     cb              coderef     Debug cb task to run
#   @return     before          arrayref    Error values before cb
#               after           arrayref    Error values after cb
# #

sub _err_states
{
    my ( $cb ) = @_;

    eval
    {
        die "saved eval error\n";
    };

    $!  = 2;
    $^E = 3;
    $?  = 1024;

    my @before = ( $@, 0 + $!, 0 + $^E, 0 + $? );
    $cb->( );
    my @after = ( $@, 0 + $!, 0 + $^E, 0 + $? );

    return ( \@before, \@after );
}

# #
#   DebugLocal.t › Core › Register Secrets
#   
#   Register one known secret used by log(), log_singleize(), and dump().
#   
#   Secrets must be registered in order for redaction to work
#   properly.
#   
#   @vars       $secret_is_registered       If secret was registered
#                                               (1)     Secret was registered
#                                               (0)     Secret was rejected
# #

my $secret_is_registered;
{
    local $SIG{__WARN__} = sub { };

    $secret_is_registered = eval
    {
        ConfigServer::Secrets::register_secret( 'DEBUG_TEST_SECRET', TESTS_SECRET );
        1;
    };
}

ok( $secret_is_registered, 'Successfully registered secret for debug tests' );

# #
#   DebugLocal.t › Core › Module List
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
#   DebugLocal.t › Tests › Debug Levels › 0 - 5
#   
#   Each child process loads the module using const DEBUG value.
#   Values 0-4 print messages at or below that level and redact secrets.
#   
#   DEBUG 5 prints only level 5 messages without redacting secrets.
#   
#   @vars       $out                [1]Secrets::_secret_prepare_name:1296   [ok] => name:[DEBUG_TEST_SECRET] len:[17] max:[256] status:[ok]
#                                   (w/ log color + formatting)
#               $ch_exit_status     0
#               $stderr             [5]BEGIN:104        [info] => DEBUG_LEVEL_OUTPUT_5
#                                   [5]BEGIN:109        [info] => DEBUG_SECRET_OUTPUT_debug-test-secret-974
#                                   DEBUG_GETOPTS_OUTPUT_secret_name=debug-test-secret-974
#                                   DEBUG_DUMP_OUTPUT_Dump = { 'secret_name' => 'debug-test-secret-974' }; 
# #

for my $debug_level ( 0 .. 5 )
{
    my ( $ch_exit_status, $stderr ) = _run_debug_level( $debug_level );
    my $out                         = ConfigServer::DebugLocal::_ansi_clean( $stderr );

    # warn( "[DebugLocal.t] \$out: $out \n" );

    is( $ch_exit_status, 0, "DEBUG=$debug_level child process exits successfully" );

    note(
        _note_field(
            'Input',
            "DEBUG=$debug_level child process",
        ) . "\n" .
        _note_field( 'Result', "exit status $ch_exit_status" ) .
        " \n\n"
    );

    for my $msg_level ( 0 .. 5 )
    {
        # #
        #   @vars       $is_expected            0, 1
        #               $msg_result             DEBUG_LEVEL_OUTPUT_0
        # #

        my $is_expected     = $debug_level == 5
                                ? $msg_level == 5
                                : $msg_level <= $debug_level;
        my ( $msg_result )  = $out =~ /(DEBUG_LEVEL_OUTPUT_$msg_level)/;

        if ( $is_expected )
        {
            like(
                $out,
                qr/DEBUG_LEVEL_OUTPUT_$msg_level/,
                "DEBUG=$debug_level prints level $msg_level",
            );
        }
        else
        {
            unlike(
                $out,
                qr/DEBUG_LEVEL_OUTPUT_$msg_level/,
                "DEBUG=$debug_level suppresses level $msg_level",
            );
        }

        note(
            _note_field( 'Input', "DEBUG=$debug_level, TEST_LEVEL=$msg_level" ) . "\n" .
            _note_field( 'Result',
                defined( $msg_result )
                    ? $msg_result
                    : "suppressed",
            ) .
            " \n\n"
        );
    }

    # #
    #   @vars       $secret_secret_res      [REDACTED]
    #               $singleize_secret_res   secret_name=[REDACTED]
    #               $dump_secret_res        Dump = { 'secret_name' => '[REDACTED]' };
    #               $out                    [5]BEGIN:117    [info] => DEBUG_LEVEL_OUTPUT_5
    #                                       [5]BEGIN:122    [info] => DEBUG_SECRET_OUTPUT_debug-test-secret-974
    #                                       DEBUG_GETOPTS_OUTPUT_secret_name=debug-test-secret-974
    #                                       DEBUG_DUMP_OUTPUT_Dump = { 'secret_name' => 'debug-test-secret-974' }; 
    # #

    my ( $secret_secret_res )       = $out =~ /DEBUG_SECRET_OUTPUT_([^\r\n]*)/;
    my ( $singleize_secret_res )    = $out =~ /DEBUG_SINGLEIZE_OUTPUT_([^\r\n]*)/;
    my ( $dump_secret_res )         = $out =~ /DEBUG_DUMP_OUTPUT_([^\r\n]*)/;

    # warn( "[DebugLocal.t] \$out: $out \n" );

    # #
    #   DEBUG = 5 (Show Secrets)
    # #

    if ( $debug_level == 5 )
    {
        like(
            $out,
            qr/DEBUG_SECRET_OUTPUT_\Q@{[ TESTS_SECRET ]}\E/,
            'DEBUG=5 log() leaves registered secret unredacted',
        );

        note(
            _note_field( 'Input', TESTS_SECRET ) . "\n" .
            _note_field( 'Expected', TESTS_SECRET ) . "\n" .
            _note_field(
                'Result',
                defined( $secret_secret_res )
                    ? $secret_secret_res
                    : "not found",
            ) .
            " \n\n"
        );

        unlike(
            $out,
            qr/DEBUG_SECRET_OUTPUT_.*REDACTED/,
            'DEBUG=5 log() does not add redaction marker',
        );

        note(
            _note_field( 'Input', TESTS_SECRET ) . "\n" .
            _note_field( 'Expected', 'no redaction marker' ) . "\n" .
            _note_field(
                'Result',
                defined( $secret_secret_res )
                    ? $secret_secret_res
                    : "not found",
            ) .
            " \n\n"
        );

        like(
            $out,
            qr/DEBUG_GETOPTS_OUTPUT_.*\Q@{[ TESTS_SECRET ]}\E/,
            'DEBUG=5 log_singleize() leaves registered secret unredacted',
        );

        note(
            _note_field( 'Input', TESTS_SECRET ) . "\n" .
            _note_field(
                'Expected',
                'secret_name=' . TESTS_SECRET,
            ) . "\n" .
            _note_field(
                'Result',
                defined( $singleize_secret_res )
                    ? $singleize_secret_res
                    : "not found",
            ) .
            " \n\n"
        );

        unlike(
            $out,
            qr/DEBUG_GETOPTS_OUTPUT_.*REDACTED/,
            'DEBUG=5 log_singleize() does not add redaction marker',
        );

        note(
            _note_field( 'Input', TESTS_SECRET ) . "\n" .
            _note_field( 'Expected', 'no redaction marker' ) . "\n" .
            _note_field(
                'Result',
                defined( $singleize_secret_res )
                    ? $singleize_secret_res
                    : "not found",
            ) .
            " \n\n"
        );

        like(
            $out,
            qr/DEBUG_DUMP_OUTPUT_.*\Q@{[ TESTS_SECRET ]}\E/,
            'DEBUG=5 dump() leaves registered secret unredacted',
        );

        note(
            _note_field( 'Input', TESTS_SECRET ) . "\n" .
            _note_field( 'Expected', 'secret remains visible' ) . "\n" .
            _note_field(
                'Result',
                defined( $dump_secret_res )
                    ? $dump_secret_res
                    : "not found",
            ) .
            " \n\n"
        );

        unlike(
            $out,
            qr/DEBUG_DUMP_OUTPUT_.*REDACTED/,
            'DEBUG=5 dump() does not add redaction marker',
        );

        note(
            _note_field( 'Input', TESTS_SECRET ) . "\n" .
            _note_field( 'Expected', 'no redaction marker' ) . "\n" .
            _note_field(
                'Result',
                defined( $dump_secret_res )
                    ? $dump_secret_res
                    : "not found",
            ) .
            " \n\n"
        );
    }

    # #
    #   DEBUG < 5 (Redact Secrets)
    # #

    else
    {
        unlike(
            $out,
            qr/DEBUG_SECRET_OUTPUT_.*\Q@{[ TESTS_SECRET ]}\E/,
            "DEBUG=$debug_level log() hides registered secret",
        );

        note(
            _note_field( 'Input', TESTS_SECRET ) . "\n" .
            _note_field(
                'Expected',
                'Raw secret not leaked in result',
            ) . "\n" .
            _note_field(
                'Result',
                defined( $secret_secret_res )
                    ? $secret_secret_res
                    : "not found",
            ) .
            " \n\n"
        );

        like(
            $out,
            qr/DEBUG_SECRET_OUTPUT_.*REDACTED/,
            "DEBUG=$debug_level log() adds redaction marker",
        );

        note(
            _note_field( 'Input', TESTS_SECRET ) . "\n" .
            _note_field( 'Expected', '[REDACTED]' ) . "\n" .
            _note_field(
                'Result',
                defined( $secret_secret_res )
                    ? $secret_secret_res
                    : "not found",
            ) .
            " \n\n"
        );

        unlike(
            $out,
            qr/DEBUG_GETOPTS_OUTPUT_.*\Q@{[ TESTS_SECRET ]}\E/,
            "DEBUG=$debug_level log_singleize() hides registered secret",
        );

        note(
            _note_field( 'Input', TESTS_SECRET ) . "\n" .
            _note_field(
                'Expected',
                'Raw secret not leaked in result',
            ) . "\n" .
            _note_field(
                'Result',
                defined( $singleize_secret_res )
                    ? $singleize_secret_res
                    : "not found",
            ) .
            " \n\n"
        );

        like(
            $out,
            qr/DEBUG_GETOPTS_OUTPUT_.*REDACTED/,
            "DEBUG=$debug_level log_singleize() adds redaction marker",
        );

        note(
            _note_field( 'Input', TESTS_SECRET ) . "\n" .
            _note_field(
                'Expected',
                'secret_name=[REDACTED]',
            ) . "\n" .
            _note_field(
                'Result',
                defined( $singleize_secret_res )
                    ? $singleize_secret_res
                    : "not found",
            ) .
            " \n\n"
        );

        unlike(
            $out,
            qr/DEBUG_DUMP_OUTPUT_.*\Q@{[ TESTS_SECRET ]}\E/,
            "DEBUG=$debug_level dump() hides registered secret",
        );

        note(
            _note_field( 'Input', TESTS_SECRET ) . "\n" .
            _note_field( 'Dev', $out ) . "\n\n" .
            _note_field(
                'Expected',
                'Raw secret not leaked in result',
            ) . "\n" .
            _note_field(
                'Result',
                defined( $dump_secret_res )
                    ? $dump_secret_res
                    : 'not found',
            ) .
            " \n\n"
        );

        like(
            $out,
            qr/DEBUG_DUMP_OUTPUT_.*REDACTED/,
            "DEBUG=$debug_level dump() adds redaction marker",
        );

        note(
            _note_field( 'Input', TESTS_SECRET ) . "\n" .
            _note_field( 'Expected', 'contains [REDACTED]' ) . "\n" .
            _note_field(
                'Result',
                defined( $dump_secret_res )
                    ? $dump_secret_res
                    : "not found",
            ) .
            " \n\n"
        );
    }
}

# #
#   DebugLocal.t › Tests › Invalid Input
#   
#   All of these should return blank; provided bad/invalid values.
#   
#   @eg         ConfigServer::DebugLocal::log_capture( '$DEBUG_LEVEL', '$STATUS_LABEL', 'msg' )
#               ConfigServer::DebugLocal::log_capture( 1, 'info', 'msg' )
#   
#   @vars       $log_out                empty
# #

my $log_out = ConfigServer::DebugLocal::log_capture(
    undef,
    'bad log',
);

is( $log_out, '', 'Debug level missing' );

note(
    _note_field( 'Input', 'DEBUG=undef, message=bad log' ) . "\n" .
    _note_field( 'Expected', 'empty output' ) . "\n" .
    _note_field(
        'Result',
        $log_out eq '' ? 'empty output' : $log_out,
    ) .
    " \n\n"
);

$log_out = ConfigServer::DebugLocal::log_capture(
    [],
    'bad log',
);

is( $log_out, '', 'Debug level ref ignored' );

note(
    _note_field( 'Input', 'DEBUG=ARRAY ref, message=bad log' ) . "\n" .
    _note_field( 'Expected', 'empty output' ) . "\n" .
    _note_field(
        'Result',
        $log_out eq '' ? 'empty output' : $log_out,
    ) .
    " \n\n"
);

$log_out = ConfigServer::DebugLocal::log_capture(
    'invalid',
    'bad log',
);

is( $log_out, '', 'Debug level invalid is ignored' );

note(
    _note_field( 'Input', 'DEBUG=invalid, message=bad log' ) . "\n" .
    _note_field( 'Expected', 'empty output' ) . "\n" .
    _note_field(
        'Result',
        $log_out eq '' ? 'empty output' : $log_out,
    ) .
    " \n\n"
);

$log_out = ConfigServer::DebugLocal::log_capture(
    TESTS_DEBUG_LEVEL,
);

is( $log_out, '', 'Debug msg missing is ignored' );

note(
    _note_field(
        'Input',
        'DEBUG=' . TESTS_DEBUG_LEVEL . ', message=',
    ) . "\n" .
    _note_field( 'Expected', 'empty output' ) . "\n" .
    _note_field(
        'Result',
        $log_out eq '' ? 'empty output' : $log_out,
    ) .
    " \n\n"
);

$log_out = ConfigServer::DebugLocal::log_capture(
    TESTS_DEBUG_LEVEL + 1,
    'hidden',
);

is( $log_out, '', 'Debug level above DEBUG const is suppressed' );

note(
    _note_field(
        'Input',
        'DEBUG=' . ( TESTS_DEBUG_LEVEL + 1 ) . ', message=hidden',
    ) . "\n" .
    _note_field( 'Expected', 'empty output' ) . "\n" .
    _note_field(
        'Result',
        $log_out eq '' ? 'empty output' : $log_out,
    ) .
    " \n\n"
);

# #
#   DebugLocal.t › Tests › Single Message
#   
#   Capture one debug msg, remove ansi colors. Verify the output
#   has debug level.
#   
#   Defaults to status: 'info'
#   
#   @vars       $msg_single         [2]DebugLocal::log_capture:1964  [info] => Single debug msg
#               $msg_single_note    [2]DebugLocal::log_capture:1964 [info] => Single debug msg\n 
# #

my $msg_single = ConfigServer::DebugLocal::_ansi_clean( ConfigServer::DebugLocal::log_capture( TESTS_DEBUG_LEVEL, 'Single debug message' ) );

# expects "[2] ... [info] ... Single debug message"
like(
    $msg_single,
    qr/\[2\].*\[info\].*Single debug message/s,
    'Single message contains level, default status, and text',
);

# change carriage return / newline into \r \n
my $msg_single_note = defined( $msg_single ) ? $msg_single : "undef";
$msg_single_note    =~ s/\r/\\r/g;
$msg_single_note    =~ s/\n/\\n/g;

note(
    _note_field( 'Input', 'Single debug message' ) . "\n" .
    _note_field(
        'Expected',
        '[2], [info], and single debug message',
    ) . "\n" .
    _note_field( 'Result', $msg_single_note ) .
    " \n\n"
);

# #
#   DebugLocal.t › Tests › Status › Mapping
#   
#   Verify str and int status values change to expected label
#   which is shown in the debug output.
#   
#   @note       These tests are different from the status tests in
#               Logger.t.
#   
#               >   DebugLocal.t checks the status displayed in captured
#                   terminal output after ansi colors are removed.
#   
#               X   Logger.t checks the returned status and plain log
#                   file line, and confirms ansi colors are not
#                   included.
#   
#   @note       No ansi color in output
#   
#   @vars       $status         1
#               $expected       ok
#               $type           Integer
#               $msg            Integer status 1
#               $log            [2]DebugLocal::log_capture:1964  [ok] => Integer status 1
#               $actual         ok
# #

for my $status ( qw( fail ok warn abort info ), 0 .. 4 )
{
    my $expected    = $STATUS_MAP{ $status };
    my $type        = $status =~ /\A[0-9]+\z/ ? 'Integer' : 'String';
    my $msg         = "$type status $status";

    my $log = ConfigServer::DebugLocal::_ansi_clean(
        ConfigServer::DebugLocal::log_capture(
            TESTS_DEBUG_LEVEL,
            $status,
            $msg,
        )
    );

    like(
        $log,
        qr/\[$expected\].*\Q$msg\E/s,
        "$type status '$status' is displayed",
    );

    my ( $actual ) = $log =~ /\[([a-z0-9_-]+)\][^\[\]\r\n]*\Q$msg\E/;

    $actual = "not found"
        if !defined( $actual );

    note(
        _note_field( 'Log', $log ) . "\n" .
        _note_field( 'Status', $status ) . "\n" .
        _note_field( 'Expected', "[$expected] $msg" ) . "\n" .
        _note_field(
            'Result',
            $actual eq "not found" ? $actual : "[$actual] $msg"
        ) .
        " \n\n"
    );
}

# #
#   DebugLocal.t › Tests › Status › Color
#   
#   Verify each status uses expected ansi color.
#   
#   Debug output shows in terminal, therefore, ansi colors are 
#   included in Debug output.
#   
#   @note       These tests are different from the status tests in
#               Logger.t.
#   
#               >   DebugLocal.t verifies that terminal output includes the
#                   correct ansi color for each status.
#   
#               X   Logger.t verifies the status written to a log file
#                   and confirms that the ansi colors are not included.
#   
#   @vars       $status         ok                          (No ansi color)
#               $expected       [fail]                      (Includes ansi color)
#               $log            [2]DebugLocal::log_capture:1964  [fail] => Status color fail
#               $actual         \e[38;5;46m[ok]\e[0m
# #

for my $status ( qw( fail ok warn abort info ) )
{
    my $expected = $STATUS_CLR{ $status } . "[$status]" . $C{reset};

    my $log = ConfigServer::DebugLocal::log_capture(
        TESTS_DEBUG_LEVEL,
        $status,
        "Status color $status",
    );

    like(
        $log,
        qr/\Q$expected\E/,
        "Status '$status' uses expected color",
    );

    my ( $actual ) = $log =~ /(\e\[[0-9;]*m\[\Q$status\E\]\e\[[0-9;]*m)/;

    $actual = "not found"
        if !defined( $actual );

    $expected =~ s/\e/\\e/g;
    $actual   =~ s/\e/\\e/g;

    note(
        _note_field( 'Log', $log ) . "\n" .
        _note_field( 'Status', $status ) . "\n" .
        _note_field( 'Expected', $expected ) . "\n" .
        _note_field( 'Result', $actual ) .
        " \n\n"
    );
}

# #
#   DebugLocal.t › Tests › Grouped Values
#   
#   Tests key/value group prints.
#   
#   @vars       $tests_grouped      grouped [2]DebugLocal::log_capture:1964 [info] => GROUP
#                                   {
#                                       label1:         value1
#                                       label2:         value2
#                                       CONSTANTS:
#                                       {
#                                           CONST_LABEL1:   const_value1
#                                       }
#                                   }
# #

my $tests_grouped = ConfigServer::DebugLocal::_ansi_clean(
    ConfigServer::DebugLocal::log_capture(
        TESTS_DEBUG_LEVEL,
        'info',
        'label1',
        'value1',
        'label2',
        'value2',
        'CONST_LABEL1',
        'const_value1',
    )
);

# #
#   Check if log output contains 'GROUP' label
#   
#   @ex     [2]DebugLocal::log_capture:1964 [info] => GROUP { label1: value1, label2: value2, CONSTANTS: { CONST_LABEL1: const_value1 } }
# #

like( $tests_grouped, qr/GROUP/, 'Grouped: output has GROUP label' );

note(
    _note_field( 'Input', ConfigServer::DebugLocal::log_flatten( $tests_grouped ) ) . "\n" .
    _note_field( 'Expected', 'GROUP' ) . "\n" .
    _note_field(
        'Result',
        $tests_grouped =~ /GROUP/
            ? 'GROUP'
            : 'not found',
    ) .
    " \n\n"
);

like( $tests_grouped, qr/label1:\s+value1/, 'Grouped: output has first pair' );

note(
    _note_field( 'Input', 'label1 => value1' ) . "\n" .
    _note_field( 'Expected', 'label1: value1' ) . "\n" .
    _note_field(
        'Result',
        $tests_grouped =~ /label1:\s+value1/
            ? 'label1: value1'
            : 'not found',
    ) .
    " \n\n"
);

like( $tests_grouped, qr/label2:\s+value2/, 'Grouped: output has second pair' );

note(
    _note_field( 'Input', 'label2 => value2' ) . "\n" .
    _note_field( 'Expected', 'label2: value2' ) . "\n" .
    _note_field(
        'Result',
        $tests_grouped =~ /label2:\s+value2/
            ? 'label2: value2'
            : 'not found',
    ) .
    " \n\n"
);

like( $tests_grouped, qr/CONSTANTS:/, 'Grouped: output has const section' );

note(
    _note_field( 'Input', 'CONST_LABEL1 => const_value1' ) . "\n" .
    _note_field( 'Expected', 'CONSTANTS:' ) . "\n" .
    _note_field(
        'Result',
        $tests_grouped =~ /CONSTANTS:/
            ? 'CONSTANTS:'
            : 'not found',
    ) .
    " \n\n"
);

like(
    $tests_grouped,
    qr/CONST_LABEL1:\s+const_value1/,
    'Grouped: output has const value',
);

note(
    _note_field( 'Input', 'CONST_LABEL1 => const_value1' ) . "\n" .
    _note_field( 'Expected', 'CONST_LABEL1: const_value1' ) . "\n" .
    _note_field(
        'Result',
        $tests_grouped =~ /CONST_LABEL1:\s+const_value1/
            ? 'CONST_LABEL1: const_value1'
            : 'not found',
    ) .
    " \n\n"
);

# #
#   DebugLocal.t › Tests › Singleize
#   
#   Make sure DebugLocal::log() output using grouped key/value is
#   compressed to a single line with commas between fields.
#   
#   Also checks undefined, ref, and empty input.
#   
#   @vars       $singleize_input    GROUP
#                                   {
#                                       label1:             value1
#                                       label2:             value2
#                                       CONSTANTS:
#                                       {
#                                           CONST_LABEL1:   const_value1
#                                       }
#                                   }
#   
#               $singleize_expected GROUP { label1: value1, label2: value2, CONSTANTS: { CONST_LABEL1: const_value1 } }
#               $singleize_out      GROUP { label1: value1, label2: value2, CONSTANTS: { CONST_LABEL1: const_value1 } }
#               $singleize_empty        
# #

my $singleize_input     = "GROUP\r\n" .
                        "{\r\n" .
                        "    label1:       value1\r\n" .
                        "    label2:       value2\r\n" .
                        "    CONSTANTS:\r\n" .
                        "    {\r\n" .
                        "        CONST_LABEL1:       const_value1\r\n" .
                        "    }\r\n" .
                        "}\r\n";

my $singleize_expected  = 'GROUP { label1: value1, label2: value2, ' .
                          'CONSTANTS: { CONST_LABEL1: const_value1 } }';

my $singleize_out       = ConfigServer::DebugLocal::log_flatten( $singleize_input );
my $singleize_empty     = ConfigServer::DebugLocal::log_flatten( "\r\n \n" );

is(
    $singleize_out,
    $singleize_expected,
    'log_flatten() changes grouped output to one line',
);

note(
    _note_field( 'Input', 'Grouped output with line breaks' ) . "\n" .
    _note_field( 'Expected', $singleize_expected ) . "\n" .
    _note_field( 'Result', $singleize_out ) .
    " \n\n"
);

is(
    ConfigServer::DebugLocal::log_flatten( undef ),
    'undef',
    'log_flatten() formats undefined input',
);

note(
    _note_field( 'Input', 'undef' ) . "\n" .
    _note_field( 'Expected', 'undef' ) . "\n" .
    _note_field( 'Result', 'undef' ) .
    " \n\n"
);

is(
    ConfigServer::DebugLocal::log_flatten( [] ),
    'ARRAY',
    'log_flatten() formats ref input',
);

note(
    _note_field( 'Input', 'ARRAY ref' ) . "\n" .
    _note_field( 'Expected', 'ARRAY' ) . "\n" .
    _note_field( 'Result', 'ARRAY' ) .
    " \n\n"
);

is(
    $singleize_empty,
    '',
    'log_flatten() returns empty str for blank input',
);

note(
    _note_field( 'Input', 'blank lines' ) . "\n" .
    _note_field( 'Expected', 'empty output' ) . "\n" .
    _note_field(
        'Result',
        $singleize_empty eq '' ? 'empty output' : $singleize_empty,
    ) .
    " \n\n"
);

# #
#   DebugLocal.t › Tests › Secret Redaction (Single)
#   
#   Make sure a single msg removes a secret and adds the
#   redaction marker
#   
#   @vars       $secret_single      [2]DebugLocal::log_capture:1964    [info] => Secret value: [REDACTED]
#               $secret_single_res  [REDACTED]
# #

my $secret_single = ConfigServer::DebugLocal::_ansi_clean(
    ConfigServer::DebugLocal::log_capture(
        TESTS_DEBUG_LEVEL,
        'Secret value: ' . TESTS_SECRET,
    )
);

my ( $secret_single_res ) = $secret_single =~ /Secret value:\s*([^\r\n]*)/;

unlike(
    $secret_single,
    qr/\Q@{[ TESTS_SECRET ]}\E/,
    'Single message does not contain registered secret',
);

like(
    $secret_single,
    qr/REDACTED/,
    'Single message contains redaction marker',
);

note(
    _note_field( 'Input', TESTS_SECRET ) . "\n" .
    _note_field(
        'Result',
        defined( $secret_single_res )
            ? $secret_single_res
            : "not found",
    ) .
    " \n\n"
);

# #
#   DebugLocal.t › Tests › Secret Redaction (Group)
#   
#   Make sure a grouped value removes secrets and replace secrets 
#   with redaction marker.
#   
#   @vars       $secret_group       secret_group [2]DebugLocal::log_capture:1964 [info] => GROUP
#                                   {
#                                       secret_name: [REDACTED]
#                                   }
#               $secret_group_res   [REDACTED]
# #

my $secret_group = ConfigServer::DebugLocal::_ansi_clean(
    ConfigServer::DebugLocal::log_capture( TESTS_DEBUG_LEVEL, 'secret_name', TESTS_SECRET )
);

my ( $secret_group_res ) = $secret_group =~ /secret_name:\s*([^\r\n]*)/;

unlike(
    $secret_group,
    qr/\Q@{[ TESTS_SECRET ]}\E/,
    'Grouped output does not contain registered secret',
);

like(
    $secret_group,
    qr/REDACTED/,
    'Grouped output contains redaction marker',
);

note(
    _note_field( 'Input', TESTS_SECRET ) . "\n" .
    _note_field(
        'Result',
        defined( $secret_group_res )
            ? $secret_group_res
            : "not found",
    ) .
    " \n\n"
);

# #
#   DebugLocal.t › Tests › Redaction Failure
#   
#   Make sure log output stops when redaction fails, or returns a 
#   ref
# #

{
    no warnings 'redefine';
    local *ConfigServer::Secrets::redact_obj_log = sub
    {
        die "forced redaction failure\n";
    };

    my $redaction_exception_output = ConfigServer::DebugLocal::log_capture(
        TESTS_DEBUG_LEVEL,
        'must not print',
    );

    is(
        $redaction_exception_output,
        '',
        'Single message stops when redaction throws an exception',
    );

    note(
        _note_field( 'Input', 'must not print' ) . "\n" .
        _note_field( 'Redaction', 'forced exception' ) . "\n" .
        _note_field(
            'Result',
            $redaction_exception_output eq ''
                ? "empty haaa $redaction_exception_output"
                : $redaction_exception_output,
        ) .
        " \n\n"
    );
}

{
    no warnings 'redefine';
    local *ConfigServer::Secrets::redact_obj_log = sub
    {
        return [];
    };

    my $redaction_ref_output =
        ConfigServer::DebugLocal::log_capture(
            TESTS_DEBUG_LEVEL,
            'must not print',
        );

    is(
        $redaction_ref_output,
        '',
        'Single message stops when redaction returns a ref',
    );

    note(
        _note_field( 'Input', 'must not print' ) . "\n" .
        _note_field( 'Redaction', 'ARRAY ref' ) . "\n" .
        _note_field(
            'Result',
            $redaction_ref_output eq ''
                ? "empty output"
                : $redaction_ref_output,
        ) .
        " \n\n"
    );
}

# #
#   DebugLocal.t › Tests › Redaction Recursion
#   
#   Make sure outter msg prints while nested log started during
#   redaction does not show.
# #

{
    no warnings 'redefine';
    local *ConfigServer::Secrets::redact_obj_log = sub
    {
        ConfigServer::DebugLocal::log(
            TESTS_DEBUG_LEVEL,
            'nested redaction message',
        );

        return $_[ 0 ];
    };

    my $out = ConfigServer::DebugLocal::_ansi_clean(
        ConfigServer::DebugLocal::log_capture(
            TESTS_DEBUG_LEVEL,
            'outer redaction message',
        )
    );

    like(
        $out,
        qr/outer redaction message/,
        'Outer message prints during recursion test',
    );

    unlike(
        $out,
        qr/nested redaction message/,
        'Nested message is suppressed while redaction is active',
    );

    note(
        _note_field(
            'Outer',
            $out =~ /outer redaction message/
                ? "printed"
                : "not found",
        ) . "\n" .
        _note_field(
            'Nested',
            $out =~ /nested redaction message/
                ? "printed"
                : "suppressed",
        ) .
        " \n\n"
    );
}

# #
#   DebugLocal.t › Tests › Warning Recursion
#   
#   @vars       $warn_recursion         [2]main:1097 [info] => outer warning message
#                                           No clr
#               $control_out            [2]DebugLocal::log_capture:1964 [info] => ABCDE
#                                           With clr
# #

my $warn_recursion = '';
{
    local $SIG{__WARN__} = sub
    {
        $warn_recursion .= join( '', @_ );
        ConfigServer::DebugLocal::log( TESTS_DEBUG_LEVEL, 'nested warning message' );
    };

    ConfigServer::DebugLocal::log( TESTS_DEBUG_LEVEL, 'outer warning message' );
}

$warn_recursion = ConfigServer::DebugLocal::_ansi_clean( $warn_recursion );

like(
    $warn_recursion,
    qr/outer warning message/,
    'Outer warning message prints',
);

unlike(
    $warn_recursion,
    qr/nested warning message/,
    'Nested warning message is suppressed',
);

# #
#   DebugLocal.t › Tests › Terminal Controls
# #

my $control_out = ConfigServer::DebugLocal::log_capture(
    TESTS_DEBUG_LEVEL,
    "A\e]0;unsafe-title\aB\e[2JC\e[8mD\0E",
);

unlike( $control_out, qr/\e\]/, 'OSC terminal control is removed' );
unlike( $control_out, qr/\e\[2J/, 'Non color CSI control is removed' );
unlike( $control_out, qr/\e\[8m/, 'Conceal color code is removed' );
unlike( $control_out, qr/\0/, 'NUL char is removed' );

# #
#   @vars       $safe_color_out         red
#                                           With clr
# #

my $safe_color_out = ConfigServer::DebugLocal::_text_terminal_clean(
    "\e[31mred\e[0m",
    1,
);

like(
    $safe_color_out,
    qr/\e\[31mred\e\[0m/,
    'Safe ansi color code is retained',
);

# #
#   DebugLocal.t › Tests › Item / Output Limits
#   
#   Iterate TESTS_ITEM_MAX (256) + 20 extra to ensure limit is 
#   reached.
#   
#   @vars       $item_limit_out     [2]DebugLocal::log_capture:1964  [info] => GROUP
#                                   {
#                                       name_1:     value_1
#                                       [...]:      [...]
#                                       name_256:   value_256
#                                       [limit reached]
#                                   }
#   
#               $long_out           [2]DebugLocal::log_capture:1964  [info] => AAAAAAAAA [...] AAAAAAAAA
# #

my @many_pairs;
for my $i ( 1 .. TESTS_ITEM_MAX + 20 )
{
    push @many_pairs, "name_$i", "value_$i";
}

my $item_limit_out = ConfigServer::DebugLocal::_ansi_clean(
    ConfigServer::DebugLocal::log_capture(
        TESTS_DEBUG_LEVEL,
        @many_pairs,
    )
);

like(
    $item_limit_out,
    qr/\[limit reached\]/,
    'Grouped output stops at item maximum',
);

my $long_out = ConfigServer::DebugLocal::_ansi_clean(
    ConfigServer::DebugLocal::log_capture(
        TESTS_DEBUG_LEVEL,
        'A' x ( TESTS_OUT_CHAR_MAX * 2 ),
    )
);

like(
    $long_out,
    qr/ \[\.\.\.\] /,
    'Long single message contains truncation marker',
);

# #
#   DebugLocal.t › Tests › Utf8 › Decode
#   
#   Use euro char for test since it is a multiple byte utf8 char,
#   and confirms decoder works.
#   
#   Make sure valid utf8 bytes are decoded without changing their value.
#   Invalid utf8 bytes become the replacement char.
#   
#   @vars       $euro_bytes         €           (3 bytes)
#               $euro_text          €           (1 decoded char)
#               $euro_decoded       1 
# #

my $euro_bytes                      = pack( 'H*', 'e282ac' );
my ( $euro_text, $euro_decoded )    = ConfigServer::DebugLocal::_text_utf8_decode( $euro_bytes );

ok( $euro_decoded, 'Valid utf8 byte string is decoded' );
ok( utf8::is_utf8( $euro_text ), 'Decoded utf8 value has utf8 flag' );
is(
    unpack( 'H*', Encode::encode( 'UTF-8', $euro_text ) ),
    'e282ac',
    'Decoded utf8 value keeps expected bytes',
);

# #
#   @note       "ff" is an invalid utf8 byte. Replace with
#               U+FFFD (�):
#                   ff          = invalid input byte
#                   �           = char                      (plain)
#                   U+FFFD      = char as unicode           (hex)
#                   ef bf bd    = char as 3 utf8 bytes      (hex)
#   
#   @vars       $invalid_text       �
#               $invalid_decoded    1
# #

my ( $invalid_text, $invalid_decoded ) = ConfigServer::DebugLocal::_text_utf8_decode(
    pack( 'H*', 'ff' ),
);

ok( $invalid_decoded, 'Malformed utf8 byte string is handled' );

is(
    unpack( 'H*', Encode::encode( 'UTF-8', $invalid_text ) ),
    'efbfbd',
    'Replacement char encodes to utf8 bytes: ef bf bd',
);

is(
    sprintf( 'U+%04X', ord( $invalid_text ) ),
    'U+FFFD',
    'Replacement char has Unicode value: U+FFFD',
);

# #
#   DebugLocal.t › Tests › Utf8 › Truncate
#   
#   Long utf8 text is shortend without splitting multibyte char,
#   include truncation marker.
#   
#   @vars       $truncate_edge      8188
#               $utf8_long          AAAAAAAAAAAAAAAAAAA
#               $utf8_truncated     AAAAAA [...] AAAAAA
#               $utf8_truncate_ok   1
#               $copy               AAAAAA [...] AAAAAA
#               $euro_bytes         €
#   
#   @const      TESTS_OUT_CHAR_MAX  16 * 1024
# #

my $truncate_edge = int(
    (
        TESTS_OUT_CHAR_MAX - length( ' [...] ' )
    ) / 2
);

my $utf8_long = ( 'A' x ( $truncate_edge - 1 ) ) .
    $euro_bytes .
    ( 'B' x TESTS_OUT_CHAR_MAX );

my $utf8_truncated = ConfigServer::DebugLocal::_text_truncate( $utf8_long );

my $utf8_truncate_ok = eval
{
    my $copy = $utf8_truncated;
    Encode::decode(
        'UTF-8',
        $copy,
        Encode::FB_CROAK(),
    );
    1;
};

ok( $utf8_truncate_ok, 'Truncation does not split a multi-byte utf8 char' );

like( $utf8_truncated, qr/ \[\.\.\.\] /, 'Truncated utf8 contains truncation marker' );

# #
#   DebugLocal.t › Tests › Utf8 › Mixed
#   
#   Make sure text and utf8 bytes can be used together without 
#   changing or encoding either value more than once.
#   
#   Requires $wide_name to be at least 2 utf8 bytes.
#   
#   @vars       $euro_bytes         €
#               $wide_name          Ā       (uses 2 utf8 bytes)
#               $singleize_mixed    Ā=€ 
#               $dump_mixed         Dump = [ 'Ā', '€' ]; 
# #

my $wide_name = chr( 0x0100 );      # Ā (latin)
my $singleize_mixed = _utf8_bytes(
    ConfigServer::DebugLocal::log_singleize(
        [ $wide_name, $euro_bytes ],
    )
);

like(
    unpack( 'H*', $singleize_mixed ),
    qr/c4803de282ac/,       # Ā
    'log_singleize() keeps mixed utf8 values correct',
);

my $dump_mixed = _utf8_bytes(
    ConfigServer::DebugLocal::dump(
        [ $wide_name, $euro_bytes ],
    )
);

unlike(
    unpack( 'H*', $dump_mixed ),
    qr/c3a2c282c2ac/,
    'dump() does not encode utf8 a second time',
);

# #
#   DebugLocal.t › Tests › log_singleize() › Formatting
#   
#   log_singleize() should format options properly, reject empty / bad / 
#   invalid / oversized lists.
# #

is(
    ConfigServer::DebugLocal::log_singleize(
        {
            csf_field_b     => 2,
            csf_field_a     => 1,
        }
    ),
    'csf_field_a=1, csf_field_b=2',
    'log_singleize() sorts hash names alphabetically',
);

is(
    ConfigServer::DebugLocal::log_singleize(
        'colon',
        [ csf_field_b => 2, csf_field_a => 1 ],
    ),
    'csf_field_b:[2] csf_field_a:[1]',
    'log_singleize() preserves array order with colon style',
);

is(
    ConfigServer::DebugLocal::log_singleize( {} ),
    '(none)',
    'log_singleize() reports an empty hash',
);

is(
    ConfigServer::DebugLocal::log_singleize( [] ),
    '(none)',
    'log_singleize() reports an empty array',
);

is(
    ConfigServer::DebugLocal::log_singleize( 'invalid', {} ),
    '(invalid)',
    'log_singleize() rejects invalid style',
);

is(
    ConfigServer::DebugLocal::log_singleize( [ csf_field_a => 1, 'odd' ] ),
    '(invalid)',
    'log_singleize() rejects unmatched array name',
);

# #
#   @vars       $options_over_limit =
#               {
#                   'name_51'   => 'value_51',
#                   'name_32'   => 'value_32',
#                   'name_21'   => 'value_21',
#                   'name_179'  => 'value_179',
#                   'name_45'   => 'value_45',
#               };
#               # max 255
# #

my %options_over_limit = map
{
    ( "name_$_" => "value_$_" )
} 1 .. TESTS_ITEM_MAX + 1;

is(
    ConfigServer::DebugLocal::log_singleize( \%options_over_limit ),
    '(invalid)',
    'log_singleize() rejects too many fields',
);

is(
    ConfigServer::DebugLocal::log_singleize( [ csf_field_a => undef ] ),
    'csf_field_a=undef',
    'log_singleize() formats undefined value',
);

is(
    ConfigServer::DebugLocal::log_singleize( [ csf_field_a => [] ] ),
    'csf_field_a=ARRAY',
    'log_singleize() formats array ref value',
);

is(
    ConfigServer::DebugLocal::log_singleize( [ undef, 'value' ] ),
    '(invalid)',
    'log_singleize() rejects undefined field name',
);

is(
    ConfigServer::DebugLocal::log_singleize( [ [], 'value' ] ),
    '(invalid)',
    'log_singleize() rejects field name ref',
);

# #
#   DebugLocal.t › Tests › log_singleize() › Redaction / Limits
#   
#   Make sure registered secret is redacted.
#   
#   @vars       $singleize_secret_norm      secret_name=[REDACTED]
#               $singleize_secret_res       [REDACTED]
# #

my $singleize_secret_norm = ConfigServer::DebugLocal::log_singleize(
    [ secret_name => TESTS_SECRET ],
);

my ( $singleize_secret_res ) = $singleize_secret_norm =~ /\Asecret_name=([^\r\n]*)\z/;

unlike(
    $singleize_secret_norm,
    qr/\Q@{[ TESTS_SECRET ]}\E/,
    'log_singleize() does not return registered secret',
);

like(
    $singleize_secret_norm,
    qr/REDACTED/,
    'log_singleize() returns redaction marker',
);

note(
    _note_field( 'Input', TESTS_SECRET ) . "\n" .
    _note_field(
        'Result',
        defined( $singleize_secret_res )
            ? $singleize_secret_res
            : "not found",
    ) .
    " \n\n"
);

# #
#   Make sure private uid field is redacted.
#   
#   @vars       $singleize_secret_uid       uid=[REDACTED]
#               $singleize_secret_uid_res   [REDACTED]
# #

my $singleize_secret_uid = ConfigServer::DebugLocal::log_singleize(
    [ uid => 974 ],
);

unlike(
    $singleize_secret_uid,
    qr/uid=974/,
    'log_singleize() redacts private field with unregistered value',
);

like(
    $singleize_secret_uid,
    qr/REDACTED/,
    'log_singleize() marks private field as redacted',
);

my ( $singleize_secret_uid_res ) = $singleize_secret_uid =~ /\Auid=([^\r\n]*)\z/;

note(
    _note_field( 'Input', 'uid=974' ) . "\n" .
    _note_field(
        'Result',
        defined( $singleize_secret_uid_res )
            ? $singleize_secret_uid_res
            : "not found",
    ) .
    " \n\n"
);

# #
#   DebugLocal.t › Tests › log_singleize() › Oversized Field
#   
#   Make sure a field that exceeds the size limit is replaced.
#   
#   When log_singleize() returns too many, it will throw
#   "DEBUG VALUE TOO LARGE" within the output.
# #

is(
    ConfigServer::DebugLocal::log_singleize(
        [ large => 'A' x ( TESTS_OUT_CHAR_MAX + 1 ) ],
    ),
    '[DEBUG VALUE TOO LARGE]',
    'log_singleize() replaces oversized field before redaction',
);

# #
#   DebugLocal.t › Tests › log_singleize() › Complete Output Limit
#   
#   Make sure the complete output stays within the max allowed size.
#   
#   @vars       @singleize_limit_values [
#                                           'name_1',
#                                           'AAAAAAAA',
#                                           '[...]',
#                                           'name_256',
#                                           'AAAAAAAA'
#                                       ];
#   
#               $singleize_limit_out    name_1=AAAAAAAA,
#                                       [...],
#                                       name_37=AAAAAAAA,
#                                       [DEBUG OUTPUT LIMIT REACHED] 
# #

my @singleize_limit_values;
for my $i ( 1 .. TESTS_ITEM_MAX )
{
    push @singleize_limit_values,
        "name_$i",
        'A' x 100;
}

my $singleize_limit_out = ConfigServer::DebugLocal::log_singleize( \@singleize_limit_values );

like(
    $singleize_limit_out,
    qr/\[DEBUG OUTPUT LIMIT REACHED\]/,
    'log_singleize() reports complete output limit',
);

cmp_ok(
    length( $singleize_limit_out ),
    '<=',
    TESTS_OUT_CHAR_MAX,
    'log_singleize() stays within complete output maximum',
);

# #
#   DebugLocal.t › Tests › log_singleize() › Redaction Active
#   
#   Make sure log_singleize() stops when redaction already running.
# #

{
    local $ConfigServer::DebugLocal::debug_redaction_active = 1;

    is(
        ConfigServer::DebugLocal::log_singleize( { csf_field_1 => 1 } ),
        '(redaction active)',
        'log_singleize() stops while redaction is active',
    );
}

# #
#   DebugLocal.t › Tests › log_singleize() › Redaction Failure
#   
#   Make sure log_singleize() reports when redaction fails.
# #

{
    no warnings 'redefine';
    local *ConfigServer::Secrets::redact_obj_log = sub
    {
        die "forced redaction failure\n";
    };

    is(
        ConfigServer::DebugLocal::log_singleize( { csf_field_1 => 1 } ),
        '(redaction failed)',
        'log_singleize() reports redaction failure',
    );
}

# #
#   DebugLocal.t › Tests › dump() › Scalars and Refs
#   
#   dump() should format undef values, nums, text, and scalar refs.
#   
#   @vars       $scalar_value       scalar ref
# #

my $scalar_value = 'scalar ref';

like(
    ConfigServer::DebugLocal::dump( ),
    qr/\ADump = undef;\s*\z/,
    'dump() formats missing value as undefined',
);

like(
    ConfigServer::DebugLocal::dump( undef ),
    qr/\ADump = undef;\s*\z/,
    'dump() formats explicit undefined value',
);

like(
    ConfigServer::DebugLocal::dump( -12.5 ),
    qr/\ADump = -12\.5;\s*\z/,
    'dump() leaves negative decimal unquoted',
);

like(
    ConfigServer::DebugLocal::dump( '01' ),
    qr/\ADump = '01';\s*\z/,
    'dump() quotes number with leading zero',
);

like(
    ConfigServer::DebugLocal::dump( 'plain' ),
    qr/\ADump = 'plain';\s*\z/,
    'dump() formats text scalar',
);

like(
    ConfigServer::DebugLocal::dump( 974 ),
    qr/\ADump = 974;\s*\z/,
    'dump() leaves number unquoted',
);

like(
    ConfigServer::DebugLocal::dump( \$scalar_value ),
    qr/\ADump = \\'scalar ref';\s*\z/,
    'dump() follows scalar ref',
);

# #
#   DebugLocal.t › Tests › dump() › Arrays and Hashes
#   
#   dump() should format empty, populated, and nested arrays and
#   hashes. 
#   
#   Sorts hash names alphabetically.
# #

like(
    ConfigServer::DebugLocal::dump( 'one', 2 ),
    qr/\ADump = \[\s*'one',\s+2\s*\];\s*\z/,
    'dump() formats multiple values as array',
);

like(
    ConfigServer::DebugLocal::dump( [] ),
    qr/\ADump = \[\];\s*\z/,
    'dump() formats empty array',
);

like(
    ConfigServer::DebugLocal::dump( {} ),
    qr/\ADump = \{\};\s*\z/,
    'dump() formats empty hash',
);

like(
    ConfigServer::DebugLocal::dump(
        {
            csf_field_1 => [ 1, 'csf_value_1' ],
        }
    ),
    qr/'csf_field_1'\s*=>\s*\[\s*1,\s+'csf_value_1'\s*\]/,
    'dump() formats nested hash and array',
);

# #
#   @vars       $dump_arr           Dump = [ 'one', 2 ];
#                                       [ ]         = array
#                                       'field_1'   = str
#                                       1           = number
# #

my $dump_arr = ConfigServer::DebugLocal::dump(
    [ 'field_1', 2 ],
);

like( $dump_arr, qr/\ADump = \[\s/, 'dump() opens array' );
like( $dump_arr, qr/'field_1'/, 'dump() includes array string' );
like( $dump_arr, qr/'field_1',\s+2/, 'dump() includes array number' );

# #
#   Add hash fields in reverse order, verify they are returned in
#   alphabetical order.
#   
#   @vars       $dump_hash              Dump = { 'csf_field_1' => 1, 'csf_field_2' => 2 }; 
# #

my $dump_hash = ConfigServer::DebugLocal::dump(
    {
        csf_field_2 => 2,
        csf_field_1 => 1,
    }
);

like(
    $dump_hash,
    qr/'csf_field_1' => 1,\s+'csf_field_2' => 2/,
    'dump() sorts hash names alphabetically',
);

# #
#   DebugLocal.t › Tests › dump() › Objects
#
#   Create test obj, show as object, display all values,
#   and include class name, similar to Data::Dumper.
#   
#   @vars       $arr_bless              CSF::Test=ARRAY()
#                                       = bless( [
#                                           'field_value_2',
#                                           2,
#                                           {
#                                               'enabled' => 1
#                                           }
#                                       ], 'CSF::Test' );
#   
#               $arr_bless_dump         Dump = bless( [ 'field_value_2', 2, { 'enabled' => 1 } ], 'CSF::Test' );
# #

my $arr_bless = bless(
    [
        'field_value_2',
        2,
        {
            enabled => 1,
        },
    ],
    'CSF::Test',
);

my $arr_bless_dump = ConfigServer::DebugLocal::dump( $arr_bless );

like(
    $arr_bless_dump,
    qr/\ADump = bless\(\s+\[/,
    'dump() formats blessed array',
);

like(
    $arr_bless_dump,
    qr/'field_value_2',\s+2/,
    'dump() includes blessed array values',
);

like(
    $arr_bless_dump,
    qr/'enabled'\s*=>\s*1/,
    'dump() includes nested blessed array values',
);

like(
    $arr_bless_dump,
    qr/'CSF::Test'\s+\);\s*\z/,
    'dump() includes blessed array class',
);

# #
#   DebugLocal.t › Tests › dump() › File Handles
#   
#   Create temp file, pass open file handle to dump().
#   
#   dump() identifies file handle, report it is open, and report
#   it belongs to a regular file.
#   
#   @vars       $dump_handle            GLOB(0x55753e3cc780)
#               $dump_path              /tmp/csf-debug-dump-EzBm5_.log
#               $dump_glob              Dump = GLOB {
#                                           'accessed'      => 1791479406,
#                                           'changed'       => 1791479406,
#                                           'device'        => 64768,
#                                           'file_type'     => 'regular file',
#                                           'flags'         => 163842,
#                                           'gid'           => '[REDACTED]',
#                                           'glob_package'  => 'File::Temp',
#                                           'permissions'   => '0600',
#                                           'state'         => 'open',
#                                           'type'          => 'GLOB',
#                                           'uid'           => '[REDACTED]'
#                                       };
# #

my ( $dump_handle, $dump_path ) = File::Temp::tempfile(
    TESTS_TMP_FILE . 'dump-XXXXXX',
    SUFFIX  => '.log',
    TMPDIR  => 1,
    UNLINK  => 1,
);

my $dump_glob = ConfigServer::DebugLocal::dump( $dump_handle );

like(
    $dump_glob,
    qr/\bGLOB\s+\{/,
    'dump() identifies open file handle',
);

like(
    $dump_glob,
    qr/'state'\s*=>\s*'open'/,
    'dump() reports open file handle state',
);

like(
    $dump_glob,
    qr/'file_type'\s*=>\s*'regular file'/,
    'dump() reports regular file type',
);

close( $dump_handle );

# #
#   DebugLocal.t › Tests › dump() › Escapes
#   
#   Hidden / special chars should be changed into readable text:
#       \'          Single quote
#       \\          Backslash
#       \e          Esc char
#       \r          Carriage return
#       \n          Line break
#       \t          Tab
#       \x{0000}    NUL char
#   
#   @vars       $dump_escape            A\'\\\e\r\n\t\x{0000}B
# #

my $dump_escape = ConfigServer::DebugLocal::_text_escape_dump(
    "A'\\\e\r\n\t\0B",
);

like( $dump_escape, qr/\\'/, '_text_escape_dump() esc single quote' );
like( $dump_escape, qr/\\\\/, '_text_escape_dump() esc backslash' );
like( $dump_escape, qr/\\e/, '_text_escape_dump() displays esc char' );
like( $dump_escape, qr/\\r/, '_text_escape_dump() displays carriage return' );
like( $dump_escape, qr/\\n/, '_text_escape_dump() displays line break' );
like( $dump_escape, qr/\\t/, '_text_escape_dump() displays tab' );
like( $dump_escape, qr/\\x\{0000\}/, '_text_escape_dump() displays NUL char' );

# #
#   DebugLocal.t › Tests › dump() › Limits / Cycles
#   
#   Make sure dump() shortens long values, stop cyclic refs, stop at
#   the item limit, and keep output within the max size.
#   
#   @vars       $dump_scalar_long       Dump = 'VALUE_START_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA [...] AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA_VALUE_END';
#               $dump_limit_out         [
#                                           'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA1',
#                                           '[...]',
#                                           'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA255',
#                                           [limit reached]
#                                       ];
#   
#               %large_hash             Generated hash list with max number 256
#                                       {
#                                           'name_159' => 'value_159',
#                                           'name_194' => 'value_194',
#                                           'name_61' => 'value_61',
#                                           'name_133' => 'value_133',
#                                           'name_64' => 'value_64'
#                                       }
# #

my $dump_scalar_long = ConfigServer::DebugLocal::dump(
    'VALUE_START_' . ( 'A' x 1000 ) . '_VALUE_END',
);

like(
    $dump_scalar_long,
    qr/\ADump = 'VALUE_START_/,
    'dump() keeps beginning of long scalar',
);

like(
    $dump_scalar_long,
    qr/ \[\.\.\.\] /,
    'dump() truncates long scalar',
);

like(
    $dump_scalar_long,
    qr/_VALUE_END';\s*\z/,
    'dump() keeps ending of long scalar',
);

my $cycle = [];
push @{$cycle}, $cycle;

like(
    ConfigServer::DebugLocal::dump( $cycle ),
    qr/\.\.\./,
    'dump() stops cyclic value at nesting maximum',
);

my %large_hash = map
{
    ( "name_$_" => "value_$_" )
} 1 .. TESTS_ITEM_MAX + 1;

like(
    ConfigServer::DebugLocal::dump( \%large_hash ),
    qr/\[limit reached\]/,
    'dump() stops large hash at item maximum',
);

my @dump_limit_values = map
{
    'A' x 90 . $_
} 1 .. TESTS_ITEM_MAX;

my $dump_limit_out = ConfigServer::DebugLocal::dump( \@dump_limit_values );

like(
    $dump_limit_out,
    qr/ \[\.\.\.\] /,
    'dump() marks complete output truncation',
);

cmp_ok(
    length( $dump_limit_out ),
    '<=',
    TESTS_OUT_CHAR_MAX,
    'dump() stays within complete output maximum',
);

# #
#   DebugLocal.t › Tests › dump() › Registered Secret
#   
#   Redact TESTS_SECRET because its value is registered as a secret.
#   
#   @vars       $dump_secret        Dump = { 'secret_name' => '[REDACTED]' };
#               $dump_secret_res    [REDACTED]
# #

my $dump_secret             = ConfigServer::DebugLocal::dump( { secret_name => TESTS_SECRET } );
my ( $dump_secret_res )     = $dump_secret =~ /'secret_name'\s*=>\s*'([^']*)'/;

unlike(
    $dump_secret,
    qr/\Q@{[ TESTS_SECRET ]}\E/,
    'dump() does not return registered secret',
);

like(
    $dump_secret,
    qr/REDACTED/,
    'dump() returns redaction marker',
);

note(
    _note_field( 'Input', TESTS_SECRET ) . "\n" .
    _note_field(
        'Result',
        defined( $dump_secret_res )
            ? $dump_secret_res
            : "not found",
    ) .
    " \n\n"
);

# #
#   DebugLocal.t › Tests › dump() › Secret Field
#   
#   Redact 974 because it is stored in the uid field.
#   
#   @vars       $dump_uid       Dump = { 'uid' => '[REDACTED]' };
#               $dump_ui_res    [REDACTED]
# #

my $dump_uid            = ConfigServer::DebugLocal::dump( { uid => 974 } );
my ( $dump_ui_res )     = $dump_uid =~ /'uid'\s*=>\s*'([^']*)'/;

unlike(
    $dump_uid,
    qr/'uid'\s*=>\s*974/,
    'dump() redacts secret field with unregistered value',
);

like(
    $dump_uid,
    qr/REDACTED/,
    'dump() marks secret field as redacted',
);

note(
    _note_field( 'Input', 'uid => 974' ) . "\n" .
    _note_field(
        'Result',
        defined( $dump_ui_res )
            ? $dump_ui_res
            : "not found",
    ) .
    " \n\n"
);

{
    local $ConfigServer::DebugLocal::debug_redaction_active = 1;

    is(
        ConfigServer::DebugLocal::dump( 'plain' ),
        "Dump = '[REDACTION ACTIVE]';\n",
        'dump() stops while redaction is active',
    );
}

{
    no warnings 'redefine';
    local *ConfigServer::Secrets::redact_obj_log = sub
    {
        die "forced redaction failure\n";
    };

    is(
        ConfigServer::DebugLocal::dump( 'plain' ),
        "Dump = '[REDACTION FAILED]';\n",
        'dump() reports redaction failure',
    );
}

# #
#   DebugLocal.t › Tests › Caller Error Values
#   
#   Tests check if the 3 debugging subs preserve perl's error vars
#   without changing them.
#   
#   Each before / after array for test should have:
#       $@      "saved eval error\n"        Last eval err (EVAL_ERROR)
#       $!      3                           Last file / os err num (ERRNO)
#       $^E     3                           Extended OS err (EXTENDED_OS_ERROR)
#       $?      1024                        Last child process wait status (CHILD_ERROR)
#   
#   Both before / after array should return the same result:
#       [ "saved eval error\n", 3, 3, 1024 ]
#   
#   @vars       $log_err_before         arrayref    Err state before log()
#               $log_err_after          arrayref    Err state after log()
#               $singleize_err_before   arrayref    Err state before log_singleize()
#               $singleize_err_after    arrayref    Err state after log_singleize()
#               $dump_err_before        arrayref    Err state before dump()
#               $dump_err_after         arrayref    Err state after dump()
# #

my ( $log_err_before, $log_err_after ) = _err_states(
    sub
    {
        ConfigServer::DebugLocal::log_capture( TESTS_DEBUG_LEVEL, 'error state test' );
    }
);

is_deeply(
    $log_err_after,
    $log_err_before,
    'log() preserves caller error values',
);

my ( $singleize_err_before, $singleize_err_after ) = _err_states(
    sub
    {
        ConfigServer::DebugLocal::log_singleize( { csf_field_1 => 1 } );
    }
);

is_deeply(
    $singleize_err_after,
    $singleize_err_before,
    'log_singleize() preserves caller error values',
);

my ( $dump_err_before, $dump_err_after ) = _err_states(
    sub
    {
        ConfigServer::DebugLocal::dump( { csf_field_1 => 1 } );
    }
);

is_deeply(
    $dump_err_after,
    $dump_err_before,
    'dump() preserves caller error values',
);

# #
#   DebugLocal.t › Core › Summary (Output)
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
print STDERR "   $C{greyl}Tests Run:                    " .
    "$C{greenl}$tests_i$C{reset}\n";
print STDERR "   $C{greyl}Platform:                     " .
    "$C{greenl}$^O$C{reset}\n";
print STDERR "   $C{greyl}Process ID:                   " .
    "$C{greenl}" . $$ . "$C{reset}\n";
print STDERR "   $C{greyl}Main DEBUG Level:             " .
    "$C{greenl}" . TESTS_DEBUG_LEVEL . "$C{reset}\n";
print STDERR "\n";

done_testing( );
