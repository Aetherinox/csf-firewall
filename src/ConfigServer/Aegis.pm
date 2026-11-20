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
#   @updated            11.19.2026
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
#   @commands       Load module directly:
#                       sudo perl -I. ConfigServer/Aegis.pm
#   
#                   Check module for syntax errors:
#                       sudo  perl -I. -c ConfigServer/Aegis.pm
#   
#                   Module docs:
#                       perldoc -T ConfigServer/Aegis.pm
#   
#                   Run test suite:
#                       sudo prove -I. -v tests/Aegis.t
# #

# #
#   NOTES
#   
#   ENABLE DEBUG LOGS
#       To enable debug logs, set constant:
#           DEBUG_ENABLE = 1
#   
#       _log() auto opens file DEBUG_LOG_PATH (const) on first write.
#   
#       Log file DEBUG_LOG_PATH MUST be a regular file, owned by
#       root, with mode 0600. If an existing log has incorrect owner
#       or mode, fix:
#   
#           $   sudo chown root:root /tmp/csf_debug_aegis.log
#           $   sudo chmod 0600 /tmp/csf_debug_aegis.log
#   
#       When manually running this module's @test commands, use sudo
#       so that the debug log can be opened and validated as root:
#   
#           $   sudo perl -I. -MConfigServer::Aegis -e '...'
# #

# #
#   Declare › Package
# #

package ConfigServer::Aegis;

# #
#   Declare › Use
# #

use strict;
use warnings;
use ConfigServer::Logger ( );
use Cwd ( );
use Errno ( );
use Fcntl ( );
use POSIX ( );

# #
#   Declare › Version
# #

our $VERSION = 15.11;

# #
#   Declare › Constants › Internal
#   
#   You should not need to tweak with these constant values unless
#   you are testing and know what you are doing.
#   
#   CAPABILITY_HEX_DIGITS_MAX
#       Linux returns 16 hex digits for capability values.
#       Allow up to 64 digits, reject anything larger as invalid.
#       Used as sanity check in case malformed capability found.
#           Eg:         0000000000000000        (CapInh)
#           Digits:     16
#   
#   DEBUG_LOG_BYTES_MAX
#       Limit module debug log to 16 MiB.
#       Stop writing if next log line would exceed limit.
#   
#   FD_COUNT_MAX
#       File descriptors (FD) limit.
#       Represents an opened file within a process. All opened files
#           are referred to by a non-negative fd num, which is
#           returned by open() or create().
#       Set high to avoid affecting legit systems.
#           Default:    65,536
#   
#       View specific limits with the cmds below:
#   
#           $   ulimit -Sn
#                   Shell Soft Limit        = 1024
#   
#           $   ulimit -Hn
#                   Shell Hard Limit        = 524288
#   
#           $   ps -ef | grep '[l]fd'
#   
#           $   cat /proc/478314/limits | grep "Max open files"
#               root    478310  478297  0 07:30 ?   00:00:00 lfd - messenger csf...
#               user    478314  478297  0 07:30 ?   00:00:00 lfd TEXT messenger
#   
#                       Process Limit       = 4096
#                       478314              = lfd TEXT messenger process
#   
#       To view current process descriptor count manually:
#   
#           1.  Get LFD processes
#               $ ps -ef | grep '[l]fd'
#   
#           2.  Command outputs:
#               root    478310  478297  0 07:30 ?   00:00:00 lfd - messenger csf...
#               user    478314  478297  0 07:30 ?   00:00:00 lfd TEXT messenger
#   
#           3.  Copy PID for "lfd TEXT messenger" (478297)
#       
#           4.  Run command:
#               $ sudo ls -1 /proc/478297/fd | wc -l
#   
#           5.  Command output:
#               5
#   
#   GROUPS_SECONDARY_COUNT_MAX
#       Max num of secondary group ids accepted from /proc/self/status.
#       If group count exceeds this num, stop.
#       All secondary groups are removed before changing Messenger uid and gid.
#           Default:    65,536
#   
#   ID_LENGTH_MAX
#       Max allowed digit length of a uid or gid.
#       Valid ids are usually 10 digits, but it may have leading zeros.
#           Default:    64 digits
#   
#   ID_VALUE_MAX
#       Max allowed highest uid or gid value.
#       Linux reserves 4,294,967,295: means "leave this ID unchanged"
#           Default:    4,294,967,294
#   
#   LOG_LINE_BYTES_MAX
#       Limit each complete debug log line to a size.
#       Includes date, level, caller, message, and newline.
#           Default:    4 * 1024 (4 KiB)
#   
#   LOG_WRITE_ATTEMPTS_MAX
#       Max attempts allowed to write one complete log line.
#       More than one attempt needed if only part of the line is written.
#       Stop after X attempts; prevent write loop continuing forever.
#           Default:    16
#   
#   SYSCALL_NUM_MAX
#       Highest syscall num accepted.
#           Default:    2,147,483,647
#
#   SYSCALL_BYTES_MAX
#       Max digits accepted before checking a syscall num.
#       This allows leading zeros, rejects extremely long values.
#           Default:    32
#   
#   STATUS_BYTES_MAX
#       Max data accepted from '/proc/self/status'.
#       Reject status file if it has more. Avoid using too much memory.
#           Default:    1 MiB
#   
#   STATUS_BYTES_READ
#       Max bytes read from '/proc/self/status' at one time using sysread()
#           Default:    8 KiB
#   
#   NO_NEW_PRIVS_SET
#       Linux prctl cmd used to enable no_new_privs.
#       Requires Linux kernel 3.5 or newer.
#       Read from <linux/prctl.h>.
#           38  enable no_new_privs
#           39  read current value
#           Default:    38
#   
#   NO_NEW_PRIVS_GET
#       Linux prctl cmd used to read no_new_privs setting.
#       Return 0 if disabled, 1 if enabled.
#       Requires Linux kernel 3.5 or newer.
#       Read from <linux/prctl.h>.
#           38  enable no_new_privs
#           39  read current value
#           Default:    39
#   
#   @note       FD_COUNT_MAX does not use a math formula to
#               determine a specific value. 65_536 provides generous
#               headroom, but still limits an insanely large
#               descriptor inventory.
# #

use constant
{
    CAPABILITY_HEX_DIGITS_MAX   => 64,
    DEBUG_LOG_BYTES_MAX         => 16 * 1024 * 1024,
    FD_COUNT_MAX                => 65_536,
    GROUPS_SECONDARY_COUNT_MAX  => 65_536,
    ID_LENGTH_MAX               => 64,
    ID_VALUE_MAX                => 4_294_967_294,
    LOG_LINE_BYTES_MAX          => 4 * 1024,
    LOG_WRITE_ATTEMPTS_MAX      => 16,
    SYSCALL_NUM_MAX             => 2_147_483_647,
    SYSCALL_BYTES_MAX           => 32,
    STATUS_BYTES_MAX            => 1024 * 1024,
    STATUS_BYTES_READ           => 8 * 1024,
    NO_NEW_PRIVS_SET            => 38,
    NO_NEW_PRIVS_GET            => 39,
};

# #
#   Declare › Constants › Processes
#   
#   Linux paths that provide details about the LFD Messenger process.
#   
#   PROC_FD_PATH
#       List all files / sockets open by LFD Messenger process.
#   
#       LFD closes anything Messenger doesn't need before changing
#       from root to cfg MESSENGER_USER. Required since changing users
#       does not close files or sockets already open.
#   
#   PROC_STATUS_PATH
#       Shows uid, gid, groups, and perms for LFD Messenger process.
#       
#       LFD checks these before and after changing from root to
#       cfg MESSENGER_USER.
#       
#       Confirms the change worked and no root access remains.
#   
#   PROC_TASK_PATH
#       Lists all threads in LFD Messenger process.
#   
#       LFD requires exactly one thread before it can change from root
#       to MESSENGER_USER. This user change happens because Messenger
#       accepts network connections and must not keep root access.
#       Only 1 thread allowed, because another thread could remain
#       as root.
# #

use constant
{
    PROC_FD_PATH        => "/proc/self/fd",
    PROC_STATUS_PATH    => "/proc/self/status",
    PROC_TASK_PATH      => "/proc/self/task",
};

# #
#   Declare › Constants › Debug
#   
#   DEBUG mode allows local debug logs to be written to:
#       /tmp/csf_debug_aegis.log
#   
#   Debug mode is NOT controlled by CSF's "/etc/csf/csf.conf" DEBUG
#   setting. Local constant only.
#   
#   DEBUG_ENABLE
#       0   Disable logging
#       1   Enable logging
#   
#   DEBUG_LOG_PATH
#       Where _log() saves this module's debug messages.
#   
#   @warn       Do not use this in production env.
# #

use constant
{
    MODULE_NAME         => "Aegis",
    DEBUG_ENABLE        => 0,
    DEBUG_LOG_PATH      => "/tmp/csf_debug_aegis.log",
};

# #
#   Declare › Variables › Global
#   
#   List of global vars for this module.
#   
#   $DEBUG_LOG_FH
#       Stores the open and validated fh used by _log() to write
#       messages to DEBUG_LOG_PATH.
#   
#   $FLAG_NOFOLLOW
#       Stores O_NOFOLLOW flag after the first successful check.
#       Flag stops open files from following symlinks. Stored so 
#       module doesn't have to check for the flag again later.
# #

my $DEBUG_LOG_FH;
my $FLAG_NOFOLLOW;

# #
#   Aegis › Identity › Config Items
#   
#   Each module protected by this Aegis module must have a uid
#   and gid that the module will run under:
#       eg: Messenger uses MESSENGER_USER
#   
#   The map below specifies which setting will be associated with a 
#   module for the target user and group ids.
# #

my %MODULES_CONFIG_USER = (
    Messenger => "MESSENGER_USER",
);

# #
#   Aegis › Stream Replacement
#   
#   Messenger child processes inherit STDIN, STDOUT, and STDERR from LFD.
#   Replace these fh with /dev/null so that the child process can't
#   use FHs inherited from LFD.
#   
#   STDIN:              opened for reading
#   STDOUT, STDERR:     opened for writing
#   
#   Reading from STDIN returns no data. Output written to STDOUT or
#   STDERR discarded.
#   
#   Keeps entries in order (0, 1, 2). Linux assigns lowest descriptor
#   when file is opened. Makes sure:
#       STDIN = 0, STDOUT = 1, STDERR = 2
# #

my @STREAMS_FH = (
    {
        handle          => \*STDIN,
        fd_num          => 0,
        access_mode     => Fcntl::O_RDONLY( ),
        display_name    => "STDIN",
    },
    {
        handle          => \*STDOUT,
        fd_num          => 1,
        access_mode     => Fcntl::O_WRONLY( ),
        display_name    => "STDOUT",
    },
    {
        handle          => \*STDERR,
        fd_num          => 2,
        access_mode     => Fcntl::O_WRONLY( ),
        display_name    => "STDERR",
    },
);

# #
#   Aegis › Linux › Process Capability Fields
#
#   Maps '/proc/self/status' cap field names, used to validate an
#   identity.
#   
#   CapInh          Inheritable Set             0000000000000000
#                   Caps that may be preserved across exec transitions.
#   
#   CapEff          Effective Set               0000003fffffffff
#                   All caps process can currently use.
#   
#   CapPrm          Permitted Set               0000003fffffffff
#                   all caps a process is allowed to use. These can
#                   be copied to the effective set and used after that.
#   
#   CapAmb          Ambient Set                 0000000000000000
#                   All non SUID binaries without file caps. Preserved
#                   when running new non privileged program. 
#                   Field missing on kernels older than Linux 4.3.
#   
#   @note           To check CSF caps; ran:
#                   $   ps -ef | grep '[l]fd'
#                       root    478310  478297  0 07:30 ?   00:00:00 lfd - messenger csf...
#                       user    478314  478297  0 07:30 ?   00:00:00 lfd TEXT messenger
#                       
#                   $   cat /proc/478310/status
#                       CapEff:	000001ffffffffff
#                       CapPrm:	000001ffffffffff
#                       CapAmb:	0000000000000000
#                       
#                   $   cat /proc/478314/status
#                       CapEff:	0000000000000000
#                       CapPrm:	0000000000000000
#                       CapAmb:	0000000000000000
#   
#                   Can convert hexadecimal capability using:
#                       capsh --decode=000001ffffffffff
#   
#   @note           CapAmb is here as a filler.
#                   https://man7.org/linux/man-pages/man5/proc_pid_status.5.html
# #

my @CAPABILITY_FIELDS = (
    {
        proc_field  => "CapInh",
        map_key     => "capinh",
        required    => 1,
    },
    {
        proc_field  => "CapPrm",
        map_key     => "capprm",
        required    => 1,
    },
    {
        proc_field  => "CapEff",
        map_key     => "capeff",
        required    => 1,
    },
    {
        proc_field  => "CapAmb",
        map_key     => "capamb",
        required    => 0,
    },
);

# #
#   Aegis › Linux › Syscall Lookup
#
#   Define identity required by Messenger.
#   
#   Operation name used by both primary and fallback methods.
#   SYS_* constant subroutine name used when reading syscall.ph.
#   
#   Arch        Name            Constant Sub        Num
#   
#   x86_64      prctl           SYS_prctl           157
#               setgroups       SYS_setgroups       116
#               setresgid       SYS_setresgid       119
#               setresuid       SYS_setresuid       117
#   
#   aarch64     prctl           SYS_prctl           167
#               setgroups       SYS_setgroups       159
#               setresgid       SYS_setresgid       149
#               setresuid       SYS_setresuid       147
# #

my @SC_LOOKUP = (
    {
        name        => "setgroups",
        sub         => "SYS_setgroups",
        required    => 1,
    },
    {
        name        => "setresgid",
        sub         => "SYS_setresgid",
        required    => 1,
    },
    {
        name        => "setresuid",
        sub         => "SYS_setresuid",
        required    => 1,
    },
    {
        name        => "prctl",
        sub         => "SYS_prctl",
        required    => 0,
    },
);

# #
#   Aegis › Linux › Syscall › ABI (Numbers)
#   
#   Store syscall nums for each supported cpu arch.
#   
#   Use these as fallback when syscall.ph not available.
#   When syscall.ph available, compare consts with this table.
#   
#   @note           Arch names returned with POSIX::uname(),
#                   uname returns aarch64 for arm64.
#   
#                   Linux equiv command:
#                       uname -a
#   
#   @note           Many arch are defined in the hash below, probably
#                   excessive. But it ensures there are no surprises
#                   later with compatibility issues.
#   
#   @note           Github repo "hrw/syscalls-table" has a huge list
#                   that has correct arch info.
#   
#   @ref            x86             (32-bit x86)
#                   https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_32.tbl
#   
#                   x86_64          (64-bit x86)
#                   https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_64.tbl
#   
#                   arm             (32-bit ARM)
#                   https://github.com/torvalds/linux/blob/master/arch/arm/tools/syscall.tbl
#   
#                   aarch64         (64-bit ARM)
#                   https://github.com/torvalds/linux/blob/master/scripts/syscall.tbl
#   
#                   arm64-compat    (32-bit (aarch32) app running on 64-bit (arm64) ARM processor)
#                   https://github.com/torvalds/linux/blob/master/arch/arm64/tools/syscall_32.tbl
#   
#   @ref            https://syscall.sh/x64/setgroups/
#                   https://gpages.juszkiewicz.com.pl/syscalls-table/syscalls.html
#                   https://github.com/hrw/syscalls-table/tree/master/data/tables
#                   https://filippo.io/linux-syscall-table/
# #

my %SC_ABI = (
    x86_64 =>
    {
        prctl       => 157,
        setgroups   => 116,
        setresgid   => 119,
        setresuid   => 117,
    },
    aarch64 =>
    {
        prctl       => 167,
        setgroups   => 159,
        setresgid   => 149,
        setresuid   => 147,
    },
    riscv64 =>
    {
        prctl       => 167,
        setgroups   => 159,
        setresgid   => 149,
        setresuid   => 147,
    },
    loongarch64 =>
    {
        prctl       => 167,
        setgroups   => 159,
        setresgid   => 149,
        setresuid   => 147,
    },
    ppc64 =>
    {
        prctl       => 171,
        setgroups   => 81,
        setresgid   => 169,
        setresuid   => 164,
    },
    ppc64le =>
    {
        prctl       => 171,
        setgroups   => 81,
        setresgid   => 169,
        setresuid   => 164,
    },
    s390x =>
    {
        prctl       => 172,
        setgroups   => 206,
        setresgid   => 210,
        setresuid   => 208,
    },
);

# #
#   Aegis › Throw › Error
#   
#   Log error, return undef with complete err message. 
#   Accepts optional secondary err message.
#   
#   Two usages:
#       1.  Return provided reason
#       2.  Get additional err returned by another operation.
#           Uses "Unknown error" if additional err missing.
#   
#   @usage      return _throw_err( "Failure reason" );
#               return _throw_err( "Failure reason", $error );
#   
#   @params     reason          str|undef   Main failure reason
#               err             scalar      (Optional) additional error
#   @return     status          undef       Failure status
#               err             str         Complete failure reason
# #

sub _throw_err
{
    my ( $reason, $err ) = @_;
    $reason = "Unknown " . MODULE_NAME . " error"
        if !defined( $reason );

    if ( @_ > 1 )
    {
        $err = "unknown error"
            if !defined( $err ) or ref( $err ) or !length( $err );

        $reason .= ": $err";
    }

    my $caller = ( caller( 1 ) )[ 3 ];
    $caller = __PACKAGE__
        if !defined( $caller );

    _log( "ERROR", "Err: $reason", $caller );

    return ( undef, $reason );
}

# #
#   Aegis › Throw › Fatal
#   
#   Log fatal error, stop process with exit status 126.
#   Accepts optional secondary err msg.
#   
#   Two usages:
#       1.  Stop with provided fail reason
#       2.  Get failure message returned by another operation.
#           Uses "Unknown fatal error" if additional err missing.
#   
#   @usage      return _throw_err( "Failure reason" );
#               return _throw_err( "Failure reason", $error );
#   
#   @test       Note:           Verify fatal errors write to /var/log/lfd.log and exit with status 126
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require Fcntl; my $all_ok = 1; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my $log_path = "/var/log/lfd.log"; my $token = "Aegis fatal logger test [$$-" . time . "]"; my $pid = fork( ); die "Cannot fork: $!\n" if !defined( $pid ); if ( $pid == 0 ) { ConfigServer::Aegis::_throw_fatal( $token ); POSIX::_exit( 125 ); } my $waited = waitpid( $pid, 0 ); die "Cannot wait for child: $!\n" if $waited != $pid; my $child_status = $?; my $exit_status = $child_status >> 8; open( my $LOG, "<", $log_path ) or die "Cannot open $log_path: $!\n"; flock( $LOG, Fcntl::LOCK_SH( ) ) or die "Cannot lock $log_path: $!\n"; my $message_found = 0; while ( my $line = <$LOG> ) { if ( index( $line, $token ) >= 0 ) { $message_found = 1; last; } } close( $LOG ) or die "Cannot close $log_path: $!\n"; printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; $show->( "exit_status", $exit_status, 126 ); $show->( "log_path", $log_path, "/var/log/lfd.log" ); $show->( "message_found", $message_found ? "yes" : "no", "yes" ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     reason          str|undef   Main failure reason
#               err             scalar      (Optional) additional err
#   @return     void
# #

sub _throw_fatal
{
    my ( $reason, $err ) = @_;
    $reason = "Unknown " . MODULE_NAME . " fatal error"
        if !defined( $reason );

    if ( @_ > 1 )
    {
        $err = "unknown fatal error"
            if !defined( $err ) or ref( $err ) or !length( $err );

        $reason .= ": $err";
    }

    my $module = _caller_module( );
    my $caller = ( caller( 1 ) )[ 3 ];
    $caller = __PACKAGE__
        if !defined( $caller );

    _log( "FATAL", "Fatal: $reason", $caller );

    eval
    {
        local $SIG{__DIE__} = undef;

        ConfigServer::Logger::logfile( "normal", "abort", "[" . MODULE_NAME . "] [$module] Fatal [ $caller ]: $reason" );
    };

    POSIX::_exit( 126 );
}

# #
#   Aegis › Debug › Handle (Set)
#   
#   Set/clear fh used by this module's debug log. Prevent other
#   processes from inheriting it.
#   
#   Pass undef to clear.
#   
#   @params     fh              fh|undef    Debug log fh.
#                                           Use undef to clear it
#   @return     status          int|undef   Debug fh result
#                                               1           Fh set or cleared
#                                               undef       Invalid fh
# #

sub _debug_handle_set
{
    my ( $fh ) = @_;

    if ( !defined $fh )
    {
        $DEBUG_LOG_FH = undef;
        return 1;
    }

    $DEBUG_LOG_FH = undef;

    return undef
        if !ref( $fh );

    my $fd = fileno( $fh );
    return undef
        if !defined( $fd ) or $fd < 3;

    my @status = stat( $fh );
    return undef
        if !@status;

    return undef
        if !Fcntl::S_ISREG( $status[ 2 ] );

    return undef
        if $status[ 4 ] != 0;

    return undef
        if ( $status[ 2 ] & 0077 ) != 0;

    return undef
        if $status[ 7 ] > DEBUG_LOG_BYTES_MAX;

    my $open_flags = fcntl( $fh, Fcntl::F_GETFL( ), 0 );
    return undef
        if !defined( $open_flags );

    return undef
        if ( $open_flags & Fcntl::O_ACCMODE( ) ) == Fcntl::O_RDONLY( );

    return undef
        if !( $open_flags & Fcntl::O_APPEND( ) );

    return undef
        if !_set_close_on_exec( $fh );

    return undef
        if !binmode( $fh, ":raw" );

    $DEBUG_LOG_FH = $fh;

    return 1;
}

# #
#   Aegis › Debug › Open Log
#   
#   Open / validate debug log. Reject symlink/bad files, store
#   handle writes.
#   
#   @note       used with _log()
#   
#   @params     void
#   @return     fh              fh|undef    Open debug log fh
#               error           str|undef   Failure reason
# #

sub debug_log_open
{
    return ( undef, undef )
        if !DEBUG_ENABLE;

    my $nofollow = eval { Fcntl::O_NOFOLLOW() };
    return ( undef,
        "Unable to enable Aegis debug logging: " .
        "O_NOFOLLOW not available"
    ) if !defined( $nofollow );

    my $fh;
    return ( undef, "Unable to open Aegis debug logging: $!" )
        if !sysopen( $fh, DEBUG_LOG_PATH,
            Fcntl::O_WRONLY( ) |
            Fcntl::O_APPEND( ) |
            Fcntl::O_CREAT( ) |
            $nofollow,
            0600,
        );

    if ( !_debug_handle_set( $fh ) )
    {
        my $cleanup_err = _cleanup_close_filehandle( $fh );

        return ( undef,
            "Aegis debug log failed security validation" .
            $cleanup_err
        );
    }

    return ( $fh, undef );
}

# #
#   Aegis › Debug › Close Log
#   
#   Clear and close debug log handle.
#   
#   Eg:         my ( $debug_closed, $debug_close_error ) = ConfigServer::Aegis::debug_log_close( );
#               if ( !$debug_closed ) { return _messenger_failed( 1, $debug_close_error ) }
#   
#   @note       Was the old method for closing debug logs.
#               _log() keeps file handle open through lifetime of 
#               the log. Should not be ran in production.
#   
#   @params     void
#   @return     status          int|undef   Debug log close result
#                                               1           Closed
#                                               undef       Log close failed
#               error           str|undef   Failure reason
# #

sub debug_log_close
{
    return ( 1, undef )
        if !defined( $DEBUG_LOG_FH );

    my $fh          = $DEBUG_LOG_FH;
    $DEBUG_LOG_FH   = undef;

    my $closed      = close( $fh );
    my $close_err   = "$!";

    return (
        undef,
        "Unable to close Aegis debug log: $close_err"
    ) if !$closed;

    return ( 1, undef );
}

# #
#   Aegis › Caller Module
#   
#   Find module that called Aegis. Skip calls made inside Aegis.
#   
#   @params     void
#   @return     module          str         Calling module name
# #

sub _caller_module
{
    my $depth = 1;

    while ( my @caller = caller( $depth++ ) )
    {
        next if $caller[ 0 ] eq __PACKAGE__;

        my $module  = $caller[ 0 ];
        $module     =~ s{^.*::}{};

        return $module;
    }

    my $module  = __PACKAGE__;
    $module     =~ s{^.*::}{};

    return $module;
}

# #
#   Aegis › Identity › Config Item
#   
#   Return the config item used by the module that called Aegis.
#   Return a generic description when the module is not mapped.
#   
#   @params     void
#   @return     config_item     str         Config item or generic description
# #

sub _identity_config_item
{
    my $module = _caller_module( );

    return $MODULES_CONFIG_USER{$module}
        if exists( $MODULES_CONFIG_USER{$module} );

    return "caller-provided identity";
}

# #
#   Aegis › Debug Log › Write
#   
#   Write single line to debug log.
#   
#   Logging failures should never stop ident/privilege change.
#   
#   @note       If const DEBUG_ENABLE = 1, run this module's @test
#               commands with sudo. The debug log must be owned by
#               'root' or the fh will be rejected.
#   
#   @params     level           str|undef   Log level
#               msg             str|undef   Log message
#               caller          str|undef   Sub name
#   @return     status          int|undef   Log write result
#                                               1           Successful write or disabled
#                                               undef       Write failed
# #

sub _log
{
    my ( $level, $msg, $caller ) = @_;

    return 1 if !DEBUG_ENABLE;

    my $module = _caller_module( );

    # #
    #   @note       If $DEBUG_LOG_FH is not set, open and validate the
    #               debug log before writing to it.
    #               
    #               Debug log must be owned by 'root'. If it can't
    #               be opened or validated, warn and skip debug log.
    # #

    if ( !$DEBUG_LOG_FH )
    {
        my ( $debug_fh, $debug_err ) = debug_log_open( );

        if ( !defined( $debug_fh ) )
        {
            warn(
                "Aegis debug log handle is unavailable " .
                "[Module: $module]: " .
                ( defined( $debug_err ) ? $debug_err : "unknown error" ) . "\n"
            );
            return undef;
        }
    }

    local $!;
    local $^E;
    local $@;
    local $?;
    local $SIG{PIPE} = 'IGNORE';

    $level = "DEBUG"
        if !defined( $level );

    $msg = ""
        if !defined( $msg );

    $caller = ( caller( 1 ) )[ 3 ]
        if !defined( $caller );

    $caller = __PACKAGE__
        if !defined( $caller );

    $caller =~ s/^\Q@{[__PACKAGE__]}\E:://;

    for my $field ( $level, $module, $caller, $msg )
    {
        $field =~ s/[\r\n\t]+/ /g;
    }

    my $date = POSIX::strftime( "%b %e %H:%M:%S", localtime );
    my $line = "$date [" . MODULE_NAME . "] [$module] [$level] [$caller] $msg\n";

    utf8::encode( $line );

    my $line_bytes = length( $line );
    return undef
        if $line_bytes > LOG_LINE_BYTES_MAX;

    my @log_status = stat( $DEBUG_LOG_FH );
    return undef
        if !@log_status or $log_status[ 7 ] > DEBUG_LOG_BYTES_MAX - $line_bytes;

    my $offset_bytes    = 0;
    my $write_attempts  = 0;

    while ( $offset_bytes < $line_bytes )
    {
        return undef
            if ++$write_attempts > LOG_WRITE_ATTEMPTS_MAX;

        my $is_written = eval {
            syswrite( $DEBUG_LOG_FH, $line, $line_bytes - $offset_bytes, $offset_bytes );
        };

        if ( !defined( $is_written ) )
        {
            next if !$@ and $! == Errno::EINTR( );
            return undef;
        }

        return undef
            if $is_written == 0;

        $offset_bytes += $is_written;
    }

    return 1;
}

# #
#   Aegis › FD › Close on Exec
#   
#   Mark a fh so a later app can't inherit it through exec.
#   
#   @warn       This sub uses perl's fcntl(), and should only be used
#               with an fh created by open() or sysopen(). Don't use
#               it with a dir handle created by opendir(); it may fail.
#               
#               opendir() already sets close-on-exec flag; calling
#               this sub for that dir handle not needed.
#   
#   @params     fh              fh          Open fh
#   @return     status          int|undef   Flag update result
#                                               1           Updated (flag set)
#                                               undef       Invalid or failed
# #

sub _set_close_on_exec
{
    my ( $fh ) = @_;

    return
        if !ref( $fh );

    my $flags = fcntl( $fh, Fcntl::F_GETFD( ), 0 );
    return
        if !defined( $flags );

    return fcntl( $fh, Fcntl::F_SETFD( ), $flags | Fcntl::FD_CLOEXEC( ) )
        ? 1
        : undef;
}

# #
#   Aegis › Cleanup › Close Filehandle
#   
#   Close a fh. Return an error if it can't be closed.
#   Fh opened with open() or sysopen()
#   
#   @params     fh              fh          Fh to close
#   @return     error           str         Close result
#                                               ""          Fh closed
#                                               str         Failure reason
# #

sub _cleanup_close_filehandle
{
    my ( $fh ) = @_;

    return ""
        if close( $fh );

    return "; cleanup close also failed: $!";
}

# #
#   Aegis › Cleanup › Close Dirhandle
#   
#   Close a dir handle. Return an error if it can't be closed.
#   Dirhandle opened with opendir()
#   
#   @params     dir             dh          Dir handle
#   @return     error           str         Close result
#                                               ""          Dir closed
#                                               str         Failure reason
# #

sub _cleanup_close_dirhandle
{
    my ( $dir ) = @_;

    return ""
        if closedir( $dir );

    return "; cleanup close also failed: $!";
}

# #
#   Aegis › Get › O_NOFOLLOW
#   
#   Load O_NOFOLLOW flag, rejects symlinks when opening files.
#   
#   Save the flag to global $FLAG_NOFOLLOW after first successful
#   check.
#   
#   @params     void
#   @return     flag            int|undef   O_NOFOLLOW value
#               error           str|undef   Failure reason
# #

sub _get_nofollow
{
    if ( !defined( $FLAG_NOFOLLOW ) )
    {
        my $resolved = eval
        {
            $FLAG_NOFOLLOW = Fcntl::O_NOFOLLOW();
            1;
        };

        return _throw_err( "O_NOFOLLOW not available" )
            if !$resolved or !defined( $FLAG_NOFOLLOW );
    }

    _log( "DEBUG", "O_NOFOLLOW is available" );

    return ( $FLAG_NOFOLLOW, undef );
}

# #
#   Aegis › Normalize UID or GID (Root Rejected)
#   
#   Validate / normalize Messenger target uid or gid.
#   Remove leading zeros.
#   Reject root id 0
#   
#   Input $id must be a numeric scalar in this range:
#       1 - ID_VALUE_MAX
#   
#   Remove leading zeros, reject root id 0, and check the range.
#
#   @usage      _normalize_uid_or_gid_noroot( "000974" )    => 974
#               _normalize_uid_or_gid_noroot( "0" )         => undef
#   
#   @note       _normalize_uid_or_gid()             Check uid or gid.
#                                                   Root id 0 allowed.
#   
#               _normalize_uid_or_gid_noroot()      Check Messenger target uid or gid.
#                                                   Root id 0 rejected.
#   
#   @test       Note:           Test / normalize a bunch of ids
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my $id_max = ConfigServer::Aegis::ID_VALUE_MAX( ); my @cases = ( [ "0", "0", undef ], [ "0000", "0000", undef ], [ "1", "1", 1 ], [ "000974", "000974", 974 ], [ "974", "974", 974 ], [ "maximum", $id_max, $id_max ], [ "above_maximum", $id_max + 1, undef ], [ "negative", "-1", undef ], [ "leading_plus", "+1", undef ], [ "decimal", "1.5", undef ], [ "text", "abc", undef ], [ "empty", "", undef ], [ "undefined", undef, undef ] ); printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; for my $case ( @cases ) { my ( $name, $raw, $expected ) = @{$case}; my $actual = ConfigServer::Aegis::_normalize_uid_or_gid_noroot( $raw ); $show->( $name, $actual, $expected ); } my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); my $res = $all_ok ? "OK" : "FAILED"; $show->( "result", $res, "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @param      id              scalar      uid or gid to check / normalize
#   @return                     int|undef   normalized uid or gid (excludes root id > 0)
#                                               undef       $id invalid uid/gid or root id 0
#                                               $id         $id defined and not root (0) 
#                                       
# #

sub _normalize_uid_or_gid_noroot
{
    my ( $id )      = @_;                               #  974
    my $id_out      = _normalize_uid_or_gid( $id );     #  974
  # my $user        = getpwuid( $id_out );              #  user

    return undef
        if !defined( $id_out ) or $id_out == 0;

    return $id_out; #  $id_out > 0
}

# #
#   Aegis › Normalize UID or GID (Root Allowed)
#   
#   Validate and normalize one uid or gid.
#   Allow root id 0
#   
#   @usage      _normalize_uid_or_gid( "000974" )   => 974
#               _normalize_uid_or_gid( "0" )        => 0
#   
#   @note       _normalize_uid_or_gid()             Check uid or gid.
#                                                   Root id 0 allowed.
#   
#               _normalize_uid_or_gid_noroot()      Check Messenger target uid or gid.
#                                                   Root id 0 rejected.
#   
#   @test       Note:           Test / normalize a bunch of ids
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my $id_max = ConfigServer::Aegis::ID_VALUE_MAX( ); my @cases = ( [ "root_zero", "0", 0 ], [ "root_leading_zeros", "0000", 0 ], [ "one", "1", 1 ], [ "user_leading_zeros", "000974", 974 ], [ "user_id", "974", 974 ], [ "maximum", $id_max, $id_max ], [ "above_maximum", $id_max + 1, undef ], [ "negative", "-1", undef ], [ "leading_plus", "+1", undef ], [ "decimal", "1.5", undef ], [ "text", "abc", undef ], [ "empty", "", undef ], [ "undefined", undef, undef ] ); printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; for my $case ( @cases ) { my ( $name, $raw, $expected ) = @{$case}; my $actual = ConfigServer::Aegis::_normalize_uid_or_gid( $raw ); $show->( $name, $actual, $expected ); } my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); my $res = $all_ok ? "OK" : "FAILED"; $show->( "result", $res, "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @param      id              scalar      uid or gid to normalize
#   @return                     int|undef   normalized uid or gid (includes root id 0)
#                                               undef       invalid, undef, or out of range id
#                                               $id         $id defined including root (0) 
# #

sub _normalize_uid_or_gid
{
    my ( $id )      = @_;   #  974

    return undef
        if !defined( $id ) or ref( $id );

    my $id_str      = "$id";
    my $id_len      = length( $id_str );
    my $id_preview  = $id_len > ID_LENGTH_MAX
                        ? substr( $id_str, 0, ID_LENGTH_MAX ) . "..."
                            : $id_str;

    _log( "DEBUG",
        "Normalize UID or GID " .
        "[id(raw): " . $id . " | " .
        "id(str): " . $id_preview . " | " .
        "id(len): " . $id_len . " | " .
        "id(max_val): " . ID_VALUE_MAX . " | " .
        "id(max_len): " . ID_LENGTH_MAX . "]"
    );

    if ( $id_len > ID_LENGTH_MAX )
    {
        _log( "FAIL",
            "Uid or gid exceeds the supported text limit " .
            "[id(raw): " . $id . " | " .
            "id(str): " . $id_preview . " | " .
            "id(len): " . $id_len . " | " .
            "id(max_val): " . ID_VALUE_MAX . " | " .
            "id(max_len): " . ID_LENGTH_MAX . "]"
        );

        return undef;
    }

    my ( $id_out ) = $id_str =~ /\A([0-9]+)\z/;
    return undef
        if !defined( $id_out );

    $id_out =~ s/\A0+(?=[0-9])//;

    my $id_max = "" . ID_VALUE_MAX;
    return undef
        if length( $id_out ) > length( $id_max ) or ( length( $id_out ) == length( $id_max ) and $id_out gt $id_max );

    return 0 + $id_out;
}

# #
#   Aegis › proc/self/status › Load
#   
#   Open and prep '/proc/self/status', get contents, close the fh.
#   
#   @test       Note:           Test status loading and helper failure conditions
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'no warnings qw(redefine prototype); my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my $path = ConfigServer::Aegis::PROC_STATUS_PATH( ); my $debug_ready = ConfigServer::Aegis::_log( "DEBUG", "Preparing proc status load test" ); my ( $nofollow_text, $nofollow_error ); { local *ConfigServer::Aegis::_get_nofollow = sub { return ( undef, "forced nofollow failure" ); }; ( $nofollow_text, $nofollow_error ) = ConfigServer::Aegis::_read_procstatus_load( ); } my ( $cloexec_text, $cloexec_error ); { local *ConfigServer::Aegis::_set_close_on_exec = sub { return undef; }; ( $cloexec_text, $cloexec_error ) = ConfigServer::Aegis::_read_procstatus_load( ); } my ( $read_text, $read_error ); { local *ConfigServer::Aegis::_read_procstatus_read = sub { return ( undef, "forced proc status read failure" ); }; ( $read_text, $read_error ) = ConfigServer::Aegis::_read_procstatus_load( ); } my ( $text, $error ) = ConfigServer::Aegis::_read_procstatus_load( ); my $text_type = defined( $text ) && !ref( $text ) ? "scalar" : "invalid"; my $text_bytes = defined( $text ) ? length( $text ) : 0; my $bytes_valid = $text_bytes > 0 && $text_bytes <= ConfigServer::Aegis::STATUS_BYTES_MAX( ) ? "yes" : "no"; my $uid_found = defined( $text ) && $text =~ /(?:\A|\n)Uid:[ \t]+[0-9]+/ ? "yes" : "no"; my $gid_found = defined( $text ) && $text =~ /(?:\A|\n)Gid:[ \t]+[0-9]+/ ? "yes" : "no"; my $groups_found = defined( $text ) && $text =~ /(?:\A|\n)Groups:[ \t]*/ ? "yes" : "no"; printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; $show->( "debug_log_ready", $debug_ready, 1 ); $show->( "nofollow_text", $nofollow_text, undef ); $show->( "nofollow_error", $nofollow_error, "forced nofollow failure" ); $show->( "cloexec_text", $cloexec_text, undef ); $show->( "cloexec_error", $cloexec_error, "Unable to protect fd for procfs path [ $path ] from exec inheritance" ); $show->( "read_text", $read_text, undef ); $show->( "read_error", $read_error, "forced proc status read failure" ); $show->( "text_type", $text_type, "scalar" ); $show->( "load_error", $error, undef ); $show->( "bytes_valid", $bytes_valid, "yes" ); $show->( "uid_found", $uid_found, "yes" ); $show->( "gid_found", $gid_found, "yes" ); $show->( "groups_found", $groups_found, "yes" ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); my $res = $all_ok ? "OK" : "FAILED"; $show->( "result", $res, "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     void
#   @return     read_data       str|undef   Status text
#               error           str|undef   Failure reason
# #

sub _read_procstatus_load
{
    my $path = PROC_STATUS_PATH;
    return _throw_err( "Cannot read procfs path $path" )
        if $^O ne 'linux';

    my ( $nofollow, $nofollow_err ) = _get_nofollow( );
    return ( undef, $nofollow_err )
        if !defined( $nofollow );

    my $status;
    return _throw_err( "Unable to open procfs path [ $path ]: $!" )
        if !sysopen( $status, $path, Fcntl::O_RDONLY( ) | $nofollow );

    my $status_fd = fileno( $status );

    if ( !defined( $status_fd ) or $status_fd < 0 )
    {
        my $cleanup = _cleanup_close_filehandle( $status );
        return _throw_err( "Unable to get fd for procfs path: [ $path$cleanup ]" );
    }

    if ( !_set_close_on_exec( $status ) )
    {
        my $cleanup = _cleanup_close_filehandle( $status );
        return _throw_err( "Unable to protect fd for procfs path [ $path ] from exec inheritance$cleanup" );
    }

    if ( !binmode( $status, ":raw" ) )
    {
        my $mode_err    = "$!";
        my $cleanup     = _cleanup_close_filehandle( $status );

        return _throw_err( "Unable to set binary mode on procfs path [ $path ]: $mode_err$cleanup" );
    }

    _log( "DEBUG",
        "Opened procfs path $path " .
        "[FD: " . ( defined( $status_fd ) ? $status_fd : "undef" ) . "]"
    );

    my ( $read_data, $read_err )    = _read_procstatus_read( $status );
    my $closed                      = close( $status );
    my $close_err                   = "$!";

    return _throw_err( $read_err )
        if defined( $read_err );

    return _throw_err( "Unable to close procfs path [ $path ]: $close_err" )
        if !$closed;

    _log( "OK",
        "Read $path " .
        "[Bytes: " . length( $read_data ) . " / " . STATUS_BYTES_MAX . "]"
    );

    return ( $read_data, undef );
}

# #
#   Aegis › proc/self/status › Read
#   
#   Copy data from opened '/proc/self/status' fh.
#   
#   @test       Note:           Test valid, invalid, failed, and oversized status reads
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require Errno; require Fcntl; require File::Temp; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my $path = ConfigServer::Aegis::PROC_STATUS_PATH( ); my $invalid_error = "Cannot read procfs path [ $path ], fh missing or not open"; my ( $missing_text, $missing_error ) = ConfigServer::Aegis::_read_procstatus_read( undef ); my ( $scalar_text, $scalar_error ) = ConfigServer::Aegis::_read_procstatus_read( "invalid" ); sysopen( my $failed_fh, "/proc/self", Fcntl::O_RDONLY( ) ) or die "Cannot open /proc/self: $!\n"; my $read_error_text; { local $! = Errno::EISDIR( ); $read_error_text = "$!"; } my ( $failed_text, $failed_error ) = ConfigServer::Aegis::_read_procstatus_read( $failed_fh ); close( $failed_fh ) or die "Cannot close failed-read test fh: $!\n"; my $failed_expected = "Unable to read procfs path [ $path ]: $read_error_text"; my $maximum = ConfigServer::Aegis::STATUS_BYTES_MAX( ); my ( $large_fh, $large_path ) = File::Temp::tempfile( "messenger-status-XXXXXX", TMPDIR => 1, UNLINK => 1 ); binmode( $large_fh, ":raw" ) or die "Cannot set raw mode on oversized test fh: $!\n"; my $payload = "A" x ( $maximum + 1 ); my $offset_bytes = 0; while ( $offset_bytes < length( $payload ) ) { my $is_written = syswrite( $large_fh, $payload, length( $payload ) - $offset_bytes, $offset_bytes ); die "Cannot write oversized test data: $!\n" if !defined( $is_written ); die "Oversized test write made no progress\n" if $is_written == 0; $offset_bytes += $is_written; } defined( sysseek( $large_fh, 0, 0 ) ) or die "Cannot reset oversized test fh: $!\n"; my ( $large_text, $large_error ) = ConfigServer::Aegis::_read_procstatus_read( $large_fh ); close( $large_fh ) or die "Cannot close oversized test fh: $!\n"; my $large_expected = "Identity procfs path oversized: [ $path ]"; sysopen( my $status_fh, $path, Fcntl::O_RDONLY( ) ) or die "Cannot open $path: $!\n"; my ( $text, $error ) = ConfigServer::Aegis::_read_procstatus_read( $status_fh ); my $fh_state = defined( fileno( $status_fh ) ) ? "open" : "closed"; close( $status_fh ) or die "Cannot close $path: $!\n"; my $text_type = defined( $text ) && !ref( $text ) ? "scalar" : "invalid"; my $text_bytes = defined( $text ) ? length( $text ) : 0; my $bytes_valid = $text_bytes > 0 && $text_bytes <= $maximum ? "yes" : "no"; my $uid_found = defined( $text ) && $text =~ /(?:\A|\n)Uid:[ \t]+[0-9]+/ ? "yes" : "no"; my $gid_found = defined( $text ) && $text =~ /(?:\A|\n)Gid:[ \t]+[0-9]+/ ? "yes" : "no"; my $groups_found = defined( $text ) && $text =~ /(?:\A|\n)Groups:[ \t]*/ ? "yes" : "no"; printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; $show->( "missing_text", $missing_text, undef ); $show->( "missing_error", $missing_error, $invalid_error ); $show->( "scalar_text", $scalar_text, undef ); $show->( "scalar_error", $scalar_error, $invalid_error ); $show->( "failed_text", $failed_text, undef ); $show->( "failed_error", $failed_error, $failed_expected ); $show->( "oversized_text", $large_text, undef ); $show->( "oversized_error", $large_error, $large_expected ); $show->( "text_type", $text_type, "scalar" ); $show->( "read_error", $error, undef ); $show->( "fh_after_read", $fh_state, "open" ); $show->( "bytes_valid", $bytes_valid, "yes" ); $show->( "uid_found", $uid_found, "yes" ); $show->( "gid_found", $gid_found, "yes" ); $show->( "groups_found", $groups_found, "yes" ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); my $res = $all_ok ? "OK" : "FAILED"; $show->( "result", $res, "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     status          fh          Open status fh
#   @return     text            str|undef   Process status text
#               error           str|undef   Failure reason
# #

sub _read_procstatus_read
{
    my ( $status ) = @_;

    return ( undef, "Cannot read procfs path [ " . PROC_STATUS_PATH . " ], fh missing or not open" )
        if !ref( $status ) or !defined( fileno( $status ) );

    my $out = "";

    while ( 1 )
    {
        my $remains     = STATUS_BYTES_MAX - length( $out );
        my $read_size   = $remains < STATUS_BYTES_READ ? $remains + 1 : STATUS_BYTES_READ;
        my $buffer      = "";
        my $bytes       = sysread( $status, $buffer, $read_size );

        if ( !defined( $bytes ) )
        {
            next if $! == Errno::EINTR( );
            return ( undef, "Unable to read procfs path [ " . PROC_STATUS_PATH . " ]: $!" );
        }

        last if $bytes == 0;

        $out .= $buffer;

        return ( undef, "Identity procfs path oversized: [ " . PROC_STATUS_PATH . " ]" )
            if length( $out ) > STATUS_BYTES_MAX;
    }

    return ( $out, undef );
}

# #
#   Aegis › Parse › ID Field
#   
#   Extract and validate the 4 values ( uid or gid ) from the
#   process status.
#   
#   @test       Note:           Validate 'Uid' and 'Gid' fields
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my $show = sub { my ($name, $actual, $expected) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $expected_out = defined($expected) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s => %-112s [%s]\n", $name, $actual_out, $status; }; my $status_error = "Cannot read process ids, status text missing or invalid"; my $field_error = "Cannot read process ids, field name must be \"Uid\" or \"Gid\""; my $uid_count_error = "Cannot read process user ids, Uid must have exactly 4 nums"; my $gid_count_error = "Cannot read process group ids, Gid must have exactly 4 nums"; my $uid_range_error = "Cannot read process user ids, Uid contains a num outside the allowed Linux id range"; my @cases = (["valid_uid", "Uid:\t1001\t1002\t1003\t1004\n", "Uid", "1001:1002:1003:1004", undef], ["valid_gid", "Gid: 2001 2002 2003 2004\n", "Gid", "2001:2002:2003:2004", undef], ["missing_status", undef, "Uid", undef, $status_error], ["ref_status", [], "Uid", undef, $status_error], ["missing_field", "Uid: 1 2 3 4\n", undef, undef, $field_error], ["bad_field", "Uid: 1 2 3 4\n", "Name", undef, $field_error], ["ref_field", "Uid: 1 2 3 4\n", [], undef, $field_error], ["uid_missing", "Name: 1 2 3 4\n", "Uid", undef, $uid_count_error], ["uid_short", "Uid: 1 2 3\n", "Uid", undef, $uid_count_error], ["uid_extra", "Uid: 1 2 3 4 5\n", "Uid", undef, $uid_count_error], ["uid_text", "Uid: 1 two 3 4\n", "Uid", undef, $uid_count_error], ["uid_negative", "Uid: 1 2 -3 4\n", "Uid", undef, $uid_count_error], ["uid_large", "Uid: 1 2 3 999999999999999999999999\n", "Uid", undef, $uid_range_error], ["gid_short", "Gid: 1 2 3\n", "Gid", undef, $gid_count_error]); for my $case (@cases) { my ($name, $text, $field, $expected_ids, $expected_error) = @{$case}; my ($ids, $error) = ConfigServer::Aegis::_parse_id_field($text, $field); my $ids_out = ref($ids) eq "ARRAY" ? join(":", @{$ids}) : undef; $show->("${name}_ids", $ids_out, $expected_ids); $show->("${name}_error", $error, $expected_error); } printf "%-24s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#   @params     status          str             Process status text
#               field           str             'Uid' or 'Gid' field name
#   @return     ids             arrayref|undef  4 checked ID nums
#               error           str|undef       Failure reason
# #

sub _parse_id_field
{
    my ( $status, $field ) = @_;

    return _throw_err( "Cannot read process ids, status text missing or invalid" )
        if !defined( $status ) or ref( $status );

    return _throw_err( "Cannot read process ids, field name must be \"Uid\" or \"Gid\"" )
        if !defined( $field ) or ref( $field ) or $field !~ /\A(?:Uid|Gid)\z/;

    my $id_type = $field eq "Uid" ? "user ids" : "group ids";

    my ( $raw ) = $status =~ /(?:\A|\n)\Q$field\E:[ \t]+([0-9]+(?:[ \t]+[0-9]+){3})[ \t]*(?=\n|\z)/;
    return _throw_err( "Cannot read process $id_type, $field must have exactly 4 nums" )
        if !defined( $raw );

    my @ids = split( /[ \t]+/, $raw );
    return _throw_err( "Cannot read process $id_type, $field must have exactly 4 nums" )
        if @ids != 4;

    @ids = map { scalar _normalize_uid_or_gid( $_ ) } @ids;

    return _throw_err( "Cannot read process $id_type, $field contains a num outside the allowed Linux id range" )
        if grep { !defined( $_ ) } @ids;

    return ( \@ids, undef );
}

# #
#   Aegis › Parse › Groups
#   
#   Read the secondary group ids from the process status.
#   
#   @test       Note:           Parse valid group lists
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my $missing_error = "Cannot parse group: identity status is incomplete [Groups]"; my $invalid_error = "Cannot parse group: secondary group list contains an invalid value"; my $limit_error = "Cannot parse group: secondary group list exceeds supported limit"; my $id_max = ConfigServer::Aegis::ID_VALUE_MAX( ); my @cases = ( [ "multiple", "Name:\ttest\nGroups:\t10 20 30\n", "10,20,30", undef ], [ "spaces_tabs", "Groups:  00010\t20   30  \n", "10,20,30", undef ], [ "empty", "Groups:\t\n", "none", undef ], [ "maximum_id", "Groups:\t$id_max\n", "$id_max", undef ], [ "invalid_id", "Groups:\t" . ( $id_max + 1 ) . "\n", undef, $invalid_error ], [ "missing_field", "Name:\ttest\nState:\tR\n", undef, $missing_error ] ); printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; for my $case ( @cases ) { my ( $name, $text, $expected_groups, $expected_error ) = @{$case}; my ( $groups, $error ) = ConfigServer::Aegis::_parse_groups( $text ); my $groups_out = ref( $groups ) eq "ARRAY" ? ( @{$groups} ? join( ",", @{$groups} ) : "none" ) : undef; $show->( "${name}_groups", $groups_out, $expected_groups ); $show->( "${name}_error", $error, $expected_error ); } my $group_max = ConfigServer::Aegis::GROUPS_SECONDARY_COUNT_MAX( ); my $oversized_text = "Groups:\t" . join( " ", ( "1" ) x ( $group_max + 1 ) ) . "\n"; my ( $oversized_groups, $oversized_error ) = ConfigServer::Aegis::_parse_groups( $oversized_text ); $show->( "oversized_groups", $oversized_groups, undef ); $show->( "oversized_error", $oversized_error, $limit_error ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     status          str             Process status text
#   @return     groups          undef|arrayref  Secondary group ids
#               error           undef|str       Failure reason
# #

sub _parse_groups
{
    my ( $status ) = @_;

    my ( $raw ) = $status =~ /(?:\A|\n)Groups:[ \t]*([0-9 \t]*)[ \t]*(?=\n|\z)/;
    if ( !defined( $raw ) )
    {
        return _throw_err( "Cannot parse group: identity status is incomplete [Groups]" );
    }

    my @groups;
    my @group_entries = grep { length( $_ ) } split( /[ \t]+/, $raw );

    return _throw_err( "Cannot parse group: secondary group list exceeds supported limit" )
        if @group_entries > GROUPS_SECONDARY_COUNT_MAX;

    my $group_list = @group_entries ? join( ", ", @group_entries ) : "none";

    _log( "DEBUG",
        "Parse Groups " .
        "[groups: " . $group_list . " | " .
        "count(now): " . scalar( @group_entries ) . " | " .
        "count(max): " . GROUPS_SECONDARY_COUNT_MAX . "]"
    );

    for my $entry ( @group_entries )
    {
        my $group = _normalize_uid_or_gid( $entry );
        return _throw_err( "Cannot parse group: secondary group list contains an invalid value" )
            if !defined( $group );

        push @groups, $group;
    }

    return ( \@groups, undef );
}

# #
#   Aegis › Parse › Capabilities
#   
#   Extract and validate required Linux cap fields.
#   
#   @test       Note:           Parse and verify test cap values
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $text = "CapInh:\t0000000000000000\nCapPrm:\t00000000000000AB\nCapEff:\t0000000000000001\nCapAmb:\t0000000000000000\n"; my ($caps, $error) = ConfigServer::Aegis::_parse_capabilities($text); if (!$caps) { print "error     => ", (defined($error) ? $error : "unknown"), "\n"; print "result    => FAILED\n"; exit 1; } my %expected = (capinh => "0000000000000000", capprm => "00000000000000ab", capeff => "0000000000000001", capamb => "0000000000000000"); my $passed = 1; for my $key (sort keys %expected) { my $value = defined($caps->{$key}) ? $caps->{$key} : "undef"; my $status = $value eq $expected{$key} ? "OK" : "FAILED"; $passed = 0 if $status eq "FAILED"; printf "%-9s => %s [%s]\n", $key, $value, $status; } print "error     => ", (defined($error) ? $error : "undef"), "\n"; print "result    => ", ($passed ? "OK" : "FAILED"), "\n"; exit($passed ? 0 : 1);'
#   
#   @params     status          str             Process status text
#   @return     capabilities    undef|hashref   Linux perms
#               error           undef|str       Failure reason
# #

sub _parse_capabilities
{
    my ( $status ) = @_;

    my %caps;
    for my $capitem ( @CAPABILITY_FIELDS )
    {
        my $proc_field  = $capitem->{proc_field};
        my $map_key     = $capitem->{map_key};
        my $required    = $capitem->{required};
        my ( $bitmask ) = $status =~ /(?:\A|\n)\Q$proc_field\E:[ \t]+([0-9A-Fa-f]+)[ \t]*(?=\n|\z)/;
        my $bitmask_len = defined( $bitmask ) ? length( $bitmask ) : "undef";

        _log( "DEBUG",
            "Check Capabilities " .
            "[name: "           . ( defined( $proc_field ) ? $proc_field : "undef" ) . " | " .
            "key: "             . ( defined( $map_key ) ? $map_key : "undef" ) . " | " .
            "required: "        . ( defined( $required ) ? $required : "undef" ) . " | " .
            "bitmask: "         . ( defined( $bitmask ) ? $bitmask : "undef" ) . " | " .
            "bitmask(len): "    . $bitmask_len . " | " .
            "bitmask(max): "    . CAPABILITY_HEX_DIGITS_MAX . "]"
        );

        if ( !defined( $bitmask ) )
        {
            return _throw_err( "Cannot parse capabilities: required cap bitmask is missing [ $proc_field ]" )
                if $required;

            next;
        }

        return _throw_err( "Cannot parse capabilities: cap bitmask is too long [$proc_field]" )
            if $bitmask_len > CAPABILITY_HEX_DIGITS_MAX;

        $caps{$map_key} = lc( $bitmask );
    }

    return ( \%caps, undef );
}

# #
#   Aegis › Check Process Threads
#   
#   Make sure process has exactly one running thread.
#   
#   @test       Note:           Verify one thread passes, multiple threads fail, and the check passes again after cleanup
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require threads; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; my ( $initial_status, $initial_error ) = ConfigServer::Aegis::_verify_single_threaded_process( ); $show->( "initial_status", $initial_status, 1 ); $show->( "initial_error", $initial_error, undef ); pipe( my $reader, my $writer ) or die "Cannot create thread test pipe: $!\n"; my $thread = threads->create( sub { my $byte; my $read = sysread( $reader, $byte, 1 ); return defined( $read ) && $read == 1 ? "released" : "read failed"; } ); my ( $multiple_status, $multiple_error ) = ConfigServer::Aegis::_verify_single_threaded_process( ); $show->( "multiple_status", $multiple_status, undef ); $show->( "multiple_error", $multiple_error, "Aegis requires a single threaded process" ); my $released = syswrite( $writer, "1", 1 ); $show->( "thread_release", $released, 1 ); my $thread_result = $thread->join( ); $show->( "thread_result", $thread_result, "released" ); close( $reader ) or die "Cannot close thread test reader: $!\n"; close( $writer ) or die "Cannot close thread test writer: $!\n"; my ( $final_status, $final_error ) = ConfigServer::Aegis::_verify_single_threaded_process( ); $show->( "final_status", $final_status, 1 ); $show->( "final_error", $final_error, undef ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     void
#   @return     status          undef|int   Thread check result
#                                               1           One thread
#                                               undef       Check failed
#               error           undef|str   Failure reason
# #

sub _verify_single_threaded_process
{
    _log( "INFO", "Verify single thread state started" );

    return _throw_err( "Cannot verify process thread state: Linux procfs is unavailable" )
        if $^O ne 'linux' or !-d PROC_TASK_PATH;

    my $task_dir;
    return _throw_err( "Cannot inspect process thread state: $!" )
        if !opendir( $task_dir, PROC_TASK_PATH );

    my $task_dir_fd = fileno( $task_dir );
    _log( "INFO", "Single thread task dir: $task_dir_fd" );

    # #
    # if ( defined( $task_dir_fd ) and !_set_close_on_exec( $task_dir ) )
    # {
    #       my $dh_clean = _cleanup_close_dirhandle( $task_dir );
    #       return _throw_err( "Unable to protect the process thread inventory from exec inheritance$dh_clean" );
    # }
    # #

    # #
    #   Perl fcntl() not portable for handles created by opendir().
    #   opendir() creates a close-on-exec dir stream. This subroutine
    #   closes it before returning.
    # #

    my $thread_i = 0;

    while ( 1 )
    {
        local $!        = 0;
        my $dir_entry   = readdir( $task_dir );

        if ( !defined( $dir_entry ) )
        {
            if ( $! )
            {
                my $read_err    = "$!";
                my $dh_clean    = _cleanup_close_dirhandle( $task_dir );

                return _throw_err( "Cannot read process thread state: $read_err$dh_clean" );
            }

            last;
        }

        next
            if $dir_entry !~ /\A[0-9]+\z/;

        if ( ++$thread_i > 1 )
        {
            my $dh_clean = _cleanup_close_dirhandle( $task_dir );
            return _throw_err( MODULE_NAME . " requires a single threaded process$dh_clean" );
        }
    }

    return _throw_err( "Cannot close process thread inventory: $!" )
        if !closedir( $task_dir );

    return _throw_err( "Process thread inventory is incomplete" )
        if $thread_i != 1;

    _log( "OK", "Single thread process state: OK" );

    return ( 1, undef );
}

# #
#   Aegis › Clear Secondary Groups
#   
#   Remove all secondary groups before dropping / restricting root.
#   
#   @test       Note:           Add / clear secondary / supplementary groups in child process, verify parent is unchanged
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require POSIX; $| = 1; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; my $user = "csf"; my ( undef, undef, $uid, $gid ) = getpwnam( $user ); my $account_valid = defined( $uid ) && !ref( $uid ) && $uid =~ /\A[0-9]+\z/ && $uid > 0 && defined( $gid ) && !ref( $gid ) && $gid =~ /\A[0-9]+\z/ && $gid > 0; $show->( "test_account", $account_valid ? "$user ($uid:$gid)" : "invalid", $account_valid ? "$user ($uid:$gid)" : "valid account" ); my ( $calls, $map_error ) = ConfigServer::Aegis::_identity_map_prepare( ); $show->( "map_type", ref( $calls ) || "undef", "HASH" ); $show->( "map_error", $map_error, undef ); my $starting_ids = join( ":", POSIX::getuid( ), POSIX::geteuid( ), POSIX::getgid( ), POSIX::getegid( ) ); $show->( "starting_ids", $starting_ids, "0:0:0:0" ); my ( $parent_before, $parent_before_error ) = ConfigServer::Aegis::identity_read( ); my $parent_groups_before = ref( $parent_before ) eq "HASH" && ref( $parent_before->{secondary_groups} ) eq "ARRAY" ? ( @{$parent_before->{secondary_groups}} ? join( ",", @{$parent_before->{secondary_groups}} ) : "none" ) : undef; $show->( "parent_read_error", $parent_before_error, undef ); if ( !$account_valid or ref( $calls ) ne "HASH" or $starting_ids ne "0:0:0:0" or ref( $parent_before ) ne "HASH" ) { $show->( "complete", "FAILED", "OK" ); exit 1; } my $pid = fork( ); die "Cannot fork group-clear test: $!\n" if !defined( $pid ); if ( $pid == 0 ) { my $group_data = pack( "I", $gid ); local $! = 0; my $seed_status = syscall( $calls->{setgroups}, 1, $group_data ); $show->( "seed_status", $seed_status, 0 ); POSIX::_exit( 1 ) if !defined( $seed_status ) or $seed_status != 0; my ( $before, $before_error ) = ConfigServer::Aegis::identity_read( ); $show->( "before_read_error", $before_error, undef ); my $groups_before = ref( $before ) eq "HASH" && ref( $before->{secondary_groups} ) eq "ARRAY" ? ( @{$before->{secondary_groups}} ? join( ",", @{$before->{secondary_groups}} ) : "none" ) : undef; $show->( "groups_before", $groups_before, "$gid" ); my ( $cleared, $clear_error ) = ConfigServer::Aegis::_identity_groups_clear( $calls ); $show->( "clear_status", $cleared, 1 ); $show->( "clear_error", $clear_error, undef ); my ( $after, $after_error ) = ConfigServer::Aegis::identity_read( ); $show->( "after_read_error", $after_error, undef ); my $groups_after = ref( $after ) eq "HASH" && ref( $after->{secondary_groups} ) eq "ARRAY" ? ( @{$after->{secondary_groups}} ? join( ",", @{$after->{secondary_groups}} ) : "none" ) : undef; my $uid_after = ref( $after ) eq "HASH" && ref( $after->{user_ids} ) eq "HASH" ? join( ":", @{$after->{user_ids}}{qw( real effective saved filesystem )} ) : undef; my $gid_after = ref( $after ) eq "HASH" && ref( $after->{group_ids} ) eq "HASH" ? join( ":", @{$after->{group_ids}}{qw( real effective saved filesystem )} ) : undef; $show->( "groups_after", $groups_after, "none" ); $show->( "uid_after", $uid_after, "0:0:0:0" ); $show->( "gid_after", $gid_after, "0:0:0:0" ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); POSIX::_exit( $all_ok ? 0 : 1 ); } my $waited = waitpid( $pid, 0 ); my $wait_status = $?; my $child_exit = $waited != $pid ? "wait failed: $!" : ( $wait_status & 127 ) ? "signal " . ( $wait_status & 127 ) : $wait_status >> 8; $show->( "child_exit", $child_exit, 0 ); my ( $parent_after, $parent_after_error ) = ConfigServer::Aegis::identity_read( ); my $parent_groups_after = ref( $parent_after ) eq "HASH" && ref( $parent_after->{secondary_groups} ) eq "ARRAY" ? ( @{$parent_after->{secondary_groups}} ? join( ",", @{$parent_after->{secondary_groups}} ) : "none" ) : undef; $show->( "parent_after_error", $parent_after_error, undef ); $show->( "parent_groups", $parent_groups_after, $parent_groups_before ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     calls           hashref     Syscall nums
#   @return     status          int|undef   Group clear result
#                                               1           Groups cleared
#                                               undef       Failed
#               error           str|undef   Failure reason
# #

sub _identity_groups_clear
{
    my ( $calls ) = @_;

    local $!    = 0;
    my $res     = syscall( $calls->{setgroups}, 0, 0 );

    return _throw_err( "Secondary groups cannot be cleared before restricting privileges: $!" )
        if !defined( $res ) or $res != 0;

    _log( "OK", "Secondary group clear call succeeded; verification pending" );

    return ( 1, undef );
}

# #
#   Aegis › No New Privileges › Read
#   
#   Read current no_new_privs setting without making changes.
#   
#   Requires Linux kernel 3.5 or newer. Return err if setting
#   cannot be read / not available.
#   
#   @test       Note:           Read 'no_new_privs' before and after enabling it, test invalid call maps
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my $show = sub { my ( $name, $actual, $expected, $passed ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; $passed = $actual_out eq $expected_out if !defined( $passed ); my $status = $passed ? "OK" : "FAILED"; $all_ok = 0 if !$passed; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my ( $calls, $map_error ) = ConfigServer::Aegis::_identity_map_prepare( ); $show->( "map_type", ref( $calls ) || "undef", "HASH" ); $show->( "map_error", $map_error, undef ); my ( $before, $before_error ) = ConfigServer::Aegis::_no_new_privs_read( $calls ); my $before_valid = defined( $before ) && !ref( $before ) && ( $before == 0 || $before == 1 ); $show->( "before_value", $before, "0 or 1", $before_valid ); $show->( "before_error", $before_error, undef ); my ( $enabled, $enable_error ) = ConfigServer::Aegis::_no_new_privs_enable( $calls ); $show->( "enable_status", $enabled, 1 ); $show->( "enable_error", $enable_error, undef ); my ( $after, $after_error ) = ConfigServer::Aegis::_no_new_privs_read( $calls ); $show->( "after_value", $after, 1 ); $show->( "after_error", $after_error, undef ); my $invalid_error = "Cannot read no_new_privs, syscall map is missing or invalid"; my ( $missing_status, $missing_error ) = ConfigServer::Aegis::_no_new_privs_read( undef ); $show->( "missing_map_status", $missing_status, undef ); $show->( "missing_map_error", $missing_error, $invalid_error ); my ( $invalid_status, $invalid_map_error ) = ConfigServer::Aegis::_no_new_privs_read( {} ); $show->( "invalid_map_status", $invalid_status, undef ); $show->( "invalid_map_error", $invalid_map_error, $invalid_error ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     calls           hashref     Syscall nums
#   @return     status          int|undef   Current 'no_new_privs' setting
#                                               0           Disabled
#                                               1           Enabled
#                                               undef       Read failed
#               error           str|undef   Failure reason
# #

sub _no_new_privs_read
{
    my ( $calls ) = @_;

    return _throw_err( "Cannot read no_new_privs, syscall map is missing or invalid" )
        if ref( $calls ) ne 'HASH' or !defined( $calls->{prctl} );

    # #
    #   NO_NEW_PRIVS_SET = 38       enable no_new_privs
    #   NO_NEW_PRIVS_GET = 39       read current value
    # #

    local $!    = 0;
    my $status  = syscall(
        $calls->{prctl},
        NO_NEW_PRIVS_GET,
        0,
        0,
        0,
        0,
    );

    return _throw_err( "Cannot read \"no_new_privs\" setting: $!" )
        if !defined( $status ) or $status == -1;

    return _throw_err( "Linux returned an invalid \"no_new_privs\" setting: [ $status ]" )
        if $status != 0 and $status != 1;

    return ( $status, undef );
}

# #
#   Aegis › No New Privileges › Enable
#   
#   Enable and verify 'no_new_privs'. Stops Messenger from getting new
#   privileges. Child processes inherit the setting.
#   
#   no_new_privs needs Linux kernel 3.5 or newer. Skip step if
#   Linux does not support it or prctl syscall num is not
#   available.
#   
#   @ref        https://docs.kernel.org/userspace-api/no_new_privs.html
#   
#   @test       Note:           Test / enable no_new_privs in the main and child processes
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require POSIX; my $all_ok = 1; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-24s | %-24s | %s\n", $name, $actual_out, $expected_out, $status; }; my ( $calls, $map_error ) = ConfigServer::Aegis::_identity_map_prepare( ); $show->( "map_type", ref( $calls ) || "undef", "HASH" ); $show->( "map_error", $map_error, undef ); my ( $enabled, $enable_error ) = ConfigServer::Aegis::_no_new_privs_enable( $calls ); $show->( "enable_status", $enabled, 1 ); $show->( "enable_error", $enable_error, undef ); my ( $parent_value, $parent_error ) = ConfigServer::Aegis::_no_new_privs_read( $calls ); $show->( "parent_value", $parent_value, 1 ); $show->( "parent_error", $parent_error, undef ); my $child_exit; my $pid = fork( ); if ( !defined( $pid ) ) { $child_exit = "fork failed: $!"; } elsif ( $pid == 0 ) { my ( $child_value, $child_error ) = ConfigServer::Aegis::_no_new_privs_read( $calls ); POSIX::_exit( defined( $child_value ) && $child_value == 1 && !defined( $child_error ) ? 0 : 1 ); } else { waitpid( $pid, 0 ); $child_exit = $? >> 8; } $show->( "child_exit", $child_exit, 0 ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#               Note:           Test no_new_privs on supported and older Linux systems
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require POSIX; my $all_ok = 1; my $show = sub { my ( $name, $actual, $expected, $passed ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; $passed = $actual_out eq $expected_out if !defined( $passed ); my $status = $passed ? "OK" : "FAILED"; $all_ok = 0 if !$passed; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my ( $calls, $map_error ) = ConfigServer::Aegis::_identity_map_prepare( ); $show->( "map_type", ref( $calls ) || "undef", "HASH" ); $show->( "map_error", $map_error, undef ); my ( $enabled, $enable_error ) = ConfigServer::Aegis::_no_new_privs_enable( $calls ); my $enable_valid = defined( $enabled ) && !ref( $enabled ) && ( $enabled == 0 || $enabled == 1 ); $show->( "enable_status", $enabled, "0 or 1", $enable_valid ); $show->( "enable_error", $enable_error, undef ); if ( defined( $enabled ) && $enabled == 1 ) { my ( $parent_value, $parent_error ) = ConfigServer::Aegis::_no_new_privs_read( $calls ); $show->( "parent_value", $parent_value, 1 ); $show->( "parent_error", $parent_error, undef ); my $child_exit; my $pid = fork( ); if ( !defined( $pid ) ) { $child_exit = "fork failed: $!"; } elsif ( $pid == 0 ) { my ( $child_value, $child_error ) = ConfigServer::Aegis::_no_new_privs_read( $calls ); POSIX::_exit( defined( $child_value ) && $child_value == 1 && !defined( $child_error ) ? 0 : 1 ); } else { waitpid( $pid, 0 ); $child_exit = $? >> 8; } $show->( "child_exit", $child_exit, 0 ); } else { $show->( "parent_value", "skipped", "skipped" ); $show->( "parent_error", "skipped", "skipped" ); $show->( "child_exit", "skipped", "skipped" ); } my $invalid_syscall = ConfigServer::Aegis::SYSCALL_NUM_MAX( ); my ( $skip_status, $skip_error ) = ConfigServer::Aegis::_no_new_privs_enable( { prctl => $invalid_syscall } ); $show->( "forced_skip_status", $skip_status, 0 ); $show->( "forced_skip_error", $skip_error, undef ); my $invalid_error = "Cannot enable setting \"no_new_privs\", syscall map is missing or invalid"; my ( $invalid_status, $invalid_map_error ) = ConfigServer::Aegis::_no_new_privs_enable( {} ); $show->( "invalid_map_status", $invalid_status, undef ); $show->( "invalid_map_error", $invalid_map_error, $invalid_error ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     calls           hashref     Syscall num
#   @return     status          int|undef   Update result
#                                               1           Enabled and verified
#                                               0           Unsupported and skipped
#                                               undef       Failed
#               error           str|undef   Failure reason
# #

sub _no_new_privs_enable
{
    my ( $calls ) = @_;

    return _throw_err( "Cannot enable setting \"no_new_privs\", syscall map is missing or invalid" )
        if ref( $calls ) ne 'HASH' or !exists( $calls->{prctl} );

    if ( !defined( $calls->{prctl} ) )
    {
        _log(
            "WARN",
            "Linux prctl syscall number is unavailable; continuing without no_new_privs"
        );

        return ( 0, undef );
    }

    # #
    #   NO_NEW_PRIVS_SET = 38       enable no_new_privs
    #   NO_NEW_PRIVS_GET = 39       read current value
    # #

    local $!    = 0;
    my $res     = syscall(
        $calls->{prctl},
        NO_NEW_PRIVS_SET,
        1,
        0,
        0,
        0,
    );

    if ( !defined( $res ) or $res != 0 )
    {
        my $errno           = 0 + $!;
        my $error           = "$!";
        my $is_unsupported  = $errno == Errno::EINVAL( ) || $errno == Errno::ENOSYS( );

        if ( $is_unsupported )
        {
            _log(
                "WARN",
                "Linux setting \"no_new_privs\" is unavailable; continuing with reduced exec protection " .
                "[Error: $error]"
            );

            return ( 0, undef );
        }

        return _throw_err( "Cannot enable setting \"no_new_privs\"", $error );
    }

    my ( $nnp_read, $nnp_read_err ) = _no_new_privs_read( $calls );
    return ( undef, $nnp_read_err )
        if !defined( $nnp_read );

    return _throw_err(
        "Linux setting \"no_new_privs\" is supported but remained disabled " .
        "after the enable call succeeded [ Expected: 1 | Actual: $nnp_read ]"
    ) if $nnp_read != 1;

    _log( "OK", "Linux \"no_new_privs\" enabled and verified" );

    return ( 1, undef );
}

# #
#   Aegis › Set › Messenger gid
#   
#   Change every process gid to the Messenger gid.
#   Stop process if the change or check fails.
#   
#   @test       Note:           Change child process to Messenger gid, verify root uid remains
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require POSIX; $| = 1; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; my $user = "csf"; my ( undef, undef, $uid, $gid ) = getpwnam( $user ); my $account_valid = defined( $uid ) && !ref( $uid ) && $uid =~ /\A[0-9]+\z/ && $uid > 0 && defined( $gid ) && !ref( $gid ) && $gid =~ /\A[0-9]+\z/ && $gid > 0; $show->( "test_account", $account_valid ? "$user ($uid:$gid)" : "invalid", $account_valid ? "$user ($uid:$gid)" : "valid account" ); my ( $calls, $map_error ) = ConfigServer::Aegis::_identity_map_prepare( ); $show->( "map_type", ref( $calls ) || "undef", "HASH" ); $show->( "map_error", $map_error, undef ); my $starting_ids = join( ":", POSIX::getuid( ), POSIX::geteuid( ), POSIX::getgid( ), POSIX::getegid( ) ); $show->( "starting_ids", $starting_ids, "0:0:0:0" ); if ( !$account_valid or ref( $calls ) ne "HASH" or $starting_ids ne "0:0:0:0" ) { $show->( "complete", "FAILED", "OK" ); exit 1; } my $pid = fork( ); die "Cannot fork GID test: $!\n" if !defined( $pid ); if ( $pid == 0 ) { my ( $cleared, $clear_error ) = ConfigServer::Aegis::_identity_groups_clear( $calls ); $show->( "groups_clear_status", $cleared, 1 ); $show->( "groups_clear_error", $clear_error, undef ); POSIX::_exit( 1 ) if !$cleared; my $set_status = ConfigServer::Aegis::_set_gid( $calls, $gid ); $show->( "set_gid_status", $set_status, 1 ); my ( $identity, $identity_error ) = ConfigServer::Aegis::identity_read( ); $show->( "identity_type", ref( $identity ) || "undef", "HASH" ); $show->( "identity_error", $identity_error, undef ); my $uid_out = ref( $identity ) eq "HASH" && ref( $identity->{user_ids} ) eq "HASH" ? join( ":", @{$identity->{user_ids}}{qw( real effective saved filesystem )} ) : undef; my $gid_out = ref( $identity ) eq "HASH" && ref( $identity->{group_ids} ) eq "HASH" ? join( ":", @{$identity->{group_ids}}{qw( real effective saved filesystem )} ) : undef; my $groups_out = ref( $identity ) eq "HASH" && ref( $identity->{secondary_groups} ) eq "ARRAY" ? ( @{$identity->{secondary_groups}} ? join( ",", @{$identity->{secondary_groups}} ) : "none" ) : undef; $show->( "child_uid", $uid_out, "0:0:0:0" ); $show->( "child_gid", $gid_out, join( ":", ( $gid ) x 4 ) ); $show->( "child_groups", $groups_out, "none" ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); POSIX::_exit( $all_ok ? 0 : 1 ); } my $waited = waitpid( $pid, 0 ); my $wait_status = $?; my $child_exit = $waited != $pid ? "wait failed: $!" : ( $wait_status & 127 ) ? "signal " . ( $wait_status & 127 ) : $wait_status >> 8; $show->( "child_exit", $child_exit, 0 ); my $parent_ids = join( ":", POSIX::getuid( ), POSIX::geteuid( ), POSIX::getgid( ), POSIX::getegid( ) ); $show->( "parent_ids", $parent_ids, "0:0:0:0" ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     calls           hashref     Syscall nums
#               gid             int         Messenger gid
#   @return     status          int         Change result
#                                               1           Changed
# #

sub _set_gid
{
    my ( $calls, $gid ) = @_;

    local $!    = 0;
    my $res     = syscall( $calls->{setresgid}, $gid, $gid, $gid );
    _throw_fatal( "Set gid: Cannot permanently set gid to [ $gid ]: $!" )
        if !defined( $res ) or $res != 0;

    my ( $identity, $identity_err ) = identity_read( );
    _throw_fatal( "Set gid: Cannot read identity after changing gid", $identity_err )
        if !$identity;

    my $is_gid_changed = (
        _is_ids_match( $identity->{user_ids}, 0 )
        and _is_ids_match( $identity->{group_ids}, $gid )
        and !@{$identity->{secondary_groups}}
    );
    _throw_fatal( "Set gid: Identity verification failed after changing gid to [ $gid ]" )
        if !$is_gid_changed;

    _log(
        "OK",
        "GID transition verified; secondary groups empty and root uid preserved " .
        "[GID: $gid]"
    );

    return 1;
}

# #
#   Aegis › Set › Messenger uid
#   
#   Change every process uid to the Messenger uid.
#   Stop the process if the change or check fails.
#   
#   @test       Note:           Change a child process to the Messenger uid, verify all root perms are removed
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require POSIX; $| = 1; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; my $user = "csf"; my ( undef, undef, $uid, $gid ) = getpwnam( $user ); my $account_valid = defined( $uid ) && !ref( $uid ) && $uid =~ /\A[0-9]+\z/ && $uid > 0 && defined( $gid ) && !ref( $gid ) && $gid =~ /\A[0-9]+\z/ && $gid > 0; $show->( "test_account", $account_valid ? "$user ($uid:$gid)" : "invalid", $account_valid ? "$user ($uid:$gid)" : "valid account" ); my ( $calls, $map_error ) = ConfigServer::Aegis::_identity_map_prepare( ); $show->( "map_type", ref( $calls ) || "undef", "HASH" ); $show->( "map_error", $map_error, undef ); my $starting_ids = join( ":", POSIX::getuid( ), POSIX::geteuid( ), POSIX::getgid( ), POSIX::getegid( ) ); $show->( "starting_ids", $starting_ids, "0:0:0:0" ); if ( !$account_valid or ref( $calls ) ne "HASH" or $starting_ids ne "0:0:0:0" ) { $show->( "complete", "FAILED", "OK" ); exit 1; } my $pid = fork( ); die "Cannot fork UID test: $!\n" if !defined( $pid ); if ( $pid == 0 ) { my ( $cleared, $clear_error ) = ConfigServer::Aegis::_identity_groups_clear( $calls ); $show->( "groups_clear_status", $cleared, 1 ); $show->( "groups_clear_error", $clear_error, undef ); POSIX::_exit( 1 ) if !$cleared; my $gid_status = ConfigServer::Aegis::_set_gid( $calls, $gid ); $show->( "set_gid_status", $gid_status, 1 ); my $uid_status = ConfigServer::Aegis::_set_uid( $calls, $uid, $gid ); $show->( "set_uid_status", $uid_status, 1 ); my ( $identity, $identity_error ) = ConfigServer::Aegis::identity_read( ); $show->( "identity_type", ref( $identity ) || "undef", "HASH" ); $show->( "identity_error", $identity_error, undef ); my $uid_out = ref( $identity ) eq "HASH" && ref( $identity->{user_ids} ) eq "HASH" ? join( ":", @{$identity->{user_ids}}{qw( real effective saved filesystem )} ) : undef; my $gid_out = ref( $identity ) eq "HASH" && ref( $identity->{group_ids} ) eq "HASH" ? join( ":", @{$identity->{group_ids}}{qw( real effective saved filesystem )} ) : undef; my $groups_out = ref( $identity ) eq "HASH" && ref( $identity->{secondary_groups} ) eq "ARRAY" ? ( @{$identity->{secondary_groups}} ? join( ",", @{$identity->{secondary_groups}} ) : "none" ) : undef; my $caps = ref( $identity ) eq "HASH" ? $identity->{caps} : undef; my $required_caps_clear = ref( $caps ) eq "HASH" && !( grep { !exists( $caps->{$_} ) || !defined( $caps->{$_} ) || ref( $caps->{$_} ) || $caps->{$_} !~ /\A0+\z/ } qw( capinh capprm capeff ) ); my $ambient_cap_clear = ref( $caps ) eq "HASH" && ( !exists( $caps->{capamb} ) || ( defined( $caps->{capamb} ) && !ref( $caps->{capamb} ) && $caps->{capamb} =~ /\A0+\z/ ) ); my $permissions_out = $required_caps_clear && $ambient_cap_clear ? "none" : "present or invalid"; $show->( "child_uid", $uid_out, join( ":", ( $uid ) x 4 ) ); $show->( "child_gid", $gid_out, join( ":", ( $gid ) x 4 ) ); $show->( "child_groups", $groups_out, "none" ); $show->( "linux_permissions", $permissions_out, "none" ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); POSIX::_exit( $all_ok ? 0 : 1 ); } my $waited = waitpid( $pid, 0 ); my $wait_status = $?; my $child_exit = $waited != $pid ? "wait failed: $!" : ( $wait_status & 127 ) ? "signal " . ( $wait_status & 127 ) : $wait_status >> 8; $show->( "child_exit", $child_exit, 0 ); my $parent_ids = join( ":", POSIX::getuid( ), POSIX::geteuid( ), POSIX::getgid( ), POSIX::getegid( ) ); $show->( "parent_ids", $parent_ids, "0:0:0:0" ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     calls           hashref     Syscall nums
#               uid             int         Messenger uid
#               gid             int         Messenger gid
#   @return     status          int         Change result
#                                               1           Changed
# #

sub _set_uid
{
    my ( $calls, $uid, $gid ) = @_;

    # #
    #   @security       Success:    zero returned
    #                   Error:      -1 returned
    #   
    #                   Errno set to indicate the error.
    #   
    #                   Note: there are cases where setresuid() can
    #                   fail even when the caller is uid 0; it is a
    #                   grave security err to omit checking for a 
    #                   failure return from setresuid().
    #   
    #   @ref            https://man7.org/linux/man-pages/man2/setresuid.2.html
    # #

    local $!    = 0;
    my $res     = syscall( $calls->{setresuid}, $uid, $uid, $uid );
    _throw_fatal( "Set uid: Cannot permanently set uid to [ $uid ]: $!" )
        if !defined( $res ) or $res != 0;

    my ( $identity, $identity_err ) = identity_read( );
    _throw_fatal( "Set uid: Cannot read identity after changing uid", $identity_err )
        if !$identity;

    my ( $identity_is_restricted, $identity_restricted_err ) = _identity_is_restricted(
        $identity,
        $uid,
        $gid,
    );

    _throw_fatal(
        "Set uid: Identity verification failed after changing uid",
        $identity_restricted_err,
    ) if !$identity_is_restricted;

    _log(
        "OK",
        "UID transition and restricted identity verified " .
        "[UID: $uid | GID: $gid]"
    );

    return 1;
}

# #
#   Aegis › Root › Verify Root Access Is Removed
#   
#   Runs during Messenger startup after changing the process from
#   root uid/gid 0 to MESSENGER_USER uid/gid.
#   
#   Reject attempts to restore root uid/gid with EPERM.
#   
#   Then make sure the process still has restricted identity and
#   is single threaded.
#   
#   @test       Note:           Change child to the Messenger uid and gid, verify it can't regain root
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require POSIX; $| = 1; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; my $user = "csf"; my ( undef, undef, $uid, $gid ) = getpwnam( $user ); my $account_valid = defined( $uid ) && !ref( $uid ) && $uid =~ /\A[0-9]+\z/ && $uid > 0 && defined( $gid ) && !ref( $gid ) && $gid =~ /\A[0-9]+\z/ && $gid > 0; $show->( "test_account", $account_valid ? "$user ($uid:$gid)" : "invalid", $account_valid ? "$user ($uid:$gid)" : "valid account" ); my ( $calls, $map_error ) = ConfigServer::Aegis::_identity_map_prepare( ); $show->( "map_type", ref( $calls ) || "undef", "HASH" ); $show->( "map_error", $map_error, undef ); my $starting_ids = join( ":", POSIX::getuid( ), POSIX::geteuid( ), POSIX::getgid( ), POSIX::getegid( ) ); $show->( "starting_ids", $starting_ids, "0:0:0:0" ); if ( !$account_valid or ref( $calls ) ne "HASH" or $starting_ids ne "0:0:0:0" ) { $show->( "complete", "FAILED", "OK" ); exit 1; } my $pid = fork( ); die "Cannot fork root-regain test: $!\n" if !defined( $pid ); if ( $pid == 0 ) { my ( $cleared, $clear_error ) = ConfigServer::Aegis::_identity_groups_clear( $calls ); $show->( "groups_clear_status", $cleared, 1 ); $show->( "groups_clear_error", $clear_error, undef ); POSIX::_exit( 1 ) if !$cleared; my $gid_status = ConfigServer::Aegis::_set_gid( $calls, $gid ); $show->( "set_gid_status", $gid_status, 1 ); my $uid_status = ConfigServer::Aegis::_set_uid( $calls, $uid, $gid ); $show->( "set_uid_status", $uid_status, 1 ); my $verify_status = ConfigServer::Aegis::_root_regain_verify( $calls, $uid, $gid ); $show->( "regain_verify_status", $verify_status, 1 ); my ( $identity, $identity_error ) = ConfigServer::Aegis::identity_read( ); $show->( "identity_type", ref( $identity ) || "undef", "HASH" ); $show->( "identity_error", $identity_error, undef ); my $uid_out = ref( $identity ) eq "HASH" && ref( $identity->{user_ids} ) eq "HASH" ? join( ":", @{$identity->{user_ids}}{qw( real effective saved filesystem )} ) : undef; my $gid_out = ref( $identity ) eq "HASH" && ref( $identity->{group_ids} ) eq "HASH" ? join( ":", @{$identity->{group_ids}}{qw( real effective saved filesystem )} ) : undef; my $groups_out = ref( $identity ) eq "HASH" && ref( $identity->{secondary_groups} ) eq "ARRAY" ? ( @{$identity->{secondary_groups}} ? join( ",", @{$identity->{secondary_groups}} ) : "none" ) : undef; my $caps = ref( $identity ) eq "HASH" ? $identity->{caps} : undef; my $required_caps_clear = ref( $caps ) eq "HASH" && !( grep { !exists( $caps->{$_} ) || !defined( $caps->{$_} ) || ref( $caps->{$_} ) || $caps->{$_} !~ /\A0+\z/ } qw( capinh capprm capeff ) ); my $ambient_cap_clear = ref( $caps ) eq "HASH" && ( !exists( $caps->{capamb} ) || ( defined( $caps->{capamb} ) && !ref( $caps->{capamb} ) && $caps->{capamb} =~ /\A0+\z/ ) ); my $permissions_out = $required_caps_clear && $ambient_cap_clear ? "none" : "present or invalid"; $show->( "child_uid", $uid_out, join( ":", ( $uid ) x 4 ) ); $show->( "child_gid", $gid_out, join( ":", ( $gid ) x 4 ) ); $show->( "child_groups", $groups_out, "none" ); $show->( "linux_permissions", $permissions_out, "none" ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); POSIX::_exit( $all_ok ? 0 : 1 ); } my $waited = waitpid( $pid, 0 ); my $wait_status = $?; my $child_exit = $waited != $pid ? "wait failed: $!" : ( $wait_status & 127 ) ? "signal " . ( $wait_status & 127 ) : $wait_status >> 8; $show->( "child_exit", $child_exit, 0 ); my $parent_ids = join( ":", POSIX::getuid( ), POSIX::geteuid( ), POSIX::getgid( ), POSIX::getegid( ) ); $show->( "parent_ids", $parent_ids, "0:0:0:0" ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     calls           hashref     Syscall nums
#               uid             int         Messenger uid
#               gid             int         Messenger gid
#   @return     status          int         Check result
#                                               1           Root was blocked
# #

sub _root_regain_verify
{
    my ( $calls, $uid, $gid ) = @_;

    _root_regain_check( $calls->{setresuid}, "UID" );
    _root_regain_check( $calls->{setresgid}, "GID" );

    my ( $identity, $identity_err ) = identity_read( );
    _throw_fatal( "Regain verify: Cannot read identity after regain tests on root: $identity_err" )
        if !$identity;

    my ( $identity_is_restricted, $identity_restricted_err ) = _identity_is_restricted(
        $identity,
        $uid,
        $gid,
    );

    _throw_fatal(
        "Regain verify: Process identity changed during root regain tests",
        $identity_restricted_err,
    ) if !$identity_is_restricted;

    my ( $thread_single, $thread_err ) = _verify_single_threaded_process( );
    _throw_fatal( $thread_err )
        if !$thread_single;

    _log( "OK", "Restricted identity preserved after regain tests on root" );

    return 1;
}

# #
#   Aegis › Root › Regain Check
#   
#   Ran during Messenger startup, after it changes from root uid/gid
#   0 to MESSENGER_USER uid/gid.
#   
#   Tries to change back to root id 0 to confirm that the process
#   did not retain root access.
#   
#   Continue only if Linux rejects the root change with EPERM. Stop
#   if the change succeeds or fails with any other error.
#   
#   @params     sc_num          int         System call number
#               identity_name   str         uid or gid name
#   @return     status          int         Test result
#                                               1           Root regain blocked
# #

sub _root_regain_check
{
    my ( $sc_num, $identity_name ) = @_;

    local $!    = 0;
    my $res     = syscall( $sc_num, 0, 0, 0 );
    my $errno   = 0 + $!;
    my $error   = "$!";

    _throw_fatal( "Regain check: Unable to test if root $identity_name can be regained" )
        if !defined( $res );

    _throw_fatal( "Regain check: Module process unexpectedly regained root $identity_name" )
        if $res != -1;

    _throw_fatal( "Regain check: Root $identity_name regain attempt failed unexpectedly: $error" )
        if $errno != Errno::EPERM( );

    _log( "OK", "regain check: root $identity_name regain attempt rejected with EPERM" );

    return 1;
}

# #
#   Aegis › Check Null Device
#   
#   Check if /dev/null exists, is a character device, and owned by root.
#       Character device check with:
#           ls -l /dev/null
#           crw-rw-rw- 1 root root 1, 3 Nov  1 16:51 /dev/null
#   
#   Save its file details so reopened fhs can be checked against the
#   same device.
#   
#   @test       Note:           Verify /dev/null, compare its returned file details
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require Fcntl; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my ( $null_device, $error ) = ConfigServer::Aegis::_get_devnull( ); my @status = lstat( "/dev/null" ); my $path_status = @status ? "available" : "missing"; my $is_character = @status && Fcntl::S_ISCHR( $status[ 2 ] ) ? 1 : 0; my $owner_uid = @status ? $status[ 4 ] : undef; my $device = ref( $null_device ) eq "HASH" ? $null_device->{device} : undef; my $inode = ref( $null_device ) eq "HASH" ? $null_device->{inode} : undef; my $rdev = ref( $null_device ) eq "HASH" ? $null_device->{rdev} : undef; printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; $show->( "return_type", ref( $null_device ) || "undef", "HASH" ); $show->( "error", $error, undef ); $show->( "path_status", $path_status, "available" ); $show->( "character_device", $is_character, 1 ); $show->( "owner_uid", $owner_uid, 0 ); $show->( "device", $device, @status ? $status[ 0 ] : undef ); $show->( "inode", $inode, @status ? $status[ 1 ] : undef ); $show->( "rdev", $rdev, @status ? $status[ 6 ] : undef ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); my $res = $all_ok ? "OK" : "FAILED"; $show->( "result", $res, "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     void
#   @return     nuldev          hashref|undef       Checked /dev/null file details
#               error           str|undef           Failure reason
# #

sub _get_devnull
{
    my @status = lstat( "/dev/null" );

    return _throw_err( "Cannot read /dev/null details", "$!" )
        if !@status;

    return _throw_err( "/dev/null is not a character device" )
        if !Fcntl::S_ISCHR( $status[ 2 ] );

    return _throw_err( "/dev/null is not owned by root" )
        if $status[ 4 ] != 0;

    _log( "OK", "/dev/null is a root owned character device" );

    return (
        {
            device  => $status[ 0 ],
            inode   => $status[ 1 ],
            rdev    => $status[ 6 ],
        },
        undef
    );
}

# #
#   Aegis › Streams › Reopen Standard Filehandles
#   
#   Close stdin, stdout, stderr, inherited from root.
#   
#   Reopen them on /dev/null, Messenger shouldn't use root's old
#   input/output.
#   
#   Make sure /dev/null is the real root owned device before using it.
#   
#   @test       Note:           Test stream errors, replace all 3 fhs
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'no warnings qw(redefine prototype); my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; open( my $report_fh, ">&", \*STDOUT ) or die "Cannot duplicate STDOUT: $!\n"; my $selected_fh = select( $report_fh ); $| = 1; select( $selected_fh ); my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf {$report_fh} "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my ( $nofollow_status, $nofollow_error ); { local *ConfigServer::Aegis::_get_nofollow = sub { return ( undef, "forced nofollow failure" ); }; ( $nofollow_status, $nofollow_error ) = ConfigServer::Aegis::_reopen_standard_streams( ); } my ( $null_status, $null_error ); { local *ConfigServer::Aegis::_get_nofollow = sub { return ( 0, undef ); }; local *ConfigServer::Aegis::_get_devnull = sub { return ( undef, "forced null device failure" ); }; ( $null_status, $null_error ) = ConfigServer::Aegis::_reopen_standard_streams( ); } my ( $close_status, $close_error ); { local *ConfigServer::Aegis::_get_nofollow = sub { return ( 0, undef ); }; local *ConfigServer::Aegis::_get_devnull = sub { return ( {}, undef ); }; local *ConfigServer::Aegis::_fds_close = sub { return ( undef, "forced fh close failure" ); }; ( $close_status, $close_error ) = ConfigServer::Aegis::_reopen_standard_streams( ); } my ( $open_status, $open_error ); { local *ConfigServer::Aegis::_get_nofollow = sub { return ( 0, undef ); }; local *ConfigServer::Aegis::_get_devnull = sub { return ( {}, undef ); }; local *ConfigServer::Aegis::_fds_close = sub { return ( 1, undef ); }; local *ConfigServer::Aegis::_reopen_standard_stream = sub { return ( undef, "forced fh open failure" ); }; ( $open_status, $open_error ) = ConfigServer::Aegis::_reopen_standard_streams( ); } my $report_fd = fileno( $report_fh ); my ( $status, $error ) = ConfigServer::Aegis::_reopen_standard_streams( ); my $proc_fd_path = ConfigServer::Aegis::PROC_FD_PATH( ); my $report_state = lstat( "$proc_fd_path/$report_fd" ) ? "open" : "closed"; my $stdin_target = readlink( "$proc_fd_path/0" ); my $stdout_target = readlink( "$proc_fd_path/1" ); my $stderr_target = readlink( "$proc_fd_path/2" ); my $buffer = ""; my $stdin_read = sysread( STDIN, $buffer, 1 ); printf {$report_fh} "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf {$report_fh} "%s\n", "-" x 179; $show->( "nofollow_status", $nofollow_status, undef ); $show->( "nofollow_error", $nofollow_error, "forced nofollow failure" ); $show->( "null_status", $null_status, undef ); $show->( "null_error", $null_error, "forced null device failure" ); $show->( "close_status", $close_status, undef ); $show->( "close_error", $close_error, "forced fh close failure" ); $show->( "open_status", $open_status, undef ); $show->( "open_error", $open_error, "forced fh open failure" ); $show->( "replace_status", $status, 1 ); $show->( "replace_error", $error, undef ); $show->( "report_fh_state", $report_state, "open" ); $show->( "stdin_target", $stdin_target, "/dev/null" ); $show->( "stdout_target", $stdout_target, "/dev/null" ); $show->( "stderr_target", $stderr_target, "/dev/null" ); $show->( "stdin_read", $stdin_read, 0 ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); my $res = $all_ok ? "OK" : "FAILED"; $show->( "result", $res, "OK" ); close( $report_fh ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     void
#   @return     status          int|undef   Replace result
#                                               1           Reopened
#                                               undef       Failed
#               error           str|undef   Failure reason
# #

sub _reopen_standard_streams
{
    my ( $nofollow_flag, $nofollow_err ) = _get_nofollow( );
    return ( undef, $nofollow_err )
        if !defined( $nofollow_flag );

    my ( $nulldev, $null_err ) = _get_devnull( );
    return ( undef, $null_err )
        if !$nulldev;

    # #
    #   Close STDIN, STDOUT, and STDERR before reopening /dev/null.
    #   Abort if any fh can't be closed.
    # #

    for my $stream ( @STREAMS_FH )
    {
        my $fd_num                  = $stream ->{fd_num};
        my ( $closed, $close_err )  = _fds_close( $fd_num, 1 );

        return ( undef, $close_err )
            if !$closed;
    }

    for my $stream ( @STREAMS_FH )
    {
        my ( $is_open, $open_err ) = _reopen_standard_stream(
            $stream ->{handle},
            $stream ->{fd_num},
            $stream ->{access_mode},
            $stream ->{display_name},
            $nofollow_flag,
            $nulldev,
        );

        return ( undef, $open_err )
            if !$is_open;
    }

    _log( "OK", "Streams verified, STDIN, STDOUT, and STDERR now use /dev/null" );

    return ( 1, undef );
}

# #
#   Aegis › Streams › Reopen One Standard Filehandle
#   
#   Open /dev/null as STDIN, STDOUT, or STDERR.
#   Make sure it uses correct fd and raw mode.
#   
#   @test       Note:           Test read, write, unexpected fd, and wrong device results
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require Fcntl; require POSIX; require Symbol; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; my ( $nofollow, $nofollow_error ) = ConfigServer::Aegis::_get_nofollow( ); my ( $null_device, $null_error ) = ConfigServer::Aegis::_get_devnull( ); $show->( "nofollow_status", defined( $nofollow ) ? 1 : undef, 1 ); $show->( "nofollow_error", $nofollow_error, undef ); $show->( "null_status", ref( $null_device ) eq "HASH" ? 1 : undef, 1 ); $show->( "null_error", $null_error, undef ); if ( !defined( $nofollow ) or ref( $null_device ) ne "HASH" ) { my $res = $all_ok ? "OK" : "FAILED"; $show->( "result", $res, "OK" ); exit( 1 ); } my $proc_fd_path = ConfigServer::Aegis::PROC_FD_PATH( ); my $reserve_fd = sub { my $fd = POSIX::open( "/dev/null", Fcntl::O_RDONLY( ) ); die "Cannot reserve test FD: $!\n" if !defined( $fd ) or $fd < 0; POSIX::close( $fd ) == 0 or die "Cannot release test FD [$fd]: $!\n"; return $fd; }; my $read_fh = Symbol::gensym( ); my $read_fd = $reserve_fd->( ); my ( $read_status, $read_error ) = ConfigServer::Aegis::_reopen_standard_stream( $read_fh, $read_fd, Fcntl::O_RDONLY( ), "TEST_READ", $nofollow, $null_device ); my $read_opened_fd = fileno( $read_fh ); my $read_target = defined( $read_opened_fd ) ? readlink( "$proc_fd_path/$read_opened_fd" ) : undef; $show->( "read_status", $read_status, 1 ); $show->( "read_error", $read_error, undef ); $show->( "read_fd", $read_opened_fd, $read_fd ); $show->( "read_target", $read_target, "/dev/null" ); close( $read_fh ) or die "Cannot close read test fh: $!\n"; my $write_fh = Symbol::gensym( ); my $write_fd = $reserve_fd->( ); my ( $write_status, $write_error ) = ConfigServer::Aegis::_reopen_standard_stream( $write_fh, $write_fd, Fcntl::O_WRONLY( ), "TEST_WRITE", $nofollow, $null_device ); my $write_opened_fd = fileno( $write_fh ); my $write_target = defined( $write_opened_fd ) ? readlink( "$proc_fd_path/$write_opened_fd" ) : undef; $show->( "write_status", $write_status, 1 ); $show->( "write_error", $write_error, undef ); $show->( "write_fd", $write_opened_fd, $write_fd ); $show->( "write_target", $write_target, "/dev/null" ); close( $write_fh ) or die "Cannot close write test fh: $!\n"; my $wrong_fd_fh = Symbol::gensym( ); my $wrong_opened_fd = $reserve_fd->( ); my $wrong_expected_fd = $wrong_opened_fd + 1; my ( $wrong_fd_status, $wrong_fd_error ) = ConfigServer::Aegis::_reopen_standard_stream( $wrong_fd_fh, $wrong_expected_fd, Fcntl::O_RDONLY( ), "TEST_FD", $nofollow, $null_device ); my $wrong_fd_state = lstat( "$proc_fd_path/$wrong_opened_fd" ) ? "open" : "closed"; $show->( "wrong_fd_status", $wrong_fd_status, undef ); $show->( "wrong_fd_error", $wrong_fd_error, "Name [ TEST_FD ] opened on fd [ $wrong_opened_fd ], expected [ $wrong_expected_fd ]" ); $show->( "wrong_fd_cleanup", $wrong_fd_state, "closed" ); my %wrong_device = %{$null_device}; $wrong_device{inode}++; my $wrong_device_fh = Symbol::gensym( ); my $wrong_device_fd = $reserve_fd->( ); my ( $wrong_device_status, $wrong_device_error ) = ConfigServer::Aegis::_reopen_standard_stream( $wrong_device_fh, $wrong_device_fd, Fcntl::O_RDONLY( ), "TEST_DEVICE", $nofollow, \%wrong_device ); my $wrong_device_state = lstat( "$proc_fd_path/$wrong_device_fd" ) ? "open" : "closed"; $show->( "wrong_device_status", $wrong_device_status, undef ); $show->( "wrong_device_error", $wrong_device_error, "Name [ TEST_DEVICE ] did not open the verified /dev/null device" ); $show->( "wrong_device_cleanup", $wrong_device_state, "closed" ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); my $res = $all_ok ? "OK" : "FAILED"; $show->( "result", $res, "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     handle          fh          Standard fh
#               fd_expect       int         Expected fd num
#               flags           int         Open flags
#               name            str         Fh name
#               nofollow        int         Symlink block flag
#               devnull         hashref     Checked /dev/null file details
#   @return     status          int|undef   Replace result
#                                               1           Replaced
#                                               undef       Failed
#               error           str|undef   Failure reason
# #

sub _reopen_standard_stream
{
    my ( $fh, $fd_expect, $flags, $name, $nofollow, $devnull ) = @_;

    return _throw_err( "Cannot open /dev/null for name [ $name ]", "$!" )
        if !sysopen( $fh, "/dev/null", $flags | $nofollow );

    my $fd_opened = fileno( $fh );
    if ( !defined( $fd_opened ) or $fd_opened != $fd_expect )
    {
        my $closed  = close( $fh );
        my $cleanup = $closed ? "" : "; could not close fh: $!";

        return _throw_err( "Name [ $name ] opened on fd [ " . ( defined( $fd_opened ) ? $fd_opened : "undef" ) . " ], expected [ $fd_expect ]$cleanup" );
    }

    my @status = stat( $fh );

    if (
        !@status or
        !Fcntl::S_ISCHR( $status[ 2 ] ) or
        $status[ 4 ] != 0 or
        $status[ 0 ] != $devnull->{device} or
        $status[ 1 ] != $devnull->{inode} or
        $status[ 6 ] != $devnull->{rdev}
    )
    {
        my $closed  = close( $fh );
        my $cleanup = $closed ? "" : "; could not close fh: $!";

        return _throw_err( "Name [ $name ] did not open the verified /dev/null device$cleanup" );
    }

    if ( !binmode( $fh, ":raw" ) )
    {
        my $mode_err    = "$!";
        my $closed      = close( $fh );
        my $cleanup     = $closed ? "" : "; could not close fh: $!";

        return _throw_err( "Cannot set raw mode on name [ $name ]: $mode_err$cleanup" );
    }

    _log(
        "OK",
        "$name connected to /dev/null " .
        "[FD: $fd_opened]"
    );

    return ( 1, undef );
}

# #
#   Aegis › FDs › Cage Filehandles
#   
#   Close every open fh except the ones Messenger needs.
#   
#   STDIN, STDOUT, and STDERR replaced with fhs connected to /dev/null.
#   Fhs passed to this sub stay open.
#   
#   @test       Note:           Reject invalid entry, verify real fh isolation
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require Fcntl; require POSIX; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; open( my $report_fh, ">&", \*STDOUT ) or die "Cannot duplicate STDOUT: $!\n"; my $selected_fh = select( $report_fh ); $| = 1; select( $selected_fh ); my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf {$report_fh} "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my ( $invalid_status, $invalid_error ) = ConfigServer::Aegis::fds_cage( "invalid" ); my $extra_fd = POSIX::open( "/dev/null", Fcntl::O_RDONLY( ) ); die "Cannot open extra test FD: $!\n" if !defined( $extra_fd ) or $extra_fd < 0; my $report_fd = fileno( $report_fh ); my ( $cage_status, $cage_error ) = ConfigServer::Aegis::fds_cage( $report_fh ); my $proc_fd_path = ConfigServer::Aegis::PROC_FD_PATH( ); my $report_state = lstat( "$proc_fd_path/$report_fd" ) ? "open" : "closed"; my $extra_state = lstat( "$proc_fd_path/$extra_fd" ) ? "open" : "closed"; my $stdin_target = readlink( "$proc_fd_path/0" ); my $stdout_target = readlink( "$proc_fd_path/1" ); my $stderr_target = readlink( "$proc_fd_path/2" ); printf {$report_fh} "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf {$report_fh} "%s\n", "-" x 179; $show->( "invalid_status", $invalid_status, undef ); $show->( "invalid_error", $invalid_error, "Allowed fd list has an entry that is not an open fh" ); $show->( "cage_status", $cage_status, 1 ); $show->( "cage_error", $cage_error, undef ); my $report_fd_result = defined( $report_fd ) && $report_fd >= 3 ? "valid" : "invalid"; $show->( "kept_fd", "$report_fd ($report_fd_result)", "$report_fd (valid)" ); $show->( "kept_fd_state", $report_state, "open" ); $show->( "unlisted_fd_state", $extra_state, "closed" ); $show->( "stdin_target", $stdin_target, "/dev/null" ); $show->( "stdout_target", $stdout_target, "/dev/null" ); $show->( "stderr_target", $stderr_target, "/dev/null" ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); my $res = $all_ok ? "OK" : "FAILED"; $show->( "result", $res, "OK" ); close( $report_fh ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     fhs_keep        list        Fhs to keep open
#   @return     status          int|undef   Isolation status
#                                               1           Fhs isolated
#                                               undef       Failed
#               error           str|undef   Failure reason
# #

sub fds_cage
{
    my @fhs_keep = @_;

    _log( "DEBUG", "Starting module fh isolation" );

    push @fhs_keep, $DEBUG_LOG_FH
        if DEBUG_ENABLE and $DEBUG_LOG_FH;

    return _throw_err( "Module fh isolation requires linux" )
        if $^O ne 'linux';

    return _throw_err( "Cannot isolate module fhs, [ " . PROC_FD_PATH . " ] is not available" )
        if !-d PROC_FD_PATH;

    my ( $thread_single, $thread_err ) = _verify_single_threaded_process();
    return ( undef, $thread_err )
        if !$thread_single;

    my ( $allowlist, $allowlist_err ) = _fds_build_allowlist( @fhs_keep );
    return ( undef, $allowlist_err )
        if !$allowlist;

    my ( $standard_ok, $standard_err ) = _reopen_standard_streams( );
    return ( undef, $standard_err )
        if !$standard_ok;

    my ( $inherited, $snapshot_err ) = _fds_snapshot( );
    return ( undef, $snapshot_err )
        if !$inherited;

    my ( $closed, $close_err ) = _fds_close_unlisted( $inherited, $allowlist );
    return ( undef, $close_err )
        if !$closed;

    my ( $remains, $verify_err ) = _fds_snapshot( );
    return ( undef, $verify_err )
        if !$remains;

    my ( $verified, $cage_err ) = _fds_cage_verify( $remains, $allowlist );
    return ( undef, $cage_err )
        if !$verified;

    my ( $is_single_threaded, $thread_final_err ) =
        _verify_single_threaded_process( );

    return ( undef, $thread_final_err )
        if !$is_single_threaded;

    return ( 1, undef );
}

# #
#   Aegis › FDs › Build Filehandle List
#   
#   Make list of open fhs Messenger can keep.
#   Always include STDIN (0), STDOUT (1), and STDERR (2).
#   
#   @test       Note:           Build allowed fd list, test invalid fh entries
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require Fcntl; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s => %-112s [%s]\n", $name, $actual_out, $status; }; sysopen( my $keep_fh, "/dev/null", Fcntl::O_RDONLY( ) ) or die "Cannot open /dev/null: $!\n"; my $keep_fd = fileno( $keep_fh ); my ( $allowed, $allowed_error ) = ConfigServer::Aegis::_fds_build_allowlist( $keep_fh ); my %expected_fds = ( 0 => 1, 1 => 1, 2 => 1, $keep_fd => 1 ); my $allowed_out = $allowed ? join( ",", sort { $a <=> $b } keys( %{$allowed} ) ) : undef; my $expected_out = join( ",", sort { $a <=> $b } keys( %expected_fds ) ); $show->( "valid_status", $allowed ? 1 : undef, 1 ); $show->( "valid_error", $allowed_error, undef ); $show->( "allowed_fds", $allowed_out, $expected_out ); my ( $debug_status, $debug_error ) = ConfigServer::Aegis::_fds_build_allowlist( $keep_fh ); my $debug_enabled = ConfigServer::Aegis::DEBUG_ENABLE( ); $show->( "debug_missing_status", $debug_status ? 1 : undef, $debug_enabled ? undef : 1 ); $show->( "debug_missing_error", $debug_error, $debug_enabled ? "Active debug log fh is missing from the allowed list" : undef ); my ( $entry_status, $entry_error ) = ConfigServer::Aegis::_fds_build_allowlist( "invalid" ); $show->( "invalid_entry_status", $entry_status, undef ); $show->( "invalid_entry_error", $entry_error, "Allowed fd list has an entry that is not an open fh" ); sysopen( my $closed_fh, "/dev/null", Fcntl::O_RDONLY( ) ) or die "Cannot open /dev/null: $!\n"; close( $closed_fh ) or die "Cannot close test filehandle: $!\n"; my ( $closed_status, $closed_error ) = ConfigServer::Aegis::_fds_build_allowlist( $closed_fh ); $show->( "closed_fh_status", $closed_status, undef ); $show->( "closed_fh_error", $closed_error, "fh must be open on fd 3 or higher" ); my ( $low_status, $low_error ) = ConfigServer::Aegis::_fds_build_allowlist( \*STDIN ); $show->( "low_fd_status", $low_status, undef ); $show->( "low_fd_error", $low_error, "fh must be open on fd 3 or higher" ); my ( $duplicate_status, $duplicate_error ) = ConfigServer::Aegis::_fds_build_allowlist( $keep_fh, $keep_fh ); $show->( "duplicate_status", $duplicate_status, undef ); $show->( "duplicate_error", $duplicate_error, "Fd [ $keep_fd ] provided more than once" ); my $maximum = ConfigServer::Aegis::FD_COUNT_MAX( ); my @too_many = ( "invalid" ) x ( $maximum + 1 ); my ( $maximum_status, $maximum_error ) = ConfigServer::Aegis::_fds_build_allowlist( @too_many ); $show->( "maximum_status", $maximum_status, undef ); $show->( "maximum_error", $maximum_error, "Too many fhs were provided" ); close( $keep_fh ) or die "Cannot close test filehandle: $!\n"; my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); printf "%-24s => %s\n", "result", ( $all_ok ? "OK" : "FAILED" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     handles         list            Fhs to keep
#   @return     allowlist       hashref|undef   Allowed fd nums
#               error           str|undef       Failure reason
# #

sub _fds_build_allowlist
{
    my @handles = @_;

    return _throw_err( "Too many fhs were provided" )
        if @handles > FD_COUNT_MAX;

    my %allowed = map { $_ => 1 } 0 .. 2;
    for my $handle ( @handles )
    {
        return _throw_err( "Allowed fd list has an entry that is not an open fh" )
            if !ref( $handle );

        my $fd = fileno( $handle );
        return _throw_err( "fh must be open on fd 3 or higher" )
            if !defined( $fd ) or $fd !~ /\A[0-9]+\z/ or $fd < 3;

        return _throw_err( "Fd [ $fd ] provided more than once" )
            if $allowed{$fd};

        $allowed{$fd} = 1;
    }

    my $msg = "Allowed fh list verified";
    if ( DEBUG_ENABLE and $DEBUG_LOG_FH )
    {
        my $debug_fd = fileno( $DEBUG_LOG_FH );
        return _throw_err( "Active debug log fh is missing from the allowed list" )
            if !defined( $debug_fd ) or !$allowed{$debug_fd};

        $msg .= ", including debug log fh";
    }

    _log( "OK", $msg );

    return ( \%allowed, undef );
}

# #
#   Aegis › FDs › Verify Cage / Open Filehandles
#   
#   Make sure every allowed fh is open, no unapproved fhs should stay open.
#   
#   Sub only checks fh lists. Doesn't open / close any fhs.
#   
#   @test       Note:           Compare fh lists
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-28s => %-112s [%s]\n", $name, $actual_out, $status; }; my ( $valid_status, $valid_error ) = ConfigServer::Aegis::_fds_cage_verify( [ 0, 1, 2, 8 ], { 0 => 1, 1 => 1, 2 => 1, 8 => 1 } ); $show->( "valid_status", $valid_status, 1 ); $show->( "valid_error", $valid_error, undef ); my @cases = ( [ "extra_open", [ 0, 1, 2, 8 ], { 0 => 1, 1 => 1, 2 => 1 }, "Cannot verify module fhs, unapproved fh [ 8 ] is still open" ], [ "missing_allowed", [ 0, 1, 2 ], { 0 => 1, 1 => 1, 2 => 1, 8 => 1 }, "Cannot verify module fhs, allowed fhs are not open: [ 8 ]" ], [ "missing_open_list", undef, {}, "Cannot verify module fhs, open fh list missing or invalid" ], [ "invalid_open_list", {}, {}, "Cannot verify module fhs, open fh list missing or invalid" ], [ "missing_allowed_list", [], undef, "Cannot verify module fhs, allowed fh list missing or invalid" ], [ "invalid_allowed_list", [], [], "Cannot verify module fhs, allowed fh list missing or invalid" ], [ "invalid_open_number", [ 0, "invalid" ], { 0 => 1 }, "Cannot verify module fhs, open fh list has an invalid fh num" ], [ "invalid_allowed_number", [ 0 ], { 0 => 1, invalid => 1 }, "Cannot verify module fhs, the allowed fh list has invalid fh num" ] ); for my $case ( @cases ) { my ( $name, $open, $allowed, $expected_error ) = @{$case}; my ( $status, $error ) = ConfigServer::Aegis::_fds_cage_verify( $open, $allowed ); $show->( "${name}_status", $status, undef ); $show->( "${name}_error", $error, $expected_error ); } my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); printf "%-28s => %s\n", "result", ( $all_ok ? "OK" : "FAILED" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     fds_open        arrayref    Open fh nums
#               fds_allowed     hashref     Allowed fh nums
#   @return     status          int|undef   Check result
#                                               1           Fh lists verified
#                                               undef       Check failed
#               error           str|undef   Failure reason
# #

sub _fds_cage_verify
{
    my ( $fds_open, $fds_allowed ) = @_;

    return _throw_err( "Cannot verify module fhs, open fh list missing or invalid" )
        if ref( $fds_open ) ne 'ARRAY';

    return _throw_err( "Cannot verify module fhs, allowed fh list missing or invalid" )
        if ref( $fds_allowed ) ne 'HASH';

    for my $fd_opened ( @{$fds_open} )
    {
        return _throw_err( "Cannot verify module fhs, open fh list has an invalid fh num" )
            if !defined( $fd_opened ) or ref( $fd_opened ) or $fd_opened !~ /\A[0-9]+\z/;
    }

    for my $allowed_fd ( keys( %{$fds_allowed} ) )
    {
        return _throw_err( "Cannot verify module fhs, the allowed fh list has invalid fh num" )
            if $allowed_fd !~ /\A[0-9]+\z/;
    }

    my %allowlist_unconfirmed = %{$fds_allowed};
    for my $fd_opened ( @{$fds_open} )
    {
        return _throw_err( "Cannot verify module fhs, unapproved fh [ $fd_opened ] is still open" )
            if !exists( $fds_allowed->{$fd_opened} );

        delete $allowlist_unconfirmed{$fd_opened};
    }

    if ( keys( %allowlist_unconfirmed ) )
    {
        my @missing = sort { $a <=> $b } keys( %allowlist_unconfirmed );
        return _throw_err( "Cannot verify module fhs, allowed fhs are not open: [ " . join( ", ", @missing ) . " ]" );
    }

    _log(
        "OK",
        "Verified module fhs; every allowed fh is open and no unapproved fhs remain open"
    );

    return ( 1, undef );
}

# #
#   Aegis › FDs › Snapshot
#   
#   Create list of every open fd num in current process.
#   
#   @test       Note:           Create / verify snapshot that has a real open fd
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require Fcntl; require POSIX; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push(@warnings, @_); }; my $show = sub { my ($name, $actual, $passed) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $status = $passed ? "OK" : "FAILED"; $all_ok = 0 if !$passed; printf "%-20s => %-112s [%s]\n", $name, $actual_out, $status; }; my $fd_limit = ConfigServer::Aegis::FD_COUNT_MAX(); my $test_fd = POSIX::open("/dev/null", Fcntl::O_RDONLY()); die "Cannot open /dev/null: $!\n" if !defined($test_fd); my ($fds, $error) = ConfigServer::Aegis::_fds_snapshot(); my $fds_type = ref($fds) || "undef"; my $fds_out = ref($fds) eq "ARRAY" ? "[" . join(", ", @{$fds}) . "]" : "undef"; my $fd_count = ref($fds) eq "ARRAY" ? scalar(@{$fds}) : 0; my $numeric_ok = ref($fds) eq "ARRAY" && !grep { !defined($_) || ref($_) || $_ !~ /\A[0-9]+\z/ } @{$fds}; my %seen; my $unique_ok = ref($fds) eq "ARRAY"; my %present; if (ref($fds) eq "ARRAY") { for my $fd (@{$fds}) { $unique_ok = 0 if $seen{$fd}++; $present{$fd} = 1; } } my $standard_ok = $present{0} && $present{1} && $present{2}; my $test_found = $present{$test_fd} ? 1 : 0; my $test_state = -e "/proc/self/fd/$test_fd" ? "open" : "closed"; $show->("snapshot_type", $fds_type, $fds_type eq "ARRAY"); $show->("snapshot_error", $error, !defined($error)); $show->("test_fd", $test_fd, defined($test_fd) && $test_fd =~ /\A[0-9]+\z/); $show->("open_fds", $fds_out, ref($fds) eq "ARRAY"); $show->("fd_count", $fd_count, $fd_count > 0); $show->("count_limit", "$fd_count/$fd_limit", $fd_count > 0 && $fd_count <= $fd_limit); $show->("numeric_fds", ($numeric_ok ? "yes" : "no"), $numeric_ok); $show->("unique_fds", ($unique_ok ? "yes" : "no"), $unique_ok); $show->("standard_fds", ($standard_ok ? "found" : "missing"), $standard_ok); $show->("test_fd_found", $test_found, $test_found == 1); $show->("test_fd_state", $test_state, $test_state eq "open"); my $close_result = POSIX::close($test_fd); my $cleanup = defined($close_result) && $close_result == 0 ? 1 : 0; $show->("test_fd_cleanup", $cleanup, $cleanup == 1); my $warnings_out = @warnings ? join("", @warnings) : "none"; $warnings_out =~ s/\s+\z//; $show->("warnings", $warnings_out, $warnings_out eq "none"); printf "%-20s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#   @params     void
#   @return     fds             arrayref|undef  Open fd numbers
#               error           str|undef       Failure reason
# #

sub _fds_snapshot
{
    my $dir;

    # open fd $dir assoc to Messenger process
    if ( !opendir( $dir, PROC_FD_PATH ) )
    {
        my $open_err = "$!";
        return _throw_err( "Cannot open the current process fh folder [ " . PROC_FD_PATH . " ]", $open_err );
    }

    # #
    #   Opening '/proc/self/fd' creates an fd used to read the dir.
    #   Get fd num so that it can be skipped in the list of open fds.
    # #

    my $dir_fd      = fileno( $dir );
    my $dir_fd_log  = defined( $dir_fd ) ? $dir_fd : "undef";
    my @fds;

    _log(
        "DEBUG",
        "Reading current process fh " .
        "[Folder: " . PROC_FD_PATH . "] " .
        "[Folder FD: $dir_fd_log] " .
        "[Maximum: " . FD_COUNT_MAX . "]"
    );

    my $ignored_entries = 0;
    my $fd_dir_skipped  = 0;

    while ( 1 )
    {
        # #
        #   @vars       $dir_entry      .       /proc/self/fd dir itself
        #                               ..      parent dir
        #                               0       STDIN
        #                               1       STDOUT
        #                               2       STDERR
        # #

        local $!        = 0;
        my $dir_entry   = readdir( $dir );

        # _log( "DEBUG", "Snapshot Folder entry [$dir_entry]" )
        #   if defined( $dir_entry );

        if ( !defined( $dir_entry ) )
        {
            if ( $! )
            {
                my $err         = "$!";
                my $dh_clean    = _cleanup_close_dirhandle( $dir );

                return _throw_err( "Cannot read current process fh folder [ " . PROC_FD_PATH . " ]", "$err$dh_clean" );
            }

            last;
        }

        # #
        #   The dir $dir_entry has entries like:
        #       "."
        #       ".."
        #   
        #   Count and skip anything that is not an fd number.
        # #

        if ( $dir_entry !~ /\A[0-9]+\z/ )
        {
            $ignored_entries++;
            next;
        }

        my $fd = 0 + $dir_entry;
        if ( defined( $dir_fd ) and $fd == $dir_fd )
        {
            $fd_dir_skipped++;
            next;
        }

        push @fds, $fd;
        my $current_i = scalar( @fds );

        _log(
            "DEBUG",
            "Open fh found [FD: $fd] " .
            "[Count: $current_i / " . FD_COUNT_MAX . "]"
        );

        if ( $current_i > FD_COUNT_MAX )
        {
            my $cleanup = _cleanup_close_dirhandle( $dir );
            return _throw_err( "Cannot create the open fh list, too many fhs were found " . "[Count: $current_i / " . FD_COUNT_MAX . "]$cleanup" );
        }
    }

    my $total_i = scalar( @fds );

    _log(
        "DEBUG",
        "Finished reading current process fhs " .
        "[Found: "             . scalar( @fds ) . " | " .
        "Ignored: "            . $ignored_entries . " | " .
        "Folder FD Skipped: "  . $fd_dir_skipped . " | " .
        "Count: "              . $total_i . " / " . FD_COUNT_MAX . "]"
    );

    _log(
        "DEBUG",
        "Finished reading the open fh folder " .
        "[Count: $total_i / " . FD_COUNT_MAX . "]"
    );

    if ( !closedir( $dir ) )
    {
        my $close_err = "$!";
        return _throw_err( "Cannot close the current process fh folder [ " . PROC_FD_PATH . " ]", $close_err );
    }

    undef $dir;

    my @fds_remains;
    for my $fd ( @fds )
    {
        my $fd_path = PROC_FD_PATH . "/$fd";

        local $! = 0;
        if ( lstat( $fd_path ) )
        {
            push( @fds_remains, $fd );
            next;
        }

        my $err_code    = 0 + $!;
        my $err_text    = "$!";

        next
            if $err_code == Errno::ENOENT( );

        return _throw_err( "Cannot check if fh [ $fd ] still open", $err_text );
    }

    _log(
        "OK",
        "Open fh list is ready " .
        "[Count: " . scalar( @fds_remains ) . "]"
    );

    return ( \@fds_remains, undef );
}

# #
#   Aegis › FDs › Close FH Number
#   
#   Close one open fh using its numeric fd.
#   
#   When allow_missing is 1, treat an already closed fd as a
#   successful result.
#   
#   @test       Note:           Close fd, test open / missing bad, close results
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require Fcntl; require Errno; require POSIX; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push(@warnings, @_); }; my $show = sub { my ($name, $actual, $expected) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $expected_out = defined($expected) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s => %-112s [%s]\n", $name, $actual_out, $status; }; my $fd = POSIX::open("/dev/null", Fcntl::O_RDONLY()); die "Cannot open /dev/null: $!\n" if !defined($fd); my ($closed, $close_error) = ConfigServer::Aegis::_fds_close($fd, 0); my $fd_state = -e "/proc/self/fd/$fd" ? "open" : "closed"; $show->("close_status", $closed, 1); $show->("close_error", $close_error, undef); $show->("fd_state", $fd_state, "closed"); my ($missing, $missing_error) = ConfigServer::Aegis::_fds_close($fd, 1); $show->("missing_status", $missing, 1); $show->("missing_error", $missing_error, undef); my $bad_fd_text; { local $! = Errno::EBADF(); $bad_fd_text = "$!"; } my ($required, $required_error) = ConfigServer::Aegis::_fds_close($fd, 0); $show->("required_status", $required, undef); $show->("required_error", $required_error, "Cannot close fh [ $fd ]: $bad_fd_text"); my $invalid_error = "Cannot close fh, fd nums missing or invalid"; my @cases = (["missing_fd", undef], ["ref_fd", []], ["negative_fd", "-1"], ["text_fd", "invalid"], ["decimal_fd", "3.5"], ["empty_fd", ""]); for my $case (@cases) { my ($name, $invalid_fd) = @{$case}; my ($status, $error) = ConfigServer::Aegis::_fds_close($invalid_fd, 0); $show->("${name}_status", $status, undef); $show->("${name}_error", $error, $invalid_error); } my $warnings_out = @warnings ? join("", @warnings) : "none"; $warnings_out =~ s/\s+\z//; $show->("warnings", $warnings_out, "none"); printf "%-24s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#   @params     fd_id           int             fd num
#               allow_missing   int             Allow an already closed fd
#   @return     status          undef|int       Close result
#                                                   1           Closed or already missing
#                                                   undef       Failed
#               error           undef|str       Failure reason
# #

sub _fds_close
{
    my ( $fd_id, $allow_missing ) = @_;

    return _throw_err( "Cannot close fh, fd nums missing or invalid" )
        if !defined( $fd_id ) or ref( $fd_id ) or $fd_id !~ /\A[0-9]+\z/;

    local $!            = 0;
    my $close_res       = POSIX::close( $fd_id );
    my $close_errno     = 0 + $!;
    my $close_err       = "$!";

    return ( 1, undef )
        if ( defined( $close_res ) and $close_res == 0 ) or ( $allow_missing and $close_errno == Errno::EBADF( ) );

    return _throw_err( "Cannot close fh [ $fd_id ]", $close_err );
}

# #
#   Aegis › FDs › Close Other Filehandles
#   
#   Close every open fh that Messenger doesn't need. Keep 
#   fhs listed in the allowed fh list.
#   
#   @test       Note:           Verify allowed fhs keep their original file, all others release theirs
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require File::Temp; require Fcntl; require POSIX; no warnings qw(redefine prototype); my $all_ok = 1; my $show = sub { my ($name, $actual, $expected) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $expected_out = defined($expected) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s => %-112s [%s]\n", $name, $actual_out, $status; }; my $open_test_fd = sub { my ($label) = @_; my ($fh, $path) = File::Temp::tempfile("messenger-$label-XXXXXX", TMPDIR => 1, UNLINK => 0); close($fh) or die "Cannot close temp file [$path]: $!\n"; my $fd = POSIX::open($path, Fcntl::O_RDONLY()); die "Cannot open temp file [$path]: $!\n" if !defined($fd); return ($fd, $path); }; my ($keep_fd, $keep_path) = $open_test_fd->("keep"); my ($close_fd_1, $close_path_1) = $open_test_fd->("close-1"); my ($close_fd_2, $close_path_2) = $open_test_fd->("close-2"); my ($close_status, $close_error) = ConfigServer::Aegis::_fds_close_unlisted([$keep_fd, $close_fd_1, $close_fd_2], {$keep_fd => 1}); my $keep_target = readlink("/proc/self/fd/$keep_fd"); my $close_target_1 = readlink("/proc/self/fd/$close_fd_1"); my $close_target_2 = readlink("/proc/self/fd/$close_fd_2"); my $keep_state = defined($keep_target) && $keep_target eq $keep_path ? "original-open" : "original-closed"; my $close_state_1 = defined($close_target_1) && $close_target_1 eq $close_path_1 ? "original-open" : "original-closed"; my $close_state_2 = defined($close_target_2) && $close_target_2 eq $close_path_2 ? "original-open" : "original-closed"; $show->("close_status", $close_status, 1); $show->("close_error", $close_error, undef); $show->("allowed_fd", $keep_state, "original-open"); $show->("closed_fd_1", $close_state_1, "original-closed"); $show->("closed_fd_2", $close_state_2, "original-closed"); my $keep_close = POSIX::close($keep_fd); my $keep_cleanup = defined($keep_close) && $keep_close == 0 ? 1 : 0; $show->("allowed_cleanup", $keep_cleanup, 1); my $removed = unlink($keep_path, $close_path_1, $close_path_2); $show->("files_removed", $removed, 3); my $input_error = "Cannot close fhs, open or allowed fh list is invalid"; my ($list_status, $list_error) = ConfigServer::Aegis::_fds_close_unlisted(undef, {}); $show->("invalid_list_status", $list_status, undef); $show->("invalid_list_error", $list_error, $input_error); my ($allow_status, $allow_error) = ConfigServer::Aegis::_fds_close_unlisted([], undef); $show->("invalid_allow_status", $allow_status, undef); $show->("invalid_allow_error", $allow_error, $input_error); my ($forced_status, $forced_error); { local *ConfigServer::Aegis::_fds_close = sub { return (undef, "forced close failure"); }; ($forced_status, $forced_error) = ConfigServer::Aegis::_fds_close_unlisted([9], {}); } $show->("forced_close_status", $forced_status, undef); $show->("forced_close_error", $forced_error, "Cannot close unneeded filehandles [9]: forced close failure"); my @closed_order; my ($order_status, $order_error); { local *ConfigServer::Aegis::_fds_close = sub { my ($fd) = @_; push(@closed_order, $fd); return (1, undef); }; ($order_status, $order_error) = ConfigServer::Aegis::_fds_close_unlisted([3, 9, 5], {5 => 1}); } $show->("order_status", $order_status, 1); $show->("order_error", $order_error, undef); $show->("closed_order", join(":", @closed_order), "9:3"); printf "%-24s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#   @params     fds_open        arrayref    Open fh numbers
#               allowlist       hashref     Allowed fh numbers
#   @return     status          undef|int   Close result
#                                               1           fh closed
#                                               undef       Failed
#               error           undef|str   Failure reason
# #

sub _fds_close_unlisted
{
    my ( $fds_open, $allowlist ) = @_;

    return _throw_err( "Cannot close fhs, open or allowed fh list is invalid" )
        if ref( $fds_open ) ne 'ARRAY' or ref( $allowlist ) ne 'HASH';

    my $closed_i = 0;
    for my $fd ( sort { $b <=> $a } @{$fds_open} )
    {
        next if $allowlist->{$fd};

        my ( $closed, $close_err ) = _fds_close( $fd, 0 );
        return _throw_err( "Cannot close unneeded filehandles [$fd]", $close_err )
            if !$closed;

        $closed_i++;
    }

    _log(
        "DEBUG",
        "Closed all filehandles that module doesn't need " .
        "[Closed: $closed_i]"
    );

    return ( 1, undef );
}

# #
#   Aegis › Perl › Get Paths
#   
#   Find perl lib folders that only root can change.
#   
#   @test       Note:           List / verify root owned perl lib folders
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require Cwd; require Fcntl; my $all_ok = 1; my $show = sub { my ($name, $actual, $passed) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $status = $passed ? "OK" : "FAILED"; $all_ok = 0 if !$passed; printf "%-16s => %-64s [%s]\n", $name, $actual_out, $status; }; my @paths = ConfigServer::Aegis::_perl_trusted_paths_get(); my %seen; my $path_num = 0; for my $path (@paths) { $path_num++; my $path_ok = defined($path) && !ref($path) && $path =~ m{\A/}; my $path_key = $path_ok ? $path : "invalid-$path_num"; $path_ok = 0 if $seen{$path_key}++; if ($path_ok) { my $resolved = Cwd::realpath($path); $path_ok = 0 if !defined($resolved) || $resolved ne $path; } if ($path_ok) { my $path_current = ""; for my $path_seg (grep { length($_) } split(m{/+}, $path)) { $path_current .= "/$path_seg"; my @status = stat($path_current); if (!@status || !Fcntl::S_ISDIR($status[2]) || $status[4] != 0 || ($status[2] & 0022) != 0) { $path_ok = 0; last; } } } $show->("trusted_dir_$path_num", $path, $path_ok); } $show->("trusted_count", scalar(@paths), scalar(@paths) > 0); printf "%-16s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#   @params     void
#   @return                     list        Detected perl lib folders
# #

sub _perl_trusted_paths_get
{
    my %seen;
    my @trusted;

    # warn( "INC entry: $_\n" ) for @INC;

    for my $path_inc ( @INC )
    {
        # skip $path_inc "."
        next
            if !defined( $path_inc ) or ref( $path_inc ) or $path_inc !~ m{\A/};

        # if $path_inc valid; resolve path ( /usr/lib64/perl5/vendor_perl )
        my $path_resolved = Cwd::realpath( $path_inc );
        next
            if !defined( $path_resolved ) or $seen{$path_resolved}++;

        # #
        #    @vars      $path_seg       usr
        #                               lib64
        #                               perl5
        #                               usr
        #               $path_current   /usr
        #                               /usr/lib64
        #                               /usr/lib64/perl5
        #               $path_trusted   0 || 1
        # #

        my $path_current = "";
        my $path_trusted = 1;
    
        for my $path_seg ( grep { length( $_ ) } split( m{/+}, $path_resolved ) )
        {
            $path_current   .= "/$path_seg";
            my @status      = stat( $path_current );

            if ( !@status or !Fcntl::S_ISDIR( $status[ 2 ] ) or $status[ 4 ] != 0 or ( $status[ 2 ] & 0022 ) != 0 )
            {
                $path_trusted = 0;
                last;
            }
        }

        push @trusted, $path_resolved
            if $path_trusted;
    }

    return @trusted;
}

# #
#   Aegis › Syscalls › Normalize Number
#   
#   Check a syscall number, remove leading zeros.
#   
#   @test       Note:           Normalize syscall nums
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my $sc_max = ConfigServer::Aegis::SYSCALL_NUM_MAX(); my $too_long = "1" x (ConfigServer::Aegis::SYSCALL_BYTES_MAX() + 1); my @cases = (["0", 0], ["0000", 0], ["116", 116], ["000116", 116], ["117", 117], ["119", 119], [$sc_max, $sc_max], [$sc_max + 1, undef], [$too_long, undef], ["-1", undef], ["+117", undef], ["117.0", undef], ["abc", undef], ["", undef], [undef, undef], [[], undef], [{}, undef]); for my $case (@cases) { my ($raw, $expected) = @{$case}; my $actual = ConfigServer::Aegis::_sc_normalize_number($raw); my $input = !defined($raw) ? "<undef>" : ref($raw) eq "ARRAY" ? "<arrayref>" : ref($raw) eq "HASH" ? "<hashref>" : length($raw) ? "$raw" : "<empty>"; my $actual_out = defined($actual) ? "$actual" : "undef"; my $expected_out = defined($expected) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-34s => %-12s [%s]\n", $input, $actual_out, $status; } printf "%-34s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#   @params     sc_num          scalar      Syscall num to check
#   @return     number          int|undef   Checked sc num
#                                               int         Valid num
#                                               undef       Invalid num
# #

sub _sc_normalize_number
{
    my ( $sc_num ) = @_;

    return
        if !defined( $sc_num ) or ref( $sc_num );

    my $sc_str = "$sc_num";
    return
        if length( $sc_str ) > SYSCALL_BYTES_MAX or
           $sc_str !~ /\A[0-9]+\z/;

    $sc_str =~ s/\A0+(?=[0-9])//;

    my $sc_max = "" . SYSCALL_NUM_MAX;
    return
        if length( $sc_str ) > length( $sc_max ) or
           ( length( $sc_str ) == length( $sc_max ) and
             $sc_str gt $sc_max );

    return 0 + $sc_str;
}

# #
#   Aegis › Syscalls › Format
#   
#   Return sorted syscall names
#   
#   @usage		my $formatted = _sc_format( $calls );
#   
#   @test		Note:		    Format and sort resolved syscall names
#               Command:	    sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $calls = { setresuid => 117, setresgid => 119, setgroups => 116 }; my $actual = ConfigServer::Aegis::_sc_format($calls); my $expected = "setgroups, setresgid, setresuid"; my $status = defined($actual) && $actual eq $expected ? "OK" : "FAILED"; my $actual_out = defined($actual) ? $actual : "undef"; printf "%-12s => %-36s [%s]\n", "formatted", $actual_out, $status; printf "%-12s => %s\n", "result", $status; exit($status eq "OK" ? 0 : 1);'
#   
#   @params     calls           hashref     System calls
#   @return     result          str         Formatted names
#                                               "undef"     $calls not a hash ref
#                                               ""          $calls has no names
#                                               str         sorted syscall names
# #

sub _sc_format
{
    my ( $calls ) = @_;
    return "undef"
        if ref( $calls ) ne 'HASH';

    # return join( ", ", map { "$_=$calls->{$_}" } sort keys %{$calls} );
    return join( ", ", sort keys( %{$calls} ) );
}

# #
#   Aegis › Syscalls › Find Perl Syscall File
#   
#   Find "syscall.ph" inside perl folder that only root can change.
#   
#   syscall.ph: perl file that defines the numbers Linux uses for
#               syscalls. These numbers based on cpu arch.
#   
#       Eg:     setgroups = 116
#               setresgid = 119
#               setresuid = 117
#   
#   @test       Note:           Find syscall.ph; verify Perl dir/path
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my $show = sub { my ($name, $actual, $passed) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $status = $passed ? "OK" : "FAILED"; $all_ok = 0 if !$passed; printf "%-16s => %-64s [%s]\n", $name, $actual_out, $status; }; my ($source, $dirs) = ConfigServer::Aegis::_sc_locate(); my $source_ok = defined($source) && !ref($source) && $source =~ m{/syscall[.]ph\z} && -f $source; $show->("source", $source, $source_ok); my $dirs_type = ref($dirs) || "undef"; $show->("dirs_type", $dirs_type, $dirs_type eq "ARRAY"); my $trusted_count = ref($dirs) eq "ARRAY" ? scalar(@{$dirs}) : 0; $show->("trusted_count", $trusted_count, $trusted_count > 0); my $source_trusted = 0; if ($source_ok && ref($dirs) eq "ARRAY") { my $source_dir = $source; $source_dir =~ s{/syscall[.]ph\z}{}; $source_trusted = grep { defined($_) && !ref($_) && $_ eq $source_dir } @{$dirs}; } $show->("source_trusted", ($source_trusted ? "yes" : "no"), $source_trusted); if (ref($dirs) eq "ARRAY") { my $dir_num = 0; for my $dir (@{$dirs}) { $dir_num++; my $dir_ok = defined($dir) && !ref($dir) && $dir =~ m{\A/} && -d $dir; $show->("trusted_dir_$dir_num", $dir, $dir_ok); } } printf "%-16s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#   @params     void
#   @return     source          str|undef   syscall.ph path
#               dirs_include    arrayref    Perl lib folders
# #

sub _sc_locate
{
    my @dirs = _perl_trusted_paths_get( );

    # #
    #   Loop @dirs until syscall.ph found.
    #   
    #   @vars       $dirs           [/usr/lib64/perl5/vendor_perl, /usr/share/perl5/vendor_perl, /usr/lib64/perl5, /usr/share/perl5]
    #               $dir            /usr/lib64/perl5/vendor_perl
    #                               /usr/share/perl5/vendor_perl
    #                               /usr/lib64/perl5
    #                               /usr/share/perl5
    #               $path_check     /usr/share/perl5/vendor_perl/syscall.ph
    #               $status         [64768, 10703818, 33188, 1, 0, 0, 0, 86, 1792020658, 1753674839, 1771348100, 4096, 8]
    #                                   Only populated if $path_check exists
    # #

    for my $dir ( @dirs )
    {
        my $path_check  = "$dir/syscall.ph";
        my @status      = lstat( $path_check );
      # warn( "status [" . join( ", ", @status ) . "]\n" );

        next
            if !@status or
               !Fcntl::S_ISREG( $status[ 2 ] ) or
               $status[ 4 ] != 0 or
               ( $status[ 2 ] & 0022 ) != 0;

        return ( $path_check, \@dirs );
    }

    return ( undef, \@dirs );
}

# #
#   Aegis › Match Process IDs
#   
#   Check all 4 uid or gid values match the $expect id.
#   
#   Accept arrayref with all 4 ids, or a hashref with
#   the named real, effective, saved, and fs ids.
#   
#   $ids        = [ 974, 974, 974, 974 ]
#               974     (RUID) Real User ID
#               974     (EUID) Effective User ID
#               974     (SUID) Saved Set User ID
#               974     (FSUID) File System User ID
#   
#   $expect     = 974
#   
#   Return 1    = if all 4 $ids match the $expect id
#               ( $ids ) 974 == 974 ($expect)
#               ( $ids ) 974 == 974 ($expect)
#               ( $ids ) 974 == 974 ($expect)
#               ( $ids ) 974 == 974 ($expect)
#   
#   @usage      _is_ids_match( [ 974, 974, 974, 974 ], 0 )      =>  undef
#               _is_ids_match( [ 974, 974, 974, 974 ], 974 )    =>  1
#   
#   @test       Note:           Test array and named hash process ids
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my @cases = ( [ "array_match", [ 974, 974, 974, 974 ], 974, 1 ], [ "hash_match", { real => 974, effective => 974, saved => 974, filesystem => 974 }, 974, 1 ], [ "array_mismatch", [ 974, 974, 975, 974 ], 974, undef ], [ "hash_mismatch", { real => 974, effective => 974, saved => 975, filesystem => 974 }, 974, undef ], [ "hash_missing", { real => 974, effective => 974, saved => 974 }, 974, undef ], [ "invalid_type", "974", 974, undef ], [ "invalid_expected", [ 974, 974, 974, 974 ], "invalid", undef ] ); printf "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 179; for my $case ( @cases ) { my ( $name, $ids, $expected_id, $expected_result ) = @{$case}; my $actual = ConfigServer::Aegis::_is_ids_match( $ids, $expected_id ); $show->( $name, $actual, $expected_result ); } my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     ids             arrayref|hashref    All 4 uid / gid ids
#               expect          int                 uid or gid that all 4 ids must match
#   @return     status          int|undef   Match result
#                                               1           All 4 ids match
#                                               undef       No match
# #

sub _is_ids_match
{
    my ( $ids, $expect ) = @_;

    if ( ref( $ids ) eq 'HASH' )
    {
        my @id_names = qw( real effective saved filesystem );

        if ( grep { !exists( $ids->{$_} ) } @id_names )
        {
            _log( "FAIL", "Cannot compare process ids, all 4 named id values required" );
            return;
        }

        $ids = [ @{$ids}{@id_names} ];
    }

    if ( ref( $ids ) ne 'ARRAY' or @{$ids} != 4 )
    {
        _log( "FAIL", "Cannot compare process ids, exactly 4 id values required" );
        return;
    }

    _log( "DEBUG", "Starting id comparison " .
        "[IDs: " . join( ":", @{$ids} ) . "] " .
        "[Expected: " . ( defined( $expect ) && !ref( $expect ) ? $expect : "invalid" ) . "]"
    );

    my $normalize_expect = _normalize_uid_or_gid( $expect );
    if ( !defined( $normalize_expect ) )
    {
        _log( "FAIL", "Cannot compare process ids, expected user or group is invalid" );
        return;
    }

    _log( "DEBUG", "[normalize_expect: " . $normalize_expect . "] " );

    my @normalize_ids = map { scalar _normalize_uid_or_gid( $_ ) } @{$ids};
    if ( grep { !defined( $_ ) } @normalize_ids )
    {
        _log( "FAIL", "Cannot compare process ids, one or more id values are invalid" );
        return;
    }

    _log( "DEBUG", "Checking all 4 process ids against expected id" );

    my $is_ids_match = !grep { $_ != $normalize_expect } @normalize_ids;
    if ( !$is_ids_match )
    {
        _log( "FAIL", "One or more process ids do not match expected user or group id" );
        return;
    }

    _log( "OK", "All 4 process ids match expected user or group id" );

    return 1;
}

# #
#   Aegis › Identity › Signals › Block
#
#   Save which signals are currently blocked. Temp block signals while
#   the process changes uid and gid from root using mapped config item.
#
#   Doesn't allow SIGKILL or SIGSTOP to be blocked, has to be
#   able to always make process exit/pause.
#   
#   @test       Note:           Test full sub
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my ($set_prev, $block_error) = ConfigServer::Aegis::_identity_signals_block(); my $saved_set = ref($set_prev) || "undef"; my $saved_status = $saved_set eq "POSIX::SigSet" ? "OK" : "FAILED"; my $block_error_out = defined($block_error) ? $block_error : "undef"; my $block_status = !defined($block_error) ? "OK" : "FAILED"; my ($restored, $restore_error); my $restore_called = 0; if ($saved_status eq "OK" && $block_status eq "OK") { $restore_called = 1; ($restored, $restore_error) = ConfigServer::Aegis::_identity_signals_restore($set_prev); } my $restored_out = defined($restored) ? $restored : "undef"; my $restored_status = $restore_called && defined($restored) && $restored == 1 ? "OK" : "FAILED"; my $restore_error_out = defined($restore_error) ? $restore_error : "undef"; my $restore_error_status = $restore_called && !defined($restore_error) ? "OK" : "FAILED"; my $passed = $saved_status eq "OK" && $block_status eq "OK" && $restored_status eq "OK" && $restore_error_status eq "OK"; printf "%-13s => %-13s [%s]\n", "saved_set", $saved_set, $saved_status; printf "%-13s => %-13s [%s]\n", "block_error", $block_error_out, $block_status; printf "%-13s => %-13s [%s]\n", "restored", $restored_out, $restored_status; printf "%-13s => %-13s [%s]\n", "restore_error", $restore_error_out, $restore_error_status; printf "%-13s => %s\n", "result", ($passed ? "OK" : "FAILED"); exit($passed ? 0 : 1);'
#               
#               Note:           Test condition "my ( $blocked, $exception );"
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require POSIX; my $set_blocked = POSIX::SigSet->new(); my $set_type = ref($set_blocked) || "undef"; my $set_status = $set_type eq "POSIX::SigSet" ? "OK" : "FAILED"; my $filled = $set_blocked->fillset(); my $filled_out = defined($filled) ? $filled : "undef"; my $filled_status = defined($filled) ? "OK" : "FAILED"; my $set_prev = POSIX::SigSet->new(); local $! = 0; my ($blocked, $exception); { local $@; $blocked = eval { POSIX::sigprocmask(POSIX::SIG_BLOCK(), $set_blocked, $set_prev); }; $exception = "$@"; } my $block_errno = "$!"; my $blocked_out = defined($blocked) ? $blocked : "undef"; my $blocked_status = defined($blocked) ? "OK" : "FAILED"; my $exception_out = length($exception) ? $exception : "undef"; my $exception_status = !length($exception) ? "OK" : "FAILED"; my $errno_out = length($block_errno) ? $block_errno : "undef"; my $errno_status = !length($block_errno) ? "OK" : "FAILED"; my $restored = POSIX::sigprocmask(POSIX::SIG_SETMASK(), $set_prev); my $restored_out = defined($restored) ? $restored : "undef"; my $restored_status = defined($restored) ? "OK" : "FAILED"; my $passed = $set_status eq "OK" && $filled_status eq "OK" && $blocked_status eq "OK" && $exception_status eq "OK" && $errno_status eq "OK" && $restored_status eq "OK"; printf "%-9s => %-13s [%s]\n", "set_type", $set_type, $set_status; printf "%-9s => %-13s [%s]\n", "filled", $filled_out, $filled_status; printf "%-9s => %-13s [%s]\n", "blocked", $blocked_out, $blocked_status; printf "%-9s => %-13s [%s]\n", "exception", $exception_out, $exception_status; printf "%-9s => %-13s [%s]\n", "errno", $errno_out, $errno_status; printf "%-9s => %-13s [%s]\n", "restored", $restored_out, $restored_status; printf "%-9s => %s\n", "result", ($passed ? "OK" : "FAILED"); exit($passed ? 0 : 1);'
#
#   @params     void
#   @return     set_prev        ref|undef   Previous signal mask
#                                               ref         Signals blocked
#                                               undef       Failed
#               error           str|undef   Failure reason
# #

sub _identity_signals_block
{
    my $config_item = _identity_config_item( );

    # #
    #   $set_blocked        POSIX::SigSet=SCALAR
    #   $filled             0 but true
    #   $set_prev           POSIX::SigSet=SCALAR
    # #

    my $set_blocked = eval { POSIX::SigSet->new( ) };
    return _throw_err( "Unable to create the list of signals to block" )
        if !defined( $set_blocked );

    my $filled = eval { $set_blocked->fillset( ) };
    return _throw_err( "Unable to add all signals to blocked signal list" )
        if !defined( $filled );

    my $set_prev = eval { POSIX::SigSet->new( ) };
    return _throw_err( "Unable to create list used to save signals already blocked" )
        if !defined( $set_prev );

    local $! = 0;
    my ( $blocked, $except );
    {
        local $@;
        $blocked = eval
        {
            POSIX::sigprocmask( POSIX::SIG_BLOCK( ), $set_blocked,$set_prev );
        };
        $except = "$@";
    }

    # #
    #   @vars       $blocked        "0 but true";   # Success
    #                               undef;          # Failure
    # #

    if ( !defined( $blocked ) )
    {
        my $reason  = length( $except )
                        ? "Signal blocking unavailable"
                        : "$!";

        $reason = "unknown error"
            if !length( $reason );

        return _throw_err(
            "Unable to block signals while changing uid and gid from root " .
            "using [ $config_item ]: [ $reason ]"
        );
    }

    _log(
        "OK",
        "Signals blocked while changing uid and gid from root using [ $config_item ]"
    );

    return ( $set_prev, undef );
}

# #
#   Aegis › Identity › Signals › Restore
#
#   Signals are temp blocked while process uid and gid change from
#   root using mapped config item.
#   
#   Restore which signals were blocked before the change happened.
#   Signals that were temp blocked can be delivered again.
#   
#   @test       Note:           Change / restore SIGUSR1 setting, test invalid input / forced failure paths
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require POSIX; require Errno; my $all_ok = 1; my $show = sub { my ($name, $actual, $expected) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $expected_out = defined($expected) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-18s => %-160s [%s]\n", $name, $actual_out, $status; }; my $empty_set = POSIX::SigSet->new(); my $original_set = POSIX::SigSet->new(); my $captured = POSIX::sigprocmask(POSIX::SIG_BLOCK(), $empty_set, $original_set); my $test_set = POSIX::SigSet->new(); $test_set->addset(POSIX::SIGUSR1()); my $was_blocked = $original_set->ismember(POSIX::SIGUSR1()); my $before_out = $was_blocked ? "blocked" : "unblocked"; my $change_type = $was_blocked ? POSIX::SIG_UNBLOCK() : POSIX::SIG_BLOCK(); my $changed = POSIX::sigprocmask($change_type, $test_set); my ($status, $error) = ConfigServer::Aegis::_identity_signals_restore($original_set); my $after_set = POSIX::SigSet->new(); my $read_after = POSIX::sigprocmask(POSIX::SIG_BLOCK(), $empty_set, $after_set); my $is_blocked = $after_set->ismember(POSIX::SIGUSR1()); my $after_out = $is_blocked ? "blocked" : "unblocked"; my $cleanup = POSIX::sigprocmask(POSIX::SIG_SETMASK(), $original_set); $show->("captured", $captured, "0 but true"); $show->("changed", $changed, "0 but true"); $show->("signal_before", $before_out, $before_out); $show->("restore_status", $status, 1); $show->("restore_error", $error, undef); $show->("read_after", $read_after, "0 but true"); $show->("signal_after", $after_out, $before_out); $show->("cleanup", $cleanup, "0 but true"); my $invalid_error = "Unable to restore signals, saved blocked signal list missing or invalid"; my ($missing_status, $missing_error) = ConfigServer::Aegis::_identity_signals_restore(undef); $show->("missing_status", $missing_status, undef); $show->("missing_error", $missing_error, $invalid_error); my ($nonref_status, $nonref_error) = ConfigServer::Aegis::_identity_signals_restore("invalid"); $show->("nonref_status", $nonref_status, undef); $show->("nonref_error", $nonref_error, $invalid_error); my $error_start = "Unable to restore blocked signal list saved before changing uid and gid from root using [ caller-provided identity ]: "; my ($exception_status, $exception_error); { no warnings qw(redefine prototype); local *POSIX::sigprocmask = sub { die "forced exception\n"; }; ($exception_status, $exception_error) = ConfigServer::Aegis::_identity_signals_restore($original_set); } $show->("exception_status", $exception_status, undef); $show->("exception_error", $exception_error, $error_start . "Changing the blocked signal list is unavailable"); my $eperm_text; { local $! = Errno::EPERM(); $eperm_text = "$!"; } my ($errno_status, $errno_error); { no warnings qw(redefine prototype); local *POSIX::sigprocmask = sub { $! = Errno::EPERM(); return; }; ($errno_status, $errno_error) = ConfigServer::Aegis::_identity_signals_restore($original_set); } $show->("errno_status", $errno_status, undef); $show->("errno_error", $errno_error, $error_start . $eperm_text); my ($unknown_status, $unknown_error); { no warnings qw(redefine prototype); local *POSIX::sigprocmask = sub { $! = 0; return; }; ($unknown_status, $unknown_error) = ConfigServer::Aegis::_identity_signals_restore($original_set); } $show->("unknown_status", $unknown_status, undef); $show->("unknown_error", $unknown_error, $error_start . "unknown error"); printf "%-18s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#
#   @params     set_prev        ref         Previous signal mask
#   @return     status          int|undef   Restore result
#                                               1           Restored
#                                               undef       Failed
#               error           str|undef   Failure reason
# #

sub _identity_signals_restore
{
    my ( $set_prev ) = @_;

    return _throw_err( "Unable to restore signals, saved blocked signal list missing or invalid" )
        if !defined( $set_prev ) or !ref( $set_prev );

    my $config_item = _identity_config_item( );

    local $! = 0;
    my ( $restored, $exception );
    {
        local $@;
        $restored = eval
        {
            POSIX::sigprocmask( POSIX::SIG_SETMASK( ), $set_prev );
        };
        $exception = "$@";
    }

    if ( !defined( $restored ) )
    {
        my $reason  = length( $exception )
                        ? "Changing the blocked signal list is unavailable"
                        : "$!";

        $reason = "unknown error"
            if !length( $reason );

        return _throw_err(
            "Unable to restore blocked signal list saved before changing uid and gid from root using [ $config_item ]: $reason"
        );
    }

    _log(
        "OK",
        "Restored blocked signal list saved before changing uid and gid from root using [ $config_item ]"
    );

    return ( 1, undef );
}

# #
#   Aegis › Identity › Prepare
#   
#   Check configured MESSENGER_USER uid and gid before changing
#   process to user
#   
#   @test       Note:           Check Messenger uid and gid
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push(@warnings, @_); }; my $show = sub { my ($name, $actual, $expected) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $expected_out = defined($expected) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s => %-112s [%s]\n", $name, $actual_out, $status; }; $show->("platform", $^O, "linux"); my ($identity, $error) = ConfigServer::Aegis::_identity_prepare(1001, 1002); my $identity_out = $identity ? "uid=$identity->{uid}, gid=$identity->{gid}" : "undef"; $show->("valid_identity", $identity_out, "uid=1001, gid=1002"); $show->("valid_error", $error, undef); my $invalid_error = "uid and gid must be within the Linux id range [1 - " . ConfigServer::Aegis::ID_VALUE_MAX( ) . "]"; my @cases = (["missing_uid", undef, 1002], ["missing_gid", 1001, undef], ["root_uid", 0, 1002], ["root_gid", 1001, 0], ["text_uid", "invalid", 1002], ["text_gid", 1001, "invalid"], ["ref_uid", [], 1002], ["ref_gid", 1001, []]); for my $case (@cases) { my ($name, $uid, $gid) = @{$case}; my ($case_identity, $case_error) = ConfigServer::Aegis::_identity_prepare($uid, $gid); my $case_identity_out = $case_identity ? "uid=$case_identity->{uid}, gid=$case_identity->{gid}" : "undef"; $show->("${name}_identity", $case_identity_out, undef); $show->("${name}_error", $case_error, $invalid_error); } my $warnings_out = @warnings ? join("", @warnings) : "none"; $warnings_out =~ s/\s+\z//; $show->("warnings", $warnings_out, "none"); printf "%-24s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#   @params     _uid            scalar          Messenger uid
#               _gid            scalar          Messenger gid
#   @return     identity        hashref|undef   Checked uid and gid
#               error           str|undef       Failure reason
# #

sub _identity_prepare
{
    my ( $_uid, $_gid ) = @_;

    my $uid = _normalize_uid_or_gid_noroot( $_uid );
    my $gid = _normalize_uid_or_gid_noroot( $_gid );

    _log(
        "DEBUG",
        "Checking configured uid and gid " .
        "[User ID: " . ( defined( $uid ) ? $uid : "invalid" ) . " | " .
        "Group ID: " . ( defined( $gid ) ? $gid : "invalid" ) . "]"
    );

    return _throw_err( "uid and gid must be within the Linux id range [1 - " . ID_VALUE_MAX . "]" )
        if !defined( $uid ) or !defined( $gid );

    return _throw_err( MODULE_NAME . " can only remove root perms on Linux" )
        if $^O ne 'linux';

    _log(
        "OK",
        "Configured uid and gid are valid " .
        "[UID: $uid | GID: $gid]"
    );

    return ( { uid => $uid, gid => $gid }, undef );
}

# #
#   Aegis › Identity › System Calls
#   
#   Load syscall nums Linux uses for:
#       setgroups, setresgid, setresuid
#   
#   Load nums from syscall.ph file. Use integrated fallback list of
#   nums if syscall.ph not found.
#   
#   Validate syscall nums before running task.
#   
#   @usage      my ( $calls, $error ) = _identity_map_prepare( );
#   
#   @test       Note:           Test primary syscall lookup on current architecture
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-16s => %-24s [%s]\n", $name, $actual_out, $status; }; my ( $map, $error ) = ConfigServer::Aegis::_identity_map_prepare( ); my $map_type = ref( $map ) || "undef"; $show->( "map_type", $map_type, "HASH" ); for my $name ( qw( prctl setgroups setresgid setresuid ) ) { my $value = ref( $map ) eq "HASH" && exists( $map->{$name} ) ? $map->{$name} : undef; my $actual = !defined( $value ) && $name eq "prctl" ? "optional-unavailable" : defined( ConfigServer::Aegis::_sc_normalize_number( $value ) ) ? "valid" : "invalid"; my $expected = $name eq "prctl" && !defined( $value ) ? "optional-unavailable" : "valid"; $show->( $name, $actual, $expected ); } $show->( "error", $error, undef ); printf "%-16s => %s\n", "result", ( $all_ok ? "OK" : "FAILED" ); exit( $all_ok ? 0 : 1 );'
#   
#               Note:           Test fallback syscall lookup on current architecture
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'no warnings qw( redefine prototype ); local *ConfigServer::Aegis::_sc_locate = sub { return ( undef, [] ); }; my $all_ok = 1; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-16s => %-24s [%s]\n", $name, $actual_out, $status; }; my ( $map, $error ) = ConfigServer::Aegis::_identity_map_prepare( ); my $map_type = ref( $map ) || "undef"; $show->( "map_type", $map_type, "HASH" ); for my $name ( qw( prctl setgroups setresgid setresuid ) ) { my $value = ref( $map ) eq "HASH" && exists( $map->{$name} ) ? $map->{$name} : undef; my $actual = !defined( $value ) && $name eq "prctl" ? "optional-unavailable" : defined( ConfigServer::Aegis::_sc_normalize_number( $value ) ) ? "valid" : "invalid"; my $expected = $name eq "prctl" && !defined( $value ) ? "optional-unavailable" : "valid"; $show->( $name, $actual, $expected ); } $show->( "error", $error, undef ); printf "%-16s => %s\n", "result", ( $all_ok ? "OK" : "FAILED" ); exit( $all_ok ? 0 : 1 );'
#   
#   @test       Note:           Force missing syscall.ph path, validate aarch64 fallback map
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require POSIX; no warnings qw(redefine prototype); local *ConfigServer::Aegis::_sc_locate = sub { return (undef, []); }; local *POSIX::uname = sub { return ("Linux", "test-host", "test-release", "test-version", "aarch64"); }; my (undef, undef, undef, undef, $arch) = POSIX::uname(); my $all_ok = 1; my $show = sub { my ($name, $actual, $expected) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $expected_out = defined($expected) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-10s => %-12s [%s]\n", $name, $actual_out, $status; }; my ($map, $error) = ConfigServer::Aegis::_identity_map_prepare(); my $map_type = ref($map) || "undef"; $show->("arch", $arch, "aarch64"); $show->("map_type", $map_type, "HASH"); my %expected = (prctl => 167, setgroups => 159, setresgid => 149, setresuid => 147); for my $name (qw(prctl setgroups setresgid setresuid)) { my $actual = ref($map) eq "HASH" && exists($map->{$name}) ? $map->{$name} : undef; $show->($name, $actual, $expected{$name}); } $show->("error", $error, undef); printf "%-10s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#   @params     void
#   @return     calls           hashref|undef   Syscall nums
#               error           str|undef       Failure reason
# #

sub _identity_map_prepare
{
    my ( undef, undef, undef, undef, $arch ) = POSIX::uname( );

    # #
    #   @vars       %sc_raw         prctl=157, setgroups=116, setresgid=119, setresuid=117
    #               $sc_file        /usr/lib64/perl5/syscall.ph
    #               $is_arch_ok     0 || 1
    # #

    my ( %sc_raw, $sc_file );
    my $is_arch_ok = defined( $arch ) && exists( $SC_ABI{$arch} );

    # #
    #   System Call › Method 1 (Primary)
    #   
    #   Locate and load syscall.ph from a Perl dir.
    #   Read the required call numbers when the file loads.
    #   
    #   @vars       $header_path    /usr/lib64/perl5/syscall.ph
    #               $trusted_dirs:  Array
    #                               /usr/local/csf/lib
    #                               /usr/lib64/perl5/vendor_perl
    #                               /usr/share/perl5/vendor_perl
    #                               /usr/lib64/perl5
    #                               /usr/share/perl5
    #               $header_valid   0 || 1
    #               $header_err     ""
    # #

    my ( $header_path, $trusted_dirs )  = _sc_locate( );
    my ( $header_valid, $header_err )   = ( 0, "" );

    if ( defined( $header_path ) )
    {
        local $@;
        $header_valid = eval
        {
            local $SIG{__DIE__} = undef;
            local @INC          = @{$trusted_dirs};

            # /usr/lib64/perl5/syscall.ph => /usr/lib64/perl5/bits/syscall.ph
            require $header_path;
            1;
        };
        $header_err = "$@";
    }
    else
    {
        $header_err = "syscall.ph source unavailable";
    }

    $header_err = "none"
        if $header_valid;

    $header_err = "unknown error"
        if !$header_valid and !length( $header_err );

    _log(
        "DEBUG",
        "Identity map source check " .
        "[header: " . ( defined( $header_path ) ? $header_path : "undef" ) . " | " .
        "loaded: " . ( $header_valid ? "yes" : "no" ) . " | " .
        "arch: " . ( defined( $arch ) ? $arch : "undef" ) . " | " .
        "dirs(trust): " . join( ", ", @{$trusted_dirs} ) . " | " .
        "error: $header_err]"
    );

    if ( $header_valid )
    {
        $sc_file = $header_path;
        for my $sysgroup ( @SC_LOOKUP )
        {
            # #
            #   $name       prctl, setgroups, setresgid, or setresuid
            #   $sys        SYS_prctl, SYS_setgroups, SYS_setresgid, or SYS_setresuid
            #   $sub        Code ref for loaded const subroutine
            # #

            my $name        = $sysgroup->{name};
            my $sys         = $sysgroup->{sub};
            my $required    = $sysgroup->{required};
            my $sub         = __PACKAGE__->can( $sys );

            if ( !$sub )
            {
                return _throw_err( "Syscall subroutine [ $sys ] unavailable from file [ $sc_file ]" )
                    if $required;

                $sc_raw{$name} = undef;
                next;
            }

            local $@;

            # #
            #   Run const sub loaded through syscall.ph.
            #   Each const sub returns syscall num for current CPU arch.
            # #

            my $sc_num  = eval { $sub->( ) };
            my $sc_err  = "$@";

            if ( $sc_err )
            {
                return _throw_err(
                    "Identity call [ $name ] could not be read from file [ $sc_file ]: " .
                    ( length( $sc_err ) ? $sc_err : "unknown error" )
                ) if $required;

                $sc_raw{$name} = undef;
                next;
            }

            $sc_raw{$name} = $sc_num;
        }

    }

    # #
    #   System Call › Method 2 (Fallback)
    #   
    #   cpanel version of perl might not have syscall.ph. If
    #   unavailable, use fallback list of Linux arch abi numbers.
    # #

    else
    {
        return _throw_err( "Syscall definitions are unavailable for arch [" . ( defined( $arch ) ? $arch : "unknown" ) . "]" )
            if !$is_arch_ok;

        for my $sysgroup ( @SC_LOOKUP )
        {
            my $name        = $sysgroup->{name};
            $sc_raw{$name}  = $SC_ABI{$arch}{$name};
        }

        $sc_file = "supported Linux abi";
    }

    # #
    #   System Call › Map Validation
    #   
    #   Validate numbers collected by primary or fallback method.
    #   
    #   $sysgroup = {
    #       'name'  => 'setresuid',
    #       'sub'   => 'SYS_setresuid'
    #   }
    # #

    my %map;
    for my $sysgroup ( @SC_LOOKUP )
    {
        # #
        #   name        setresuid 
        #   sys         SYS_setresuid 
        # #

        my $name            = $sysgroup->{name};
        my $sys             = $sysgroup->{sub};
        my $required        = $sysgroup->{required};

        my $num_raw         = $sc_raw{$name};
        my $num_verified    = _sc_normalize_number( $num_raw );
        my $num_expected    = $is_arch_ok
                                ? $SC_ABI{$arch}{$name}
                                : undef;

        _log(
            "DEBUG",
            "Identity call validation " .
            "[arch: " . ( defined( $arch ) ? $arch : "undef" ) . " | " .
            "file: $sc_file | " .
            "name: $name | " .
            "constant: $sys | " .
            "num(raw): " . ( defined( $num_raw ) ? $num_raw : "undef" ) . " | " .
            "num(out): " . ( defined( $num_verified ) ? $num_verified : "undef" ) . " | " .
            "num(expect): " . ( defined( $num_expected ) ? $num_expected : "undef" ) . " | " .
            "num(max_val): " . SYSCALL_NUM_MAX . " | " .
            "num(max_len): " . SYSCALL_BYTES_MAX . "]"
        );

        if ( !defined( $num_verified ) )
        {
            if ( !$required and !defined( $num_raw ) )
            {
                $map{$name} = undef;

                _log(
                    "WARN",
                    "Optional identity call [ $name ] unavailable; \"no_new_privs\" will be skipped"
                );

                next;
            }

            return _throw_err( "Identity call name [ $name ] not a valid syscall num" );
        }

        if ( $is_arch_ok and $num_verified != $num_expected )
        {
            return _throw_err(
                "Identity call name [ $name ] does not match supported Linux abi " .
                "[Loaded: $num_verified] " .
                "[Expected: $num_expected]"
            );
        }

        $map{$name} = $num_verified;
    }

    my $status = $is_arch_ok ? "matched supported Linux ABI" : "numeric format validated";

    _log(
        "OK",
        "Identity call map prepared " .
        "[File: $sc_file] " .
        "[Validation: $status] " .
        "[Calls: " . _sc_format( \%map ) . "]"
    );

    return ( \%map, undef );
}

# #
#   Aegis › Identity › Check Is Restricted
#   
#   Make sure process uses the Messenger uid and gid.
#   Make sure it has no secondary groups or Linux perms.
#   
#   @test       Note:           Check that allowed Messenger identity fully restricted
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $zero = q{0000000000000000}; my $ids = { real => 974, effective => 974, saved => 974, filesystem => 974 }; my $state = { user_ids => $ids, group_ids => $ids, secondary_groups => [], caps => { capinh => $zero, capprm => $zero, capeff => $zero, capamb => $zero } }; my $actual = ConfigServer::Aegis::_identity_is_restricted($state, 974, 974); my $expected = 1; my $status = defined($actual) && "$actual" eq "$expected" ? "OK" : "FAILED"; my $actual_out = defined($actual) ? "$actual" : "undef"; my $meaning = $status eq "OK" ? "Identity is fully restricted" : "Identity is not fully restricted"; printf "%-12s => %-32s [%s]\n", "restricted", $actual_out, $status; printf "%-12s => %-32s [%s]\n", "meaning", $meaning, $status; printf "%-12s => %s\n", "result", $status; exit($status eq "OK" ? 0 : 1);'
#   
#               Note:           Check identity results, detailed errors, and safe fatal logging
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require Fcntl; my $all_ok = 1; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-28s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; my $zero = "0000000000000000"; my $ids_974 = { real => 974, effective => 974, saved => 974, filesystem => 974 }; my $ids_975 = { real => 975, effective => 975, saved => 975, filesystem => 975 }; my $valid = { user_ids => $ids_974, group_ids => $ids_974, secondary_groups => [], caps => { capinh => $zero, capprm => $zero, capeff => $zero, capamb => $zero } }; my $invalid_data = { user_ids => $ids_974, group_ids => $ids_974, secondary_groups => [], caps => undef }; my $wrong_ids = { user_ids => $ids_975, group_ids => $ids_974, secondary_groups => [], caps => { capinh => $zero, capprm => $zero, capeff => $zero, capamb => $zero } }; my $raw_group = 4294967294; my $secondary_groups = { user_ids => $ids_974, group_ids => $ids_974, secondary_groups => [ $raw_group ], caps => { capinh => $zero, capprm => $zero, capeff => $zero, capamb => $zero } }; my $raw_cap = "0000000000000400"; my $linux_caps = { user_ids => $ids_974, group_ids => $ids_974, secondary_groups => [], caps => { capinh => $zero, capprm => $zero, capeff => $raw_cap, capamb => $zero } }; my @cases = ( [ "valid", $valid, 1, undef ], [ "missing_identity", undef, undef, "Cannot check process perms, identity data missing or invalid" ], [ "invalid_data", $invalid_data, undef, "Cannot check process perms, identity data missing or invalid" ], [ "wrong_ids", $wrong_ids, undef, "Process uid or gid does not match the configured uid and gid" ], [ "secondary_groups", $secondary_groups, undef, "Process still belongs to secondary groups after changing from root" ], [ "linux_caps", $linux_caps, undef, "Process still has Linux caps, or its capability data is invalid" ] ); printf "%-28s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf "%s\n", "-" x 183; for my $case ( @cases ) { my ( $name, $identity, $expected_status, $expected_error ) = @{$case}; my ( $status, $error ) = ConfigServer::Aegis::_identity_is_restricted( $identity, 974, 974 ); $show->( "${name}_status", $status, $expected_status ); $show->( "${name}_error", $error, $expected_error ); } my $scalar_status = ConfigServer::Aegis::_identity_is_restricted( $valid, 974, 974 ); $show->( "scalar_status", $scalar_status, 1 ); my ( $fatal_status, $fatal_reason ) = ConfigServer::Aegis::_identity_is_restricted( $secondary_groups, 974, 974 ); my $token = "Aegis identity test [$$-" . time . "]"; my $log_path = "/var/log/lfd.log"; my $pid = fork( ); die "Cannot fork: $!\n" if !defined( $pid ); if ( $pid == 0 ) { ConfigServer::Aegis::_throw_fatal( "$token Final Messenger identity verification failed", $fatal_reason ); POSIX::_exit( 125 ); } my $waited = waitpid( $pid, 0 ); die "Cannot wait for child: $!\n" if $waited != $pid; my $child_status = $?; my $exit_status = $child_status >> 8; open( my $LOG, "<", $log_path ) or die "Cannot open $log_path: $!\n"; flock( $LOG, Fcntl::LOCK_SH( ) ) or die "Cannot lock $log_path: $!\n"; my $log_line; while ( my $line = <$LOG> ) { if ( index( $line, $token ) >= 0 ) { $log_line = $line; last; } } close( $LOG ) or die "Cannot close $log_path: $!\n"; my $reason_found = defined( $log_line ) && index( $log_line, $fatal_reason ) >= 0 ? "yes" : "no"; my $group_hidden = defined( $log_line ) && index( $log_line, "$raw_group" ) < 0 ? "yes" : "no"; my $cap_hidden = defined( $log_line ) && index( $log_line, $raw_cap ) < 0 ? "yes" : "no"; $show->( "fatal_exit_status", $exit_status, 126 ); $show->( "fatal_log_path", $log_path, "/var/log/lfd.log" ); $show->( "fatal_reason_found", $reason_found, "yes" ); $show->( "raw_group_hidden", $group_hidden, "yes" ); $show->( "raw_cap_hidden", $cap_hidden, "yes" ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     ident           hashref     Process identity
#               uid             int         Messenger uid
#               gid             int         Messenger gid
#   @return     status          int|undef   Identity check result
#                                               1           Passed
#                                               undef       Failed
#               error           str|undef   Safe failure reason in list context
# #

sub _identity_is_restricted
{
    my ( $ident, $uid, $gid ) = @_;

    _log( "DEBUG", "Checking process uid, gid, secondary groups, and caps" );

    if ( ref( $ident ) ne 'HASH' )
    {
        my $reason = "Cannot check process perms, identity data missing or invalid";
        _log( "FAIL", $reason );

        return wantarray ? ( undef, $reason ) : undef;
    }

    my $user_ids            = $ident->{user_ids};
    my $group_ids           = $ident->{group_ids};
    my $groups_secondary    = $ident->{secondary_groups};
    my $cap_sets            = $ident->{caps};

    if (
        ref( $user_ids ) ne 'HASH'
        or ref( $group_ids ) ne 'HASH'
        or ref( $groups_secondary ) ne 'ARRAY'
        or ref( $cap_sets ) ne 'HASH'
    )
    {
        my $reason = "Cannot check process perms, identity data missing or invalid";
        _log( "FAIL", $reason );

        return wantarray ? ( undef, $reason ) : undef;
    }

    # #
    #   Return 1:           every $user_ids = $uid
    #                       every $group_ids = $gid
    # #

    my $uid_is_restricted = _is_ids_match( $user_ids, $uid );
    my $gid_is_restricted = _is_ids_match( $group_ids, $gid );

    if ( !$uid_is_restricted or !$gid_is_restricted )
    {
        my $reason = "Process uid or gid does not match the configured uid and gid";
        _log( "FAIL", $reason );

        return wantarray ? ( undef, $reason ) : undef;
    }

    if ( @{$groups_secondary} )
    {
        my $reason = "Process still belongs to secondary groups after changing from root";
        _log( "FAIL", $reason );

        return wantarray ? ( undef, $reason ) : undef;
    }

    # #
    #   $is_caps_clear defines if process has any Linux special
    #   perms left.
    #   
    #   Eg:     0 (not clear)   capeff => "0000000000000400"
    #                           required cap missing, invalid, or nonzero.
    #   
    #           1 (clear)       capeff => "0000000000000000"
    #                           every required cap exists and has
    #                               only zeros.
    # #

    my $is_caps_clear = !grep
    {
        my $map_key         = $_->{map_key};
        my $required        = $_->{required};

        my $field_exists    = exists( $cap_sets->{$map_key} );
        my $value           = $field_exists ? $cap_sets->{$map_key} : undef;

        ( $required and !$field_exists ) or ( $field_exists and ( !defined( $value ) or ref( $value ) or $value !~ /\A0+\z/ ) );
    } @CAPABILITY_FIELDS;

    if ( !$is_caps_clear )
    {
        my $reason = "Process still has Linux caps, or its capability data is invalid";
        _log( "FAIL", $reason );

        return wantarray ? ( undef, $reason ) : undef;
    }

    _log( "OK", "Process uid and gid match; no secondary groups or special perms remain" );

    return wantarray ? ( 1, undef ) : 1;
}

# #
#   Aegis › Identity › Verify/Check Starting Root IDs
#   
#   Make sure every process uid and gid is root id 0.
#   
#   @test       Note:           Verify current process has all uid / gid set to root
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my $show = sub { my ($name, $actual, $expected) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $expected_out = defined($expected) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-12s => %-12s [%s]\n", $name, $actual_out, $status; }; my ($status, $error) = ConfigServer::Aegis::_identity_verify_root_ids(); $show->("status", $status, 1); $show->("error", $error, undef); printf "%-12s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#               Note:           Test non root uid, gid, mixed IDs, and failures
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'no warnings qw(redefine prototype); my $all_ok = 1; my $show = sub { my ($name, $actual, $expected) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $expected_out = defined($expected) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-22s => %-112s [%s]\n", $name, $actual_out, $status; }; my $root_error = "Cannot remove root perms: process uid and gid values are not all root (0)"; my $root_ids = { real => 0, effective => 0, saved => 0, filesystem => 0 }; my $user_ids = { real => 1001, effective => 1001, saved => 1001, filesystem => 1001 }; my @cases = (["uid_not_root", { user_ids => $user_ids, group_ids => $root_ids }], ["gid_not_root", { user_ids => $root_ids, group_ids => $user_ids }], ["uid_mixed", { user_ids => { real => 0, effective => 0, saved => 1001, filesystem => 0 }, group_ids => $root_ids }], ["gid_mixed", { user_ids => $root_ids, group_ids => { real => 0, effective => 0, saved => 0, filesystem => 1001 } }]); for my $case (@cases) { my ($name, $identity) = @{$case}; my ($case_status, $case_error); { local *ConfigServer::Aegis::identity_read = sub { return ($identity, undef); }; ($case_status, $case_error) = ConfigServer::Aegis::_identity_verify_root_ids(); } $show->("${name}_status", $case_status, undef); $show->("${name}_error", $case_error, $root_error); } my ($read_status, $read_error); { local *ConfigServer::Aegis::identity_read = sub { return (undef, "Forced identity read failure"); }; ($read_status, $read_error) = ConfigServer::Aegis::_identity_verify_root_ids(); } $show->("read_failure_status", $read_status, undef); $show->("read_failure_error", $read_error, "Forced identity read failure"); printf "%-22s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#   @params     void
#   @return     status          int|undef   Root id check result
#                                               1           Process started as root
#                                               undef       Check failed
#               error           str|undef   Failure reason
# #

sub _identity_verify_root_ids
{
    my ( $identity, $identity_err ) = identity_read( );

    return ( undef, $identity_err )
        if !$identity;

    return _throw_err( "Cannot remove root perms: process uid and gid values are not all root (0)" )
        if !_is_ids_match( $identity->{user_ids}, 0 ) or !_is_ids_match( $identity->{group_ids}, 0 );

    _log( "OK", "Process started with all uid and gid values set to root (0)" );

    return ( 1, undef );
}

# #
#   Aegis › Identity › Read Process IDs
#   
#   Read process ids, secondary groups, and Linux perms.
#   
#   @test       Note:           Read and validate the current process identity
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'my $all_ok = 1; my $show = sub { my ($name, $actual, $passed) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $status = $passed ? "OK" : "FAILED"; $all_ok = 0 if !$passed; printf "%-16s => %-40s [%s]\n", $name, $actual_out, $status; }; my ($identity, $error) = ConfigServer::Aegis::identity_read(); my $identity_type = ref($identity) || "undef"; $show->("identity_type", $identity_type, $identity_type eq "HASH"); $show->("error", $error, !defined($error)); my $uid_out = ref($identity) eq "HASH" && ref($identity->{user_ids}) eq "HASH" ? join(":", @{$identity->{user_ids}}{qw(real effective saved filesystem)}) : undef; my $gid_out = ref($identity) eq "HASH" && ref($identity->{group_ids}) eq "HASH" ? join(":", @{$identity->{group_ids}}{qw(real effective saved filesystem)}) : undef; $show->("uid", $uid_out, defined($uid_out) && $uid_out eq "0:0:0:0"); $show->("gid", $gid_out, defined($gid_out) && $gid_out eq "0:0:0:0"); my $groups = ref($identity) eq "HASH" ? $identity->{secondary_groups} : undef; my $groups_type = ref($groups) || "undef"; my $groups_out = ref($groups) eq "ARRAY" ? (@{$groups} ? join(",", @{$groups}) : "none") : undef; my $groups_ok = ref($groups) eq "ARRAY" && !grep { !defined($_) || ref($_) || $_ !~ /\A[0-9]+\z/ } @{$groups}; $show->("groups_type", $groups_type, $groups_type eq "ARRAY"); $show->("groups", $groups_out, $groups_ok); my $caps = ref($identity) eq "HASH" ? $identity->{caps} : undef; my $caps_type = ref($caps) || "undef"; $show->("caps_type", $caps_type, $caps_type eq "HASH"); for my $key (qw(capinh capprm capeff)) { my $value = ref($caps) eq "HASH" ? $caps->{$key} : undef; my $valid = defined($value) && !ref($value) && $value =~ /\A[0-9a-f]+\z/; $show->($key, $value, $valid); } my $capamb = ref($caps) eq "HASH" && exists($caps->{capamb}) ? $caps->{capamb} : "unavailable"; my $capamb_ok = $capamb eq "unavailable" || (!ref($capamb) && $capamb =~ /\A[0-9a-f]+\z/); $show->("capamb", $capamb, $capamb_ok); printf "%-16s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#   @test       Note:           Test every process identity read failure
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'no warnings qw(redefine prototype); my $all_ok = 1; my $show = sub { my ($name, $actual, $expected) = @_; my $actual_out = defined($actual) ? "$actual" : "undef"; my $expected_out = defined($expected) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-22s => %-96s [%s]\n", $name, $actual_out, $status; }; my @cases = (["status", "forced status failure", "Unable to read current process info: forced status failure"], ["uid", "forced uid failure", "Unable to read process user ids: forced uid failure"], ["gid", "forced gid failure", "Unable to read process group ids: forced gid failure"], ["groups", "forced group failure", "Unable to read process secondary groups: forced group failure"], ["capabilities", "forced capability failure", "Unable to read process Linux caps: forced capability failure"]); for my $case (@cases) { my ($name, $forced_error, $expected_error) = @{$case}; my ($identity, $error); { local *ConfigServer::Aegis::_read_procstatus_load = sub { return $name eq "status" ? (undef, $forced_error) : ("status", undef); }; local *ConfigServer::Aegis::_parse_id_field = sub { my ($text, $field) = @_; return (undef, $forced_error) if lc($field) eq $name; return ([ 0, 0, 0, 0 ], undef); }; local *ConfigServer::Aegis::_parse_groups = sub { return $name eq "groups" ? (undef, $forced_error) : ([], undef); }; local *ConfigServer::Aegis::_parse_capabilities = sub { return $name eq "capabilities" ? (undef, $forced_error) : ({ capinh => "0", capprm => "0", capeff => "0", capamb => "0" }, undef); }; ($identity, $error) = ConfigServer::Aegis::identity_read(); } $show->("${name}_identity", $identity, undef); $show->("${name}_error", $error, $expected_error); } printf "%-22s => %s\n", "result", ($all_ok ? "OK" : "FAILED"); exit($all_ok ? 0 : 1);'
#   
#   @params     void
#   @return     identity        hashref|undef   Process identity
#               error           str|undef       Failure reason
# #

sub identity_read
{
    _log( "DEBUG", "Reading current process user, group, and perm info" );

    my ( $status, $status_err ) = _read_procstatus_load( );
    return _throw_err( "Unable to read current process info", $status_err )
        if !defined( $status );

    # #
    #   Output:         '$uid' => [ 0, 0, 0, 0 ]
    #   Format:         '$uid' => [ real uid | effective uid | saved uid | filesystem uid ]
    # #

    my ( $uid, $uid_err ) = _parse_id_field( $status, "Uid" );
    return _throw_err( "Unable to read process user ids", $uid_err )
        if !$uid;

    # #
    #   Output:         '$gid' => [ 0, 0, 0, 0 ]
    #   Format:         '$gid' => [ real gid | effective gid | saved gid | filesystem gid ]
    # #

    my ( $gid, $gid_err ) = _parse_id_field( $status, "Gid" );
    return _throw_err( "Unable to read process group ids", $gid_err )
        if !$gid;

    # #
    #   Output:         '$groups' => [ 0, 980 ]
    #   (Eg) Get Name:  getent group 980
    # #

    my ( $groups, $group_err ) = _parse_groups( $status );
    return _throw_err( "Unable to read process secondary groups", $group_err )
        if !$groups;

    # #
    #   Output:         '$caps' => { 'capinh' => '0000000000000000', 'capeff' => '000001ffffffffff', 'capprm' => '000001ffffffffff', 'capamb' => '0000000000000000' }
    # #

    my ( $caps, $caps_err ) = _parse_capabilities( $status );
    return _throw_err( "Unable to read process Linux caps", $caps_err )
        if !$caps;

    my $user_ids =
    {
        real        => $uid->[ 0 ],
        effective   => $uid->[ 1 ],
        saved       => $uid->[ 2 ],
        filesystem  => $uid->[ 3 ],
    };

    my $group_ids =
    {
        real        => $gid->[ 0 ],
        effective   => $gid->[ 1 ],
        saved       => $gid->[ 2 ],
        filesystem  => $gid->[ 3 ],
    };

    my $capamb_log = defined( $caps->{capamb} ) ? $caps->{capamb} : "unavailable";

    _log(
        "OK",
        "Process identity read successfully " .
        "[User IDs: " . join( ":", @{$uid} ) . "] " .
        "[Group IDs: " . join( ":", @{$gid} ) . "] " .
        "[Secondary Groups: " . ( @{$groups} ? join( ",", @{$groups} ) : "none" ) . "] " .
        "[perms(capinh): $caps->{capinh}] " .
        "[perms(capprm): $caps->{capprm}] " .
        "[perms(capeff): $caps->{capeff}] " .
        "[perms(capamb): $capamb_log]"
    );

    # #
    #   @return     {
    #                   'user_ids' => {
    #                       'real'          => 974,
    #                       'effective'     => 974,
    #                       'saved'         => 974,
    #                       'filesystem'    => 974
    #                   },
    #                   'group_ids' => {
    #                       'real'          => 974,
    #                       'effective'     => 974,
    #                       'saved'         => 974,
    #                       'filesystem'    => 974
    #                   },
    #                   'secondary_groups' => [],
    #                   'caps' => {
    #                       'capamb'  => '0000000000000000',
    #                       'capprm'  => '0000000000000000',
    #                       'capinh'  => '0000000000000000',
    #                       'capeff'  => '0000000000000000'
    #                   }
    #               };
    # #

    return (
    {
        user_ids            => $user_ids,
        group_ids           => $group_ids,
        secondary_groups    => $groups,
        caps                => $caps,
    }, undef );
}

# #
#   Aegis › Identity › Restrict (Drop Root)
#   
#   Change process from root to MESSENGER_USER uid and gid.
#   Make sure Messenger process can't get root back again.
#   
#   @test       Note:           Restrict temp Perl process to Messenger uid and gid
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require POSIX; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf "%-24s => %-32s [%s]\n", $name, $actual_out, $status; }; my $user = "csf"; my ( undef, undef, $uid, $gid ) = getpwnam( $user ); my $account_valid = defined( $uid ) && !ref( $uid ) && $uid =~ /\A[0-9]+\z/ && $uid > 0 && defined( $gid ) && !ref( $gid ) && $gid =~ /\A[0-9]+\z/ && $gid > 0; $show->( "test_account", $account_valid ? "valid" : "invalid", "valid" ); if ( !$account_valid ) { printf "%-24s => %s\n", "result", "FAILED"; exit 1; } printf "%-24s => %s\n", "target_ids", "$uid:$gid"; my $starting_ids = join( ":", POSIX::getuid( ), POSIX::geteuid( ), POSIX::getgid( ), POSIX::getegid( ) ); $show->( "starting_ids", $starting_ids, "0:0:0:0" ); my ( $status, $error ) = ConfigServer::Aegis::identity_cage( $uid, $gid ); my $real_ids = POSIX::getuid( ) . ":" . POSIX::getgid( ); my $effective_ids = POSIX::geteuid( ) . ":" . POSIX::getegid( ); $show->( "cage_status", $status, 1 ); $show->( "cage_error", $error, undef ); $show->( "real_ids", $real_ids, "$uid:$gid" ); $show->( "effective_ids", $effective_ids, "$uid:$gid" ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); printf "%-24s => %s\n", "result", ( $all_ok ? "OK" : "FAILED" ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     _uid            scalar      Messenger uid
#               _gid            scalar      Messenger gid
#   @return     status          int|undef   Change result
#                                               1           Changed
#                                               undef       Failed before ident changes
#               error           str|undef   Failure reason
#   @exit       status          int         Fatal failure after ident changes begin
#                                               126         Process stopped
# #

sub identity_cage
{
    my ( $_uid, $_gid ) = @_;

    my ( $target, $target_err ) = _identity_prepare( $_uid, $_gid );
    return ( undef, $target_err )
        if !$target;

    my ( $thread_single, $thread_err ) = _verify_single_threaded_process( );
    return ( undef, $thread_err )
        if !$thread_single;

    my ( $root_is_verified, $root_err ) = _identity_verify_root_ids( );
    return ( undef, $root_err )
        if !$root_is_verified;

    # #
    #   $calls = {
    #       'prctl'     => 157,
    #       'setgroups' => 116,
    #       'setresgid' => 119,
    #       'setresuid' => 117
    #   }
    #   $groups_cleared     1
    # #

    my ( $calls, $call_err ) = _identity_map_prepare( );
    return ( undef, $call_err )
        if !$calls;

    my ( $signals_prev, $signals_prev_err ) = _identity_signals_block( );
    return ( undef, $signals_prev_err )
        if !$signals_prev;

    my ( $groups_cleared, $group_err ) = _identity_groups_clear( $calls );
    if ( !$groups_cleared )
    {
        my ( $signals_restored, $signals_restored_err ) = _identity_signals_restore( $signals_prev );
        _throw_fatal( $signals_restored_err )
            if !$signals_restored;

        return ( undef, $group_err );
    }

    # #
    #   Any failure from this point is fatal. Process may have
    #   entered a partially restricted ident that must never use.
    # #

    my ( $no_new_privs, $no_new_privs_err ) = _no_new_privs_enable( $calls );
    _throw_fatal(
        MODULE_NAME . " could not prevent the process from gaining new privileges during exec",
        $no_new_privs_err,
    ) if !defined( $no_new_privs );

    _set_gid( $calls, $target->{gid} );
    _set_uid( $calls, $target->{uid}, $target->{gid} );

    if ( $no_new_privs )
    {
        my ( $nnp_read, $nnp_read_err ) = _no_new_privs_read( $calls );
        _throw_fatal(
            MODULE_NAME . " could not verify \"no_new_privs\" after restricting the process identity",
            $nnp_read_err,
        ) if !defined( $nnp_read ) or $nnp_read != 1;

        _log( "OK", MODULE_NAME . " confirmed Linux \"no_new_privs\" remained enabled after identity restriction" );
    }

    _root_regain_verify(
        $calls,
        $target->{uid},
        $target->{gid},
    );

    my ( $signals_restored, $signals_restored_err ) = _identity_signals_restore( $signals_prev );
    _throw_fatal( $signals_restored_err )
        if !$signals_restored;

    _log(
        "OK",
        MODULE_NAME . " confirmed the process is running as the configured uid and gid; cannot " .
        "regain root perms [UID: $target->{uid} | GID: $target->{gid}]"
    );

    return ( 1, undef );
}

# #
#   Messenger Aegis > Initialize
#
#   Setup Messenger module accepting connections.
#   
#   Only keep files and security that Messenger needs. Change
#   Messenger's uid and gid to MESSENGER_USER setting in 
#   /etc/csf/csf.conf.
#   
#   @test       Note:           Test invalid ids, run real Messenger initialization
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Aegis -e 'require Fcntl; require POSIX; my $all_ok = 1; my @warnings; local $SIG{__WARN__} = sub { push( @warnings, @_ ); }; open( my $report_fh, ">&", \*STDOUT ) or die "Cannot duplicate STDOUT: $!\n"; my $selected_fh = select( $report_fh ); $| = 1; select( $selected_fh ); my $show = sub { my ( $name, $actual, $expected ) = @_; my $actual_out = defined( $actual ) ? "$actual" : "undef"; my $expected_out = defined( $expected ) ? "$expected" : "undef"; my $status = $actual_out eq $expected_out ? "OK" : "FAILED"; $all_ok = 0 if $status eq "FAILED"; printf {$report_fh} "%-24s | %-70s | %-70s | %s\n", $name, $actual_out, $expected_out, $status; }; printf {$report_fh} "%-24s | %-70s | %-70s | %s\n", "test", "actual", "expected", "status"; printf {$report_fh} "%s\n", "-" x 179; my $user = "csf"; my ( undef, undef, $uid, $gid ) = getpwnam( $user ); my $account_valid = defined( $uid ) && !ref( $uid ) && $uid =~ /\A[0-9]+\z/ && $uid > 0 && defined( $gid ) && !ref( $gid ) && $gid =~ /\A[0-9]+\z/ && $gid > 0; $show->( "test_account", $account_valid ? "$user ($uid:$gid)" : "invalid", $account_valid ? "$user ($uid:$gid)" : "valid account" ); if ( !$account_valid ) { printf {$report_fh} "%-24s => %s\n", "result", "FAILED"; close( $report_fh ); exit 1; } my $invalid_error = "uid and gid must be within the Linux id range [1 - " . ConfigServer::Aegis::ID_VALUE_MAX( ) . "]"; my @invalid_cases = ( [ "missing_uid", undef, $gid ], [ "missing_gid", $uid, undef ], [ "root_uid", 0, $gid ], [ "root_gid", $uid, 0 ], [ "text_uid", "invalid", $gid ], [ "text_gid", $uid, "invalid" ], [ "ref_uid", [], $gid ], [ "ref_gid", $uid, [] ] ); for my $case ( @invalid_cases ) { my ( $name, $case_uid, $case_gid ) = @{$case}; my ( $case_status, $case_error ) = ConfigServer::Aegis::initialize( $case_uid, $case_gid, $report_fh ); $show->( "${name}_status", $case_status, undef ); $show->( "${name}_error", $case_error, $invalid_error ); } my $starting_ids = join( ":", POSIX::getuid( ), POSIX::geteuid( ), POSIX::getgid( ), POSIX::getegid( ) ); $show->( "starting_ids", $starting_ids, "0:0:0:0" ); my $extra_fd = POSIX::open( "/dev/null", Fcntl::O_RDONLY( ) ); die "Cannot open extra test fd: $!\n" if !defined( $extra_fd ) or $extra_fd < 0; my $report_fd = fileno( $report_fh ); my ( $status, $error ) = ConfigServer::Aegis::initialize( $uid, $gid, $report_fh ); $show->( "initialize_status", $status, 1 ); $show->( "initialize_error", $error, undef ); my ( $identity, $identity_error ) = ConfigServer::Aegis::identity_read( ); $show->( "identity_type", ref( $identity ) || "undef", "HASH" ); $show->( "identity_error", $identity_error, undef ); my $uid_out = ref( $identity ) eq "HASH" && ref( $identity->{user_ids} ) eq "HASH" ? join( ":", @{$identity->{user_ids}}{qw( real effective saved filesystem )} ) : undef; my $gid_out = ref( $identity ) eq "HASH" && ref( $identity->{group_ids} ) eq "HASH" ? join( ":", @{$identity->{group_ids}}{qw( real effective saved filesystem )} ) : undef; $show->( "user_ids", $uid_out, join( ":", ( $uid ) x 4 ) ); $show->( "group_ids", $gid_out, join( ":", ( $gid ) x 4 ) ); my $groups = ref( $identity ) eq "HASH" ? $identity->{secondary_groups} : undef; my $groups_out = ref( $groups ) eq "ARRAY" && !@{$groups} ? "none" : "present or invalid"; $show->( "extra_groups", $groups_out, "none" ); my $caps = ref( $identity ) eq "HASH" ? $identity->{caps} : undef; my $required_caps_clear = ref( $caps ) eq "HASH" && !( grep { !exists( $caps->{$_} ) || !defined( $caps->{$_} ) || ref( $caps->{$_} ) || $caps->{$_} !~ /\A0+\z/ } qw( capinh capprm capeff ) ); my $ambient_cap_clear = ref( $caps ) eq "HASH" && ( !exists( $caps->{capamb} ) || ( defined( $caps->{capamb} ) && !ref( $caps->{capamb} ) && $caps->{capamb} =~ /\A0+\z/ ) ); $show->( "linux_permissions", $required_caps_clear && $ambient_cap_clear ? "none" : "present or invalid", "none" ); my $real_ids = POSIX::getuid( ) . ":" . POSIX::getgid( ); my $effective_ids = POSIX::geteuid( ) . ":" . POSIX::getegid( ); $show->( "real_ids", $real_ids, "$uid:$gid" ); $show->( "effective_ids", $effective_ids, "$uid:$gid" ); my $report_state = defined( fileno( $report_fh ) ) ? "open" : "closed"; my $extra_state = lstat( ConfigServer::Aegis::PROC_FD_PATH( ) . "/$extra_fd" ) ? "open" : "closed"; $show->( "kept_fd", "$report_fd ($report_state)", "$report_fd (open)" ); $show->( "unlisted_fd", "$extra_fd ($extra_state)", "$extra_fd (closed)" ); my $proc_fd_path = ConfigServer::Aegis::PROC_FD_PATH( ); $show->( "stdin_target", readlink( "$proc_fd_path/0" ), "/dev/null" ); $show->( "stdout_target", readlink( "$proc_fd_path/1" ), "/dev/null" ); $show->( "stderr_target", readlink( "$proc_fd_path/2" ), "/dev/null" ); my $warnings_out = @warnings ? join( "", @warnings ) : "none"; $warnings_out =~ s/\s+\z//; $show->( "warnings", $warnings_out, "none" ); $show->( "complete", $all_ok ? "OK" : "FAILED", "OK" ); close( $report_fh ); exit( $all_ok ? 0 : 1 );'
#   
#   @params     _uid            scalar      Messenger uid
#               _gid            scalar      Messenger gid
#               fhs_keep        list        Open files or connections to keep
#
#   @return     status          int|undef   Setup result
#                                               1           Setup completed
#                                               undef       Setup did not start
#               error           str|undef   Reason setup did not start
#   @exit       status          int         Fatal failure after init Aegis setup begins
#                                               126         Process stopped
# #

sub initialize
{
    my ( $_uid, $_gid, @fhs_keep ) = @_;

    my ( $target, $target_err ) = _identity_prepare( $_uid, $_gid );
    return ( undef, $target_err )
        if !$target;

    my ( $thread_single, $thread_err ) = _verify_single_threaded_process( );
    return ( undef, $thread_err )
        if !$thread_single;

    my ( $root_is_verified, $root_err ) = _identity_verify_root_ids( );
    return ( undef, $root_err )
        if !$root_is_verified;

    my ( $signals_prev, $signals_prev_err ) = _identity_signals_block( );
    return ( undef, $signals_prev_err )
        if !$signals_prev;

    my ( $fds_caged, $fds_caged_err ) = fds_cage( @fhs_keep );
    _throw_fatal( MODULE_NAME . " initialization failed during fd isolation", $fds_caged_err ) if !$fds_caged;

    my ( $ident_caged, $ident_caged_err ) = identity_cage(
        $target->{uid},
        $target->{gid},
    );

    _throw_fatal( MODULE_NAME . " initialization failed during identity restriction", $ident_caged_err )
        if !$ident_caged;

    my ( $identity, $identity_err ) = identity_read( );
    _throw_fatal( MODULE_NAME . " initialization failed during identity read", $identity_err )
        if !$identity;

    my ( $identity_is_restricted, $identity_restricted_err ) = _identity_is_restricted(
        $identity,
        $target->{uid},
        $target->{gid},
    );

    _throw_fatal(
        MODULE_NAME . " initialization failed during identity verification",
        $identity_restricted_err,
    ) if !$identity_is_restricted;

    my ( $thread_final, $thread_final_err ) = _verify_single_threaded_process( );
    _throw_fatal( MODULE_NAME . " initialization failed during thread verification", $thread_final_err )
        if !$thread_final;

    my ( $signals_restored, $signals_restored_err ) = _identity_signals_restore( $signals_prev );
    _throw_fatal( MODULE_NAME . " initialization failed during signal restoration", $signals_restored_err )
        if !$signals_restored;

    _log(
        "OK",
        MODULE_NAME . " initialization completed and verified " .
        "[UID: $target->{uid} | GID: $target->{gid}]"
    );

    return ( 1, undef );
}

1;
