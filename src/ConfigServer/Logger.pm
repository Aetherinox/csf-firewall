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

## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)

# #
#   Module › Usage & Notes
#   
#   Development notes and usage summary on using this module. For
#   a complete list of features, use perldoc
#       perldoc -T ConfigServer/Logger.pm
#   
#   ABOUT:
#       -   Terminal Logs:      No (write errors use STDERR)
#       -   Log File:           Yes
#       -   Syslog:             Yes (if enabled)
#                                   Excludes target 'root'
#       -   Uses csf.conf:      Yes
#       -   Ansi Colors:        No
#       -   Production:         Yes
#       -   DEBUG Setting:      csf.conf (DEBUG = "1")
#       -   DEBUG Levels:       0 - 5:      shows same and lower levels
#       -   Redaction:          0 - 5:      Redaction: Yes
#       -   Trigger:            ConfigServer::Logger::logfile()
#  
#   
#   DEBUG LOG:
#       Description:
#       -   DEBUG:X accepts value from 0 to 5:
#               0       Normal logs             Secrets Redacted        Logs 0 only
#               1       Normal debug logs       Secrets Redacted        Logs 0 - 1
#               2       Verbose debug logs      Secrets Redacted        Logs 0 - 2
#               3       Trace debug logs        Secrets Redacted        Logs 0 - 3
#               4       Prolix debug logs       Secrets Redacted        Logs 0 - 4
#               5       Specialized logs        Secrets Redacted        Logs 0 - 5
#   
#       Usage:              ConfigServer::Logger::logfile( "DEBUG:2", "info", "Debug log msg" );
#       Path (Root):        /var/log/lfd.log
#       Path (Non-root):    /var/log/lfd_messenger.log
#   
#   
#   NORMAL LOG:
#       Description:
#       -   Write to lfd.log when running as root.
#       -   Write to lfd_messenger.log when ruid / euid match and are non-root.
#       -   Not suppressed or controlled by the DEBUG setting.
#   
#       Usage:              ConfigServer::Logger::logfile( "normal", "info", "Normal log msg" );
#       Path (Root):        /var/log/lfd.log
#       Path (Non-root):    /var/log/lfd_messenger.log
#   
#   
#   ROOT LOG:
#       Description:
#       -   For specialized root / core CSF functionality.
#       -   Does not load /etc/csf/csf.conf.
#       -   Does not write to syslog.
#   
#       Usage:              ConfigServer::Logger::logfile( "root", "info", "Root log msg" );
#       Path (Root):        /var/log/lfd_root.log
#   
#   
#   ALL LOG:
#       Description:
#       -   When running as root, writes to both 'normal' and 'root' logs.
#       -   Do not use after Messenger drops root privileges because the
#               'root' log is attempted first.
#   
#       Usage:              ConfigServer::Logger::logfile( "all", "info", "All log msg" );
#       Path (Normal):      /var/log/lfd.log
#       Path (Root):        /var/log/lfd_root.log
#   
#   
#   MESSENGER LOG:
#       Description:
#       -   Not a directly triggered log type.
#       -   Triggers when the Logger module is called using TARGET
#               'normal' or 'DEBUG:X'; AND the LFD Messenger process
#               is running as MESSENGER_USER.
#       -   LFD Messenger starts as root, then changes to
#               MESSENGER_USER. After changing users, Logger writes
#               'normal' and DEBUG:X messages to /var/log/lfd_messenger.log.
#       -   LFD Messenger process's ruid and euid must match.
#       -   Log must be owned by MESSENGER_USER and mode 0600.
#   
#       Usage:              ConfigServer::Logger::logfile( "normal", "info", "Messenger log msg" );
#       Path (Non-root):    /var/log/lfd_messenger.log
#   
#   
#   SYSLOG:
#       Description:
#       -   Sends messages to system log.
#       -   Requires SYSLOG to be enabled in /etc/csf/csf.conf.
#       -   Requires Sys::Syslog to load successfully.
#       -   Logs with TARGET 'normal', 'all', 'DEBUG:X' are sent to syslog.
#       -   Logs with TARGET 'root' don't use syslog.
#   
#       Usage:              ConfigServer::Logger::logfile( "normal", "info", "Syslog msg" );
#       Destination:        System syslog
# #

=head1 NAME

C<ConfigServer::Logger> - Write CSF and LFD messages to log files in
production environments.

=head1 SYNOPSIS

=over 4

=item *

Load module:

    use ConfigServer::Logger ( );

=item *

Call logfile():

    ConfigServer::Logger::logfile(
        "normal", "info", "CSF log message"
    );

=item *

When running as root, log is written to C</var/log/lfd.log>:

    Oct 22 12:34:56 server lfd[ 12345 ] [main::test_sub():42] [info]: CSF log message

=back

=head1 SUMMARY

The following is a list outlining the main features of this module,
and the most important notes to take into consideration.

=over 4

=item *

Log messages are written to the persistent log files:

    Type            Log Location
    --------------- --------------------------------
    Normal          /var/log/lfd.log
    Debug           /var/log/lfd.log
    Root            /var/log/lfd_root.log
    Messenger       /var/log/lfd_messenger.log

=item *

No log messages are sent to the terminal. For terminal only debug
messages; see module C<ConfigServer::DebugLocal>.

=item *

Implement log messages by calling C<ConfigServer::Logger::logfile()>
with a message, B<TARGET> (optional), and B<STATUS> (optional):

    Eg: ConfigServer::Logger::logfile( "MESSAGE" );
        ConfigServer::Logger::logfile( "Normal msg using info status" );

        ConfigServer::Logger::logfile( STATUS, "MESSAGE" );
        ConfigServer::Logger::logfile( "warn", "Normal msg using warn status" );

        ConfigServer::Logger::logfile( TARGET, STATUS, "MESSAGE" );
        ConfigServer::Logger::logfile( "root", "info", "Root log message" );

=over 4

=item *

B<TARGET>:

=over 4

=over 4

=item *

C<normal> (default) - Write to the normal LFD log.

=item *

C<root> - Write to the root LFD log.

=item *

C<all> - Write to both normal and root logs.

=item *

C<debug:X> - Write to the normal log destination when C<X> is enabled
by the C<DEBUG> setting.

=back

=back

=back

=over 4

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

=item *

Custom (eg:  C<testing>)

=back

=back

=back

=item *

For B<TARGET> C<debug:X>, set the highest DEBUG log level in
C</etc/csf/csf.conf>:

    DEBUG = "X"

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
    5       Specialized logs    Enabled     Level 0 - 5

=back

=item *

DEBUG levels C<0> - C<5>: All secrets redacted by
C<ConfigServer::Secrets>.

=item *

DEBUG levels C<0> - C<5>: Write logs to B<TARGET> log file for the
selected level and lower.

=item *

Logs do not contain ansi colors or formatting codes.

=item *

C<DEBUG> setting in C</etc/csf/csf.conf> only controls TARGET C<debug:X>.

=item *

Log destination depends on B<TARGET> AND the user running the process:

    Target      User                Log Destination
    ----------- ------------------- -------------------------------
    debug:0-5   root                /var/log/lfd.log
                MESSENGER_USER      /var/log/lfd_messenger.log

    normal      root                /var/log/lfd.log
                MESSENGER_USER      /var/log/lfd_messenger.log

    root        root                /var/log/lfd_root.log

    all         root                /var/log/lfd_root.log
                                    /var/log/lfd.log

=item *

Messenger writes logs to C</var/log/lfd_messenger.log> once the sub 
C<ConfigServer::Messenger::drop_messenger_privileges()> succeeds, AND
after the Messenger process's user changes from root to 
C<MESSENGER_USER> ( defined in C</etc/csf/csf.conf> ).

=item *

Messenger only writes logs when target is C<normal> or C<debug:X>.

Do not use target C<all> after Messenger privilege drops because it
attempts to write C</var/log/lfd_root.log> first.

=item *

When C<SYSLOG> is enabled in C</etc/csf/csf.conf> and C<Sys::Syslog>
loads successfully, system syslog also receives C<normal>, C<all>,
and C<debug:X> messages.

=item *

Target C<root> is never sent to syslog.

=item *

Target C<root> does not load csf.conf

=item *

B<TARGET> defaults to C<normal> when not specified in a call
to C<ConfigServer::Logger::logfile()>.

    ConfigServer::Logger::logfile( "warn", "Normal msg using warn status" );

=item *

B<STATUS> defaults to C<info> when not specified in a call
to C<ConfigServer::Logger::logfile()>.

    ConfigServer::Logger::logfile( "Normal msg using info status" );

=item *

C<ConfigServer::Logger::logfile()> returns:

=over 4

=item *

C<hashref>: if message is written or suppressed.

=item *

C<undef>: if a log fails to write.

=back

=item *

A custom B<STATUS> can have letters, numbers, underscores, or
hyphens, with a max length of C<16> chars (C<LOG_STATUS_CHAR_MAX>):

    ConfigServer::Logger::logfile(
        "normal", "testing", "Custom status msg"
    );

=back

=head1 DESCRIPTION

C<ConfigServer::Logger> writes plain text CSF and LFD messages to
persistent log files in production environments. Log messages are
created by calling C<ConfigServer::Logger::logfile()> and specifying
a string log message. The C<logfile()> subroutine also accepts the
optional arguments B<TARGET> and B<STATUS>.

When any module calls C<ConfigServer::Logger::logfile()>, the provided
arguments define how that log will be processed.

    Eg: sub test_sub
        {
            ConfigServer::Logger::logfile(
                "normal", "info", "Log msg"
            );
        }

B<TARGET>: specifies which log file will receive the message. When
the app runs a process as root, specifying the targets C<normal> or
C<debug:X> will make the module write logs to C</var/log/lfd.log>.
The target C<root> writes logs to C</var/log/lfd_root.log>. The
target C<all> writes logs to both C</var/log/lfd.log> and
C</var/log/lfd_root.log>.

B<STATUS>: adds a label to each log message. Supported labels include
C<fail>, C<ok>, C<warn>, C<abort>, and C<info>. The label is primarily
cosmetic and does not affect which log file receives the message.

    Eg: lfd[ 355716 ] [lfd::global:3148] [info]: Log with normal target
                                         ^^^^^^  ^^^^^^^^^^^^^^^^^^^^^^
                                         STATUS         MESSAGE

This module maintains a separate log for the B<Messenger> module at
C</var/log/lfd_messenger.log>. Access to this log is restricted to
prevent unauthorized users from reading the log's contents.

To write Messenger logs, call C<ConfigServer::Logger::logfile()>
using target C<normal> or C<debug:X>.

Messages begin writing to the Messenger log after
C<ConfigServer::Messenger::drop_messenger_privileges()> succeeds and
the Messenger process's user changes from root to C<MESSENGER_USER>.

Messenger logging requires matching real and effective user IDs. The
log file must be owned by C<MESSENGER_USER> with mode C<0600>.

This module also supports defining the target C<debug:X> when calling
C<ConfigServer::Logger::logfile()>. When the process runs as root,
debug messages are written to C</var/log/lfd.log> only when the
C<DEBUG> setting in C</etc/csf/csf.conf> enables the specified level
that you wish to see logs for.

When the process runs as root, debug levels C<0> - C<5> will write log
messages to C</var/log/lfd.log> only if the level specified by target
C<debug:X> matches or is lower than the C<DEBUG> setting defined in
C</etc/csf/csf.conf>.

    Eg: ConfigServer::Logger::logfile( 
            "debug:2", "info", "A debug log"
        );

Debug levels C<0> - C<5>: Before a debug log is written to 
C</var/log/lfd.log>, the log will pass through C<ConfigServer::Secrets>
to redact sensitive field names and values.

Targets C<normal>, C<root>, and C<all> do not enable debug logging, 
and are not controlled by the C<DEBUG> setting in C</etc/csf/csf.conf>.

When C<SYSLOG> is enabled and C<Sys::Syslog> loads successfully,
C<normal>, C<all>, and C<debug:X> messages are also sent to system
syslog. The C<root> target does not load C</etc/csf/csf.conf> or use
syslog.

Log file write errors are reported through C<STDERR>.

When C<ConfigServer::Logger::logfile()> is called by a module, it returns
a hashref when a message is written or suppressed, or returns C<undef>
if a log fails to write.

This module does not send messages to the terminal. Use
C<ConfigServer::DebugLocal> to display debug messages in the terminal.

=head1 USAGE

=over 4

=item *

Load module:

    use ConfigServer::Logger ( );

=item *

Write C<normal> log as root and check the result:

    my $result = ConfigServer::Logger::logfile(
        "normal", "info", "CSF log message"
    );

    if ( !$result ) { die "Log write failed\n"; }

Logger writes the message to:

    /var/log/lfd.log

=item *

Write C<normal> log as root without checking the result:

    ConfigServer::Logger::logfile(
        "normal", "info", "CSF log message"
    );

Logger writes the message to:

    /var/log/lfd.log

=item *

Prepare the Messenger log before changing from root to
C<MESSENGER_USER>:

    my ( undef, undef, $uid, $gid ) = getpwnam( $config{MESSENGER_USER} );

    my ( $prepared, $error ) = ConfigServer::Logger::msngr_log_prepare(
        $uid,
        $gid
    );

    if ( !$prepared )
    {
        die "Messenger log preparation failed: $error\n";
    }

After LFD changes from root to C<MESSENGER_USER>, use the same
C<normal> log call:

    ConfigServer::Logger::logfile(
        "normal", "info", "Messenger log message"
    );

Logger writes the message to:

    /var/log/lfd_messenger.log

=back

=head1 EXAMPLES

=over 4

=item *

Load module:

    use ConfigServer::Logger ( );

=item *

Write to target C<normal> using status C<info>:

    ConfigServer::Logger::logfile(
        "CSF log msg"
    );

=item *

Write to target C<normal> using status C<warn>:

    ConfigServer::Logger::logfile(
        "warn", "CSF log msg"
    );

=item *

Write to target C<root> using status C<info>:

    ConfigServer::Logger::logfile(
        "root", "info", "CSF log msg"
    );

=item *

Write to both C<normal> and C<root> using target C<all> and status
C<ok>:

    ConfigServer::Logger::logfile(
        "all", "ok", "CSF log msg"
    );

=item *

Write to target C<debug:4> using status C<info>:

    ConfigServer::Logger::logfile(
        "DEBUG:4", "info", "CSF log msg"
    );

=item *

Write to target C<root> using custom status C<testing>:

    ConfigServer::Logger::logfile(
        "root", "testing", "CSF log msg"
    );

=item *

Each example below writes the same message to the normal log.
C<DEBUG:0> is treated as a normal log target.

    ConfigServer::Logger::logfile( "DEBUG:0", "info", "Message" );
    ConfigServer::Logger::logfile( "info", "Message" );
    ConfigServer::Logger::logfile( "normal", "info", "Message" );

=item *

C<ConfigServer::Logger::logfile()> accepts the following argument
combinations:

=over 4

=item *

[ 1 Arg ] Message only:

    ConfigServer::Logger::logfile(
        "CSF Log msg"
    );

=item *

[ 2 Args ] Status and message:

    ConfigServer::Logger::logfile(
        "warn", "CSF Log msg"
    );

=item *

[ 3 Args ] Target, status, and message:

    ConfigServer::Logger::logfile(
        "root", "info", "CSF Log msg"
    );

=back

=back

=head1 COMMANDS

=over 4

=item *

Load module directly:

    sudo perl -I. ConfigServer/Logger.pm

=item *

Check module for syntax errors:

    sudo perl -I. -c ConfigServer/Logger.pm

=item *

Display module documentation:

    perldoc -T ConfigServer/Logger.pm

=item *

Run test suite:

    Linux:      sudo prove -I. -v tests/Logger.t
    Windows:    prove -Isrc -v tests/Logger.t

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

package ConfigServer::Logger;

# #
#   Declare › Use
# #

use strict;
use warnings;
use lib '/usr/local/csf/lib';
use bytes ();
use Carp ();
use Cwd ();
use Encode ();
use Errno ();
use Fcntl ();
use File::Basename ();
use File::Path ();
use File::stat ();
use POSIX ();
use utf8 ();
use ConfigServer::Config ();
use ConfigServer::Secrets ();
use ConfigServer::DebugLocal ();

# #
#	Declare › Export
# #

use Exporter qw( import );
our @EXPORT_OK = qw(
    logfile
);

# #
#	Declare › Version
# #

our $VERSION = 15.11;

# #
#	Declare › Generic
# #

my %config;
my $config_loaded = 0;
my $sys_syslog;

# #
#   Declare › Constants › Internal
#   
#   You should not need to tweak with these constant values unless
#   you are testing and know what you are doing.
#   
#   HOSTNAME_DEFAULT
#       Fallback hostname used if server hostname can't be read.
#   
#   LOGFILE_TEST_DIR
#       Local test log dir used when testing on Windows.
#           Windows:    /tests/var/log
#           Linux:      /var/log
#   
#   LOGFILE_DIR
#       Main log dir used on Linux
#   
#   LOGFILE_DIR_SUB
#       Extra subdir created during Windows tests.
#       Note:   Logger does not write logs to this subdir yet.
#   
#   LOGFILE_PROCESS
#       Process name shown in file and system log entries (lfd).
#           Eg: lfd[ 12345 ] [ROOT] [...]
#   
#   LOGFILE_NORMAL
#       File to use for normal lfd logs.
#   
#   LOGFILE_ROOT
#       File name used for root logs.
#   
#   LOGFILE_MESSENGER
#       File name used for logs written by non-root process.
#   
#   HOSTNAME_LABEL_CHAR_MAX
#       Max allowed len for the short hostname.
#   
#   FILE_PERMS_MODE_MASK
#       Extract only the perm bits from a complete file mode. Also
#       ensures $mode does not contain bits outside the allowed
#       07777 range.
#   
#   LOGFILE_CREATE_MODE
#       Perms used when creating a new log file.
#   
#   LOG_OWNER_ID_MAX_DIGIT
#       Max number of digits accepted for a log owner uid or gid.
#   
#   LOG_OWNER_ID_MAX
#       Highest numeric uid or gid accepted for log file ownership.
#       Usually 4,294,967,294.
#       
#   LOG_LOCK_ATTEMPT_MAX
#       Max attempts made to acquire exclusive log file lock.
#   
#   LOG_LOCK_DELAY_SECONDS
#       Seconds to wait between attempts to acquire the log file lock.
#           0.01 seconds => 10 milliseconds
#           0.05 seconds => 50 milliseconds
#   
#   LOG_PATH_BYTE_MAX
#       Max number of bytes allowed in a Messenger log file path.
#       For ascii chars, each char is one byte.
#   
#   LOG_LINE_BYTE_MAX
#       Max size allowed for one complete Messenger log line.
#       Unicode text is converted to utf8 bytes before checking the limit.
#   
#   LOG_STATUS_CHAR_MAX
#       Max number of chars allowed in a log status label.
#   
#   MESSENGER_LOG_MODE
#       Required perms for the Messenger log file.
#       0600    owner:  read and write
#               group:  no access
#               other:  no access
#   
#   MESSENGER_LOG_UMASK
#       Remove all 'group' and 'other' perms when creating Messenger log.
#   
#   MESSENGER_PARENT_UNSAFE_MODE_MASK
#       Perm bits that make a Messenger log parent dir unsafe.
#   
#   LOG_HARDLINK_MAX
#       Required hardlink count for the Messenger log file.
#   
#   ROOT_UID
#       System uid used to identify the root account.
# #

use constant
{
    HOSTNAME_DEFAULT                    => 'csf',
    LOGFILE_TEST_DIR                    => File::Basename::dirname( File::Basename::dirname( Cwd::abs_path( __FILE__ ) ) ) . '/tests/var/log',
    LOGFILE_DIR                         => '/var/log',
    LOGFILE_DIR_SUB                     => 'csf',                   # Not implmeneted yet
    LOGFILE_PROCESS                     => 'lfd',
    LOGFILE_NORMAL                      => 'lfd.log',
    LOGFILE_ROOT                        => 'lfd_root.log',
    LOGFILE_MESSENGER                   => 'lfd_messenger.log',
    HOSTNAME_LABEL_CHAR_MAX             => 63,
    FILE_PERMS_MODE_MASK                => 07777,
    LOGFILE_CREATE_MODE                 => 0666,
    LOG_OWNER_ID_MAX_DIGIT              => 10,
    LOG_OWNER_ID_MAX                    => 4_294_967_294,
    LOG_LOCK_ATTEMPT_MAX                => 15,
    LOG_LOCK_DELAY_SECONDS              => 0.05,
    LOG_PATH_BYTE_MAX                   => 4 * 1024,
    LOG_LINE_BYTE_MAX                   => 64 * 1024,
    LOG_STATUS_CHAR_MAX                 => 16,
    MESSENGER_LOG_MODE                  => 0600,
    MESSENGER_LOG_UMASK                 => 0077,
    MESSENGER_PARENT_UNSAFE_MODE_MASK   => 0022,
    LOG_HARDLINK_MAX                    => 1,
    ROOT_UID                            => 0,
};

# #
#   Declare › Constants › Debug
#   
#   This module does not have a DEBUG mode constant. Instead, this
#   module reads the DEBUG setting from /etc/csf/csf.conf:
#       DEBUG = "1"
#   
#   The DEBUG setting in csf.conf decides which DEBUG:X log messages
#   are written to file.
#   
#   DEBUG_LEVEL_MAX
#       Highest DEBUG:X log level accepted by logfile().
#       Used as current debug level if testing on Windows;
#           (Windows env does not load /etc/csf/csf.conf)
# #

use constant
{
    DEBUG_LEVEL_MAX => 5
};

# #
#	Declare › Status › Labels
#   
#   Map log statuses to their display string. Specifying a status in
#   ConfigServer::Logger::logfile() is optional; default is 'info'.
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
#   Logger › Config › Load
#   
#   Load /etc/csf/csf.conf config file only when this module actually
#   needs it.
#   
#   Prevent ConfigServer::Logger from immediately requiring the
#   config file.
#   
#   Cache loaded config; only read once.
#   
#   Tests may pass a config hashref to skip csf.conf and disable syslog.
#   
#   @test       Note:           Load mocked config without reading csf.conf
#               Sub:            my $result = _config_load();
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e '{ package Local::LoggerConfig; sub config { return (DEBUG => 0, SYSLOG => 0); } } no warnings q{redefine}; local *ConfigServer::Logger::logfile = sub { return {written => 1}; }; local *ConfigServer::Config::loadconfig = sub { return bless {}, q{Local::LoggerConfig}; }; local *ConfigServer::Secrets::register_secrets = sub { return 1; }; my $result = ConfigServer::Logger::_config_load(); print defined($result) ? $result : q{undef}, qq{\n};'
#               Result:         undef
#   
#               Note:           Run config_load() with real CSF config
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'ConfigServer::Logger::_config_load(); print qq{Configuration loaded\n};'
#   
#   @params     config_override hashref|undef   Config values used by tests
#   @return                     undef           No value returned
# #

sub _config_load
{
    my ( $config_override ) = @_;

    return
        if $config_loaded;

    if ( ref( $config_override ) eq 'HASH' )
    {
        my $debug_level = $config_override->{DEBUG};

        $debug_level = 0
            if !defined( $debug_level ) or
                ref( $debug_level ) or
                "$debug_level" !~ /\A[0-9]+\z/ or
                $debug_level > DEBUG_LEVEL_MAX;

        %config = (
            DEBUG   => 0 + $debug_level,
            SYSLOG  => 0,
        );

        $config_loaded = 1;

        return;
    }

    # #
    #   Windows does not load /etc/csf/csf.conf.
    #   
    #   Allow any DEBUG:X log level and disable syslog so that   the
    #   ConfigServer::Logger module can run tests in Windows.
    #   
    #   @todo       Possibly add Windows support for Config module
    #               later.
    # #

    if ( $^O eq 'MSWin32' )
    {
        %config =
        (
            DEBUG   => DEBUG_LEVEL_MAX,
            SYSLOG  => 0,
        );

        $config_loaded = 1;

        return;
    }

    ConfigServer::DebugLocal::log( 1, 'info', "status:[loading configuration]" );

    my $config_loader   = ConfigServer::Config->loadconfig();
    %config             = $config_loader->config();

    ConfigServer::Secrets::register_secrets( \%config );

    $config_loaded = 1;

    ConfigServer::DebugLocal::log( 1, 'info',
        "settings:[" . scalar( keys %config ) . "] status:[loaded]"
    );

    logfile( 'root', 'ok', 'CSF configuration loaded' );

    return;
}

# #
#   Logger › Syslog › Load
#   
#   Load Sys::Syslog only when SYSLOG is enabled in csf.conf.
#   Skip load if Sys::Syslog has already been initialized.
#   
#   Set $sys_syslog when the module loads successfully.
#   
#   @test       Note:           Skip Sys::Syslog before config is loaded
#               Sub:            my $result = _syslog_load();
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'my $result = ConfigServer::Logger::_syslog_load(); print defined($result) ? $result : q{undef}, qq{\n};'
#               Result:         undef
#   
#   @params     void 
#   @return                     int|undef   Syslog load state
#                                               1           Module loaded
#                                               0           Module unavailable
#                                               undef       SYSLOG disabled
# #

sub _syslog_load
{
    return
        if !$config{SYSLOG};

    return $sys_syslog
        if defined( $sys_syslog );

    my $is_loaded = eval
    {
        local $SIG{__DIE__};
        require Sys::Syslog;
        1;
    };

    # sys_syslog = 1 (is loaded)
    $sys_syslog = $is_loaded ? 1 : 0;

    return $sys_syslog;
}

# #
#   Logger › Hostname
#   
#   $hostname   = server01.configserver.dev
#   $hostshort  = server01
# #

my $hostname = HOSTNAME_DEFAULT;
if ( -e '/proc/sys/kernel/hostname' )
{
    if ( open( my $hostname_file, '<', '/proc/sys/kernel/hostname' ) )
    {
        my $hostname_read = <$hostname_file>;
        close( $hostname_file );

        if ( defined( $hostname_read ) )
        {
            $hostname_read =~ s/[\r\n]+\z//;
            $hostname = $hostname_read
                if $hostname_read ne '';
        }
    }
}

# #
#   Logger › Hostname › Short
#       server01.configserver.dev => server01
# #

my $hostshort = ( split( /\./, $hostname, 2 ) )[ 0 ];
$hostshort = HOSTNAME_DEFAULT
    if !defined( $hostshort ) or
       length( $hostshort ) > HOSTNAME_LABEL_CHAR_MAX or
       $hostshort !~ /\A[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\z/;

# #
#   Logger › Paths › Normal Log
#   
#	Build full absolute path for normal lfd logs.
#       /var/log/lfd.log
#   
#	@test       Note:           Build normal log path
#	            Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'print ConfigServer::Logger::_normal_log_path(q{/var/log}), qq{\n};'
#	            Result:         /var/log/lfd.log
#   
#	@params     logdir          str         Dir containing log file
#	@return                     str         Absolute path to normal log file
# #

sub _normal_log_path
{
    my ( $logdir ) = @_;
    return "$logdir/" . LOGFILE_NORMAL;
}

# #
#   Logger › Paths › Root Log
#   
#	Build full absolute path to root lfd log.
#       /var/log/lfd_root.log
#   
#   Should be reserved for core actions.
#   
#	@test       Note:           Build root log path
#	            Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'print ConfigServer::Logger::_root_log_path(q{/var/log}), qq{\n};'
#	            Result:         /var/log/lfd_root.log
#   
#	@params     logdir          str         Dir containing log file
#	@return                     str         Absolute path to root log file
# #

sub _root_log_path
{
    my ( $logdir ) = @_;
    return "$logdir/" . LOGFILE_ROOT;
}

# #
#   Logger › Paths › Messenger Log
#   
#	Build full absolute path for messenger lfd log.
#       /var/log/lfd_messenger.log
#   
#	@test       Note:           Build Messenger log path
#	            Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'print ConfigServer::Logger::_msngr_log_path(), qq{\n};'
#	            Result:         /var/log/lfd_messenger.log
#   
#	@params     void
#	@return                     str         Absolute path to messenger log file
# #

sub _msngr_log_path
{
    return LOGFILE_DIR . '/' . LOGFILE_MESSENGER;
}

# #
#   Logger › Lock (Exclusive)
#   
#   Tries to get a lock on an open file handle. Retry for a limited 
#   amount of time, if the file is already locked.
#   
#   LOG_LOCK_ATTEMPT_MAX        Number of attempts to obtain lock
#   LOG_LOCK_DELAY_SECONDS      Delay between unsuccessful attempts
#   
#	@test       Note:           Obtain lock on a tenp file
#	            Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -MFile::Temp=tempfile -e 'my ($fh, $path) = tempfile(UNLINK => 1); my $is_locked = ConfigServer::Logger::_logger_lock_exclusive($fh); print(($is_locked // q{undef}), qq{\n}); close($fh);'
#	            Result:         1
#   
#	@params     fh              glob        Open file handle to lock
#	@return                     int|undef   If exclusive lock on file obtained
#	                                            1           Lock obtained
#	                                            undef       Lock failed
# #

sub _logger_lock_exclusive
{
    my ( $fh ) = @_;
    for my $poll ( 1 .. LOG_LOCK_ATTEMPT_MAX )
    {
        return 1
            if CORE::flock( $fh, Fcntl::LOCK_EX( ) | Fcntl::LOCK_NB( ) );

        select( undef, undef, undef, LOG_LOCK_DELAY_SECONDS )
            if $poll < LOG_LOCK_ATTEMPT_MAX;
    }

    return;
}

# #
#   Logger › Handle (Abort)
#   
#   Close file handle after previous operation has failed. Add 
#   another error if the file handle can't be closed.
#   
#	@test       Note:           Close temp file after failure
#	            Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -MFile::Temp=tempfile -e 'my ($fh, $path) = tempfile(UNLINK => 1); my ($status, $error) = ConfigServer::Logger::_logger_handle_abort($fh, q{write failed}, q{test log msg}); print q{Status: }, (defined($status) ? $status : q{undef}), qq{\nError: $error\n};'
#	            Result:         Status: undef
#	                            Error:  write failed
#   
#	@params     fh              glob        Open file handle to close
#	            err             str         Error from the failed operation
#	            desc            str         File desc used in close errors
#   
#	@return     status          undef       Operation failed
#	            err             str         Original error and any close error
# #

sub _logger_handle_abort
{
    my ( $fh, $err, $desc ) = @_;

    my $is_closed = close( $fh );
    return ( undef, $err )
        if $is_closed;

    return ( undef, "$err; unable to close $desc" );
}

# #
#   Logger › Handle (Finish)
#   
#   Release file lock and close file handle after everything
#   successful.
#   
#	@test       Note:           Unlock and close temp file
#	            Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -MFile::Temp=tempfile -e 'my ($fh, $path) = tempfile(UNLINK => 1); ConfigServer::Logger::_logger_lock_exclusive($fh) or die qq{Unable to lock file\n}; my ($status, $error) = ConfigServer::Logger::_logger_handle_finish($fh, q{test log msg}); print q{Status: }, (defined($status) ? $status : q{undef}), qq{\nError: }, (defined($error) ? $error : q{undef}), qq{\n};'
#	            Result:         Status: 1
#	                            Error:  undef
#   
#	@params     fh              glob        Open and locked file handle
#	            desc            str         File desc used in errors
#   
#	@return     status          int|undef   Result of finishing the file
#	                                            1           File unlock / close successful
#	                                            undef       File unlock / close failed
#	            error           str|undef   Error message if handle failed
#                                               str         File unlock / close failed
#                                               undef       File unlock / close successful
# #

sub _logger_handle_finish
{
    my ( $fh, $desc ) = @_;

    my $is_unlocked = CORE::flock( $fh, Fcntl::LOCK_UN() );
    my $is_closed   = close( $fh );

    return ( undef, "unable to release $desc lock" )
        if !$is_unlocked;

    return ( undef, "unable to close $desc" )
        if !$is_closed;

    return ( 1, undef );
}

# #
#   Logger › Logfile
#   
#   Writes logs to the designated csf / lfd log file.
#       /var/log/lfd.log
#   
#   Messages may be sent to SYSLOG (if SYSLOG enabled in csf.conf)
#       SYSLOG = "1"
#   
#   @test       Note:           Run actual logfile(); redact, etc.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -MConfigServer::Logger -e 'my $marker = qq{CSF-TEST-$$}; my $secret = qq{FakeSecret-$$-A7X9B4Q2}; ConfigServer::Secrets::register_secret(q{TEST_PASSWORD}, $secret) or die qq{Secret registration failed\n}; my $result = ConfigServer::Logger::logfile(q{root}, q{info}, qq{$marker password=$secret}); die qq{Log write failed\n} if !defined($result) or !$result->{written}; my $path = ConfigServer::Logger::_root_log_path(q{/var/log}); open(my $in, q{<:raw}, $path) or die $!; my $match; while (my $line = <$in>) { $match = $line if index($line, $marker) >= 0; } close($in) or die $!; my $passed = defined($match) && index($match, $secret) < 0 && index($match, q{[REDACTED]}) >= 0; print qq{Written: $result->{written}\nPath: $path\nRedaction: }, ($passed ? q{PASS} : q{FAIL}), qq{\n};'
#               Result:         Written:    1
#                               Path:       /var/log/lfd_root.log
#                               Redaction:  PASS
#   
#               Note:           Test redaction of value gid and uid fields
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -MConfigServer::Logger -e 'my $marker = qq{CSF-FIELD-TEST-$$}; my $fields = q{dir:[/var] is_directory:[1] is_root_owned:[1] is_protected:[1] uid:[0] gid:[0] mode:[0755] links:[22] status:[trust returned]}; my $result = ConfigServer::Logger::logfile(q{root}, q{info}, qq{$marker $fields}); die qq{Log write failed\n} if !defined($result) or !$result->{written}; my $path = ConfigServer::Logger::_root_log_path(q{/var/log}); open(my $in, q{<:raw}, $path) or die $!; my $match; while (my $line = <$in>) { $match = $line if index($line, $marker) >= 0; } close($in) or die $!; my $passed = defined($match) && index($match, q{uid:[0]}) < 0 && index($match, q{gid:[0]}) < 0 && index($match, q{uid:[REDACTED]}) >= 0 && index($match, q{gid:[REDACTED]}) >= 0; print qq{Written: $result->{written}\nPath: $path\nField redaction: }, ($passed ? q{PASS} : q{FAIL}), qq{\n};'
#               Result:         Written:    1
#                               Path:       /var/log/lfd_root.log
#                               Redaction:  PASS
#               Log:            uid:[REDACTED] gid:[REDACTED] mode:[0755] links:[22] status:[trust returned] ] status:[append log]
#   
#               Note:           Build root log result; skip write to file
#               Sub:            my $result = logfile( "root", "info", "Test message" );
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'no warnings q{redefine}; local *ConfigServer::Logger::_log_add = sub { return (1, undef); }; my $result = ConfigServer::Logger::logfile(q{root}, q{info}, q{Test message}); print qq{Written: $result->{written}\nTarget: $result->{target}\nStatus: $result->{status}\n};'
#               Result:         Written:    1
#                               Target:     root
#                               Status:     info
#   
#   @params     type            str         (Optional) normal, root, all, or DEBUG:X
#               status          str|int     (Optional) log status
#               message         any         Message / obj to redact and log
#   
#   @return     result          hashref|undef   Log result
#                                               hashref     Log write successful or suppressed
#                                               undef       Log write failed
# #

sub logfile
{
    my ( @args )    = @_;
    my $type        = "normal";
    my $logdir      = $^O eq "MSWin32" ? LOGFILE_TEST_DIR : LOGFILE_DIR;
    my $logdirsub   = LOGFILE_DIR_SUB;

    # #
    #   OS: Windows
    # #

    if ( $^O eq 'MSWin32' )
    {
        for my $dir ( $logdir, "$logdir/$logdirsub" )
        {
            eval
            {
                File::Path::make_path( $dir );
            };

            die $@
                if $@ and $@ !~ /File exists/i and $@ !~ /already exists/i;
        }
    }

    # #
    #   Logfile › Args
    # #

    my $status          = 'info';
    my $message;

    if ( @args == 3 )
    {
        $type           = $args[ 0 ];
        $status         = $args[ 1 ];
        $message        = $args[ 2 ];
    }
    elsif ( @args == 2 )
    {
        $status         = $args[ 0 ];
        $message        = $args[ 1 ];
    }
    elsif ( @args == 1 )
    {
        $message        = $args[ 0 ];
    }

    $type = 'normal'
        if !defined( $type ) or ref( $type );

    $type               = "$type";
    $message            = ConfigServer::Secrets::redact_obj_log( $message );

    my @caller_direct   = caller( 0 );
    my $file            = $caller_direct[ 1 ] // 'unknown';
    my $line            = $caller_direct[ 2 ];
    my $sub             = ( caller( 1 ) )[ 3 ];

    # #
    #   @vars       $file               /usr/local/csf/bin/lfd.pl
    #               $file               lfd.pl
    #               $file               lfd
    # #

    $file               =~ s{^.*[\\/]}{};
    $file               =~ s{\.pl$}{};

    my $src;
    if ( defined( $sub ) )
    {
        $sub =~ s{^.*::}{};
        $src = $file . "::" . $sub . "():" . $line;
    }
    else
    {
        $src = $file . "::" . "global:" . $line;
    }

    # #
    #   Logfile › Status Mapping
    # #

    $status = 'info'
        if !defined( $status ) or ref( $status );

    $status = lc( $status )
        if $status !~ /^\d+$/;

    $status = $STATUS_MAP{ $status } // lc( $status );
    $status =~ s/[^a-z0-9_-]//g;
    $status = substr( $status, 0, LOG_STATUS_CHAR_MAX );
    $status = 'info' if $status eq '';

    # #
    #   Logfile › Set Target (type)
    # #

    my $target          = lc( $type );
    my $debug_type      = '';
    my $debug_level;

    # #
    #   if ( open( my $log_date, ">>", "/tmp/csf_debug_module_logger.log" ) )
    #   {
    #       print $log_date "message=[$message]\n";
    #       print $log_date "target=[$target]\n";
    #       print $log_date "message=[$message]\n\n";
    #       close( $log_date );
    #   }
    # #

    # #
    #   @usage      Logger::logfile( "DEBUG:0", "info", "This is a debug msg" );
    #               Logger::logfile( "DEBUG:5", "info", "This is a debug msg" );
    # #

    if ( $type =~ /\ADEBUG:([0-9])\z/i and $1 <= DEBUG_LEVEL_MAX )
    {
        $debug_level    = $1;
        $target         = 'normal';

        $debug_type = "DEBUG:$debug_level"
            if $debug_level > 0;
    }

    # #
    #   Target empty
    #   
    #   @usage      Logger::logfile( "BAD_TARGET", "info", "The target for this log will default to 'normal'" );
    # #

    elsif ( $target ne 'normal' and $target ne 'root' and $target ne 'all' )
    {
        $target = 'normal';
    }

    # #
    #   Logfile › Timestamp
    # #

    my ( undef, $month, $date_month_day, $clock ) =
        split( /\s+/, scalar localtime );

    $date_month_day     = sprintf( "%2d", $date_month_day );
    my $date_ts         = "$month $date_month_day $clock";

    my $root_line;
    my $root_written    = 0;

    my $normal_line;
    my $normal_written  = 0;

    # #
    #   Logfile › Type › Root Log
    #   
    #   'root':     Step 1      write /var/log/lfd_root.log
    #               Step 2      return without loading CSF config or Sys::Syslog
    #   
    #   'all':      Step 1      write /var/log/lfd_root.log
    #               Step 2      write /var/log/lfd.log
    #                               same message as root
    #               Step 3      send to syslog
    #                               if enabled and SYSLOG available
    #               Step 4      return hashref after successful file writes
    #                           return undef if either file write fails
    #   
    #   @usage      Logger::logfile( "root", "info", "This is a root only log, saved to /var/log/lfd_root.log" );
    #               Logger::logfile( "all", "info", "This is a root + normal log, saved to /var/log/lfd_root.log and /var/log/lfd.log" );
    # #

    if ( $target eq 'root' or $target eq 'all' )
    {
        my $logfile_root            = _root_log_path( $logdir );
        $root_line                  = "$date_ts $hostshort " . LOGFILE_PROCESS . "[ $$ ] [ROOT] [$src] [$status]: $message\n";
        my ( $root_ok, $root_err )  = _log_add( $logfile_root, $root_line );
        if ( !$root_ok )
        {
            print STDERR "[ERROR] Unable to write log file [$logfile_root]: $root_err\n";
            return;
        }

        $root_written = 1;

        if ( $target eq 'root' )
        {
            # #
            #   See @tag for full list / desc of each returned
            #   value:
            #   
            #   @tag[2001]      Logger::logfile:return
            # #

            return
            {
                written         => 1,
                root_written    => 1,
                normal_written  => 0,
                suppressed      => 0,
                target          => $target,
                status          => $status,
                source          => $src,
                message         => $message,
                root_line       => $root_line,
            };
        }
    }

    # #
    #   Logfile › Type › Normal / Debug Log
    #   
    #   Requires /etc/csf/csf.conf to be loaded
    # #

    _config_load( );

    if ( defined( $debug_level ) )
    {
        if ( ( $config{DEBUG} // 0 ) < $debug_level )
        {
            # #
            #   See @tag for full list / desc of each returned
            #   value:
            #   
            #   @tag[2001]      Logger::logfile:return
            # #

            return
            {
                written         => 0,
                root_written    => 0,
                normal_written  => 0,
                suppressed      => 1,
                target          => $target,
                status          => $status,
                source          => $src,
                message         => $message,
                debug_level     => $debug_level,
            };
        }
    }

    _syslog_load( );

    my $logfile     = _normal_log_path( $logdir );
    $normal_line    = "$date_ts $hostshort " . LOGFILE_PROCESS . "[ $$ ] [$src] [$status]" . ( $debug_type ne "" ? " [$debug_type]" : "" ) . ": $message\n";

    my $ruid        = $^O eq 'MSWin32' ? $< : POSIX::getuid( );
    my $euid        = $^O eq 'MSWin32' ? $> : POSIX::geteuid( );

    # #
    #   Logfile › Type › Normal / Debug › Messenger
    #   
    #   @important      After ConfigServer::Messenger::drop_messenger_privileges()
    #                   succeeds, logs can be written to /var/log/lfd_messenger.log
    #                   by going to ConfigServer/Messenger.pm, and calling logfile()
    #                   with either target 'normal' or 'debug:x'.
    #                       logfile( "normal", "info", "Messenger log" );
    #                       logfile( "debug:1", "info", "Messenger log" );
    #   
    #                   Do not use the 'all' target after the privilege drop since it
    #                   attempts to write to lfd_root.log first.
    #   
    #                   First expected Messenger log:
    #                       Messenger initialized securely as MESSENGER_USER
    # #

    if ( $ruid != ROOT_UID or $euid != ROOT_UID )
    {
        if ( $ruid != $euid )
        {
            print STDERR "[ERROR] Unable to write Messenger log [real and effective identities differ]\n";
            return;
        }

        my ( $msngr_written, $msngr_write_err ) = _msngr_log_append(
                                                    _msngr_log_path( ),
                                                    $ruid,
                                                    $normal_line,
                                                );

        if ( !$msngr_written )
        {
            print STDERR "[ERROR] Unable to write Messenger log [$msngr_write_err]\n";
            return;
        }

        $normal_written = 1;
    }
    else
    {
        my ( $written, $write_err ) = _log_add( $logfile, $normal_line );
        if ( !$written )
        {
            print STDERR "[ERROR] Unable to write log file [$logfile]: $write_err\n";
            return;
        }

        $normal_written = 1;
    }

    # #
    #   Logfile › Syslog Enabled
    #   
    #   Log lfd messages to SYSLOG in addition to selected log file.
    #   Must have the perl module Sys::Syslog installed to use
    #   
    #   Configured in /etc/csf/csf.conf
    #   
    #   @test       Note:           Test SYSLOG without having to fire up CSF. Makes life easier.
    #               Command:        sudo env DEBUG=4 perl -I. -MSys::Syslog -e 'eval { Sys::Syslog::openlog("lfd","ndelay,pid","user"); Sys::Syslog::syslog("info","%s","CSF SYSLOG TEST"); Sys::Syslog::closelog(); 1 } or die "Syslog failed\n"; print "Sent\n";'
    #                               Check SYSLOG after:
    #                                   sudo journalctl --since "3 minutes ago" -t lfd --no-pager
    #               Return:         Sent
    # #

    if ( $config{SYSLOG} and $sys_syslog )
    {
        my $syslog_written = eval
        {
            local $SIG{__DIE__};
            Sys::Syslog::openlog    ( LOGFILE_PROCESS, 'ndelay,pid', 'user' );
            Sys::Syslog::syslog     ( 'info', '%s', $message );
            Sys::Syslog::closelog   ( );
            1;
        };

        if ( $syslog_written )
        {
            ConfigServer::DebugLocal::log( 1, 'ok',
                "process:[" . LOGFILE_PROCESS . "] status:[syslog write completed]"
            );
        }
        else
        {
            ConfigServer::DebugLocal::log( 1, 'warn',
                "process:[" . LOGFILE_PROCESS . "] status:[syslog write failed]"
            );
        }
    }

    # #
    #   Summary of what is returned
    #   
    #   @tag[2001]      Logger::logfile:return
    #   
    #   written         Log was written to at least ONE log file.
    #                       0 = no
    #                       1 = yes
    #   
    #   root_written    Log was written to root /var/log/lfd_root.log file
    #                       0 = no
    #                       1 = yes
    #   
    #   normal_written  Log was written to normal or Messenger log file.
    #                       0 = no
    #                       1 = yes
    #   
    #   suppressed      If requested log level is higher than configured DEBUG
    #                       0 = message allowed
    #                       1 = message suppressed and not written
    #   
    #   target          Final log target written
    #                       - normal
    #                       - root
    #                       - all
    #   
    #   status          Final mapped status
    #                       Eg:         "warn"
    #   
    #   source          File:line where logfile() was called from.
    #                       Eg:         "Logger.pm::test_sub():454"
    #   
    #   message         Redacted message returned by ConfigServer::Secrets.
    #                       Eg:         "[TEST] Root log only"
    #   
    #   debug_level     DEBUG level requested by caller:
    #                       Eg:         3
    #                       Returns:    undef for a normal/root/all log
    #   
    #   root_line       Complete formatted log written to root log
    #                       Eg:         "Oct 11 04:10:00 csf lfd[ 1234 ] [ROOT] [Logger.pm::test_sub():454] [info]: Message\n"
    #                       Returns:    undef if no root log was written
    #   
    #   line            Complete line written to normal or Messenger log
    #                       Eg:         "Oct 11 04:10:00 csf lfd[ 1234 ] [Logger.pm::test_sub():454] [info]: Message\n"
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
        source          => $src,
        message         => $message,
        debug_level     => $debug_level,
        root_line       => $root_line,
        line            => $normal_line,
    };
}

# #
#   Logger › Messenger › Prepare
#	
#	Prepare Messenger log before Messenger drops root privileges.
#   
#   @test       Note:           Reject missing Messenger owner ids
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'my ($status, $error) = ConfigServer::Logger::msngr_log_prepare(undef, undef); print q{Status: }, (defined($status) ? $status : q{undef}), qq{\nError: $error\n};'
#               Result:         Status: undef
#                               Error:  Messenger log owner IDs are invalid
#   
#   @params     uid             int         Messenger user id
#               gid             int         Messenger group id
#   
#   @return     status          int|undef   Preparation result
#                                               1           Log prep success
#                                               undef       Log prep fail
#               error           str|undef   Error message
#                                               str         Log prep fail
#                                               undef       Log prep success
# #

sub msngr_log_prepare
{
    my ( $uid, $gid ) = @_;

    ConfigServer::DebugLocal::log( 1, 'info',
        "path:[" . _msngr_log_path( ) . "] status:[preparing messenger log]"
    );

    return _msngr_log_prepare( _msngr_log_path( ), $uid, $gid );
}

# #
#   Logger › Messenger › Normalize › ID
#   
#   Convert a uid or gid into positive num within an allowed range.
#   
#   @test       Note:           Normalize uid or gid with leading zeroes
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'my $uid = ConfigServer::Logger::_logger_id_normalize(q{000123}); print defined($uid) ? $uid : q{undef}, qq{\n};'
#               Result:         123
#   
#   @params     id              any         uid or gid to normalize
#   @return     id              int|undef   Positive uid or gid
#                                               int         Normalized uid or gid
#                                               undef       Id undef or invalid
# #

sub _logger_id_normalize
{
    my ( $id ) = @_;

    return
        if !defined( $id ) or ref( $id );

    $id = "$id";

    # reject non-numeric $id or input above max digit len
    return
        if length( $id ) > LOG_OWNER_ID_MAX_DIGIT or $id !~ /\A[0-9]+\z/;

    $id =~ s/\A0+//;

    # reject $id 0 or numeric $id above max uid/gid value
    return
        if $id eq '' or
           ( length( $id ) == LOG_OWNER_ID_MAX_DIGIT and $id gt LOG_OWNER_ID_MAX );

    # normalized $id
    return 0 + $id;
}

# #
#   Logger › Messenger › Validate › Identity
#   
#   Make sure the process's real and effective user ids both match
#   the expected Messenger uid.
#   
#   @test       Note:           Match the current ruid process ID
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -MPOSIX -e 'my $matches = ConfigServer::Logger::_msngr_identity_matches(POSIX::getuid()); print defined($matches) ? $matches : q{undef}, qq{\n};'
#               Result:         1
#   
#   @params     uid             int         Expected Messenger user id
#   @return     matches         int|undef   Process identity match result
#                                               1           ruid and euid both match
#                                               0           ruid or euid differs
#                                               undef       uid is undef
# #

sub _msngr_identity_matches
{
    my ( $uid ) = @_;

    return
        if !defined( $uid );

    my $ruid = $^O eq 'MSWin32' ? $< : POSIX::getuid( );    # ruid 0
    my $euid = $^O eq 'MSWin32' ? $> : POSIX::geteuid( );   # euid 0

    # return 1 if ruid and euid ids match $uid; otherwise 0
    return ( $ruid == $uid and $euid == $uid ) ? 1 : 0;
}

# #
#   Logger › Messenger › Validate › Log Line
#   
#   Verify input log line is within the allowed len, has no null
#   bytes, no embedded line breaks, and ends with 1 newline.
#   
#   @test       Note:           Validate 1 messenger log line
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'my $is_valid = ConfigServer::Logger::_msngr_is_line_valid(qq{Messenger test\n}); print defined($is_valid) ? $is_valid : q{undef}, qq{\n};'
#               Result:         1
#   
#   @params     line            str         Complete Messenger line
#   @return     is_valid        int|undef   Log line validation result
#                                               1           Log line valid
#                                               0           Log line invalid
#                                               undef       Input is invalid
# #

sub _msngr_is_line_valid
{
    my ( $line ) = @_;

    return
        if !defined( $line ) or ref( $line );

    # #
    #   @vars       $line               Messenger test
    #               $line_bytes         Messenger test
    #               $line_byte_len      15
    #               $line_safe          "Messenger test" or OVERSIZED
    #               $line_hex           4d657373656e67657220746573740a or OVERSIZED
    # #

    my $line_bytes      = utf8::is_utf8( $line )
                            ? Encode::encode_utf8( $line )
                                : $line;

    my $line_byte_len   = bytes::length( $line_bytes );
    my $line_safe       = $line_byte_len > LOG_LINE_BYTE_MAX
                            ? 'OVERSIZED'
                                : $line_bytes;
    my $line_hex        = $line_byte_len > LOG_LINE_BYTE_MAX
                            ? 'OVERSIZED'
                                : unpack( 'H*', $line_bytes );

    ConfigServer::DebugLocal::log( 1, 'info',
        ConfigServer::DebugLocal::log_singleize(
            'colon',
            [
                line        => $line_safe,
                line_utf8   => utf8::is_utf8( $line ) ? 1 : 0,
                bytes_utf8  => utf8::is_utf8( $line_bytes ) ? 1 : 0,
                bytes       => $line_byte_len,
                bytes_max   => LOG_LINE_BYTE_MAX,
                hex         => $line_hex,
            ]
        ) .
        " status:[checking line valid]"
    );

    # reject oversize lines, null bytes, contains cr, or missing final newline
    return 0
        if $line_byte_len > LOG_LINE_BYTE_MAX or
            $line !~ /\A[^\x00\r\n]*\n\z/;

    return 1;
}

# #
#   Logger › Messenger › Open
#   
#   Open an existing Messenger log without following symlinks.
#   Optionally create the file securely when it does not exist.
#   
#   @test       Note:           Create new temp file
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -MFile::Temp=tempfile -e 'my ($fh, $path) = tempfile(UNLINK => 0); close($fh) or die $!; unlink($path) or die $!; my ($log, $error) = ConfigServer::Logger::_msngr_log_open($path, 1); print q{Opened: }, (defined($log) ? 1 : 0), qq{\nError: }, (defined($error) ? $error : q{undef}), qq{\n}; close($log) if defined($log); unlink($path) if -e $path;'
#               
#               Note:           Open an existing temp file without creating it
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -MFile::Temp=tempfile -e 'my ($fh, $path) = tempfile(UNLINK => 1); close($fh) or die $!; my ($log, $error) = ConfigServer::Logger::_msngr_log_open($path, 0); print q{Opened: }, (defined($log) ? 1 : 0), qq{\nError: }, (defined($error) ? $error : q{undef}), qq{\n}; close($log) if defined($log);'
#               Result:         Opened:     1
#                               Error:      undef
#   
#   @params     path            str         Absolute Messenger log path
#               allow_create    int         If missing file can be created
#                                               1           Allow create
#                                               0           Existing file required
#   
#   @return     log             fh|undef    Messenger log file handle
#                                               fh          Log opened or created
#                                               undef       Open or create failed
#               err             str|undef   Open or create error
#                                               str         Open or create failed
#                                               undef       Log opened or created
# #

sub _msngr_log_open
{
    my ( $path, $allow_create ) = @_;

    my $nofollow = eval { Fcntl::O_NOFOLLOW() };
    return ( undef, "O_NOFOLLOW not available" )
        if !defined( $nofollow );

    # 134145
    my $open_flags = Fcntl::O_WRONLY( ) | Fcntl::O_APPEND( ) | Fcntl::O_NONBLOCK( ) | $nofollow;
    my $log;

    # open existing $log file
    return ( $log, undef )
        if CORE::sysopen( $log, $path, $open_flags );

    my $open_errno  = 0 + $!;
    my $open_detail = "$!";

    return ( undef, "Messenger log could not be opened securely: $open_detail" )
        if !$allow_create;

    return ( undef, "Messenger log open failed before creation" )
        if $open_errno != Errno::ENOENT();

    local $!;

    # set umask to 0077; save previous umask
    my $umask_prev = umask( MESSENGER_LOG_UMASK );

    # create new log
    my $is_created = CORE::sysopen(
        $log,
        $path,
        $open_flags | Fcntl::O_CREAT( ) | Fcntl::O_EXCL( ),
        MESSENGER_LOG_MODE,
    );

    # restore previous umask
    umask( $umask_prev );

    ConfigServer::DebugLocal::log( 1, 'info',
        ConfigServer::DebugLocal::log_singleize(
            'colon',
            [
                log         => $log,
                path        => $path,
                open_flags  => $open_flags,
                umask_prev  => $umask_prev,
                is_created  => $is_created
            ]
        ) .
        " status:[checking Messenger log create]"
    );

    return ( undef, "Messenger log could not be created securely" )
        if !$is_created;

    # missing log  created successfully
    return ( $log, undef );
}

# #
#   Logger › Messenger › Process Log
#   
#   Open / lock messenger log, run callback, verify log before and
#   after, unlock and close when finished.
#   
#   @test       Note:           Accept transaction
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -MPOSIX -e 'my $path = qq{/var/log/lfd-transaction-test-$$.log}; my $expected = {uid => POSIX::geteuid(), gid => undef, allow_root_own => 0, mode => 0600}; my $opts = {path => $path, create => 1, before => $expected, after => $expected}; my ($status, $error) = ConfigServer::Logger::_msngr_log_process($opts, sub { return (1, undef); }); print q{Status: }, (defined($status) ? $status : q{undef}), qq{\nError: }, (defined($error) ? $error : q{undef}), qq{\n}; unlink($path) if -e $path;'
#               Result:         after_ok:   1
#                               after_err:  undef
#                               Status:     1
#                               Error:      undef
#   
#               Note:           Reject transaction; 'no such file' error, (create => 0)
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'my $opts = {path => q{/var/log/lfd_test_relative.log}, create => 0, before => {}, after => {}}; my ($status, $error) = ConfigServer::Logger::_msngr_log_process($opts, sub { return (1, undef); }); print q{Status: }, (defined($status) ? $status : q{undef}), qq{\nError: $error\n};'
#               Result:         Status:     undef
#                               Error:      Messenger log could not be opened securely: No such file or directory
#   
#               Note:           Reject transaction; 'owner match' error, (create => 1)
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'my $opts = {path => q{/var/log/lfd_test_relative.log}, create => 1, before => {}, after => {}}; my ($status, $error) = ConfigServer::Logger::_msngr_log_process($opts, sub { return (1, undef); }); print q{Status: }, (defined($status) ? $status : q{undef}), qq{\nError: $error\n};'
#               Result:         Status:     undef
#                               Error:      Messenger log owner does not match
#   
#               Note:           Reject transaction; relative path
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'my $opts = {path => q{relative.log}, create => 0, before => {}, after => {}}; my ($status, $error) = ConfigServer::Logger::_msngr_log_process($opts, sub { return (1, undef); }); print q{Status: }, (defined($status) ? $status : q{undef}), qq{\nError: $error\n};'
#               Result:         Status:     undef
#                               Error:      Messenger log path must be absolute
#   
#   @params     opts            hashref     Path, creation, and file requirements
#               cb              coderef     Action performed while file is locked
#   
#   @return     status          int|undef   Messenger transaction result
#                                               1           Transaction completed
#                                               undef       Transaction failed
#               error           str|undef   Transaction error
#                                               str         Transaction failed
#                                               undef       Transaction completed
# #

sub _msngr_log_process
{
    my ( $opts, $cb ) = @_;

    ConfigServer::DebugLocal::log( 1, 'info',
        _msngr_debug_process( $opts, $cb )
    );

    # $opts and $cb should be valid types
    return ( undef, "invalid Messenger log transaction" )
        if ref( $opts ) ne 'HASH' or
           ref( $opts->{before} ) ne 'HASH' or
           ref( $opts->{after} ) ne 'HASH' or
           ref( $cb ) ne 'CODE';

    # make sure parent log path is valid; all parent folders are trusted
    my ( $path_ok, $path_err ) = _msngr_path_validate( $opts->{path} );
    return ( undef, $path_err )
        if !$path_ok;

    # open existing messenger log; re-create if it doesn't exist
    my ( $log_fh, $open_err ) = _msngr_log_open(
        $opts->{path},
        $opts->{create},
    );

    # couldn't open messenger log file
    return ( undef, $open_err )
        if !defined( $log_fh );

    # close messenger $log; return failure if raw mode can't be set
    return _logger_handle_abort(
        $log_fh,
        "unable to set Messenger log binary mode",
        "Messenger log",
    ) if !binmode( $log_fh, ":raw" );

    # close messenger log; return failure if log can't be locked.
    return _logger_handle_abort(
        $log_fh,
        "Messenger log lock could not be acquired",
        "Messenger log",
    ) if !_logger_lock_exclusive( $log_fh );

    # #
    #   Make sure the opened log is the correct one, check to make sure it
    #   contains the expected ownership and perms.
    #   
    #   If perms / ownership change during write; abort, close the file.
    #   
    #   $before_ok      int
    #   $before_err     str
    # #

    my ( $before_ok, $before_err ) = _msngr_file_validate(
        $log_fh,
        $opts->{path},                       # /var/log/lfd_test_2284808.log
        $opts->{before}->{uid},              # 0
        $opts->{before}->{gid},              # 0
        $opts->{before}->{allow_root_own},   # 1
        $opts->{before}->{mode},             # decimal: 384 = octal: 0600
    );

    return _logger_handle_abort( $log_fh, $before_err, "Messenger log" )
        if !$before_ok;

    # run callback, throw error if anything screwed up
    my ( $cb_ok, $cb_err ) = $cb->( $log_fh );
    return _logger_handle_abort( $log_fh, $cb_err, "Messenger log" )
        if !$cb_ok;

    # #
    #   Make sure $before and $after option values match
    #   
    #   $after_ok       int
    #   $after_err      str
    # #

    my ( $after_ok, $after_err ) = _msngr_file_validate(
        $log_fh,
        $opts->{path},                          # /var/log/lfd_test_2284808.log
        $opts->{after}->{uid},                  # 0
        $opts->{after}->{gid},                  # 0
        $opts->{after}->{allow_root_own},       # 0
        $opts->{after}->{mode},                 # 384
    );

    # something went wrong with $after comparison
    return _logger_handle_abort( $log_fh, $after_err, "Messenger log" )
        if !$after_ok;

    ConfigServer::DebugLocal::log( 1, 'info',
        "path:[$opts->{path}] status:[transaction success]"
    );

    # success
    return _logger_handle_finish( $log_fh, "Messenger log" );
}

# #
#   Logger › Messenger › Validate › Directory Trusted
#	
#	Check if existing parent dir is safe to use in Messenger
#   log path.
#   
#	@test       Note:           Check a trusted system log dir
#	            Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'my $trusted = ConfigServer::Logger::_msngr_dir_istrusted(q{/var/log}); print defined($trusted) ? $trusted : q{undef}, qq{\n};'
#	            Result:         1
#   
#	            Note:           Check a trusted sys log dir (use local module)
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -MConfigServer::Logger -e 'my $trusted = ConfigServer::Logger::_msngr_dir_istrusted(q{/var/log}); print defined($trusted) ? $trusted : q{undef}, qq{\n};'
#	            Result:         1
#   
#	@params     dir             str         Existing parent dir
#   
#	@return     is_trusted      int|undef   Dir trust result
#	                                            1           Dir trusted
#	                                            undef       Dir unsafe
# #

sub _msngr_dir_istrusted
{
    # #
    #   $dir        /var/log
    #   $dir_text   '/var/log' or 'none'
    #               Ensures $dir always has a value, not undef
    # #

    my ( $dir ) = @_;

    # return $dir or 'none'; eg: "/var/log"
    my $dir_text = defined( $dir ) && !ref( $dir ) && length( $dir ) ? $dir : 'none';

    ConfigServer::DebugLocal::log( 1, 'info',
        "dir:[$dir_text] status:[dir trust: checking]"
    );

    # reject missing / invalid dir
    if ( !defined( $dir ) or ref( $dir ) or !length( $dir ) )
    {
        ConfigServer::DebugLocal::log( 1, 'warn',
            "dir:[$dir_text] " .
            "return:[undef] " .
            "route:[dir trust: invalid]"
        );

        return;
    }

    # load dir metadata from lstat
    my $mdata = File::stat::lstat( $dir );
    if ( !defined( $mdata ) )
    {
        ConfigServer::DebugLocal::log( 1, 'warn',
            "dir:[$dir_text] " .
            "return:[undef] " .
            "route:[dir trust: metadata unavailable]"
        );

        return;
    }

    # check dir type, owner, and perms
    my $is_root_owned   = $mdata->uid == ROOT_UID;                                      # ROOT_UID = 0
    my $is_protected    = ( $mdata->mode & MESSENGER_PARENT_UNSAFE_MODE_MASK ) == 0;    # MESSENGER_PARENT_UNSAFE_MODE_MASK = 0022
    my $is_directory    = Fcntl::S_ISDIR( $mdata->mode );
    my $is_trusted      = $is_directory && $is_root_owned && $is_protected;

    # get mode state for $dir
    my $mode_check      = !$is_directory  ? 'not dir'
                            : !$is_root_owned ? 'not root owned'
                            : !$is_protected  ? 'unsafe perms'
                            : 'trusted';

    my $result          = $is_trusted ? 1 : undef;
    my $debug_status    = $is_trusted ? 'ok' : 'warn';

    ConfigServer::DebugLocal::log( 1, $debug_status,
        "dir:[$dir_text] " .
        "is_directory:[$is_directory] " .
        "is_root_owned:[$is_root_owned] " .
        "is_protected:[$is_protected] " .
        "uid:[" . $mdata->uid . "] " .
        "gid:[" . $mdata->gid . "] " .
        "mode:[" . sprintf( '%04o', $mdata->mode & FILE_PERMS_MODE_MASK ) . "] " .
        "links:[" . $mdata->nlink . "] " .
        "return:[" . ( defined( $result ) ? $result : 'undef' ) . "] " .
        "status:[dir trust: $mode_check]"
    );

    return $result;
}

# #
#	Logger › Messenger › Validate › Path
#	
#	Validate the path format, then check each dir leading to
#	the Messenger log. Every dir must be trusted and root owned.
#   
#	@test       Note:           Validate default Messenger log path
#	            Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'my ($status, $error) = ConfigServer::Logger::_msngr_path_validate(q{/var/log/lfd_messenger.log}); print q{Status: }, (defined($status) ? $status : q{undef}), qq{\nError: }, (defined($error) ? $error : q{undef}), qq{\n};'
#	            Result:         Status: 1
#	                            Error:  undef
#   
#	@params     path            str         Absolute Messenger log path
#
#	@return     status          int|undef   Path validation result
#	                                            1           Path and parent dirs passed validation
#	                                            undef       Path or parent dir failed validation
#	            error           str|undef   Validation error
#	                                            str         Validation failed; contains reason
#	                                            undef       Validation succeeds
# #

sub _msngr_path_validate
{
    # #
    #   $path       /var/log/lfd_messenger.log
    # #

    my ( $path ) = @_;

    my $error;
    if ( !defined( $path ) )
    {
        $error = "Messenger log path is missing";
    }

    # #
    #   $path must be a str, no ref.
    #       Accept:     _msngr_path_validate( "/var/log/lfd.log" );
    #       Reject:     _msngr_path_validate( {} );
    # #

    elsif ( ref( $path ) )
    {
        $error = "Messenger log path must be plain text";
    }

    # #
    #   $path exceeds LOG_PATH_BYTE_MAX (4,096 bytes)
    # #

    elsif ( bytes::length( $path ) > LOG_PATH_BYTE_MAX )
    {
        $error = "Messenger log path exceeds byte limit";
    }

    # #
    #   $path must be absolute ( start with / )
    #       Accept:     /var/log/messenger.log
    #       Reject:     var/log//messenger.log
    # #

    elsif ( substr( $path, 0, 1 ) ne '/' )
    {
        $error = "Messenger log path must be absolute";
    }

    # #
    #   Disallow $path chars:
    #       Spaces, backslash, quotes, brackets, etc.
    # #

    elsif ( $path =~ m{[^A-Za-z0-9._/+\-]} )
    {
        $error = "Messenger log path contains unsupported characters";
    }

    # #
    #   $path has repeated forward slashes
    #       Accept:     /var/log/messenger.log
    #       Reject:     /var/log//messenger.log
    # #

    elsif ( index( $path, '//' ) >= 0 )
    {
        $error = "Messenger log path contains an empty section";
    }

    # #
    #   $path must end with filename
    #       Accept:     /var/log/messenger.log
    #       Reject:     /var/log//
    # #

    elsif ( substr( $path, -1, 1 ) eq '/' )
    {
        $error = "Messenger log path must end with a filename";
    }

    # #
    #   $path contains dir '.' (current dir) or '..' (parent dir):
    #       Accept:     /var/log/lfd.log
    #       Reject:     /var/./log/lfd.log
    #       Reject:     /var/../log/lfd.log
    # #

    elsif ( $path =~ m{(?:\A|/)\.{1,2}(?:/|\z)} )
    {
        $error = "Messenger log path contains a dot section";
    }

    # #
    #   $path is valid; check all parent dirs from the log dir
    #   upward to the fs root.
    # #

    else
    {
        # #
        #   Eg:     dir         /var/log 
        #           path        /var/log/lfd_messenger.log
        # #

        my $dir = File::Basename::dirname( $path );
        if ( $dir eq '/' )
        {
            $error = "Messenger log path requires a parent below root";
        }
        else
        {
            # work upward from the log dir; stop at root
            while ( $dir ne '/' )
            {
                if ( !_msngr_dir_istrusted( $dir ) )
                {
                    $error = "Messenger log dir is not trusted";
                    last;
                }

                # #
                #   Eg:     dir             /var/log 
                #           dir_next        /var
                #   
                #           dir             /var 
                #           dir_next        / 
                # #

                my $dir_next = File::Basename::dirname( $dir );
                if ( $dir_next eq $dir )
                {
                    $error = "Messenger log dir chain cannot be resolved";
                    last;
                }

                $dir = $dir_next;
            }
        }
    }

    # return one result after every validation has finished
    return defined( $error ) ? ( undef, $error ) : ( 1, undef );
}

# #
#	Logger › Log › Add New Line (Entry)
#   
#   Open / create log file, enable raw mode, lock, append the log to
#   file, unlock file, and then close it.
#   
#   Runs _log_write( ) to write the bytes to the log file:
#       _log_add( ) => _log_write( )
#   
#   @note       Do not call; use Logger::logfile(); 
#   
#	@test       Note:           Append log to a temp log file
#	            Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -MFile::Temp=tempfile -e 'my ($fh, $path) = tempfile(UNLINK => 1); close($fh) or die $!; my ($status, $error) = ConfigServer::Logger::_log_add($path, qq{test log message\n}); open(my $in, q{<:raw}, $path) or die $!; local $/; my $contents = <$in>; close($in) or die $!; my $passed = $status && !defined($error) && $contents eq qq{test log message\n}; print($passed ? qq{PASS\n} : qq{FAIL\n});'
#	            Result:         PASS
#   
#	@params     path            str         Path to log file
#	            line            str         Line to append to log
#   
#	@return     status          int|undef   Result of appending the line
#	                                            1           Log append success
#	                                            undef       Log append failed
#	            error           str|undef   Error msg if handle failed
#                                               str         Log append failed
#                                               undef       Log append success
# #

sub _log_add
{
    # #
    #   @vars       $path               /tmp/uAscSyZPpK
    #               $line               test log message
    #               $log                glob (fh)
    # #

    my ( $path, $line ) = @_;

    # #
    #   $log populated by SYSOPEN
    # #

    my $log;
    return ( undef, "unable to open log" )
        if !CORE::sysopen(
            $log,
            $path,
            Fcntl::O_WRONLY() | Fcntl::O_APPEND() | Fcntl::O_CREAT(),
            LOGFILE_CREATE_MODE,
        );

    ConfigServer::DebugLocal::log( 1, 'info',
        "log:[$log] path:[$path] line:[$line] status:[append log]"
    );

    return _logger_handle_abort( $log, "unable to set binary log mode", "log" )
        if !binmode( $log, ":raw" );

    return _logger_handle_abort( $log, "unable to acquire log lock", "log" )
        if !_logger_lock_exclusive( $log );

    # undef if log write fails, or 1
    my ( $is_written, $write_err ) = _log_write( $log, $path, $line );
    return _logger_handle_abort( $log, $write_err, "log" )
        if !$is_written;

    return _logger_handle_finish( $log, "log" );
}

# #
#	Logger › Log › Write
#	
#   Writes the log line to log file. 
#   
#   Retries writes until all bytes have been written.
#   
#	@test       Note:           Write log to temp file
#	            Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -MFile::Temp=tempfile -e 'my ($fh, $path) = tempfile(UNLINK => 1); binmode($fh, q{:raw}) or die $!; my ($status, $error) = ConfigServer::Logger::_log_write($fh, $path, qq{Messenger test\n}); seek($fh, 0, 0) or die $!; local $/; my $contents = <$fh>; close($fh) or die $!; my $matches = $contents eq qq{Messenger test\n} ? 1 : 0; print q{Status: }, (defined($status) ? $status : q{undef}), qq{\nError: }, (defined($error) ? $error : q{undef}), qq{\nContents match: $matches\n};'
#	            Result:         Status:         1
#	                            Error:          undef
#	                            Contents match: 1
#   
#	@params     log             fh          Open writable file handle
#	            path            str         Path belonging to log
#	            line            str         Complete log byte str to write
#   
#	@return     status          int|undef   Result of writing log
#	                                            1           Log wrote successful
#	                                            undef       Log wrote failed
#	            error           str|undef   Error message if handle failed
#                                               str         Log wrote failed
#                                               undef       Log wrote successful
# #

sub _log_write
{
    # #
    #   log         glob (fh)
    #   path        /tmp/uAscSyZPpK
    #   line        test record
    # #

    my ( $log, $path, $line ) = @_;

    ConfigServer::DebugLocal::log( 1, 'info',
        "log:[$log] " .
        "path:[$path] " .
        "line:[$line] " .
        "status:[write log]"
    );

    # unicode text => utf8 bytes before write
    my $buffer = utf8::is_utf8( $line )
        ? Encode::encode_utf8( $line )
            : $line;

    # track total bytes and how many were written
    my $bytes_total     = bytes::length( $buffer );
    my $bytes_written   = 0;

    # continue until all bytes written
    while ( $bytes_written < $bytes_total )
    {
        my $bytes_left = $bytes_total - $bytes_written;

        my $write_result = CORE::syswrite(
            $log,
            $buffer,
            $bytes_left,
            $bytes_written,
        );

        # $write_result is undef
        if ( !defined( $write_result ) )
        {
            next
                if $! == Errno::EINTR();

            return ( undef, "unable to append log record" );
        }

        # could not write log
        return ( undef, "unable to append log record" )
            if $write_result == 0;

        $bytes_written += $write_result;
    }

    # log write successful
    return ( 1, undef );
}


# #
#	Logger › Messenger › Prepare › Log
#	
#	Validate, create, secure, and verify the Messenger log file.
#   
#   @test       Note:           Reject invalid Messenger owner ids
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'my ($status, $error) = ConfigServer::Logger::_msngr_log_prepare(q{/var/log/lfd_messenger.log}, undef, undef); print q{Status: }, (defined($status) ? $status : q{undef}), qq{\nError: $error\n};'
#               Result:         Status: undef
#                               Error:  Messenger log owner ids are invalid
#   
#   @params     path            str         Absolute Messenger log path
#               uid             any         Messenger uid to normalize
#               gid             any         Messenger gid to normalize
#   
#   @return     status          int|undef   Result
#                                               1           Successful (Log prepared)
#                                               undef       Failed
#               error           str|undef   Result
#                                               str         Failed (Error message)
#                                               undef       Successful (No error)
# #

sub _msngr_log_prepare
{
    my ( $path, $uid, $gid ) = @_;

    # normalize owner uid / gid
    my %owner =
    (
        uid => scalar _logger_id_normalize( $uid ),
        gid => scalar _logger_id_normalize( $gid ),
    );

    ConfigServer::DebugLocal::log( 1, 'info',
        ConfigServer::DebugLocal::log_singleize(
            'colon',
            {
                path    => $path,
                uid     => $owner{uid},
                gid     => $owner{gid},
            }
        ) .
        " status:[prepare logger]"
    );

    # reject bad / invalid owner ids
    if ( !defined( $owner{uid} ) or !defined( $owner{gid} ) )
    {
        ConfigServer::DebugLocal::log( 1, 'warn',
            "path:[$path] status:[uid or gid missing]"
        );

        return ( undef, "Messenger log owner IDs are invalid" );
    }

    # log file state before and after prep
    my $opts =
    {
        path    => $path,
        create  => 1,
        before  =>
        {
            uid             => $owner{uid},
            gid             => undef,
            allow_root_own  => 1,
            mode            => undef,
        },
        after   =>
        {
            uid             => $owner{uid},
            gid             => $owner{gid},
            allow_root_own  => 0,
            mode            => MESSENGER_LOG_MODE,
        },
    };

    # callback to set log owner, group, perms
    my $log_callback = sub
    {
        my ( $log ) = @_;

        # apply required owner, group, perms
        my $is_secure =
        (
            chown( $owner{uid}, $owner{gid}, $log ) == 1 and
            chmod( MESSENGER_LOG_MODE, $log ) == 1
        );

        # stop if ownership or perms can't be applied
        if ( !$is_secure )
        {
            ConfigServer::DebugLocal::log( 1, 'warn',
                "path:[$path] status:[Messenger log ownership or permissions could not be applied]"
            );

            return ( undef, "Messenger log ownership or permissions could not be applied" );
        }

        return ( 1, undef );
    };

    # log file: open, validate, secure, close, etc
    return _msngr_log_process( $opts, $log_callback );
}

# #
#	Logger › Messenger › Log › Append
#	
#	Append log entry after Messenger has dropped root privileges.
#   
#   @test       Note:           Simulate real log
#               Command:        sudo env DEBUG=4 perl -I. -MPOSIX -MConfigServer::Logger -e 'bytes::length(q{warmup}); Encode::encode_utf8(q{warmup}); my @user = getpwnam(q{csf}); die qq{csf user not found\n} if !@user; my $uid = $user[2]; my $gid = $user[3]; POSIX::setgid($gid) == 0 or die qq{setgid failed: $!\n}; POSIX::setuid($uid) == 0 or die qq{setuid failed: $!\n}; my ($status, $error) = ConfigServer::Logger::_msngr_log_append(q{/var/log/lfd_messenger.log}, $uid, qq{Test\n}); print q{Status: }, (defined($status) ? $status : q{undef}), qq{\nError: }, (defined($error) ? $error : q{undef}), qq{\n};'
#   
#               Note:           Reject missing Messenger identity
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'my ($status, $error) = ConfigServer::Logger::_msngr_log_append(q{/var/log/lfd_messenger.log}, undef, qq{Test\n}); print q{Status: }, (defined($status) ? $status : q{undef}), qq{\nError: $error\n};'
#               Result:         Status: undef
#                               Error:  Messenger process identity is invalid
#   
#   @params     path            str         Absolute Messenger log path
#               uid             any         Messenger uid to normalize
#               line            str         Log line to append
#   
#   @return     status          int|undef   Append result
#                                               1           Log appended
#                                               undef       Log append failed
#               error           str|undef   Error message
#                                               str         Log write failed
#                                               undef       Log write successful
# #

sub _msngr_log_append
{
    my ( $path, $uid, $line ) = @_;

    $uid = _logger_id_normalize( $uid );
    return ( undef, "Messenger process identity is invalid" )
        if !_msngr_identity_matches( $uid );

    return ( undef, "Messenger log line is invalid" )
        if !_msngr_is_line_valid( $line );

    # file must keep the stats below (owner and mode)
    my $expected =
    {
        uid             => $uid,
        gid             => undef,
        allow_root_own  => 0,
        mode            => MESSENGER_LOG_MODE,
    };

    # how to deal with the log file
    my $opts =
    {
        path            => $path,           # log path
        create          => 0,               # don't create new file
        before          => $expected,       #   => ensure the same file state
        after           => $expected,       #   => before and after
    };

    # #
    #   Open, check, lock, and close Messenger log.
    #   Write new log line if / while the log file is locked.
    # #

    return _msngr_log_process(
        $opts,
        sub
        {
            my ( $log ) = @_;
            return _log_write( $log, $path, $line );
        },
    );
}

# #
#	Logger › Messenger › File › Error Policy
#   
#   Check required perm mode, group, and owner for Messenger log file.
#   
#   @test       Note:           Accept matching owner, group, mode
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -MFile::Temp=tempfile -e 'my ($fh, $path) = tempfile(UNLINK => 1); chmod(ConfigServer::Logger::MESSENGER_LOG_MODE(), $path) or die $!; my $mdata = File::stat::stat($fh); my $error = ConfigServer::Logger::_msngr_file_policy_err($mdata, $path, $mdata->uid, $mdata->gid, 0, ConfigServer::Logger::MESSENGER_LOG_MODE()); print defined($error) ? $error : q{undef}, qq{\n}; close($fh) or die $!;'
#               Result:         undef
#   
#   @params     mdata           obj         Open file metadata
#               path            str         Absolute Messenger log path
#               uid             int         Expected file owner
#               gid             int|undef   Expected group (undef to skip)
#               allow_root_own  int         If root ownership allowed
#               mode            int|undef   Expected / required mode (undef to skip)
#   
#   @return     error           str|undef   Policy error message
#                                               str         Policy requirements failed
#                                               undef       Policy requirements met successfully
# #

sub _msngr_file_policy_err
{
    # #
    #   @vars       $mdata              array (fstat)
    #               $path               /tmp/o624V5tDDs 
    #               $uid                0
    #               $gid                0
    #               $allow_root_own     0
    #               $mode               384
    #               $path_absolute      /tmp/o624V5tDDs
    # #

    my ( $mdata, $path, $uid, $gid, $allow_root_own, $mode ) = @_;

    my $path_absolute = defined( $path ) && !ref( $path )
        ? "$path"
            : 'undef';

    # the perm / mode a log file is required to have
    my $mode_oct = 'undef';

    # #
    #   If $mode is undef; perm check intentionally skipped by:
    #       before  => { mode => undef }
    #       after   => { mode => undef }
    #   
    #   @vars       $mode               384         Required file perms (decimal as num)
    #               $mode_dec           384         Required file perms (decimal as text)
    #               $mode_oct           0600        Required file perms (octal as text)
    # #

    if ( defined( $mode ) )
    {
        $mode_oct           = ( !ref( $mode ) and "$mode" =~ /\A[0-9]+\z/ )
                                ? sprintf( '%04o', $mode )
                                    : 'invalid';
    }

    # #
    #   @vars       $mode_dec           384 
    #               $allow_root_text    0 
    # #

    my $mode_dec            = !defined( $mode ) ? 'undef'
                                : ref( $mode ) ? 'invalid'
                                : "$mode";

    my $allow_root_text     = !defined( $allow_root_own ) ? 'undef'
                                : ref( $allow_root_own ) ? 'invalid'
                                : "$allow_root_own";

    # #
    #   @note       mode_mask           07777       Keeps file perm bits
    #               mode_req            0600 (384)  Required file perms
    #               mode_current        0600        Current file perms
    #               mode_metadata       100600      Regular file type (100000)
    #                                               plus file perms (0600)
    # #

    ConfigServer::DebugLocal::log( 1, 'info',
        "path:[$path_absolute] " .
        "allow_root_own:[$allow_root_text] " .
        "mode_mask:[" . sprintf( '%05o', FILE_PERMS_MODE_MASK ) . "] " .
        "mode_req:[$mode_oct ($mode_dec)] " .
        "mode_current:[" .
            sprintf( '%04o', $mdata->mode & FILE_PERMS_MODE_MASK ) .
        "] " .
        "mode_metadata:[" . sprintf( '%06o', $mdata->mode ) . "] " .
        "status:[checking policy]"
    );

    if ( defined( $mode ) )
    {
        return "Messenger log perms do not match"
            if ref( $mode ) or
                "$mode" !~ /\A[0-9]+\z/ or
                $mode > FILE_PERMS_MODE_MASK or
                ( $mdata->mode & FILE_PERMS_MODE_MASK ) != $mode;
    }

    # #
    #   Policy $gid and metadata gid (group) don't match
    #   
    #   @vars       $gid                0
    #               $mdata->gid         0
    # #

    if ( defined( $gid ) )
    {
        return "Messenger log gid does not match"
            if ref( $gid ) or "$gid" !~ /\A[0-9]+\z/ or $mdata->gid != $gid;
    }

    # #
    #   Policy $uid and $mdata->uid (owner) don't match
    #   
    #   @vars       $uid                0
    #               $mdata->uid         0
    # #

    my $matches_oid =
    (
        defined( $uid ) and
        !ref( $uid ) and
        "$uid" =~ /\A[0-9]+\z/ and
        $mdata->uid == $uid
    );

    # #
    #   If root ownership is allowed and file is owned by root.
    #       Returns 0 if $allow_root_own = 0;
    #   
    #   Defined by:
    #       before  => { allow_root_own => 0 }
    #       after   => { allow_root_own => 0 }
    # #

    my $matches_root =
    (
        defined( $allow_root_own ) and
        !ref( $allow_root_own ) and
        "$allow_root_own" =~ /\A[01]\z/ and
        $allow_root_own and
        $mdata->uid == ROOT_UID
    );

    # #
    #   Check root ownership and owner matches
    #   
    #   @vars       $matches_policy     1
    #               $debug_type         ok
    #               $debug_status       owner accepted
    # #

    my $matches_policy      = ( $matches_oid or $matches_root ) ? 1 : 0;
    my $debug_type          = $matches_policy ? 'ok' : 'warn';
    my $debug_status        = $matches_policy ? 'owner accepted' : 'owner rejected';

    # #
    #   @vars       $matches_root       0
    #               $matches_oid        1
    #               $path_absolute      /tmp/o624V5tDDs
    # #

    ConfigServer::DebugLocal::log( 1, $debug_type,
        "path:[$path_absolute] " .
        "matches_root:[$matches_root] " .
        "matches_oid:[$matches_oid] " .
        "status:[$debug_status]"
    );

    return "Messenger log owner does not match"
        if !$matches_policy;

    # policy requirements passed
    return;
}

# #
#	Logger › Messenger › File › Inspect
#   
#   Read a single file target. Return its metadata and filesystem
#   identity.
#   
#   Reject anything other than a regular file with one hard link.
#   
#   @test       Note:           Inspect an open temp file
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -MFile::Temp=tempfile -e 'my ($fh, $path) = tempfile(UNLINK => 1); my ($mdata, $identity) = ConfigServer::Logger::_msngr_file_inspect($fh, 1); print q{Regular: }, (defined($mdata) ? 1 : 0), qq{\nIdentity: }, (defined($identity) ? q{defined} : q{undef}), qq{\n}; close($fh) or die $!;'
#               Result:         Regular:    1
#                               Identity:   defined
#   
#   @params     target          any         Open handle or str file path
#                                               str         Inspect named path
#                                               fh          Inspect opened file
#               is_handle       int         Target type and metadata lookup
#                                               1           Target is an opened handle; use stat()
#                                               0           Target is a path; use lstat() without
#                                                           following a symlink
#   
#   @return     mdata           obj|undef   File::stat metadata
#                                               obj         Fh is regular file with required link count
#                                               undef       File can't be inspected, not regular, or has invalid link count
#               identity        str|undef   Device and inode identity
#                                               str         File valid; returned as device:inode
#                                               undef       Metadata validation fails
# #

sub _msngr_file_inspect
{
    # #
    #   @vars       $target             glob || str (fhandle)
    #               $is_handle          1
    # #

    my ( $target, $is_handle ) = @_;

    # #
    #   lstat( $target )        check named path without following symlink
    #   stat( $target )         check actual file ref'd by open fh
    # #

    my $mdata = $is_handle ? File::stat::stat( $target ) : File::stat::lstat( $target );
    if ( !defined( $mdata ) )
    {
        ConfigServer::DebugLocal::log( 1, 'warn',
            "target:[$target] " .
            "is_handle:[$is_handle] " .
            "return:[undef] " .
            "status:[inspect: metadata unavailable]"
        );

        return ( undef, undef );
    }

    # #
    #   Confirm $target is a regular file with the max hard
    #   link count allowed.
    #   
    #   Reject dirs, symlinks, special files, or files with too many
    #   hard links.
    # #

    my $is_regular  = Fcntl::S_ISREG( $mdata->mode );
    my $link_count  = $mdata->nlink;
    my $target_text = !defined( $target ) ? 'undef'
                        : !ref( $target ) ? "$target"
                        : ref( $target ) eq 'GLOB'  ? 'opened file handle'
                        : ref( $target );
    my $file_info   = ConfigServer::DebugLocal::getfstatinfo( $mdata );

    if ( !$is_regular or $link_count != LOG_HARDLINK_MAX )
    {
        my $inspect_status = !$is_regular
            ? 'not regular file'
                : 'unexpected link count';

        ConfigServer::DebugLocal::log( 1, 'warn',
            "target:[$target_text] " .
            "is_handle:[$is_handle] " .
            "is_regular:[$is_regular] " .
            "hardlinks:[$link_count] " .
            "hardlinks(max):[" . LOG_HARDLINK_MAX . "] " .
            "file_info:[$file_info] " .
            "return:[undef] " .
            "status:[inspect: $inspect_status]"
        );

        # return undef; target file does not have exactly one hard link
        return ( undef, undef );
    }

    # #
    #   Inspect successful
    #   
    #   @vars       $mdata              ARRAY (fstat)
    #               $identity           64768:10634229
    # #

    my $identity = $mdata->dev . ':' . $mdata->ino;

    ConfigServer::DebugLocal::log( 1, 'ok',
        "target:[$target_text] " .
        "is_handle:[$is_handle] " .
        "is_regular:[$is_regular] " .
        "hardlinks:[$link_count] " .
        "hardlinks(max):[" . LOG_HARDLINK_MAX . "] " .
        "file_info:[$file_info] " .
        "return:[metadata, $identity] " .
        "status:[inspect: ok]"
    );

    # passed inspect
    return ( $mdata, $identity );
}

# #
#	Logger › Messenger › File › Validate
#   
#   Verify the open handle and pathname identify the same file,
#   then apply the requested ownership and perm policy.
#   
#   @test       Note:           Validate temp file and its open handle
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -MFile::Temp=tempfile -e 'my ($fh, $path) = tempfile(UNLINK => 1); chmod(ConfigServer::Logger::MESSENGER_LOG_MODE(), $path) or die $!; my @status = stat($fh); my ($result, $error) = ConfigServer::Logger::_msngr_file_validate($fh, $path, $status[4], $status[5], 0, ConfigServer::Logger::MESSENGER_LOG_MODE()); print q{Status: }, (defined($result) ? $result : q{undef}), qq{\nError: }, (defined($error) ? $error : q{undef}), qq{\n};'
#               Result:         Status: 1
#                               Error:  undef
#   
#   @params     handle          fh          Open Messenger log file handle
#               path            str         Path belonging to the open file
#               uid             int         Expected file owner
#               gid             int|undef   Expected group (undef to skip)
#               allow_root_own  int         If root can own the file
#                                               1           Allow root ownership
#                                               0           Require supplied uid
#               mode            int|undef   Required file mode in decimal notation, or undef to skip
#                                               int         Perms must match
#                                                           Eg: decimal: 384 => octal: 0600
#                                               undef       Skip perm validation
#   
#   @return     status          int|undef   File validation result
#                                               1           File passed validation
#                                               undef       File failed validation
#	            error           str|undef   File validation error message
#                                               str         Validation failed
#                                               undef       Validation successful
# #

sub _msngr_file_validate
{
    my ( $fh, $path, $uid, $gid, $allow_root_own, $mode ) = @_;

    # #
    #                                        $target, $is_handle
    #   _msngr_file_inspect  ( "/tmp/RNCnOOi2gO", 0 );
    #       named               File::stat=ARRAY(0x55c223f55290)
    #       named_identity      64768:9196336
    #   
    #   _msngr_file_inspect  ( GLOB(0x55a1c13e0d08), 1 );
    #       opened              File::stat=ARRAY(0x55c224198430)
    #       opened_identity     64768:9196336
    # #

    my ( $named, $named_identity )      = _msngr_file_inspect( $path, 0 );
    my ( $opened, $opened_identity )    = _msngr_file_inspect( $fh, 1 );

    ConfigServer::DebugLocal::log( 1, 'info',
        ConfigServer::DebugLocal::log_singleize(
            'colon',
            [
                path            => $path,
                uid             => $uid,
                gid             => $gid,
                allow_root_own  => $allow_root_own,
                mode            => $mode,
            ]
        ) .
        " status:[validate: start]"
    );

    return ( undef, "Messenger log file identity is unsafe" )
        if !defined( $named ) or
            !defined( $opened ) or
            $named_identity ne $opened_identity;

    # check required perm mode, group, and owner for Messenger log file
    my $policy_err = _msngr_file_policy_err(
        $opened,
        $path,
        $uid,
        $gid,
        $allow_root_own,
        $mode,
    );

    return ( undef, $policy_err )
        if defined( $policy_err );

    return ( 1, undef );
}

# #
#	Logger › Messenger › Debug › Process Log
#	
#   Build debug message showing the log path, if a missing log can
#   be created, before / after checks, and callback type.
#   
#   These are only used internally during development, not required
#   for CSF in production env.
#	
#   @test       Note:           Format a Messenger log for debugging
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Logger -e 'my $opts = {path => q{relative.log}, create => 0, before => {}, after => {}}; my $out = ConfigServer::Logger::_msngr_debug_process($opts, sub { return; }); print $out, qq{\n};'
#               Result:         options:[create=0, path=relative.log] before:[allow_root_own=undef, gid=undef, mode=undef, uid=undef] after:[allow_root_own=undef, gid=undef, mode=undef, uid=undef] callback:[CODE] status:[transaction]
#	
#	@params     opts            hashref     Messenger transaction options
#	            cb              coderef     Process callback
#	
#	@return                     str         Safe formatted debug text
# #

sub _msngr_debug_process
{
    my ( $opts, $cb ) = @_;

    my $text_opts       = '(invalid)';
    my $text_before     = '(invalid)';
    my $text_after      = '(invalid)';

    if ( ref( $opts ) eq 'HASH' )
    {
        $text_opts = ConfigServer::DebugLocal::log_singleize(
            {
                path    => $opts->{path},
                create  => $opts->{create},
            }
        );

        if ( ref( $opts->{before} ) eq 'HASH' )
        {
            $text_before = ConfigServer::DebugLocal::log_singleize(
                {
                    uid             => $opts->{before}->{uid},
                    gid             => $opts->{before}->{gid},
                    allow_root_own  => $opts->{before}->{allow_root_own},
                    mode            => $opts->{before}->{mode},
                }
            );
        }

        if ( ref( $opts->{after} ) eq 'HASH' )
        {
            $text_after = ConfigServer::DebugLocal::log_singleize(
                {
                    uid             => $opts->{after}->{uid},
                    gid             => $opts->{after}->{gid},
                    allow_root_own  => $opts->{after}->{allow_root_own},
                    mode            => $opts->{after}->{mode},
                }
            );
        }
    }

    return
        "options:[$text_opts] " .
        "before:[$text_before] " .
        "after:[$text_after] " .
        "callback:[" . ( ref( $cb ) || '(invalid)' ) . "] " .
        "status:[transaction]";
}

1;
