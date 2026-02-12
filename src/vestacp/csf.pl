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
# start main
use strict;
use File::Find;
use Fcntl qw(:DEFAULT :flock);
use Sys::Hostname qw(hostname);
use IPC::Open3;
use lib '/usr/local/csf/lib';
use ConfigServer::DisplayUI;
use ConfigServer::Config;

our ($script, $images, $myv, %FORM, %in);

# #
#	Load configs
# #

my $config = ConfigServer::Config->loadconfig();
my %config = $config->config;

# #
#	Get Codename
#	
#	returns the codename depending on which control panel a user is running.
#	
#	@args			$config
#	@usage			my $codename = getCodename(\%config);
# #

sub getCodename
{
	my ($config_ref) = @_;
	my %config = %{$config_ref};
	my $cname = "cpanel";

	if ($config{GENERIC})      { $cname = "generic" }
	if ($config{DIRECTADMIN})  { $cname = "directadmin" }
	if ($config{INTERWORX})    { $cname = "interworx" }
	if ($config{CYBERPANEL})   { $cname = "cyberpanel" }
	if ($config{CWP})          { $cname = "cwp" }
	if ($config{VESTA})        { $cname = "vestacp" }

	if ( -e "/usr/share/webmin/miniserv.pl" || -e "/usr/libexec/webmin/bin/webmin" || -e "/usr/bin/webmin" )
	{
		$cname = "webmin";
	}

	# #
    #	Optional debug output
	# #

	#	print "$cname\n";

	# #
    #	Return the value so it can be used in conditionals
	# #

	return $cname;
}

my $codename = getCodename(\%config);

# #
#	open version.txt
# #

open (my $IN, "<", "/etc/csf/version.txt") or die $!;
$myv = <$IN>;
close ($IN);
chomp $myv;

$script = "/list/csf/frame.php";
$images = "/list/csf/images";

my $buffer = $ENV{'QUERY_STRING'};
if ($buffer eq "") {$buffer = $ENV{POST}}
if ($buffer eq "") {read(STDIN, $buffer,$ENV{'CONTENT_LENGTH'})}
if ($buffer eq "") {foreach my $item (@ARGV) {$buffer .= $item."&"}}
my @pairs = split(/&/, $buffer);
foreach my $pair (@pairs) {
	my ($name, $value) = split(/=/, $pair);
	$value =~ tr/+/ /;
	$value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
	$FORM{$name} = $value;
}

print "content-type: text/html\n\n";

#foreach my $key (keys %ENV) {
#	print "$key = [$ENV{$key}]<br>\n";
#}

my $csfjs = qq{
	<script>
		var csfCodename = "$codename";
	</script>
	<script src="$images/csf.min.js"></script>
};
my $bootstrapcss = "<link rel='stylesheet' href='$images/bootstrap/css/bootstrap.min.css'>";
my $csfnt = "<script src='$images/csfont.min.js'></script>";
my $jqueryjs = "<script src='$images/jquery.min.js'></script>";
my $bootstrapjs = "<script src='$images/bootstrap/js/bootstrap.min.js'></script>";

unless ($FORM{action} eq "tailcmd" or $FORM{action} =~ /^cf/ or $FORM{action} eq "logtailcmd" or $FORM{action} eq "loggrepcmd")
{
	print <<EOF;
<!doctype html>
<html lang='en'>
<head>
	<script>
		(function()
		{
			var theme = localStorage.getItem('theme') || 'light';
			document.documentElement.setAttribute('data-theme', theme);
		})();
	</script>

	$bootstrapcss

	<link rel="preload" href="$images/configserver.css" as="style" onload="this.onload=null;this.rel='stylesheet'">
	<noscript><link rel="stylesheet" href="$images/configserver.css"></noscript>
	<link rel="icon" type="image/x-icon" href="$images/csf.png">
	<title>ConfigServer Security &amp; Firewall</title>
	<meta charset='utf-8'>
	<meta name='viewport' content='width=device-width, initial-scale=1'>

	$csfjs
	$jqueryjs
	$csfnt
	$bootstrapjs

<style>
.mobilecontainer
{
	display:none;
}
.normalcontainer
{
	display:block;
}
EOF
	if ($config{STYLE_MOBILE})
	{
		print <<EOF;
\@media (max-width: 600px)
{
	.mobilecontainer
	{
		display:block;
	}
	.normalcontainer
	{
		display:none;
	}
}
EOF
	}
	print "</style>\n";
	print <<EOF;
</head>
<body>
<div id="loader"></div>
<a id='toplink' class='toplink' title='Go to bottom'><span class='glyphicon glyphicon-hand-down'></span></a>
<div class='container-fluid'>
<div class='panel panel-default'>
<h4><img src='$images/csf_small.png' style='padding-left: 10px'> ConfigServer Security &amp; Firewall - csf v$myv</h4>
</div>
EOF
}

my $templatehtml;
open (my $SCRIPTOUT, '>', \$templatehtml);
select $SCRIPTOUT;
ConfigServer::DisplayUI::main(\%FORM, $script, $script, $images, $myv);
close ($SCRIPTOUT);
select STDOUT;
$templatehtml =~ s/csfframe\?/csfframe\&/g;
print $templatehtml;

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
	\$('#tabAll').click(function(){
		\$('#tabAll').addClass('active');
		\$('.tab-pane').each(function(i,t){
			\$('#myTabs li').removeClass('active');
			\$(this).addClass('active');
		});
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
	print "  parent.resizeIframe(parent.document.getElementById('myiframe'));\n";
	print "</script>\n";
	print "</body>\n";
	print "</html>\n";
}

1;
