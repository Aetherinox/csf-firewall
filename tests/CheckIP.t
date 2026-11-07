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
#   @updated            11.07.2026
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
#           sudo perl -I. ConfigServer/CheckIP.pm
#   
#       -   Check module for syntax errors:
#           sudo perl -I. -c ConfigServer/CheckIP.pm
#   
#       -   Run test suite:
#           sudo prove -I. -v tests/CheckIP.t
#   
#   
#   INSTALL:
#       Save this file in the git repo:
#           ./tests/CheckIP.t
#   
#       Run the USAGE commands below from the root of the git repo.
#   
#   
#   USAGE:
#       -   Windows
#           prove -Isrc -v tests/CheckIP.t
#   
#       -   Linux
#           sudo prove -I. -v tests/CheckIP.t
#   
#   
#   MODULES:
#       ConfigServer::CheckIP()
#           /usr/local/csf/lib/ConfigServer/CheckIP.pm
#   
#   
#   NOTES:
#       Tests support Windows and Linux, with a few notes:
#           -   Tests load local perl modules first. If unavailable,
#               load installed copies from /usr/local/csf/lib.
#   
#           -   Run the complete suite on Linux before release because
#               the module uses the Linux CSF configuration.
# #

# #
#   Declare › Use
# #

use strict;
use warnings;

# #
#   CheckIP.t › Modules › List
# #

use constant TEST_MODULES => qw(
    Cwd
    FindBin
    Math::BigInt
    Net::IP
);

# #
#   CheckIP.t › Modules › Load
# #

BEGIN
{
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
#   Declare › Constants
#   
#   TESTS_NETIP_BUGFAIL
#       Fail when installed Net::IP contains the zero address bug.
#           0   Report bug without failing
#           1   Fail test when bug is present
# #

use constant
{
    TESTS_NETIP_BUGFAIL => 0
};

# #
#   CheckIP.t › Core › Manually Load Modules
#   
#   These are commented out because I opted to change the loading 
#   order below, and load local copies first.
# #

# use ConfigServer::Secrets ( );
# use ConfigServer::CheckIP ( );
# use ConfigServer::Config;

# #
#   CheckIP.t › Modules › Search Path
#   
#   Add project root to the front of Perl's module search path before
#   loading the CSF module.
#   
#   This makes sure tests use local copies of the modules instead of
#   matching the modules installed in /usr/local/csf/lib
# #

use lib "$FindBin::Bin/..";
use ConfigServer::CheckIP ( );

# #
#   Declare › Colors
#   
#   @ref        https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
# #

my %C =
(
    reset       => "\e[0m",
    greyl       => "\e[38;5;245m",
    greyd       => "\e[38;5;236m",
    fucsial     => "\e[38;5;198m",
    orangel     => "\e[38;5;214m",
    yellowm     => "\e[38;5;226m",
    greenl      => "\e[38;5;120m",
    bluem       => "\e[38;5;33m",
);

# #
#   CheckIP.t › Helpers › Note Field
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

    my $prefix  = sprintf( '         %-12s', "$name:" );
    my $indent  = ' ' x length( $prefix );

    $value      =~ s/\n/\n$indent/g;

    return $prefix . $value;
}

# #
#   CheckIP.t › Helpers › Parsed Field
#   
#   Return a parsed field as text for test notes.
#   
#   @params     parsed          hashref     Parsed IP result
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
#   CheckIP.t › Helpers › Run Sub
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
#   CheckIP.t › Core › Module List
#   
#   Print full list of all CSF modules and paths.
#   
#   @vars       $path_loaded        /tmp/csf/tests/../ConfigServer/CheckIP.pm
#               $path_full          /tmp/csf/ConfigServer/CheckIP.pm
#               $module             ConfigServer/CheckIP.pm
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
#   CheckIP.t › Module › API
#   
#   Make sure module has all the subs and constants we need for
#   tests.
# #

for my $sub_name (
    qw(
        addr_bin_to_ip
        addr_hex_to_ip
        addr_int_to_ip
        addr_parse
        addr_iptype
        addr_get_embedded_v4
        _is_addr_loopback
        _checkip_validate
        checkip
        cccheckip
    )
)
{
    my $sub_ref             = ConfigServer::CheckIP->can( $sub_name );
    my $sub_available       = defined( $sub_ref ) ? 'Yes' : 'No';
    my $sub_ref_type        = ref( $sub_ref ) ne '' ? ref( $sub_ref ) : 'None';

    ok( $sub_ref, "ConfigServer::CheckIP provides $sub_name()" );

    note(
        _note_field( 'Package', 'ConfigServer::CheckIP' ) . "\n" .
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
        IP_LENGTH_MAX
        IPV4_BITS
        IPV6_BITS
        IPV4_FAMILY
        IPV6_FAMILY
    )
)
{
    my $const_ref           = ConfigServer::CheckIP->can( $constant_name );
    my $const_available     = defined( $const_ref ) ? 'Yes' : 'No';
    my $const_ref_type      = ref( $const_ref ) ne '' ? ref( $const_ref ) : 'None';

    ok( $const_ref, "ConfigServer::CheckIP provides $constant_name" );

    note(
        _note_field( 'Package', 'ConfigServer::CheckIP' ) . "\n" .
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
#   CheckIP.t › Module › Constants
#   
#   Pull constants from ConfigServer/CheckIP.pm module.
# #

my $ip_length_max   = ConfigServer::CheckIP::IP_LENGTH_MAX( );
my $ipv4_bits       = ConfigServer::CheckIP::IPV4_BITS( );
my $ipv6_bits       = ConfigServer::CheckIP::IPV6_BITS( );
my $ipv4_family     = ConfigServer::CheckIP::IPV4_FAMILY( );
my $ipv6_family     = ConfigServer::CheckIP::IPV6_FAMILY( );

# #
#   CheckIP.t › Tests › addr_iptype()
#   
#   Check every v4 and v6 type used by addr_iptype().
#   
#   Test binary addr, and test both 'family' options.
#       1.  Specify 'family' as 2nd arg when calling:
#               addr_iptype( $binip, $family )
#       2.  Don't specify 'family', let sub auto-detect using
#           Ip's binary lenth
#   
#   Full list of types listed in CheckIP.pm module as:
#       iptype_ipv4_ranges
#       iptype_ipv6_ranges
# #

# #
#   $label, $ip, $family, $type_expect
# #

my @list_addr_iptype =
(
    [ 'IPv4 private zero',          '0.0.0.1',                  $ipv4_family,       'PRIVATE' ],
    [ 'IPv4 private',               '10.0.0.1',                 $ipv4_family,       'PRIVATE' ],
    [ 'IPv4 shared',                '100.64.0.1',               $ipv4_family,       'SHARED' ],
    [ 'IPv4 loopback',              '127.0.0.1',                $ipv4_family,       'LOOPBACK' ],
    [ 'IPv4 link-local',            '169.254.1.1',              $ipv4_family,       'LINK-LOCAL' ],
    [ 'IPv4 private 172',           '172.16.0.1',               $ipv4_family,       'PRIVATE' ],
    [ 'IPv4 reserved 192',          '192.0.0.1',                $ipv4_family,       'RESERVED' ],
    [ 'IPv4 test network one',      '192.0.2.1',                $ipv4_family,       'TEST-NET' ],
    [ 'IPv4 6to4 relay',            '192.88.99.1',              $ipv4_family,       '6TO4-RELAY' ],
    [ 'IPv4 private 192',           '192.168.1.1',              $ipv4_family,       'PRIVATE' ],
    [ 'IPv4 benchmark',             '198.18.0.1',               $ipv4_family,       'RESERVED' ],
    [ 'IPv4 test network two',      '198.51.100.1',             $ipv4_family,       'TEST-NET' ],
    [ 'IPv4 test network three',    '203.0.113.1',              $ipv4_family,       'TEST-NET' ],
    [ 'IPv4 multicast',             '224.0.0.1',                $ipv4_family,       'MULTICAST' ],
    [ 'IPv4 reserved 240',          '240.0.0.1',                $ipv4_family,       'RESERVED' ],
    [ 'IPv4 broadcast',             '255.255.255.255',          $ipv4_family,       'BROADCAST' ],
    [ 'IPv4 public',                '8.8.8.8',                  $ipv4_family,       'PUBLIC' ],

    [ 'IPv6 unspecified',           '::',                       $ipv6_family,       'UNSPECIFIED' ],
    [ 'IPv6 loopback',              '::1',                      $ipv6_family,       'LOOPBACK' ],
    [ 'IPv6 mapped IPv4',           '::ffff:192.0.2.1',         $ipv6_family,       'IPV4MAP' ],
    [ 'IPv6 discard',               '100::1',                   $ipv6_family,       'DISCARD' ],
    [ 'IPv6 reserved',              '4000::1',                  $ipv6_family,       'RESERVED' ],
    [ 'IPv6 global unicast',        '2606:4700:4700::1111',     $ipv6_family,       'GLOBAL-UNICAST' ],
    [ 'IPv6 Teredo',                '2001::1',                  $ipv6_family,       'TEREDO' ],
    [ 'IPv6 benchmark',             '2001:2::1',                $ipv6_family,       'BMWG' ],
    [ 'IPv6 documentation',         '2001:db8::1',              $ipv6_family,       'DOCUMENTATION' ],
    [ 'IPv6 ORCHID',                '2001:10::1',               $ipv6_family,       'ORCHID' ],
    [ 'IPv6 6to4',                  '2002::1',                  $ipv6_family,       '6TO4' ],
    [ 'IPv6 unique-local',          'fc00::1',                  $ipv6_family,       'UNIQUE-LOCAL-UNICAST' ],
    [ 'IPv6 link-local',            'fe80::1',                  $ipv6_family,       'LINK-LOCAL-UNICAST' ],
    [ 'IPv6 multicast',             'ff02::1',                  $ipv6_family,       'MULTICAST' ],
);

for my $test ( @list_addr_iptype )
{
    my ( $label, $ip, $family, $type_expect ) = @{$test};

    my $netip               = Net::IP->new( $ip, $family );
    my $binip               = defined( $netip ) ? $netip->binip( ) : undef;
    my $type_with_family    = ConfigServer::CheckIP::addr_iptype( $binip, $family );
    my $type_detect_family  = ConfigServer::CheckIP::addr_iptype( $binip );
    my $netip_state         = defined( $netip ) ? 'Defined' : 'Undefined';
    my $type_family_text    = defined( $type_with_family ) ? $type_with_family : 'undef';
    my $type_detect_text    = defined( $type_detect_family ) ? $type_detect_family : 'undef';

    ok( defined( $netip ), "$label: Net::IP creates binary addr" );

    is(
        $type_with_family,
        $type_expect,
        "$label: addr_iptype() with supplied family expects '$type_expect'",
    );

    is(
        $type_detect_family,
        $type_expect,
        "$label: addr_iptype() with detected family expects '$type_expect'",
    );

    note(
        _note_field( 'Sub', 'addr_iptype( )' ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field( 'Family', $family ) . "\n" .
        _note_field(
            'Net::IP',
            "Expect:    Defined\nActual:    $netip_state",
        ) . "\n" .
        _note_field(
            'IP Type',
            "Expect:    $type_expect\n" .
            "Provided:  $type_family_text\n" .
            "Detected:  $type_detect_text",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   $label, $binip, $family
# #

my @list_addr_iptype_invalid =
(
    [ 'Undefined binary',       undef,                              undef ],
    [ 'Binary arrayref',        [],                                 undef ],
    [ 'Short IPv4 binary',      '0' x ( $ipv4_bits - 1 ),           undef ],
    [ 'Long IPv4 binary',       '0' x ( $ipv4_bits + 1 ),           undef ],
    [ 'Invalid binary char',    ( '0' x ( $ipv4_bits - 1 ) ) . 'x', undef ],
    [ 'Invalid family',         '0' x $ipv4_bits,                   5 ],
    [ 'Wrong supplied family',  '0' x $ipv4_bits,                   $ipv6_family ],
    [ 'Family arrayref',        '0' x $ipv4_bits,                   [] ],
);

for my $test ( @list_addr_iptype_invalid )
{
    my ( $label, $binip, $family ) = @{$test};

    my $type_actual         = ConfigServer::CheckIP::addr_iptype( $binip, $family );
    my $type_actual_text    = defined( $type_actual ) ? $type_actual : 'undef';
    my $binip_text          = !defined( $binip )
                                ? 'undef'
                                : ref( $binip )
                                    ? ref( $binip )
                                    : $binip;
    my $family_text         = !defined( $family )
                                ? 'Not supplied'
                                : ref( $family )
                                    ? ref( $family )
                                    : $family;

    is( $type_actual, undef, "$label: addr_iptype() expects undef" );

    note(
        _note_field( 'Sub', 'addr_iptype( )' ) . "\n" .
        _note_field( 'Test', $label ) . "\n" .
        _note_field( 'Binary IP', $binip_text ) . "\n" .
        _note_field( 'Family', $family_text ) . "\n" .
        _note_field(
            'IP Type',
            "Expect:    undef\nActual:    $type_actual_text",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_bin_to_ip()
#   
#   Convert 32 or 128 bit binary addr to normal IP notation.
#   
#   Detect IP family (4 or 6) from the binary length unless 
#   family is manually supplied.
# #

my $bin_ipv4_zero       = '0' x $ipv4_bits;
my $bin_ipv4_one        = ( '0' x ( $ipv4_bits - 1 ) ) . '1';
my $bin_ipv4_public     = '00001000000010000000100000001000';
my $bin_ipv4_private    = '00001010000000000000000000000001';
my $bin_ipv4_loopback   = '01111111000000000000000000000001';
my $bin_ipv4_test       = '11000000000000000000001000000001';
my $bin_ipv4_max        = '1' x $ipv4_bits;
my $bin_ipv6_zero       = '0' x $ipv6_bits;
my $bin_ipv6_one        = ( '0' x ( $ipv6_bits - 1 ) ) . '1';
my $bin_ipv6_doc        = '00100000000000010000110110111000' .
                          ( '0' x 95 ) . '1';
my $bin_ipv6_mapped     = ( '0' x 80 ) . ( '1' x 16 ) . $bin_ipv4_test;
my $bin_ipv6_max        = '1' x $ipv6_bits;

# #
#   $label, $binip, $family, $ip_expect
# #

my @list_bin_to_ip =
(
    [ 'IPv4 zero',              $bin_ipv4_zero,             undef,          '0.0.0.0' ],
    [ 'IPv4 one',               $bin_ipv4_one,              undef,          '0.0.0.1' ],
    [ 'IPv4 public',            $bin_ipv4_public,           undef,          '8.8.8.8' ],
    [ 'IPv4 private',           $bin_ipv4_private,          undef,          '10.0.0.1' ],
    [ 'IPv4 loopback',          $bin_ipv4_loopback,         undef,          '127.0.0.1' ],
    [ 'IPv4 test network',      $bin_ipv4_test,             undef,          '192.0.2.1' ],
    [ 'IPv4 maximum',           $bin_ipv4_max,              undef,          '255.255.255.255' ],
    [ 'IPv4 supplied family',   $bin_ipv4_public,           $ipv4_family,   '8.8.8.8' ],
    [ 'IPv6 zero',              $bin_ipv6_zero,             undef,          '::' ],
    [ 'IPv6 one',               $bin_ipv6_one,              undef,          '::1' ],
    [ 'IPv6 documentation',     $bin_ipv6_doc,              undef,          '2001:db8::1' ],
    [ 'IPv6 mapped IPv4',       $bin_ipv6_mapped,           undef,          '::ffff:c000:201' ],
    [
        'IPv6 maximum',
        $bin_ipv6_max,
        $ipv6_family,
        'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
    ],
    [ 'Wrong IPv6 family',      $bin_ipv4_test,             $ipv6_family,   undef ],
    [ 'Wrong IPv4 family',      $bin_ipv6_doc,              $ipv4_family,   undef ],
    [ 'Undefined binary',       undef,                      undef,          undef ],
    [ 'Binary arrayref',        [],                         undef,          undef ],
    [ 'Empty binary',           '',                         undef,          undef ],
    [ 'Short binary',           '0' x ( $ipv4_bits - 1 ),   undef,          undef ],
    [ 'Long binary',            '0' x ( $ipv6_bits + 1 ),   undef,          undef ],
    [ 'Binary prefix',          '0b' . $bin_ipv4_test,      undef,          undef ],
    [ 'Invalid binary char',    ( '0' x ( $ipv4_bits - 1 ) ) . '2', undef,  undef ],
    [ 'Invalid family',         $bin_ipv4_test,             5,              undef ],
    [ 'Family arrayref',        $bin_ipv4_test,             [],             undef ],
);

for my $test ( @list_bin_to_ip )
{
    my ( $label, $binip, $family, $ip_expect ) = @{$test};

    my $ip_actual = defined( $family )
        ? ConfigServer::CheckIP::addr_bin_to_ip( $binip, $family )
        : ConfigServer::CheckIP::addr_bin_to_ip( $binip );

    my $binip_text = !defined( $binip )
        ? 'undef'
        : ref( $binip )
            ? ref( $binip )
            : length( $binip ) > 64
                ? substr( $binip, 0, 22 ) . '...' . substr( $binip, -22 )
                : $binip eq ''
                    ? '<empty>'
                    : $binip;

    my $family_text = !defined( $family )
        ? 'Auto'
        : ref( $family )
            ? ref( $family )
            : $family;

    my $ip_expect_text  = defined( $ip_expect ) ? $ip_expect : 'undef';
    my $ip_actual_text  = defined( $ip_actual ) ? $ip_actual : 'undef';

    is( $ip_actual, $ip_expect, "$label: addr_bin_to_ip() expects '$ip_expect_text'" );

    note(
        _note_field( 'Sub', 'addr_bin_to_ip( )' ) . "\n" .
        _note_field( 'Test', $label ) . "\n" .
        _note_field( 'Binary IP', $binip_text ) . "\n" .
        _note_field( 'Family', $family_text ) . "\n" .
        _note_field(
            'Converted IP',
            "Expect:    $ip_expect_text\nActual:    $ip_actual_text",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_hex_to_ip()
#   
#   Convert 8 or 32 character hexadecimal addr to normal IP notation.
#   
#   Detect IP family (4 or 6) from the hexadecimal length unless 
#   family is manually supplied.
# #

# #
#   $label, $hexip, $family, $ip_expect
# #

my @list_hex_to_ip =
(
    [ 'IPv4 zero',              '00000000',                             undef,          '0.0.0.0' ],
    [ 'IPv4 one',               '00000001',                             undef,          '0.0.0.1' ],
    [ 'IPv4 public',            '08080808',                             undef,          '8.8.8.8' ],
    [ 'IPv4 loopback',          '7f000001',                             undef,          '127.0.0.1' ],
    [ 'IPv4 test network',      'c0000201',                             undef,          '192.0.2.1' ],
    [ 'IPv4 uppercase',         'C0000201',                             undef,          '192.0.2.1' ],
    [ 'IPv4 maximum',           'ffffffff',                             undef,          '255.255.255.255' ],
    [ 'IPv4 supplied family',   '08080808',                             $ipv4_family,   '8.8.8.8' ],
    [ 'IPv6 zero',              '0' x ( $ipv6_bits / 4 ),               undef,          '::' ],
    [ 'IPv6 one',               ( '0' x 31 ) . '1',                     undef,          '::1' ],
    [ 'IPv6 documentation',     '20010db8000000000000000000000001',     undef,          '2001:db8::1' ],
    [ 'IPv6 uppercase',         '20010DB8000000000000000000000001',     undef,          '2001:db8::1' ],
    [ 'IPv6 mapped IPv4',       '00000000000000000000ffffc0000201',     undef,          '::ffff:c000:201' ],
    [ 'IPv6 maximum',           'f' x ( $ipv6_bits / 4 ),               $ipv6_family,   'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff' ],
    [ 'Wrong IPv6 family',      'c0000201',                             $ipv6_family,   undef ],
    [ 'Wrong IPv4 family',      '20010db8000000000000000000000001',     $ipv4_family,   undef ],
    [ 'Undefined hexadecimal',  undef,                                  undef,          undef ],
    [ 'Hexadecimal arrayref',   [],                                     undef,          undef ],
    [ 'Empty hexadecimal',      '',                                     undef,          undef ],
    [ 'Hexadecimal prefix',     '0xc0000201',                           undef,          undef ],
    [ 'Short hexadecimal',      'c000020',                              undef,          undef ],
    [ 'Long hexadecimal',       'c00002010',                            undef,          undef ],
    [ 'Invalid hexadecimal',    'c000020g',                             undef,          undef ],
    [ 'Invalid family',         'c0000201',                             5,              undef ],
    [ 'Family arrayref',        'c0000201',                             [],             undef ],
);

for my $test ( @list_hex_to_ip )
{
    my ( $label, $hexip, $family, $ip_expect ) = @{$test};

    my $ip_actual = defined( $family )
        ? ConfigServer::CheckIP::addr_hex_to_ip( $hexip, $family )
        : ConfigServer::CheckIP::addr_hex_to_ip( $hexip );

    my $hexip_text = !defined( $hexip )
        ? 'undef'
        : ref( $hexip )
            ? ref( $hexip )
            : $hexip eq ''
                ? '<empty>'
                : $hexip;

    my $family_text = !defined( $family )
        ? 'Auto'
        : ref( $family )
            ? ref( $family )
            : $family;

    my $ip_expect_text = defined( $ip_expect ) ? $ip_expect : 'undef';
    my $ip_actual_text = defined( $ip_actual ) ? $ip_actual : 'undef';

    is( $ip_actual, $ip_expect, "$label: addr_hex_to_ip() expects '$ip_expect_text'" );

    note(
        _note_field( 'Sub', 'addr_hex_to_ip( )' ) . "\n" .
        _note_field( 'Test', $label ) . "\n" .
        _note_field( 'Hexadecimal IP', $hexip_text ) . "\n" .
        _note_field( 'Family', $family_text ) . "\n" .
        _note_field(
            'Converted IP',
            "Expect:    $ip_expect_text\nActual:    $ip_actual_text",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_int_to_ip()
#   
#   Convert decimal addr to normal IP notation.
#   
#   Detect IP family (4 or 6) from the hexadecimal length unless 
#   family is manually supplied.
# #

my $int_ipv4_max    = Math::BigInt->new( 2 )->bpow( $ipv4_bits )->bdec( )->bstr( );
my $int_ipv4_over   = Math::BigInt->new( $int_ipv4_max )->binc( )->bstr( );
my $int_ipv6_max    = Math::BigInt->new( 2 )->bpow( $ipv6_bits )->bdec( )->bstr( );
my $int_ipv6_over   = Math::BigInt->new( $int_ipv6_max )->binc( )->bstr( );

# #
#   $label, $intip, $family, $ip_expect
# #

my @list_int_to_ip =
(
    [ 'IPv4 zero',              '0',                                        undef,          '0.0.0.0' ],
    [ 'IPv4 one',               '1',                                        undef,          '0.0.0.1' ],
    [ 'IPv4 public',            '134744072',                                undef,          '8.8.8.8' ],
    [ 'IPv4 loopback',          '2130706433',                               undef,          '127.0.0.1' ],
    [ 'IPv4 test network',      '3221225985',                               undef,          '192.0.2.1' ],
    [ 'IPv4 maximum',           $int_ipv4_max,                              undef,          '255.255.255.255' ],
    [ 'IPv6 minimum auto',      $int_ipv4_over,                             undef,          '::1:0:0' ],
    [ 'IPv6 documentation',     '42540766411282592856903984951653826561',   undef,          '2001:db8::1' ],
    [ 'IPv6 maximum',           $int_ipv6_max,                              undef,          'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff' ],
    [ 'IPv4 supplied family',   '134744072',                                $ipv4_family,   '8.8.8.8' ],
    [ 'IPv6 supplied family',   '134744072',                                $ipv6_family,   '::808:808' ],
    [ 'IPv4 supplied overflow', $int_ipv4_over,                             $ipv4_family,   undef ],
    [ 'IPv6 overflow',          $int_ipv6_over,                             undef,          undef ],
    [ 'Undefined decimal',      undef,                                      undef,          undef ],
    [ 'Decimal arrayref',       [],                                         undef,          undef ],
    [ 'Empty decimal',          '',                                         undef,          undef ],
    [ 'Leading zero',           '0134744072',                               undef,          undef ],
    [ 'Negative decimal',       '-1',                                       undef,          undef ],
    [ 'Positive sign',          '+1',                                       undef,          undef ],
    [ 'Decimal point',          '1.5',                                      undef,          undef ],
    [ 'Invalid decimal char',   '13474407x',                                undef,          undef ],
    [ 'Invalid family',         '134744072',                                5,              undef ],
    [ 'Family arrayref',        '134744072',                                [],             undef ],
);

for my $test ( @list_int_to_ip )
{
    my ( $label, $intip, $family, $ip_expect ) = @{$test};

    my $ip_actual = defined( $family )
        ? ConfigServer::CheckIP::addr_int_to_ip( $intip, $family )
        : ConfigServer::CheckIP::addr_int_to_ip( $intip );

    my $intip_text = !defined( $intip )
        ? 'undef'
        : ref( $intip )
            ? ref( $intip )
            : $intip eq ''
                ? '<empty>'
                : $intip;

    my $family_text = !defined( $family )
        ? 'Auto'
        : ref( $family )
            ? ref( $family )
            : $family;

    my $ip_expect_text  = defined( $ip_expect ) ? $ip_expect : 'undef';
    my $ip_actual_text  = defined( $ip_actual ) ? $ip_actual : 'undef';
 
    is( $ip_actual, $ip_expect, "$label: addr_int_to_ip() expects '$ip_expect_text'" );

    note(
        _note_field( 'Sub', 'addr_int_to_ip( )' ) . "\n" .
        _note_field( 'Test', $label ) . "\n" .
        _note_field( 'Decimal IP', $intip_text ) . "\n" .
        _note_field( 'Family', $family_text ) . "\n" .
        _note_field(
            'Converted IP',
            "Expect:    $ip_expect_text\nActual:    $ip_actual_text",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › Input Formats
#   
#   Make sure addr_parse detects binary, hex, and decimal IPs.
#   
#   Specifying custom option 'input_format' takes priority over auto
#   detection.
#   
#   Keep CIDR prefix after converting ip to normal notation.
# #

# #
#   $label, $ip, $opts, $complete_expect, $family_expect
# # 

my @list_addr_parse_format =
(
    [ 'Plain text auto',                '192.0.2.1',                                undef,                          '192.0.2.1',        $ipv4_family ],
    [ 'Binary IPv4 auto',               $bin_ipv4_test,                             undef,                          '192.0.2.1',        $ipv4_family ],
    [ 'Binary IPv4 CIDR auto',          "$bin_ipv4_test/24",                        undef,                          '192.0.2.1/24',     $ipv4_family ],
    [ 'Binary IPv6 auto',               $bin_ipv6_doc,                              undef,                          '2001:db8::1',      $ipv6_family ],
    [ 'Hexadec IPv4 auto',              'c0000201',                                 undef,                          '192.0.2.1',        $ipv4_family ],
    [ 'Hexadec IPv4 CIDR auto',         'c0000201/24',                              undef,                          '192.0.2.1/24',     $ipv4_family ],
    [ 'Hexadec IPv6 auto',              '20010db8000000000000000000000001',         undef,                          '2001:db8::1',      $ipv6_family ],
    [ 'Decimal IPv4 auto',              '3221225985',                               undef,                          '192.0.2.1',        $ipv4_family ],
    [ 'Decimal IPv4 CIDR auto',         '3221225985/24',                            undef,                          '192.0.2.1/24',     $ipv4_family ],
    [ 'Decimal IPv6 auto',              '42540766411282592856903984951653826561',   undef,                          '2001:db8::1',      $ipv6_family ],
    [ 'Binary format supplied',         $bin_ipv4_test,                             { input_format => 'binary' },   '192.0.2.1',        $ipv4_family ],
    [ 'Hexadec format supplied',        'c0000201',                                 { input_format => 'hex' },      '192.0.2.1',        $ipv4_family ],
    [ 'Decimal format supplied',        '3221225985',                               { input_format => 'decimal' },  '192.0.2.1',        $ipv4_family ],
    [ 'Text format supplied',           '192.0.2.1',                                { input_format => 'text' },     '192.0.2.1',        $ipv4_family ],
    [ 'Auto chooses binary first',      $bin_ipv4_zero,                             undef,                          '0.0.0.0',          $ipv4_family ],
    [ 'Forced hexadec override',        $bin_ipv4_zero,                             { input_format => 'hex' },      '::',               $ipv6_family ],
    [ 'Auto choose hexadec before dec', '00000001',                                 undef,                          '0.0.0.1',          $ipv4_family ],
    [ 'Forced dec rejects leading zero','00000001',                                 { input_format => 'decimal' },  undef,              undef ],
    [ 'Forced binary rejects Hexadec',  'c0000201',                                 { input_format => 'binary' },   undef,              undef ],
    [ 'Forced text rejects decimal IP', '3221225985',                               { input_format => 'text' },     undef,              undef ],
    [ 'Invalid format name',            '192.0.2.1',                                { input_format => 'invalid' },  undef,              undef ],
    [ 'Format arrayref',                '192.0.2.1',                                { input_format => [] },         undef,              undef ],
);

for my $test ( @list_addr_parse_format )
{
    my ( $label, $ip, $opts, $complete_expect, $family_expect ) = @{$test};

    my $parsed          = ConfigServer::CheckIP::addr_parse( $ip, $opts );
    my $complete_actual = _parsed_field( $parsed, 'addr_zone_cidr' );
    my $family_actual   = _parsed_field( $parsed, 'family' );
    my $complete_text   = defined( $complete_expect ) ? $complete_expect : 'undef';
    my $family_text     = defined( $family_expect ) ? $family_expect : 'undef';
    my $opts_text       = !defined( $opts )
                            ? 'Auto'
                            : ref( $opts->{input_format} )
                                ? ref( $opts->{input_format} )
                                : $opts->{input_format};

    is( $complete_actual,   $complete_text, "$label: addr_parse() expects complete IP '$complete_text'" );
    is( $family_actual,     $family_text,   "$label: addr_parse() expects family '$family_text'" );

    note(
        _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
        _note_field( 'Test', $label ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field( 'Input Format', $opts_text ) . "\n" .
        _note_field(
            'Complete IP',
            "Expect:    $complete_text\nActual:    $complete_actual",
        ) . "\n" .
        _note_field(
            'Family',
            "Expect:    $family_text\nActual:    $family_actual",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › Valid Addresses
#   
#   All the entries below should be accepted by addr_parse().
# #

# #
#   $label, $ip, $opts, $expect_family
# #

my @list_addr_valid =
(
    [ 'IPv4 addr',                  '192.0.2.10',               undef,                          4 ],
    [ 'IPv4 CIDR',                  '10.0.0.1/8',               undef,                          4 ],
    [ 'IPv4 host prefix',           "192.0.2.10/$ipv4_bits",    undef,                          4 ],
    [ 'IPv6 addr',                  '2001:db8::1',              undef,                          6 ],
    [ 'IPv6 CIDR',                  '2001:db8::1/64',           undef,                          6 ],
    [ 'IPv6 host prefix',           "2001:db8::1/$ipv6_bits",   undef,                          6 ],
    [ 'IPv6 loopback',              '::1',                      undef,                          6 ],
    [ 'IPv4 mapped IPv6',           '::ffff:192.0.2.1',         undef,                          6 ],
    [ 'IPv6 zone id',               'fe80::1%eth0',             { allow_zone_id => 1 },         6 ],
    [ 'IPv6 scope id alias',        'fe80::1%eth0',             { allow_scope_id => 1 },        6 ],
    [ 'IPv6 zone id and CIDR',      'fe80::1%eth0/64',          { allow_zone_id => 1 },         6 ],
    [ 'IPv4 /0 prefix',             '0.0.0.0/0',                { allow_prefix_zero => 1 },     4 ],
    [ 'IPv6 /0 prefix',             '::/0',                     { allow_prefix_zero => 1 },     6 ],
);

for my $test ( @list_addr_valid )
{
    my ( $label, $ip, $opts, $expect_family ) = @{$test};

    my $parsed              = ConfigServer::CheckIP::addr_parse( $ip, $opts );
    my $parsed_state        = defined( $parsed ) ? 'Defined' : 'Undefined';
    my $ref_actual          = ref( $parsed ) ne '' ? ref( $parsed ) : 'None';
    my $family_actual       = _parsed_field( $parsed, 'family' );
    my $address_actual      = _parsed_field( $parsed, 'address' );
    my $complete_actual     = _parsed_field( $parsed, 'addr_zone_cidr' );
    my $opts_text           = !defined( $opts )
                                ? 'None'
                                : join(
                                    ', ',
                                    map { "$_ = $opts->{$_}" } sort keys( %{$opts} ),
                                );

    ok( defined( $parsed ), "addr_parse() accepts $label" );

    is( $ref_actual,    'HASH',         "addr_parse() returns hashref for $label" );
    is( $family_actual, $expect_family, "addr_parse() returns expected family for $label" );

    note(
        _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
        _note_field( 'Test', $label ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field( 'Options', $opts_text ) . "\n" .
        _note_field(
            'Parsed',
            "Expect:    Defined\nActual:    $parsed_state",
        ) . "\n" .
        _note_field(
            'Reference',
            "Expect:    HASH\nActual:    $ref_actual",
        ) . "\n" .
        _note_field(
            'Family',
            "Expect:    $expect_family\nActual:    $family_actual",
        ) . "\n" .
        _note_field( 'Address', $address_actual ) . "\n" .
        _note_field( 'Complete', $complete_actual ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › Invalid Input
#   
#   All the entries below have purposeful issues within each string.
#   Such as leading spaces, line break, etc.
#   
#   Make sure invalid Ips are rejected by addr_parse().
#   Invalid IPs must return undef.
# #

# #
#   $label, $input, $opts
# #

my @list_addr_invalid =
(
    [ 'undefined input',            undef,                                  undef ],
    [ 'empty input',                '',                                     undef ],
    [ 'reference input',            [],                                     undef ],
    [ 'options not hashref',        '192.0.2.10',                           [] ],
    [ 'leading space',              ' 192.0.2.10',                          undef ],
    [ 'trailing space',             '192.0.2.10 ',                          undef ],
    [ 'line break',                 "192.0.2.10\n",                         undef ],
    [ 'IPv4 octet too large',       '192.0.2.256',                          undef ],
    [ 'IPv4 too few octets',        '192.0.2',                              undef ],
    [ 'IPv4 too many octets',       '192.0.2.1.5',                          undef ],
    [ 'IPv4 leading zero',          '192.0.02.10',                          undef ],
    [ 'IPv4 double zero octet',     '00.0.0.0',                             undef ],
    [ 'IPv4 leading zero octet',    '01.2.3.4',                             undef ],
    [ 'empty CIDR',                 '192.0.2.10/',                          undef ],
    [ 'extra CIDR field',           '192.0.2.10/24/junk',                   undef ],
    [ 'CIDR leading zero',          '192.0.2.10/024',                       undef ],
    [ 'CIDR contains text',         '192.0.2.10/24x',                       undef ],
    [ 'IPv4 CIDR too large',        '192.0.2.10/' . ( $ipv4_bits + 1 ),     undef ],
    [ 'IPv6 CIDR too large',        '2001:db8::1/' . ( $ipv6_bits + 1 ),    undef ],
    [ 'IPv6 invalid hex',           '2001:db8::g',                          undef ],
    [ 'IPv6 compression twice',     '2001::db8::1',                         undef ],
    [ 'IPv6 bad dotted tail',       '::ffff:192.0.2',                       undef ],
    [ 'IPv6 leading colon only',    ':1',                                   undef ],
    [ 'IPv6 trailing colon only',   '1:',                                   undef ],
    [ 'IPv6 triple colon',          ':::1',                                 undef ],
    [ 'IPv6 too few groups',        '1:2:3:4:5:6:7',                        undef ],
    [ 'IPv6 too many groups',       '1:2:3:4:5:6:7:8:9',                    undef ],
    [ 'IPv6 group too long',        '12345::1',                             undef ],
    [ 'IPv6 dotted leading zero',   '::ffff:192.0.02.1',                    undef ],
    [ 'IPv4 zero prefix disabled',  '192.0.2.10/0',                         undef ],
    [ 'IPv6 zero prefix disabled',  '2001:db8::1/0',                        undef ],
    [ 'zone id disabled',           'fe80::1%eth0',                         undef ],
    [ 'empty zone id',              'fe80::1%',                             { allow_zone_id => 1 } ],
    [ 'invalid zone id char',       'fe80::1%eth0!',                        { allow_zone_id => 1 } ],
    [ 'zone id too long',           'fe80::1%abcdefghijklmcsf',             { allow_zone_id => 1 } ],
    [ 'zone id leading period',     'fe80::1%.eth0',                        { allow_zone_id => 1 } ],
    [ 'zone id leading hyphen',     'fe80::1%-eth0',                        { allow_zone_id => 1 } ],
    [ 'multiple zone IDs',          'fe80::1%eth0%eth1',                    { allow_zone_id => 1 } ],
    [ 'zone id after CIDR',         'fe80::1/64%eth0',                      { allow_zone_id => 1 } ],
    [ 'zone id on global IPv6',     '2001:db8::1%eth0',                     { allow_zone_id => 1 } ],
    [ 'zone id on IPv4',            '192.0.2.1%eth0',                       { allow_zone_id => 1 } ],
    [ 'input exceeds length',       '1' x ( $ip_length_max + 1 ),           undef ],
);

for my $test ( @list_addr_invalid )
{
    my ( $label, $input, $opts ) = @{$test};

    my $parsed      = ConfigServer::CheckIP::addr_parse( $input, $opts );
    my $ip_text     = !defined( $input )
                        ? '<undef>'
                        : ref( $input )
                            ? ref( $input ) . ' ref'
                            : $input eq ''
                                ? '<empty>'
                                : $input;

    my $opts_text   = !defined( $opts )
                        ? 'None'
                        : ref( $opts ) eq 'HASH'
                            ? join(
                                ', ',
                                map { "$_ = $opts->{$_}" } sort keys( %{$opts} ),
                            )
                            : ref( $opts )
                                ? ref( $opts ) . ' ref'
                                : $opts;

    my $parsed_text = defined( $parsed ) ? 'Accepted (hashref)' : 'Rejected (undef)';

    is( $parsed, undef, "addr_parse() rejects $label" );

    note(
        _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
        _note_field( 'Test', $label ) . "\n" .
        _note_field( 'IP', $ip_text ) . "\n" .
        _note_field( 'Options', $opts_text ) . "\n" .
        _note_field(
            'Validation',
            "Expect:    Rejected (undef)\nActual:    $parsed_text",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › IPv4 Num Ranges
#   
#   Lowest and highest nums in each IPv4 range.
#   Octet range:    0 - 255.
# #

my @list_ipv4_octet_ranges =
(
    '0.0.0.0',
    '9.9.9.9',
    '10.10.10.10',
    '99.99.99.99',
    '100.100.100.100',
    '199.199.199.199',
    '200.200.200.200',
    '249.249.249.249',
    '250.250.250.250',
    '255.255.255.255',
);

for my $ip ( @list_ipv4_octet_ranges )
{
    my $parsed              = ConfigServer::CheckIP::addr_parse( $ip );
    my $parsed_state        = defined( $parsed ) ? 'Defined' : 'Undefined';
    my $addr_actual         = defined( $parsed ) && defined( $parsed->{address} ) ? $parsed->{address} : 'Undefined';
    my $fam_actual          = defined( $parsed ) && defined( $parsed->{family} ) ? $parsed->{family} : 'Undefined';

    ok( defined( $parsed ), "addr_parse() accepts IPv4 octet boundary $ip" );

    is( $addr_actual,   $ip,            "addr_parse() keeps IPv4 octet boundary $ip" );
    is( $fam_actual,    $ipv4_family,   "addr_parse() returns IPv4 family for $ip" );

    note(
        _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field(
            'Parsed',
            "Expect:    Defined\nActual:    $parsed_state",
        ) . "\n" .
        _note_field(
            'Address',
            "Expect:    $ip\nActual:    $addr_actual",
        ) . "\n" .
        _note_field(
            'Family',
            "Expect:    $ipv4_family\nActual:    $fam_actual",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › IPv6 Addr Formats
#   
#   Test short, full, and uppercase IPv6 addrs.
#   Return uppercase as lowercase letters.
# #

# #
#   $ip, $addr_expect
# #

my @list_ipv6_formats =
(
    [ '::',                     '::' ],
    [ '1::',                    '1::' ],
    [ '1:2:3:4:5:6:7:8',        '1:2:3:4:5:6:7:8' ],
    [ '2001:DB8::A',            '2001:db8::a' ],
);

for my $test ( @list_ipv6_formats )
{
    my ( $ip, $addr_expect )    = @{$test};

    my $parsed                  = ConfigServer::CheckIP::addr_parse( $ip );
    my $parsed_state            = defined( $parsed ) ? 'Defined' : 'Undefined';
    my $addr_actual             = defined( $parsed ) && defined( $parsed->{address} ) ? $parsed->{address} : 'Undefined';
    my $fam_actual              = defined( $parsed ) && defined( $parsed->{family} ) ? $parsed->{family} : 'Undefined';

    ok( defined( $parsed ), "addr_parse() accepts IPv6 syntax $ip" );

    is( $addr_actual, $addr_expect, "addr_parse() normalizes IPv6 syntax $ip" );
    is( $fam_actual, $ipv6_family,  "addr_parse() returns IPv6 family for $ip" );

    note(
        _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field(
            'Parsed',
            "Expect:    Defined\nActual:    $parsed_state",
        ) . "\n" .
        _note_field(
            'Address',
            "Expect:    $addr_expect\nActual:    $addr_actual",
        ) . "\n" .
        _note_field(
            'Family',
            "Expect:    $ipv6_family\nActual:    $fam_actual",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › IPv4 Details
#   
#   Run the static ipv4 address below through addr_parse().
#   
#   Addr should be valid/private; cidr prefix correct, network ranges,
#   etc.
# #

my $ipv4_input                  = '10.0.0.1/29';
my ( $ipv4_addr, $ipv4_cidr )   = split( /\//, $ipv4_input, 2 );
my $ipv4_host_bits              = $ipv4_bits - $ipv4_cidr;
my $ipv4_range_count            = Math::BigInt->new( 2 ) ->bpow( $ipv4_host_bits )->bstr( );
my $ipv4_first                  = '10.0.0.0';
my $ipv4_last                   = '10.0.0.7';
my $ipv4_range                  = "$ipv4_first - $ipv4_last";
my $ipv4_network                = "$ipv4_first/$ipv4_cidr";

my $parse_ipv4                  = ConfigServer::CheckIP::addr_parse( $ipv4_input );

my %ipv4_expect = (
    address                     => $ipv4_addr,
    addr_full                   => $ipv4_addr,
    addr_zone_cidr              => $ipv4_input,
    family                      => $ipv4_family,
    cidr                        => $ipv4_cidr,
    zone_id                     => undef,
    iptype                      => 'PRIVATE',
    is_loopback_address         => 0,
    binip_length                => $ipv4_bits,
    reverse_ip                  => '1.0.0.10.in-addr.arpa.',
    intip                       => '167772161',
    addr_network_cidr           => $ipv4_network,
    addr_netmask                => '255.255.255.248',
    addr_wildcard_mask          => '0.0.0.7',
    addr_first                  => $ipv4_first,
    addr_first_int              => '167772160',
    addr_last                   => $ipv4_last,
    addr_last_int               => '167772167',
    addr_range_short            => $ipv4_range,
    addr_range_full             => $ipv4_range,
    addr_range_count            => $ipv4_range_count,
    bits_mask                   => $ipv4_cidr,
    bits_host                   => $ipv4_host_bits,
    is_first_address            => 0,
    is_last_address             => 0,
);

ok( defined( $parse_ipv4 ), 'addr_parse() returns IPv4 CIDR details' );

is( $parse_ipv4->{address},             $ipv4_expect{address},              'IPv4 addr is normalized' );
is( $parse_ipv4->{addr_full},           $ipv4_expect{addr_full},            'IPv4 full addr is normalized' );
is( $parse_ipv4->{addr_zone_cidr},      $ipv4_expect{addr_zone_cidr},       'IPv4 complete addr includes CIDR' );
is( $parse_ipv4->{family},              $ipv4_expect{family},               'IPv4 family uses module const' );
is( $parse_ipv4->{cidr},                $ipv4_expect{cidr},                 'IPv4 CIDR returned' );
is( $parse_ipv4->{zone_id},             $ipv4_expect{zone_id},              'IPv4 zone id undefined' );
is( $parse_ipv4->{iptype},              $ipv4_expect{iptype},               'IPv4 type returned' );
is( $parse_ipv4->{is_loopback_address}, $ipv4_expect{is_loopback_address},  'IPv4 private addr not loopback' );
is( length( $parse_ipv4->{binip} ),     $ipv4_expect{binip_length},         'IPv4 binary addr has expected bits' );
is( $parse_ipv4->{reverse_ip},          $ipv4_expect{reverse_ip},           'IPv4 reverse name returned' );
is( $parse_ipv4->{intip},               $ipv4_expect{intip},                'IPv4 decimal addr returned' );
is( $parse_ipv4->{addr_network_cidr},   $ipv4_expect{addr_network_cidr},    'IPv4 network CIDR returned' );
is( $parse_ipv4->{addr_netmask},        $ipv4_expect{addr_netmask},         'IPv4 netmask returned' );
is( $parse_ipv4->{addr_wildcard_mask},  $ipv4_expect{addr_wildcard_mask},   'IPv4 wildcard mask returned' );
is( $parse_ipv4->{addr_first},          $ipv4_expect{addr_first},           'IPv4 first addr returned' );
is( $parse_ipv4->{addr_first_int},      $ipv4_expect{addr_first_int},       'IPv4 first decimal addr returned' );
is( $parse_ipv4->{addr_last},           $ipv4_expect{addr_last},            'IPv4 last addr returned' );
is( $parse_ipv4->{addr_last_int},       $ipv4_expect{addr_last_int},        'IPv4 last decimal addr returned' );
is( $parse_ipv4->{addr_range_short},    $ipv4_expect{addr_range_short},     'IPv4 short range returned' );
is( $parse_ipv4->{addr_range_full},     $ipv4_expect{addr_range_full},      'IPv4 full range returned' );
is( $parse_ipv4->{addr_range_count},    $ipv4_expect{addr_range_count},     'IPv4 range count returned' );
is( $parse_ipv4->{bits_mask},           $ipv4_expect{bits_mask},            'IPv4 mask bits returned' );
is( $parse_ipv4->{bits_host},           $ipv4_expect{bits_host},            'IPv4 host bits returned' );
is( $parse_ipv4->{is_first_address},    $ipv4_expect{is_first_address},     'IPv4 member not first addr' );
is( $parse_ipv4->{is_last_address},     $ipv4_expect{is_last_address},      'IPv4 member not last addr' );

note(
    _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
    _note_field( 'IP', $ipv4_input ) . "\n" .
    _note_field(
        'Range',
        "Expect:    $ipv4_expect{addr_range_short}\n" .
        "Actual:    " . $parse_ipv4->{addr_range_short},
    ) . "\n" .
    _note_field(
        'Range Count',
        "Expect:    $ipv4_expect{addr_range_count}\n" .
        "Actual:    " . $parse_ipv4->{addr_range_count},
    ) . "\n" .
    " \n\n"
);

# #
#   CheckIP.t › Tests › addr_parse() › IPv6 Details
#   
#   Run the static ipv6 address below through addr_parse().
#   
#   Verify that each field returned by the hash has the correct
#   info for that IP.
# #

my $parse_ipv6 = ConfigServer::CheckIP::addr_parse( '2001:db8::1/64' );

ok( defined( $parse_ipv6 ), 'addr_parse() returns IPv6 CIDR details' );

is( $parse_ipv6->{address},                 '2001:db8::1',                              'IPv6 addr uses short format' );
is( $parse_ipv6->{addr_full},               '2001:0db8:0000:0000:0000:0000:0000:0001',  'IPv6 full addr is returned' );
is( $parse_ipv6->{addr_zone_cidr},          '2001:db8::1/64',                           'IPv6 complete addr includes CIDR' );
is( $parse_ipv6->{family},                  $ipv6_family,                               'IPv6 family uses module const' );
is( $parse_ipv6->{cidr},                    64,                                         'IPv6 CIDR is returned' );
is( $parse_ipv6->{zone_id},                 undef,                                      'IPv6 zone id is undefined when absent' );
is( $parse_ipv6->{iptype},                  'DOCUMENTATION',                            'IPv6 type is returned' );
is( $parse_ipv6->{is_loopback_address},     0,                                          'IPv6 documentation addr is not loopback' );
is( length( $parse_ipv6->{binip} ),         $ipv6_bits,                                 'IPv6 binary addr has expected bits' );
is(
    $parse_ipv6->{reverse_ip},
    '1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa.',
    'IPv6 reverse name is returned',
);
is( $parse_ipv6->{intip},                   '42540766411282592856903984951653826561',   'IPv6 decimal addr is returned' );
is( $parse_ipv6->{addr_network_cidr},       '2001:db8::/64',                            'IPv6 network CIDR is returned' );
is( $parse_ipv6->{addr_netmask},            'ffff:ffff:ffff:ffff:0000:0000:0000:0000',  'IPv6 netmask is returned' );
is( $parse_ipv6->{addr_wildcard_mask},      undef,                                      'IPv6 wildcard mask is undefined' );
is( $parse_ipv6->{addr_first},              '2001:db8::',                               'IPv6 first addr is returned' );
is( $parse_ipv6->{addr_first_int},          '42540766411282592856903984951653826560',   'IPv6 first decimal addr is returned' );
is( $parse_ipv6->{addr_last},               '2001:db8::ffff:ffff:ffff:ffff',            'IPv6 last addr is returned' );
is( $parse_ipv6->{addr_last_int},           '42540766411282592875350729025363378175',   'IPv6 last decimal addr is returned' );
is( $parse_ipv6->{addr_range_short},        '2001:db8:: - 2001:db8::ffff:ffff:ffff:ffff', 'IPv6 short range is returned' );
is(
    $parse_ipv6->{addr_range_full},
    '2001:0db8:0000:0000:0000:0000:0000:0000 - ' .
    '2001:0db8:0000:0000:ffff:ffff:ffff:ffff',
    'IPv6 full range is returned',
);
is( $parse_ipv6->{addr_range_count},        '18446744073709551616',     'IPv6 range count is returned' );
is( $parse_ipv6->{bits_mask},               64,                         'IPv6 mask bits are returned' );
is( $parse_ipv6->{bits_host},               64,                         'IPv6 host bits are returned' );
is( $parse_ipv6->{is_first_address},        0,                          'IPv6 member is not first addr' );
is( $parse_ipv6->{is_last_address},         0,                          'IPv6 member is not last addr' );

note(
    _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
    _note_field( 'IP', '2001:db8::1/64' ) . "\n" .
    _note_field(
        'Range',
        "Expect:    2001:db8:: - 2001:db8::ffff:ffff:ffff:ffff\n" .
        "Actual:    " . $parse_ipv6->{addr_range_short},
    ) . "\n" .
    _note_field(
        'Range Count',
        "Expect:    18446744073709551616\n" .
        "Actual:    " . $parse_ipv6->{addr_range_count},
    ) . "\n" .
    " \n\n"
);

# #
#   CheckIP.t › Tests › addr_parse() › No CIDR
#   
#   Passing an IP without a CIDR through addr_parse() will yield
#   significantly less info within the returned hash.
#   
#   Without a CIDR, such fields will be blank / empty:
#       - addr_first
#       - addr_last
#       - addr_range_count
#       - addr_range_full
#       - addr_wildcard_mask
#       - cidr
#   
#   Eg: addr_parse( '192.0.2.10' ) Output:
#        ip:                    "192.0.2.10"
#        status:                "ALLOWED"
#        address:               "192.0.2.10"
#        addr_full:             "192.0.2.10"
#        addr_zone_cidr:        "192.0.2.10"
#        addr_range_count:      <none>
#        addr_first:            "<none>"
#        addr_first_int:        <none>
#        addr_range_short:      "<none>"
#        addr_range_full:       "<none>"
#        addr_last:             "<none>"
#        addr_last_int:         <none>
#        addr_netmask:          "<none>"
#        addr_wildcard_mask:    "<none>"
#        addr_network_cidr:     "<none>"
#        binip:                 "11000000000000000000001000001010"
#        intip:                 3221225994
#        reverse_ip:            "10.2.0.192.in-addr.arpa."
#        cidr:                  <none>
#        zone_id:               <none>
#        iptype:                TEST-NET
#        bits_mask:             <none>
#        bits_host:             <none>
#        family:                4
#        is_first_address:      <none>
#        is_last_address:       <none>
#        is_loopback_address:   0
#   
#   Populate those fields by passing cidr /32:
#       addr_parse( '192.0.2.10/32' )
#   
#   Network fields should stay undefined if CIDR prefix not provided.
# #

my $parse_ipv4_nocidr_ip    = '192.0.2.10';
my $parse_ipv4_nocidr       = ConfigServer::CheckIP::addr_parse( $parse_ipv4_nocidr_ip );

for my $addrparse_field (
    qw(
        cidr
        addr_network_cidr
        addr_netmask
        addr_wildcard_mask
        addr_first
        addr_first_int
        addr_last
        addr_last_int
        addr_range_short
        addr_range_full
        addr_range_count
        bits_mask
        bits_host
        is_first_address
        is_last_address
    )
)
{
    my $field_actual        = $parse_ipv4_nocidr->{$addrparse_field};
    my $field_actual_text   = defined( $field_actual ) ? $field_actual : 'Undefined';

    is( $field_actual, undef, "addr_parse() leaves $addrparse_field undefined without CIDR" );

    note(
        _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
        _note_field( 'IP', $parse_ipv4_nocidr_ip ) . "\n" .
        _note_field( 'Field', $addrparse_field ) . "\n" .
        _note_field(
            'Result',
            "Expect:    Undefined\nActual:    $field_actual_text",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › (Opts) Zone / Scope ID
#   
#   Tests addr_parse() Zone / Scope ID options:
#       - allow_zone_id         (alias)
#       - allow_scope_id        (alias)
#   
#   Allows ipv6 ip with type 'LINK-LOCAL-UNICAST' to include the
#   network interface used to reach it in the return hash; 
#       addr_zone_cidr
#   
#   Eg: addr_parse( "fe80::1%eth0/64", { allow_zone_id => 1 } )
#       addr_zone_cidr = "fe80::1%eth0/64"
#   
#   Eg: addr_parse( "fe80::1%eth0/64", { allow_zone_id => 0 } )
#       IP:     "fe80::1%eth0/64"
#       Status: DENIED
#       return: undef
# #

for my $opt_name ( qw( allow_zone_id allow_scope_id ) )
{
    my $ip                  = 'fe80::1%eth0/64';
    my $zone_expect         = 'eth0';
    my $complete_expect     = $ip;
    my $parsed              = ConfigServer::CheckIP::addr_parse( $ip, { $opt_name => 1 } );

    my $parsed_state        = defined( $parsed ) ? 'Defined' : 'Undefined';
    my $zone_actual         = defined( $parsed ) && defined( $parsed->{zone_id} ) ? $parsed->{zone_id} : 'Undefined';
    my $complete_actual     = defined( $parsed ) && defined( $parsed->{addr_zone_cidr} ) ? $parsed->{addr_zone_cidr} : 'Undefined';

    ok( defined( $parsed ), "addr_parse() accepts $opt_name" );

    is( $zone_actual,       $zone_expect,       "$opt_name returns zone/scope id" );
    is( $complete_actual,   $complete_expect,   "$opt_name keeps zone id and CIDR" );

    note(
        _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
        _note_field( 'Option', $opt_name ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field(
            'Parsed',
            "Expect:    Defined\nActual:    $parsed_state",
        ) . "\n" .
        _note_field(
            'Zone ID',
            "Expect:    $zone_expect\nActual:    $zone_actual",
        ) . "\n" .
        _note_field(
            'Complete IP',
            "Expect:    $complete_expect\nActual:    $complete_actual",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › Zone IDs
#   
#   Test valid v6 zone ids when 'allow_zone_id' or 'allow_scope_id'
#   is enabled.
#   
#   Same exact zone / scope id should return.
#   
#   @note       Zone ID limited to 15 chars.
# #

my @list_zone_ids =
(
    'a',
    '_',
    'eth0.100',
    'csfdefghijklcsf',
);

for my $zone_id ( @list_zone_ids )
{
    my $ip                  = "fe80::1%$zone_id";
    my $zone_expect         = $zone_id;
    my $complete_expect     = $ip;
    my $parsed              = ConfigServer::CheckIP::addr_parse( $ip, { allow_zone_id => 1 } );

    my $parsed_state        = defined( $parsed ) ? 'Defined' : 'Undefined';
    my $zone_actual         = defined( $parsed ) && defined( $parsed->{zone_id} ) ? $parsed->{zone_id} : 'Undefined';
    my $complete_actual     = defined( $parsed ) && defined( $parsed->{addr_zone_cidr} ) ? $parsed->{addr_zone_cidr} : 'Undefined';

    ok( defined( $parsed ), "addr_parse() accepts zone / scope id $zone_id" );

    is( $zone_actual,       $zone_expect,       "addr_parse() returns zone / scope id $zone_id" );
    is( $complete_actual,   $complete_expect,   "addr_parse() keeps zone / scope id $zone_id" );

    note(
        _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
        _note_field( 'Option', 'allow_zone_id' ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field(
            'Parsed',
            "Expect:    Defined\nActual:    $parsed_state",
        ) . "\n" .
        _note_field(
            'Zone ID',
            "Expect:    $zone_expect\nActual:    $zone_actual",
        ) . "\n" .
        _note_field(
            'Complete IP',
            "Expect:    $complete_expect\nActual:    $complete_actual",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › '/0' Zero Prefix
#   
#   Test ipv4 and ipv6 /0 prefix.
#       -   If option 'allow_prefix_zero' not specified, reject IP.
#       -   If option 'allow_prefix_zero' specified, allow CIDR /0
# #

for my $ip ( '0.0.0.0/0', '::/0' )
{
    my $parsed_default  = ConfigServer::CheckIP::addr_parse( $ip );
    my $state_default   = defined( $parsed_default ) ? 'Defined' : 'Undefined';

    is( $parsed_default, undef, "addr_parse() rejects $ip by default" );

    my $parsed_enabled  = ConfigServer::CheckIP::addr_parse( $ip, { allow_prefix_zero => 1 } );
    my $state_enabled   = defined( $parsed_enabled ) ? 'Defined' : 'Undefined';
    my $int_expect      = '0';
    my $int_actual      = defined( $parsed_enabled ) && defined( $parsed_enabled->{intip} ) ? $parsed_enabled->{intip} : 'Undefined';
    my $network_expect  = $ip;
    my $network_actual  = defined( $parsed_enabled ) && defined( $parsed_enabled->{addr_network_cidr} )
                            ? $parsed_enabled->{addr_network_cidr}
                            : 'Undefined';

    ok( defined( $parsed_enabled ), "addr_parse() accepts enabled $ip" );

    is( $int_actual,        $int_expect,        "addr_parse() returns zero integer for $ip" );
    is( $network_actual,    $network_expect,    "addr_parse() returns network for $ip" );

    note(
        _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field(
            'Default',
            "Expect:    Undefined\nActual:    $state_default",
        ) . "\n" .
        _note_field(
            'Enabled',
            "Expect:    Defined\nActual:    $state_enabled",
        ) . "\n" .
        _note_field(
            'Integer',
            "Expect:    $int_expect\nActual:    $int_actual",
        ) . "\n" .
        _note_field(
            'Network',
            "Expect:    $network_expect\nActual:    $network_actual",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › Range Boundaries
#   
#   Test first and last addr in ipv4 / ipv6 cidr ranges.
#       -   First addr should be marked as first, but not last.
#       -   Last addr should be marked as last, but not first.
#       -   Single IP addr should be marked as first and last
#       -   Ranges should return correct total addr count in range.
# #

# #
#   $ip, $first_expect, $last_expect, $range_expect
# #

my @list_range_boundaries =
(
    [ '10.0.0.0/29',                        1, 0, '8' ],
    [ '10.0.0.7/29',                        0, 1, '8' ],
    [ "192.0.2.10/$ipv4_bits",              1, 1, '1' ],
    [ '2001:db8::/' . ( $ipv6_bits - 1 ),   1, 0, '2' ],
    [ '2001:db8::1/' . ( $ipv6_bits - 1 ),  0, 1, '2' ],
    [ "2001:db8::1/$ipv6_bits",             1, 1, '1' ],
);

for my $test ( @list_range_boundaries )
{
    my ( $ip, $first_expect, $last_expect, $range_expect ) = @{$test};

    my $parsed          = ConfigServer::CheckIP::addr_parse( $ip );
    my $parsed_state    = defined( $parsed ) ? 'Defined' : 'Undefined';
    my $first_actual    = defined( $parsed ) && defined( $parsed->{is_first_address} ) ? $parsed->{is_first_address} : 'Undefined';
    my $last_actual     = defined( $parsed ) && defined( $parsed->{is_last_address} ) ? $parsed->{is_last_address} : 'Undefined';
    my $range_actual    = defined( $parsed ) && defined( $parsed->{addr_range_count} ) ? $parsed->{addr_range_count} : 'Undefined';

    ok( defined( $parsed ), "addr_parse() accepts range boundary $ip" );

    is( $first_actual,  $first_expect,  "addr_parse() returns first-address state for $ip" );
    is( $last_actual,   $last_expect,   "addr_parse() returns last-address state for $ip" );
    is( $range_actual,  $range_expect,  "addr_parse() returns range count for $ip" );

    note(
        _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field(
            'Parsed',
            "Expect:    Defined\nActual:    $parsed_state",
        ) . "\n" .
        _note_field(
            'First Addr',
            "Expect:    $first_expect\nActual:    $first_actual",
        ) . "\n" .
        _note_field(
            'Last Addr',
            "Expect:    $last_expect\nActual:    $last_actual",
        ) . "\n" .
        _note_field(
            'Range Count',
            "Expect:    $range_expect\nActual:    $range_actual",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › Loopback
#   
#   Check ipv4, ipv6, and ipv4 mapped ipv6 loopback addrs.
#       -   ipv4: 127.0.0.1/8 loopback
#       -   Ipv6: ::1 loopback
#       -   Detect ipv4 loopbacks in ipv6
#       -   Detection works with both str and hashref
#       -   Invalid input return 0, no loopback detected
# #

# #
#   $ip, $loopback_expect
# #

my @list_loopback =
(
    [ '127.0.0.0',                                  1 ],
    [ '127.0.0.1',                                  1 ],
    [ '127.0.0.1/8',                                1 ],
    [ '127.42.10.5',                                1 ],
    [ '127.255.255.255',                            1 ],
    [ '126.255.255.255',                            0 ],
    [ '128.0.0.0',                                  0 ],
    [ '0.0.0.0',                                    0 ],
    [ '8.8.8.8',                                    0 ],
    [ '192.0.2.10',                                 0 ],
    [ '::1',                                        1 ],
    [ '0:0:0:0:0:0:0:1',                            1 ],
    [ '::1/128',                                    1 ],
    [ '::ffff:127.0.0.0',                           1 ],
    [ '::ffff:127.0.0.1',                           1 ],
    [ '::ffff:127.42.10.5',                         1 ],
    [ '0:0:0:0:0:ffff:7f00:1',                      1 ],
    [ '::ffff:126.255.255.255',                     0 ],
    [ '::ffff:128.0.0.0',                           0 ],
    [ '::ffff:192.0.2.1',                           0 ],
    [ '::',                                         0 ],
    [ '::2',                                        0 ],
    [ 'fe80::1',                                    0 ],
    [ '2001:db8::1',                                0 ],
    [ 'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff',    0 ],
);

for my $test ( @list_loopback )
{
    my ( $ip, $loopback_expect ) = @{$test};

    my $parsed              = ConfigServer::CheckIP::addr_parse( $ip );
    my $parsed_state        = defined( $parsed ) ? 'Defined' : 'Undefined';
    my $parsed_loopback     = defined( $parsed ) && defined( $parsed->{is_loopback_address} )
                                ? $parsed->{is_loopback_address}
                                : 'Undefined';
    my $string_loopback     = ConfigServer::CheckIP::_is_addr_loopback( $ip );
    my $hashref_loopback    = defined( $parsed ) ? ConfigServer::CheckIP::_is_addr_loopback( $parsed ) : 'Undefined';

    ok( defined( $parsed ), "addr_parse() accepts loopback test $ip" );

    is( $parsed_loopback,   $loopback_expect,   "addr_parse() returns loopback state for $ip" );
    is( $string_loopback,   $loopback_expect,   "_is_addr_loopback() checks string $ip" );
    is( $hashref_loopback,  $loopback_expect,   "_is_addr_loopback() checks hashref parsed $ip" );

    note(
        _note_field( 'Sub', 'addr_parse( ), _is_addr_loopback( )' ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field(
            'Parsed',
            "Expect:    Defined\nActual:    $parsed_state",
        ) . "\n" .
        _note_field(
            'Loopback',
            "Expect:    $loopback_expect\n" .
            "Parsed:    $parsed_loopback\n" .
            "String:    $string_loopback\n" .
            "Hashref:   $hashref_loopback",
        ) . "\n" .
        " \n\n"
    );
}

is( ConfigServer::CheckIP::_is_addr_loopback( undef ),  0, 'loopback reject undef' );
is( ConfigServer::CheckIP::_is_addr_loopback( [] ),     0, 'loopback reject arrayref' );
is( ConfigServer::CheckIP::_is_addr_loopback( {} ),     0, 'loopback reject invalid hashref' );

# #
#   CheckIP.t › Tests › addr_get_embedded_v4() › Ipv4 mapped ipv6
#   
#   Extract ipv4 addrs from dotted or hexadecimal ipv4 mapped ipv6.
#   Test both IP types; (str and parsed hash), returned by addr_parse().
#   
#       Eg: Dotted IPv4:
#           my $ipv4 = ConfigServer::CheckIP::addr_get_embedded_v4(
#               "::ffff:192.0.2.1",
#           );
#           print "$ipv4"   # "192.0.2.1"
#   
#       Eg: Hexadecimal IPv4:
#           my $ipv4 = ConfigServer::CheckIP::addr_get_embedded_v4(
#               "0:0:0:0:0:ffff:c000:201",
#           );
#           print "$ipv4"   # "192.0.2.1"
#   
#   Return undef for regular ipv4 addr, any other ipv6 addr, or
#   invalid input.
# #

# #
#   $label, $ip, $embedded_expect
# #

my @list_embedded_v4 =
(
    [ 'Mapped zero dotted',             '::ffff:0.0.0.0',               '0.0.0.0' ],
    [ 'Mapped normal dotted',           '::ffff:1.2.3.4',               '1.2.3.4' ],
    [ 'Mapped public dotted',           '::ffff:8.8.8.8',               '8.8.8.8' ],
    [ 'Mapped private dotted',          '::ffff:10.0.0.1',              '10.0.0.1' ],
    [ 'Mapped loopback minimum',        '::ffff:127.0.0.0',             '127.0.0.0' ],
    [ 'Mapped loopback dotted',         '::ffff:127.0.0.1',             '127.0.0.1' ],
    [ 'Mapped loopback range',          '::ffff:127.42.10.5',           '127.42.10.5' ],
    [ 'Mapped link-local',              '::ffff:169.254.1.1',           '169.254.1.1' ],
    [ 'Mapped documentation',           '::ffff:192.0.2.1',             '192.0.2.1' ],
    [ 'Mapped private range',           '::ffff:192.168.1.1',           '192.168.1.1' ],
    [ 'Mapped multicast',               '::ffff:224.0.0.1',             '224.0.0.1' ],
    [ 'Mapped broadcast',               '::ffff:255.255.255.255',       '255.255.255.255' ],
    [ 'Mapped zero hexadec',            '0:0:0:0:0:ffff:0:0',           '0.0.0.0' ],
    [ 'Mapped normal hexadec',          '::ffff:102:304',               '1.2.3.4' ],
    [ 'Mapped loopback hexadec',        '0:0:0:0:0:ffff:7f00:1',        '127.0.0.1' ],
    [ 'Mapped documentation hex',       '::ffff:c000:201',              '192.0.2.1' ],
    [ 'Mapped broadcast hex',           '::ffff:ffff:ffff',             '255.255.255.255' ],
    [ 'Mapped host CIDR',               '::ffff:192.0.2.1/128',         '192.0.2.1' ],
    [ 'Mapped network CIDR',            '::ffff:192.0.2.1/64',          '192.0.2.1' ],
    [ 'IPv4 input',                     '192.0.2.1',                    undef ],
    [ 'IPv6 unspecified',               '::',                           undef ],
    [ 'IPv6 loopback',                  '::1',                          undef ],
    [ 'IPv6 documentation',             '2001:db8::1',                  undef ],
    [ 'IPv6 link-local',                'fe80::1',                      undef ],
    [ 'IPv6 multicast',                 'ff02::1',                      undef ],
    [ 'Nonmapped dotted tail',          '2001:db8::192.0.2.1',          undef ],
    [ 'IPv4 compatible IPv6',           '::192.0.2.1',                  undef ],
    [ 'NAT64 dotted tail',              '64:ff9b::192.0.2.1',           undef ],
    [ 'Prefix zero disabled',           '::ffff:192.0.2.1/0',           undef ],
    [ 'Invalid mapped IPv4',            '::ffff:192.0.2.256',           undef ],
    [ 'Invalid text',                   'invalid',                      undef ],
    [ 'Empty input',                    '',                             undef ],
    [ 'Undefined input',                undef,                          undef ],
);

for my $test ( @list_embedded_v4 )
{
    my ( $label, $ip, $embedded_expect ) = @{$test};

    my $parsed                  = defined( $ip ) ? ConfigServer::CheckIP::addr_parse( $ip ) : undef;
    my $embedded_str_actual     = ConfigServer::CheckIP::addr_get_embedded_v4( $ip );
    my $embedded_hash_actual    = ConfigServer::CheckIP::addr_get_embedded_v4( $parsed );
    my $ip_text                 = !defined( $ip ) ? 'undef' : $ip eq '' ? '<empty>' : $ip;              # fe80::1
    my $parsed_state            = defined( $parsed ) ? 'Defined' : 'Undefined';
    my $embedded_expect_text    = defined( $embedded_expect ) ? $embedded_expect : 'undef';
    my $embedded_str_text       = defined( $embedded_str_actual ) ? $embedded_str_actual : 'undef';
    my $embedded_hash_text      = defined( $embedded_hash_actual ) ? $embedded_hash_actual : 'undef';

    is( $embedded_str_actual,   $embedded_expect, "$label: string input expects embedded IPv4 '$embedded_expect_text'" );
    is( $embedded_hash_actual,  $embedded_expect, "$label: parsed input expects embedded IPv4 '$embedded_expect_text'" );

    note(
        _note_field( 'Sub', 'addr_get_embedded_v4( )' ) . "\n" .
        _note_field( 'Test', $label ) . "\n" .
        _note_field( 'IP', $ip_text ) . "\n" .
        _note_field( 'Parsed', $parsed_state ) . "\n" .
        _note_field(
            'Embedded IPv4',
            "Expect:    $embedded_expect_text\n" .
            "String:    $embedded_str_text\n" .
            "Hashref:   $embedded_hash_text",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_get_embedded_v4() › Parsed Hash
#   
#   Pass both valid and invalid hashes to addr_get_embedded_v4().
#   
#   Valid ipv4 mapped ipv6 hashes should return ipv4 addr.
#   Invalid should return undef.
# #

my $embedded_parsed         = ConfigServer::CheckIP::addr_parse( '::ffff:192.0.2.1' );
my $embedded_zero_parsed    = ConfigServer::CheckIP::addr_parse( '::ffff:192.0.2.1/0', { allow_prefix_zero => 1 } );

my $embedded_global_parsed  = ConfigServer::CheckIP::addr_parse( '2001:db8::1' );
my $embedded_binip          = defined( $embedded_parsed ) && defined( $embedded_parsed->{binip} )
                                ? $embedded_parsed->{binip}
                                : undef;

my $embedded_global_binip   = defined( $embedded_global_parsed ) && defined( $embedded_global_parsed->{binip} )
                                ? $embedded_global_parsed->{binip}
                                : undef;

my $embedded_family_ref     = $ipv6_family;         # 6
my $embedded_binip_ref      = $embedded_binip;      # 00000000000000000000000000000000000000000000000000000000000000000000000000000000111111111111111111000000000000000000001000000001

# #
#   $label, $input, $embedded_expect
# #

my @list_embedded_v4_hash =
(
    [ 'Complete parsed hash', $embedded_parsed, '192.0.2.1' ],
    [
        'Minimal valid hash',
        { family => $ipv6_family, binip => $embedded_binip },
        '192.0.2.1',
    ],
    [ 'Enabled prefix /0 hash', $embedded_zero_parsed, '192.0.2.1' ],
    [
        'Nonmapped IPv6 hash',
        { family => $ipv6_family, binip => $embedded_global_binip },
        undef,
    ],
    [
        'Wrong IPv4 family',
        { family => $ipv4_family, binip => $embedded_binip },
        undef,
    ],
    [ 'Missing family', { binip => $embedded_binip }, undef ],
    [ 'Missing binary', { family => $ipv6_family }, undef ],
    [
        'Undefined family',
        { family => undef, binip => $embedded_binip },
        undef,
    ],
    [
        'Undefined binary',
        { family => $ipv6_family, binip => undef },
        undef,
    ],
    [
        'Family scalarref',
        { family => \$embedded_family_ref, binip => $embedded_binip },
        undef,
    ],
    [
        'Binary scalarref',
        { family => $ipv6_family, binip => \$embedded_binip_ref },
        undef,
    ],
    [
        'Short binary',
        { family => $ipv6_family, binip => '0' x ( $ipv6_bits - 1 ) },
        undef,
    ],
    [
        'Long binary',
        { family => $ipv6_family, binip => '0' x ( $ipv6_bits + 1 ) },
        undef,
    ],
    [
        'Invalid binary char',
        { family => $ipv6_family, binip => ( '0' x ( $ipv6_bits - 1 ) ) . 'x' },
        undef,
    ],
    [ 'Empty hash',         {},     undef ],
    [ 'Arrayref input',     [],     undef ],
    [ 'Undefined input',    undef,  undef ],
);

for my $test ( @list_embedded_v4_hash )
{
    my ( $label, $input, $embedded_expect ) = @{$test};

    my $embedded_actual         = ConfigServer::CheckIP::addr_get_embedded_v4( $input );
    my $input_type              = !defined( $input ) ? 'undef' : ref( $input ) || 'str';
    my $embedded_expect_text    = defined( $embedded_expect ) ? $embedded_expect : 'undef';
    my $embedded_actual_text    = defined( $embedded_actual ) ? $embedded_actual : 'undef';

    is( $embedded_actual, $embedded_expect, "$label: hash validation expects embedded IPv4 '$embedded_expect_text'" );

    note(
        _note_field( 'Sub', 'addr_get_embedded_v4( )' ) . "\n" .
        _note_field( 'Test', $label ) . "\n" .
        _note_field( 'Input Type', $input_type ) . "\n" .
        _note_field(
            'Embedded IPv4',
            "Expect:    $embedded_expect_text\n" .
            "Actual:    $embedded_actual_text",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_get_embedded_v4() › Loopback
#   
#   Make sure addr_parse() uses extracted v4 addr to detect mapped 
#   127.0.0.0/8 loop range. 
#   
#   IPv4 addrs in 127.0.0.0/8 and IPv6 addr ::1 must still be
#   detected as loopback addrs.
# #

# #
#   $label, $ip, $embedded_expect, $loopback_expect
# #

my @list_embedded_v4_loopback =
(
    [ 'Mapped loopback minimum',    '::ffff:127.0.0.0',         '127.0.0.0',        1 ],
    [ 'Mapped loopback dotted',     '::ffff:127.0.0.1',         '127.0.0.1',        1 ],
    [ 'Mapped loopback range',      '::ffff:127.42.10.5',       '127.42.10.5',      1 ],
    [ 'Mapped loopback maximum',    '::ffff:127.255.255.255',   '127.255.255.255',  1 ],
    [ 'Mapped loopback hex',        '0:0:0:0:0:ffff:7f00:1',    '127.0.0.1',        1 ],
    [ 'Mapped below loopback',      '::ffff:126.255.255.255',   '126.255.255.255',  0 ],
    [ 'Mapped above loopback',      '::ffff:128.0.0.0',         '128.0.0.0',        0 ],
    [ 'Mapped private',             '::ffff:10.0.0.1',          '10.0.0.1',         0 ],
    [ 'Mapped documentation',       '::ffff:192.0.2.1',         '192.0.2.1',        0 ],
    [ 'Native IPv4 loopback',       '127.0.0.1',                undef,              1 ],
    [ 'Native IPv6 loopback',       '::1',                      undef,              1 ],
    [ 'Normal IPv6',                '2001:db8::1',              undef,              0 ],
);

for my $test ( @list_embedded_v4_loopback )
{
    my ( $label, $ip, $embedded_expect, $loopback_expect ) = @{$test};

    my $parsed                  = ConfigServer::CheckIP::addr_parse( $ip );
    my $parsed_state            = defined( $parsed ) ? 'Defined' : 'Undefined';
    my $embedded_actual         = defined( $parsed )
                                    ? ConfigServer::CheckIP::addr_get_embedded_v4( $parsed )
                                    : undef;
    my $loopback_actual         = defined( $parsed )
                                    ? $parsed->{is_loopback_address}
                                    : undef;

    my $embedded_expect_text    = defined( $embedded_expect ) ? $embedded_expect : 'undef';
    my $embedded_actual_text    = defined( $embedded_actual ) ? $embedded_actual : 'undef';
    my $loopback_actual_text    = defined( $loopback_actual ) ? $loopback_actual : 'undef';

    ok( defined( $parsed ), "$label: addr_parse() accepts $ip" );

    is( $embedded_actual,   $embedded_expect,   "$label: embedded IPv4 expects '$embedded_expect_text'" );
    is( $loopback_actual,   $loopback_expect,   "$label: loopback state expects '$loopback_expect'" );

    note(
        _note_field( 'Sub', 'addr_parse( ), addr_get_embedded_v4( )' ) . "\n" .
        _note_field( 'Test', $label ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field(
            'Parsed',
            "Expect:    Defined\nActual:    $parsed_state",
        ) . "\n" .
        _note_field(
            'Embedded IPv4',
            "Expect:    $embedded_expect_text\n" .
            "Actual:    $embedded_actual_text",
        ) . "\n" .
        _note_field(
            'Loopback',
            "Expect:    $loopback_expect\n" .
            "Actual:    $loopback_actual_text",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › Reverse Names
#   
#   Test IPs converted to reverse DNS. Does not actually do DNS 
#   lookup, only tests format:
#       -   Ipv4 octets are correct, end with 'in-addr.arpa'
#       -   Ipv4 0's not accidentally removed
#       -   IPv6 hex digits are reversed, end with 'ip6.arpa'
#       -   All return correct reverse name
#   
#   Also tests for @bug (see below):
#   
#   @bug        Some Net::IP versions remove trailing zero octets
#               when creating ipv4 reverse name:
#                   Incorrect:  192.0.2.0 => "2.0.192.in-addr.arpa."
#                   Correct:    192.0.2.0 => "0.2.0.192.in-addr.arpa."
#   
#               Build reverse name from all 4 validated ipv4 octets.
#   
#               https://sources.debian.org/patches/libnet-ip-perl/1.26-4/ip_reverse.patch/
#               https://sources.debian.org/src/libnet-ip-perl/1.26-3/IP.pm/
# #

# #
#   $ip, $rdns_expect
# #

my @list_ipv4_rdns =
(
    [ '192.0.2.0/24',       '0.2.0.192.in-addr.arpa.' ],
    [ '192.0.2.10/24',      '10.2.0.192.in-addr.arpa.' ],
    [ '10.0.0.0/8',         '0.0.0.10.in-addr.arpa.' ],
    [ '1.0.0.0',            '0.0.0.1.in-addr.arpa.' ],
    [ '1.2.0.0',            '0.0.2.1.in-addr.arpa.' ],
    [ '1.2.3.0',            '0.3.2.1.in-addr.arpa.' ],
    [ '1.2.3.4',            '4.3.2.1.in-addr.arpa.' ],
    [ '0.0.0.0',            '0.0.0.0.in-addr.arpa.' ],
    [ '255.255.255.255',    '255.255.255.255.in-addr.arpa.' ],
);

for my $test ( @list_ipv4_rdns )
{
    my ( $ip, $rdns_expect ) = @{$test};

    my $parsed          = ConfigServer::CheckIP::addr_parse( $ip );
    my $parsed_actual   = defined( $parsed ) ? 'Defined' : 'Undefined';
    my $rdns_actual     = defined( $parsed ) && defined( $parsed->{reverse_ip} )
                            ? $parsed->{reverse_ip}
                            : 'Undefined';

    ok( defined( $parsed ), "addr_parse() accepts reverse test $ip" );

    is( $rdns_actual, $rdns_expect, "addr_parse() returns reverse name for $ip" );

    note(
        _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field(
            'Parsed',
            "Expect:    Defined\nActual:    $parsed_actual",
        ) . "\n" .
        _note_field(
            'Reverse DNS',
            "Expect:    $rdns_expect\nActual:    $rdns_actual",
        ) . "\n" .
        " \n\n"
    );
}

my @list_ipv6_rdns =
(
    '::',
    '::1',
    '2001:db8::1',
    'fe80::1',
    '::ffff:192.0.2.1',
    'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
);

for my $ip ( @list_ipv6_rdns )
{
    my $parsed          = ConfigServer::CheckIP::addr_parse( $ip );
    my $parsed_actual   = defined( $parsed ) ? 'Defined' : 'Undefined';
    my $hex             = defined( $parsed ) && defined( $parsed->{addr_full} ) ? $parsed->{addr_full} : '';
    $hex                =~ s/://g;

    my $rdns_expect     = $hex ne '' ? join( '.', reverse( split( //, $hex ) ), 'ip6', 'arpa.' ) : 'Undefined';
    my $rdns_actual     = defined( $parsed ) && defined( $parsed->{reverse_ip} ) ? $parsed->{reverse_ip} : 'Undefined';

    ok( defined( $parsed ), "addr_parse() accepts IPv6 reverse test $ip" );
    is( $rdns_actual, $rdns_expect, "addr_parse() returns IPv6 reverse name for $ip" );

    note(
        _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field(
            'Parsed',
            "Expect:    Defined\nActual:    $parsed_actual",
        ) . "\n" .
        _note_field(
            'Reverse DNS',
            "Expect:    $rdns_expect\nActual:    $rdns_actual",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › CIDR Prefixes
#   
#   Test possible CIDR prefixes for v4 and v6.
#       -   ipv4: verify prefix /0 - /32
#       -   ipv6: verify prefix /0 - /128
#       -   Each prefix returns correct family label (4 or 6)
#       -   Mask and host bits correct.
#       -   Binary addrs correct:
#               IPv4:   32 bits
#               IPv6:   128 bits
#       -   CIDR range and total addr count correct.
#       -   /0 works only if option 'allow_prefix_zero' is specified.
# #

# #
#   $label, $addr, $bit_i, $family
# #

for my $case (
    [ 'IPv4',   '203.0.113.129',                            $ipv4_bits,     $ipv4_family ],
    [ 'IPv6',   '2001:db8:abcd:1234:5678:9abc:def0:1234',   $ipv6_bits,     $ipv6_family ]
)
{
    my ( $label, $addr, $bit_i, $family ) = @{$case};

    subtest "$label CIDR prefixes" => sub
    {
        for my $cidr ( 0 .. $bit_i )
        {
            my $ip              = "$addr/$cidr";
            my $parsed          = ConfigServer::CheckIP::addr_parse( $ip, { allow_prefix_zero => 1 } );

            my $parsed_actual   = defined( $parsed ) ? 'Defined' : 'Undefined';
            my $fam_actual      = defined( $parsed ) && defined( $parsed->{family} ) ? $parsed->{family} : 'Undefined';
            my $mask_actual     = defined( $parsed ) && defined( $parsed->{bits_mask} ) ? $parsed->{bits_mask} : 'Undefined';
            my $host_expect     = $bit_i - $cidr;
            my $host_actual     = defined( $parsed ) && defined( $parsed->{bits_host} ) ? $parsed->{bits_host} : 'Undefined';
            my $bin_actual      = defined( $parsed ) && defined( $parsed->{binip} ) ? length( $parsed->{binip} ) : 'Undefined';
            my $range_expect    = Math::BigInt->new( 2 ) ->bpow( $host_expect ) ->bstr( );
            my $range_actual    = defined( $parsed ) && defined( $parsed->{addr_range_count} ) ? $parsed->{addr_range_count} : 'Undefined';

            ok( defined( $parsed ), "$label /$cidr parses" );

            is( $fam_actual,    $family,        "$label /$cidr family" );
            is( $mask_actual,   $cidr,          "$label /$cidr bits (mask)" );
            is( $host_actual,   $host_expect,   "$label /$cidr bits (host)" );
            is( $bin_actual,    $bit_i,         "$label /$cidr bits (binary)" );
            is( $range_actual,  $range_expect,  "$label /$cidr range count" );

            note(
                _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
                _note_field( 'IP', $ip ) . "\n" .
                _note_field(
                    'Parsed',
                    "Expect:    Defined\nActual:    $parsed_actual",
                ) . "\n" .
                _note_field(
                    'Family',
                    "Expect:    $family\nActual:    $fam_actual",
                ) . "\n" .
                _note_field(
                    'Mask Bits',
                    "Expect:    $cidr\nActual:    $mask_actual",
                ) . "\n" .
                _note_field(
                    'Host Bits',
                    "Expect:    $host_expect\nActual:    $host_actual",
                ) . "\n" .
                _note_field(
                    'Binary Bits',
                    "Expect:    $bit_i\nActual:    $bin_actual",
                ) . "\n" .
                _note_field(
                    'Range Count',
                    "Expect:    $range_expect\nActual:    $range_actual",
                ) . "\n" .
                " \n\n"
            );
        }
    };
}

# #
#   CheckIP.t › Tests › addr_parse() › Parse Twice
#   
#   Parse each addr twice:
#       -   Original addr
#       -   Normalized addr returned by first call
#   
#   Make sure both calls return same info with no changes.
# #

# #
#   $input, $opts
# #

my @list_twice_addr =
(
    [ '192.0.2.129/25',                                 {}                          ],
    [ '0.0.0.0/0',                                      { allow_prefix_zero => 1 }  ],
    [ '2001:db8:abcd:1234:5678:9abc:def0:1234/73',      {}                          ],
    [ '::/0',                                           { allow_prefix_zero => 1 }  ],
    [ 'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff/128',    {}                          ],
    [ 'fe80::1%eth0/64',                                { allow_zone_id => 1 }      ],
    [ '::ffff:192.0.2.1/128',                           {}                          ],
);

my @list_twice_fields = qw(
    address
    addr_full
    addr_zone_cidr
    family
    cidr
    zone_id
    iptype
    binip
    reverse_ip
    intip
    addr_network_cidr
    addr_netmask
    addr_wildcard_mask
    addr_first
    addr_first_int
    addr_last
    addr_last_int
    addr_range_short
    addr_range_full
    addr_range_count
    bits_mask
    bits_host
    is_first_address
    is_last_address
    is_loopback_address
);

for my $test ( @list_twice_addr )
{
    my ( $input, $opts ) = @{$test};

    my $first   = ConfigServer::CheckIP::addr_parse( $input, $opts );
    my $second  = ConfigServer::CheckIP::addr_parse( $first->{addr_zone_cidr}, $opts );

    ok( defined( $first ),  "round trip first parse accepts $input" );
    ok( defined( $second ), "round trip second parse accepts $input" );

    for my $field ( @list_twice_fields )
    {
        my $field_expect    = _parsed_field( $first, $field );
        my $field_actual    = _parsed_field( $second, $field );

        is( $field_actual, $field_expect, "round trip keeps $field for $input" );

        note(
            _note_field( 'Sub', 'addr_parse( )' ) . "\n" .
            _note_field( 'IP', $input ) . "\n" .
            _note_field( 'Field', $field ) . "\n" .
            _note_field(
                'Result',
                "Expect:    $field_expect\nActual:    $field_actual",
            ) . "\n" .
            " \n\n"
        );
    }
}

# #
#   CheckIP.t › Tests › Public Check Sub › Invalid Input
#   
#   Pass invalid input to checkip() and cccheckip(), and make sure
#   of the following:
#       -   Reject missing / ref values
#       -   Reject invalid v4, v6, or cidrs
#       -   Don't crash or throw warnings.
#       -   Return 0 if value is invalid.
# #

my $scalar_silent_undef;

# #
#   $label, $input
# #

my @list_silent_invalid =
(
    [ 'undefined input',            undef ],
    [ 'empty input',                '' ],
    [ 'arrayref input',             [] ],
    [ 'hashref input',              {} ],
    [ 'coderef input',              sub { } ],
    [ 'undefined scalarref',        \$scalar_silent_undef ],
    [ 'empty CIDR',                 '8.8.8.8/' ],
    [ 'extra CIDR field',           '8.8.8.8/24/junk' ],
    [ 'CIDR leading zero',          '8.8.8.8/024' ],
    [ 'CIDR contains text',         '8.8.8.8/24x' ],
    [ 'IPv4 CIDR too large',        '8.8.8.8/' . ( $ipv4_bits + 1 ) ],
    [ 'IPv6 CIDR too large',        '2001:db8::1/' . ( $ipv6_bits + 1 ) ],
    [ 'IPv4 leading zero',          '08.8.8.8' ],
    [ 'IPv6 compression twice',     '2001::db8::1' ],
    [ 'IPv6 leading colon only',    ':1' ],
    [ 'IPv6 trailing colon only',   '1:' ],
    [ 'IPv6 triple colon',          ':::1' ],
    [ 'IPv6 too few groups',        '1:2:3:4:5:6:7' ],
    [ 'IPv6 too many groups',       '1:2:3:4:5:6:7:8:9' ],
    [ 'IPv6 group too long',        '12345::1' ],
    [ 'IPv6 bad dotted tail',       '::ffff:192.0.2' ],
);

for my $subname ( qw( checkip cccheckip ) )
{
    my $subrun = ConfigServer::CheckIP->can( $subname );

    for my $test ( @list_silent_invalid )
    {
        my ( $label, $input ) = @{$test};

        my $input_text  = !defined( $input )
                            ? '<undef>'
                            : ref( $input )
                                ? "<$label>"
                                : $input eq ''
                                    ? '<empty>'
                                    : $input;

        my ( $res, $err, $warn ) = _runsub(
            sub
            {
                return $subrun->( $input );
            }
        );

        my $subret              = defined( $res ) ? $res : 'undef';
        my $err_actual_text     = $err eq '' ? 'None' : $err;
        my $warn_actual_text    = $warn eq '' ? 'None' : $warn;
        my $res_actual_text     = !defined( $res )
                                    ? 'Undefined'
                                    : $subret == 0
                                        ? 'Rejected (0)'
                                        : "Unexpected value ($subret)";

        is( $err,       '', "$subname() does not die for test '$label'" );
        is( $warn,      '', "$subname() does not warn for test '$label'" );
        is( $subret,    0,  "$subname() rejects test '$label'" );

        note(
            _note_field( 'Sub', "$subname( )" ) . "\n" .
            _note_field( 'Test', $label ) . "\n" .
            _note_field( 'IP', $input_text ) . "\n" .
            _note_field(
                'Exception',
                "Expect:    None\nActual:    $err_actual_text",
            ) . "\n" .
            _note_field(
                'Warning',
                "Expect:    None\nActual:    $warn_actual_text",
            ) . "\n" .
            _note_field(
                'Validation',
                "Expect:    Rejected (0)\nActual:    $res_actual_text",
            ) . "\n" .
            " \n\n"
        );
    }
}

# #
#   CheckIP.t › Tests › _checkip_validate() › Run
#   
#   Test shared behavior used between checkip() and cccheckip():
#       -   Accept str and scalarrefs.
#       -   Reject loopback addrs.
#       -   Forward parser options.
#       -   Apply PUBLIC IPv4 validation when requested.
#       -   Normalize only accepted scalarrefs.
# #

# #
#   $label, $ip_actual, $opts, $res_expect
# #

my @list_cip_validate = (
    [ 'IPv4 value',                     '192.168.1.1',          undef,                          $ipv4_family ],
    [ 'IPv6 value',                     '2001:db8::1',          undef,                          $ipv6_family ],
    [ 'IPv4 loopback',                  '127.42.10.5',          undef,                          0 ],
    [ 'IPv6 loopback',                  '::1',                  undef,                          0 ],
    [ 'IPv4 mapped loopback',           '::ffff:127.0.0.1',     undef,                          0 ],
    [ 'PUBLIC required private IPv4',   '192.168.1.1',          { require_public_ip => 1 },     0 ],
    [ 'PUBLIC required public IPv4',    '8.8.8.8',              { require_public_ip => 1 },     $ipv4_family ],
    [ 'PUBLIC applies to IPv4 only',    'fc00::1',              { require_public_ip => 1 },     $ipv6_family ],
    [ 'IPv4 prefix /0 disabled',        '8.8.8.8/0',            undef,                          0 ],
    [ 'IPv4 prefix /0 enabled',         '8.8.8.8/0',            { allow_prefix_zero => 1 },     $ipv4_family ],
    [ 'IPv6 prefix /0 enabled',         '2001:db8::1/0',        { allow_prefix_zero => 1 },     $ipv6_family ],
    [ 'zone ID disabled',               'fe80::1%eth0',         undef,                          0 ],
    [ 'zone ID enabled',                'fe80::1%eth0',         { allow_zone_id => 1 },         $ipv6_family ],
    [ 'scope ID alias enabled',         'fe80::1%eth0',         { allow_scope_id => 1 },        $ipv6_family ],
);

# #
#   Convert family return to readable string
# #

my %res_str_family = (
    0               => 'Rejected',
    $ipv4_family    => 'Accepted IPv4',
    $ipv6_family    => 'Accepted IPv6',
);

for my $test ( @list_cip_validate )
{
    my ( $label, $ip_actual, $opts, $res_expect ) = @{$test};

    my $res_actual          = ConfigServer::CheckIP::_checkip_validate( $ip_actual, $opts );
    my $res_expect_text     = "$res_str_family{$res_expect} ($res_expect)";

    my $res_actual_text     = !defined( $res_actual )
                                ? 'Undefined'
                                : exists( $res_str_family{$res_actual} )
                                    ? "$res_str_family{$res_actual} ($res_actual)"
                                    : "Unexpected value ($res_actual)";

    is( $res_actual, $res_expect, "$label: _checkip_validate() expects $res_expect_text" );

    note(
        _note_field(
            'Validation',
            "Expect:    $res_expect_text\nActual:    $res_actual_text",
        ) . "\n" .
        " \n\n"
    );
}

is(
    ConfigServer::CheckIP::_checkip_validate( undef ),
    0,
    '_checkip_validate() rejects undefined input',
);

is(
    ConfigServer::CheckIP::_checkip_validate( [], undef ),
    0,
    '_checkip_validate() rejects an input arrayref',
);

is(
    ConfigServer::CheckIP::_checkip_validate( '8.8.8.8', [] ),
    0,
    '_checkip_validate() rejects an options arrayref',
);

my $validate_undef_ref;

is(
    ConfigServer::CheckIP::_checkip_validate( \$validate_undef_ref ),
    0,
    '_checkip_validate() rejects an undefined scalarref',
);

my $validate_ipv6_ref = '2001:0db8:0000:0000:0000:0000:0000:0001/64';

is(
    ConfigServer::CheckIP::_checkip_validate( \$validate_ipv6_ref ),
    $ipv6_family,
    '_checkip_validate() accepts scalarref IPv6 addr',
);

is(
    $validate_ipv6_ref,
    '2001:db8::1/64',
    '_checkip_validate() normalizes accepted scalarref input',
);

my $validate_rejected_ref = '127.42.10.5';

is(
    ConfigServer::CheckIP::_checkip_validate( \$validate_rejected_ref ),
    0,
    '_checkip_validate() rejects scalarref loopback addr',
);

is(
    $validate_rejected_ref,
    '127.42.10.5',
    '_checkip_validate() leaves rejected scalarref input unchanged',
);

# #
#   CheckIP.t › Tests › checkip + cccheckip › IP Type
#   
#   Checks return ( value, type ) for every listed ip.
#   
#   This is the same list written within CheckIP.pm module's sub:
#       tests_checkip()
#   
#   Test gets ran through both subs:
#       checkip() and cccheckip()
# #

my @list_check_sub_type = (
    [ '127.0.0.1',              'LOOPBACK',                 0,              0 ],
    [ '0.0.0.1',                'PRIVATE',                  $ipv4_family,   0 ],
    [ '192.168.1.1',            'PRIVATE',                  $ipv4_family,   0 ],
    [ '172.16.0.1',             'PRIVATE',                  $ipv4_family,   0 ],
    [ '10.0.0.1',               'PRIVATE',                  $ipv4_family,   0 ],
    [ '100.64.0.1',             'SHARED',                   $ipv4_family,   0 ],
    [ '8.8.8.8',                'PUBLIC',                   $ipv4_family,   $ipv4_family ],
    [ '8.8.8.8/0',              'PREFIX ZERO DISALLOWED',   0,              0 ],
    [ "8.8.8.8/$ipv4_bits",     'PUBLIC',                   $ipv4_family,   $ipv4_family ],
    [ '1.1.1.1',                'PUBLIC',                   $ipv4_family,   $ipv4_family ],
    [ '169.254.1.1',            'LINK-LOCAL',               $ipv4_family,   0 ],
    [ '192.0.0.1',              'RESERVED',                 $ipv4_family,   0 ],
    [ '192.0.2.1',              'TEST-NET',                 $ipv4_family,   0 ],
    [ '192.88.99.1',            '6TO4-RELAY',               $ipv4_family,   0 ],
    [ '198.18.0.1',             'RESERVED',                 $ipv4_family,   0 ],
    [ '198.51.100.1',           'TEST-NET',                 $ipv4_family,   0 ],
    [ '203.0.113.1',            'TEST-NET',                 $ipv4_family,   0 ],
    [ '224.0.0.1',              'MULTICAST',                $ipv4_family,   0 ],
    [ '240.0.0.1',              'RESERVED',                 $ipv4_family,   0 ],
    [ '255.255.255.255',        'BROADCAST',                $ipv4_family,   0 ],

    [ '::',                     'UNSPECIFIED',              $ipv6_family,   $ipv6_family ],
    [ '::1',                    'LOOPBACK',                 0,              0 ],
    [ '::ffff:127.0.0.0',       'IPV4MAP',                  0,              0 ],
    [ '::ffff:192.0.2.1',       'IPV4MAP',                  $ipv6_family,   $ipv6_family ],
    [ '100::1',                 'DISCARD',                  $ipv6_family,   $ipv6_family ],
    [ '4000::1',                'RESERVED',                 $ipv6_family,   $ipv6_family ],
    [ '2001::1',                'TEREDO',                   $ipv6_family,   $ipv6_family ],
    [ '2001:2::1',              'BMWG',                     $ipv6_family,   $ipv6_family ],
    [ '2001:db8::1',            'DOCUMENTATION',            $ipv6_family,   $ipv6_family ],
    [ '2001:10::1',             'ORCHID',                   $ipv6_family,   $ipv6_family ],
    [ '2002::1',                '6TO4',                     $ipv6_family,   $ipv6_family ],
    [ '2001:db8::1/0',          'PREFIX ZERO DISALLOWED',   0,              0 ],
    [ '2001:db8::/64',          'DOCUMENTATION',            $ipv6_family,   $ipv6_family ],
    [ '2001:db8::1/64',         'DOCUMENTATION',            $ipv6_family,   $ipv6_family ],
    [ '2606:4700:4700::1111',   'GLOBAL-UNICAST',           $ipv6_family,   $ipv6_family ],
    [ '2001:4860:4860::8888',   'GLOBAL-UNICAST',           $ipv6_family,   $ipv6_family ],
    [ 'fc00::1',                'UNIQUE-LOCAL-UNICAST',     $ipv6_family,   $ipv6_family ],
    [ 'fd00::1',                'UNIQUE-LOCAL-UNICAST',     $ipv6_family,   $ipv6_family ],
    [ 'fe80::1',                'LINK-LOCAL-UNICAST',       $ipv6_family,   $ipv6_family ],
    [ 'ff02::1',                'MULTICAST',                $ipv6_family,   $ipv6_family ],
);

# #
#   $sub_name, $fam_select
# #

for my $sub_config (
    [ 'checkip',    2 ],
    [ 'cccheckip',  3 ],
)
{
    my ( $sub_name, $fam_select ) = @{$sub_config};

    my $sub_ref                 = ConfigServer::CheckIP->can( $sub_name );
    my $sub_name_aligned        = sprintf( '%-13s', "$sub_name()" );

    for my $ip_test ( @list_check_sub_type )
    {
        my ( $ip_actual, $type_expect ) = @{$ip_test}[ 0, 1 ];

        my $fam_expect          = $ip_test->[$fam_select];          # 2 or 3
        my ( $ip_address )      = split( /\//, $ip_actual, 2 );
        my $ip_parsed           = ConfigServer::CheckIP::addr_parse( $ip_address );
        my $type_actual         = defined( $ip_parsed ) &&
                                    defined( $ip_parsed->{iptype} )
                                    ? $ip_parsed->{iptype}
                                    : 'INVALID';

        $type_actual = 'PREFIX ZERO DISALLOWED'
            if $ip_actual =~ m{/0\z};

        my $fam_actual      = $sub_ref->( $ip_actual );

        is( $type_actual,   $type_expect,   "$sub_name_aligned IP $ip_actual expects type '$type_expect'" );
        is( $fam_actual,    $fam_expect,    "              IP $ip_actual expects family '$fam_expect'" );

        note(
            _note_field( 'Sub', "$sub_name (id:$fam_select)" ) . "\n" .
            _note_field( 'IP', $ip_actual ) . "\n" .
            _note_field(
                'Type', "Expect:    $type_expect\nActual:    $type_actual",
            ) . "\n" .
            _note_field(
                'Result', "Expect:    $fam_expect\nActual:    $fam_actual",
            ) . 
            " \n\n"
        );
    }
}

# #
#   CheckIP.t › Tests › checkip()
#   
#   Make sure checkip() returns correct response:
#       -   Ipv4:       return 4
#       -   Ipv6:       return 6
#       -   Loopback:   return 0
#       -   Invalid:    return 0
#   
#   Reject /0 cidr prefix
# #

# #
#   $ip_actual, $fam_expect
# #

my @list_checkip =
(
    [ '192.168.1.1',                $ipv4_family ],
    [ '169.254.1.1',                $ipv4_family ],
    [ '224.0.0.1',                  $ipv4_family ],
    [ '8.8.8.8',                    $ipv4_family ],
    [ '8.8.8.8/1',                  $ipv4_family ],
    [ "8.8.8.8/$ipv4_bits",         $ipv4_family ],
    [ '2001:db8::1',                $ipv6_family ],
    [ '2001:db8::1/1',              $ipv6_family ],
    [ '2001:db8::1/64',             $ipv6_family ],
    [ "2001:db8::1/$ipv6_bits",     $ipv6_family ],
    [ '127.0.0.1',                  0 ],
    [ '127.42.10.5',                0 ],
    [ '127.255.255.255',            0 ],
    [ '::1',                        0 ],
    [ '::ffff:127.0.0.0',           0 ],
    [ '::ffff:127.0.0.1',           0 ],
    [ '::ffff:127.42.10.5',         0 ],
    [ '0:0:0:0:0:ffff:7f00:1',      0 ],
    [ '192.0.2.256',                0 ],
    [ '192.0.2.10/0',               0 ],
    [ '2001:db8::1/0',              0 ],
);

for my $test ( @list_checkip )
{
    my ( $ip_actual, $fam_expect ) = @{$test};

    my $fam_actual = ConfigServer::CheckIP::checkip( $ip_actual );

    is( $fam_actual, $fam_expect, "checkip() IP $ip_actual expects family '$fam_expect'" );

    note(
        _note_field(
            'Result', "Expect:    $fam_expect\nActual:    $fam_actual",
        ) . "\n" .
        " \n\n"
    );
}

my $cip_ipv6_ref = '2001:0db8:0000:0000:0000:0000:0000:0001/64';

is(
    ConfigServer::CheckIP::checkip( \$cip_ipv6_ref ),
    $ipv6_family,
    'checkip() accepts scalarref IPv6 addr',
);

is( $cip_ipv6_ref, '2001:db8::1/64', 'checkip() normalizes scalarref IPv6 addr' );

# #
#   Test checkip() option handling.
# #

my $cip_opts        = { allow_prefix_zero => 1 };
my %cip_opts_before = %{$cip_opts};

is(
    ConfigServer::CheckIP::checkip( '8.8.8.8/0', $cip_opts ),
    $ipv4_family,
    'checkip() allows an IPv4 /0 prefix when enabled',
);

is_deeply(
    $cip_opts,
    \%cip_opts_before,
    'checkip() does not modify the supplied options hash',
);

is(
    ConfigServer::CheckIP::checkip(
        '2001:db8::1/0',
        { allow_prefix_zero => 1 },
    ),
    $ipv6_family,
    'checkip() allows an IPv6 /0 prefix when enabled',
);

is(
    ConfigServer::CheckIP::checkip(
        'fe80::1%eth0',
        { allow_zone_id => 1 },
    ),
    $ipv6_family,
    'checkip() forwards the zone ID option',
);

is(
    ConfigServer::CheckIP::checkip(
        'fe80::1%eth0',
        { allow_scope_id => 1 },
    ),
    $ipv6_family,
    'checkip() forwards the scope ID alias',
);

is(
    ConfigServer::CheckIP::checkip(
        '192.168.1.1',
        { require_public_ip => 1 },
    ),
    0,
    'checkip() rejects private IPv4 when PUBLIC type is required',
);

is(
    ConfigServer::CheckIP::checkip(
        '8.8.8.8',
        { require_public_ip => 1 },
    ),
    $ipv4_family,
    'checkip() accepts public IPv4 when PUBLIC type is required',
);

is(
    ConfigServer::CheckIP::checkip( '8.8.8.8', [] ),
    0,
    'checkip() rejects an options arrayref',
);

# #
#   CheckIP.t › Tests › cccheckip()
#   
#   Test addrs using cccheckip():
#       -   Ipv4:                   return 4
#       -   Ipv6:                   return 6
#       -   IPv4 mapped IPv6:       return 6
#       -   Private, link-local,
#           multicast, loopback,
#           invalid ipv4:           return 0
#       -   Valid CIDR prefix limits accepted
#       -   Ipv6 scalarref accepted, changed to shorter form.
# #

# #
#   $ip, $res_expect
# #

my @list_cccip =
(
    [ '8.8.8.8',                    $ipv4_family ],
    [ '8.8.8.8/1',                  $ipv4_family ],
    [ "8.8.8.8/$ipv4_bits",         $ipv4_family ],
    [ '8.8.8.8/0',                  0 ],
    [ '1.1.1.1',                    $ipv4_family ],
    [ '10.0.0.1',                   0 ],
    [ '172.16.0.1',                 0 ],
    [ '192.168.1.1',                0 ],
    [ '169.254.1.1',                0 ],
    [ '224.0.0.1',                  0 ],
    [ '2001:db8::1',                $ipv6_family ],
    [ '2001:db8::1/1',              $ipv6_family ],
    [ "2001:db8::1/$ipv6_bits",     $ipv6_family ],
    [ '2001:db8::1/0',              0 ],
    [ 'fc00::1',                    $ipv6_family ],
    [ '127.0.0.1',                  0 ],
    [ '127.42.10.5',                0 ],
    [ '::1',                        0 ],
    [ '::ffff:127.0.0.0',           0 ],
    [ '::ffff:127.0.0.1',           0 ],
    [ '0:0:0:0:0:ffff:7f00:1',      0 ],
    [ '::ffff:10.0.0.1',            $ipv6_family ],
    [ '::ffff:172.16.0.1',          $ipv6_family ],
    [ '::ffff:192.168.1.1',         $ipv6_family ],
    [ '::ffff:169.254.1.1',         $ipv6_family ],
    [ '::ffff:8.8.8.8',             $ipv6_family ],
    [ '192.0.2.256',                0 ],
);

for my $test ( @list_cccip )
{
    my ( $ip, $res_expect ) = @{$test};

    my $res_actual          = ConfigServer::CheckIP::cccheckip( $ip );
    my $res_expect_text     = "$res_str_family{$res_expect} ($res_expect)";
    my $res_actual_text     = !defined( $res_actual )
                                ? 'Undefined'
                                : exists( $res_str_family{$res_actual} )
                                    ? "$res_str_family{$res_actual} ($res_actual)"
                                    : "Unexpected value ($res_actual)";

    is( $res_actual, $res_expect, "cccheckip() IP $ip expects $res_expect_text" );

    note(
        _note_field( 'Sub', 'cccheckip( )' ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field(
            'Validation',
            "Expect:    $res_expect_text\nActual:    $res_actual_text",
        ) . "\n" .
        " \n\n"
    );
}

my $cccip_ipv6_ref = '2001:0db8:0000:0000:0000:0000:0000:0001/64';

is(
    ConfigServer::CheckIP::cccheckip( \$cccip_ipv6_ref ),
    $ipv6_family,
    "cccheckip() accepts scalarref IPv6 addr $cccip_ipv6_ref",
);

is( $cccip_ipv6_ref, '2001:db8::1/64', 'cccheckip() normalizes scalarref IPv6 addr' );

# #
#   Test cccheckip() option handling and PUBLIC IPv4 enforcement.
# #

my $cccip_opts =
{
    allow_prefix_zero   => 1,
    require_public_ip   => 0,
};

my %cccip_opts_before = %{$cccip_opts};

is(
    ConfigServer::CheckIP::cccheckip( '8.8.8.8/0', $cccip_opts ),
    $ipv4_family,
    'cccheckip() allows an IPv4 /0 prefix when enabled',
);

is_deeply(
    $cccip_opts,
    \%cccip_opts_before,
    'cccheckip() does not modify the supplied options hash',
);

is(
    ConfigServer::CheckIP::cccheckip(
        '192.168.1.1',
        { require_public_ip => 0 },
    ),
    0,
    'cccheckip() cannot have PUBLIC IPv4 enforcement disabled',
);

is(
    ConfigServer::CheckIP::cccheckip(
        '2001:db8::1/0',
        { allow_prefix_zero => 1 },
    ),
    $ipv6_family,
    'cccheckip() allows an IPv6 /0 prefix when enabled',
);

is(
    ConfigServer::CheckIP::cccheckip(
        'fe80::1%eth0',
        { allow_zone_id => 1 },
    ),
    $ipv6_family,
    'cccheckip() forwards the zone ID option',
);

is(
    ConfigServer::CheckIP::cccheckip(
        'fe80::1%eth0',
        { allow_scope_id => 1 },
    ),
    $ipv6_family,
    'cccheckip() forwards the scope ID alias',
);

is(
    ConfigServer::CheckIP::cccheckip( '8.8.8.8', [] ),
    0,
    'cccheckip() rejects an options arrayref',
);

# #
#   CheckIP.t › Tests › checkip() and cccheckip() › Input Formats
#   
#   Pass ip formats binary, hex, and decimal through both public
#   check subs checkip() and cccheckip().
#   
#   No matter which format the IP is provided in, all sub rules
#   still apply, and all acceptance conditions stay.
# #

# #
#   $label, $ip, $opts, $cip_expect, $cccip_expect
# #

my @list_check_format_input =
(
    [ 'Binary public IPv4',             $bin_ipv4_public,       undef,  $ipv4_family,   $ipv4_family ],
    [ 'Binary private IPv4',            $bin_ipv4_private,      undef,  $ipv4_family,   0 ],
    [ 'Binary loopback IPv4',           $bin_ipv4_loopback,     undef,  0,              0 ],
    [ 'Hexadec public IPv4',            '08080808',             undef,  $ipv4_family,   $ipv4_family ],
    [ 'Hexadec private IPv4',           '0a000001',             undef,  $ipv4_family,   0 ],
    [ 'Hexadec loopback IPv4',          '7f000001',             undef,  0,              0 ],
    [ 'Decimal public IPv4',            '134744072',            undef,  $ipv4_family,   $ipv4_family ],
    [ 'Decimal private IPv4',           '167772161',            undef,  $ipv4_family,   0 ],
    [ 'Decimal loopback IPv4',          '2130706433',           undef,  0,              0 ],
    [ 'Binary IPv6',                    $bin_ipv6_doc,          undef,  $ipv6_family,   $ipv6_family ],
    [ 'Hexadecimal IPv6',
        '20010db8000000000000000000000001',
        undef,
        $ipv6_family,
        $ipv6_family,
    ],
    [
        'Decimal IPv6',
        '42540766411282592856903984951653826561',
        undef,
        $ipv6_family,
        $ipv6_family,
    ],
    [
        'Hexadecimal IPv4 CIDR',
        '08080808/24',
        undef,
        $ipv4_family,
        $ipv4_family
    ],
    [
        'Binary prefix zero disabled',
        "$bin_ipv4_public/0",
        undef,
        0,
        0 ],
    [
        'Binary prefix zero enabled',
        "$bin_ipv4_public/0",
        { allow_prefix_zero => 1 },
        $ipv4_family,
        $ipv4_family,
    ],
    [
        'Forced hexadecimal override',
        $bin_ipv4_zero,
        { input_format => 'hex' },
        $ipv6_family,
        $ipv6_family,
    ],
    [
        'Forced decimal rejects leading zero',
        '00000001',
        { input_format => 'decimal' },
        0,
        0,
    ],
    [
        'Forced binary rejects hexadecimal',
        'c0000201',
        { input_format => 'binary' },
        0,
        0,
    ],
    [
        'IPv4 mapped private IPv6',
        '00000000000000000000ffff0a000001',
        undef,
        $ipv6_family,
        $ipv6_family,
    ],
    [
        'IPv4 mapped loopback IPv6',
        '00000000000000000000ffff7f000001',
        undef,
        0,
        0,
    ],
    [
        'Invalid format name',
        '8.8.8.8',
        { input_format => 'invalid' },
        0,
        0,
    ],
);

for my $test ( @list_check_format_input )
{
    my ( $label, $ip, $opts, $cip_expect, $cccip_expect ) = @{$test};

    my $cip_actual          = ConfigServer::CheckIP::checkip( $ip, $opts );
    my $cccip_actual        = ConfigServer::CheckIP::cccheckip( $ip, $opts );

    my $cip_expect_text     = "$res_str_family{$cip_expect} ($cip_expect)";
    my $cccip_expect_text   = "$res_str_family{$cccip_expect} ($cccip_expect)";

    my $cip_actual_text     = exists( $res_str_family{$cip_actual} )
                                ? "$res_str_family{$cip_actual} ($cip_actual)"
                                : "Unexpected value ($cip_actual)";
    my $cccip_actual_text   = exists( $res_str_family{$cccip_actual} )
                                ? "$res_str_family{$cccip_actual} ($cccip_actual)"
                                : "Unexpected value ($cccip_actual)";

    my $opts_text           = !defined( $opts )
                                ? 'Auto'
                                : join(
                                    ', ',
                                    map { "$_ = $opts->{$_}" } sort keys( %{$opts} ),
                                );

    is( $cip_actual,    $cip_expect,    "$label: checkip() expects $cip_expect_text" );
    is( $cccip_actual,  $cccip_expect,  "$label: cccheckip() expects $cccip_expect_text" );

    note(
        _note_field( 'Test', $label ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field( 'Options', $opts_text ) . "\n" .
        _note_field(
            'checkip',
            "Expect:    $cip_expect_text\nActual:    $cip_actual_text",
        ) . "\n" .
        _note_field(
            'cccheckip',
            "Expect:    $cccip_expect_text\nActual:    $cccip_actual_text",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › Scalarrefs
#   
#   Test scalarrefs with binary, hexadecimal, and decimal IPs.
#   
#   IPs accepted by checkip() and cccheckip() will return family value
#   0, 4, or 6.
#   
#   Will then replace the ref with the IP converted from hex/dec/bin
#   to a plain text IP (x.x.x.x)
#   
#   If family value '0' returned; remain unchanged.
# #

# #
#   CheckIP.t › Tests › Scalarrefs (Note)
#   
#   @note       I've changed this multiple times. A few notes about
#               how the new structure works. I'll forget later.
#   
#   Subs checkip() and cccheckip() only return an IP's family int:
#       0   Reject
#       4   Accept IPv4 addr
#       6   Accept IPv6 addr
#   
#   Use scalarref to get both the IP family, AND the plain text IP
#   that was converted from hex/bin/dec. 
#   
#   Pass \$ip to checkip() or cccheckip() to create a ref to $ip.
#   The checkip subs receive that ref \$ip in $ipin:
#       my $ip      = "134744072";          # decimal of 8.8.8.8
#       my $family  = checkip( \$ip );      # returns 0,4,6
#   
#   One of two routes are taken:
#       checkip( \$ip ) => checkip( $ipin )   => _checkip_validate( $ipin ) => addr_parse( $value )
#       checkip( \$ip ) => cccheckip( $ipin ) => _checkip_validate( $ipin ) => addr_parse( $value )
#   
#   If the IP is accepted (family int of 4 or 6), $ip transformed from
#   decimal IP to plain text notation.
# #

# #
#   $label, $sub_name, $ip, $opts, $family_expect, $value_expect
# #

my @list_check_format_scalarref =
(
    [
        'checkip binary public',
        'checkip',
        $bin_ipv4_public,
        undef,
        $ipv4_family,
        '8.8.8.8',
    ],
    [
        'cccheckip hexadecimal public',
        'cccheckip',
        '08080808',
        undef,
        $ipv4_family,
        '8.8.8.8',
    ],
    [
        'checkip decimal IPv6',
        'checkip',
        '42540766411282592856903984951653826561',
        undef,
        $ipv6_family,
        '2001:db8::1',
    ],
    [
        'cccheckip binary private',
        'cccheckip',
        $bin_ipv4_private,
        undef,
        0,
        $bin_ipv4_private,
    ],
    [
        'checkip hexadecimal loopback',
        'checkip',
        '7f000001',
        undef,
        0,
        '7f000001',
    ],
);

for my $test ( @list_check_format_scalarref )
{
    my ( $label, $sub_name, $ip, $opts, $family_expect, $value_expect ) = @{$test};

    my $sub_ref         = ConfigServer::CheckIP->can( $sub_name );
    my $value_actual    = $ip;
    my $family_actual   = $sub_ref->( \$value_actual, $opts );
    my $family_text     = "$res_str_family{$family_expect} ($family_expect)";

    is(
        $family_actual,
        $family_expect,
        "$label: $sub_name() expects $family_text",
    );

    is(
        $value_actual,
        $value_expect,
        "$label: $sub_name() stores expected scalarref value",
    );

    note(
        _note_field( 'Sub', "$sub_name( )" ) . "\n" .
        _note_field( 'Test', $label ) . "\n" .
        _note_field( 'IP Before', $ip ) . "\n" .
        _note_field(
            'Family',
            "Expect:    $family_expect\nActual:    $family_actual",
        ) . "\n" .
        _note_field(
            'IP After',
            "Expect:    $value_expect\nActual:    $value_actual",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › Net::IP All Zero Bug
#   
#   Show installed Net::IP module version and if the test system's
#   copy of Net::IP has the intip() "zero address bug".
#   
#   Some Net::IP 1.26 builds return undef from intip() for an all zero
#   IPv4 and IPv6 address, instead of 0:
#       [BUG]:
#           my $netip   = Net::IP->new( '0.0.0.0', 4 );
#           my $intip   = $netip->intip( );             # return undef
#   
#           my $netip   = Net::IP->new( '::', 6 );
#           my $intip   = $netip->intip( );             # return undef
#   
#       [FIX]:
#           my $netip   = Net::IP->new( '0.0.0.0', 4 );
#           my $intip   = $netip->intip( );             # return 0
#   
#   Report if Net::IP bug found, but don't fail, since addr_parse()
#   already addresses the bug on our own.
#   
#   Patch:      https://sources.debian.org/patches/libnet-ip-perl/1.26-4/Net-IP-1.26-rt60439.patch/
#   Ref:        https://sources.debian.org/patches/libnet-ip-perl/1.26-4/
# #

my $netip_ver = Net::IP->VERSION( );
my @netip_zero_bug;

# #
#   $label, $ip, $family
# #

for my $test (
    [ 'IPv4',   '0.0.0.0',  $ipv4_family ],
    [ 'IPv6',   '::',       $ipv6_family ],
)
{
    my ( $label, $ip, $family ) = @{$test};

    my $netip           = Net::IP->new( $ip, $family );
    my $netip_state     = defined( $netip ) ? 'Defined' : 'Undefined';
    my $netip_int       = defined( $netip ) ? $netip->intip( ) : undef;
    my $netip_int_text  = defined( $netip_int ) ? "$netip_int" : 'Undefined';

    ok( defined( $netip ), "Net::IP accepts zero $label addr" );

    my $bug_state       = !defined( $netip )
                            ? 'UNABLE TO TEST: Net::IP object was not created'
                            : !defined( $netip_int )
                                ? 'BUG FOUND: Net::IP intip() returned undef'
                                : "$netip_int" eq '0'
                                    ? 'BUG NOT FOUND'
                                    : "BUG FOUND: Net::IP intip() returned $netip_int";

    my $bug_found       = defined( $netip ) && ( !defined( $netip_int ) || "$netip_int" ne '0' );

    push( @netip_zero_bug, "$label $ip returned $netip_int_text" )
        if $bug_found;

    if ( TESTS_NETIP_BUGFAIL )
    {
        is( $netip_int_text, '0', "Net::IP intip() returns zero for all zero $label addr" );
    }

    my $parsed          = ConfigServer::CheckIP::addr_parse( $ip );
    my $parsed_int      = _parsed_field( $parsed, 'intip' );
    my $bug_test_mode   = TESTS_NETIP_BUGFAIL
                            ? 'Fail test when bug is found'
                            : 'Report bug without failing';

    is( $parsed_int, '0', "addr_parse() returns zero int for zero $label addr" );

    note(
        _note_field( 'Net::IP Ver', $netip_ver ) . "\n" .
        _note_field( 'IP', $ip ) . "\n" .
        _note_field( 'Family', "$label ($family)" ) . "\n" .
        _note_field(
            'Net::IP Obj',
            "Expect:    Defined\nActual:    $netip_state",
        ) . "\n" .
        _note_field(
            'Net::IP Int',
            "Expect:    0\nActual:    $netip_int_text",
        ) . "\n" .
        _note_field( 'Bug Status', $bug_state ) . "\n" .
        _note_field( 'Bug Test', $bug_test_mode ) . "\n" .
        _note_field(
            'Parser Int',
            "Expect:    0\nActual:    $parsed_int",
        ) . "\n" .
        " \n\n"
    );
}

# #
#   CheckIP.t › Core › Summary (Net::IP Zero Bug Notice)
#   
#   @bug        Net::IP Bug Detected
#   
#               Show a warning message to the user about this bug 
#               and the corrective action to take.
#   
#               Not the most pretty warning, but noticable.
# #

if ( @netip_zero_bug )
{
    diag(
        "\n" .
        ( '# ' x 42 ) . "\n" .
        " NET::IP ZERO ADDRESS BUG DETECTED\n" .
        ( '# ' x 42 ) . "\n\n" .
        "Installed Net::IP version: $netip_ver\n\n" .
        "Affected tests:\n" .
            join( "\n", map { "  - $_" } @netip_zero_bug ) . "\n\n" .
        "What the bug does:\n" .
        "    Net::IP->intip() returns undef for an all zero IPv4 or IPv6\n" .
        "    address. The correct integer value for both addresses is 0.\n\n" .
        "Bug Status:\n" .
        "    ConfigServer::CheckIP::addr_parse() contains its own workaround\n" .
        "    and should still return 0 for these addresses.\n\n" .
        "Manually Fix Net::IP:\n" .
        "    Apply the Net::IP RT #60439 patch or install a system package\n" .
        "    that includes the corrected intip() implementation.\n\n" .
        "Patch:\n" .
        "    https://sources.debian.org/patches/libnet-ip-perl/1.26-4/" .
        "Net-IP-1.26-rt60439.patch/\n" .
        ( '# ' x 42 ) . "\n"
    );
}

# #
#   CheckIP.t › Core › Summary (Output)
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
print STDERR "\n";

done_testing( );
