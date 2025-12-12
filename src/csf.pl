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
#   @updated            12.12.2025
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
# start main
use strict;
use lib '/usr/local/csf/lib';
use Fcntl qw(:DEFAULT :flock);
use File::Basename;
use IO::Handle;
use IPC::Open3;
use Net::CIDR::Lite;
use Socket;
use ConfigServer::Config;
use ConfigServer::Slurp qw(slurp);
use ConfigServer::CheckIP qw(checkip cccheckip);
use ConfigServer::Ports;
use ConfigServer::URLGet;
use ConfigServer::Sanity qw(sanity);
use ConfigServer::ServerCheck;
use ConfigServer::ServerStats;
use ConfigServer::Service;
use ConfigServer::Messenger;
use ConfigServer::RBLCheck;
use ConfigServer::GetEthDev;
use ConfigServer::Sendmail;
use ConfigServer::LookUpIP qw(iplookup);

umask(0177);

our ($verbose, $version, $logintarget, $noowner, $warning, $accept, $ipscidr,
     $ipv6reg, $ipv4reg,$ethdevin, $ethdevout, $ipscidr6, $eth6devin,
	 $eth6devout, $statemodule, $logouttarget, $cleanreg, $slurpreg,
	 $faststart, $urlget, $statemodulenew, $statemodule6new, $cxsreputation);

our ($IPTABLESLOCK, $CSFLOCKFILE);

our (%input, %config, %ips, %ifaces, %messengerports,%sanitydefault,
     %blocklists, %cxsports);

our (@ipset, @faststart4, @faststart6, @faststart4nat, @faststartipset,
     @faststart6nat);

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
my $bgBlueDark 		= "${esc}[1;38;5;15;48;5;25m";   	# white on dark blue
my $bgYellowDark = "${esc}[1;38;5;15;48;5;172m";    	# white on dark yellow

# #
#   Logs › Prepare
#   
#   Called by:
#       log_csf
# #

sub log_prepare
{
    my (%opts)          = @_;
    my $level           = $opts{level}          || 'INFO';      #  INFO, WARN, FAIL, PASS, DBUG
    my $msg             = $opts{msg}            || '';
    my $color_prefix    = $opts{color}          || '';
    my $label      		= $opts{label}     || 0;

    $msg =~ s/\n+$//;

    my $tag = sprintf("   %s %-5s%s", $color_prefix, $level, $end);
    my $txt = sprintf("%s  %s%s", $greym, $msg, $end);

    # #
	#	label (no tag)
	# #

    if ($label)
	{
        printf "%-20s %-65s\n", "", $txt;
        return;
    }

	# #
	#	Normal Message
	# #

    printf "%-44s %-65s\n", $tag, $txt;
}


# #
#   Declare › Helper › Daemon Log
#   
#   @usage                  log_csf("Some daemon message\n");
#   @returns                null
# #

sub log_label
{
    my ($msg) = @_;
    log_prepare(
        msg         => $msg,
        label  		=> 1
    );
}

sub log_info
{
    my ($msg) = @_;
    log_prepare(
        msg         => $msg,
        level       => 'INFO',
        color       => $bgInfo,
        no_console  => 1
    );
}

sub log_warn {
    my ($msg) = @_;
    log_prepare(
        msg     => " $msg",
        level   => 'WARN',
        color   => $bgWarn,
        no_console => 1
    );
}

sub log_fail {
    my ($msg) = @_;
    log_prepare(
        msg     => $msg,
        level   => 'FAIL',
        color   => $bgError,
        no_console => 1
    );
}

sub log_pass {
    my ($msg) = @_;
    log_prepare(
        msg     => $msg,
        level   => 'PASS',
        color   => $bgOk,
        no_console => 1
    );
}

sub log_debug {
    my ($msg) = @_;
    log_prepare(
        msg     => $msg,
        level   => 'DBUG',
        color   => $bgDebug,
        no_console => 1
    );
}


$version = &version;

$ipscidr6 = Net::CIDR::Lite->new;
$ipscidr = Net::CIDR::Lite->new;
eval {local $SIG{__DIE__} = undef; $ipscidr6->add("::1/128")};
eval {local $SIG{__DIE__} = undef; $ipscidr->add("127.0.0.0/8")};

$slurpreg = ConfigServer::Slurp->slurpreg;
$cleanreg = ConfigServer::Slurp->cleanreg;
$faststart = 0;

&process_input;
&load_config;

$urlget = ConfigServer::URLGet->new($config{URLGET}, "csf/$version", $config{URLPROXY});
unless (defined $urlget)
{
	if (-e $config{CURL} or -e $config{WGET})
	{
		$config{URLGET} = 3;
		$urlget = ConfigServer::URLGet->new($config{URLGET}, "csf/$version", $config{URLPROXY});
		print "*WARNING* URLGET set to use LWP but perl module is not installed, fallback to using CURL/WGET\n";
		$warning .= "*WARNING* URLGET set to use LWP but perl module is not installed, fallback to using CURL/WGET\n";
	}
	else
	{
		$config{URLGET} = 1;
		$urlget = ConfigServer::URLGet->new($config{URLGET}, "csf/$version", $config{URLPROXY});
		print "*WARNING* URLGET set to use LWP but perl module is not installed, reverting to HTTP::Tiny\n";
		$warning .= "*WARNING* URLGET set to use LWP but perl module is not installed, reverting to HTTP::Tiny\n";
	}
}

if ( ( -e "/etc/csf/csf.disable" ) and ( $input{command} ne "--enable" ) and ( $input{command} ne "-e" ) )
{

	log_warn( "CSF and LFD have been ${redl}disabled${greym}! Use ${yellowl}'csf -e'${greym} to re-enable" );

	# #
	#   Bypass warning for certain commands
	# #

	my %valid_cmds = map { $_ => 1 } (
		"-v",      "--version",
		"-c",      "--check",
		"-p",      "--ports",
		"-h",      "--help",
		"-u",      "--update",
		"-uf",
		"-f",      "--flush",
		"--profile",
		"-ap",     "--addport",
		"-rp",     "--removeport",
		"-lp",     "--listports",
	);

	my $ok = $valid_cmds{ $input{command} } ? 1 : 0;

	unless ( $ok )
	{
		exit 1;
	}
}

unless (-e $config{IPTABLES})
{
	&error(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} (iptables binary location) does not exist!")
}

if ($config{IPV6} and !(-e $config{IP6TABLES}))
{
	&error(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} (ip6tables binary location) does not exist!")
}

if ((-e "/etc/csf/csf.error") and ($input{command} ne "--startf") and ($input{command} ne "-sf") and ($input{command} ne "-q") and ($input{command} ne "--startq") and ($input{command} ne "--start") and ($input{command} ne "-s") and ($input{command} ne "--restart") and ($input{command} ne "-r") and ($input{command} ne "--enable") and ($input{command} ne "-e"))
{
	open (my $IN, "<", "/etc/csf/csf.error");
	flock ($IN, LOCK_SH);
	my $error = <$IN>;
	close ($IN);
	chomp $error;
	print "You have an unresolved error when starting csf:\n$error\n\nYou need to restart csf successfully to remove this warning, or delete /etc/csf/csf.error\n";
	exit 1;
}

unless ($input{command} =~ /^--(stop|initdown|initup)$/)
{
	if (-e "/var/lib/csf/csf.4.saved") {unlink "/var/lib/csf/csf.4.saved"}
	if (-e "/var/lib/csf/csf.4.ipsets") {unlink "/var/lib/csf/csf.4.ipsets"}
	if (-e "/var/lib/csf/csf.6.saved") {unlink "/var/lib/csf/csf.6.saved"}
}

# #
#	Command List
# #

if ( ( $input{command} eq "--status" ) 			or ( $input{command} eq "-l" ) ) 	{ &dostatus }
elsif ( ( $input{command} eq "--status6" ) 		or ( $input{command} eq "-l6" ) ) 	{ &dostatus6 }
elsif ( ( $input{command} eq "--version" ) 		or ( $input{command} eq "-v" ) ) 	{ &doversion }
elsif ( ( $input{command} eq "--stop" )			or ( $input{command} eq "-f" ) ) 	{ &csflock("lock" );&dostop(0);&csflock("unlock" ) }
elsif ( ( $input{command} eq "--startf" ) 		or ( $input{command} eq "-sf" ) ) 	{ &csflock("lock" );&dostop(1);&dostart;&csflock("unlock" ) }
elsif ( ( $input{command} eq "--start" ) 		or ( $input{command} eq "-s" ) or ( $input{command} eq "--restart" ) or ( $input{command} eq "-r" ) ) {if ($config{LFDSTART}) {&lfdstart} else {&csflock("lock" );&dostop(1);&dostart;&csflock("unlock" )}}
elsif ( ( $input{command} eq "--startq" ) 		or ( $input{command} eq "-q" ) ) 	{ &lfdstart }
elsif ( ( $input{command} eq "--restartall" ) 	or ( $input{command} eq "-ra" ) ) 	{ &dorestartall }
elsif ( ( $input{command} eq "--add" ) 			or ( $input{command} eq "-a" ) ) 	{ &doadd }
elsif ( ( $input{command} eq "--deny" )			or ( $input{command} eq "-d" ) ) 	{ &dodeny }
elsif ( ( $input{command} eq "--denyrm" ) 		or ( $input{command} eq "-dr" ) ) 	{ &dokill }
elsif ( ( $input{command} eq "--denyf" ) 		or ( $input{command} eq "-df" ) ) 	{ &dokillall }
elsif ( ( $input{command} eq "--addrm" ) 		or ( $input{command} eq "-ar" ) ) 	{ &doakill }
elsif ( ( $input{command} eq "--update" ) 		or ( $input{command} eq "-u" ) or ( $input{command} eq "-uf" ) ) { &doupdate }
elsif ( ( $input{command} eq "--disable" ) 		or ( $input{command} eq "-x" ) ) 	{ &csflock("lock" );&dodisable;&csflock("unlock" ) }
elsif ( ( $input{command} eq "--enable" ) 		or ( $input{command} eq "-e" ) ) 	{ &csflock("lock" );&doenable;&csflock("unlock" ) }
elsif ( ( $input{command} eq "--check" ) 		or ( $input{command} eq "-c" ) ) 	{ &docheck }
elsif ( ( $input{command} eq "--grep" )			or ( $input{command} eq "-g" ) ) 	{ &dogrep }
elsif ( ( $input{command} eq "--iplookup" )		or ( $input{command} eq "-i" ) ) 	{ &doiplookup }
elsif ( ( $input{command} eq "--temp" )			or ( $input{command} eq "-t" ) ) 	{ &dotempban }
elsif ( ( $input{command} eq "--temprm" ) 		or ( $input{command} eq "-tr" ) ) 	{ &dotemprm }
elsif ( ( $input{command} eq "--temprma" ) 		or ( $input{command} eq "-tra" ) ) 	{ &dotemprma }
elsif ( ( $input{command} eq "--temprmd" ) 		or ( $input{command} eq "-trd" ) ) 	{ &dotemprmd }
elsif ( ( $input{command} eq "--tempdeny" )		or ( $input{command} eq "-td" ) ) 	{ &dotempdeny }
elsif ( ( $input{command} eq "--tempallow" ) 	or ( $input{command} eq "-ta" ) ) 	{ &dotempallow }
elsif ( ( $input{command} eq "--tempf" ) 		or ( $input{command} eq "-tf" ) ) 	{ &dotempf }
elsif ( ( $input{command} eq "--mail" )			or ( $input{command} eq "-m" ) ) 	{ &domail }
elsif ( ( $input{command} eq "--cdeny" ) 		or ( $input{command} eq "-cd" ) ) 	{ &doclusterdeny }
elsif ( ( $input{command} eq "--ctempdeny" ) 	or ( $input{command} eq "-ctd" ) ) 	{ &doclustertempdeny }
elsif ( ( $input{command} eq "--callow" ) 		or ( $input{command} eq "-ca" ) ) 	{ &doclusterallow }
elsif ( ( $input{command} eq "--ctempallow" ) 	or ( $input{command} eq "-cta" ) ) 	{ &doclustertempallow }
elsif ( ( $input{command} eq "--crm" ) 			or ( $input{command} eq "-cr" ) ) 	{ &doclusterrm }
elsif ( ( $input{command} eq "--carm" )			or ( $input{command} eq "-car" ) ) 	{ &doclusterarm }
elsif ( ( $input{command} eq "--cignore" ) 		or ( $input{command} eq "-ci" ) ) 	{ &doclusterignore }
elsif ( ( $input{command} eq "--cirm" )			or ( $input{command} eq "-cir" ) ) 	{ &doclusterirm }
elsif ( ( $input{command} eq "--cping" ) 		or ( $input{command} eq "-cp" ) ) 	{ &clustersend( "PING" ) }
elsif ( ( $input{command} eq "--cgrep" ) 		or ( $input{command} eq "-cg" ) ) 	{ &doclustergrep }
elsif ( ( $input{command} eq "--cconfig" ) 		or ( $input{command} eq "-cc" ) ) 	{ &docconfig }
elsif ( ( $input{command} eq "--cfile" ) 		or ( $input{command} eq "-cf" ) ) 	{ &docfile }
elsif ( ( $input{command} eq "--crestart" )		or ( $input{command} eq "-crs" ) ) 	{ &docrestart }
elsif ( ( $input{command} eq "--watch" ) 		or ( $input{command} eq "-w" ) ) 	{ &dowatch }
elsif ( ( $input{command} eq "--logrun" ) 		or ( $input{command} eq "-lr" ) ) 	{ &dologrun }
elsif ( ( $input{command} eq "--ports" ) 		or ( $input{command} eq "-p" ) ) 	{ &doports }
elsif ( ( $input{command} eq "--addport" ) 		or ( $input{command} eq "-ap" ) ) 	{ &portAdd }
elsif ( ( $input{command} eq "--removeport" ) 	or ( $input{command} eq "-rp" ) ) 	{ &portRemove }
elsif ( ( $input{command} eq "--listports" ) 	or ( $input{command} eq "-lp" ) ) 	{ &portsList }
elsif ( $input{command} eq "--cloudflare" ) 	{ &docloudflare }
elsif ( $input{command} eq "--graphs" ) 		{ &dographs }
elsif ( $input{command} eq "--lfd" ) 			{ &dolfd }
elsif ( $input{command} eq "--rbl" ) 			{ &dorbls }
elsif ( $input{command} eq "--initup" ) 		{ &doinitup }
elsif ( $input{command} eq "--initdown" ) 		{ &doinitdown }
elsif ( $input{command} eq "--profile" ) 		{ &doprofile }
elsif ( $input{command} eq "--mregen" ) 		{ &domessengerv2 }
elsif ( $input{command} eq "--trace" ) 			{ &dotrace }
elsif ( ( $input{command} eq "--insiders" ) or ( $input{command} eq "-in" ) ) { &doinsiders }
else { &dohelp }

# #
#	Warning › TESTING (Enabled)
#	
#	End-user should not have testing mode enabled; throw warning.
# #

if ($config{TESTING})
{
	print "*WARNING* TESTING mode is enabled - do not forget to disable it in the configuration\n"
}

if ($config{AUTO_UPDATES})
{
	unless (-e "/etc/cron.d/csf_update") {&autoupdates}
}
elsif (-e "/etc/cron.d/csf_update")
{
	unlink "/etc/cron.d/csf_update"
}

# #
#	Warning › Startup
# #

if (($input{command} eq "--start") or ($input{command} eq "-s") or ($input{command} eq "--restart") or ($input{command} eq "-r") or ($input{command} eq "--restartall") or ($input{command} eq "-ra"))
{
	if ($warning)
	{
		print $warning
	}

	foreach my $key ( keys %config )
	{
		my ( $insane,$range,$default ) = sanity( $key,$config{$key} );
		if ( $insane )
		{
			log_warn( "${yellowl}$key${greym} sanity check. ${yellowl}$key = $config{$key}${greym}" );
			log_label( "Recommended range: $range (Default: $default)${greym}" )
		}
	}

	unless ( $config{RESTRICT_SYSLOG} )
	{
		log_warn( "${yellowl}RESTRICT_SYSLOG${greym} is disabled. See SECURITY WARNING in ${yellowl}/etc/csf/csf.conf${greym}" );
	}

	# #
	#	Warning › LF_MODSEC_PERM (Recommended)
	#	
	#	Ensure the end-user understands the reprocussions of setting LF_MODSEC_PERM too low.
	#	Send a warning if setting is below recommended.
	# #

	my $lfmodsec_threshold_warn = 3600;
	if ( $config{LF_MODSEC_PERM} && $config{LF_MODSEC_PERM} =~ /^\d+$/ )
	{
		if ( $config{LF_MODSEC_PERM} < $lfmodsec_threshold_warn && $config{LF_MODSEC_PERM} > 1 )
		{
			print "*WARNING* LF_MODSEC_PERM is set to $config{LF_MODSEC_PERM} seconds.\n";
			print "This is extremely short and may not effectively block attackers.\n";
			print "Recommended: \"1\" (permanent) or \"3600\" (1 hour)\n";
		}
	}
}

exit 0;

# #
#   csflock › Acquire or release CSF lock
#	
#   Manages the csf.lock file to prevent concurrent CSF operations.
#   When called with "lock", it opens the lockfile and obtains an
#   exclusive non-blocking lock; otherwise, it releases it.
#	
#   @param      lock    string      "lock" to acquire, anything else to release
#   @return     void
# #

sub csflock
{
	my $lock = shift;
	if ($lock eq "lock")
	{
		sysopen ($CSFLOCKFILE, "/var/lib/csf/csf.lock", O_RDWR | O_CREAT) or die ("Error: Unable to open csf lock file: $!");
		flock ($CSFLOCKFILE, LOCK_EX | LOCK_NB) or die "Error: csf is being restarted, try again in a moment: $!";
	}
	else
	{
		close ($CSFLOCKFILE);
	}

	return;
}

# #
#   Loads and initializes all CSF config values, imports optional modules,
#   prepares blocklists, sets logging/accept modes, and verifies required
#   system binaries before firewall rules are built.
#	
#   @return     void
# #

sub load_config
{
	my $config = ConfigServer::Config->loadconfig();
	%config = $config->config;
	my %configsetting = $config->configsetting;
	$ipv4reg = $config->ipv4reg;
	$ipv6reg = $config->ipv6reg;
	$warning .= $config->{warning};

	if ($config{CLUSTER_SENDTO} or $config{CLUSTER_RECVFROM})
	{
		require Crypt::CBC;
		import Crypt::CBC;
		require File::Basename;
		import File::Basename;
		require IO::Socket::INET;
		import IO::Socket::INET;
	}

	if ($config{CF_ENABLE}) {
		require ConfigServer::CloudFlare;
		import ConfigServer::CloudFlare;
	}

	$verbose = "";
	if ($config{VERBOSE} or $config{DEBUG} >= 1) {$verbose = "-v"}

	$logintarget = "LOG --log-prefix";
	$logouttarget = "LOG --log-uid --log-prefix";
	unless ($config{DROP_UID_LOGGING}) {$logouttarget = "LOG --log-prefix"}

	$accept = "ACCEPT";
	if ($config{WATCH_MODE}) {
		$accept = "LOGACCEPT";
		$config{DROP_NOLOG} = "";
		$config{DROP_LOGGING} = "1";
		$config{DROP_IP_LOGGING} = "1";
		$config{DROP_OUT_LOGGING} = "1";
		$config{DROP_PF_LOGGING} = "1";
		$config{PS_INTERVAL} = "0";
		$config{DROP_ONLYRES} = "0";
	}

	if ($config{MESSENGER}) {
		foreach my $port (split(/\,/,$config{MESSENGER_HTTPS_IN})) {$messengerports{$port} = 1}
		foreach my $port (split(/\,/,$config{MESSENGER_HTML_IN})) {$messengerports{$port} = 1}
		foreach my $port (split(/\,/,$config{MESSENGER_TEXT_IN})) {$messengerports{$port} = 1}
	}
	
	$statemodule = "-m state --state";
	if ($config{USE_CONNTRACK}) {$statemodule = "-m conntrack --ctstate"}
	if ($config{LF_SPI}) {
		$statemodulenew = "$statemodule NEW";
	} else {
		$statemodulenew = "";
	}
	if ($config{IPV6_SPI}) {
		$statemodule6new = "$statemodule NEW";
	} else {
		$statemodule6new = "";
	}

	my @entries = slurp("/etc/csf/csf.blocklists");
	foreach my $line (@entries)
	{
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @entries,@incfile;
		}
	}

	foreach my $line (@entries)
	{
		$line =~ s/$cleanreg//g;
		if ($line eq "") { next }
		if ($line =~ /^\s*\#|Include/) { next }

		my ($name,$interval,$max,$url) = split(/\|/,$line);

		# Trim whitespace
		for ($name, $interval, $max, $url) { s/^\s+|\s+$//g; }

		if ($name =~ /^\w+$/)
		{
			$name = substr(uc $name, 0, 25);
			if ($name =~ /^CXS_/) {$name =~ s/^CXS_/X_CXS_/}
			if ($interval < 3600) {$interval = 3600}
			if ($max eq "") {$max = 0}
			$blocklists{$name}{interval} = $interval;
			$blocklists{$name}{max} = $max;
			$blocklists{$name}{url} = $url;
		}
	}

	if (-e "/etc/cxs/cxs.reputation" and -e "/usr/local/csf/lib/ConfigServer/cxs.pm") {
		require ConfigServer::cxs;
		import ConfigServer::cxs;
		$cxsreputation = 1;
		if (-e "/etc/cxs/cxs.blocklists")
		{
			my $all = 0;
			my @lines = slurp("/etc/cxs/cxs.blocklists");
			if (grep {$_ =~ /^CXS_ALL/} @lines) {$all = 1}
			foreach my $line (@lines) {
				$line =~ s/$cleanreg//g;
				if ($line =~ /^(\s|\#|$)/) {next}
				my ($name,$interval,$max,$url) = split(/\|/,$line);

				# Trim whitespace
				for ($name, $interval, $max, $url) { s/^\s+|\s+$//g; }

				if ($all and $name ne "CXS_ALL") {next}
				if ($name =~ /^\w+$/)
				{
					$name = substr(uc $name, 0, 25);
					if ($max eq "") {$max = 0}
					$blocklists{$name}{interval} = $interval;
					$blocklists{$name}{max} = $max;
					$blocklists{$name}{url} = $url;
				}
			}
		}
		%cxsports = ConfigServer::cxs::Rports();
	}

	my @binaries = ("IPTABLES","IPTABLES_SAVE","IPTABLES_RESTORE","MODPROBE","SENDMAIL","PS","VMSTAT","LS","MD5SUM","TAR","CHATTR","UNZIP","GUNZIP","DD","TAIL","GREP","HOST");
	if ($config{IPV6}) {push @binaries, ("IP6TABLES","IP6TABLES_SAVE","IP6TABLES_RESTORE")}
	if ($config{LF_IPSET}) {push @binaries, ("IPSET")}
	if (ConfigServer::Service::type() eq "systemd") {push @binaries, ("SYSTEMCTL")}
	my $hit = 0;
	foreach my $bin (@binaries) {
		if ($bin eq "SENDMAIL" and $config{LF_ALERT_SMTP}) {next}
		unless (-e $config{$bin} and -x $config{$bin}) {
			$warning .= "*WARNING* Binary location for [$bin] [$config{$bin}] in /etc/csf/csf.conf is either incorrect, is not installed or is not executable\n";
			$hit = 1;
		}
	}
	my $iphit = 0;
	if (-e $config{IP} or -e $config{IFCONFIG}) {$iphit = 1}
	unless ($iphit) {
		$warning .= "*WARNING* Binary location for either [IP] [$config{IP}] or [IFCONFIG] [$config{IFCONFIG}] in /etc/csf/csf.conf must be set correctly, installed and executable\n";
		$hit = 1;
	}
	if ($hit) {$warning .= "*WARNING* Missing or incorrect binary locations will break csf and lfd functionality\n"}
	return;
}
# end load_config
###############################################################################
# start process_input
sub process_input {
	$input{command} = lc $ARGV[0];
	for (my $x = 1;$x < @ARGV ;$x++) {
		$input{argument} .= $ARGV[$x] . " ";
	}
	$input{argument} =~ s/\s$//;
	return;
}
# end process_input
###############################################################################
# start dostatus
sub dostatus {
	print "iptables filter table\n";
	print "=====================\n";
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -v -L -n --line-numbers");
	if ($config{MANGLE}) {
		print "\n\n";
		print "iptables mangle table\n";
		print "=====================\n";
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -v -t mangle -L -n --line-numbers");
	}
	if ($config{RAW}) {
		print "\n\n";
		print "iptables raw table\n";
		print "==================\n";
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -v -t raw -L -n --line-numbers");
	}
	if ($config{NAT}) {
		print "\n\n";
		print "iptables nat table\n";
		print "==================\n";
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -v -t nat -L -n --line-numbers");
	}
	return;
}
# end dostatus
###############################################################################
# start dostatus6
sub dostatus6 {
	if ($config{IPV6}) {
		print "ip6tables filter table\n";
		print "======================\n";
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -v -L -n --line-numbers");
		if ($config{MANGLE6}) {
			print "\n\n";
			print "ip6tables mangle table\n";
			print "======================\n";
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -v -t mangle -L -n --line-numbers");
		}
		if ($config{RAW6}) {
			print "\n\n";
			print "ip6tables raw table\n";
			print "===================\n";
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -v -t raw -L -n --line-numbers");
		}
		if ($config{NAT6}) {
			print "\n\n";
			print "ip6tables nat table\n";
			print "===================\n";
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -v -t nat -L -n --line-numbers");
		}
	} else {
		print "csf: IPV6 firewall not enabled\n";
	}
	return;
}
# end dostatus
###############################################################################
# start doversion
sub doversion {
my $generic = " (cPanel)";
if ($config{GENERIC}) {$generic = " (generic)"}
if ($config{DIRECTADMIN}) {$generic = " (DirectAdmin)"}
if ($config{INTERWORX}) {$generic = " (InterWorx)"}
if ($config{CYBERPANEL}) {$generic = " (CyberPanel)"}
if ($config{CWP}) {$generic = " (CentOS Web Panel)"}
if ($config{VESTA}) {$generic = " (VestaCP)"}
	print "csf: v$version$generic\n";
	return;
}
# end doversion
###############################################################################
# start dolfd
sub dolfd {
	my $lfd  = $input{argument};
	if ($lfd eq "start") {ConfigServer::Service::startlfd()}
	elsif ($lfd eq "stop") {ConfigServer::Service::stoplfd()}
	elsif ($lfd eq "restart") {ConfigServer::Service::restartlfd()}
	elsif ($lfd eq "status") {ConfigServer::Service::statuslfd()}
	else {print "csf: usage: csf --lfd [stop|start|restart|status]\n"}
	return;
}
# end dolfd
###############################################################################
# start dorestartall
sub dorestartall {
	&csflock("lock");
	&dostop(1);
	&dostart;
	&csflock("unlock");
	ConfigServer::Service::restartlfd();
	return;
}
# end dorestartall
###############################################################################
# start doinitup
sub doinitup {
	&csflock("lock");
	if ($config{FASTSTART}) {
		&modprobe;
		if (-e "/var/lib/csf/csf.4.saved") {
			if ($config{LF_IPSET}) {
				if (-x $config{IPSET}) {
					print "(restoring ipsets) ";

					open (my $IN, "<", "/var/lib/csf/csf.4.ipsets");
					flock ($IN, LOCK_SH);
					my @data = <$IN>;
					close ($IN);
					chomp @data;
					my ($childin, $childout);
					my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"restore");
					print $childin join("\n",@data)."\n";
					close $childin;
					my @results = <$childout>;
					waitpid ($cmdpid, 0);
					chomp @results;

					unlink "/var/lib/csf/csf.4.ipsets";
				}
			}
			print "(restoring iptables) ";

			open (my $IN, "<", "/var/lib/csf/csf.4.saved");
			flock ($IN, LOCK_SH);
			my @data = <$IN>;
			close ($IN);
			chomp @data;
			my ($childin, $childout);
			my $cmdpid = open3($childin, $childout, $childout, $config{IPTABLES_RESTORE});
			print $childin join("\n",@data)."\n";
			close $childin;
			my @results = <$childout>;
			waitpid ($cmdpid, 0);
			chomp @results;

			unlink "/var/lib/csf/csf.4.saved";
		} else {
			&dostop(1);
			&dostart;
			exit 0;
		}
		if ($config{IPV6}) {
			if (-e "/var/lib/csf/csf.6.saved") {
				print "(restoring ip6tables) ";

				open (my $IN, "<", "/var/lib/csf/csf.6.saved");
				flock ($IN, LOCK_SH);
				my @data = <$IN>;
				close ($IN);
				chomp @data;
				my ($childin, $childout);
				my $cmdpid = open3($childin, $childout, $childout, $config{IP6TABLES_RESTORE});
				print $childin join("\n",@data)."\n";
				close $childin;
				my @results = <$childout>;
				waitpid ($cmdpid, 0);
				chomp @results;

				unlink "/var/lib/csf/csf.6.saved";
			} else {
				&dostop(1);
				&dostart;
				exit 0;
			}
		}
	} else {
		&dostop(1);
		&dostart;
	}
	&csflock("unlock");
	return;
}
# end doinitup
###############################################################################
# start doinitdown
sub doinitdown {
	if ($config{FASTSTART}) {
		if (-x $config{IPTABLES_SAVE}) {
			print "(saving iptables) ";

			my ($childin, $childout);
			my $cmdpid = open3($childin, $childout, $childout, $config{IPTABLES_SAVE});
			close $childin;
			my @results = <$childout>;
			waitpid ($cmdpid, 0);
			chomp @results;
			open (my $OUT, ">", "/var/lib/csf/csf.4.saved");
			flock ($OUT, LOCK_EX);
			print $OUT join("\n",@results)."\n";
			close ($OUT);

			if ($config{LF_IPSET}) {
				if (-x $config{IPSET}) {
					print "(saving ipsets) ";

					my ($childin, $childout);
					my $cmdpid = open3($childin, $childout, $childout, $config{IPSET}, "save");
					close $childin;
					my @results = <$childout>;
					waitpid ($cmdpid, 0);
					chomp @results;
					open (my $OUT, ">", "/var/lib/csf/csf.4.ipsets");
					flock ($OUT, LOCK_EX);
					print $OUT join("\n",@results)."\n";
					close ($OUT);
				}
			}
		}
		if ($config{IPV6} and -x $config{IP6TABLES_SAVE}) {
			print "(saving ip6tables) ";

			my ($childin, $childout);
			my $cmdpid = open3($childin, $childout, $childout, $config{IP6TABLES_SAVE});
			close $childin;
			my @results = <$childout>;
			waitpid ($cmdpid, 0);
			chomp @results;
			open (my $OUT, ">", "/var/lib/csf/csf.6.saved");
			flock ($OUT, LOCK_EX);
			print $OUT join("\n",@results)."\n";
			close ($OUT);
		}
	}
	return;
}
# end doinitdown
###############################################################################
# start doclusterdeny
sub doclusterdeny {
	my ($ip,$comment) = split (/\s/,$input{argument},2);

	if (!checkip(\$ip)) {
		print "[$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	&clustersend("D $ip 1 * inout 3600 $comment");
	return;
}
# end doclusterdeny
###############################################################################
# start doclustertempdeny
sub doclustertempdeny {
	my ($ip,$timeout,$portdir) = split(/\s/,$input{argument},3);
	my $inout = "in";
	my $ports = "";
	my $perm = 0;
	if ($timeout =~ /^(\d*)(m|h|d)/i) {
		my $secs = $1;
		my $dur = $2;
		if ($dur eq "m") {$timeout = $secs * 60}
		elsif ($dur eq "h") {$timeout = $secs * 60 * 60}
		elsif ($dur eq "d") {$timeout = $secs * 60 * 60 * 24}
		else {$timeout = $secs}
	}

	my $iptype = checkip(\$ip);
	if ($iptype == 6 and !$config{IPV6}) {
		print "failed: [$ip] is valid IPv6 but IPV6 is not enabled in csf.conf\n";
	}

	unless ($iptype) {
		print "csf: [$ip] is not a valid PUBLIC IP\n";
		return;
	}

	if ($timeout =~ /\D/) {
		$portdir = join(" ",$timeout,$portdir);
		$timeout = 0;
	}

	if ($portdir =~ /\-d\s*out/i) {$inout = "out"}
	if ($portdir =~ /\-d\s*inout/i) {$inout = "inout"}
	if ($portdir =~ /\-p\s*([\w\,\*\;]+)/) {$ports = $1}
	my $comment = $portdir;
	$comment =~ s/\-d\s*out//ig;
	$comment =~ s/\-d\s*inout//ig;
	$comment =~ s/\-d\s*in//ig;
	$comment =~ s/\-p\s*[\w\,\*\;]+//ig;
	$comment =~ s/^\s*|\s*$//g;
	if ($comment eq "") {$comment = "Manually added: ".iplookup($ip)}
	if ($timeout < 2) {$timeout = 3600}
	if ($ports eq "") {$ports = "*"}

	if (!checkip(\$ip)) {
		print "[$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	&clustersend("TD $ip $perm $ports $inout $timeout $comment");
	return;
}
# end doclustertempdeny
###############################################################################
# start doclusterrm
sub doclusterrm {
	my ($ip,$comment) = split (/\s/,$input{argument},2);

	if (!checkip(\$ip)) {
		print "[$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	&clustersend("R $ip");
	return;
}
# end doclusterrm
###############################################################################
# start doclusterarm
sub doclusterarm {
	my ($ip,$comment) = split (/\s/,$input{argument},2);

	if (!checkip(\$ip)) {
		print "[$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	&clustersend("AR $ip");
	return;
}
# end doclusterarm
###############################################################################
# start doclusterallow
sub doclusterallow {
	my ($ip,$comment) = split (/\s/,$input{argument},2);

	if (!checkip(\$ip)) {
		print "[$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	&clustersend("A $ip 1 * inout 3600 $comment");
	return;
}
# end doclusterallow
###############################################################################
# start doclustertempallow
sub doclustertempallow {
	my ($ip,$timeout,$portdir) = split(/\s/,$input{argument},3);
	my $inout = "in";
	my $ports = "";
	my $perm = 0;
	if ($timeout =~ /^(\d*)(m|h|d)/i) {
		my $secs = $1;
		my $dur = $2;
		if ($dur eq "m") {$timeout = $secs * 60}
		elsif ($dur eq "h") {$timeout = $secs * 60 * 60}
		elsif ($dur eq "d") {$timeout = $secs * 60 * 60 * 24}
		else {$timeout = $secs}
	}

	my $iptype = checkip(\$ip);
	if ($iptype == 6 and !$config{IPV6}) {
		print "failed: [$ip] is valid IPv6 but IPV6 is not enabled in csf.conf\n";
	}

	unless ($iptype) {
		print "csf: [$ip] is not a valid PUBLIC IP\n";
		return;
	}

	if ($timeout =~ /\D/) {
		$portdir = join(" ",$timeout,$portdir);
		$timeout = 0;
	}

	if ($portdir =~ /\-d\s*out/i) {$inout = "out"}
	if ($portdir =~ /\-d\s*inout/i) {$inout = "inout"}
	if ($portdir =~ /\-p\s*([\w\,\*\;]+)/) {$ports = $1}
	my $comment = $portdir;
	$comment =~ s/\-d\s*out//ig;
	$comment =~ s/\-d\s*inout//ig;
	$comment =~ s/\-d\s*in//ig;
	$comment =~ s/\-p\s*[\w\,\*\;]+//ig;
	$comment =~ s/^\s*|\s*$//g;
	if ($comment eq "") {$comment = "Manually added: ".iplookup($ip)}
	if ($timeout < 2) {$timeout = 3600}
	if ($ports eq "") {$ports = "*"}

	if (!checkip(\$ip)) {
		print "[$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	&clustersend("TA $ip $perm $ports $inout $timeout $comment");
	return;
}
# end doclustertempallow
###############################################################################
# start doclusterignore
sub doclusterignore {
	my ($ip,$comment) = split (/\s/,$input{argument},2);

	if (!checkip(\$ip)) {
		print "[$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	&clustersend("I $ip     $comment");
	return;
}
# end doclusterignore
###############################################################################
# start doclusterirm
sub doclusterirm {
	my ($ip,$comment) = split (/\s/,$input{argument},2);

	if (!checkip(\$ip)) {
		print "[$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	&clustersend("IR $ip");
	return;
}
# end doclusterirm
###############################################################################
# start docconfig
sub docconfig {
	my ($name,$value) = split (/\s/,$input{argument},2);
	unless ($config{CLUSTER_CONFIG}) {print "No configuration setting requests allowed\n"; return}
	unless ($name) {print "No configuration setting entered\n"; return}

	&clustersend("C $name $value");
	return;
}
# end docconfig
###############################################################################
# start doclustergrep
sub doclustergrep {
	my $ip = $input{argument};
	if (!checkip(\$ip)) {
		print "[$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	&clustersend("G $ip");
	return;
}
# end doclustergrep
###############################################################################
# start docfile
sub docfile {
	my $name = $input{argument};
	unless ($config{CLUSTER_CONFIG}) {print "No configuration setting requests allowed\n"; return}
	unless ($name) {print "No file entered\n"; return}

	if (-e $name) {
		open (my $FH, "<", $name);
		flock ($FH, LOCK_SH);
		my @data = <$FH>;
		close @data;

		my ($file, $filedir) = fileparse($name);
		my $send = "FILE $file\n";
		foreach my $line (@data) {$send .= $line}

		&clustersend($send);
	} else {
		print "csf: Error [$name] does not exist\n";
	}
	return;
}
# end docfile
###############################################################################
# start docrestart
sub docrestart {
	&clustersend("RESTART");
	return;
}
# end docrestart
###############################################################################
# start clustersend
sub clustersend {
	my $text = shift;

	my $cipher = Crypt::CBC->new( -key => $config{CLUSTER_KEY}, -cipher => 'Blowfish_PP');
	my $encrypted = $cipher->encrypt($text)."END\n";

	foreach my $cip (split(/\,/,$config{CLUSTER_SENDTO})) {
		my $localaddr = "0.0.0.0";
		if ($config{CLUSTER_LOCALADDR}) {$localaddr = $config{CLUSTER_LOCALADDR}}
		my $sock;
		eval {$sock = IO::Socket::INET->new(PeerAddr => $cip, PeerPort => $config{CLUSTER_PORT}, LocalAddr => $localaddr, Timeout => '10') or print "Cluster error connecting to $cip: $!\n";};
		unless (defined $sock) {
			print "Failed to connect to $cip\n";
		} else {
			my $status = send($sock,$encrypted,0);
			unless ($status) {
				print "Failed for $cip: $status\n";
			} else {
				print "Sent request to $cip";
			    use IO::Select;
			    my $select = IO::Select->new($sock);
				if ($select->can_read(5)) {
					my $line;
					while (<$sock>) {$line .= $_}
					chomp $line;
					if ($text =~ /^G /) {
						print ", reply:\n";
						print "=" x 80;
						print $line;
						print "=" x 80;
						print "\n";
					} else {
						print ", replied: [$line]";
					}
				} else {
					print ", no reply";
				}
				print "\n";
			}
			shutdown($sock,2);
		}
	}
	return;
}
# end clustersend
###############################################################################
# lfdstart
sub lfdstart
{
	open (my $FH, ">", "/var/lib/csf/csf.restart") or die "Failed to create csf.restart - $!";
	flock ($FH, LOCK_EX);
	close ($FH);
	print "lfd will restart csf within the next $config{LF_PARSE} seconds\n";
	return;
}
# lfdstart
###############################################################################
# start dostop
sub dostop
{
	log_info( "Flushing firewall rules${greym}" );

	my $restart = shift;

	&syscommand(__LINE__,"$config{IPTABLES} $verbose --policy INPUT ACCEPT");
	&syscommand(__LINE__,"$config{IPTABLES} $verbose --policy OUTPUT ACCEPT");
	&syscommand(__LINE__,"$config{IPTABLES} $verbose --policy FORWARD ACCEPT");
	&syscommand(__LINE__,"$config{IPTABLES} $verbose --flush");
	&syscommand(__LINE__,"$config{IPTABLES} $verbose --delete-chain");

	if ($config{NAT})
	{
		&syscommand(__LINE__,"$config{IPTABLES} $verbose -t nat --flush");
		&syscommand(__LINE__,"$config{IPTABLES} $verbose -t nat --delete-chain");
	}
	if ($config{RAW})
	{
		&syscommand(__LINE__,"$config{IPTABLES} $verbose -t raw --flush");
		&syscommand(__LINE__,"$config{IPTABLES} $verbose -t raw --delete-chain");
	}
	if ($config{MANGLE})
	{
		&syscommand(__LINE__,"$config{IPTABLES} $verbose -t mangle --flush");
		&syscommand(__LINE__,"$config{IPTABLES} $verbose -t mangle --delete-chain");
	}

	if ($config{IPV6})
	{
		&syscommand(__LINE__,"$config{IP6TABLES} $verbose --policy INPUT ACCEPT");
		&syscommand(__LINE__,"$config{IP6TABLES} $verbose --policy OUTPUT ACCEPT");
		&syscommand(__LINE__,"$config{IP6TABLES} $verbose --policy FORWARD ACCEPT");
		&syscommand(__LINE__,"$config{IP6TABLES} $verbose --flush");
		&syscommand(__LINE__,"$config{IP6TABLES} $verbose --delete-chain");

		if ($config{NAT6})
		{
			&syscommand(__LINE__,"$config{IP6TABLES} $verbose -t nat --flush");
			&syscommand(__LINE__,"$config{IP6TABLES} $verbose -t nat --delete-chain");
		}

		if ($config{RAW6})
		{
			&syscommand(__LINE__,"$config{IP6TABLES} $verbose -t raw --flush");
			&syscommand(__LINE__,"$config{IP6TABLES} $verbose -t raw --delete-chain");
		}

		if ($config{MANGLE6})
		{
			&syscommand(__LINE__,"$config{IP6TABLES} $verbose -t mangle --flush");
			&syscommand(__LINE__,"$config{IP6TABLES} $verbose -t mangle --delete-chain");
		}
	}

	if ($config{LF_IPSET}) {
		&syscommand(__LINE__,"$config{IPSET} flush");
		&syscommand(__LINE__,"$config{IPSET} destroy");
	}

	if ($config{TESTING}) {&crontab("remove")}
	return;

}
# end dostop
###############################################################################
# start dostart
sub dostart {
	if (ConfigServer::Service::type() eq "systemd") {
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, $config{SYSTEMCTL},"is-active","firewalld");
		my @reply = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @reply;
		if ($reply[0] eq "active" or $reply[0] eq "activating") {
			&error(__LINE__,"*Error* firewalld found to be running. You must stop and disable firewalld when using csf");
			exit 1;
		}
	}

	if ($config{TESTING}) {&crontab("add")} else {&crontab("remove")}
	if (-e "/etc/csf/csf.error") {unlink ("/etc/csf/csf.error")}

	&getethdev;
	&modprobe;

	$noowner = 0;
	if ($config{VPS} and $config{SMTP_BLOCK})
	{
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "$config{IPTABLES} $config{IPTABLESWAIT} -I OUTPUT -p tcp --dport 9999 -m owner --uid-owner 0 -j $accept");
		my @ipdata = <$childout>;

		waitpid ($cmdpid, 0);
		chomp @ipdata;

		if ($ipdata[0] =~ /# Warning: iptables-legacy tables present/) {shift @ipdata}
		if ($ipdata[0] =~ /^iptables/)
		{
			$warning .= "*WARNING* Cannot use SMTP_BLOCK on this VPS as the Monolithic kernel does not support the iptables module ipt_owner/xt_owner - SMTP_BLOCK disabled\n";
			$config{SMTP_BLOCK} = 0;
			$noowner = 1;
		}
		else
		{
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D OUTPUT -p tcp --dport 9999 -m owner --uid-owner 0 -j $accept",0);
		}
	}

	# #
	#	Define › csfpre/post › Defaults
	# #

	my $path = "PATH=\$PATH:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin";
	my @csfpre  = ();
	my @csfpost = ();

	# #
	#	Define › csfpre/post › Scripts
	#	
	#	All possible pre/post script paths (if exists)
	# #

	push @csfpre,  "/usr/local/csf/bin/csfpre.sh"  if -e "/usr/local/csf/bin/csfpre.sh";
	push @csfpre,  "/etc/csf/csfpre.sh"            if -e "/etc/csf/csfpre.sh";
	push @csfpost, "/usr/local/csf/bin/csfpost.sh" if -e "/usr/local/csf/bin/csfpost.sh";
	push @csfpost, "/etc/csf/csfpost.sh"           if -e "/etc/csf/csfpost.sh";

    # #
	#	CSFpre › Sanitize and Execute
	#	
	#	csfpre		Initialize rules BEFORE csf adds its own rulesets
	#	csfpost		Initialize rules BEFORE csf adds its own rulesets
	#	
    #   For each csfpre script found in @csfpre:
    #       › Ensure executable (chmod 0700)
    #       › Read contents and verify it starts with  valid shebang(#!/bin/bash).
	#			If missing; rewrite file + add one.
    #       › Clean each line using $cleanreg before writing it back
    #       › Execute the script using syscommand() in a clean PATH
	#	
	#	@notes		original logic only supported a single csfpre using if/else exists
	#					csfpre
	#						/usr/local/csf/bin/csfpre.sh		OR
	#						/etc/csf/csfpre.sh
	#					csfpost
	#						/usr/local/csf/bin/csfpost.sh		OR
	#						/etc/csf/csfpost.sh
	#				updated logic supports both csfpre locations
    # #

	foreach my $pre ( @csfpre )
	{
		chmod( 0700, $pre );

		my @conf = slurp( $pre );
		if ( $conf[0] !~ /^\#\!/ )
		{
			open( my $CONF, ">", $pre );
			flock( $CONF, LOCK_EX );
			print $CONF "#!/bin/bash\n";
			
			foreach my $line ( @conf )
			{
				$line =~ s/$cleanreg//g;
				print $CONF "$line\n";
			}
			close( $CONF );
		}

		log_info( "Initializing ${bluel}csfpre${greym} script ${bluel}${pre}${greym}" );
		&syscommand( __LINE__, "$path ; $pre" );
	}

	if ($config{WATCH_MODE})
	{
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N LOGACCEPT");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOGACCEPT -j ACCEPT");
		if ($config{IPV6})
		{
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N LOGACCEPT");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOGACCEPT -j ACCEPT");
		}
	}

	foreach my $name (keys %blocklists)
	{
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N $name");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N $name");
		}
	}

	if ($config{CC_ALLOW_FILTER}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N CC_ALLOWF")}
	if ($config{CC_ALLOW_PORTS}) {
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N CC_ALLOWP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N CC_ALLOWPORTS");
	}
	if ($config{CC_DENY_PORTS}) {
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N CC_DENYP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N CC_DENYPORTS");
	}
	if ($config{CC_ALLOW}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N CC_ALLOW")}
	if ($config{CC_DENY}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N CC_DENY")}
	if (scalar(keys %blocklists) > 0 and $config{DROP_IP_LOGGING}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N BLOCKDROP")}
	if (($config{CC_DENY} or $config{CC_ALLOW_FILTER}) and $config{DROP_IP_LOGGING}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N CCDROP")}
	if ($config{IPV6}) {
		if ($config{CC_ALLOW_FILTER}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N CC_ALLOWF")}
		if ($config{CC_ALLOW_PORTS}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N CC_ALLOWP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N CC_ALLOWPORTS");
		}
		if ($config{CC_DENY_PORTS}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N CC_DENYP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N CC_DENYPORTS");
		}
		if ($config{CC_ALLOW}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N CC_ALLOW")}
		if ($config{CC_DENY}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N CC_DENY")}
		if (scalar(keys %blocklists) > 0 and $config{DROP_IP_LOGGING}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N BLOCKDROP")}
		if (($config{CC_DENY} or $config{CC_ALLOW_FILTER}) and $config{DROP_IP_LOGGING}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N CCDROP")}
	}

	if ($config{GLOBAL_ALLOW}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N GALLOWIN")}
	if ($config{GLOBAL_ALLOW}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N GALLOWOUT")}
	if ($config{GLOBAL_DENY}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N GDENYIN")}
	if ($config{GLOBAL_DENY}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N GDENYOUT")}
	if ($config{DYNDNS}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N ALLOWDYNIN")}
	if ($config{DYNDNS}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N ALLOWDYNOUT")}
	if ($config{GLOBAL_DYNDNS}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N GDYNIN")}
	if ($config{GLOBAL_DYNDNS}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N GDYNOUT")}
	if ($config{SYNFLOOD}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N SYNFLOOD")}
	if ($config{PORTFLOOD}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N PORTFLOOD")}
	if ($config{CONNLIMIT}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N CONNLIMIT")}
	if ($config{UDPFLOOD}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N UDPFLOOD")}
	if ($config{IPV6}) {
		if ($config{GLOBAL_ALLOW}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N GALLOWIN")}
		if ($config{GLOBAL_ALLOW}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N GALLOWOUT")}
		if ($config{GLOBAL_DENY}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N GDENYIN")}
		if ($config{GLOBAL_DENY}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N GDENYOUT")}
		if ($config{DYNDNS}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N ALLOWDYNIN")}
		if ($config{DYNDNS}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N ALLOWDYNOUT")}
		if ($config{GLOBAL_DYNDNS}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N GDYNIN")}
		if ($config{GLOBAL_DYNDNS}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N GDYNOUT")}
		if ($config{SYNFLOOD}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N SYNFLOOD")}
		if ($config{PORTFLOOD6}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N PORTFLOOD")}
		if ($config{CONNLIMIT6}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N CONNLIMIT")}
		if ($config{UDPFLOOD}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N UDPFLOOD")}
	}

	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N LOGDROPIN");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N LOGDROPOUT");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N DENYIN");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N DENYOUT");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N ALLOWIN");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N ALLOWOUT");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N LOCALINPUT");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N LOCALOUTPUT");
	if ($config{IPV6}) {
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N LOGDROPIN");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N LOGDROPOUT");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N DENYIN");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N DENYOUT");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N ALLOWIN");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N ALLOWOUT");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N LOCALINPUT");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N LOCALOUTPUT");
	}

	if ($config{DROP_LOGGING}) {
		my $dports;
		if ($config{DROP_ONLYRES}) {$dports = "--dport 0:1023"}
		$config{DROP_NOLOG} =~ s/\s//g;
		if ($config{DROP_NOLOG} ne "") {
			if ($config{FASTSTART}) {$faststart = 1}
			foreach my $port (split(/\,/,$config{DROP_NOLOG})) {
				if ($port eq "") {next}
				if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid DROP_NOLOG port [$port]")}
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPIN -p tcp --dport $port -j $config{DROP}");
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPIN -p udp --dport $port -j $config{DROP}");
				if ($config{IPV6}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPIN -p tcp --dport $port -j $config{DROP}");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPIN -p udp --dport $port -j $config{DROP}");
				}
			}
			if ($config{FASTSTART}) {&faststart("DROP no logging")}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPIN -p tcp $dports -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *TCP_IN Blocked* '");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPOUT -p tcp --syn -m limit --limit 30/m --limit-burst 5 -j $logouttarget 'Firewall: *TCP_OUT Blocked* '");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPIN -p udp $dports -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *UDP_IN Blocked* '");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPOUT -p udp -m limit --limit 30/m --limit-burst 5 -j $logouttarget 'Firewall: *UDP_OUT Blocked* '");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPIN -p icmp -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *ICMP_IN Blocked* '");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPOUT -p icmp -m limit --limit 30/m --limit-burst 5 -j $logouttarget 'Firewall: *ICMP_OUT Blocked* '");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPIN -p tcp $dports -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *TCP6IN Blocked* '");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPOUT -p tcp --syn -m limit --limit 30/m --limit-burst 5 -j $logouttarget 'Firewall: *TCP6OUT Blocked* '");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPIN -p udp $dports -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *UDP6IN Blocked* '");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPOUT -p udp -m limit --limit 30/m --limit-burst 5 -j $logouttarget 'Firewall: *UDP6OUT Blocked* '");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPIN -p icmpv6 -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *ICMP6IN Blocked* '");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPOUT -p icmpv6 -m limit --limit 30/m --limit-burst 5 -j $logouttarget 'Firewall: *ICMP6OUT Blocked* '");
		}
		if (scalar(keys %blocklists) > 0 and $config{DROP_IP_LOGGING}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A BLOCKDROP -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *BLOCK_LIST* '");}
		if (($config{CC_DENY} or $config{CC_ALLOW_FILTER}) and $config{DROP_IP_LOGGING}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CCDROP -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *CC_DENY* '");}
		if ($config{PORTFLOOD}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A PORTFLOOD -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *Port Flood* '");}
		if ($config{IPV6}) {
			if (scalar(keys %blocklists) > 0 and $config{DROP_IP_LOGGING}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A BLOCKDROP -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *BLOCK_LIST* '");}
			if (($config{CC_DENY} or $config{CC_ALLOW_FILTER}) and $config{DROP_IP_LOGGING}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CCDROP -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *CC_DENY* '");}
			if ($config{PORTFLOOD6}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A PORTFLOOD -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *Port Flood* '");}
		}
	}

	if (scalar(keys %blocklists) > 0 and $config{DROP_IP_LOGGING}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A BLOCKDROP -j $config{DROP}");}
	if (($config{CC_DENY} or $config{CC_ALLOW_FILTER}) and $config{DROP_IP_LOGGING}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CCDROP -j $config{DROP}");}
	if ($config{IPV6}) {
		if (scalar(keys %blocklists) > 0 and $config{DROP_IP_LOGGING}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A BLOCKDROP -j $config{DROP}");}
		if (($config{CC_DENY} or $config{CC_ALLOW_FILTER}) and $config{DROP_IP_LOGGING}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CCDROP -j $config{DROP}");}
	}

	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPIN -j $config{DROP}");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPOUT -j $config{DROP_OUT}");
	if ($config{IPV6}) {
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPIN -j $config{DROP}");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOGDROPOUT -j $config{DROP_OUT}");
	}

	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALOUTPUT $ethdevout -j DENYOUT");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j DENYIN");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I LOCALOUTPUT $ethdevout -j ALLOWOUT");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I LOCALINPUT $ethdevin -j ALLOWIN");
	if ($config{IPV6}) {
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALOUTPUT $ethdevout -j DENYOUT");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j DENYIN");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I LOCALOUTPUT $ethdevout -j ALLOWOUT");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I LOCALINPUT $ethdevin -j ALLOWIN");
	}

	if ($config{MESSENGER}) {
		if ($config{LF_IPSET}) {
			&ipsetcreate("MESSENGER");
			if ($config{MESSENGER6}) {&ipsetcreate("MESSENGER_6")}
			&domessenger("-m set --match-set MESSENGER src","A")
		}
	}

	&dopacketfilters;
	&doportfilters;

	my $skipin = 1;
	my $skipout = 1;
	my $skipin6 = 1;
	my $skipout6 = 1;

	my $dropout = $config{DROP_OUT};
	if ($config{DROP_OUT_LOGGING}) {$dropout = "LOGDROPOUT"}

	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I INPUT  -i lo -j $accept");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT -o lo -j $accept");
	unless ($config{LF_SPI}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -j $accept")}
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -j $dropout");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -j LOGDROPIN");
	if ($config{IPV6}) {
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I INPUT  -i lo -j $accept");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT -o lo -j $accept");
		unless ($config{IPV6_SPI}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $eth6devout -j $accept")}
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $eth6devout -j $dropout");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INPUT $eth6devin -j LOGDROPIN");
	}

	if ($config{SMTP_BLOCK}) {
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N SMTPOUTPUT");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT -j SMTPOUTPUT");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N SMTPOUTPUT");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT -j SMTPOUTPUT");
		}
		if ($config{FASTSTART}) {$faststart = 1}
		my $dropout = $config{DROP_OUT};
		if ($config{DROP_OUT_LOGGING}) {$dropout = "LOGDROPOUT"}
		$config{SMTP_PORTS} =~ s/\s//g;
		if ($config{SMTP_PORTS} ne "") {
			unless ($config{SMTP_REDIRECT}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I SMTPOUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -j $dropout",1)}
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I SMTPOUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -m owner --uid-owner 0 -j $accept",1);
			if ($config{IPV6}) {
				unless ($config{SMTP_REDIRECT}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I SMTPOUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -j $dropout",1)}
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I SMTPOUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -m owner --uid-owner 0 -j $accept",1);
			}
			foreach my $item (split(/\,/,$config{SMTP_ALLOWUSER})) {
				$item =~ s/\s//g;
				my $uid = (getpwnam($item))[2];
				if ($uid) {
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I SMTPOUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -m owner --uid-owner $uid -j $accept",1);
					if ($config{IPV6}) {
						&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I SMTPOUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -m owner --uid-owner $uid -j $accept",1);
					}
				}
			}
			foreach my $item (split(/\,/,$config{SMTP_ALLOWGROUP})) {
				$item =~ s/\s//g;
				my $gid = (getgrnam($item))[2];
				if ($gid) {
					syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I SMTPOUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -m owner --gid-owner $gid -j $accept",1);
					if ($config{IPV6}) {
						syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I SMTPOUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -m owner --gid-owner $gid -j $accept",1);
					}
				}
			}
			if ($config{SMTP_ALLOWLOCAL}) {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I SMTPOUTPUT -o lo -p tcp -m multiport --dports $config{SMTP_PORTS} -j $accept",1);
				if ($config{IPV6}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I SMTPOUTPUT -o lo -p tcp -m multiport --dports $config{SMTP_PORTS} -j $accept",1);
				}
			}
			if ($config{SMTP_REDIRECT}) {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -I OUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -j REDIRECT",1);
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -I OUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -m owner --uid-owner 0 -j RETURN",1);
				if ($config{IPV6} and $config{SMTP_REDIRECT6}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t nat -I OUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -j REDIRECT",1);
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t nat -I OUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -m owner --uid-owner 0 -j RETURN",1);
				}
				foreach my $item (split(/\,/,$config{SMTP_ALLOWUSER})) {
					$item =~ s/\s//g;
					my $uid = (getpwnam($item))[2];
					if ($uid) {
						&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -I OUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -m owner --uid-owner $uid -j RETURN",1);
						if ($config{IPV6} and $config{SMTP_REDIRECT6}) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t nat -I OUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -m owner --uid-owner $uid -j RETURN",1);
						}
					}
				}
				foreach my $item (split(/\,/,$config{SMTP_ALLOWGROUP})) {
					$item =~ s/\s//g;
					my $gid = (getgrnam($item))[2];
					if ($gid) {
						syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -I OUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -m owner --gid-owner $gid -j RETURN",1);
						if ($config{IPV6} and $config{SMTP_REDIRECT6}) {
							syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t nat -I OUTPUT -p tcp -m multiport --dports $config{SMTP_PORTS} -m owner --gid-owner $gid -j RETURN",1);
						}
					}
				}
				if ($config{SMTP_ALLOWLOCAL}) {
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -I OUTPUT -o lo -p tcp -m multiport --dports $config{SMTP_PORTS} -j RETURN",1);
					if ($config{IPV6} and $config{SMTP_REDIRECT6}) {
						&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t nat -I OUTPUT -o lo -p tcp -m multiport --dports $config{SMTP_PORTS} -j RETURN",1);
					}
				}
			}
		}
		if ($config{FASTSTART}) {&faststart("SMTP Block")}
	}

	if ($config{FASTSTART}) {$faststart = 1}
	unless ($config{DNS_STRICT})
	{
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -p udp --sport 53 -j $accept");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -p tcp --sport 53 -j $accept");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -p udp --dport 53 -j $accept");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -p tcp --dport 53 -j $accept");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $eth6devout -p udp --sport 53 -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $eth6devout -p tcp --sport 53 -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $eth6devout -p udp --dport 53 -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $eth6devout -p tcp --dport 53 -j $accept");
		}
	}

	unless ($config{DNS_STRICT_NS})
	{
		foreach my $line (slurp("/etc/resolv.conf"))
		{
			$line =~ s/$cleanreg//g;
			if ($line =~ /^(\s|\#|$)/) {next}
			if ($line =~ /^nameserver\s+($ipv4reg)/) {
				my $ip = $1;
				unless ($ips{$ip} or $ipscidr->find($ip)) {
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -s $ip -p udp --sport 53 -j $accept");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -s $ip -p tcp --sport 53 -j $accept");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -s $ip -p udp --dport 53 -j $accept");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -s $ip -p tcp --dport 53 -j $accept");
					$skipin += 4;
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -d $ip -p udp --sport 53 -j $accept");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -d $ip -p tcp --sport 53 -j $accept");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -d $ip -p udp --dport 53 -j $accept");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -d $ip -p tcp --dport 53 -j $accept");
					$skipout += 4;
				}
			}
			if ($line =~ /^nameserver\s+($ipv6reg)/) {
				my $ip = $1;
				unless ($ips{$ip} or $ipscidr6->find($ip)) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -s $ip -p udp --sport 53 -j $accept");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -s $ip -p tcp --sport 53 -j $accept");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -s $ip -p udp --dport 53 -j $accept");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -s $ip -p tcp --dport 53 -j $accept");
					$skipin6 += 4;
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -d $ip -p udp --sport 53 -j $accept");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -d $ip -p tcp --sport 53 -j $accept");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -d $ip -p udp --dport 53 -j $accept");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -d $ip -p tcp --dport 53 -j $accept");
					$skipout6 += 4;
				}
			}
		}
	}

	if ($config{FASTSTART})
	{
		&faststart("DNS")
	}

	if ($config{MESSENGER})
	{
		$skipin += 2;
		$skipout += 2;
		if ($config{MESSENGER_HTTPS_IN})
		{
			$skipin += 1;
			$skipout += 1;
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -p tcp --dport $config{MESSENGER_HTTPS} -m limit --limit $config{MESSENGER_RATE} --limit-burst $config{MESSENGER_BURST} -j $accept");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -p tcp --sport $config{MESSENGER_HTTPS} -m limit --limit $config{MESSENGER_RATE} --limit-burst $config{MESSENGER_BURST} -j $accept");
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -p tcp --dport $config{MESSENGER_HTML} -m limit --limit $config{MESSENGER_RATE} --limit-burst $config{MESSENGER_BURST} -j $accept");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -p tcp --dport $config{MESSENGER_TEXT} -m limit --limit $config{MESSENGER_RATE} --limit-burst $config{MESSENGER_BURST} -j $accept");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -p tcp --sport $config{MESSENGER_HTML} -m limit --limit $config{MESSENGER_RATE} --limit-burst $config{MESSENGER_BURST} -j $accept");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -p tcp --sport $config{MESSENGER_TEXT} -m limit --limit $config{MESSENGER_RATE} --limit-burst $config{MESSENGER_BURST} -j $accept");
		if ($config{MESSENGER6})
		{
			$skipin6 += 2;
			$skipout6 += 2;
			if ($config{MESSENGER_HTTPS_IN})
			{
				$skipin6 += 1;
				$skipout6 += 1;
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -p tcp --dport $config{MESSENGER_HTTPS} -m limit --limit $config{MESSENGER_RATE} --limit-burst $config{MESSENGER_BURST} -j $accept");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -p tcp --sport $config{MESSENGER_HTTPS} -m limit --limit $config{MESSENGER_RATE} --limit-burst $config{MESSENGER_BURST} -j $accept");
			}
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -p tcp --dport $config{MESSENGER_HTML} -m limit --limit $config{MESSENGER_RATE} --limit-burst $config{MESSENGER_BURST} -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -p tcp --dport $config{MESSENGER_TEXT} -m limit --limit $config{MESSENGER_RATE} --limit-burst $config{MESSENGER_BURST} -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -p tcp --sport $config{MESSENGER_HTML} -m limit --limit $config{MESSENGER_RATE} --limit-burst $config{MESSENGER_BURST} -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -p tcp --sport $config{MESSENGER_TEXT} -m limit --limit $config{MESSENGER_RATE} --limit-burst $config{MESSENGER_BURST} -j $accept");
		}
	}

	if ( $config{DOCKER} )
	{
		log_info( "Docker integration enabled${greym}" );

		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N DOCKER");
		if ($config{NAT})
		{
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -N DOCKER");
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -A POSTROUTING -s $config{DOCKER_NETWORK4} ! -o $config{DOCKER_DEVICE} -j MASQUERADE");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A FORWARD -o $config{DOCKER_DEVICE} $statemodule RELATED,ESTABLISHED -j ACCEPT");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A FORWARD -i $config{DOCKER_DEVICE} ! -o $config{DOCKER_DEVICE} -j ACCEPT");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A FORWARD -i $config{DOCKER_DEVICE} -o $config{DOCKER_DEVICE} -j ACCEPT");
		if ($config{IPV6} and $config{NAT6} and $config{DOCKER_NETWORK6} ne "")
		{
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N DOCKER");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t nat -A POSTROUTING -s $config{DOCKER_NETWORK6} ! -o $config{DOCKER_DEVICE} -j MASQUERADE");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A FORWARD -o $config{DOCKER_DEVICE} $statemodule RELATED,ESTABLISHED -j ACCEPT");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A FORWARD -i $config{DOCKER_DEVICE} ! -o $config{DOCKER_DEVICE} -j ACCEPT");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A FORWARD -i $config{DOCKER_DEVICE} -o $config{DOCKER_DEVICE} -j ACCEPT");
		}
	}
	else
	{
		log_info( "Docker integration disabled; skipping.${greym}" );
	}

	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $skipout $ethdevout -j LOCALOUTPUT");
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I INPUT $skipin $ethdevin -j LOCALINPUT");
	if ($config{IPV6})
	{
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $skipout6 $eth6devout -j LOCALOUTPUT");
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I INPUT $skipin6 $eth6devin -j LOCALINPUT");
	}

	$config{ETH_DEVICE_SKIP} =~ s/\s//g;
	if ($config{ETH_DEVICE_SKIP} ne "")
	{
		foreach my $device (split(/\,/,$config{ETH_DEVICE_SKIP}))
		{
			if ($ifaces{$device})
			{
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I INPUT  -i $device -j $accept");
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT -o $device -j $accept");
				if ($config{IPV6})
				{
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I INPUT  -i $device -j $accept");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT -o $device -j $accept");
				}
			}
			else
			{
				$warning .= "*WARNING* ETH_DEVICE_SKIP device [$device] not listed in ip/ifconfig\n";
			}
		}
	}

	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose --policy INPUT   DROP",1);
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose --policy OUTPUT  DROP",1);
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose --policy FORWARD DROP",1);
	if ($config{IPV6})
	{
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose --policy INPUT   DROP",1);
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose --policy OUTPUT  DROP",1);
		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose --policy FORWARD DROP",1);
	}

    # #
	#	CSFpost › Sanitize and Execute
	#	
	#	csfpre		Initialize rules BEFORE csf adds its own rulesets
	#	csfpost		Initialize rules BEFORE csf adds its own rulesets
	#	
    #   For each csfpost script found in @csfpost:
    #       › Ensure executable (chmod 0700)
    #       › Read contents and verify it starts with  valid shebang(#!/bin/bash).
	#			If missing; rewrite file + add one.
    #       › Clean each line using $cleanreg before writing it back
    #       › Execute the script using syscommand() in a clean PATH
	#	
	#	@notes		original logic only supported a single csfpost using if/else exists
	#					csfpre
	#						/usr/local/csf/bin/csfpre.sh		OR
	#						/etc/csf/csfpre.sh
	#					csfpost
	#						/usr/local/csf/bin/csfpost.sh		OR
	#						/etc/csf/csfpost.sh
	#				updated logic supports both csfpost locations
    # #

	foreach my $post ( @csfpost )
	{
		chmod( 0700, $post );

		my @conf = slurp( $post );
		if ($conf[0] !~ /^\#\!/)
		{
			open( my $CONF, ">", $post );
			flock( $CONF, LOCK_EX );
			print $CONF "#!/bin/bash\n";

			foreach my $line ( @conf )
			{
				$line =~ s/$cleanreg//g;
				print $CONF "$line\n";
			}
			close( $CONF );
		}

		log_info( "Initializing ${bluel}csfpost${greym} script ${bluel}${post}${greym}" );
		&syscommand( __LINE__, "$path ; $post" );
	}

	# #
	#	Give user warning at restart about default username and password
	# #

	if ( $config{UI} )
	{
		log_info( "Checking config file for valid username and password${greym}" );
		
		if ( $config{UI_USER} eq "" or $config{UI_USER} eq "username" )
		{
			log_fail( "Cannot enable CSF web interface. Setting ${redl}UI_USER${greym} has default value ${redl}'username'${greym}" );
			log_label( "You MUST change the default value." );
			$config{UI} = 0;
		}
		elsif ( $config{UI_PASS} eq "" or $config{UI_PASS} eq "password" )
		{
			log_fail( "Cannot enable CSF web interface. Setting ${redl}UI_PASS${greym} has default value ${redl}'password'${greym}" );
			log_label( "You MUST change the default value." );
			$config{UI} = 0;
		}
		else
		{
    		log_pass( "${greend}CSF web interface running on port${greym} ${greenl}$config{UI_PORT}${greym}" );
		}
	}
	else
	{
		log_info( "CSF web interface disabled; skipping.${greym}" );
	}

	if ( $config{VPS} )
	{
		open (my $FH, "<", "/proc/sys/kernel/osrelease");
		flock ($FH, LOCK_SH);
		my @data = <$FH>;
		close ($FH);
		chomp @data;

		if ($data[0] =~ /^(\d+)\.(\d+)\.(\d+)/)
		{
			my $maj = $1;
			my $mid = $2;
			my $min = $3;
	
			if (($maj > 2) or (($maj > 1) and ($mid > 5) and ($min > 26)))
			{
			}
			else
			{
				my $status = 0;
				if (-e "/etc/pure-ftpd.conf") {
					my @conf = slurp("/etc/pure-ftpd.conf");
					if (my @ls = grep {$_ =~ /^PassivePortRange\s+(\d+)\s+(\d+)/} @conf) {
						if ($ls[0] =~ /^PassivePortRange\s+(\d+)\s+(\d+)/) {
							if ($config{TCP_IN} !~ /\b$1:$2\b/) {$status = 1}
						}
					} else {$status = 1}
					if ($status) {$warning .= "*WARNING* Since the Virtuozzo VPS iptables ip_conntrack_ftp kernel module is currently broken you have to open a PASV port hole in iptables for incoming FTP connections to work correctly. See the csf readme.txt under 'A note about FTP Connection Issues' on how to do this if you have not already done so.\n"}
				}
				elsif (-e "/etc/proftpd.conf")
				{
					my @conf = slurp("/etc/proftpd.conf");
					if (my @ls = grep {$_ =~ /^PassivePorts\s+(\d+)\s+(\d+)/} @conf)
					{
						if ($ls[0] =~ /^PassivePorts\s+(\d+)\s+(\d+)/)
						{
							if ($config{TCP_IN} !~ /\b$1:$2\b/) {$status = 1}
						}
					}
					else
					{
						$status = 1
					}

					if ($status)
					{
						$warning .= "*WARNING* Since the Virtuozzo VPS iptables ip_conntrack_ftp kernel module is currently broken you have to open a PASV port hole in iptables for incoming FTP connections to work correctly. See the csf readme.txt under 'A note about FTP Connection Issues' on how to do this if you have not already done so.\n"
					}
				}
			}
		}
	}
	return;
}
# end dostart
###############################################################################
# start doadd
sub doadd {
	my ($ip,$comment) = split (/\s/,$input{argument},2);
	my $checkip = checkip(\$ip);

	&getethdev;

	if ($ips{$ip} or $ipscidr->find($ip) or $ipscidr6->find($ip)) {
		print "add failed: $ip is one of this servers addresses!\n";
		return;
	}

	if ($checkip == 6 and !$config{IPV6}) {
		print "add failed: [$ip] is valid IPv6 but IPV6 is not enabled in csf.conf\n";
		return;
	}

	if (!$checkip and !(($ip =~ /:|\|/) and ($ip =~ /=/))) {
		print "add failed: [$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	my $hit;
	my @deny = slurp("/etc/csf/csf.deny");
	foreach my $line (@deny) {
        $line =~ s/$cleanreg//g;
		if ($line eq "") {next}
		if ($line =~ /^\s*\#|Include/) {next}
		my ($ipd,$commentd) = split (/\s/,$line,2);
		checkip(\$ipd);
		if ($ipd eq $ip) {
			$hit = 1;
			last;
		}
	}
	if ($hit) {
		print "Removing $ip from csf.deny...\n";
		$input{argument} = $ip;
		&dokill;
	}

	my $allowmatches;
	my @allow = slurp("/etc/csf/csf.allow");
	foreach my $line (@allow) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @allow,@incfile;
		}
	}
	foreach my $line (@allow) {
        $line =~ s/$cleanreg//g;
		if ($line eq "") {next}
		if ($line =~ /^\s*\#|Include/) {next}
		my ($ipd,$commentd) = split (/\s/,$line,2);
		checkip(\$ipd);
		if ($ipd eq $ip) {
			$allowmatches = 1;
			last;
		}
	}

	my $ipstring = quotemeta($ip);
	sysopen (my $ALLOW, "/etc/csf/csf.allow", O_RDWR | O_CREAT) or &error(__LINE__,"Could not open /etc/csf/csf.allow: $!");
	flock ($ALLOW, LOCK_EX) or &error(__LINE__,"Could not lock /etc/csf/csf.allow: $!");
	my $text = join("", <$ALLOW>);
	@allow = split(/$slurpreg/,$text);
	chomp @allow;
	unless ($allowmatches) {
		if ($comment eq "") {$comment = "Manually allowed: ".iplookup($ip)}
		print $ALLOW "$ip \# $comment - ".localtime(time)."\n";
		if ($config{TESTING}) {
			print "Adding $ip to csf.allow only while in TESTING mode (not iptables ACCEPT)\n";
		} else {
			print "Adding $ip to csf.allow and iptables ACCEPT...\n";
			&linefilter($ip, "allow");
		}
	} else {
		print "add failed: $ip is in already in the allow file /etc/csf/csf.allow\n";
	}
	close ($ALLOW) or &error(__LINE__,"Could not close /etc/csf/csf.allow: $!");
	return;
}
# end doadd
###############################################################################
# start dodeny
sub dodeny {
	my ($ip,$comment) = split (/\s/,$input{argument},2);
	my $checkip = checkip(\$ip);

	&getethdev;

	if ($ips{$ip} or $ipscidr->find($ip) or $ipscidr6->find($ip)) {
		print "deny failed: [$ip] is one of this servers addresses!\n";
		return;
	}

	if ($checkip == 6 and !$config{IPV6}) {
		print "deny failed: [$ip] is valid IPv6 but IPV6 is not enabled in csf.conf\n";
		return;
	}

	if (!$checkip and !(($ip =~ /:|\|/) and ($ip =~ /=/))) {
		print "deny failed: [$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	my @allow = slurp("/etc/csf/csf.allow");
	foreach my $line (@allow) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @allow,@incfile;
		}
	}
	foreach my $line (@allow) {
        $line =~ s/$cleanreg//g;
		if ($line eq "") {next}
		if ($line =~ /^\s*\#|Include/) {next}
		my ($ipd,$commentd) = split (/\s/,$line,2);
		checkip(\$ipd);
		if ($ipd eq $ip) {
			print "deny failed: $ip is in the allow file /etc/csf/csf.allow\n";
			return;
		}
		elsif ($ipd =~ /(.*\/\d+)/) {
			my $cidrhit = $1;
			if (checkip(\$cidrhit)) {
				my $cidr = Net::CIDR::Lite->new;
				eval {local $SIG{__DIE__} = undef; $cidr->add($cidrhit)};
				if ($cidr->find($ip)) {
					print "deny failed: $ip is in the allow file /etc/csf/csf.allow\n";
					return;
				}
			}
		}
	}

	my @ignore = slurp("/etc/csf/csf.ignore");
	foreach my $line (@ignore) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @ignore,@incfile;
		}
	}

	foreach my $line (@ignore) {
        $line =~ s/$cleanreg//g;
		if ($line eq "") {next}
		if ($line =~ /^\s*\#|Include/) {next}
		my ($ipd,$commentd) = split (/\s/,$line,2);
		checkip(\$ipd);
		if ($ipd eq $ip) {
			print "deny failed: $ip is in the ignore file /etc/csf/csf.ignore\n";
			return;
		}
		elsif ($ipd =~ /(.*\/\d+)/) {
			my $cidrhit = $1;
			if (checkip(\$cidrhit)) {
				my $cidr = Net::CIDR::Lite->new;
				eval {local $SIG{__DIE__} = undef; $cidr->add($cidrhit)};
				if ($cidr->find($ip)) {
					print "deny failed: $ip is in the ignore file /etc/csf/csf.ignore\n";
					return;
				}
			}
		}
	}

	my $denymatches;
	my @deny = slurp("/etc/csf/csf.deny");
	foreach my $line (@deny)
	{
		if ($line =~ /^Include\s*(.*)$/)
		{
			my @incfile = slurp($1);
			push @deny,@incfile;
		}
	}

	foreach my $line (@deny)
	{
        $line =~ s/$cleanreg//g;
		if ($line eq "") {next}
		if ($line =~ /^\s*\#|Include/) {next}
		my ($ipd,$commentd) = split (/\s/,$line,2);
		checkip(\$ipd);
		if ($ipd eq $ip)
		{
			$denymatches = 1;
			last;
		}
	}

	sysopen (my $DENY, "/etc/csf/csf.deny", O_RDWR | O_CREAT) or &error(__LINE__,"Could not open /etc/csf/csf.deny: $!");
	flock ($DENY, LOCK_EX) or &error(__LINE__,"Could not lock /etc/csf/csf.deny: $!");
	my $text = join("", <$DENY>);
	@deny = split(/$slurpreg/,$text);
	chomp @deny;
	if ($config{LF_REPEATBLOCK} and $denymatches < $config{LF_REPEATBLOCK}) {$denymatches = 0}
	if ($denymatches == 0) {
		my $ipcount;
		my @denyips;
		foreach my $line (@deny) {
	        $line =~ s/$cleanreg//g;
			if ($line eq "") {next}
			if ($line =~ /^\s*\#|Include/) {next}
			if ($line =~ /do not delete/i) {next}
			my ($ipd,$commentd) = split (/\s/,$line,2);
			$ipcount++;
			push @denyips,$line;
		}
		if (($config{DENY_IP_LIMIT} > 0) and ($ipcount >= $config{DENY_IP_LIMIT})) {
			seek ($DENY, 0, 0);
			truncate ($DENY, 0);
			foreach my $line (@deny) {
				my $hit = 0;
				for (my $x = 0; $x < ($ipcount - $config{DENY_IP_LIMIT})+1;$x++) {
					if ($line eq $denyips[$x]) {$hit = 1;}
				}
				if ($hit) {next}
				print $DENY $line."\n";
			}
			print "csf: DENY_IP_LIMIT ($config{DENY_IP_LIMIT}), the following IP's were removed from /etc/csf/csf.deny:\n";
			for (my $x = 0; $x < ($ipcount - $config{DENY_IP_LIMIT})+1;$x++) {
				print "$denyips[$x]\n";
				my ($kip,undef) = split (/\s/,$denyips[$x],2);
				&linefilter($kip, "deny", "", 1);

#				sysopen (my $TEMPIP, "/var/lib/csf/csf.tempip", O_RDWR | O_CREAT);
#				flock ($TEMPIP, LOCK_EX);
#				my @data = <$TEMPIP>;
#				chomp @data;
#				seek ($TEMPIP, 0, 0);
#				truncate ($TEMPIP, 0);
#				foreach my $line (@data) {
#					my ($oip,undef,undef,undef) = split(/\|/,$line,4);
#					checkip(\$oip);
#					if ($oip eq $kip) {next}
#					print $TEMPIP "$line\n";
#				}
#				close ($TEMPIP);
			}

		}

		if ($comment eq "") {$comment = "Manually denied: ".iplookup($ip)}
		print $DENY "$ip \# $comment - ".localtime(time)."\n";

		if ($config{TESTING}) {
			print "Adding $ip to csf.deny only while in TESTING mode (not iptables DROP)\n";
		} else {
			print "Adding $ip to csf.deny and iptables DROP...\n";
			&linefilter($ip, "deny");
		}
	} else {
		print "deny failed: $ip is in already in the deny file /etc/csf/csf.deny $denymatches times\n";
	}
	close ($DENY) or &error(__LINE__,"Could not close /etc/csf/csf.deny: $!");
	return;
}
# end dodeny
###############################################################################
# start dokill
sub dokill {
	my $ip = $input{argument};
	my $is_ip = 0;
	if (checkip(\$ip)) {$is_ip = 1}

	if (!$is_ip and !(($ip =~ /:|\|/) and ($ip =~ /=/))) {
		print "[$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	&getethdev;

	sysopen (my $DENY, "/etc/csf/csf.deny", O_RDWR | O_CREAT) or &error(__LINE__,"Could not open /etc/csf/csf.deny: $!");
	flock ($DENY, LOCK_EX) or &error(__LINE__,"Could not lock /etc/csf/csf.deny: $!");
	my $text = join("", <$DENY>);
	my @deny = split(/$slurpreg/,$text);
	chomp @deny;
	seek ($DENY, 0, 0);
	truncate ($DENY, 0);
	my $hit = 0;
	foreach my $line (@deny) {
        $line =~ s/$cleanreg//g;
		my ($ipd,$commentd) = split (/\s/,$line,2);
		my $ipmatch = $ipd;
		if ($is_ip and $ipd =~ /($ipv4reg|$ipv6reg)/) {
			$ipmatch = $1;
			if ($ipd =~ /(\/\d+)$/) {$ipmatch .= $1}
		}
		checkip(\$ipd);
		if (uc $ip eq uc $ipmatch) {
			if ($commentd =~ /do not delete/i) {
				print "csf: $ip set as \"do not delete\" - not removed\n";
				$hit = -1;
			} else {
				print "Removing rule...\n";
				&linefilter($ipd, "deny", "", 1);
				$hit = 1;
				next;
			}
		}
		print $DENY $line."\n";
	}
	close ($DENY) or &error(__LINE__,"Could not close /etc/csf/csf.deny: $!");

	if ($hit and ($config{LF_PERMBLOCK} or $config{LF_NETBLOCK})) {
		sysopen (my $TEMPIP, "/var/lib/csf/csf.tempip", O_RDWR | O_CREAT);
		flock ($TEMPIP, LOCK_EX);
		my @data = <$TEMPIP>;
		chomp @data;
		seek ($TEMPIP, 0, 0);
		truncate ($TEMPIP, 0);
		foreach my $line (@data) {
			my ($oip,undef,undef,undef) = split(/\|/,$line,4);
			if ($oip eq $ip) {next}
			print $TEMPIP "$line\n";
		}
		close ($TEMPIP);
	}
	elsif ($hit == -1) {}
	elsif (!$hit) {
		print "csf: $ip not found in csf.deny\n";
	}
	return;
}
# end dokill
###############################################################################
# start dokillall
sub dokillall {

	&getethdev;

	sysopen (my $DENY, "/etc/csf/csf.deny", O_RDWR | O_CREAT) or &error(__LINE__,"Could not open /etc/csf/csf.deny: $!");
	flock ($DENY, LOCK_EX) or &error(__LINE__,"Could not lock /etc/csf/csf.deny: $!");
	my $text = join("", <$DENY>);
	my @deny = split(/$slurpreg/,$text);
	chomp @deny;
	seek ($DENY, 0, 0);
	truncate ($DENY, 0);
	my $hit = 0;
	foreach my $line (@deny) {
        $line =~ s/$cleanreg//g;
		if ($line =~ /^(\#|\n|Include)/) {
			print $DENY $line."\n";
		}
		elsif ($line =~ /do not delete/i) {
			print $DENY $line."\n";
			print "csf: skipped line: $line\n";
		}
		else {
			my ($ipd,$commentd) = split (/\s/,$line,2);
			&linefilter($ipd, "deny", "", 1);
		}
	}
	close ($DENY) or &error(__LINE__,"Could not close /etc/csf/csf.deny: $!");
	print "csf: all entries removed from csf.deny\n";
	return;
}
# end dokillall
###############################################################################
# start doakill
sub doakill {
	my $ip = $input{argument};

	if (!checkip(\$ip) and !(($ip =~ /:|\|/) and ($ip =~ /=/))) {
		print "[$ip] is not a valid PUBLIC IP/CIDR\n";
		return;
	}

	&getethdev;

	sysopen (my $ALLOW, "/etc/csf/csf.allow", O_RDWR | O_CREAT) or &error(__LINE__,"Could not open /etc/csf/csf.allow: $!");
	flock ($ALLOW, LOCK_EX) or &error(__LINE__,"Could not lock /etc/csf/csf.allow: $!");
	my $text = join("", <$ALLOW>);
	my @allow = split(/$slurpreg/,$text);
	chomp @allow;
	seek ($ALLOW, 0, 0);
	truncate ($ALLOW, 0);
	my $hit = 0;
	foreach my $line (@allow) {
        $line =~ s/$cleanreg//g;
		my ($ipd,$commentd) = split (/\s/,$line,2);
		checkip(\$ipd);
		if (uc $ipd eq uc $ip) {
			print "Removing rule...\n";
			&linefilter($ipd, "allow", "", 1);
			$hit = 1;
			next;
		}
		print $ALLOW $line."\n";
	}
	close ($ALLOW) or &error(__LINE__,"Could not close /etc/csf/csf.allow: $!");
	unless ($hit) {
		print "csf: $ip not found in csf.allow\n";
	}
	return;
}
# end doakill
###############################################################################
# start help
sub dohelp {
	my $generic = " (cPanel)";
	if ($config{GENERIC}) {$generic = " (generic)"}
	if ($config{DIRECTADMIN}) {$generic = " (DirectAdmin)"}
	print "csf: v$version$generic\n";
	open (my $IN, "<", "/usr/local/csf/lib/csf.help");
	flock ($IN, LOCK_SH);
	print <$IN>;
	close ($IN);
	return;
}
# end help
###############################################################################
# start dopacketfilters
sub dopacketfilters {
	if ($config{PACKET_FILTER} and $config{LF_SPI}) {
		if ($config{FASTSTART}) {$faststart = 1}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N INVDROP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N INVALID");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVALID $statemodule INVALID -j INVDROP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags ALL NONE -j INVDROP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags ALL ALL -j INVDROP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags SYN,FIN SYN,FIN -j INVDROP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags SYN,RST SYN,RST -j INVDROP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags FIN,RST FIN,RST -j INVDROP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags ACK,FIN FIN -j INVDROP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags ACK,PSH PSH -j INVDROP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags ACK,URG URG -j INVDROP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp ! --syn $statemodulenew -j INVDROP");
		if ($config{IPV6} and $config{IPV6_SPI}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N INVDROP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -N INVALID");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVALID $statemodule INVALID -j INVDROP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags ALL NONE -j INVDROP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags ALL ALL -j INVDROP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags SYN,FIN SYN,FIN -j INVDROP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags SYN,RST SYN,RST -j INVDROP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags FIN,RST FIN,RST -j INVDROP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags ACK,FIN FIN -j INVDROP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags ACK,PSH PSH -j INVDROP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp --tcp-flags ACK,URG URG -j INVDROP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVALID -p tcp ! --syn $statemodule6new -j INVDROP");
		}
		if ($config{FASTSTART}) {&faststart("Packet Filter")}

		if ($config{DROP_PF_LOGGING}) {
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVDROP $statemodule INVALID -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INVALID* '");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags ALL NONE -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_AN* '");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags ALL ALL -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_AA* '");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags SYN,FIN SYN,FIN -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_SFSF* '");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags SYN,RST SYN,RST -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_SRSR* '");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags FIN,RST FIN,RST -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_FRFR* '");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags ACK,FIN FIN -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_AFF* '");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags ACK,PSH PSH -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_APP* '");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags ACK,URG URG -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_AUU* '");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp ! --syn $statemodulenew -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_NOSYN* '");
			if ($config{IPV6} and $config{IPV6_SPI}) {
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVDROP $statemodule INVALID -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INVALID* '");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags ALL NONE -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_AN* '");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags ALL ALL -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_AA* '");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags SYN,FIN SYN,FIN -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_SFSF* '");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags SYN,RST SYN,RST -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_SRSR* '");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags FIN,RST FIN,RST -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_FRFR* '");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags ACK,FIN FIN -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_AFF* '");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags ACK,PSH PSH -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_APP* '");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp --tcp-flags ACK,URG URG -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_AUU* '");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -p tcp ! --syn $statemodule6new -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *INV_NOSYN* '");
			}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -j $config{DROP}");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -p tcp -j INVALID");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $ethdevout -p tcp -j INVALID");
		if ($config{IPV6} and $config{IPV6_SPI}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INVDROP -j $config{DROP}");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I INPUT $eth6devin -p tcp -j INVALID");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I OUTPUT $eth6devout -p tcp -j INVALID");
		}
	}
	return;
}
# end dopacketfilters
###############################################################################
# start doportfilters
sub doportfilters {
	my $dropin = $config{DROP};
	my $dropout = $config{DROP_OUT};
	if ($config{DROP_LOGGING}) {$dropin = "LOGDROPIN"}
	if ($config{DROP_LOGGING}) {$dropout = "LOGDROPOUT"}

	my @entries = slurp("/etc/csf/csf.sips");
	foreach my $line (@entries) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @entries,@incfile;
		}
	}
	foreach my $line (@entries) {
        $line =~ s/$cleanreg//g;
		if ($line eq "") {next}
		if ($line =~ /^\s*\#|Include/) {next}
		my ($ip,$comment) = split (/\s/,$line,2);
		my $iptype = checkip(\$ip);
		if ($iptype == 4) {
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -d $ip -j $dropin");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALOUTPUT $ethdevout -s $ip -j $dropout");
		}
		elsif ($iptype == 6) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $eth6devin -d $ip -j $dropin");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALOUTPUT $eth6devout -s $ip -j $dropout");
		}
	}

	if ($config{GLOBAL_DENY}) {
		if ($config{LF_IPSET}) {
			my $pktin = $config{DROP};
			my $pktout = $config{DROP_OUT};
			if ($config{DROP_IP_LOGGING}) {$pktin = "LOGDROPIN"}
			if ($config{DROP_OUT_LOGGING}) {$pktout = "LOGDROPOUT"}
			&ipsetcreate("chain_GDENY");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A GDENYIN -m set --match-set chain_GDENY src -j $pktin");
			unless ($config{LF_BLOCKINONLY}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A GDENYOUT -m set --match-set chain_GDENY dst -j $pktout")}
			if ($config{IPV6}) {
				&ipsetcreate("chain_6_GDENY");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A GDENYIN -m set --match-set chain_6_GDENY src -j $pktin");
				unless ($config{LF_BLOCKINONLY}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A GDENYOUT -m set --match-set chain_6_GDENY dst -j $pktout")}
			}
		}
		if (-e "/var/lib/csf/csf.gdeny") {
			if ($config{FASTSTART}) {$faststart = 1}
			foreach my $line (slurp("/var/lib/csf/csf.gdeny")) {
				$line =~ s/$cleanreg//g;
				if ($line =~ /^(\s|\#|$)/) {next}
				my ($ip,$comment) = split (/\s/,$line,2);
				&linefilter($ip, "deny","GDENY");
			}
			if ($config{FASTSTART}) {&faststart("Global Deny")}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j GDENYIN");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALOUTPUT $ethdevout -j GDENYOUT");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $eth6devin -j GDENYIN");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALOUTPUT $eth6devout -j GDENYOUT");
		}
	}

	my @deny = slurp("/etc/csf/csf.deny");
	foreach my $line (@deny) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @deny,@incfile;
		}
	}
	if ($config{FASTSTART}) {$faststart = 1}
	if ($config{LF_IPSET}) {
		my $pktin = $config{DROP};
		my $pktout = $config{DROP_OUT};
		if ($config{DROP_IP_LOGGING}) {$pktin = "LOGDROPIN"}
		if ($config{DROP_OUT_LOGGING}) {$pktout = "LOGDROPOUT"}
		&ipsetcreate("chain_DENY");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A DENYIN -m set --match-set chain_DENY src -j $pktin");
		unless ($config{LF_BLOCKINONLY}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A DENYOUT -m set --match-set chain_DENY dst -j $pktout")}
		if ($config{IPV6}) {
			&ipsetcreate("chain_6_DENY");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A DENYIN -m set --match-set chain_6_DENY src -j $pktin");
			unless ($config{LF_BLOCKINONLY}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A DENYOUT -m set --match-set chain_6_DENY dst -j $pktout")}
		}
	}
	foreach my $line (@deny) {
        $line =~ s/$cleanreg//g;
		if ($line eq "") {next}
		if ($line =~ /^\s*\#|Include/) {next}
		my ($ip,$comment) = split (/\s/,$line,2);
		&linefilter($ip, "deny");
	}
	if ($config{FASTSTART}) {&faststart("csf.deny")}

	if (! -z "/var/lib/csf/csf.tempban") {
		my $dropin = $config{DROP};
		my $dropout = $config{DROP_OUT};
		if ($config{DROP_IP_LOGGING}) {$dropin = "LOGDROPIN"}
		if ($config{DROP_OUT_LOGGING}) {$dropout = "LOGDROPOUT"}

		sysopen (my $TEMPBAN, "/var/lib/csf/csf.tempban", O_RDWR | O_CREAT);
		flock ($TEMPBAN, LOCK_EX);
		my @data = <$TEMPBAN>;
		chomp @data;

		my @newdata;
		foreach my $line (@data) {
			my ($time,$ip,$port,$inout,$timeout,$message) = split(/\|/,$line);
			my $iptype = checkip(\$ip);
			if ($iptype == 6 and !$config{IPV6}) {next}
			if ((((time - $time) < $timeout) and $iptype) or ($message =~ /\(CF:([^\)]+)\)/)) {
				if ($inout =~ /in/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A DENYIN $eth6devin -p $proto --dport $dport -s $ip -j $dropin");
								if ($messengerports{$dport} and $config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"A",$dport)}
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A DENYIN $ethdevin -p $proto --dport $dport -s $ip -j $dropin");
								if ($messengerports{$dport} and $config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"A",$dport)}
							}
						}
					} else {
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A DENYIN $eth6devin -s $ip -j $dropin");
							if ($config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"A")}
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A DENYIN $ethdevin -s $ip -j $dropin");
							if ($config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"A")}
						}
					}
				}
				if ($inout =~ /out/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A DENYOUT $eth6devout -p $proto --dport $dport -d $ip -j $dropout");
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A DENYOUT $ethdevout -p $proto --dport $dport -d $ip -j $dropout");
							}
						}
					} else {
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A DENYOUT $eth6devout -d $ip -j $dropout");
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A DENYOUT $ethdevout -d $ip -j $dropout");
						}
					}
				}
				push @newdata, $line;
			}
		}
		seek ($TEMPBAN, 0, 0);
		truncate ($TEMPBAN, 0);
		foreach my $line (@newdata) {print $TEMPBAN "$line\n"}
		close ($TEMPBAN);
	}

	if (! -z "/var/lib/csf/csf.tempallow") {
		sysopen (my $TEMPALLOW, "/var/lib/csf/csf.tempallow", O_RDWR | O_CREAT);
		flock ($TEMPALLOW, LOCK_EX);
		my @data = <$TEMPALLOW>;
		chomp @data;

		my @newdata;
		foreach my $line (@data) {
			my ($time,$ip,$port,$inout,$timeout,$message) = split(/\|/,$line);
			my $iptype = checkip(\$ip);
			if ($iptype == 6 and !$config{IPV6}) {next}
			if ((((time - $time) < $timeout) and $iptype) or ($message =~ /\(CF:([^\)]+)\)/)) {
				if ($inout =~ /in/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I ALLOWIN $eth6devin -p $proto --dport $dport -s $ip -j $accept");
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I ALLOWIN $ethdevin -p $proto --dport $dport -s $ip -j $accept");
							}
						}
					} else {
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I ALLOWIN $eth6devin -s $ip -j $accept");
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I ALLOWIN $ethdevin -s $ip -j $accept");
						}
					}
				}
				if ($inout =~ /out/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I ALLOWOUT $eth6devout -p $proto --dport $dport -d $ip -j $accept");
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I ALLOWOUT $ethdevout -p $proto --dport $dport -d $ip -j $accept");
							}
						}
					} else {
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I ALLOWOUT $eth6devout -d $ip -j $accept");
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I ALLOWOUT $ethdevout -d $ip -j $accept");
						}
					}
				}
				push @newdata, $line;
			}
		}
		seek ($TEMPALLOW, 0, 0);
		truncate ($TEMPALLOW, 0);
		foreach my $line (@newdata) {print $TEMPALLOW "$line\n"}
		close ($TEMPALLOW);
	}

	if ($config{GLOBAL_ALLOW}) {
		if ($config{LF_IPSET}) {
			&ipsetcreate("chain_GALLOW");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A GALLOWIN -m set --match-set chain_GALLOW src -j $accept");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A GALLOWOUT -m set --match-set chain_GALLOW dst -j $accept");
			if ($config{IPV6}) {
				&ipsetcreate("chain_6_GALLOW");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A GALLOWIN -m set --match-set chain_6_GALLOW src -j $accept");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A GALLOWOUT -m set --match-set chain_6_GALLOW dst -j $accept");
			}
		}
		if (-e "/var/lib/csf/csf.gallow") {
			if ($config{FASTSTART}) {$faststart = 1}
			foreach my $line (slurp("/var/lib/csf/csf.gallow")) {
				$line =~ s/$cleanreg//g;
				if ($line =~ /^(\s|\#|$)/) {next}
				my ($ip,$comment) = split (/\s/,$line,2);
				&linefilter($ip, "allow","GALLOW");
			}
			if ($config{FASTSTART}) {&faststart("Global Allow")}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I LOCALINPUT $ethdevin -j GALLOWIN");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I LOCALOUTPUT $ethdevout -j GALLOWOUT");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I LOCALINPUT $eth6devin -j GALLOWIN");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I LOCALOUTPUT $eth6devout -j GALLOWOUT");
		}
	}

	$config{CC_ALLOW} =~ s/\s//g;
	if ($config{CC_ALLOW}) {
		foreach my $cc (split(/\,/,$config{CC_ALLOW})) {
			$cc = lc $cc;
			if ($config{LF_IPSET}) {
				&ipsetcreate("cc_$cc");
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOW -m set --match-set cc_$cc src -j $accept");
				if ($config{CC6_LOOKUPS} and $config{IPV6}) {
					&ipsetcreate("cc_6_$cc");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOW -m set --match-set cc_6_$cc src -j $accept");
				}
			}
			if (-e "/var/lib/csf/zone/$cc.zone") {
				if ($config{LF_IPSET}) {
					undef @ipset;
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
							my ($drop_ip,$drop_cidr) = split(/\//,$ip);
							if ($drop_cidr eq "") {$drop_cidr = "32"}
							if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
						}
						if (cccheckip(\$ip)) {push @ipset,"add -exist cc_$cc $ip"}
					}
					&ipsetrestore("cc_$cc");
				} else {
					if ($config{FASTSTART}) {$faststart = 1}
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {
							if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
								my ($drop_ip,$drop_cidr) = split(/\//,$ip);
								if ($drop_cidr eq "") {$drop_cidr = "32"}
								if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
							}
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOW -s $ip -j $accept");
						}
					}
					if ($config{FASTSTART}) {&faststart("CC_ALLOW [$cc]")}
				}
			}
			if ($config{CC6_LOOKUPS} and -e "/var/lib/csf/zone/$cc.zone6") {
				if ($config{LF_IPSET}) {
					undef @ipset;
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone6")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {push @ipset,"add -exist cc_6_$cc $ip"}
					}
					&ipsetrestore("cc_6_$cc");
				} else {
					if ($config{FASTSTART}) {$faststart = 1}
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone6")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOW -s $ip -j $accept");
						}
					}
					if ($config{FASTSTART}) {&faststart("CC_ALLOW [$cc]")}
				}
			}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I LOCALINPUT $ethdevin -j CC_ALLOW");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I LOCALINPUT $ethdevin -j CC_ALLOW");
		}
	}

	if ($config{DYNDNS}) {
		if ($config{LF_IPSET}) {
			&ipsetcreate("chain_ALLOWDYN");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A ALLOWDYNIN -m set --match-set chain_ALLOWDYN src -j $accept");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A ALLOWDYNOUT -m set --match-set chain_ALLOWDYN dst -j $accept");
			if ($config{IPV6}) {
				&ipsetcreate("chain_6_ALLOWDYN");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A ALLOWDYNIN -m set --match-set chain_6_ALLOWDYN src -j $accept");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A ALLOWDYNOUT -m set --match-set chain_6_ALLOWDYN dst -j $accept");
			}
		}
		if (-e "/var/lib/csf/csf.tempdyn") {
			foreach my $line (slurp("/var/lib/csf/csf.tempdyn")) {
				$line =~ s/$cleanreg//g;
				if ($line =~ /^(\s|\#|$)/) {next}
				my ($ip,$comment) = split (/\s/,$line,2);
				&linefilter($ip, "allow","ALLOWDYN");
			}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I LOCALINPUT $ethdevin -j ALLOWDYNIN");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I LOCALOUTPUT $ethdevout -j ALLOWDYNOUT");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I LOCALINPUT $ethdevin -j ALLOWDYNIN");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I LOCALOUTPUT $ethdevout -j ALLOWDYNOUT");
		}
	}
	if ($config{GLOBAL_DYNDNS}) {
		if ($config{LF_IPSET}) {
			&ipsetcreate("chain_GDYN");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A GDYNIN -m set --match-set chain_GDYN src -j $accept");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A GDYNOUT -m set --match-set chain_GDYN dst -j $accept");
			if ($config{IPV6}) {
				&ipsetcreate("chain_6_GDYN");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A GDYNIN -m set --match-set chain_6_GDYN src -j $accept");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A GDYNOUT -m set --match-set chain_6_GDYN dst -j $accept");
			}
		}
		if (-e "/var/lib/csf/csf.tempgdyn") {
			if ($config{FASTSTART}) {$faststart = 1}
			foreach my $line (slurp("/var/lib/csf/csf.tempgdyn")) {
				$line =~ s/$cleanreg//g;
				if ($line =~ /^(\s|\#|$)/) {next}
				my ($ip,$comment) = split (/\s/,$line,2);
				&linefilter($ip, "allow","GDYN");
			}
			if ($config{FASTSTART}) {&faststart("Global Dynamic DNS")}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I LOCALINPUT $ethdevin -j GDYNIN");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I LOCALOUTPUT $ethdevout -j GDYNOUT");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I LOCALINPUT $ethdevin -j GDYNIN");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I LOCALOUTPUT $ethdevout -j GDYNOUT");
		}
	}

	my @allow = slurp("/etc/csf/csf.allow");
	foreach my $line (@allow) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @allow,@incfile;
		}
	}
	if ($config{FASTSTART}) {$faststart = 1}
	if ($config{LF_IPSET}) {
		&ipsetcreate("chain_ALLOW");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A ALLOWIN -m set --match-set chain_ALLOW src -j $accept");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A ALLOWOUT -m set --match-set chain_ALLOW dst -j $accept");
		if ($config{IPV6}) {
			&ipsetcreate("chain_6_ALLOW");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A ALLOWIN -m set --match-set chain_6_ALLOW src -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A ALLOWOUT -m set --match-set chain_6_ALLOW dst -j $accept");
		}
	}

	foreach my $line (@allow)
	{
        $line =~ s/$cleanreg//g;
		if ($line eq "") {next}
		if ($line =~ /^\s*\#|Include/) {next}
		my ($ip,$comment) = split (/\s/,$line,2);
		&linefilter($ip, "allow");
	}

	if ($config{FASTSTART})
	{
		&faststart("csf.allow")
	}

	foreach my $name (keys %blocklists)
	{
		my $drop = $config{DROP};
		if ($config{DROP_IP_LOGGING}) {$drop = "BLOCKDROP"}
		if ($config{LF_IPSET}) {
			&ipsetcreate("bl_$name");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A $name -m set --match-set bl_$name src -j $drop");
			if ($config{IPV6}) {
				&ipsetcreate("bl_6_$name");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A $name -m set --match-set bl_6_$name src -j $drop");
			}
		}

		if (-e "/var/lib/csf/csf.block.$name")
		{
			if ($config{LF_IPSET})
			{
				undef @ipset;
				my @ipset6;
				foreach my $line (slurp("/var/lib/csf/csf.block.$name"))
				{
					$line =~ s/$cleanreg//g;
					if ($line =~ /^(\s|\#|$)/) {next}
					my ($ip,$comment) = split (/\s/,$line,2);
					my $iptype = checkip(\$ip);
					if ($iptype == 4)
					{
						push @ipset,"add -exist bl_$name $ip";
					}
					elsif ($iptype == 6 and $config{IPV6}) {
						push @ipset6,"add -exist bl_6_$name $ip";
					}
				}
				&ipsetrestore("bl_$name");
				if ($config{IPV6})
				{
					@ipset = @ipset6;
					&ipsetrestore("bl_6_$name");
				}
			}
			else
			{
				if ($config{FASTSTART}) {$faststart = 1}
				foreach my $line (slurp("/var/lib/csf/csf.block.$name")) {
					$line =~ s/$cleanreg//g;
					if ($line =~ /^(\s|\#|$)/) {next}
					my ($ip,$comment) = split (/\s/,$line,2);
					my $iptype = checkip(\$ip);
					if ($iptype == 4) {
						&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A $name -s $ip -j $drop");
					}
					elsif ($iptype == 6 and $config{IPV6}) {
						&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A $name -s $ip -j $drop");
					}
				}
				if ($config{FASTSTART}) {&faststart("Blocklist $name")}
			}
		}
		$config{LF_BOGON_SKIP} =~ s/\s//g;
		if ($name eq "BOGON" and $config{LF_BOGON_SKIP} ne "") {
			foreach my $device (split(/\,/,$config{LF_BOGON_SKIP})) {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I BOGON -i $device -j RETURN");
			}
		}
		if ($cxsreputation and $name =~ /^CXS_/ and $name ne "CXS_ALL" and $cxsports{$name} ne "")
		{
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT -p tcp -m multiport --dport $cxsports{$name} $ethdevin -j $name");
			if ($config{IPV6}) {
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT -p tcp -m multiport --dport $cxsports{$name} $ethdevin -j $name");
			}
		}
		else
		{
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j $name");
			if ($config{IPV6})
			{
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j $name");
			}
		}
	}

	$config{CC_ALLOW_SMTPAUTH} =~ s/\s//g;
	if ($config{SMTPAUTH_RESTRICT}) {
		if ($verbose) {print "csf: Generating /etc/exim.smtpauth\n"}
		sysopen (my $SMTPAUTH, "/etc/exim.smtpauth", O_WRONLY | O_CREAT);
		flock ($SMTPAUTH, LOCK_EX);
		seek ($SMTPAUTH, 0, 0);
		truncate ($SMTPAUTH, 0);
		print $SMTPAUTH "# DO NOT EDIT THIS FILE\n#\n";
		print $SMTPAUTH "# Modify /etc/csf/csf.smtpauth and then restart csf and then lfd\n\n";
		print $SMTPAUTH "127.0.0.0/8\n";
		print $SMTPAUTH "\"::1\"\n";
		print $SMTPAUTH "\"::1/128\"\n";
		if (-e "/etc/csf/csf.smtpauth") {
			my @entries = slurp("/etc/csf/csf.smtpauth");
			foreach my $line (@entries) {
				if ($line =~ /^Include\s*(.*)$/) {
					my @incfile = slurp($1);
					push @entries,@incfile;
				}
			}
			foreach my $line (@entries) {
				$line =~ s/$cleanreg//g;
				if ($line eq "") {next}
				if ($line =~ /^\s*\#|Include/) {next}
				my ($ip,undef) = split (/\s/,$line,2);
				my $status = checkip(\$ip);
				if ($status == 4) {print $SMTPAUTH "$ip\n"}
				elsif ($status == 6) {print $SMTPAUTH "\"$ip\"\n"}
			}
		}
		foreach my $cc (split(/\,/,$config{CC_ALLOW_SMTPAUTH})) {
			$cc = lc $cc;
			if (-e "/var/lib/csf/zone/$cc.zone") {
				print $SMTPAUTH "\n# IPv4 addresses for [".uc($cc)."]:\n";
				foreach my $line (slurp("/var/lib/csf/zone/$cc.zone")) {
					$line =~ s/$cleanreg//g;
					if ($line =~ /^(\s|\#|$)/) {next}
					my ($ip,undef) = split (/\s/,$line,2);
					if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
						my ($drop_ip,$drop_cidr) = split(/\//,$ip);
						if ($drop_cidr eq "") {$drop_cidr = "32"}
						if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
					}
					my $status = cccheckip(\$ip);
					if ($status == 4) {print $SMTPAUTH "$ip\n"}
					elsif ($status == 6) {print $SMTPAUTH "\"$ip\"\n"}
				}
			}
			if ($config{CC6_LOOKUPS} and -e "/var/lib/csf/zone/$cc.zone6") {
				print $SMTPAUTH "\n# IPv6 addresses for [".uc($cc)."]:\n";
				foreach my $line (slurp("/var/lib/csf/zone/$cc.zone6")) {
					$line =~ s/$cleanreg//g;
					if ($line =~ /^(\s|\#|$)/) {next}
					my ($ip,undef) = split (/\s/,$line,2);
					my $status = cccheckip(\$ip);
					if ($status == 4) {print $SMTPAUTH "$ip\n"}
					elsif ($status == 6) {print $SMTPAUTH "\"$ip\"\n"}
				}
			}
		}
		close ($SMTPAUTH);
		chmod (0644,"/etc/exim.smtpauth");
	}

	$config{CC_DENY} =~ s/\s//g;
	if ($config{CC_DENY}) {
		foreach my $cc (split(/\,/,$config{CC_DENY})) {
			$cc = lc $cc;
			my $drop = $config{DROP};
			if ($config{DROP_IP_LOGGING}) {$drop = "CCDROP"}
			if ($config{LF_IPSET}) {
				&ipsetcreate("cc_$cc");
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I CC_DENY -m set --match-set cc_$cc src -j $drop");
				if ($config{CC6_LOOKUPS} and $config{IPV6}) {
					&ipsetcreate("cc_6_$cc");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I CC_DENY -m set --match-set cc_6_$cc src -j $drop");
				}
			}
			if (-e "/var/lib/csf/zone/$cc.zone") {
				if ($config{LF_IPSET}) {
					undef @ipset;
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
							my ($drop_ip,$drop_cidr) = split(/\//,$ip);
							if ($drop_cidr eq "") {$drop_cidr = "32"}
							if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
						}
						if (cccheckip(\$ip)) {push @ipset,"add -exist cc_$cc $ip"}
					}
					&ipsetrestore("cc_$cc");
				} else {
					if ($config{FASTSTART}) {$faststart = 1}
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
							my ($drop_ip,$drop_cidr) = split(/\//,$ip);
							if ($drop_cidr eq "") {$drop_cidr = "32"}
							if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
						}
						if (cccheckip(\$ip)) {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I CC_DENY -s $ip -j $drop");
						}
					}
					if ($config{FASTSTART}) {&faststart("CC_DENY [$cc]")}
				}
			}
			if ($config{CC6_LOOKUPS} and -e "/var/lib/csf/zone/$cc.zone6") {
				if ($config{LF_IPSET}) {
					undef @ipset;
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone6")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {push @ipset,"add -exist cc_6_$cc $ip"}
					}
					&ipsetrestore("cc_6_$cc");
				} else {
					if ($config{FASTSTART}) {$faststart = 1}
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone6")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I CC_DENY -s $ip -j $drop");
						}
					}
					if ($config{FASTSTART}) {&faststart("CC_DENY [$cc]")}
				}
			}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j CC_DENY");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j CC_DENY");
		}
	}


	$config{CC_ALLOW_FILTER} =~ s/\s//g;
	if ($config{CC_ALLOW_FILTER}) {
		my $cnt = 0;
		my $cnt6 = 0;
		foreach my $cc (split(/\,/,$config{CC_ALLOW_FILTER})) {
			$cc = lc $cc;
			if ($config{LF_IPSET}) {
				&ipsetcreate("cc_$cc");
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWF -m set --match-set cc_$cc src -j RETURN");
				if ($config{CC6_LOOKUPS} and $config{IPV6}) {
					&ipsetcreate("cc_6_$cc");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWF -m set --match-set cc_6_$cc src -j RETURN");
				}
			}
			if (-e "/var/lib/csf/zone/$cc.zone") {
				if ($config{LF_IPSET}) {
					undef @ipset;
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
							my ($drop_ip,$drop_cidr) = split(/\//,$ip);
							if ($drop_cidr eq "") {$drop_cidr = "32"}
							if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
						}
						if (cccheckip(\$ip)) {
							push @ipset,"add -exist cc_$cc $ip";
							$cnt++;
						}
					}
					&ipsetrestore("cc_$cc");
				} else {
					if ($config{FASTSTART}) {$faststart = 1}
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {
							if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
								my ($drop_ip,$drop_cidr) = split(/\//,$ip);
								if ($drop_cidr eq "") {$drop_cidr = "32"}
								if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
							}
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWF -s $ip -j RETURN");
							$cnt++;
						}
					}
					if ($config{FASTSTART}) {&faststart("CC_ALLOW_FILTER [$cc]")}
				}
			}
			if ($config{CC6_LOOKUPS} and -e "/var/lib/csf/zone/$cc.zone6") {
				if ($config{LF_IPSET}) {
					undef @ipset;
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone6")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {
							push @ipset,"add -exist cc_6_$cc $ip";
							$cnt6++;
						}
					}
					&ipsetrestore("cc_6_$cc");
				} else {
					if ($config{FASTSTART}) {$faststart = 1}
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone6")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWF -s $ip -j RETURN");
							$cnt6++;
						}
					}
					if ($config{FASTSTART}) {&faststart("CC_ALLOW_FILTER [$cc]")}
				}
			}
		}
		my $drop = $config{DROP};
		if ($config{DROP_IP_LOGGING}) {$drop = "CCDROP"}
		if ($cnt > 0) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWF -j $drop")};
		if ($config{LF_SPI}) {
			if ($config{USE_FTPHELPER}) {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I CC_ALLOWF $ethdevin $statemodule RELATED -m helper --helper ftp -j $accept");

				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I CC_ALLOWF $ethdevin $statemodule ESTABLISHED -j $accept");
			} else {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I CC_ALLOWF $ethdevin $statemodule ESTABLISHED,RELATED -j $accept");
			}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j CC_ALLOWF");
		if ($config{IPV6}) {
			if ($cnt6 > 0) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWF -j $drop")};
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j CC_ALLOWF");
			if ($config{IPV6_SPI}) {
				if ($config{USE_FTPHELPER}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I CC_ALLOWF $ethdevin $statemodule RELATED -m helper --helper ftp -j $accept");

					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I CC_ALLOWF $ethdevin $statemodule ESTABLISHED -j $accept");
				} else {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I CC_ALLOWF $ethdevin $statemodule ESTABLISHED,RELATED -j $accept");
				}
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -I CC_ALLOWF $eth6devin -p icmpv6 -j $accept");
			}
		}
	}

	$config{CC_ALLOW_PORTS} =~ s/\s//g;
	if ($config{CC_ALLOW_PORTS}) {
		$config{CC_ALLOW_PORTS_TCP} =~ s/\s//g;
		$config{CC_ALLOW_PORTS_UDP} =~ s/\s//g;
		if ($config{CC_ALLOW_PORTS_TCP} ne "") {
			foreach my $port (split(/\,/,$config{CC_ALLOW_PORTS_TCP})) {
				if ($port eq "") {next}
				if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid CC_ALLOW_PORTS_TCP port [$port]")}
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWPORTS $ethdevin -p tcp $statemodulenew --dport $port -j $accept");
				if ($config{CC6_LOOKUPS} and $config{IPV6}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWPORTS $ethdevin -p tcp $statemodulenew --dport $port -j $accept");
				}
			}
		}
		if ($config{CC_ALLOW_PORTS_UDP} ne "") {
			foreach my $port (split(/\,/,$config{CC_ALLOW_PORTS_UDP})) {
				if ($port eq "") {next}
				if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid CC_ALLOW_PORTS_UDP port [$port]")}
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWPORTS $ethdevin -p udp $statemodulenew --dport $port -j $accept");
				if ($config{CC6_LOOKUPS} and $config{IPV6}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWPORTS $ethdevin -p udp $statemodulenew --dport $port -j $accept");
				}
			}
		}
		my $cnt = 0;
		foreach my $cc (split(/\,/,$config{CC_ALLOW_PORTS})) {
			$cc = lc $cc;
			if ($config{LF_IPSET}) {
				&ipsetcreate("cc_$cc");
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWP -m set --match-set cc_$cc src -j CC_ALLOWPORTS");
				if ($config{CC6_LOOKUPS} and $config{IPV6}) {
					&ipsetcreate("cc_6_$cc");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWP -m set --match-set cc_6_$cc src -j CC_ALLOWPORTS");
				}
			}
			if (-e "/var/lib/csf/zone/$cc.zone") {
				if ($config{LF_IPSET}) {
					undef @ipset;
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
							my ($drop_ip,$drop_cidr) = split(/\//,$ip);
							if ($drop_cidr eq "") {$drop_cidr = "32"}
							if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
						}
						if (cccheckip(\$ip)) {push @ipset,"add -exist cc_$cc $ip"}
					}
					&ipsetrestore("cc_$cc");
				} else {
					if ($config{FASTSTART}) {$faststart = 1}
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {
							if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
								my ($drop_ip,$drop_cidr) = split(/\//,$ip);
								if ($drop_cidr eq "") {$drop_cidr = "32"}
								if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
							}
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWP -s $ip -j CC_ALLOWPORTS");
							$cnt++;
						}
					}
					if ($config{FASTSTART}) {&faststart("CC_ALLOW_PORTS [$cc]")}
				}
			}
			if ($config{CC6_LOOKUPS} and -e "/var/lib/csf/zone/$cc.zone6") {
				if ($config{LF_IPSET}) {
					undef @ipset;
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone6")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {push @ipset,"add -exist cc_6_$cc $ip"}
					}
					&ipsetrestore("cc_6_$cc");
				} else {
					if ($config{FASTSTART}) {$faststart = 1}
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone6")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CC_ALLOWP -s $ip -j CC_ALLOWPORTS");
							$cnt++;
						}
					}
					if ($config{FASTSTART}) {&faststart("CC_ALLOW_PORTS [$cc]")}
				}
			}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j CC_ALLOWP");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j CC_ALLOWP");
		}
	}

	$config{CC_DENY_PORTS} =~ s/\s//g;
	if ($config{CC_DENY_PORTS}) {
		$config{CC_DENY_PORTS_TCP} =~ s/\s//g;
		$config{CC_DENY_PORTS_UDP} =~ s/\s//g;
		if ($config{CC_DENY_PORTS_TCP} ne "") {
			foreach my $port (split(/\,/,$config{CC_DENY_PORTS_TCP})) {
				if ($port eq "") {next}
				if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid CC_DENY_PORTS_TCP port [$port]")}
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CC_DENYPORTS $ethdevin -p tcp --dport $port -j $config{DROP}");
				if ($config{CC6_LOOKUPS} and $config{IPV6}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CC_DENYPORTS $ethdevin -p tcp --dport $port -j $config{DROP}");
				}
			}
		}
		if ($config{CC_DENY_PORTS_UDP} ne "") {
			foreach my $port (split(/\,/,$config{CC_DENY_PORTS_UDP})) {
				if ($port eq "") {next}
				if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid CC_DENY_PORTS_UDP port [$port]")}
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CC_DENYPORTS $ethdevin -p udp --dport $port -j $config{DROP}");
				if ($config{CC6_LOOKUPS} and $config{IPV6}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CC_DENYPORTS $ethdevin -p udp --dport $port -j $config{DROP}");

				}
			}
		}
		my $cnt = 0;
		foreach my $cc (split(/\,/,$config{CC_DENY_PORTS})) {
			$cc = lc $cc;
			if ($config{LF_IPSET}) {
				&ipsetcreate("cc_$cc");
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I CC_DENYP -m set --match-set cc_$cc src -j CC_DENYPORTS");
				if ($config{CC6_LOOKUPS} and $config{IPV6}) {
					&ipsetcreate("cc_6_$cc");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I CC_DENYP -m set --match-set cc_6_$cc src -j CC_DENYPORTS");
				}
			}
			if (-e "/var/lib/csf/zone/$cc.zone") {
				if ($config{LF_IPSET}) {
					undef @ipset;
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
							my ($drop_ip,$drop_cidr) = split(/\//,$ip);
							if ($drop_cidr eq "") {$drop_cidr = "32"}
							if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
						}
						if (cccheckip(\$ip)) {push @ipset,"add -exist cc_$cc $ip"}
					}
					&ipsetrestore("cc_$cc");
				} else {
					if ($config{FASTSTART}) {$faststart = 1}
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {
							if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
								my ($drop_ip,$drop_cidr) = split(/\//,$ip);
								if ($drop_cidr eq "") {$drop_cidr = "32"}
								if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
							}
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CC_DENYP -s $ip -j CC_DENYPORTS");
							$cnt++;
						}
					}
					if ($config{FASTSTART}) {&faststart("CC_DENY_PORTS [$cc]")}
				}
			}
			if ($config{CC6_LOOKUPS} and -e "/var/lib/csf/zone/$cc.zone6") {
				if ($config{LF_IPSET}) {
					undef @ipset;
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone6")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {push @ipset,"add -exist cc_6_$cc $ip"}
					}
					&ipsetrestore("cc_6_$cc");
				} else {
					if ($config{FASTSTART}) {$faststart = 1}
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone6")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if (cccheckip(\$ip)) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CC_DENYP -s $ip -j CC_DENYPORTS");
							$cnt++;
						}
					}
					if ($config{FASTSTART}) {&faststart("CC_DENY_PORTS [$cc]")}
				}
			}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j CC_DENYP");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALINPUT $ethdevin -j CC_DENYP");
		}
	}

	if ($config{CLUSTER_SENDTO}) {
		foreach my $ip (split(/\,/,$config{CLUSTER_SENDTO})) {
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I LOCALOUTPUT $ethdevout -p tcp -d $ip --dport $config{CLUSTER_PORT} -j $accept");
		}
	}
	if ($config{CLUSTER_RECVFROM}) {
		foreach my $ip (split(/\,/,$config{CLUSTER_RECVFROM})) {
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I LOCALINPUT $ethdevin -p tcp -s $ip --dport $config{CLUSTER_PORT} -j $accept");
		}
	}

	if ($config{SYNFLOOD}) {
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A SYNFLOOD -m limit --limit $config{SYNFLOOD_RATE} --limit-burst $config{SYNFLOOD_BURST} -j RETURN");
		if ($config{DROP_LOGGING}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A SYNFLOOD -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *SYNFLOOD Blocked* '")}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A SYNFLOOD -j DROP");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -p tcp --syn -j SYNFLOOD");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A SYNFLOOD -m limit --limit $config{SYNFLOOD_RATE} --limit-burst $config{SYNFLOOD_BURST} -j RETURN");
			if ($config{DROP_LOGGING}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A SYNFLOOD -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *SYNFLOOD Blocked* '")}
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A SYNFLOOD -j DROP");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I INPUT $ethdevin -p tcp --syn -j SYNFLOOD");
		}
	}

	$config{PORTFLOOD} =~ s/\s//g;
	if ($config{PORTFLOOD}) {
		my $maxrecent = 20;
		if (-e "/sys/module/ipt_recent/parameters/ip_pkt_list_tot") {
			my @new = slurp("/sys/module/ipt_recent/parameters/ip_pkt_list_tot");
			if ($new[0] > 1) {$maxrecent = $new[0]}
		}
		if (-e "/sys/module/xt_recent/parameters/ip_pkt_list_tot") {
			my @new = slurp("/sys/module/xt_recent/parameters/ip_pkt_list_tot");
			if ($new[0] > 1) {$maxrecent = $new[0]}
		}
		foreach my $portflood (split(/\,/,$config{PORTFLOOD})) {
			my ($port,$proto,$count,$seconds) = split(/\;/,$portflood);
			if ((($port < 0) or ($port > 65535)) or ($proto !~ /icmp|tcp|udp/) or ($seconds !~ /\d+/)) {&error(__LINE__,"csf: Incorrect PORTFLOOD setting: [$portflood]")}
			if (($count < 1) or ($count > $maxrecent)) {
				print "WARNING: count in PORTFLOOD setting must be between 1 and $maxrecent: [$portflood]\n";
			} else {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p $proto --dport $port $statemodulenew -m recent --set --name $port");
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p $proto --dport $port $statemodulenew -m recent --update --seconds $seconds --hitcount $count --name $port -j PORTFLOOD");
				if ($config{PORTFLOOD6}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p $proto --dport $port $statemodulenew -m recent --set --name $port");
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p $proto --dport $port $statemodulenew -m recent --update --seconds $seconds --hitcount $count --name $port -j PORTFLOOD");
				}
			}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A PORTFLOOD -j $config{DROP}");
		if ($config{PORTFLOOD6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A PORTFLOOD -j $config{DROP}");
		}
	}

	$config{CONNLIMIT} =~ s/\s//g;
	if ($config{CONNLIMIT}) {
		foreach my $connlimit (split(/\,/,$config{CONNLIMIT})) {
			my ($port,$limit) = split(/\;/,$connlimit);
			if (($port < 0) or ($port > 65535) or ($limit < 1) or ($limit !~ /\d+/)) {&error(__LINE__,"csf: Incorrect CONNLIMIT setting: [$connlimit]")}
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p tcp --syn --dport $port -m connlimit --connlimit-above $limit -j CONNLIMIT");
			if ($config{CONNLIMIT6}) {
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p tcp --syn --dport $port -m connlimit --connlimit-above $limit -j CONNLIMIT");
			}
		}
		if ($config{CONNLIMIT_LOGGING}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CONNLIMIT -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *ConnLimit* '");}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A CONNLIMIT -p tcp -j REJECT --reject-with tcp-reset");
		if ($config{CONNLIMIT6}) {
			if ($config{CONNLIMIT_LOGGING}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CONNLIMIT -m limit --limit 30/m --limit-burst 5 -j $logintarget 'Firewall: *ConnLimit* '");}
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A CONNLIMIT -p tcp -j REJECT --reject-with tcp-reset");
		}
	}

	if ($config{UDPFLOOD}) {
		foreach my $item (split(/\,/,$config{UDPFLOOD_ALLOWUSER})) {
			$item =~ s/\s//g;
			my $uid = (getpwnam($item))[2];
			if ($uid) {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A UDPFLOOD -p udp -m owner --uid-owner $uid -j RETURN",1);
				if ($config{IPV6}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A UDPFLOOD -p udp -m owner --uid-owner $uid -j RETURN",1);
				}
			}
		}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A UDPFLOOD -p udp -m owner --uid-owner 0 -j RETURN",1);
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A UDPFLOOD $ethdevout -p udp -m limit --limit $config{UDPFLOOD_LIMIT} --limit-burst $config{UDPFLOOD_BURST} -j RETURN");
		if ($config{UDPFLOOD_LOGGING}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A UDPFLOOD -m limit --limit 30/m --limit-burst 5 -j $logouttarget 'Firewall: *UDPFLOOD* '");}
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A UDPFLOOD $ethdevout -p udp -j $config{DROP_OUT}");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A LOCALOUTPUT $ethdevout -p udp -j UDPFLOOD");
		if ($config{IPV6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A UDPFLOOD -p udp -m owner --uid-owner 0 -j RETURN",1);
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A UDPFLOOD $ethdevout -p udp -m limit --limit $config{UDPFLOOD_LIMIT} --limit-burst $config{UDPFLOOD_BURST} -j RETURN");
			if ($config{UDPFLOOD_LOGGING}) {&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A UDPFLOOD -m limit --limit 30/m --limit-burst 5 -j $logouttarget 'Firewall: *UDPFLOOD* '");}
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A UDPFLOOD $ethdevout -p udp -j $config{DROP_OUT}");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A LOCALOUTPUT $ethdevout -p udp -j UDPFLOOD");
		}
	}
	my $icmp_in_rate = "";
	my $icmp_out_rate = "";
	if ($config{ICMP_IN_RATE}) {$icmp_in_rate = "-m limit --limit $config{ICMP_IN_RATE}"}
	if ($config{ICMP_OUT_RATE}) {$icmp_out_rate = "-m limit --limit $config{ICMP_OUT_RATE}"}

	if ($config{ICMP_IN}) {
		if ($config{ICMP_IN_RATE}) {
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p icmp --icmp-type echo-request $icmp_in_rate -j $accept");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p icmp --icmp-type echo-request -j $dropin");
		}
	} else {
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p icmp --icmp-type echo-request -j $dropin");
	}
	if ($config{ICMP_TIMESTAMPDROP}) {
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p icmp --icmp-type timestamp-request -j $dropin");
	}
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p icmp -j $accept");

	if ($config{ICMP_OUT}) {
		if ($config{ICMP_OUT_RATE}) {
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -p icmp --icmp-type echo-request $icmp_out_rate -j $accept");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -p icmp --icmp-type echo-request -j $dropout");
		}
	} else {
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -p icmp --icmp-type echo-request -j $dropout");
	}
	if ($config{ICMP_TIMESTAMPDROP}) {
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -p icmp --icmp-type timestamp-reply -j $dropout");
	}
	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -p icmp -j $accept");

	if ($config{IPV6}) {
		if ($config{IPV6_ICMP_STRICT}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type destination-unreachable -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type packet-too-big -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type time-exceeded -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type parameter-problem -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type echo-request -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type echo-reply -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type router-advertisement -m hl --hl-eq 255 -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type neighbor-solicitation -m hl --hl-eq 255 -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type neighbor-advertisement -m hl --hl-eq 255 -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type redirect -m hl --hl-eq 255 -j $accept");
		} else {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 -j $accept");
		}

		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 -j $accept");
#		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type destination-unreachable -j $accept");
#		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type packet-too-big -j $accept");
#		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type time-exceeded -j $accept");
#		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type parameter-problem -j $accept");
#		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type echo-request -j $accept");
#		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type echo-reply -j $accept");
#		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type router-advertisement -m hl --hl-eq 255 -j $accept");
#		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type neighbor-solicitation -m hl --hl-eq 255 -j $accept");
#		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type neighbor-advertisement -m hl --hl-eq 255 -j $accept");
#		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type redirect -m hl --hl-eq 255 -j $accept");
	}

	if ($config{LF_SPI}) {
		if ($config{USE_FTPHELPER}) {
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t raw -A PREROUTING -p tcp --dport $config{USE_FTPHELPER} -j CT --helper ftp");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t raw -A OUTPUT -p tcp --dport $config{USE_FTPHELPER} -j CT --helper ftp");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin $statemodule RELATED -m helper --helper ftp -j $accept");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout $statemodule RELATED -m helper --helper ftp -j $accept");

			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin $statemodule ESTABLISHED -j $accept");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout $statemodule ESTABLISHED -j $accept");
		} else {
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin $statemodule ESTABLISHED,RELATED -j $accept");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout $statemodule ESTABLISHED,RELATED -j $accept");
		}
	} else {
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p udp -m udp --dport 32768:61000 -j $accept");
		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p tcp -m tcp --dport 32768:61000 ! --syn -j $accept");
	}
	if ($config{IPV6}) {
		if ($config{IPV6_SPI}) {
			if ($config{USE_FTPHELPER}) {
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t raw -A PREROUTING -p tcp --dport $config{USE_FTPHELPER} -j CT --helper ftp");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t raw -A OUTPUT -p tcp --dport $config{USE_FTPHELPER} -j CT --helper ftp");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin $statemodule RELATED -m helper --helper ftp -j $accept");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout $statemodule RELATED -m helper --helper ftp -j $accept");
				
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INPUT $eth6devin $statemodule ESTABLISHED -j $accept");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $eth6devout $statemodule ESTABLISHED -j $accept");
			} else {
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INPUT $eth6devin $statemodule ESTABLISHED,RELATED -j $accept");
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $eth6devout $statemodule ESTABLISHED,RELATED -j $accept");
			}
		} else {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INPUT $eth6devin -p udp -m udp --dport 32768:61000 -j $accept");
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INPUT $eth6devin -p tcp -m tcp --dport 32768:61000 ! --syn -j $accept");
		}
	}

	$config{PORTKNOCKING} =~ s/\s//g;
	if ($config{PORTKNOCKING}) {
		foreach my $portknock (split(/\,/,$config{PORTKNOCKING})) {
			my ($port,$proto,$timeout,$knocks) = split(/\;/,$portknock,4);
			my @steps = split(/\;/,$knocks);
			my $nsteps = @steps;
			if ($nsteps < 3) {
				print "csf: Error - not enough Port Knocks for port $port [$knocks]\n";
				next;
			}
			for (my $step = 1; $step < $nsteps+1; $step++) {
				my $ar = $step - 1;
				if ($step == 1) {
					if ($config{PORTKNOCKING_LOG}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p $proto --dport $steps[$ar] $statemodulenew -m limit --limit 30/m --limit-burst 5 -j LOG --log-prefix 'Knock: *$port\_S$step* '")}
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p $proto --dport $steps[$ar] $statemodulenew -m recent --set --name PK\_$port\_S$step");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p $proto --dport $steps[$ar] $statemodulenew -j DROP");
				} else {
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -N PK\_$port\_S$step\_IN");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A PK\_$port\_S$step\_IN -m recent --name PK\_$port\_S".($step - 1)." --remove");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A PK\_$port\_S$step\_IN -m recent --name PK\_$port\_S$step --set");
					if ($config{PORTKNOCKING_LOG}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A PK\_$port\_S$step\_IN -m limit --limit 30/m --limit-burst 5 -j LOG --log-prefix 'Knock: *$port\_S$step* '")}
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A PK\_$port\_S$step\_IN -j DROP");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p $proto --dport $steps[$ar] $statemodulenew -m recent --rcheck --seconds $timeout --name PK\_$port\_S".($step - 1)." -j PK\_$port\_S$step\_IN");
				}
			}
			if ($config{PORTKNOCKING_LOG}) {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p $proto --dport $port $statemodulenew -m recent --rcheck --seconds $timeout --name PK\_$port\_S$nsteps -m limit --limit 30/m --limit-burst 5 -j LOG --log-prefix 'Knock: *$port\_IN* '")}
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p $proto --dport $port $statemodulenew -m recent --rcheck --seconds $timeout --name PK\_$port\_S$nsteps -j ACCEPT");
		}
	}

	if ($config{FASTSTART}) {$faststart = 1}
	$config{TCP_IN} =~ s/\s//g;
	if ($config{TCP_IN} ne "") {
		foreach my $port (split(/\,/,$config{TCP_IN})) {
			if ($port eq "") {next}
			if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid TCP_IN port [$port]")}
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p tcp $statemodulenew --dport $port -j $accept");
		}
	}
	if ($config{FASTSTART}) {&faststart("TCP_IN")}

	if ($config{FASTSTART}) {$faststart = 1}
	$config{TCP6_IN} =~ s/\s//g;
	if ($config{IPV6} and $config{TCP6_IN} ne "") {
		foreach my $port (split(/\,/,$config{TCP6_IN})) {
			if ($port eq "") {next}
			if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid TCP6_IN port [$port]")}
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INPUT $eth6devin -p tcp $statemodule6new --dport $port -j $accept");
		}
	}
	if ($config{FASTSTART}) {&faststart("TCP6_IN")}

	if ($config{FASTSTART}) {$faststart = 1}
	$config{TCP_OUT} =~ s/\s//g;
	if ($config{TCP_OUT} ne "") {
		foreach my $port (split(/\,/,$config{TCP_OUT})) {
			if ($port eq "") {next}
			if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid TCP_OUT port [$port]")}
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -p tcp $statemodulenew --dport $port -j $accept");
		}
	}
	if ($config{FASTSTART}) {&faststart("TCP_OUT")}

	if ($config{FASTSTART}) {$faststart = 1}
	$config{TCP6_OUT} =~ s/\s//g;
	if ($config{IPV6} and $config{TCP6_OUT} ne "") {
		foreach my $port (split(/\,/,$config{TCP6_OUT})) {
			if ($port eq "") {next}
			if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid TCP6_OUT port [$port]")}
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $eth6devout -p tcp $statemodule6new --dport $port -j $accept");
		}
	}
	if ($config{FASTSTART}) {&faststart("TCP6_OUT")}

	if ($config{FASTSTART}) {$faststart = 1}
	$config{UDP_IN} =~ s/\s//g;
	if ($config{UDP_IN} ne "") {
		foreach my $port (split(/\,/,$config{UDP_IN})) {
			if ($port eq "") {next}
			if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid UDP_IN port [$port]")}
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p udp $statemodulenew --dport $port -j $accept");
		}
	}
	if ($config{FASTSTART}) {&faststart("UDP_IN")}

	if ($config{FASTSTART}) {$faststart = 1}
	$config{UDP6_IN} =~ s/\s//g;
	if ($config{IPV6} and $config{UDP6_IN} ne "") {
		foreach my $port (split(/\,/,$config{UDP6_IN})) {
			if ($port eq "") {next}
			if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid UDP6_IN port [$port]")}
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INPUT $eth6devin -p udp $statemodule6new --dport $port -j $accept");
		}
	}
	if ($config{FASTSTART}) {&faststart("UDP6_IN")}

	if ($config{FASTSTART}) {$faststart = 1}
	$config{UDP_OUT} =~ s/\s//g;
	if ($config{UDP_OUT} ne "") {
		foreach my $port (split(/\,/,$config{UDP_OUT})) {
			if ($port eq "") {next}
			if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid UDP_OUT port [$port]")}
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -p udp $statemodulenew --dport $port -j $accept");
		}
	}
	if ($config{FASTSTART}) {&faststart("UDP_OUT")}

	if ($config{FASTSTART}) {$faststart = 1}
	$config{UDP6_OUT} =~ s/\s//g;
	if ($config{IPV6} and $config{UDP6_OUT} ne "") {
		foreach my $port (split(/\,/,$config{UDP6_OUT})) {
			if ($port eq "") {next}
			if ($port !~ /^[\d:]*$/) {&error(__LINE__,"Invalid UDP6_OUT port [$port]")}
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $eth6devout -p udp $statemodule6new --dport $port -j $accept");
		}
	}
	if ($config{FASTSTART}) {&faststart("UDP6_OUT")}

#	if ($config{IPV6}) {
#		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A INPUT $eth6devin -p udp -m frag --fraglast -j $accept");
#	}

#	my $icmp_in_rate = "";
#	my $icmp_out_rate = "";
#	if ($config{ICMP_IN_RATE}) {$icmp_in_rate = "-m limit --limit $config{ICMP_IN_RATE}"}
#	if ($config{ICMP_OUT_RATE}) {$icmp_out_rate = "-m limit --limit $config{ICMP_OUT_RATE}"}
#
#	if ($config{ICMP_IN}) {
#		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p icmp --icmp-type echo-request $icmp_in_rate -j $accept");
#		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -p icmp --icmp-type echo-reply $icmp_out_rate -j $accept");
#	}
#
#	if ($config{ICMP_OUT}) {
#		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -p icmp --icmp-type echo-request $icmp_out_rate -j $accept");
#		&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p icmp --icmp-type echo-reply $icmp_in_rate -j $accept");
#	}
#
#	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p icmp --icmp-type time-exceeded -j $accept");
#	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A INPUT $ethdevin -p icmp --icmp-type destination-unreachable -j $accept");
#
#	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -p icmp --icmp-type time-exceeded -j $accept");
#	&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A OUTPUT $ethdevout -p icmp --icmp-type destination-unreachable -j $accept");
#
#	if ($config{IPV6}) {
#		if ($config{IPV6_ICMP_STRICT}) {
#			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type destination-unreachable -j $accept");
#			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type packet-too-big -j $accept");
#			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type time-exceeded -j $accept");
#			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type parameter-problem -j $accept");
#			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type echo-request -j $accept");
#			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type echo-reply -j $accept");
#			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type router-advertisement -m hl --hl-eq 255 -j $accept");
#			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type neighbor-solicitation -m hl --hl-eq 255 -j $accept");
#			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type neighbor-advertisement -m hl --hl-eq 255 -j $accept");
#			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 --icmpv6-type redirect -m hl --hl-eq 255 -j $accept");
#		} else {
#			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A INPUT $eth6devin -p icmpv6 -j $accept");
#		}
#
#		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 -j $accept");
##		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type destination-unreachable -j $accept");
##		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type packet-too-big -j $accept");
##		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type time-exceeded -j $accept");
##		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type parameter-problem -j $accept");
##		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type echo-request -j $accept");
##		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type echo-reply -j $accept");
##		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type router-advertisement -m hl --hl-eq 255 -j $accept");
##		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type neighbor-solicitation -m hl --hl-eq 255 -j $accept");
##		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type neighbor-advertisement -m hl --hl-eq 255 -j $accept");
##		&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose  -A OUTPUT $eth6devout -p icmpv6 --icmpv6-type redirect -m hl --hl-eq 255 -j $accept");
#	}

	if (-e "/etc/csf/csf.redirect") {
		my $dnat = 0;
		my @entries = slurp("/etc/csf/csf.redirect");
		foreach my $line (@entries) {
			if ($line =~ /^Include\s*(.*)$/) {
				my @incfile = slurp($1);
				push @entries,@incfile;
			}
		}
		foreach my $line (@entries) {
			$line =~ s/$cleanreg//g;
			if ($line eq "") {next}
			if ($line =~ /^\s*\#|Include/) {next}
			my ($redirect,$comment) = split (/\s/,$line,2);
			my ($ipx,$porta,$ipy,$portb,$proto) = split (/\|/,$redirect);
			unless ($proto eq "tcp" or $proto eq "udp") {&error(__LINE__,"csf: Incorrect csf.redirect  setting ([$proto]): [$line]")}
			unless ($ipx eq "*" or checkip(\$ipx)) {&error(__LINE__,"csf: Incorrect csf.redirect  setting ([$ipx]): [$line]")}
			unless ($porta eq "*" or $porta > 0 or $porta < 65536) {&error(__LINE__,"csf: Incorrect csf.redirect  setting ([$porta]): [$line]")}
			unless ($ipy eq "*" or checkip(\$ipy)) {&error(__LINE__,"csf: Incorrect csf.redirect  setting ([$ipy]): [$line]")}
			unless ($portb eq "*" or $portb > 0 or $portb < 65536) {&error(__LINE__,"csf: Incorrect csf.redirect  setting ([$portb]): [$line]")}
			if ($ipy eq "*") {
				if ($ipx eq "*") {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -A PREROUTING $ethdevin -p $proto --dport $porta -j REDIRECT --to-ports $portb")}
				else {&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -A PREROUTING $ethdevin -p $proto -d $ipx --dport $porta -j REDIRECT --to-ports $portb")}
			} else {
				unless ($dnat) {
					open (my $OUT,">","/proc/sys/net/ipv4/ip_forward");
					flock ($OUT, LOCK_EX);
					print $OUT "1";
					close ($OUT);
					$dnat = 1;
				}
				if ($ipx ne "*" and $porta eq "*") {
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -A PREROUTING $ethdevin -p $proto -d $ipx -j DNAT --to-destination $ipy");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -A POSTROUTING $ethdevout -p $proto -d $ipy -j SNAT --to-source $ipx");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A FORWARD $ethdevin -p $proto -d $ipy  $statemodulenew -j ACCEPT");
				}
				elsif ($ipx ne "*" and $porta ne "*" and $portb ne "*") {
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -A PREROUTING $ethdevin -p $proto -d $ipx --dport $porta -j DNAT --to-destination $ipy:$portb");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -A POSTROUTING $ethdevout -p $proto -d $ipy -j SNAT --to-source $ipx");
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A FORWARD $ethdevin -p $proto -d $ipy --dport $portb  $statemodulenew -j ACCEPT");
				}
				else {&error(__LINE__,"csf: Invalid csf.redirect format [$line]")}
			}
		}
		if ($dnat and $config{LF_SPI}) {
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A FORWARD $ethdevin $statemodule ESTABLISHED,RELATED -j ACCEPT");
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A FORWARD $ethdevin -j LOGDROPIN");
		}
	}
	return;
}
# end doportfilters
###############################################################################
# start dodisable
sub dodisable {
	open (my $OUT, ">", "/etc/csf/csf.disable");
	flock ($OUT, LOCK_EX);
	close ($OUT);
	unless ($config{GENERIC}) {
		sysopen (my $CONF, "/etc/chkserv.d/chkservd.conf", O_RDWR | O_CREAT) or &error(__LINE__,"Could not open /etc/chkserv.d/chkservd.conf: $!");
		flock ($CONF, LOCK_EX) or &error(__LINE__,"Could not lock /etc/chkserv.d/chkservd.conf: $!");
		my $text = join("", <$CONF>);
		my @conf = split(/$slurpreg/,$text);
		chomp @conf;
		seek ($CONF, 0, 0);
		truncate ($CONF, 0);
		foreach my $line (@conf) {
			if ($line =~ /^lfd:/) {$line = "lfd:0"}
			print $CONF $line."\n";
		}
		close ($CONF) or &error(__LINE__,"Could not close /etc/conf: $!");
	}
	if ($config{DIRECTADMIN}) {
		sysopen (my $CONF, "/usr/local/directadmin/data/admin/services.status", O_RDWR | O_CREAT) or &error(__LINE__,"Could not open /usr/local/directadmin/data/admin/services.status: $!");
		flock ($CONF, LOCK_EX) or &error(__LINE__,"Could not lock /usr/local/directadmin/data/admin/services.status: $!");
		my $text = join("", <$CONF>);
		my @conf = split(/$slurpreg/,$text);
		chomp @conf;
		seek ($CONF, 0, 0);
		truncate ($CONF, 0);
		foreach my $line (@conf) {
			if ($line =~ /^lfd=/) {$line = "lfd=OFF"}
			print $CONF $line."\n";
		}
		close ($CONF) or &error(__LINE__,"Could not close /usr/local/directadmin/data/admin/services.status: $!");
	}

	ConfigServer::Service::stoplfd();
	&dostop(0);

	log_pass( "CSF and LFD have been ${redl}disabled${greym}! Use ${greend}'csf -e'${greym} to re-enable" );

	return;
}
# end dodisable
###############################################################################
# start doenable
sub doenable
{
	unless (-e "/etc/csf/csf.disable")
	{
		log_fail( "CSF and LFD are not ${redl}disabled${greym}!" );
		exit 0;
	}

	unlink ("/etc/csf/csf.disable");
	&dostart;
	ConfigServer::Service::startlfd();
	unless ($config{GENERIC})
	{
		sysopen (my $CONF, "/etc/chkserv.d/chkservd.conf", O_RDWR | O_CREAT) or &error(__LINE__,"Could not open /etc/chkserv.d/chkservd.conf: $!");
		flock ($CONF, LOCK_EX) or &error(__LINE__,"Could not lock /etc/chkserv.d/chkservd.conf: $!");
		my $text = join("", <$CONF>);
		my @conf = split(/$slurpreg/,$text);
		chomp @conf;
		seek ($CONF, 0, 0);
		truncate ($CONF, 0);
		foreach my $line (@conf) {
			if ($line =~ /^lfd:/) {$line = "lfd:1"}
			print $CONF $line."\n";
		}
		close ($CONF) or &error(__LINE__,"Could not close /etc/conf: $!");
		open (my $OUT, ">", "/etc/chkserv.d/lfd");
		flock ($OUT, LOCK_EX);
		print $OUT "service[lfd]=x,x,x,service lfd restart,lfd,root\n";
		close ($OUT);
	}
	if ($config{DIRECTADMIN}) {
		sysopen (my $CONF, "/usr/local/directadmin/data/admin/services.status", O_RDWR | O_CREAT) or &error(__LINE__,"Could not open /usr/local/directadmin/data/admin/services.status: $!");
		flock ($CONF, LOCK_EX) or &error(__LINE__,"Could not lock /usr/local/directadmin/data/admin/services.status: $!");
		my $text = join("", <$CONF>);
		my @conf = split(/$slurpreg/,$text);
		chomp @conf;
		seek ($CONF, 0, 0);
		truncate ($CONF, 0);
		foreach my $line (@conf) {
			if ($line =~ /^lfd=/) {$line = "lfd=ON"}
			print $CONF $line."\n";
		}
		close ($CONF) or &error(__LINE__,"Could not close /usr/local/directadmin/data/admin/services.status: $!");
	}

	log_pass( "CSF and LFD have been ${greenl}enabled${greym}! Use ${greenl}'csf -x'${greym} to disable" );

	return;
}
# end doenable
###############################################################################
# start crontab
sub crontab {
	my $act = shift;
	my @crontab = slurp("/etc/crontab");
	my $hit = 0;
	my @newcrontab;
	foreach my $line (@crontab) {
		if ($line =~ /csf(\.pl)? -f/) {
			$hit = 1;
			if ($act eq "add") {
				push @newcrontab, $line;
			}
		} else {
			push @newcrontab, $line;
		}
	}
	if (($act eq "add") and !($hit)) {
		push @newcrontab, "*/$config{TESTING_INTERVAL} * * * * root /usr/sbin/csf -f > /dev/null 2>&1";
	}

	if (($act eq "remove") and !($hit)) {
		# don't do anything
	} else {
		sysopen (my $CRONTAB, "/etc/crontab", O_RDWR | O_CREAT) or die "Could not open /etc/crontab: $!";
		flock ($CRONTAB, LOCK_EX) or die "Could not lock /etc/crontab: $!";
		seek ($CRONTAB, 0, 0);
		truncate ($CRONTAB, 0);
		foreach my $line (@newcrontab) {
			print $CRONTAB $line."\n";
		}
		close ($CRONTAB) or die "Could not close /etc/crontab: $!";
	}
	return;
}
# end crontab
###############################################################################
# start error
sub error {
	my $line = shift;
	my $error = shift;
	my $verbose;
	if ($config{DEBUG} >= 1) {$verbose = "--verbose"}
	system ("$config{IPTABLES} $verbose --policy INPUT ACCEPT");
	system ("$config{IPTABLES} $verbose --policy OUTPUT ACCEPT");
	system ("$config{IPTABLES} $verbose --policy FORWARD ACCEPT");
	system ("$config{IPTABLES} $verbose --flush");
	system ("$config{IPTABLES} $verbose --delete-chain");
	if ($config{NAT}) {
		&syscommand(__LINE__,"$config{IPTABLES} $verbose -t nat --flush");
		&syscommand(__LINE__,"$config{IPTABLES} $verbose -t nat --delete-chain");
	}
	if ($config{RAW}) {
		&syscommand(__LINE__,"$config{IPTABLES} $verbose -t raw --flush");
		&syscommand(__LINE__,"$config{IPTABLES} $verbose -t raw --delete-chain");
	}
	if ($config{MANGLE}) {
		&syscommand(__LINE__,"$config{IPTABLES} $verbose -t mangle --flush");
		&syscommand(__LINE__,"$config{IPTABLES} $verbose -t mangle --delete-chain");
	}

	if ($config{IPV6}) {
		system ("$config{IP6TABLES} $verbose --policy INPUT ACCEPT");
		system ("$config{IP6TABLES} $verbose --policy OUTPUT ACCEPT");
		system ("$config{IP6TABLES} $verbose --policy FORWARD ACCEPT");
		system ("$config{IP6TABLES} $verbose --flush");
		system ("$config{IP6TABLES} $verbose --delete-chain");
		if ($config{NAT6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $verbose -t nat --flush");
			&syscommand(__LINE__,"$config{IP6TABLES} $verbose -t nat --delete-chain");
		}
		if ($config{RAW6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $verbose -t raw --flush");
			&syscommand(__LINE__,"$config{IP6TABLES} $verbose -t raw --delete-chain");
		}
		if ($config{MANGLE6}) {
			&syscommand(__LINE__,"$config{IP6TABLES} $verbose -t mangle --flush");
			&syscommand(__LINE__,"$config{IP6TABLES} $verbose -t mangle --delete-chain");
		}
	}

	if ($config{LF_IPSET}) {
		system ("$config{IPSET} flush");
		system ("$config{IPSET} destroy");
	}

	print "Error: $error, at line $line\n";
	open (my $OUT,">", "/etc/csf/csf.error");
	flock ($OUT, LOCK_EX);
	print $OUT "Error: $error, at line $line in /usr/sbin/csf\n";
	close ($OUT);
	if ($config{TESTING}) {&crontab("remove")}
	exit 1;
}
# end error
###############################################################################
# start version
sub version {
	open (my $IN, "<", "/etc/csf/version.txt") or die "Unable to open version.txt: $!";
	flock ($IN, LOCK_SH);
	my $myv = <$IN>;
	close ($IN);
	chomp $myv;
	return $myv;
}
# end version
###############################################################################
# start getethdev
sub getethdev {
	my $ethdev = ConfigServer::GetEthDev->new();
	my %g_ifaces = $ethdev->ifaces;
	my %g_ipv4 = $ethdev->ipv4;
	my %g_ipv6 = $ethdev->ipv6;
	foreach my $key (keys %g_ifaces) {
		$ifaces{$key} = 1;
	}
	foreach my $key (keys %g_ipv4) {
		$ips{$key} = 1;
	}
	if ($config{IPV6}) {
		foreach my $key (keys %g_ipv6) {
			eval {
				local $SIG{__DIE__} = undef;
				$ipscidr6->add($key);
			};
		}
	}

	($config{ETH_DEVICE},undef) = split (/:/,$config{ETH_DEVICE},2);
	if ($config{ETH_DEVICE} eq "") {
		$ethdevin = "! -i lo";
		$ethdevout = "! -o lo";
	} else {
		$ethdevin = "-i $config{ETH_DEVICE}";
		$ethdevout = "-o $config{ETH_DEVICE}";
	}
	if ($config{ETH6_DEVICE} eq "") {
		$eth6devin = $ethdevin;
		$eth6devout = $ethdevout;
	} else {
		$eth6devin = "-i $config{ETH6_DEVICE}";
		$eth6devout = "-o $config{ETH6_DEVICE}";
	}
	return;
}
# end getethdev
###############################################################################
# start linefilter
sub linefilter
{
	my $line 		= shift;
	my $ad 			= shift;
	my $chain 		= shift;
	my $delete 		= shift;
	my $pktin 		= "$accept";
	my $pktout 		= "$accept";
	my $localin 	= "ALLOWIN";
	my $localout 	= "ALLOWOUT";
	my $inadd 		= "-I";

	if ($ad eq "deny")
	{
		$inadd 		= "-A";
		$pktin 		= $config{DROP};
		$pktout 	= $config{DROP_OUT};

		if ($config{DROP_IP_LOGGING})
		{
			$pktin = "LOGDROPIN"
		}

		if ($config{DROP_OUT_LOGGING})
		{
			$pktout = "LOGDROPOUT"
		}

		$localin	= "DENYIN";
		$localout	= "DENYOUT";
	}

	my $chainin 	= $chain."IN";
	my $chainout 	= $chain."OUT";

	$line =~ s/\n|\r//g;
	$line = lc $line;
	if ($line =~ /^\#/) {return}
	if ($line =~ /^Include/) {return}
	if ($line eq "") {return}

	my $checkip 	= checkip(\$line);
	my $iptables 	= $config{IPTABLES};
	my $ipv4 		= 1;
	my $ipv6 		= 0;
	my $linein 		= $ethdevin;
	my $lineout 	= $ethdevout;

	if ($checkip == 6)
	{
		if ($config{IPV6})
		{
			$iptables = $config{IP6TABLES};
			$linein = $eth6devin;
			$lineout = $eth6devout;
			$ipv4 = 0;
			$ipv6 = 1;
		}
		else
		{
			return
		}
	}

	if ($checkip) {
		if ($chain) {
			if ($config{LF_IPSET}) {
				if ($ipv4) {&ipsetadd("chain_$chainin",$line)}
				else {&ipsetadd("chain_6_${chainin}",$line)}
			} else {
				&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -A $chainin $linein -s $line -j $pktin");
				if (($ad eq "deny" and !$config{LF_BLOCKINONLY}) or ($ad ne "deny")) {&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -A $chainout $lineout -d $line -j $pktout")}
			}
		} else {
			if ($delete) {
				if ($config{LF_IPSET}) {
					if ($ipv4) {&ipsetdel("chain_$localin",$line)}
					else {&ipsetdel("chain_6_${localin}",$line)}
				} else {
					&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -D $localin $linein -s $line -j $pktin");
					if (($ad eq "deny" and !$config{LF_BLOCKINONLY}) or ($ad ne "deny")) {&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -D $localout $lineout -d $line -j $pktout")}
				}
				if (($ad eq "deny") and ($ipv4 and $config{MESSENGER} and $config{MESSENGER_PERM})) {&domessenger($line,"D")}
				if (($ad eq "deny") and ($ipv6 and $config{MESSENGER6} and $config{MESSENGER_PERM})) {&domessenger($line,"D")}
			} else {
				if ($config{LF_IPSET}) {
					if ($ipv4) {&ipsetadd("chain_$localin",$line)}
					else {&ipsetadd("chain_6_${localin}",$line)}
				} else {
					&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose $inadd $localin $linein -s $line -j $pktin");
					if (($ad eq "deny" and !$config{LF_BLOCKINONLY}) or ($ad ne "deny")) {&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose $inadd $localout $lineout -d $line -j $pktout")}
				}
				if (($ad eq "deny") and ($ipv4 and $config{MESSENGER} and $config{MESSENGER_PERM})) {&domessenger($line,"A")}
				if (($ad eq "deny") and ($ipv6 and $config{MESSENGER6} and $config{MESSENGER_PERM})) {&domessenger($line,"A")}
			}
		}
	}
	elsif ($line =~ /\:|\|/)
	{
		if ($line !~ /\|/)
		{
			$line =~ s/\:/\|/g
		}

		my $sip;
		my $dip;
		my $sport;
		my $dport;
		my $protocol = "-p tcp";
		my $inout;
		my $from = 0;
		my $uid;
		my $gid;
		my $iptype;

		my @ll = split(/\|/,$line);
		if ($ll[0] eq "tcp")
		{
			$protocol = "-p tcp";
			$from = 1;
		}
		elsif ($ll[0] eq "udp")
		{
			$protocol = "-p udp";
			$from = 1;
		}
		elsif ($ll[0] eq "icmp")
		{
			$protocol = "-p icmp";
			$from = 1;
		}

		for (my $x = $from;$x < 2;$x++)
		{
			if (($ll[$x] eq "out")) {
				$inout = "out";
				$from = $x + 1;
				last;
			}
			elsif (($ll[$x] eq "in"))
			{
				$inout = "in";
				$from = $x + 1;
				last;
			}
		}

		for (my $x = $from;$x < 3;$x++)
		{
			if (($ll[$x] =~ /d=(.*)/))
			{
				$dport = "--dport $1";
				$dport =~ s/_/:/g;
				if ($protocol eq "-p icmp") {$dport = "--icmp-type $1"}
				if ($dport =~ /,/) {$dport = "-m multiport ".$dport}
				$from = $x + 1;
				last;
			}
			elsif (($ll[$x] =~ /s=(.*)/))
			{
				$sport = "--sport $1";
				$sport =~ s/_/:/g;
				if ($protocol eq "-p icmp") {$sport = "--icmp-type $1"}
				if ($sport =~ /,/) {$sport = "-m multiport ".$sport}
				$from = $x + 1;
				last;
			}
		}
	
		for (my $x = $from;$x < 4;$x++)
		{
			if (($ll[$x] =~ /d=(.*)/))
			{
				my $ip = $1;
				my $status = checkip(\$ip);
				if ($status)
				{
					$iptype = $status;
					$dip = "-d $1";
				}
				last;
			}
			elsif (($ll[$x] =~ /s=(.*)/))
			{
				my $ip = $1;
				my $status = checkip(\$ip);
				if ($status)
				{
					$iptype = $status;
					$sip = "-s $1";
				}
				last;
			}
		}

		for (my $x = $from;$x < 5;$x++)
		{
			if (($ll[$x] =~ /u=(.*)/))
			{
				$uid = "--uid-owner $1";
				last;
			}
			elsif (($ll[$x] =~ /g=(.*)/))
			{
				$gid = "--gid-owner $1";
				last;
			}
		}

		if ($uid or $gid)
		{
			if ($config{VPS} and $noowner)
			{
				print "Cannot use UID or GID rules [$ad: $line] on this VPS as the Monolithic kernel does not support the iptables module ipt_owner/xt_owner - rule skipped\n";
			} else
			{
				if ($chain)
				{
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A $chainout $lineout $protocol $dport -m owner $uid $gid -j $pktout");
					if ($config{IPV6}) {
						&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A $chainout $lineout $protocol $dport -m owner $uid $gid -j $pktout");
					}
				}
				else
				{
					if ($delete)
					{
						&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D $localout $lineout $protocol $dport -m owner $uid $gid -j $pktout");
						if ($config{IPV6}) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D $localout $lineout $protocol $dport -m owner $uid $gid -j $pktout");
						}
					}
					else
					{
						&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose $inadd $localout $lineout $protocol $dport -m owner $uid $gid -j $pktout");
						if ($config{IPV6}) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose $inadd $localout $lineout $protocol $dport -m owner $uid $gid -j $pktout");
						}
					}
				}
			}
		}
		elsif (($sip or $dip) and ($dport or $sport))
		{
			my $iptables = $config{IPTABLES};
			if ($iptype == 6)
			{
				if ($config{IPV6})
				{
					$iptables = $config{IP6TABLES};
				}
				else
				{
					return;
				}
			}

			if (($inout eq "") or ($inout eq "in"))
			{
				my $bport = $dport;
				$bport =~ s/--dport //o;
				my $bip = $sip;
				$bip =~ s/-s //o;

				if ($chain)
				{
					&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -A $chainin $linein $protocol $dip $sip $dport $sport -j $pktin");
				}
				else
				{
					if ($delete)
					{
						&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -D $localin $linein $protocol $dip $sip $dport $sport -j $pktin");
						if ($messengerports{$bport} and ($ad eq "deny") and ($ipv4 and $config{MESSENGER} and $config{MESSENGER_PERM})) {&domessenger($bip,"D","$bport")}
						if ($messengerports{$bport} and ($ad eq "deny") and ($ipv6 and $config{MESSENGER6} and $config{MESSENGER_PERM})) {&domessenger($bip,"D","$bport")}
					}
					else
					{
						&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose $inadd $localin $linein $protocol $dip $sip $dport $sport -j $pktin");
						if ($messengerports{$bport} and ($ad eq "deny") and ($ipv4 and $config{MESSENGER} and $config{MESSENGER_PERM})) {&domessenger($bip,"A","$bport")}
						if ($messengerports{$bport} and ($ad eq "deny") and ($ipv6 and $config{MESSENGER6} and $config{MESSENGER_PERM})) {&domessenger($bip,"A","$bport")}
					}
				}
			}

			if ($inout eq "out")
			{
				if ($chain)
				{
					&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -A $chainout $lineout $protocol $dip $sip $dport $sport -j $pktout");
				}
				else
				{
					if ($delete)
					{
						&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -D $localout $lineout $protocol $dip $sip $dport $sport -j $pktout");
					}
					else
					{
						&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose $inadd $localout $lineout $protocol $dip $sip $dport $sport -j $pktout");
					}
				}
			}
		}
	}
	return;
}
# end linefilter
###############################################################################
# start autoupdates
sub autoupdates
{
	my $hour 		= int (rand(24));
	my $minutes 	= int (rand(60));

	unless (-d "/etc/cron.d") {mkdir "/etc/cron.d"}
	open (my $OUT,">", "/etc/cron.d/csf_update") or &error(__LINE__,"Could not create /etc/cron.d/csf_update: $!");
	flock ($OUT, LOCK_EX) or &error(__LINE__,"Could not lock /etc/cron.d/csf_update: $!");
	print $OUT <<END;
SHELL=/bin/sh
$minutes $hour * * * root /usr/sbin/csf -u
END
	close ($OUT);
	return;
}
# end autoupdates
###############################################################################
# start doupdate

# #
#	License › Status
#	
#	Returns a user's license status.
#	
#	@return			0 (false)		License invalid
#					1 (true)		License valid
# #

sub userLicenseStatus
{
    my $license = $config{SPONSOR_LICENSE} // '';

    # Return 0 if license in config missing
    return 0 unless $license;

    # Check license server
    my ( $statusCode, $resp ) = $urlget->urlget("https://license.configserver.dev/?license=${license}");

    # Return 0 if error contacting the server
    return 0 if $statusCode;

    # Determine if the license is valid (checks JSON "valid": true inside "message")
    my $isValid = ($resp =~ /"message"\s*:\s*{.*?"valid"\s*:\s*true/s) ? 1 : 0;

    return $isValid;
}

# #
#	Release Channel › Insiders
#	
#	Checks the server to determine if the user is using the `Insiders` or `Stable`.
#	If insiders server not accessible; default to false for stable channel.
#	
#	Requires csf.conf settings
#		SPONSOR_LICENSE = "XXXX-XXXX-XXXX"
#		SPONSOR_RELEASE_INSIDERS = "1"
#	
#	@param (optional) 	int 			pre-define if license key came back successful
#										avoids double hits to the server if needing both insiders status and license status.
#											( See usage examples #2 / #3 )
#	@return				0 (false)		User on Stable Channel
#						1 (true)		User on Insiders Channel
#	
#	@usage #1			my $releaseChannel 	= userIsInsider() ? "Insiders" : "Stable";					# No license status param specified
#	@usage #2			my $licenseValid 	= userLicenseStatus();
#						my $licenseStatus 	= $licenseValid ? "Valid" : "Invalid";
#						my $releaseChannel 	= userIsInsider($licenseValid) ? "Insiders" : "Stable";
#	@usage #3			my $releaseChannel 	= userIsInsider(1);											# Pass user has valid license / true
# #


sub userIsInsider
{
    my ( $preCheckedLicense ) = @_;   # Optional param: 1 if license valid, 0 if not

    # License key missing OR Insiders release not enabled in config
    return 0 unless ( ( $config{SPONSOR_RELEASE_INSIDERS} // 0 ) == 1 && ( $config{SPONSOR_LICENSE} // '' ) ne '' );

    # Avoid double hits to server; use pre-checked license status if provided via param, otherwise call userLicenseStatus()
    my $userLicenseValid = defined $preCheckedLicense ? $preCheckedLicense : userLicenseStatus();

    # Debug output
    if ( $debug )
    {
        my $userInsiderStatus = $userLicenseValid ? 'Enabled' : 'Disabled';
        log_label( "Insiders Status: ${yellowd}${userInsiderStatus}" );
    }

    # Return true if license valid + Insiders enabled
    return $userLicenseValid;
}

# #
#	Update
# #

sub doupdate
{
    my $force = 0;
    my $actv  = "";

    if ( $input{command} eq "-uf" )
    {
        $force = 1;
    }
    else
    {
        my $url = "https://$config{DOWNLOADSERVER}/csf/version.txt";
        if ( $config{URLGET} == 1 )
        {
            $url = "http://$config{DOWNLOADSERVER}/csf/version.txt";
        }

        # #
        #   Insiders Release Channel
        #   
        #   This should NOT be used on production servers.
        #   
        #   Enabled by defining the following in your csf.conf:
        #       SPONSOR_RELEASE_INSIDERS = "1"
        # #

        if ( ( $config{SPONSOR_RELEASE_INSIDERS} // 0 ) == 1 && ( $config{SPONSOR_LICENSE} // '' ) ne '' )
        {
            $url .= "?channel=insiders&license=$config{SPONSOR_LICENSE}";
        }

        my ($status, $text) = $urlget->urlget($url);
        if ( $status )
        {
			log_fail( "An error occurred performing the CSF update: ${redl}${text}${greym}" );
            exit 1;
        }

        $actv = $text;
    }

    # #
    #	Normalize version string (allow suffixes like -insiders, -beta)
    # #

    $actv =~ s/^\s+|\s+$//g;                      # Trim whitespace
    my ($actv_num) = $actv =~ /^([\d.]+)/;        # Extract numeric portion (e.g. "15.07" from "15.07-insiders")
    my ($curr_num) = $version =~ /^([\d.]+)/;     # Current version numeric portion

    if ( ( defined $actv_num && $actv_num ne '' ) || $force )
    {
        my $newer = 0;

        # #
        #	Compare numeric parts
        # #

        my @a = split /\./, $curr_num // '0';
        my @b = split /\./, $actv_num  // '0';

        for (my $i = 0; $i < @a || $i < @b; $i++)
        {
            my $c = $a[$i] // 0;
            my $n = $b[$i] // 0;
            if ($n > $c) { $newer = 1; last; }
            if ($n < $c) { $newer = 0; last; }
        }

        if ( $newer or $force )
        {
            local $| = 1;

            unless ( $force )
            {
				log_info( "Updating CSF from ${bluel}${version}${greym} to ${bluel}${actv}${greym}" );
            }

            if ( -e "/usr/src/csf.tgz" )
            {
                unlink( "/usr/src/csf.tgz" ) or die $!;
            }

			log_info( "Preparing to get newest CSF package${greym}" );

            my $url = "https://$config{DOWNLOADSERVER}/csf.tgz";
            if ( $config{URLGET} == 1 )
            {
                $url = "http://$config{DOWNLOADSERVER}/csf.tgz";
            }

            if ( ( $config{SPONSOR_RELEASE_INSIDERS} // 0 ) == 1 && ( $config{SPONSOR_LICENSE} // '' ) ne '' )
            {
                $url .= "?channel=insiders&license=$config{SPONSOR_LICENSE}";
				log_info( "Using ${bluel}Insiders Channel${greym} to download update" );
			}
			else
			{
				log_info( "Using ${bluel}Stable Channel${greym} to download update" );
            }

            my ($status, $text) = $urlget->urlget( $url, "/usr/src/csf.tgz" );

			log_info( "Downloading CSF update from ${bluel}${url}${greym}" );

            if (! -z "/usr/src/csf/csf.tgz")
            {
				log_info( "Unpacking new CSF package ${bluel}/usr/src/csf/csf.tgz${greym}" );
                system("cd /usr/src ; tar -xzf csf.tgz ; cd csf ; sh install.sh");

				log_info( "Performing housekeeping on temp files${greym}" );
                system("rm -Rfv /usr/src/csf*");

				log_info( "Please wait, restarting CSF and LFD services${greym}" );
                system("/usr/sbin/csf -r");
                ConfigServer::Service::restartlfd();

				log_pass( "Update complete! View changelog at ${bluel}https://$config{DOWNLOADSERVER}/csf/changelog.txt${greym}" );
            }
        }
        else
        {
            if (-t STDOUT)
			{
				log_warn( "You are already running the latest CSF version: ${yellowl}${version}${greym}" );
			} ##no critic
        }
    }
    else
    {
		log_fail( "Unable to verify the latest version of CSF at this time.${greym}" );
		log_label( "Reach out to the development team if this error continues" );
    }

    return;
}

# end doupdate

# #
#	Check for Updates
#		Stable				https://$config{DOWNLOADSERVER}/csf/version.txt
#		Insiders			https://$config{DOWNLOADSERVER}/csf/version.txt?channel=insiders
# #

sub docheck
{
	# Stable Release Channel
    my $url = "https://$config{DOWNLOADSERVER}/csf/version.txt";
    if ($config{URLGET} == 1)
    {
        $url = "http://$config{DOWNLOADSERVER}/csf/version.txt";
    }

    # Insiders Release Channel
    if ( ( $config{SPONSOR_RELEASE_INSIDERS} // 0 ) == 1 && ( $config{SPONSOR_LICENSE} // '' ) ne '' )
    {
        $url .= "?channel=insiders&license=$config{SPONSOR_LICENSE}";
    }

    my ($status, $text) = $urlget->urlget($url);
    if ($status)
    {
        print "Oops: $text\n"; 
        exit 1;
    }

    my $actv = $text;
    my $up = 0;

    if ($actv ne "")
    {
        # Split version into numeric and optional suffix
        my ($num_version, $suffix) = split /-/, $actv, 2;    # "15.07-insiders" → "15.07", "insiders"

        # Compare numeric versions
        my $current = $version;                              # current version
        my $newer = 0;

		# #
        #	Split numeric parts by dot
		# #

        my @current_parts = split /\./, $current;
        my @new_parts     = split /\./, $num_version;

        for (my $i = 0; $i < @new_parts || $i < @current_parts; $i++)
        {
            my $n = $new_parts[$i] // 0;
            my $c = $current_parts[$i] // 0;
            if ($n > $c) { $newer = 1; last; }
            if ($n < $c) { $newer = 0; last; }
        }

        if ( $newer )
        {
			log_info( "${bgYellowDark} A newer version of CSF is available! ${end}" );
			log_label( "Current: ${bluel}v${version}" );
			log_label( "Available: ${greenl}v${actv}" );
        }
        else
        {
			log_pass( "${bgBlueDark} You are already running the latest version! ${end}" );
			log_label( "Current: ${bluel}v${version}" );
        }
    }
    else
    {
        print "Unable to verify the latest version of csf at this time\n";
    }

    return;
}

###############################################################################
# start doiplookup
sub doiplookup {
	if (checkip(\$input{argument})) {
		print iplookup($input{argument})."\n";
	} else {
		print "lookup failed: [$input{argument}] is not a valid PUBLIC IP\n";
	}
	return;
}
# end doiplookup
###############################################################################
# start dogrep
sub dogrep {
	my $ipmatch = $input{argument};
	checkip(\$ipmatch);
	my $ipstring = quotemeta($ipmatch);
	my $mhit = 0;
	my $head = 0;
	my $oldchain = "INPUT";
	my $table = "filter";
	my ($chain,$rest);
	format GREP =
@<<<<< @<<<<<<<<<<<<<<< @*
$table, $chain, $rest
.
	local $~ = "GREP";
	
	my $command = "echo 'filter table:\n' ; $config{IPTABLES} $config{IPTABLESWAIT} -v -L -n --line-numbers";
	if ($config{NAT}) {$command .= " ; echo 'nat table:\n' ; $config{IPTABLES} $config{IPTABLESWAIT} -v -t nat -L -n --line-numbers"}
	if ($config{MANGLE}) {$command .= " ;echo 'mangle table:\n' ;  $config{IPTABLES} $config{IPTABLESWAIT} -v -t mangle -L -n --line-numbers"}
	if ($config{RAW}) {$command .= " ; echo 'raw table:\n' ; $config{IPTABLES} $config{IPTABLESWAIT} -v -t raw -L -n --line-numbers"}
	my ($childin, $childout);
	my $pid = open3($childin, $childout, $childout, $command);
	my @output = <$childout>;
	waitpid ($pid, 0);
	chomp @output;
	if ($output[0] =~ /# Warning: iptables-legacy tables present/) {shift @output}
	foreach my $line (@output) {
		if ($line =~ /^Chain\s([\w\_]*)\s/) {$chain = $1}
		if ($line =~ /^(\S+) table:$/) {$table = $1}
		if ($chain eq "acctboth") {next}
		if (!$head and ($line =~ /^num/)) {print "\nTable  Chain            $line\n"; $head = 1}
		if ($line !~ /\d+/) {next}
		my (undef,undef,undef,$action,undef,undef,undef,undef,$source,$destination,$options) = split(/\s+/,$line,11);
	
		my $hit = 0;
		if ($line =~ /\b$ipstring\b/i) {
			$hit = 1;
		} else {
			if (($source =~ /\//) and ($source ne "0.0.0.0/0")) {
				if (checkip(\$source)) {
					my $cidr = Net::CIDR::Lite->new;
					eval {local $SIG{__DIE__} = undef; $cidr->add($source)};
					if ($cidr->find($ipmatch)) {$hit = 1}
				}
			}
			if (!$hit and ($destination =~ /\//) and ($destination ne "0.0.0.0/0")) {
				if (checkip(\$destination)) {
					my $cidr = Net::CIDR::Lite->new;
					eval {local $SIG{__DIE__} = undef; $cidr->add($destination)};
					if ($cidr->find($ipmatch)) {$hit = 1}
				}
			}
		}
		if ($hit) {
			$rest = $line;
			if ($oldchain ne $chain) {print "\n"}
			write;
			$oldchain = $chain;
			$mhit = 1;
		}
	}
	unless ($mhit) {
		print "No matches found for $ipmatch in iptables\n";
	}

	if ($config{LF_IPSET} and checkip(\$ipmatch)) {
		print "\n";
		my $mhit = 0;
		my $head = 0;
		my $oldchain = "INPUT";
		my ($childin, $childout);
		my $pid = open3($childin, $childout, $childout, $config{IPSET}, "-n", "list");
		my @output = <$childout>;
		waitpid ($pid, 0);
		chomp @output;
		my %sets;
		foreach my $line (@output) {$sets{$line} = 1}
		foreach my $chain (keys %sets) {
			my $option;
			my $cc;
			my $country;

			if ($chain =~ /^cc_(\w+)$/) {
				$cc = $1;
				$country = uc $cc;
				if ($config{CC_DENY} =~ /$cc/i) {$option = "CC_DENY"}
				if ($config{CC_ALLOW} =~ /$cc/i) {$option = "CC_ALLOW"}
				if ($config{CC_ALLOW_FILTER} =~ /$cc/i) {$option = "CC_ALLOW_FILTER"}
				if ($config{CC_ALLOW_PORTS} =~ /$cc/i) {$option = "CC_ALLOW_PORTS"}
				if ($config{CC_DENY_PORTS} =~ /$cc/i) {$option = "CC_DENY_PORTS"}
			}
			if ($chain =~ /^cc_6_(\w+)$/) {
				$cc = $1;
				$country = uc $cc;
				if ($config{CC_DENY} =~ /$cc/i) {$option = "CC_DENY"}
				if ($config{CC_ALLOW} =~ /$cc/i) {$option = "CC_ALLOW"}
				if ($config{CC_ALLOW_FILTER} =~ /$cc/i) {$option = "CC_ALLOW_FILTER"}
				if ($config{CC_ALLOW_PORTS} =~ /$cc/i) {$option = "CC_ALLOW_PORTS"}
				if ($config{CC_DENY_PORTS} =~ /$cc/i) {$option = "CC_DENY_PORTS"}
			}

			if ($chain =~ /^bl_(\w+)$/) {
				$cc = $1;
				$option = "$cc file:/etc/csf/csf.blocklists";
			}
			if ($chain =~ /^bl_6_(\w+)$/) {
				$cc = $1;
				$option = "$cc file:/etc/csf/csf.blocklists";
			}

			if ($chain =~ /^chain_(\w+)$/) {
				$cc = $1;
				if ($cc eq "DENY") {$option = " File:/etc/csf/csf.deny"}
				if ($cc eq "ALLOW") {$option = " File:/etc/csf/csf.allow"}
				if ($cc eq "GDENY") {$option = "GLOBAL_DENY"}
				if ($cc eq "GALLOW") {$option = "GLOBAL_ALLOW"}
				if ($cc eq "ALLOWDYN") {$option = "DYNDNS"}
				if ($cc eq "GDYN") {$option = "GLOBAL_DYNDNS"}
			}
			if ($chain =~ /^chain_6_(\w+)$/) {
				$cc = $1;
				if ($cc eq "DENY") {$option = " File:/etc/csf/csf.deny"}
				if ($cc eq "ALLOW") {$option = " File:/etc/csf/csf.allow"}
				if ($cc eq "GDENY") {$option = "GLOBAL_DENY"}
				if ($cc eq "GALLOW") {$option = "GLOBAL_ALLOW"}
				if ($cc eq "ALLOWDYN") {$option = "DYNDNS"}
				if ($cc eq "GDYN") {$option = "GLOBAL_DYNDNS"}
			}
		
			my $hit = 0;
			my ($childin, $childout);
			my $pid = open3($childin, $childout, $childout, $config{IPSET}, "test", "$chain", "$ipmatch");
			my @output = <$childout>;
			waitpid ($pid, 0);
			chomp @output;
			my $line = $output[0];
			if ($line =~ /is in set/) {$hit = 1}

			if ($hit) {
				$rest = $line;
				if ($oldchain ne $chain) {print "\n"}
				print "IPSET: Set:$chain Match:$ipmatch";
				if ($option) {
					print " Setting:$option";
					if ($country) {print " Country:$country"}
				}
				print "\n";
				$oldchain = $chain;
				$mhit = 1;
			}
		}
		unless ($mhit) {
			print "IPSET: No matches found for $ipmatch\n";
		}
	}

	if ($config{IPV6}) {
		my $mhit = 0;
		my $head = 0;
		$table = "filter";
		my $oldchain = "INPUT";
		print "\n\nip6tables:\n";
		my $command = "echo 'filter table:\n' ; $config{IP6TABLES} $config{IPTABLESWAIT} -v -L -n --line-numbers";
		if ($config{NAT6}) {$command .= " ; echo 'nat table:\n' ; $config{IP6TABLES} $config{IPTABLESWAIT} -v -t nat -L -n --line-numbers"}
		if ($config{MANGLE6}) {$command .= " ; echo 'mangle table:\n' ; $config{IP6TABLES} $config{IPTABLESWAIT} -v -t mangle -L -n --line-numbers"}
		if ($config{RAW6}) {$command .= " ; echo 'raw table:\n' ; $config{IP6TABLES} $config{IPTABLESWAIT} -v -t raw -L -n --line-numbers"}
		my ($childin, $childout);
		my $pid = open3($childin, $childout, $childout, $command);
		my @output = <$childout>;
		waitpid ($pid, 0);
		chomp @output;
		if ($output[0] =~ /# Warning: iptables-legacy tables present/) {shift @output}
		foreach my $line (@output) {
			if ($line =~ /^Chain\s([\w\_]*)\s/) {$chain = $1}
			if ($line =~ /^(\S+) table:$/) {$table = $1}
			if ($chain eq "acctboth") {next}
			if (!$head and ($line =~ /^num/)) {print "\nTable  Chain            $line\n"; $head = 1}

			if ($line !~ /\d+/) {next}
			my (undef,undef,undef,$action,undef,undef,undef,$source,$destination,$options) = split(/\s+/,$line,11);
		
			my $hit = 0;
			if ($line =~ /\b$ipstring\b/i) {
				$hit = 1;
			} else {
				if (($source =~ /\//) and ($source ne "::/0")) {
					if (checkip(\$source)) {
						my $cidr = Net::CIDR::Lite->new;
						eval {local $SIG{__DIE__} = undef; $cidr->add($source)};
						if ($cidr->find($ipmatch)) {$hit = 1}
					}
				}
				if (!$hit and ($destination =~ /\//) and ($destination ne "::/0")) {
					if (checkip(\$destination)) {
						my $cidr = Net::CIDR::Lite->new;
						eval {local $SIG{__DIE__} = undef; $cidr->add($destination)};
						if ($cidr->find($ipmatch)) {$hit = 1}
					}
				}
			}
			if ($hit) {
				$rest = $line;
				if ($oldchain ne $chain) {print "\n"}
				write;
				$oldchain = $chain;
				$mhit = 1;
			}
		}
		unless ($mhit) {
			print "No matches found for $ipmatch in ip6tables\n";
		}
	}

	open (my $IN, "<", "/var/lib/csf/csf.tempallow");
	flock ($IN, LOCK_SH);
	my @tempallow = <$IN>;
	close ($IN);
	chomp @tempallow;
	foreach my $line (@tempallow) {
		my ($time,$ipd,$port,$inout,$timeout,$message) = split(/\|/,$line);
		checkip(\$ipd);
		if ($ipd eq $ipmatch) {
			print "\nTemporary Allows: IP:$ipd Port:$port Dir:$inout TTL:$timeout ($message)\n";
		}
		elsif ($ipd =~ /(.*\/\d+)/) {
			my $cidrhit = $1;
			if (checkip(\$cidrhit)) {
				my $cidr = Net::CIDR::Lite->new;
				eval {local $SIG{__DIE__} = undef; $cidr->add($cidrhit)};
				if ($cidr->find($ipmatch)) {
					print "\nTemporary Allows: IP:$ipd Port:$port Dir:$inout TTL:$timeout ($message)\n";
				}
			}
		}
	}
	my @allow = slurp("/etc/csf/csf.allow");
	foreach my $line (@allow) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @allow,@incfile;
		}
	}
	foreach my $line (@allow) {
        $line =~ s/$cleanreg//g;
		if ($line eq "") {next}
		if ($line =~ /^\s*\#|Include/) {next}
		my ($ipd,$commentd) = split (/\s/,$line,2);
		checkip(\$ipd);
		if ($ipd eq $ipmatch) {
			print "\ncsf.allow: $line\n";
		}
		elsif ($ipd =~ /(.*\/\d+)/) {
			my $cidrhit = $1;
			if (checkip(\$cidrhit)) {
				my $cidr = Net::CIDR::Lite->new;
				eval {local $SIG{__DIE__} = undef; $cidr->add($cidrhit)};
				if ($cidr->find($ipmatch)) {
					print "\nPermanent Allows (csf.allow): $line\n"
				}
			}
		}
	}
	open (my $TEMPBAN, "<", "/var/lib/csf/csf.tempban");
	flock ($TEMPBAN, LOCK_SH);
	my @tempdeny = <$TEMPBAN>;
	close ($TEMPBAN);
	chomp @tempdeny;
	foreach my $line (@tempdeny) {
		my ($time,$ipd,$port,$inout,$timeout,$message) = split(/\|/,$line);
		checkip(\$ipd);
		if ($ipd eq $ipmatch) {
			print "\nTemporary Blocks: IP:$ipd Port:$port Dir:$inout TTL:$timeout ($message)\n";
		}
		elsif ($ipd =~ /(.*\/\d+)/) {
			my $cidrhit = $1;
			if (checkip(\$cidrhit)) {
				my $cidr = Net::CIDR::Lite->new;
				eval {local $SIG{__DIE__} = undef; $cidr->add($cidrhit)};
				if ($cidr->find($ipmatch)) {
					print "\nTemporary Blocks: IP:$ipd Port:$port Dir:$inout TTL:$timeout ($message)\n";
				}
			}
		}
	}
	my @deny = slurp("/etc/csf/csf.deny");
	foreach my $line (@deny) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @deny,@incfile;
		}
	}
	foreach my $line (@deny) {
        $line =~ s/$cleanreg//g;
		if ($line eq "") {next}
		if ($line =~ /^\s*\#|Include/) {next}
		my ($ipd,$commentd) = split (/\s/,$line,2);
		checkip(\$ipd);
		if ($ipd eq $ipmatch) {
			print "\ncsf.deny: $line\n";
		}
		elsif ($ipd =~ /(.*\/\d+)/) {
			my $cidrhit = $1;
			if (checkip(\$cidrhit)) {
				my $cidr = Net::CIDR::Lite->new;
				eval {local $SIG{__DIE__} = undef; $cidr->add($cidrhit)};
				if ($cidr->find($ipmatch)) {
					print "\nPermanent Blocks (csf.deny): $line\n"
				}
			}
		}
	}
	return;
}
# end dogrep
###############################################################################
# start dotempban
sub dotempban {
	my ($ip,$deny,$ports,$inout,$time,$timeout,$message);
	format TEMPBAN =
@<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @|||||| @<<<< @<<<<<<<<<<<<<<< @*
$deny, $ip,                                   $ports,  $inout,$time,$message
.
	local $~ = "TEMPBAN";
	if ((! -z "/var/lib/csf/csf.tempban") or (! -z "/var/lib/csf/csf.tempallow")) {
		print "\nA/D   IP address                               Port   Dir   Time To Live     Comment\n";
		if (! -z "/var/lib/csf/csf.tempban") {
			sysopen (my $IN, "/var/lib/csf/csf.tempban", O_RDWR);
			flock ($IN, LOCK_SH);
			my @data = <$IN>;
			chomp @data;
			close ($IN);

			foreach my $line (@data) {
				if ($line eq "") {next}
				($time,$ip,$ports,$inout,$timeout,$message) = split(/\|/,$line);
				$time = $timeout - (time - $time);
				if ($ports eq "") {$ports = "*"}
				if ($inout eq "") {$inout = " *"}
				if ($time < 1) {
					$time = "<1";
				} else {
					my $days = int($time/(24*60*60));
					my $hours = ($time/(60*60))%24;
					my $mins = ($time/60)%60;
					my $secs = $time%60;
					$days = $days < 1 ? '' : $days .'d ';
					$hours = $hours < 1 ? '' : $hours .'h ';
					$mins = $mins < 1 ? '' : $mins . 'm ';
					$time = $days . $hours . $mins . $secs . 's'; 
				}
				$deny = "DENY";
				foreach (split(/,/,$ports)) {write}
			}
		}
		if (! -z "/var/lib/csf/csf.tempallow") {
			sysopen (my $IN, "/var/lib/csf/csf.tempallow", O_RDWR);
			flock ($IN, LOCK_SH);
			my @data = <$IN>;
			chomp @data;
			close ($IN);

			foreach my $line (@data) {
				if ($line eq "") {next}
				($time,$ip,$ports,$inout,$timeout,$message) = split(/\|/,$line);
				$time = $timeout - (time - $time);
				if ($ports eq "") {$ports = "*"}
				if ($inout eq "") {$inout = " *"}
				if ($time < 1) {
					$time = "<1";
				} else {
					my $days = int($time/(24*60*60));
					my $hours = ($time/(60*60))%24;
					my $mins = ($time/60)%60;
					my $secs = $time%60;
					$days = $days < 1 ? '' : $days .'d ';
					$hours = $hours < 1 ? '' : $hours .'h ';
					$mins = $mins < 1 ? '' : $mins . 'm ';
					$time = $days . $hours . $mins . $secs . 's'; 
				}
				$deny = "ALLOW";
				foreach (split(/,/,$ports)) {write}
			}
		}
	} else {
		print "csf: There are no temporary IP entries\n";
	}
	return;
}
# end dotempban
###############################################################################
# start dotempdeny
sub dotempdeny {
	my $cftemp = shift;
	my ($ip,$timeout,$portdir) = split(/\s/,$input{argument},3);
	my $inout = "in";
	my $port = "";
	if ($timeout =~ /^(\d*)(m|h|d)/i) {
		my $secs = $1;
		my $dur = $2;
		if ($dur eq "m") {$timeout = $secs * 60}
		elsif ($dur eq "h") {$timeout = $secs * 60 * 60}
		elsif ($dur eq "d") {$timeout = $secs * 60 * 60 * 24}
		else {$timeout = $secs}
	}

	my $iptype = checkip(\$ip);
	if ($iptype == 6 and !$config{IPV6}) {
		print "failed: [$ip] is valid IPv6 but IPV6 is not enabled in csf.conf\n";
	}

	unless ($iptype) {
		print "csf: [$ip] is not a valid PUBLIC IP\n";
		return;
	}

	&getethdev;

	if ($ips{$ip} or $ipscidr->find($ip) or $ipscidr6->find($ip)) {
		print "deny failed: [$ip] is one of this servers addresses!\n";
		return;
	}

	if ($timeout =~ /\D/) {
		$portdir = join(" ",$timeout,$portdir);
		$timeout = 0;
	}

	if ($portdir =~ /\-d\s*out/i) {$inout = "out"}
	if ($portdir =~ /\-d\s*inout/i) {$inout = "inout"}
	if ($portdir =~ /\-p\s*([\w\,\*\;]+)/) {$port = $1}
	my $comment = $portdir;
	$comment =~ s/\-d\s*out//ig;
	$comment =~ s/\-d\s*inout//ig;
	$comment =~ s/\-d\s*in//ig;
	$comment =~ s/\-p\s*[\w\,\*\;]+//ig;
	$comment =~ s/^\s*|\s*$//g;
	if ($comment eq "") {$comment = "Manually added: ".iplookup($ip)}

	my @deny = slurp("/etc/csf/csf.deny");
	foreach my $line (@deny) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @deny,@incfile;
		}
	}
	my $ipstring = quotemeta($ip);
	if (grep {$_ =~ /^$ipstring\b/} @deny) {
		print "csf: $ip is already permanently blocked\n";
		exit 0;
	}
	open (my $IN, "<", "/var/lib/csf/csf.tempban");
	flock ($IN, LOCK_SH);
	@deny = <$IN>;
	close ($IN);
	chomp @deny;
	if (grep {$_ =~ /\b$ip\|$port\|\b/} @deny) {
		print "csf: $ip is already temporarily blocked\n";
		exit 0;
	}

	my $dropin = $config{DROP};
	my $dropout = $config{DROP_OUT};
	if ($config{DROP_IP_LOGGING}) {$dropin = "LOGDROPIN"}
	if ($config{DROP_OUT_LOGGING}) {$dropout = "LOGDROPOUT"}
	if ($timeout < 2) {$timeout = 3600}
	if ($port =~ /\*/) {$port = ""}

	if ($inout =~ /in/) {
		if ($port) {
			foreach my $dport (split(/\,/,$port)) {
				my ($tport,$proto) = split(/\;/,$dport);
				$dport = $tport;
				if ($proto eq "") {$proto = "tcp"}
				if ($iptype == 6) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A DENYIN $eth6devin -p $proto --dport $dport -s $ip -j $dropin");
					if ($messengerports{$dport} and $config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"A",$dport)}
				} else {
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A DENYIN $ethdevin -p $proto --dport $dport -s $ip -j $dropin");
					if ($messengerports{$dport} and $config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"A",$dport)}
				}
			}
		} else {
			if ($iptype == 6) {
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A DENYIN $eth6devin -s $ip -j $dropin");
				if ($config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"A")}
			} else {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A DENYIN $ethdevin -s $ip -j $dropin");
				if ($config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"A")}
			}
		}
	}
	if ($inout =~ /out/) {
		if ($port) {
			foreach my $dport (split(/\,/,$port)) {
				my ($tport,$proto) = split(/\;/,$dport);
				$dport = $tport;
				if ($proto eq "") {$proto = "tcp"}
				if ($iptype == 6) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A DENYOUT $eth6devout -p $proto --dport $dport -d $ip -j $dropout");
				} else {
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A DENYOUT $ethdevout -p $proto --dport $dport -d $ip -j $dropout");
				}
			}
		} else {
			if ($iptype == 6) {
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -A DENYOUT $eth6devout -d $ip -j $dropout");
			} else {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -A DENYOUT $ethdevout -d $ip -j $dropout");
			}
		}
	}

	if ($config{CF_ENABLE} and $cftemp) {$comment .= " (CF_ENABLE)"}

	sysopen (my $OUT, "/var/lib/csf/csf.tempban", O_WRONLY | O_APPEND | O_CREAT) or &error(__LINE__,"Error: Can't append out file: $!");
	flock ($OUT, LOCK_EX);
	print $OUT time."|$ip|$port|$inout|$timeout|$comment\n";
	close ($OUT);

	if ($port eq "") {$port = "*"}
	if ($inout eq "in") {$inout = "inbound"}
	if ($inout eq "out") {$inout = "outbound"}
	if ($inout eq "inout") {$inout = "in and outbound"}
	print "csf: $ip blocked on port $port for $timeout seconds $inout\n";
	return;
}
# end dotempdeny
###############################################################################
# start dotempallow
sub dotempallow {
	my $cftemp = shift;
	my ($ip,$timeout,$portdir) = split(/\s/,$input{argument},3);
	my $inout = "inout";
	my $port = "";
	if ($timeout =~ /^(\d*)(m|h|d)/i) {
		my $secs = $1;
		my $dur = $2;
		if ($dur eq "m") {$timeout = $secs * 60}
		elsif ($dur eq "h") {$timeout = $secs * 60 * 60}
		elsif ($dur eq "d") {$timeout = $secs * 60 * 60 * 24}
		else {$timeout = $secs}
	}

	my $iptype = checkip(\$ip);
	if ($iptype == 6 and !$config{IPV6}) {
		print "failed: [$ip] is valid IPv6 but IPV6 is not enabled in csf.conf\n";
	}

	unless ($iptype) {
		print "csf: [$ip] is not a valid PUBLIC IP\n";
		return;
	}
	if ($timeout =~ /\D/) {
		$portdir = join(" ",$timeout,$portdir);
		$timeout = 0;
	}

	if ($portdir =~ /\-d\s*in/i) {$inout = "in"}
	if ($portdir =~ /\-d\s*out/i) {$inout = "out"}
	if ($portdir =~ /\-d\s*inout/i) {$inout = "inout"}
	if ($portdir =~ /\-p\s*([\w\,\*\;]+)/) {$port = $1}
	my $comment = $portdir;
	$comment =~ s/\-d\s*out//ig;
	$comment =~ s/\-d\s*inout//ig;
	$comment =~ s/\-d\s*in//ig;
	$comment =~ s/\-p\s*[\w\,\*\;]+//ig;
	$comment =~ s/^\s*|\s*$//g;
	if ($comment eq "") {$comment = "Manually added: ".iplookup($ip)}

	my @allow = slurp("/etc/csf/csf.allow");
	foreach my $line (@allow) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @allow,@incfile;
		}
	}
	if (grep {$_ =~ /^$ip\b/} @allow) {
		print "csf: $ip is already permanently allowed\n";
		exit 0;
	}
	open (my $IN, "<", "/var/lib/csf/csf.tempallow");
	flock ($IN, LOCK_SH);
	@allow = <$IN>;
	close ($IN);
	chomp @allow;
	if (grep {$_ =~ /\b$ip\|$port\|\b/} @allow) {
		print "csf: $ip is already temporarily allowed\n";
		exit 0;
	}

	if ($timeout < 2) {$timeout = 3600}
	if ($port =~ /\*/) {$port = ""}

	&getethdev;

	if ($inout =~ /in/) {
		if ($port) {
			foreach my $dport (split(/\,/,$port)) {
				my ($tport,$proto) = split(/\;/,$dport);
				$dport = $tport;
				if ($proto eq "") {$proto = "tcp"}
				if ($iptype == 6) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I ALLOWIN $eth6devin -p $proto --dport $dport -s $ip -j $accept");
				} else {
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I ALLOWIN $ethdevin -p $proto --dport $dport -s $ip -j $accept");
				}
			}
		} else {
			if ($iptype == 6) {
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I ALLOWIN $eth6devin -s $ip -j $accept");
			} else {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I ALLOWIN $ethdevin -s $ip -j $accept");
			}
		}
	}
	if ($inout =~ /out/) {
		if ($port) {
			foreach my $dport (split(/\,/,$port)) {
				my ($tport,$proto) = split(/\;/,$dport);
				$dport = $tport;
				if ($proto eq "") {$proto = "tcp"}
				if ($iptype == 6) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I ALLOWOUT $eth6devout -p $proto --dport $dport -d $ip -j $accept");
				} else {
					&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I ALLOWOUT $ethdevout -p $proto --dport $dport -d $ip -j $accept");
				}
			}
		} else {
			if ($iptype == 6) {
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -I ALLOWOUT $eth6devout -d $ip -j $accept");
			} else {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -I ALLOWOUT $ethdevout -d $ip -j $accept");
			}
		}
	}

	if ($config{CF_ENABLE} and $cftemp) {$comment .= " (CF_ENABLE)"}

	sysopen (my $OUT, "/var/lib/csf/csf.tempallow", O_WRONLY | O_APPEND | O_CREAT) or &error(__LINE__,"Error: Can't append out file: $!");
	flock ($OUT, LOCK_EX);
	print $OUT time."|$ip|$port|$inout|$timeout|$comment\n";
	close ($OUT);

	if ($port eq "") {$port = "*"}
	if ($inout eq "in") {$inout = "inbound"}
	if ($inout eq "out") {$inout = "outbound"}
	if ($inout eq "inout") {$inout = "in and outbound"}
	print "csf: $ip allowed on port $port for $timeout seconds $inout\n";
	return;
}
# end dotempallow
###############################################################################
# start dotemprm
sub dotemprm {
	my $ip = $input{argument};

	if ($ip eq "") {
		print "csf: No IP specified\n";
		return;
	}

	my $iptype = checkip(\$ip);
	if ($iptype == 6 and !$config{IPV6}) {
		print "failed: [$ip] is valid IPv6 but IPV6 is not enabled in csf.conf\n";
	}

	unless ($iptype) {
		print "csf: [$ip] is not a valid PUBLIC IP\n";
		return;
	}
	&getethdev;
	if (! -z "/var/lib/csf/csf.tempban") {
		my $unblock = 0;
		sysopen (my $TEMPBAN, "/var/lib/csf/csf.tempban", O_RDWR | O_CREAT);
		flock ($TEMPBAN, LOCK_EX);
		my @data = <$TEMPBAN>;
		chomp @data;

		my @newdata;
		foreach my $line (@data) {
			my ($time,$thisip,$port,$inout,$timeout,$message) = split(/\|/,$line);
			if ($thisip eq $ip) {
				my $dropin = $config{DROP};
				my $dropout = $config{DROP_OUT};
				if ($config{DROP_IP_LOGGING}) {$dropin = "LOGDROPIN"}
				if ($config{DROP_OUT_LOGGING}) {$dropout = "LOGDROPOUT"}

				if ($inout =~ /in/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D DENYIN $eth6devin -p $proto --dport $dport -s $ip -j $dropin");
								if ($messengerports{$dport} and $config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D",$dport)}
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D DENYIN $ethdevin -p $proto --dport $dport -s $ip -j $dropin");
								if ($messengerports{$dport} and $config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D",$dport)}
							}
						}
					} else {
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D DENYIN $eth6devin -s $ip -j $dropin");
							if ($config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D")}
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D DENYIN $ethdevin -s $ip -j $dropin");
							if ($config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D")}
						}
					}
				}
				if ($inout =~ /out/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D DENYOUT $eth6devout -p $proto --dport $dport -d $ip -j $dropout");
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D DENYOUT $ethdevout -p $proto --dport $dport -d $ip -j $dropout");
							}
						}
					} else {
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D DENYOUT $eth6devout -d $ip -j $dropout");
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D DENYOUT $ethdevout -d $ip -j $dropout");
						}
					}
				}
				if ($config{CF_ENABLE} and $message =~ /\(CF_ENABLE\)/) {ConfigServer::CloudFlare::action("remove",$ip,$config{CF_BLOCK})}
				print "csf: $ip temporary block removed\n";
				$unblock = 1;
			} else {
				push @newdata, $line;
			}
		}
		seek ($TEMPBAN, 0, 0);
		truncate ($TEMPBAN, 0);
		foreach my $line (@newdata) {print $TEMPBAN "$line\n"}
		close ($TEMPBAN);
		unless ($unblock) {
			print "csf: $ip not found in temporary bans\n";
		}
	} else {
		print "csf: There are no temporary IP bans\n";
	}
	if (! -z "/var/lib/csf/csf.tempallow") {
		my $unblock = 0;
		sysopen (my $TEMPALLOW, "/var/lib/csf/csf.tempallow", O_RDWR | O_CREAT);
		flock ($TEMPALLOW, LOCK_EX);
		my @data = <$TEMPALLOW>;
		chomp @data;

		my @newdata;
		foreach my $line (@data) {
			my ($time,$thisip,$port,$inout,$timeout,$message) = split(/\|/,$line);
			if ($thisip eq $ip) {
				if ($inout =~ /in/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D ALLOWIN $eth6devin -p $proto --dport $dport -s $ip -j $accept");
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D ALLOWIN $ethdevin -p $proto --dport $dport -s $ip -j $accept");
							}
						}
					} else {
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D ALLOWIN $eth6devin -s $ip -j $accept");
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D ALLOWIN $ethdevin -s $ip -j $accept");
						}
					}
				}
				if ($inout =~ /out/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D ALLOWOUT $eth6devout -p $proto --dport $dport -d $ip -j $accept");
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D ALLOWOUT $ethdevout -p $proto --dport $dport -d $ip -j $accept");
							}
						}
					} else {
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D ALLOWOUT $eth6devout -d $ip -j $accept");
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D ALLOWOUT $ethdevout -d $ip -j $accept");
						}
					}
				}
				if ($config{CF_ENABLE} and $message =~ /\(CF_ENABLE\)/) {ConfigServer::CloudFlare::action("remove",$ip,"whitelist")}
				print "csf: $ip temporary allow removed\n";
				$unblock = 1;
			} else {
				push @newdata, $line;
			}
		}
		seek ($TEMPALLOW, 0, 0);
		truncate ($TEMPALLOW, 0);
		foreach my $line (@newdata) {print $TEMPALLOW "$line\n"}
		close ($TEMPALLOW);
		unless ($unblock) {
			print "csf: $ip not found in temporary allows\n";
		}
	} else {
		print "csf: There are no temporary IP allows\n";
	}
	return;
}
# end dotemprm
###############################################################################
# start dotemprmd
sub dotemprmd {
	my $ip = $input{argument};

	if ($ip eq "") {
		print "csf: No IP specified\n";
		return;
	}

	my $iptype = checkip(\$ip);
	if ($iptype == 6 and !$config{IPV6}) {
		print "failed: [$ip] is valid IPv6 but IPV6 is not enabled in csf.conf\n";
	}

	unless ($iptype) {
		print "csf: [$ip] is not a valid PUBLIC IP\n";
		return;
	}
	&getethdev;
	if (! -z "/var/lib/csf/csf.tempban") {
		my $unblock = 0;
		sysopen (my $TEMPBAN, "/var/lib/csf/csf.tempban", O_RDWR | O_CREAT);
		flock ($TEMPBAN, LOCK_EX);
		my @data = <$TEMPBAN>;
		chomp @data;

		my @newdata;
		foreach my $line (@data) {
			my ($time,$thisip,$port,$inout,$timeout,$message) = split(/\|/,$line);
			if ($thisip eq $ip) {
				my $dropin = $config{DROP};
				my $dropout = $config{DROP_OUT};
				if ($config{DROP_IP_LOGGING}) {$dropin = "LOGDROPIN"}
				if ($config{DROP_OUT_LOGGING}) {$dropout = "LOGDROPOUT"}

				if ($inout =~ /in/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D DENYIN $eth6devin -p $proto --dport $dport -s $ip -j $dropin");
								if ($messengerports{$dport} and $config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D",$dport)}
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D DENYIN $ethdevin -p $proto --dport $dport -s $ip -j $dropin");
								if ($messengerports{$dport} and $config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D",$dport)}
							}
						}
					} else {
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D DENYIN $eth6devin -s $ip -j $dropin");
							if ($config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D")}
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D DENYIN $ethdevin -s $ip -j $dropin");
							if ($config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D")}
						}
					}
				}
				if ($inout =~ /out/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D DENYOUT $eth6devout -p $proto --dport $dport -d $ip -j $dropout");
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D DENYOUT $ethdevout -p $proto --dport $dport -d $ip -j $dropout");
							}
						}
					} else {
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D DENYOUT $eth6devout -d $ip -j $dropout");
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D DENYOUT $ethdevout -d $ip -j $dropout");
						}
					}
				}
				if ($config{CF_ENABLE} and $message =~ /\(CF_ENABLE\)/) {ConfigServer::CloudFlare::action("remove",$ip,$config{CF_BLOCK})}
				print "csf: $ip temporary block removed\n";
				$unblock = 1;
			} else {
				push @newdata, $line;
			}
		}
		seek ($TEMPBAN, 0, 0);
		truncate ($TEMPBAN, 0);
		foreach my $line (@newdata) {print $TEMPBAN "$line\n"}
		close ($TEMPBAN);
		unless ($unblock) {
			print "csf: $ip not found in temporary bans\n";
		}
	} else {
		print "csf: There are no temporary IP bans\n";
	}

	return;
}
# end dotemprmd
###############################################################################
# start dotemprma
sub dotemprma {
	my $ip = $input{argument};

	if ($ip eq "") {
		print "csf: No IP specified\n";
		return;
	}

	my $iptype = checkip(\$ip);
	if ($iptype == 6 and !$config{IPV6}) {
		print "failed: [$ip] is valid IPv6 but IPV6 is not enabled in csf.conf\n";
	}

	unless ($iptype) {
		print "csf: [$ip] is not a valid PUBLIC IP\n";
		return;
	}
	&getethdev;
	if (! -z "/var/lib/csf/csf.tempallow") {
		my $unblock = 0;
		sysopen (my $TEMPALLOW, "/var/lib/csf/csf.tempallow", O_RDWR | O_CREAT);
		flock ($TEMPALLOW, LOCK_EX);
		my @data = <$TEMPALLOW>;
		chomp @data;

		my @newdata;
		foreach my $line (@data) {
			my ($time,$thisip,$port,$inout,$timeout,$message) = split(/\|/,$line);
			if ($thisip eq $ip) {
				if ($inout =~ /in/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D ALLOWIN $eth6devin -p $proto --dport $dport -s $ip -j $accept");
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D ALLOWIN $ethdevin -p $proto --dport $dport -s $ip -j $accept");
							}
						}
					} else {
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D ALLOWIN $eth6devin -s $ip -j $accept");
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D ALLOWIN $ethdevin -s $ip -j $accept");
						}
					}
				}
				if ($inout =~ /out/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D ALLOWOUT $eth6devout -p $proto --dport $dport -d $ip -j $accept");
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D ALLOWOUT $ethdevout -p $proto --dport $dport -d $ip -j $accept");
							}
						}
					} else {
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D ALLOWOUT $eth6devout -d $ip -j $accept");
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D ALLOWOUT $ethdevout -d $ip -j $accept");
						}
					}
				}
				if ($config{CF_ENABLE} and $message =~ /\(CF_ENABLE\)/) {ConfigServer::CloudFlare::action("remove",$ip,"whitelist")}
				print "csf: $ip temporary allow removed\n";
				$unblock = 1;
			} else {
				push @newdata, $line;
			}
		}
		seek ($TEMPALLOW, 0, 0);
		truncate ($TEMPALLOW, 0);
		foreach my $line (@newdata) {print $TEMPALLOW "$line\n"}
		close ($TEMPALLOW);
		unless ($unblock) {
			print "csf: $ip not found in temporary allows\n";
		}
	} else {
		print "csf: There are no temporary IP allows\n";
	}
	return;
}
# end dotemprma
###############################################################################
# start dotempf
sub dotempf {
	&getethdev;
	if (! -z "/var/lib/csf/csf.tempban") {
		sysopen (my $TEMPBAN, "/var/lib/csf/csf.tempban", O_RDWR | O_CREAT);
		flock ($TEMPBAN, LOCK_EX);
		my @data = <$TEMPBAN>;
		chomp @data;

		foreach my $line (@data) {
			if ($line eq "") {next}
			my ($time,$ip,$port,$inout,$timeout,$message) = split(/\|/,$line);
			my $iptype = checkip(\$ip);
			if ($iptype == 6 and !$config{IPV6}) {next}
			my $dropin = $config{DROP};
			my $dropout = $config{DROP_OUT};
			if ($config{DROP_IP_LOGGING}) {$dropin = "LOGDROPIN"}
			if ($config{DROP_OUT_LOGGING}) {$dropout = "LOGDROPOUT"}

			if ($inout =~ /in/) {
				if ($port) {
					foreach my $dport (split(/\,/,$port)) {
						my ($tport,$proto) = split(/\;/,$dport);
						$dport = $tport;
						if ($proto eq "") {$proto = "tcp"}
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D DENYIN $eth6devin -p $proto --dport $dport -s $ip -j $dropin");
							if ($messengerports{$dport} and $config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D",$dport)}
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D DENYIN $ethdevin -p $proto --dport $dport -s $ip -j $dropin");
							if ($messengerports{$dport} and $config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D",$dport)}
						}
					}
				} else {
					if ($iptype == 6) {
						&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D DENYIN $eth6devin -s $ip -j $dropin");
						if ($config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D")}
					} else {
						&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D DENYIN $ethdevin -s $ip -j $dropin");
						if ($config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D")}
					}
				}
			}
			if ($inout =~ /out/) {
				if ($port) {
					foreach my $dport (split(/\,/,$port)) {
						my ($tport,$proto) = split(/\;/,$dport);
						$dport = $tport;
						if ($proto eq "") {$proto = "tcp"}
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D DENYOUT $eth6devout -p $proto --dport $dport -d $ip -j $dropout");
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D DENYOUT $ethdevout -p $proto --dport $dport -d $ip -j $dropout");
						}
					}
				} else {
					if ($iptype == 6) {
						&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D DENYOUT $eth6devout -d $ip -j $dropout");
					} else {
						&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D DENYOUT $ethdevout -d $ip -j $dropout");
					}
				}
			}
			if ($config{CF_ENABLE} and $message =~ /\(CF_ENABLE\)/) {ConfigServer::CloudFlare::action("remove",$ip,$config{CF_BLOCK})}
			print "csf: $ip temporary block removed\n";
		}
		seek ($TEMPBAN, 0, 0);
		truncate ($TEMPBAN, 0);
		close ($TEMPBAN);
	} else {
		print "csf: There are no temporary IP bans\n";
	}
	if (! -z "/var/lib/csf/csf.tempallow") {
		sysopen (my $TEMPALLOW, "/var/lib/csf/csf.tempallow", O_RDWR | O_CREAT);
		flock ($TEMPALLOW, LOCK_EX);
		my @data = <$TEMPALLOW>;
		chomp @data;

		foreach my $line (@data) {
			if ($line eq "") {next}
			my ($time,$ip,$port,$inout,$timeout,$message) = split(/\|/,$line);
			my $iptype = checkip(\$ip);
			if ($iptype == 6 and !$config{IPV6}) {next}
			if ($inout =~ /in/) {
				if ($port) {
					foreach my $dport (split(/\,/,$port)) {
						my ($tport,$proto) = split(/\;/,$dport);
						$dport = $tport;
						if ($proto eq "") {$proto = "tcp"}
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D ALLOWIN $eth6devin -p $proto --dport $dport -s $ip -j $accept");
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D ALLOWIN $ethdevin -p $proto --dport $dport -s $ip -j $accept");
						}
					}
				} else {
					if ($iptype == 6) {
						&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D ALLOWIN $eth6devin -s $ip -j $accept");
					} else {
						&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D ALLOWIN $ethdevin -s $ip -j $accept");
					}
				}
			}
			if ($inout =~ /out/) {
				if ($port) {
					foreach my $dport (split(/\,/,$port)) {
						my ($tport,$proto) = split(/\;/,$dport);
						$dport = $tport;
						if ($proto eq "") {$proto = "tcp"}
						if ($iptype == 6) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D ALLOWOUT $eth6devout -p $proto --dport $dport -d $ip -j $accept");
						} else {
							&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D ALLOWOUT $ethdevout -p $proto --dport $dport -d $ip -j $accept");
						}
					}
				} else {
					if ($iptype == 6) {
						&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -D ALLOWOUT $eth6devout -d $ip -j $accept");
					} else {
						&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -D ALLOWOUT $ethdevout -d $ip -j $accept");
					}
				}
			}
			if ($config{CF_ENABLE} and $message =~ /\(CF_ENABLE\)/) {ConfigServer::CloudFlare::action("remove",$ip,"whitelist")}
			print "csf: $ip temporary allow removed\n";
		}
		seek ($TEMPALLOW, 0, 0);
		truncate ($TEMPALLOW, 0);
		close ($TEMPALLOW);
	} else {
		print "csf: There are no temporary IP allows\n";
	}
	return;
}
# end dotempf
###############################################################################
# start dowatch
sub dowatch {
	print "csf: --watch, -w is no longer supported. Use --trace instead\n";
	return;
}
# end dowatch
###############################################################################
# start dotrace
sub dotrace {
	my $cmd = $ARGV[1];
	my $ip = $ARGV[2];

	if ($ip eq "") {
		print "csf: No IP specified\n";
		return;
	}

	my $checkip = checkip(\$ip);
	unless ($checkip) {
		print "csf: [$ip] is not a valid PUBLIC IP\n";
		return;
	}

	if ($cmd eq "add") {
		if ($checkip == 4) {
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t raw -I PREROUTING -p tcp --syn --source $ip -j TRACE");
		} else {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t raw -I PREROUTING -p tcp --syn --source $ip -j TRACE");
		}
		print "csf: Added trace for $ip\n";
	}
	elsif ($cmd eq "remove") {
		if ($checkip == 4) {
			&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t raw -D PREROUTING -p tcp --syn --source $ip -j TRACE");
		} else {
			&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t raw -D PREROUTING -p tcp --syn --source $ip -j TRACE");
		}
		print "csf: Removed trace for $ip\n";
	}
	else {
		print "csf: Error, use [add|remove] [ip]\n";
	}

	return;
}
# end dotrace
###############################################################################
# start dologrun
sub dologrun {
	if ($config{LOGSCANNER}) {
		open (my $OUT, ">", "/var/lib/csf/csf.logrun") or &error(__LINE__,"Could not create /var/lib/csf/csf.logrun: $!");
		flock ($OUT, LOCK_EX);
		close ($OUT);
	} else {
		print "Option LOGSCANNER needs to be enabled in csf.conf for this feature\n";
	}
	return;
}
# end dologrun
###############################################################################
# start domessenger
sub domessenger {
	my $ip = shift;
	my $delete = shift;
	my $ports = shift;
	if ($ports eq "") {$ports = "$config{MESSENGER_HTTPS_IN},$config{MESSENGER_HTML_IN},$config{MESSENGER_TEXT_IN}"}
	my $iptype = checkip(\$ip);

	if ($config{CC_MESSENGER_ALLOW} or $config{CC_MESSENGER_DENY}) {
		my ($cc,$asn) = iplookup($ip,1);
		($asn,undef) = split(/\s+/,$asn);

		if ($config{CC_MESSENGER_ALLOW}) {
			my $allow = 0;
			if ($cc ne "" and $config{CC_MESSENGER_ALLOW} =~ /$cc/i) {$allow = 1}
			if ($asn ne "" and $config{CC_MESSENGER_ALLOW} =~ /$asn/i) {$allow = 1}
			unless ($allow) {return 1}
		}

		if ($config{CC_MESSENGER_DENY}) {
			if ($cc ne "" and $config{CC_MESSENGER_DENY} =~ /$cc/i) {return 1}
			if ($asn ne "" and $config{CC_MESSENGER_DENY} =~ /$asn/i) {return 1}
		}
	}

	my $del = "-A";
	if ($delete eq "D") {$del = "-D"}

	my %textin;
	my %htmlin;
	my %httpsin;
	foreach my $port (split(/\,/,$config{MESSENGER_HTTPS_IN})) {$httpsin{$port} = 1}
	foreach my $port (split(/\,/,$config{MESSENGER_HTML_IN})) {$htmlin{$port} = 1}
	foreach my $port (split(/\,/,$config{MESSENGER_TEXT_IN})) {$textin{$port} = 1}

	my $textports;
	my $htmlports;
	my $httpsports;
	foreach my $port (split(/\,/,$ports)) {
		if ($httpsin{$port}) {
			if ($httpsports eq "") {$httpsports = "$port"} else {$httpsports .= ",$port"}
		}
		if ($htmlin{$port}) {
			if ($htmlports eq "") {$htmlports = "$port"} else {$htmlports .= ",$port"}
		}
		if ($textin{$port}) {
			if ($textports eq "") {$textports = "$port"} else {$textports .= ",$port"}
		}
	}

	if ($config{LF_IPSET}) {
		if ($ip =~ /^-m set/) {
			my $ip6 = $ip;
			$ip6 =~ s/MESSENGER src/MESSENGER_6 src/g;
			if ($httpsports ne "") {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -A PREROUTING $ethdevin -p tcp $ip -m multiport --dports $httpsports -j REDIRECT --to-ports $config{MESSENGER_HTTPS}");
				if ($config{MESSENGER6}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t nat -A PREROUTING $ethdevin -p tcp $ip6 -m multiport --dports $httpsports -j REDIRECT --to-ports $config{MESSENGER_HTTPS}");
				}
			}
			if ($htmlports ne "") {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -A PREROUTING $ethdevin -p tcp $ip -m multiport --dports $htmlports -j REDIRECT --to-ports $config{MESSENGER_HTML}");
				if ($config{MESSENGER6}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t nat -A PREROUTING $ethdevin -p tcp $ip6 -m multiport --dports $htmlports -j REDIRECT --to-ports $config{MESSENGER_HTML}");
				}
			}
			if ($textports ne "") {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat -A PREROUTING $ethdevin -p tcp $ip -m multiport --dports $textports -j REDIRECT --to-ports $config{MESSENGER_TEXT}");
				if ($config{MESSENGER6}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t nat -A PREROUTING $ethdevin -p tcp $ip6 -m multiport --dports $textports -j REDIRECT --to-ports $config{MESSENGER_TEXT}");
				}
			}
		} else {
			if ($delete eq "D") {
				if ($iptype == 4) {
					&ipsetdel("MESSENGER",$ip);
				}
				if ($iptype == 6 and $config{MESSENGER6}) {
					&ipsetdel("MESSENGER_6",$ip);
				}
			} else {
				if ($iptype == 4) {
					&ipsetadd("MESSENGER",$ip);
				}
				if ($iptype == 6 and $config{MESSENGER6}) {
					&ipsetadd("MESSENGER_6",$ip);
				}
			}
		}
	} else {
		if ($httpsports ne "") {
			if ($iptype == 4) {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -t nat $del PREROUTING $ethdevin -p tcp -s $ip -m multiport --dports $httpsports -j REDIRECT --to-ports $config{MESSENGER_HTTPS}");
			}
			if ($iptype == 6 and $config{MESSENGER6}) {
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -t nat $del PREROUTING $ethdevin -p tcp -s $ip -m multiport --dports $httpsports -j REDIRECT --to-ports $config{MESSENGER_HTTPS}");
			}
		}
		if ($htmlports ne "") {
			if ($iptype == 4) {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat $del PREROUTING $ethdevin -p tcp -s $ip -m multiport --dports $htmlports -j REDIRECT --to-ports $config{MESSENGER_HTML}");
			}
			if ($iptype == 6 and $config{MESSENGER6}) {
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t nat $del PREROUTING $ethdevin -p tcp -s $ip -m multiport --dports $htmlports -j REDIRECT --to-ports $config{MESSENGER_HTML}");
			}
		}
		if ($textports ne "") {
			if ($iptype == 4) {
				&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} $verbose -t nat $del PREROUTING $ethdevin -p tcp -s $ip -m multiport --dports $textports -j REDIRECT --to-ports $config{MESSENGER_TEXT}");
			}
			if ($iptype == 6 and $config{MESSENGER6}) {
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} $verbose -t nat $del PREROUTING $ethdevin -p tcp -s $ip -m multiport --dports $textports -j REDIRECT --to-ports $config{MESSENGER_TEXT}");
			}
		}
	}
	return;
}
# end domessenger
###############################################################################
# start domail
sub domail {
	my $output = ConfigServer::ServerCheck::report();

	if ($input{argument}) {
		my $message = "From: root\n";
		$message .= "To: root\n";
		$message .= "Subject: Server Check on [hostname]\n";
		$message .= "MIME-Version: 1.0\n";
		$message .= "Content-Type: text/html\n";
		$message .= "\n";
		$message .= $output;
		my @message = split(/\n/,$message);
		ConfigServer::Sendmail::relay($input{argument}, "", @message);
	} else {
		print $output;
		print "\n";
	}
	return;
}
# end domail
###############################################################################
# start dorbls
sub dorbls {
	my ($failures, $output) = ConfigServer::RBLCheck::report(1,"",0);
	my $failure_s = "failure";
	if ($failures ne 1) {$failure_s .= "s"}
	if ($failures eq "") {$failures = 0}
	if ($input{argument}) {
		my $message = "From: root\n";
		$message .= "To: root\n";
		$message .= "Subject: RBL Check on [hostname]: [$failures] $failure_s\n";
		$message .= "MIME-Version: 1.0\n";
		$message .= "Content-Type: text/html\n";
		$message .= "\n";
		$message .= $output;
		my @message = split(/\n/,$message);
		ConfigServer::Sendmail::relay($input{argument}, "", @message);
	} else {
		print $output;
		print "\n";
	}
	return;
}
# end dorbls
###############################################################################
# start doprofile
sub doprofile {
	my $cmd = $ARGV[1];
	my $profile1 = $ARGV[2];
	my $profile2 = $ARGV[3];
	my $stamp = time;

	$profile1 =~ s/\W/_/g;
	$profile2 =~ s/\W/_/g;

	if ($cmd eq "list") {
		my @profiles = sort glob("/usr/local/csf/profiles/*");
		my @backups = reverse glob("/var/lib/csf/backup/*");
		print "\n";
		print "Configuration Profiles\n";
		print "======================\n";
		foreach my $profile (@profiles) {
			my ($file, undef) = fileparse($profile);
			$file =~ s/\.conf$//;
			print "$file\n";
		}
		print "\n";

		print "Configuration Backups\n";
		print "=====================\n";
		foreach my $backup (@backups) {
			my ($file, undef) = fileparse($backup);
			my ($stamp,undef) = split(/_/,$file);
			print $file." (".localtime($stamp).")\n";
		}
		print "\n";
	}
	elsif ($cmd eq "backup") {
		unless ($profile1) {$profile1 = "backup"}
		print "Creating backup...\n";
		system("/bin/cp","-avf","/etc/csf/csf.conf","/var/lib/csf/backup/${stamp}_${profile1}");
	}
	elsif ($cmd eq "restore") {
		if (-e "/var/lib/csf/backup/$profile1") {
			print "Restoring backup...\n";
			system("/bin/cp","-avf","/var/lib/csf/backup/${profile1}","/etc/csf/csf.conf");
			print "You should now restart csf and then lfd\n";
		} else {
			print "File [$profile1] not found in /var/lib/csf/backup/\n";
		}
	}
	elsif ($cmd eq "apply") {
		if (-e "/usr/local/csf/profiles/${profile1}.conf") {
			my %apply;
			print "Creating backup...\n";
			system("/bin/cp","-avf","/etc/csf/csf.conf","/var/lib/csf/backup/${stamp}_pre_${profile1}");
			print "Applying profile...\n";
			open (my $IN, "<", "/usr/local/csf/profiles/${profile1}.conf") or die $!;
			flock ($IN, LOCK_SH) or die $!;
			my @applyconfig = <$IN>;
			close ($IN);
			chomp @applyconfig;
			foreach my $line (@applyconfig) {
				if ($line =~ /^\#/) {next}
				if ($line !~ /=/) {next}
				my ($name,$value) = split (/=/,$line,2);
				$name =~ s/\s//g;
				if ($value =~ /\"(.*)\"/) {$value = $1}
				$apply{$name} = $value;
			}

			sysopen (my $CONF, "/etc/csf/csf.conf", O_RDWR | O_CREAT) or die "Unable to open file: $!";
			flock ($CONF, LOCK_SH);
			my @confdata = <$CONF>;
			close ($CONF);
			chomp @confdata;

			sysopen (my $OUT, "/etc/csf/csf.conf", O_WRONLY | O_CREAT) or die "Unable to open file: $!";
			flock ($OUT, LOCK_EX);
			seek ($OUT, 0, 0);
			truncate ($OUT, 0);
			for (my $x = 0; $x < @confdata;$x++) {
				if (($confdata[$x] !~ /^\#/) and ($confdata[$x] =~ /=/)) {
					my ($name,$value) = split (/=/,$confdata[$x],2);
					$name =~ s/\s//g;
					if ($value =~ /\"(.*)\"/) {$value = $1}
					if (defined $apply{$name} and ($apply{$name} ne $value)) {$value = $apply{$name}}
					print $OUT "$name = \"$value\"\n";
				} else {
					print $OUT "$confdata[$x]\n";
				}
			}
			close ($OUT);

			print "[$profile1] has been applied. You should now restart csf and then lfd\n";
		} else {
			print "[$profile1] is not a valid profile\n";
		}
	}
	elsif ($cmd eq "keep") {
		if ($profile1 =~ /^\d+$/) {
			my @backups = reverse glob("/var/lib/csf/backup/*");
			for ($profile1..(@backups -1)) {
				system("/bin/rm","-fv",$backups[$_]);
			}
		} else {
			print "You must specify the number of backups to keep\n";
		}
	} 
	elsif ($cmd eq "diff") {
		my $firstfile = "/var/lib/csf/backup/$profile1";
		my $secondfile = "/var/lib/csf/backup/$profile2";
		if (-e "/usr/local/csf/profiles/${profile1}.conf") {
			$firstfile = "/usr/local/csf/profiles/${profile1}.conf";
		}
		if (-e "/usr/local/csf/profiles/${profile2}.conf") {
			$secondfile = "/usr/local/csf/profiles/${profile2}.conf";
		}
		if (-e $firstfile) {
			if (-e $secondfile or $profile2 eq "" or $profile2 eq "current") {
				my %config1;
				open (my $IN, "<",$firstfile) or die $!;
				flock ($IN, LOCK_SH) or die $!;
				my @configdata = <$IN>;
				close ($IN);
				chomp @configdata;
				foreach my $line (@configdata) {
					if ($line =~ /^\#/) {next}
					if ($line !~ /=/) {next}
					my ($name,$value) = split (/=/,$line,2);
					$name =~ s/\s//g;
					if ($value =~ /\"(.*)\"/) {$value = $1}
					$config1{$name} = $value;
				}

				my $PROFILE;
				if ($profile2 eq "" or $profile2 eq "current") {
					$profile2 = "current";
					open ($PROFILE, "<", "/etc/csf/csf.conf") or die $!;
				} else {
					open ($PROFILE, "<", $secondfile) or die $!;
				}
				flock ($PROFILE, LOCK_SH) or die $!;
				@configdata = sort <$PROFILE>;
				close ($PROFILE);
				chomp @configdata;

				print "[SETTING]\t[$profile1]\t[$profile2]\n\n";
				foreach my $line (@configdata) {
					if ($line =~ /^\#/) {next}
					if ($line !~ /=/) {next}
					my ($name,$value) = split (/=/,$line,2);
					$name =~ s/\s//g;
					if ($value =~ /\"(.*)\"/) {$value = $1}
					if (defined $config1{$name} and ($config1{$name} ne $value)) {
						print "[$name]\t[$config1{$name}]\t[$value]\n";
					}
				}
			} else {
				print "File [$profile2] not found in /var/lib/csf/backup/\n";
			}
		} else {
			print "File [$profile1] not found in /var/lib/csf/backup/\n";
		}
	} 
	else {
		print "Incorrect syntax for command\n";
	}
	return;
}

# #
#	Ports › Add
#	
#	Allows a user to add a port using a console command, instead of editing the config.
#	
#	@syntax			--addport <protocol>:<port>
#	@usage			--addport TCP_IN:9985
# #

sub portAdd
{
    # Get args
    my $arg = $input{argument} // '';

	# #
	#	Expect format: PROTOCOL:PORT
	#	
	#	Accepted Formats:
	#		<protocol>:<port>
	#		<protocol>=<port>
	#	
	#	Example
	#		TCP_IN:2525
	# #

    unless ( $arg =~ /^(\w+)[:=](\d+)$/ )
    {
		log_label( "" );
		log_fail( "Invalid format provided. Command requires format ${yellowl}<protocol>:<port>${greym}" );
		log_info( "Usage: csf --addport <protocol>:<port>" );
		log_label( "       ${fuchsial}csf ${bluel}--addport ${navy}[ ${yellowl}TCP_IN ${navy}|${yellowl} TCP_OUT ${navy}|${yellowl} UDP_IN ${navy}|${yellowl} UDP_OUT${navy} ]${greym}:${greenl}PORT" );
		log_label( "       ${fuchsial}csf ${bluel}--addport ${yellowl}TCP_IN${greym}:${greenl}8080" );
		log_label( "       ${fuchsial}csf ${bluel}--addport ${yellowl}UDP_IN${greym}:${greenl}5353" );
		log_label( "" );
		
        return;
    }

    my ($protocol, $port) 	= ($1, $2);
    my $conf_file 			= '/etc/csf/csf.conf';

	# #
	#	Read csf.conf
	# #

	open my $fh, '<', $conf_file or do
	{
		log_error( "Cannot open ${redl}$conf_file${greym} - returned error: ${redl}$${greym}!" );
		return;
	};
	my @lines = <$fh>;
	close $fh;

    my $found = 0;
    for my $line ( @lines )
    {
        if ($line =~ /^$protocol\s*=\s*"(.*?)"/)
        {
            my $ports = $1;

            # #
			#	Add port if not already exists in csf.conf
			# #

            if ( $ports !~ /\b\Q$port\E\b/ )
            {
                $ports .= ",$port";
                $line = "$protocol = \"$ports\"\n";

				log_label( "" );
				log_pass( "Successfully added port ${greenl}${protocol}:${port}${greym} in ${greenl}${conf_file}${greym}" );
				log_label( "" );
            }
            else
            {
				log_label( "" );
				log_warn( "Port ${yellowl}${protocol}:${port}${greym} already ${greenl}allowed${greym} in ${yellowl}${conf_file}${greym}" );
				log_label( "" );
            }

            $found = 1;
            last;
        }
    }

	# #
	#	Specified incorrect protocol
	#		› TCP_IN
	#		› TCP_OUT
	#		› UDP_IN
	#		› UDP_OUT
	# #

    unless ( $found )
    {
		log_label ( "" );
		log_fail( "Protocol ${redl}${protocol}${greym} not found in ${redl}${conf_file}" );
		log_label( "       ${bluel}Options: ${yellowl}TCP_IN${navy},${yellowl} TCP_OUT${navy},${yellowl} UDP_IN${navy},${yellowl} UDP_OUT${greym}" );
		log_label ( "" );
		log_info( "Usage: csf --addport <protocol>:<port>" );
		log_label( "       ${fuchsial}csf ${bluel}--addport ${navy}[ ${yellowl}TCP_IN ${navy}|${yellowl} TCP_OUT ${navy}|${yellowl} UDP_IN ${navy}|${yellowl} UDP_OUT${navy} ]${greym}:${greenl}PORT" );
		log_label( "       ${fuchsial}csf ${bluel}--addport ${yellowl}TCP_IN${greym}:${greenl}8080" );
		log_label( "       ${fuchsial}csf ${bluel}--addport ${yellowl}UDP_IN${greym}:${greenl}5353" );
		log_label ( "" );

        return;
    }

	# #
	#	Output / write changes
	# #

    open my $fh_out, '>', $conf_file or die "Cannot write $conf_file: $!";
    print $fh_out @lines;
    close $fh_out;
}

# #
#   Ports › Remove
#	
#   Allows a user to remove a port using a console command, 
#   instead of editing the config.
#	
#   @syntax         --removeport <protocol>:<port>
#   @usage          --removeport TCP_IN:9985
# #

sub portRemove
{
    my $arg = $input{argument} // '';

	# #
	#	Expect format: PROTOCOL:PORT
	#	
	#	Accepted Formats:
	#		<protocol>:<port>
	#		<protocol>=<port>
	#	
	#	Example
	#		TCP_IN:2525
	# #

    unless ( $arg =~ /^(\w+)[:=](\d+)$/ )
    {
        log_label( "" );
		log_fail( "Invalid format provided. Command requires format ${yellowl}<protocol>:<port>${greym}" );
        log_info( "Usage: csf --removeport <protocol>:<port>" );
        log_label( "       ${fuchsial}csf ${bluel}--removeport ${navy}[ ${yellowl}TCP_IN ${navy}|${yellowl} TCP_OUT ${navy}|${yellowl} UDP_IN ${navy}|${yellowl} UDP_OUT${navy} ]${greym}:${greenl}PORT" );
        log_label( "       ${fuchsial}csf ${bluel}--removeport ${yellowl}TCP_IN${greym}:${greenl}8080" );
        log_label( "       ${fuchsial}csf ${bluel}--removeport ${yellowl}UDP_IN${greym}:${greenl}5353" );
        log_label( "" );

        return;
    }

    my ($protocol, $port) 	= ($1, $2);
    my $conf_file 			= '/etc/csf/csf.conf';

	# #
	#	Read csf.conf
	# #

	open my $fh, '<', $conf_file or do
	{
		log_error( "Cannot open ${redl}$conf_file${greym} - returned error: ${redl}$${greym}!" );
		return;
	};
	my @lines = <$fh>;
	close $fh;

    my $found_protocol 		= 0;
    my $found_port     		= 0;

    for my $line ( @lines )
    {
        if ( $line =~ /^$protocol\s*=\s*"(.*?)"/ )
        {
            $found_protocol = 1;
            my $ports 		= $1;

            # Split list into array
            my @plist = split /\s*,\s*/, $ports;

            # Check if port exists
            unless ( grep { $_ eq $port } @plist )
            {
                log_warn( "Port ${yellowl}${protocol}:${port}${greym} is already ${redl}BLOCKED${greym} and not added in ${yellowl}${conf_file}${greym}" );
                last;
            }

            # Remove port
            @plist = grep { $_ ne $port } @plist;

            # Rebuild port list
            my $new_ports 	= join(",", @plist);
            $line 			= "$protocol = \"$new_ports\"\n";
            $found_port 	= 1;

			log_label( "" );
            log_pass( "Successfully removed port ${greenl}${protocol}:${port}${greym} from ${greenl}${conf_file}${greym}" );
			log_label( "" );

            last;
        }
    }

	# #
	#	Specified incorrect protocol
	#		› TCP_IN
	#		› TCP_OUT
	#		› UDP_IN
	#		› UDP_OUT
	# #

    unless ( $found_protocol )
    {
        log_label( "" );
        log_fail( "Protocol ${redl}${protocol}${greym} not found in ${redl}${conf_file}" );
        log_label( "       ${bluel}Options: ${yellowl}TCP_IN${navy},${yellowl} TCP_OUT${navy},${yellowl} UDP_IN${navy},${yellowl} UDP_OUT${greym}" );
        log_label( "" );

        return;
    }

	# #
	#	Output / write changes
	# #

    open my $fh_out, '>', $conf_file or die "Cannot write $conf_file: $!";
    print $fh_out @lines;
    close $fh_out;
}

# #
#   Ports › List
#	
#   Lists all ports assigned to each protocol in csf.conf
#	
#   @syntax         --listports
#   @usage          csf --listports
# #

sub portsList
{
    my $conf_file = '/etc/csf/csf.conf';

	# #
	#	Read csf.conf
	# #

	open my $fh, '<', $conf_file or do
	{
		log_error( "Cannot open ${redl}$conf_file${greym} - returned error: ${redl}$${greym}!" );
		return;
	};
	my @lines = <$fh>;
	close $fh;

    log_label( "" );
    log_info( "Configured CSF Ports:" );
	log_label( "The following are a list of the whitelisted ports configured in your ${yellowd}${conf_file}${greym}" );
    log_label( "" );

	# #
	#	Loop port protocols
	# #

    for my $protocol (qw(TCP_IN TCP_OUT UDP_IN UDP_OUT)) 
    {
        my ($line) = grep { /^$protocol\s*=/ } @lines;

        if ($line) 
        {
            # Extract port list
            my ($ports) = $line =~ /^$protocol\s*=\s*"(.*?)"/;
            $ports //= "";

            # Clean whitespace and display
            $ports =~ s/\s+//g;

            log_label( "${bluel}$protocol${greym}: ${yellowl}$ports${greym}" );
        }
        else
        {
            log_label( "${bluel}$protocol${greym}: ${redl}Not found${greym}" );
        }
    }

    log_label( "" );
}

# end doprofile
###############################################################################
# start doports
sub doports
{
	my ($fport,$fopen,$fconn,$fpid,$fexe,$fcmd);
	format PORTS =
@<<<<<<<<< @<<< @<<<< @<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<... @*
$fport,    $fopen,$fconn,$fpid,            $fcmd,                                  $fexe
.
	local $~ = "PORTS";

	print "Ports listening for external connections and the executables running behind them:\n";
	print "Port/Proto Open Conn  PID/User             Command Line                            Executable\n";
	my %listen = ConfigServer::Ports->listening;
	my %ports = ConfigServer::Ports->openports;
	foreach my $protocol (sort keys %listen) {
		foreach my $port (sort {$a <=> $b} keys %{$listen{$protocol}}) {
			foreach my $pid (sort {$a <=> $b} keys %{$listen{$protocol}{$port}}) {
				$fport = "$port/$protocol";
				if ($ports{$protocol}{$port}) {$fopen = "4"} else {$fopen = "-"}
				if ($config{IPV6} and $ports{$protocol."6"}{$port}) {$fopen .= "/6"} else {$fopen .= "/-"}
				$fpid = "($pid/".$listen{$protocol}{$port}{$pid}{user}.")";
				$fexe = $listen{$protocol}{$port}{$pid}{exe};
				$fcmd = $listen{$protocol}{$port}{$pid}{cmd};
				$fconn = $listen{$protocol}{$port}{$pid}{conn};
				write;
			}
		}
	}
	return;
}

# #
#	Insiders Program / Sponsor
#	
#	Returns the status of the end-users Sponsorship status and if they are
#	subscribed to the insider's release channel.
# #

sub doinsiders
{
    print "\n  Checking CSF sponsorship and Insiders access\n";

    my $license = $config{SPONSOR_LICENSE} // '';
    my ($license_status, $insiders_status, $message) = ( 'Invalid', 'Disabled', '' );

    # #
    #    Check if license key is empty
    # #

    if ( $license eq '' )
    {
        $message = 'License key not specified in /etc/csf/csf.conf';
    }
    else
    {
        print "  Connecting to license server ...\n";

        # #
        #    Query license server
        # #

        my ($status, $resp) = $urlget->urlget("https://license.configserver.dev/?license=$license");

        # #
        #    Handle URL fetch error
        # #

        if ( $status )
        {
            $message = "An error occurred checking for sponsorship status: $resp";
        }
        else
        {
            # #
            #    Check JSON manually
            # #
		
            my $valid = ( $resp =~ /"message"\s*:\s*{.*?"valid"\s*:\s*true/s ) ? 1 : 0;
            $license_status = $valid ? 'Valid' : 'Invalid';
            $insiders_status = ( $valid && ( $config{SPONSOR_RELEASE_INSIDERS} // '' ) eq '1' ) ? 'Enabled' : 'Disabled';

            # #
            #    Extract error message if invalid
            # #
		
			if ( $resp =~ /"message"\s*:\s*{.*?"response"\s*:\s*"([^"]+)"/s )
			{
				$message = $1;
			}
	
            $message ||= $valid ? 'Success' : 'License key is empty or invalid';
        }
    }

    # #
    #    Print status at the end
    # #
    print "\n";
    print "      Status ..................... " . ( $license_status eq 'Valid' ? 'OK' : 'Failed' ) . "\n";
    print "      Sponsorship License ........ $license_status\n";
    print "      Insiders Channel ........... $insiders_status\n";
    print "      Message .................... " . ( $message || '-' ) . "\n";
    print "\n";

    return;
}

# start domessengerv2
sub domessengerv2
{
	print "csf - MESSENGERV2 /etc/apache2/conf.d/csf_messenger.conf regeneration:\n\n";
	ConfigServer::Messenger::messengerv2();
	print "\n...Done.\n";
	return;
}
# end domessengerv2
###############################################################################
# start docloudflare
sub docloudflare {
	my $cmd = $ARGV[1];
	my $setting = $ARGV[2];
	my $value = $ARGV[3];
	my $valuemore = $ARGV[4];
	my $valuelist;
	my $valuemorelist;
	foreach my $i (3..$#ARGV) {$valuelist .= $ARGV[$i]}
	foreach my $i (4..$#ARGV) {$valuemorelist .= $ARGV[$i]}

	unless ($config{CF_ENABLE}) {
		print "csf - CF_ENABLE must be enabled and CloudFlare access details configured to use these commands\n";
		exit 1;
	}

	if ($cmd eq "list") {
		my %modes;
		unless ($setting eq "all" or $setting eq "block" or $setting eq "challenge" or $setting eq "whitelist") {
			print "Invalid list type, must be: [block], [challenge], [whitelist] or [all]\n";
			exit 1;
		}
		my ($ip,$domain, $mode,$date,$comment);
		format CLOUDFLARE =
@<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<< @<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<< @*
$ip,             $domain,             $mode,     $date,                    $comment
.
		local $~ = "CLOUDFLARE";

		print "Target           Local User           Mode       Date                      Notes\n";
		print "======           ==========           ====       ====                      =====\n";
		my @domains = ConfigServer::CloudFlare::action("getlist","","","",$valuelist);
		foreach my $domainkey (@domains) {
			foreach my $key (sort {$domainkey->{$a}{created_on} <=> $domainkey->{$b}{created_on}} keys %{$domainkey}) {
				if ($domainkey->{$key}{success}) {
					if ($setting eq "all" or $domainkey->{$key}{mode} eq $setting) {
						$ip = $key;
						$date = localtime($domainkey->{$key}{created_on});
						$comment = $domainkey->{$key}{notes};
						$domain = $domainkey->{$key}{domain};
						$mode = $domainkey->{$key}{mode};
						write;
					}
				} else {
					print $domainkey->{$key}{domain}."\n";
				}
			}
		}
	}
	elsif ($cmd eq "add") {
		my $mode;
		if ($setting eq "block") {$mode = "block"}
		elsif ($setting eq "challenge") {$mode = "challenge"}
		elsif ($setting eq "whitelist") {$mode = "whitelist"}
		else {
			print "Invalid add type, must be: [block], [challenge] or [whitelist]\n";
			exit 1;
		}
		my $status = ConfigServer::CloudFlare::action("add",$value,$mode,"",$valuemorelist);
	}
	elsif ($cmd eq "del") {
		my $status = ConfigServer::CloudFlare::action("del",$setting,"whitelist","",$valuelist);
	}
	elsif ($cmd eq "tempadd") {
		my $mode;
		if ($setting eq "deny") {$mode = "block"}
		elsif ($setting eq "allow") {$mode = "whitelist"}
		else {
			print "Invalid tempadd type, must be: [deny], or [allow]\n";
			exit 1;
		}
		$input{argument} = "$value $config{CF_TEMP}";
		if ($setting eq "deny") {
			my $status = ConfigServer::CloudFlare::action("deny",$value,$mode,"",$valuemorelist,1);
			&dotempdeny("cf");
		}
		elsif ($setting eq "allow") {
			my $status = ConfigServer::CloudFlare::action("allow",$value,$mode,"",$valuemorelist,1);
			&dotempallow("cf");
		}
	}
	else {
		print "Invalid command, must be: [list], [remove], [add], or [tempadd]\n";
		exit 1;
	}

	return;
}
# end docloudflare
###############################################################################
# start dographs
sub dographs {
	my ($type, $dir) = split(/\s/,$input{argument});
	my %types = ("load" => 1,
				 "cpu" => 1,
				 "mem" => 1,
				 "net" => 1,
				 "disk" => 1,
				 "diskw" => 1,
				 "email" => 1,
				 "temp" => 1,
				 "mysqldata" => 1,
				 "mysqlqueries" => 1,
				 "mysqlslowqueries" => 1,
				 "mysqlconns" => 1,
				 "apachecpu" => 1,
				 "apacheconn" => 1,
				 "apachework" => 1);
	if ($dir !~ /\/$/) {$dir .= "/"}
	
	unless ($config{ST_ENABLE}) {
		print "ST_ENABLE is disabled\n";
		exit 1;
	}
	unless ($config{ST_SYSTEM}) {
		print "ST_SYSTEM is disabled\n";
		exit 1;
	}
	if (!defined ConfigServer::ServerStats::init()) {
		print "Perl module GD::Graph is not installed/working\n";
		exit 1;
	}

	if ($type eq "" and $dir eq "") {
		print "Valid graph types:\n";
		foreach my $key (keys %types) {print "$key "}
		print "\n";
		print "Usage: csf [graph type] [directory]\n";
		exit 1;
	}

	if ($type eq "" or !$types{$type}) {
		print "Invalid graph type. Choose one of:\n";
		foreach my $key (keys %types) {print "$key "}
		print "\n";
		print "Usage: csf [graph type] [directory]\n";
		exit 1;
	}
	if ($dir eq "" or !(-d $dir)) {
		print "You must specify a valid directory in which to create the graphs and html pages\n";
		print "Usage: csf [graph type] [directory]\n";
		exit 1;
	}

	print "Creating html pages and images...\n";

	ConfigServer::ServerStats::charts($config{CC_LOOKUPS},$dir);
	open (my $CHARTS, ">", $dir."/charts.html");
	flock ($CHARTS, LOCK_EX);
	print $CHARTS ConfigServer::ServerStats::charts_html($config{CC_LOOKUPS},"");
	close ($CHARTS);

	ConfigServer::ServerStats::graphs($type,$config{ST_SYSTEM_MAXDAYS},$dir);
	open (my $GRAPHS, ">", $dir."/graphs.html");
	flock ($GRAPHS, LOCK_EX);
	print $GRAPHS ConfigServer::ServerStats::graphs_html("");
	close ($GRAPHS);

	print "Created charts.html, graphs.html and their images in $dir\n";
	return;
}
# end dographs
###############################################################################
# start loadmodule
sub loadmodule {
	my $module = shift;
	my @output;

	eval {
		local $SIG{__DIE__} = undef;
		local $SIG{'ALRM'} = sub {die};
		alarm(5);
		my ($childin, $childout);
		my $pid = open3($childin, $childout, $childout, $config{MODPROBE},$module);
		@output = <$childout>;
		waitpid ($pid, 0);
		alarm(0);
	};
	alarm(0);

	return @output;
}
# end loadmodule
###############################################################################
# start syscommand
sub syscommand
{
	my $line 			= shift;
	my $command 		= shift;
	my $force 			= shift;
	my $status 			= 0;
	my $iptableslock 	= 0;

	if ($command =~ /^($config{IPTABLES}|$config{IP6TABLES})/)
	{
		$iptableslock = 1
	}

	if ($faststart)
	{
		if ($command =~ /^$config{IPTABLES}\s+(.*)$/)
		{
			my $fastcmd = $1;
			$fastcmd =~ s/-v//;
			$fastcmd =~ s/--wait//;
			if ($fastcmd =~ /-t\s+nat/)
			{
				$fastcmd =~ s/-t\s+nat//;
				push @faststart4nat,$fastcmd;
			}
			else
			{
				push @faststart4,$fastcmd;
			}
		}

		if ($command =~ /^$config{IP6TABLES}\s+(.*)$/)
		{
			my $fastcmd = $1;
			$fastcmd =~ s/-v//;
			$fastcmd =~ s/--wait//;
	
			if ($fastcmd =~ /-t\s+nat/)
			{
				$fastcmd =~ s/-t\s+nat//;
				push @faststart6nat,$fastcmd;
			}
			else
			{
				push @faststart6,$fastcmd;
			}
		}
		return;
	}

	if ($config{VPS})
	{
		$status = &checkvps
	}

	if ($status)
	{
		&error($line,$status);
	}
	else
	{
		if ($config{DEBUG} >= 1)
		{
			print "debug[$line]: Command:$command\n";
		}

		if ($iptableslock) {&iptableslock("lock")}
		my @output;

		if ($iptableslock and $config{WAITLOCK})
		{
			eval
			{
				local $SIG{__DIE__} = undef;
				local $SIG{'ALRM'} = sub {die "alarm\n"};
				alarm($config{WAITLOCK_TIMEOUT});
				my ($childin, $childout);
				my $cmdpid = open3($childin, $childout, $childout, $command);
				@output = <$childout>;
				waitpid ($cmdpid, 0);
				alarm(0);
			};

			alarm(0);
			if ($@ eq "alarm\n")
			{
				&error(__LINE__,"*Error* timeout after iptables --wait for $config{WAITLOCK_TIMEOUT} seconds - WAITLOCK");
			}
		}
		else
		{
			my ($childin, $childout);
			my $cmdpid = open3($childin, $childout, $childout, $command);
			@output = <$childout>;
			waitpid ($cmdpid, 0);
		}

		if ($iptableslock)
		{
			&iptableslock("unlock")
		}

		chomp @output;
		if ($output[0] =~ /# Warning: iptables-legacy tables present/)
		{
			shift @output
		}
	
		foreach my $line (@output)
		{
			if ($line =~ /^Using intrapositioned negation/) {next}
			log_label( "$line" );
		}

		if ($output[0] =~ /(^iptables: Unknown error 4294967295)|(xtables lock)/ and !$config{WAITLOCK})
		{
			my $cnt = 0;
			my $repeat = 6;
			while ($cnt < $repeat)
			{
				sleep 1;
				if ($config{DEBUG} >= 1) {print "debug[$line]: Retry (".($cnt+1).") [$command] due to [$output[0]]"}
				if ($iptableslock) {&iptableslock("lock")}
				my ($childin, $childout);
				my $cmdpid = open3($childin, $childout, $childout, $command);
				my @output = <$childout>;
				waitpid ($cmdpid, 0);
				if ($iptableslock) {&iptableslock("unlock")}
				chomp @output;
				if ($output[0] =~ /# Warning: iptables-legacy tables present/) {shift @output}
				$cnt++;
				if ($output[0] =~ /(^iptables: Unknown error 4294967295)|(xtables lock)/ and $cnt == $repeat) {&error($line,"Error processing command for line [$line] ($repeat times): [$output[0]]");}
				unless ($output[0] =~ /(^iptables: Unknown error 4294967295)|(xtables lock)/) {$cnt = $repeat}
			}
		}

		if ($output[0] =~ /^(iptables|xtables|Bad|Another)/ and ($config{TESTING} or $force))
		{
			if ($output[0] =~ /iptables: No chain\/target\/match by that name/)
			{
				&error($line,"iptables command [$command] failed, you appear to be missing a required iptables module")
			}
			else
			{
				&error($line,"iptables command [$command] failed");
			}
		}

		if ($output[0] =~ /^(ip6tables|Bad|Another)/ and ($config{TESTING} or $force))
		{
			if ($output[0] =~ /ip6tables: No chain\/target\/match by that name/)
			{
				&error($line,"ip6tables command [$command] failed, you appear to be missing a required ip6tables module")
			}
			else
			{
				&error($line,"ip6tables command [$command] failed");
			}
		}

		if ($output[0] =~ /xtables lock/)
		{
			$warning .= "iptables command [$command] failed due to xtables lock, enable WAITLOCK in csf.conf\n\n";
		}

		if ($output[0] =~ /^(iptables|xtables|ip6tables|Bad|Another)/)
		{
			$warning .= "*ERROR* line:[$line]\nCommand:[$command]\nError:[$output[0]]\nYou should check through the main output carefully\n\n";
		}
	}
	return;
}

# end syscommand
###############################################################################
# start iptableslock
sub iptableslock {
	my $lock = shift;
	my $iptablesx = shift;
	if ($lock eq "lock") {
		sysopen ($IPTABLESLOCK, "/var/lib/csf/lock/command.lock", O_RDWR | O_CREAT);
		flock ($IPTABLESLOCK, LOCK_EX);
		autoflush $IPTABLESLOCK 1;
		seek ($IPTABLESLOCK, 0, 0);
		truncate ($IPTABLESLOCK, 0);
		print $IPTABLESLOCK $$;
	} else {
		close ($IPTABLESLOCK);
	}
	return;
}
# end iptableslock
###############################################################################
# start checkvps
sub checkvps {
	if (-e "/proc/user_beancounters" and !(-e "/proc/vz/version")) {
		open (my $INVPS, "<", "/proc/user_beancounters");
		flock ($INVPS, LOCK_SH);
		my @data = <$INVPS>;
		close ($INVPS);
		chomp @data;

		foreach my $line (@data) {
			if ($line =~ /^\s*numiptent\s+(\d*)\s+(\d*)\s+(\d*)\s+(\d*)/) {
				if ($1 > $4 - 10) {return "The VPS iptables rule limit (numiptent) is too low ($1/$4) - stopping firewall to prevent iptables blocking all connections"}
			}
		}
	}
	return 0;
}
# end checkvps
###############################################################################
# start modprobe
sub modprobe {
	if (-e $config{MODPROBE}) {
		my @modules = ("ip_tables","ipt_multiport","iptable_filter","ipt_limit","ipt_LOG","ipt_REJECT","ipt_conntrack","ip_conntrack","ip_conntrack_ftp","iptable_mangle","ipt_REDIRECT","iptable_nat");

		unless (&loadmodule("xt_multiport")) {
			@modules = ("ip_tables","xt_multiport","iptable_filter","xt_limit","ipt_LOG","ipt_REJECT","ip_conntrack_ftp","iptable_mangle","xt_conntrack","ipt_REDIRECT","iptable_nat","nf_conntrack_ftp","nf_nat_ftp");
		}

		if ($config{SMTP_BLOCK}) {
			push @modules,"ipt_owner";
			push @modules,"xt_owner";
		}
		if ($config{PORTFLOOD} or $config{PORTFLOOD6} or $config{PORTKNOCKING}) {
			push @modules,"ipt_recent ip_list_tot=1000 ip_list_hash_size=0";
		}
		if ($config{CONNLIMIT}) {
			push @modules,"xt_connlimit";
		}

		foreach my $module (@modules) {&loadmodule($module)}
	}
	return;
}
# end modprobe
###############################################################################
# start faststart
sub faststart
{
	my $text = shift;

	# #
	#	Module › IPV4
	# #

	if ( @faststart4 )
	{
		if ( $verbose )
		{
			log_info( "FASTSTART loading (IPv4) ${bluel}${text}${greym}" );
		}

		my $status;
		if ($config{VPS}) {$status = &fastvps(scalar @faststart4)}
		if ($status) {&error(__LINE__,$status)}
		if ($config{DEBUG} >= 2) {print join("\n",@faststart4)."\n"};
		&iptableslock("lock");
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "$config{IPTABLES_RESTORE} $config{IPTABLESWAIT} -n");
		print $childin "*filter\n".join("\n",@faststart4)."\nCOMMIT\n";
		close $childin;
		my @results = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @results;
		if ($results[0] =~ /# Warning: iptables-legacy tables present/) {shift @results}
		if ($results[0] =~ /^(iptables|ip6tables|xtables|Bad|Another)/) {
			my $cmd;
			if ($results[1] =~ /^Error occurred at line: (\d+)$/) {$cmd = $faststart4[$1 - 1]}
			&error(__LINE__,"FASTSTART: ($text IPv4) [$cmd] [$results[0]]. Try restarting csf with FASTSTART disabled");
		}
		&iptableslock("unlock",1);
	}

	# #
	#	Module › IPV4 › NAT
	# #

	if (@faststart4nat)
	{
		if ($verbose)
		{
			log_info( "FASTSTART loading (IPv4-NAT) ${bluel}${text}${greym}" );
		}

		my $status;
		if ($config{VPS}) {$status = &fastvps(scalar @faststart4nat)}
		if ($status) {&error(__LINE__,$status)}
		if ($config{DEBUG} >= 2) {print join("\n",@faststart4nat)."\n"};
		&iptableslock("lock");
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "$config{IPTABLES_RESTORE} $config{IPTABLESWAIT} -n");
		print $childin "*nat\n".join("\n",@faststart4nat)."\nCOMMIT\n";
		close $childin;
		my @results = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @results;
		if ($results[0] =~ /# Warning: iptables-legacy tables present/) {shift @results}
		if ($results[0] =~ /^(iptables|ip6tables|xtables|Bad|Another)/) {
			my $cmd;
			if ($results[1] =~ /^Error occurred at line: (\d+)$/) {$cmd = $faststart4[$1 - 1]}
			&error(__LINE__,"FASTSTART: ($text IPv4nat) [$cmd] [$results[0]]. Try restarting csf with FASTSTART disabled");
		}
		&iptableslock("unlock",1);
	}

	# #
	#	Module › IPV6
	# #

	if (@faststart6 and $config{IPV6})
	{
		if ($verbose)
		{
			log_info( "FASTSTART loading (IPv6) ${bluel}${text}${greym}" );
		}
	
		my $status;
		if ($config{VPS}) {$status = &fastvps(scalar @faststart6)}
		if ($status) {&error(__LINE__,$status)}
		if ($config{DEBUG} >= 2) {print join("\n",@faststart6)."\n"};
		&iptableslock("lock");
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "$config{IP6TABLES_RESTORE} $config{IPTABLESWAIT} -n");
		print $childin "*filter\n".join("\n",@faststart6)."\nCOMMIT\n";
		close $childin;
		my @results = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @results;
		if ($results[0] =~ /# Warning: iptables-legacy tables present/) {shift @results}
		if ($results[0] =~ /^(iptables|ip6tables|xtables|Bad|Another)/) {
			my $cmd;
			if ($results[1] =~ /^Error occurred at line: (\d+)$/) {$cmd = $faststart4[$1 - 1]}
			&error(__LINE__,"FASTSTART: ($text IPv6) [$cmd] [$results[0]]. Try restarting csf with FASTSTART disabled");
		}
		&iptableslock("unlock",1);
	}

	# #
	#	Module › IPV6 › NAT
	# #

	if (@faststart6nat and $config{IPV6})
	{
		if ($verbose)
		{
			log_info( "FASTSTART loading (IPv6-NAT) ${bluel}${text}${greym}" );
		}
	
		my $status;
		if ($config{VPS}) {$status = &fastvps(scalar @faststart6nat)}
		if ($status) {&error(__LINE__,$status)}
		if ($config{DEBUG} >= 2) {print join("\n",@faststart6nat)."\n"};
		&iptableslock("lock");
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "$config{IP6TABLES_RESTORE} $config{IPTABLESWAIT} -n");
		print $childin "*nat\n".join("\n",@faststart6nat)."\nCOMMIT\n";
		close $childin;
		my @results = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @results;
		if ($results[0] =~ /# Warning: iptables-legacy tables present/) {shift @results}
		if ($results[0] =~ /^(iptables|ip6tables|xtables|Bad|Another)/) {
			my $cmd;
			if ($results[1] =~ /^Error occurred at line: (\d+)$/) {$cmd = $faststart6[$1 - 1]}
			&error(__LINE__,"FASTSTART: ($text IPv6nat) [$cmd] [$results[0]]. Try restarting csf with FASTSTART disabled");
		}
		&iptableslock("unlock",1);
	}

	# #
	#	Module › IPSET
	# #

	if (@faststartipset)
	{
		if ($verbose)
		{
			log_info( "FASTSTART loading (IPSET) ${bluel}${text}${greym}" );
		}
	
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"restore");
		print $childin join("\n",@faststartipset)."\n";
		close $childin;
		my @results = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @results;
		if ($results[0] =~ /^ipset/) {
			print "FASTSTART: (IPSET) Error:[$results[0]]. Try restarting csf with FASTSTART disabled";
		}
	}
	undef @faststart4;
	undef @faststart4nat;
	undef @faststart6;
	undef @faststart6nat;
	undef @faststartipset;
	$faststart = 0;
	return;
}
# end faststart
###############################################################################
# start fastvps
sub fastvps {
	my $size = shift;
	if (-e "/proc/user_beancounters" and !(-e "/proc/vz/version")) {
		open (my $INVPS, "<", "/proc/user_beancounters");
		flock ($INVPS, LOCK_SH);
		my @data = <$INVPS>;
		close ($INVPS);
		chomp @data;

		foreach my $line (@data) {
			if ($line =~ /^\s*numiptent\s+(\d*)\s+(\d*)\s+(\d*)\s+(\d*)/) {
				if ($1 > $4 - ($size + 10)) {return "The VPS iptables rule limit (numiptent) is too low to add $size rules ($1/$4) - *IPs not added*"}
			}
		}
	}
	return 0;
}
# end fastvps
###############################################################################
# start ipsetcreate
sub ipsetcreate {
	my $set = shift;
	$SIG{PIPE} = 'IGNORE';
	my $family = "inet";
	if ($set =~ /_6/) {$family = "inet6"}
	if ($verbose) {print "csf: IPSET creating set $set\n"}
	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"create","-exist",$set,"hash:net","family",$family,"hashsize",$config{LF_IPSET_HASHSIZE},"maxelem",$config{LF_IPSET_MAXELEM});
	close $childin;
	my @results = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @results;
	if ($results[0] =~ /^ipset/) {
		print "IPSET: [$results[0]]\n";
		$warning .= "*ERROR* IPSET: [$results[0]]\n";
	}
	return;
}
# end ipsetcreate
###############################################################################
# start ipsetrestore
sub ipsetrestore {
	my $set = shift;
	$SIG{PIPE} = 'IGNORE';
	if ($verbose) {print "csf: IPSET loading set $set with ".scalar(@ipset)." entries\n"}
	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"restore");
	print $childin join("\n",@ipset)."\n";
	close $childin;
	my @results = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @results;
	if ($results[0] =~ /^ipset/) {
		print "IPSET: [$results[0]]\n";
		$warning .= "*ERROR* IPSET: [$results[0]]\n";
	}
	undef @ipset;
	return;
}
# end ipsetrestore
###############################################################################
# start ipsetadd
sub ipsetadd {
	my $set = shift;
	my $ip = shift;
	$SIG{PIPE} = 'IGNORE';
	if ($set =~ /^chain(_6)?_NEW(\w+)$/) {$set = "chain".$1."_".$2}
	if ($set =~ /^(\w+)(IN|OUT)$/) {$set = $1}
	if ($set =~ /^bl(_6)?_NEW(\w+)$/) {$set = "bl".$1."_".$2}
	if ($set eq "" or $ip eq "") {return}
	if ($faststart) {
		push @faststartipset, "add -exist $set $ip";
		return;
	}
	if ($verbose) {print "csf: IPSET adding [$ip] to set [$set]\n"}
	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"add","-exist",$set,$ip);
	close $childin;
	my @results = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @results;
	if ($results[0] =~ /^ipset/) {
		print "IPSET: [$results[0]]\n";
		$warning .= "*ERROR* IPSET: [$results[0]]\n";
	}
	return;
}
# end ipsetadd
###############################################################################
# start ipsetdel
sub ipsetdel {
	my $set = shift;
	my $ip = shift;
	$SIG{PIPE} = 'IGNORE';
	if ($set =~ /^chain(_6)?_NEW(\w+)$/) {$set = "chain".$1."_".$2}
	if ($set =~ /^(\w+)(IN|OUT)$/) {$set = $1}
	if ($set =~ /^bl(_6)?_NEW(\w+)$/) {$set = "bl".$1."_".$2}
	if ($set eq "" or $ip eq "") {return}
	if ($verbose) {print "csf: IPSET deleting [$ip] from set [$set]\n"}
	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"del",$set,$ip);
	close $childin;
	my @results = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @results;
	if ($results[0] =~ /^ipset/) {
		print "IPSET: [$results[0]]\n";
		$warning .= "*ERROR* IPSET: [$results[0]]\n";
	}
	return;
}
# end ipsetadd
###############################################################################
