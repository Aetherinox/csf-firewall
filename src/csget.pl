#!/usr/bin/perl
# #
#   @app                    ConfigServer Firewall & Security (CSF)
#                           Login Failure Daemon (LFD)
#   @website                https://configserver.dev
#   @docs                   https://docs.configserver.dev
#   @download               https://download.configserver.dev
#   @repo                   https://github.com/Aetherinox/csf-firewall
#   @copyright              Copyright (C) 2025-2026 Aetherinox
#                           Copyright (C) 2006-2025 Jonathan Michaelson
#                           Copyright (C) 2006-2025 Way to the Web Limited
#   @license                GPLv3
#   @updated                09.26.2025
#   
#   This program is free software; you can redistribute it and/or modify it under
#   the terms of the GNU General Public License as published by the Free Software
#   Foundation; either version 3 of the License, or (at your option) any later
#   version.
#   
#   This program is distributed in the hope that it will be useful, but WITHOUT
#   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#   FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
#   details.
#   
#   You should have received a copy of the GNU General Public License along with
#   this program; if not, see <https://www.gnu.org/licenses>.
# #

# #
#   ConfigServer and Firewall › CSGet
#       Script runs as a cron in:
#           /etc/cron.daily/csget
#       By default, the script sleeps for a random number of seconds in fork / daemonization mode:
#           0 and 6 hours (rand(60*60*6) = up to 21600 seconds).
#       After sleep; connects to the official github repo and checks the latest version of CSF using the file:
#           https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/api/templates/versions/<APP>/version.txt
#           https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/api/templates/versions/csf/version.txt
#       After latest version fetched from @downloadserver; file will be created in `/var/lib/configserver/csf.txt` with:
#           15.10
#   
#       If you run the script using the command:
#           sudo perl /etc/cron.daily/csget
#       A process will be created which has a random duration between 0 and 6 hours, you can find it using
#           ps aux | grep Config
#           root     3830870  0.0  0.1  22280  8980 ?        S    15:41   0:00 ConfigServer Version Check
#           sudo kill -9 3830870
#   
#       If you run the script using the command:
#           sudo perl -d:Trace /etc/cron.daily/csget --nosleep
#       The action will be immediately ran with no lingering process.
#       All output will be logged to /var/log/csf/csget_daemon.log
#   
#       If you run the script using the command:
#           sudo perl -d:Trace /etc/cron.daily/csget --debug
#       The action will trigger, create a child process, and wait 0 - 6 hours before running.
#       But logging will be sent to /var/log/csf/csget_debug.log
#   
#   This script contains two log files:
#       /var/log/csf/csget_daemon.log               logs to this file if --debug mode DISABLED
#       /var/log/csf/csget_debug.log                logs to this file if --debug mode ENABLED
#   
#   sudo perl /etc/cron.daily/csget
#       Plain Perl execution.
#       Runs the script normally.
#       No extra warnings, no debugging.
#       If your script forks (daemonizes), it will fork normally and the parent exits.
#       STDOUT/STDERR behavior depends on what your script does (in your case, closes them in the fork).
#   
#   sudo perl -w /etc/cron.daily/csget
#       Enables warnings (-w flag).
#       Prints warnings for things like uninitialized variables, deprecated features, or risky operations.
#       Otherwise, behaves exactly like plain Perl.
#       Fork/daemon behavior is unchanged.
#       STDOUT/STDERR is unchanged (aside from warnings).
#   
#   sudo perl -d /etc/cron.daily/csget
#       Runs the Perl debugger (-d).
#       Stops the script at the first line and waits for debugger commands (like n for next, c for continue).
#       You can step through lines, inspect variables, set breakpoints, etc.
#       Important: The debugger expects to control the terminal.
#       If your script forks (daemonizes), the debugger can interfere, because child processes won’t have the debugger attached.
#       Script will not behave the same as normal run when it forks.
#   
#   sudo perl -d:Trace /etc/cron.daily/csget
#       Special debugger module: Trace.
#       Prints every line executed in real time.
#       Useful for debugging line-by-line execution.
#       Still runs in debugger context, so fork/daemonization can behave differently.
#       Script may exit immediately or behave oddly because the debugger is keeping control of STDOUT/STDERR for trace output.
#   
#   Process can be killed with
#       ps aux | grep csget
#       sudo pkill -9 -f "sudo perl -w /etc/cron.daily/csget"
# #

use strict;
use warnings;
use diagnostics;

# #
#   set debug mode
#       1 = debug mode		    sets logging, disables daemonization/fork block
#       0 = normal mode		    no logging, enables daemonization/fork block
# #

our $DEBUG = 0;
our $log_dir  = '/var/log/csf';
our $log_debug = "$log_dir/csget_debug.log";
our $log_daemon = "$log_dir/csget_daemon.log";
our $proc_name = "ConfigServer Version Check";
our $dbg;
my %versions;
my $cmd;
my $GET;

# #
#   download servers / structure
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
    # , "https://download.configserver.com"
);

# #
#   set process name
#       ps aux | grep perl
#       root   120546  0.0  0.1 ... ConfigServer Version Check
# #

$0 = $proc_name;            # change process name

# #
#   helper › get csget process pids
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
#   helper › debug
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
#   arguments
#       --debug
#           enables debug logging; disables forked child process daemonization
#           sudo perl /etc/cron.daily/csget --debug
#       --kill
#           kills all processes associated with csget
#           sudo perl /etc/cron.daily/csget --kill
#       --list
#           lists all processes associated with csget
#           sudo perl /etc/cron.daily/csget --list
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
    elsif ($arg eq '--kill')
    {
        # #
        #   @usage          sudo perl /etc/cron.daily/csget --kill
        #                   kills all processes associated with csget
        # #

        my @pids = fetch_csget_pids();

        if (@pids)
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
    elsif ($arg eq '--list')
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

        if (@lines) {
            print "csget processes currently running:\n", @lines;
        } else {
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
#   debugging
# #

if ($DEBUG)
{
    mkdir $log_dir unless -d $log_dir;

    open $dbg, '>>', $log_debug or die "Cannot open debug log: $!";
    select((select($dbg), $|=1)[0]);        # auto-flush

    my $script_path = `readlink -f $0`; chomp $script_path;
    dbg("=== csget started at " . localtime() . " ===\n");
    dbg("Script absolute path: $script_path\n");
}

# #
#   Perl daemonization/fork block
#       sudo perl -w /etc/cron.daily/csget --nosleep
#       sudo perl -d /etc/cron.daily/csget
#   
#   Parent exits				terminal / cron is free
#   Child continues 			runs in background
# #

unless ($DEBUG)
{
    if (my $pid = fork) { exit 0; }         # parent
    elsif (defined($pid)) { $pid = $$; }    # child
    else { die "Unable to fork: $!"; }      # cannot fork

    chdir("/");
    close(STDIN);
    close(STDOUT);
    close(STDERR);
    open(STDIN,  "<", "/dev/null");
    open(STDOUT, ">>", "$log_daemon")
        or die "Cannot open STDOUT log: $!";
    open(STDERR, ">>", "$log_daemon")
        or die "Cannot open STDERR log: $!";
}

# #
#   welcome print
# #

my $script_path = `readlink -f /etc/cron.daily/csget`;
chomp($script_path);                        # remove trailing newline
print "Script absolute path: $script_path\n";

# #
#   create required folders and files
# #

system("mkdir -p /var/lib/configserver/");
system("rm -f /var/lib/configserver/*.txt /var/lib/configserver/*error");

# #
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
	open (my $ERROR, ">", "/var/lib/configserver/error");
	print $ERROR "Cannot find /usr/bin/curl or /usr/bin/wget to retrieve product versions\n";
	close ($ERROR);
	exit;
}

# #
#   used as an alternative to curl / wget
# #

if (-e "/usr/bin/GET")
{
	$GET = "/usr/bin/GET -sd -t 120"
}

# #
#   Get Version Info
#       csf             ConfigServer and Firewall                   Free
#       cxs             ConfigServer Exploit Scanner                Commercial
#       cmm             ConfigServer Mail Manage                    Free
#       cse             ConfigServer Explorer                       Free
#       cmq             ConfigServer Mail Queues                    Free
#       cmc             ConfigServer Modsecurity Control            Free
#       osm             Outgoing Spam Monitor                       Commercial
#       msfe            MailScanner Front-End                       Commercial
# #

if ( -e "/etc/csf/csf.pl" )
{
	$versions{"/csf/version.txt"} = "/var/lib/configserver/csf.txt"
}

if (-e "/etc/cxs/cxs.pl")
{
	$versions{"/cxs/version.txt"} = "/var/lib/configserver/cxs.txt"
}

if (-e "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmm.cgi")
{
	$versions{"/cmm/cmmversion.txt"} = "/var/lib/configserver/cmm.txt"
}

if (-e "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cse.cgi")
{
	$versions{"/cse/cseversion.txt"} = "/var/lib/configserver/cse.txt"
}

if (-e "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmq.cgi")
{
	$versions{"/cmq/cmqversion.txt"} = "/var/lib/configserver/cmq.txt"
}

if (-e "/usr/local/cpanel/whostmgr/docroot/cgi/configserver/cmc.cgi")
{
	$versions{"/cmc/cmcversion.txt"} = "/var/lib/configserver/cmc.txt"
}

if ( -e "/etc/osm/osmd.pl" )
{
	$versions{"/osm/osmversion.txt"} = "/var/lib/configserver/osm.txt"
}

if ( -e "/usr/msfe/version.txt" )
{
	$versions{"/version.txt"} = "/var/lib/configserver/msinstall.txt"
}

if ( -e "/usr/msfe/msfeversion.txt" )
{
	$versions{"/msfeversion.txt"} = "/var/lib/configserver/msfe.txt"
}

# #
#   no version files found
#       originally, this function would unlink the cron
# #

if (scalar(keys %versions) == 0)
{

    # unlink $0;

    if ($DEBUG)
	{
        dbg("=== csget: No version files to fetch — exiting ===\n");
    }

    # mark last run with no versions
    my $status_file = "/var/lib/configserver/last_run_no_versions";
    if (!-d "/var/lib/configserver")
	{
        system("mkdir -p /var/lib/configserver") == 0
            or die "Failed to create /var/lib/configserver for status file";
    }

    system("touch $status_file") == 0
        or warn "Failed to create status file $status_file";

    exit 0;
}

# #
#   process delayed timer
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
#   loop download server array with Fisher-Yates shuffle
#       Randomize order of @downloadservers.
# #

for (my $x = @downloadservers; --$x;)
{
	my $y = int(rand($x+1));
	if ($x == $y) {next}
	@downloadservers[$x,$y] = @downloadservers[$y,$x];
}

# #
#   Loop update url
# #

foreach my $server ( @downloadservers )
{
    foreach my $version ( keys %versions )
    {
        unless ( -e $versions{ $version } )
        {
            if ( -e $versions{ $version }.".error" )
            {
                unlink $versions{ $version }.".error";
                dbg("DEBUG: Removed previous error file: $versions{ $version }.error\n");
            }

            dbg("DEBUG: Attempting to download $version from $server\n");

            my $status = system("$cmd $versions{ $version } $server$version");
            dbg("DEBUG: Command executed: $cmd $versions{ $version } $server$version\n");
            dbg("DEBUG: Command exit code: " . ($status >> 8) . "\n");

            if ( $status )
            {
                if ($GET ne "")
                {
                    open (my $ERROR, ">", $versions{ $version }.".error");
                    print $ERROR "$server$version - ";
                    close ($ERROR);

                    dbg("DEBUG: Curl/wget failed, trying GET command: $GET $server$version\n");
                    my $GETstatus = system("$GET $server$version >> $versions{ $version }.error");
                    dbg("DEBUG: GET command exit code: " . ($GETstatus >> 8) . "\n");
                }
                else
                {
                    open (my $ERROR, ">", $versions{ $version }.".error");
                    print $ERROR "Failed to retrieve latest version from ConfigServer";
                    close ($ERROR);
                    dbg("DEBUG: Failed to retrieve $version from $server and no GET command available\n");
                }
            }
            else
            {
                dbg("DEBUG: Successfully downloaded $version from $server\n");
            }
        }
        else
        {
            dbg("DEBUG: $versions{ $version } already exists, skipping download\n");
        }
    }
}
