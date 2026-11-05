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
#   @updated            11.04.2026
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
    my $test_more_available = eval
    {
        require Test::More;
        Test::More->import( );
        1;
    };

    my $test_more_error = $@;
    die "Test::More module is required: $test_more_error"
        if !$test_more_available;

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

    BAIL_OUT( "Required Perl modules are unavailable:\n" . join( '', @mod_errs ) )
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

for my $sub_name ( qw( addr_parse _is_addr_loopback checkip cccheckip ) )
{
    ok(
        ConfigServer::CheckIP->can( $sub_name ),
        "ConfigServer::CheckIP provides $sub_name()",
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
    ok(
        ConfigServer::CheckIP->can( $constant_name ),
        "ConfigServer::CheckIP provides $constant_name",
    );
}

# #
#   CheckIP.t › Module › Constants
#   
#   Pull constants from CheckIP module.
# #

my $ip_length_max   = ConfigServer::CheckIP::IP_LENGTH_MAX( );
my $ipv4_bits       = ConfigServer::CheckIP::IPV4_BITS( );
my $ipv6_bits       = ConfigServer::CheckIP::IPV6_BITS( );
my $ipv4_family     = ConfigServer::CheckIP::IPV4_FAMILY( );
my $ipv6_family     = ConfigServer::CheckIP::IPV6_FAMILY( );

# #
#   CheckIP.t › Tests › addr_parse() › Valid Addresses
#   
#   All the entries below should be accepted by addr_parse().
# #

my @list_addr_valid =
(
    [ 'IPv4 addr',                  '192.0.2.10',               undef,                      4 ],
    [ 'IPv4 CIDR',                  '10.0.0.1/8',               undef,                      4 ],
    [ 'IPv4 host prefix',           "192.0.2.10/$ipv4_bits",    undef,                      4 ],
    [ 'IPv6 addr',                  '2001:db8::1',              undef,                      6 ],
    [ 'IPv6 CIDR',                  '2001:db8::1/64',           undef,                      6 ],
    [ 'IPv6 host prefix',           "2001:db8::1/$ipv6_bits",   undef,                      6 ],
    [ 'IPv6 loopback',              '::1',                      undef,                      6 ],
    [ 'IPv4 mapped IPv6',           '::ffff:192.0.2.1',         undef,                      6 ],
    [ 'IPv6 zone id',               'fe80::1%eth0',             { allow_zone_id => 1 },     6 ],
    [ 'IPv6 scope id alias',        'fe80::1%eth0',             { allow_scope_id => 1 },    6 ],
    [ 'IPv6 zone id and CIDR',      'fe80::1%eth0/64',          { allow_zone_id => 1 },     6 ],
    [ 'IPv4 zero prefix',           '0.0.0.0/0',                { allow_zero_mask => 1 },   4 ],
    [ 'IPv6 zero prefix',           '::/0',                     { allow_zero_mask => 1 },   6 ],
);

for my $test ( @list_addr_valid )
{
    my ( $label, $input, $opts, $expected_family ) = @{$test};
    my $parsed = ConfigServer::CheckIP::addr_parse( $input, $opts );

    ok( defined( $parsed ), "addr_parse() accepts $label" );

    note(
        _note_field( 'Input', $input ) . "\n" .
        _note_field( 'Address', _parsed_field( $parsed, 'address' ) ) . "\n" .
        _note_field( 'Complete', _parsed_field( $parsed, 'addr_zone_cidr' ) ) .
        " \n\n"
    );

    is(
        ref( $parsed ),
        'HASH',
        "addr_parse() returns hashref for $label",
    );

    is(
        $parsed->{family},
        $expected_family,
        "addr_parse() returns expected family for $label",
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › Invalid Input
#   
#   All the entries below should have some type of issue with them, 
#   and should be rejected by addr_parse().
#   
#   Reject missing input, refs, disabled/invalid opts, spaces, bad
#   prefixes, invalid zone IDs, and hitting length limits.
#   
#   Every test must return undef.
# #

my @list_addr_invalid =
(
    [ 'undefined input',          undef,                                undef ],
    [ 'empty input',              '',                                   undef ],
    [ 'reference input',          [],                                   undef ],
    [ 'options not hashref',      '192.0.2.10',                         [] ],
    [ 'leading space',            ' 192.0.2.10',                        undef ],
    [ 'trailing space',           '192.0.2.10 ',                        undef ],
    [ 'line break',               "192.0.2.10\n",                       undef ],
    [ 'IPv4 octet too large',     '192.0.2.256',                        undef ],
    [ 'IPv4 too few octets',      '192.0.2',                            undef ],
    [ 'IPv4 too many octets',     '192.0.2.1.5',                        undef ],
    [ 'IPv4 leading zero',        '192.0.02.10',                        undef ],
    [ 'IPv4 double zero octet',   '00.0.0.0',                           undef ],
    [ 'IPv4 leading zero octet',  '01.2.3.4',                           undef ],
    [ 'empty CIDR',               '192.0.2.10/',                        undef ],
    [ 'extra CIDR field',         '192.0.2.10/24/junk',                 undef ],
    [ 'CIDR leading zero',        '192.0.2.10/024',                     undef ],
    [ 'CIDR contains text',       '192.0.2.10/24x',                     undef ],
    [ 'IPv4 CIDR too large',      '192.0.2.10/' . ( $ipv4_bits + 1 ),   undef ],
    [ 'IPv6 CIDR too large',      '2001:db8::1/' . ( $ipv6_bits + 1 ),  undef ],
    [ 'IPv6 invalid hex',         '2001:db8::g',                        undef ],
    [ 'IPv6 compression twice',   '2001::db8::1',                       undef ],
    [ 'IPv6 bad dotted tail',     '::ffff:192.0.2',                     undef ],
    [ 'IPv6 leading colon only',  ':1',                                 undef ],
    [ 'IPv6 trailing colon only', '1:',                                 undef ],
    [ 'IPv6 triple colon',        ':::1',                               undef ],
    [ 'IPv6 too few groups',      '1:2:3:4:5:6:7',                      undef ],
    [ 'IPv6 too many groups',     '1:2:3:4:5:6:7:8:9',                  undef ],
    [ 'IPv6 group too long',      '12345::1',                           undef ],
    [ 'IPv6 dotted leading zero', '::ffff:192.0.02.1',                  undef ],
    [ 'IPv4 zero prefix disabled', '192.0.2.10/0',                      undef ],
    [ 'IPv6 zero prefix disabled', '2001:db8::1/0',                     undef ],
    [ 'zone id disabled',         'fe80::1%eth0',                       undef ],
    [ 'empty zone id',            'fe80::1%',                           { allow_zone_id => 1 } ],
    [ 'invalid zone id char',     'fe80::1%eth0!',                      { allow_zone_id => 1 } ],
    [ 'zone id too long',         'fe80::1%abcdefghijklmcsf',           { allow_zone_id => 1 } ],
    [ 'zone id leading period',   'fe80::1%.eth0',                      { allow_zone_id => 1 } ],
    [ 'zone id leading hyphen',   'fe80::1%-eth0',                      { allow_zone_id => 1 } ],
    [ 'multiple zone IDs',        'fe80::1%eth0%eth1',                  { allow_zone_id => 1 } ],
    [ 'zone id after CIDR',       'fe80::1/64%eth0',                    { allow_zone_id => 1 } ],
    [ 'zone id on global IPv6',   '2001:db8::1%eth0',                   { allow_zone_id => 1 } ],
    [ 'zone id on IPv4',          '192.0.2.1%eth0',                     { allow_zone_id => 1 } ],
    [ 'input exceeds length',     '1' x ( $ip_length_max + 1 ),         undef ],
);

for my $test ( @list_addr_invalid )
{
    my ( $label, $input, $opts ) = @{$test};
    my $parsed = ConfigServer::CheckIP::addr_parse( $input, $opts );

    is( $parsed, undef, "addr_parse() rejects $label" );

    note(
        _note_field( 'Input', defined( $input ) && !ref( $input ) ? $input : 'undef or ref' ) .
        " \n\n"
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › IPv4 Num Ranges
#   
#   Lowest and highest nums in each IPv4 range. Valid nums are 0 - 255.
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

for my $input ( @list_ipv4_octet_ranges )
{
    my $parsed = ConfigServer::CheckIP::addr_parse( $input );

    ok( defined( $parsed ), "addr_parse() accepts IPv4 octet boundary $input" );
    is( $parsed->{address}, $input,         "addr_parse() keeps IPv4 octet boundary $input" );
    is( $parsed->{family},  $ipv4_family,   "addr_parse() returns IPv4 family for $input" );
}

# #
#   CheckIP.t › Tests › addr_parse() › IPv6 Addr Formats
#   
#   Test short, full, and uppercase IPv6 addrs.
#   Return uppercase as lowercase letters.
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
    my ( $input, $expect ) = @{$test};
    my $parsed = ConfigServer::CheckIP::addr_parse( $input );

    ok( defined( $parsed ), "addr_parse() accepts IPv6 grammar $input" );
    is( $parsed->{address}, $expect,        "addr_parse() normalizes IPv6 grammar $input" );
    is( $parsed->{family},  $ipv6_family,   "addr_parse() returns IPv6 family for $input" );
}

# #
#   CheckIP.t › Tests › addr_parse() › IPv4 Details
#   
#   Process the IP assigned to $parse_ipv4. Check every detail returned
#   in the hash by addr_prase().
#   
#   Addr should be valid/private; cidr prefix correct, network ranges,
#   etc.
# #

my $parse_ipv4 = ConfigServer::CheckIP::addr_parse( '10.0.0.1/29' );

ok( defined( $parse_ipv4 ), 'addr_parse() returns IPv4 CIDR details' );
is( $parse_ipv4->{address},                 '10.0.0.1',                 'IPv4 addr is normalized' );
is( $parse_ipv4->{addr_full},               '10.0.0.1',                 'IPv4 full addr is normalized' );
is( $parse_ipv4->{addr_zone_cidr},          '10.0.0.1/29',              'IPv4 complete addr includes CIDR' );
is( $parse_ipv4->{family},                  $ipv4_family,               'IPv4 family uses module constant' );
is( $parse_ipv4->{cidr},                    29,                         'IPv4 CIDR is returned' );
is( $parse_ipv4->{zone_id},                 undef,                      'IPv4 zone id is undefined' );
is( $parse_ipv4->{iptype},                  'PRIVATE',                  'IPv4 type is returned' );
is( $parse_ipv4->{is_loopback_address},     0,                          'IPv4 private addr is not loopback' );
is( length( $parse_ipv4->{binip} ),         $ipv4_bits,                 'IPv4 binary addr has expected bits' );
is( $parse_ipv4->{reverse_ip},              '1.0.0.10.in-addr.arpa.',   'IPv4 reverse name is returned' );
is( $parse_ipv4->{intip},                   '167772161',                'IPv4 decimal addr is returned' );
is( $parse_ipv4->{addr_network_cidr},       '10.0.0.0/29',              'IPv4 network CIDR is returned' );
is( $parse_ipv4->{addr_netmask},            '255.255.255.248',          'IPv4 netmask is returned' );
is( $parse_ipv4->{addr_wildcard_mask},      '0.0.0.7',                  'IPv4 wildcard mask is returned' );
is( $parse_ipv4->{addr_first},              '10.0.0.0',                 'IPv4 first addr is returned' );
is( $parse_ipv4->{addr_first_int},          '167772160',                'IPv4 first decimal addr is returned' );
is( $parse_ipv4->{addr_last},               '10.0.0.7',                 'IPv4 last addr is returned' );
is( $parse_ipv4->{addr_last_int},           '167772167',                'IPv4 last decimal addr is returned' );
is( $parse_ipv4->{addr_range_short},        '10.0.0.0 - 10.0.0.7',      'IPv4 short range is returned' );
is( $parse_ipv4->{addr_range_full},         '10.0.0.0 - 10.0.0.7',      'IPv4 full range is returned' );
is( $parse_ipv4->{addr_range_count},        '8',                        'IPv4 range count is returned' );
is( $parse_ipv4->{bits_mask},               29,                         'IPv4 mask bits are returned' );
is( $parse_ipv4->{bits_host},               3,                          'IPv4 host bits are returned' );
is( $parse_ipv4->{is_first_address},        0,                          'IPv4 member is not first addr' );
is( $parse_ipv4->{is_last_address},         0,                          'IPv4 member is not last addr' );

note(
    _note_field( 'Input', '10.0.0.1/29' ) . "\n" .
    _note_field( 'Range', $parse_ipv4->{addr_range_short} ) . "\n" .
    _note_field( 'Count', $parse_ipv4->{addr_range_count} ) .
    " \n\n"
);

# #
#   CheckIP.t › Tests › addr_parse() › IPv6 Details
#   
#   Process the IP assigned to $parse_ipv6. Check every detail returned
#   in the hash by addr_prase().
#   
#   Both short and long addr formats should be correct, correct iptype,
#   cidr prefix are correct, etc.
# #

my $parse_ipv6 = ConfigServer::CheckIP::addr_parse( '2001:db8::1/64' );

ok( defined( $parse_ipv6 ), 'addr_parse() returns IPv6 CIDR details' );
is( $parse_ipv6->{address},                 '2001:db8::1',              'IPv6 addr uses short format' );
is(
    $parse_ipv6->{addr_full},
    '2001:0db8:0000:0000:0000:0000:0000:0001',
    'IPv6 full addr is returned',
);
is( $parse_ipv6->{addr_zone_cidr},          '2001:db8::1/64',           'IPv6 complete addr includes CIDR' );
is( $parse_ipv6->{family},                  $ipv6_family,               'IPv6 family uses module constant' );
is( $parse_ipv6->{cidr},                    64,                         'IPv6 CIDR is returned' );
is( $parse_ipv6->{zone_id},                 undef,                      'IPv6 zone id is undefined when absent' );
is( $parse_ipv6->{iptype},                  'DOCUMENTATION',            'IPv6 type is returned' );
is( $parse_ipv6->{is_loopback_address},     0,                          'IPv6 documentation addr is not loopback' );
is( length( $parse_ipv6->{binip} ),         $ipv6_bits,                 'IPv6 binary addr has expected bits' );
is(
    $parse_ipv6->{reverse_ip},
    '1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa.',
    'IPv6 reverse name is returned',
);
is(
    $parse_ipv6->{intip},
    '42540766411282592856903984951653826561',
    'IPv6 decimal addr is returned',
);
is( $parse_ipv6->{addr_network_cidr},       '2001:db8::/64',            'IPv6 network CIDR is returned' );
is(
    $parse_ipv6->{addr_netmask},
    'ffff:ffff:ffff:ffff:0000:0000:0000:0000',
    'IPv6 netmask is returned',
);
is( $parse_ipv6->{addr_wildcard_mask},      undef,                      'IPv6 wildcard mask is undefined' );
is( $parse_ipv6->{addr_first},              '2001:db8::',               'IPv6 first addr is returned' );
is(
    $parse_ipv6->{addr_first_int},
    '42540766411282592856903984951653826560',
    'IPv6 first decimal addr is returned',
);
is(
    $parse_ipv6->{addr_last},
    '2001:db8::ffff:ffff:ffff:ffff',
    'IPv6 last addr is returned',
);
is(
    $parse_ipv6->{addr_last_int},
    '42540766411282592875350729025363378175',
    'IPv6 last decimal addr is returned',
);
is(
    $parse_ipv6->{addr_range_short},
    '2001:db8:: - 2001:db8::ffff:ffff:ffff:ffff',
    'IPv6 short range is returned',
);
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
    _note_field( 'Input', '2001:db8::1/64' ) . "\n" .
    _note_field( 'Range', $parse_ipv6->{addr_range_short} ) . "\n" .
    _note_field( 'Count', $parse_ipv6->{addr_range_count} ) .
    " \n\n"
);

# #
#   CheckIP.t › Tests › addr_parse() › No CIDR
#   
#   Network fields must stay undefined if CIDR prefix not provided.
# #

my $parse_ipv4_nocidr = ConfigServer::CheckIP::addr_parse( '192.0.2.10' );

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
    is( $parse_ipv4_nocidr->{$addrparse_field}, undef, "addr_parse() leaves $addrparse_field undefined without CIDR" );
}

# #
#   CheckIP.t › Tests › addr_parse() › (Opts) Zone / Scope ID
#   
#   Tests addr_parse() option 'allow_zone_id'.
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
#   
#   Both options / aliases should enable including zone / scope id:
#       - allow_zone_id
#       - allow_scope_id
# #

for my $opt_name ( qw( allow_zone_id allow_scope_id ) )
{
    my $parsed = ConfigServer::CheckIP::addr_parse(
        'fe80::1%eth0/64',
        { $opt_name => 1 },
    );

    ok( defined( $parsed ), "addr_parse() accepts $opt_name" );
    is( $parsed->{zone_id},         'eth0',             "$opt_name returns zone/scope id" );
    is( $parsed->{addr_zone_cidr}, 'fe80::1%eth0/64',   "$opt_name keeps zone id and CIDR" );
}

my @list_zone_ids =
(
    'a',
    '_',
    'eth0.100',
    'csfdefghijklcsf',
);

for my $zone_id ( @list_zone_ids )
{
    my $input   = "fe80::1%$zone_id";
    my $parsed  = ConfigServer::CheckIP::addr_parse(
        $input,
        { allow_zone_id => 1 },
    );

    ok( defined( $parsed ), "addr_parse() accepts zone / scope id $zone_id" );
    is( $parsed->{zone_id},         $zone_id,   "addr_parse() returns zone / scope id $zone_id" );
    is( $parsed->{addr_zone_cidr},  $input,     "addr_parse() keeps zone / scope id $zone_id" );
}

# #
#   CheckIP.t › Tests › addr_parse() › Zero Prefix
#   
#   Test ipv4/ipv6 /0 prefix.
#       -   If option allow_zero_mask not specified, reject IP.
#       -   If option allow_zero_mask specified, allow /0
# #

for my $parse_ip ( '0.0.0.0/0', '::/0' )
{
    is(
        ConfigServer::CheckIP::addr_parse( $parse_ip ),
        undef,
        "addr_parse() rejects $parse_ip by default",
    );

    my $parsed_ip = ConfigServer::CheckIP::addr_parse(
        $parse_ip,
        { allow_zero_mask => 1 },
    );

    ok( defined( $parsed_ip ), "addr_parse() accepts enabled $parse_ip" );
    is( $parsed_ip->{intip},                '0',            "addr_parse() returns zero integer for $parse_ip" );
    is( $parsed_ip->{addr_network_cidr},    $parse_ip,      "addr_parse() returns network for $parse_ip" );
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
    my ( $input, $expect_first, $expect_last, $expect_i ) = @{$test};
    my $parsed = ConfigServer::CheckIP::addr_parse( $input );

    ok( defined( $parsed ), "addr_parse() accepts range boundary $input" );
    is(
        $parsed->{is_first_address},
        $expect_first,
        "addr_parse() returns first-address state for $input",
    );
    is(
        $parsed->{is_last_address},
        $expect_last,
        "addr_parse() returns last-address state for $input",
    );
    is(
        $parsed->{addr_range_count},
        $expect_i,
        "addr_parse() returns range count for $input",
    );
}

# #
#   CheckIP.t › Tests › addr_parse() › Loopback
#   
#   Check ipv4, ipv6, and ipv4 mapped IPv6 loopback addrs.
#       -   All ipv4 in 127.0.0.1/8 are loopback
#       -   Ipv6 ::1 is loopback
#       -   Detect ipv4 loopbacks in ipv6
#       -   Detection works with both str and hashref
#       -   Invalid input return 0, no loopback detected
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
    my ( $input, $expect ) = @{$test};
    my $parsed = ConfigServer::CheckIP::addr_parse( $input );

    ok( defined( $parsed ), "addr_parse() accepts loopback test $input" );
    is(
        $parsed->{is_loopback_address},
        $expect,
        "addr_parse() returns loopback state for $input",
    );
    is(
        ConfigServer::CheckIP::_is_addr_loopback( $input ),
        $expect,
        "_is_addr_loopback() checks string $input",
    );
    is(
        ConfigServer::CheckIP::_is_addr_loopback( $parsed ),
        $expect,
        "_is_addr_loopback() checks hashref parsed $input",
    );
}

is( ConfigServer::CheckIP::_is_addr_loopback( undef ),  0, 'loopback reject undef' );
is( ConfigServer::CheckIP::_is_addr_loopback( [] ),     0, 'loopback reject arrayref' );
is( ConfigServer::CheckIP::_is_addr_loopback( {} ),     0, 'loopback reject invalid hashref' );

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
    my ( $input, $expect ) = @{$test};
    my $parsed = ConfigServer::CheckIP::addr_parse( $input );

    ok( defined( $parsed ), "addr_parse() accepts reverse test $input" );
    is( $parsed->{reverse_ip}, $expect, "addr_parse() returns reverse name for $input" );
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

for my $input ( @list_ipv6_rdns )
{
    my $parsed  = ConfigServer::CheckIP::addr_parse( $input );
    my $hex     = $parsed->{addr_full};
    $hex        =~ s/://g;

    my $expect = join( '.', reverse( split( //, $hex ) ), 'ip6', 'arpa.' );

    ok( defined( $parsed ), "addr_parse() accepts IPv6 reverse test $input" );
    is( $parsed->{reverse_ip}, $expect, "addr_parse() returns IPv6 reverse name for $input" );
}

# #
#   CheckIP.t › Tests › addr_parse() › CIDR Prefixes
#   
#   Test possible CIDR prefixes for v4 and v6.
#       -   Verify ipv4 prefix /0 - /32
#       -   Verify ipv6 prefix /0 - /128
#       -   Each prefix returns correct family label.
#       -   Mask and host bits correct.
#       -   Binary addrs correct:
#               IPv4:   32 bits
#               IPv6:   128 bits
#       -   CIDR range and total addr count correct.
#       -   /0 works only when opt allow_zero_mask specified.
# #

for my $case (
    [ 'IPv4', '203.0.113.129', $ipv4_bits, $ipv4_family ],
    [ 'IPv6', '2001:db8:abcd:1234:5678:9abc:def0:1234', $ipv6_bits, $ipv6_family ]
)
{
    my ( $label, $address, $bit_count, $family ) = @{$case};

    subtest "$label CIDR prefixes" => sub
    {
        for my $cidr ( 0 .. $bit_count )
        {
            my $parsed = ConfigServer::CheckIP::addr_parse(
                "$address/$cidr",
                { allow_zero_mask => 1 },
            );

            ok( defined( $parsed ), "$label /$cidr parses" );
            is( $parsed->{family},              $family,            "$label /$cidr family" );
            is( $parsed->{bits_mask},           $cidr,              "$label /$cidr mask bits" );
            is( $parsed->{bits_host},           $bit_count - $cidr, "$label /$cidr host bits" );
            is( length( $parsed->{binip} ),     $bit_count,         "$label /$cidr binary bits" );

            my $expect_i = Math::BigInt->new( 2 ) ->bpow( $bit_count - $cidr ) ->bstr( );
            is( $parsed->{addr_range_count},    $expect_i,          "$label /$cidr range count" );
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

my @list_twice_addr =
(
    [ '192.0.2.129/25',                                 {} ],
    [ '0.0.0.0/0',                                      { allow_zero_mask => 1 } ],
    [ '2001:db8:abcd:1234:5678:9abc:def0:1234/73',      {} ],
    [ '::/0',                                           { allow_zero_mask => 1 } ],
    [ 'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff/128',    {} ],
    [ 'fe80::1%eth0/64',                                { allow_zone_id => 1 } ],
    [ '::ffff:192.0.2.1/128',                           {} ],
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
        is(
            _parsed_field( $second, $field ),
            _parsed_field( $first, $field ),
            "round trip keeps $field for $input",
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
        my ( $res, $err, $warn ) = _runsub(
            sub
            {
                return $subrun->( $input );
            }
        );

        my $subret = defined( $res ) ? $res : 'undef';

        is( $err,       '', "$subname() does not die for $label" );
        is( $warn,      '', "$subname() does not warn for $label" );
        is( $subret,    0,  "$subname() rejects $label" );
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
    [ '::ffff:127.0.0.1',           0 ],
    [ '::ffff:127.42.10.5',         0 ],
    [ '0:0:0:0:0:ffff:7f00:1',      0 ],
    [ '192.0.2.256',                0 ],
    [ '192.0.2.10/0',               0 ],
    [ '2001:db8::1/0',              0 ],
);

for my $test ( @list_checkip )
{
    my ( $input, $expect ) = @{$test};

    is(
        ConfigServer::CheckIP::checkip( $input ),
        $expect,
        "checkip() returns expected result for $input",
    );
}

my $checkip_ipv6_ref = '2001:0db8:0000:0000:0000:0000:0000:0001/64';

is(
    ConfigServer::CheckIP::checkip( \$checkip_ipv6_ref ),
    $ipv6_family,
    'checkip() accepts scalarref IPv6 addr',
);
is( $checkip_ipv6_ref, '2001:db8::1/64', 'checkip() normalizes scalarref IPv6 addr' );

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

my @list_cccheckip =
(
    [ '8.8.8.8',                    $ipv4_family ],
    [ '8.8.8.8/1',                  $ipv4_family ],
    [ "8.8.8.8/$ipv4_bits",         $ipv4_family ],
    [ '1.1.1.1',                    $ipv4_family ],
    [ '10.0.0.1',                   0 ],
    [ '172.16.0.1',                 0 ],
    [ '192.168.1.1',                0 ],
    [ '169.254.1.1',                0 ],
    [ '224.0.0.1',                  0 ],
    [ '2001:db8::1',                $ipv6_family ],
    [ '2001:db8::1/1',              $ipv6_family ],
    [ "2001:db8::1/$ipv6_bits",     $ipv6_family ],
    [ '127.0.0.1',                  0 ],
    [ '127.42.10.5',                0 ],
    [ '::1',                        0 ],
    [ '::ffff:127.0.0.1',           0 ],
    [ '0:0:0:0:0:ffff:7f00:1',      0 ],
    [ '::ffff:10.0.0.1',            $ipv6_family ],
    [ '::ffff:172.16.0.1',          $ipv6_family ],
    [ '::ffff:192.168.1.1',         $ipv6_family ],
    [ '::ffff:169.254.1.1',         $ipv6_family ],
    [ '::ffff:8.8.8.8',             $ipv6_family ],
    [ '192.0.2.256',                0 ],
);

for my $test ( @list_cccheckip )
{
    my ( $input, $expect ) = @{$test};

    is(
        ConfigServer::CheckIP::cccheckip( $input ),
        $expect,
        "cccheckip() returns expected result for $input",
    );
}

my $cccheckip_ipv6_ref = '2001:0db8:0000:0000:0000:0000:0000:0001/64';

is(
    ConfigServer::CheckIP::cccheckip( \$cccheckip_ipv6_ref ),
    $ipv6_family,
    'cccheckip() accepts scalarref IPv6 addr',
);
is( $cccheckip_ipv6_ref, '2001:db8::1/64', 'cccheckip() normalizes scalarref IPv6 addr' );

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

my $netip_version = Net::IP->VERSION( );

for my $test (
    [ 'IPv4', '0.0.0.0',    $ipv4_family ],
    [ 'IPv6', '::',         $ipv6_family ],
)
{
    my ( $label, $input, $family ) = @{$test};
    my $netip = Net::IP->new( $input, $family );

    ok( defined( $netip ), "Net::IP accepts zero $label addr" );

    my $netip_int = defined( $netip )
        ? $netip->intip( )
        : undef;

    my $bug_state = !defined( $netip )
        ? 'unable to test'
        : defined( $netip_int )
            ? 'Bug not found'
            : 'BUG EXISTS IN NET::IP ON THIS INSTALL OF PERL!';

    note(
        _note_field( 'Net::IP Version ...... ', $netip_version ) . "\n" .
        _note_field( "$label Bug Status ...... ", $bug_state ) .
        " \n\n"
    );

    if ( TESTS_NETIP_BUGFAIL )
    {
        is(
            defined( $netip_int ) ? "$netip_int" : 'undef',
            '0',
            "Net::IP intip() returns zero for all zero $label addr",
        );
    }

    my $parsed = ConfigServer::CheckIP::addr_parse( $input );

    is(
        _parsed_field( $parsed, 'intip' ),
        '0',
        "addr_parse() returns zero integer for zero $label addr",
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
