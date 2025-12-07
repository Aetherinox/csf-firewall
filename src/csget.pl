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
#   @updated            12.07.2025
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
#       Script runs as a cron in:
#           /etc/cron.daily/csget
#       
#       By default, the script sleeps for a random number of seconds in
#       fork/daemon mode:
#           0 to 6 hours (rand(60*60*6) = up to 21600 seconds)
#       
#       After sleep, it connects to the official GitHub repo and checks
#       the latest version of CSF using the file:
#           https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/api/templates/versions/<APP>/version.txt
#           https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/api/templates/versions/csf/version.txt
#       
#       After the latest version is fetched from @downloadserver, a file is
#       created in /var/lib/configserver/csf.txt with contents like:
#           15.03
#       
#       If you run the script using:
#           sudo perl /etc/cron.daily/csget
#       A process will be created with a random duration between 0 and 6 hours.
#       You can find it using:
#           ps aux | grep Config
#           root     3830870  0.0  0.1  22280  8980 ?        S    15:41   0:00 ConfigServer Version Check
#           sudo kill -9 3830870
#       
#       If you run the script using:
#           sudo perl -d:Trace /etc/cron.daily/csget --nosleep
#       The action will run immediately with no lingering process.
#       All output will be logged to /var/log/csf/csget_daemon.log
#   
#           Requires:
#               DEBIAN/UBUNTU               sudo apt update
#                                           sudo apt install libdevel-trace-perl
#               REDHAT                      sudo yum makecache
#                                           sudo dnf install perl-Devel-Trace
#       
#       If you run the script using:
#           sudo perl -d:Trace /etc/cron.daily/csget --debug
#       The action will trigger, create a child process, and wait 0–6 hours
#       before running. Logging will be sent to
#       /var/log/csf/csget_debug.log
#       
#   This script contains two log files:
#       /var/log/csf/csget_daemon.log     logs to this file if --debug mode DISABLED
#       /var/log/csf/csget_debug.log      logs to this file if --debug mode ENABLED
#       
#   sudo perl /etc/cron.daily/csget
#       Runs the script normally, no extra warnings, no debugging.
#       If the script forks (daemonizes), the parent exits normally.
#       STDOUT/STDERR behavior depends on the script (e.g., closed in fork).
#       
#   sudo perl -w /etc/cron.daily/csget
#       Enables warnings (-w flag) for uninitialized variables, deprecated
#       features, or risky operations. Otherwise behaves like plain Perl.
#       Fork/daemon behavior and STDOUT/STDERR unchanged (aside from warnings).
#       
#   sudo perl -d /etc/cron.daily/csget
#       Runs the Perl debugger (-d). Stops at the first line and waits for
#       debugger commands (n=next, c=continue). Can step through lines,
#       inspect variables, set breakpoints, etc.
#       Note: If the script forks, child processes won't have the debugger
#       attached. Script behavior differs from normal run.
#       
#   sudo perl -d:Trace /etc/cron.daily/csget
#       Special debugger module: Trace. Prints every line executed in real
#       time. Useful for line-by-line debugging. Fork/daemonization can behave
#       differently. Script may exit immediately or behave oddly as the
#       debugger controls STDOUT/STDERR for trace output.
#       
#   Process can be killed with:
#       ps aux | grep csget
#       sudo pkill -9 -f "sudo perl -w /etc/cron.daily/csget"
# #

use strict;
use warnings;

# #
#   Define › Debug
#   
#   1 = debug mode		    sets logging, disables daemonization/fork block
#   0 = normal mode		    no logging, enables daemonization/fork block
# #

our $DEBUG      = 0;

# #
#   Define › Log Paths
# #

our $log_dir    = '/var/log/csf';
our $log_debug  = "$log_dir/csget_debug.log";
our $log_daemon = "$log_dir/csget_daemon.log";
our $proc_name  = "ConfigServer Version Check";
our $dbg;
my %versions;
my $cmd;
my $GET;

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
if ($@)
{
    warn "diagnostics module not found; continuing without it\n" if $DEBUG;
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
    my $self_pid = $$;
    my $parent_pid = getppid();

    # get PIDs by script path and by $0 name
    my @pids_path = map { chomp; $_ } `pgrep -f '/etc/cron.daily/csget' 2>/dev/null`;
    my @pids_name = map { chomp; $_ } `pgrep -f '\Q$proc_name\E' 2>/dev/null`;

    # merge unique PIDs
    my %seen;
    my @pids = grep { !$seen{$_}++ } (@pids_path, @pids_name);

    # remove current script and parent sudo
    @pids = grep { $_ =~ /^\d+$/ && $_ != $self_pid && $_ != $parent_pid } @pids;

    return @pids;
}

# #
#   Declare › Helper › Debug
#   
#   @usage                  dbg("Some debug message\n");
#   @returns                null
#                           prints message to debug log if $DEBUG is true and debug 
#                               filehandle ($dbg) is defined
# #

sub dbg
{
    my ($msg) = @_;
    return unless $DEBUG && defined $dbg;  # safety check
    print $dbg $msg;
}

# #
#   Define › etc/csf/csf.conf
# # 

my %CONFIG;
my $CONFIG_FILE = "/etc/csf/csf.conf";

# #
#   Load › Settings
#   
#   Grabs a few csf config settings we'll need in order to confirm the release channel
#   to use when downloading updates.
# # 

if ( -e $CONFIG_FILE )
{
    open my $fh, '<', $CONFIG_FILE or die "Cannot open $CONFIG_FILE: $!";
    while (<$fh>)
    {
        chomp;
        s/#.*$//;              # remove comments
        next if /^\s*$/;       # skip empty lines
        if (/^\s*(\w+)\s*=\s*["']?([^"']+)["']?/)
        {
            $CONFIG{$1} = $2;
        }
    }
    close $fh;
}

# #
#   Declare › Flags
#   
#       --debug                 enables debug logging; disables forked child process daemonization
#                                   › sudo perl /etc/cron.daily/csget --debug
#       --kill                  kills all processes associated with csget
#                                   › sudo perl /etc/cron.daily/csget --kill
#       --list                  lists all processes associated with csget
#                                   › sudo perl /etc/cron.daily/csget --list
# #

foreach my $arg (@ARGV)
{
    if ($arg eq '--debug')
    {
        # #
        #   @usage          sudo perl /etc/cron.daily/csget --debug
        #                   enables debug logging; disables forked child processes
        # #

        $DEBUG = 1;
        next;
    }
    elsif ( $arg eq '--kill' )
    {
        # #
        #   @usage          sudo perl /etc/cron.daily/csget --kill
        #                   kills all processes associated with csget
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
    elsif ( $arg eq '--list' )
    {
        # #
        #   @usage          sudo perl /etc/cron.daily/csget --list
        #                   lists all csget processes except this command
        # #

        my $self_pid   = $$;                # current Perl PID
        my $parent_pid = getppid;           # parent PID (sudo)

        my @lines = grep {
            (/\/etc\/cron.daily\/csget/ || /ConfigServer Version Check/) 
            && !/--list/                    # skip the list command itself
            && !/\b$self_pid\b/             # skip current PID
            && !/\b$parent_pid\b/           # skip parent (sudo)
        } `ps aux`;

        if (@lines)
        {
            print "csget processes currently running:\n", @lines;
        }
        else
        {
            print "No csget processes found.\n";
        }

        exit 0;
    }
}

# #
#   always make sure log dir exists
# #

mkdir $log_dir unless -d $log_dir;

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
    dbg( "=== csget started at " . localtime() . " ===\n" );
    dbg( "Script absolute path: $script_path\n" );
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
#   Define › Welcome Print
# #

my $script_path = `readlink -f /etc/cron.daily/csget`;
chomp( $script_path ); # remove trailing newline
print "Script absolute path: $script_path\n";

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
# #

if ( -e "/usr/bin/curl" )
{
	$cmd = "/usr/bin/curl -skLf -m 120 -o"
}
elsif ( -e "/usr/bin/wget" )
{
	$cmd = "/usr/bin/wget -q -T 120 -O"
}
else
{
	open ( my $ERROR, ">", "/var/lib/configserver/error" );
	print $ERROR "Cannot find /usr/bin/curl or /usr/bin/wget to retrieve product versions\n";
	close ( $ERROR );
	exit;
}

# #
#   Condition › Binary (Backup)
#   
#   Used as an alternative to curl / wget
# #

if ( -e "/usr/bin/GET" )
{
	$GET = "/usr/bin/GET -sd -t 120"
}

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
#   Condition › No Source Version Found
#   
#   originally, this function would unlink the cron
# #

if ( scalar( keys %versions ) == 0 )
{

    # unlink $0;

    if ( $DEBUG )
	{
        dbg( "=== csget: No version files to fetch — exiting ===\n" );
    }

    # mark last run with no versions
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
#   no arg					› $ARGV[0] undefined → condition is true → sleep
#   arg `--nosleep`			› skip sleep
#   arg `something else`	› sleep
# #

unless ( defined $ARGV[0] && $ARGV[0] eq '--nosleep' )
{
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
    dbg( "DEBUG: Checking server: $server\n" );
    foreach my $version ( keys %versions )
    {
        dbg( "DEBUG: Checking version: $version -> $versions{$version}\n" );
        unless ( -e $versions{ $version } )
        {
            if ( -e $versions{ $version }.".error" )
            {
                unlink $versions{ $version }.".error";
                dbg( "DEBUG: Removed previous error file: $versions{ $version }.error\n" );
            }

            my $url = "$server$version";

            # Enable insiders channel if allowed
            if ( ( $CONFIG{SPONSOR_RELEASE_INSIDERS} // 0 ) == 1 
                && ( $CONFIG{SPONSOR_LICENSE} // '' ) ne '' 
                && $version eq "/csf/version.txt" )
            {
                $url .= "?channel=insiders&license=$CONFIG{SPONSOR_LICENSE}";
                dbg( "DEBUG: Using Insiders release channel, URL: $url\n" );
            }
            else
            {
                dbg( "DEBUG: Using Stable release channel, URL: $url\n" );
            }

            dbg( "DEBUG: Preparing to download $version from $url ($server)\n" );

            my $status = system( "$cmd $versions{ $version } $url" );
            dbg( "DEBUG: Command executed: $cmd $versions{ $version } $url\n" );
            dbg( "DEBUG: Command exit code: " . ( $status >> 8 ) . "\n" );

            if ( $status )
            {
                if ( $GET ne "" )
                {
                    open ( my $ERROR, ">", $versions{ $version }.".error" );
                    print $ERROR "$server$version - ";
                    close ( $ERROR );

                    dbg( "DEBUG: Curl/wget failed, trying GET command: $GET $server$version\n" );
                    my $GETstatus = system( "$GET $server$version >> $versions{ $version }.error" );
                    dbg( "DEBUG: GET command exit code: " . ( $GETstatus >> 8 ) . "\n" );
                }
                else
                {
                    open ( my $ERROR, ">", $versions{ $version }.".error" );
                    print $ERROR "Failed to retrieve latest version from ConfigServer";
                    close ( $ERROR );
                    dbg( "DEBUG: Failed to retrieve $version from $server and no GET command available\n" );
                }
            }
            else
            {
                dbg( "DEBUG: Successfully downloaded $version from $server\n" );
            }
        }
        else
        {
            dbg( "DEBUG: $versions{ $version } already exists, skipping download\n" );
        }
    }
}
