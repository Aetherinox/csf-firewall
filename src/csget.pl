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
#   @updated            02.12.2026
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
#       15.09
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
#       sudo perl -d:Trace /etc/cron.daily/csget --nodaemon
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
use File::Basename;

# #
#   Colors
# #

my $esc                 = "\033";
my $end                 = "${esc}[0m";
my $bgEnd               = "${esc}[49m";
my $fgEnd               = "${esc}[39m";
my $bold                = "${esc}[1m";
my $dim                 = "${esc}[2m";
my $underline           = "${esc}[4m";
my $blink               = "${esc}[5m";

# Foreground colors
my $white           = "${esc}[97m";
my $black           = "${esc}[0;30m";
my $redl            = "${esc}[0;91m";
my $redd            = "${esc}[38;5;196m";
my $magental        = "${esc}[38;5;198m";
my $magentad        = "${esc}[38;5;161m";
my $fuchsial        = "${esc}[38;5;206m";
my $fuchsiad        = "${esc}[38;5;199m";
my $bluel           = "${esc}[38;5;33m";
my $blued           = "${esc}[38;5;27m";
my $greenl          = "${esc}[38;5;47m";
my $greend          = "${esc}[38;5;35m";
my $orangel         = "${esc}[38;5;208m";
my $oranged         = "${esc}[38;5;202m";
my $yellowl         = "${esc}[38;5;226m";
my $yellowd         = "${esc}[38;5;214m";
my $greyl           = "${esc}[38;5;250m";
my $greym           = "${esc}[38;5;244m";
my $greyd           = "${esc}[38;5;240m";
my $navy            = "${esc}[38;5;62m";
my $olive           = "${esc}[38;5;144m";
my $peach           = "${esc}[38;5;204m";
my $cyan            = "${esc}[38;5;6m";

# Background / combined colors
my $bgVerbose       = "${esc}[1;38;5;15;48;5;125m";     # white on purple
my $bgDebug         = "${esc}[1;38;5;15;48;5;237m";     # white on dark grey
my $bgInfo          = "${esc}[1;38;5;15;48;5;27m";      # white on blue
my $bgOk            = "${esc}[1;38;5;15;48;5;64m";      # white on green
my $bgWarn          = "${esc}[1;38;5;16;48;5;214m";     # black on orange/yellow
my $bgDanger        = "${esc}[1;38;5;15;48;5;202m";     # white on orange-red
my $bgError         = "${esc}[1;38;5;15;48;5;160m";     # white on red

# #
#   Define › Flag › Debug
#   
#   0 = normal mode		    no logging, enables daemonization/fork block; logs to /var/log/csf/csget_daemon.log
#   1 = debug mode		    sets logging, disables daemonization/fork block; logs to /var/log/csf/csget_debug.log
# #

our $FLG_DEBUG = 0;

# #
#   Define › Flag › Nosleep
#   
#   0 = disable		        condition is true › script sleeps.
#   1 = enable		        condition is false › script runs immediately.
# #

my $FLG_NOSLEEP = 0;

# #
#   Define › Flag › Return Response
#   
#   0 = disable		        when complete or failed, return nothing
#   1 = enable		        when complete or failed, return response
# #

my $FLG_RETRESPONSE = 0;

# #
#   Define › Log Paths
# #

our $log_dir            = '/var/log/csf';
our $log_file_debug     = "$log_dir/csget_debug.log";
our $log_file_daemon    = "$log_dir/csget_daemon.log";
our $app_name           = "CSF CSGET Perl Updater";
our $app_desc           = "A perl script which allows for automated update checks for the official CSF servers.";
our $app_repo           = "https://github.com/Aetherinox/csf-firewall";
our $proc_name          = "ConfigServer Version Check";
our $proc_path          = "/etc/cron.daily/" . basename($0) ."";
our $log_dbg;
my %versions;
my %config_vals;
my $config_file         = "/etc/csf/csf.conf";
my $version_file        = "/etc/csf/version.txt";
my $get_bin;
my $get_cmd;
my $get_method          = "none";
my $get_status          = 0;
my $col_width_left      = 32;

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
    print "\n" if $FLG_DEBUG;
    warn "  ${yellowl}Diagnostics${redl} perl module not found; continuing without it. You can install this perl module using the commands:${end}\n" if $FLG_DEBUG;
    warn "      ${greyd}sudo dnf install perl-Diagnostics${end}\n" if $FLG_DEBUG;
    warn "      ${greyd}sudo apt install libdiagnostics-perl${end}\n" if $FLG_DEBUG;
    print "\n" if $FLG_DEBUG;
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

$0 = $proc_name;            # change the process name

# #
#   Define › Version › Compare
#   
#   Compare two version numbers
# #

sub version_is_newer
{
    my ($new, $old) = @_;

    my @new_parts   = split /\./, $new;
    my @old_parts   = split /\./, $old;

    # Pad shorter array with zeros
    my $len         = @new_parts > @old_parts ? @new_parts : @old_parts;
    $#new_parts     = $len - 1;
    $#old_parts     = $len - 1;

    $_ ||= 0 for @new_parts, @old_parts;

    for my $i ( 0..$len - 1 )
    {
        return 1 if $new_parts[$i] > $old_parts[$i];
        return 0 if $new_parts[$i] < $old_parts[$i];
    }

    return 0; # same version
}

# #
#   Define › Version › Read File
#   
#   Read version from a file
# #

sub version_read
{
    my ($file) = @_;
    open my $fh, '<', $file or die "Cannot open $file: $!";
    my $line = <$fh>;
    close $fh;
    chomp $line;
    $line =~ s/^\s+|\s+$//g;   # trim whitespace

    # Validate version format
    unless ( $line =~ /^\d+(\.\d+){0,3}$/ )
    {
        die "Invalid version format in $file: '$line'\n";
    }

    return $line;
}

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
    my @pids_path   = map { chomp; $_ } `pgrep -f "$proc_path" 2>/dev/null`;
    my @pids_name   = map { chomp; $_ } `pgrep -f '\Q$proc_name\E' 2>/dev/null`;

    # Merge unique PIDs
    my %seen;
    my @pids        = grep { !$seen{$_}++ } (@pids_path, @pids_name);

    # Remove current script and parent sudo
    @pids           = grep { $_ =~ /^\d+$/ && $_ != $self_pid && $_ != $parent_pid } @pids;

    return @pids;
}

# #
#   Logs › Main
#   
#   Called by:
#       log_dbg
#       log_daemon
# #

sub log_msg
{
    my (%opts)          = @_;
    my $level           = $opts{level}          || 'INFO';      #  INFO, WARN, FAIL, PASS, DBUG
    my $msg             = $opts{msg}            || '';
    my $color_prefix    = $opts{color}          || '';
    my $no_console      = $opts{no_console}     || 0;

    $msg =~ s/\n+$//;   # remove newlines

    # #
    #   Build timestamp for FILE logs only
    # #

    my ($sec,$min,$hour,$mday,$mon,$year) = localtime();
    $mon  += 1;
    $year += 1900;
    $year %= 100;
    my $timestamp = sprintf "%02d/%02d/%02d %02d:%02d:%02d",
        $mon, $mday, $year, $hour, $min, $sec;

    # #
    #   Log › Debug & RETRESPONSE › Console Output
    # #

    if ( ( $FLG_DEBUG || $FLG_RETRESPONSE ) && !$no_console )
    {
        my $tag = sprintf("   %s %-5s%s", $color_prefix, $level, $end);
        my $txt = sprintf("%s  %s%s", $greym, $msg, $end);

        printf "%-44s %-65s\n", $tag, $txt;
    }

    # #
    #   Log › Daemon › File Output
    # #

    if ( !$FLG_DEBUG )
    {
        # #
        #   Always log clean text to daemon log
        # #

        open my $dh, '>>', $log_file_daemon;

        # #
        #   Strip ANSI color codes for clean file logs
        # #
    
        my $plain_msg = $msg;                       # start with message
        $plain_msg =~ s/\e\[[\d;]*m//g;             # remove ANSI codes
        my $clean_color = $color_prefix;           
        $clean_color =~ s/\e\[[\d;]*m//g;           # remove ANSI codes from color prefix
        $plain_msg = $clean_color . $plain_msg;     # prepend clean color label

        print $dh "$timestamp | [$level] $plain_msg\n";
        close $dh;
    }

    # #
    #   Log › Debug › File Output
    # #

    if ( $FLG_DEBUG )
    {
        open my $fh, '>>', $log_file_debug;
        print $fh "$timestamp | [$level] $msg\n";
        close $fh;
    }
}

# #
#   Declare › Helper › Daemon Log
#   
#   @usage                  log_daemon("Some daemon message\n");
#   @returns                null
#                           prints message to log_daemon 
# #

sub log_daemon
{
    my ($msg) = @_;
    log_msg(
        msg         => $msg,
        level       => 'INFO',
        color       => $bgInfo,
        no_console  => 1       # never print daemon logs to console
    );
}

# #
#   Declare › Helper › Debug Logging (w/ optional daemon logging route)
#   
#   @usage                  log_dbg( "This is a debug message" );
#   @returns                null
# #

sub log_dbg
{
    my ($msg) = @_;

    my ($tag, $rest) = $msg =~ /^\[(\w+)\]:\s*(.*)/;
    $tag ||= 'DBUG';            # fallback
    $rest ||= $msg;             # if no match, use whole message

    my $color = $bgDebug;
    if    ( $tag eq 'INFO' )    { $color = $bgInfo }
    elsif ( $tag eq 'PASS' )    { $color = $bgOk }
    elsif ( $tag eq 'WARN' )    { $color = $bgWarn }
    elsif ( $tag eq 'DNGR' )    { $color = $bgError }
    elsif ( $tag eq 'FAIL' )    { $color = $bgDanger }
    elsif ( $tag eq 'DBUG' )    { $color = $bgDebug }
    elsif ( $tag eq 'VRBO' )    { $color = $bgVerbose }

    log_msg(
        msg   => $rest,
        level => $tag,
        color => $color
    );
}

# #
#   Load › Settings
#   
#   Grabs a few csf config settings we'll need in order to confirm the release channel
#   to use when downloading updates.
# # 

if ( -e $config_file )
{
    open my $fh, '<', $config_file or die "Cannot open $config_file: $!";
    while (<$fh>)
    {
        chomp;
        s/#.*$//;              # remove comments
        next if /^\s*$/;       # skip empty lines
        if (/^\s*(\w+)\s*=\s*["']?([^"']+)["']?/)
        {
            $config_vals{$1} = $2;
        }
    }
    close $fh;
}

# #
#   Declare › Flags
#   
#       -r, --response          Run in foreground and show logs. Useful with bash scripts.
#                                   › sudo perl /etc/cron.daily/csget --response
#   
#       -n, --nodaemon          Skips random sleep interval; processes immediately
#                                   › sudo perl /etc/cron.daily/csget --nodaemon
#   
#       -k, --kill              Kills all processes associated with csget.
#                                   › sudo perl /etc/cron.daily/csget --kill
#   
#       -l, --list              Lists all csget processes except this command.
#                                   › sudo perl /etc/cron.daily/csget --list
#       
#       -d, --diag              Show diagnostic information.
#                                   › sudo perl /etc/cron.daily/csget --diag
#   
#       -D, --debug             Show verbose logs and additional details; disables forked child process daemonization.
#                                   › sudo perl /etc/cron.daily/csget --debug
#   
#       -v, --version           Show version information about csget and csf.
#                                   › sudo perl /etc/cron.daily/csget --version
#   
#       -h, --help              Returns help information.
#                                   › sudo perl /etc/cron.daily/csget --help
# #

foreach my $arg ( @ARGV )
{
    if ( $FLG_DEBUG )
    {
        log_dbg( "[DBUG]: Passing arg [ ${peach}\"$arg\"${greym} ]" );
    }

    # #
    #   @usage          sudo perl /etc/cron.daily/csget --response
    #                   Run in foreground and show logs. Useful with bash scripts.
    # #

    if ( $arg =~ /^--response$|^--resp$|^-r$/ )
    {
        $FLG_RETRESPONSE = 1;
    }

    # #
    #   @usage          sudo perl /etc/cron.daily/csget --nodaemon
    #                   If specified, csget runs instantly, not on a random timer.
    # #

    elsif ( $arg =~ /^--nosleep$|^-n$|^--nodaemon$|^-N$/ )
    {
        $FLG_NOSLEEP = 1;
    }

    # #
    #   @usage          sudo perl /etc/cron.daily/csget --kill
    #                   Kills all processes associated with csget.
    # #

    elsif ( $arg =~ /^--kill$|^-k$/ )
    {

        my @pids = fetch_csget_pids();

        if ( @pids )
        {
            kill 9, @pids;
            print "CSGet processes terminated: @pids\n";
        }
        else
        {
            print "No CSGet processes found to kill.\n";
        }
    
        exit 0;
    }

    # #
    #   @usage          sudo perl /etc/cron.daily/csget --list
    #                   Lists all csget processes except this command.
    # #

    elsif ( $arg =~ /^--list$|^-l$/ )
    {
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
            print "   ${bluel}CSGet processes currently running:${end}\n";
            print "   ${greyd}The following is a list of processes attached to CSGet${end}\n\n";
            print "   @lines";
        }
        else
        {
            print "   ${greenl}No CSGet processes found.${end}\n";
            print "   ${greyd}No CSGet process are currently running. To start CSGet, ensure the file is in:${end}\n";
            print "   ${magental}    $proc_path${end}\n\n";

            print "   ${greyd}To run CSGet once, execute the command${end}\n";
            print "   ${bluel}    \$ ${greend} sudo ${magental}$proc_path ${yellowl}--nodaemon${end}\n\n";

            print "   ${greyd}To start CSGet cron, execute the command${end}\n";
            print "   ${bluel}    \$ ${greend} sudo ${magental}$proc_path${end}\n\n";

            print "   ${greyd}For a list of command flags and descriptions, execute:${end}\n";
            print "   ${bluel}    \$ ${greend} sudo ${magental}$proc_path ${yellowl}--help${end}\n\n";
        }

        print "\n";

        exit 0;
    }

    # #
    #   @usage          sudo perl /etc/cron.daily/csget --diag
    #                   Show diagnostic information.
    # #

    elsif ( $arg =~ /^--diag$|^--diagnostic$|^-d$/ )
    {

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

        if ( -e $config_file )
        {
            $configStatus = "${greenl}(Found)${end}";
        }
        else
        {
            $configStatus = "${redl}(Not Found)${end}";
        }

        # #
        #   Output
        # #

        print "\n";
        print "   ${yellowl}${app_name}${end}\n";
        print "   ${greyd}${app_desc}${end}\n";
        print "   ${greyd}$app_repo${end}\n\n";
        printf "   %-*s %s\n", $col_width_left, "${greyd}Process Name", "${magental}${proc_name}${end}";
        printf "   %-*s %s\n", $col_width_left, "${greyd}Process Path", "${magental}${proc_path}${end}";
        printf "   %-*s %s\n", $col_width_left, "${greyd}Server URL", "${magental}${diagUrl}${end}";
        printf "   %-*s %s\n", $col_width_left, "${greyd}Fetch Package", "${magental}${diagMethod}${end}";
        printf "   %-*s %s\n", $col_width_left, "${greyd}Command (Base)", "${magental}${diagCmd}${end}";
        printf "   %-*s %s\n", $col_width_left, "${greyd}Command (Out)", "${magental}${diagOut}${end}";
        printf "   %-*s %s\n", $col_width_left, "${greyd}Config Path", "${magental}${config_file} ${configStatus}${end}";
        printf "   %-*s %s\n", $col_width_left, "${greyd}Log Folder", "${magental}${log_dir}${end}";
        printf "   %-*s %s\n", $col_width_left, "${greyd}Log Daemon", "${magental}${log_file_daemon}${end}";
        printf "   %-*s %s\n", $col_width_left, "${greyd}Log Debug", "${magental}${log_file_debug}${end}";
        print "\n";

        exit 0;
    }

    # #
    #   @usage          sudo perl /etc/cron.daily/csget --debug
    #                   Show verbose logs and additional details; disables forked child process daemonization.
    # #

    elsif ( $arg =~ /^--debug$|^-D$/ )
    {
        $FLG_DEBUG = 1;
        next;
    }

    # #
    #   @usage          sudo perl /etc/cron.daily/csget --version
    #                   Show version information about csget and csf.
    # #

    elsif ( $arg =~ /^--version$|^-v$/ )
    {

        if ( -e $version_file )
        {
            open my $fh, '<', $version_file
                or die "Cannot open $version_file: $!";
            my $version = <$fh>;       # read first line
            chomp $version;            # remove newline
            close $fh;

            print "\n";
            print "   ${yellowl}${app_name}${end}\n";
            print "   ${greyd}ConfigServer Security & Firewall v$version${end}\n";
            print "   ${greyd}${app_desc}${end}\n";
            print "   ${greyd}$app_repo${end}\n";
            print "\n";
        }
        else
        {
            print "   ${redl}CSF version file not found: $version_file${end}\n";
        }

        exit 0;
    }

    # #
    #   @usage          sudo perl /etc/cron.daily/csget --help
    #                   Returns help information
    # #

    elsif ( $arg =~ /^--help$|^-h$/ )
    {

        # #
        #   Output
        # #

        print "\n";
        print "   ${yellowl}${app_name}${end}\n";
        print "   ${greyd}${app_desc}${end}\n";
        print "   ${greyd}$app_repo${end}\n\n";

        printf STDERR "   %-5s %-40s\n", "${greyd}Syntax:${end}", "";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "${greyd}Command${end}                           ", "  ${magental}$proc_path${greyd} [ ${greym}--option ${greyd}[ ${yellowd}arg${greyd} ]${greyd} ]${end}";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "${greyd}Options${end}                           ", "  ${magental}$proc_path${greyd} [ ${greym}-h${greyd} | ${greym}--help${greyd} ]${end}";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "    ${greym}-A${end}                            ", "     ${white}required";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "    ${greym}-A...${end}                         ", "     ${white}required; multiple can be specified";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "    ${greym}[ -A ]${end}                        ", "     ${white}optional";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "    ${greym}[ -A... ]${end}                     ", "     ${white}optional; multiple can be specified";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "    ${greym}{ -A | -B }${end}                   ", "     ${white}one or the other; do not use both";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "${greyd}Examples${end}                          ", "  ${magental}$proc_path${end}";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "${greyd}${end}                                  ", "  ${magental}$proc_path${end} ${yellowl}--nodaemon${end}";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "${greyd}${end}                                  ", "  ${magental}$proc_path${end} ${yellowl}--debug${end}";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "${greyd}${end}                                  ", "  ${magental}$proc_path${end} ${yellowl}--nodaemon ${yellowl}--response${end}";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "${greyd}${end}                                  ", "  ${magental}$proc_path${end} ${yellowl}--diag${end}";
        printf STDERR "   %-5s %-30s %-40s\n", "    ", "${greyd}${end}                                  ", "  ${magental}$proc_path${end} ${yellowl}--list${end}";
        print STDERR "\n";
        printf STDERR "   %-5s %-40s\n", "${greyd}Options:${end}", "";
        printf STDERR "   %-5s %-81s %-40s\n", "    ", "${bluel}-r${greyd},${bluel}  --response ${yellowd}${end}                    ", "Run in foreground and show logs. Useful with bash scripts.${end}";
        printf STDERR "   %-5s %-81s %-40s\n", "    ", "${blued}  ${greyd} ${blued}           ${yellowd}${end}                      ", "    ${greyd}disables forked daemonization${end}";
        printf STDERR "   %-5s %-81s %-40s\n", "    ", "${bluel}-n${greyd},${bluel}  --nodaemon ${yellowd}${end}                    ", "Run task immediately, do not start on timed delay.${end}";
        printf STDERR "   %-5s %-81s %-40s\n", "    ", "${blued}  ${greyd} ${blued}           ${yellowd}${end}                      ", "    ${greyd}no forked daemonization${end}";
        printf STDERR "   %-5s %-81s %-40s\n", "    ", "${bluel}-k${greyd},${bluel}  --kill ${yellowd}${end}                        ", "Kills all processes associated with csget.${end}";
        printf STDERR "   %-5s %-81s %-40s\n", "    ", "${bluel}-l${greyd},${bluel}  --list ${yellowd}${end}                        ", "Lists all csget processes except this command.${end}";
        printf STDERR "   %-5s %-81s %-40s\n", "    ", "${bluel}-d${greyd},${bluel}  --diag ${yellowd}${end}                        ", "Show diagnostic information.${end}";
        printf STDERR "   %-5s %-81s %-40s\n", "    ", "${bluel}-D${greyd},${bluel}  --debug ${yellowd}${end}                       ", "Show verbose logs and additional details; disables forked child process daemonization.${end}";
        printf STDERR "   %-5s %-81s %-40s\n", "    ", "${blued}  ${greyd} ${blued}           ${yellowd}${end}                      ", "    ${greyd}disables forked daemonization${end}";
        printf STDERR "   %-5s %-81s %-40s\n", "    ", "${bluel}-v${greyd},${bluel}  --version ${yellowd}${end}                     ", "Show version information about csget and csf.${end}";
        printf STDERR "   %-5s %-81s %-40s\n", "    ", "${bluel}-h${greyd},${bluel}  --help ${yellowd}${end}                        ", "Show this help menu.${end}";
        print STDERR "\n";
        printf STDERR "   %-5s %-40s\n", "${greyd}Tips:${end}", "";
        printf STDERR "   %-5s %-10s %-40s\n", "    ", "${bluel}Run CSGet once${end}                    ", "${bluel}  \$ ${greend}sudo ${magental}$proc_path ${yellowl}--nodaemon${end}";
        printf STDERR "   %-5s %-10s %-40s\n", "    ", "${bluel}Start CSGet cron${end}                  ", "${bluel}  \$ ${greend}sudo ${magental}$proc_path${end}";
        printf STDERR "   %-5s %-10s %-40s\n", "    ", "${bluel}Run using perl (normal)${end}           ", "${bluel}  \$ ${greend}sudo perl ${magental}$proc_path${end}";
        printf STDERR "   %-5s %-10s %-40s\n", "    ", "${bluel}Run using perl (+w warnings)${end}      ", "${bluel}  \$ ${greend}sudo perl ${yellowl}-w ${magental}$proc_path${end}";
        printf STDERR "   %-5s %-10s %-40s\n", "    ", "${bluel}Run using perl (+d debugger)${end}      ", "${bluel}  \$ ${greend}sudo perl ${yellowl}-d ${magental}$proc_path${end}";
        printf STDERR "   %-5s %-10s %-40s\n", "    ", "${bluel}Run using perl (+d:Trace)${end}         ", "${bluel}  \$ ${greend}sudo perl ${yellowl}-d:Trace ${magental}$proc_path${end}";
        print "\n\n";

        exit 0;
    }

    # #
    #   @usage          sudo perl /etc/cron.daily/csget --randomBadFlag
    #                   Specified bad flag doesn't exist
    # #

    else
    {
        print "\n";
        print "   ${redl}Invalid argument: ${yellowl}$arg${end}\n";
        print "   ${greyd}Usage: ${bluel}sudo perl $proc_path ${greyd}[${yellowl} --debug ${greyd}|${yellowl} --kill ${greyd}|${yellowl} --list ${greyd}|${yellowl} --version ${greyd}|${yellowl} --nodaemon ${greyd}]${bluel}${end}\n";
        print "\n";
        exit 1;
    }
}

# #
#   Define › Debug Mode
# #

if ( $FLG_DEBUG )
{
    mkdir $log_dir unless -d $log_dir;

    open $log_dbg, '>>', $log_file_debug or die "Cannot open debug log: $!";
    select((select($log_dbg), $|=1)[0]);        # auto-flush

    my $script_path = `readlink -f $0`;
    chomp $script_path;

    log_dbg( "[DBUG]: csget debug enabled; logging to [ \"$log_dir\" ]" );
}

# #
#   Perl daemonization/fork block
#       sudo perl -w /etc/cron.daily/csget --nodaemon
#       sudo perl -d /etc/cron.daily/csget
#   
#   Parent exits				terminal / cron is free
#   Child continues 			runs in background
# #

unless ( $FLG_DEBUG || $FLG_RETRESPONSE )
{
    if ( my $pid = fork ) { exit 0; }               # parent
    elsif ( defined( $pid ) ) { $pid = $$; }        # child
    else { die "Unable to fork: $!"; }              # cannot fork

    chdir( "/" );
    close( STDIN );
    close( STDOUT );
    close( STDERR );
    open( STDIN,  "<", "/dev/null" );
    open( STDOUT, ">>", "$log_file_daemon" )
        or die "Cannot open STDOUT log: $!";
    open( STDERR, ">>", "$log_file_daemon" )
        or die "Cannot open STDERR log: $!";
}

# #
#   Always make sure log dir exists
# #

mkdir $log_dir unless -d $log_dir;

# #
#   Define › Welcome Print
# #

my $script_path = `readlink -f "$proc_path"`;
chomp( $script_path ); # remove trailing newline
log_daemon( "[INFO]: Found csget path: [$script_path]" );
log_daemon( "[INFO]: Daemon started with PID [ \"$$\" ]" );

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
    $get_cmd        = $fetch{ 'curl' };
    $get_method     = "curl";
}
elsif ( -e "/usr/bin/wget" )
{
    $get_cmd        = $fetch{ 'wget' };
    $get_method     = "wget";
}
elsif ( -e "/usr/bin/GET" )
{
    $get_cmd        = $fetch{ 'get' };
    $get_method     = "get";
}
else
{
    open( my $ERROR, ">", "/var/lib/configserver/error" );
    log_daemon( "[FAIL]: No download tool found: curl, wget, or get", $ERROR );
    close( $ERROR );
    exit 1;
}

log_dbg( "[PASS]: Found package [ ${greenl}\"$get_method\"${greym} ] using cmd [ ${greenl}\"$get_cmd\"${greym} ]" );

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
	$get_bin = "/usr/bin/GET -sd -t 120"
}

# #
#   Condition › No Source Version Found
#   
#   Originally, this function would unlink the cron
# #

if ( scalar( keys %versions ) == 0 )
{

    # unlink $0;

    log_dbg( "ERROR: No version files to fetch — aborting cron run" );

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
#   arg `--nodaemon`        › skip sleep (no background daemon)
#   arg `something else`	› sleep (create forked daemon process)
# #

unless ( $FLG_NOSLEEP )
{
    log_daemon( "[INFO]: Activating sleep mode" );
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

    log_dbg( "[INFO]: Connecting to server [ ${bluel}\"$server\"${greym} ]" );

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

        log_dbg( "[INFO]: Detected correct remote url as [ ${bluel}\"$url\"${greym} ]" );
    
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
                log_dbg( "[INFO]: Removed previous error file: ${bluel}$versions{ $version }.error${greym}" );
            }

            # #
            #   Channel › Insiders
            #   Get sponsor license key from CSF config /etc/csf/csf.conf
            # #

            if ( ( $config_vals{SPONSOR_RELEASE_INSIDERS} // 0 ) == 1 && ( $config_vals{SPONSOR_LICENSE} // '' ) ne '' && $version eq "/csf/version.txt" )
            {
                $url .= "?channel=insiders&license=$config_vals{ SPONSOR_LICENSE }";
                log_dbg( "[PASS]: Using release channel [ ${greenl}\"insiders\"${greym} ] from server [ ${greenl}\"$url\"${greym} ]" );
            }

            # #
            #   Channel › Stable
            # #

            else
            {
                log_dbg( "[PASS]: Using release channel [ ${greenl}\"stable\"${greym} ] from server [ ${greenl}\"$url\"${greym} ]" );
            }

            # #
            #   Prepare download
            # #

            log_dbg( "[INFO]: Preparing to download remote [ ${bluel}\"$url\"${greym} ] to local [ ${bluel}\"$versions{ $version }\"${greym} ]" );

            # #
            #   Method: None
            #   
            #   Backup check to ensure we get the proper method.
            # #

            if ( $get_method eq "none" )
            {
                log_dbg( "[FAIL]: GET [ ${redl}\"$get_method\"${greym} ] bad method; aborting process" );
                exit 0;

            }
            elsif ( $get_method eq "get" )
            {
                # #
                #   GET prints to stdout; redirect stdout -> file, stderr -> .error
                # #
            
                my $cmdline = "$get_cmd $url > $versions{ $version } 2> $versions{ $version }.error";
                log_dbg( "[INFO]: Download file using [ ${bluel}\"$get_method\"${greym} ] with cmd [ ${bluel}\"$cmdline\"${greym} ]" );

                my $raw     = system( $cmdline );           # Raw return from system()
                my $exit    = $raw >> 8;                    # Real exit code from raw return; shift right 8 bytes

                log_dbg( "[INFO]: Download with [ ${bluel}\"$get_method\"${greym} ] returned raw response [ ${bluel}\"$raw\"${greym} ]; exit = [ ${bluel}\"$exit\"${greym} ]" );

                # #
                #   Success only if exit == 0 AND file exists and has content
                # #
            
                if ( $exit == 0 && -s $versions{ $version } )
                {
                    $get_status = 0;                            # success

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
        
                    $get_status = ( $exit != 0 ) ? $exit : 1;

                    log_dbg( "[WARN]: GET [ ${yellowl}\"$get_method\"${greym} ] failed or produced empty file; status set to [ ${yellowl}\"$get_status\"${greym} ]" );
                }
            }

            # #
            #   Method: curl / wget
            #   
            #   These write to file when invoked with -o/-O; system() exit is reliable
            # #

            else
            {
                my $cmdline = "$get_cmd $versions{ $version } $url";
                log_dbg( "[INFO]: Download file using [ ${bluel}\"$get_method\"${greym} ] with cmd [ ${bluel}\"$cmdline\"${greym} ]" );

                my $raw     = system( $cmdline );
                my $exit    = $raw >> 8;

                log_dbg( "[INFO]: Download with [ ${bluel}\"$get_method\"${greym} ] returned raw response [ ${bluel}\"$raw\"${greym} ]; exit = [ ${bluel}\"$exit\"${greym} ]" );

                # Normalize to 0 (success) / non-zero (failure)
                $get_status = $exit == 0 ? 0 : $exit;
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

            my %STATUS_TEXT = (
                0 => 'Success',
                1 => 'Connection Error',
                2 => 'Timeout',
                3 => 'Invalid Response',
                4 => 'Permission Denied',
                5 => 'Unknown Error',
            );

            my $status_code = $get_status;
            my $status_text = $STATUS_TEXT{$status_code} // 'Undefined Status';

            log_dbg( "[INFO]: Download with [ ${bluel}\"$get_method\"${greym} ] returned status [ ${bluel}\"$status_text ($get_status)\"${greym} ]"  );

            if ( $get_status )
            {
				if ( $get_bin ne "" )
                {
					open ( my $ERROR, ">", $versions{ $version }.".error" );
                    log_daemon( "[FAIL]: [ \"$get_method\" ]: $server$version -", $ERROR );
					close ( $ERROR );
					my $GETstatus = system( "$get_bin $server$version >> $versions{ $version }".".error" );
				}
                else
                {
					open ( my $ERROR, ">", $versions{ $version }.".error" );
                    log_daemon( "[FAIL]: [ ${redl}\"$get_method\"${greym} ]: Failed to retrieve latest version from ConfigServer", $ERROR );
					close ( $ERROR );
				}
            }
            else
            {
                log_dbg( "[PASS]: Successfully downloaded csf version from [ ${greenl}\"$url\"${greym} ] to file [ ${greenl}\"$versions{ $version }\"${greym} ]" );
            }

            # #
            #   Verify the downloaded file contains a valid version
            # #

            if ( -s $versions{ $version } )        # file exists and has content
            {
                open my $fh, '<', $versions{ $version } or do
                {
                    log_dbg( "[FAIL]: Cannot open [ ${redl}\"$versions{ $version }\" ${greym} ] for reading: [ ${redl}\"$!\" ${greym} ]" );
                    next;
                };

                my $line = <$fh>;                  # read first line
                chomp $line;
                close $fh;

                # regex: one or more digits, followed by 1-3 groups of .digits
                if ( $line =~ /^\d+(\.\d+){0,3}$/ )
                {
                    log_dbg( "[PASS]: File [ ${greenl}\"$versions{ $version }\" ${greym} ] contains valid version: [ ${greenl}\"$line\" ${greym} ]" );
                    $get_status = 0;                # mark as passed
                }
                else
                {
                    log_dbg( "[WARN]: File [ ${yellowl}\"$versions{ $version }\" ${greym} ] does NOT contain a valid version: [ ${yellowl}\"$line\" ${greym} ]" );
                    $get_status = 1;                # mark as failed
                }
            }
            else
            {
                log_dbg( "[FAIL]: File [ ${redl}\"$versions{ $version }\" ${greym} ] is empty or missing" );
                $get_status = 1;
            }

            # #
            #   Version Check (Optional)
            #   
            #   After the newest remote CSF version is downloaded and placed in /var/lib/configserver/csf.txt;
            #   compare the remote version of CSF available (/var/lib/configserver/csf.txt) with the current local version (/etc/csf/version.txt).
            #   Return if an update is available.
            # #

            my $file_ver_current    = "${version_file}";            # /etc/csf/version.txt
            my $file_ver_remote     = $versions{ $version };        # /var/lib/configserver/csf.txt

            if ( -r $file_ver_current )
            {
                log_dbg( "[INFO]: File [ ${bluel}\"$file_ver_current\"${greym} ] is readable" );

                my $ver_current     = version_read( $file_ver_current );
                my $ver_remote      = version_read( $file_ver_remote );

                if ( version_is_newer( $ver_remote, $ver_current ) )
                {
                    log_dbg( "[PASS]: Update available! Current Version [ ${greenl}\"$ver_current\"${greym} ] | Newest Version [ ${greenl}\"$ver_remote\"${greym} ]" );
                }
                else
                {
                    log_dbg( "[INFO]: No update available. Current Version [ ${bluel}\"$ver_current\"${greym} ] | Newest Version [ ${bluel}\"$ver_remote\"${greym} ]" );
                }
            }
            else
            {
                log_dbg( "[FAIL]: Version file ${redl}${file_ver_current}${greym} not readable. Skipping initial version check." );
            }

            # #
            #   Response
            #   
            #   If running from external script such as bash; status will return if job
            #   was successful or not.
            #   
            #   @return         0   success
            #                   1   failure
            #   
            #   @example        "$CSF_CRON_CSGET_DEST" --nodaemon --response
            #                   CSF_CRON_CSGET_STATUS=$?
            #   
            #                   if [ "$CSF_CRON_CSGET_STATUS" -eq 0 ]; then
            #                       ok "    CSGET daemon ${greenl}${CSF_CRON_CSGET_DEST}${greym} successfully ran"
            #                   else
            #                       warn "    CSGET daemon ${yellowl}${CSF_CRON_CSGET_DEST}${greym} failed to run"
            #                   fi
            # #

            if ( $FLG_RETRESPONSE )
            {
                if ( $get_status == 0 )
                {
                    log_dbg( "[PASS]: Job has completed ${greenl}successfully${greym}. File [ ${greenl}\"$versions{ $version }\" ${greym} ] contains good data." );
                    exit 0;     # success
                }
                else
                {
                    log_dbg( "[FAIL]: Job has ${redl}failed${greym} to fetch version from CSF network. Try running script again." );
                    exit 1;     # failure
                }
            }
        }
    }
}
