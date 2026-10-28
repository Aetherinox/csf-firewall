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
#   Development notes and usage summary on using this module. For
#   a complete list of features, use perldoc
#       perldoc -T ConfigServer/DebugLocal.pm
#   
#   ABOUT:
#       -   Terminal Logs:      Yes
#       -   Log File:           No
#       -   Syslog:             No
#       -   Uses csf.conf:      No
#       -   Ansi Colors:        Yes
#       -   Production:         No
#       -   DEBUG Setting:      env DEBUG=X
#       -   DEBUG Levels:       0 - 4:      shows same and lower levels
#                                   5:      shows only level 5
#       -   Redaction:          0 - 4:      Redaction: Yes
#                                   5:      Redaction: No
#       -   Trigger:            ConfigServer::DebugLocal::log()
#   
#   SYNTAX OPTIONS:
#       -   Supports 2 output formats:
#               1.      Single Line Message
#               2a.     Grouped Value Pairs (Syntax 1)
#               2b.     Grouped Value Pairs (Syntax 2)
#   
#               1.  Single Line Message
#                   ConfigServer::DebugLocal::log( 1, 'info',
#                       ConfigServer::DebugLocal::log_singleize(
#                           'colon',
#                           [
#                               field_name_1    => 'Devil',
#                               field_name_2    => 'Stardust',
#                           ]
#                       ) .
#                       ' status:[single line]',
#                   );
#   
#               2a. Grouped Value Pairs (Syntax 1)
#                   ConfigServer::DebugLocal::log( 1, 'info',
#                       "field_name_1"  => "Devil",
#                       "field_name_2"  => "Stardust",
#                       "CONST_1"       => "Maiyannah"
#                   );
#   
#               2b. Grouped Value Pairs (Syntax 2)
#                   ConfigServer::DebugLocal::log( 1, 'info',
#                       "field_name_1", "Devil",
#                       "field_name_2", "Stardust",
#                       "CONST_1",      "Maiyannah"
#                   );
#   
#       -   Supports 2 separator types:
#               'colon'         key:[value]
#               'default'       key=value
#   
#               ConfigServer::DebugLocal::log( 1, 'info',
#                   ConfigServer::DebugLocal::log_singleize(
#                       'default|colon',
#                       [
#                           field_name_1    => 'Devil',
#                           field_name_2    => 'Stardust',
#                       ]
#                   ) .
#                   ' status:[single line]',
#               );
#   
#       -   Supports 2 sorting options:
#               { } hashref     Order not preserved.
#                               log_singleize() sorts names alphabetically.
#   
#               [ ] arrayref    Order preserved.
#   
#   @warn       DEBUG messages NOT written to log files.
#               Sent to STDERR through warn().
# #

=head1 NAME

C<ConfigServer::DebugLocal> - Debug messages routed to
terminal under development environments.

=head1 SYNOPSIS

=over 4

=item *

Load module:

    use ConfigServer::DebugLocal ( );

=item *

Declare subroutine with DebugLocal call:

    sub test_sub
    {
        ConfigServer::DebugLocal::log( 1, "info", "Debug message" );
    }

=item *

Run the sub with C<env DEBUG=1> to display the message:

    sudo env DEBUG=1 perl -I. -MYourModule -e 'YourModule::test_sub();'

=item *

Debug log sent to terminal:

    [1]YourModule::test_sub:42 [info] => Debug message

=back

=head1 SUMMARY

The following is a list outlining the main features of this module,
and the most important notes to take into consideration.

=over 4

=item *

Debug messages are sent to terminal through C<STDERR>.

=item *

No debug messages are written to log files or syslog;
see module C<ConfigServer::Logger>.

=item *

Implement debug by calling C<ConfigServer::DebugLocal::log()>
with a B<DEBUGLEVEL>, B<STATUS> (optional), and message:

    Eg: ConfigServer::DebugLocal::log( DEBUGLEVEL, "MESSAGE" );
        ConfigServer::DebugLocal::log( 1, "Debug message using info status" );

        ConfigServer::DebugLocal::log( DEBUGLEVEL, STATUS, "MESSAGE" );
        ConfigServer::DebugLocal::log( 1, "warn", "Debug message using warn status" );

=over 4

=item *

B<DEBUGLEVEL>:

=over 4

=over 4

=item *

C<0> - Normal logs

=item *

C<1> - Debug logs

=item *

C<2> - Verbose debug logs

=item *

C<3> - Trace debug logs

=item *

C<4> - Prolix debug logs

=item *

C<5> - Specialized logs

=back

=back

=item *

B<STATUS>:

=over 4

=over 4

=item *

C<fail> or C<0>

=item *

C<ok> or C<1>

=item *

C<warn> or C<2>

=item *

C<abort> or C<3>

=item *

C<info> or C<4> (default)

=back

=back

=back

=item *

View existing debug messages in code by prefixing each Perl test
command with C<env DEBUG=X>:

    sudo env DEBUG=X perl -I. -MYourModule -e 'YourModule::test_sub();'

=over 4

=item *

C<X> is a value from C<0> to C<5>:

    Level   Log Type            Redaction   Levels Shown
    -----   ------------------  ----------  ----------------
    0       Normal logs         Enabled     Level 0 only
    1       Debug logs          Enabled     Level 0 - 1
    2       Verbose debug logs  Enabled     Level 0 - 2
    3       Trace debug logs    Enabled     Level 0 - 3
    4       Prolix debug logs   Enabled     Level 0 - 4
    5       Specialized logs    Disabled    Level 5 only

=back

=item *

DEBUG levels C<0> - C<4>: Pass all debug messages through
C<ConfigServer::Secrets>; sensitive field names / values in debug
messages will be redacted before being sent to the terminal.

=item *

DEBUG level C<5>: Do not redact using  C<ConfigServer::Secrets>.

=item *

DEBUG level C<5>: Only show level C<5>. Messages assigned to levels 
C<0> - C<4> are hidden.

=item *

Debug messages have ansi colors and formatting codes when output.

=item *

The C<DEBUG> setting in C</etc/csf/csf.conf> does NOT control debug
output from this module.

=item *

Debug lines can be formatted in one of two styles:

=over 4

=over 4

=item 1.

B<Single Line Messages>

=item 2.

B<Grouped Name/Value Pairs>

=back

=back

=item *

B<STATUS> defaults to C<info> if not specified.

    ConfigServer::DebugLocal::log( 1, "Debug message using info status" );

=back

=head1 DESCRIPTION

C<ConfigServer::DebugLocal> sends CSF and LFD debug messages to the
terminal through C<STDERR> during development testing. Debug messages
can be generated by calling C<ConfigServer::DebugLocal::log()> with a
debug level, status, and message content.

When any module calls C<ConfigServer::DebugLocal::log()>, the provided
arguments define how that debug message will be processed.

    Eg: ConfigServer::DebugLocal::log( DEBUGLEVEL, STATUS, "Message" );

        sub test_sub
        {
            ConfigServer::DebugLocal::log( 1, "info", "Debug message" );
        }

B<DEBUGLEVEL>: assigns debug level to a message between C<0> - C<5>.

B<STATUS>: adds a label to each log message. Labels include C<fail>,
C<ok>, C<warn>, C<abort>, and C<info>. Label are primarily cosmetic.

    [1]Logger::_log_add:1929 [info] => Debug message
    ^^^                      ^^^^^^    ^^^^^^^^^^^^^
 DEBUGLEVEL                  STATUS       MESSAGE

To show debug messages, prefix a Perl command with C<env DEBUG=X>,
with C<X> being a value from C<0> - C<5>. Perl command must load
the module and call the subroutine containing
C<ConfigServer::DebugLocal::log()>:

    Eg: sudo env DEBUG=4 perl -I. -MYourModule -e 'YourModule::test_sub();'

Levels C<0> - C<4>: displays messages assigned to the selected level
and lower. Debug messages redact sensitive fields using the module 
C<ConfigServer::Secrets>.

Level C<5>: displays only messages explicitly assigned to level C<5>.
Intentionally skips redaction.

The C<DEBUG> setting in C</etc/csf/csf.conf> does not affect this
module.

When you call the custom subroutine with a test Perl command, the
debug message will show in terminal:

    [1]test_sub:123 [info] => Debug message

Debug output includes single line messages or grouped name/value
pairs. Each message has ansi color and formatting codes and displays
the debug level, calling sub, source line, and status label. Status
labels include C<fail>, C<ok>, C<warn>, C<abort>, and C<info>.

    Eg:     [1]Secrets::_secret_prepare_name:1286    [ok] => name:[TEST_PASSWORD] len:[13] max:[256] status:[ok]
            [1]Logger::_log_add:1929               [info] => path:[/var/log/lfd_root.log] line:passwd=[REDACTED] status:[append log]
            [1]Logger::logfile:851                   [ok] => process:[lfd] status:[syslog write completed]

This module does NOT write messages to log files or syslog. Use 
C<ConfigServer::Logger::logfile()> to write logs to a file.

=head1 USAGE

=over 4

=item *

Load module:

    use ConfigServer::DebugLocal ( );

=item *

Call C<ConfigServer::DebugLocal::log()> from within a test sub:

    sub test_sub()
    {
        ConfigServer::DebugLocal::log( 1, 'info',
            ConfigServer::DebugLocal::log_singleize(
                'colon',
                [
                    field_name_1    => 'Devil',
                    field_name_2    => 'Stardust',
                ]
            ) .
            ' status:[single line]',
        );
    }

=item *

Run the test sub through Perl, replace C<NewModuleName> with the
module containing C<test_sub()>:

    sudo env DEBUG=1 perl -I. -MConfigServer::DebugLocal -MConfigServer::NewModuleName -e 'ConfigServer::NewModuleName::test_sub();'

Output:

    [1]NewModuleName::test_sub:2239 [info] => field_name_1:[Devil] field_name_2:[Stardust] status:[single line]

=item *

To show debug output for an existing C<@test> command, prefix the
Perl command with C<env DEBUG=X>, x being C<0> - C<5>:

    env DEBUG=1 perl -I. -MConfigServer::DebugLocal -e 'ConfigServer::DebugLocal::log(1, q{info}, q{Test message});'

=back

=head1 EXAMPLES

=over 4

=item *

Load module:

    use ConfigServer::DebugLocal ( );

=item *

Create a level C<1> debug message using default status C<info>:

    ConfigServer::DebugLocal::log( 1, "Debug message" );

=item *

Create a level C<1> debug message using status C<warn>:

    ConfigServer::DebugLocal::log( 1, "warn", "Debug message" );

=item *

Create a specialized level C<5> debug message:

    ConfigServer::DebugLocal::log( 5, "info", "Specialized debug message" );

=item *

Create a single line message containing name/value pairs:

    ConfigServer::DebugLocal::log(
        1, "info",
        ConfigServer::DebugLocal::log_singleize(
            "colon",
            [
                field_name_1    => "Devil",
                field_name_2    => "Stardust",
            ]
        )
    );

=item *

Create a grouped name/value message:

    ConfigServer::DebugLocal::log(
        1, "info",
        "field_name_1", "Devil",
        "field_name_2", "Stardust",
        "CONST_1",      "Maiyannah"
    );

=item *

C<ConfigServer::DebugLocal::log()> accepts the following argument
combinations:

=over 4

=item *

[ 2 Args ] Debug level and message:

    ConfigServer::DebugLocal::log( 1, "Debug message" );

=item *

[ 3 Args ] Debug level, status, and message:

    ConfigServer::DebugLocal::log( 1, "warn", "Debug message" );

=item *

[ Grouped ] Debug level, status, and name/value pairs:

    ConfigServer::DebugLocal::log(
        1, "info",
        "field_name_1", "Devil",
        "field_name_2", "Stardust"
    );

=back

=item *

Show debug messages assigned to level C<1> and lower:

    sudo env DEBUG=1 perl -I. -MYourModule -e 'YourModule::test_sub();'

Show debug messages assigned to level C<5> only:

    sudo env DEBUG=5 perl -I. -MYourModule -e 'YourModule::test_sub();'

=back

=head1 COMMANDS

=over 4

=item *

Load module directly:

    sudo perl -I. ConfigServer/DebugLocal.pm

=item *

Check module for syntax errors:

    sudo perl -I. -c ConfigServer/DebugLocal.pm

=item *

Display module documentation:

    perldoc -T ConfigServer/DebugLocal.pm

=item *

Run test suite:

    Linux:      sudo prove -I. -v tests/DebugLocal.t
    Windows:    prove -Isrc -v tests/DebugLocal.t

=back

=head1 COPYRIGHT

Copyright (C) 2025-2027.

This program is free software; you may redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or (at
your option) any later version.

=cut

# #
#   Declare › Package
# #

package ConfigServer::DebugLocal;

# #
#   Declare › Use
# #

use strict;
use warnings;
use Encode ();
use Fcntl ();
use utf8 ();

# #
#	Declare › Export
# #

# use Exporter qw( import );
# our @EXPORT_OK = qw(
#    log
# );

# #
#	Declare › Version
# #

our $VERSION = 15.11;

# #
#	Declare › Colors
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
    redm                => "\e[38;5;203m",
    redd                => "\e[31m",
    purplel             => "\e[38;5;177m",
    purplem             => "\e[38;5;201m",
    purpled             => "\e[38;5;90m",
    bluel               => "\e[38;5;75m",
    bluem               => "\e[38;5;33m",
    blued               => "\e[38;5;25m",
    fucsial             => "\e[38;5;198m",
    fucsiam             => "\e[38;5;197m",
    fucsiad             => "\e[38;5;161m",
    orangel             => "\e[38;5;214m",
    orangem             => "\e[38;5;208m",
    oranged             => "\e[38;5;166m",
    yellowl             => "\e[38;5;229m",
    yellowm             => "\e[38;5;226m",
    yellowd             => "\e[38;5;220m",
    greenl              => "\e[38;5;120m",
    greenm              => "\e[32m",
    greend              => "\e[38;5;22m"
);

# #
#   Declare › Constants › Debug
#   
#   You should not need to tweak with these constant values unless
#   you are testing and know what you are doing.
#   
#   DEBUG
#       Enables detailed STDERR outputs for this module.
#       DEBUG constant accepts value from 0 to 5:
#           0       Normal logs             Secrets Redacted        Level 0 only
#           1       Normal debug logs       Secrets Redacted        Level 0 - 1
#           2       Verbose debug logs      Secrets Redacted        Level 0 - 2
#           3       Trace debug logs        Secrets Redacted        Level 0 - 3
#           4       Prolix debug logs       Secrets Redacted        Level 0 - 4
#           5       Specialized logs        No Secrets Redacted     Level 5 only
#   
#   DEBUG_TRUNCATE_CHARS_SIDE
#       Number of chars kept at both the beginning and end of a
#       truncated value.
#           Eg:     CSFEXAMPLE [...] CSFEXAMPLE
#           Eg:     [1]main:1 [info] => GROUP
#                   {
#                       second_name:    SECOND_VALUE_START_ [...] _SECOND_VALUE_END
#                   }
#   
#   DEBUG_TRUNCATE_NAME_CHAR_MAX
#       Max total chars displayed for a truncated grouped field
#       name, including the truncation marker.
#           Eg:     [1]main:1 [info] => GROUP
#                   {
#                       first_name [...] eeeeeeeee: First value
#                   }
#   
#   DEBUG_TRUNCATE_CHAR_MIN
#       Min number of chars that truncation will allow. Anything less
#       than this value will default back to this min value.
#   
#   DEBUG_TRUNCATE_CHAR_MAX
#       Max number of chars allowed before a str is truncated.
#   
#   DEBUG_SPACER_WIDTH
#       Width of log spacing between log info and message type:
#           Eg: [1]Secrets::_secret_prepare_name:1296  [SPACING]  [ok] => name:[API_KEY] len:[7] max:[256] status:[ok]
#   
#   DEBUG_DUMP_NEST_MAX
#       Max nesting depth allowed by dump()
#   
#   DEBUG_ITEM_MAX
#       Max total values allowed in one dump()
#   
#   @note       CSF 'pre-commit' git hook automatically checks to
#               ensure const DEBUG = 0 before it will allows a git
#               commit.
#   
#   @test       Note:           Manually override DEBUG constant
#               Command:        sudo env DEBUG=5 perl -I. -MConfigServer::DebugLocal -e 'ConfigServer::DebugLocal::log(5, q{info}, q{uid}, 974, q{gid}, 974, q{details}, q{before:[allow_root_own=0, gid=undef, mode=384, uid=974]});'
#   
#               Note:           View preview of DEBUG_TRUNCATE_CHAR_MAX length
#               Command:        sudo env DEBUG=5 perl -I. -MConfigServer::DebugLocal -e '$max=ConfigServer::DebugLocal::DEBUG_TRUNCATE_CHAR_MAX(); $msg="A"x$max; print "$msg\n\nLength: ",length($msg)," chars\n";'
# #

use constant
{
    DEBUG                           => defined( $ENV{DEBUG} ) && $ENV{DEBUG} =~ /\A[0-5]\z/ ? 0 + $ENV{DEBUG} : 0,
    DEBUG_TRUNCATE_MARKER           => ' [...] ',
    DEBUG_TRUNCATE_CHARS_SIDE       => 50,
    DEBUG_TRUNCATE_NAME_CHAR_MAX    => 26,
    DEBUG_TRUNCATE_CHAR_MIN         => 9,
    DEBUG_TRUNCATE_CHAR_MAX         => 4 * 1024,
    DEBUG_SPACER_WIDTH              => 56,
    DEBUG_DUMP_NEST_MAX             => 7,
    DEBUG_ITEM_MAX                  => 256,
};

# #
#   Declare › Constants › Internal
#   
#   FILE_PERMS_MODE_MASK
#       Extract only the perm bits from a complete file mode. Also
#       ensures $mode does not contain bits outside the allowed
#       07777 range.
# #

use constant
{
    FILE_PERMS_MODE_MASK            => 07777,
};

# #
#   Declare › State › Redaction
#   
#   Prevent DEBUG messages from being sent through redaction multiple
#   times. Can cause loop recursion over and over:
#       0       Debug output runs normally
#       1       Redaction active; suppress internal debug output
# #

our $debug_redaction_active = 0;

# #
#   Declare › State › Output
#   
#   Prevent log() from running again while formatting another
#   debug message:
#       0       Debug output formatting not active
#       1       Formatting active; suppress nested debug output
# #

our $debug_output_active = 0;

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
#   DebugLocal › Log
#   
#   Prints detailed STDERR outputs for this module.
#   
#   @test       Note:           Test each DEBUG level, make sure secrets are actually redacted.
#               Command:        for level in 0 1 2 3 4 5; do printf "\nTEST DEBUG=%s  \n" "$level"; sudo env DEBUG="$level" perl -I. -MConfigServer::DebugLocal -MConfigServer::Secrets -e 'my $secret=q{my-secret-value}; { local $SIG{__WARN__}=sub{}; ConfigServer::Secrets::register_secret(q{TEST_SECRET},$secret); } ConfigServer::DebugLocal::log(0+$ENV{DEBUG},q{info},qq{single password=$secret}); ConfigServer::DebugLocal::log(0+$ENV{DEBUG},q{info},q{password},$secret);'; done
#               Result:         Should show one single str log, and one array.
#                               All redacted (except DEBUG=5)
#   
#               Note:           Test single log()
#               Command:        sudo env DEBUG=1 perl -I. -MConfigServer::DebugLocal -e 'ConfigServer::DebugLocal::log(1,"info","ConfigServer Security Firewall");'
#               Result:         [1]main:1 [info] => ConfigServer Security Firewall
#   
#               Note:           Test grouped log()
#               Command:        sudo env DEBUG=2 perl -I. -MConfigServer::DebugLocal -e 'ConfigServer::DebugLocal::log(2,"info","name_1","a","name_2","b","CONST_1","test");'
#               Result:         [2]main:1 [info] => GROUP
#                               {
#                                   name_1:     a
#                                   name_2:     b
#                                   CONSTANTS:
#                                   {
#                                       CONST_1:    test
#                                   }
#                               }
#   
#   @params     level           int         Debug level (0 - 5)
#               values          list        Message, status ||
#                                               name / value pairs
#   @return                     undef       No value
# #

sub log
{
    local $@;
    local $!;
    local $^E;
    local $?;

    # #
    #   @vars       $level      1
    #               \@values    info ConfigServer Security Firewall
    # #

    my ( $level, @values ) = @_;

    return
        if !defined( $level ) or ref( $level ) or $level !~ /\A[0-5]\z/ or !@values;

    $level = 0 + $level;

    return
        if ( DEBUG == 5 and $level != 5 ) or ( DEBUG != 5 and DEBUG < $level );

    # #
    #   @warn       $debug_redaction_active
    #                   1 = log() redaction already running.
    #                       prevent debug messages from starting
    #                       redaction again, otherwise we get endless
    #                       nested loops
    #                   0 = log() redaction not running.
    #               
    #               $debug_output_active
    #                   1 = log() already formatting output.
    #                       prevent new log() call from starting before
    #                       first one finishes
    #                   0 = log() output formatting not active.
    # #

    return
        if $debug_redaction_active or $debug_output_active;

    local $debug_output_active = 1;

  # my $caller      = ( caller( 0 ) )[ 3 ] // 'main';   #log
    my $caller      = ( caller( 1 ) )[ 3 ] // 'main';
    my $line_number = ( caller( 0 ) )[ 2 ] // 0;
    my $status      = 'info';

    if ( @values > 1 && defined( $values[ 0 ] ) && !ref( $values[ 0 ] ) )
    {
        my $requested_status = lc( "$values[ 0 ]" );
        if ( exists( $STATUS_MAP{$requested_status} ) )
        {
            shift @values;
            $status = $STATUS_MAP{$requested_status};
        }
    }

    # #
    #   @vars       $caller             ConfigServer::DebugLocal::log
    #               $caller_short       DebugLocal::log
    # #

    my $caller_short    = $caller;
    $caller_short       =~ s/\A[^:]+:://;
    my $status_label    = "[$status]";

    my $header_plain    = "[$level]$status_label$caller_short:$line_number";
    my $header_padding  = ' ' x ( length( $header_plain ) < DEBUG_SPACER_WIDTH
                            ? DEBUG_SPACER_WIDTH - length( $header_plain )
                                : 1
    );

    my $header  =   $C{bluem}       . "[$level]"    . $C{reset} .
                    $C{yellowm}     . $caller_short . $C{reset} .
                    $C{greyl}       . ":"           . $C{reset} .
                    $C{fucsial}     . $line_number  . $C{reset};

    # #
    #   Type 1: Single Line Message
    #   
    #   @eg         [1]DebugLocal::log:1580 [ok] => name:[API_KEY] len:[7] max:[256] status:[ok]
    # #

    if ( @values == 1 )
    {
        my $msg = !defined( $values[ 0 ] )
                    ? 'undef'
                    : ref( $values[ 0 ] )
                        ? ref( $values[ 0 ] )
                        : "$values[ 0 ]";

        # #
        #   Redact fields and secrets before adding ansi colors.
        #   Running redaction after this point would remove the colors.
        #   
        #   @warn       DEBUG level 5:      disable redactions
        #               DEBUG level 0-4:    enable redactions
        # #

        if ( DEBUG != 5 )
        {
            my $redact_ok = eval
            {
                local $debug_redaction_active = 1;
                require ConfigServer::Secrets;

                $msg = ConfigServer::Secrets::redact_obj_log( $msg );
                defined( $msg ) and !ref( $msg );
            };

            # redact failed; don't print output
            return
                if !$redact_ok;
        }

        # #
        #   Redaction has to run on the original text before controls,
        #   line breaks, or other chars are changed.
        #       Eg: \e[5mBLINK\e[0m => BLINK
        #   
        #   Limit the redacted result before termimal cleanup / colors.
        #       Eg: AAAAAAAAAAAAAA => AAAA [...] AAAAA
        #   
        #   @test       Note:           Force long string, add unsafe blink
        #               Command:        sudo env DEBUG=1 perl -I. -MConfigServer::DebugLocal -e '$msg=("A"x17000)."\e[5mBLINK\e[0m"; ConfigServer::DebugLocal::log(1,"info",$msg);' | cat -v
        #               Uncleaned:      perl -e '$msg=("A"x17000)."\e[5mBLINK\e[0m"; print "$msg\n";' | cat -v
        #                               AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA^[[5mBLINK^[[0m
        #               Result:         [1]main:1   [info] => AAAAAAAAAAAAAAAAA [...] AAAAAAAAAAAAAAAAAABLINK
        # #

        $msg = _text_truncate( $msg );
        $msg = _text_terminal_clean( $msg, 1 );

        my $msg_clr         = $C{white};
        my $bracket_depth   = 0;

        # #
        #   Placing square [ brackets ] in a messsage can screw
        #   up colors.
        #   
        #   Process one char at a time to fix bracket colors.
        # #

        while ( length( $msg ) )
        {
            # copy complete ansi color code without treating [ as text
            if ( $msg =~ s/\A(\x{001B}\[[0-?]*[ -\/]*m)// )
            {
                $msg_clr .= $1;
                next;
            }

            my $char = substr( $msg, 0, 1, '' );
            if ( $char eq '[' )
            {
                $bracket_depth++;

                $msg_clr .=
                    ( $bracket_depth == 1 ? $C{greym} : $C{white} ) .
                    '[' .
                    $C{orangem};

                next;
            }

            if ( $char eq ']' and $bracket_depth > 0 )
            {
                # close bracket using matching color
                $msg_clr .=
                    ( $bracket_depth == 1 ? $C{greym} : $C{white} ) .
                    ']';

                $bracket_depth--;

                $msg_clr .= $bracket_depth > 0
                    ? $C{orangem}
                    : $C{white};

                next;
            }

            $msg_clr .= $char;
        }

        $msg    = $msg_clr . $C{reset};
        $msg    = Encode::encode_utf8( $msg )
                    if utf8::is_utf8( $msg );

        # #
        #   Type 1: Output
        # #

        my $out =
            $header .
            ' ' .
            $C{reset} .
            $header_padding .
            $STATUS_CLR{ lc( $status ) } .
            $status_label .
            $C{reset} .
            $C{greyl} . ' => ' . $C{reset} .
            $msg .
            "\n";

        $out = _text_terminal_clean( $out, 1, 1 );
        warn( $out );

        return;
    }

    # #
    #   Type 2: Grouped Name/Value Pairs
    #   
    #   @eg         [2]main:1 [info] => GROUP
    #               {
    #                   field_name_1:   value_1
    #                   field_name_2:   value_2
    #                   CONSTANTS:
    #                   {
    #                       CONST_1:    test
    #                   }
    #               }
    # #

    my $out =
        $header .
        ' ' .
        $header_padding .
        $STATUS_CLR{ lc( $status ) } .
        $status_label .
        $C{reset} .
        $C{greyl} . ' => ' . $C{reset} .
        "GROUP" .
        "\n{\n";

    my $item_i  = 0;
    my @consts;

    while ( @values )
    {
        if ( $item_i >= DEBUG_ITEM_MAX )
        {
            $out .= "    [limit reached]\n";
            last;
        }

        $item_i++;
        my $name = shift @values;

        if ( defined( $name ) and $name =~ /\A(?:\r\n|\r|\n)+\z/ )
        {
            $out .= "\n";
            next;
        }

        # #
        #   @vars       $name           field name; secrets redacted in next step
        #               $value_raw      field value; secrets never redacted
        #               $value          field value; secrets redacted in next step
        # #

        $name           = !defined( $name ) ? 'undef'
                            : ref( $name ) ? ref( $name )
                                : "$name";

        my $value_raw   = shift @values;
        my $value       = !defined( $value_raw ) ? 'undef'
                            : ref( $value_raw ) ? ref( $value_raw )
                                : "$value_raw";

        if ( DEBUG != 5 )
        {
            my $redact_ok = eval
            {
                local $debug_redaction_active = 1;
                require ConfigServer::Secrets;

                $value  = ConfigServer::Secrets::redact_obj_log( $value );              # secrets in field value
                $value  = ConfigServer::Secrets::redact_obj_field( $name, $value );
                $name   = ConfigServer::Secrets::redact_obj_log( $name );               # secrets in field name

              # warn( "[name]: $name [before]: $value_raw [after]: $value\n" );

                defined( $name ) and !ref( $name ) and defined( $value ) and !ref( $value );
            };

            # redaction failed; don't print output
            return
                if !$redact_ok;
        }

        # clean before truncating
        $name   = _text_terminal_clean( $name, 1 );
        $value  = _text_terminal_clean( $value, 1 );

        # truncate each line; first X chars [...] last X chars
        my $value_len_max   = DEBUG_TRUNCATE_CHARS_SIDE * 2 + length( DEBUG_TRUNCATE_MARKER );
        $name               = _text_truncate( $name, DEBUG_TRUNCATE_NAME_CHAR_MAX );

        $value = join( "\n",
            map
            {
                _text_truncate( $_, $value_len_max )
            }
            split( /\n/, $value, -1 )
        );

        my $display     = utf8::is_utf8( $value ) ? Encode::encode_utf8( $value ) : $value;
        my $is_step     = lc( $name ) eq 'step';
        my $is_constant = $name =~ /\A[A-Z][A-Z0-9_]*\z/;
        if ( $is_constant )
        {
            push @consts, [ $name, $display ];
            next;
        }

        # #
        #   Encode label before adding it to the byte output. 
        #   
        #   Prevents encoded values from being encoded a second time,
        #   when field names have wide utf8 chars
        # #

        my $label   = ( $is_step ? ucfirst( $name ) : $name ) . ':';
        $label      = Encode::encode_utf8( $label )
                        if utf8::is_utf8( $label );

        $out .= sprintf(
            "    %-28s%s%s\n",
            $label,
            $display,
            $C{reset},
        );
    }

    # #
    #   Type 2: Constants
    #   
    #   Print all constants in a sub group with the label 'CONSTANTS'. To add
    #   a new const, all letters should be in CAPS.
    #   
    #   @eg         ConfigServer::DebugLocal::log( 1, 'info',
    #                   "field_name_1"  => "value_1",
    #                   "field_name_2"  => "value_2",
    #                   "CONST_1"       => "test"
    #               );
    # #

    if ( @consts )
    {
        $out .=
            "    " .
            $C{greyl} .
            "CONSTANTS:" .
            $C{reset} .
            "\n";

        $out .=
            "    " .
            $C{fucsial} .
            "{" .
            $C{reset} .
            "\n";

        for my $const ( @consts )
        {
            my ( $name, $display ) = @{$const};

            $out .= sprintf(
                "        %-24s%s%s\n",
                "$name:",
                $display,
                $C{reset},
            );
        }

        $out .=
            "    " .
            $C{fucsial} .
            "}" .
            $C{reset} .
            "\n";
    }

    # #
    #   Final cleanup
    # #

    $out .= $C{reset} . "}\n\n";
    $out = _text_terminal_clean( $out, 1, 1 );

    # #
    #   Type 2: Output
    # #

    warn( utf8::is_utf8( $out ) ? Encode::encode_utf8( $out ) : $out );

    return;
}

# #
#   DebugLocal › Capture Debug Output
#   
#   Capture output from DebugLocal::log(); prevents the log from
#   appearing in STDERR. Returns log message as str.
#   
#   Colors are included in captured log.
#   
#   @usage      my $output = ConfigServer::DebugLocal::log_capture( 2, 'info', 'csf' );
#               $output     [2]DebugLocal::log_capture:1969 [info] => csf
#   
#   @params     args            list        Args passed to log()
#   @return                     str         Captured warning output
# #

sub log_capture
{
    my ( @args ) = @_;
    my $out = '';

    {
        local $SIG{__WARN__} = sub
        {
            $out .= join( '', @_ );
        };

        ConfigServer::DebugLocal::log( @args );
    }

    return $out;
}

# #
#   DebugLocal › Log › Flatten
#   
#   Take multiline string, convert into single line.
#   Flattens log() output if in "grouped value pairs" format.
#   
#   Adds commas between grouped name/value fields.
#   
#   Used to make DebugLocal.t test results consume less space.
#   
#   @note       log_singleize()
#                   Build single (1) line str from fields in an
#                   arrayref or hashref.
#   
#               log_flatten()
#                   Flatten existing multiline str to one (1) line.
#   
#   @test       Note:           Flatten existing multiline str to one line
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -e 'my $value = qq{Group\n{\nfield_name_1 = Devil\nfield_name_2 = Stardust\n}\n}; print ConfigServer::DebugLocal::log_flatten($value), qq{\n};'
#               Result:         Group { field_name_1 = Devil, field_name_2 = Stardust }
#   
#   @params     value           scalar      Formatted debug output
#   @return                     str         Debug output on one line
# #

sub log_flatten
{
    my ( $value ) = @_;

    return 'undef'
        if !defined( $value );

    return ref( $value )
        if ref( $value );

    $value =~ s/\r\n?/\n/g;

    my @lines;
    for my $line ( split( /\n/, $value, -1 ) )
    {
        $line =~ s/\s+/ /g;
        $line =~ s/\A\s+|\s+\z//g;

        push @lines, $line
            if length( $line );
    }

    return ''
        if !@lines;

    my $out = shift @lines;

    for my $line ( @lines )
    {
        if ( $line eq '{' )
        {
            $out .= ' {';
        }
        elsif ( $line eq '}' )
        {
            $out .= ' }';
        }
        elsif ( $out =~ /\{\z/ )
        {
            $out .= " $line";
        }
        else
        {
            $out .= ", $line";
        }
    }

    return $out;
}

# #
#   DebugLocal › Singleize
#   
#   Take multiline input (arrayref or hashref) of fields, and
#   convert / compress to single line.
#   
#   Field seperator can be changed via the first param $style:
#       colon, default
#   
#   Seperators:
#       colon   key:[value]
#                   Struct:     fields separated by spaces
#                   Eg:         ConfigServer::DebugLocal::log( 1, 'info',
#                               ConfigServer::DebugLocal::log_singleize(
#                                   'colon',
#                                   [
#                                       gid     => '123',
#                                       mode    => '384',
#                                       path    => '/tmp/test',
#                                   ]
#                               ) .
#                               " status:[redact uid, use colon sep]" );
#                   Result:     gid:[REDACTED] mode:[384] path:[/tmp/test]
#   
#       default key=value
#                   Struct:     fields separated by commas
#                   Note:       Default option
#                   Eg:         ConfigServer::DebugLocal::log( 1, 'info',
#                               ConfigServer::DebugLocal::log_singleize(
#                                   'default',
#                                   [
#                                       gid     => '123',
#                                       mode    => '384',
#                                       path    => '/tmp/test',
#                                   ]
#                               ) .
#                               " status:[redact uid, use colon comma]" );
#                   Result:     gid=[REDACTED], mode=384, path=/tmp/test
#   
#   Lists sorted differently depending if a hashref or arrayref is used:
#       { } hashref:
#               Sort:           Order not preserved.
#                               log_singleize() sorts names alphabetically.
#               Eg:             my $hash = ConfigServer::DebugLocal::log_singleize(
#                               {
#                                   third   => 3,
#                                   first   => 1,
#                                   second  => 2,
#                               });
#               Result:         first=1, second=2, third=3
#   
#       [ ] arrayref:
#               Sort:           Order preserved.
#               Eg:             my $array = ConfigServer::DebugLocal::log_singleize(
#                               [
#                                   third   => 3,
#                                   first   => 1,
#                                   second  => 2,
#                               ]);
#               Result:         third=3, first=1, second=2
#   
#   @note       log_singleize()
#                   Build single (1) line str from fields in an
#                   arrayref or hashref.
#   
#               log_flatten()
#                   Flatten existing multiline str to one (1) line.
#   
#   @test       Note:           Singleize arrayref with colon style
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -e 'my $value = ConfigServer::DebugLocal::log_singleize(q{colon}, [field_name_1 => q{Devil}, field_name_2 => q{Stardust}]); print $value, qq{\n};'
#               Result:         field_name_1:[Devil] field_name_2:[Stardust]
#   
#               Note:           Singleize arrayref with default style
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -e 'my $value = ConfigServer::DebugLocal::log_singleize(q{default}, [field_name_1 => q{Devil}, field_name_2 => q{Stardust}]); print $value, qq{\n};'
#               Result:         field_name_1=Devil, field_name_2=Stardust
#   
#   @params     style           str                 Style format, eg: 'colon', 'default'
#               opts            hashref|arrayref    Name / value pairs to format
#   @return                     str                 Fields compressed to one line
# #

sub log_singleize
{
    local $@;
    local $!;
    local $^E;
    local $?;

    my ( $style, $opts ) = @_;

    if ( @_ == 1 )
    {
        $opts   = $style;
        $style  = '';
    }

    return "(invalid)"
        if ref( $style );

    $style = ''
        if !defined( $style ) or $style eq 'default';

    return "(invalid)"
        if $style ne '' and $style ne 'colon';

    # #
    #   Sorting: { } Hashref (use alphabetical order)
    # #

    my @pairs;
    if ( ref( $opts ) eq 'HASH' )
    {
        return "(none)"
            if !keys( %{$opts} );

        return "(invalid)"
            if keys( %{$opts} ) > DEBUG_ITEM_MAX;

        for my $name ( sort keys( %{$opts} ) )
        {
            push @pairs, $name, $opts->{$name};
        }
    }

    # #
    #   Sorting: [ ] Arrayref (preserve defined order)
    # #

    elsif ( ref( $opts ) eq 'ARRAY' )
    {
        return "(none)"
            if !@{$opts};

        return "(invalid)"
            if @{$opts} % 2;

        return "(invalid)"
            if @{$opts} / 2 > DEBUG_ITEM_MAX;

        @pairs = @{$opts};
    }

    # #
    #   No hashref or arrayref
    # #

    else
    {
        return "(invalid)";
    }

    my @fields;
    my $out_len = 0;
    while ( @pairs )
    {
        my $name    = shift( @pairs );
        my $value   = shift( @pairs );

        return "(invalid)"
            if !defined( $name ) or ref( $name );

        $name       = "$name";
        $value      = !defined( $value ) ? "undef"
                        : ref( $value ) ? ref( $value )
                            : "$value";

        $name   = _text_utf8_bytes( $name );
        $value  = _text_utf8_bytes( $value );

        # #
        #   Keep each name/value field unchanged until redaction runs.
        #   
        #   Cleaning or shortening it first could stop a registered
        #   secret from matching.
        #   
        #   DEBUG 0 - 4:    replace oversized field instead of shortening
        #   DEBUG 5:        skip redaction, so field can be shortened
        # #

        my $field_len = length( $name ) + length( $value ) + ( $style eq 'colon' ? 3 : 1 );
        my $field;
        if ( $field_len > DEBUG_TRUNCATE_CHAR_MAX )
        {
            if ( DEBUG == 5 )
            {
                $name   = _text_truncate( $name );
                $value  = _text_truncate( $value );
                $field  = $style eq 'colon'
                            ? $name . ':[' . $value . ']'
                                : $name . '=' . $value;
                $field  = _text_truncate( $field );
            }
            else
            {
                $field  = '[DEBUG VALUE TOO LARGE]';
            }
        }
        else
        {
            $field      = $style eq 'colon'
                            ? $name . ':[' . $value . ']'
                                : $name . '=' . $value;
        }

        my $separator_len = @fields ? length( $style eq 'colon' ? ' ' : ', ' ) : 0;
        if ( $out_len + $separator_len + length( $field ) > DEBUG_TRUNCATE_CHAR_MAX )
        {
            push @fields, '[DEBUG OUTPUT LIMIT REACHED]';
            last;
        }

        push @fields, $field;
        $out_len += $separator_len + length( $field );
    }

    my $out = join( $style eq 'colon' 
            ? ' '
                : ', ',
        @fields,
    );

    # #
    #   @warn       DEBUG 5 returns unredacted strings. No production
    #               install will ever have this enabled, and this
    #               only works under specific conditions.
    #   
    #               This is NOT controlled by CSF's csf.conf DEBUG
    #               setting. This module has its own independent
    #               DEBUG env variable passed via perl command.
    #   
    #   @test       Note:           Compare redactions in singleize for debug level 4 vs 5
    #               Command:        for level in 4 5; do printf 'DEBUG=%s: ' "$level"; sudo env DEBUG="$level" perl -I. -MConfigServer::DebugLocal -MConfigServer::Secrets -e 'my $secret=q{csf-secret-name}; { local $SIG{__WARN__}=sub{}; ConfigServer::Secrets::register_secret(q{DEBUG_TEST_SECRET},$secret); } print ConfigServer::DebugLocal::log_singleize([q{value},qq{secret-$secret-\e[5mBLINK\e[0m},q{uid},q{1000}]),qq{\n};'; done
    #               Result:         DEBUG=4:    value=secret-[REDACTED]-BLINK, uid=[REDACTED]
    #                               DEBUG=5:    value=secret-csf-secret-name-BLINK, uid=1000
    # #

    if ( DEBUG == 5 )
    {
        $out = _text_terminal_clean( $out, 0 );
        return _text_truncate( $out );
    }

    return "(redaction active)"
        if $debug_redaction_active;

    my $redact_ok;
    {
        local $@;
        local $!;
        local $^E;
        local $?;

        $redact_ok = eval
        {
            local $debug_redaction_active = 1;
            require ConfigServer::Secrets;

            $out = ConfigServer::Secrets::redact_obj_log( $out );
            defined( $out ) and !ref( $out );
        };
    }

    return "(redaction failed)"
        if !$redact_ok;

    $out = _text_terminal_clean( $out, 0 );
    return _text_truncate( $out );
}

# #
#   DebugLocal › Dump
#   
#   Format values into a human readable debug dump.
#   
#   Dumbed down version of perl's Data::Dumper, with a few extra
#   features.
#   
#   @test       Note:           Test escapes; bypass truncation
#               Ref:            https://www.unicode.org/charts/charindex.html
#                                   (Website only works with 4 digit unicode for command below)
#               Command:        sudo env DEBUG=5 perl -I. -MConfigServer::DebugLocal -e 'print ConfigServer::DebugLocal::dump(join("",map { chr($_) } (0x0041,0x0027,0x005c,0x001b,0x000d,0x000a,0x0009,0x0000,0x0008,0x000b,0x000c,0x007f,0x0042)),join("",map { chr($_) } (0x0041,0x061c,0x200e,0x200f,0x2028,0x2029,0x202a,0x202b,0x202c,0x202d,0x0042)),join("",map { chr($_) } (0x0041,0x202e,0x2066,0x2067,0x2068,0x2069,0x0042)));'
#               Result:         Dump = [
#                                   'A\'\\\e\r\n\t\x{0000}\x{0008}\x{000B}\x{000C}\x{007F}B',
#                                   'A\x{061C}\x{200E}\x{200F}\x{2028}\x{2029}\x{202A}\x{202B}\x{202C}\x{202D}B',
#                                   'A\x{202E}\x{2066}\x{2067}\x{2068}\x{2069}B'
#                               ];
#   
#               Note:           Compare redactions in dumps for debug level 4 vs 5
#               Command:        for level in 4 5; do printf "\nDEBUG=%s\n" "$level"; sudo env DEBUG="$level" perl -I. -MConfigServer::DebugLocal -MConfigServer::Secrets -e 'my $secret=q{csf-secret-name}; { local $SIG{__WARN__}=sub{}; ConfigServer::Secrets::register_secret(q{DEBUG_TEST_SECRET},$secret); } print ConfigServer::DebugLocal::dump({q{gid}=>q{1000},q{message}=>qq{secret-$secret},q{mode}=>q{384},q{uid}=>q{1000}});'; done
#               Result:         DEBUG=4:    Dump = { 'gid' => '[REDACTED]', 'message' => 'secret-[REDACTED]', 'mode' => 384, 'uid' => '[REDACTED]' };
#                               DEBUG=5:    Dump = {
#                                               'gid'       => 1000,
#                                               'message'   => 'secret-csf-secret-name',
#                                               'mode'      => 384,
#                                               'uid'       => 1000
#                                           };
#   
#   @params     values          list        Input values to format
#   @return                     str         Formatted dump
# #

sub dump
{
    local $@;
    local $!;
    local $^E;
    local $?;

    my ( @values ) = @_;

    my $value = !@values ? undef : @values == 1 ? $values[ 0 ] : \@values;
    my $out;

    if ( DEBUG == 5 )
    {
        my $items           = 0;
        my $redact_failed   = 0;

        $out = _debug_dump_value(
            $value,
            undef,          # depth
            \$items,
            0,              # disable redactions
            undef,
            \$redact_failed,
        ) . "\n";
        
        return _text_truncate( $out );
    }

    return "Dump = '[REDACTION ACTIVE]';\n"
        if $debug_redaction_active;

    my $redact_ok = eval
    {
        local $debug_redaction_active = 1;
        require ConfigServer::Secrets;

        my $items           = 0;
        my $redact_failed   = 0;

        $out = _debug_dump_value(
            $value,
            undef,          # depth
            \$items,
            1,              # enable redactions
            undef,
            \$redact_failed,
        ) . "\n";

        $out = ConfigServer::Secrets::redact_obj_log( $out )
            if !$redact_failed;

        !$redact_failed and defined( $out ) and !ref( $out );
    };

    return "Dump = '[REDACTION FAILED]';\n"
        if !$redact_ok;

    $out = _text_terminal_clean( $out, 0, 1 );
    return _text_truncate( $out );
}

# #
#   DebugLocal › Get File::stat Info
#   
#   Convert File::stat() metadata to a readable line for the Logger 
#   module.
#   
#   Includes device id, inode, perms, links, owner, group, size.
#   
#   @warn       Does NOT redact data such as uid and gid.
#   
#   @test       Note:           Format info about /var/log
#                               Returned numbers depend on the system.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -mFile::stat -e 'my $mdata = File::stat::lstat(q{/var/log}); print ConfigServer::DebugLocal::getfstatinfo($mdata), qq{\n};'
#               Result:         file_type=directory, device=64768, inode=25561351, mode_raw=16877, mode=040755, permissions=0755, permissions_dec=493, links=20, uid=0, gid=0, rdev=0, size=20480, accessed=1792551270, modified=1792464216, changed=1792464216, block_size=4096, blocks=32
#   
#   @params     mdata           obj         File::stat metadata
#   @return     info            str         File info formatted into one str line
#                                               (none)      Metadata undef
#                                               (invalid)   Value is not a File::stat object
# #

sub getfstatinfo
{
    my ( $mdata ) = @_;

    return '(none)'
        if !defined( $mdata );

    return '(invalid)'
        if ref( $mdata ) ne 'File::stat';

    my $mode_raw        = $mdata->mode;
    my $perms_dec       = $mode_raw & FILE_PERMS_MODE_MASK;
    my $file_type       = Fcntl::S_ISREG( $mode_raw ) ? 'regular file'
                            : Fcntl::S_ISDIR( $mode_raw ) ? 'directory'
                            : Fcntl::S_ISCHR( $mode_raw ) ? 'character device'
                            : Fcntl::S_ISBLK( $mode_raw ) ? 'block device'
                            : Fcntl::S_ISFIFO( $mode_raw ) ? 'fifo'
                            : (
                                defined( &Fcntl::S_ISLNK ) and
                                Fcntl::S_ISLNK( $mode_raw )
                            ) ? 'symlink'
                            : (
                                defined( &Fcntl::S_ISSOCK ) and
                                Fcntl::S_ISSOCK( $mode_raw )
                            ) ? 'socket'
                            : 'unknown';

    return join(
        ', ',
        'file_type='        . $file_type,
        'device='           . $mdata->dev,
        'inode='            . $mdata->ino,
        'mode_raw='         . $mode_raw,
        'mode='             . sprintf( '%06o', $mode_raw ),
        'permissions='      . sprintf( '%04o', $perms_dec ),
        'permissions_dec='  . $perms_dec,
        'links='            . $mdata->nlink,
        'uid='              . $mdata->uid,
        'gid='              . $mdata->gid,
        'rdev='             . $mdata->rdev,
        'size='             . $mdata->size,
        'accessed='         . $mdata->atime,
        'modified='         . $mdata->mtime,
        'changed='          . $mdata->ctime,
        'block_size='       . $mdata->blksize,
        'blocks='           . $mdata->blocks,
    );
}

# #
#   DebugLocal › Try Redaction
#   
#   Run redaction callback and catch errors. Keep caller error state.
#   
#   Return success if callback returns a defined value that is not
#   a ref.
#   
#   @params     cb              coderef         Redaction callback
#   @return     value           scalar|undef    Callback res
#               is_ok           int             Callback err state
#                                                   1           Valid value returned
#                                                   0           Failed or invalid value
# #

sub _debug_redaction_try
{
    my ( $cb ) = @_;

    my ( $res, $is_ok );
    {
        local $@;
        local $!;
        local $^E;
        local $?;

        $is_ok = eval
        {
            $res = $cb->( );
            defined( $res ) and !ref( $res );
        };
    }

    return ( $res, $is_ok ? 1 : 0 );
}

# #
#   DebugLocal › Dump › Value
#   
#   Convert scalar, array, hash, or other objects into something
#   more human readable.
#   
#   @test       Note:           Restrict escaped output to max len
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -e '$max=ConfigServer::DebugLocal::DEBUG_TRUNCATE_CHARS_SIDE()*2+length(ConfigServer::DebugLocal::DEBUG_TRUNCATE_MARKER()); $raw=("A\n"x1000); $first=ConfigServer::DebugLocal::_text_truncate($raw,$max); $escaped=ConfigServer::DebugLocal::_text_escape_dump($first); $final=ConfigServer::DebugLocal::_text_truncate($escaped,$max); print "raw=",length($raw),", first=",length($first),", escaped=",length($escaped),", final=",length($final),", max=$max\n$final\n";'
#               Result:         raw=2000, first=107, escaped=157, final=107, max=107
#                               A\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\ [...] \nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\n
#   
#               Note:           Verify dump output: stay within max len after control chars become visible
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -e 'my $max=ConfigServer::DebugLocal::DEBUG_TRUNCATE_CHARS_SIDE()*2+length(ConfigServer::DebugLocal::DEBUG_TRUNCATE_MARKER()); my $items=0; my $failed=0; my $out=ConfigServer::DebugLocal::_debug_dump_value(("A\n"x1000),0,\$items,0,undef,\$failed); my $expected=$max+2; print "out=",length($out),", expected=$expected, failed=$failed\n$out\n";'
#               Result:         out=109, expected=109, failed=0
#                               'A\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\ [...] \nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\n'
#   
#               Note:           3 chars become 4 (1 line break is shown as 2 visible chars)
#                                   => LF becomes \n
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -e 'my $before="A\nB"; (my $after=$before)=~s/\n/\\n/g; my $before_chars=join(q{},map { $_ eq "\n" ? q{[LF]} : $_ eq "\\" ? q{[BACKSLASH]} : qq{[$_]} } split(//,$before)); my $after_chars=join(q{},map { $_ eq "\n" ? q{[LF]} : $_ eq "\\" ? q{[BACKSLASH]} : qq{[$_]} } split(//,$after)); print "before=",length($before)," chars=$before_chars hex=",unpack("H*",$before),"\n"; print "after=",length($after)," chars=$after_chars hex=",unpack("H*",$after),"\n";'
#               Result:         before=3    chars=[A][LF][B]            hex=410a42
#                               after=4     chars=[A][BACKSLASH][n][B]  hex=415c6e42
#   
#   @params     value           scalar      Input to format
#               depth           int|undef   Current nesting level (used internally)
#                                               int         Nested recursive call
#                                               undef       Initial call (starts at 0)
#   @return                     str         Formatted dump
# #

sub _debug_dump_value
{
    my ( $value, $depth, $items_ref, $redact, $field_name, $redact_failed_ref ) = @_;

    # is_root = first call / top level; start at depth 0
    my $is_root = !defined( $depth );

    my $items = 0;
    $items_ref = \$items
        if !defined( $items_ref );

    my $redact_failed = 0;
    $redact_failed_ref = \$redact_failed
        if !defined( $redact_failed_ref );

    $redact = 0
        if !defined( $redact );

    return ''
        if ${$redact_failed_ref};

    $depth = 0
        if $is_root;

    my $out;
    my $indent      = '    ' x $depth;
    my $indent_next = '    ' x ( $depth + 1 );

    ${$items_ref}++;

    if ( ${$items_ref} > DEBUG_ITEM_MAX )
    {
        $out = '...';
    }
    elsif ( $depth >= DEBUG_DUMP_NEST_MAX )
    {
        $out = '...';
    }
    elsif ( !defined( $value ) )
    {
        $out = 'undef';
    }
    elsif ( !ref( $value ) )
    {
        if ( $redact )
        {
            my ( $value_redacted, $value_redaction_ok ) =
                _debug_redaction_try(
                    sub
                    {
                        return ConfigServer::Secrets::redact_obj_log(
                            $value,
                        );
                    },
                );

            if ( !$value_redaction_ok )
            {
                ${$redact_failed_ref} = 1;
                return '';
            }

            $value = $value_redacted;

            if ( defined( $field_name ) )
            {
                my ( $field_redacted, $field_redaction_ok ) =
                    _debug_redaction_try(
                        sub
                        {
                            return ConfigServer::Secrets::redact_obj_field(
                                $field_name,
                                $value,
                            );
                        },
                    );

                if ( !$field_redaction_ok )
                {
                    ${$redact_failed_ref} = 1;
                    return '';
                }

                $value = $field_redacted;
            }
        }

        # truncate redacted value before esc chars can increase len
        $value = _text_truncate( $value, DEBUG_TRUNCATE_CHARS_SIDE * 2 + length( DEBUG_TRUNCATE_MARKER ) );
        $value = _text_escape_dump( $value );

        # truncate result value if escaping increased its len.
        $value = _text_truncate( $value, DEBUG_TRUNCATE_CHARS_SIDE * 2 + length( DEBUG_TRUNCATE_MARKER ) );

        # leave nums unquoted, wrap $value in 'single quotes'
        $out = $value =~ /\A-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?\z/ ? $value : "'$value'";
    }

    # #
    #   Hashes with sorted field names
    # #

    elsif ( ref( $value ) eq 'HASH' )
    {
        my @lines;
        my @names;

        # hash has too many fields (256), don't process anymore.
        if ( keys( %{$value} ) > DEBUG_ITEM_MAX )
        {
            push @lines,
                $indent_next . '[limit reached]';
        }

        # limit not reached, process in alphabetical order.
        else
        {
            @names = sort keys( %{$value} );
        }

        for my $name ( @names )
        {
            if ( ${$items_ref} >= DEBUG_ITEM_MAX )
            {
                push @lines, $indent_next . '[limit reached]';
                last;
            }

            my $name_display = $name;
            if ( $redact )
            {
                my ( $name_redacted, $name_redacted_ok ) =
                    _debug_redaction_try(
                        sub
                        {
                            return ConfigServer::Secrets::redact_obj_log(
                                $name_display,
                            );
                        },
                    );

                if ( !$name_redacted_ok )
                {
                    ${$redact_failed_ref} = 1;
                    return '';
                }

                $name_display = $name_redacted;
            }

            # shorten field name before esc chars can increase len
            $name_display   = _text_truncate( $name_display, DEBUG_TRUNCATE_CHARS_SIDE * 2 + length( DEBUG_TRUNCATE_MARKER ) );
            my $name_esc    = _text_escape_dump( $name_display );

            # #
            #   Shorten field name again if visible escaped text made
            #   len too long
            # #

            $name_esc = _text_truncate( $name_esc, DEBUG_TRUNCATE_CHARS_SIDE * 2 + length( DEBUG_TRUNCATE_MARKER ) );

            push @lines,
                $indent_next .
                "'$name_esc' => " .
                _debug_dump_value(
                    $value->{$name},
                    $depth + 1,
                    $items_ref,
                    $redact,
                    $name,
                    $redact_failed_ref,
                );
        }

        $out = @lines ? "{\n" . join( ",\n", @lines ) . "\n$indent}" : '{}';
    }

    # #
    #   Each value in array
    # #

    elsif ( ref( $value ) eq 'ARRAY' )
    {
        my @lines;
        for my $item ( @{$value} )
        {
            if ( ${$items_ref} >= DEBUG_ITEM_MAX )
            {
                push @lines, $indent_next . '[limit reached]';
                last;
            }

            push @lines,
                $indent_next .
                _debug_dump_value(
                    $item,
                    $depth + 1,
                    $items_ref,
                    $redact,
                    undef,
                    $redact_failed_ref,
                );
        }

        $out = @lines ? "[\n" . join( ",\n", @lines ) . "\n$indent]" : '[]';
    }

    # #
    #   Follow scalar refs, format $value
    # #

    elsif ( ref( $value ) eq 'SCALAR' or ref( $value ) eq 'REF' )
    {
        $out = '\\' . _debug_dump_value(
            ${$value},
            $depth + 1,
            $items_ref,
            $redact,
            $field_name,
            $redact_failed_ref,
        );
    }

    # #
    #   Handle GLOBs
    #   
    #   Show file handle type, state, and file number.
    #   Try to get as much info about a GLOB as possible.
    #   
    #   @test       Note:           Test GLOBs
    #               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -MFile::Temp -e 'my ($fh,$path)=File::Temp::tempfile(q{csf-debug-glob-XXXXXX},TMPDIR=>1,UNLINK=>1); print {$fh} "test\n"; print "OPEN:\n",ConfigServer::DebugLocal::dump($fh); close($fh); print "\nCLOSED:\n",ConfigServer::DebugLocal::dump($fh);'
    #               Result:         Dump = GLOB { [...], 'uid' => '[REDACTED]' }
    # #

    elsif ( ref( $value ) eq 'GLOB' )
    {
        my $file_number     = fileno( $value );

        my %glob_info =
        (
            type            => 'GLOB',
            state           => defined( $file_number ) ? 'open' : 'closed',
            file_number     => $file_number,
            glob_name       => eval { *{$value}{NAME} },
            glob_package    => eval { *{$value}{PACKAGE} },
        );

        if ( defined( $file_number ) )
        {
            my $pos                     = tell( $value );
            $glob_info{pos}             = $pos >= 0 ? $pos : 'unavailable';
            $glob_info{is_terminal}     = -t $value ? 1 : 0;

            my $flag_cmd = eval { Fcntl::F_GETFL() };
            if ( defined( $flag_cmd ) )
            {
                my $flags = fcntl( $value, $flag_cmd, 0 );

                $glob_info{flags} = 0 + $flags
                    if defined( $flags );
            }

            # stats 64768 10383391 33152 1 0 0 0 0 1791242567 1791242567 1791242567 4096 0
            my @stats = stat( $value );
            if ( @stats )
            {
                my $mode        = $stats[ 2 ];
                my $perms_dec   = $mode & FILE_PERMS_MODE_MASK;
                my $file_type   = Fcntl::S_ISREG( $mode )  ? 'regular file'
                                    : Fcntl::S_ISDIR( $mode )  ? 'directory'
                                    : Fcntl::S_ISCHR( $mode )  ? 'character device'
                                    : Fcntl::S_ISBLK( $mode )  ? 'block device'
                                    : Fcntl::S_ISFIFO( $mode ) ? 'fifo'
                                    : (
                                        defined( &Fcntl::S_ISSOCK ) and
                                        Fcntl::S_ISSOCK( $mode )
                                    ) ? 'socket'
                                    : 'unknown';

                $glob_info{file_type}       = $file_type;
                $glob_info{device}          = $stats[ 0 ];
                $glob_info{inode}           = $stats[ 1 ];
                $glob_info{mode_raw}        = $mode;
                $glob_info{mode}            = sprintf( '%06o', $mode );
                $glob_info{permissions}     = sprintf( '%04o', $perms_dec );
                $glob_info{permissions_dec} = $perms_dec;
                $glob_info{links}           = $stats[ 3 ];
                $glob_info{uid}             = $stats[ 4 ];
                $glob_info{gid}             = $stats[ 5 ];
                $glob_info{device_type}     = $stats[ 6 ];
                $glob_info{size}            = $stats[ 7 ];
                $glob_info{accessed}        = $stats[ 8 ];
                $glob_info{modified}        = $stats[ 9 ];
                $glob_info{changed}         = $stats[ 10 ];
                $glob_info{block_size}      = $stats[ 11 ];
                $glob_info{blocks}          = $stats[ 12 ];
            }
        }

        $out = 'GLOB ' . _debug_dump_value(
            \%glob_info,
            $depth,
            $items_ref,
            $redact,
            undef,
            $redact_failed_ref,
        );
    }

    # #
    #   Handle obj and other ref types
    # #

    else
    {
        # $class    CSF::Test
        my $class = ref( $value );

        if ( $redact )
        {
            my ( $class_redacted, $class_redact_ok ) =
                _debug_redaction_try(
                    sub
                    {
                        return ConfigServer::Secrets::redact_obj_log(
                            $class,
                        );
                    },
                );

            if ( !$class_redact_ok )
            {
                ${$redact_failed_ref} = 1;
                return '';
            }

            $class = $class_redacted;
        }

        $class = _text_escape_dump( $class );

        my $is_array = eval
        {
            my $index_last = $#{$value};
            1;
        };

        if ( $is_array )
        {
            my @lines;
            for my $item ( @{$value} )
            {
                if ( ${$items_ref} >= DEBUG_ITEM_MAX )
                {
                    push @lines, $indent_next . '[limit reached]';
                    last;
                }

                push @lines,
                    $indent_next .
                    _debug_dump_value(
                        $item,
                        $depth + 1,
                        $items_ref,
                        $redact,
                        undef,
                        $redact_failed_ref,
                    );
            }

            my $arr = @lines ? "[\n" . join( ",\n", @lines ) . "\n$indent]" : '[]';
            $out    = "bless( $arr, '$class' )";
        }
        else
        {
            $out    = "'$class'";
        }
    }

    return ''
        if ${$redact_failed_ref};

    return $is_root ? 'Dump = ' . $out . ';' : $out;
}

# #
#   DebugLocal › Text › Utf8 › Decode
#   
#   Decode utf8 bytes to text. Replace invalid bytes with unicode
#   replacement chars so that controls can't be hid.
#   
#   Return 1 if byte str decoded.
#   
#   Cleaned text can be converted back to utf8 bytes.
#   
#   @note       _text_utf8_decode()     Output as decoded chars
#               _text_utf8_bytes()      Output as utf8 bytes
#   
#   @test       Note:           Test utf8 byte decoding
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -MEncode -e 'for my $test ([ascii=>q{CSF}],[utf8_bytes=>pack(q{H*},q{e282ac})],[decoded_text=>chr(0x20ac)],[invalid_bytes=>pack(q{H*},q{ff})]) { my ($name,$input)=@{$test}; my ($text,$was_decoded)=ConfigServer::DebugLocal::_text_utf8_decode($input); my $output=utf8::is_utf8($text) ? Encode::encode_utf8($text) : $text; print "$name: was_decoded=$was_decoded, output(hex)=",unpack(q{H*},$output),"\n"; }'
#               Result:         ascii:          was_decoded=0, output(hex)=435346
#                               utf8_bytes:     was_decoded=1, output(hex)=e282ac
#                               decoded_text:   was_decoded=0, output(hex)=e282ac
#                               invalid_bytes:  was_decoded=1, output(hex)=efbfbd
#   
#   @params     value           scalar      Input text
#   @return                     str         Decoded or unchanged input
#                               int         If byte str was decoded
#                                               0           Value not decoded
#                                               1           Value decoded
# #

sub _text_utf8_decode
{
    my ( $value ) = @_;

    $value = "$value";

    if ( utf8::is_utf8( $value ) )
    {
        return ( '[INVALID UTF-8]', 0 )
            if !utf8::valid( $value );

        return ( $value, 0 );
    }

    return ( $value, 0 )
        if $value !~ /[\x{0080}-\x{00FF}]/;

    my $value_encoded = $value;
    my $value_decoded = Encode::decode(
        'UTF-8',
        $value_encoded,
        Encode::FB_DEFAULT( ),
    );

    return ( $value_decoded, 1 );
}

# #
#   DebugLocal › Text › Utf8 › Bytes
#   
#   Decode input text if needed, then convert output to utf8 bytes.
#   Leave existing utf8 bytes unchanged.
#   
#   @note       _text_utf8_decode()     Output as decoded chars
#               _text_utf8_bytes()      Output as utf8 bytes
#   
#   @test       Note:           Verify all results return as utf8 bytes
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -e 'for my $test ([ascii=>q{CSF}],[utf8_bytes=>pack(q{H*},q{e282ac})],[decoded_text=>chr(0x20ac)],[invalid_bytes=>pack(q{H*},q{ff})]) { my ($name,$input)=@{$test}; my $output=ConfigServer::DebugLocal::_text_utf8_bytes($input); print "$name: hex=",unpack(q{H*},$output),", utf8_flag=",utf8::is_utf8($output)?1:0,"\n"; }'
#               Result:         ascii:          hex=435346, utf8_flag=0
#                               utf8_bytes:     hex=e282ac, utf8_flag=0
#                               decoded_text:   hex=e282ac, utf8_flag=0
#                               invalid_bytes:  hex=efbfbd, utf8_flag=0
#   
#   @params     value           scalar      Input text
#   @return                     str         Text stored as utf8 bytes
# #

sub _text_utf8_bytes
{
    my ( $value ) = @_;

    my ( $out ) = _text_utf8_decode( $value );

    return utf8::is_utf8( $out )
        ? Encode::encode_utf8( $out )
        : $out;
}

# #
#   DebugLocal › Text › Truncate
#   
#   Keep the beginning and end of a long value. If len_max is not
#   provided, use DEBUG_TRUNCATE_CHAR_MAX (4 * 1024) chars.
#   
#   @test       Note:           Test truncation
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -e '$value="START_".("A"x100)."_END"; $out=ConfigServer::DebugLocal::_text_truncate($value, 30); print "In len:  ",length($value),"\nOut len: ",length($out),"\nResult:     $out\n";'
#               Result:         In len:     110
#                               Out len:    30
#                               Result:     START_AAAAA [...] AAAAAAAA_END
#   
#   @params     value           str         Text to truncate
#               len_max         int|undef   Max returned len
#                                               int         Use supplied $len_max
#                                               undef       Use DEBUG_TRUNCATE_CHAR_MAX
#   @return     value           str         Result
#                                               str         Original or truncated value
# #

sub _text_truncate
{
    my ( $value, $len_max ) = @_;

    $len_max = DEBUG_TRUNCATE_CHAR_MAX
        if !defined( $len_max );

    $len_max = DEBUG_TRUNCATE_CHAR_MIN
        if $len_max < DEBUG_TRUNCATE_CHAR_MIN;

    return $value
        if length( $value ) <= $len_max;

    my ( $value_text, $value_decoded_byte ) = _text_utf8_decode( $value );
    if ( length( $value_text ) <= $len_max )
    {
        return $value_decoded_byte ? Encode::encode_utf8( $value_text ) : $value_text;
    }

    my $truncate_marker = DEBUG_TRUNCATE_MARKER;
    if ( $len_max <= length( $truncate_marker ) )
    {
        my $out = substr( $value_text, 0, $len_max );
        return $value_decoded_byte ? Encode::encode_utf8( $out ) : $out;
    }

    my $len_remains = $len_max - length( $truncate_marker );
    my $len_start   = int( $len_remains / 2 );
    my $len_end     = $len_remains - $len_start;

    my $out         = substr( $value_text, 0, $len_start ) . $truncate_marker . substr( $value_text, -$len_end );

    return $value_decoded_byte ? Encode::encode_utf8( $out ) : $out;
}

# #
#   DebugLocal › Text › Clean Terminal Strings
#   
#   Make text safe to show in terminal. Remove unsafe chars and
#   controls
#   
#   Remove osc, unsafe csi, control chars, chars that can change
#   text direction.
#   
#   Allowed ansi text colors and styles are kept only if:
#       $is_keep_clr = 1
#   
#   Line breaks are kept only if:
#       $is_keep_lb = 1
#   
#   @todo       Should be migrated to Sanitize.pm
#   
#   @test       Note:           Several tests for cleaning; char 'C' should be red
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -e 'my $value="A\e]0;title\aB\e[91mC\e[0m\e[2JD\r\n\tE\0F".chr(0x202e)."G"; print "is_keep_clr=0: ",ConfigServer::DebugLocal::_text_terminal_clean($value,0),"\n"; print "is_keep_clr=1: ",ConfigServer::DebugLocal::_text_terminal_clean($value,1),"\n"; print "undef: ",ConfigServer::DebugLocal::_text_terminal_clean(undef,0),"\n"; print "ref: ",ConfigServer::DebugLocal::_text_terminal_clean([],0),"\n";'
#               Result:         is_keep_clr=0:      ABCD EFG
#                               is_keep_clr=1:      ABCD EFG
#                                                     ^ red
#                               undef:              undef
#                               ref:                ARRAY
#   
#   @params     value           scalar      Input str
#               is_keep_clr     int         Ansi styling behavior
#                                               0           Remove all styling
#                                               1           Keep allowed styling
#               is_keep_lb      int         Line break behavior
#                                               0           Replace line breaks with spaces
#                                               1           Keep line breaks
#   @return     text            str         Result
#                                               str         Sanitized text, undef, ref
# #

sub _text_terminal_clean
{
    my ( $value, $is_keep_clr, $is_keep_lb ) = @_;

    return 'undef'
        if !defined( $value );

    return ref( $value )
        if ref( $value );

    my ( $_value, $value_decoded_byte ) = _text_utf8_decode( $value );
    my $value_is_utf8                   = utf8::is_utf8( $_value );

    # #
    #   @note       Clean up string in steps, otherwise we get
    #               undesired results that screw up certain strings
    # #

    # remove all osc (title, link, etc)
    $_value =~ s{
        \x{001B}\]
        (?:
            [^\x{0007}\x{001B}] |
            \x{001B}(?!\\)
        )*
        (?:\x{0007}|\x{001B}\\)
    }{}gx;

    if ( $is_keep_clr )
    {
        # allow csi clrs, bold, dim, reset; remove all other csi
        $_value =~ s{
            \x{001B}\[
            ([0-?]*[ -\/]*)
            ([@-~])
        }{
            ( $2 eq 'm' and _ansi_style_is_safe( $1 ) )
                ? "\x{001B}[$1$2"
                : ''
        }gex;

        # remove esc chars (allow basic clr codes, bold, dim, reset)
        $_value =~ s/\x{001B}(?!\[[0-?]*[ -\/]*m)//g;
    }
    else
    {
        # remove all csi; includes clrs and styling
        $_value =~ s/\x{001B}\[[0-?]*[ -\/]*[@-~]//g;

        # remove all remaining esc chars
        $_value =~ s/\x{001B}//g;
    }

    if ( $is_keep_lb )
    {
        # normalize cr without removing line breaks
        $_value =~ s/\r\n?/\n/g;

        # replace tabs and line breaks with spaces
        $_value =~ s/[\t\x{2028}\x{2029}]+/ /g;
    }

    # replace tabs and line breaks with spaces
    $_value =~ s/(?:\r\n|[\r\n\t\x{2028}\x{2029}])+/ /g
        if !$is_keep_lb;

    # remove c0, del, c1, etc
    $_value =~ s/[\x{0000}-\x{0008}\x{000B}\x{000C}\x{000E}-\x{001A}\x{001C}-\x{001F}\x{007F}-\x{009F}]//g;

    # remove text direction chars
    $_value =~ s/[\x{061C}\x{200E}\x{200F}\x{202A}-\x{202E}\x{2066}-\x{2069}]//g
        if $value_is_utf8;

    return $value_decoded_byte ? Encode::encode_utf8( $_value ) : $_value;
}

# #
#   DebugLocal › Text › Escape Input (Dump)
#   
#   Make hidden chars visible in dump output. Convert control chars
#   into readable text.
#   
#   Displays chars as \e, \r, \x{0000}, etc
#   
#   @todo       Should be migrated to Sanitize.pm
#   
#   @test       Note:           Test all escapes
#               Ref:            https://www.unicode.org/charts/charindex.html
#                                   (Website only works with 4 digit unicode for command below)
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -e 'my $value=join(q{},map { chr($_) } (0x0041,0x0027,0x005c,0x001b,0x000d,0x000a,0x0009,0x0000,0x0008,0x000b,0x000c,0x000e,0x001a,0x001c,0x001f,0x007f,0x0080,0x009f,0x061c,0x200e,0x200f,0x2028,0x2029,0x202a,0x202e,0x2066,0x2069,0x0042)); print "escaped: ",ConfigServer::DebugLocal::_text_escape_dump($value),"\n"; print "undef: ",ConfigServer::DebugLocal::_text_escape_dump(undef),"\n"; print "reference: ",ConfigServer::DebugLocal::_text_escape_dump([]),"\n"; my $bytes=pack(q{H*},q{e282ac}); print "utf8 bytes: ",unpack(q{H*},ConfigServer::DebugLocal::_text_escape_dump($bytes)),"\n";' | cat -v
#               Result:         escaped:    A\'\\\e\r\n\t\x{0000}\x{0008}\x{000B}\x{000C}\x{000E}\x{001A}\x{001C}\x{001F}\x{007F}\x{0080}\x{009F}\x{061C}\x{200E}\x{200F}\x{2028}\x{2029}\x{202A}\x{202E}\x{2066}\x{2069}B
#                               undef:      undef
#                               reference:  ARRAY
#                               utf8 bytes: e282ac
#   
#   @params     value           scalar      Value to escape
#   @return     text            str         Result
#                                               str         Escaped text, undef, ref
# #

sub _text_escape_dump
{
    my ( $value ) = @_;

    return 'undef'
        if !defined( $value );

    return ref( $value )
        if ref( $value );

    my ( $_value, $value_decoded_byte ) = _text_utf8_decode( $value );
    my $value_is_utf8                   = utf8::is_utf8( $_value );

    $_value =~ s{\\}{\\\\}g;            # esc backslashes
    $_value =~ s{'}{\\'}g;              # esc single quotes
    $_value =~ s{\x{001B}}{\\e}g;       # show escape chars => \e
    $_value =~ s{\r}{\\r}g;             # show carriage returns => \r
    $_value =~ s{\n}{\\n}g;             # show line breaks => \n
    $_value =~ s{\t}{\\t}g;             # show tabs => \t

    # hidden control chars into readable (nul - bs, vt, ff, etc)
    $_value =~ s{
        ([\x{0000}-\x{0008}\x{000B}\x{000C}\x{000E}-\x{001A}\x{001C}-\x{001F}\x{007F}-\x{009F}])
    }{sprintf( '\\x{%04X}', ord( $1 ) )}gex;

    # directional and line chars (alm, lrm, rlm, etc) (converted to readable hex text)
    $_value =~ s{
        ([\x{061C}\x{200E}\x{200F}\x{2028}\x{2029}\x{202A}-\x{202E}\x{2066}-\x{2069}])
    }{sprintf( '\\x{%04X}', ord( $1 ) )}gex
        if $value_is_utf8;

    return ( $value_decoded_byte or utf8::is_utf8( $_value ) )
        ? Encode::encode_utf8( $_value )
        : $_value;
}

# #
#   DebugLocal › Ansi › Remove Terminal Controls
#   
#   Strip csi / osc controls from input str. Then remove any
#   remaining esc chars.
#   
#   Should only be left with regular text. This sub is used 
#   with DebugLocal.t module tests to compare plain text results.
#   
#   Cleans:
#       CSI (Control Sequence Introducer)
#           Text fg/bg clrs, cur movement/visibility, screen clearing
#           Eg:     \x{001B}[31m    Red text
#                   \x{001B}[2J     Clear screen
#   
#       OSC (OS Commands)
#           Window/tab titles, terminal wide clrs, links, clipboard
#           Eg:     \x{001B}]0;CSF Test\x{0007}
#                   \x{001B}]8;;https://configserver.dev\x{001B}\\
#   
#   @ref        https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
#               https://ansi.tools/lookup
#   
#   @test       Note:           Remove terminal clrs from str
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -e 'my $value="\e]0;CSF Test\a\e[1;34mConfigServer\e[0m \e[1;31mSecurity\e[0m \e[1;33mFirewall\e[0m"; print ConfigServer::DebugLocal::_ansi_clean($value), qq{\n};'
#               Result:         ConfigServer Security Firewall
#   
#   @params     value           str         Debug output as input
#   @return                     str         Output without clr codes
# #

sub _ansi_clean
{
    my ( $value ) = @_;

    return 'undef'
        if !defined( $value );

    # remove osc (title, link, etc)
    $value =~ s{
        \x{001B}\]
        (?:
            [^\x{0007}\x{001B}] |
            \x{001B}(?!\\)
        )*
        (?:\x{0007}|\x{001B}\\)
    }{}gx;

    # remove all csi (terminal ctrls, clrs, text styles)
    $value =~ s/\x{001B}\[[0-?]*[ -\/]*[@-~]//g;

    # remove remaining esc chars
    $value =~ s/\x{001B}//g;

    return $value;
}

# #
#   DebugLocal › Ansi › Safe Styling
#   
#   Returns undef or 1, if ansi text styling params are safe to use.
#   
#   Allow:      Reset, basic colors, bold, dim
#   Disallow:   Italic, underline, blink, conceal, inverse, strike,
#               clr values above 255
#   
#   @todo       Should be migrated to Sanitize.pm
#   
#   @test       Note:           Test clr input
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::DebugLocal -e 'for my $params (q{},qw(31 38;5;33 38;2;255;100;0 5 7 8 38;5;256)) { my $result=ConfigServer::DebugLocal::_ansi_style_is_safe($params); printf "%-18s %s\n", length($params) ? $params : "(empty)", defined($result) ? "safe" : "not safe"; }'
#               Result:         (empty)            safe
#                               31                 safe
#                               38;5;33            safe
#                               38;2;255;100;0     safe
#                               5                  not safe
#                               7                  not safe
#                               8                  not safe
#                               38;5;256           not safe
#   
#   @params     params          str         Ansi styling params
#   @return     result          int         If styling params are safe
#                                               1           Safe
#                                               undef       Unsafe
# #

sub _ansi_style_is_safe
{
    # $params     38;5;33
    my ( $params ) = @_;

    return
        if !defined( $params ) or ref( $params );

    return 1
        if $params eq '';

    return
        if $params !~ /\A[0-9;]+\z/;

    my @parts = split( /;/, $params, -1 );
    while ( @parts )
    {
        my $part = shift( @parts );
        return
            if $part eq '';

        if ( $part =~ /\A(?:0|1|2|22|3[0-7]|39|4[0-7]|49|9[0-7]|10[0-7])\z/ )
        {
            next;
        }

        # allow extended fg (38) or bg (48) clr; reject any other value
        return
            if $part ne '38' and $part ne '48';

        # #
        #   Mode 5:     256 color
        #               requires one clr value: 0 - 255
        #               Eg:     $params = "38;5;33"
        #   
        #   Mode 2:     RGB color
        #               requires three clr values: 0 - 255
        #               Eg:     $params = "38 ; 2 ; red ; green ; blue"
        #                       $params = "38;2;255;100;0"
        # #

        my $mode = shift( @parts );
        return
            if !defined( $mode );

        if ( $mode eq '5' )
        {
            my $clr = shift( @parts );
            return
                if !defined( $clr ) or
                   $clr !~ /\A[0-9]+\z/ or
                   length( $clr ) > 3 or
                   $clr > 255;

            next;
        }

        return
            if $mode ne '2';

        for ( 1 .. 3 )
        {
            my $clr = shift( @parts );
            return
                if !defined( $clr ) or
                   $clr !~ /\A[0-9]+\z/ or
                   length( $clr ) > 3 or
                   $clr > 255;
        }
    }

    return 1;
}

1;