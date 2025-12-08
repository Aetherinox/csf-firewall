#!/usr/bin/perl
# #
#   @app                ConfigServer Firewall & Security (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.dev
#   @docs               https://docs.configserver.dev
#   @download           https://download.configserver.dev
#   @repo               https://github.com/Aetherinox/csf-firewall
#   @copyright          Copyright (C) 2025-2026 Aetherinox
#                       Copyright (C) 2006-2025 Jonathan Michaelson
#                       Copyright (C) 2006-2025 Way to the Web Ltd.
#   @license            GPLv3
#   @updated            12.08.2025
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
#   ConfigServer and Firewall › CSGet
#   
#   Script runs as a cron in:
#       /etc/cron.daily/csget
#       
#   By default, the script sleeps for a random number of seconds in
#   fork/daemon mode:
#       0 - 6 hours (rand(60*60*6) = up to 21600 seconds)
#       
#   After sleep, it connects to CSF api and gets the current ver of CSF:
#       https://download.configserver.dev/csf/version.txt
#       https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/api/templates/versions/csf/version.txt
#       
#   After latest version is fetched from @downloadserver, a file is created in:
#       /var/lib/configserver/csf.txt
#   With contents like:
#       15.08
#       
#   If you run the script with the cmd below; a process is created with a random
#   duration between 0-6 hours.
#       sudo perl /etc/cron.daily/csget
#   
#   You can search for active copies of the process with:
#       ps aux | grep Config
#       root     3830870  0.0  0.1  22280  8980 ?        S    15:41   0:00 ConfigServer Version Check
#       sudo kill -9 3830870
#       
#   If you run the command below; action will immediately start with no lingering process:
#       sudo perl -d:Trace /etc/cron.daily/csget --nosleep
#   All output will be logged to:
#       /var/log/csf/csget_daemon.log
#   
#   Requires:
#       DEBIAN/UBUNTU               sudo apt update
#                                   sudo apt install libdevel-trace-perl
#       REDHAT                      sudo yum makecache
#                                   sudo dnf install perl-Devel-Trace
#       
#   If you run the script using the cmd below; Action will trigger, 
#   create a child process, and wait 0–6 hours
#       sudo perl -d:Trace /etc/cron.daily/csget --debug
#   Logging will be sent to
#       /var/log/csf/csget_debug.log
#       
#   This script contains two log files:
#       /var/log/csf/csget_daemon.log     logs to this file if --debug mode DISABLED
#       /var/log/csf/csget_debug.log      logs to this file if --debug mode ENABLED
#   
#   @usage      sudo perl /etc/cron.daily/csget
#                   Runs the script normally, no extra warnings, no debugging.
#                   If the script forks (daemonizes), the parent exits normally.
#                   STDOUT/STDERR behavior depends on the script (e.g., closed in fork).
#       
#               sudo perl -w /etc/cron.daily/csget
#                   Enables warnings (-w flag) for uninitialized variables, deprecated
#                   features, or risky operations. Otherwise behaves like plain Perl.
#                   Fork/daemon behavior and STDOUT/STDERR unchanged (aside from warnings).
#       
#               sudo perl -d /etc/cron.daily/csget
#                   Runs the Perl debugger (-d). Stops at the first line and waits for
#                   debugger commands (n=next, c=continue). Can step through lines,
#                   inspect variables, set breakpoints, etc.
#                   Note: If the script forks, child processes won't have the debugger
#                   attached. Script behavior differs from normal run.
#       
#               sudo perl -d:Trace /etc/cron.daily/csget
#                   Special debugger module: Trace. Prints every line executed in real
#                   time. Useful for line-by-line debugging. Fork/daemonization can behave
#                   differently. Script may exit immediately or behave oddly as the
#                   debugger controls STDOUT/STDERR for trace output.
#       
#               Process can be killed with:
#                   ps aux | grep csget
#                   sudo pkill -9 -f "sudo perl -w /etc/cron.daily/csget"
# #

use strict;
use warnings;

# #
#   ANSI Colors
# #

my $ESC             = "\e";
my $END             = "${ESC}[0m";

# #
#   Colors › Standard Foreground
# #

my $BLACK           = "${ESC}[30m";
my $RED             = "${ESC}[31m";
my $GREEN           = "${ESC}[32m";
my $YELLOW          = "${ESC}[33m";
my $BLUE            = "${ESC}[34m";
my $MAGENTA         = "${ESC}[35m";
my $CYAN            = "${ESC}[36m";
my $WHITE           = "${ESC}[37m";                     # correct standard white
my $GREY_DARK       = "${ESC}[90m";                     # bright black (dark gray)
my $GREY_MEDIUM     = "${ESC}[37m";                     # standard white = medium grey
my $GREY_LIGHT      = "${ESC}[97m";                     # bright white (light grey)

# #
#   Colors › Bright Foreground
# #

my $BRIGHT_BLACK    = "${ESC}[90m";                     # dark gray
my $BRIGHT_RED      = "${ESC}[91m";
my $BRIGHT_GREEN    = "${ESC}[92m";
my $BRIGHT_YELLOW   = "${ESC}[93m";
my $BRIGHT_BLUE     = "${ESC}[94m";
my $BRIGHT_MAGENTA  = "${ESC}[95m";
my $BRIGHT_CYAN     = "${ESC}[96m";
my $BRIGHT_WHITE    = "${ESC}[97m";                     # light grey / nearly white

# #
#   Colors › Background Styles (256-color)
# #

my $bgVerbose       = "${ESC}[1;38;5;15;48;5;125m";     # white on purple
my $bgDebug         = "${ESC}[1;38;5;15;48;5;237m";     # white on dark grey
my $bgInfo          = "${ESC}[1;38;5;15;48;5;27m";      # white on blue
my $bgOk            = "${ESC}[1;38;5;15;48;5;64m";      # white on green
my $bgWarn          = "${ESC}[1;38;5;16;48;5;214m";     # black on orange/yellow
my $bgDanger        = "${ESC}[1;38;5;15;48;5;202m";     # white on orange-red
my $bgError         = "${ESC}[1;38;5;15;48;5;160m";     # white on red

# #
#   Define › Debug
#   
#   0 = normal mode		    no logging, enables daemonization/fork block; logs to /var/log/csf/csget_daemon.log
#   1 = debug mode		    sets logging, disables daemonization/fork block; logs to /var/log/csf/csget_debug.log
# #

our $DEBUG = 0;

# #
#   Define › Nosleep
#   
#   0 = disable		        condition is true › script sleeps.
#   1 = enable		        condition is false › script runs immediately.
# #

my $NOSLEEP = 0;

# #
#   Define › Log Paths
# #

our $log_dir        = '/var/log/csf';
our $log_debug      = "$log_dir/csget_debug.log";
our $log_daemon     = "$log_dir/csget_daemon.log";
our $proc_title     = "CSF CSGET Perl Updater";
our $proc_desc      = "A perl script which allows for automated update checks for the official CSF servers.";
our $proc_url       = "https://github.com/Aetherinox/csf-firewall";
our $proc_name      = "ConfigServer Version Check";
our $dbg;
my %versions;
my $cmd;
my $GET;
my %configValues;
my $configFile      = "/etc/csf/csf.conf";
my $method          = "none";
my $status          = 0;

# #
#   Declare › Diagnostics Module
#   
#   On development servers, install module with
#       sudo dnf install perl-Diagnostics           # RHEL/AlmaLinux
#           OR
#       sudo apt install libdiagnostics-perl        # Debian/Ubuntu
# #

eval
{
    require diagnostics;
    diagnostics->import();
};
if ( $@ )
{
    print "\n" if $DEBUG;
    warn "  ${BRIGHT_YELLOW}Diagnostics${BRIGHT_RED} perl module not found; continuing without it. You can install this perl module using the commands:${END}\n" if $DEBUG;
    warn "      ${GREY_DARK}sudo dnf install perl-Diagnostics${END}\n" if $DEBUG;
    warn "      ${GREY_DARK}sudo apt install libdiagnostics-perl${END}\n" if $DEBUG;
    print "\n" if $DEBUG;
}

# #
#   Declare › Download Servers & Structure
#   
#   https://download.configserver.dev
#       csf
#           changelog.txt
#           install.txt
#           license.txt
#           readme.txt
#           version.txt
#   
#   https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/api/templates/versions
#       csf
#           changelog.txt
#           install.txt
#           license.txt
#           readme.txt
#           version.txt
# #

my @downloadservers = (
        "https://download.configserver.dev"
    #   "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/api/templates/versions"
);

# #
#   Declare › Fetch Types
#   
#   Map available fetch tools to their command templates
# #

my %fetch = (
    curl => "/usr/bin/curl -skLf -m 120 -o",
    wget => "/usr/bin/wget -q -T 120 -O",
    get  => "/usr/bin/GET -t 120"
);

# #
#   Define › Source Version File
#   
#   Get Version Info
#       csf             ConfigServer and Firewall                   Free
#       cmm             ConfigServer Mail Manage                    Free
#       cse             ConfigServer Explorer                       Free
#       cmq             ConfigServer Mail Queues                    Free
#       cmc             ConfigServer Modsecurity Control            Free
#       cxs             ConfigServer Exploit Scanner                Commercial
#       osm             Outgoing Spam Monitor                       Commercial
#       msfe            MailScanner Front-End                       Commercial
# #

if ( -e "/etc/csf/csf.pl" )
{
	$versions{ "/csf/version.txt" } = "/var/lib/configserver/csf.txt"
}

if ( -e "/etc/cxs/cxs.pl" )
{
	$versions{ "/cxs/version.txt" } = "/var/lib/configserver/cxs.txt"
}

if ( -e "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm.cgi" )
{
	$versions{ "/cmm/cmmversion.txt" } = "/var/lib/configserver/cmm.txt"
}

if ( -e "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cse.cgi" )
{
	$versions{ "/cse/cseversion.txt" } = "/var/lib/configserver/cse.txt"
}

if ( -e "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmq.cgi" )
{
	$versions{ "/cmq/cmqversion.txt" } = "/var/lib/configserver/cmq.txt"
}

if ( -e "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc.cgi" )
{
	$versions{ "/cmc/cmcversion.txt" } = "/var/lib/configserver/cmc.txt"
}

if ( -e "/etc/osm/osmd.pl" )
{
	$versions{ "/osm/osmversion.txt" } = "/var/lib/configserver/osm.txt"
}

if ( -e "/usr/msfe/version.txt" )
{
	$versions{ "/version.txt" } = "/var/lib/configserver/msinstall.txt"
}

if ( -e "/usr/msfe/msfeversion.txt" )
{
	$versions{ "/msfeversion.txt" } = "/var/lib/configserver/msfe.txt"
}

# #
#   Define › Process Name
#   
#   ps aux | grep perl
#   root   120546  0.0  0.1 ... ConfigServer Version Check
# #

$0 = $proc_name;            # change process name

# #
#   Declare › Helper › Get csget process pids
#   
#   @usage                  fetch_csget_pids()
#   @returns                List of PIDs for all csget processes, excluding the current script and parent sudo
# #

sub fetch_csget_pids
{
    my $self_pid    = $$;
    my $parent_pid  = getppid();

    # Get PIDs by script path and by $0 name
    my @pids_path   = map { chomp; $_ } `pgrep -f '/etc/cron.daily/csget' 2>/dev/null`;
    my @pids_name   = map { chomp; $_ } `pgrep -f '\Q$proc_name\E' 2>/dev/null`;

    # Merge unique PIDs
    my %seen;
    my @pids        = grep { !$seen{$_}++ } (@pids_path, @pids_name);

    # Remove current script and parent sudo
    @pids           = grep { $_ =~ /^\d+$/ && $_ != $self_pid && $_ != $parent_pid } @pids;

    return @pids;
}

# #
#   Declare › Helper › Daemon Log
#   
#   @usage                  daemon_log("Some daemon message\n");
#   @returns                null
#                           prints message to daemon_log 
# #

sub daemon_log
{
    my ($msg, $fh) = @_;

    # #
    #   Strip any trailing newlines
    # #

    $msg =~ s/\n+$//;

    # #
    #   Timestamp
    # #

    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    $mon  += 1;
    $year += 1900;
    $year %= 100;

    my $timestamp = sprintf( "%02d/%02d/%02d %02d:%02d:%02d",
        $mon, $mday, $year, $hour, $min, $sec
    );

    if ($fh)
    {
        print $fh "$timestamp | $msg\n";
    }
    else
    {
        print "$timestamp | $msg\n";
    }
}

# #
#   Declare › Helper › Debug Logging (w/ optional daemon logging route)
#   
#   @usage                  dbg( "This is a debug message", daemon => 1 );
#   @returns                null
# #

sub dbg
{
    my ($msg, %opts) = @_;

    # #
    #   Strip any trailing newlines
    # #

    $msg =~ s/\n+$//;

    # #
    #   Timestamp
    # #

    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    $mon  += 1;
    $year += 1900;
    $year %= 100;
    my $timestamp = sprintf( "%02d/%02d/%02d %02d:%02d:%02d",
        $mon, $mday, $year, $hour, $min, $sec
    );

    my $log_entry = "$timestamp | $msg\n";

    # #
    #   Print to debug log if $DEBUG
    # #

    if ( $DEBUG && defined $dbg )
    {
        print $dbg $log_entry;
    }

    # #
    #   Print to daemon log if requested, pass fh if provided
    # #

    if ( $opts{daemon} )
    {
        daemon_log( $msg, $opts{fh} );
    }

    # #
    #   Only print to custom filehandle if not sent to daemon log
    # #

    elsif ( $opts{fh} )
    {
        my $fh = $opts{fh};
        print $fh $log_entry;
    }
}

# #
#   Load › Settings
#   
#   Grabs a few csf config settings we'll need in order to confirm the release channel
#   to use when downloading updates.
# # 

if ( -e $configFile )
{
    open my $fh, '<', $configFile or die "Cannot open $configFile: $!";
    while (<$fh>)
    {
        chomp;
        s/#.*$//;              # remove comments
        next if /^\s*$/;       # skip empty lines
        if (/^\s*(\w+)\s*=\s*["']?([^"']+)["']?/)
        {
            $configValues{$1} = $2;
        }
    }
    close $fh;
}

# #
#   Declare › Flags
#   
#       --debug                 enables debug logging; disables forked child process daemonization
#                                   › sudo perl /etc/cron.daily/csget --debug
#   
#       --kill                  kills all processes associated with csget
#                                   › sudo perl /etc/cron.daily/csget --kill
#   
#       --list                  lists all processes associated with csget
#                                   › sudo perl /etc/cron.daily/csget --list
#   
#       --version               Prints version information about csget and csf
#                                   › sudo perl /etc/cron.daily/csget --version
#   
#       --nosleep               Skips random sleep interval; processes immediately
#                                   › sudo perl /etc/cron.daily/csget --nosleep
#       
#       --diag                  Prints diagnostic info
#                                   › sudo perl /etc/cron.daily/csget --diag
# #

foreach my $arg ( @ARGV )
{
    if ( $arg =~ /^--debug$|^-D$/ )
    {
        # #
        #   @usage          sudo perl /etc/cron.daily/csget --debug
        #                   Enables debug logging; disables forked child processes
        # #

        $DEBUG = 1;
        next;
    }
    elsif ( $arg =~ /^--kill$|^-k$/ )
    {
        # #
        #   @usage          sudo perl /etc/cron.daily/csget --kill
        #                   Kills all processes associated with csget
        # #

        my @pids = fetch_csget_pids();

        if ( @pids )
        {
            kill 9, @pids;
            print "csget processes terminated: @pids\n";
        }
        else
        {
            print "No csget processes found to kill.\n";
        }
    
        exit 0;
    }
    elsif ( $arg =~ /^--list$|^-l$/ )
    {
        # #
        #   @usage          sudo perl /etc/cron.daily/csget --list
        #                   Lists all csget processes except this command
        # #

        print "\n";

        my $self_pid   = $$;                # current Perl PID
        my $parent_pid = getppid;           # parent PID (sudo)

        my @lines = grep
        {
            (/\/etc\/cron.daily\/csget/ || /ConfigServer Version Check/) 
            && !/--list/                    # skip the list command itself
            && !/\b$self_pid\b/             # skip current PID
            && !/\b$parent_pid\b/           # skip parent (sudo)
        } `ps aux`;

        if ( @lines )
        {
            print "  ${BRIGHT_BLUE}csget processes currently running:${END}\n", @lines;
        }
        else
        {
            print "  ${BRIGHT_GREEN}No csget processes found.${END}\n";
        }

        print "\n";

        exit 0;
    }
    elsif ( $arg =~ /^--version$|^-v$/ )
    {
        # #
        #   @usage          sudo perl /etc/cron.daily/csget --version
        #                   Prints the CSF version number and exits
        # #

        my $version_file = "/etc/csf/version.txt";

        if ( -e $version_file )
        {
            open my $fh, '<', $version_file
                or die "Cannot open $version_file: $!";
            my $version = <$fh>;       # read first line
            chomp $version;            # remove newline
            close $fh;

            print "\n";
            print "  ${BRIGHT_YELLOW}${proc_title}${END}\n";
            print "  ${GREY_DARK}ConfigServer Security & Firewall v$version${END}\n";
            print "  ${GREY_DARK}${proc_desc}${END}\n";
            print "  ${GREY_DARK}$proc_url${END}\n";
            print "\n";
        }
        else
        {
            print "  ${BRIGHT_RED}CSF version file not found: $version_file${END}\n";
        }

        exit 0;
    }
    elsif ( $arg =~ /^--diag$|^--diagnostic$|^-d$/ )
    {
        # #
        #   @usage          sudo perl /etc/cron.daily/csget --diag
        #                   Prints diagnostic info about csget
        # #

        # #
        #   Determine which fetch tool exists
        # #
    
        my ($diagMethod, $diagCmd) = ( "none", "None" );
        foreach my $tool (qw(curl wget get))
        {
            if ( -e "/usr/bin/$tool" )
            {
                $diagMethod     = $tool;
                $diagCmd        = $fetch{ $tool };
                last;
            }
        }

        # #
        #   Pick a server/version for diagnostics
        # #

        my ( $diagUrl, $diagVersion, $diagOut ) = ( "none", "none", "none" );
        my ( $configStatus ) = "None";
        if ( @downloadservers && keys %versions )
        {
            $diagVersion        = (keys %versions)[ 0 ];
            $diagUrl            = $downloadservers[ 0 ] . $diagVersion;

            # #
            #   Build command string based on fetch method
            # #

            if ( $diagMethod eq "get" )
            {
                $diagOut = "$diagCmd $diagUrl > $versions{ $diagVersion }";
            }
            else
            {
                $diagOut = "$diagCmd $versions{ $diagVersion } $diagUrl";
            }
        }

        # #
        #   Config Status
        # #

        if ( -e $configFile )
        {
            $configStatus = "${BRIGHT_GREEN}(Found)${END}";
        }
        else
        {
            $configStatus = "${BRIGHT_RED}(Not Found)${END}";
        }

        # #
        #   Output
        # #

        print "\n";
        print "  ${BRIGHT_YELLOW}${proc_title}${END}\n";
        print "  ${GREY_DARK}${proc_desc}${END}\n";
        print "  ${GREY_DARK}$proc_url${END}\n\n";
        print "  ${GREY_DARK}Server URL ....... ${BRIGHT_YELLOW}${diagUrl}${END}\n";
        print "  ${GREY_DARK}Fetch Package .... ${BRIGHT_YELLOW}${diagMethod}${END}\n";
        print "  ${GREY_DARK}Command (Base) ... ${BRIGHT_YELLOW}${diagCmd}${END}\n";
        print "  ${GREY_DARK}Command (Out) .... ${BRIGHT_YELLOW}${diagOut}${END}\n";
        print "  ${GREY_DARK}Config Path ...... ${BRIGHT_YELLOW}${configFile} ${configStatus}${END}\n";
        print "  ${GREY_DARK}Log Folder ....... ${BRIGHT_YELLOW}${log_dir}${END}\n";
        print "  ${GREY_DARK}Log Daemon ....... ${BRIGHT_YELLOW}${log_daemon}${END}\n";
        print "  ${GREY_DARK}Log Debug ........ ${BRIGHT_YELLOW}${log_debug}${END}\n";
        print "\n";

        exit 0;
    }
    elsif ( $arg =~ /^--nosleep$|^-n$/ )
    {
        # #
        #   @usage          sudo perl /etc/cron.daily/csget --nosleep
        #                   If specified, csget runs instantly, not on a random timer.
        # #

        $NOSLEEP = 1;
    }
    elsif ( $arg =~ /^--help$|^-h$/ )
    {
        # #
        #   @usage          sudo perl /etc/cron.daily/csget --help
        #                   Returns help information
        # #

        # #
        #   Output
        # #

        print "\n";
        print "  ${BRIGHT_YELLOW}${proc_title}${END}\n";
        print "  ${GREY_DARK}${proc_desc}${END}\n";
        print "  ${GREY_DARK}$proc_url${END}\n\n";
        printf "  %-28s %s%s\n", "${BRIGHT_BLUE}-k, --kill ", "${GREY_MEDIUM}Kills all processes associated with csget.", $END;
        printf "  %-28s %s%s\n", "${BRIGHT_BLUE}-n, --nosleep ", "${GREY_MEDIUM}Run task immediately, do not start on timed delay.", $END;
        printf "  %-28s %s%s\n", "${BRIGHT_BLUE}-l, --list ", "${GREY_MEDIUM}Lists all csget processes except this command.", $END;
        printf "  %-28s %s%s\n", "${BRIGHT_BLUE}-d, --diag ", "${GREY_MEDIUM}Show diagnostic information.", $END;
        printf "  %-28s %s%s\n", "${BRIGHT_BLUE}-D, --debug ", "${GREY_MEDIUM}Show verbose logs and additional details.", $END;
        printf "  %-28s %s%s\n", "${BRIGHT_BLUE}-v, --version ", "${GREY_MEDIUM}Show version information.", $END;
        printf "  %-28s %s%s\n", "${BRIGHT_BLUE}-h, --help ", "${GREY_MEDIUM}Show this help menu.", $END;
        print "\n";

        exit 0;
    }
    else
    {
        # #
        #   @usage          sudo perl /etc/cron.daily/csget --randomBadFlag
        #                   Specified bad flag doesn't exist
        # #

        print "\n";
        print "  ${BRIGHT_RED}Invalid argument: ${BRIGHT_YELLOW}$arg${END}\n";
        print "  ${GREY_DARK}Usage: ${BRIGHT_BLUE}sudo perl /etc/cron.daily/csget ${GREY_DARK}[${BRIGHT_YELLOW} --debug ${GREY_DARK}|${BRIGHT_YELLOW} --kill ${GREY_DARK}|${BRIGHT_YELLOW} --list ${GREY_DARK}|${BRIGHT_YELLOW} --version ${GREY_DARK}|${BRIGHT_YELLOW} --nosleep ${GREY_DARK}]${BRIGHT_BLUE}${END}\n";
        print "\n";
        exit 1;
    }
}

# #
#   Define › Debug Mode
# #

if ( $DEBUG )
{
    mkdir $log_dir unless -d $log_dir;

    open $dbg, '>>', $log_debug or die "Cannot open debug log: $!";
    select((select($dbg), $|=1)[0]);        # auto-flush

    my $script_path = `readlink -f $0`;
    chomp $script_path;

    dbg( "[DBUG]: csget debug enabled; logging to [ \"$log_dir\" ]" );
}

# #
#   Perl daemonization/fork block
#       sudo perl -w /etc/cron.daily/csget --nosleep
#       sudo perl -d /etc/cron.daily/csget
#   
#   Parent exits				terminal / cron is free
#   Child continues 			runs in background
# #

unless ( $DEBUG )
{
    if ( my $pid = fork ) { exit 0; }               # parent
    elsif ( defined( $pid ) ) { $pid = $$; }        # child
    else { die "Unable to fork: $!"; }              # cannot fork

    chdir( "/" );
    close( STDIN );
    close( STDOUT );
    close( STDERR );
    open( STDIN,  "<", "/dev/null" );
    open( STDOUT, ">>", "$log_daemon" )
        or die "Cannot open STDOUT log: $!";
    open( STDERR, ">>", "$log_daemon" )
        or die "Cannot open STDERR log: $!";
}

# #
#   Always make sure log dir exists
# #

mkdir $log_dir unless -d $log_dir;

# #
#   Define › Welcome Print
# #

my $script_path = `readlink -f /etc/cron.daily/csget`;
chomp( $script_path ); # remove trailing newline
daemon_log( "[INFO]: Found csget path: [$script_path]" );
daemon_log( "[INFO]: Daemon started with PID [ \"$$\" ]" );

# #
#   Action › Create required folders and files
# #

system( "mkdir -p /var/lib/configserver/" );
system( "rm -f /var/lib/configserver/*.txt /var/lib/configserver/*error" );

# #
#   Condition › Update Fetch Command / Binary
#   
#   determine which binary to use for fetching server info
#       /usr/bin/curl
#       /usr/bin/wget
#       /usr/bin/GET
# #

if ( -e "/usr/bin/curl" )
{
    $cmd        = $fetch{ 'curl' };
    $method     = "curl";
}
elsif ( -e "/usr/bin/wget" )
{
    $cmd        = $fetch{ 'wget' };
    $method     = "wget";
}
elsif ( -e "/usr/bin/GET" )
{
    $cmd        = $fetch{ 'get' };
    $method     = "get";
}
else
{
    open( my $ERROR, ">", "/var/lib/configserver/error" );
    daemon_log( "[FAIL]: No download tool found: curl, wget, or get", $ERROR );
    close( $ERROR );
    exit 1;
}

daemon_log( "[PASS]: Found package [ \"$method\" ] using cmd [ \"$cmd\" ]" );

# #
#   Secondary fallback
#   
#   This is here in case curl or wget are detected, but for some reason, the version file
#   cannot be downloaded. 
#   
#   However, GET is a primary option to fetch the version file from the CSF server.
# #

if ( -e "/usr/bin/GET" )
{
	$GET = "/usr/bin/GET -sd -t 120"
}

# #
#   Condition › No Source Version Found
#   
#   Originally, this function would unlink the cron
# #

if ( scalar( keys %versions ) == 0 )
{

    # unlink $0;

    dbg( "ERROR: No version files to fetch — aborting cron run", daemon => 1 );

    # #
    #   mark last run with no versions
    # #

    my $status_file = "/var/lib/configserver/last_run_no_versions";
    if ( !-d "/var/lib/configserver" )
	{
        system( "mkdir -p /var/lib/configserver" ) == 0
            or die "Failed to create /var/lib/configserver for status file";
    }

    system( "touch $status_file" ) == 0
        or warn "Failed to create status file $status_file";

    exit 0;
}

# #
#   Execute › Process Delayed Timer
#   
#   creates a delay for when the cron will actually run. Anywhere between 0 and 6 hours from the 
#       time of this condition being triggered.
#   
#   original csf developer added this delay. we'll assume in order to mitigate floods of
#       traffic from hitting the server all at once.
#   
#   no arg					› $ARGV[0] undefined › condition is true › sleep
#   arg `--nosleep`			› skip sleep
#   arg `something else`	› sleep
# #

unless ( $NOSLEEP )
{
    daemon_log( "[INFO]: Activating sleep mode" );
    system( 'sleep', int( rand( 60 * 60 * 6 ) ) );
}

# #
#   Logic › Get Download Server
#   
#   loop download server array with Fisher-Yates shuffle
#       Randomize order of @downloadservers.
# #

for ( my $x = @downloadservers; --$x; )
{
	my $y = int( rand( $x+1 ) );
	if ( $x == $y ) { next }
	@downloadservers[ $x,$y ] = @downloadservers[ $y,$x ];
}

# #
#   Logic › Loop Update URL
# #

foreach my $server ( @downloadservers )
{
    dbg( "[INFO]: Check server: [ \"$server\" ]", daemon => 1 );

    # #
    #   Loop $versions
    #   
    #       %versions                               $version
    #       -------------------------------------------------------------------------------
    #       $versions{ "/csf/version.txt" }         = "/var/lib/configserver/csf.txt"
    #       $versions{ "/cxs/version.txt" }         = "/var/lib/configserver/cxs.txt"
    #       $versions{ "/cmm/cmmversion.txt" }      = "/var/lib/configserver/cmm.txt"
    # #

    foreach my $version ( keys %versions )
    {
        # #
        #   Download url
        #       Example: https://download.configserver.dev/csf/version.txt
        # #
    
        my $url = "$server$version";

        dbg( "[INFO]: Found local file [ \"$version\" ]; getting remote latest version number from [ \"$url\" ] and store in local [ \"$versions{ $version }\" ]", daemon => 1 );
    
        # #
        #   Run if local version file does NOT exist
        #   Download new copy of file from CSF server.
        # #

        unless ( -e $versions{ $version } )
        {
            # #
            #   Clean up .error files
            # #

            if ( -e $versions{ $version }.".error" )
            {
                unlink $versions{ $version }.".error";
                dbg( "[INFO]: Removed previous error file: $versions{ $version }.error", daemon => 1 );
            }

            # #
            #   Channel › Insiders
            #   Get sponsor license key from CSF config /etc/csf/csf.conf
            # #

            if ( ( $configValues{SPONSOR_RELEASE_INSIDERS} // 0 ) == 1 && ( $configValues{SPONSOR_LICENSE} // '' ) ne '' && $version eq "/csf/version.txt" )
            {
                $url .= "?channel=insiders&license=$configValues{ SPONSOR_LICENSE }";
                dbg( "[PASS]: Using release channel [ \"insiders\" ] from server [ \"$url\" ]", daemon => 1 );
            }

            # #
            #   Channel › Stable
            # #

            else
            {
                dbg( "[PASS]: Using release channel [ \"stable\" ] from server [ \"$url\" ]", daemon => 1 );
            }

            # #
            #   Prepare download
            # #

            dbg( "[INFO]: Preparing to download remote [ \"$url\" ] to local [ \"$versions{ $version }\" ]", daemon => 1 );

            # #
            #   Method: None
            #   
            #   Backup check to ensure we get the proper method.
            # #

            if ( $method eq "none" )
            {
                dbg( "[FAIL]: GET [ \"$method\" ] bad method; aborting process", daemon => 1 );
                exit 0;

            }
            elsif ( $method eq "get" )
            {
                # #
                #   GET prints to stdout; redirect stdout -> file, stderr -> .error
                # #
            
                my $cmdline = "$cmd $url > $versions{ $version } 2> $versions{ $version }.error";
                dbg( "[INFO]: Downloading file using [ \"$method\" ] with command [ \"$cmdline\" ]", daemon => 1 );

                my $raw     = system( $cmdline );           # Raw return from system()
                my $exit    = $raw >> 8;                    # Real exit code from raw return; shift right 8 bytes

                dbg( "[INFO]: Method [ \"$method\" ] returned raw response [ \"$raw\" ]; exit = [ \"$exit\" ]", daemon => 1 );

                # #
                #   Success only if exit == 0 AND file exists and has content
                # #
            
                if ( $exit == 0 && -s $versions{ $version } )
                {
                    $status = 0;                            # success

                    # remove stale .error if present and empty
                    if ( -e "$versions{ $version }.error" && -z "$versions{ $version }.error" )
                    {
                        unlink "$versions{ $version }.error";
                    }
                }
                else
                {
                    # #
                    #   GET returns 0                   Success
                    #   GET returns 0 + blank file      Generic failure 1
                    #   GET returns non-zero            Keep exit code (non-zero indicates failure)
                    # #
        
                    $status = ( $exit != 0 ) ? $exit : 1;

                    dbg( "[WARN]: GET [ \"$method\" ] failed or produced empty file; status set to [ \"$status\" ]", daemon => 1 );
                }
            }

            # #
            #   Method: curl / wget
            #   
            #   These write to file when invoked with -o/-O; system() exit is reliable
            # #

            else
            {
                my $cmdline = "$cmd $versions{ $version } $url";
                dbg( "[INFO]: Downloading file using [ \"$method\" ] with command [ \"$cmdline\" ]", daemon => 1 );

                my $raw     = system( $cmdline );
                my $exit    = $raw >> 8;

                dbg( "[INFO]: Method [ \"$method\" ] returned raw response [ \"$raw\" ]; exit = [ \"$exit\" ]", daemon => 1 );

                # Normalize to 0 (success) / non-zero (failure)
                $status = $exit == 0 ? 0 : $exit;
            }

            # #
            #   curl        0           Success 
            #               non-zero    Error           https://curl.se/libcurl/c/libcurl-errors.html
            #   
            #   wget        0           Success
            #               non-zero    Error           https://gnu.org/software/wget/manual/html_node/Exit-Status.html
            #   
            #   get         0           Success
            #               non-zero    Error
            # #

            dbg( "[INFO]: Method [ \"$method\" ] returned status [ \"" . ( $status ) . "\" ]" , daemon => 1 );

            if ( $status )
            {
				if ($GET ne "")
                {
					open ( my $ERROR, ">", $versions{ $version }.".error" );
                    daemon_log( "[FAIL]: [ \"$method\" ]: $server$version -", $ERROR );
					close ( $ERROR );
					my $GETstatus = system( "$GET $server$version >> $versions{ $version }".".error" );
				}
                else
                {
					open ( my $ERROR, ">", $versions{ $version }.".error" );
                    daemon_log( "[FAIL]: [ \"$method\" ]: Failed to retrieve latest version from ConfigServer", $ERROR );
					close ( $ERROR );
				}
            }
            else
            {
                dbg( "[INFO]: Successfully downloaded csf version from [ \"$url\" ] to file [ \"$versions{ $version }\" ]", daemon => 1 );
            }


        }
    }
}
