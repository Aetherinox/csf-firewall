#!/usr/bin/perl
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
#   @updated            11.27.2026
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
#   INSTALL:
#       Save this file in the git repo:
#           ./tests/LineFilter.t
#   
#       Run the USAGE commands below from the root of the git repo.
#   
#   
#   USAGE:
#       -   Windows source:
#           set CSF_SOURCE=source
#           prove --color -v tests/LineFilter.t
#   
#       -   Linux source:
#           sudo env CSF_SOURCE=source prove --color -v tests/LineFilter.t
#   
#       -   Linux installed:
#           sudo env CSF_SOURCE=installed prove --color -v tests/LineFilter.t
#   
#   
#   MODULES:
#       ConfigServer::LineFilter()
#           /usr/local/csf/lib/ConfigServer/LineFilter.pm
#   
#   
#   NOTES:
#       Originally, LineFilter was a subroutine within csf.pl and lfd.pl.
#       Migrated it to its own individual module to allow tests and
#       remove duplicate code.
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

# #
#   Declare › Constants
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
#   RUNTIME_ENV
#       Env var used to select which CSF modules are tested:
#           source, src, local      Test modules from the repo ./src dir
#           installed, install      Test modules from /usr/local/csf/lib
#   
#   RUNTIME_MODULE
#       Module path used for file Perl loaded from %INC.
# #

use constant
{
    TESTS_DEBUG_LEVEL   => 0,
    RUNTIME_ENV         => "CSF_SOURCE",
    RUNTIME_MODULE      => "ConfigServer/LineFilter.pm"
};

BEGIN
{
    $ENV{DEBUG} = TESTS_DEBUG_LEVEL
        if !$ENV{CSF_TEST_CHILD};
}

# #
#   LineFilter.t › Modules › List
#   
#   Add project root to the front of Perl's module search path before
#   loading the CSF module.
#   
#   This makes sure tests use local copies of the modules instead of
#   matching the modules installed in /usr/local/csf/lib
# #

use FindBin ( );
# use lib "$FindBin::Bin/../src";
use lib "$FindBin::Bin/..";

use constant TEST_MODULES => qw(
    Cwd
    ConfigServer::LineFilter
);

BEGIN
{
    my $runtime = $ENV{ +RUNTIME_ENV() } // "source";
    if ( $runtime =~ /\A(?:source|src|local)\z/ )
    {
        $runtime = "source";
    }
    elsif ( $runtime =~ /\A(?:installed|install)\z/ )
    {
        $runtime = "installed";
    }
    else
    {
        die "Invalid " . RUNTIME_MODULE() . " runtime [ $runtime ]\n";
    }

    $ENV{ +RUNTIME_ENV() } = $runtime;

    my $module_dir = $runtime eq "installed"
        ? "/usr/local/csf/lib"
        : "$FindBin::Bin/../src";

    die "ConfigServer module directory does not exist [ $module_dir ]\n"
        if !-d "$module_dir/ConfigServer";

    unshift @INC, $module_dir;
}

# #
#   LineFilter.t › Modules › Load
#   
#   Load and verify all required Perl modules.
#   Abort testing if any required module cannot be loaded.
# #

BEGIN
{
    return
        if $ENV{CSF_TEST_CHILD};

    my $test_more_avail = eval
    {
        require Test::More;
        Test::More->import( );
        1;
    };

    my $test_more_err = $@;
    die "Test::More module is required: $test_more_err"
        if !$test_more_avail;

    ok( 1, 'Test::More module is available' );

    my @mod_errs;
    for my $mod ( TEST_MODULES )
    {
        my $mod_file    = $mod;
        $mod_file       =~ s{::}{/}g;
        $mod_file       .= '.pm';

        my $mod_ok = eval
        {
            require $mod_file;
            1;
        };
        my $mod_err = $@;

        if ( $mod_ok )
        {
            pass( "$mod module is available" );
        }
        else
        {
            fail( "$mod module is missing" );
        }

        push @mod_errs, "$mod: $mod_err"
            if !$mod_ok;
    }

    BAIL_OUT( "Required Perl modules for these tests are unavailable:\n" . join( '', @mod_errs ) )
        if @mod_errs;
}

# #
#   LineFilter.t › Core › Manually Load Modules
#   
#   These are commented out because I opted to change the loading 
#   order below, and load local copies first.
# #

# use ConfigServer::Logger ( );
# use ConfigServer::Config;

# #
#   LineFilter.t › Core › Colors
#   
#   @ref            https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
# #

my %C =
(
    end                 => "\e[0m",
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
#   LineFilter.t › Helpers › Note Field
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
#   LineFilter.t › Helpers › Parsed Field
#   
#   Return a parsed field as text for test notes.
#   
#   @params     parsed          hashref     Parsed result
#               field           str         Field name
#   @return     value           str         Field value or undef label
# #

sub _parsed_field
{
    my ( $parsed, $field ) = @_;

    return 'undef'
        if ref( $parsed ) ne 'HASH' or !defined( $parsed->{$field} );

    return "$parsed->{$field}";
}

# #
#   LineFilter.t › Helpers › Run Sub
#   
#   Run callback; get results, err, and warning.
#   
#   @params     cb              coderef     Test callback
#   @return     res             scalar      Callback result
#               err             str         Exception text
#               warn            str         Warning text
# #

sub _runsub
{
    my ( $cb ) = @_;

    my $res;
    my $err = '';
    my $warn = '';

    {
        local $@;
        local $SIG{__WARN__} = sub
        {
            $warn .= $_[0];
        };

        $res = eval
        {
            $cb->( );
        };

        $err = $@;
    }

    return ( $res, $err, $warn );
}

# #
#   LineFilter.t › Core › Module List
#   
#   Print full list of all CSF modules and paths.
#   
#   @vars       $path_loaded        /tmp/csf/tests/../ConfigServer/LineFilter.pm
#               $path_full          /tmp/csf/ConfigServer/LineFilter.pm
#               $module             ConfigServer/LineFilter.pm
# #

print STDERR "\n";
print STDERR "\n";
print STDERR "  ", $C{greyd}, '-' x 140, "\n";

my $runtime             = $ENV{ +RUNTIME_ENV() } // "source";
my $module_path         = $INC{ +RUNTIME_MODULE() };
my $module_path_full    = defined( $module_path )
                            ? Cwd::abs_path( $module_path )
                            : undef;

$module_path_full = $module_path
    if !defined( $module_path_full ) and defined( $module_path );

$module_path_full = "not loaded"
    if !defined( $module_path_full );

diag(
    "$C{fucsial} [Runtime] " .
    "$C{yellowm}Running tests on $C{greenl} [ $runtime ] $C{yellowm} instance$C{end}"
);

diag(
    "$C{fucsial} [Module Path] " .
    "$C{bluem}$module_path_full$C{end}"
);

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
        "$C{bluem}$path_full$C{end}"
    );
}

# #
#   LineFilter.t › Module › API
#   
#   Make sure module has all the subs and constants we need for
#   tests.
# #

for my $sub_name (
    qw(
        parse_advanced_rule
    )
)
{
    my $sub_ref             = ConfigServer::LineFilter->can( $sub_name );
    my $sub_available       = defined( $sub_ref ) ? 'Yes' : 'No';
    my $sub_ref_type        = ref( $sub_ref ) ne '' ? ref( $sub_ref ) : 'None';

    ok( $sub_ref, "ConfigServer::LineFilter provides $sub_name()" );

    note(
        _note_field( 'Package', 'ConfigServer::LineFilter' ) . "\n" .
        _note_field( 'Sub', "$sub_name( )" ) . "\n" .
        _note_field(
            'Available',
            "Expect:    Yes\nActual:    $sub_available",
        ) . "\n" .
        _note_field(
            'Reference',
            "Expect:    CODE\nActual:    $sub_ref_type",
        ) . "\n" .
        " \n\n"
    );
}

for my $constant_name (
    qw(

    )
)
{
    my $const_ref           = ConfigServer::LineFilter->can( $constant_name );
    my $const_available     = defined( $const_ref ) ? 'Yes' : 'No';
    my $const_ref_type      = ref( $const_ref ) ne '' ? ref( $const_ref ) : 'None';

    ok( $const_ref, "ConfigServer::LineFilter provides $constant_name" );

    note(
        _note_field( 'Package', 'ConfigServer::LineFilter' ) . "\n" .
        _note_field( 'Constant', $constant_name ) . "\n" .
        _note_field(
            'Available',
            "Expect:    Yes\nActual:    $const_available",
        ) . "\n" .
        _note_field(
            'Reference',
            "Expect:    CODE\nActual:    $const_ref_type",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   LineFilter.t › Tests › Proper Syntax
#   
#   Valid inbound TCP rule parses the protocol, direction, dest port,
#   and src ipv4 addr
# #

my ( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|in|d=443|s=192.0.2.10",
);

Test::More::is( $err, undef, "valid IP rule has no err" );
Test::More::is( $rule->{protocol}, "-p tcp", "TCP protocol was parsed" );
Test::More::is( $rule->{inout}, "in", "input direction was parsed" );
Test::More::is( $rule->{dport}, "--dport 443", "dest port was parsed" );
Test::More::is( $rule->{sip}, "-s 192.0.2.10", "src IPv4 addr was parsed" );

# #
#   LineFilter.t › Tests › UID owner without Dest IP (index 4)
#   
#   Valid outbound TCP rule parses the UID owner at index 4, without
#   needing a dest IP addr.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|out|d=22||u=974",
);

Test::More::is( $err, undef, "valid UID owner rule has no err" );
Test::More::is( $rule->{uid}, "--uid-owner 974", "UID owner at index 4 was parsed" );
Test::More::is( $rule->{dip}, undef, "UID owner rule has no dest IP" );

# #
#   LineFilter.t › Tests › GID owner (index 4)
#   
#   Valid outbound TCP rule parses GID owner at index 4
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|out|d=22||g=974",
);

Test::More::is( $err, undef, "valid GID owner rule has no err" );
Test::More::is( $rule->{gid}, "--gid-owner 974", "GID owner at index 4 was parsed" );

# #
#   LineFilter.t › Tests › UID owner priority
#   
#   Valid UID owner rule takes priority over invalid dest IP addr,
#   ignores the unused IP field
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|out|d=22|d=not-an-ip|u=974",
);

Test::More::is( $err, undef, "owner rule ignores its unused invalid IP field" );
Test::More::is( $rule->{uid}, "--uid-owner 974", "owner remains selected" );
Test::More::is( $rule->{dip}, undef, "unused invalid dest IP was not selected" );

# #
#   LineFilter.t › Tests › Bad Dest IP
#   
#   Rule with an invalid dest IP addr is rejected, and returns the
#   right error.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|out|d=22|d=not-an-ip",
);

Test::More::is( $rule, undef, "invalid dest IP returns no parsed rule" );
Test::More::is( $err, "dest ip", "invalid dest IP reports its field" );

# #
#   LineFilter.t › Tests › Bad UID
#   
#   Rule with an invalid UID owner is rejected, and the right error
#   is returned.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|out|d=22||u=root;test",
);

Test::More::is( $rule, undef, "invalid UID owner returns no parsed rule" );
Test::More::is( $err, "owner", "invalid UID owner reports its field" );

# #
#   LineFilter.t › Tests › Bad GID
#   
#   Rule with an invalid GID owner is rejected, and returns the right
#   error.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|out|d=22||g=root;test",
);

Test::More::is( $rule, undef, "invalid GID owner returns no parsed rule" );
Test::More::is( $err, "owner", "invalid GID owner reports its field" );

# #
#   LineFilter.t › Tests › Port Out Of Range
#   
#   Rule with an out of range dest port is rejected, and returns the
#   right error.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|in|d=70000|s=192.0.2.10",
);

Test::More::is( $rule, undef, "invalid port returns no parsed rule" );
Test::More::is( $err, "port", "invalid port reports its field" );

# #
#   LineFilter.t › Tests › Invalid Input
#   
#   Undef, empty, and ref inputs rejected, returns correct error for
#   each type.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule( undef );

Test::More::is( $rule, undef, "undef input returns no parsed rule" );
Test::More::is( $err, "rule", "undef input reports the rule field" );

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule( "" );

Test::More::is( $rule, undef, "empty input returns no parsed rule" );
Test::More::is( $err, "rule", "empty input reports the rule field" );

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule( [] );

Test::More::is( $rule, undef, "ref input returns no parsed rule" );
Test::More::is( $err, "rule", "ref input reports the rule field" );

# #
#   LineFilter.t › Tests › Normalize / Uppercase / Line Endings
#   
#   Uppercase rules normalized to lowercase, and remove trailing line
#   endings without errors.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"TCP|IN|D=443|S=192.0.2.10\r\n",
);

Test::More::is( $err, undef, "uppercase rule has no err" );
Test::More::is(
	$rule->{line},
	"tcp|in|d=443|s=192.0.2.10",
	"rule was lowercased and line endings were removed",
);

# #
#   LineFilter.t › Tests › Legacy Colon Separated Format
#   
#   Process legacy colon separated rules, which convert to pipe
#   separated fields, and src ipv4 addr is parsed without errors.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp:in:d=443:s=192.0.2.10",
);

Test::More::is( $err, undef, "colon separated rule has no err" );
Test::More::is(
	$rule->{line},
	"tcp|in|d=443|s=192.0.2.10",
	"colon separated rule was converted to pipe separated fields",
);
Test::More::is( $rule->{sip}, "-s 192.0.2.10", "colon separated src IP was parsed" );

# #
#   LineFilter.t › Tests › Parse UDP
#   
#   Valid outbound UDP rule correctly parses protocol, direction, 
#   dest port, and dest ipv4 without errors.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"udp|out|d=53|d=198.51.100.53",
);

Test::More::is( $err, undef, "valid UDP rule has no err" );
Test::More::is( $rule->{protocol}, "-p udp", "UDP protocol was parsed" );
Test::More::is( $rule->{inout}, "out", "output direction was parsed" );
Test::More::is( $rule->{dport}, "--dport 53", "UDP dest port was parsed" );
Test::More::is(
	$rule->{dip},
	"-d 198.51.100.53",
	"UDP dest IPv4 addr was parsed",
);

# #
#   LineFilter.t › Tests › Parse ICMP
#   
#   Valid inbound ICMP rule parses protocol, converts dest port field
#   to ICMP type without errors.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"icmp|in|d=8|s=192.0.2.10",
);

Test::More::is( $err, undef, "valid ICMP rule has no err" );
Test::More::is( $rule->{protocol}, "-p icmp", "ICMP protocol was parsed" );
Test::More::is( $rule->{dport}, "--icmp-type 8", "ICMP type was parsed" );

# #
#   LineFilter.t › Tests › Parse Multiport
#   
#   Valid TCP multiport rule parses multiple dest ports, generates
#   expected multiport expression.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|in|d=80,443|s=192.0.2.10",
);

Test::More::is( $err, undef, "valid multiport rule has no err" );
Test::More::is(
	$rule->{dport},
	"-m multiport --dport 80,443",
	"dest multiport expression was parsed",
);

# #
#   LineFilter.t › Tests › Parse Src Ports
#   
#   Valid outbound TCP rule parses the src port range and dest ipv4
#   addr without errors.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|out|s=1024:65535|d=198.51.100.20",
);

Test::More::is( $err, undef, "valid src port rule has no err" );
Test::More::is(
	$rule->{sport},
	"--sport 1024:65535",
	"src port range was parsed",
);
Test::More::is(
	$rule->{dip},
	"-d 198.51.100.20",
	"dest IP following a src port was parsed",
);

# #
#   LineFilter.t › Tests › Parse IPv6
#   
#   Valid inbound TCP rule parses src ipv6 addr, identifies the
#   addr family as ipv6 without errors.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|in|d=443|s=2001:db8::10",
);

Test::More::is( $err, undef, "valid ipv6 rule has no err" );
Test::More::is( $rule->{iptype}, 6, "IPv6 addr reports addr family 6" );
Test::More::is( $rule->{sip}, "-s 2001:db8::10", "src ipv6 addr was parsed" );

# #
#   LineFilter.t › Tests › Reject Invalid Src IP
#   
#   Rule which has an invalid src IP is rejected, the right error
#   is returned.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|in|d=443|s=not-an-ip",
);

Test::More::is( $rule, undef, "invalid src IP returns no parsed rule" );
Test::More::is( $err, "src ip", "invalid src IP reports its field" );

# #
#   LineFilter.t › Tests › Reject Empty UID Fields
#   
#   Rule with an empty UID owner field is rejected, correct error is
#   returned.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|out|d=22||u=",
);

Test::More::is( $rule, undef, "empty UID owner returns no parsed rule" );
Test::More::is( $err, "owner", "empty UID owner reports its field" );

# #
#   LineFilter.t › Tests › Reject Empty GID Fields
#   
#   Rule with an empty GID owner field is rejected, correct error is
#   returned.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|out|d=22||g=",
);

Test::More::is( $rule, undef, "empty GID owner returns no parsed rule" );
Test::More::is( $err, "owner", "empty GID owner reports its field" );

# #
#   LineFilter.t › Tests › Owner Validation before IP
#   
#   Owner validation takes priority over IP validation, reports the
#   invalid owner when both fields are invalid.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|out|d=22|d=not-an-ip|u=root;test",
);

Test::More::is( $rule, undef, "rule with invalid IP and owner was rejected" );
Test::More::is(
	$err,
	"owner",
	"invalid owner was reported before the unused invalid IP",
);

# #
#   LineFilter.t › Tests › Parse Independent Rules
#   
#   UID and GID values from previous processed rules are not carried
#   over to the next rule.
# #

( $rule, $err ) = ConfigServer::LineFilter::parse_advanced_rule(
	"tcp|in|d=443|s=192.0.2.10",
);

Test::More::is( $err, undef, "rule after owner tests has no err" );
Test::More::is( $rule->{uid}, undef, "UID state did not leak from an earlier rule" );
Test::More::is( $rule->{gid}, undef, "GID state did not leak from an earlier rule" );

# #
#   LineFilter.t › Core › Summary (Output)
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
print STDERR " $C{orangel}Test Summary$C{end}\n";
print STDERR "   $C{greyl}Tests Run:                    " .
    "$C{greenl}$tests_i$C{end}\n";
print STDERR "   $C{greyl}Platform:                     " .
    "$C{greenl}$^O$C{end}\n";
print STDERR "   $C{greyl}Process ID:                   " .
    "$C{greenl}" . $$ . "$C{end}\n";
print STDERR "   $C{greyl}Instance:                     " .
    "$C{greenl}$runtime$C{end}\n";
print STDERR "   $C{greyl}Instance Path:                " .
    "$C{greenl}$module_path_full$C{end}\n";
print STDERR "   $C{greyl}DEBUG Level:                  " .
    "$C{greenl}" . TESTS_DEBUG_LEVEL . "$C{end}\n";
print STDERR "\n";

Test::More::done_testing( );
