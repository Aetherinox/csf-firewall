#!/usr/bin/perl
###############################################################################
# Copyright 2006-2023, Way to the Web Limited
# URL: http://www.configserver.com
# Email: sales@waytotheweb.com
###############################################################################
## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen, RequireLocalizedPunctuationVars)
# start main
use strict;
use lib '/usr/local/csf/lib';
use Fcntl qw(:DEFAULT :flock);
use IO::Handle;
use IPC::Open3;
use Net::CIDR::Lite;
use POSIX qw(:sys_wait_h sysconf strftime setsid);
use Socket;
use ConfigServer::Config;
use ConfigServer::Slurp qw(slurp);
use ConfigServer::CheckIP qw(checkip);
use ConfigServer::URLGet;
use ConfigServer::GetIPs qw(getips);
use ConfigServer::Service;
use ConfigServer::AbuseIP qw(abuseip);
use ConfigServer::GetEthDev;
use ConfigServer::Sendmail;
use ConfigServer::Logger qw(logfile);
use ConfigServer::KillSSH;
use ConfigServer::LookUpIP qw(iplookup);

umask(0177);

our ($abuseip, $accept, $apache401timeout, $apache403timeout,
     $apache404timeout, $attimeout, $blocklisttimeout, $ccltimeout, $cctimeout,
	 $childcnt, $childpid, $childproc, $cidr, $cidr6, $cleanreg, $clock_ticks,
	 $clusterip, $count, $csftimeout, $cttimeout, $cxsreputation,
	 $dirwatchfiletimeout, $dirwatchtimeout, $dyndnstimeout, $eth6devin,
	 $eth6devout, $ethdevin, $ethdevout, $exploittimeout, $faststart, $gcidr,
	 $gcidr6, $gdyndnstimeout, $globaltimeout, $hostname, $hostshort,
	 $integritytimeout, $ipscidr, $ipscidr6, $ipv4reg, $ipv6reg, $loadtimeout,
	 $locktimeout, $loginterval, $masterpid, $modsecipdbchecktimeout, $pid,
	 $pidfile, $pidino, $pstimeout, $ptchildpid, $pttimeout, $queuetimeout,
	 $relaytimeout, $scripttimeout, $slurpreg, $smtptimeout, $sys_syslog,
	 $syslogcheckcode, $syslogchecktimeout, $sysloggid, $syslogpid,
	 $systemstatstimeout, $tar, $toomanymatches, $tz, $uidtimeout, $uiip,
	 $urlget, $version, $messenger1, $messenger2, $messenger3);

our ($LISTLOCK, $IPTABLESLOCK, $PIDFILE);

our (%accounttracking, %adb, %adf, %ads, %apache401, %apache403, %apache404,
     %blockedips, %blocklists, %cfblocks, %config, %cpanelalert,
	 %cpanelalertusers, %cpconfig, %cxsports, %db, %dirwatchfile, %forks,
	 %gignoreips, %globlogs, %ifaces, %ignoreips, %ips, %logfiles, %loginproto,
	 %logins, %logintimeout, %logscannerfiles, %messengerips, %messengerports,
	 %newaccounttracking, %nofiles, %ports, %portscans, %psips, %pskip,
	 %relayip, %relays, %rtignore, %scripts, %sfile, %skip, %skipfile,
	 %skipscript, %skipuser, %suignore, %uidignore, %uidscans);

our (@cccidrs, @cidrs, @faststart4, @faststart4nat, @faststart6,
     @faststart6nat, @faststartipset, @gcidrs, @ipset, @lfbuf, @lffd, @lfino,
	 @lfsize, @logignore, @matchfile, @rdns, @suspicious);

$pidfile = "/var/run/lfd.pid";

if (-e "/etc/csf/csf.disable") {
	print "csf and lfd have been disabled\n";
	exit 1;
}

if (-e "/etc/csf/csf.error") {
	print "\nError: You have an unresolved error when starting csf. You need to restart csf successfully before starting lfd (see /etc/csf/csf.error)\n";
	exit 1;
}

my $config = ConfigServer::Config->loadconfig();
%config = $config->config();
my %configsetting = $config->configsetting();
$ipv4reg = $config->ipv4reg;
$ipv6reg = $config->ipv6reg;
$slurpreg = ConfigServer::Slurp->slurpreg;
$cleanreg = ConfigServer::Slurp->cleanreg;

unless ($config{LF_DAEMON}) {&cleanup(__LINE__,"*Error* LF_DAEMON not enabled in /etc/csf/csf.conf")}
if ($config{TESTING}) {&cleanup(__LINE__,"*Error* lfd will not run with TESTING enabled in /etc/csf/csf.conf")}

if ($config{UI}) {
	require ConfigServer::DisplayUI;
	import ConfigServer::DisplayUI;
	require ConfigServer::cseUI;
	import ConfigServer::cseUI;
	eval {
		local $SIG{__DIE__} = undef;
		require IO::Socket::SSL;
		import IO::Socket::SSL;
	};
}
if ($config{LF_DIRWATCH}) {
	require File::Find;
	import File::Find;
}
if ($config{UI} or $config{LF_DIRWATCH_FILE}) {
	require Digest::MD5;
	import Digest::MD5;
}
if ($config{SYSLOG} or $config{SYSLOG_CHECK}) {
	eval('use Sys::Syslog;'); ##no critic
	unless ($@) {$sys_syslog = 1}
}
if ($config{DEBUG}) {
	require Time::HiRes;
	import Time::HiRes;
}
if ($config{CLUSTER_SENDTO} or $config{CLUSTER_RECVFROM}) {
	require Crypt::CBC;
	import Crypt::CBC;
	require File::Basename;
	import File::Basename;
}
if ($config{CLUSTER_SENDTO} or $config{CLUSTER_RECVFROM}) {
	require IO::Socket::INET;
	import IO::Socket::INET;
}
if ($config{MESSENGER}) {
	require ConfigServer::Messenger;
	import ConfigServer::Messenger;
}
if ($config{CF_ENABLE}) {
	require ConfigServer::CloudFlare;
	import ConfigServer::CloudFlare;
}
if (-e "/etc/cxs/cxs.reputation" and -e "/usr/local/csf/lib/ConfigServer/cxs.pm") {
	require ConfigServer::cxs;
	import ConfigServer::cxs;
	$cxsreputation = 1;
	%cxsports = ConfigServer::cxs::Rports();
}
$SIG{CHLD} = 'IGNORE';

if ($pid = fork)  {
	exit 0;
} elsif (defined($pid)) {
	$pid = $$;
} else {
	die "*Error* Unable to fork: $!";
}

chdir("/etc/csf");

close(STDIN);
close(STDOUT);
close(STDERR);
open STDIN, "<","/dev/null";
open STDOUT, ">","/dev/null";
open STDERR, ">","/dev/null";
setsid();

my $oldfh = select STDERR; ##no critic
$| = 1;
select $oldfh; ##no critic

if ($config{DEBUG}) {
	open (STDERR, ">>", "/var/log/lfd.log");
}

if (-e "/proc/sys/kernel/hostname") {
	open (my $IN, "<", "/proc/sys/kernel/hostname");
	flock ($IN, LOCK_SH);
	$hostname = <$IN>;
	chomp $hostname;
	close ($IN);
} else {
	$hostname = "unknown";
}
$hostshort = (split(/\./,$hostname))[0];
$clock_ticks = sysconf( &POSIX::_SC_CLK_TCK ) || 100;
$tz = strftime("%z", localtime);

sysopen ($PIDFILE, $pidfile, O_RDWR | O_CREAT) or &childcleanup(__LINE__,"*Error* unable to create lfd PID file [$pidfile] $!");
flock ($PIDFILE, LOCK_EX | LOCK_NB) or &childcleanup(__LINE__,"*Error* attempt to start lfd when it is already running");
autoflush $PIDFILE 1;
seek ($PIDFILE, 0, 0);
truncate ($PIDFILE, 0);
print $PIDFILE "$pid\n";
$pidino = (stat($pidfile))[1];
$masterpid = $pid;

$0 = "lfd - starting";

$SIG{INT} = \&cleanup;
$SIG{TERM} = \&cleanup;
$SIG{HUP} = \&cleanup;
$SIG{__DIE__} = sub {&cleanup(@_);};
$SIG{CHLD} = 'IGNORE';
$SIG{PIPE} = 'IGNORE';

$ipscidr = Net::CIDR::Lite->new;
$ipscidr6 = Net::CIDR::Lite->new;
$cidr = Net::CIDR::Lite->new;
$cidr6 = Net::CIDR::Lite->new;
$gcidr = Net::CIDR::Lite->new;
$gcidr6 = Net::CIDR::Lite->new;
eval {local $SIG{__DIE__} = undef; $ipscidr6->add("::1/128")};
eval {local $SIG{__DIE__} = undef; $ipscidr->add("127.0.0.0/8")};

$faststart = 0;

eval {
	local $SIG{__DIE__} = undef;
	$urlget = ConfigServer::URLGet->new($config{URLGET}, "csf/$version", $config{URLPROXY});
};
unless (defined $urlget) {
	if (-e $config{CURL} or -e $config{WGET}) {
		$config{URLGET} = 3;
		$urlget = ConfigServer::URLGet->new($config{URLGET}, "csf/$version", $config{URLPROXY});
		logfile("*WARNING* URLGET set to use LWP but perl module is not installed, fallback to using CURL/WGET");
	} else {
		$config{URLGET} = 1;
		$urlget = ConfigServer::URLGet->new($config{URLGET}, "csf/$version", $config{URLPROXY});
		logfile("*WARNING* URLGET set to use LWP but perl module is not installed, CURL and WGET not installed - reverting to HTTP::Tiny");
	}
}

if (-e "/etc/wwwacct.conf") {
	foreach my $line (slurp("/etc/wwwacct.conf")) {
		$line =~ s/$cleanreg//g;
		if ($line =~ /^(\s|\#|$)/) {next}
		my ($name,$value) = split (/ /,$line,2);
		$cpconfig{$name} = $value;
	}
}
if (-e "/usr/local/cpanel/version") {
	foreach my $line (slurp("/usr/local/cpanel/version")) {
		$line =~ s/$cleanreg//g;
		if ($line =~ /\d/) {$cpconfig{version} = $line}
	}
}

if (-e "/var/lib/csf/csf.tempconf") {unlink ("/var/lib/csf/csf.tempconf")}
if (-e "/var/lib/csf/lfd.enable") {unlink "/var/lib/csf/lfd.enable"}
if (-e "/var/lib/csf/lfd.start") {unlink "/var/lib/csf/lfd.start"}
if (-e "/var/lib/csf/lfd.restart") {unlink "/var/lib/csf/lfd.restart"}
if (-e "/var/lib/csf/csf.4.saved") {unlink "/var/lib/csf/csf.4.saved"}
if (-e "/var/lib/csf/csf.4.ipsets") {unlink "/var/lib/csf/csf.4.ipsets"}
if (-e "/var/lib/csf/csf.6.saved") {unlink "/var/lib/csf/csf.6.saved"}
if (-e "/var/lib/csf/csf.dnscache") {unlink "/var/lib/csf/csf.dnscache"}
if (-e "/var/lib/csf/csf.gignore") {unlink "/var/lib/csf/csf.gignore"}

&getethdev;

open (my $IN, "<", "/etc/csf/version.txt") or &cleanup(__LINE__,"Unable to open version.txt: $!");
flock ($IN, LOCK_SH);
$version = <$IN>;
close ($IN);
chomp $version;
my $generic = " (cPanel)";
if ($config{GENERIC}) {$generic = " (generic)"}
if ($config{DIRECTADMIN}) {$generic = " (DirectAdmin)"}
if ($config{INTERWORX}) {$generic = " (InterWorx)"}
if ($config{CYBERPANEL}) {$generic = " (CyberPanel)"}
if ($config{CWP}) {$generic = " (CentOS Web Panel)"}
if ($config{VESTA}) {$generic = " (VestaCP)"}
logfile("daemon started on $hostname - csf v$version$generic");
if ($config{DEBUG} >= 1) {logfile("Clock Ticks: $clock_ticks")}
if ($config{DEBUG} >= 1) {logfile("debug: **** DEBUG LEVEL $config{DEBUG} ENABLED ****")}

unless (-e $config{SENDMAIL}) {
	logfile("*WARNING* Unable to send email reports - [$config{SENDMAIL}] not found");
}

if (ConfigServer::Service::type() eq "systemd") {
	my @reply = &syscommand(__LINE__,$config{SYSTEMCTL},"is-active","firewalld");
	chomp @reply;
	if ($reply[0] eq "active" or $reply[0] eq "activating") {
		&cleanup(__LINE__,"*Error* firewalld found to be running. You must stop and disable firewalld when using csf");
		exit 1;
	}
}

require ConfigServer::RegexMain;
import ConfigServer::RegexMain;

if ($config{RESTRICT_SYSLOG} == 1) {
	logfile("Restricted log file access (RESTRICT_SYSLOG)");
	foreach (qw{LF_SSHD LF_FTPD LF_IMAPD LF_POP3D LF_BIND LF_SUHOSIN
				LF_SSH_EMAIL_ALERT LF_SU_EMAIL_ALERT LF_CONSOLE_EMAIL_ALERT
				LF_DISTATTACK LF_DISTFTP LT_POP3D LT_IMAPD PS_INTERVAL
				UID_INTERVAL WEBMIN_LOG LF_WEBMIN_EMAIL_ALERT
				PORTKNOCKING_ALERT LF_SUDO_EMAIL_ALERT}) {
		if ($config{$_} != 0) {
			$config{$_} = 0;
			logfile("RESTRICT_SYSLOG: Option $_ *Disabled*");
		}
	}
}
elsif ($config{RESTRICT_SYSLOG} == 3) {
	logfile("Restricting syslog/rsyslog socket acccess to group [$config{RESTRICT_SYSLOG_GROUP}]...");
	&syslog_init;
}

if ($config{SYSLOG} or $config{SYSLOG_CHECK}) {
	unless ($sys_syslog) {
		logfile("*Error* Cannot log to SYSLOG - Perl module Sys::Syslog required");
	}
}

if (-e "/etc/csf/csf.blocklists") {
	my @entries = slurp("/etc/csf/csf.blocklists");
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
		my ($name,$interval,$max,$url) = split(/\|/,$line);
		if ($name =~ /^\w+$/) {
			$name = substr(uc $name, 0, 25);
			if ($name =~ /^CXS_/) {$name =~ s/^CXS_/X_CXS_/}
			if ($interval < 3600) {$interval = 3600}
			if ($max eq "") {$max = 0}
			$blocklists{$name}{interval} = $interval;
			$blocklists{$name}{max} = $max;
			$blocklists{$name}{url} = $url;
		}
	}
}
if ($cxsreputation and -e "/etc/cxs/cxs.blocklists") {
	my $all = 0;
	my @lines = slurp("/etc/cxs/cxs.blocklists");
	if (grep {$_ =~ /^CXS_ALL/} @lines) {$all = 1}
	foreach my $line (@lines) {
		$line =~ s/$cleanreg//g;
		if ($line =~ /^(\s|\#|$)/) {next}
		my ($name,$interval,$max,$url) = split(/\|/,$line);
		$url =~ s/download\.configserver\.com/$config{DOWNLOADSERVER}/g;
		if ($all and $name ne "CXS_ALL") {next}
		if ($name =~ /^\w+$/) {
			$name = substr(uc $name, 0, 25);
			if ($max eq "") {$max = 0}
			$blocklists{$name}{interval} = $interval;
			$blocklists{$name}{max} = $max;
			$blocklists{$name}{url} = $url;
		}
	}
}

if (-e "/etc/csf/csf.ignore") {
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
		my ($first,undef) = split(/\s/,$line);
		my ($ip,$iscidr) = split(/\//,$first);
		if (checkip(\$first)) {
			if ($iscidr) {push @cidrs,$first} else {$ignoreips{$ip} = 1}
		}
		elsif ($ip ne "127.0.0.1") {logfile("Invalid entry in csf.ignore: [$first]")}
	}
	foreach my $entry (@cidrs) {
		if (checkip(\$entry) == 6) {
			eval {local $SIG{__DIE__} = undef; $cidr6->add($entry)};
		} else {
			eval {local $SIG{__DIE__} = undef; $cidr->add($entry)};
		}
		if ($@) {logfile("Invalid entry in csf.ignore: $entry")}
	}
}
if (-e "/etc/csf/csf.rignore") {
	my @entries = slurp("/etc/csf/csf.rignore");
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
		if ($line =~ /^(\.|\w)/) {
			my ($host,undef) = split (/\s/,$line);
			if ($host ne "") {push @rdns,$host}
		}
	}
}
if ($config{IGNORE_ALLOW} and -e "/etc/csf/csf.allow") {
	my @ignore = slurp("/etc/csf/csf.allow");
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
		my ($first,undef) = split(/\s/,$line);
		my ($ip,$iscidr) = split(/\//,$first);
		if (checkip(\$first)) {
			if ($iscidr) {push @cidrs,$first} else {$ignoreips{$ip} = 1}
		}
	}
	foreach my $entry (@cidrs) {
		if (checkip(\$entry) == 6) {
			eval {local $SIG{__DIE__} = undef; $cidr6->add($entry)};
		} else {
			eval {local $SIG{__DIE__} = undef; $cidr->add($entry)};
		}
		if ($@) {logfile("Invalid CIDR in csf.allow: $entry")}
	}
}

if ($config{LF_HTACCESS} or $config{LF_APACHE_404} or $config{LF_APACHE_403} or $config{LF_APACHE_401} or $config{LF_QOS} or $config{LF_SYMLINK}) {&globlog("HTACCESS_LOG")}
if ($config{LF_MODSEC} or $config{LF_CXS}) {&globlog("MODSEC_LOG")}
if ($config{LF_SUHOSIN}) {&globlog("SUHOSIN_LOG}")}
if ($config{LF_SMTPAUTH} or $config{LF_EXIMSYNTAX}) {&globlog("SMTPAUTH_LOG")}
if ($config{LF_POP3D} or $config{LT_POP3D}) {&globlog("POP3D_LOG")}
if ($config{LF_IMAPD} or $config{LT_IMAPD}) {&globlog("IMAPD_LOG")}
if ($config{LF_CPANEL}) {&globlog("CPANEL_LOG")}
if ($config{LF_DIRECTADMIN}) {
	&globlog("DIRECTADMIN_LOG");
	&globlog("DIRECTADMIN_LOG_R");
	&globlog("DIRECTADMIN_LOG_S");
	&globlog("DIRECTADMIN_LOG_P");
}
if ($config{LF_INTERWORX}) {&globlog("INTERWORX_LOG")}
if ($config{LF_CYBERPANEL}) {&globlog("CYBERPANEL_LOG")}
if ($config{LF_CWP}) {&globlog("CWP_LOG")}
if ($config{LF_VESTA}) {&globlog("VESTA_LOG")}
if ($config{LF_WEBMIN} or $config{LF_WEBMIN_EMAIL_ALERT}) {&globlog("WEBMIN_LOG")}
if ($config{LF_SSHD} or $config{LF_SSH_EMAIL_ALERT} or $config{LF_CONSOLE_EMAIL_ALERT}) {&globlog("SSHD_LOG")}
if ($config{LF_FTPD}) {&globlog("FTPD_LOG")}
if ($config{LF_BIND}) {&globlog("BIND_LOG")}
if ($config{LF_CPANEL_ALERT}) {&globlog("CPANEL_ACCESSLOG")}
if ($config{SYSLOG_CHECK} and $sys_syslog) {&globlog("SYSLOG_LOG")}

if ($config{PS_INTERVAL} or $config{ST_ENABLE} or $config{UID_INTERVAL}) {&globlog("IPTABLES_LOG")}
if ($config{LF_SU_EMAIL_ALERT}) {&globlog("SU_LOG")}
if ($config{LF_SUDO_EMAIL_ALERT}) {&globlog("SUDO_LOG")}
if ($config{LF_SCRIPT_ALERT}) {&globlog("SCRIPT_LOG")}
if ($config{RT_RELAY_ALERT} or $config{RT_AUTHRELAY_ALERT} or $config{RT_POPRELAY_ALERT}) {&globlog("SMTPRELAY_LOG")}

if ($config{LT_IMAPD}) {$loginproto{imapd} = $config{LT_IMAPD}}
if ($config{LT_POP3D}) {$loginproto{pop3d} = $config{LT_POP3D}}

for (my $x = 1;$x < 10;$x++) {&globlog("CUSTOM${x}_LOG")}

if (-e "/usr/local/cpanel/version" and -e "/etc/cpanel/ea4/is_ea4" and -e "/etc/cpanel/ea4/paths.conf") {
	my @file = slurp("/etc/cpanel/ea4/paths.conf");
	foreach my $line (@file) {
		$line =~ s/$cleanreg//g;
		if ($line =~ /^(\s|\#|$)/) {next}
		if ($line !~ /=/) {next}
		my ($name,$value) = split (/=/,$line,2);
		$value =~ s/^\s+//g;
		$value =~ s/\s+$//g;
		if ($name eq "dir_logs") {
			if ($config{LF_HTACCESS} or $config{LF_APACHE_404} or $config{LF_APACHE_403} or $config{LF_APACHE_401} or $config{LF_QOS} or $config{LF_SYMLINK}) {
				delete $globlogs{HTACCESS_LOG}{$config{HTACCESS_LOG}};
				delete $logfiles{$config{HTACCESS_LOG}};
				$globlogs{HTACCESS_LOG}{"$value/error_log"} = 1;
				$logfiles{"$value/error_log"} = 1;
				logfile("EasyApache4, using $value/error_log instead of $config{HTACCESS_LOG} (Web Server)");
			}
			if ($config{LF_MODSEC} or $config{LF_CXS}) {
				delete $globlogs{MODSEC_LOG}{$config{MODSEC_LOG}};
				delete $logfiles{$config{MODSEC_LOG}};
				$globlogs{MODSEC_LOG}{"$value/error_log"} = 1;
				$logfiles{"$value/error_log"} = 1;
				logfile("EasyApache4, using $value/error_log instead of $config{MODSEC_LOG} {ModSecurity}");
			}
		}
	}
}

if ($config{LOGSCANNER}) {
	my @entries = slurp("/etc/csf/csf.logfiles");
	foreach my $line (@entries) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @entries,@incfile;
		}
	}
	foreach my $file (@entries) {
        $file =~ s/$cleanreg//g;
		if ($file eq "") {next}
		if ($file =~ /^\s*\#|Include/) {next}
		if ($file =~ /\*|\?|\[/) {
			foreach my $log (glob $file) {
				if (-e $log) {
					$logfiles{$log} = 1;
					$logscannerfiles{$log} = 1;
				}
			}
		} else {
			if (-e $file) {
				$logfiles{$file} = 1;
				$logscannerfiles{$file} = 1;
			}
		}
	}
	my @entries2 = slurp("/etc/csf/csf.logignore");
	foreach my $line (@entries2) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @entries2,@incfile;
		}
	}
	foreach my $line (@entries2) {
		$line =~ s/$cleanreg//g;
		if ($line eq "") {next}
		if ($line =~ /^\s*\#|Include/) {next}
		if (&testregex($line)) {push @logignore, $line}
		else {logfile("*Error* Invalid regex [$line] in csf.logignore")}
	}
	logfile("Log Scanner...");
}

unless (-d "/var/spool/exim") {$config{LF_QUEUE_ALERT} = 0}

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
	logfile("WATCH_MODE enabled...");
}

if (-e "/var/lib/csf/csf.restart") {
	unlink "/var/lib/csf/csf.restart";
	&csfrestart;
}

if ($config{LF_CSF}) {
	if (-e "/var/lib/csf/cpanel.new") {unlink "/var/lib/csf/cpanel.new"}
	logfile("CSF Tracking...");
	&csfcheck;
	$csftimeout = 0;
}

if ($config{IPV6}) {
	logfile("IPv6 Enabled...");
}

if ($cxsreputation) {
	logfile("cxs Reputation Enabled...");
}

if ($config{PT_LOAD}) {
	logfile("LOAD Tracking...");
	&loadcheck;
	$loadtimeout = 0;
}

if ($config{CF_ENABLE} and -e "/etc/csf/csf.cloudflare") {
	logfile("CloudFlare Firewall...");
	$cfblocks{LF_MODSEC} = 1;
	$cfblocks{LF_CXS} = 1;
#	$cfblocks{LF_CPANEL} = 1;
#	$cfblocks{LF_DIRECTADMIN} = 1;
#	$cfblocks{LF_WEBMIN} = 1;
}

if ($config{MESSENGER}) {
	unless (-e "/var/log/lfd_messenger.log") {
		open (my $OUT, ">", "/var/log/lfd_messenger.log");
		close ($OUT);
	}
	system("chown","$config{MESSENGER_USER}:$config{MESSENGER_USER}","/var/log/lfd_messenger.log");

	if (!$config{MESSENGERV2}) {
		&messengerstop(2);
	}
	if (!$config{MESSENGERV3}) {
		&messengerstop(3);
	}
	my (undef,undef,$uid,$gid) = getpwnam($config{MESSENGER_USER});
	if (($config{MESSENGER_USER} ne "") and ($config{MESSENGER_USER} ne "root") and ($uid > 0) and ($gid > 0)) {
		if ($config{MESSENGER_HTTPS_DISABLED} ne "") {
			logfile($config{MESSENGER_HTTPS_DISABLED});
		}
		if ($config{MESSENGERV3}) {
			$messenger3 = ConfigServer::Messenger->init(3);
			if (-e "/var/cpanel/users/$config{MESSENGER_USER}") {
				logfile("*MESSENGERV3* - Cannot run service using a cPanel account:[$config{MESSENGER_USER}], MESSENGER service disabled");
				$config{MESSENGER} = 0;
				$config{MESSENGERV3} = 0;
				&messengerstop(3);
			} else {
				if ($config{MESSENGER_HTTPS_IN} ne "") {
					foreach my $port (split(/\,/,$config{MESSENGER_HTTPS_IN})) {$messengerports{$port} = 1}
					logfile("Messenger HTTPS Service starting...");
				}
				if ($config{MESSENGER_HTML_IN} ne "") {
					foreach my $port (split(/\,/,$config{MESSENGER_HTML_IN})) {$messengerports{$port} = 1}
					logfile("Messenger HTML Service starting...");
				}
				&messengerv3;
			}
		}
		elsif ($config{MESSENGERV2}) {
			$messenger2 = ConfigServer::Messenger->init(2);
			if (-e "/var/cpanel/users/$config{MESSENGER_USER}") {
				logfile("*MESSENGERV2* - Cannot run service using a cPanel account:[$config{MESSENGER_USER}], MESSENGER service disabled");
				$config{MESSENGER} = 0;
				$config{MESSENGERV2} = 0;
				&messengerstop(2);
			} else {
				if ($config{MESSENGER_HTTPS_IN} ne "") {
					foreach my $port (split(/\,/,$config{MESSENGER_HTTPS_IN})) {$messengerports{$port} = 1}
					logfile("Messenger HTTPS Service starting...");
				}
				if ($config{MESSENGER_HTML_IN} ne "") {
					foreach my $port (split(/\,/,$config{MESSENGER_HTML_IN})) {$messengerports{$port} = 1}
					logfile("Messenger HTML Service starting...");
				}
				&messengerv2;
			}
		}
		else {
			$messenger1 = ConfigServer::Messenger->init(1);
			if ($config{MESSENGER_HTTPS_IN} ne "") {
				foreach my $port (split(/\,/,$config{MESSENGER_HTTPS_IN})) {$messengerports{$port} = 1}
				logfile("Messenger HTTPS Service starting...");
				&messenger($config{MESSENGER_HTTPS},$config{MESSENGER_USER},"HTTPS");
			}
			if ($config{MESSENGER_HTML_IN} ne "") {
				foreach my $port (split(/\,/,$config{MESSENGER_HTML_IN})) {$messengerports{$port} = 1}
				logfile("Messenger HTML Service starting...");
				&messenger($config{MESSENGER_HTML},$config{MESSENGER_USER},"HTML");
			}
		}
		if ($config{MESSENGER_TEXT_IN} ne "") {
			unless (defined $messenger1) {
				$messenger1 = ConfigServer::Messenger->init(1);
			}
			foreach my $port (split(/\,/,$config{MESSENGER_TEXT_IN})) {$messengerports{$port} = 1}
			logfile("Messenger TEXT Service starting...");
			&messenger($config{MESSENGER_TEXT},$config{MESSENGER_USER},"TEXT");
		}
	} else {
		logfile("Messenger account [$config{MESSENGER_USER}] invalid, MESSENGER service *disabled*");
		$config{MESSENGER} = 0;
	}
} else {
	&messengerstop(2);
	&messengerstop(3);
}

if ($config{UI}) {
	if ($config{UI_CXS}) {
	use lib '/etc/cxs';
	require ConfigServer::cxsUI;
	}
	if ($config{UI_USER} eq "" or $config{UI_USER} eq "username") {
		logfile("*Error* Cannot run csf Integrated UI - UI_USER must set");
		$config{UI} = 0;
	}
	elsif ($config{UI_PASS} eq "" or $config{UI_PASS} eq "password") {
		logfile("*Error* Cannot run Integrated csf UI - UI_PASS must set");
		$config{UI} = 0;
	}
	else {
		logfile("csf Integrated UI running up on port $config{UI_PORT}...");
		&ui;
	}
}

if ($config{CLUSTER_RECVFROM}) {
	logfile("Cluster Service starting...");
	if (length $config{CLUSTER_KEY} < 8) {
		logfile("Failed: Cluster Service - CLUSTER_KEY too short");
		$config{CLUSTER_RECVFROM} = 0;
	} else {
		if (length $config{CLUSTER_KEY} < 20) {logfile("Cluster Service - CLUSTER_KEY should really be longer than 20 characters")}
		&lfdserver;
	}
}

if ($config{DYNDNS}) {
	logfile("DynDNS Tracking...");
	&dyndns;
	$dyndnstimeout = 0;
	if ($config{DYNDNS} < 60) {
		logfile("DYNDNS refresh increased to 300 to prevent looping (csf.conf setting: $config{DYNDNS})");
		$config{DYNDNS} = 300;
	}
}

if ($config{LF_GLOBAL}) {
	if ($config{GLOBAL_IGNORE}) {logfile("Global Ignore Tracking...")}
	if ($config{GLOBAL_ALLOW}) {logfile("Global Allow Tracking...")}
	if ($config{GLOBAL_DENY}) {logfile("Global Deny Tracking...")}
	if ($config{GLOBAL_DYNDNS}) {logfile("Global DynDNS Tracking...")}
	&global;
	$globaltimeout = 0;
	if ($config{LF_GLOBAL} < 60) {
		logfile("LF_GLOBAL refresh increased to 300 to prevent looping (csf.conf setting: $config{LF_GLOBAL})");
		$config{LF_GLOBAL} = 300;
	}
	if ($config{GLOBAL_DYNDNS_INTERVAL} < 60) {
		logfile("GLOBAL_DYNDNS_INTERVAL refresh increased to 300 to prevent looping (csf.conf setting: $config{GLOBAL_DYNDNS_INTERVAL})");
		$config{GLOBAL_DYNDNS_INTERVAL} = 300;
	}
}

if (scalar(keys %blocklists) > 0) {
	logfile("Blocklist Tracking...");
	&blocklist;
	$blocklisttimeout = 0;
}

if ($config{CC_LOOKUPS}) {
	if ($config{CC_LOOKUPS} != 4 and $config{MM_LICENSE_KEY} eq "" and $config{CC_SRC} eq "1") {
		logfile("*ERROR*: Country Code Lookups setting MM_LICENSE_KEY must be set in /etc/csf/csf.conf to continue updating the MaxMind databases");
	}
	logfile("Country Code Lookups...");
	&countrycodelookups;
	$ccltimeout = 0;
}

if ($config{CC_DENY} or $config{CC_ALLOW} or $config{CC_ALLOW_FILTER} or $config{CC_ALLOW_PORTS} or $config{CC_DENY_PORTS} or $config{CC_ALLOW_SMTPAUTH}) {
	if ($config{MM_LICENSE_KEY} eq "" and $config{CC_SRC} eq "1") {
		logfile("*ERROR*: Country Code Filters setting MM_LICENSE_KEY must be set in /etc/csf/csf.conf to continue updating the MaxMind databases");
	}
	logfile("Country Code Filters...");
	&countrycode;
	$cctimeout = 0;
}

if ($config{CC_IGNORE}) {
	if ($config{CC_LOOKUPS}) {
		logfile("Country Code Ignores...");
	} else {
		logfile("Country Code Ignores requires CC_LOOKUPS to be enabled - disabled CC_IGNORE");
		$config{CC_IGNORE} = "";
	}
}

if ($config{LF_INTEGRITY}) {
	logfile("System Integrity Tracking...");
	&integrity;
	$integritytimeout = 0;
	if ($config{LF_INTEGRITY} < 120) {
		logfile("LF_INTEGRITY refresh increased to 300 to prevent looping (csf.conf setting: $config{LF_INTEGRITY})");
		$config{LF_INTEGRITY} = 300;
	}
}

if ($config{LF_EXPLOIT}) {
	if (-e "/var/lib/csf/csf.tempexploit") {unlink ("/var/lib/csf/csf.tempexploit")}
	if (-e "/etc/csf/csf.suignore") {
		my @entries = slurp("/etc/csf/csf.suignore");
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
			$suignore{$line} = 1;
		}
	}
	logfile("Exploit Tracking...");
	&exploit;
	$exploittimeout = 0;
	if ($config{LF_EXPLOIT} < 60) {
		logfile("LF_EXPLOIT refresh increased to 60 to prevent looping (csf.conf setting: $config{LF_EXPLOIT})");
		$config{LF_EXPLOIT} = 60;
	}
}
if ($config{X_ARF}) {
	if (-e $config{HOST}) {$abuseip = 1}
	else {logfile("Binary location of HOST is incorrect in csf.conf")}
}

if ($config{LF_DIRWATCH}) {
	if (-e "/etc/csf/csf.fignore") {
		my @entries = slurp("/etc/csf/csf.fignore");
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
			if ($line =~ /\*|\\/) {
				if (&testregex($line)) {push @matchfile, $line}
				else {logfile("*Error* Invalid regex [$line] in csf.fignore")}
			}
			elsif ($line =~ /^user:(.*)/) {
				$skipuser{$1} = 1;
			}
			else {
				$skipfile{$line} = 1;
			}
		}
	}
	if (-e "/var/lib/csf/csf.tempfiles") {unlink ("/var/lib/csf/csf.tempfiles")}
	if (-e "/var/lib/csf/csf.dwdisable") {unlink ("/var/lib/csf/csf.dwdisable")}
	logfile("Directory Watching...");
	$dirwatchtimeout = 0;
}

if ($config{LF_DIRWATCH_FILE}) {
	if (-e "/etc/csf/csf.dirwatch") {
		logfile("Directory File Watching...");
		my @entries = slurp("/etc/csf/csf.dirwatch");
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
			if (-e $line) {
				$dirwatchfile{$line} = 1;
			} else {
				logfile("Directory File Watching [$line] not found - ignoring");
			}
		}
		&dirwatchfile;
		$dirwatchfiletimeout = 0;
	}
}

if ($config{LF_SCRIPT_ALERT}) {
	logfile("Email Script Tracking...");
	if (-e "/etc/csf/csf.signore") {
		my @entries = slurp("/etc/csf/csf.signore");
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
			$skipscript{$line} = 1;
		}
	}
}

if ($config{LF_QUEUE_ALERT}) {
	logfile("Email Queue Tracking...");
	&queuecheck;
	$queuetimeout = 0;
	if ($config{LF_QUEUE_INTERVAL} < 30) {
		logfile("LF_QUEUE_INTERVAL refresh increased to 300 to prevent looping (csf.conf setting: $config{LF_QUEUE_INTERVAL})");
		$config{LF_QUEUE_INTERVAL} = 300;
	}
}

if ($config{LF_MODSECIPDB_ALERT}) {
	logfile("ModSecurity IP D/B Tracking...");
	&modsecipdbcheck;
	$modsecipdbchecktimeout = 0;
}

if ($config{RT_RELAY_ALERT} or $config{RT_AUTHRELAY_ALERT} or $config{RT_POPRELAY_ALERT} or $config{RT_LOCALRELAY_ALERT} or $config{RT_LOCALHOSTRELAY_ALERT}) {
	logfile("Email Relay Tracking...");
	if ($config{RT_LOCALRELAY_ALERT}) {
		if (-e "/etc/csf/csf.mignore") {
			my @entries = slurp("/etc/csf/csf.mignore");
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
				$rtignore{$line} = 1;
			}
		}
	}
}

if ($config{LF_PERMBLOCK}) {
	logfile("Temp to Perm Block Tracking...");
}

if ($config{LF_NETBLOCK}) {
	logfile("Netblock Tracking...");
}

if ($config{LF_PERMBLOCK} or $config{LF_NETBLOCK}) {
	sysopen (my $TEMPIP, "/var/lib/csf/csf.tempip", O_RDWR | O_CREAT);
	flock ($TEMPIP, LOCK_EX);
	my @data = <$TEMPIP>;
	chomp @data;
	seek ($TEMPIP, 0, 0);
	truncate ($TEMPIP, 0);
	foreach my $line (@data) {
		my $old = 1;
		my ($oip,$operm,$otime,$omessage) = split(/\|/,$line,4);
		my $interval = time - $otime;
		if ($config{LF_PERMBLOCK} and $interval < ($config{LF_PERMBLOCK_INTERVAL} * $config{LF_PERMBLOCK_COUNT})) {$old = 0}
		if ($config{LF_NETBLOCK} and $interval < ($config{LF_NETBLOCK_INTERVAL} * $config{LF_NETBLOCK_COUNT})) {$old = 0}
		unless ($old) {print $TEMPIP "$line\n"}
	}
	close ($TEMPIP);
}

if ($config{ST_SYSTEM}) {
	logfile("System Statistics...");
	my $time = time;
	sysopen (my $SYSSTATNEW,"/var/lib/csf/stats/system.new", O_RDWR | O_CREAT);
	flock ($SYSSTATNEW, LOCK_EX);
	seek ($SYSSTATNEW, 0, 0);
	truncate ($SYSSTATNEW, 0);

	sysopen (my $SYSSTAT,"/var/lib/csf/stats/system", O_RDWR | O_CREAT);
	flock ($SYSSTAT, LOCK_EX);
	while (my $line = <$SYSSTAT>) {
		chomp $line;
		my ($thistime,undef) = split(/\,/,$line);
		if ($time - $thistime > (86400 * $config{ST_SYSTEM_MAXDAYS})) {next}
		print $SYSSTATNEW $line."\n";
	}
	close ($SYSSTAT);
	close ($SYSSTATNEW);
	rename "/var/lib/csf/stats/system.new", "/var/lib/csf/stats/system";
	&systemstats;
}
if ($config{PS_INTERVAL}) {
	logfile("Port Scan Tracking...");
	if ($config{PS_INTERVAL} < 60) {
		logfile("PS_INTERVAL refresh increased to 60 to prevent looping (csf.conf setting: $config{PS_INTERVAL})");
		$config{PS_INTERVAL} = 60;
	}
	$pstimeout = 0;
}
if ($config{UID_INTERVAL}) {
	logfile("User ID Tracking...");
	if ($config{UID_INTERVAL} < 60) {
		logfile("UID_INTERVAL refresh increased to 60 to prevent looping (csf.conf setting: $config{UID_INTERVAL})");
		$config{UID_INTERVAL} = 60;
	}
	$uidtimeout = 0;
	my @entries = slurp("/etc/csf/csf.uidignore");
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
		$uidignore{$line} = 1;
	}
}

if ($config{CT_LIMIT}) {
	if ($config{CT_STATES}) {
		logfile("Connection Tracking ($config{CT_STATES})...");
	} else {
		logfile("Connection Tracking...");
	}
	&connectiontracking;
	$cttimeout = 0;
	if ($config{CT_INTERVAL} < 10) {
		logfile("CT_INTERVAL refresh increased to 30 to prevent looping (csf.conf setting: $config{CT_INTERVAL})");
		$config{CT_INTERVAL} = 30;
	}
}

if ($config{PT_LIMIT}) {
	if (-e "/etc/csf/csf.pignore") {
		my @entries = slurp("/etc/csf/csf.pignore");
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
			my ($item,$rule) = split(/:/,$line,2);
			$rule =~ s/\r|\n//g;
			$rule =~ s/\s*$//g;
			$item =~ s/\s//g;
			$item = lc $item;
			if ($item =~ /^(cmd|exe|user)$/) {
				$skip{$item}{$rule} = 1;
			}
			elsif ($item =~ /^(pcmd|pexe|puser)$/) {
				if (&testregex($rule)) {$pskip{$item}{$rule} = 1}
				else {logfile("*Error* Invalid regex [$line] in csf.pignore")}
			}
		}
	}
	if (-e "/var/lib/csf/csf.temppids") {unlink ("/var/lib/csf/csf.temppids")}
	if (-e "/var/lib/csf/csf.tempusers") {unlink ("/var/lib/csf/csf.tempusers")}
	logfile("Process Tracking...");
	&processtracking;
	$pttimeout = 0;
	if ($config{PT_INTERVAL} < 10) {
		logfile("PT_INTERVAL refresh increased to 60 to prevent looping (csf.conf setting: $config{PT_INTERVAL})");
		$config{PT_INTERVAL} = 60;
	}

	if ($config{PT_SSHDHUNG}) {
		logfile("SSHD Hung Session Tracking...");
	}
}

if ($config{AT_ALERT}) {
	if ($config{AT_ALERT} == 3) {
		my ($user,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell) = getpwnam("root");
		$accounttracking{$user}{account} = 1;
		$accounttracking{$user}{passwd} = $passwd;
		$accounttracking{$user}{uid} = $uid;
		$accounttracking{$user}{gid} = $gid;
		$accounttracking{$user}{dir} = $dir;
		$accounttracking{$user}{shell} = $shell;
	} else {
		while (my ($user,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell) = getpwent()) {
			if (($config{AT_ALERT} eq "2") and ($uid ne "0")) {next}
			$accounttracking{$user}{account} = 1;
			$accounttracking{$user}{passwd} = $passwd;
			$accounttracking{$user}{uid} = $uid;
			$accounttracking{$user}{gid} = $gid;
			$accounttracking{$user}{dir} = $dir;
			$accounttracking{$user}{shell} = $shell;
		}
		endpwent();
	}
	logfile("Account Tracking...");
	$attimeout = 0;
	if ($config{AT_INTERVAL} < 10) {
		logfile("AT_INTERVAL refresh increased to 60 to prevent looping (csf.conf setting: $config{AT_INTERVAL})");
		$config{AT_INTERVAL} = 60;
	}
}

if ($config{LF_SSH_EMAIL_ALERT}) {
	logfile("SSH Tracking...");
}
if ($config{LF_WEBMIN_EMAIL_ALERT}) {
	logfile("Webmin Tracking...");
}
if ($config{LF_SU_EMAIL_ALERT}) {
	logfile("SU Tracking...");
}
if ($config{LF_SUDO_EMAIL_ALERT}) {
	logfile("SUDO Tracking...");
}
if ($config{LF_CONSOLE_EMAIL_ALERT}) {
	logfile("Console Tracking...");
}

if ($config{LF_CPANEL_ALERT}) {
	$config{LF_CPANEL_ALERT_USERS} =~ s/\s//g;
	foreach my $user (split(/\,/,$config{LF_CPANEL_ALERT_USERS})) {
		$cpanelalertusers{$user} = 1;
	}
	logfile("WHM Tracking...");
}

if ($config{PORTKNOCKING} and $config{PORTKNOCKING_ALERT}) {
	logfile("Port Knocking Tracking...");
}

my $sshdef = $config{PORTS_sshd};
$ports{pop3d} = $config{PORTS_pop3d};
$ports{imapd} = $config{PORTS_imapd};
$ports{htpasswd} = $config{PORTS_htpasswd};
$ports{mod_security} = $config{PORTS_mod_security};
$ports{mod_qos} = $config{PORTS_mod_qos};
$ports{symlink} = $config{PORTS_symlink};
$ports{cxs} = $config{PORTS_cxs};
$ports{bind} = $config{PORTS_bind};
$ports{suhosin} = $config{PORTS_suhosin};
$ports{cpanel} = $config{PORTS_cpanel};
$ports{ftpd} = $config{PORTS_ftpd};
$ports{smtpauth} = $config{PORTS_smtpauth};
$ports{eximsyntax} = $config{PORTS_eximsyntax};
$ports{webmin} = $config{PORTS_webmin};
$ports{directadmin} = $config{PORTS_directadmin};

opendir (DIR, "/etc/chkserv.d");
while (my $file = readdir (DIR)) {
	if ($file =~ /exim-(\d+)/) {
		$ports{smtpauth} .= ",$1";
		$ports{eximsyntax} .= ",$1";
	}
}
closedir (DIR);

if (-e "/etc/ssh/sshd_config") {
	foreach my $line (slurp("/etc/ssh/sshd_config")) {
		$line =~ s/$cleanreg//g;
		if ($line =~ /^(\s|\#|$)/) {next}
		if ($line =~ /^Port\s+(\d+)/i) {
			my $port = $1;
			if ($ports{sshd}) {
				$ports{sshd} .= ",$port";
			} else {
				$ports{sshd} = $port;
			}
		}
	}
}
unless ($ports{sshd}) {$ports{sshd} = $sshdef}

if ($config{LF_INTERVAL} < 60) {
	logfile("LF_INTERVAL refresh increased to 300 to prevent looping (csf.conf setting: $config{LF_INTERVAL})");
	$config{LT_INTERVAL} = 300;
}

if ($config{LF_PARSE} < 5 or $config{LF_PARSE} > 20) {
	logfile("LF_PARSE refresh reset to 5 to prevent looping (csf.conf setting: $config{LF_PARSE})");
	$config{LF_PARSE} = 5;
}

my $lastline = "";
$scripttimeout = 0;
my $duration = 0;
my $maintimer = 0;
while (1)  {
	$0 = "lfd - processing";
	$maintimer = time;

	seek ($PIDFILE, 0, 0);
	my @piddata = <$PIDFILE>;
	chomp @piddata;
	if (($pid ne $piddata[0]) or ($pidino ne (stat($pidfile))[1])) {
		&cleanup(__LINE__,"*Error* pid mismatch or missing");
	}

	if (-e "/etc/csf/csf.error") {
		&cleanup(__LINE__,"*Error* You have an unresolved error when starting csf. You need to restart csf successfully before restarting lfd (see /etc/csf/csf.error). *lfd stopped*");
	}
	my $perms = sprintf "%04o", (stat("/etc/csf"))[2] & oct("07777");
	if ($perms != "0600") {
		chmod (0600,"/etc/csf");
		logfile("*Permissions* on /etc/csf reset to 0600 [currently: $perms]");
	}
	$perms = sprintf "%04o", (stat("/var/lib/csf"))[2] & oct("07777");
	if ($perms != "0600") {
		chmod (0600,"/var/lib/csf");
		logfile("*Permissions* on /var/lib/csf reset to 0600 [currently: $perms]");
	}
	$perms = sprintf "%04o", (stat("/usr/local/csf"))[2] & oct("07777");
	if ($perms != "0600") {
		chmod (0600,"/usr/local/csf");
		logfile("*Permissions* on /usr/local/csf reset to 0600 [currently: $perms]");
	}

	$locktimeout+=$duration;
	if ($locktimeout >= 60) {
		$locktimeout = 0;
		&lockhang;
	}

	if (scalar(keys %forks) > 200) {
		my $forkcnt = 0;
		foreach my $key (keys %forks) {
			if ($key =~ /\d+/ and $key > 1 and kill(0,$key)) {
				$forkcnt++;
				if ($config{DEBUG} >= 3) {logfile("debug: fork:[$key]")}
			} else {
				delete $forks{$key};
			}
		}
		if ($config{DEBUG} >= 2) {logfile("debug: Forks:[$forkcnt]")}
		if ($forkcnt > 200) {
			logfile("*Error* Excessive number of children ($forkcnt), restarting lfd...");
			&lfdrestart;
			exit;
		}
	}

	if (-e "/var/lib/csf/lfd.restart") {
		unlink "/var/lib/csf/lfd.restart";
		&lfdrestart;
		exit;
	}

	if (-e "/var/lib/csf/csf.restart") {
		unlink "/var/lib/csf/csf.restart";
		&csfrestart;
	}

	if ($config{LF_CSF}) {
		$csftimeout+=$duration;
		if ($csftimeout >= 300) {
			$csftimeout = 0;
			&csfcheck;
		}
	}

	if ($config{SYSLOG_CHECK} and $sys_syslog) {
		$syslogchecktimeout+=$duration;
		if ($syslogchecktimeout >= $config{SYSLOG_CHECK}) {
			$syslogchecktimeout = 0;
			if ($syslogcheckcode eq "") {
				my @chars = ('0'..'9','a'..'z','A'..'Z');
				$syslogcheckcode = join '', map {$chars[rand(@chars)]} (1..(15 + int(rand(15))));
				eval {
					local $SIG{__DIE__} = undef;
					openlog('lfd', 'ndelay,pid', 'user');
					syslog('info', "SYSLOG check [$syslogcheckcode]");
					closelog();
				}
			} else {
				&syslogcheck;
				$syslogcheckcode = "";
			}
		}
	}

	if ($config{ST_SYSTEM}) {
		$systemstatstimeout+=$duration;
		if ($systemstatstimeout >= 60) {
			$systemstatstimeout = 0;
			&systemstats;
		}
	}

	if ($config{LT_POP3D}) {
		$logintimeout{pop3d}+=$duration;
		if ($logintimeout{pop3d} >= 3600) {
			delete $logintimeout{pop3d};
			delete $logins{pop3d};
		}
	}
	if ($config{LT_IMAPD}) {
		$logintimeout{imapd}+=$duration;
		if ($logintimeout{imapd} >= 3600) {
			delete $logintimeout{imapd};
			delete $logins{imapd};
		}
	}
	if ($config{PS_INTERVAL}) {
		$pstimeout+=$duration;
		if ($pstimeout >= $config{PS_INTERVAL}) {
			$pstimeout = 0;
			undef %portscans;
		}
	}
	if ($config{UID_INTERVAL}) {
		$uidtimeout+=$duration;
		if ($uidtimeout >= $config{UID_INTERVAL}) {
			$uidtimeout = 0;
			undef %uidscans;
		}
	}
	if ($config{LF_SCRIPT_ALERT}) {
		$scripttimeout+=$duration;
		if ($scripttimeout >= 3600) {
			$scripttimeout = 0;
			undef %scripts;
		}
	}
	if ($config{LF_APACHE_404}) {
		$apache404timeout+=$duration;
		if ($apache404timeout >= $config{LF_INTERVAL}) {
			$apache404timeout = 0;
			undef %apache404;
		}
	}
	if ($config{LF_APACHE_403}) {
		$apache403timeout+=$duration;
		if ($apache403timeout >= $config{LF_INTERVAL}) {
			$apache403timeout = 0;
			undef %apache403;
		}
	}
	if ($config{LF_APACHE_401}) {
		$apache401timeout+=$duration;
		if ($apache401timeout >= $config{LF_INTERVAL}) {
			$apache401timeout = 0;
			undef %apache401;
		}
	}
	if ($config{RT_RELAY_ALERT} or $config{RT_AUTHRELAY_ALERT} or $config{RT_POPRELAY_ALERT} or $config{RT_LOCALRELAY_ALERT} or $config{RT_LOCALHOSTRELAY_ALERT}) {
		$relaytimeout+=$duration;
		if ($relaytimeout >= 3600) {
			$relaytimeout = 0;
			undef %relays;
		}
	}

	if (-e "/var/lib/csf/csf.tempconf") {
		open (my $IN, "<", "/var/lib/csf/csf.tempconf");
		flock ($IN, LOCK_SH);
		while (my $line = <$IN>) {
			chomp $line;
			if ($line =~ /^\#/) {next}
			if ($line !~ /=/) {next}
			my ($name,$value) = split (/=/,$line,2);
			$name =~ s/\s//g;
			if ($value =~ /\"(.*)\"/) {
				$value = $1;
			} else {
				&cleanup(__LINE__,"*Error* Invalid configuration line in csf.tempconf");
			}
			$config{$name} = $value;
		}
		close ($IN);
	}

	if ($config{GLOBAL_IGNORE} and -e "/var/lib/csf/csf.gignore") {
		undef @gcidrs;
		undef %gignoreips;
		undef $gcidr;
		undef $gcidr6;
		$gcidr = Net::CIDR::Lite->new;
		$gcidr6 = Net::CIDR::Lite->new;
		open (my $IN, "<", "/var/lib/csf/csf.gignore");
		flock ($IN, LOCK_SH);
		while (my $line = <$IN>) {
			chomp $line;
			if ($line =~ /^(\#|\n|\r|\s)/ or $line eq "") {next}
			my ($ip,undef) = split(/\s/,$line);
			my (undef,$iscidr) = split(/\//,$ip);
			my $v = checkip(\$ip);
			if ($v) {
				if ($iscidr) {
					push @gcidrs,$ip;
					undef $@;
					if ($v == 6) {
						eval {local $SIG{__DIE__} = undef; $gcidr6->add($ip)};
					} else {
						eval {local $SIG{__DIE__} = undef; $gcidr->add($ip)};
					}
					if ($@) {logfile("Invalid entry in GLOBAL_IGNORE: $ip")}
				} else {$gignoreips{$ip} = 1}
			}
			elsif ($ip ne "127.0.0.1") {logfile("Invalid entry in GLOBAL_IGNORE: [$ip]")}
		}
		close ($IN);
		unlink "/var/lib/csf/csf.gignore";
	}

	$count = 0;
	$0 = "lfd - scanning log files";
	undef %relayip;
	if ($config{RELAYHOSTS}) {
		open (my $IN, "<", "/etc/relayhosts");
		flock ($IN, LOCK_SH);
		while (my $ip = <$IN>) {
			chomp $ip;
			if (checkip(\$ip)) {$relayip{$ip} = 1}
		}
		close ($IN);
	}
	if ($config{DYNDNS} and $config{DYNDNS_IGNORE}) {
		open (my $IN, "<", "/var/lib/csf/csf.tempdyn");
		flock ($IN, LOCK_SH);
		while (my $ip = <$IN>) {
			chomp $ip;
			if (checkip(\$ip)) {$relayip{$ip} = 1}
		}
		close ($IN);
	}
	if ($config{GLOBAL_DYNDNS} and $config{GLOBAL_DYNDNS_IGNORE}) {
		open (my $IN, "<", "/var/lib/csf/csf.tempgdyn");
		flock ($IN, LOCK_SH);
		while (my $ip = <$IN>) {
			chomp $ip;
			if (checkip(\$ip)) {$relayip{$ip} = 1}
		}
		close ($IN);
	}

	if ($config{RESTRICT_SYSLOG} == 3) {&syslog_perms}
	foreach my $lgfile (keys %logfiles) {
		if ($lgfile eq "") {next}
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start",$lgfile,$timer)}
		my $totlines = 0;
		my @data;
		while (my $line = &getlogfile($lgfile,$count,$totlines))  {
			if ($line eq "reopen") {
				undef @data;
				last;
			} else {
				$totlines ++;
				push @data, $line;
			}
		}
		if ($config{DEBUG} >= 2) {logfile("debug: Parsing $lgfile ($totlines lines)")}
		foreach my $line (@data) {
			if (($lastline ne "") and ($line =~ /^\S+\s+\d+\s+\S+ \S+ last message repeated (\d+) times/)) {
				my $hits = $1;
				if ($hits > 100) {$hits = 100}
				for (my $x = 0;$x <$hits ;$x++) {
					&dochecks($lastline,$lgfile);
				}
			} else {
				&dochecks($line,$lgfile);
				$lastline = $line;
			}
		}
		$lastline = "";
		$count++;
		undef %psips;
		undef %blockedips;
		if ($config{DEBUG} >= 3) {$timer = &timer("stop",$lgfile,$timer)}
	}

	$0 = "lfd - processing";
	if ($config{CT_LIMIT}) {
		$cttimeout+=$duration;
		if ($cttimeout >= $config{CT_INTERVAL}) {
			$cttimeout = 0;
			&connectiontracking;
		}
	}

	if ($config{DYNDNS}) {
		$dyndnstimeout+=$duration;
		if ($dyndnstimeout >= $config{DYNDNS}) {
			$dyndnstimeout = 0;
			&dyndns;
		}
	}

	if ($config{GLOBAL_DYNDNS}) {
		$gdyndnstimeout+=$duration;
		if ($gdyndnstimeout >= $config{GLOBAL_DYNDNS_INTERVAL}) {
			$gdyndnstimeout = 0;
			&globaldyndns;
		}
	}

	if ($config{LF_GLOBAL}) {
		$globaltimeout+=$duration;
		if ($globaltimeout >= $config{LF_GLOBAL}) {
			$globaltimeout = 0;
			&global;
		}
	}

	if (scalar(keys %blocklists)) {
		$blocklisttimeout+=$duration;
		if ($blocklisttimeout >= 300) {
			$blocklisttimeout = 0;
			&blocklist;
		}
	}

	if ($config{CC_DENY} or $config{CC_ALLOW} or $config{CC_ALLOW_FILTER} or $config{CC_ALLOW_PORTS} or $config{CC_DENY_PORTS} or $config{CC_ALLOW_SMTPAUTH}) {
		$cctimeout+=$duration;
		if ($cctimeout >= 3600) {
			$cctimeout = 0;
			&countrycode;
		}
	}

	if ($config{CC_LOOKUPS}) {
		$ccltimeout+=$duration;
		if ($ccltimeout >= 3600) {
			$ccltimeout = 0;
			&countrycodelookups;
		}
	}

	if ($config{LOGSCANNER}) {
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
		my $lastrun;

		if (-e "/var/lib/csf/csf.lastlogrun") {
			my @data = slurp("/var/lib/csf/csf.lastlogrun");
			$loginterval = $lastrun = $data[0];
		}
		if ($loginterval eq "") {
			if ($config{LOGSCANNER_INTERVAL} eq "hourly") {$loginterval = $hour}
			if ($config{LOGSCANNER_INTERVAL} eq "daily") {$loginterval = $mday}
		}
		if (-e "/var/lib/csf/csf.logrun") {
			unlink "/var/lib/csf/csf.logrun";
			&logscanner($hour);
		}
		elsif ($config{LOGSCANNER_INTERVAL} eq "hourly" and $loginterval ne $hour) {
			$loginterval = $hour;
			&logscanner($hour);
		}
		elsif ($config{LOGSCANNER_INTERVAL} eq "daily" and $loginterval ne $mday) {
			$loginterval = $mday;
			&logscanner($hour);
		}

		if ($lastrun ne $loginterval) {
			$lastrun = $loginterval;
			sysopen (my $LOGRUN, "/var/lib/csf/csf.lastlogrun", O_WRONLY | O_CREAT | O_TRUNC);
			flock ($LOGRUN, LOCK_EX);
			print $LOGRUN $loginterval;
			close ($LOGRUN);
		}
	}

	if ($config{LF_INTEGRITY}) {
		$integritytimeout+=$duration;
		if ($integritytimeout >= $config{LF_INTEGRITY}) {
			$integritytimeout = 0;
			&integrity;
		}
	}

	if ($config{LF_QUEUE_ALERT}) {
		$queuetimeout+=$duration;
		if ($queuetimeout >= $config{LF_QUEUE_INTERVAL}) {
			$queuetimeout = 0;
			&queuecheck;
		}
	}

	if ($config{LF_MODSECIPDB_ALERT}) {
		$modsecipdbchecktimeout+=$duration;
		if ($modsecipdbchecktimeout >= 3600) {
			$modsecipdbchecktimeout = 0;
			&modsecipdbcheck;
		}
	}

	if ($config{LF_EXPLOIT}) {
		$exploittimeout+=$duration;
		if ($exploittimeout >= $config{LF_EXPLOIT}) {
			$exploittimeout = 0;
			&exploit;
		}
	}

	if ($config{LF_DIRWATCH}) {
		$dirwatchtimeout+=$duration;
		if (not -e "/var/lib/csf/csf.dwdisable") {
			if ($dirwatchtimeout >= $config{LF_DIRWATCH}) {
				$dirwatchtimeout = 0;
				&dirwatch;
			}
		}
	}

	if ($config{LF_DIRWATCH_FILE}) {
		$dirwatchfiletimeout+=$duration;
		if ($dirwatchfiletimeout >= $config{LF_DIRWATCH_FILE}) {
			&dirwatchfile;
			$dirwatchfiletimeout = 0;
		}
	}

	if ($config{PT_LOAD}) {
		$loadtimeout+=$duration;
		if ($loadtimeout >= $config{PT_LOAD}) {
			$loadtimeout = 0;
			&loadcheck;
		}
	}

	if ($config{PT_LIMIT}) {
		$pttimeout+=$duration;
		if ($pttimeout >= $config{PT_INTERVAL}) {
			$pttimeout = 0;
			&processtracking;
		}
	}

	if ($config{MESSENGER}) {
		unless (-e "/var/log/lfd_messenger.log") {
			open (my $OUT, ">", "/var/log/lfd_messenger.log");
			close ($OUT);
		}
		system("chown","$config{MESSENGER_USER}:$config{MESSENGER_USER}","/var/log/lfd_messenger.log");
		foreach my $key (keys %messengerips) {
			if ($messengerips{$key} > 1 and $config{"MESSENGER_${key}_IN"} ne "") {
				unless (kill(0,$messengerips{$key})) {
					&messenger($config{"MESSENGER_${key}"},$config{MESSENGER_USER},$key);
					logfile("Messenger $key Service died, restarted");
				}
			}
		}
		&messengerrecaptcha;
	}
	if ($config{UI}) {
		if ($uiip > 1 and !(kill(0,$uiip))) {
			&ui;
			logfile("Integrated UI Service died, restarted");
		}
	}
	if ($config{CLUSTER_RECVFROM}) {
		if ($clusterip > 1 and !(kill(0,$clusterip))) {
			&lfdserver;
			logfile("Cluster Service died, restarted");
		}
	}

	if ($config{AT_ALERT}) {
		$attimeout+=$duration;
		if ($attimeout >= $config{AT_INTERVAL}) {
			$attimeout = 0;
			undef %newaccounttracking;
			if ($config{AT_ALERT} == 3) {
				my ($user,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell) = getpwnam("root");
				$newaccounttracking{$user}{account} = 1;
				$newaccounttracking{$user}{passwd} = $passwd;
				$newaccounttracking{$user}{uid} = $uid;
				$newaccounttracking{$user}{gid} = $gid;
				$newaccounttracking{$user}{dir} = $dir;
				$newaccounttracking{$user}{shell} = $shell;
			} else {
				while (my ($user,$passwd,$uid,$gid,$quota,$comment,$gcos,$dir,$shell) = getpwent()) {
					if (($config{AT_ALERT} eq "2") and ($uid ne "0")) {next}
					$newaccounttracking{$user}{account} = 1;
					$newaccounttracking{$user}{passwd} = $passwd;
					$newaccounttracking{$user}{uid} = $uid;
					$newaccounttracking{$user}{gid} = $gid;
					$newaccounttracking{$user}{dir} = $dir;
					$newaccounttracking{$user}{shell} = $shell;
				}
				endpwent();
			}
			&accounttracking;
			%accounttracking = %newaccounttracking;
		}
	}

	if ($config{INTERWORX}) {
		if (slurp("/etc/csf/apf_stub.pl") ne slurp("/etc/apf/apf")) {
			&syscommand(__LINE__,"cp -af /etc/csf/apf_stub.pl /etc/apf/apf");
			&syscommand(__LINE__,"chmod 750 /etc/apf/apf");
			logfile ("InterWorx: Reapplied apf stub");
		}
	}

	&ipunblock;

	$0 = "lfd - sleeping";
	sleep ($config{LF_PARSE});

	$duration = time - $maintimer;
	if (($config{DEBUG} >= 1) and ($duration > ($config{LF_PARSE} * 10))) {
		logfile ("debug: *Performance* log parsing taking $duration seconds");
	}
	if ($config{DEBUG} >= 2) {logfile("debug: Tick: $duration [$config{LF_PARSE}]")}
}

exit;

# end main
###############################################################################
# start dochecks
sub dochecks {
	my $line = shift;
	my $lgfile = shift;
	my $timenow = time;
	my $logscanner_skip = 0;

	my ($reason, $ip, $app, $customtrigger, $customports, $customperm, $customcf) = ConfigServer::RegexMain::processline ($line,$lgfile,\%globlogs);

	my ($gip,$account,$domain) = split (/\|/,$ip,3);
	unless ($account =~ /^[a-zA-Z0-9\-\_\.\@\%\+]+$/) {
		if ($account and $config{DEBUG} >= 1) {logfile("debug: (processline) Account name [$account] is invalid")}
		$account = "";
	}
	$ip = $gip;
	if (($ip) and ($ip !~ /^127\./) and ($ip ne "::1")) {
		if (&ignoreip($ip)) {
			logfile("$reason $ip - ignored");
		} else {
			if ($blockedips{$ip}{block} or ($blockedips{$ip}{apps} =~ /\b$app\b/)) {
				if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
			} else {
				if (($app eq "pop3d" or $app eq "imapd") and $line =~ /\(auth failed, (\d+) attempts/) {
					$db{$ip}{text} .= "$line\n";
					for (1..$1) {
						$db{$ip}{count}++;
						$db{$ip}{apps} .= $app." ";
						$db{$ip}{appscount}{$app}++;
						$db{$ip}{mytime} .= "$timenow,";
						$db{$ip}{appstime}{$app} .= "$timenow,";
						$db{$ip}{domains} .= $domain." ";
					}
				} else {
					$db{$ip}{count}++;
					$db{$ip}{text} .= "$line\n";
					$db{$ip}{apps} .= $app." ";
					$db{$ip}{appscount}{$app}++;
					$db{$ip}{mytime} .= "$timenow,";
					$db{$ip}{appstime}{$app} .= "$timenow,";
					$db{$ip}{domains} .= $domain." ";
				}

				my $hits;
				my $trigger;
				my $setting;
				my @times;
				if ($customtrigger) {
					$trigger = "LF_CUSTOMTRIGGER";
					$config{$trigger} = $customtrigger;
					$config{"$trigger\_PERM"} = $customperm;
					$ports{$app} = $customports;
					$cfblocks{LF_CUSTOMTRIGGER} = $customcf;
				}
				if ($config{LF_TRIGGER}) {
					@times = split(/\,/,$db{$ip}{mytime});
					$trigger = "LF_TRIGGER";
				} else {
					@times = split(/\,/,$db{$ip}{appstime}{$app});
					if ($app eq "sshd") {$trigger = "LF_SSHD"}
					elsif ($app eq "pop3d") {$trigger = "LF_POP3D"}
					elsif ($app eq "imapd") {$trigger = "LF_IMAPD"}
					elsif ($app eq "ftpd") {$trigger = "LF_FTPD"}
					elsif ($app eq "smtpauth") {$trigger = "LF_SMTPAUTH"}
					elsif ($app eq "eximsyntax") {$trigger = "LF_EXIMSYNTAX"}
					elsif ($app eq "htpasswd") {$trigger = "LF_HTACCESS"}
					elsif ($app eq "mod_security") {$trigger = "LF_MODSEC"}
					elsif ($app eq "bind") {$trigger = "LF_BIND"}
					elsif ($app eq "suhosin") {$trigger = "LF_SUHOSIN"}
					elsif ($app eq "cpanel") {$trigger = "LF_CPANEL"}
					elsif ($app eq "directadmin") {$trigger = "LF_DIRECTADMIN"}
					elsif ($app eq "interworx") {$trigger = "LF_INTERWORX"}
					elsif ($app eq "cyberpanel") {$trigger = "LF_CYBERPANEL"}
					elsif ($app eq "cwp") {$trigger = "LF_CWP"}
					elsif ($app eq "vesta") {$trigger = "LF_VESTA"}
					elsif ($app eq "webmin") {$trigger = "LF_WEBMIN"}
					elsif ($app eq "whm") {$trigger = "LF_CPANEL"}
					elsif ($app eq "webmail") {$trigger = "LF_CPANEL"}
					elsif ($app eq "mod_qos") {$trigger = "LF_QOS"}
					elsif ($app eq "symlink") {$trigger = "LF_SYMLINK"}
					elsif ($app eq "cxs") {$trigger = "LF_CXS"}
				}

				my $newtimes;
				my $newcnt = 0;
				foreach my $time (@times) {
					if ($timenow - $time <= $config{LF_INTERVAL}) {
						$newtimes .= "$time,";
						$newcnt++;
					}
				}
				if ($config{LF_TRIGGER}) {
					$db{$ip}{count} = $newcnt;
					$db{$ip}{mytime} = $newtimes;
					$hits = $db{$ip}{count};
				} else {
					$db{$ip}{appscount}{$app} = $newcnt;
					$db{$ip}{appstime}{$app} = $newtimes;
					$hits = $db{$ip}{appscount}{$app};
				}

				if ($config{DEBUG} >= 1) {logfile("debug: $reason $ip - $hits failure(s) in the last $config{LF_INTERVAL} secs")}

				if ($hits >= $config{$trigger}) {
					my @text = split(/\n/,$db{$ip}{text});
					$db{$ip}{text} = "";
					for (-$hits..-1) {$db{$ip}{text} .= "$text[$_]\n"}
					$0 = "lfd - blocking $ip";
					&block($ip,$hits,$app,$config{"$trigger\_PERM"},$trigger,$reason);
					if ($config{LF_SELECT} and !$config{LF_TRIGGER}) {
						$db{$ip}{appscount}{$app} = 0;
						$db{$ip}{appstime}{$app} = "";
					} else {
						delete $db{$ip};
					}
					if ($cxsreputation) {
						ConfigServer::cxs::Rreport($trigger,$ip,"$reason $ip - $hits failure(s) in the last $config{LF_INTERVAL} secs",$trigger);
					}
					$0 = "lfd - scanning $lgfile";
				}

				if ($config{LF_DISTATTACK} and $account) {
					$adb{$app}{$account}{$timenow}{ip} .= "$ip,";
					$adb{$app}{$account}{$timenow}{text} .= "$line\n";
					my @accountips;
					my $text;
					foreach my $key (keys %{$adb{$app}{$account}}) {
						if ($timenow - $key <= $config{LF_INTERVAL}) {
							push @accountips, (split(/\,/,$adb{$app}{$account}{$key}{ip}));
							$text .= $adb{$app}{$account}{$key}{text};
						} else {
							delete $adb{$app}{$account}{$key};
						}
					}
					my %seen;
					my @uniqueips = grep { ! $seen{ $_ }++ } @accountips;
					if ($config{DEBUG} >= 1) {logfile("debug: $reason ".@uniqueips." ip(s) to account [$account] ".@accountips." in the last $config{LF_INTERVAL} secs")}
					if ((@accountips >= $config{$trigger}) and (@uniqueips >= $config{LF_DISTATTACK_UNIQ})) {
						delete $adb{$app}{$account};
						&blockaccount(\@uniqueips,$account,$#accountips+1,$app,$text,$config{"$trigger\_PERM"},$trigger);
					}
				}
			}
		}
	}

	if ($config{LF_DISTFTP} and ($globlogs{FTPD_LOG}{$lgfile})) {
		my ($ip, $account) = ConfigServer::RegexMain::processdistftpline ($line);
		unless ($account =~ /^[a-zA-Z0-9\-\_\.\@\%\+]+$/) {
			if ($account and $config{DEBUG} >= 1) {logfile("debug: (processdistftpline) Account name [$account] is invalid")}
			$account = "";
		}
		if ($ip and $account and ($ip !~ /^127\./) and ($ip ne "::1")) {
			if (&ignoreip($ip)) {
				if ($config{DEBUG} >= 1) {logfile("debug: Distributed FTP $ip - ignored")}
			} else {
				$adf{$account}{$timenow}{ip} .= "$ip,";
				$adf{$account}{$timenow}{text} .= "$line\n";
				my @accountips;
				my $text;
				foreach my $key (keys %{$adf{$account}}) {
					if ($timenow - $key <= $config{LF_DIST_INTERVAL}) {
						push @accountips, (split(/\,/,$adf{$account}{$key}{ip}));
						$text .= $adf{$account}{$key}{text};
					} else {
						delete $adf{$account}{$key};
					}
				}
				my %seen;
				my @uniqueips = grep { ! $seen{ $_ }++ } @accountips;
				if ($config{DEBUG} >= 1) {logfile("debug: FTP logins from ".@uniqueips." ip(s) to account [$account] ".@accountips." in the last $config{LF_INTERVAL} secs")}
				if ((@accountips >= $config{LF_DISTFTP}) and (@uniqueips >= $config{LF_DISTFTP_UNIQ})) {
					delete $adf{$account};
					&blockdistftp(\@uniqueips,$account,$#accountips+1,$text,$config{LF_DISTFTP_PERM});
				}
			}
		}
	}

	if ($config{LF_DISTSMTP} and ($globlogs{SMTPAUTH_LOG}{$lgfile})) {
		my ($ip, $account) = ConfigServer::RegexMain::processdistsmtpline ($line);
		unless ($account =~ /^[a-zA-Z0-9\-\_\.\@\%\+]+$/) {
			if ($account and $config{DEBUG} >= 1) {logfile("debug: (processdistsmtpline) Account name [$account] is invalid")}
			$account = "";
		}
		if ($ip and $account and ($ip !~ /^127\./) and ($ip ne "::1")) {
			if (&ignoreip($ip)) {
				if ($config{DEBUG} >= 1) {logfile("debug: Distributed SMTP $ip - ignored")}
			} else {
				$ads{$account}{$timenow}{ip} .= "$ip,";
				$ads{$account}{$timenow}{text} .= "$line\n";
				my @accountips;
				my $text;
				foreach my $key (keys %{$ads{$account}}) {
					if ($timenow - $key <= $config{LF_DIST_INTERVAL}) {
						push @accountips, (split(/\,/,$ads{$account}{$key}{ip}));
						$text .= $ads{$account}{$key}{text};
					} else {
						delete $ads{$account}{$key};
					}
				}
				my %seen;
				my @uniqueips = grep { ! $seen{ $_ }++ } @accountips;
				if ($config{DEBUG} >= 1) {logfile("debug: SMTP logins from ".@uniqueips." ip(s) to account [$account] ".@accountips." in the last $config{LF_INTERVAL} secs")}
				if ((@accountips >= $config{LF_DISTSMTP}) and (@uniqueips >= $config{LF_DISTSMTP_UNIQ})) {
					delete $ads{$account};
					&blockdistsmtp(\@uniqueips,$account,$#accountips+1,$text,$config{LF_DISTSMTP_PERM});
				}
			}
		}
	}

	if ($config{LF_APACHE_404} and ($globlogs{HTACCESS_LOG}{$lgfile})) {
		my ($ip) = ConfigServer::RegexMain::loginline404($line);
		if ($ip and !&ignoreip($ip)) {
			$apache404{$ip}{count}++;
			$apache404{$ip}{text} .= "$line\n";
			if ($apache404{$ip}{count} > $config{LF_APACHE_404}) {
				&disable404($ip,$apache404{$ip}{text});
				delete $apache404{$ip};
			}
		}
	}

	if ($config{LF_APACHE_403} and ($globlogs{HTACCESS_LOG}{$lgfile})) {
		my ($ip) = ConfigServer::RegexMain::loginline403($line);
		if ($ip and !&ignoreip($ip)) {
			$apache403{$ip}{count}++;
			$apache403{$ip}{text} .= "$line\n";
			if ($apache403{$ip}{count} > $config{LF_APACHE_403}) {
				&disable403($ip,$apache403{$ip}{text});
				delete $apache403{$ip};
			}
		}
	}

	if ($config{LF_APACHE_401} and ($globlogs{HTACCESS_LOG}{$lgfile})) {
		my ($ip) = ConfigServer::RegexMain::loginline401($line);
		if ($ip and !&ignoreip($ip)) {
			$apache401{$ip}{count}++;
			$apache401{$ip}{text} .= "$line\n";
			if ($apache401{$ip}{count} > $config{LF_APACHE_401}) {
				&disable401($ip,$apache401{$ip}{text});
				delete $apache401{$ip};
			}
		}
	}

	if (($config{LT_POP3D} or $config{LT_IMAPD}) and (($globlogs{POP3D_LOG}{$lgfile}) or ($globlogs{IMAPD_LOG}{$lgfile}))) {
		my ($app, $account, $ip) = ConfigServer::RegexMain::processloginline ($line);
		unless ($account =~ /^[a-zA-Z0-9\-\_\.\@\%\+]+$/) {
			if ($account and $config{DEBUG} >= 1) {logfile("debug: (processloginline) Account name [$account] is invalid")}
			$account = "";
		}
		if ($account and $loginproto{$app} and !&ignoreip($ip,1)) {
			$logins{$app}{$account}{$ip}++;
			if ($account and $config{DEBUG} >= 1) {logfile("debug: (processloginline) Account name [$account] [$ip] [$logins{$app}{$account}{$ip}]")}
			if ($logins{$app}{$account}{$ip} > $loginproto{$app}) {
				$0 = "lfd - disabling $app logins for $account";
				&logindisable($app,$ip,$logins{$app}{$account}{$ip},$account);
				delete $logins{$app}{$account}{$ip};
				$0 = "lfd - scanning $lgfile";
			}
		}
	}

	if ($config{LF_SSH_EMAIL_ALERT} and (($lgfile eq "/var/log/messages") or ($lgfile eq "/var/log/secure") or ($lgfile eq "/var/log/auth.log") or ($globlogs{SSHD_LOG}{$lgfile}))) {
		my ($account, $ip, $method) = ConfigServer::RegexMain::processsshline ($line);
		unless ($account =~ /^[a-zA-Z0-9\-\_\.\@\%\+]+$/) {
			if ($account and $config{DEBUG} >= 1) {logfile("debug: (processsshline) Account name [$account] is invalid")}
			$account = "";
		}
		if ($account and $ip and !&ignoreip($ip)) {
			&sshalert($account, $ip, $method, $line);
		}
		elsif (&ignoreip($ip)) {logfile("*SSH login* from $ip into the $account account using $method authentication - ignored")}
	}

	if ($config{LF_SU_EMAIL_ALERT} and (($lgfile eq "/var/log/messages") or ($lgfile eq "/var/log/secure") or ($lgfile eq "/var/log/auth.log") or ($globlogs{SU_LOG}{$lgfile}))) {
		my ($to, $from, $status) = ConfigServer::RegexMain::processsuline ($line);
		if (($to and $from) and ($from ne "root") and ($from ne 'root(uid=0)') and ($from ne '(uid=0)')) {
			&sualert($to, $from, $status, $line);
		}
	}

	if ($config{LF_SUDO_EMAIL_ALERT} and (($lgfile eq "/var/log/messages") or ($lgfile eq "/var/log/secure") or ($lgfile eq "/var/log/auth.log") or ($globlogs{SUDO_LOG}{$lgfile}))) {
		my ($to, $from, $status) = ConfigServer::RegexMain::processsudoline ($line);
		if (($to and $from) and ($from ne "root") and ($from ne 'root(uid=0)') and ($from ne '(uid=0)')) {
			&sudoalert($to, $from, $status, $line);
		}
	}

	if ($config{LF_CONSOLE_EMAIL_ALERT} and (($lgfile eq "/var/log/messages") or ($lgfile eq "/var/log/secure") or ($lgfile eq "/var/log/auth.log") or ($globlogs{SU_LOG}{$lgfile}))) {
		my ($status) = ConfigServer::RegexMain::processconsoleline ($line);
		if ($status) {
			&consolealert($line);
		}
	}

	if ($config{LF_CPANEL_ALERT} and ($globlogs{CPANEL_ACCESSLOG}{$lgfile})) {
		my ($ip,$user) = ConfigServer::RegexMain::processcpanelline ($line);
		unless ($user =~ /^[a-zA-Z0-9\-\_\.\@\%\+]+$/) {
			if ($user and $config{DEBUG} >= 1) {logfile("debug: (processcpanelline) Account name [$user] is invalid")}
			$user = "";
		}
		if ($ip and !&ignoreip($ip) and $user and ($cpanelalertusers{$user} or $cpanelalertusers{all})) {
			if ($cpanelalert{$ip}{$user} and (time - $cpanelalert{$ip}{$user} < 3600)) {
				$cpanelalert{$ip}{$user} = time;
			} else {
				$cpanelalert{$ip}{$user} = time;
				&cpanelalert($ip,$user, $line);
			}
		}
	}

	if ($config{LF_WEBMIN_EMAIL_ALERT} and ($globlogs{WEBMIN_LOG}{$lgfile})) {
		my ($account, $ip) = ConfigServer::RegexMain::processwebminline ($line);
		if ($account) {
			&webminalert($account,$ip, $line);
		}
	}

	if ($config{LF_SCRIPT_ALERT} and ($globlogs{SCRIPT_LOG}{$lgfile})) {
		my $path = ConfigServer::RegexMain::scriptlinecheck($line);
		if ($path ne "") {
			$scripts{$path}{cnt}++;
			if ($scripts{$path}{cnt} <= 10) {
				$scripts{$path}{mails} .= "$line\n";
			}
			if ($scripts{$path}{cnt} > $config{LF_SCRIPT_LIMIT}) {
				&scriptalert($path,$scripts{$path}{cnt},$scripts{$path}{mails});
				delete $scripts{$path};
			}
		}
	}

	if ($config{PS_INTERVAL} and ($globlogs{IPTABLES_LOG}{$lgfile})) {
		my ($ip, $port) = ConfigServer::RegexMain::pslinecheck($line);
		if ($port and $ip and !&ignoreip($ip)) {
			my $hit = 0;
			foreach my $ports (split(/\,/,$config{PS_PORTS})) {
				if ($ports =~ /\:/) {
					my ($start,$end) = split(/\:/,$ports);
					if ($port >= $start and $port <= $end) {$hit = 1}
				}
				elsif ($port == $ports) {$hit = 1}
				if ($hit) {last}
			}
			if ($hit) {
				$portscans{$ip}{count}++;
				$portscans{$ip}{blocks} .= "$line\n";
				$portscans{$ip}{ports}{$port} = 1;
				if ($portscans{$ip}{count} > $config{PS_LIMIT}) {
					if ($config{PS_DIVERSITY} > 1 and ($config{PS_DIVERSITY} > scalar (keys %{$portscans{$ip}{ports}}))) {
						if ($config{DEBUG} >= 1) {logfile("debug: *Port Scan* detected from $ip - but denied by PS_DIVERSITY")}
					} else {
						if ($psips{$ip}) {
							if ($config{DEBUG} >= 1) {logfile("debug: *Port Scan* detected from $ip - already blocked")}
							delete $portscans{$ip};
						} else {
							&portscans($ip,$portscans{$ip}{count},$portscans{$ip}{blocks});
							$psips{$ip} = 1;
							delete $portscans{$ip};
						}
					}
				}
			}
		}
		elsif (($config{DEBUG} >= 1) and $port and $ip and &ignoreip($ip)) {
			logfile("debug: PS count for $ip - ignored");
		}
	}

	if ($config{UID_INTERVAL} and ($globlogs{IPTABLES_LOG}{$lgfile})) {
		my ($port, $uid) = ConfigServer::RegexMain::uidlinecheck($line);
		if ($port and $uid and !$uidignore{$uid}) {
			my $hit = 0;
			foreach my $ports (split(/\,/,$config{UID_PORTS})) {
				if ($ports =~ /\:/) {
					my ($start,$end) = split(/\:/,$ports);
					if ($port >= $start and $port <= $end) {$hit = 1}
				}
				elsif ($port == $ports) {$hit = 1}
				if ($hit) {last}
			}
			if ($hit) {
				$uidscans{$uid}{count}++;
				$uidscans{$uid}{blocks} .= "$line\n";
				if ($uidscans{$uid}{count} > $config{UID_LIMIT}) {
					&uidscans($uid,$uidscans{$uid}{count},$uidscans{$uid}{blocks});
					delete $uidscans{$uid};
				}
			}
		}
		elsif (($config{DEBUG} >= 1) and $port and $uid and $uidignore{$uid}) {
			logfile("debug: UID count for $uid - ignored");
		}
	}

	if ($config{ST_ENABLE} and ($globlogs{IPTABLES_LOG}{$lgfile})) {
		if (ConfigServer::RegexMain::statscheck($line)) {
			&stats($line,"iptables");
		}
	}

	if ($config{SYSLOG_CHECK} and $sys_syslog and $syslogcheckcode and ($globlogs{SYSLOG_LOG}{$lgfile})) {
		if (ConfigServer::RegexMain::syslogcheckline($line,$syslogcheckcode)) {
			if ($config{DEBUG} >= 2) {logfile("debug: SYSLOG_CHECK match [$syslogcheckcode]")}
			$syslogcheckcode = "";
			$logscanner_skip = 1;
		}
	}

	if ($config{PORTKNOCKING} and $config{PORTKNOCKING_ALERT} and ($globlogs{IPTABLES_LOG}{$lgfile})) {
		my ($ip, $port) = ConfigServer::RegexMain::portknockingcheck($line);
		if ($port and $ip and !&ignoreip($ip)) {
			&portknocking($ip, $port);
		}
	}

	if ($config{LOGSCANNER} and $logscannerfiles{$lgfile} and !$logscanner_skip) {
		my $hit = 1;
		foreach my $regex (@logignore) {
			if ($line =~ /$regex/) {
				$hit = 0;
				last;
			}
		}
		if ($hit) {
			unless (-e "/var/lib/csf/csf.logmax") {
				sysopen (my $LOGTEMP,"/var/lib/csf/csf.logtemp", O_RDWR | O_CREAT);
				flock ($LOGTEMP, LOCK_EX);
				my @data = <$LOGTEMP>;
				close ($LOGTEMP);
				if (@data > $config{LOGSCANNER_LINES}) {
					open (my $OUT,">","/var/lib/csf/csf.logmax");
					close ($OUT);
				} else {
					sysopen (my $LOGTEMP,"/var/lib/csf/csf.logtemp", O_WRONLY | O_APPEND | O_CREAT);
					flock ($LOGTEMP, LOCK_EX);
					print $LOGTEMP "$lgfile|$line\n";
					close ($LOGTEMP);
				}
			}
		}
	}

	if ((($config{RT_RELAY_ALERT} or $config{RT_AUTHRELAY_ALERT} or $config{RT_POPRELAY_ALERT} or $config{RT_LOCALRELAY_ALERT} or $config{RT_LOCALHOSTRELAY_ALERT})) and ($globlogs{SMTPRELAY_LOG}{$lgfile})) {
		my ($ip,$check) = ConfigServer::RegexMain::relaycheck($line);
		if ($ip) {
			if ($check eq "RELAY" and !$relays{$ip}{check}) {
				open (my $RELAYHOSTS, "<", "/etc/relayhosts");
				flock ($RELAYHOSTS, LOCK_SH);
				my @relayhosts = <$RELAYHOSTS>;
				close ($RELAYHOSTS);
				chomp @relayhosts;
				if (grep {$_ =~ /^$ip$/} @relayhosts) {$check = "POPRELAY"}

				open (my $ALWAYSRELAY, "<", "/etc/alwaysrelay");
				flock ($ALWAYSRELAY, LOCK_SH);
				@relayhosts = <$ALWAYSRELAY>;
				close ($ALWAYSRELAY);
				chomp @relayhosts;
				if (grep {$_ =~ /^$ip$/} @relayhosts) {$check = "POPRELAY"}
			}
			if ($ips{$ip} or $ipscidr->find($ip) or $ipscidr6->find($ip)) {$check = "LOCALHOSTRELAY"}
			if ($config{ST_SYSTEM}) {
				sysopen (my $EMAIL, "/var/lib/csf/stats/email", O_RDWR | O_CREAT);
				flock ($EMAIL, LOCK_EX);
				my $stats = <$EMAIL>;
				chomp $stats;
				my ($sent,$recv) = split(/\:/,$stats);
				if ($check eq "RELAY") {$recv++} else {$sent++}
				seek ($EMAIL, 0, 0);
				truncate ($EMAIL, 0);
				print $EMAIL "$sent:$recv";
				close ($EMAIL);
			}
		}
		if ($ip and ($ip ne "mailnull") and ($ip ne "root") and (!$rtignore{$ip})) {
			my $tline = $line;
			$tline =~ s/".*"/""/g;
			my $start = 0;
			my $cnt = 0;
			foreach my $item (split(/\s+/,$tline)) {
					if ($item eq "for") {$start = 1 ; next}
					if ($start and ($item =~ /\@/)) {$cnt++} else {$start = 0}
			}
			if ($cnt > 0) {
				$relays{$ip}{cnt}+=$cnt;
			} else {
				$relays{$ip}{cnt}++;
			}
			if ($config{DEBUG} >= 1) {logfile("debug: RT\_$check\_LIMIT detected from $ip, count = $relays{$ip}{cnt}")}

			unless ($relays{$ip}{check}) {$relays{$ip}{check} = $check}

			my $mailcnt = 0;
			foreach my $mail (split(/\n/,$relays{$ip}{mails})) {$mailcnt++}
			if ($mailcnt < 10) {
				$relays{$ip}{mails} .= "$line\n";
			}

			if (($relays{$ip}{cnt} > $config{"RT\_$check\_LIMIT"}) and ($config{"RT\_$check\_ALERT"})) {
				if (($check eq "LOCALHOSTRELAY") or (!&ignoreip($ip))) {
					&relayalert($ip,$relays{$ip}{cnt},$relays{$ip}{check},$relays{$ip}{mails});
					delete $relays{$ip};
				}
			}
		}
		elsif (($config{DEBUG} >= 1) and $ip and $rtignore{$ip}) {
			logfile("debug: RT\_$check\_LIMIT detected from $ip - ignored");
		}
	}
	return;
}
# end dochecks
###############################################################################
# start getlogfile
sub getlogfile {
	my $logfile = shift;
	my $lfn = shift;
	my $totlines = shift;
    my $ino;
	my $size;
    my $line;
	my $count;

    if (!defined($lffd[$lfn]))  {
		if (&openlogfile($logfile,$lfn)) {return undef}
    }

    (undef, $ino, undef, undef, undef, undef, undef, $size, undef) = stat($logfile);

    if ($ino != $lfino[$lfn])  {
		logfile("$logfile rotated. Reopening log file");
		if (&openlogfile($logfile,$lfn)) {return undef}
	    return "reopen";
    }

	if ($size < $lfsize[$lfn])  {
		logfile("$logfile has been reset. Reopening log file");
		if (&openlogfile($logfile,$lfn)) {return undef}
	    return "reopen";
    }

	$lffd[$lfn]->clearerr();
	$line = readline($lffd[$lfn]);

	if ($totlines > ($config{LF_PARSE} * 1000)) {
		my $text = "*Error* Log line flooding/looping in $logfile. Reopening log file";
		logfile("$text");
		if ($config{LOGFLOOD_ALERT}) {
			my @alert = slurp("/usr/local/csf/tpl/logfloodalert.txt");
			my @message;
			foreach my $line (@alert) {
				$line =~ s/\[text\]/$text/ig;
				push @message, $line;
			}
			ConfigServer::Sendmail::relay("", "", @message);
		}
		if (&openlogfile($logfile,$lfn)) {return undef}
	    return "reopen";
	}
	
	chomp $line;
    if ($line)  {
		$lfsize[$lfn] = $size;
		return $line;
    }

    return undef;
}
# end getlogfile
###############################################################################
# start openlogfile
sub openlogfile {
	my $logfile = shift;
	my $lfn = shift;

    if (defined($lffd[$lfn]))  {
		close($lffd[$lfn]);
		delete($lffd[$lfn]);
	}

	sysopen ($lffd[$lfn], $logfile, O_RDONLY | O_NONBLOCK);
	if (!defined($lffd[$lfn]))  {
		logfile("*Error* Cannot open $logfile");
		return 1;
	}
	if (seek($lffd[$lfn], 0, 2) == -1)  {
		logfile("*Error* Cannot seek to end of $logfile");
		return 1;
	}

	logfile("Watching $logfile...");
	(undef, $lfino[$lfn], undef, undef, undef, undef, undef, $lfsize[$lfn], undef) = stat($lffd[$lfn]);

	return 0;
}
# end openlogfile
###############################################################################
# start globlog
sub globlog {
	my $setting = shift;
	if ($config{$setting} =~ /\*|\?|\[/) {
		foreach my $log (glob $config{$setting}) {
			$globlogs{$setting}{$log} = 1;
			$logfiles{$log} = 1;
		}
	} else {
		$globlogs{$setting}{$config{$setting}} = 1;
		$logfiles{$config{$setting}} = 1;
	}
	return;
}
# end globlog
###############################################################################
# start lockhang
sub lockhang {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","lockhang",$timer)}
		$0 = "lfd - (child) checking for lock hang";

		eval {
			local $SIG{__DIE__} = undef;
			local $SIG{'ALRM'} = sub {die};
			alarm(10);
			sysopen (my $COMMANDLOCK, "/var/lib/csf/lock/command.lock", O_RDWR | O_CREAT) or logfile("open: $!");
			flock ($COMMANDLOCK, LOCK_EX) or logfile("lock: $!");
			close ($COMMANDLOCK);
			alarm(0);
		};
		alarm(0);
		if ($@) {
			sysopen (my $COMMANDLOCK, "/var/lib/csf/lock/command.lock", O_RDWR | O_CREAT);
			flock ($COMMANDLOCK, LOCK_SH);
			my $pid = <$COMMANDLOCK>;
			chomp $pid;
			close ($COMMANDLOCK);
			if ($pid == $$) {
				logfile("*Hanging Lock* by main lfd process found for /var/lib/csf/lock/command.lock - restarting lfd");
				open (my $LFDOUT, ">", "/var/lib/csf/lfd.restart");
				close ($LFDOUT);
			} else {
				kill (9, $pid);
				logfile("*Hanging Lock* by $pid found for /var/lib/csf/lock/command.lock - terminated");
			}
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","lockhang",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end lockhang
###############################################################################
# start syslog_init
sub syslog_init {
	local $SIG{CHLD} = 'DEFAULT';
	my %syslogusers;
	my @entries = slurp("/etc/csf/csf.syslogusers");
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
		if ($line =~ /^[a-zA-Z0-9]+([\_\s\-\.]?[a-zA-Z0-9])*$/) {$syslogusers{$line} = 1}
	}

	$sysloggid = getgrnam($config{RESTRICT_SYSLOG_GROUP});
	unless ($sysloggid) {&syscommand(__LINE__,"/usr/sbin/groupadd","-r",$config{RESTRICT_SYSLOG_GROUP})}
	$sysloggid = getgrnam($config{RESTRICT_SYSLOG_GROUP});
	unless ($sysloggid) {
		logfile("RESTRICT_SYSLOG: *Error* Failed to create group: [$config{RESTRICT_SYSLOG_GROUP}], RESTRICT_SYSLOG disabled");
		$config{RESTRICT_SYSLOG} = 0;
		return;
	}

	my (undef,undef,$gid,$members) = getgrgid($sysloggid);
	foreach my $name (split(/\s+/,$members)) {$syslogusers{$name} = 0}
	foreach my $name (keys %syslogusers) {
		if ($syslogusers{$name} and getpwnam($name) ne "") {
			&syscommand(__LINE__,"/usr/sbin/usermod","-a","-G",$config{RESTRICT_SYSLOG_GROUP},$name);
			if ($config{DEBUG} >= 1) {logfile("debug: RESTRICT_SYSLOG: User $name added to group $config{RESTRICT_SYSLOG_GROUP}")}
		}
	}
	return;
}
# end syslog_init
###############################################################################
# start syslog_perms
sub syslog_perms {
	my $newpid = 1;
	my @socketids;
	my @sockets;
	if (-S "/dev/log") {push @sockets, "/dev/log"}
	if (-S "/usr/share/cagefs-skeleton/dev/log") {push @sockets, "/usr/share/cagefs-skeleton/dev/log"}

	if ($syslogpid) {
		if (readlink("/proc/$syslogpid/exe") =~ m[^(/sbin/syslog)|(/sbin/rsyslog)|(/usr/sbin/syslog)|(/usr/sbin/rsyslog)]) {$newpid = 0}
	}

	if ($newpid) {
		opendir (PROCDIR, "/proc");
		while (my $pid = readdir(PROCDIR)) {
			if ($pid !~ /^\d+$/) {next}
			my $exe = readlink("/proc/$pid/exe");
			if ($exe =~ m[^(/sbin/syslog)|(/sbin/rsyslog)|(/usr/sbin/syslog)|(/usr/sbin/rsyslog)]) {
				$syslogpid = $pid;
				last;
			}
		}
		closedir (PROCDIR);
	}

	if ($syslogpid) {
		opendir (DIR, "/proc/$syslogpid/fd/");
		while (my $file = readdir(DIR)) {
			if (readlink("/proc/$syslogpid/fd/$file") =~/^socket:\[(\d*)\]$/) {push @socketids,$1}
		}
		closedir (DIR);
		if (@socketids) {
			open (my $IN, "<", "/proc/net/unix");
			flock ($IN, LOCK_SH);
			while (my $line = <$IN>) {
				chomp $line;
				my @data = split(/\s+/,$line,8);
				foreach my $socket (@socketids) {
					if (($socket == $data[6]) and ($data[7] ne "/dev/log") and ($data[7] ne "/usr/share/cagefs-skeleton/dev/log")) {push @sockets,$data[7]}
				}
			}
			close ($IN);
		} else {
			if ($config{DEBUG} >= 2) {logfile("debug: RESTRICT_SYSLOG: *Error* No additional unix sockets found")}
		}
	} else {
		if ($config{DEBUG} >= 1) {logfile("debug: RESTRICT_SYSLOG: *Error* syslog/rsyslog process not found")}
	}

	if (@sockets) {
		my $fixme = 0;
		foreach my $socket (@sockets) {
			if (-S $socket) {
				my (undef,undef,$mode,undef,$uid,$gid,undef) = stat($socket);
				$mode = sprintf("%04o",$mode & oct("07777"));
				if ($gid != $sysloggid or $mode ne "0660") {
					$fixme = 1;
					last;
				}
			}
		}
		if ($fixme) {
			chown (-1,$sysloggid,@sockets);
			chmod (0660, @sockets);
			my $count = 0;
			logfile("RESTRICT_SYSLOG: Unix socket permissions reapplied. Reopening log files...");
			foreach my $lgfile (keys %logfiles) {
				&openlogfile($lgfile,$count);
				$count++;
			}
			if ($config{DEBUG} >= 1) {logfile("debug: RESTRICT_SYSLOG: Fixed socket ownership/permissions")}
		}
	} else {
			logfile("RESTRICT_SYSLOG: *Error* No matching unix sockets found");
			return;
	}
	return;
}
# end syslog_perms
###############################################################################
# start block
sub block {
	my $ip = shift;
	my $ipcount = shift;
	my $app = shift;
	my $temp = shift;
	my $active = shift;
	my $reason = shift;
	my $ipc = $ipcount;

	my $text = $db{$ip}{text};
	my $apps = $db{$ip}{apps};
	my $domains = $db{$ip}{domains};
	unless ($config{LF_TRIGGER}) {$apps = $app}

	$blockedips{$ip}{block} = 1;
	$blockedips{$ip}{apps} .= "$app\,";
	$text =~ s/\n+/\n/g;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","block",$timer)}
		my %logapps;
		my $apptext;
		foreach my $app (split(/ /,$apps)) {$logapps{$app} = 1}
		foreach my $key (keys %logapps) {
			if ($apptext eq "") {$apptext = $key} else {$apptext .= ",$key"}
		}
		my $perm = 1;
		if ($temp > 1) {$perm = 0}

		$0 = "lfd - (child) blocking $ip";

		my $tip = iplookup($ip);
		my $failtext = "Login failure/trigger from";
		if (keys %logapps == 1) {$failtext = $reason}

		my $cfid;
		if ($config{CF_ENABLE} and $cfblocks{$active}) {
			$perm = 0;
			$temp = $config{CF_TEMP};
			&cloudflare("deny",$ip,$config{CF_BLOCK},$domains);
			$cfid = " (CF_ENABLE)";
		}
		if ($config{PT_SSHDKILL} and $logapps{sshd}) {ConfigServer::KillSSH::find($ip,$ports{sshd})}

		my $blocked = 0;
		if ($config{LF_SELECT} and !$config{LF_TRIGGER}) {
			if (&ipblock($perm,"($apptext) $failtext $tip: $ipcount in the last $config{LF_INTERVAL} secs$cfid",$ip,$ports{$app},"in",$temp,0,$text,$active)) {
				if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
			} else {$blocked = 1}
		} else {
			if (&ipblock($perm,"($apptext) $failtext $tip: $ipcount in the last $config{LF_INTERVAL} secs$cfid",$ip,"","inout",$temp,0,$text,$active)) {
				if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
			} else {$blocked = 1}
		}

		if ($blocked) {
			if ($config{LF_EMAIL_ALERT} and ($perm or (!$perm and $config{LF_TEMP_EMAIL_ALERT}))) {
				$0 = "lfd - (child) sending alert email for $ip";

				my @alert = slurp("/usr/local/csf/tpl/alert.txt");
				my $block = "Temporary Block for $temp seconds [$active]";
				if ($perm) {$block = "Permanent Block [$active]"}

				my $allowip = &allowip($ip);
				if ($allowip == 1) {$block .= " (IP match in csf.allow, block may not work)"}
				if ($allowip == 2) {$block .= " (IP match in GLOBAL_ALLOW, block may not work)"}

				my @message;
				foreach my $line (@alert) {
					$line =~ s/\[ip\]/$tip/ig;
					$line =~ s/\[ipcount\]/$ipcount \($apptext\)/ig;
					$line =~ s/\[iptick\]/$config{LF_INTERVAL}/ig;
					$line =~ s/\[block\]/$block/ig;
					$line =~ s/\[text\]/$text/ig;
					push @message, $line;
				}
				ConfigServer::Sendmail::relay("", "", @message);

				if ($config{DEBUG} >= 1) {logfile("debug: alert email sent for $ip")}
			}

			if ($config{X_ARF}) {
				$0 = "lfd - (child) sending X-ARF email for $ip";

				my @alert = slurp("/usr/local/csf/tpl/x-arf.txt");
				my @message;
				my $rfc3339 = strftime('%Y-%m-%dT%H:%M:%S%z',localtime);
				my $boundary = time;
				my $reportedfrom = "root\@$hostname";
				if ($config{X_ARF_TO}) {$config{LF_ALERT_TO} = $config{X_ARF_TO}}
				if ($config{X_ARF_FROM}) {$config{LF_ALERT_FROM} = $config{X_ARF_FROM}; $reportedfrom = $config{X_ARF_FROM}}
				my $iptype = "ipv".checkip(\$ip);
				my $abuseto = "";
				my $abusemsg = "";

				if ($abuseip) {
					($abuseto, $abusemsg) = abuseip($ip);
					if ($abuseto eq "") {
						$abusemsg = "";
					}
					elsif ($config{X_ARF_ABUSE} and $config{X_ARF_FROM}) {
						if ($config{LF_ALERT_TO}) {
							$config{LF_ALERT_TO} .= ",".$abuseto;
						} else {
							$config{LF_ALERT_TO} = "root,".$abuseto;
						}
					}
				}

				foreach my $line (@alert) {
					$line =~ s/\[ip\]/$ip/ig;
					$line =~ s/\[abuseip\]/$abusemsg/ig;
					$line =~ s/\[iptype\]/$iptype/ig;
					$line =~ s/\[tip\]/$tip/ig;
					$line =~ s/\[ipcount\]/$ipc/ig;
					$line =~ s/\[iptick\]/$config{LF_INTERVAL}/ig;
					$line =~ s/\[service\]/$app/ig;
					$line =~ s/\[csfversion\]/$version/ig;
					$line =~ s/\[reportedfrom\]/$reportedfrom/ig;
					$line =~ s/\[reportedid\]/$boundary\@$hostname/ig;
					$line =~ s/\[boundary\]/$boundary/ig;
					$line =~ s/\[text\]/$text/ig;
					$line =~ s/\[RFC3339\]/$rfc3339/ig;
					push @message, $line;
				}
				ConfigServer::Sendmail::relay($config{LF_ALERT_TO}, $config{LF_ALERT_FROM}, @message);

				if ($config{DEBUG} >= 1) {logfile("debug: X-ARF email sent for $ip")}
			}
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","block",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end block
###############################################################################
# start blockaccount
sub blockaccount {
	my $ipa = shift;
	my @ips = @$ipa;
	my $account = shift;
	my $ipcount = shift;
	my $app = shift;
	my $text = shift;
	my $temp = shift;
	my $trigger = shift;

	foreach my $ip (@ips) {
		$blockedips{$ip}{block} = 1;
		$blockedips{$ip}{apps} .= "$app\,";
	}

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","blockaccount",$timer)}
		my $perm = 1;
		if ($temp > 1) {$perm = 0}

		$text .= "\nIP Addresses Blocked:\n\n";
		foreach my $ip (@ips) {
			$0 = "lfd - (child) blocking $ip";

			if ($config{PT_SSHDKILL} and $app eq "sshd") {ConfigServer::KillSSH::find($ip,$ports{sshd})}

			my $tip = iplookup($ip);
			if ($config{LF_SELECT} and !$config{LF_TRIGGER}) {
				if (&ipblock($perm,"$tip, $ipcount distributed $app attacks on account [$account] in the last $config{LF_INTERVAL} secs",$ip,$ports{$app},"in",$temp,0,$text,"LF_DISTATTACK")) {
					if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
				}
			} else {
				if (&ipblock($perm,"$tip, $ipcount distributed $app attacks on account [$account] in the last $config{LF_INTERVAL} secs",$ip,"","inout",$temp,0,$text,"LF_DISTATTACK")) {
					if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
				}
			}
			$text .= "$tip\n";
			if ($cxsreputation) {
				ConfigServer::cxs::Rreport($trigger,$ip,"$ipcount distributed $trigger attacks in the last $config{LF_INTERVAL} secs",$trigger);
			}
		}

		if ($config{LF_EMAIL_ALERT}) {
			my @alert = slurp("/usr/local/csf/tpl/alert.txt");
			my $block = "Temporary Block for $temp seconds [LF_DISTATTACK]";
			if ($perm) {$block = "Permanent Block [LF_DISTATTACK]"}

			my @message;
			foreach my $line (@alert) {
				$line =~ s/\[ip\]/distributed $app attack on account [$account]/ig;
				$line =~ s/\[ipcount\]/$ipcount/ig;
				$line =~ s/\[iptick\]/$config{LF_INTERVAL}/ig;
				$line =~ s/\[block\]/$block/ig;
				$line =~ s/\[text\]/$text/ig;
				push @message, $line;
			}
			ConfigServer::Sendmail::relay("", "", @message);
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","blockaccount",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end blockaccount
###############################################################################
# start blockdistftp
sub blockdistftp {
	my $ipa = shift;
	my @ips = @$ipa;
	my $account = shift;
	my $ipcount = shift;
	my $text = shift;
	my $temp = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","blockdistftp",$timer)}
		my $perm = 1;
		if ($temp > 1) {$perm = 0}

		$text .= "\nIP Addresses Blocked:\n\n";
		foreach my $ip (@ips) {
			$0 = "lfd - (child) blocking $ip";
			my $tip = iplookup($ip);
			if (&ipblock($perm,"$tip, $ipcount distributed FTP Logins on account [$account] in the last $config{LF_DIST_INTERVAL} secs",$ip,"","inout",$temp,0,$text,"LF_DISTFTP")) {
				if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
			}
			$text .= "$tip\n";
		}

		if ($config{LF_DISTFTP_ALERT}) {
			my @alert = slurp("/usr/local/csf/tpl/alert.txt");
			my $block = "Temporary Block for $temp seconds [LF_DISTFTP]";
			if ($perm) {$block = "Permanent Block [LF_DISTFTP]"}

			my @message;
			foreach my $line (@alert) {
				$line =~ s/\[ip\]/distributed FTP Logins on account [$account]/ig;
				$line =~ s/\[ipcount\]/$ipcount/ig;
				$line =~ s/\[iptick\]/$config{LF_INTERVAL}/ig;
				$line =~ s/\[block\]/$block/ig;
				$line =~ s/\[text\]/$text/ig;
				push @message, $line;
			}
			ConfigServer::Sendmail::relay("", "", @message);
		}

		if ($config{LF_DIST_ACTION} and -e $config{LF_DIST_ACTION} and -x $config{LF_DIST_ACTION}) {
			$0 = "lfd - (child) running LF_DIST_ACTION";
			system($config{LF_DIST_ACTION},"LF_DISTFTP",$account,$text);
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","blockdistftp",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end blockdistftp
###############################################################################
# start blockdistsmtp
sub blockdistsmtp {
	my $ipa = shift;
	my @ips = @$ipa;
	my $account = shift;
	my $ipcount = shift;
	my $text = shift;
	my $temp = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","blockdistsmtp",$timer)}
		my $perm = 1;
		if ($temp > 1) {$perm = 0}

		$text .= "\nIP Addresses Blocked:\n\n";
		foreach my $ip (@ips) {
			$0 = "lfd - (child) blocking $ip";
			my $tip = iplookup($ip);
			if (&ipblock($perm,"$tip, $ipcount distributed SMTP Logins on account [$account] in the last $config{LF_DIST_INTERVAL} secs",$ip,"","inout",$temp,0,$text,"LF_DISTSMTP")) {
				if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
			}
			$text .= "$tip\n";
		}

		if ($config{LF_DISTSMTP_ALERT}) {
			my @alert = slurp("/usr/local/csf/tpl/alert.txt");
			my $block = "Temporary Block for $temp seconds [LF_DISTSMTP]";
			if ($perm) {$block = "Permanent Block [LF_DISTSMTP]"}

			my @message;
			foreach my $line (@alert) {
				$line =~ s/\[ip\]/distributed SMTP Logins on account [$account]/ig;
				$line =~ s/\[ipcount\]/$ipcount/ig;
				$line =~ s/\[iptick\]/$config{LF_INTERVAL}/ig;
				$line =~ s/\[block\]/$block/ig;
				$line =~ s/\[text\]/$text/ig;
				push @message, $line;
			}
			ConfigServer::Sendmail::relay("", "", @message);
		}

		if ($config{LF_DIST_ACTION} and -e $config{LF_DIST_ACTION} and -x $config{LF_DIST_ACTION}) {
			$0 = "lfd - (child) running LF_DIST_ACTION";
			system($config{LF_DIST_ACTION},"LF_DISTSMTP",$account,$text);
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","blockdistsmtp",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end blockdistsmtp
###############################################################################
# start disable404
sub disable404 {
	my $ip = shift;
	my $text = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","disable404",$timer)}

		my $tip = iplookup($ip);
		my $perm = 1;
		if ($config{LF_APACHE_404_PERM} > 1) {$perm = 0}
		if (&ipblock($perm,"$tip, more than $config{LF_APACHE_404} Apache 404 hits in the last $config{LF_INTERVAL} secs",$ip,$ports{mod_security},"in",$config{LF_APACHE_404_PERM},0,"","LF_APACHE_404")) {
			if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
		} else {
			if ($config{LT_EMAIL_ALERT}) {
				$0 = "lfd - (child) sending alert email for $ip";

				my @alert = slurp("/usr/local/csf/tpl/alert.txt");
				my $block = "Temporary Block for $config{LF_APACHE_404_PERM} seconds [LF_APACHE_404]";
				if ($perm) {$block = "Permanent Block [LF_APACHE_404]"}
				my @message;
				foreach my $line (@alert) {
					$line =~ s/\[ip\]/$tip/ig;
					$line =~ s/\[ipcount\]/$config{LF_APACHE_404}/ig;
					$line =~ s/\[iptick\]/$config{LF_INTERVAL}/ig;
					$line =~ s/\[block\]/$block/ig;
					$line =~ s/\[text\]/$text/ig;
					push @message, $line;
				}
				ConfigServer::Sendmail::relay("", "", @message);
			}
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","disable404",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end disable404
###############################################################################
# start disable403
sub disable403 {
	my $ip = shift;
	my $text = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","disable403",$timer)}

		my $tip = iplookup($ip);
		my $perm = 1;
		if ($config{LF_APACHE_403_PERM} > 1) {$perm = 0}
		if (&ipblock($perm,"$tip, more than $config{LF_APACHE_403} Apache 403 hits in the last $config{LF_INTERVAL} secs",$ip,$ports{mod_security},"in",$config{LF_APACHE_403_PERM},0,"","LF_APACHE_403")) {
			if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
		} else {
			if ($config{LT_EMAIL_ALERT}) {
				$0 = "lfd - (child) sending alert email for $ip";

				my @alert = slurp("/usr/local/csf/tpl/alert.txt");
				my $block = "Temporary Block for $config{LF_APACHE_403_PERM} seconds [LF_APACHE_403]";
				if ($perm) {$block = "Permanent Block [LF_APACHE_403]"}
				my @message;
				foreach my $line (@alert) {
					$line =~ s/\[ip\]/$tip/ig;
					$line =~ s/\[ipcount\]/$config{LF_APACHE_403}/ig;
					$line =~ s/\[iptick\]/$config{LF_INTERVAL}/ig;
					$line =~ s/\[block\]/$block/ig;
					$line =~ s/\[text\]/$text/ig;
					push @message, $line;
				}
				ConfigServer::Sendmail::relay("", "", @message);
			}
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","disable403",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end disable403
###############################################################################
# start disable401
sub disable401 {
	my $ip = shift;
	my $text = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","disable401",$timer)}

		my $tip = iplookup($ip);
		my $perm = 1;
		if ($config{LF_APACHE_401_PERM} > 1) {$perm = 0}
		if (&ipblock($perm,"$tip, more than $config{LF_APACHE_401} Apache 401 hits in the last $config{LF_INTERVAL} secs",$ip,$ports{mod_security},"in",$config{LF_APACHE_401_PERM},0,"","LF_APACHE_401")) {
			if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
		} else {
			if ($config{LT_EMAIL_ALERT}) {
				$0 = "lfd - (child) sending alert email for $ip";

				my @alert = slurp("/usr/local/csf/tpl/alert.txt");
				my $block = "Temporary Block for $config{LF_APACHE_401_PERM} seconds [LF_APACHE_401]";
				if ($perm) {$block = "Permanent Block [LF_APACHE_401]"}
				my @message;
				foreach my $line (@alert) {
					$line =~ s/\[ip\]/$tip/ig;
					$line =~ s/\[ipcount\]/$config{LF_APACHE_401}/ig;
					$line =~ s/\[iptick\]/$config{LF_INTERVAL}/ig;
					$line =~ s/\[block\]/$block/ig;
					$line =~ s/\[text\]/$text/ig;
					push @message, $line;
				}
				ConfigServer::Sendmail::relay("", "", @message);
			}
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","disable401",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end disable401
###############################################################################
# start logindisable
sub logindisable {
	my $app = shift;
	my $ip = shift;
	my $logins = shift;
	my $account = shift;
	my $trigger = "LT_".uc($app);

	my $port = "110";
	my $sport = "995";
	if ($app eq "imapd") {$port = "143"; $sport = "993"}

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","logindisable",$timer)}
		my $flush = (3600-$logintimeout{$app});

		my $tip = iplookup($ip);
		if ($config{LT_SKIPPERMBLOCK}) {$config{LF_PERMBLOCK} = 0}
		if (&ipblock(0,"$app - $logins logins in $logintimeout{$app} secs from $tip for $account exceeds $loginproto{$app}/hour",$ip,"$port,$sport","in",$flush,0,"",$trigger)) {
			if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
		} else {
			if ($config{LT_EMAIL_ALERT}) {
				$0 = "lfd - (child) sending alert email for $account";

				my @alert = slurp("/usr/local/csf/tpl/tracking.txt");
				my @message;
				foreach my $line (@alert) {
					$line =~ s/\[ip\]/$tip/ig;
					$line =~ s/\[app\]/$app/ig;
					$line =~ s/\[logins\]/$logins/ig;
					$line =~ s/\[account\]/$account/ig;
					$line =~ s/\[timeout\]/$logintimeout{$app}/ig;
					$line =~ s/\[flush\]/$flush/ig;
					$line =~ s/\[rate\]/$loginproto{$app}/ig;
					push @message, $line;
				}
				ConfigServer::Sendmail::relay("", "", @message);

				logfile("tracking email sent for $account");
			}
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","logindisable",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end logindisable
###############################################################################
# start portscans
sub portscans {
	my $ip = shift;
	my $count = shift;
	my $blocks = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","portscans",$timer)}

		my $tip = iplookup($ip);
		if (&ipblock($config{PS_PERMANENT},"*Port Scan* detected from $tip. $count hits in the last $pstimeout seconds",$ip,"","in",$config{PS_BLOCK_TIME},0,$blocks,"PS_LIMIT")) {
			if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
		} else {
			if ($config{PS_EMAIL_ALERT}) {
				$0 = "lfd - (child) sending alert email for $ip";

				my @alert = slurp("/usr/local/csf/tpl/portscan.txt");
				my $block = "Temporary Block for $config{PS_BLOCK_TIME} seconds [PS_LIMIT]";
				if ($config{PS_PERMANENT}) {$block = "Permanent Block [PS_LIMIT]"}

				my $allowip = &allowip($ip);
				if ($allowip == 1) {$block .= " (IP match in csf.allow, block may not work)"}
				if ($allowip == 2) {$block .= " (IP match in GLOBAL_ALLOW, block may not work)"}

				my @message;
				foreach my $line (@alert) {
					$line =~ s/\[ip\]/$tip/ig;
					$line =~ s/\[count\]/$count/ig;
					$line =~ s/\[blocks\]/$blocks/ig;
					$line =~ s/\[temp\]/$block/ig;
					push @message, $line;
				}
				ConfigServer::Sendmail::relay("", "", @message);
				if ($config{DEBUG} >= 1) {logfile("debug: alert email sent for $ip")}

				if ($config{X_ARF}) {
					$0 = "lfd - (child) sending X-ARF email for $ip";

					my @alert = slurp("/usr/local/csf/tpl/x-arf.txt");
					my @message;
					my $rfc3339 = strftime('%Y-%m-%dT%H:%M:%S%z',localtime);
					my $boundary = time;
					my $reportedfrom = "root\@$hostname";
					if ($config{X_ARF_TO}) {$config{LF_ALERT_TO} = $config{X_ARF_TO}}
					if ($config{X_ARF_FROM}) {$config{LF_ALERT_FROM} = $config{X_ARF_FROM}; $reportedfrom = $config{X_ARF_FROM}}
					my $iptype = "ipv".checkip(\$ip);

					my $abuseto = "";
					my $abusemsg = "";
					if ($iptype eq "ipv4" and $abuseip) {
						($abuseto, $abusemsg) = abuseip($ip);
						if ($abuseto eq "") {
							$abusemsg = "";
						}
						elsif ($config{X_ARF_ABUSE} and $config{X_ARF_FROM}) {
							if ($config{LF_ALERT_TO}) {
								$config{LF_ALERT_TO} .= ",".$abuseto;
							} else {
								$config{LF_ALERT_TO} = "root,".$abuseto;
							}
						}
					}

					foreach my $line (@alert) {
						$line =~ s/\[ip\]/$ip/ig;
						$line =~ s/\[abuseip\]/$abusemsg/ig;
						$line =~ s/\[iptype\]/$iptype/ig;
						$line =~ s/\[tip\]/$tip/ig;
						$line =~ s/\[ipcount\]/$count/ig;
						$line =~ s/\[iptick\]/$config{LF_INTERVAL}/ig;
						$line =~ s/\[service\]/firewall/ig;
						$line =~ s/\[csfversion\]/$version/ig;
						$line =~ s/\[reportedfrom\]/$reportedfrom/ig;
						$line =~ s/\[reportedid\]/$boundary\@$hostname/ig;
						$line =~ s/\[boundary\]/$boundary/ig;
						$line =~ s/\[text\]/$blocks/ig;
						$line =~ s/\[RFC3339\]/$rfc3339/ig;
						push @message, $line;
					}
					ConfigServer::Sendmail::relay($config{LF_ALERT_TO}, $config{LF_ALERT_FROM}, @message);

					if ($config{DEBUG} >= 1) {logfile("debug: X-ARF email sent for $ip")}
				}
			}
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","portscans",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end portscans
###############################################################################
# start uidscans
sub uidscans {
	my $uid = shift;
	my $count = shift;
	my $blocks = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","uidscans",$timer)}

		$0 = "lfd - (child) sending alert email for UID $uid";

		my $user = getpwuid($uid);
		if ($user eq "") {$user = $uid}
		logfile("*UID Tracking* $count blocks for UID $uid ($user)");

		my @alert = slurp("/usr/local/csf/tpl/uidscan.txt");
		my @message;
		foreach my $line (@alert) {
			$line =~ s/\[uid\]/$uid ($user)/ig;
			$line =~ s/\[count\]/$count/ig;
			$line =~ s/\[ports\]/$blocks/ig;
			push @message, $line;
		}
		ConfigServer::Sendmail::relay("", "", @message);
		if ($config{DEBUG} >= 1) {logfile("debug: alert email sent for UID $uid ($user)")}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","uidscans",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end uidscans
###############################################################################
# start csfrestart
sub csfrestart {
	my $timer = time;
	if ($config{DEBUG} >= 3) {$timer = &timer("start","csfrestart",$timer)}
	$0 = "lfd - (re)starting csf...";

	logfile("csf (re)start requested - running *csf startup*...");
	&syscommand(__LINE__,"/usr/sbin/csf","-sf");
	logfile("csf (re)start completed");

	if ($config{DEBUG} >= 3) {$timer = &timer("stop","csfrestart",$timer)}
	$0 = "lfd - processing";
	return;
}
# end csfrestart
###############################################################################
# start lfdrestart
sub lfdrestart {
	$SIG{INT} = 'IGNORE';
	$SIG{TERM} = 'IGNORE';
	$SIG{CHLD} = 'IGNORE';
	$0 = "lfd - stopping";

	logfile("daemon restart requested");

	close($PIDFILE);
	unlink $pidfile;

	$SIG{HUP} = 'IGNORE';
	kill HUP => -$$;
	exec("/usr/sbin/lfd");

	exit 0;
}
# end lfdrestart
###############################################################################
# start csfcheck
sub csfcheck {
	my $timer = time;
	if ($config{DEBUG} >= 3) {$timer = &timer("start","csfcheck",$timer)}

	my @ipdata = &syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -L LOCALINPUT -n");
	chomp @ipdata;
	if ($ipdata[0] =~ /# Warning: iptables-legacy tables present/) {shift @ipdata}

	if ($ipdata[0] =~ /xtables lock/) {
		logfile("*Error*: Unable to check csf due to xtables lock, enable WAITLOCK in csf.conf");
	} else {
		if ($ipdata[0] !~ /^Chain LOCALINPUT/) {
			$0 = "lfd - starting csf...";
			logfile("iptables appears to have been flushed - running *csf startup*...");
			&syscommand(__LINE__,"/usr/sbin/csf","-sf");
			logfile("csf startup completed");
			$0 = "lfd - processing";
		}

		if ($config{INTERWORX}) {
			&syscommand(__LINE__,"cp -af /etc/csf/apf_stub.pl /etc/apf/apf");
			&syscommand(__LINE__,"chmod 750 /etc/apf/apf");
		}

		if (-e "/usr/local/cpanel/version") {
			my $skip;

			if (-e "/var/run/upcp.pid") {
				open (my $IN, "<", "/var/run/upcp.pid");
				flock ($IN, LOCK_SH);
				my $upcp = <$IN>;
				close ($IN);
				chomp ($upcp);

				if (-d "/proc/$upcp") {
					if ($config{DEBUG} >= 1) {logfile("cPanel upcp is running, skipped version check")}
					$skip = 1;
				}
			}

			if (-e "/var/lib/csf/cpanel.new") {
				my $mtime = (stat("/var/lib/csf/cpanel.new"))[9];
				if (time - $mtime < 3600) {$skip = 1}
			}

			unless ($skip) {
				my $current;
				foreach my $line (slurp("/usr/local/cpanel/version")) {
					$line =~ s/$cleanreg//g;
					if ($line =~ /\d/) {$current = $line}
				}
				if ($current ne $cpconfig{version}) {
					$SIG{CHLD} = 'IGNORE';
					unless (defined ($childpid = fork)) {
						&cleanup(__LINE__,"*Error* cannot fork: $!");
					} 
					$forks{$childpid} = 1;
					unless ($childpid) {
						local $SIG{CHLD} = 'DEFAULT';
						my $timer = time;
						if ($config{DEBUG} >= 3) {$timer = &timer("start","cpanelcheck",$timer)}
						$0 = "lfd - (child) cPanel upgraded...";

						my $lockstr = "LF_CSF";
						sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
						flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
						print $THISLOCK time;

						logfile("cPanel upgrade detected, restarting ConfigServer services...");

						if (-e "/var/lib/csf/cpanel.new") {unlink "/var/lib/csf/cpanel.new"}
						open (my $CPANELNEW, ">", "/var/lib/csf/cpanel.new");
						flock ($CPANELNEW, LOCK_EX);
						print $CPANELNEW time;
						close ($CPANELNEW);

						if (-e "/etc/cxs/cxs.pl") {
							logfile("cPanel upgrade detected, restarting cxs Watch (if running)");
							open (my $OUT, ">", "/etc/cxs/newusers/cxswatchrestart");
							close ($OUT);
							logfile("cPanel upgrade detected, restarting cxs pure-uploadscript (if running)");
							eval {
								local $SIG{__DIE__} = undef;
								local $SIG{'ALRM'} = sub {die};
								alarm(30);
								&syscommand(__LINE__,"/sbin/service","pure-uploadscript","restart");
								&syscommand(__LINE__,"/scripts/restartsrv_ftpserver");
								alarm(0);
							};
							alarm(0);
						}

						if (-e "/etc/osm/osmd.pl") {
							logfile("cPanel upgrade detected, restarting osmd");
							eval {
								local $SIG{__DIE__} = undef;
								local $SIG{'ALRM'} = sub {die};
								alarm(30);
								&syscommand(__LINE__,"/sbin/service","osmd","restart");
								alarm(0);
							};
							alarm(0);
						}

						if (-e "/etc/exim_outgoing.conf" and (-e "/etc/init.d/MailScanner" or -e "/etc/systemd/system/multi-user.target.wants/MailScanner.service")) {
							logfile("cPanel upgrade detected, restarting MailScanner");
							eval {
								local $SIG{__DIE__} = undef;
								local $SIG{'ALRM'} = sub {die};
								alarm(30);
								&syscommand(__LINE__,"/sbin/service","MailScanner","restart");
								alarm(0);
							};
							alarm(0);
						}

						logfile("cPanel upgrade detected, restarting lfd");
						open (my $LFDOUT, ">", "/var/lib/csf/lfd.restart");
						close ($LFDOUT);
				
						close ($THISLOCK );
						if ($config{DEBUG} >= 3) {$timer = &timer("stop","cpanelcheck",$timer)}
						$0 = "lfd - child closing";
						exit;
					}
				}
			}
		}
	}

	if ($config{DEBUG} >= 3) {$timer = &timer("stop","csfcheck",$timer)}
	return;
}
# end csfcheck
###############################################################################
# start loadcheck
sub loadcheck {
	if (-e "/var/lib/csf/csf.load") {
		open (my $IN, "<", "/var/lib/csf/csf.load");
		flock ($IN, LOCK_SH);
		my $start = <$IN>;
		close ($IN);
		chomp $start;
		if (time - $start < $config{PT_LOAD_SKIP}) {
			return;
		} else {
			unlink ("/var/lib/csf/csf.load");
		}
	}
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","loadcheck",$timer)}
		$0 = "lfd - (child) checking load...";

		my $lockstr = "PT_LOAD";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		open (my $IN, "<", "/proc/loadavg");
		flock ($IN, LOCK_SH);
		my $loadavg = <$IN>;
		close ($IN);
		chomp $loadavg;
		my @load = split(/\s+/,$loadavg);

		my $reportload = $load[1];
		if ($config{PT_LOAD_AVG} == 1) {$reportload = $load[0]}
		elsif ($config{PT_LOAD_AVG} == 15) {$reportload = $load[2]}
		else {$config{PT_LOAD_AVG} = 5}

		if ($reportload >= $config{PT_LOAD_LEVEL}) {
			logfile("*LOAD* $config{PT_LOAD_AVG} minute load average is $reportload, threshold is $config{PT_LOAD_LEVEL} - email sent");
			sysopen (my $LOAD, "/var/lib/csf/csf.load", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot write to file: $!");
			flock ($LOAD, LOCK_EX);
			seek ($LOAD, 0, 0);
			truncate ($LOAD, 0);
			print $LOAD time;
			close ($LOAD);

			if ($config{PT_LOAD_ACTION} and -e "$config{PT_LOAD_ACTION}" and -x "$config{PT_LOAD_ACTION}") {
				$SIG{CHLD} = 'IGNORE';
				unless (defined ($ptchildpid = fork)) {
					&cleanup(__LINE__,"*Error* cannot fork: $!");
				} 
				unless ($ptchildpid) {
					system($config{PT_LOAD_ACTION});
					exit;
				}
			}

			my @proclist;
			eval {
				local $SIG{__DIE__} = undef;
				local $SIG{'ALRM'} = sub {die};
				alarm(15);
				@proclist = &syscommand(__LINE__,$config{PS},"axuf");
				alarm(0);
			};
			alarm(0);
			if ($@) {push @proclist, "Unable to obtain process output within 15 seconds - Timed out"}

			my @vmstat;
			eval {
				local $SIG{__DIE__} = undef;
				local $SIG{'ALRM'} = sub {die};
				alarm(10);
				@vmstat = &syscommand(__LINE__,$config{VMSTAT});
				alarm(0);
			};
			alarm(0);
			if ($@) {push @vmstat, "Unable to obtain vmstat output within 10 seconds - Timed out"}

			my @netstat;
			eval {
				local $SIG{__DIE__} = undef;
				local $SIG{'ALRM'} = sub {die};
				alarm(10);
				@netstat = &syscommand(__LINE__,$config{NETSTAT}, "-autpn");
				alarm(0);
			};
			alarm(0);
			if ($@) {push @netstat, "Unable to obtain netstat output within 10 seconds - Timed out"}

			my $url = $config{PT_APACHESTATUS};
			my ($status, $apache) = $urlget->urlget($url);
			if ($status) {$apache = "Unable to retrieve Apache Server Status [$url] - $apache"}

			my @alert = slurp("/usr/local/csf/tpl/loadalert.txt");
			my $boundary = "csf".time;
			my @message;
			foreach my $line (@alert) {
				$line =~ s/\[loadavg1\]/$load[0]/ig;
				$line =~ s/\[loadavg5\]/$load[1]/ig;
				$line =~ s/\[loadavg15\]/$load[2]/ig;
				$line =~ s/\[loadavg\]/$config{PT_LOAD_AVG}/ig;
				$line =~ s/\[reportload\]/$reportload/ig;
				$line =~ s/\[totprocs\]/$load[3]/ig;
				$line =~ s/\[processlist\]/@proclist/ig;
				$line =~ s/\[vmstat\]/@vmstat/ig;
				$line =~ s/\[netstat\]/@netstat/ig;
				$line =~ s/\[apache\]/$apache/ig;
				$line =~ s/\[boundary\]/$boundary/ig;
				push @message, $line;
			}
			ConfigServer::Sendmail::relay("", "", @message);
		}

		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","loadcheck",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end loadcheck
###############################################################################
# start denycheck
sub denycheck {
	my $ip = shift;
	my $port = shift;
	my $perm = shift;
	my $ipstring = quotemeta($ip);
	my $skip = 0;

	my @deny = slurp("/etc/csf/csf.deny");
	foreach my $line (@deny) {
		if ($line =~ /^Include\s*(.*)$/) {
			my @incfile = slurp($1);
			push @deny,@incfile;
		}
	}
	my $denymatches = scalar(grep {$_ =~ /^$ipstring\b/i} @deny);
	if ($config{LF_REPEATBLOCK} and $denymatches < $config{LF_REPEATBLOCK}) {$denymatches = 0}
	unless ($denymatches == 0) {$skip = 1}

	open (my $IN, "<", "/var/lib/csf/csf.tempban");
	flock ($IN, LOCK_SH);
	@deny = <$IN>;
	close ($IN);
	chomp @deny;
	if (grep {$_ =~ /^\d+\|$ipstring\|$port\|/i} @deny) {
		unless ($perm) {$skip = 1}
	}

	return $skip;
}
# end denycheck
###############################################################################
# start queuecheck
sub queuecheck {
	if (-e "/var/lib/csf/csf.queue") {
		open (my $IN, "<", "/var/lib/csf/csf.queue");
		flock ($IN, LOCK_SH);
		my $start = <$IN>;
		close ($IN);
		chomp $start;
		if (time - $start < $config{LF_FLUSH}) {
			return;
		} else {
			unlink ("/var/lib/csf/csf.queue");
		}
	}
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","queuecheck",$timer)}
		$0 = "lfd - (child) checking mail queue...";

		my $lockstr = "LF_QUEUE_INTERVAL";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		my $queue;
		my $msqueue;
		my $timeout = "";
		eval {
			local $SIG{__DIE__} = undef;
			local $SIG{'ALRM'} = sub {die};
			alarm(30);
			$queue = (&syscommand(__LINE__,"/usr/sbin/exim","-bpc"))[0];
			alarm(0);
		};
		alarm(0);
		if ($@) {$timeout = "Unable to obtain exim queue length within 30 seconds - Timed out"}
		chomp $queue;

		if (-e "/etc/exim_outgoing.conf") {
			$msqueue = $queue;
			eval {
				local $SIG{__DIE__} = undef;
				local $SIG{'ALRM'} = sub {die};
				alarm(30);
				$queue = (&syscommand(__LINE__,"/usr/sbin/exim","-C","/etc/exim_outgoing.conf","-bpc"))[0];
				alarm(0);
			};
			alarm(0);
			if ($@) {$timeout = "Unable to obtain exim_outgoing.conf queue length within 30 seconds - Timed out"}
			chomp $queue;
		}

		if (($queue > $config{LF_QUEUE_ALERT}) or ($msqueue > $config{LF_QUEUE_ALERT}) or ($timeout ne "")) {
			my $report = "The exim delivery queue size is $queue";
			if ($msqueue) {$report .= ", the MailScanner pending queue size is $msqueue"}
			if ($timeout) {$report = $timeout}
			logfile("*Email Queue* $report");

			sysopen (my $QUEUE, "/var/lib/csf/csf.queue", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot write to file: $!");
			flock ($QUEUE, LOCK_EX);
			seek ($QUEUE, 0, 0);
			truncate ($QUEUE, 0);
			print $QUEUE time;
			close ($QUEUE);

			my @alert = slurp("/usr/local/csf/tpl/queuealert.txt");
			my @message;
			foreach my $line (@alert) {
				$line =~ s/\[text\]/$report/ig;
				push @message, $line;
			}
			ConfigServer::Sendmail::relay("", "", @message);
		}

		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","queuecheck",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end queuecheck
###############################################################################
# start modsecipdbcheck
sub modsecipdbcheck {
	if (-e "/var/lib/csf/csf.modsecipdbcheck") {
		open (my $IN, "<", "/var/lib/csf/csf.modsecipdbcheck");
		flock ($IN, LOCK_SH);
		my $start = <$IN>;
		close ($IN);
		chomp $start;
		if (time - $start < $config{LF_FLUSH}) {
			return;
		} else {
			unlink ("/var/lib/csf/csf.modsecipdbcheck");
		}
	}
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","modsecipdbcheck",$timer)}
		$0 = "lfd - (child) checking modsec ip db...";

		my $lockstr = "LF_MODSECIPDB_ALERT";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		my $size = (stat $config{LF_MODSECIPDB_FILE})[7]/(1024*1024*1024);

		if ($size > $config{LF_MODSECIPDB_ALERT}) {
			$size = sprintf("%.2f", $size);
			my $report = "ModSecurity persistent IP database ($config{LF_MODSECIPDB_FILE}) size is ${size}GB";

			sysopen (my $QUEUE, "/var/lib/csf/csf.modsecipdbcheck", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot write to file: $!");
			flock ($QUEUE, LOCK_EX);
			seek ($QUEUE, 0, 0);
			truncate ($QUEUE, 0);
			print $QUEUE time;
			close ($QUEUE);

			my @alert = slurp("/usr/local/csf/tpl/modsecipdbalert.txt");
			my @message;
			foreach my $line (@alert) {
				$line =~ s/\[text\]/$report/ig;
				push @message, $line;
			}
			ConfigServer::Sendmail::relay("", "", @message);
		}

		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","modsecipdbcheck",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end modsecipdbcheck
###############################################################################
# start connectiontracking
sub connectiontracking {

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","connectiontracking",$timer)}
		$0 = "lfd - (child) connection tracking...";

		my $lockstr = "CT_INTERVAL";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		my @connections;
		my %ipcnt;
		my %iptext;
		my %subcnt;
		my %subtext;
		my $alarm = int($config{CT_INTERVAL}/10) + 10;
		my $start = time;
		my $tfail = 0;
		my %states;
		if ($config{CT_STATES}) {
			foreach my $state (split(/\,/,$config{CT_STATES})) {
				$states{$state} = 1;
			}
		}
		my %countports;
		if ($config{CT_PORTS}) {
			foreach my $port (split(/\,/,$config{CT_PORTS})) {
				$countports{$port} = 1;
			}
		}

		my %net;
		my %tcpstates = ("01" => "ESTABLISHED",
						 "02" => "SYN_SENT",
						 "03" => "SYN_RECV",
						 "04" => "FIN_WAIT1",
						 "05" => "FIN_WAIT2",
						 "06" => "TIME_WAIT",
						 "07" => "CLOSE",
						 "08" => "CLOSE_WAIT",
						 "09" => "LAST_ACK",
						 "0A" => "LISTEN",
						 "0B" => "CLOSING");
		foreach my $proto ("tcp","udp","tcp6","udp6") {
			open (my $IN, "<", "/proc/net/$proto");
			flock ($IN, LOCK_SH);
			while (<$IN>) {
				my @rec = split();
				if ($rec[9] =~ /uid/) {next}

				my ($dip,$dport) = split(/:/,$rec[1]);
				$dport = hex($dport);

				my ($sip,$sport) = split(/:/,$rec[2]);
				$sport = hex($sport);

				$dip = &hex2ip($dip);
				if ($dip =~ /^0:0:0:0:0:ffff:(.*)$/) {
					my $embed = $1;
					$embed =~ s/://g;
					my $embedded = inet_ntoa(pack("N",hex($embed)));
					if ($embedded =~ /^$ipv4reg$/) {$dip = $embedded}
				}

				$sip = &hex2ip($sip);
				if ($sip =~ /^0:0:0:0:0:ffff:(.*)$/) {
					my $embed = $1;
					$embed =~ s/://g;
					my $embedded = inet_ntoa(pack("N",hex($embed)));
					if ($embedded =~ /^$ipv4reg$/) {$sip = $embedded}
				}

				my $state = $tcpstates{$rec[3]};

				if ($config{DEBUG} >= 4) {logfile("debug: CT $proto: $sip:$sport -> $dip:$dport state:[$state]")}

				if ($config{CT_SKIP_TIME_WAIT} and ($state eq "TIME_WAIT")) {next}
				if ($config{CT_STATES} and ($states{$state} != 1)) {next}
				if ($config{CT_PORTS} and ($countports{$dport} != 1)) {next}
				if ($state eq "LISTEN") {next}
				if ($dip =~ /^127\./) {next}
				if ($dip =~ /^0\.0\.0\.1/) {next}

				checkip(\$sip);
				$ipcnt{$sip}++;
				$iptext{$sip} .= "$proto: $sip:$sport -> $dip:$dport ($state)\n";

				if ($config{CT_SUBNET_LIMIT} > 0) {
					my $subnet;
					if ($sip =~ /^(\d+\.\d+\.\d+)\.\d+$/) {
						$subnet = $1;
						if ($subnet ne "0.0.0" and $subnet ne "255.255.255") {
							$subcnt{$subnet}++;
							$subtext{$subnet} .= "$proto: $sip:$sport -> $dip:$dport ($state)\n";
							if ($config{DEBUG} >= 2) {logfile("debug: CT $proto: $sip:$sport -> $dip:$dport state:[$state] count:[$ipcnt{$sip}] subnet:[$subnet] subnet count:[$subcnt{$subnet}]")}
						}
					}
				} else {
					if ($config{DEBUG} >= 2) {logfile("debug: CT $proto: $sip:$sport -> $dip:$dport state:[$state] count:[$ipcnt{$sip}]")}
				}
			}
			close ($IN);
		}

		foreach my $ip (keys %ipcnt) {
			if (($ipcnt{$ip} > $config{CT_LIMIT}) and !&ignoreip($ip)) {
				my $tip = iplookup($ip);
				if (&ipblock($config{CT_PERMANENT},"(CT) IP $tip found to have $ipcnt{$ip} connections",$ip,"","inout",$config{CT_BLOCK_TIME},0,$iptext{$ip},"CT_LIMIT")) {
					if ($config{DEBUG} >= 1) {logfile("debug: CT $ip already blocked")}
				} else {
					if ($config{CT_EMAIL_ALERT}) {
						$0 = "lfd - (child) (CT) sending alert email for $ip";

						my @alert = slurp("/usr/local/csf/tpl/connectiontracking.txt");
						my $block = "Temporary Block for $config{CT_BLOCK_TIME} seconds [CT_LIMIT]";
						if ($config{CT_PERMANENT}) {$block = "Permanent Block [CT_LIMIT]"}

						my $allowip = &allowip($ip);
						if ($allowip == 1) {$block .= " (IP match in csf.allow, block may not work)"}
						if ($allowip == 2) {$block .= " (IP match in GLOBAL_ALLOW, block may not work)"}

						my @message;
						foreach my $line (@alert) {
							$line =~ s/\[ip\]/$tip/ig;
							$line =~ s/\[ipcount\]/$ipcnt{$ip}/ig;
							$line =~ s/\[iptext\]/$iptext{$ip}/ig;
							$line =~ s/\[temp\]/$block/ig;
							push @message, $line;
						}
						ConfigServer::Sendmail::relay("", "", @message);

						if ($config{X_ARF}) {
							$0 = "lfd - (child) sending X-ARF email for $ip";

							my @alert = slurp("/usr/local/csf/tpl/x-arf.txt");
							my @message;
							my $rfc3339 = strftime('%Y-%m-%dT%H:%M:%S%z',localtime);
							my $boundary = time;
							my $reportedfrom = "root\@$hostname";
							if ($config{X_ARF_TO}) {$config{LF_ALERT_TO} = $config{X_ARF_TO}}
							if ($config{X_ARF_FROM}) {$config{LF_ALERT_FROM} = $config{X_ARF_FROM}; $reportedfrom = $config{X_ARF_FROM}}
							my $iptype = "ipv".checkip(\$ip);

							my $abuseto = "";
							my $abusemsg = "";
							if ($iptype eq "ipv4" and $abuseip) {
								($abuseto, $abusemsg) = abuseip($ip);
								if ($abuseto eq "") {
									$abusemsg = "";
								}
								elsif ($config{X_ARF_ABUSE} and $config{X_ARF_FROM}) {
									if ($config{LF_ALERT_TO}) {
										$config{LF_ALERT_TO} .= ",".$abuseto;
									} else {
										$config{LF_ALERT_TO} = "root,".$abuseto;
									}
								}
							}

							foreach my $line (@alert) {
								$line =~ s/\[ip\]/$ip/ig;
								$line =~ s/\[abuseip\]/$abusemsg/ig;
								$line =~ s/\[iptype\]/$iptype/ig;
								$line =~ s/\[tip\]/$tip/ig;
								$line =~ s/\[ipcount\]/$ipcnt{$ip}/ig;
								$line =~ s/\[iptick\]/$config{LF_INTERVAL}/ig;
								$line =~ s/\[service\]/port-flood/ig;
								$line =~ s/\[csfversion\]/$version/ig;
								$line =~ s/\[reportedfrom\]/$reportedfrom/ig;
								$line =~ s/\[reportedid\]/$boundary\@$hostname/ig;
								$line =~ s/\[boundary\]/$boundary/ig;
								$line =~ s/\[text\]/$iptext{$ip}/ig;
								$line =~ s/\[RFC3339\]/$rfc3339/ig;
								push @message, $line;
							}
							ConfigServer::Sendmail::relay($config{LF_ALERT_TO}, $config{LF_ALERT_FROM}, @message);

							if ($config{DEBUG} >= 1) {logfile("debug: CT X-ARF email sent for $ip")}
						}

						if ($config{DEBUG} >= 1) {logfile("debug: CT alert email sent for $ip")}
					}
				}
			}
		}

		foreach my $subnet (keys %subcnt) {
			if ($config{DEBUG} >= 2) {logfile("debug: CT $subnet processing $subcnt{$subnet} entries")}
			my $fullsubnet = $subnet.".0/24";
			if (($subcnt{$subnet} > $config{CT_SUBNET_LIMIT}) and !&ignoreip($fullsubnet)) {
				my $tip = iplookup($fullsubnet);
				if (&ipblock($config{CT_PERMANENT},"(CT) subnet $tip found to have $subcnt{$subnet} connections",$fullsubnet,"","inout",$config{CT_BLOCK_TIME},0,$subtext{$subnet},"CT_SUBNET_LIMIT")) {
					if ($config{DEBUG} >= 1) {logfile("debug: CT $subnet already blocked")}
				} else {
					if ($config{CT_EMAIL_ALERT}) {
						$0 = "lfd - (child) (CT) sending alert email for $subnet";

						my @alert = slurp("/usr/local/csf/tpl/connectiontracking.txt");
						my $block = "Temporary Block for $config{CT_BLOCK_TIME} seconds [CT_LIMIT]";
						if ($config{CT_PERMANENT}) {$block = "Permanent Block [CT_LIMIT]"}

						my $allowip = &allowip($fullsubnet);
						if ($allowip == 1) {$block .= " (subnet match in csf.allow, block may not work)"}
						if ($allowip == 2) {$block .= " (subnet match in GLOBAL_ALLOW, block may not work)"}

						my @message;
						foreach my $line (@alert) {
							$line =~ s/\[ip\]/$tip/ig;
							$line =~ s/\[ipcount\]/$subcnt{$subnet}/ig;
							$line =~ s/\[iptext\]/$subtext{$subnet}/ig;
							$line =~ s/\[temp\]/$block/ig;
							push @message, $line;
						}
						ConfigServer::Sendmail::relay("", "", @message);

						if ($config{DEBUG} >= 1) {logfile("debug: CT alert email sent for $fullsubnet")}
					}
				}
			}
		}
		
		if ($tfail) {
			$config{CT_INTERVAL} = $config{CT_INTERVAL} * 1.5;
			sysopen (my $TEMPCONF, "/var/lib/csf/csf.tempconf", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot append out file: $!");
			flock ($TEMPCONF, LOCK_EX);
			print $TEMPCONF "CT_INTERVAL = \"$config{CT_INTERVAL}\"\n";
			close ($TEMPCONF);
			logfile("CT_INTERVAL taking $alarm seconds, temporarily throttled to run every $config{CT_INTERVAL} seconds");
		}

		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","connectiontracking",$timer)}
		$0 = "lfd - (child) closing";
		exit;
	}
	return;
}
# end connectiontracking
###############################################################################
# start accounttracking
sub accounttracking {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","accounttracking",$timer)}
		$0 = "lfd - (child) account tracking...";

		my $lockstr = "AT_INTERVAL";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		my $report = "";
		foreach my $user (keys %newaccounttracking) {
			if (($config{AT_ALERT} eq "2") and ($newaccounttracking{$user}{uid} ne "0")) {next}
			if ($accounttracking{$user}{account} != 1) {
				if ($config{AT_NEW}) {
					$report .= "New account [$user] has been created with uid:[$newaccounttracking{$user}{uid}] gid:[$newaccounttracking{$user}{gid}] login:[$newaccounttracking{$user}{dir}] shell:[$newaccounttracking{$user}{shell}]\n";
				}
			} else {
				if ($config{AT_PASSWD} and ($newaccounttracking{$user}{passwd} ne $accounttracking{$user}{passwd})) {
					$report .= "Account [$user] password has changed\n";
				}
				if ($config{AT_UID} and ($newaccounttracking{$user}{uid} ne $accounttracking{$user}{uid})) {
					$report .= "Account [$user] uid has changed from [$accounttracking{$user}{uid}] to [$newaccounttracking{$user}{uid}]\n";
				}
				if ($config{AT_GID} and ($newaccounttracking{$user}{gid} ne $accounttracking{$user}{gid})) {
					$report .= "Account [$user] gid has changed from [$accounttracking{$user}{gid}] to [$newaccounttracking{$user}{gid}]\n";
				}
				if ($config{AT_DIR} and ($newaccounttracking{$user}{dir} ne $accounttracking{$user}{dir})) {
					$report .= "Account [$user] login directory has changed from [$accounttracking{$user}{dir}] to [$newaccounttracking{$user}{dir}]\n";
				}
				if ($config{AT_SHELL} and ($newaccounttracking{$user}{shell} ne $accounttracking{$user}{shell})) {
					$report .= "Account [$user] login shell has changed from [$accounttracking{$user}{shell}] to [$newaccounttracking{$user}{shell}]\n";
				}
			}
		}
		foreach my $user (keys %accounttracking) {
			if (($config{AT_ALERT} eq "2") and ($accounttracking{$user}{uid} ne "0")) {next}
			if ($config{AT_OLD} and ($newaccounttracking{$user}{account} != 1)) {
				$report .= "Existing account [$user] has been removed. Old settings uid:[$accounttracking{$user}{uid}] gid:[$accounttracking{$user}{gid}] login:[$accounttracking{$user}{dir}] shell:[$accounttracking{$user}{shell}]\n";
			}
		}
		if ($report ne "") {
			logfile("*Account Modification* Email sent");

			my @alert = slurp("/usr/local/csf/tpl/accounttracking.txt");
			my @message;
			foreach my $line (@alert) {
				$line =~ s/\[report\]/$report/ig;
				push @message, $line;
			}
			ConfigServer::Sendmail::relay("", "", @message);
		}			

		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","accounttracking",$timer)}
		$0 = "lfd - (child) closing";
		exit;
	}
	return;
}
# end accounttracking
###############################################################################
# start syslogcheck
sub syslogcheck {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","syslogcheck",$timer)}
		$0 = "lfd - (child) SYSLOG check...";

		my $lockstr = "SYSLOG_CHECK";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		logfile("*SYSLOG CHECK* Failed to detect check line [$syslogcheckcode] sent to SYSLOG");

		my @alert = slurp("/usr/local/csf/tpl/syslogalert.txt");
		my @message;
		foreach my $line (@alert) {
			$line =~ s/\[code\]/$syslogcheckcode/ig;
			$line =~ s/\[log\]/$config{SYSLOG_LOG}/ig;
			push @message, $line;
		}
		ConfigServer::Sendmail::relay("", "", @message);

		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","syslogcheck",$timer)}
		$0 = "lfd - (child) closing";
		exit;
	}
	return;
}
# end syslogcheck
###############################################################################
# start processtracking
sub processtracking {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","processtracking",$timer)}
		$0 = "lfd - (child) process tracking...";

		my $lockstr = "PT_INTERVAL";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		my %users;
		my %net;

		unless ($config{GENERIC}) {
			opendir (DIR, "/var/cpanel/users");
			while (my $user = readdir (DIR)) {
				if ($user =~ /^\./) {next}
				$users{$user} = 1;
			}
			closedir (DIR);
			$users{nobody} = 1;
		}

		foreach my $proto ("udp","tcp","udp6","tcp6") {
			open (my $IN, "<", "/proc/net/$proto");
			flock ($IN, LOCK_SH);
			while (<$IN>) {
				my @rec = split();
				if ($rec[9] =~ /uid/) {next}

				my ($dip,$dport) = split(/:/,$rec[2]);
				$dport = hex($dport);

				my ($sip,$sport) = split(/:/,$rec[1]);
				$sport = hex($sport);

				if ($dip == 0 or $sip == 0) {next}

				$dip = &hex2ip($dip);
				if ($dip =~ /^0:0:0:0:0:ffff:(.*)$/) {
					my $embed = $1;
					$embed =~ s/://g;
					my $embedded = inet_ntoa(pack("N",hex($embed)));
					if ($embedded =~ /^$ipv4reg$/) {$dip = $embedded}
				}

				$sip = &hex2ip($sip);
				if ($sip =~ /^0:0:0:0:0:ffff:(.*)$/) {
					my $embed = $1;
					$embed =~ s/://g;
					my $embedded = inet_ntoa(pack("N",hex($embed)));
					if ($embedded =~ /^$ipv4reg$/) {$sip = $embedded}
				}

				if ($sip eq '0.0.0.1') {next}

				$net{$rec[9]}{proto} = $proto;
				$net{$rec[9]}{sport} = $sport;
				$net{$rec[9]}{sip} = $sip;
				$net{$rec[9]}{dport} = $dport;
				$net{$rec[9]}{dip} = $dip;
				if ($config{DEBUG} >= 4) {logfile("debug: PT $proto: $sip:$sport -> $dip:$dport")}
			}
			close ($IN);
		}

		open (my $IN,"<", "/proc/uptime");
		flock ($IN, LOCK_SH);
		my @up = <$IN>;
		close ($IN);
		chomp @up;
		my ($upsecs,undef) = split (/\s/,$up[0]);

		my %pids;
		if (! -z "/var/lib/csf/csf.temppids") {
			open (my $IN, "<", "/var/lib/csf/csf.temppids");
			flock ($IN, LOCK_SH);
			my @data = <$IN>;
			close ($IN);
			chomp @data;

			foreach my $line (@data) {
				my ($itemttl,$item) = split(/:/,$line);
				if (time - $itemttl < $config{LF_FLUSH}) {
					$pids{$item} = 1;
				}
			}
		}
		my %ignoreusers;
		if (! -z "/var/lib/csf/csf.tempusers") {
			open (my $IN, "<", "/var/lib/csf/csf.tempusers");
			flock ($IN, LOCK_SH);
			my @data = <$IN>;
			close ($IN);
			chomp @data;

			foreach my $line (@data) {
				my ($itemttl,$item) = split(/:/,$line);
				if (time - $itemttl < $config{LF_FLUSH}) {
					$ignoreusers{$item} = 1;
				}
			}
		}

		my %totproc;
		my %procres;
		my %sessions;
		opendir (PROCDIR, "/proc");
		while (my $pid = readdir(PROCDIR)) {
			if ($pid !~ /^\d+$/) {next}
			open (my $IN,"<", "/proc/$pid/status") or next;
			flock ($IN, LOCK_SH);
			my @status = <$IN>;
			close ($IN);
			chomp @status;
			my $user;
			my $uid;
			my $vmsize = 0;
			my $vmrss = 0;
			my $ppid = $pid;
			foreach my $line (@status) {
				if ($line =~ /^Uid:(.*)/) {
					my $uidline = $1;
					my @uids;
					foreach my $bit (split(/\s/,$uidline)) {
						if ($bit =~ /^(\d*)$/) {push @uids, $1}
					}
					$uid = $uids[-1];
					$user = getpwuid($uid);
				}
				if ($line =~ /^VmSize:\s+(\d+) kB$/) {$vmsize = $1}
				if ($line =~ /^VmRSS:\s+(\d+) kB$/) {$vmrss = $1}
				if ($line =~ /^PPid:\s+(\d+)$/) {
					$ppid = $1;
					if ($ppid == 1) {$ppid = $pid}
				}
			}

			if ($users{$user} or $config{GENERIC} or $config{PT_ALL_USERS}) {
				if ($pids{$pid}) {next}
				if ($skip{user}{$user}) {next}
				my $pmatch = 0;
				foreach my $item (keys %{$pskip{puser}}) {
					if ($user =~ /^$item$/) {
						$pmatch = 1;
						last;
					}
				}
				if ($pmatch) {next}

				my %printable = ( ( map { chr($_), unpack('H2', chr($_)) } (0..255) ), "\\"=>'\\', "\r"=>'r', "\n"=>'n', "\t"=>'t', "\""=>'"' ); ##no critic

				my $exe = readlink("/proc/$pid/exe");
				my $cwd = readlink("/proc/$pid/cwd");
				$exe =~ s/([\r\n\t\"\\\x00-\x1f\x7F-\xFF])/\\$printable{$1}/sg;
				$cwd =~ s/([\r\n\t\"\\\x00-\x1f\x7F-\xFF])/\\$printable{$1}/sg;
				if ($exe eq "") {next}

				if ($config{DEBUG} >= 4) {logfile("debug: PT exe = $exe")}
				my $exet = $exe;
				my $deleted = 0;
				if ($exe =~ /\(deleted\)/) {
					if ($ppid and ($ppid != $pid) and $pids{$ppid}) {
						my $pexe = readlink("/proc/$ppid/exe");
						$pexe =~ s/([\r\n\t\"\\\x00-\x1f\x7F-\xFF])/\\$printable{$1}/sg;
						if ($pexe =~ /\(deleted\)/) {
							if ($config{DEBUG} >= 2) {logfile("Process Tracking - Parent PID $ppid already reported for deleted $pid - ignored")}
							next;
						}
					}
					$deleted = 1;
					if ($config{PT_DELETED}) {
						$exet .= "\n\nThe file system shows this process is running an executable file that has been deleted. This typically happens when the original file has been replaced by a new file when the application is updated. To prevent this being reported again, restart the process that runs this excecutable file. See csf.conf and the PT_DELETED text for more information about the security implications of processes running deleted executable files.";
					} else {next}
				}

				open (my $CMDLINE,"<", "/proc/$pid/cmdline");
				flock ($CMDLINE, LOCK_SH);
				my $cmdline = <$CMDLINE>;
				close ($CMDLINE);
				chomp $cmdline;
				$cmdline =~ s/\0$//g;
				$cmdline =~ s/\0/ /g;
				$cmdline =~ s/\s+$//g;
				$cmdline =~ s/([\r\n\t\"\\\x00-\x1f\x7F-\xFF])/\\$printable{$1}/sg;

				open (my $STAT,"<", "/proc/$pid/stat") or next;
				flock ($STAT, LOCK_SH);
				my $pstatline = <$STAT>;
				close ($STAT);
				chomp $pstatline;
				my @pstat;
				if ($pstatline =~ /^\d+\s\(.*\)\s(.*)$/) {
					@pstat = split(/\s/,$1);
				} else {next}

				my $jiffsecs = $pstat[19] / $clock_ticks;
				my $uptime = int($upsecs - $jiffsecs);

				if ($config{PT_SSHDHUNG}) {
					if ($cmdline =~ /^sshd:\s+unknown\s+\[net|priv\]\s*$/) {
						if ($uptime > 60) {
							kill (9, $pid);
							logfile("*PT_SSHDHUNG* process pid:[$pid] cmd:[$cmdline] Uptime:[$uptime], killed");
							next;
						}
					}
				}

				if ($skip{exe}{$exe}) {next}

				$pmatch = 0;
				foreach my $item (keys %{$pskip{pexe}}) {
					if ($exe =~ /^$item$/) {
						$pmatch = 1;
						last;
					}
				}
				if ($pmatch) {next}

				if ($skip{cmd}{$cmdline}) {next}
				$pmatch = 0;
				foreach my $item (keys %{$pskip{pcmd}}) {
					if ($cmdline =~ /^$item$/) {
						$pmatch = 1;
						last;
					}
				}
				if ($pmatch) {next}

				if (($config{MESSENGER} and $user eq $config{MESSENGER_USER}) and ($cmdline =~ /^lfd (HTML|TEXT|HTTPS) messenger/)) {next}

				if ($config{PT_FORKBOMB}) {
					my $sid = $pstat[3];
					if ($sid > 1) {
						$sessions{$sid}{count}++;
						$sessions{$sid}{text} .= "PID:$pid PPID:$ppid SID:$sid User:$user EXE:$exe CMD:$cmdline\n";
						if ($sessions{$sid}{count} >= $config{PT_FORKBOMB}) {
							logfile("*PT_FORKBOMB* PID:$pid SID:$sid User:$user EXE:$exe CMD:$cmdline");
							my $text = $sessions{$sid}{text};
							delete $sessions{$sid};
							kill 9, "-$sid";

							my @alert = slurp("/usr/local/csf/tpl/forkbombalert.txt");
							my @message;
							foreach my $line (@alert) {
								$line =~ s/\[level\]/$config{PT_FORKBOMB}/ig;
								$line =~ s/\[text\]/$text/ig;
								push @message, $line;
							}
							ConfigServer::Sendmail::relay("", "", @message);
							next;
						}
					}
				}
				if ($user eq "root") {next}

				if ($config{PT_SKIP_HTTP}) {
					my $pgrp = $pstat[2];
					my $pgrpexe = readlink("/proc/$pgrp/exe");
					if (($pid ne $pgrp) and ($pgrpexe eq "/usr/local/apache/bin/httpd")) {next}
					if (($pid ne $pgrp) and ($pgrpexe eq "/usr/local/bin/httpd")) {next}
					if (($pid ne $pgrp) and ($pgrpexe eq "/usr/bin/httpd")) {next}
				}

				if ($user ne "nobody") {
					unless ($deleted) {
						$totproc{$user}{count}++;
						if ($totproc{$user}{pids} eq "") {
							$totproc{$user}{pids} = $pid;
						} else {
							$totproc{$user}{pids} .= ",$pid";
						}
						$totproc{$user}{text} .= "User:$user PID:$pid PPID:$ppid Run Time:$uptime(secs) Memory:$vmsize(kb) RSS:$vmrss(kb) exe:$exe cmd:$cmdline\n";
						$procres{$pid}{vmsize} = $vmsize;
						$procres{$pid}{vmrss} = $vmrss;
						$procres{$pid}{uptime} = $uptime;
						$procres{$pid}{user} = $user;
						$procres{$pid}{exe} = $exe;
						$procres{$pid}{exet} = $exet;
						$procres{$pid}{cmd} = $cmdline;
						$procres{$pid}{ppid} = $ppid;
					}
				}

				if ($uptime > $config{PT_LIMIT}) {
					my $suspect = 0;

					my @fd;
					opendir (DIR, "/proc/$pid/fd") or next;
					while (my $file = readdir (DIR)) {
						if ($file =~ /^\./) {next}
						push (@fd, readlink("/proc/$pid/fd/$file"));
					}
					closedir (DIR);

					my $files;
					my $sockets;
					foreach my $file (@fd) {
						if ($file =~ /^socket:\[?([0-9]+)\]?$/) {
							my $ino = $1;
							if ($net{$ino}) {
								$sockets .= "$net{$ino}{proto}: $net{$ino}{sip}:$net{$ino}{sport} -> $net{$ino}{dip}:$net{$ino}{dport}\n";
								if ($suspect != 2) {$suspect = 1}
								if ($config{PT_SKIP_HTTP} and $net{$ino}{sport} =~ /^(80|443)$/) {$suspect = 2}
							}
						}
						if ($file =~ /^socket|pipe/) {next}
						$files .= $file."\n";
					}
					if ($suspect == 2) {$suspect = 0}

					if ($suspect or $deleted) {
						my $sexe = readlink("/proc/$pid/exe");
						if ($sexe eq "") {next}

						logfile("*Suspicious Process* PID:$pid PPID:$ppid User:$user Uptime:$uptime secs EXE:$exe CMD:$cmdline");

						sysopen (my $TEMPPIDS, "/var/lib/csf/csf.temppids", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot append out file: $!");
						flock ($TEMPPIDS, LOCK_EX);
						print $TEMPPIDS time.":$pid\n";
						if ($deleted and $ppid and ($ppid != $pid)) {
							my $pexe = readlink("/proc/$ppid/exe");
							$pexe =~ s/([\r\n\t\"\\\x00-\x1f\x7F-\xFF])/\\$printable{$1}/sg;
							if ($pexe =~ /\(deleted\)/) {
								print $TEMPPIDS time.":$ppid\n";
								$pids{$ppid} = 1;
							}
						}
						close ($TEMPPIDS);

						$0 = "lfd - (child) (PT) sending alert email for process $pid";

						open (my $IN,"<", "/proc/$pid/maps");
						flock ($IN, LOCK_SH);
						my @maps = <$IN>;
						close ($IN);
						chomp @maps;
						my $maps;
						foreach my $line (@maps) {$maps .= $line."\n"}

						my @alert = slurp("/usr/local/csf/tpl/processtracking.txt");
						my @message;
						foreach my $line (@alert) {
							$line =~ s/\[pid\]/$pid (Parent PID:$ppid)/ig;
							$line =~ s/\[user\]/$user/ig;
							$line =~ s/\[uptime\]/$uptime/ig;
							$line =~ s/\[sockets\]/$sockets/ig;
							$line =~ s/\[files\]/$files/ig;
							$line =~ s/\[maps\]/$maps/ig;
							$line =~ s/\[exe\]/$exet/ig;
							$line =~ s/\[cmdline\]/$cmdline/ig;
							push @message, $line;
						}
						ConfigServer::Sendmail::relay("", "", @message);

						if ($deleted and $config{PT_DELETED_ACTION} and -e "$config{PT_DELETED_ACTION}" and -x "$config{PT_DELETED_ACTION}") {
							$SIG{CHLD} = 'IGNORE';
							unless (defined ($ptchildpid = fork)) {
								&childcleanup(__LINE__,"*Error* cannot fork: $!");
							} 
							unless ($ptchildpid) {
								system($config{PT_DELETED_ACTION},$exe,$pid,$user,$ppid);
								logfile("Executed PT_DELETED_ACTION for PID:$pid");
								exit;
							}
						}

					}
				}
			}
		}
		if ($config{PT_USERPROC}) {
			$0 = "lfd - (child) (PT) checking user processes";
			foreach my $user (keys %totproc) {
				if ($ignoreusers{$user}) {next}
				if ($totproc{$user}{count} > $config{PT_USERPROC}) {
					my $kill = "Not killed";
					if ($config{PT_USERKILL}) {
						foreach my $pid (split(/\,/,$totproc{$user}{pids})) {
							kill (9, $pid);
						}
						$kill = "Killed";
					} else {
						sysopen (my $TEMPUSERS, "/var/lib/csf/csf.tempusers", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot append out file: $!");
						flock ($TEMPUSERS, LOCK_EX);
						print $TEMPUSERS time.":$user\n";
						close ($TEMPUSERS);
					}

					logfile("*Excessive Processes* User:$user Kill:$config{PT_USERKILL} Process Count:$totproc{$user}{count}");

					if (!$config{PT_USERKILL} or ($config{PT_USERKILL} and $config{PT_USERKILL_ALERT})) {
						my @alert = slurp("/usr/local/csf/tpl/usertracking.txt");
						my @message;
						foreach my $line (@alert) {
							$line =~ s/\[user\]/$user/ig;
							$line =~ s/\[count\]/$totproc{$user}{count} \($kill\)/ig;
							$line =~ s/\[text\]/$totproc{$user}{text}/ig;
							$line =~ s/\[kill\]/$kill/ig;
							push @message, $line;
						}
						ConfigServer::Sendmail::relay("", "", @message);
					}
					if ($config{PT_USER_ACTION} and -e "$config{PT_USER_ACTION}" and -x "$config{PT_USER_ACTION}") {
						$SIG{CHLD} = 'IGNORE';
						unless (defined ($ptchildpid = fork)) {
							&childcleanup(__LINE__,"*Error* cannot fork: $!");
						} 
						unless ($ptchildpid) {
							system($config{PT_USER_ACTION},$totproc{$user}{pids});
							exit;
						}
					}
				}
			}
		}

		if ($config{PT_USERMEM} or $config{PT_USERRSS} or $config{PT_USERTIME}) {
			foreach my $pid (keys %procres) {
				my $report = 0;
				my $resource;
				my $level;
				if ($config{PT_USERMEM} and ($procres{$pid}{vmsize} > ($config{PT_USERMEM} * 1024))) {
					$report = 1;
					$resource = "Virtual Memory Size";
					my $memsize = int($procres{$pid}{vmsize} / 1024);
					$level = "$memsize > $config{PT_USERMEM} (MB)";
					logfile("*User Processing* PID:$pid Kill:$config{PT_USERKILL} User:$procres{$pid}{user} VM:$memsize(MB) EXE:$procres{$pid}{exe} CMD:$procres{$pid}{cmd}");
				}
				if ($config{PT_USERRSS} and ($procres{$pid}{vmrss} > ($config{PT_USERRSS} * 1024))) {
					$report = 1;
					$resource = "RSS Memory Size";
					my $memsize = int($procres{$pid}{vmrss} / 1024);
					$level = "$memsize > $config{PT_USERRSS} (MB)";
					logfile("*User Processing* PID:$pid Kill:$config{PT_USERKILL} User:$procres{$pid}{user} RSS:$memsize(MB) EXE:$procres{$pid}{exe} CMD:$procres{$pid}{cmd}");
				}
				if ($config{PT_USERTIME} and ($procres{$pid}{uptime} > $config{PT_USERTIME})) {
					$report = 1;
					$resource = "Process Time";
					$level = "$procres{$pid}{uptime} > $config{PT_USERTIME} (seconds)";
					logfile("*User Processing* PID:$pid Kill:$config{PT_USERKILL} User:$procres{$pid}{user} Time:$procres{$pid}{uptime} EXE:$procres{$pid}{exe} CMD:$procres{$pid}{cmd}");
				}
				if ($report) {
					my $kill = "No";
					if ($config{PT_USERKILL}) {
						kill (9, $pid);
						$kill = "Yes";
					} else {
						sysopen (my $TEMPPIDS, "/var/lib/csf/csf.temppids", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot append out file: $!");
						flock ($TEMPPIDS, LOCK_EX);
						print $TEMPPIDS time.":$pid\n";
						close ($TEMPPIDS);
					}

					if (!$config{PT_USERKILL} or ($config{PT_USERKILL} and $config{PT_USERKILL_ALERT})) {
						my @alert = slurp("/usr/local/csf/tpl/resalert.txt");
						my @message;
						foreach my $line (@alert) {
							$line =~ s/\[user\]/$procres{$pid}{user}/ig;
							$line =~ s/\[cmd\]/$procres{$pid}{cmd}/ig;
							$line =~ s/\[exe\]/$procres{$pid}{exet}/ig;
							$line =~ s/\[resource\]/$resource/ig;
							$line =~ s/\[level\]/$level/ig;
							$line =~ s/\[kill\]/$kill/ig;
							$line =~ s/\[pid\]/$pid (Parent PID:$procres{$pid}{ppid})/ig;
							push @message, $line;
						}
						ConfigServer::Sendmail::relay("", "", @message);
					}

					if ($config{PT_USER_ACTION} and -e "$config{PT_USER_ACTION}" and -x "$config{PT_USER_ACTION}") {
						$SIG{CHLD} = 'IGNORE';
						unless (defined ($ptchildpid = fork)) {
							&childcleanup(__LINE__,"*Error* cannot fork: $!");
						} 
						unless ($ptchildpid) {
							system($config{PT_USER_ACTION},$pid);
							exit;
						}
					}
				}
			}
		}

		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","processtracking",$timer)}
		$0 = "lfd - (child) closing";
		exit;
	}
	return;
}
# end processtracking
###############################################################################
# start sshalert
sub sshalert {
	my $account = shift;
	my $ip = shift;
	my $method = shift;
	my $text = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","sshalert",$timer)}
		logfile("*SSH login* from $ip into the $account account using $method authentication");

		$0 = "lfd - (child) sending SSH login alert email for $ip";

		my @alert = slurp("/usr/local/csf/tpl/sshalert.txt");
		my $tip = iplookup($ip);
		my @message;
		foreach my $line (@alert) {
			$line =~ s/\[ip\]/$tip/ig;
			$line =~ s/\[account\]/$account/ig;
			$line =~ s/\[method\]/$method/ig;
			$line =~ s/\[text\]/$text/ig;
			push @message, $line;
		}
		ConfigServer::Sendmail::relay("", "", @message);

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","sshalert",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end sshalert
###############################################################################
# start sualert
sub sualert {
	my $suto = shift;
	my $sufrom = shift;
	my $status = shift;
	my $text = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","sualert",$timer)}
		logfile("*SU login* from account $sufrom to account $suto: $status");

		$0 = "lfd - (child) sending SU login alert email from $sufrom to $suto";

		my @alert = slurp("/usr/local/csf/tpl/sualert.txt");
		my @message;
		foreach my $line (@alert) {
			$line =~ s/\[to\]/$suto/ig;
			$line =~ s/\[from\]/$sufrom/ig;
			$line =~ s/\[status\]/$status/ig;
			$line =~ s/\[text\]/$text/ig;
			push @message, $line;
		}
		ConfigServer::Sendmail::relay("", "", @message);

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","sualert",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end sualert
###############################################################################
# start sudoalert
sub sudoalert {
	my $suto = shift;
	my $sufrom = shift;
	my $status = shift;
	my $text = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","sudoalert",$timer)}
		logfile("*SUDO login* from account $sufrom to account $suto: $status");

		$0 = "lfd - (child) sending SU login alert email from $sufrom to $suto";

		my @alert = slurp("/usr/local/csf/tpl/sudoalert.txt");
		my @message;
		foreach my $line (@alert) {
			$line =~ s/\[to\]/$suto/ig;
			$line =~ s/\[from\]/$sufrom/ig;
			$line =~ s/\[status\]/$status/ig;
			$line =~ s/\[text\]/$text/ig;
			push @message, $line;
		}
		ConfigServer::Sendmail::relay("", "", @message);

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","sudoalert",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end sudoalert
###############################################################################
# start webminalert
sub webminalert {
	my $account = shift;
	my $ip = shift;
	my $text = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","webminalert",$timer)}
		logfile("*Webmin login* from $ip into the $account account");

		$0 = "lfd - (child) sending Webmin login alert email for $ip";

		my @alert = slurp("/usr/local/csf/tpl/webminalert.txt");
		my $tip = iplookup($ip);
		my @message;
		foreach my $line (@alert) {
			$line =~ s/\[ip\]/$tip/ig;
			$line =~ s/\[account\]/$account/ig;
			$line =~ s/\[text\]/$text/ig;
			push @message, $line;
		}
		ConfigServer::Sendmail::relay("", "", @message);

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","webminalert",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end webminalert
###############################################################################
# start consolealert
sub consolealert {
	my $logline = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","consolealert",$timer)}
		logfile("*CONSOLE login* to root");

		$0 = "lfd - (child) sending console login alert email";

		my @alert = slurp("/usr/local/csf/tpl/consolealert.txt");
		my @message;
		foreach my $line (@alert) {
			$line =~ s/\[line\]/$logline/ig;
			push @message, $line;
		}
		ConfigServer::Sendmail::relay("", "", @message);

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","consolealert",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end consolealert
###############################################################################
# start cpanelalert
sub cpanelalert {
	my $ip = shift;
	my $user = shift;
	my $text = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","cpanelalert",$timer)}
		logfile("*WHM/cPanel $user access* from $ip");

		$0 = "lfd - (child) sending WHM/cPanel access alert email for $ip";

		my @alert = slurp("/usr/local/csf/tpl/cpanelalert.txt");
		my $tip = iplookup($ip);
		my @message;
		foreach my $line (@alert) {
			$line =~ s/\[ip\]/$tip/ig;
			$line =~ s/\[user\]/$user/ig;
			$line =~ s/\[text\]/$text/ig;
			push @message, $line;
		}
		ConfigServer::Sendmail::relay("", "", @message);

		if ($config{LF_CPANEL_ALERT_ACTION} and -e "$config{LF_CPANEL_ALERT_ACTION}" and -x "$config{LF_CPANEL_ALERT_ACTION}") {
			$0 = "lfd - (child) running LF_CPANEL_ALERT_ACTION";
			system($config{LF_CPANEL_ALERT_ACTION},$ip,$user,$tip);
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","cpanelalert",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end cpanelalert
###############################################################################
# start scriptalert
sub scriptalert {
	my $path = shift;
	my $count = shift;
	my $mails = shift;
	my $text;
	my $files;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","scriptalert",$timer)}
		if ($skipscript{$path}) {
			logfile("*Script Alert* - A script in '$path' has sent an email $count times within the last hour - ignored");
			exit;
		}
		logfile("*Script Alert* - A script in '$path' has sent an email $count times within the last hour");

		$0 = "lfd - (child) identifying possible email scripts";

		opendir (DIR, "$path");
		while (my $file = readdir (DIR)) {
			if ($file =~ /\.(php([\ds]?)|phtml|cgi|pl|pm|sh|py)$/) {
				open (my $IN, "<", "$path/$file");
				flock ($IN, LOCK_SH);
				while (my $line = <$IN>) {
					chomp $line;
					if ($line =~ /mail\s*\(/) {$files .= "'$path/$file'\n"; last;}
					if ($line =~ /sendmail/) {$files .= "'$path/$file'\n"; last;}
					if ($line =~ /exim/) {$files .= "'$path/$file'\n"; last;}
				}
				close ($IN);
			}
		}
		closedir (DIR);

		if ($config{LF_SCRIPT_PERM}) {
			if (-l $path) {
				logfile("'$path' is a symlink - *not* disabled by LF_SCRIPT_PERM");
				$files .= "\nDirectory '$path' is a symlink - *not* disabled\n";
			} else {
				my $perms = sprintf "%04o", (stat($path))[2] & oct("00777");
				$files .= "\nDirectory '$path' has been disabled with 000 permissions.\n\nTo restore the permissions use:\nchattr -i $path\nchmod $perms $path\n";
				chmod (0000,$path);
				system($config{CHATTR},"+i",$path);
				logfile("'$path' has been disabled");
			}
		}

		$0 = "lfd - (child) sending script alert";

		my @alert = slurp("/usr/local/csf/tpl/scriptalert.txt");
		my @message;
		foreach my $line (@alert) {
			$line =~ s/\[path\]/\'$path\'/ig;
			$line =~ s/\[count\]/$count/ig;
			$line =~ s/\[emails\]/$mails/ig;
			$line =~ s/\[scripts\]/$files/ig;
			push @message, $line;
		}
		ConfigServer::Sendmail::relay("", "", @message);

		if ($config{LF_SCRIPT_ACTION} and -e $config{LF_SCRIPT_ACTION} and -x $config{LF_SCRIPT_ACTION}) {
			$0 = "lfd - (child) running LF_SCRIPT_ACTION";
			system($config{LF_SCRIPT_ACTION},$path,$count,$mails,$files);
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","scriptalert",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end scriptalert
###############################################################################
# start relayalert
sub relayalert {
	my $ip = shift;
	my $cnt = shift;
	my $check = shift;
	my $mails = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","relayalert",$timer)}

		logfile("*Exceeded $check limit* from $ip ($cnt in the last hour)");

		$0 = "lfd - (child) reporting exceeded $check limit";

		my $tip = $ip;
		my $type = "$check, Local Account";
		if ($ip =~ /^127\./) {
			$type = "$check, IPv4 localhost";
		}
		elsif ($ip eq "::1") {
			$type = "$check, IPv6 localhost";
		}
		elsif (checkip(\$ip)) {
			$tip = iplookup($ip);
			$type = "$check, Remote IP";
		}

		if ($config{"RT\_$check\_BLOCK"}) {
			if (checkip(\$ip) and !&ignoreip($ip)) {
				my $perm = 0;
				if ($config{"RT\_$check\_BLOCK"} == 1) {$perm = 1}
				if (&ipblock($perm,"$tip $check limit exceeded",$ip,$ports{smtpauth},"in",$config{"RT\_$check\_BLOCK"},0,$mails,"RT\_$check\_LIMIT")) {
					if ($config{DEBUG} >= 1) {logfile("debug: $ip already blocked")}
				}
			}
		}

		my @alert = slurp("/usr/local/csf/tpl/relayalert.txt");
		my $block = "No";
		if ($config{"RT\_$check\_BLOCK"} == 1) {$block = "Permanent Block [RT\_$check\_LIMIT]"}
		if ($config{"RT\_$check\_BLOCK"} > 1) {$block = "Temporary Block for ".$config{"RT\_$check\_BLOCK"}." seconds [RT\_$check\_LIMIT]"}

		my $allowip = &allowip($ip);
		if ($allowip == 1 and $block ne "No") {$block .= " (IP match in csf.allow, block may not work)"}
		if ($allowip == 2 and $block ne "No") {$block .= " (IP match in GLOBAL_ALLOW, block may not work)"}

		my @message;
		foreach my $line (@alert) {
			$line =~ s/\[ip\]/$tip/ig;
			$line =~ s/\[block\]/$block/ig;
			$line =~ s/\[check\]/$check/ig;
			$line =~ s/\[type\]/$type/ig;
			$line =~ s/\[count\]/$cnt/ig;
			$line =~ s/\[emails\]/$mails/ig;
			push @message, $line;
		}
		ConfigServer::Sendmail::relay("", "", @message);

		if ($config{RT_ACTION} and -e "$config{RT_ACTION}" and -x "$config{RT_ACTION}") {
			$0 = "lfd - (child) running RT_ACTION";
			system($config{RT_ACTION},$ip,$check,$block,$cnt,$mails);
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","relayalert",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end relayalert
###############################################################################
# start portknocking
sub portknocking {
	my $ip = shift;
	my $port = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","portknocking",$timer)}
		logfile("*Port Knocking* port $port opened by $ip");

		$0 = "lfd - (child) sending Port Knocking alert email for $ip";

		my @alert = slurp("/usr/local/csf/tpl/portknocking.txt");
		my $tip = iplookup($ip);
		my @message;
		foreach my $line (@alert) {
			$line =~ s/\[ip\]/$tip/ig;
			$line =~ s/\[port\]/$port/ig;
			push @message, $line;
		}
		ConfigServer::Sendmail::relay("", "", @message);

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","portknocking",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end portknocking
###############################################################################
# start blocklist
sub blocklist {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","blocklist",$timer)}
		$0 = "lfd - retrieving blocklists";

		my $lockstr = "BLOCKLISTS";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		$0 = "lfd - retrieving blocklists (waiting for list lock)";
		&listlock("lock");

		my $skipcxs;
		foreach my $name (keys %blocklists) {
			if ($skipcxs) {next}
			my $getlist = 0;
			my $verbose = 1;

			if ($name =~ /^CXS_/ and $blocklists{$name}{url} =~ /download\.configserver\.com/) {
				$blocklists{$name}{interval} = 600;
				$verbose = 0;
			}
			if (-e "/var/lib/csf/csf.block.$name") {
				my $mtime = (stat("/var/lib/csf/csf.block.$name"))[9];
				my $listtime = (time - $mtime);
				if ($listtime >= $blocklists{$name}{interval}) {$getlist = 1}
			} else {$getlist = 1}

			if ($getlist and ($name eq "SPAMDROP" or $name eq "SPAMEDROP")) {
				my $tmpfile = "/var/lib/csf/$name.tmp";
				if (-e $tmpfile) {
					my $mtime = (stat($tmpfile))[9];
					my $listtime = (time - $mtime);
					if ($listtime < 7200) {
						logfile("Unable to retrieve blocklist $name for the next ".(7200 - $listtime)." secs");
						$getlist = 0;
					} else {unlink $tmpfile}
				} else {
					sysopen (my $OUT, $tmpfile, O_WRONLY | O_CREAT);
					flock ($OUT, LOCK_EX);
					print $OUT time;
					close ($OUT);
				}
			}

			if ($getlist) {
				$0 = "lfd - retrieving blocklist $name";
				my ($status, $text) = $urlget->urlget($blocklists{$name}{url});
				if ($status) {
					logfile("Unable to retrieve blocklist $name - $text");
					if ($name =~ /^CXS_/ and $text =~ /Forbidden/) {
						logfile("CXS Reputation service disabled [$text]");
						$skipcxs = 1;
						unlink "/etc/cxs/cxs.reputation";
					}
					next;
				}

				my $blcidr = Net::CIDR::Lite->new;
				eval {local $SIG{__DIE__} = undef; $blcidr->add_any("127.0.0.1")};
				my $blcidr6 = Net::CIDR::Lite->new;
				eval {local $SIG{__DIE__} = undef; $blcidr6->add("::1/128")};
				foreach my $bl (keys %blocklists) {
					if ($bl eq $name) {next}
					if (-e "/var/lib/csf/csf.block.$bl") {
						sysopen (my $BLOCK, "/var/lib/csf/csf.block.$bl", O_RDWR | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot open out file: $!");
						flock ($BLOCK, LOCK_SH);
						while (my $ipstr = <$BLOCK>) {
							chomp $ipstr;
							my $iptype = checkip(\$ipstr);
							if ($iptype == 4) {
								eval {local $SIG{__DIE__} = undef; $blcidr->add_any($ipstr)};
							}
							elsif ($iptype == 6 and $config{IPV6}) {
								eval {local $SIG{__DIE__} = undef; $blcidr6->add_any($ipstr)};
							}
						}
						close ($BLOCK);
					}
				}

				if (&csflock) {&lockfail("BLOCKLIST")}
				if ($verbose) {logfile("Retrieved and blocking blocklist $name IP address ranges")}
				my $drop = $config{DROP};
				if ($config{DROP_IP_LOGGING}) {$drop = "BLOCKDROP"}

				if ($text =~ m[^PK\x03\x04] or $text =~ m[^PK\x05\x06] or $text =~ m[^PK\x07\x08]) {
					sysopen (my $BLOCK, "/var/lib/csf/csf.block.${name}.zip", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot open out file: $!");
					flock ($BLOCK, LOCK_EX);
					print $BLOCK $text;
					close ($BLOCK);
					my @data;
					eval {
						local $SIG{__DIE__} = undef;
						local $SIG{'ALRM'} = sub {die};
						alarm(180);
						@data = &syscommand(__LINE__,$config{UNZIP},"-p","/var/lib/csf/csf.block.${name}.zip");
						alarm(0);
					};
					alarm(0);
					if ($@) {
						logfile("CC Error: Unable to unzip Blocklist $name [/var/lib/csf/csf.block.${name}.zip] - timeout");
						$text = "";
					} else {
						logfile("CC: Unzipped Blocklist $name [/var/lib/csf/csf.block.${name}.zip]");
						$text = join("\n",@data);
					}
				}

				sysopen (my $BLOCK, "/var/lib/csf/csf.block.$name", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot open out file: $!");
				flock ($BLOCK, LOCK_EX);
				seek ($BLOCK, 0, 0);
				truncate ($BLOCK, 0);
				my $count = 0;
				my @blocklist = split (/\n/,$text);
				my %seen;
				my @uniqueips = grep { ! $seen{ $_ }++ } @blocklist;
				if ($config{FASTSTART}) {$faststart = 1}
				foreach my $line (@uniqueips) {
					if ($line =~ /^\#/) {next}
					if ($line =~ /($ipv4reg(\/\d+)?)/) {
						my $iprange = $1;
						if ($name eq "DSHIELD" and $iprange !~/\/24/) {$iprange .= "/24"}
						if (checkip(\$iprange)) {
							my $skip = 0;
							eval {local $SIG{__DIE__} = undef; $skip = $blcidr->find($iprange)};
							if ($skip) {
								if ($config{DEBUG} >= 1) {logfile("debug: BLOCKLIST [$name] duplicate skipped: [$iprange]")}
								next;
							}
							$count++;
							if ($blocklists{$name}{max} > 0 and $count > $blocklists{$name}{max}) {last}
							print $BLOCK "$iprange\n";
						}
					}
					elsif ($line =~ /($ipv6reg(\/\d+)?)/) {
						my $iprange = $1;
						if (checkip(\$iprange)) {
							my $skip = 0;
							eval {local $SIG{__DIE__} = undef; $skip = $blcidr6->find($iprange)};
							if ($skip) {
								if ($config{DEBUG} >= 1) {logfile("debug: BLOCKLIST [$name] duplicate skipped: [$iprange]")}
								next;
							}
							$count++;
							if ($blocklists{$name}{max} > 0 and $count > $blocklists{$name}{max}) {last}
							print $BLOCK "$iprange\n";
						}
					}
				}
				close ($BLOCK);

				if ($config{LF_IPSET}) {
					open (my $BLOCK, "<", "/var/lib/csf/csf.block.$name");
					flock ($BLOCK, LOCK_SH);
					my @ipset6;
					while (my $line = <$BLOCK>) {
						chomp $line;
						if ($line =~ /^\#/) {next}
						if ($line =~ /($ipv4reg(\/\d+)?)/) {
							my $iprange = $1;
							push @ipset,"add new_$name $iprange\n";
						}
						elsif ($line =~ /($ipv6reg(\/\d+)?)/) {
							my $iprange = $1;
							push @ipset6,"add new_6_$name $iprange\n";
						}
					}
					close ($BLOCK);
					&ipsetrestore("new_$name");
					&ipsetswap("new_$name","bl_$name");
					if ($config{IPV6}) {
						@ipset = @ipset6;
						&ipsetrestore("new_6_$name");
						&ipsetswap("new_6_$name","bl_6_$name");
					}
				} else {
					if ($config{SAFECHAINUPDATE}) {
						&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NEW$name");
					} else {
						&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F $name");
					}
					if ($config{IPV6}) {
						if ($config{SAFECHAINUPDATE}) {
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NEW$name");
						} else {
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F $name");
						}
					}
					open (my $BLOCK, "<", "/var/lib/csf/csf.block.$name");
					flock ($BLOCK, LOCK_SH);
					while (my $line = <$BLOCK>) {
						chomp $line;
						if ($line =~ /^\#/) {next}
						if ($line =~ /($ipv4reg(\/\d+)?)/) {
							my $iprange = $1;
							if ($config{SAFECHAINUPDATE}) {
								&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NEW$name -s $iprange -j $drop");
							} else {
								&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A $name -s $iprange -j $drop");
							}
						}
						elsif ($line =~ /($ipv6reg(\/\d+)?)/) {
							my $iprange = $1;
							if ($config{SAFECHAINUPDATE}) {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NEW$name -s $iprange -j $drop");
							} else {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A $name -s $iprange -j $drop");
							}
						}
					}
					close ($BLOCK);
					if ($config{FASTSTART}) {&faststart("Blocklist [$name]")}

					$config{LF_BOGON_SKIP} =~ s/\s//g;
					if ($name eq "BOGON" and $config{LF_BOGON_SKIP} ne "") {
						foreach my $device (split(/\,/,$config{LF_BOGON_SKIP})) {
							if ($config{SAFECHAINUPDATE}) {
								&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I NEWBOGON -i $device -j RETURN");
							} else {
								&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I BOGON -i $device -j RETURN");
							}
						}
					}
					if ($config{SAFECHAINUPDATE}) {
						if ($cxsreputation and $name =~ /^CXS_/ and $name ne "CXS_ALL" and $cxsports{$name} ne "") {
							&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A LOCALINPUT -p tcp -m multiport --dport $cxsports{$name} $ethdevin -j NEW$name");
							&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALINPUT -p tcp -m multiport --dport $cxsports{$name} $ethdevin -j $name");
						} else {
							&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A LOCALINPUT $ethdevin -j NEW$name");
							&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j $name");
						}
						&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F $name");
						&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X $name");
						&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NEW$name $name");
						if ($config{IPV6}) {
							if ($cxsreputation and $name =~ /^CXS_/ and $name ne "CXS_ALL" and $cxsports{$name} ne "") {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A LOCALINPUT -p tcp -m multiport --dport $cxsports{$name} $ethdevin -j NEW$name");
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALINPUT -p tcp -m multiport --dport $cxsports{$name} $ethdevin -j $name");
							} else {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A LOCALINPUT $ethdevin -j NEW$name");
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j $name");
							}
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F $name");
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X $name");
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NEW$name $name");
						}
					}
				}
			}
		}

		&listlock("unlock");
		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","blocklist",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end blocklist
###############################################################################
# start countrycode
sub countrycode {
	my $force = shift;

	if ($config{MM_LICENSE_KEY} eq "" and $config{CC_SRC} eq "1") {
		logfile("CC Error: Country Code Lookups setting MM_LICENSE_KEY must be set in /etc/csf/csf.conf to continue using the MaxMind databases");
		return;
	}

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","countrycode",$timer)}
		$0 = "lfd - retrieving countrycode lists";

		my $lockstr = "COUNTRYCODE";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		$0 = "lfd - retrieving countrycode lists (waiting for list lock)";
		&listlock("lock");
		$0 = "lfd - retrieving countrycode lists";

		my $drop = $config{DROP};
		if ($config{DROP_IP_LOGGING}) {$drop = "CCDROP"}

		my $redo_deny = 0;
		my $redo_allow = 0;
		my $redo_allow_filter = 0;
		my $redo_allow_ports = 0;
		my $redo_deny_ports = 0;
		my $redo_allow_smtpauth = 0;
		$config{CC_DENY} =~ s/\s//g;
		$config{CC_ALLOW} =~ s/\s//g;
		$config{CC_ALLOW_FILTER} =~ s/\s//g;
		$config{CC_ALLOW_PORTS} =~ s/\s//g;
		$config{CC_DENY_PORTS} =~ s/\s//g;
		$config{CC_ALLOW_SMTPAUTH} =~ s/\s//g;
		my $getgeo = 0;
		my %cclist;

		if ($config{CC_SRC} eq "" or $config{CC_SRC} eq "1") {
			unless (-e "/var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv4.csv") {$getgeo = 1}
			if (-z "/var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv4.csv") {$getgeo = 1}
			unless (-e "/var/lib/csf/Geo/GeoLite2-ASN-Blocks-IPv4.csv") {$getgeo = 1}
			if (-z "/var/lib/csf/Geo/GeoLite2-ASN-Blocks-IPv4.csv") {$getgeo = 1}

			if (-e "/var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv4.csv") {
				my $mtime = (stat("/var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv4.csv"))[9];
				my $days = int((time - $mtime) / 86400);
				if ($days >= $config{CC_INTERVAL}) {$getgeo = 1}
			} else {$getgeo = 1}
			if ($getgeo) {
				unless (-e $config{UNZIP}) {
					logfile("Error: unzip binary ($config{UNZIP}) does not exist");
					exit;
				}
				logfile("CC: Retrieving $config{cc_src} Country database [$config{cc_country}]");
				my ($status, $text) = $urlget->urlget("$config{cc_country}","/var/lib/csf/Geo/GeoLite2-Country-CSV.zip");
				if ($status) {
					logfile("CC Error: Unable to retrieve $config{cc_src} Country database [$config{cc_country}] - $text");
				} else {
					if (-e "/var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv4.csv") {unlink "/var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv4.csv"}
					my @data;
					eval {
						local $SIG{__DIE__} = undef;
						local $SIG{'ALRM'} = sub {die};
						alarm(180);
						@data = &syscommand(__LINE__,$config{UNZIP},"-DDjod","/var/lib/csf/Geo/","/var/lib/csf/Geo/GeoLite2-Country-CSV.zip");
						alarm(0);
					};
					alarm(0);
					if ($@) {
						logfile("CC Error: Unable to unzip $config{cc_src} Country database /var/lib/csf/Geo/GeoLite2-Country-CSV.zip - timeout");
					}
					if (-z "/var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv4.csv" or !(-e "/var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv4.csv")) {
						logfile("CC Error: GeoLite2-Country-Blocks-IPv4.csv empty or missing");
					}
					foreach my $cc (split(/\,/,"$config{CC_DENY},$config{CC_ALLOW},$config{CC_ALLOW_FILTER},$config{CC_ALLOW_PORTS},$config{CC_DENY_PORTS},$config{CC_ALLOW_SMTPAUTH}")) {
						if ($cc and length($cc) == 2) {
							$cc = lc $cc;
							$cclist{$cc} = 1;
						}
					}
				}
				logfile("CC: Retrieving $config{asn_src} ASN database [$config{cc_asn}]");
				($status, $text) = $urlget->urlget("$config{cc_asn}","/var/lib/csf/Geo/GeoLite2-ASN-CSV.zip");
				if ($status) {
					logfile("CC Error: Unable to retrieve $config{asn_src} ASN database [$config{cc_asn}] - $text");
				} else {
					if (-e "/var/lib/csf/Geo/GeoLite2-ASN-Blocks-IPv4.csv") {unlink "/var/lib/csf/Geo/GeoLite2-ASN-Blocks-IPv4.csv"}
					my @data;
					eval {
						local $SIG{__DIE__} = undef;
						local $SIG{'ALRM'} = sub {die};
						alarm(180);
						@data = &syscommand(__LINE__,$config{UNZIP},"-DDjod","/var/lib/csf/Geo/","/var/lib/csf/Geo/GeoLite2-ASN-CSV.zip");
						alarm(0);
					};
					alarm(0);
					if ($@) {
						logfile("CC Error: Unable to unzip $config{cc_src} Country database /var/lib/csf/Geo/GeoLite2-ASN-CSV.zip - timeout");
					}
					if (-z "/var/lib/csf/Geo/GeoLite2-ASN-Blocks-IPv4.csv" or !(-e "/var/lib/csf/Geo/GeoLite2-ASN-Blocks-IPv4.csv")) {
						logfile("CC Error: GeoLite2-ASN-Blocks-IPv4.csv empty or missing");
					}
					foreach my $cc (split(/\,/,"$config{CC_DENY},$config{CC_ALLOW},$config{CC_ALLOW_FILTER},$config{CC_ALLOW_PORTS},$config{CC_DENY_PORTS},$config{CC_ALLOW_SMTPAUTH}")) {
						if ($cc and length($cc) > 2) {
							$cc = lc $cc;
							$cclist{$cc} = 1;
						}
					}
				}
				unlink glob "/var/lib/csf/Geo/*.zip";
				unlink glob "/var/lib/csf/Geo/*-Locations-de.csv";
				unlink glob "/var/lib/csf/Geo/*-Locations-es.csv";
				unlink glob "/var/lib/csf/Geo/*-Locations-fr.csv";
				unlink glob "/var/lib/csf/Geo/*-Locations-ja.csv";
				unlink glob "/var/lib/csf/Geo/*-Locations-pt-BR.csv";
				unlink glob "/var/lib/csf/Geo/*-Locations-ru.csv";
				unlink glob "/var/lib/csf/Geo/*-Locations-zh-CN.csv";
				unlink glob "/var/lib/csf/Geo/*.dat";
				unlink glob "/var/lib/csf/zone/*.zip";
				unlink glob "/var/lib/csf/zone/*.csv";
				unlink "/var/lib/csf/Geo/GeoIPv6.csv";
			}

			$0 = "lfd - processing countrycode lists";
			foreach my $cc (split(/\,/,"$config{CC_DENY},$config{CC_ALLOW},$config{CC_ALLOW_FILTER},$config{CC_ALLOW_PORTS},$config{CC_DENY_PORTS},$config{CC_ALLOW_SMTPAUTH}")) {
				if ($cc) {
					$cc = lc $cc;
					if (-e "/var/lib/csf/zone/$cc.zone") {
						my $mtime = (stat("/var/lib/csf/zone/$cc.zone"))[9];
						my $days = int((time - $mtime) / 86400);
						if ($days >= $config{CC_INTERVAL}) {$getgeo = 1; $cclist{$cc} = 1}
					} else {$getgeo = 1;  $cclist{$cc} = 1}
					if (-z "/var/lib/csf/zone/$cc.zone") {$getgeo = 1;  $cclist{$cc} = 1}

					if ($cclist{$cc}) {
						if ($config{CC_DENY} =~ /\b$cc\b/i) {$redo_deny = 1}
						if ($config{CC_ALLOW} =~ /\b$cc\b/i) {$redo_allow = 1}
						if ($config{CC_ALLOW_FILTER} =~ /\b$cc\b/i) {$redo_allow_filter = 1}
						if ($config{CC_ALLOW_PORTS} =~ /\b$cc\b/i) {$redo_allow_ports = 1}
						if ($config{CC_DENY_PORTS} =~ /\b$cc\b/i) {$redo_deny_ports = 1}
						if ($config{CC_ALLOW_SMTPAUTH} =~ /\b$cc\b/i) {$redo_allow_smtpauth = 1}
					}
				}
			}

			if ($getgeo) {
				logfile("CC: Processing $config{cc_src} Country/ASN database");
				my %dcidr;
				my %geoid;
				open (my $GEO, "<", "/var/lib/csf/Geo/GeoLite2-Country-Locations-en.csv");
				flock ($GEO, LOCK_SH);
				while (my $record = <$GEO>) {
					chomp $record;
					$record =~ s/\"//g;
					my ($geoname_id,undef,undef,undef,$country_iso_code,undef) = split (/\,/,$record);
					foreach my $cc (keys %cclist) {
						if (uc $cc eq uc $country_iso_code) {
							$geoid{$cc}{$geoname_id} = 1;
						}
					}
				}
				close ($GEO);
				open (my $IN, "<", "/var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv4.csv");
				flock ($IN, LOCK_SH);
				while (my $record = <$IN>) {
					chomp $record;
					$record =~ s/\"//g;
					my ($range,$geoname_id,undef) = split (/\,/,$record);
					foreach my $cc (keys %cclist) {
						if ($geoid{$cc}{$geoname_id}) {
							$dcidr{$cc}{$range} = 1;
						}
					}
				}
				close ($IN);
				open ($IN, "<", "/var/lib/csf/Geo/GeoLite2-ASN-Blocks-IPv4.csv");
				flock ($IN, LOCK_SH);
				while (my $record = <$IN>) {
					chomp $record;
					$record =~ s/\"//g;
					my ($range,$asn,undef) = split (/\,/,$record);
					foreach my $cc (keys %cclist) {
						if (uc($cc) =~ /AS(\d+)/) {
							if ($1 eq $asn) {
								$dcidr{$cc}{$range} = 1;
							}
						}
					}
				}
				close ($IN);
				foreach my $cc (keys %cclist) {
					logfile("CC: Extracting zone from $config{cc_src} Country/ASN database for [".uc($cc)."]");
					if (keys %{$dcidr{$cc}} eq 0) {
						if (length($cc) == 2) {
							logfile("CC: No entries found for [".uc($cc)."] in /var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv4.csv");
						} else {
							logfile("CC: No entries found for [".uc($cc)."] in /var/lib/csf/Geo/GeoLite2-ASN-Blocks-IPv4.csv");
						}
					} else {
						sysopen (my $CIDROUT, "/var/lib/csf/zone/$cc.zone", O_WRONLY | O_CREAT);
						flock ($CIDROUT, LOCK_EX);
						seek ($CIDROUT, 0, 0);
						truncate ($CIDROUT, 0);
						foreach my $key (keys %{$dcidr{$cc}}) {print $CIDROUT "$key\n"}
						close ($CIDROUT);
					}
				}
			}
		} elsif ($config{CC_SRC} eq "2") {
			unless (-e "/var/lib/csf/Geo/ip2asn-combined.tsv") {$getgeo = 1}
			if (-z "/var/lib/csf/Geo/ip2asn-combined.tsv") {$getgeo = 1}

			if ($getgeo) {
				unless (-e $config{UNZIP}) {
					logfile("Error: unzip binary ($config{UNZIP}) does not exist");
					exit;
				}
				logfile("CC: Retrieving $config{asn_src} ASN database [$config{cc_asn}]");
				my ($status, $text) = $urlget->urlget("$config{cc_asn}","/var/lib/csf/Geo/ip2asn-combined.tsv.gz");
				if ($status) {
					logfile("CC Error: Unable to retrieve $config{asn_src} ASN database [$config{cc_asn}] - $text");
				} else {
					if (-e "/var/lib/csf/Geo/ip2asn-combined.tsv") {unlink "/var/lib/csf/Geo/ip2asn-combined.tsv"}
					my @data;
					eval {
						local $SIG{__DIE__} = undef;
						local $SIG{'ALRM'} = sub {die};
						alarm(180);
						@data = &syscommand(__LINE__,$config{GUNZIP},"/var/lib/csf/Geo/ip2asn-combined.tsv.gz");
						alarm(0);
					};
					alarm(0);
					if ($@) {
						logfile("CC Error: Unable to unzip $config{cc_src} Country database /var/lib/csf/Geo/ip2asn-combined.tsv.gz - timeout");
					}
					if (-z "/var/lib/csf/Geo/ip2asn-combined.tsv" or !(-e "/var/lib/csf/Geo/ip2asn-combined.tsv")) {
						logfile("CC Error: ip2asn-combined.tsv empty or missing");
					}
					foreach my $cc (split(/\,/,"$config{CC_DENY},$config{CC_ALLOW},$config{CC_ALLOW_FILTER},$config{CC_ALLOW_PORTS},$config{CC_DENY_PORTS},$config{CC_ALLOW_SMTPAUTH}")) {
						if ($cc and length($cc) > 2) {
							$cc = lc $cc;
							$cclist{$cc} = 1;
						}
					}
				}
			}

			$0 = "lfd - processing countrycode lists";
			foreach my $cc (split(/\,/,"$config{CC_DENY},$config{CC_ALLOW},$config{CC_ALLOW_FILTER},$config{CC_ALLOW_PORTS},$config{CC_DENY_PORTS},$config{CC_ALLOW_SMTPAUTH}")) {
				if ($cc) {
					$cc = lc $cc;
					if (-e "/var/lib/csf/zone/$cc.zone") {
						my $mtime = (stat("/var/lib/csf/zone/$cc.zone"))[9];
						my $days = int((time - $mtime) / 86400);
						if ($days >= $config{CC_INTERVAL}) {$getgeo = 1; $cclist{$cc} = 1}
					} else {$getgeo = 1;  $cclist{$cc} = 1}
					if (-z "/var/lib/csf/zone/$cc.zone") {$getgeo = 1;  $cclist{$cc} = 1}

					if ($cclist{$cc}) {
						if ($config{CC_DENY} =~ /\b$cc\b/i) {$redo_deny = 1}
						if ($config{CC_ALLOW} =~ /\b$cc\b/i) {$redo_allow = 1}
						if ($config{CC_ALLOW_FILTER} =~ /\b$cc\b/i) {$redo_allow_filter = 1}
						if ($config{CC_ALLOW_PORTS} =~ /\b$cc\b/i) {$redo_allow_ports = 1}
						if ($config{CC_DENY_PORTS} =~ /\b$cc\b/i) {$redo_deny_ports = 1}
						if ($config{CC_ALLOW_SMTPAUTH} =~ /\b$cc\b/i) {$redo_allow_smtpauth = 1}
					}
				}
			}

			if ($getgeo) {
				logfile("CC: Processing $config{asn_src} ASN database");
				my %dcidr;
				open ($IN, "<", "/var/lib/csf/Geo/ip2asn-combined.tsv");
				flock ($IN, LOCK_SH);
				while (my $record = <$IN>) {
					chomp $record;
					$record =~ s/\"//g;
					my ($start,$end,$asn,undef) = split (/\t/,$record);
					if (checkip($start) == 6) {last}
					foreach my $cc (keys %cclist) {
						if (uc($cc) =~ /AS(\d+)/) {
							if ($1 eq $asn) {
								my $ipscidr = Net::CIDR::Lite->new;
								eval {local $SIG{__DIE__} = undef; $ipscidr->add_range("$start-$end")};
								my @cidr_list = $ipscidr->list;
								foreach my $list (@cidr_list) {
									$dcidr{$cc}{$list} = 1;
								}
							}
						}
					}
				}
				close ($IN);
				foreach my $cc (keys %cclist) {
					if (length($cc) > 2) {
						logfile("CC: Extracting zone from $config{asn_src} ASN database for [".uc($cc)."]");
						if (keys %{$dcidr{$cc}} eq 0) {
							logfile("CC: No entries found for [".uc($cc)."] in /var/lib/csf/Geo/ip2asn-combined.tsv");
						} else {
							sysopen (my $CIDROUT, "/var/lib/csf/zone/$cc.zone", O_WRONLY | O_CREAT);
							flock ($CIDROUT, LOCK_EX);
							seek ($CIDROUT, 0, 0);
							truncate ($CIDROUT, 0);
							foreach my $key (keys %{$dcidr{$cc}}) {print $CIDROUT "$key\n"}
							close ($CIDROUT);
						}
					}
					elsif (length($cc) == 2) {
						logfile("CC: Retrieving $config{ccl_src} Country Code Zone [".uc($cc)."] from https://www.ipdeny.com");
						my ($status, $text) = $urlget->urlget("https://www.ipdeny.com/ipblocks/data/aggregated/${cc}-aggregated.zone","/var/lib/csf/zone/$cc.zone");
						if ($status) {
							logfile("CC Error: Unable to retrieve $config{ccl_src} Country Code Zone [".uc($cc)."] from https://www.ipdeny.com/ - $text");
						} else {
							logfile("CC: Country Code Zone [".uc($cc)."] retrieved");
						}
						sleep 1;
					}
				}
			}
		}
		
		if ($force) {
			$redo_deny = 1;
			$redo_allow = 1;
			$redo_allow_filter = 1;
			$redo_allow_ports = 1;
			$redo_deny_ports = 1;
			$redo_allow_smtpauth = 1;
		}

		if ($config{LF_IPSET}) {
			my $cclist;
			my $cnt = 0;
			if ($redo_deny) {$cclist .= $config{CC_DENY}.","}
			if ($redo_allow) {$cclist .= $config{CC_ALLOW}.","}
			if ($redo_allow_filter) {$cclist .= $config{CC_ALLOW_FILTER}.","}
			if ($redo_allow_ports) {$cclist .= $config{CC_ALLOW_PORTS}.","}
			if ($redo_deny_ports) {$cclist .= $config{CC_DENY_PORTS}}
			if ($config{CC_ALLOW_FILTER} and $redo_allow_filter) {&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F CC_ALLOWF")}
			foreach my $cc (split(/\,/,$cclist)) {
				if ($cc eq "") {next}
				undef @ipset;
				$cc = lc $cc;
				if ($config{CC_ALLOW_FILTER} and $redo_allow_filter) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A CC_ALLOWF -m set --match-set cc_$cc src -j RETURN");}
				if (-e "/var/lib/csf/zone/$cc.zone") {
					logfile("CC: Repopulating ipset cc_$cc with IP addresses from [".uc($cc)."]");
					open (my $IN, "<", "/var/lib/csf/zone/$cc.zone");
					flock ($IN, LOCK_SH);
					while (my $line = <$IN>) {
						chomp $line;
						my ($ip,undef) = split (/\s/,$line,2);
						if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
							my ($drop_ip,$drop_cidr) = split(/\//,$ip);
							if ($drop_cidr eq "") {$drop_cidr = "32"}
							if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
						}
						if (checkip(\$ip)) {
							push @ipset,"add new_$cc $ip";
							$cnt++;
						}
					}
					&ipsetrestore("new_$cc");
					&ipsetswap("new_$cc","cc_$cc");
				}
			}
			if ($config{CC_ALLOW_FILTER} and $redo_allow_filter and $cnt > 0) {
				&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A CC_ALLOWF -j $drop");
				if ($config{LF_SPI}) {
					my $statemodule = "-m state --state";
					if ($config{USE_CONNTRACK}) {$statemodule = "-m conntrack --ctstate"}
					if ($config{USE_FTPHELPER}) {
						&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I CC_ALLOWF $ethdevin $statemodule RELATED -m helper --helper ftp -j $accept");

						&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I CC_ALLOWF $ethdevin $statemodule ESTABLISHED -j $accept");
					} else {
						&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I CC_ALLOWF $ethdevin $statemodule ESTABLISHED,RELATED -j $accept");
					}
				}
			}
		} else {
			if ($config{CC_DENY} and $redo_deny) {
				if (&csflock) {&lockfail("CC_DENY")}
				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NEWCC_DENY");
				} else {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F CC_DENY");
				}
				foreach my $cc (split(/\,/,$config{CC_DENY})) {
					$cc = lc $cc;
					if (-e "/var/lib/csf/zone/$cc.zone") {
						if ($config{FASTSTART}) {$faststart = 1}
						logfile("CC: Repopulating CC_DENY with IP addresses from [".uc($cc)."]");
						open (my $IN, "<", "/var/lib/csf/zone/$cc.zone");
						flock ($IN, LOCK_SH);
						while (my $line = <$IN>) {
							chomp $line;
							my ($ip,undef) = split (/\s/,$line,2);
							if (checkip(\$ip)) {
								if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
									my ($drop_ip,$drop_cidr) = split(/\//,$ip);
									if ($drop_cidr eq "") {$drop_cidr = "32"}
									if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
								}
								if ($config{SAFECHAINUPDATE}) {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NEWCC_DENY -s $ip -j $drop");
								} else {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A CC_DENY -s $ip -j $drop");
								}
							}
						}
						close ($IN);
						if ($config{FASTSTART}) {&faststart("CC_DENY [".uc($cc)."]")}
						logfile("CC: Finished repopulating CC_DENY with IP addresses from [".uc($cc)."]");
					}
				}
				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A LOCALINPUT $ethdevin -j NEWCC_DENY");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j CC_DENY");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F CC_DENY");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X CC_DENY");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NEWCC_DENY CC_DENY");
				}
			}

			if ($config{CC_ALLOW} and $redo_allow) {
				if (&csflock) {&lockfail("CC_ALLOW")}
				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NEWCC_ALLOW");
				} else {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F CC_ALLOW");
				}
				foreach my $cc (split(/\,/,$config{CC_ALLOW})) {
					$cc = lc $cc;
					if (-e "/var/lib/csf/zone/$cc.zone") {
						if ($config{FASTSTART}) {$faststart = 1}
						logfile("CC: Repopulating CC_ALLOW with IP addresses from [".uc($cc)."]");
						open (my $IN, "<", "/var/lib/csf/zone/$cc.zone");
						flock ($IN, LOCK_SH);
						while (my $line = <$IN>) {
							chomp $line;
							my ($ip,undef) = split (/\s/,$line,2);
							if (checkip(\$ip)) {
								if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
									my ($drop_ip,$drop_cidr) = split(/\//,$ip);
									if ($drop_cidr eq "") {$drop_cidr = "32"}
									if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
								}
								if ($config{SAFECHAINUPDATE}) {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NEWCC_ALLOW -s $ip -j $accept");
								} else {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A CC_ALLOW -s $ip -j $accept");
								}
							}
						}
						close ($IN);
						if ($config{FASTSTART}) {&faststart("CC_ALLOW [".uc($cc)."]")}
						logfile("CC: Finished repopulating CC_ALLOW with IP addresses from [".uc($cc)."]");
					}
				}
				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I LOCALINPUT $ethdevin -j NEWCC_ALLOW");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j CC_ALLOW");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F CC_ALLOW");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X CC_ALLOW");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NEWCC_ALLOW CC_ALLOW");
				}
			}

			if ($config{CC_ALLOW_FILTER} and $redo_allow_filter) {
				my $cnt = 0;
				if (&csflock) {&lockfail("CC_ALLOW_FILTER")}
				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NCC_ALLOWF");
				} else {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F CC_ALLOWF");
				}
				foreach my $cc (split(/\,/,$config{CC_ALLOW_FILTER})) {
					$cc = lc $cc;
					if (-e "/var/lib/csf/zone/$cc.zone") {
						if ($config{FASTSTART}) {$faststart = 1}
						logfile("CC: Repopulating CC_ALLOWF with IP addresses from [".uc($cc)."]");
						open (my $IN, "<", "/var/lib/csf/zone/$cc.zone");
						flock ($IN, LOCK_SH);
						while (my $line = <$IN>) {
							chomp $line;
							my ($ip,undef) = split (/\s/,$line,2);
							if (checkip(\$ip)) {
								if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
									my ($drop_ip,$drop_cidr) = split(/\//,$ip);
									if ($drop_cidr eq "") {$drop_cidr = "32"}
									if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
								}
								$cnt++;
								if ($config{SAFECHAINUPDATE}) {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NCC_ALLOWF -s $ip -j RETURN");
								} else {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A CC_ALLOWF -s $ip -j RETURN");
								}
							}
						}
						close ($IN);
						if ($config{FASTSTART}) {&faststart("CC_ALLOW_FILTER [".uc($cc)."]")}
						logfile("CC: Finished repopulating CC_ALLOWF with IP addresses from [".uc($cc)."]");
					}
				}
				if ($config{SAFECHAINUPDATE}) {
					if ($cnt > 0) {&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NCC_ALLOWF -j $drop")}
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A LOCALINPUT $ethdevin -j NCC_ALLOWF");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j CC_ALLOWF");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F CC_ALLOWF");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X CC_ALLOWF");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NCC_ALLOWF CC_ALLOWF");
				} else {
					if ($cnt > 0) {
						&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A CC_ALLOWF -j $drop");
						if ($config{LF_SPI}) {
							my $statemodule = "-m state --state";
							if ($config{USE_CONNTRACK}) {$statemodule = "-m conntrack --ctstate"}
							if ($config{USE_FTPHELPER}) {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I CC_ALLOWF $ethdevin $statemodule RELATED -m helper --helper ftp -j $accept");

								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I CC_ALLOWF $ethdevin $statemodule ESTABLISHED -j $accept");
							} else {
								&syscommand(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I CC_ALLOWF $ethdevin $statemodule ESTABLISHED,RELATED -j $accept");
							}
						}
					}
				}
			}

			if ($config{CC_ALLOW_PORTS} and $redo_allow_ports) {
				my $cnt = 0;
				if (&csflock) {&lockfail("CC_ALLOW_PORTS")}
				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NCC_ALLOWP");
				} else {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F CC_ALLOWP");
				}
				foreach my $cc (split(/\,/,$config{CC_ALLOW_PORTS})) {
					$cc = lc $cc;
					if (-e "/var/lib/csf/zone/$cc.zone") {
						if ($config{FASTSTART}) {$faststart = 1}
						logfile("CC: Repopulating CC_ALLOWP with IP addresses from [".uc($cc)."]");
						open (my $IN, "<", "/var/lib/csf/zone/$cc.zone");
						flock ($IN, LOCK_SH);
						while (my $line = <$IN>) {
							chomp $line;
							my ($ip,undef) = split (/\s/,$line,2);
							if (checkip(\$ip)) {
								if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
									my ($drop_ip,$drop_cidr) = split(/\//,$ip);
									if ($drop_cidr eq "") {$drop_cidr = "32"}
									if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
								}
								$cnt++;
								if ($config{SAFECHAINUPDATE}) {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NCC_ALLOWP -s $ip -j CC_ALLOWPORTS");
								} else {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A CC_ALLOWP -s $ip -j CC_ALLOWPORTS");
								}
							}
						}
						close ($IN);
						if ($config{FASTSTART}) {&faststart("CC_ALLOW_PORTS [".uc($cc)."]")}
						logfile("CC: Finished repopulating CC_ALLOWP with IP addresses from [".uc($cc)."]");
					}
				}
				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A LOCALINPUT $ethdevin -j NCC_ALLOWP");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j CC_ALLOWP");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F CC_ALLOWP");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X CC_ALLOWP");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NCC_ALLOWP CC_ALLOWP");
				}
			}

			if ($config{CC_DENY_PORTS} and $redo_deny_ports) {
				my $cnt = 0;
				if (&csflock) {&lockfail("CC_DENY_PORTS")}
				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NCC_DENYP");
				} else {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F CC_DENYP");
				}
				foreach my $cc (split(/\,/,$config{CC_DENY_PORTS})) {
					$cc = lc $cc;
					if (-e "/var/lib/csf/zone/$cc.zone") {
						if ($config{FASTSTART}) {$faststart = 1}
						logfile("CC: Repopulating CC_DENYP with IP addresses from [".uc($cc)."]");
						open (my $IN, "<", "/var/lib/csf/zone/$cc.zone");
						flock ($IN, LOCK_SH);
						while (my $line = <$IN>) {
							chomp $line;
							my ($ip,undef) = split (/\s/,$line,2);
							if (checkip(\$ip)) {
								if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
									my ($drop_ip,$drop_cidr) = split(/\//,$ip);
									if ($drop_cidr eq "") {$drop_cidr = "32"}
									if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
								}
								$cnt++;
								if ($config{SAFECHAINUPDATE}) {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NCC_DENYP -s $ip -j CC_DENYPORTS");
								} else {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A CC_DENYP -s $ip -j CC_DENYPORTS");
								}
							}
						}
						close ($IN);
						if ($config{FASTSTART}) {&faststart("CC_DENY_PORTS [".uc($cc)."]")}
						logfile("CC: Finished repopulating CC_DENYP with IP addresses from [".uc($cc)."]");
					}
				}
				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A LOCALINPUT $ethdevin -j NCC_DENYP");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j CC_DENYP");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F CC_DENYP");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X CC_DENYP");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NCC_DENYP CC_DENYP");
				}
			}
		}
		if ($config{CC6_LOOKUPS} and $config{IPV6}) {
			&countrycode6($force);
		}

		if ($config{CC_ALLOW_SMTPAUTH} and $config{SMTPAUTH_RESTRICT} and $redo_allow_smtpauth) {
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
						my $status = checkip(\$ip);
						if ($status == 4) {print $SMTPAUTH "$ip\n"}
						elsif ($status == 6) {print $SMTPAUTH "\"$ip\"\n"}
					}
					logfile("CC: Finished repopulating /etc/exim.smtpauth with IPv4 addresses from [".uc($cc)."]");
				}
				if ($config{CC6_LOOKUPS} and -e "/var/lib/csf/zone/$cc.zone6") {
					print $SMTPAUTH "\n# IPv6 addresses for [".uc($cc)."]:\n";
					foreach my $line (slurp("/var/lib/csf/zone/$cc.zone6")) {
						$line =~ s/$cleanreg//g;
						if ($line =~ /^(\s|\#|$)/) {next}
						my ($ip,undef) = split (/\s/,$line,2);
						if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
							my ($drop_ip,$drop_cidr) = split(/\//,$ip);
							if ($drop_cidr eq "") {$drop_cidr = "32"}
							if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
						}
						my $status = checkip(\$ip);
						if ($status == 4) {print $SMTPAUTH "$ip\n"}
						elsif ($status == 6) {print $SMTPAUTH "\"$ip\"\n"}
					}
					logfile("CC: Finished repopulating /etc/exim.smtpauth with IPv6 addresses from [".uc($cc)."]");
				}
			}
			close ($SMTPAUTH);
			chmod (0644,"/etc/exim.smtpauth");
		}

		&listlock("unlock");
		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","countrycode",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end countrycode
###############################################################################
# start countrycodelookups
sub countrycodelookups {
	my $force = shift;
	if ($config{CC_LOOKUPS} == 4) {return}

	if ($config{MM_LICENSE_KEY} eq "" and $config{CC_SRC} eq "1") {
		logfile("CC Error: Country Code Filters setting MM_LICENSE_KEY must be set in /etc/csf/csf.conf to continue using the MaxMind databases");
		return;
	}

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","countrycodelookups",$timer)}
		$0 = "lfd - retrieving countrycode lookups";

		my $lockstr = "CC_LOOKUPS";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		$0 = "lfd - retrieving countrycodelookups lists (waiting for list lock)";
		&listlock("lock");
		$0 = "lfd - retrieving countrycodelookups lists";

		if ($config{CC_SRC} eq "" or $config{CC_SRC} eq "1") {
			my $getgeo = 0;
			my $geofile = "/var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv4.csv";
			if ($config{CC_LOOKUPS} == 2 or $config{CC_LOOKUPS} == 3) {$geofile = "/var/lib/csf/Geo/GeoLite2-City-Blocks-IPv4.csv"}
			if (-e $geofile) {
				if (-z $geofile) {$getgeo = 1}
				my $mtime = (stat($geofile))[9];
				my $days = int((time - $mtime) / 86400);
				if ($days >= $config{CC_INTERVAL}) {$getgeo = 1}

				if ($config{CC_LOOKUPS} == 3) {
					my $geofile = "/var/lib/csf/Geo/GeoLite2-ASN-Blocks-IPv4.csv";
					if (-z $geofile) {$getgeo = 1}
					my $mtime = (stat($geofile))[9];
					my $days = int((time - $mtime) / 86400);
					if ($days >= $config{CC_INTERVAL}) {$getgeo = 1}
				}
			} else {$getgeo = 1}
			if ($getgeo) {
				my $status;
				my $text;
				if ($config{CC_LOOKUPS} == 3) {
					logfile("CCL: Retrieving $config{asn_src} ASN database [$config{cc_asn}]");
					($status, $text) = $urlget->urlget("$config{cc_asn}","/var/lib/csf/Geo/GeoLite2-ASN-CSV.zip");
					logfile("CCL: Retrieving $config{cc_src} City database [$config{cc_city}]");
					($status, $text) = $urlget->urlget("$config{cc_city}","/var/lib/csf/Geo/GeoLite2-City-CSV.zip");
				}
				elsif ($config{CC_LOOKUPS} == 2) {
					logfile("CCL: Retrieving $config{cc_src} City database [$config{cc_city}]");
					($status, $text) = $urlget->urlget("$config{cc_city}","/var/lib/csf/Geo/GeoLite2-City-CSV.zip");
				}
				else {
					logfile("CCL: Retrieving $config{cc_src} Country database [$config{cc_country}]");
					($status, $text) = $urlget->urlget("$config{cc_country}","/var/lib/csf/Geo/GeoLite2-Country-CSV.zip");
				}
				if ($status) {
					if ($config{CC_LOOKUPS} == 2 or $config{CC_LOOKUPS} == 3) {
						logfile("CCL Error: Unable to retrieve $config{cc_src} City database [$config{cc_city}] - $text");
					} else {
						logfile("CCL Error: Unable to retrieve $config{cc_src} Country database [$config{cc_country}] - $text");
					}
				} else {
					my @data;
					eval {
						local $SIG{__DIE__} = undef;
						local $SIG{'ALRM'} = sub {die};
						alarm(180);
						my ($childin, $childout, $cmdpid);
						if ($config{CC_LOOKUPS} == 3) {
							@data = &syscommand(__LINE__,$config{UNZIP},"-DDjod","/var/lib/csf/Geo/","/var/lib/csf/Geo/GeoLite2-ASN-CSV.zip");
							@data = &syscommand(__LINE__,$config{UNZIP},"-DDjod","/var/lib/csf/Geo/","/var/lib/csf/Geo/GeoLite2-City-CSV.zip");
						}
						elsif ($config{CC_LOOKUPS} == 2) {
							@data = &syscommand(__LINE__,$config{UNZIP},"-DDjod","/var/lib/csf/Geo/","/var/lib/csf/Geo/GeoLite2-City-CSV.zip");
						}
						else {
							@data = &syscommand(__LINE__,$config{UNZIP},"-DDjod","/var/lib/csf/Geo/","/var/lib/csf/Geo/GeoLite2-Country-CSV.zip");
						}
						alarm(0);
					};
					alarm(0);
					if ($@) {
						if ($config{CC_LOOKUPS} == 2 or $config{CC_LOOKUPS} == 3) {
							logfile("CCL Error: Unable to unzip $config{cc_src} City database /var/lib/csf/Geo/GeoLite2-City-CSV.zip - timeout");
						} else {
							logfile("CCL Error: Unable to unzip $config{cc_src} Country database /var/lib/csf/Geo/GeoLite2-Country-CSV.zip - timeout");
						}
					}
					if (!(-e $geofile) or -z $geofile) {
						logfile("CCL Error: $geofile empty or missing");
					} else {
						my $now = time;
						utime ($now,$now,$geofile);
						logfile("CCL: Retrieved $config{cc_src} IP database");
						open (my $OUT, ">", "/var/lib/csf/csf.cclookup");
						close ($OUT);
					}
				}
				unlink glob "/var/lib/csf/Geo/*.zip";
				unlink glob "/var/lib/csf/Geo/*-Locations-de.csv";
				unlink glob "/var/lib/csf/Geo/*-Locations-es.csv";
				unlink glob "/var/lib/csf/Geo/*-Locations-fr.csv";
				unlink glob "/var/lib/csf/Geo/*-Locations-ja.csv";
				unlink glob "/var/lib/csf/Geo/*-Locations-pt-BR.csv";
				unlink glob "/var/lib/csf/Geo/*-Locations-ru.csv";
				unlink glob "/var/lib/csf/Geo/*-Locations-zh-CN.csv";
				unlink glob "/var/lib/csf/Geo/*.dat";
				unlink glob "/var/lib/csf/zone/*.zip";
				unlink glob "/var/lib/csf/zone/*.csv";
				unlink "/var/lib/csf/Geo/GeoIPv6.csv";
			}
		} elsif ($config{CC_SRC} eq "2") {
			my $getgeo = 0;
			my $geofile = "/var/lib/csf/Geo/dbip-country-lite.csv";
			if ($config{CC_LOOKUPS} == 2 or $config{CC_LOOKUPS} == 3) {$geofile = "/var/lib/csf/Geo/dbip-city-lite.csv"}
			if (-e $geofile) {
				if (-z $geofile) {$getgeo = 1}
				my $mtime = (stat($geofile))[9];
				my $days = int((time - $mtime) / 86400);
				if ($days >= $config{CC_INTERVAL}) {$getgeo = 1}

				if ($config{CC_LOOKUPS} == 3) {
					my $geofile = "/var/lib/csf/Geo/ip2asn-combined.tsv";
					if (-z $geofile) {$getgeo = 1}
					my $mtime = (stat($geofile))[9];
					my $days = int((time - $mtime) / 86400);
					if ($days >= $config{CC_INTERVAL}) {$getgeo = 1}
				}
			} else {$getgeo = 1}
			if ($getgeo) {
				unless (-e $config{GUNZIP}) {
					logfile("Error: gunzip binary ($config{GUNZIP}) does not exist");
					exit;
				}
				logfile("CCL: Retrieving CC Lookup database [$config{cc_cc}]");
				my ($status, $text) = $urlget->urlget("$config{cc_cc}","/var/lib/csf/Geo/countryInfo.txt");
				if ($status) {
					logfile("CCL Error: Unable to retrieve $config{cc_src} CC Lookup database [$config{cc_cc}] - $text");
				} else {
					if (-z "/var/lib/csf/Geo/countryInfo.txt" or !(-e "/var/lib/csf/Geo/countryInfo.txt")) {
						logfile("CC Error: countryInfo.txt empty or missing");
					}
				}
				if ($config{CC_LOOKUPS} == 2 or $config{CC_LOOKUPS} == 3) {
					logfile("CCL: Retrieving $config{cc_src} City database [$config{cc_city}]");
					my ($status, $text) = $urlget->urlget("$config{cc_city}","/var/lib/csf/Geo/dbip-city-lite.csv.gz");
					if ($status) {
						logfile("CCL Error: Unable to retrieve $config{cc_src} City database [$config{cc_city}] - $text");
					} else {
						if (-e "/var/lib/csf/Geo/dbip-city-lite.csv") {unlink "/var/lib/csf/Geo/dbip-city-lite.csv"}
						my @data;
						eval {
							local $SIG{__DIE__} = undef;
							local $SIG{'ALRM'} = sub {die};
							alarm(180);
							@data = &syscommand(__LINE__,$config{GUNZIP},"/var/lib/csf/Geo/dbip-city-lite.csv.gz");
							alarm(0);
						};
						alarm(0);
						if ($@) {
							logfile("CCL Error: Unable to gunzip $config{cc_src} City database /var/lib/csf/Geo/dbip-city-lite.csv.gz - timeout");
						}
						if (-z "/var/lib/csf/Geo/dbip-city-lite.csv" or !(-e "/var/lib/csf/Geo/dbip-city-lite.csv")) {
							logfile("CCL Error: dbip-city-lite.csv empty or missing");
						}
					}
					if ($config{CC_LOOKUPS} == 3) {
						logfile("CCL: Retrieving $config{asn_src} ASN database [$config{cc_asn}]");
						($status, $text) = $urlget->urlget("$config{cc_asn}","/var/lib/csf/Geo/ip2asn-combined.tsv.gz");
						if ($status) {
							logfile("CCL Error: Unable to retrieve $config{asn_src} ASN database [$config{cc_asn}] - $text");
						} else {
							if (-e "/var/lib/csf/Geo/ip2asn-combined.tsv") {unlink "/var/lib/csf/Geo/ip2asn-combined.tsv"}
							my @data;
							eval {
								local $SIG{__DIE__} = undef;
								local $SIG{'ALRM'} = sub {die};
								alarm(180);
								@data = &syscommand(__LINE__,$config{GUNZIP},"/var/lib/csf/Geo/ip2asn-combined.tsv.gz");
								alarm(0);
							};
							alarm(0);
							if ($@) {
								logfile("CCL Error: Unable to unzip $config{cc_src} Country database /var/lib/csf/Geo/ip2asn-combined.tsv.gz - timeout");
							}
							if (-z "/var/lib/csf/Geo/ip2asn-combined.tsv" or !(-e "/var/lib/csf/Geo/ip2asn-combined.tsv")) {
								logfile("CCL Error: ip2asn-combined.tsv empty or missing");
							}
						}
					}
				} else {
					logfile("CC: Retrieving $config{cc_src} Country database [$config{cc_country}]");
					my ($status, $text) = $urlget->urlget("$config{cc_country}","/var/lib/csf/Geo/dbip-country-lite.csv.gz");
					if ($status) {
						logfile("CCL Error: Unable to retrieve $config{cc_src} Country database [$config{cc_country}] - $text");
					} else {
						if (-e "/var/lib/csf/Geo/dbip-country-lite.csv") {unlink "/var/lib/csf/Geo/dbip-country-lite.csv"}
						my @data;
						eval {
							local $SIG{__DIE__} = undef;
							local $SIG{'ALRM'} = sub {die};
							alarm(180);
							@data = &syscommand(__LINE__,$config{GUNZIP},"/var/lib/csf/Geo/dbip-country-lite.csv.gz");
							alarm(0);
						};
						alarm(0);
						if ($@) {
							logfile("CC Error: Unable to gunzip $config{cc_src} Country database /var/lib/csf/Geo/dbip-country-lite.csv.gz - timeout");
						}
						if (-z "/var/lib/csf/Geo/dbip-country-lite.csv" or !(-e "/var/lib/csf/Geo/dbip-country-lite.csv")) {
							logfile("CC Error: dbip-country-lite.csv empty or missing");
						}
					}
				}
			}
		}

		&listlock("unlock");
		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","countrycodelookups",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end countrycodelookups
###############################################################################
# start countrycode6
sub countrycode6 {
	my $force = shift;
	my $getgeo;
	my %cclist;
	my $redo_deny = 0;
	my $redo_allow = 0;
	my $redo_allow_filter = 0;
	my $redo_allow_ports = 0;
	my $redo_deny_ports = 0;
	my $redo_allow_smtpauth = 0;
	my $drop = $config{DROP};
	if ($config{DROP_IP_LOGGING}) {$drop = "CCDROP"}

	$config{CC_DENY} =~ s/\s//g;
	$config{CC_ALLOW} =~ s/\s//g;
	$config{CC_ALLOW_FILTER} =~ s/\s//g;
	$config{CC_ALLOW_PORTS} =~ s/\s//g;
	$config{CC_DENY_PORTS} =~ s/\s//g;
	$config{CC_ALLOW_SMTPAUTH} =~ s/\s//g;

	if ($force) {
		$redo_deny = 1;
		$redo_allow = 1;
		$redo_allow_filter = 1;
		$redo_allow_ports = 1;
		$redo_deny_ports = 1;
		$redo_allow_smtpauth = 1;
	}

	$0 = "lfd - processing countrycode6 lists";
	foreach my $cc (split(/\,/,"$config{CC_DENY},$config{CC_ALLOW},$config{CC_ALLOW_FILTER},$config{CC_ALLOW_PORTS},$config{CC_DENY_PORTS},$config{CC_ALLOW_SMTPAUTH}")) {
		if ($cc eq "") {next}
		$cc = lc $cc;
		if (-e "/var/lib/csf/zone/$cc.zone6") {
			my $mtime = (stat("/var/lib/csf/zone/$cc.zone6"))[9];
			my $days = int((time - $mtime) / 86400);
			if ($days >= $config{CC_INTERVAL}) {$getgeo = 1; $cclist{$cc} = 1}
		} else {$getgeo = 1;  $cclist{$cc} = 1}
		if (-z "/var/lib/csf/zone/$cc.zone6") {$getgeo = 1;  $cclist{$cc} = 1}

		if ($cclist{$cc}) {
			if ($config{CC_DENY} =~ /\b$cc\b/i) {$redo_deny = 1}
			if ($config{CC_ALLOW} =~ /\b$cc\b/i) {$redo_allow = 1}
			if ($config{CC_ALLOW_FILTER} =~ /\b$cc\b/i) {$redo_allow_filter = 1}
			if ($config{CC_ALLOW_PORTS} =~ /\b$cc\b/i) {$redo_allow_ports = 1}
			if ($config{CC_DENY_PORTS} =~ /\b$cc\b/i) {$redo_deny_ports = 1}
			if ($config{CC_ALLOW_SMTPAUTH} =~ /\b$cc\b/i) {$redo_allow_smtpauth = 1}
		}
	}

	if ($config{CC_SRC} eq "" or $config{CC_SRC} eq "1") {
		if ($getgeo) {
			logfile("CC: Processing $config{cc_src} Country/ASN IPv6 database");
			my %dcidr;
			my %geoid;
			open (my $GEO, "<", "/var/lib/csf/Geo/GeoLite2-Country-Locations-en.csv");
			flock ($GEO, LOCK_SH);
			while (my $record = <$GEO>) {
				chomp $record;
				$record =~ s/\"//g;
				my ($geoname_id,undef,undef,undef,$country_iso_code,undef) = split (/\,/,$record);
				foreach my $cc (keys %cclist) {
					if (uc $cc eq uc $country_iso_code) {
						$geoid{$cc}{$geoname_id} = 1;
					}
				}
			}
			close ($GEO);
			open (my $IN, "<", "/var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv6.csv");
			flock ($IN, LOCK_SH);
			while (my $record = <$IN>) {
				chomp $record;
				$record =~ s/\"//g;
				my ($range,$geoname_id,undef) = split (/\,/,$record);
				foreach my $cc (keys %cclist) {
					if ($geoid{$cc}{$geoname_id}) {
						$dcidr{$cc}{$range} = 1;
					}
				}
			}
			close ($IN);
			open ($IN, "<", "/var/lib/csf/Geo/GeoLite2-ASN-Blocks-IPv6.csv");
			flock ($IN, LOCK_SH);
			while (my $record = <$IN>) {
				chomp $record;
				$record =~ s/\"//g;
				my ($range,$asn,undef) = split (/\,/,$record);
				foreach my $cc (keys %cclist) {
					if (uc($cc) =~ /AS(\d+)/) {
						if ($1 eq $asn) {
							$dcidr{$cc}{$range} = 1;
						}
					}
				}
			}
			close ($IN);
			foreach my $cc (keys %cclist) {
				logfile("CC: Extracting zone from $config{cc_src} Country/ASN IPv6 database for [".uc($cc)."]");
				if (keys %{$dcidr{$cc}} eq 0) {
					if (length($cc) == 2) {
						logfile("CC: No IPv6 entries found for [".uc($cc)."] in /var/lib/csf/Geo/GeoLite2-Country-Blocks-IPv6.csv");
					} else {
						logfile("CC: No IPv6 entries found for [".uc($cc)."] in /var/lib/csf/Geo/GeoLite2-ASN-Blocks-IPv6.csv");
					}
				} else {
					sysopen (my $CIDROUT, "/var/lib/csf/zone/$cc.zone6", O_WRONLY | O_CREAT);
					flock ($CIDROUT, LOCK_EX);
					seek ($CIDROUT, 0, 0);
					truncate ($CIDROUT, 0);
					foreach my $key (keys %{$dcidr{$cc}}) {print $CIDROUT "$key\n"}
					close ($CIDROUT);
				}
			}
		}
	} elsif ($config{CC_SRC} eq "2") {
		if ($getgeo) {
			logfile("CC: Processing $config{cc_src} Country/ASN IPv6 database");
			my %dcidr;
			open ($IN, "<", "/var/lib/csf/Geo/ip2asn-combined.tsv");
			flock ($IN, LOCK_SH);
			while (my $record = <$IN>) {
				chomp $record;
				$record =~ s/\"//g;
				my ($start,$end,$asn,undef) = split (/\t/,$record);
				if (checkip($start) == 4) {next}
				foreach my $cc (keys %cclist) {
					if (uc($cc) =~ /AS(\d+)/) {
						if ($1 eq $asn) {
							my $ipscidr = Net::CIDR::Lite->new;
							eval {local $SIG{__DIE__} = undef; $ipscidr->add_range("$start-$end")};
							my @cidr_list = $ipscidr->list;
							foreach my $list (@cidr_list) {
								$dcidr{$cc}{$list} = 1;
							}
						}
					}
				}
			}
			close ($IN);
			foreach my $cc (keys %cclist) {
				if (length($cc) > 2) {
					logfile("CC: Extracting IPv6 zone from $config{asn_src} ASN database for [".uc($cc)."]");
					if (keys %{$dcidr{$cc}} eq 0) {
						logfile("CC: No entries found for [".uc($cc)."] in /var/lib/csf/Geo/ip2asn-combined.tsv");
					} else {
						sysopen (my $CIDROUT, "/var/lib/csf/zone/$cc.zone6", O_WRONLY | O_CREAT);
						flock ($CIDROUT, LOCK_EX);
						seek ($CIDROUT, 0, 0);
						truncate ($CIDROUT, 0);
						foreach my $key (keys %{$dcidr{$cc}}) {print $CIDROUT "$key\n"}
						close ($CIDROUT);
					}
				}
				elsif (length($cc) == 2) {
					logfile("CC: Retrieving $config{ccl_src} Country Code IPv6 Zone [".uc($cc)."] from https://www.ipdeny.com");
					my ($status, $text) = $urlget->urlget("https://www.ipdeny.com/ipv6/ipaddresses/aggregated/${cc}-aggregated.zone","/var/lib/csf/zone/$cc.zone6");
					if ($status) {
						logfile("CC Error: Unable to retrieve $config{ccl_src} Country Code IPv6 Zone [".uc($cc)."] from https://www.ipdeny.com - $text");
					} else {
						logfile("CC: Country Code IPv6 Zone [".uc($cc)."] retrieved");
					}
					sleep 1;
				}
			}
		}
	}

	if ($config{LF_IPSET}) {
		my $cclist;
		my $cnt = 0;
		if ($redo_deny) {$cclist .= $config{CC_DENY}.","}
		if ($redo_allow) {$cclist .= $config{CC_ALLOW}.","}
		if ($redo_allow_filter) {$cclist .= $config{CC_ALLOW_FILTER}.","}
		if ($redo_allow_ports) {$cclist .= $config{CC_ALLOW_PORTS}.","}
		if ($redo_deny_ports) {$cclist .= $config{CC_DENY_PORTS}}
		if ($config{CC_ALLOW_FILTER} and $redo_allow_filter) {&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F CC_ALLOWF")}
		foreach my $cc (split(/\,/,$cclist)) {
			if ($cc eq "") {next}
			undef @ipset;
			$cc = lc $cc;
			if ($config{CC_ALLOW_FILTER} and $redo_allow_filter) {&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A CC_ALLOWF -m set --match-set cc_6_$cc src -j RETURN")}
			if (-e "/var/lib/csf/zone/$cc.zone6") {
				logfile("CC: Repopulating ipset cc_6_$cc with IP addresses from [".uc($cc)."]");
				open (my $IN, "<", "/var/lib/csf/zone/$cc.zone6");
				flock ($IN, LOCK_SH);
				while (my $line = <$IN>) {
					chomp $line;
					my ($ip,undef) = split (/\s/,$line,2);
					if ($config{CC_DROP_CIDR} > 0 and $config{CC_DROP_CIDR} < 33) {
						my ($drop_ip,$drop_cidr) = split(/\//,$ip);
						if ($drop_cidr eq "") {$drop_cidr = "32"}
						if ($drop_cidr > $config{CC_DROP_CIDR}) {next}
					}
					if (checkip(\$ip)) {
						push @ipset,"add new_6_$cc $ip";
						$cnt++;
					}
				}
				&ipsetrestore("new_6_$cc");
				&ipsetswap("new_6_$cc","cc_6_$cc");
			}
		}
		if ($config{CC_ALLOW_FILTER} and $redo_allow_filter and $cnt > 0) {
			&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A CC_ALLOWF -j $drop");
			if ($config{IPV6_SPI}) {
				my $statemodule = "-m state --state";
				if ($config{USE_FTPHELPER}) {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I CC_ALLOWF $ethdevin $statemodule RELATED -m helper --helper ftp -j $accept");

					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I CC_ALLOWF $ethdevin $statemodule ESTABLISHED -j $accept");
				} else {
					&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I CC_ALLOWF $ethdevin $statemodule ESTABLISHED,RELATED -j $accept");
				}
				&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT}  -I CC_ALLOWF $eth6devin -p icmpv6 -j $accept");
			}
		}
	} else {
		if ($config{CC_DENY} and $redo_deny) {
			if (&csflock) {&lockfail("CC_DENY")}
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NEWCC_DENY");
			} else {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F CC_DENY");
			}
			foreach my $cc (split(/\,/,$config{CC_DENY})) {
				$cc = lc $cc;
				if (-e "/var/lib/csf/zone/$cc.zone6") {
					if ($config{FASTSTART}) {$faststart = 1}
					logfile("CC: Repopulating CC_DENY with IP addresses from [".uc($cc)."]");
					open (my $IN, "<", "/var/lib/csf/zone/$cc.zone6");
					flock ($IN, LOCK_SH);
					while (my $line = <$IN>) {
						chomp $line;
						my ($ip,undef) = split (/\s/,$line,2);
						if (checkip(\$ip)) {
							if ($config{SAFECHAINUPDATE}) {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NEWCC_DENY -s $ip -j $drop");
							} else {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A CC_DENY -s $ip -j $drop");
							}
						}
					}
					close ($IN);
					if ($config{FASTSTART}) {&faststart("CC_DENY [".uc($cc)."]")}
					logfile("CC: Finished repopulating CC_DENY with IP addresses from [".uc($cc)."]");
				}
			}
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A LOCALINPUT $ethdevin -j NEWCC_DENY");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j CC_DENY");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F CC_DENY");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X CC_DENY");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NEWCC_DENY CC_DENY");
			}
		}

		if ($config{CC_ALLOW} and $redo_allow) {
			if (&csflock) {&lockfail("CC_ALLOW")}
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NEWCC_ALLOW");
			} else {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F CC_ALLOW");
			}
			foreach my $cc (split(/\,/,$config{CC_ALLOW})) {
				$cc = lc $cc;
				if (-e "/var/lib/csf/zone/$cc.zone6") {
					if ($config{FASTSTART}) {$faststart = 1}
					logfile("CC: Repopulating CC_ALLOW with IP addresses from [".uc($cc)."]");
					open (my $IN, "<", "/var/lib/csf/zone/$cc.zone6");
					flock ($IN, LOCK_SH);
					while (my $line = <$IN>) {
						chomp $line;
						my ($ip,undef) = split (/\s/,$line,2);
						if (checkip(\$ip)) {
							if ($config{SAFECHAINUPDATE}) {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NEWCC_ALLOW -s $ip -j $accept");
							} else {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A CC_ALLOW -s $ip -j $accept");
							}
						}
					}
					close ($IN);
					if ($config{FASTSTART}) {&faststart("CC_ALLOW [".uc($cc)."]")}
					logfile("CC: Finished repopulating CC_ALLOW with IP addresses from [".uc($cc)."]");
				}
			}
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I LOCALINPUT $ethdevin -j NEWCC_ALLOW");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j CC_ALLOW");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F CC_ALLOW");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X CC_ALLOW");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NEWCC_ALLOW CC_ALLOW");
			}
		}

		if ($config{CC_ALLOW_FILTER} and $redo_allow_filter) {
			my $cnt = 0;
			if (&csflock) {&lockfail("CC_ALLOW_FILTER")}
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NCC_ALLOWF");
			} else {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F CC_ALLOWF");
			}
			foreach my $cc (split(/\,/,$config{CC_ALLOW_FILTER})) {
				$cc = lc $cc;
				if (-e "/var/lib/csf/zone/$cc.zone6") {
					if ($config{FASTSTART}) {$faststart = 1}
					logfile("CC: Repopulating CC_ALLOWF with IP addresses from [".uc($cc)."]");
					open (my $IN, "<", "/var/lib/csf/zone/$cc.zone6");
					flock ($IN, LOCK_SH);
					while (my $line = <$IN>) {
						chomp $line;
						my ($ip,undef) = split (/\s/,$line,2);
						if (checkip(\$ip)) {
							$cnt++;
							if ($config{SAFECHAINUPDATE}) {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NCC_ALLOWF -s $ip -j RETURN");
							} else {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A CC_ALLOWF -s $ip -j RETURN");
							}
						}
					}
					close ($IN);
					if ($config{FASTSTART}) {&faststart("CC_ALLOW_FILTER [".uc($cc)."]")}
					logfile("CC: Finished repopulating CC_ALLOWF with IP addresses from [".uc($cc)."]");
				}
			}
			if ($config{SAFECHAINUPDATE}) {
				if ($cnt > 0) {&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NCC_ALLOWF -j $drop")}
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A LOCALINPUT $ethdevin -j NCC_ALLOWF");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j CC_ALLOWF");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F CC_ALLOWF");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X CC_ALLOWF");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NCC_ALLOWF CC_ALLOWF");
			} else {
				if ($cnt > 0) {
					&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A CC_ALLOWF -j $drop");
					if ($config{IPV6_SPI}) {
						my $statemodule = "-m state --state";
						if ($config{USE_FTPHELPER}) {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I CC_ALLOWF $ethdevin $statemodule RELATED -m helper --helper ftp -j $accept");

							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I CC_ALLOWF $ethdevin $statemodule ESTABLISHED -j $accept");
						} else {
							&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I CC_ALLOWF $ethdevin $statemodule ESTABLISHED,RELATED -j $accept");
						}
						&syscommand(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT}  -I CC_ALLOWF $eth6devin -p icmpv6 -j $accept");
					}
				}
			}
		}

		if ($config{CC_ALLOW_PORTS} and $redo_allow_ports) {
			my $cnt = 0;
			if (&csflock) {&lockfail("CC_ALLOW_PORTS")}
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NCC_ALLOWP");
			} else {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F CC_ALLOWP");
			}
			foreach my $cc (split(/\,/,$config{CC_ALLOW_PORTS})) {
				$cc = lc $cc;
				if (-e "/var/lib/csf/zone/$cc.zone6") {
					if ($config{FASTSTART}) {$faststart = 1}
					logfile("CC: Repopulating CC_ALLOWP with IP addresses from [".uc($cc)."]");
					open (my $IN, "<", "/var/lib/csf/zone/$cc.zone6");
					flock ($IN, LOCK_SH);
					while (my $line = <$IN>) {
						chomp $line;
						my ($ip,undef) = split (/\s/,$line,2);
						if (checkip(\$ip)) {
							$cnt++;
							if ($config{SAFECHAINUPDATE}) {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NCC_ALLOWP -s $ip -j CC_ALLOWPORTS");
							} else {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A CC_ALLOWP -s $ip -j CC_ALLOWPORTS");
							}
						}
					}
					close ($IN);
					if ($config{FASTSTART}) {&faststart("CC_ALLOW_PORTS [".uc($cc)."]")}
					logfile("CC: Finished repopulating CC_ALLOWP with IP addresses from [".uc($cc)."]");
				}
			}
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A LOCALINPUT $ethdevin -j NCC_ALLOWP");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j CC_ALLOWP");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F CC_ALLOWP");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X CC_ALLOWP");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NCC_ALLOWP CC_ALLOWP");
			}
		}

		if ($config{CC_DENY_PORTS} and $redo_deny_ports) {
			my $cnt = 0;
			if (&csflock) {&lockfail("CC_DENY_PORTS")}
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NCC_DENYP");
			} else {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F CC_DENYP");
			}
			foreach my $cc (split(/\,/,$config{CC_DENY_PORTS})) {
				$cc = lc $cc;
				if (-e "/var/lib/csf/zone/$cc.zone6") {
					if ($config{FASTSTART}) {$faststart = 1}
					logfile("CC: Repopulating CC_DENYP with IP addresses from [".uc($cc)."]");
					open (my $IN, "<", "/var/lib/csf/zone/$cc.zone6");
					flock ($IN, LOCK_SH);
					while (my $line = <$IN>) {
						chomp $line;
						my ($ip,undef) = split (/\s/,$line,2);
						if (checkip(\$ip)) {
							$cnt++;
							if ($config{SAFECHAINUPDATE}) {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NCC_DENYP -s $ip -j CC_DENYPORTS");
							} else {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A CC_DENYP -s $ip -j CC_DENYPORTS");
							}
						}
					}
					close ($IN);
					if ($config{FASTSTART}) {&faststart("CC_DENY_PORTS [".uc($cc)."]")}
					logfile("CC: Finished repopulating CC_DENYP with IP addresses from [".uc($cc)."]");
				}
			}
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A LOCALINPUT $ethdevin -j NCC_DENYP");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j CC_DENYP");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F CC_DENYP");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X CC_DENYP");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NCC_DENYP CC_DENYP");
			}
		}
	}
	return;
}
# end countrycode6
###############################################################################
# start global
sub global {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","global",$timer)}
		$0 = "lfd - retrieving global lists";

		my $lockstr = "LF_GLOBAL";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		$0 = "lfd - retrieving global lists (waiting for list lock)";
		&listlock("lock");
		$0 = "lfd - retrieving global lists";

		if ($config{GLOBAL_ALLOW}) {
			my ($status, $text) = $urlget->urlget($config{GLOBAL_ALLOW});
			if ($status) {
				logfile("Unable to retrieve global allow list - $text");
			} else {
				if (&csflock) {&lockfail("GLOBAL_ALLOW")}
				logfile("Global Allow - retrieved and allowing IP address ranges");

				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NEWGALLOWIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NEWGALLOWOUT");
					if ($config{LF_IPSET}) {
						&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NEWGALLOWIN -m set --match-set chain_GALLOW src -j $accept");
						&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NEWGALLOWOUT -m set --match-set chain_GALLOW dst -j $accept");
						&ipsetcreate("chain_NEWGALLOW");
					}
					if ($config{IPV6}) {
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NEWGALLOWIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NEWGALLOWOUT");
						if ($config{LF_IPSET}) {
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NEWGALLOWIN -m set --match-set chain_6_GALLOW src -j $accept");
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NEWGALLOWOUT -m set --match-set chain_6_GALLOW dst -j $accept");
							&ipsetcreate("chain_6_NEWGALLOW");
						}
					}
				} else {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F GALLOWIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F GALLOWOUT");
					if ($config{LF_IPSET}) {
						&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A GALLOWIN -m set --match-set chain_GALLOW src -j $accept");
						&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A GALLOWOUT -m set --match-set chain_GALLOW dst -j $accept");
						&ipsetflush("chain_GALLOW");
					}
					if ($config{IPV6}) {
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F GALLOWIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F GALLOWOUT");
						if ($config{LF_IPSET}) {
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A GALLOWIN -m set --match-set chain_6_GALLOW src -j $accept");
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A GALLOWOUT -m set --match-set chain_6_GALLOW dst -j $accept");
							&ipsetflush("chain_6_GALLOW");
						}
					}
				}
				sysopen (my $GALLOW, "/var/lib/csf/csf.gallow", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot open out file: $!");
				flock ($GALLOW, LOCK_EX);
				seek ($GALLOW, 0, 0);
				truncate ($GALLOW, 0);
				if ($config{FASTSTART}) {$faststart = 1}
				foreach my $line (split (/\n/,$text)) {
					if ($line =~ /^\#/) {next}
					my ($ip,$comment) = split (/\s/,$line,2);
					print $GALLOW "$ip\n";
					if ($config{SAFECHAINUPDATE}) {
						&linefilter($ip, "allow","NEWGALLOW");
					} else {
						&linefilter($ip, "allow","GALLOW");
					}
				}
				if ($config{FASTSTART}) {&faststart("GLOBAL_ALLOW")}
				close ($GALLOW);
				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I LOCALINPUT $ethdevin -j NEWGALLOWIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I LOCALOUTPUT $ethdevout -j NEWGALLOWOUT");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j GALLOWIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALOUTPUT $ethdevout -j GALLOWOUT");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F GALLOWIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F GALLOWOUT");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X GALLOWIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X GALLOWOUT");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NEWGALLOWIN GALLOWIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NEWGALLOWOUT GALLOWOUT");
					if ($config{IPV6}) {
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I LOCALINPUT $eth6devin -j NEWGALLOWIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I LOCALOUTPUT $eth6devout -j NEWGALLOWOUT");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALINPUT $eth6devin -j GALLOWIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALOUTPUT $eth6devout -j GALLOWOUT");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F GALLOWIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F GALLOWOUT");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X GALLOWIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X GALLOWOUT");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NEWGALLOWIN GALLOWIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NEWGALLOWOUT GALLOWOUT");
					}
					if ($config{LF_IPSET}) {
						&ipsetswap("chain_NEWGALLOW","chain_GALLOW");
						if ($config{IPV6}) {
							&ipsetswap("chain_6_NEWGALLOW","chain_6_GALLOW");
						}
					}
				}
			}
		}

		if ($config{GLOBAL_DENY}) {
			my ($status, $text) = $urlget->urlget($config{GLOBAL_DENY});
			if ($status) {
				logfile("Unable to retrieve global deny list - $text");
			} else {
				if (&csflock) {&lockfail("GLOBAL_DENY")}
				logfile("Global Deny - retrieved and blocking IP address ranges");
				my $drop = $config{DROP};
				if ($config{DROP_IP_LOGGING}) {$drop = "BLOCKDROP"}

				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NEWGDENYIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NEWGDENYOUT");
					if ($config{LF_IPSET}) {
						my $pktin = $config{DROP};
						my $pktout = $config{DROP_OUT};
						if ($config{DROP_IP_LOGGING}) {$pktin = "LOGDROPIN"}
						if ($config{DROP_OUT_LOGGING}) {$pktout = "LOGDROPOUT"}
						&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NEWGDENYIN -m set --match-set chain_GDENY src -j $pktin");
						unless ($config{LF_BLOCKINONLY}) {&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NEWGDENYOUT -m set --match-set chain_GDENY dst -j $pktout")}
						&ipsetcreate("chain_NEWGDENY");
					}
					if ($config{IPV6}) {
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NEWGDENYIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NEWGDENYOUT");
						if ($config{LF_IPSET}) {
							my $pktin = $config{DROP};
							my $pktout = $config{DROP_OUT};
							if ($config{DROP_IP_LOGGING}) {$pktin = "LOGDROPIN"}
							if ($config{DROP_OUT_LOGGING}) {$pktout = "LOGDROPOUT"}
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NEWGDENYIN -m set --match-set chain_6_GDENY src -j $pktin");
							unless ($config{LF_BLOCKINONLY}) {&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NEWGDENYOUT -m set --match-set chain_6_GDENY dst -j $pktout")}
							&ipsetcreate("chain_6_NEWGDENY");
						}
					}
				} else {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F GDENYIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F GDENYOUT");
					if ($config{LF_IPSET}) {
						my $pktin = $config{DROP};
						my $pktout = $config{DROP_OUT};
						if ($config{DROP_IP_LOGGING}) {$pktin = "LOGDROPIN"}
						if ($config{DROP_OUT_LOGGING}) {$pktout = "LOGDROPOUT"}
						&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A GDENYIN -m set --match-set chain_GDENY src -j $pktin");
						unless ($config{LF_BLOCKINONLY}) {&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A GDENYOUT -m set --match-set chain_GDENY dst -j $pktout")}
						&ipsetflush("chain_GDENY");
					}
					if ($config{IPV6}) {
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F GDENYIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F GDENYOUT");
						if ($config{LF_IPSET}) {
							my $pktin = $config{DROP};
							my $pktout = $config{DROP_OUT};
							if ($config{DROP_IP_LOGGING}) {$pktin = "LOGDROPIN"}
							if ($config{DROP_OUT_LOGGING}) {$pktout = "LOGDROPOUT"}
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A GDENYIN -m set --match-set chain_6_GDENY src -j $pktin");
							unless ($config{LF_BLOCKINONLY}) {&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A GDENYOUT -m set --match-set chain_6_GDENY dst -j $pktout")}
							&ipsetflush("chain_6_GDENY");
						}
					}
				}
				sysopen (my $GDENY, "/var/lib/csf/csf.gdeny", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot open out file: $!");
				flock ($GDENY, LOCK_EX);
				seek ($GDENY, 0, 0);
				truncate ($GDENY, 0);
				if ($config{FASTSTART}) {$faststart = 1}
				foreach my $line (split (/\n/,$text)) {
					if ($line =~ /^\#/) {next}
					my ($ip,$comment) = split (/\s/,$line,2);
					print $GDENY "$ip\n";
					if ($config{SAFECHAINUPDATE}) {
						&linefilter($ip, "deny","NEWGDENY");
					} else {
						&linefilter($ip, "deny","GDENY");
					}
				}
				if ($config{FASTSTART}) {&faststart("GLOBAL_DENY")}
				close ($GDENY);
				if ($config{SAFECHAINUPDATE}) {
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A LOCALINPUT $ethdevin -j NEWGDENYIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A LOCALOUTPUT $ethdevout -j NEWGDENYOUT");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j GDENYIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALOUTPUT $ethdevout -j GDENYOUT");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F GDENYIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F GDENYOUT");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X GDENYIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X GDENYOUT");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NEWGDENYIN GDENYIN");
					&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NEWGDENYOUT GDENYOUT");
					if ($config{IPV6}) {
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A LOCALINPUT $eth6devin -j NEWGDENYIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A LOCALOUTPUT $eth6devout -j NEWGDENYOUT");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALINPUT $eth6devin -j GDENYIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALOUTPUT $eth6devout -j GDENYOUT");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F GDENYIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F GDENYOUT");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X GDENYIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X GDENYOUT");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NEWGDENYIN GDENYIN");
						&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NEWGDENYOUT GDENYOUT");
					}
					if ($config{LF_IPSET}) {
						&ipsetswap("chain_NEWGDENY","chain_GDENY");
						if ($config{IPV6}) {
							&ipsetswap("chain_6_NEWGDENY","chain_6_GDENY");
						}
					}
				}
			}
		}

		if ($config{GLOBAL_IGNORE}) {
			my ($status, $text) = $urlget->urlget($config{GLOBAL_IGNORE});
			if ($status) {
				logfile("Unable to retrieve global ignore list - $text");
			} else {
				logfile("Global Ignore - retrieved and ignoring");

				sysopen (my $GIGNORE, "/var/lib/csf/csf.gignore", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot open out file: $!");
				flock ($GIGNORE, LOCK_EX);
				seek ($GIGNORE, 0, 0);
				truncate ($GIGNORE, 0);
				foreach my $line (split (/\n/,$text)) {
					if ($line =~ /^\#/) {next}
					my ($ip,$comment) = split (/\s/,$line,2);
					print $GIGNORE "$ip\n";
				}
				close ($GIGNORE);
			}
		}

		if ($config{GLOBAL_DYNDNS}) {
			my ($status, $text) = $urlget->urlget($config{GLOBAL_DYNDNS});
			if ($status) {
				logfile("Unable to retrieve global dyndns list - $text");
			} else {
				logfile("Global DynDNS - retrieved and allowing IP addresses");

				sysopen (my $GDYNDNS, "/var/lib/csf/csf.gdyndns", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot open out file: $!");
				flock ($GDYNDNS, LOCK_EX);
				seek ($GDYNDNS, 0, 0);
				truncate ($GDYNDNS, 0);
				foreach my $line (split (/\n/,$text)) {
					if ($line =~ /^\#/) {next}
					my ($ip,$comment) = split (/\s/,$line,2);
					print $GDYNDNS "$ip\n";
				}
				close ($GDYNDNS);
				&globaldyndns;
			}
		}

		&listlock("unlock");
		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","global",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end global
###############################################################################
# start dyndns
sub dyndns {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","dyndns",$timer)}
		$0 = "lfd - resolving dyndns IP addresses";

		my $lockstr = "DYNDNS";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		$0 = "lfd - resolving dyndns IP addresses (waiting for list lock)";
		&listlock("lock");
		$0 = "lfd - resolving dyndns IP addresses";

		my @dyndns;
		my @entries = slurp("/etc/csf/csf.dyndns");
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
			push @dyndns, $line;
		}

		if (&csflock) {&lockfail("DYNDNS")}
		if ($config{DEBUG} >= 1) {logfile("DynDNS - update IP addresses")}
		if ($config{SAFECHAINUPDATE}) {
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NEWALLOWDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NEWALLOWDYNOUT");
			if ($config{LF_IPSET}) {
				&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NEWALLOWDYNIN -m set --match-set chain_ALLOWDYN src -j $accept");
				&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NEWALLOWDYNOUT -m set --match-set chain_ALLOWDYN dst -j $accept");
			}
		} else {
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F ALLOWDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F ALLOWDYNOUT");
			if ($config{LF_IPSET}) {
				&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A ALLOWDYNIN -m set --match-set chain_ALLOWDYN src -j $accept");
				&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A ALLOWDYNOUT -m set --match-set chain_ALLOWDYN dst -j $accept");
			}
		}
		if ($config{IPV6}) {
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NEWALLOWDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NEWALLOWDYNOUT");
			} else {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F ALLOWDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F ALLOWDYNOUT");
			}
		}
		sysopen (my $TEMPDYN, "/var/lib/csf/csf.tempdyn", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot open out file: $!");
		flock ($TEMPDYN, LOCK_EX);
		seek ($TEMPDYN, 0, 0);
		truncate ($TEMPDYN, 0);
		foreach my $line (@dyndns) {
			my $adport;
			my ($fqdn,undef) = split(/\s/,$line,2);
			if ($fqdn =~ /^(.*(s|d)=)(.*)$/) {$adport = $1; $fqdn = $3}
			my @results = getips($fqdn);
			if (@results) {
				foreach my $ip (@results) {
					if ($adport) {$ip = $adport.$ip}
					if ($config{SAFECHAINUPDATE}) {
						&linefilter($ip, "allow","NEWALLOWDYN");
					} else {
						&linefilter($ip, "allow","ALLOWDYN");
					}
					print $TEMPDYN "$ip\n";
				}
			} else {
				logfile ("DynDNS: Lookup for [$fqdn] failed");
			}
		}
		close ($TEMPDYN);
		if ($config{SAFECHAINUPDATE}) {
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I LOCALINPUT $ethdevin -j NEWALLOWDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I LOCALOUTPUT $ethdevout -j NEWALLOWDYNOUT");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j ALLOWDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALOUTPUT $ethdevout -j ALLOWDYNOUT");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F ALLOWDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F ALLOWDYNOUT");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X ALLOWDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X ALLOWDYNOUT");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NEWALLOWDYNIN ALLOWDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NEWALLOWDYNOUT ALLOWDYNOUT");
		}
		if ($config{IPV6}) {
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I LOCALINPUT $ethdevin -j NEWALLOWDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I LOCALOUTPUT $ethdevout -j NEWALLOWDYNOUT");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j ALLOWDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALOUTPUT $ethdevout -j ALLOWDYNOUT");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F ALLOWDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F ALLOWDYNOUT");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X ALLOWDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X ALLOWDYNOUT");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NEWALLOWDYNIN ALLOWDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NEWALLOWDYNOUT ALLOWDYNOUT");
			}
		}

		&listlock("unlock");
		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","dyndns",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end dyndns
###############################################################################
# start globaldyndns
sub globaldyndns {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","globaldyndns",$timer)}
		$0 = "lfd - resolving global dyndns IP addresses";

		my $lockstr = "GLOBAL_DYNDNS_INTERVAL";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		$0 = "lfd - resolving global dyndns IP addresses (waiting for list lock)";
		&listlock("lock");
		$0 = "lfd - resolving global dyndns IP addresses";

		open (my $IN, "<", "/var/lib/csf/csf.gdyndns");
		flock ($IN, LOCK_SH);
		my @dyndns = <$IN>;
		close ($IN);
		chomp @dyndns;

		if (&csflock) {&lockfail("GLOBAL_DYNDNS_INTERVAL")}
		logfile("Global DynDNS - update IP addresses");
		if ($config{SAFECHAINUPDATE}) {
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NEWGDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -N NEWGDYNOUT");
			if ($config{LF_IPSET}) {
				&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NEWGDYNIN -m set --match-set chain_GDYN src -j $accept");
				&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A NEWGDYNOUT -m set --match-set chain_GDYN dst -j $accept");
			}
		} else {
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F GDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F GDYNOUT");
			if ($config{LF_IPSET}) {
				&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A GDYNIN -m set --match-set chain_GDYN src -j $accept");
				&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A GDYNOUT -m set --match-set chain_GDYN dst -j $accept");
			}
		}
		if ($config{IPV6}) {
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NEWGDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -N NEWGDYNOUT");
				if ($config{LF_IPSET}) {
					&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NEWGDYNIN -m set --match-set chain_6_GDYN src -j $accept");
					&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A NEWGDYNOUT -m set --match-set chain_6_GDYN dst -j $accept");
				}
			} else {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F GDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F GDYNOUT");
				if ($config{LF_IPSET}) {
					&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A GDYNIN -m set --match-set chain_6_GDYN src -j $accept");
					&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A GDYNOUT -m set --match-set chain_6_GDYN dst -j $accept");
				}
			}
		}
		sysopen (my $TEMPDYN, "/var/lib/csf/csf.tempgdyn", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot open out file: $!");
		flock ($TEMPDYN, LOCK_EX);
		seek ($TEMPDYN, 0, 0);
		truncate ($TEMPDYN, 0);
		foreach my $line (@dyndns) {
			if ($line =~ /^\#/) {next}
			if ($line eq "") {next}
			if ($line =~ /^\n/) {next}
			if ($line =~ /^\r/) {next}
			if ($line =~ /^\s/) {next}
			my $ip;
			my $adport;
			my ($fqdn,undef) = split(/\s/,$line,2);
			if ($fqdn =~ /(.*:(s|d)=)(.*)$/) {$adport = $1; $fqdn = $3}
			my @results = getips($fqdn);
			if (@results) {
				foreach my $ip (@results) {
					if ($adport) {$ip = $adport.$ip}
					if ($config{SAFECHAINUPDATE}) {
						&linefilter($ip, "allow","NEWGDYN");
					} else {
						&linefilter($ip, "allow","GDYN");
					}
					print $TEMPDYN "$ip\n";
				}
			} else {
				logfile ("Global DynDNS: Lookup for [$fqdn] failed");
			}
		}
		close ($TEMPDYN);
		if ($config{SAFECHAINUPDATE}) {
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I LOCALINPUT $ethdevin -j NEWGDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -I LOCALOUTPUT $ethdevout -j NEWGDYNOUT");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j GDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D LOCALOUTPUT $ethdevout -j GDYNOUT");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F GDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -F GDYNOUT");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X GDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -X GDYNOUT");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NEWGDYNIN GDYNIN");
			&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -E NEWGDYNOUT GDYNOUT");
		}
		if ($config{IPV6}) {
			if ($config{SAFECHAINUPDATE}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I LOCALINPUT $ethdevin -j NEWGDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -I LOCALOUTPUT $ethdevout -j NEWGDYNOUT");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALINPUT $ethdevin -j GDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D LOCALOUTPUT $ethdevout -j GDYNOUT");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F GDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -F GDYNOUT");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X GDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -X GDYNOUT");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NEWGDYNIN GDYNIN");
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -E NEWGDYNOUT GDYNOUT");
			}
		}

		&listlock("unlock");
		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","globaldyndns",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end globaldyndns
###############################################################################
# start listlock
sub listlock {
	my $state = shift;
	if ($state eq "lock") {
		sysopen ($LISTLOCK, "/var/lib/csf/lock/list.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/list.lock");
		flock ($LISTLOCK, LOCK_EX) or &childcleanup("*Lock Error* [listlock] unable to lock");
		print $LISTLOCK time;
	} else {
		close ($LISTLOCK);
	}
	return;
}
# end listlock
###############################################################################
# start dirwatch
sub dirwatch {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","dirwatch",$timer)}
		$0 = "lfd - checking directories";

		my $lockstr = "LF_DIRWATCH";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		my $alarm = int($config{LF_DIRWATCH}/10) + 10;
		my $start = time;
		my $tfail = 0;
		undef %nofiles;
		if (! -z "/var/lib/csf/csf.tempfiles") {
			open (my $IN, "<", "/var/lib/csf/csf.tempfiles");
			flock ($IN, LOCK_SH);
			my @data = <$IN>;
			close ($IN);
			chomp @data;

			foreach my $line (@data) {
				my ($itemttl,$item) = split(/:/,$line);
				if (time - $itemttl < $config{LF_FLUSH}) {
					$nofiles{$item} = 1;
				}
			}
		}

		undef @suspicious;
		my @dirs = ('/tmp','/dev/shm','/usr/local/apache/proxy','/etc/cron.d','/etc/cron.daily','/etc/cron.hourly','/etc/cron.weekly');
		my $tmpino = (stat("/tmp"))[1];
		my $ino = (lstat("/var/tmp"))[1];
		if ($ino ne $tmpino) {push @dirs, '/var/tmp'}
		$ino = (lstat("/usr/tmp"))[1];
		if ($ino ne $tmpino) {push @dirs, '/usr/tmp'}
		eval {
			local $SIG{__DIE__} = undef;
			local $SIG{'ALRM'} = sub {die};
			alarm($alarm);
			find(\&dirfiles, @dirs);
			alarm(0);
		};
		alarm(0);
		if ($@) {
			logfile("Directory Watching terminated after $alarm seconds");
			$tfail = 1;
		} else {
			if (@suspicious) {
				$0 = "lfd - reporting directory watch results";

				my @alert = slurp("/usr/local/csf/tpl/filealert.txt");
				my $matches = 0;
				foreach my $file (@suspicious) {
					if ($nofiles{$file}) {next}
					unless (-e $file) {next}
					$nofiles{$file} = 1;

					my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
					if (-l $file) {($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = lstat($file)}

					if ($file !~/\/core\./) {
						if ($uid eq "0") {next}
					}

					my $tuid = getpwuid($uid);
					my $tgid = getgrgid($gid);
					if ($file !~ /\/core\./) {
						if (($uid eq "postgres") and ($gid eq "postgres")) {next}
						if ($skipuser{$uid}) {next}
					}

					$matches++;
					if ($matches > 10) {
						logfile("Too many hits for *LF_DIRWATCH* - Directory Watching disabled");
						sysopen (my $DWDISABLE, "/var/lib/csf/csf.dwdisable", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot append out file: $!");
						flock ($DWDISABLE, LOCK_EX);
						print $DWDISABLE "disabled\n";
						close ($DWDISABLE);

						my @newalert = @alert;
						my @message;
						foreach my $line (@newalert) {
							$line =~ s/\[file\]//ig;
							$line =~ s/\[reason\]//ig;
							$line =~ s/\[owner\]//ig;
							$line =~ s/\[action\]/Too many hits for \*LF_DIRWATCH\* - Directory Watching disabled/ig;
							push @message, $line;
						}
						ConfigServer::Sendmail::relay("", "", @message);
						
						exit;
					}

					my $owner = "$tuid:$tgid ($uid:$gid)";
					my $line = "*Suspicious File* $file [$owner] - $sfile{$file}{reason}";
					my $action = "No action taken";

					if ($config{LF_DIRWATCH_DISABLE}) {
						if (-l $file) {
							unlink ($file);
							$action = "Symlink removed";
							$line .= " - symlink removed";
							delete $nofiles{$file};
						}
						elsif (-f $file) {
							system($config{TAR},"-rf","/var/lib/csf/suspicious.tar",$file);
							unlink ($file);
							$line .= " - removed";
							$action = "Moved into /var/lib/csf/suspicious.tar";
							delete $nofiles{$file};
						}
					}
					logfile($line);
					$0 = "lfd - (child) suspicious file alert for $file";

					my @newalert = @alert;
					my @message;
					foreach my $line (@newalert) {
						$line =~ s/\[file\]/$file/ig;
						$line =~ s/\[reason\]/$sfile{$file}{reason}/ig;
						$line =~ s/\[owner\]/$owner/ig;
						$line =~ s/\[action\]/$action/ig;
						push @message, $line;
					}
					ConfigServer::Sendmail::relay("", "", @message);

					if (! $config{LF_DIRWATCH_DISABLE}) {
						sysopen (my $TEMPFILES, "/var/lib/csf/csf.tempfiles", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot append out file: $!");
						flock ($TEMPFILES, LOCK_EX);
						print $TEMPFILES time.":$file\n";
						close ($TEMPFILES);
					}
				}
			}
		}

		if ($tfail) {
			$config{LF_DIRWATCH} = $config{LF_DIRWATCH} * 3;
			sysopen (my $TEMPCONF, "/var/lib/csf/csf.tempconf", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot append out file: $!");
			flock ($TEMPCONF, LOCK_EX);
			print $TEMPCONF "LF_DIRWATCH = \"$config{LF_DIRWATCH}\"\n";
			close ($TEMPCONF);
			logfile("LF_DIRWATCH taking $alarm seconds, temporarily throttled to run every $config{LF_DIRWATCH} seconds");
		}

		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","dirwatch",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end dirwatch
###############################################################################
# start dirfiles
sub dirfiles {
	if ($skipfile{$File::Find::name}) {return}
	if ($nofiles{$File::Find::name}) {return}
	if ((-d $File::Find::name) and ($_ =~ /^(\.|\.\.)$/)) {return}

	my $skip = 0;
	foreach my $match (@matchfile) {
		if ($File::Find::name =~ /$match/) {
			$skip = 1;
			last;
		}
	}
	if ($skip) {return}

	if (-l $File::Find::name) {
		push @suspicious, $File::Find::name;
		$sfile{$File::Find::name}{reason} = "Suspicious symlink (->".readlink($File::Find::name).")";
		return;
	}
	elsif ((-d $File::Find::name) and ($_ =~ /^(\.|\s)/)) {
		push @suspicious, $File::Find::name;
		$sfile{$File::Find::name}{reason} = "Suspicious directory";
		return;
	}
	elsif (-f $File::Find::name) {
		if ($File::Find::name =~ /^\/etc\/cron/) {
			if ($_ =~ /^core\./) {
				push @suspicious, $File::Find::name;
				$sfile{$File::Find::name}{reason} = "Core dump found - possible root exploit attack";
				return;
			} else {return}
		}
		if ($File::Find::name =~ /[\;\|\`\\]/) {
			push @suspicious, $File::Find::name;
			$sfile{$File::Find::name}{reason} = "Suspicious file name";
			return;
		}
		if ($File::Find::name =~ /^\-/) {
			push @suspicious, $File::Find::name;
			$sfile{$File::Find::name}{reason} = "Suspicious file name";
			return;
		}
		if ($_ =~ /\.(pl|cgi|ph.*|py|sh|bash)$/) {
			push @suspicious, $File::Find::name;
			$sfile{$File::Find::name}{reason} = "Script, file extension";
			return;
		}
		if ($_ =~ /^(udp\.pl|r0nin|dc\.pl|bind|bindz|inetd|z|httpd|sshd|ssh|cron|crond|su)$/) {
			push @suspicious, $File::Find::name;
			$sfile{$File::Find::name}{reason} = "Known exploit";
			return;
		}

		open (my $FILETYPE, "<", $File::Find::name);
		flock ($FILETYPE, LOCK_SH);
		read ($FILETYPE, my $filedata, 1024);
		close ($FILETYPE);
		if ($filedata =~ m[^\177ELF]) {
			push @suspicious, $File::Find::name;
			$sfile{$File::Find::name}{reason} = "Linux Binary";
			return;
		}
		if ($filedata =~ m[^\#\!]) {
			push @suspicious, $File::Find::name;
			$sfile{$File::Find::name}{reason} = "Script, starts with \#\!";
			return;
		}
	}
	return;
}
# end dirfiles
###############################################################################
# start dirwatchfile
sub dirwatchfile {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","dirwatchfile",$timer)}

		my $lockstr = "LF_DIRWATCH_FILE";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		$0 = "lfd - checking files and directories";

		undef %nofiles;
		if (-e "/var/lib/csf/csf.tempwatch") {
			open (my $IN, "<", "/var/lib/csf/csf.tempwatch");
			flock ($IN, LOCK_SH);
			my @data = <$IN>;
			close ($IN);
			chomp @data;

			foreach my $line (@data) {
				my ($file,$md5sum) = split(/:/,$line);
				if ($dirwatchfile{$file}) {$dirwatchfile{$file} = $md5sum}
			}
		}

		my @alert = slurp("/usr/local/csf/tpl/watchalert.txt");
		foreach my $file (keys %dirwatchfile) {
			unless (-e $file) {
				logfile("Directory *File Watching* [$file] does not exist");
				next;
			}
			my @data;
			eval {
				local $SIG{__DIE__} = undef;
				local $SIG{'ALRM'} = sub {die};
				alarm(10);
				@data = &syscommand(__LINE__,$config{LS},"--full-time","-lARt",$file);
				alarm(0);
			};
			alarm(0);
			if ($@) {
				logfile("Directory File Watching terminated after 10 seconds for $file: ".$@);
				exit;
			}
			chomp @data;
			my $md5current = Digest::MD5->new;
			my $output;
			foreach my $line (@data) {
				$md5current->add($line);
				$output .= $line."\n";
			}
			my $md5sum = $md5current->b64digest;

			if ($dirwatchfile{$file} ne "1") {
				if ($md5sum ne $dirwatchfile{$file}) {
					$0 = "lfd - (child) suspicious file alert for $file";
					logfile("Directory *File Watching* has detected a change in $file");
					$dirwatchfile{$file} = $md5sum;

					my @newalert = @alert;
					my @message;
					foreach my $line (@newalert) {
						$line =~ s/\[file\]/$file/ig;
						$line =~ s/\[output\]/$output/ig;
						push @message, $line;
					}
					ConfigServer::Sendmail::relay("", "", @message);
				}
			} else {
				$dirwatchfile{$file} = $md5sum;
			}
		}
		
		sysopen (my $TEMPWATCH, "/var/lib/csf/csf.tempwatch", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot write out file: $!");
		flock ($TEMPWATCH, LOCK_EX);
		seek ($TEMPWATCH, 0, 0);
		truncate ($TEMPWATCH, 0);
		foreach my $file (keys %dirwatchfile) {
			print $TEMPWATCH "$file:$dirwatchfile{$file}\n";
		}
		close ($TEMPWATCH);

		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","dirwatchfile",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end dirwatchfile
###############################################################################
# start integrity
sub integrity {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","integrity",$timer)}

		my $lockstr = "LF_INTEGRITY";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		$0 = "lfd - checking system integrity";

		my $integrity = '/usr/bin/* /usr/sbin/* /bin/* /sbin/* /usr/local/bin/* /usr/local/sbin/* /etc/init.d/* /etc/xinetd.d/* /etc/rc.local';
		my $alarm = int($config{LF_INTEGRITY}/10) + 10;
		my $start = time;
		my $tfail = 0;

		my $action;
		if (-z "/var/lib/csf/csf.tempint") {$action = "start"}
		unless (-e "/var/lib/csf/csf.tempint") {$action = "start"}
		if ($action eq "start") {
			eval {
				local $SIG{__DIE__} = undef;
				local $SIG{'ALRM'} = sub {die};
				alarm($alarm);
				&syscommand(__LINE__,"$config{MD5SUM} $integrity > /var/lib/csf/csf.tempint");
				alarm(0);
			};
			alarm(0);
			if ($@) {
				logfile("System Integrity start terminated after $alarm seconds");
				$tfail = 1;
			}
		} else {
			my @data;
			eval {
				local $SIG{__DIE__} = undef;
				local $SIG{'ALRM'} = sub {die};
				alarm($alarm);
				@data = &syscommand(__LINE__,"$config{MD5SUM} --check /var/lib/csf/csf.tempint");
				alarm(0);
			};
			alarm(0);
			if ($@) {
				logfile("System Integrity check terminated after $alarm seconds");
				$tfail = 1;
			} else {
				chomp @data;
				my $report;
				my $files;
				foreach my $line (@data) {
					my ($file,$text) = split(/:/,$line);
					if ($text =~ /FAILED/) {
						$report .= "$line\n";
						$files .= " $file";
					}
				}

				if ($report) {
					logfile("*System Integrity* has detected modified file(s):$files");
					$0 = "lfd - (child) system integrity alert";

					my @alert = slurp("/usr/local/csf/tpl/integrityalert.txt");
					my @message;
					foreach my $line (@alert) {
						$line =~ s/\r//;
						$line =~ s/\[text\]/$report/ig;
						push @message, $line;
					}
					ConfigServer::Sendmail::relay("", "", @message);
					unlink "/var/lib/csf/csf.tempint";

					eval {
						local $SIG{__DIE__} = undef;
						local $SIG{'ALRM'} = sub {die};
						alarm($alarm);
						&syscommand(__LINE__,"$config{MD5SUM} $integrity > /var/lib/csf/csf.tempint");
						alarm(0);
					};
					alarm(0);
					if ($@) {
						logfile("System Integrity start terminated after $alarm seconds");
						$tfail = 1;
					}
				}
			}
		}

		if ($tfail) {
			$config{LF_INTEGRITY} = $config{LF_INTEGRITY} * 1.5;
			sysopen (my $TEMPCONF, "/var/lib/csf/csf.tempconf", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot append out file: $!");
			flock ($TEMPCONF, LOCK_EX);
			print $TEMPCONF "LF_INTEGRITY = \"$config{LF_INTEGRITY}\"\n";
			close ($TEMPCONF);
			logfile("LF_INTEGRITY taking $alarm seconds, temporarily throttled to run every $config{LF_INTEGRITY} seconds");
		}

		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","integrity",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end integrity
###############################################################################
# start logscanner
sub logscanner {
	my $hour = shift;
	if (length $hour == 1) {$hour = "0$hour:00"} else {$hour = "$hour:00"}
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","logscanner",$timer)}

		my $lockstr = "LOGSCANNER";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		$0 = "lfd - log scanner";

		unless (-z "/var/lib/csf/csf.logtemp" and $config{LOGSCANNER_EMPTY} == 0) {
			my $text;
			my %loglines;
			my $total = 0;
			my $max = 0;

			sysopen (my $LOGTEMP,"/var/lib/csf/csf.logtemp", O_RDWR | O_CREAT);
			flock ($LOGTEMP, LOCK_EX);
			my @data = <$LOGTEMP>;
			seek ($LOGTEMP, 0, 0);
			truncate ($LOGTEMP, 0);
			if (-e "/var/lib/csf/csf.logmax") {
				unlink "/var/lib/csf/csf.logmax";
				$max = 1;
			}
			close ($LOGTEMP);
			chomp @data;

			if ($config{LOGSCANNER_STYLE} == "1") {
				foreach my $line (@data) {
					my ($logfile,$logline) = split(/\|/,$line);
					$loglines{$logfile} .= "$logline\n";
					$total++;
				}
				foreach my $logfile (keys %loglines) {
					$text .= "$logfile:\n$loglines{$logfile}\n";
				}
			} else {
				foreach my $line (@data) {
					my ($logfile,$logline) = split(/\|/,$line);
					$text .= "$logline\n";
					$total++;
				}
			}

			if ($max) {$text .= "\n...Report truncated as it exceeded $config{LOGSCANNER_LINES} of log lines...\n"}

			if ($text eq "") {$text = "...No log lines to report..."}

			my @alert = slurp("/usr/local/csf/tpl/logalert.txt");
			my @message;
			foreach my $line (@alert) {
				$line =~ s/\r//;
				$line =~ s/\[text\]/$text/ig;
				$line =~ s/\[lines\]/$total/ig;
				$line =~ s/\[hour\]/$hour/ig;
				push @message, $line;
			}
			ConfigServer::Sendmail::relay("", "", @message);

			if ($config{DEBUG} >= 1) {logfile("LOGSCANNER report sent")}
		}

		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","logscanner",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end logscanner
###############################################################################
# start exploit
sub exploit {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","exploit",$timer)}

		my $lockstr = "LF_EXPLOIT";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;

		$0 = "lfd - checking system exploit";

		my %exploit_tests;
		foreach my $test (split(/\,/,$config{LF_EXPLOIT_IGNORE})) {$exploit_tests{$test} = 1}
		my $report = "";

		unless ($exploit_tests{SUPERUSER}) {
			while (my ($name,undef,$uid) = getpwent()) {
				if (($uid == 0) and ($name ne "root") and ($suignore{$name} != 1)) {
					$report .= "Possible root compromise: User account $name is a superuser (UID 0)\n";
					logfile("*System Exploit* has detected a possible root compromise ($name = UID 0)");
				}
			}
			endpwent();
		}

		if ($report) {
			$0 = "lfd - (child) system exploit alert";
			sysopen (my $TEMPEXPLOIT, "/var/lib/csf/csf.tempexploit", O_WRONLY | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot open out file: $!");
			flock ($TEMPEXPLOIT, LOCK_EX);
			print $TEMPEXPLOIT time;
			close ($TEMPEXPLOIT);

			my @alert = slurp("/usr/local/csf/tpl/exploitalert.txt");
			my @message;
			foreach my $line (@alert) {
				$line =~ s/\[text\]/$report/ig;
				push @message, $line;
			}
			ConfigServer::Sendmail::relay("", "", @message);
			unlink "/var/lib/csf/csf.tempexp";
		}

		close ($THISLOCK );
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","exploit",$timer)}
		$0 = "lfd - child closing";
		exit;
	}
	return;
}
# end exploit
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
## start hex2ip
sub hex2ip {
    my $bin = pack "C*" => map hex, $_[0] =~ /../g;
    my @l = unpack "L*", $bin;
    if (@l == 4) {
        return join ':', map { sprintf "%x:%x", $_ >> 16, $_ & 0xffff } @l;
    }
    elsif (@l == 1) {
        return join '.', map { $_ >> 24, ($_ >> 16 ) & 0xff, ($_ >> 8) & 0xff, $_ & 0xff } @l;
    }
}
## end hex2ip
###############################################################################
# start cleanup
sub cleanup {
	$SIG{INT} = 'IGNORE';
	$SIG{TERM} = 'IGNORE';
	$SIG{HUP} = 'IGNORE';
	my $line = shift;
	my $message = shift;

	if (($message eq "") and $line) {
		$message = "Main Process: $line";
		$line = "";
	}

	$0 = "lfd - stopping";

	if ($message) {
		if ($line ne "") {$message .= ", at line $line"}
		logfile("$message");
	}
	logfile("daemon stopped");

	if ($PIDFILE and fileno($PIDFILE)) {
		close($PIDFILE);
		unlink $pidfile;
	}

	kill (9, -$$);

    exit 0;
}
# end cleanup
###############################################################################
# start childcleanup
sub childcleanup {
	$SIG{INT} = 'IGNORE';
	$SIG{TERM} = 'IGNORE';
	$SIG{HUP} = 'IGNORE';
	my $line = shift;
	my $message = shift;

	if (($message eq "") and $line ne "") {
		$message = "Child $childproc: $line";
		$line = "";
	}

	$0 = "child - aborting";

	if ($message) {
		if ($line ne "") {$message .= ", at line $line"}
		logfile("$message");
	}
    exit;
}
# end childcleanup
###############################################################################
# start ignoreip
sub ignoreip {
	my $ip = shift;
	my $skip = shift;

	if ($ip eq "") {return 0}

	if ($ips{$ip} or $ipscidr->find($ip) or $ipscidr6->find($ip)) {return 1}

	if ($ignoreips{$ip}) {return 1}

	if ($gignoreips{$ip}) {return 1}

	if ($config{CC_IGNORE}) {
		my ($cc,$asn) = iplookup($ip,1);
		($asn,undef) = split(/\s+/,$asn);
		if ($cc ne "" and $config{CC_IGNORE} =~ /$cc/i) {return 1}
		if ($asn ne "" and $config{CC_IGNORE} =~ /$asn/i) {return 1}
	}

	if ($relayip{$ip} and !$skip) {return 1}

	if (@cidrs) {
		if ($cidr->find($ip)) {return 1}
		if ($cidr6->find($ip)) {return 1}
	}

	if (@gcidrs) {
		if ($gcidr->find($ip)) {return 1}
		if ($gcidr6->find($ip)) {return 1}
	}

	if (@rdns and !$skip) {
		my $matchdomain;
		my $matchip;

		my $dnsip;
		my $dnsrip;
		my $dnshost;
		my $cachehit;
		open (my $DNS, "<", "/var/lib/csf/csf.dnscache");
		flock ($DNS, LOCK_SH);
		while (my $line = <$DNS>) {
			chomp $line;
			($dnsip,$dnsrip,$dnshost) = split(/\|/,$line);
			if ($ip eq $dnsip) {
				$cachehit = 1;
				last;
			}
		}
		close ($DNS);
		if ($cachehit) {
			$matchip = $dnsrip;
			$matchdomain = $dnshost;
			if ($config{DEBUG} >= 2) {logfile("debug: (ignoreip) [cached] [$ip]:[$matchip] [$matchdomain]")}
		} else {
			eval {
				local $SIG{__DIE__} = undef;
				local $SIG{'ALRM'} = sub {die};
				alarm(8);
				$matchip = inet_aton($ip);
				$matchdomain = gethostbyaddr($matchip, AF_INET);
				if ($matchdomain ne "") {
					$matchip = gethostbyname($matchdomain);
					$matchip = inet_ntoa($matchip);
				}
				alarm(0);
			};
			alarm(0);
			unless (checkip(\$matchip)) {$matchip = ""}
			sysopen (my $DNS, "/var/lib/csf/csf.dnscache", O_WRONLY | O_APPEND | O_CREAT);
			flock ($DNS, LOCK_EX);
			print $DNS "$ip|$matchip|$matchdomain\n";
			close ($DNS);
			if ($config{DEBUG} >= 2) {logfile("debug: (ignoreip) [not cached] [$ip]:[$matchip] [$matchdomain]")}
		}

		if ($ip eq $matchip) {
			foreach my $host (@rdns) {
				if (($host =~ /\./) and ($matchdomain =~ /$host$/)) {
					if ($config{DEBUG} >= 1) {logfile("debug: (ignoreip) [$ip]:[$matchip] [$host]:[$matchdomain]")}
					return 1;
				}
				if ($matchdomain eq $host) {
					if ($config{DEBUG} >= 1) {logfile("debug: (ignoreip) [$ip]:[$matchip] [$host]:[$matchdomain]")}
					return 1;
				}
			}
		}
	}

	return 0;
}
# end ignoreip
###############################################################################
# start linefilter
sub linefilter {
	my $line = shift;
	my $ad = shift;
	my $chain = shift;
	my $delete = shift;
	my $pktin = "$accept";
	my $pktout = "$accept";
	my $inadd = "-I";
	my $verbose = "";
	my $localin = "ALLOWIN";
	my $localout = "ALLOWOUT";
	if ($ad eq "deny") {
		$inadd = "-A";
		$pktin = $config{DROP};
		$pktout = $config{DROP_OUT};
		if ($config{DROP_IP_LOGGING}) {$pktin = "LOGDROPIN"}
		if ($config{DROP_OUT_LOGGING}) {$pktout = "LOGDROPOUT"}
		$localin = "DENYIN";
		$localout = "DENYOUT";
	}
	my $chainin = $chain."IN";
	my $chainout = $chain."OUT";

	$line =~ s/\n|\r//g;
	$line = lc $line;
	if ($line =~ /^\#/) {return}
	if ($line =~ /^Include/) {return}
	if ($line eq "") {return}

	my $checkip = checkip(\$line);
	my $iptables = $config{IPTABLES};
	my $ipv4 = 1;
	my $ipv6 = 0;
	my $linein = $ethdevin;
	my $lineout = $ethdevout;
	if ($checkip == 6) {
		if ($config{IPV6}) {
			$iptables = $config{IP6TABLES};
			$linein = $eth6devin;
			$lineout = $eth6devout;
			$ipv4 = 0;
			$ipv6 = 1;
		} else {return}
	}

	if ($checkip) {
		if ($chain) {
			if ($config{LF_IPSET}) {
				if ($ipv4) {&ipsetadd("chain_$chainin",$line)}
				else {&ipsetadd("chain_6_${chainin}",$line)}
			} else {
				&iptablescmd(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -A $chainin $linein -s $line -j $pktin");
				if (($ad eq "deny" and !$config{LF_BLOCKINONLY}) or ($ad ne "deny")) {&iptablescmd(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -A $chainout $lineout -d $line -j $pktout")}
			}
		} else {
			if ($delete) {
				if ($config{LF_IPSET}) {
					if ($ipv4) {&ipsetdel("chain_$localin",$line)}
					else {&ipsetdel("chain_6_${localin}",$line)}
				} else {
					&iptablescmd(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -D $localin $linein -s $line -j $pktin");
					if (($ad eq "deny" and !$config{LF_BLOCKINONLY}) or ($ad ne "deny")) {&syscommand(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -D $localout $lineout -d $line -j $pktout")}
				}
				if (($ad eq "deny") and ($ipv4 and $config{MESSENGER} and $config{MESSENGER_PERM})) {&domessenger($line,"D")}
				if (($ad eq "deny") and ($ipv6 and $config{MESSENGER6} and $config{MESSENGER_PERM})) {&domessenger($line,"D")}
			} else {
				if ($config{LF_IPSET}) {
					if ($ipv4) {&ipsetadd("chain_$localin",$line)}
					else {&ipsetadd("chain_6_${localin}",$line)}
				} else {
					&iptablescmd(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose $inadd $localin $linein -s $line -j $pktin");
					if (($ad eq "deny" and !$config{LF_BLOCKINONLY}) or ($ad ne "deny")) {&iptablescmd(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose $inadd $localout $lineout -d $line -j $pktout")}
				}
				if (($ad eq "deny") and ($ipv4 and $config{MESSENGER} and $config{MESSENGER_PERM})) {&domessenger($line,"A")}
				if (($ad eq "deny") and ($ipv6 and $config{MESSENGER6} and $config{MESSENGER_PERM})) {&domessenger($line,"A")}
			}
		}
	}
	elsif ($line =~ /\:|\|/) {
		if ($line !~ /\|/) {$line =~ s/\:/\|/g}
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
		if ($ll[0] eq "tcp") {
			$protocol = "-p tcp";
			$from = 1;
		}
		elsif ($ll[0] eq "udp") {
			$protocol = "-p udp";
			$from = 1;
		}
		elsif ($ll[0] eq "icmp") {
			$protocol = "-p icmp";
			$from = 1;
		}
		for (my $x = $from;$x < 2;$x++) {
			if (($ll[$x] eq "out")) {
				$inout = "out";
				$from = $x + 1;
				last;
			}
			elsif (($ll[$x] eq "in")) {
				$inout = "in";
				$from = $x + 1;
				last;
			}
		}
		for (my $x = $from;$x < 3;$x++) {
			if (($ll[$x] =~ /d=(.*)/)) {
				$dport = "--dport $1";
				$dport =~ s/_/:/g;
				if ($protocol eq "-p icmp") {$dport = "--icmp-type $1"}
				if ($dport =~ /,/) {$dport = "-m multiport ".$dport}
				$from = $x + 1;
				last;
			}
			elsif (($ll[$x] =~ /s=(.*)/)) {
				$sport = "--sport $1";
				$sport =~ s/_/:/g;
				if ($protocol eq "-p icmp") {$sport = "--icmp-type $1"}
				if ($sport =~ /,/) {$sport = "-m multiport ".$sport}
				$from = $x + 1;
				last;
			}
		}
		for (my $x = $from;$x < 4;$x++) {
			if (($ll[$x] =~ /d=(.*)/)) {
				my $ip = $1;
				my $status = checkip(\$ip);
				if ($status) {
					$iptype = $status;
					$dip = "-d $1";
				}
				last;
			}
			elsif (($ll[$x] =~ /s=(.*)/)) {
				my $ip = $1;
				my $status = checkip(\$ip);
				if ($status) {
					$iptype = $status;
					$sip = "-s $1";
				}
				last;
			}
		}
		for (my $x = $from;$x < 5;$x++) {
			if (($ll[$x] =~ /u=(.*)/)) {
				$uid = "--uid-owner $1";
				last;
			}
			elsif (($ll[$x] =~ /g=(.*)/)) {
				$gid = "--gid-owner $1";
				last;
			}
		}
		if (($sip or $dip) and ($dport or $sport)) {
			my $iptables = $config{IPTABLES};
			if ($iptype == 6) {
				if ($config{IPV6}) {
					$iptables = $config{IP6TABLES};
				} else {
					return;
				}
			}
			if (($inout eq "") or ($inout eq "in")) {
				my $bport = $dport;
				$bport =~ s/--dport //o;
				my $bip = $sip;
				$bip =~ s/-s //o;
				if ($chain) {
					&iptablescmd(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -A $chainin $linein $protocol $dip $sip $dport $sport -j $pktin");
				} else {
					if ($delete) {
						&iptablescmd(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -D $localin $linein $protocol $dip $sip $dport $sport -j $pktin");
						if ($messengerports{$bport} and ($ad eq "deny") and ($ipv4 and $config{MESSENGER} and $config{MESSENGER_PERM})) {&domessenger($bip,"D","$bport")}
						if ($messengerports{$bport} and ($ad eq "deny") and ($ipv6 and $config{MESSENGER6} and $config{MESSENGER_PERM})) {&domessenger($bip,"D","$bport")}
					} else {
						&iptablescmd(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose $inadd $localin $linein $protocol $dip $sip $dport $sport -j $pktin");
						if ($messengerports{$bport} and ($ad eq "deny") and ($ipv4 and $config{MESSENGER} and $config{MESSENGER_PERM})) {&domessenger($bip,"A","$bport")}
						if ($messengerports{$bport} and ($ad eq "deny") and ($ipv6 and $config{MESSENGER6} and $config{MESSENGER_PERM})) {&domessenger($bip,"A","$bport")}
					}
				}
			}
			if ($inout eq "out") {
				if ($chain) {
					&iptablescmd(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -A $chainout $lineout $protocol $dip $sip $dport $sport -j $pktout");
				} else {
					if ($delete) {
						&iptablescmd(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose -D $localout $lineout $protocol $dip $sip $dport $sport -j $pktout");
					} else {
						&iptablescmd(__LINE__,"$iptables $config{IPTABLESWAIT} $verbose $inadd $localout $lineout $protocol $dip $sip $dport $sport -j $pktout");
					}
				}
			}
		}
	}
	return;
}
# end linefilter
###############################################################################
# start iptablescmd
sub iptablescmd {
	my $line = shift;
	my $command = shift;
	$command =~ s/;`|//g;
	my $status = 0;
	my $iptableslock = 0;
	if ($command =~ /^($config{IPTABLES}|$config{IP6TABLES})/) {$iptableslock = 1}
	if ($faststart) {
		if ($command =~ /^$config{IPTABLES}\s+(.*)$/) {
			my $fastcmd = $1;
			$fastcmd =~ s/-v//;
			$fastcmd =~ s/--wait//;
			if ($fastcmd =~ /-t\s+nat/) {
				$fastcmd =~ s/-t\s+nat//;
				push @faststart4nat,$fastcmd;
			} else {
				push @faststart4,$fastcmd;
			}
		}
		if ($command =~ /^$config{IP6TABLES}\s+(.*)$/) {
			my $fastcmd = $1;
			$fastcmd =~ s/-v//;
			$fastcmd =~ s/--wait//;
			if ($fastcmd =~ /-t\s+nat/) {
				$fastcmd =~ s/-t\s+nat//;
				push @faststart6nat,$fastcmd;
			} else {
				push @faststart6,$fastcmd;
			}
		}
		return;
	}

	if (-e "/etc/csf/csf.error") {
		&cleanup(__LINE__,"*Error* csf reported an error (see /etc/csf/csf.error). *lfd stopped*");
		exit 1;
	}

	if ($config{VPS}) {$status = &checkvps}
	if ($status) {
		logfile($status);
	} else {
		if ($config{DEBUG} >= 2) {logfile("debug[$line]: Command:$command")}
		if (&csflock) {
			logfile("csf is currently restarting - command [$command] skipped on line $line");
			unless ($masterpid == $$) {exit}
		}
		if ($iptableslock) {&iptableslock("lock")}
		my @output;
		if ($iptableslock and $config{WAITLOCK}) {
			eval {
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
			if ($@ eq "alarm\n") {
				&cleanup(__LINE__,"*Error* timeout after iptables --wait for $config{WAITLOCK_TIMEOUT} seconds - WAITLOCK");
			}
		} else {
			my ($childin, $childout);
			my $cmdpid = open3($childin, $childout, $childout, $command);
			@output = <$childout>;
			waitpid ($cmdpid, 0);
		}
		if ($iptableslock) {&iptableslock("unlock")}

		chomp @output;
		if ($output[0] =~ /# Warning: iptables-legacy tables present/) {shift @output}
		if ($output[0] =~ /^deny failed\:/) {logfile("*Error*: csf output: $output[0]")}
		if ($output[0] =~ /^Error\:/) {logfile("*Error*: csf output: $output[0]")}
		if ($output[0] =~ /xtables lock/) {logfile("*Error*: Unable to check csf due to xtables lock, enable WAITLOCK in csf.conf")}

		if ($output[0] =~ /(^iptables: Unknown error 4294967295)|(xtables lock)/ and !$config{WAITLOCK}) {
			my $cnt = 0;
			my $repeat = 6;
			while ($cnt < $repeat) {
				sleep 1;
				if ($config{DEBUG} >= 1) {logfile("debug[$line]: Retry (".($cnt+1).") [$command] due to [$output[0]]")}
				if ($iptableslock) {&iptableslock("lock")}
				my ($childin, $childout);
				my $cmdpid = open3($childin, $childout, $childout, $command);
				my @output = <$childout>;
				waitpid ($cmdpid, 0);
				if ($iptableslock) {&iptableslock("unlock")}
				chomp @output;
				if ($output[0] =~ /# Warning: iptables-legacy tables present/) {shift @output}
				$cnt++;
				if ($output[0] =~ /(^iptables: Unknown error 4294967295)|(xtables lock)/ and $cnt == $repeat) {logfile("*Error* processing command for line [$line] ($repeat times): [$output[0]]");}
				unless ($output[0] =~ /(^iptables: Unknown error 4294967295)|(xtables lock)/) {$cnt = $repeat}
			}
		}
		elsif ($config{DEBUG} >= 1 and $output[0] =~ /^iptables|ip6tables|xtables|Bad|Another/) {
				logfile("*Error* processing command for line [$line]: [$output[0]]");
		}
	}
	return;
}
# end iptablescmd
###############################################################################
# start syscommand
sub syscommand {
	my ($line, @cmd) = @_;
	my $cmdline = join(" ",@cmd);
	my $status = 0;
	my @output;

	if (-e "/etc/csf/csf.error") {
		&cleanup(__LINE__,"*Error* csf reported an error (see /etc/csf/csf.error). *lfd stopped*");
		exit 1;
	}

	if ($config{VPS}) {$status = &checkvps}
	if ($status) {
		logfile($status);
	} else {
		if ($config{DEBUG} >= 2) {logfile("debug[$line]: Command:$cmdline")}
		if (&csflock) {
			logfile("csf is currently restarting - command [$cmdline] skipped on line $line");
			unless ($masterpid == $$) {exit}
		}
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, @cmd);
		@output = <$childout>;
		waitpid ($cmdpid, 0);
		if ($output[0] =~ /# Warning: iptables-legacy tables present/) {shift @output}
		if ($output[0] =~ /^deny failed\:/) {logfile("*Error*: csf output: $output[0]")}
		if ($output[0] =~ /^Error\:/) {logfile("*Error*: csf output: $output[0]")}
	}
	return @output;
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
# start timer
sub timer {
	my $status = shift;
	my $check = shift;
	my $start = shift;

	if ($status eq "start") {
		logfile("debug: TIMER start: $check");
		return Time::HiRes::gettimeofday();
	} else {
		if ($start == 0) {return}
		my $diff = sprintf '%.6f', (Time::HiRes::gettimeofday() - $start);
		logfile("debug: TIMER stop:  $check ($diff secs)");
	}
	return;
}
# end timer
###############################################################################
# start csflock
sub csflock {
	my $ret = 0;
	sysopen (my $CSFLOCKFILE, "/var/lib/csf/csf.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open csf lock file");
	flock ($CSFLOCKFILE, LOCK_SH | LOCK_NB) or $ret = 1;
	close ($CSFLOCKFILE);

	return $ret;
}
# end csflock
###############################################################################
# start lockfail
sub lockfail {
	my $section = shift;
	logfile("csf is currently restarting - section [$section] skipped");
	exit;
}
# end lockfail
###############################################################################
# start ipblock
sub ipblock {
	my $perm = shift;
	my $message = shift;
	my $ip = shift;
	my $port = shift;
	my $inout = shift;
	my $timeout = shift;
	my $cluster = shift;
	my $logs = shift;
	my $active = shift;
	unless ($active) {$active = "other"}
	my $return = 0;

	if ($message =~ / exceeds /) {$cluster = 1}

	my @report;
	$report[0] = $ip;
	if ($port) {$report[1] = "$port"} else {$report[1] = "*"}
	if ($perm) {$report[2] = "1"} else {$report[2] = "0"}
	if ($inout) {$report[3] = "$inout"} else {$report[3] = "inout"}
	if ($timeout) {$report[4] = "$timeout"} else {$report[4] = "0"}
	if ($message) {$report[5] = "$message"} else {$report[5] = " "}
	if ($logs) {$report[6] = "$logs"} else {$report[6] = " "}
	if ($active) {$report[7] = "$active"}

	my $ipv = checkip(\$ip);
	unless ($ipv) {return 1}
	my (undef,$iscidr) = split(/\//,$ip);
	if ($iscidr and !$cluster and ($active ne "CT_SUBNET_LIMIT")) {
		if ($config{DEBUG} >= 1) {logfile("debug: IP [$ip] not blocked, contains a CIDR (ignore already blocked message)")}
		return 1;
	}

	$0 = "lfd - (child) blocking $ip";

	my $blocked = 0;
	if (!$iscidr and ($config{LF_PERMBLOCK} or $config{LF_NETBLOCK})) {
		if (&denycheck($ip)) {
			$return = 2;
		} else {
			my $ips;
			my $ipmatch;
			my $ptext;
			my $nips;
			my $ntext;
			my $nipmatch;
			my $ipblock;
			my @newdata;
			my %skipip;
			my %skipnip;
			my $block_interval = $config{LF_PERMBLOCK_INTERVAL};
			if ($config{LF_NETBLOCK_INTERVAL} > $config{LF_PERMBLOCK_INTERVAL}) {$block_interval = $config{LF_NETBLOCK_INTERVAL}}
			if ($ipv == 4) {
				if ($config{LF_NETBLOCK_CLASS} eq "A") {
					if ($ip =~ /^(\d+)/) {$ipblock = "$1\.0\.0\.0/8"}
				}
				elsif ($config{LF_NETBLOCK_CLASS} eq "B") {
					if ($ip =~ /^(\d+\.\d+)/) {$ipblock = "$1\.0\.0/16"}
				}
				elsif ($config{LF_NETBLOCK_CLASS} eq "C") {
					if ($ip =~ /^(\d+\.\d+\.\d+)/) {$ipblock = "$1\.0/24"}
				}
			}
			elsif ($ipv == 6 and $config{LF_NETBLOCK_IPV6} ne "") {
				if ($config{LF_NETBLOCK_IPV6} eq "/64" or $config{LF_NETBLOCK_IPV6} eq "/56" or $config{LF_NETBLOCK_IPV6} eq "/48" or $config{LF_NETBLOCK_IPV6} eq "/32" or $config{LF_NETBLOCK_IPV6} eq "24") {
					eval {
						local $SIG{__DIE__} = undef;
						my $netip = $ip.$config{LF_NETBLOCK_IPV6};
						my $status = checkip(\$netip);
						if ($status == 6) {$ipblock = $netip}
					};
				}
			}

			sysopen (my $TEMPIP, "/var/lib/csf/csf.tempip", O_RDWR | O_CREAT);
			flock ($TEMPIP, LOCK_EX);
			my @data = <$TEMPIP>;
			chomp @data;
			foreach my $line (@data) {
				my ($oip,$operm,$otime,$omessage) = split(/\|/,$line,4);
				if (time - $otime < $block_interval) {
					push @newdata,$line;
				}
				if ($config{LF_PERMBLOCK} and !$perm) {
					if (($ip eq $oip) and ($operm != 1) and (time - $otime < $config{LF_PERMBLOCK_INTERVAL})) {
						$ips++;
						$ptext .= localtime($otime)." $omessage\n";
						$skipip{$line} = 1;
					}
					if ($operm and ($ip eq $oip)) {
						$ipmatch = 1;
					}
				}
				if ($config{LF_NETBLOCK} and ($ipv == 4) and $ipblock) {
					if (time - $otime < $config{LF_NETBLOCK_INTERVAL}) {
						my $block = "";
						if ($config{LF_NETBLOCK_CLASS} eq "A") {
							if ($oip =~ /^(\d+)/) {$block = "$1\.0\.0\.0/8"}
						}
						elsif ($config{LF_NETBLOCK_CLASS} eq "B") {
							if ($oip =~ /^(\d+\.\d+)/) {$block = "$1\.0\.0/16"}
						}
						elsif ($config{LF_NETBLOCK_CLASS} eq "C") {
							if ($oip =~ /^(\d+\.\d+\.\d+)/) {$block = "$1\.0/24"}
						}
						if ($block ne "" and ($ipblock eq $block)) {
							unless ($oip eq $ip) {
								$nips++;
								$ntext .= localtime($otime)." $omessage\n";
								$skipnip{$line} = 1;
							}
						}
#						if ($block eq $oip) {$nipmatch = 1}
					}
				}
				if ($config{LF_NETBLOCK} and ($ipv == 6) and $config{LF_NETBLOCK_IPV6} ne "" and $ipblock) {
					if (time - $otime < $config{LF_NETBLOCK_INTERVAL}) {
						my $block = "";
						eval {
							local $SIG{__DIE__} = undef;
							my $netip = $oip.$config{LF_NETBLOCK_IPV6};
							my $status = checkip(\$netip);
							if ($status == 6) {$block = $netip}
						};
						if ($block ne "" and ($ipblock eq $block)) {
							unless ($oip eq $ip) {
								$nips++;
								$ntext .= localtime($otime)." $omessage\n";
								$skipnip{$line} = 1;
							}
						}
#						if ($block eq $oip) {$nipmatch = 1}
					}
				}
			}
			if ($ipmatch) {
				$ips = 0;
				undef %skipip;
				if ($config{DEBUG} >= 1) {logfile("debug: $message - already PERM blocked")}
			} else {
				$ips++;
				$ptext .= localtime(time)." $message\n";
			}
			if ($nipmatch) {
				$nips = 0;
				undef %skipnip;
				if ($config{DEBUG} >= 1) {logfile("debug: $message - already NET blocked")}
			} else {
				$nips++;
				$ntext .= localtime(time)." $message\n";
			}

			if ($nips > $config{LF_NETBLOCK_COUNT}) {
				my $status = 0;
				if ($config{VPS}) {$status = &checkvps}
				if ($status) {
					logfile($status);
				} else {
					my $tip = iplookup($ipblock);
					$message = "(NETBLOCK) $tip has had more than $config{LF_NETBLOCK_COUNT} blocks in the last $config{LF_NETBLOCK_INTERVAL} secs";
					&syscommand(__LINE__,"/usr/sbin/csf","-d",$ipblock,"lfd: $message");
					logfile("$message - *Blocked in csf* [$active]");
					if ($config{CLUSTER_BLOCK} and $config{CLUSTER_SENDTO} and !$cluster) {&lfdclient(1,$message,$ipblock,"","inout","0")}
					if ($config{BLOCK_REPORT}) {&block_report($ipblock,"*","1","inout","0",$message,"","LF_NETBLOCK_COUNT")}
					if ($config{ST_ENABLE}) {&stats_report($ipblock,"*","1","inout","0",$message,"","LF_NETBLOCK_COUNT")}
					$blocked = 1;
				}

				if ($config{LF_NETBLOCK_ALERT}) {
					$0 = "lfd - (child) sending alert email for $ipblock";

					my @alert = slurp("/usr/local/csf/tpl/netblock.txt");
					my @message;
					my $tip = iplookup($ipblock);
					foreach my $line (@alert) {
						$line =~ s/\[block\]/$tip/ig;
						$line =~ s/\[count\]/$nips/ig;
						if (checkip(\$ipblock) == 4) {
							$line =~ s/\[class\]/$config{LF_NETBLOCK_CLASS}/ig;
						} else {
							$line =~ s/\[class\]/$config{LF_NETBLOCK_IPV6}/ig;
						}
						$line =~ s/\[ips\]/$ntext/ig;
						push @message, $line;
					}
					ConfigServer::Sendmail::relay("", "", @message);
				}

				$ip = $ipblock;
				$perm = 1;
				$blocked = 1;
			}
			elsif ($ips > $config{LF_PERMBLOCK_COUNT}) {
				my $status = 0;
				if ($config{VPS}) {$status = &checkvps}
				if ($status) {
					logfile($status);
				} else {
					my $tip = iplookup($ip);
					$message = "(PERMBLOCK) $tip has had more than $config{LF_PERMBLOCK_COUNT} temp blocks in the last $config{LF_PERMBLOCK_INTERVAL} secs";
					&syscommand(__LINE__,"/usr/sbin/csf","-tr",$ip);
					&syscommand(__LINE__,"/usr/sbin/csf","-d",$ip,"lfd: $message");
					logfile("$message - *Blocked in csf* [$active]");
					if ($config{CLUSTER_BLOCK} and $config{CLUSTER_SENDTO} and !$cluster) {&lfdclient(1,$message,$ip,"","inout","0")}
					if ($config{BLOCK_REPORT}) {&block_report($ip,"*","1","inout","0",$message,"","LF_PERMBLOCK_COUNT")}
					if ($config{ST_ENABLE}) {&stats_report($ip,"*","1","inout","0",$message,"","LF_PERMBLOCK_COUNT")}
					$blocked = 1;
				}
				if ($config{LF_PERMBLOCK_ALERT}) {
					$0 = "lfd - (child) sending alert email for $ip";

					my @alert = slurp("/usr/local/csf/tpl/permblock.txt");
					my $tip = iplookup($ip);
					my @message;
					foreach my $line (@alert) {
						$line =~ s/\[ip\]/$tip/ig;
						$line =~ s/\[count\]/$ips/ig;
						$line =~ s/\[blocks\]/$ptext/ig;
						push @message, $line;
					}
					ConfigServer::Sendmail::relay("", "", @message);
				}
				$perm = 1;
				$blocked = 1;
			}
			seek ($TEMPIP, 0, 0);
			truncate ($TEMPIP, 0);
			foreach my $line (@newdata) {
				if (($ips > $config{LF_PERMBLOCK_COUNT}) and ($skipip{$line})) {next}
				if (($nips > $config{LF_NETBLOCK_COUNT}) and ($skipnip{$line})) {next}
				print $TEMPIP "$line\n";
			}
			print $TEMPIP "$ip|$perm|".time."|$message\n";
			close ($TEMPIP);
		}
	}
	if (!$blocked and !$return) {
		if ($perm) {
			if ($port) {
				foreach my $dport (split(/\,/,$port)) {
					my $status = 0;
					if ($config{VPS}) {$status = &checkvps}
					if ($status) {
						logfile($status);
					} else {
						if (&denycheck("tcp|in|d=$dport|s=$ip",undef,$perm)) {
							$return = 2;
						} else {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							&syscommand(__LINE__,"/usr/sbin/csf","-d","$proto|in|d=$dport|s=$ip","lfd: $message");
							logfile("$message - *Blocked in csf* port=$dport [$active]");
							$blocked = 1;
						}
					}
				}
				if ($blocked) {$return = 0}
			} else {
				my $status = 0;
				if ($config{VPS}) {$status = &checkvps}
				if ($status) {
					logfile($status);
				} else {
					if (&denycheck($ip,undef,$perm)) {
						$blocked = 0;
						$return = 2;
					} else {
						$blocked = 1;
						&syscommand(__LINE__,"/usr/sbin/csf","-d",$ip,"lfd: $message");
						logfile("$message - *Blocked in csf* [$active]");
					}
				}
			}
			if ($blocked) {
				if ($config{CLUSTER_BLOCK} and $config{CLUSTER_SENDTO} and !$cluster) {&lfdclient(1,$message,$ip,$port,$inout,"0")}
				if ($config{BLOCK_REPORT}) {&block_report(@report)}
				if ($config{ST_ENABLE}) {&stats_report(@report)}
			}
		} else {
			if (&denycheck($ip,$port,$perm)) {
				$return = 2;
			} else {
				my $dropin = $config{DROP};
				my $dropout = $config{DROP_OUT};
				if ($config{DROP_IP_LOGGING}) {$dropin = "LOGDROPIN"}
				if ($config{DROP_OUT_LOGGING}) {$dropout = "LOGDROPOUT"}
				if ($timeout < 2) {$timeout = 3600}
				my $iptype = checkip(\$ip);

				if ($inout =~ /in/) {
					if ($port) {
						foreach my $dport (split(/\,/,$port)) {
							my ($tport,$proto) = split(/\;/,$dport);
							$dport = $tport;
							if ($proto eq "") {$proto = "tcp"}
							if ($iptype == 6) {
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A DENYIN $eth6devin -p $proto --dport $dport -s $ip -j $dropin");
								if ($messengerports{$dport} and $config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"A",$dport)}
							} else {
								&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A DENYIN $ethdevin -p $proto --dport $dport -s $ip -j $dropin");
								if ($messengerports{$dport} and $config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"A",$dport)}
							}
						}
					} else {
						if ($iptype == 6) {
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A DENYIN $eth6devin -s $ip -j $dropin");
							if ($config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"A")}
						} else {
							&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A DENYIN $ethdevin -s $ip -j $dropin");
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
								&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A DENYOUT $eth6devout -p $proto --dport $dport -d $ip -j $dropout");
							} else {
								&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A DENYOUT $ethdevout -p $proto --dport $dport -d $ip -j $dropout");
							}
						}
					} else {
						if ($iptype == 6) {
							&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -A DENYOUT $eth6devout -d $ip -j $dropout");
						} else {
							&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -A DENYOUT $ethdevout -d $ip -j $dropout");
						}
					}
				}
				sysopen (my $TEMPBAN, "/var/lib/csf/csf.tempban", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot append out file: $!");
				flock ($TEMPBAN, LOCK_EX);
				print $TEMPBAN time."|$ip|$port|$inout|$timeout|lfd - $message\n";
				close ($TEMPBAN);

				if ($message) {logfile("$message - *Blocked in csf* for $timeout secs [$active]")}
				if ($config{CLUSTER_BLOCK} and $config{CLUSTER_SENDTO} and !$cluster) {&lfdclient($perm,$message,$ip,$port,$inout,$timeout)}
				if ($config{BLOCK_REPORT}) {&block_report(@report)}
				if ($config{ST_ENABLE}) {&stats_report(@report)}
			}
		}
	}
	return $return;
}
# end ipblock
###############################################################################
# start ipunblock
sub ipunblock {
	if (! -z "/var/lib/csf/csf.tempban") {
		$SIG{CHLD} = 'IGNORE';
		unless (defined ($childpid = fork)) {
			&cleanup(__LINE__,"*Error* cannot fork: $!");
		} 
		$forks{$childpid} = 1;
		unless ($childpid) {
			$0 = "lfd - processing temporary bans";
			my $timer = time;
			if ($config{DEBUG} >= 3) {$timer = &timer("start","ipunblock",$timer)}
			sysopen (my $TEMPBAN, "/var/lib/csf/csf.tempban", O_RDWR | O_CREAT) or &childcleanup(__LINE__,"Unable to open /var/lib/csf/csf.tempban: $!");
			unless (flock ($TEMPBAN, LOCK_EX | LOCK_NB)) {
				if ($config{DEBUG} >= 3) {logfile("debug: Unable to lock csf.tempban in ipunblock")}
			} else {
				my @data = <$TEMPBAN>;
				chomp @data;

				my $cnt = @data;
				my @newdata;
				foreach my $line (@data) {
					my $unblock = 0;
					my $logmess = "";
					if ($config{DENY_TEMP_IP_LIMIT} and ($cnt > $config{DENY_TEMP_IP_LIMIT})) {
						$unblock = 1;
						$logmess = "(too many temporary bans in list)";
					}
					my ($time,$ip,$port,$inout,$timeout,$message) = split(/\|/,$line);
					my $iptype = checkip(\$ip);
					if ((((time - $time) >= $timeout) and $ip) or $unblock) {
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
										&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D DENYIN $eth6devin -p $proto --dport $dport -s $ip -j $dropin");
										if ($messengerports{$dport} and $config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D",$dport)}
									} else {
										&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D DENYIN $ethdevin -p $proto --dport $dport -s $ip -j $dropin");
										if ($messengerports{$dport} and $config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D",$dport)}
									}
									logfile("Incoming IP $ip:$dport temporary block removed");
									if ($config{UNBLOCK_REPORT}) {&unblock_report($ip,$dport)};
								}
							} else {
								if ($iptype == 6) {
									&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D DENYIN $eth6devin -s $ip -j $dropin");
									if ($config{MESSENGER6} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D")}
								} else {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D DENYIN $ethdevin -s $ip -j $dropin");
									if ($config{MESSENGER} and $config{MESSENGER_TEMP}) {&domessenger($ip,"D")}
								}
								logfile("Incoming IP $ip temporary block removed");
								if ($config{UNBLOCK_REPORT}) {&unblock_report($ip)};
							}
						}
						if ($inout =~ /out/) {
							if ($port) {
								foreach my $dport (split(/\,/,$port)) {
									my ($tport,$proto) = split(/\;/,$dport);
									$dport = $tport;
									if ($proto eq "") {$proto = "tcp"}
									if ($iptype == 6) {
										&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D DENYOUT $eth6devout -p $proto --dport $dport -d $ip -j $dropout");
									} else {
										&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D DENYOUT $ethdevout -p $proto --dport $dport -d $ip -j $dropout");
									}
									logfile("Outgoing IP $ip:$dport temporary block removed");
									if ($config{UNBLOCK_REPORT}) {&unblock_report($ip,$dport)};
								}
							} else {
								if ($iptype == 6) {
									&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D DENYOUT $eth6devout -d $ip -j $dropout");
								} else {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D DENYOUT $ethdevout -d $ip -j $dropout");
								}
								logfile("Outgoing IP $ip temporary block removed");
							}
							if ($config{UNBLOCK_REPORT}) {&unblock_report($ip)};
						}
						if ($config{CF_ENABLE} and $message =~ /\(CF_ENABLE\)/) {&cloudflare("remove",$ip,$config{CF_BLOCK})}
					} else {
						push @newdata, $line;
					}
					$cnt--;
				}
				eval {
					local $SIG{__DIE__} = undef;
					local $SIG{'ALRM'} = sub {die};
					alarm(60);
					local $SIG{INT} = 'IGNORE';
					local $SIG{TERM} = 'IGNORE';
					local $SIG{HUP} = 'IGNORE';
					seek ($TEMPBAN, 0, 0);
					truncate ($TEMPBAN, 0);
					foreach my $line (@newdata) {print $TEMPBAN "$line\n"}
				};
				alarm(0);
			}
			close ($TEMPBAN);
			if ($config{DEBUG} >= 3) {$timer = &timer("stop","ipunblock",$timer)}
			$0 = "lfd - (child) closing";
			exit;
		}
	}
	if (! -z "/var/lib/csf/csf.tempallow") {
		$SIG{CHLD} = 'IGNORE';
		unless (defined ($childpid = fork)) {
			&cleanup(__LINE__,"*Error* cannot fork: $!");
		} 
		$forks{$childpid} = 1;
		unless ($childpid) {
			$0 = "lfd - processing temporary allows";
			my $timer = time;
			if ($config{DEBUG} >= 3) {$timer = &timer("start","ipunblock",$timer)}
			sysopen (my $TEMPALLOW, "/var/lib/csf/csf.tempallow", O_RDWR | O_CREAT) or &childcleanup(__LINE__,"Enable to open /var/lib/csf/csf.tempallow: $!");
			unless (flock ($TEMPALLOW, LOCK_EX | LOCK_NB)) {
				if ($config{DEBUG} >= 3) {logfile("debug: Unable to lock csf.tempallow in ipunblock")}
			} else {
				my @data = <$TEMPALLOW>;
				chomp @data;

				my $cnt = @data;
				my @newdata;
				foreach my $line (@data) {
					my ($time,$ip,$port,$inout,$timeout,$message) = split(/\|/,$line);
					my $iptype = checkip(\$ip);
					if ((((time - $time) >= $timeout) and $ip)) {
						if ($inout =~ /in/) {
							if ($port) {
								foreach my $dport (split(/\,/,$port)) {
									my ($tport,$proto) = split(/\;/,$dport);
									$dport = $tport;
									if ($proto eq "") {$proto = "tcp"}
									if ($iptype == 6) {
										&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D ALLOWIN $eth6devin -p $proto --dport $dport -s $ip -j $accept");
									} else {
										&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D ALLOWIN $ethdevin -p $proto --dport $dport -s $ip -j $accept");
									}
									logfile("Incoming IP $ip:$dport temporary allow removed");
								}
							} else {
								if ($iptype == 6) {
									&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D ALLOWIN $eth6devin -s $ip -j $accept");
								} else {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D ALLOWIN $ethdevin -s $ip -j $accept");
								}
								logfile("Incoming IP $ip temporary allow removed");
							}
						}
						if ($inout =~ /out/) {
							if ($port) {
								foreach my $dport (split(/\,/,$port)) {
									my ($tport,$proto) = split(/\;/,$dport);
									$dport = $tport;
									if ($proto eq "") {$proto = "tcp"}
									if ($iptype == 6) {
										&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D ALLOWOUT $eth6devout -p $proto --dport $dport -d $ip -j $accept");
									} else {
										&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D ALLOWOUT $ethdevout -p $proto --dport $dport -d $ip -j $accept");
									}
									logfile("Outgoing IP $ip:$dport temporary allow removed");
								}
							} else {
								if ($iptype == 6) {
									&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -D ALLOWOUT $eth6devout -d $ip -j $accept");
								} else {
									&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -D ALLOWOUT $ethdevout -d $ip -j $accept");
								}
								logfile("Outgoing IP $ip temporary allow removed");
							}
						}
						if ($config{CF_ENABLE} and $message =~ /\(CF_ENABLE\)/) {&cloudflare("remove",$ip,"whitelist")}
					} else {
						push @newdata, $line;
					}
					$cnt--;
				}
				eval {
					local $SIG{__DIE__} = undef;
					local $SIG{'ALRM'} = sub {die};
					alarm(60);
					local $SIG{INT} = 'IGNORE';
					local $SIG{TERM} = 'IGNORE';
					local $SIG{HUP} = 'IGNORE';
					seek ($TEMPALLOW, 0, 0);
					truncate ($TEMPALLOW, 0);
					foreach my $line (@newdata) {print $TEMPALLOW "$line\n"}
				};
				alarm(0);
			}
			close ($TEMPALLOW);
			if ($config{DEBUG} >= 3) {$timer = &timer("stop","ipunblock",$timer)}
			$0 = "lfd - (child) closing";
			exit;
		}
	}
	return;
}
# end ipunblock
###############################################################################
# start cloudflare
sub cloudflare {
	my $action = shift;
	my $ip = shift;
	my $mode = shift;
	my $domains = shift;;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","cloudflare",$timer)}
		$0 = "lfd - (child) CloudFlare $action...";

		if ($action eq "remove") {
			ConfigServer::CloudFlare::action("remove",$ip,$mode);
		}
		elsif ($action eq "deny") {
			ConfigServer::CloudFlare::action("deny",$ip,$config{CF_BLOCK},"",$domains,1);
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","cloudflare",$timer)}
		$0 = "lfd - (child) closing";
		exit;
	}
	return;
}
# end cloudflare
###############################################################################
# start block_report
sub block_report {
	my @report = @_;
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","block_report",$timer)}
		$0 = "lfd - (child) Block Report...";

		eval {
			local $SIG{__DIE__} = undef;
			local $SIG{'ALRM'} = sub {die};
			alarm(10);
			if ($config{DEBUG} >= 1) {&logfile("debug: BLOCK_REPORT [$config{BLOCK_REPORT}] triggered")}
			system($config{BLOCK_REPORT},@report);
			alarm(0);
		};
		alarm(0);
		if ($@) {
			logfile("BLOCK_REPORT timed out after 10 seconds");
		} else {
			if ($config{DEBUG} >= 3) {logfile("debug: BLOCK_REPORT [$config{BLOCK_REPORT}] for ['$report[0]' '$report[1]' '$report[2]' '$report[3]' '$report[4]' '$report[5]']")}
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","block_report",$timer)}
		$0 = "lfd - (child) closing";
		exit;
	}
	return;
}
# end block_report
###############################################################################
# start unblock_report
sub unblock_report {
	my $ip = shift;
	my $port = shift;
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","unblock_report",$timer)}
		$0 = "lfd - (child) Block Report...";

		eval {
			local $SIG{__DIE__} = undef;
			local $SIG{'ALRM'} = sub {die};
			alarm(10);
			system($config{UNBLOCK_REPORT},$ip,$port);
			alarm(0);
		};
		alarm(0);
		if ($@) {
			logfile("UNBLOCK_REPORT timed out after 10 seconds");
		} else {
			if ($config{DEBUG} >= 3) {logfile("debug: UNBLOCK_REPORT [$config{UNBLOCK_REPORT}] for [$ip] [$port]")}
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","unblock_report",$timer)}
		$0 = "lfd - (child) closing";
		exit;
	}
	return;
}
# end unblock_report
###############################################################################
# start stats_report
sub stats_report {
	my @report = @_;
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","stats_report",$timer)}
		$0 = "lfd - (child) Stats Report...";

		my $lockstr = "ST_ENABLE_report";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		unless (flock ($THISLOCK, LOCK_EX | LOCK_NB)) {
			if ($config{DEBUG} >= 1) {
				&childcleanup("debug: *Lock Error* [$lockstr] still active - section skipped");
			} else {
				&childcleanup;
			}
		}
		print $THISLOCK time;

		#[0-23] hour, [24-54] day, [55-57] month
		my $STATS;
		if (-e "/var/lib/csf/stats/lfdstats") {
			sysopen ($STATS,"/var/lib/csf/stats/lfdstats", O_RDWR | O_CREAT);
		}
		elsif (-e "/var/lib/csf/stats/lfdmain") {
			sysopen (my $OLDSTATS,"/var/lib/csf/stats/lfdmain", O_RDWR | O_CREAT);
			flock ($OLDSTATS, LOCK_EX);
			my @stats = <$OLDSTATS>;
			chomp @stats;

			my @newstats;
			my $cnt = 0;
			foreach my $line (@stats) {
				if ($cnt == 55) {push @newstats,""}
				push @newstats,$line;
				$cnt++;
			}
			sysopen (my $STATS,"/var/lib/csf/stats/lfdstats", O_RDWR | O_CREAT);
			flock ($STATS, LOCK_EX);
			seek ($STATS, 0, 0);
			truncate ($STATS, 0);
			foreach my $line (@newstats) {
				print $STATS "$line\n";
			}
			close ($STATS);

			rename "/var/lib/csf/stats/lfdmain", "/var/lib/csf/stats/lfdmain.".time;
			close ($OLDSTATS);
			sysopen ($STATS,"/var/lib/csf/stats/lfdstats", O_RDWR | O_CREAT);
		} else {
			sysopen ($STATS,"/var/lib/csf/stats/lfdstats", O_RDWR | O_CREAT);
		}
		flock ($STATS, LOCK_EX);
		my @stats = <$STATS>;
		chomp @stats;

		my $perm = $report[2];
		my $trigger = $report[7];
		my $time = time;
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
		my @line;
		my %triggers;
		my $permdate;
		my $permcount;
		my $tempdate;
		my $tempcount;
		my $loop;

		@line = split(/\,/,$stats[$hour]);
		$permdate = $line[0];
		$permcount = $line[1];
		$tempdate = $line[2];
		$tempcount = $line[3];
		for ($loop = 4; $loop < @line; $loop+=2) {
			if ($time - $line[$loop] > (24 * 60 * 60)) {next}
			my ($triggerstat,$triggercount) = split(/\:/,$line[$loop+1]);
			$triggers{$triggerstat}{date} = $line[$loop];
			$triggers{$triggerstat}{count} = $triggercount;
		}
		$triggers{$trigger}{date} = $time;
		$triggers{$trigger}{count}++;
		if ($time - $permdate > (24 * 60 * 60)) {$permdate = 0; $permcount = 0}
		if ($time - $tempdate > (24 * 60 * 60)) {$tempdate = 0; $tempcount = 0}
		if ($perm) {$permdate = $time; $permcount++} else {$tempdate = $time; $tempcount++}
		$stats[$hour] = "$permdate,$permcount,$tempdate,$tempcount";
		foreach my $key (keys %triggers) {$stats[$hour] .= ",$triggers{$key}{date},$key:$triggers{$key}{count}"}
		
		@line = split(/\,/,$stats[$mday+24]);
		undef %triggers;
		$permdate = $line[0];
		$permcount = $line[1];
		$tempdate = $line[2];
		$tempcount = $line[3];
		for ($loop = 4; $loop < @line; $loop+=2) {
			if ($time - $line[$loop] > (29 * 24 * 60 * 60)) {next}
			my ($triggerstat,$triggercount) = split(/\:/,$line[$loop+1]);
			$triggers{$triggerstat}{date} = $line[$loop];
			$triggers{$triggerstat}{count} = $triggercount;
		}
		$triggers{$trigger}{date} = $time;
		$triggers{$trigger}{count}++;
		if ($time - $permdate > (29 * 24 * 60 * 60)) {$permdate = 0; $permcount = 0}
		if ($time - $tempdate > (29 * 24 * 60 * 60)) {$tempdate = 0; $tempcount = 0}
		if ($perm) {$permdate = $time; $permcount++} else {$tempdate = $time; $tempcount++}
		$stats[$mday+24] = "$permdate,$permcount,$tempdate,$tempcount";
		foreach my $key (keys %triggers) {$stats[$mday+24] .= ",$triggers{$key}{date},$key:$triggers{$key}{count}"}

		@line = split(/\,/,$stats[$mon+56]);
		undef %triggers;
		$permdate = $line[0];
		$permcount = $line[1];
		$tempdate = $line[2];
		$tempcount = $line[3];
		for ($loop = 4; $loop < @line; $loop+=2) {
			if ($time - $line[$loop] > (364 * 24 * 60 * 60)) {next}
			my ($triggerstat,$triggercount) = split(/\:/,$line[$loop+1]);
			$triggers{$triggerstat}{date} = $line[$loop];
			$triggers{$triggerstat}{count} = $triggercount;
		}
		$triggers{$trigger}{date} = $time;
		$triggers{$trigger}{count}++;
		if ($time - $permdate > (364 * 24 * 60 * 60)) {$permdate = 0; $permcount = 0}
		if ($time - $tempdate > (364 * 24 * 60 * 60)) {$tempdate = 0; $tempcount = 0}
		if ($perm) {$permdate = $time; $permcount++} else {$tempdate = $time; $tempcount++}
		$stats[$mon+56] = "$permdate,$permcount,$tempdate,$tempcount";
		foreach my $key (keys %triggers) {$stats[$mon+56] .= ",$triggers{$key}{date},$key:$triggers{$key}{count}"}

		if ($config{CC_LOOKUPS}) {
			my $cc = "**";
			my %ccs;
			@line = split(/\,/,$stats[69]);
			if ($report[5] =~ /\s\((\w\w)\//) {$cc = $1}
			for (my $x = 0; $x < @line; $x+=2) {$ccs{$line[$x]} = $line[$x+1]}
			$ccs{$cc}++;
			$stats[69] = "";
			foreach my $key (keys %ccs) {$stats[69] .= "$key,$ccs{$key},"}
		}

		seek ($STATS, 0, 0);
		truncate ($STATS, 0);
		foreach my $line (@stats) {
			print $STATS "$line\n";
		}
		close ($STATS);

		close ($THISLOCK);

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","stats_report",$timer)}
		$0 = "lfd - (child) closing";
		exit;
	}
	return;
}
# end stats_report
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
				if ($1 > $4 - 10) {return "The VPS iptables rule limit (numiptent) is too low ($1/$4) - *IP not blocked*"}
			}
		}
	}
	return 0;
}
# end checkvps
###############################################################################
# start messengerrecaptcha
sub messengerrecaptcha {
	my $timer = time;
	my (undef,undef,$uid,$gid,undef,undef,undef,$homedir) = getpwnam($config{MESSENGER_USER});
	if (-z "$homedir/unblock.txt") {return}

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		if ($config{DEBUG} >= 3) {$timer = &timer("start","messengerrecaptcha",$timer)}
		$0 = "lfd - reCAPTCHA csf...";
		$childproc = "Messenger (Recaptcha)";
		$SIG{INT} = \&childcleanup;
		$SIG{TERM} = \&childcleanup;
		$SIG{HUP} = \&childcleanup;
		$SIG{__DIE__} = sub {&childcleanup(@_);};

		if (-f "$homedir/unblock.txt") {
			my @alert = slurp("/usr/local/csf/tpl/recaptcha.txt");
			sysopen (my $UNBLOCK, "$homedir/unblock.txt", O_RDWR | O_CREAT);
			flock($UNBLOCK, LOCK_EX);
			while (my $line = <$UNBLOCK>) {
				chomp $line;
				my ($unblockip,$host,$hostip) = split(/;/,$line);
				if (checkip(\$unblockip)) {
					&logfile("reCAPTCHA: Unblocking client [$unblockip] on domain [$host ($hostip)]");
					&syscommand(__LINE__,"/usr/sbin/csf","-dr",$unblockip);
					&syscommand(__LINE__,"/usr/sbin/csf","-tr",$unblockip);

					if ($config{RECAPTCHA_ALERT}) {
						my $tip = iplookup($unblockip);
						my @message;
						foreach my $line (@alert) {
							$line =~ s/\[ip\]/$tip/ig;
							$line =~ s/\[host\]/$host ($hostip)/ig;
							push @message, $line;
						}
						ConfigServer::Sendmail::relay("", "", @message);

						if ($config{DEBUG} >= 1) {logfile("debug: recaptcha email sent for $unblockip")}
					}
				}
			}
			seek ($UNBLOCK, 0, 0);
			truncate ($UNBLOCK, 0);
			close ($UNBLOCK);
		}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","messengerrecaptcha",$timer)}
		exit;
	}
	return;
}
# end messengerrecaptcha
###############################################################################
# start messenger
sub messengerstop {
	my $version = shift;
	if ($version == 1) {
		return;
	}
	elsif ($version == 2) {
		if (-e "/etc/apache2/conf.d/csf.messenger.conf") {
			unlink("/etc/apache2/conf.d/csf.messenger.conf");
			system("/scripts/restartsrv_httpd");
			logfile("*MESSENGERV2* Removed /etc/apache2/conf.d/csf.messenger.conf");
		}
	}
	elsif ($version == 3) {
		if (-d $config{MESSENGERV3LOCATION}) {
			if (-e $config{MESSENGERV3LOCATION}."/csf.messenger.conf") {
				unlink($config{MESSENGERV3LOCATION}."/csf.messenger.conf");
				system($config{MESSENGERV3RESTART});
				logfile("*MESSENGERV3* Removed ".$config{MESSENGERV3LOCATION}."/csf.messenger.conf");
			}
		}
		elsif (-f $config{MESSENGERV3LOCATION}) {
			my @conf = slurp($config{MESSENGERV3LOCATION});
			if (grep {$_ =~ m[^Include /var/lib/csf/csf.conf]i} @conf) {
				sysopen (my $FILE, $config{MESSENGERV3LOCATION}, O_WRONLY | O_CREAT | O_TRUNC);
				flock ($FILE, LOCK_EX);
				foreach my $line (@conf) {
			        $line =~ s/$cleanreg//g;
					if ($line =~ m[^Include /var/lib/csf/csf.conf]i) {next}
					print $FILE $line."\n";
				}
				close ($FILE);
				system($config{MESSENGERV3RESTART});
				logfile("*MESSENGERV3* Removed from $config{MESSENGERV3LOCATION}");
			}
		}
	}
	
	return;
}
# end messengerstop
###############################################################################
# start messenger
sub messenger {
	my $port = shift;
	my $user = shift;
	my $type = shift;
	my $timer = time;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	$messengerips{$type} = $childpid;
	unless ($childpid) {
		if ($config{DEBUG} >= 3) {$timer = &timer("start","messenger",$timer)}
		$0 = "lfd - messenger csf...";
		$SIG{INT} = \&childcleanup;
		$SIG{TERM} = \&childcleanup;
		$SIG{HUP} = \&childcleanup;
		$SIG{__DIE__} = sub {&childcleanup(@_);};
		$childproc = "Messenger ($type)";

		my ($status,$reason) = $messenger1->start($port,$user,$type);
		if ($status) {
			logfile("*MESSENGER*: Error starting $type service: $reason");
			sysopen (my $TEMPCONF, "/var/lib/csf/csf.tempconf", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot append out file: $!");
			flock ($TEMPCONF, LOCK_EX);
			print $TEMPCONF "MESSENGER_${type}_IN = \"\"\n";
			close ($TEMPCONF);
			logfile("*MESSENGER*: $type service temporarily *DISABLED*");
		}
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","messenger",$timer)}
		exit;
	}
	return;
}
# end messenger
###############################################################################
# start messengerv2
sub messengerv2 {
	my $timer = time;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		if ($config{DEBUG} >= 3) {$timer = &timer("start","messengerv2",$timer)}
		$0 = "lfd - messenger csf...";

		my ($status,$reason) = $messenger2->start();
		if ($status) {
			logfile("*MESSENGERV2* Error: $reason");
		}
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","messengerv2",$timer)}
		exit;
	}
	return;
}
# end messengerv2
###############################################################################
# start messengerv3
sub messengerv3 {
	my $timer = time;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		if ($config{DEBUG} >= 3) {$timer = &timer("start","messengerv3",$timer)}
		$0 = "lfd - messenger csf...";

		my ($status,$reason) = $messenger3->start();
		if ($status) {
			logfile("*MESSENGERV3* Error: $reason");
		}
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","messengerv3",$timer)}
		exit;
	}
	return;
}
# end messengerv3
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
	} else {
		if ($httpsports ne "") {
			if ($iptype == 4) {
				&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -t nat $del PREROUTING $ethdevin -p tcp -s $ip -m multiport --dports $httpsports -j REDIRECT --to-ports $config{MESSENGER_HTTPS}");
			}
			if ($iptype == 6 and $config{MESSENGER6}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -t nat $del PREROUTING $ethdevin -p tcp -s $ip -m multiport --dports $httpsports -j REDIRECT --to-ports $config{MESSENGER_HTTPS}");
			}
		}
		if ($htmlports ne "") {
			if ($iptype == 4) {
				&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -t nat $del PREROUTING $ethdevin -p tcp -s $ip -m multiport --dports $htmlports -j REDIRECT --to-ports $config{MESSENGER_HTML}");
			}
			if ($iptype == 6 and $config{MESSENGER6}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -t nat $del PREROUTING $ethdevin -p tcp -s $ip -m multiport --dports $htmlports -j REDIRECT --to-ports $config{MESSENGER_HTML}");
			}
		}
		if ($textports ne "") {
			if ($iptype == 4) {
				&iptablescmd(__LINE__,"$config{IPTABLES} $config{IPTABLESWAIT} -t nat $del PREROUTING $ethdevin -p tcp -s $ip -m multiport --dports $textports -j REDIRECT --to-ports $config{MESSENGER_TEXT}");
			}
			if ($iptype == 6 and $config{MESSENGER6}) {
				&iptablescmd(__LINE__,"$config{IP6TABLES} $config{IPTABLESWAIT} -t nat $del PREROUTING $ethdevin -p tcp -s $ip -m multiport --dports $textports -j REDIRECT --to-ports $config{MESSENGER_TEXT}");
			}
		}
	}
	return;
}
# end domessenger
###############################################################################
# start ui
sub ui {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	$uiip = $childpid;
	unless ($childpid) {
		$0 = "lfd UI";
		$SIG{INT} = \&childcleanup;
		$SIG{TERM} = \&childcleanup;
		$SIG{HUP} = \&childcleanup;
		$SIG{__DIE__} = sub {&childcleanup(@_);};
		$childproc = "UI";

		my @alert = slurp("/usr/local/csf/tpl/uialert.txt");
		my $server;
		if ($config{IPV6}) {
			$server = IO::Socket::SSL->new(
						Domain => AF_INET6,
						LocalAddr => $config{UI_IP},
						LocalPort => $config{UI_PORT},
						Type => SOCK_STREAM,
						ReuseAddr => 1,
						Listen => $config{UI_CHILDREN},
						SSL_server => 1,
						SSL_use_cert => 1,
						SSL_cipher_list => $config{UI_CIPHER},
						SSL_honor_cipher_order => 1,
						SSL_version => $config{UI_SSL_VERSION},
						SSL_key_file => '/etc/csf/ui/server.key',
						SSL_cert_file => '/etc/csf/ui/server.crt',
			) or &childcleanup(__LINE__,"UI: *Error* cannot open server on port $config{UI_PORT}: ".IO::Socket::SSL->errstr);
		} else {
			$server = IO::Socket::SSL->new(
						Domain => AF_INET,
						LocalAddr => $config{UI_IP},
						LocalPort => $config{UI_PORT},
						Type => SOCK_STREAM,
						ReuseAddr => 1,
						Listen => $config{UI_CHILDREN},
						SSL_server => 1,
						SSL_use_cert => 1,
						SSL_cipher_list => $config{UI_CIPHER},
						SSL_honor_cipher_order => 1,
						SSL_version => $config{UI_SSL_VERSION},
						SSL_key_file => '/etc/csf/ui/server.key',
						SSL_cert_file => '/etc/csf/ui/server.crt',
			) or &childcleanup(__LINE__,"UI: *Error* cannot open server on port $config{UI_PORT}: ".IO::Socket::SSL->errstr);
		}

		my $looperrors;
		while (1) {
			my $client = $server->accept();
			unless ($client) {
				$looperrors++;
				if ($looperrors > 1000) {
					logfile("UI: *Error* looping process");
					last;
				}
				if ($config{DEBUG} >= 1) {logfile("UI debug: [loop:$looperrors] [$@]")}
				next;
			}
			$SIG{CHLD} = 'IGNORE';
			my $pid = fork;
			if ($pid == 0) {
				eval {
					local $SIG{__DIE__} = undef;
					local $SIG{'ALRM'} = sub {die "Connection timeout!\n"};
					alarm(10);
					close $server;

					our %FORM;
					our $myv;
					our $script;
					our $images;
					our $fileinc;

					my $input;
					my $session;
					my $file;
					my $cookie;
					my %header;
					my %fails;
					my $application = "csf";
					my $buffer;
					my $clientcnt;
					my $request;
					my @chars = ('0'..'9','a'..'z','A'..'Z');
					my $valid = "login";
					my $maxheader = 64;
					my $maxbody = 64 * 1024 * 1024;
					my $maxline = 1024 * 1024;
					my $peeraddress = $client->peerhost;

					if ($peeraddress =~ /^::ffff:(\d+\.\d+\.\d+\.\d+)$/) {$peeraddress = $1}
					if ($peeraddress eq "") {
						close ($client);
						alarm(0);
						exit;
					}
					$ENV{REMOTE_ADDR} = $peeraddress; ##no critic

					if ($ips{$peeraddress}) {
						logfile("UI: Login attempt from local IP address denied [$peeraddress]");
						if ($config{UI_ALERT} >= 4) {
							my @message;
							my $tip = iplookup($peeraddress);
							foreach my $line (@alert) {
								$line =~ s/\[ip\]/$tip/ig;
								$line =~ s/\[alert\]/Login attempt from local IP/ig;
								$line =~ s/\[text\]/Login attempt from local IP address $tip - denied/ig;
								push @message, $line;
							}
							ConfigServer::Sendmail::relay("", "", @message);
						}
						close ($client);
						alarm(0);
						exit;
					}

					if ($config{"UI_BAN"}) {
						open (my $UIBAN,"<","/etc/csf/ui/ui.ban");
						flock ($UIBAN, LOCK_SH);
						my @records = <$UIBAN>;
						chomp @records;
						close ($UIBAN);
						foreach my $record (@records) {
							if ($record =~ /^(\#|\s|\r|\n)/) {next}
							my ($rip,undef) = split(/\s/,$record);
							if ($rip eq $peeraddress) {
								logfile("UI: Access attempt from a banned IP address in /etc/csf/ui/ui.ban - denied [$peeraddress]");
								if ($config{UI_ALERT} >= 4) {
									my @message;
									my $tip = iplookup($peeraddress);
									foreach my $line (@alert) {
										$line =~ s/\[ip\]/$tip/ig;
										$line =~ s/\[alert\]/Access attempt from banned IP/ig;
										$line =~ s/\[text\]/Access attempt from a banned IP $tip in \/etc\/csf\/ui\/ui\.ban - denied/ig;
										push @message, $line;
									}
									ConfigServer::Sendmail::relay("", "", @message);
								}
								close ($client);
								alarm(0);
								exit;
							}
						}
					}

					if ($config{"UI_ALLOW"}) {
						my $allow = 0;
						sysopen (my $UIALLOW,"/etc/csf/ui/ui.allow", O_RDWR | O_CREAT);
						flock ($UIALLOW, LOCK_SH);
						my @records = <$UIALLOW>;
						chomp @records;
						close ($UIALLOW);
						foreach my $record (@records) {
							if ($record =~ /^(\#|\s|\r|\n)/) {next}
							my ($rip,undef) = split(/\s/,$record);
							if ($rip eq $peeraddress) {
								$allow = 1;
								last;
							}
							my (undef,$cidr) = split(/\//,$rip);
							if ($cidr) {
								my $uicidr = Net::CIDR::Lite->new;
								eval {local $SIG{__DIE__} = undef; $uicidr->add($rip)};
								if ($uicidr->find($peeraddress)) {
									$allow = 1;
									last;
								}
							}
						}
						unless ($allow) {
							logfile("UI: Access attempt from an IP not in /etc/csf/ui/ui.allow - denied [$peeraddress]");
							if ($config{UI_ALERT} >= 4) {
								my @message;
								my $tip = iplookup($peeraddress);
								foreach my $line (@alert) {
									$line =~ s/\[ip\]/$tip/ig;
									$line =~ s/\[alert\]/Login attempt/ig;
									$line =~ s/\[text\]/Access attempt from an IP $tip not in \/etc\/csf\/ui\/ui\.allow - denied/ig;
									push @message, $line;
								}
								ConfigServer::Sendmail::relay("", "", @message);
							}
							close ($client);
							alarm(0);
							exit;
						}
					}

					select $client; ##no critic
					$| = 1;

					$clientcnt = 0;
					while ($request !~ /\n$/) {
						my $char;
						$client->read($char,1);
						$request .= $char;
						$clientcnt++;
						if ($char eq "") {
							if ($config{DEBUG} >= 2) {logfile("UI debug: Child [request] finished")}
							close ($client);
							alarm(0);
							exit;
						}
						if ($clientcnt > $maxline) {
							&ui_413;
							close ($client);
							alarm(0);
							exit;
						}
					}
					$request =~ s/\r\n$//;
					if ($request =~ /^(GET|POST)\s(\S+)\sHTTP/) {
						($file,undef) = split(/\?/,$2);
						if ($file =~ /^\/(\w+)(\/.*)/) {
							$session = $1;
							$file = $2;
						}
					} else {
						close ($client);
						alarm(0);
						exit;
					}
					my $linecnt;
					while (1) {
						my $line;
						$clientcnt = 0;
						while ($line !~ /\n$/) {
							my $char;
							$client->read($char,1);
							$line .= $char;
							$clientcnt++;
							if ($char eq "") {
								if ($config{DEBUG} >= 2) {logfile("UI debug: Child [header] finished")}
								close ($client);
								alarm(0);
								exit;
							}
							if ($clientcnt > $maxline) {
								&ui_413;
								close ($client);
								alarm(0);
								exit;
							}
						}
						if ($line =~ /^\r\n$/) {last}
						$line =~ s/\r\n$//;
						my ($field,$value) = split(/\:\s/,$line);
						$header{$field} = $value;
						if ($config{DEBUG} >= 2) {logfile("UI debug: header [$field] [$value]")}
						$linecnt++;
						if ($linecnt > $maxheader) {
							&ui_413;
							close ($client);
							alarm(0);
							exit;
						}
					}
					if ($header{'Content-Length'} > 0) {
						if ($header{'Content-Length'} > $maxbody) {
							&ui_413;
							close ($client);
							alarm(0);
							exit;
						} else {
							if ($header{'Content-Type'} =~ /multipart\/form-data/) {
								$client->read($fileinc,$header{'Content-Length'});
							} else {
								$client->read($buffer,$header{'Content-Length'});
							}
						}
					}
					if ($request =~ /^GET\s(\S+)\sHTTP/) {if ($1 =~ /\?([^\?]*)$/) {$buffer = $1}}
					if ($config{DEBUG} >= 2) {logfile("UI debug: request [$request] buffer [$buffer]")}
					my @pairs = split(/&/,$buffer);
					foreach my $pair (@pairs) {
						my ($name, $value) = split(/=/, $pair);
						$value =~ tr/+/ /;
						$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
						$FORM{$name} = $value;
					}
					if ($header{Cookie} =~ /csfsession=(\w+)/) {$cookie = $1}

					if (($session ne "" and $cookie ne "") or defined $FORM{csflogin}) {
						sysopen (my $SESSION,"/var/lib/csf/ui/ui.session", O_RDWR | O_CREAT) or &childcleanup(__LINE__,"UI: unable to open csf.session: $!");
						flock ($SESSION, LOCK_EX);
						my @records = <$SESSION>;
						chomp @records;
						seek ($SESSION, 0, 0);
						truncate ($SESSION, 0);

						my $md5current = Digest::MD5->new;
						$md5current->add($header{'User-Agent'});
						my $md5sum = $md5current->b64digest;
						foreach my $record (@records) {
							my ($rtype,$rstart,$rtime,$rsession,$rcookie,$rip,$rhead,$rapp) = split(/\|/,$record,8);
							if ($rtype eq "login" and $rip eq $peeraddress and $rsession eq $session) {
								if ((time - $rtime) > $config{UI_TIMEOUT}) {
									$valid = "login";
									$record = "";
									($rstart,$rtime,$rsession,$rcookie,$rip,$rhead) = "";
									logfile("UI: *Invalid session* $peeraddress [timeout]");
								}
								elsif ($rcookie eq $cookie) {
									if ($rhead eq $md5sum) {
										if ($FORM{csfaction} eq "csflogout") {
											$valid = "login";
											$record = "";
											logfile("UI: Successful logout from $peeraddress");
										} else {
											$valid = "session";
											$application = $rapp;
											$rtime = time;
											$record = "$rtype|$rstart|$rtime|$rsession|$rcookie|$rip|$rhead|$rapp";
										}
									} else {
										$valid = "fail";
										$record = "";
										logfile("UI: *Invalid session* $peeraddress [session-header]");
									}
								} else {
									$valid = "fail";
									$record = "";
									logfile("UI: *Invalid session* $peeraddress [session-cookie]");
								}
							} else {
								if ($rtype eq "login") {
									if ((time - $rtime) > $config{UI_TIMEOUT}) {
										$record = "";
										($rstart,$rtime,$rsession,$rcookie,$rip,$rhead) = "";
									}
								}
								elsif ($rtype eq "fail") {
									if ((time - $rstart) > 86400) {
										$record = "";
									} else {
										$fails{$rip}++;
									}
								}
							}
							if ($record ne "") {print $SESSION "$record\n"}
						}
						close ($SESSION);
					} else {
						$valid = "login";
					}
					if (defined $FORM{csflogin} and $valid ne "fail") {
						if ($FORM{csflogin} eq $config{UI_USER} and $FORM{csfpassword} eq $config{UI_PASS}) {
							$valid = "yes";
						} else {
							$valid = "fail";
						}
					}

					if ($valid eq "fail") {
						$fails{$peeraddress}++;
						if ($fails{$peeraddress} > $config{UI_RETRY}) {
							if ($config{UI_BAN}) {
								sysopen (my $SESSIONBAN,"/etc/csf/ui/ui.ban", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"UI: unable to open csf.session: $!");
								flock ($SESSIONBAN, LOCK_EX);
								print $SESSIONBAN "$peeraddress - Banned for too many login failures ".localtime()."\n";
								close ($SESSIONBAN);
								logfile("UI: *Invalid login* attempts from $peeraddress [$fails{$peeraddress}/$config{UI_RETRY}] - Banned in /etc/csf/ui/ui.ban");
							} else {
								logfile("UI: *Invalid login* attempts from $peeraddress [$fails{$peeraddress}/$config{UI_RETRY}] - Not Banned");
							}
							sysopen (my $SESSION,"/var/lib/csf/ui/ui.session", O_RDWR | O_CREAT) or &childcleanup(__LINE__,"UI: unable to open csf.session: $!");
							flock ($SESSION, LOCK_EX);
							my @records = <$SESSION>;
							chomp @records;
							seek ($SESSION, 0, 0);
							truncate ($SESSION, 0);
							foreach my $record (@records) {
								my ($rtype,$rstart,$rtime,$rsession,$rcookie,$rip,$rhead,$rapp) = split(/\|/,$record,8);
								if ($rip eq $peeraddress) {next}
								print $SESSION "$record\n"
							}
							close ($SESSION);
							if ($config{UI_BLOCK}) {
								my $perm = 0;
								if ($config{UI_BLOCK} == 1) {$perm = 1}
								my $tip = iplookup($peeraddress);
								&ipblock("1","UI: Invalid login attempts from $tip",$peeraddress,"","in",$config{UI_BLOCK},0,"UI: *Invalid login* attempts from $peeraddress [$fails{$peeraddress}/$config{UI_RETRY}] - Banned","UI_RETRY");
							}
							if ($config{UI_ALERT} >= 1) {
								my @message;
								my $tip = iplookup($peeraddress);
								my $text;
								if ($config{UI_BAN}) {$text .= "Banned in ui.ban"}
								if ($config{UI_BLOCK}) {
									if ($text ne "") {$text .= ", "}
									$text .= "Blocked in csf";
								}
								foreach my $line (@alert) {
									$line =~ s/\[ip\]/$tip/ig;
									$line =~ s/\[alert\]/Login failure \[$fails{$peeraddress}\/$config{UI_RETRY}]/ig;
									$line =~ s/\[text\]/Login failure from IP address $tip \[$fails{$peeraddress}\/$config{UI_RETRY}] - $text/ig;
									push @message, $line;
								}
								ConfigServer::Sendmail::relay("", "", @message);
							}
							&ui_403;
							close ($client);
							alarm(0);
							exit;
						} else {
							my $time = time;
							sysopen (my $SESSION,"/var/lib/csf/ui/ui.session", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"UI: unable to open csf.session: $!");
							flock ($SESSION, LOCK_EX);
							print $SESSION "fail|$time||||$peeraddress||\n";
							close ($SESSION);
							$valid = "login";
							logfile("UI: *Invalid login* attempt from $peeraddress [$fails{$peeraddress}/$config{UI_RETRY}]");
							if ($config{UI_ALERT} >= 2) {
								my @message;
								my $tip = iplookup($peeraddress);
								foreach my $line (@alert) {
									$line =~ s/\[ip\]/$tip/ig;
									$line =~ s/\[alert\]/Login failure \[$fails{$peeraddress}\/$config{UI_RETRY}]/ig;
									$line =~ s/\[text\]/Login failure from IP address $tip \[$fails{$peeraddress}\/$config{UI_RETRY}] - denied/ig;
									push @message, $line;
								}
								ConfigServer::Sendmail::relay("", "", @message);
							}
						}
					}
					if ($valid eq "yes") {
						srand;
						$session = join '', map {$chars[rand(@chars)]} (1..(15 + int(rand(15))));
						$cookie = join '', map {$chars[rand(@chars)]} (1..(15 + int(rand(15))));

						my $md5current = Digest::MD5->new;
						$md5current->add($header{'User-Agent'});
						my $md5sum = $md5current->b64digest;
						my $time = time;
						sysopen (my $SESSION,"/var/lib/csf/ui/ui.session", O_RDWR | O_CREAT) or &childcleanup(__LINE__,"UI: unable to open csf.session: $!");
						flock ($SESSION, LOCK_EX);
						my @records = <$SESSION>;
						chomp @records;
						seek ($SESSION, 0, 0);
						truncate ($SESSION, 0);
						foreach my $record (@records) {
							my ($rtype,$rstart,$rtime,$rsession,$rcookie,$rip,$rhead) = split(/\|/,$record,8);
							if ($rtype eq "fail" and $rip eq $peeraddress) {next}
							print $SESSION "$record\n"
						}
						print $SESSION "login|$time|$time|$session|$cookie|$peeraddress|$md5sum|$application\n";
						close ($SESSION);

						print "HTTP/1.0 301 Moved Permanently\r\n";
						print "Location: /$session/\r\n";
						print "Set-Cookie: csfsession=$cookie; secure\r\n";
						print "\r\n";

						logfile("UI: Successful login from $peeraddress");
						if ($config{UI_ALERT} >= 3) {
							my @message;
							my $tip = iplookup($peeraddress);
							foreach my $line (@alert) {
								$line =~ s/\[ip\]/$tip/ig;
								$line =~ s/\[alert\]/Login success/ig;
								$line =~ s/\[text\]/Login success from IP address $tip/ig;
								push @message, $line;
							}
							ConfigServer::Sendmail::relay("", "", @message);
						}
					}
					if ($valid eq "login") {
						print "HTTP/1.0 200 OK\r\n";
						print "Content-type: text/html\r\n";
						print "\r\n";
						print "<!DOCTYPE html>\n";
						print "<HTML>\n<TITLE>ConfigServer Security & Firewall</TITLE>\n<BODY style='font-family:Arial, Helvetica, sans-serif;' onload='document.getElementById(\"user\").focus()'>\n";
						if ($valid eq "failed") {print "<div align='center'><h2>Login Failed</h2></div>\n"}
						print "<form action='/' method='post'><div align='center'>\n";
						print "<table align='center' border='0' cellspacing='0' cellpadding='4' bgcolor='#FFFFFF' style='border:1px solid #990000'>\n";
						print "<tr bgcolor='#F4F4EA'><td>Username:</td><td><input id='user' name='csflogin' type='text' size='15'></td></tr>\n";
						print "<tr bgcolor='#F4F4EA'><td>Password:</td><td><input name='csfpassword' type='password' size='15'></td></tr>\n";
						print "<tr bgcolor='#FFFFFF'><td colspan='2' align='center'><input type='submit' value='Enter'></td></tr>\n";
						print "<", "/table></div></form>\n";
						print "\n</BODY>\n</HTML>\n";
					}
					if ($valid eq "session") {
						if (defined $FORM{csfapp} and ($FORM{csfapp} ne $application)) {
							my $newapp = $application;
							if ($FORM{csfapp} eq "csf") {$newapp = "csf"}
							elsif ($FORM{csfapp} eq "cxs" and $config{UI_CXS}) {$newapp = "cxs"}
							elsif ($FORM{csfapp} eq "cse" and $config{UI_CSE}) {$newapp = "cse"}
							if ($newapp ne $application) {
								sysopen (my $SESSION,"/var/lib/csf/ui/ui.session", O_RDWR | O_CREAT) or &childcleanup(__LINE__,"UI: unable to open csf.session: $!");
								flock ($SESSION, LOCK_EX);
								my @records = <$SESSION>;
								chomp @records;
								seek ($SESSION, 0, 0);
								truncate ($SESSION, 0);
								foreach my $record (@records) {
									my ($rtype,$rstart,$rtime,$rsession,$rcookie,$rip,$rhead,$rapp) = split(/\|/,$record,8);
									if ($rip eq $peeraddress and $rsession eq $session) {
										$record = "$rtype|$rstart|$rtime|$rsession|$rcookie|$rip|$rhead|$newapp";
										$application = $newapp;
									}
									print $SESSION "$record\n"
								}
								close ($SESSION);
							}
						}
						if ($file eq "/") {
							print "HTTP/1.0 200 OK\r\n";
							if ($application eq "csf") {
								open (my $IN, "<", "/etc/csf/version.txt") or die $!;
								flock ($IN, LOCK_SH);
								$myv = <$IN>;
								close ($IN);
								chomp $myv;
								$script = "/$session/";
								$images = "/$session/images";
								$config{THIS_UI} = 1;
								my $bootstrapcss = "<link rel='stylesheet' href='$images/bootstrap/css/bootstrap.min.css'>";
								my $jqueryjs = "<script src='$images/jquery.min.js'></script>";
								my $bootstrapjs = "<script src='$images/bootstrap/js/bootstrap.min.js'></script>";
								my @header;
								my @footer;
								my $htmltag = "data-post='$FORM{action}'";
								if (-e "/etc/csf/csf.header") {
									open (my $HEADER, "<", "/etc/csf/csf.header");
									flock ($HEADER, LOCK_SH);
									@header = <$HEADER>;
									close ($HEADER);
								}
								if (-e "/etc/csf/csf.footer") {
									open (my $FOOTER, "<", "/etc/csf/csf.footer");
									flock ($FOOTER, LOCK_SH);
									@footer = <$FOOTER>;
									close ($FOOTER);
								}
								unless ($config{STYLE_CUSTOM}) {
									undef @header;
									undef @footer;
									$htmltag = "";
								}

								print "Content-type: text/html\r\n";
								print "\r\n";
								unless ($FORM{action} eq "tailcmd" or $FORM{action} =~ /^cf/ or $FORM{action} eq "logtailcmd" or $FORM{action} eq "loggrepcmd") {
									print <<EOF;
<!doctype html>
<html lang='en' $htmltag>
<head>
<title>ConfigServer Security &amp; Firewall</title>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1'>
$bootstrapcss
<link href='$images/configserver.css' rel='stylesheet' type='text/css'>
$jqueryjs
$bootstrapjs

<style>
.mobilecontainer {
display:none;
}
.normalcontainer {
display:block;
}
EOF
									if ($config{STYLE_MOBILE}) {
	print <<EOF;
\@media (max-width: 480px) {
.mobilecontainer {
	display:block;
}
.normalcontainer {
	display:none;
}
}
EOF
									}
									print "</style>\n";
									print @header;
									print <<EOF;
</head>
<body>
<div id="loader"></div>
<a id='toplink' class='toplink' title='Go to bottom'><span class='glyphicon glyphicon-hand-down'></span></a>
<div class='container-fluid'>
EOF
								}
								unless ($FORM{action} eq "tailcmd" or $FORM{action} =~ /^cf/ or $FORM{action} eq "logtailcmd" or $FORM{action} eq "loggrepcmd") {
									print "<div class='pull-right' style='margin:8px'>\n";
									if ($config{UI_CXS} or $config{UI_CSE}) {
										print "<form action='$script' method='post'><select name='csfapp'><option>csf</option>";
										if ($config{UI_CXS}) {print "<option>cxs</option>"}
										if ($config{UI_CSE}) {print "<option>cse</option>"}
										print "<", "/select> <input class='btn btn-default' type='submit' value='Switch'></form>\n";
									}
									print " <a class='btn btn-default' href='/$session/?csfaction=csflogout'>csf Logout</a>\n";
									print "</div>\n";
									print <<EOF;
<div class='panel panel-default panel-body'>
<img align='absmiddle' src='$images/csf_small.png' alt='ConfigServer Firewall &amp; Security' style='float:left'>
<h3>ConfigServer Security &amp; Firewall - csf v$myv</h3>
</div>
EOF
								}
								ConfigServer::DisplayUI::main(\%FORM, $script, 0, $images, $myv, $config{THIS_UI});
								unless ($FORM{action} eq "tailcmd" or $FORM{action} =~ /^cf/ or $FORM{action} eq "logtailcmd" or $FORM{action} eq "loggrepcmd") {
									print <<EOF;
<a class='botlink' id='botlink' title='Go to top'><span class='glyphicon glyphicon-hand-up'></span></a>
<script>
function getCookie(cname) {
	var name = cname + "=";
	var ca = document.cookie.split(';');
	for(var i = 0; i <ca.length; i++) {
		var c = ca[i];
		while (c.charAt(0)==' ') {
			c = c.substring(1);
		}
		if (c.indexOf(name) == 0) {
			return c.substring(name.length,c.length);
		}
	}
	return "";
} 
\$("#loader").hide();
\$.fn.scrollBottom = function() { 
  return \$(document).height() - this.scrollTop() - this.height(); 
};
\$('#botlink').on("click",function(){
	\$('html,body').animate({ scrollTop: 0 }, 'slow', function () {});
});
\$('#toplink').on("click",function() {
	var window_height = \$(window).height();
	var document_height = \$(document).height();
	\$('html,body').animate({ scrollTop: window_height + document_height }, 'slow', function () {});
});
\$(document).ready(function(){
	\$('[data-tooltip="tooltip"]').tooltip();
	\$(window).scroll(function () {
		if (\$(this).scrollTop() > 500) {
			\$('#botlink').fadeIn();
		} else {
			\$('#botlink').fadeOut();
		}
		if (\$(this).scrollBottom() > 500) {
			\$('#toplink').fadeIn();
		} else {
			\$('#toplink').fadeOut();
		}
	});
EOF
									if ($config{STYLE_MOBILE}) {
									print <<EOF;
	var csfview = getCookie('csfview');
	if (csfview == 'mobile') {
		\$(".mobilecontainer").css('display','block');
		\$(".normalcontainer").css('display','none');
		\$("#csfreturn").addClass('btn-primary btn-lg btn-block').removeClass('btn-default');
	} else if (csfview == 'desktop') {
		\$(".mobilecontainer").css('display','none');
		\$(".normalcontainer").css('display','block');
		\$("#csfreturn").removeClass('btn-primary btn-lg btn-block').addClass('btn-default');
	}
EOF
}
									print "});\n";
									if ($config{STYLE_MOBILE}) {
										print <<EOF;
\$("#NormalView").click(function(){
	document.cookie = "csfview=desktop; path=/";
	\$(".mobilecontainer").css('display','none');
	\$(".normalcontainer").css('display','block');
});
\$("#MobileView").click(function(){
	document.cookie = "csfview=mobile; path=/";
	\$(".mobilecontainer").css('display','block');
	\$(".normalcontainer").css('display','none');
});
EOF
}
									print "</script>\n";
									print @footer;
									print "</body>\n";
									print "</html>\n";
								}
							}
							elsif ($application eq "cxs" and $config{UI_CXS}) {
								my @data = &syscommand(__LINE__,"/usr/sbin/cxs","--version");
								chomp @data;
								if ($data[0] =~ /v(.*)$/) {$myv = $1}
								my %ajaxsubs = (
									"cc_body" => 1,
									"cc_dbody" => 1,
									"cc_restore" => 1,
									"cc_report" => 1,
									"cc_showreports" => 1,
									"cc_ignore" => 1,
									"cc_blockip" => 1,
									"cc_delete" => 1,
									"cc_edelete" => 1,
									"tailcmd" => 1,
									"tailscancmd" => 1,
								);
								my %fullsubs = (
									"cc_setup" => 1,
									"cc_setup1" => 1,
									"cc_setup2" => 1,
									"cc_setup3" => 1,
									"cc_setup4" => 1,
									"cc_setup5" => 1,
									"cc_setup6" => 1,
									"cc_delreport" => 1,
									"cc_reports" => 1,
									"cc_stats" => 1,
									"cc_file" => 1,
								);

								$script = "/$session/";
								$images = "/$session/images/cxs";
								$config{THIS_UI} = 1;
								my $bootstrapcss = "<link rel='stylesheet' href='$images/bootstrap/css/bootstrap.min.css'>";
								my $jqueryjs = "<script src='$images/jquery.min.js'></script>";
								my $bootstrapjs = "<script src='$images/bootstrap/js/bootstrap.min.js'></script>";
								my $fontawesome = "<link rel='stylesheet' href='https://use.fontawesome.com/releases/v5.0.10/css/all.css'>";
								if ($FORM{action} eq "cc_body" or $FORM{action} eq "cc_dbody" or $FORM{action} eq "cc_showreports") {
								} elsif ($ajaxsubs{$FORM{action}} or $FORM{action} eq "tailcmd" or $FORM{action} eq "tailscancmd") {
									print "content-type: text/plain\n\n";
								} else {
									print "Content-type: text/html\n\n";
									unless ($FORM{action} eq "RunScan" or ($FORM{action} =~ /^cc_/ and !$fullsubs{$FORM{action}} and $FORM{action} !~ /^cc_\w+bulk$/) or $FORM{action} eq "Run Scan" or $FORM{action} eq "viewq" or $FORM{action} eq "tailcmd" or $FORM{action} eq "tailscancmd") {
										print <<EOF;
<!doctype html>
<html lang='en'>
<head>
<title>ConfigServer eXploit Scanner</title>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1'>
$bootstrapcss
$fontawesome
<link href='$images/configserver.css' rel='stylesheet' type='text/css'>
$jqueryjs
$bootstrapjs
<link href='https://fonts.googleapis.com/css?family=Raleway:400,700' rel='stylesheet' type='text/css'>
</head>
<body>
<div id="loader"></div>
<a id='toplink' class='toplink' title='Go to bottom'><span class='glyphicon glyphicon-hand-down'></span></a>
<div class='container-fluid'>
EOF
										print "<div class='pull-right' style='margin:8px'>\n";
										if ($config{UI_CXS} or $config{UI_CSE}) {
											print "<form action='$script' method='post'><select name='csfapp'><option>csf</option>";
											if ($config{UI_CXS}) {print "<option selected>cxs</option>"}
											if ($config{UI_CSE}) {print "<option>cse</option>"}
											print "<", "/select> <input class='btn btn-default' type='submit' value='Switch'></form>\n";
										}
										print " <a class='btn btn-default' href='/$session/?csfaction=csflogout'>cxs Logout</a>\n";
										print "</div>\n";
										print <<EOF;
<div class='panel panel-default panel-body'>
<img align='absmiddle' src='$images/cxs_small.png' alt='ConfigServer eXploit Scanner' style='float:left'>
<h3>ConfigServer eXploit Scanner - cxs v$myv</h3>
</div>
EOF
									} else {
										print <<EOF;
<!doctype html>
<html lang='en'>
<head>
	$bootstrapcss
	<link href='$images/configserver.css' rel='stylesheet' type='text/css'>
	$jqueryjs
	$bootstrapjs
</head>
<body>
<div class='container-fluid'>
<style>
pre {
	overflow: initial;
}
</style>
EOF
									}
								}
								ConfigServer::cxsUI::displayUI(\%FORM,\%ajaxsubs,$script,"",$images,$myv, "cpsess".$session);

								unless ($ajaxsubs{$FORM{action}}) {
									print <<EOF;
<script>
	\$("#loader").hide();
</script>
</body>
</html>
EOF
								}
							}
							elsif ($application eq "cse" and $config{UI_CSE}) {
								$script = "/$session/";
								$images = "/$session/images";
								$config{THIS_UI} = 1;
								ConfigServer::cseUI::main(\%FORM, $fileinc, $script, 0, $images, $myv, $config{THIS_UI});
							}
						}
						elsif ($file =~ /^\/images\/(\w+\/)?(\w+\/)?(\w+\/)?([\w\-]+\.(gif|png|jpg|[\w\-]+\.js|[\w\-]+\.css|css|[\w\-]+\.woff2|woff2|[\w\-]+\.woff|woff|[\w\-]+\.tff|tff))/i) {
							my $type = $2;
							if ($type eq "jpg") {$type = "jpeg"}
							print "HTTP/1.0 200 OK\r\n";
							if ($file =~ /^\/images\/((\w+\/)?(\w+\/)?(\w+\/)?[\w\-]+\.(gif|png|jpg))/i) {
								print "Content-type: image/$type\r\n";
							}
							elsif ($file =~ /^\/images\/((\w+\/)?(\w+\/)?(\w+\/)?[\w\-]+\.([\w\-]+\.css|css))/i) {
								print "Content-type: text/css\r\n";
							}
							elsif ($file =~ /^\/images\/((\w+\/)?(\w+\/)?(\w+\/)?[\w\-]+\.([\w\-]+\.js))/i) {
								print "Content-type: text/plain\r\n";
							}
							elsif ($file =~ /^\/images\/((\w+\/)?(\w+\/)?(\w+\/)?[\w\-]+\.([\w\-]+\.woff2|woff2))/i) {
								print "Content-type: application/font-woff2\r\n";
							}
							elsif ($file =~ /^\/images\/((\w+\/)?(\w+\/)?(\w+\/)?[\w\-]+\.([\w\-]+\.woff|woff))/i) {
								print "Content-type: application/font-woff\r\n";
							}
							elsif ($file =~ /^\/images\/((\w+\/)?(\w+\/)?(\w+\/)?[\w\-]+\.([\w\-]+\.tff|tff))/i) {
								print "Content-type: application/octet-stream\r\n";
							}
							print "\r\n";
							open (my $IMAGE, "<", "/etc/csf/ui/images/$1");
							flock ($IMAGE, LOCK_SH);
							while (<$IMAGE>) {print $_}
							close ($IMAGE);
						} else {
							&ui_403;
						}
					}
					alarm(0);
				};
				if ($@) {logfile("*UI* child: [$!] [$@]")}
				$client->close();
				alarm(0);
				exit;
			}
			$client->close(SSL_no_shutdown => 1);
		}
		exit;
	}
	return;
}
# end ui
###############################################################################
# ui_403
sub ui_403 {
	print "HTTP/1.0 403 Forbidden\r\n";
	print "Content-type: text/html\r\n";
	print "\r\n";
	print "<html>\n<head>\n<title>403 Forbidden</title>\n</head>\n<body>\n";
	print "<h1>403 Forbidden</h1>\n";
	print "You don't have permission to access this resource\n";
	print "<", "/body>\n</html>\n";
	return;
}
# end ui_403
###############################################################################
# ui_413
sub ui_413 {
	print "HTTP/1.0 413 Request Entity Too Large\r\n";
	print "Content-type: text/html\r\n";
	print "\r\n";
	print "<html>\n<head>\n<title>413 Request Entity Too Large</title>\n</head>\n<body>\n";
	print "<h1>413 Request Entity Too Large</h1>\n";
	print "The Request Data is too large for this server to handle";
	print "<", "/body>\n</html>\n";
	return;
}
# end ui_413
###############################################################################
# start lfdserver
sub lfdserver {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	$clusterip = $childpid;
	unless ($childpid) {
		$childproc = "Cluster";
		my $cipher = Crypt::CBC->new( -key => $config{CLUSTER_KEY}, -cipher => 'Blowfish_PP');
		my %cmembers;
		foreach my $cip (split(/\,/,$config{CLUSTER_RECVFROM})) {$cmembers{$cip} = 1}
		if ($config{CLUSTER_MASTER}) {$cmembers{$config{CLUSTER_MASTER}} = 1}

		$0 = "lfd Cluster Server";
		$SIG{INT} = \&childcleanup;
		$SIG{TERM} = \&childcleanup;
		$SIG{HUP} = \&childcleanup;
		$SIG{__DIE__} = sub {&childcleanup(@_);};

		my $server = IO::Socket::INET->new(
			LocalPort => $config{CLUSTER_PORT},
			Type => SOCK_STREAM,
			ReuseAddr => 1,
			Listen => $config{CLUSTER_CHILDREN},
		) or &childcleanup(__LINE__,"*Error* cannot open server on port $config{CLUSTER_PORT}: $!");

		while (1) {
			while (my ($client, $c_addr) = $server->accept()) {
				$SIG{CHLD} = 'IGNORE';
				my $pid = fork;
				if ($pid == 0) {
					eval {
						local $SIG{__DIE__} = undef;
						local $SIG{'ALRM'} = sub {die};
						alarm(10);
						close $server;

						my ($cport,$iaddr) = sockaddr_in($c_addr);
						my $peeraddress = inet_ntoa($iaddr);
						my $pip = iplookup($peeraddress);

						if ($cmembers{$peeraddress}) {
							binmode $client;
							$| = 1;
							my $line;
							my $grep;
							my $tip;
							while ($line !~ /END\n$/) {
								my $char;
								$client->read($char,1) or last;
								$line .= $char;
							}
							$line =~ s/END\n$//;

							my $decrypted = $cipher->decrypt($line);
							if ($config{DEBUG} >= 2) {logfile("debug: Cluster member $peeraddress said [$decrypted]")}
							my ($command,$ip,$perm,$ports,$inout,$timeout,$message) = split(/\s/,$decrypted,7);
							if ($perm eq "") {$perm = 1}
							if ($ports eq "*") {$ports = ""}
							if (checkip(\$ip)) {$tip = iplookup($ip)}
							if ($message eq "") {$message = "Not provided - $tip"}

							if ($command eq "D") {
								&ipblock($perm,"Cluster member $pip said, DENY $ip, Reason:[$message]",$ip,$ports,$inout,$timeout,1,"","LF_CLUSTER");
							}
							elsif ($command eq "TD") {
								&ipblock($perm,"Cluster member $pip said, TEMPDENY $ip, Reason:[$message]",$ip,$ports,$inout,$timeout,1,"","LF_CLUSTER");
							}
							elsif ($command eq "A" and checkip(\$ip)) {
								logfile("Cluster member $pip said, ALLOW $ip, [$message]");
								&syscommand(__LINE__,"/usr/sbin/csf","-a",$ip,"Cluster member $pip said, ALLOW $ip, Reason:[$message]");
							}
							elsif ($command eq "TA") {
								logfile("Cluster member $pip said, TEMPALLOW $ip, Reason:[$message]");
								&syscommand(__LINE__,"/usr/sbin/csf","-ta",$ip,$timeout,"-p",$ports,"-d",$inout,"Cluster member $pip said, TEMPALLOW $ip, Reason:[$message]");
							}
							elsif ($command eq "AR" and checkip(\$ip)) {
								logfile("Cluster member $pip said, REMOVE ALLOW $tip");
								&syscommand(__LINE__,"/usr/sbin/csf","-ar",$ip);
								&syscommand(__LINE__,"/usr/sbin/csf","-tr",$ip);
							}
							elsif ($command eq "R" and checkip(\$ip)) {
								logfile("Cluster member $pip said, REMOVE DENY $tip");
								&syscommand(__LINE__,"/usr/sbin/csf","-dr",$ip);
								&syscommand(__LINE__,"/usr/sbin/csf","-tr",$ip);
							}
							elsif ($command eq "I" and checkip(\$ip)) {
								my $ignorematches;
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
										$ignorematches = 1;
										last;
									}
								}
								sysopen (my $IGNORE, "/etc/csf/csf.ignore", O_RDWR | O_CREAT);
								flock ($IGNORE, LOCK_EX);
								my $text = join("", <$IGNORE>);
								@ignore = split(/$slurpreg/,$text);
								chomp @ignore;
								unless ($ignorematches) {
									print $IGNORE "$ip # Cluster member $pip said, IGNORE $ip, Reason:[$message] - ".localtime(time)."\n";
									logfile("Cluster member $pip said, IGNORE $ip, [$message]");
									logfile("Cluster - lfd restarting...");
									open (my $LFDOUT, ">", "/var/lib/csf/lfd.restart");
									close ($LFDOUT);
								} else {
									logfile("Cluster member $pip said, IGNORE $ip, [$message], however it is already being ignored");
								}
								close ($IGNORE);
							}
							elsif ($command eq "IR" and checkip(\$ip)) {
								my $hit;
								sysopen (my $IGNORE, "/etc/csf/csf.ignore", O_RDWR | O_CREAT);
								flock ($IGNORE, LOCK_EX);
								my $text = join("", <$IGNORE>);
								my @ignore = split(/$slurpreg/,$text);
								chomp @ignore;
								seek ($IGNORE, 0, 0);
								truncate ($IGNORE, 0);
								foreach my $line (@ignore) {
									$line =~ s/$cleanreg//g;
									my ($ipd,$commentd) = split (/\s/,$line,2);
									checkip(\$ipd);
									if ($ipd eq $ip) {
										$hit = 1;
										next;
									} else {
										print $IGNORE $line."\n";
									}
								}
								close ($IGNORE);
								if ($hit) {
									logfile("Cluster member $pip said, REMOVE IGNORE $tip");
									logfile("Cluster - lfd restarting...");
									open (my $LFDOUT, ">", "/var/lib/csf/lfd.restart");
									close ($LFDOUT);
								} else {
									logfile("Cluster member $pip said, REMOVE IGNORE $tip, however it is not in csf.ignore");
								}
							}
							elsif ($command eq "PING") {
								logfile("Cluster member $pip said PING!");
							}
							elsif ($command eq "G") {
								logfile("Cluster member $pip said GREP $tip");
								my @output = &syscommand(__LINE__,"/usr/sbin/csf","-g",$ip);
								$grep = join("",@output);
							}
							elsif ($command eq "C") {
								my (undef,$name,$value) = split(/\s/,$decrypted,3);
								if ($config{CLUSTER_MASTER} and ($config{CLUSTER_MASTER} eq $peeraddress)) {
									$value =~ s/\"|\=//g;
									$value =~ s/(^\s*)|(\s*$)//g;
									if ($config{CLUSTER_CONFIG}) {
										logfile("Cluster member $pip said set [$name = \"$value\"]");
										&updateconfig($name,$value);
									} else {
										logfile("Cluster member $pip said set [$name = \"$value\"], however CLUSTER_CONFIG disabled");
									}
								} else {
									logfile("*Cluster* member $pip said set [$name = \"$value\"], however it is not the CLUSTER_MASTER");
								}
							}
							elsif ($command eq "FILE") {
								my (undef,$filename) = split(/\s/,$decrypted);
								my ($file, $filedir) = fileparse($filename);
								if ($config{CLUSTER_MASTER} and ($config{CLUSTER_MASTER} eq $peeraddress)) {
									if ($config{CLUSTER_CONFIG}) {
										my (undef,$content) = split(/\n/,$decrypted,2);
										logfile("Cluster member $pip said store file [$file]");
										open (my $FH, ">", "/etc/csf/$file");
										flock ($FH, LOCK_EX);
										binmode ($FH);
										print $FH $content;
										close ($FH);
									} else {
										logfile("*Cluster* member $pip said store file [$file], however CLUSTER_CONFIG disabled");
									}
								} else {
									logfile("*Cluster* member $pip said store file [$file], however it is not the CLUSTER_MASTER");
								}
							}
							elsif ($command eq "RESTART") {
								if ($config{CLUSTER_MASTER} and ($config{CLUSTER_MASTER} eq $peeraddress)) {
									if ($config{CLUSTER_CONFIG}) {
										logfile("Cluster member $pip said restart csf and lfd");
										logfile("Cluster - csf restarting...");
										&syscommand(__LINE__,"/usr/sbin/csf","-sf");
										logfile("Cluster - lfd restarting...");
										open (my $LFDOUT, ">", "/var/lib/csf/lfd.restart");
										close ($LFDOUT);
									} else {
										logfile("*Cluster* member $pip said restart csf and lfd, however CLUSTER_CONFIG disabled");
									}
								} else {
									logfile("*Cluster* member $pip said restart csf and lfd, however it is not the CLUSTER_MASTER");
								}
							}
							else {
								logfile("*WARNING* Cluster member $pip talking nonsense");
							}

							if ($command eq "PING") {
								print $client "PONG!\n";
							}
							elsif ($command eq "G") {
								print $client "$grep\n";
							}
							else {
								print $client "Received\n";
							}
						} else {
							logfile("*WARNING* $pip attempted to connect to the Cluster but not a member!");
						}
						alarm(0);
					};
					alarm(0);
					shutdown ($client,2);
					$client->close();
					exit;
				}
				$client->close();
			}
		}
	}
	return;
}
# end lfdserver
###############################################################################
# start lfdclient
sub lfdclient {
	my $perm = shift;
	my $message = shift;
	my $ip = shift;
	my $port = shift;
	my $inout = shift;
	my $timeout = shift;
	if ($port eq "") {$port = "*"}

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","lfdclient",$timer)}
		$0 = "lfd - Cluster client";

		my $cipher = Crypt::CBC->new( -key => $config{CLUSTER_KEY}, -cipher => 'Blowfish_PP');
		my $text;
		if ($perm) {
			$text = "D $ip $perm $port $inout $timeout $message";
		} else {
			$text = "TD $ip $perm $port $inout $timeout $message";
		}
		my $encrypted = $cipher->encrypt($text)."END\n";

		foreach my $cip (split(/\,/,$config{CLUSTER_SENDTO})) {
			if ($ips{$cip} or $ipscidr->find($cip) or $ipscidr6->find($cip) or ($cip eq $config{CLUSTER_NAT})) {next}
			my $localaddr = "0.0.0.0";
			if ($config{CLUSTER_LOCALADDR}) {$localaddr = $config{CLUSTER_LOCALADDR}}
			my $tip = iplookup($cip);
			my $sock;
			eval {$sock = IO::Socket::INET->new(PeerAddr => $cip, PeerPort => $config{CLUSTER_PORT}, LocalAddr => $localaddr, Timeout => '10');};
			unless (defined $sock) {
				logfile("Cluster: Failed to connect to $tip");
			} else {
				my $status = send($sock,$encrypted,0);
				unless ($status) {
					logfile("Cluster: Failed for $tip - $status");
				} else {
					if ($perm) {
						logfile("Cluster: DENY $ip sent to $tip");
					} else {
						logfile("Cluster: TEMPDENY $ip sent to $tip");
					}
				}
				shutdown($sock,2);
			}
		}
		if ($config{DEBUG} >= 3) {$timer = &timer("stop","lfdclient",$timer)}
		$0 = "lfd - (child) closing";
		exit;
	}
	return;
}
# end lfdclient
###############################################################################
# start updateconfig
sub updateconfig {
	my $chname = shift;
	my $chvalue = shift;

	sysopen (my $OUT, "/etc/csf/csf.conf", O_RDWR | O_CREAT);
	flock ($OUT, LOCK_EX);
	my @confdata = <$OUT>;
	chomp @confdata;
	seek ($OUT, 0, 0);
	truncate ($OUT, 0);
	for (my $x = 0; $x < @confdata;$x++) {
		if (($confdata[$x] !~ /^\#/) and ($confdata[$x] =~ /=/)) {
			my ($name,$value) = split (/=/,$confdata[$x],2);
			$name =~ s/\s*//g;
			if ($name eq $chname) {
				print $OUT "$name = \"$chvalue\"\n";
			} else {
				print $OUT "$confdata[$x]\n";
			}
		} else {
			print $OUT "$confdata[$x]\n";
		}
	}
	close ($OUT);
	return;
}
# end updateconfig
###############################################################################
# start stats
sub stats {
	my $line = shift;
	my $type = shift;

	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","stats",$timer)}
		$0 = "lfd - (child) Statistics...";

		eval {
			local $SIG{__DIE__} = undef;
			local $SIG{'ALRM'} = sub {die};
			alarm(15);
			if ($type eq "iptables") {
				my ($in,$out,$src,$dst,$text);
				if ($line =~ /IN=(\S+)/) {$in = $1}
				if ($line =~ /OUT=(\S+)/) {$out = $1}
				if ($line =~ /SRC=(\S+)/) {$src = $1}
				if ($line =~ /DST=(\S+)/) {$dst = $1}

				if ($config{ST_LOOKUP}) {
					if ($in and $src) {$text = iplookup($src)}
					elsif ($out and $dst) {$text = iplookup($dst)}
				}

				sysopen (my $IPTABLES, "/var/lib/csf/stats/iptables_log", O_WRONLY | O_APPEND | O_CREAT);
				flock ($IPTABLES, LOCK_EX);
				print $IPTABLES "$text|$line\n";
				close ($IPTABLES);

				if ((stat("/var/lib/csf/stats/iptables_log"))[7] > (2048 * $config{ST_IPTABLES})) {
					my $lockstr = "ST_IPTABLES";
					sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
					unless (flock ($THISLOCK, LOCK_EX | LOCK_NB)) {
						if ($config{DEBUG} >= 1) {
							&childcleanup("debug: *Lock Error* [$lockstr] still active - section skipped");
						} else {
							&childcleanup;
						}
					}

					print $THISLOCK time;
					sysopen (my $IPTABLES, "/var/lib/csf/stats/iptables_log", O_RDWR | O_CREAT);
					flock ($IPTABLES, LOCK_EX);

					my @iptables = <$IPTABLES>;
					chomp @iptables;
					my @last = @iptables[-$config{ST_IPTABLES}..-1];

					seek ($IPTABLES, 0, 0);
					truncate ($IPTABLES, 0);

					foreach my $line (@last) {
						print $IPTABLES "$line\n"
					}
					close ($IPTABLES);
				}

				if ($config{DEBUG} >= 2) {logfile("debug: STATS added iptables [$src -> $dst] log line")}
			}
			alarm(0);
		};
		alarm(0);
		if ($@) {logfile("STATS: 15 sec. timeout performing iptables_log")}

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","stats",$timer)}
		$0 = "lfd - (child) closing";
		exit;
	}
	return;
}
# end stats
###############################################################################
# start systemstats
sub systemstats {
	$SIG{CHLD} = 'IGNORE';
	unless (defined ($childpid = fork)) {
		&cleanup(__LINE__,"*Error* cannot fork: $!");
	} 
	$forks{$childpid} = 1;
	unless ($childpid) {
		my $timer = time;
		if ($config{DEBUG} >= 3) {$timer = &timer("start","systemstats",$timer)}
		$0 = "lfd - (child) System Statistics...";

		my $lockstr = "ST_SYSTEM";
		sysopen (my $THISLOCK, "/var/lib/csf/lock/$lockstr.lock", O_RDWR | O_CREAT) or &childcleanup("*Error* Unable to open /var/lib/csf/lock/$lockstr.lock");
		flock ($THISLOCK, LOCK_EX | LOCK_NB) or &childcleanup("*Lock Error* [$lockstr] still active - section skipped");
		print $THISLOCK time;
		
		local $SIG{__DIE__} = undef;
		
		my $time = time;
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
		my $cputotal;
		my $cpuidle;
		my $cpuiowait;
		my $memtotal;
		my $memfree;
		my $memswaptotal;
		my $memswapfree;
		my $netin;
		my $netout;
		my $diskread;
		my $diskwrite;
		my $mailin;
		my $mailout;
		my $cputemp;
		my $mysqlin;
		my $mysqlout;
		my $mysqlq;
		my $mysqlsq;
		my $mysqlcn;
		my $mysqlth;
		my $apachecpu;
		my $apacheacc;
		my $apachebwork;
		my $apacheiwork;
		my $diskw;
		my $memcached;

		open (my $STAT, "<", "/proc/stat");
		flock ($STAT, LOCK_SH);
		my $line = <$STAT>;
		close ($STAT);
		chomp $line;
		my @cpu = split(/\s+/,$line);
		shift @cpu;
		foreach (@cpu) {$cputotal += $_}
		$cpuidle = $cpu[3];
		$cpuiowait = $cpu[4];

		open (my $MEMINFO, "<", "/proc/meminfo");
		flock ($MEMINFO, LOCK_SH);
		my @memdata = <$MEMINFO>;
		close ($MEMINFO);
		chomp @memdata;
		foreach my $line (@memdata) {
			if ($line =~ /^MemTotal:\s+(\d+)\s+/) {$memtotal = $1}
			if ($line =~ /^MemFree:\s+(\d+)\s+/) {$memfree = $1}
			if ($line =~ /^SwapTotal:\s+(\d+)\s+/) {$memswaptotal = $1}
			if ($line =~ /^SwapFree:\s+(\d+)\s+/) {$memswapfree = $1}
			if ($line =~ /^Cached:\s+(\d+)\s+/) {$memcached = $1}
		}

		open (my $LOADAVG, "<", "/proc/loadavg");
		flock ($LOADAVG, LOCK_SH);
		my $loadavg = <$LOADAVG>;
		close ($LOADAVG);
		chomp $loadavg;
		my @load = split(/\s+/,$loadavg);

		opendir (DIR, "/sys/class/net");
		while (my $dir = readdir(DIR)) {
			if ($dir eq "." or $dir eq ".." or $dir eq "lo") {next}
			open (my $IN, "<", "/sys/class/net/$dir/operstate");
			flock ($IN, LOCK_SH);
			my $state = <$IN>;
			close ($IN);
			chomp $state;
			if ($state ne "down") {
				open (my $RX_BYTES, "<", "/sys/class/net/$dir/statistics/rx_bytes");
				flock ($RX_BYTES, LOCK_SH);
				my $datain = <$RX_BYTES>;
				close ($RX_BYTES);
				chomp $datain;
				$netin += $datain;

				open (my $TX_BYTES, "<", "/sys/class/net/$dir/statistics/tx_bytes");
				flock ($TX_BYTES, LOCK_SH);
				my $dataout = <$TX_BYTES>;
				close ($TX_BYTES);
				chomp $dataout;
				$netout += $dataout;
			}
		}
		closedir (DIR);

		if (-e "/proc/diskstats") {
			open (my $IN, "<", "/proc/diskstats");
			flock ($IN, LOCK_SH);
			my @diskdata = <$IN>;
			close ($IN);
			chomp @diskdata;
			foreach my $line (@diskdata) {
				my @item = split(/\s+/,$line);
				if ($item[3] =~ /^[[:alpha:]]+$/) {
					$diskread += $item[4];
					$diskwrite += $item[8];
				}
			}
			if ($diskread < 1) {
				foreach my $line (@diskdata) {
					my @item = split(/\s+/,$line);
					if ($item[3] =~ /^[[:alpha:]]+\d+$/) {
						$diskread += $item[4];
						$diskwrite += $item[8];
					}
				}
			}
		}

		my $dotemp = 0;
		if (-e "/sys/devices/platform/coretemp.0/temp3_input") {$dotemp = 3}
		if (-e "/sys/devices/platform/coretemp.0/temp2_input") {$dotemp = 2}
		if (-e "/sys/devices/platform/coretemp.0/temp1_input") {$dotemp = 1}
		if ($dotemp) {
			opendir (DIR, "/sys/devices/platform");
			while (my $dir = readdir(DIR)) {
				unless ($dir =~ /^coretemp/) {next}
				open (my $IN, "<", "/sys/devices/platform/$dir/temp".$dotemp."_input");
				flock ($IN, LOCK_SH);
				my $temp = <$IN>;
				close ($IN);
				chomp $temp;
				if ($temp > $cputemp) {$cputemp = $temp}
			}
			closedir (DIR);
			$cputemp = sprintf("%.2f",$cputemp/1000)
		}

		sysopen (my $EMAIL, "/var/lib/csf/stats/email", O_RDWR | O_CREAT);
		flock ($EMAIL, LOCK_EX);
		my $stats = <$EMAIL>;
		chomp $stats;
		($mailout,$mailin) = split(/\:/,$stats);
		seek ($EMAIL, 0, 0);
		truncate ($EMAIL, 0);
		print $EMAIL "0:0";
		close ($EMAIL);

		if ($config{ST_MYSQL}) {
			eval('use DBI;'); ##no critic
			if ($@) {
				sysopen (my $TEMPCONF, "/var/lib/csf/csf.tempconf", O_WRONLY | O_APPEND | O_CREAT) or &childcleanup(__LINE__,"*Error* Cannot append out file: $!");
				flock ($TEMPCONF, LOCK_EX);
				print $TEMPCONF "ST_MYSQL = \"0\"\n";
				close ($TEMPCONF);
				logfile("STATS: DBI Perl Module missing - ST_MYSQL has been temporarily disabled. You should disable ST_MYSQL and restart lfd if you do not use this feature");
			} else {
				eval {
					local $SIG{__DIE__} = undef;
					local $SIG{'ALRM'} = sub {die};
					alarm(15);
					my $dbuser = $config{ST_MYSQL_USER};
					my $dbpass = $config{ST_MYSQL_PASS};
					my $dbhost = $config{ST_MYSQL_HOST};
					if ($dbpass eq "" and $dbuser eq "root") {
						open (my $DBS, "<", "/root/.my.cnf");
						flock ($DBS, LOCK_SH);
						while (<$DBS>) {
							chomp;
							if (/^pass(word)?=(\S+)/) {
								$dbpass = $2;
								$dbpass =~ s/^\"|\"$//g;
							}
							if (/^host=(\S+)/) {
								$dbhost = $1;
								$dbhost =~ s/^\"|\"$//g;
							}
						}
						close ($DBS);
					}
					my $status;
					my $dbh = DBI->connect("DBI:mysql:hostname=".$dbhost,$dbuser,$dbpass,{PrintError=>0}) or $status = $DBI::errstr;
					if ($status) {
						logfile("STATS: Unable to connect to MySQL: [$DBI::errstr] - You should disable ST_MYSQL and restart lfd if you do not use this feature");
					} else {
						my $sth = $dbh->prepare('SHOW /*!50002 GLOBAL */ STATUS');
						$sth->execute();
						while(my ($key, $val) = $sth->fetchrow_array()) {
							if ($key eq "Bytes_received") {$mysqlin = $val}
							if ($key eq "Bytes_sent") {$mysqlout = $val}
							if ($key eq "Queries") {$mysqlq = $val}
							if ($key eq "Slow_queries") {$mysqlsq = $val}
							if ($key eq "Connections") {$mysqlcn = $val}
							if ($key eq "Threads_connected") {$mysqlth = $val}
						}
					}
					alarm(0);
				};
				alarm(0);
				if ($@) {logfile("STATS: 15 sec. timeout performing ST_MYSQL")}
			}
		}

		if ($config{ST_APACHE}) {
			eval {
				local $SIG{__DIE__} = undef;
				local $SIG{'ALRM'} = sub {die};
				alarm(15);
				my $url = $config{PT_APACHESTATUS}."?auto";
				my ($status, $apache) = $urlget->urlget($url);
				if ($status) {
					logfile("STATS: Unable to retrieve Apache Server Status [$url] - $apache");
				} else {
					foreach my $line (split(/\n/,$apache)) {
						my ($item,$val) = split(/:\s*/,$line);
						if ($item eq "CPULoad") {$apachecpu = $val}
						if ($item eq "Total Accesses") {$apacheacc = $val}
						if ($item eq "BusyWorkers") {$apachebwork = $val}
						if ($item eq "IdleWorkers") {$apacheiwork = $val}
					}
				}
				alarm(0);
			};
			alarm(0);
			if ($@) {logfile("STATS: 15 sec. timeout performing ST_APACHE")}
		}

		if ($config{ST_DISKW}) {
			my $skip = 0;
			if (-e "/var/lib/csf/csf.tempdisk") {
				open (my $ST_DISKW, "<", "/var/lib/csf/csf.tempdisk");
				flock ($ST_DISKW, LOCK_SH);
				my $line = <$ST_DISKW>;
				chomp $line;
				close ($ST_DISKW);
				my ($time,$rate) = split (/\:/,$line);
				if ($config{ST_DISKW_FREQ} < 1) {$config{ST_DISKW_FREQ} = 1}
				if (time - $time < (60 * $config{ST_DISKW_FREQ})) {
					$skip = 1;
					$diskw = $rate;
				}
			}
			unless ($skip) {
				eval {
					local $SIG{__DIE__} = undef;
					local $SIG{'ALRM'} = sub {die};
					alarm(15);
					my @dddata = &syscommand(__LINE__,"$config{DD} $config{ST_DISKW_DD}");
					chomp @dddata;
					foreach my $line (@dddata) {
						if ($line =~ / (\d+(\.\d*)?) MB\/s$/) {
							$diskw = $1;
							last;
						}
						if ($line =~ / (\d+(\.\d*)?) GB\/s$/) {
							$diskw = $1 * 1024;
							last;
						}
					}
					alarm(0);
				};
				alarm(0);
				if ($@) {
					$diskw = 0;
					logfile("STATS: 15 sec. timeout performing ST_DISKW");
				}
				sysopen (my $ST_DISKW, "/var/lib/csf/csf.tempdisk", O_WRONLY | O_CREAT);
				flock ($ST_DISKW, LOCK_EX);
				print $ST_DISKW time.":$diskw\n";
				close ($ST_DISKW);
			}
		}

		sysopen (my $SYSSTAT,"/var/lib/csf/stats/system", O_WRONLY | O_APPEND | O_CREAT);
		flock ($SYSSTAT, LOCK_EX);
		print $SYSSTAT "$time,$cputotal,$cpuidle,$cpuiowait,$memtotal,$memfree,$memswaptotal,$memswapfree,$load[0],$load[1],$load[2],$netin,$netout,$diskread,$diskwrite,$mailin,$mailout,$cputemp,$mysqlin,$mysqlout,$mysqlq,$mysqlsq,$mysqlcn,$mysqlth,$apachecpu,$apacheacc,$apachebwork,$apacheiwork,$diskw,$memcached\n";
		close ($SYSSTAT);

		close ($THISLOCK );

		if ($config{DEBUG} >= 3) {$timer = &timer("stop","systemstats",$timer)}
		$0 = "lfd - (child) closing";
		exit;
	}
	return;
}
# end systemstats
###############################################################################
# start allowip
sub allowip {
	my $ipmatch = shift;

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
		if ($ipd eq $ipmatch) {
			return 1;
		}
		elsif ($ipd =~ /(\S+\/\d+)/) {
			my $cidrhit = $1;
			if (checkip(\$cidrhit)) {
				my $dcidr = Net::CIDR::Lite->new;
				eval {local $SIG{__DIE__} = undef; $dcidr->add($cidrhit)};
				if ($@) {logfile("Invalid CIDR in csf.allow: $cidrhit")}
				if ($dcidr->find($ipmatch)) {
					return 1;
				}
			}
		}
	}

	if ($config{GLOBAL_ALLOW} and -e "/var/lib/csf/csf.gallow") {
		open (my $IN, "<", "/var/lib/csf/csf.gallow");
		flock ($IN, LOCK_SH);
		my @allow = <$IN>;
		close ($IN);
		chomp @allow;
		foreach my $line (@allow) {
			if ($line eq "") {next}
			if ($line =~ /^\s*\#/) {next}
			my ($ipd,$commentd) = split (/\s/,$line,2);
			if ($ipd eq $ipmatch) {
				return 2;
			}
			elsif ($ipd =~ /(\S+\/\d+)/) {
				my $cidrhit = $1;
				if (checkip(\$cidrhit)) {
					my $dcidr = Net::CIDR::Lite->new;
					eval {local $SIG{__DIE__} = undef; $dcidr->add($cidrhit)};
					if ($@) {logfile("Invalid CIDR in csf.gallow: $cidrhit")}
					if ($dcidr->find($ipmatch)) {
						return 2;
					}
				}
			}
		}
	}
	return;
}
# end allowip
###############################################################################
# start testregex
sub testregex {
	my $match = shift;
	eval {
		local $SIG{__DIE__} = undef;
		my $test =~ /$match/;
	};
	if ($@) {return 0}
	return 1;
}
# end testregex
###############################################################################
# start faststart
sub faststart {
	my $text = shift;
	$faststart = 0;
	my $verbose = 1;
	if ($text =~ /^Blocklist \[CXS_/) {$verbose = 0}
	if (@faststart4) {
		if ($config{DEBUG} >= 1 and $verbose) {logfile("FASTSTART loading $text (IPv4)")};
		my $status;
		if ($config{VPS}) {$status = &fastvps(scalar @faststart4)}
		if ($status) {
			logfile($status);
		} else {
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
				logfile("*Error* FASTSTART: ($text IPv4) [$cmd] [$results[0]]");
			}
			&iptableslock("unlock",1);
		}
	}
	if (@faststart4nat) {
		if ($config{DEBUG} >= 1 and $verbose) {logfile("FASTSTART loading $text (IPv4 nat)")};
		my $status;
		if ($config{VPS}) {$status = &fastvps(scalar @faststart4nat)}
		if ($status) {
			logfile($status);
		} else {
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
				logfile("*Error* FASTSTART: ($text IPv4nat) [$cmd] [$results[0]]");
			}
			&iptableslock("unlock",1);
		}
	}
	if (@faststart6) {
		if ($config{DEBUG} >= 1 and $verbose) {logfile("FASTSTART loading $text (IPv6)")};
		my $status;
		if ($config{VPS}) {$status = &fastvps(scalar @faststart6)}
		if ($status) {
			logfile($status);
		} else {
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
				logfile("*Error* FASTSTART: ($text IPv6) [$cmd] [$results[0]]");
			}
			&iptableslock("unlock",1);
		}
	}
	if (@faststart6nat) {
		if ($config{DEBUG} >= 1 and $verbose) {logfile("FASTSTART loading $text (IPv6 nat)")};
		my $status;
		if ($config{VPS}) {$status = &fastvps(scalar @faststart6nat)}
		if ($status) {
			logfile($status);
		} else {
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
				logfile("*Error* FASTSTART: ($text IPv6nat) [$cmd] [$results[0]]");
			}
			&iptableslock("unlock",1);
		}
	}
	if (@faststartipset) {
		if ($config{DEBUG} >= 1 and $verbose) {logfile("FASTSTART loading $text (IPSET)")};
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"restore");
		print $childin join("\n",@faststartipset)."\n";
		close $childin;
		my @results = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @results;
		if ($results[0] =~ /^ipset/) {
			logfile("FASTSTART: (IPSET) Error:[$results[0]]");
		}
	}
	undef @faststart4;
	undef @faststart4nat;
	undef @faststart6;
	undef @faststart6nat;
	undef @faststartipset;
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
	my $family = "inet";
	if ($set =~ /_6/) {$family = "inet6"}
	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"create","-exist",$set,"hash:net","family",$family,"hashsize",$config{LF_IPSET_HASHSIZE},"maxelem",$config{LF_IPSET_MAXELEM});
	close $childin;
	my @results = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @results;
	if ($results[0] =~ /^ipset/) {
		logfile("*Error* IPSET: [$results[0]]");
	}
	return;
}
# end ipsetcreate
###############################################################################
# start ipsetrestore
sub ipsetrestore {
	my $set = shift;
	my $verbose = 1;
	if ($set =~ /^new_(6_)?CXS_/) {$verbose = 0}
	my $family = "inet";
	if ($set =~ /_6/) {$family = "inet6"}
	if ($verbose) {logfile("IPSET: loading set $set with ".scalar(@ipset)." entries")}

	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"restore");
	print $childin "create -exist $set hash:net family $family hashsize $config{LF_IPSET_HASHSIZE} maxelem $config{LF_IPSET_MAXELEM}\n".join("\n",@ipset)."\n";
	close $childin;
	my @results = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @results;
	if ($results[0] =~ /^ipset/) {
		logfile("*Error* [$set] IPSET: [$results[0]]");
	}
	undef @ipset;
	return;
}
# end ipsetrestore
###############################################################################
# start ipsetswap
sub ipsetswap {
	my $from = shift;
	my $to = shift;
	my $verbose = 1;
	if ($from =~ /^new_(6_)?CXS_/) {$verbose = 0}
	if ($verbose) {logfile("IPSET: switching set $from to $to")}

	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"swap",$from,$to);
	close $childin;
	my @results = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @results;
	if ($results[0] =~ /^ipset/) {
		logfile("*Error* IPSET: [$results[0]]");
	}

	$cmdpid = open3($childin, $childout, $childout, $config{IPSET},"flush",$from);
	close $childin;
	@results = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @results;
	if ($results[0] =~ /^ipset/) {
		logfile("*Error* IPSET: [$results[0]]");
	}

	$cmdpid = open3($childin, $childout, $childout, $config{IPSET},"destroy",$from);
	close $childin;
	@results = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @results;
	if ($results[0] =~ /^ipset/) {
		logfile("*Error* [$from] [$to] IPSET: [$results[0]]");
	}
	return;
}
# end ipsetswap
###############################################################################
# start ipsetadd
sub ipsetadd {
	my $set = shift;
	my $ip = shift;
	if ($set =~ /GDENY/ or $set =~ /GALLOW/) {
		if ($set =~ /^(\w+)(IN|OUT)$/) {$set = $1}
	} else {
		if ($set =~ /^chain(_6)?_NEW(\w+)$/) {$set = "chain".$1."_".$2}
		if ($set =~ /^bl(_6)?_NEW(\w+)$/) {$set = "bl".$1."_".$2}
		if ($set =~ /^(\w+)(IN|OUT)$/) {$set = $1}
	}
	if ($set eq "" or $ip eq "") {return}
	if ($faststart) {
		push @faststartipset, "add -exist $set $ip";
		return;
	}
	if ($config{DEBUG} >= 1) {logfile("debug: IPSET adding [$ip] to set [$set]")}
	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"add","-exist",$set,$ip);
	close $childin;
	my @results = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @results;
	if ($results[0] =~ /^ipset/) {
		logfile("*Error* [$set] IPSET: [$results[0]]");
	}
	return;
}
# end ipsetadd
###############################################################################
# start ipsetdel
sub ipsetdel {
	my $set = shift;
	my $ip = shift;
	if ($set =~ /^chain(_6)?_NEW(\w+)$/) {$set = "chain".$1."_".$2}
	if ($set =~ /^bl(_6)?_NEW(\w+)$/) {$set = "bl".$1."_".$2}
	if ($set =~ /^(\w+)(IN|OUT)$/) {$set = $1}
	if ($set eq "" or $ip eq "") {return}
	if ($config{DEBUG} >= 1) {logfile("debug: IPSET deleting [$ip] from set [$set]")}
	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"del",$set,$ip);
	close $childin;
	my @results = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @results;
	if ($results[0] =~ /^ipset/) {
		logfile("*Error* [$set] IPSET: [$results[0]]");
	}
	return;
}
# end ipsetadd
###############################################################################
# start ipsetflush
sub ipsetflush {
	my $set = shift;
	logfile("IPSET: flushing set $set");

	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, $config{IPSET},"flush",$set);
	close $childin;
	my @results = <$childout>;
	waitpid ($cmdpid, 0);
	chomp @results;
	if ($results[0] =~ /^ipset/) {
		logfile("*Error* IPSET: [$results[0]]");
	}
	return;
}
# end ipsetflush
###############################################################################
