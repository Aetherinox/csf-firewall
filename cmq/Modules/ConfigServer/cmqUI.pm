###############################################################################
# Copyright (C) 2006-2025 Jonathan Michaelson
#
# https://github.com/waytotheweb/scripts
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <https://www.gnu.org/licenses>.
###############################################################################
## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
package ConfigServer::cmqUI;

use strict;
use Sys::Hostname qw(hostname);
use IPC::Open3;
use Fcntl qw(:DEFAULT :flock);
use Storable();

our ($images, $myv, $script, %FORM, %queue, $expcnt, %cookie, $downloadserver,
     $script_da, @config, $eximmainlog, $localdomains);
#
###############################################################################
# start displayUI
sub displayUI {
	my $formref = shift;
	$script = shift;
	$script_da = shift;
	$images = shift;
	$myv = shift;
	my $sessioncode = shift;
	%FORM = %{$formref};

	$downloadserver = &getdownloadserver;
	$eximmainlog = "/var/log/exim_mainlog";
	$localdomains = "/etc/localdomains";
	if (-e "/usr/local/directadmin/directadmin") {
		$eximmainlog = "/var/log/exim/mainlog";
		$localdomains = "/etc/virtual/domains";
	}

	my $config = "";
	my $viewqueue = "Delivery Queue";

	if (-e "/usr/msfe/mailscannerq") {
		if ($FORM{config} !~ /^exim/) {
			$config = "-qGmailscanner";
			push @config, "-qGmailscanner";
			$viewqueue = "MailScanner Queue";
		} else {
			$viewqueue = "Delivery Queue";
		}
	}
	elsif (-e "/etc/exim_outgoing.conf") {
		if ($FORM{config} !~ /^exim/) {
			$config = "-C /etc/exim_outgoing.conf";
			push @config, "-C", "/etc/exim_outgoing.conf";
			$viewqueue = "Delivery Queue";
		} else {
			$viewqueue = "MailScanner Queue";
		}
	}

	if ($FORM{refresh} == 1 and -e "/etc/cmq/cmqstore") {
		unlink "/etc/cmq/cmqstore";
	}

	if ($FORM{id} ne "" and $FORM{id} =~ /[^\w\-]/) {
		print "Invalid email ID [$FORM{id}]";
	}
	elsif ($FORM{bcc} ne "" and $FORM{bcc} =~ /[^a-zA-Z0-9\-\_\.\@\+]/) {
		print "Invalid email address [$FORM{bcc}]";
	}
	elsif (($FORM{action} eq "View Emails") or ($FORM{action} eq "Delete Emails")) {
		my $formurl = "?age=$FORM{age}&action=$FORM{action}&subject=$FORM{subject}&links=$FORM{links}&unit=$FORM{unit}&bounce=$FORM{bounce}&frozen=$FORM{frozen}&bool=$FORM{bool}&queue=$FORM{queue}&field=$FORM{field}&config=$FORM{config}&searchtype=$FORM{searchtype}&also=$FORM{also}&text=$FORM{text}&search=$FORM{search}&dir=$FORM{dir}";
		if (defined $FORM{page}) {$formurl .= "&page=$FORM{page}"}
		if (defined $FORM{refresh}) {$formurl .= "&refresh=$FORM{refresh}"}

		if ($FORM{queue} eq "in") {
			print "<h3>$viewqueue (Incoming) - $FORM{action}</h3>\n";
		}
		elsif ($FORM{queue} eq "out") {
			print "<h3>$viewqueue (Outgoing) - $FORM{action}</h3>\n";
		} else {
			print "<h3>$viewqueue - $FORM{action}</h3>\n";
		}

		if ($FORM{page} eq "") {$FORM{page} = 0}
		if ($FORM{refresh} == 2) {undef $FORM{page}}
		&getqueue("storable");

		open (my $IN, "<",$localdomains);
		flock ($IN, LOCK_SH);
		my @confdata = <$IN>;
		close ($IN);
		chomp @confdata;

		$expcnt = 0;
		my %ldomains;
		my $total = 0;
		my $divcnt = 0;
		foreach my $line (@confdata) {$ldomains{$line} = 1}
		my @messages;
		foreach my $key (sort {$queue{$b}{epoch} <=> $queue{$a}{epoch}} keys %queue) {
			my $show = 0;
			if ($FORM{queue} ne "inout") {
				foreach my $address (split(/\,/,$queue{$key}{to})) {
					my (undef,$domain) = split(/\@/,$address);
					if (($ldomains{$domain}) and ($FORM{queue} eq "in")) {
						$show = 1;
						last;
					}
					if (($ldomains{$domain}) and ($FORM{queue} eq "out")) {
						$show = 0;
						last;
					}
					elsif ((!$ldomains{$domain}) and ($FORM{queue} eq "out")) {
						$show = 1;
						last;
					}
				}
			} else {$show = 1}
			if ($show) {
				if ($FORM{also}) {
					if (!$FORM{frozen} and $queue{$key}{frozen} eq "*") {$show = 0}
					if (!$FORM{bounce} and $queue{$key}{bounce} eq "*") {$show = 0}
				} else {
					$show = 0;
					if ($FORM{frozen} and $queue{$key}{frozen} eq "*") {$show = 1}
					if ($FORM{bounce} and $queue{$key}{bounce} eq "*") {$show = 1}
				}
				if ($FORM{older} and $show) {
					my $mins = 0;
					if ($queue{$key}{time} =~ /(\d+)(\w)/) {
						if ($2 eq "m") {$mins = $1}
						if ($2 eq "h") {$mins = $1 * 60}
						if ($2 eq "d") {$mins = $1 * 60 * 24}
					}
					my $age = $FORM{age};
					if ($FORM{unit} eq "hours") {$age = $age * 60}
					if ($FORM{unit} eq "days") {$age = $age * 60 * 24}
					if ($mins > $age) {$show = 1} else {$show = 0}
				}
				if ($FORM{search} and $show) {
					$show = 0;
					if (($FORM{field} eq "from") and ($FORM{searchtype} eq "contain") and ($FORM{bool}) and ($queue{$key}{from} =~ /$FORM{text}/i)) {$show = 1}
					elsif (($FORM{field} eq "from") and ($FORM{searchtype} eq "contain") and (!$FORM{bool}) and ($queue{$key}{from} !~ /$FORM{text}/i)) {$show = 1}
					elsif (($FORM{field} eq "from") and ($FORM{searchtype} eq "begin with") and ($FORM{bool}) and ($queue{$key}{from} =~ /^$FORM{text}/i)) {$show = 1}
					elsif (($FORM{field} eq "from") and ($FORM{searchtype} eq "begin with") and (!$FORM{bool}) and ($queue{$key}{from} !~ /^$FORM{text}/i)) {$show = 1}
					elsif (($FORM{field} eq "from") and ($FORM{searchtype} eq "end with") and ($FORM{bool}) and ($queue{$key}{from} =~ /$FORM{text}$/i)) {$show = 1}
					elsif (($FORM{field} eq "from") and ($FORM{searchtype} eq "end with") and (!$FORM{bool}) and ($queue{$key}{from} !~ /$FORM{text}$/i)) {$show = 1}
					elsif (($FORM{field} eq "from") and ($FORM{searchtype} eq "equal") and ($FORM{bool}) and ($queue{$key}{from} eq $FORM{text})) {$show = 1}
					elsif (($FORM{field} eq "from") and ($FORM{searchtype} eq "equal") and (!$FORM{bool}) and ($queue{$key}{from} ne $FORM{text})) {$show = 1}

					if (($FORM{field} eq "ID") and ($FORM{searchtype} eq "contain") and ($FORM{bool}) and ($key =~ /$FORM{text}/i)) {$show = 1}
					elsif (($FORM{field} eq "ID") and ($FORM{searchtype} eq "contain") and (!$FORM{bool}) and ($key !~ /$FORM{text}/i)) {$show = 1}
					elsif (($FORM{field} eq "ID") and ($FORM{searchtype} eq "begin with") and ($FORM{bool}) and ($key =~ /^$FORM{text}/i)) {$show = 1}
					elsif (($FORM{field} eq "ID") and ($FORM{searchtype} eq "begin with") and (!$FORM{bool}) and ($key !~ /^$FORM{text}/i)) {$show = 1}
					elsif (($FORM{field} eq "ID") and ($FORM{searchtype} eq "end with") and ($FORM{bool}) and ($key =~ /$FORM{text}$/i)) {$show = 1}
					elsif (($FORM{field} eq "ID") and ($FORM{searchtype} eq "end with") and (!$FORM{bool}) and ($key !~ /$FORM{text}$/i)) {$show = 1}
					elsif (($FORM{field} eq "ID") and ($FORM{searchtype} eq "equal") and ($FORM{bool}) and ($key eq $FORM{text})) {$show = 1}
					elsif (($FORM{field} eq "ID") and ($FORM{searchtype} eq "equal") and (!$FORM{bool}) and ($key ne $FORM{text})) {$show = 1}

					if ($FORM{field} eq "to") {
						foreach my $address (split(/\,/,$queue{$key}{to})) {
							$address =~ s/D //g;
							$address =~ s/\+D //g;
							if (($FORM{searchtype} eq "contain") and ($FORM{bool}) and ($address =~ /$FORM{text}/i)) {$show = 1}
							elsif (($FORM{searchtype} eq "contain") and (!$FORM{bool}) and ($address !~ /$FORM{text}/i)) {$show = 1}
							elsif (($FORM{searchtype} eq "begin with") and ($FORM{bool}) and ($address =~ /^$FORM{text}/i)) {$show = 1}
							elsif (($FORM{searchtype} eq "begin with") and (!$FORM{bool}) and ($address !~ /^$FORM{text}/i)) {$show = 1}
							elsif (($FORM{searchtype} eq "end with") and ($FORM{bool}) and ($address =~ /$FORM{text}$/i)) {$show = 1}
							elsif (($FORM{searchtype} eq "end with") and (!$FORM{bool}) and ($address !~ /$FORM{text}$/i)) {$show = 1}
							elsif (($FORM{searchtype} eq "equal") and ($FORM{bool}) and ($address eq $FORM{text})) {$show = 1}
							elsif (($FORM{searchtype} eq "equal") and (!$FORM{bool}) and ($address ne $FORM{text})) {$show = 1}
							if ($show) {last}
						}
					}
					if ($FORM{field} eq "subject") {
						my $subject = "";
						my ($childin, $childout);
						my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-Mvh", $key);
						my @data = <$childout>;
						waitpid ($cmdpid, 0);
						chomp @data;
						foreach my $line (@data) {
							my (undef,$field,$value) = split(/\s+/,$line,3);
							if ($field =~ /subject:/i) {$subject = $value;}
						}
						if (($FORM{searchtype} eq "contain") and ($FORM{bool}) and ($subject =~ /$FORM{text}/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "contain") and (!$FORM{bool}) and ($subject !~ /$FORM{text}/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "begin with") and ($FORM{bool}) and ($subject =~ /^$FORM{text}/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "begin with") and (!$FORM{bool}) and ($subject !~ /^$FORM{text}/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "end with") and ($FORM{bool}) and ($subject =~ /$FORM{text}$/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "end with") and (!$FORM{bool}) and ($subject !~ /$FORM{text}$/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "equal") and ($FORM{bool}) and ($subject eq $FORM{text})) {$show = 1}
						elsif (($FORM{searchtype} eq "equal") and (!$FORM{bool}) and ($subject ne $FORM{text})) {$show = 1}
					}
					if ($FORM{field} eq "header") {
						my ($childin, $childout);
						my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-Mvh", $key);
						my @data = <$childout>;
						waitpid ($cmdpid, 0);
						chomp @data;
						my $header = join("\n",@data);
						if (($FORM{searchtype} eq "contain") and ($FORM{bool}) and ($header =~ /$FORM{text}/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "contain") and (!$FORM{bool}) and ($header !~ /$FORM{text}/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "begin with") and ($FORM{bool}) and ($header =~ /^$FORM{text}/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "begin with") and (!$FORM{bool}) and ($header !~ /^$FORM{text}/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "end with") and ($FORM{bool}) and ($header =~ /$FORM{text}$/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "end with") and (!$FORM{bool}) and ($header !~ /$FORM{text}$/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "equal") and ($FORM{bool}) and ($header eq $FORM{text})) {$show = 1}
						elsif (($FORM{searchtype} eq "equal") and (!$FORM{bool}) and ($header ne $FORM{text})) {$show = 1}
					}
					if ($FORM{field} eq "body") {
						my ($childin, $childout);
						my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-Mvb", $key);
						my @data = <$childout>;
						waitpid ($cmdpid, 0);
						chomp @data;
						my $body = join("\n",@data);
						if (($FORM{searchtype} eq "contain") and ($FORM{bool}) and ($body =~ /$FORM{text}/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "contain") and (!$FORM{bool}) and ($body !~ /$FORM{text}/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "begin with") and ($FORM{bool}) and ($body =~ /^$FORM{text}/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "begin with") and (!$FORM{bool}) and ($body !~ /^$FORM{text}/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "end with") and ($FORM{bool}) and ($body =~ /$FORM{text}$/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "end with") and (!$FORM{bool}) and ($body !~ /$FORM{text}$/i)) {$show = 1}
						elsif (($FORM{searchtype} eq "equal") and ($FORM{bool}) and ($body eq $FORM{text})) {$show = 1}
						elsif (($FORM{searchtype} eq "equal") and (!$FORM{bool}) and ($body ne $FORM{text})) {$show = 1}
					}
				}
			}
			if ($show) {push @messages, $key}
		}
		if ($FORM{dir} eq "d") {@messages = reverse @messages}

		my $pagination = "";
		my $offsetrows = 50;
		my $gtotal = scalar(@messages);
		$formurl = "?age=$FORM{age}&action=$FORM{action}&subject=$FORM{subject}&links=$FORM{links}&unit=$FORM{unit}&bounce=$FORM{bounce}&frozen=$FORM{frozen}&bool=$FORM{bool}&queue=$FORM{queue}&field=$FORM{field}&config=$FORM{config}&searchtype=$FORM{searchtype}&also=$FORM{also}&text=$FORM{text}&search=$FORM{search}&dir=$FORM{dir}";
		if ($FORM{action} eq "View Emails" and defined $FORM{page}) {
			my $from = 0;
			my $to = $offsetrows - 1;
			my $offset = $FORM{page};

			$from = ($offset) * $offsetrows;
			$to = (($offset) * $offsetrows) + $offsetrows - 1;
			if ($to > $gtotal) {$to = $gtotal}
			@messages = @messages[$from..$to];

			my $pages = int( ($gtotal - 1) / $offsetrows);
			my $start = 0;
			my $end = 9;
			if ($pages < 10) {$end = $pages}
			if ($pages >= 10) {
				$start = $offset - 4;
				$end = $offset + 4;
			}
			if ($end < 8) {$end = 8}
			if ($start < 0) {$start = 0}
			if ($end > $pages) {$end = $pages}
			$pagination .= "<ul class='pagination' style='margin:0'>\n";
			my $drop = int($pages/$offsetrows);
			if ($drop > 0) {
				$pagination .= "<li><span class='dropdown'>\n";
				$pagination .= "<span class='dropdown-toggle' data-toggle='dropdown' style='cursor: pointer;'>Jump <span class='caret'></span></span>\n";
				$pagination .= "<ul class='dropdown-menu'>\n";
				for (1..$drop) {
					$pagination .= "<li><a href='$formurl&page=".($_*$offsetrows - 1)."' title='Jump to page'>".($_*$offsetrows)."</a></li>\n";
				}
				$pagination .= "</ul></span></li>\n";
			}
			if ($start > 0) {$pagination .= "<li><a href='$formurl&page=0' title='Go to page'><span class='glyphicon glyphicon-chevron-left'></span> 1</a></li>\n"}
			for ($start..$end) {
				my $x = $_;
				my $active;
				if ($x == $offset) {$active = " class='active'"}
				$pagination .= "<li$active><a href='$formurl&page=$x' title='Go to page'>".($x+1)."</a></li>\n";
			}
			if ($end < $pages) {
				$pagination .= "<li><a href='$formurl&page=$pages' title='Go to page'>".($pages+1)." <span class='glyphicon glyphicon-chevron-right'></span></i></a></li>\n";
			}
			$pagination .= "<li><a>Results: <code>$gtotal</code></a></li>\n";
			$pagination .= "</ul>\n";
		}

		if ($FORM{action} eq "View Emails") {
			print "<style type='text/css'>\n.submenu {\n    display:none;\n}\n.mhead {\n    display: block;\n}\n.nooverflow {\n overflow: hidden;\n	text-overflow: ellipsis;\n max-width: 200px;\n}\n</style>\n<script language='JavaScript' src='$images/cmq.js'></script>\n";
			print "<script>\nfunction checkme() {\n";
			print "	for (var x = 0; x < document.listmail.elements.length; x++) {\n";
			print "		var check = document.listmail.elements[x];\n";
			print "	    if (document.listmail.elements[x].name != 'checkall') {\n";
			print "			check.checked = document.listmail.checkall.checked;\n";
			print "		}\n";
			print "	}\n";
			print "}\n\n";
			print "function checkme2() {\n";
			print "	for (var x = 0; x < document.listmail.elements.length; x++) {\n";
			print "		var check = document.listmail.elements[x];\n";
			print "	    if (document.listmail.elements[x].name != 'checkall2') {\n";
			print "			check.checked = document.listmail.checkall2.checked;\n";
			print "		}\n";
			print "	}\n";
			print "}\n</script>\n";
			print "<form action='$script' method='post' name='listmail'><input type='hidden' name='action' value='mass'><input type='hidden' name='config' value='$FORM{config}'>\n";
	#		if ($expcnt > 0) {
	#			print "<p><a href='javascript:expandO(\"expand\",$expcnt);'><img valign='absmiddle' src='$images/plus.png' name='i$divcnt' border='0' width='12' height='12'> Expand All</a>\n";
	#			print " <a href='javascript:expandO(\"collapse\",$expcnt);'><img valign='absmiddle' src='$images/minus.png' name='i$divcnt' border='0' width='12' height='12'> Collapse All</a></p>\n";
	#		}
			if (defined($FORM{page})) {
				print "<p>\n";
				print " <a class='btn btn-default' href='$formurl&refresh=1&page=0'><span class='glyphicon glyphicon-refresh'></span> Refresh Queue Cache</a> \n";
				if ($gtotal > $offsetrows) {
					print "<a class='btn btn-default' href='$formurl&refresh=2&page=0'><span class='glyphicon glyphicon-list'></span> No Pagination</a>\n";
				}
				print "</p>\n";
				print $pagination;
			}
			print "<table class='table table-striped table-bordered'>\n";
			my $formurl = "?age=$FORM{age}&action=$FORM{action}&subject=$FORM{subject}&links=$FORM{links}&unit=$FORM{unit}&bounce=$FORM{bounce}&frozen=$FORM{frozen}&bool=$FORM{bool}&queue=$FORM{queue}&field=$FORM{field}&config=$FORM{config}&searchtype=$FORM{searchtype}&also=$FORM{also}&text=$FORM{text}&search=$FORM{search}";
			my $age = "<a href='${formurl}&dir=d'><span class='glyphicon glyphicon-sort-by-order' title='Sort Descending'></span></a>";
			if ($FORM{dir} eq "d") {$age = "<a href='${formurl}&dir=a' title='Sort Ascending'><span class='glyphicon glyphicon-sort-by-order-alt'></span></a>"}
			print "<thead><tr><th><input type='checkbox' name='checkall' OnClick='checkme()'></th><th>Email ID</th><th>&nbsp;</th><th style='white-space:nowrap'>Age $age</th><th>Size</th><th>From</th><th>To</th>";
			if ($FORM{subject}) {print "<th>Subject</th>"}
			print "</tr></thead>";
		} else {
			print "<table class='table table-striped table-bordered'>\n";
			print "<thead><tr><th>&nbsp;</th><th>Email ID</th><th>Response</th></tr></thead>\n";
		}

		foreach my $key (@messages) {
			if ($key eq "" or $key eq "0") {next}
			if (($queue{$key}{time} eq "") or ($queue{$key}{size} eq "")) {
				if ($FORM{action} eq "View Emails") {
					print "<tr><td>&nbsp;</td><td><span>$key</span></td>\n";
					print "<td colspan='5'>Broken spool file - removed</td></tr>\n";
				} else {
					print "<tr><td><span>$key</span></td>\n";
					print "<td>Broken spool file - removed</td></tr>\n";
				}
				my ($childin, $childout);
				my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-Mrm", $key);
				my @data = <$childout>;
				waitpid ($cmdpid, 0);
				next;
			}
			if ($FORM{action} eq "View Emails") {
				my $to = $queue{$key}{to};
				if ($to =~ /\,/) {
					$divcnt++;
					my @tos = split(/\,/,$to);
					$to = "<span class='mhead'><a href='javascript:showMenu($divcnt);'><img valign='absmiddle' src='$images/plus.png' name='i$divcnt' border='0' width='12' height='12'></a>$tos[0]\n</span>\n<span class='submenu' id='s$divcnt'>\n";
					for (my $x = 1;$x < @tos;$x++) {
						$to .= "$tos[$x]<br>\n";
					}
					$to .= "</span>\n";
				}
				my $frozen;
				if ($queue{$key}{frozen} eq "*") {$frozen = "<span class='glyphicon glyphicon-certificate' title='frozen'></span>"}

				print "<tr id='$key'><td style='white-space: nowrap;'><input type='checkbox' name='del_$key'> ".(($total+1) + $FORM{page}*$offsetrows)."</td><td style='white-space: nowrap;'>\n";
				if ($FORM{links}) {
					print "<a class='btn btn-default' href='$script?action=view&id=$key&config=$FORM{config}' title='View Email' target='_blank'>$key</a> $frozen</td>\n";
				} else {
					print "<a class='btn btn-default modalButton' data-toggle='modal' data-src='$script?action=view&id=$key&config=$FORM{config}' data-height='500px' data-width='100%' data-target='#myModal' title='View Email'>$key</a> $frozen</td>\n";
				}
				print "<td nowrap>\n";
				if ($FORM{links}) {
					print "<a class='btn btn-danger' href='$script?action=delete&id=$key&config=$FORM{config}' target='_blank' title='Delete' onclick='\$(\"#$key\").hide()'><span class='glyphicon glyphicon-remove-circle'></span></a> \n";
				} else {
					print "<a class='btn btn-danger modalButton' data-toggle='modal' data-src='$script?action=delete&id=$key&config=$FORM{config}' data-height='500px' data-width='100%' data-target='#myModal' title='Delete' onclick='\$(\"#$key\").hide()'><span class='glyphicon glyphicon-remove-circle'></span></a> \n";
				}
				if ($FORM{links}) {
					print "<a class='btn btn-primary' href='$script?action=deliver&id=$key&config=$FORM{config}' target='_blank' title='Deliver'><span class='glyphicon glyphicon-repeat'></span></a> \n";
				} else {
					print "<a class='btn btn-primary modalButton' data-toggle='modal' data-src='$script?action=deliver&id=$key&config=$FORM{config}' data-height='500px' data-width='100%' data-target='#myModal' title='Deliver'><span class='glyphicon glyphicon-repeat'></span></a> \n";
				}
				if ($FORM{links}) {
					print "<a class='btn btn-info' href='$script?action=viewdelivery&id=$key&config=$FORM{config}' target='_blank' title='Delivery Log'><span class='glyphicon glyphicon-search'></span></a></td>\n";
				} else {
					print "<a class='btn btn-info modalButton' data-toggle='modal' data-src='$script?action=viewdelivery&id=$key&config=$FORM{config}' data-height='500px' data-width='100%' data-target='#myModal' title='Delivery Log'><span class='glyphicon glyphicon-search'></span></a></td>\n";
				}
				print "<td>$queue{$key}{time}</td><td>$queue{$key}{size}</td><td class='nooverflow' title='$queue{$key}{from}'>$queue{$key}{from}</td><td class='nooverflow' title='$queue{$key}{to}'>$to</td>";

				if ($FORM{subject}) {
					my $subject = "[no subject/subject not found]";
					my ($childin, $childout);
					my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-Mvh", $key);
					my @data = <$childout>;
					waitpid ($cmdpid, 0);
					chomp @data;
					foreach my $line (@data) {
						my (undef,$field,$value) = split(/\s+/,$line,3);
						if ($field =~ /subject:/i) {$subject = $value;}
					}
					$subject =~ s/>/&gt;/g;
					$subject =~ s/</&lt;/g;
					print "<td class='nooverflow' title='$subject'>$subject</td>";
				}

				print "</tr>\n";
			}
			elsif ($FORM{action} eq "Delete Emails") {
				my $cnt = $total + 1;
				print "<tr><td><span>$cnt</span></td><td><span>$key</span></td>\n";
				print "<td>";
				my ($childin, $childout);
				my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-Mrm", $key);
				my @data = <$childout>;
				waitpid ($cmdpid, 0);
				chomp @data;
				print $data[-1];
				print "</td></tr>\n";
			}
			$total++;
		}
		my $span = 7;
		if ($FORM{subject}) {$span = 8}
		if ($total == 0) {
			print "<tr><td colspan='$span'>No matching queue entries found</td></tr>\n";
		}
		elsif ($FORM{action} eq "View Emails") {
			print "<thead><tr><th><input type='checkbox' name='checkall2' OnClick='checkme2()'></th><th>Email ID</th><th>&nbsp;</th><th>Age</th><th>Size</th><th>From</th><th>To</th>";
			if ($FORM{subject}) {print "<th>Subject</th>"}
			print "</tr></thead>";
			print "<tr><td colspan='$span'>\n";
			print "<button type='button' class='btn btn-default confirmmodal' data-toggle='modal' data-target='#confirmmodal'>Delete Selected</button>\n";
			&confirmmodal("do", "Delete Selected", "Are you sure you want to delete these emails?");
			print "| <input type='submit' class='btn btn-default'  name='do' value='Bcc to:'> <input type='text' size='20' name='bcc'></td></tr>\n";
		}
		print "</table></form>\n";
		if ($FORM{action} eq "View Emails") {print $pagination}
		print "<div class='alert alert-info'><ul>\n";
		print "<li><span class='btn btn-danger glyphicon glyphicon-remove-circle'></span> Delete Email</li>\n";
		print "<li><span class='btn btn-primary glyphicon glyphicon-repeat'></span> Retry Delivery</li>\n";
		print "<li><span class='btn btn-info glyphicon glyphicon-search'></span> View Delivery Log</li>\n";
		print "</ul><br /><ul>\n";
		print "<li>The email queue is cached to allow for pagination. To refresh the cache, either go back to the main page or select the refresh button</li>\n";
		print "<li>Click on Email ID to view email headers and body</li>\n";
		print "<li><span class='glyphicon glyphicon-certificate' title='frozen'></span> These are frozen emails that exim is unable to deliver</li>\n";
		print "<li><span>To</span> D = Delivered, +D = Delivered to Forwarder</li>\n";
		print "</ul></div>\n";
		print "<hr><p><form action='$script' method='post'><input type='submit' class='btn btn-default'  value='Return'></form></p>\n";
		print  "<div class='modal fade' id='myModal' tabindex='-1' role='dialog'  aria-labelledby='myModalLabel' aria-hidden='true' data-backdrop='false' style='background-color: rgba(0, 0, 0, 0.5)'>\n";
		print  "<div class='modal-dialog modal-lg'>\n";
		print  "<div class='modal-content'>\n";
		print  "<div class='modal-body'>\n";
		print  "<iframe frameborder='0'></iframe>\n";
		print  "</div>\n";
		print  "<div class='modal-footer text-center'>\n";
		print  "<button type='button' id='ModalClose' class='btn btn-default' data-dismiss='modal'>Close</button>\n";
		print  "</div>\n";
		print  "</div><!-- /.modal-content -->\n";
		print  "</div><!-- /.modal-dialog -->\n";
		print  "</div><!-- /.modal -->\n";
		print  "<script>\n";
		print  "\$('a.modalButton').on('click', function(e) {\n";
		print  "var src = \$(this).attr('data-src');\n";
		print  "var height = \$(this).attr('data-height') || 500;\n";
		print  "var width = \$(this).attr('data-width') || 400;\n";
		print  "\$('#myModal iframe').contents().find('body').html('Loading, please wait...');\n";
		print  "\$('#myModal iframe').attr({'src':src,\n";
		print  "'height': height,\n";
		print  "'width': width});\n";
		print  "});\n";
		print "\$('.modal').click(function(event){\n";
		print "  \$(event.target).modal('hide')\n";
		print "});\n";
		print  "</script>\n";
	}
	elsif ($FORM{action} eq "view") {
		print "<div class='panel panel-default'>\n";
		print "<div class='panel-heading panel-heading-cxs'>Headers spool file</div>\n";
		print "<div class='panel=body'><pre style='white-space:pre-wrap'>";
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-Mvh", $FORM{id});
		my @data = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @data;
		foreach my $line (@data) {
			$line =~ s/>/&gt;/g;
			$line =~ s/</&lt;/g;
			print $line."\n";
		}
		print "</pre></div>\n";
		print "</div>\n";

		print "<div class='panel panel-default'>\n";
		print "<div class='panel-heading panel-heading-cxs'>Data spool file</div>\n";
		print "<div class='panel-body'><pre style='white-space:pre-wrap'>";
		$cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-Mvb", $FORM{id});
		@data = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @data;
		foreach my $line (@data) {
			$line =~ s/>/&gt;/g;
			$line =~ s/</&lt;/g;
			print $line."\n";
		}
		print "</pre></div>\n";
		print "</div>\n";
	}
	elsif ($FORM{action} eq "viewdelivery") {
		print "<table class='table table-striped table-bordered'>\n";
		print "<thead><tr><th>Delivery Log (Where available - Can take some time depending on the size of the $eximmainlog)</th></tr></thead>\n";
		print "<tr><td><pre style='white-space:pre-wrap'>";
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exigrep", $FORM{id}, "$eximmainlog");
		my @data = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @data;
		foreach my $line (@data) {
			$line =~ s/>/&gt;/g;
			$line =~ s/</&lt;/g;
			print $line."\n";
		}
		print "</pre></td></tr>\n";
		print "</table>\n";
	}
	elsif ($FORM{action} eq "deliver") {
		print "<table class='table table-striped table-bordered'>\n";
		print "<thead><tr><th>Deliver Email</th></tr></thead>\n";
		print "<tr><td><pre style='white-space:pre-wrap'>";
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-v", "-M", $FORM{id});
		my @data = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @data;
		foreach my $line (@data) {
			$line =~ s/>/&gt;/g;
			$line =~ s/</&lt;/g;
			print $line."\n";
		}
		print "</pre></td></tr>\n";
		print "</table>\n";
	}
	elsif ($FORM{action} eq "delete") {
		print "<table class='table table-striped table-bordered'>\n";
		print "<thead><tr><th>Delete Email</th></tr></thead>\n";
		print "<tr><td><pre style='white-space:pre-wrap'>";
		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-v", "-Mrm", $FORM{id});
		my @data = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @data;
		foreach my $line (@data) {
			$line =~ s/>/&gt;/g;
			$line =~ s/</&lt;/g;
			print $line."\n";
		}
		print "</pre></td></tr>\n";
		print "</table>\n";
	}
	elsif ($FORM{action} eq "mass") {
		my $total = 0;
		my $class = "tdshade2_noborder";
		if ($FORM{do} ne "Bcc to:") {
			print "<h2>Delete Selected</h2>\n";
		} else {
			print "<h2>Bcc Selected to $FORM{bcc}</h2>\n";
		}
		print "<table class='table table-striped table-bordered'>\n";
		print "<thead><tr><th>Email ID</th><th>Response</th></tr></thead>\n";
		foreach my $key (keys %FORM) {
			my $id = 0;
			if ($key =~ /^del_(.*)/) {$id = $1}
			unless ($id) {next}
			print "<tr><td><span>$id</span></td>\n";
			print "<td>";
			my $data;
			if ($FORM{do} eq "Bcc to:") {
				my ($childin, $childout);
				my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-Mar", $id, $FORM{bcc});
				my @data = <$childout>;
				waitpid ($cmdpid, 0);
				chomp @data;
				print $data[-1];

				$cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-Mc", $id);
				@data = <$childout>;
				waitpid ($cmdpid, 0);
				chomp @data;
				print $data[-1];
			} else {
				my ($childin, $childout);
				my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-Mrm", $id);
				my @data = <$childout>;
				waitpid ($cmdpid, 0);
				chomp @data;
				print $data[-1];
			}
			print "</td></tr>\n";
			$total++;
			if ($class eq "tdshade2_noborder") {$class = "tdshade1_noborder"} else {$class = "tdshade2_noborder"}
		}
		print "</table>\n";
		print "<p>Total emails: $total</p>\n";
		print "<p><form action='$script' method='post'><input type='submit' class='btn btn-default'  value='Return'></form></p>\n";
	}
	elsif ($FORM{action} eq "Queue Run") {
		my @cmd;
		my $flags;
		if ($config =~ /mailscanner/) {undef @config}
		if ($FORM{text} ne "" and $FORM{text} =~ /[^a-zA-Z0-9\-\_\.\@\+]/) {
			print "Invalid data [$FORM{text}]";
		} else {
			if ($FORM{force}) {$flags = "f"}
			if ($FORM{frozen}) {$flags = "ff"}
			if ($FORM{search}) {
				if ($FORM{field} eq "to") {
					push @cmd, "-R$flags", $FORM{text};
				} else {
					push @cmd, "-S$flags", $FORM{text};
				}
			} else {
				push @cmd, "-q$flags";
			}
			print "<div class='panel panel-default'>\n";
			print "<div class='panel-heading panel-heading-cxs'>Queue Run</div>\n";
			print "<div class='panel-body'><pre style='white-space: pre-wrap'>";
			my ($childin, $childout);
			my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-v", @cmd);
			my @data = <$childout>;
			waitpid ($cmdpid, 0);
			chomp @data;
			foreach my $line (@data) {
				$line =~ s/>/&gt;/g;
				$line =~ s/</&lt;/g;
				print $line."\n";
			}
			print "</pre></div>\n";
			print "</div>\n";
		}
		print "<p><form action='$script' method='post'><input type='submit' class='btn btn-default'  value='Return'></form></p>\n";
	}
	elsif ($FORM{action} eq "Exigrep") {
		my $cmd;
		my $flags;
		if ($FORM{text} eq "") {
			print "Empty regex";
		} else {
			print "<div class='panel panel-default'>\n";
			print "<div class='panel-heading panel-heading-cxs'>Exigrep for $FORM{text}</div>\n";
			print "<div class='panel-body'><pre style='white-space: pre-wrap'>";
			my ($childin, $childout);
			my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exigrep", $FORM{text}, "$eximmainlog");
			my @data = <$childout>;
			waitpid ($cmdpid, 0);
			chomp @data;
			foreach my $line (@data) {
				$line =~ s/>/&gt;/g;
				$line =~ s/</&lt;/g;
				print $line."\n";
			}
			print "</pre></div>\n";
			print "</div>\n";
		}
		print "<p><form action='$script' method='post'><input type='submit' class='btn btn-default'  value='Return'></form></p>\n";
	}
	elsif ($FORM{action} eq "upgrade") {
		$| = 1; ## no critic

		print "Retrieving new cmq package...\n";
		print "<pre style='white-space: pre-wrap'>";
		&printcmd("rm -Rfv /usr/src/cmq* ; cd /usr/src ; wget -q https://$downloadserver/cmq.tgz 2>&1");
		print "</pre>";
		if (! -z "/usr/src/cmq.tgz") {
			print "Unpacking new cmq package...\n";
			print "<pre style='white-space: pre-wrap'>";
			&printcmd("cd /usr/src ; tar -xzf cmq.tgz ; cd cmq ; sh install.sh 2>&1");
			print "</pre>";
			print "Tidying up...\n";
			print "<pre style='white-space: pre-wrap'>";
			&printcmd("rm -Rfv /usr/src/cmq*");
			print "</pre>";
			print "...All done.\n";
		}

		open (my $IN, "<", "/etc/cmq/cmqversion.txt") or die $!;
		$myv = <$IN>;
		close ($IN);
		chomp $myv;

		print "<p><form action='$script' method='post'><input type='submit' class='btn btn-default' value='Return'></form></p>\n";
	}
	else {
		if (-e "/etc/cmq/cmqstore") {unlink "/etc/cmq/cmqstore"}

		my ($childin, $childout);
		my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-bpc");
		my @output = <$childout>;
		waitpid ($cmdpid, 0);
		chomp @output;
		unless ($output[0]) {$output[0] = 0}

		my @eximoutput;
		if ($config) {
			my ($childin, $childout);
			my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", "-bpc");
			@eximoutput = <$childout>;
			waitpid ($cmdpid, 0);
			chomp @eximoutput;
			unless ($eximoutput[0]) {$eximoutput[0] = 0}
		}
		if ($config =~ /mailscanner/) {
			my @tmp = @eximoutput;
			@eximoutput = @output;
			@output = @tmp;
		}

		print "<form action='$script' method='post'>\n";

		print "<table class='table table-striped table-bordered'>\n";
		print "<thead><tr><th colspan='2'>Mail Queue Queries</th></tr></thead>";

		if ($config =~ /mailscanner/) {
			print "<tr><td><input type='radio' name='config' value='exim_$output[0]' checked> Delivery Queue (<b>$output[0]</b> emails)</td><td>Default queue - email waiting for delivery</td></tr>\n";
			if ($config) {
				print "<tr><td><input type='radio' name='config' value='ms_$eximoutput[0]'> MailScanner Queue (<b>$eximoutput[0]</b> emails)</td><td>Email awaiting processing by MailScanner</td></tr>\n";
			}
		}
		elsif ($config =~ /exim/) {
			print "<tr><td><input type='radio' name='config' value='ms_$output[0]' checked> Delivery Queue (<b>$output[0]</b> emails)</td><td>Default queue - email waiting for delivery</td></tr>\n";
			if ($config) {
				print "<tr><td><input type='radio' name='config' value='exim_$eximoutput[0]'> MailScanner Queue (<b>$eximoutput[0]</b> emails)</td><td>Email awaiting processing by MailScanner</td></tr>\n";
			}
		}
		else {
			print "<tr><td><input type='radio' name='config' value='ms_$output[0]' checked> Delivery Queue (<b>$output[0]</b> emails)</td><td>Default queue - email waiting for delivery</td></tr>\n";
		}
		print "<tr><td><input type='radio' name='queue' value='inout' checked> All Emails</td><td>Select all email that has been queued</td></tr>\n";
		print "<tr><td><input type='radio' name='queue' value='in'> Incoming Emails (may contain outgoing Forwarders)</td><td>Select incoming email that has been queued</td></tr>\n";
		print "<tr><td><input type='radio' name='queue' value='out'> Outgoing Emails</td><td>Select outgoing email that has been queued</td></tr>\n";
		print "<tr><td><input type='checkbox' name='frozen' value='1' checked> Frozen Emails</td><td>Select all frozen email that has been queued</td></tr>\n";
		print "<tr><td><input type='checkbox' name='bounce' value='1' checked> Bounce Emails</td><td>Select all bounce email that has been queued</td></tr>\n";
		print "<tr><td><input type='checkbox' name='also' value='1' checked> All Other Emails</td><td>Select all other email that has been queued</td></tr>\n";
		print "<tr><td><input type='checkbox' name='subject' value='1'> Display Email Subject when viewing emails</td><td>This will add load and extend the time it takes to perform the task</td></tr>\n";
		print "<tr><td><input type='checkbox' name='links' value='1'> Launch links in new window</td><td>This will open links in a new window/tab instead of a modal in View Emails</td></tr>\n";
		print "<tr><td><input type='checkbox' name='older' value='1'> Emails older than <select name='age'>\n";
		for (my $x=1;$x <61 ;$x++) {print "<option>$x</option>\n"}
		print "</select> <select name='unit'>\n";
		print "<option>minutes</option>\n";
		print "<option>hours</option>\n";
		print "<option>days</option>\n";
		print "</select></td><td>Select email that has been queued by age</td></tr>\n";
		print "<tr><td><input type='checkbox' name='search' value='1'> <select name='field'>\n";
		print "<option>to</option>\n";
		print "<option>from</option>\n";
		print "<option>subject</option>\n";
		print "<option>header</option>\n";
		print "<option>body</option>\n";
		print "<option>ID</option>\n";
		print "</select> <select name='bool'> <option value='1'>does</option><option value='0'>does not</option></select> <select name='searchtype'>\n";
		print "<option>contain</option>\n";
		print "<option>begin with</option>\n";
		print "<option>end with</option>\n";
		print "<option>equal</option>\n";
		print "</select> <input type='text' size='20' name='text'></td><td>Select email that has been queued with specified text</td></tr>\n";
		print "<tr><td colspan='2'><input type='submit' class='btn btn-default'  name='action' value='View Emails'>\n";
		print " <button type='button' class='btn btn-default confirmmodal' data-toggle='modal' data-target='#confirmmodal'>Delete Emails</button>\n";
		print " <input type='reset' class='btn btn-default' value='Reset Form'></td></tr>\n";
		print "</table>\n";
		&confirmmodal("action", "Delete Emails", "Are you sure you want to delete these emails?");
		print "</form>\n";

		print "<form action='$script' method='post'>\n";
		print "<table class='table table-striped table-bordered'>\n";
		print "<thead><tr><th colspan='2'>Exigrep</th></tr></thead>";
		print "<tr><td colspan='2'>Perform a pattern match search of $eximmainlog</td></tr>\n";
		print "<tr><td><input type='text' size='20' name='text'> Regular Expression</td><td>Uses exigrep to search $eximmainlog</td></tr>\n";
		print "<tr><td colspan='2'><input type='submit' class='btn btn-default'  name='action' value='Exigrep'> <input type='reset' class='btn btn-default' value='Reset Form'></td></tr>\n";
		print "</table></form>\n";

		print "<form action='$script' method='post'>\n";
		print "<table class='table table-striped table-bordered'>\n";
		print "<thead><tr><th colspan='2'>Mail Queue Runs</th></tr></thead>";
		print "<tr><td colspan='2'>Performs an exim queue run. These runs can take a long time to complete, so you need to be patient and careful not to spawn multiple queue runs by initiating these options until previous runs have completed.</td></tr>\n";
		print "<tr><td><input type='checkbox' name='force' value='1'> Force run</td><td>Ignores retry times for all relevant emails</td></tr>\n";
		print "<tr><td><input type='checkbox' name='frozen' value='1'> Frozen Emails (implies Force run)</td><td>Forces all emails including frozen emails to be retried</td></tr>\n";
		print "<tr><td><input type='checkbox' name='search' value='1'> <select name='field'>\n";
		print "<option>to</option>\n";
		print "<option>from</option>\n";
		print "</select> contains <input type='text' size='20' name='text'></td><td>Selects email based on sender or recipient address text</td></tr>\n";
		print "<tr><td colspan='2'><input type='submit' class='btn btn-default'  name='action' value='Queue Run'> <input type='reset' class='btn btn-default' value='Reset Form'></td></tr>\n";
		print "</table>\n";

		my ($status, $text) = &urlget("https://$downloadserver/cmq/cmqversion.txt");
		my $actv = $text;
		my $up = 0;

		print "<table class='table table-striped table-bordered'>\n";
		print "<thead><tr><th colspan='2'>Upgrade</th></tr></thead>";
		if ($actv ne "") {
			if ($actv =~ /^[\d\.]*$/) {
				if ($actv > $myv) {
					print "<tr><form action='$script' method='post'><td><input type='hidden' name='action' value='upgrade'><input type='submit' class='btn btn-default'  value='Upgrade cmq'></td><td><b>A new version of cmq (v$actv) is available. <a href='https://$downloadserver/cmq/CHANGELOG.txt' target='_blank'>View ChangeLog</a></b></td></form></tr>\n";
				} else {
					print "<tr><td colspan='2'>You appear to be running the latest version of cmq</td></tr>\n";
				}
				$up = 1;
			}
		}
		unless ($up) {
			print "<tr><td colspan='2'>Failed to determine the latest version of cmq: [$status] [$text]</td></tr>\n";
		}
		print "</table></form>\n";
	}
	print "<pre style='white-space: pre-wrap'>cmq: v$myv</pre>";
	print "<p>&copy;2006-2019, <a href='http://www.configserver.com' target='_blank'>ConfigServer Services</a> (Jonathan Michaelson)</p>\n";

	return;
}
# end displayUI
###############################################################################
# start getqueue
sub getqueue {
	my $storable = shift;

	if ($storable eq "storable" and -e "/etc/cmq/cmqstore") {
		%queue = %{Storable::retrieve("/etc/cmq/cmqstore")};
		return;
	}

	my $pos = 0;
	my $id = 0;
	my $count = 0;
	my $queuecnt = 0;
	my $per = 0;
	my $oldper = 0;
	my ($childin, $childout);
	my $cmdpid = open3($childin, $childout, $childout, "/usr/sbin/exim", @config, "-bpra");
#	my $cmdpid = open3($childin, $childout, $childout, "cat /root/tmp/q.txt");
	while (my $line = <$childout>) {
		chomp $line;

		if ($line eq "") {
			$queue{$id}{to} =~ s/,$//;
			if ($queue{$id}{to} =~ /\,/) {$expcnt++}
			$count++;
			$pos = 0;
			$id = 0;
			next;
		}

		if ($pos == 0) {
##			if ($line =~ /^\s*(\w+)\s+(\S*)\s+(\w{6}-\w{6}-\w{2})\s+(<.*?>)/) {
			if ($line =~ /^\s*(\w+)\s+(\S*)\s+(\S+)\s+(<.*?>)/) {
				my $time = $1;
				my $size = $2;
				$id = $3;
				my $from = $4;
				if ($from eq "<>") {$from = "[bounce]"; $queue{$id}{bounce} = "*"}
				$from =~ s/\<|\>//g;
				my $epoch = time;
				if ($time =~ /(\d+)(\w)/) {
					if ($2 eq "m") {$epoch -= $1 * 60}
					elsif ($2 eq "h") {$epoch -= $1 * 60 * 60}
					elsif ($2 eq "d") {$epoch -= $1 * 60 * 60 * 24}
				}
				$queue{$id}{epoch} = $epoch;
				$queue{$id}{from} = $from;
				$queue{$id}{time} = $time;
				$queue{$id}{size} = $size;
				$queuecnt++;
				if ($line =~ /\*\*\* frozen \*\*\*$/) {$queue{$id}{frozen} = "*"}
			}
		} else {
			$queue{$id}{to} .= "$line,";
		}
		$pos++;
	}
	waitpid ($cmdpid, 0);

	if ($storable eq "storable") {
		Storable::nstore(\%queue, "/etc/cmq/cmqstore");
		chmod(0600,"/etc/cmq/cmqstore");
	}

	return;
}
# end getqueue
###############################################################################
# start confirmmodal
#	print "<button type='button' class='btn btn-default confirmmodal' data-toggle='modal' data-target='#confirmmodal'>Submit</button>\n";
#	&confirmmodal("submit_name", "submit_value", "display text");
sub confirmmodal {
	my $name = shift;
	my $value = shift;
	my $text = shift;

	print "<div class='modal fade' id='confirmmodal' tabindex='-1' role='dialog'  aria-labelledby='myModalLabel' aria-hidden='true' data-backdrop='false' style='background-color: rgba(0, 0, 0, 0.5)'>\n";
	print "<div class='modal-dialog modal-sm'>\n";
	print "<div class='modal-content'>\n";
	print "<div class='modal-body'>\n";
	print "<h4>$text</h4>\n";
	print "</div>\n";
	print "<div class='modal-footer'>\n";
	print "<button type='submit' class='btn btn-success' name='$name' value='$value'>Yes - Continue</button>\n";
	print "<button type='button' class='btn btn-danger' data-dismiss='modal'>No - Cancel</button>\n";
	print "</div>\n";
	print "</div>\n";
	print "</div>\n";
	print "</div>\n";
	print  "<script>\n";
	print  "\$('button.confirmmodal').on('click', function(e) {\n";
	print  "});\n";
	print "\$('.modal').click(function(event){\n";
	print "  \$(event.target).modal('hide')\n";
	print "});\n";
	print  "</script>\n";
	return;
}
# end confirmmodal
###############################################################################
# start urlget (v1.3)
sub urlget {
	my $url = shift;
	my $file = shift;
	my $status = 0;
	my $timeout = 1200;
	local $SIG{PIPE} = 'IGNORE';

	use LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	$ua->timeout(30);
	my $req = HTTP::Request->new(GET => $url);
	my $res;
	my $text;

	($status, $text) = eval {
		local $SIG{__DIE__} = undef;
		local $SIG{'ALRM'} = sub {die "Download timeout after $timeout seconds"};
		alarm($timeout);
		if ($file) {
			$|=1; ## no critic
			my $expected_length;
			my $bytes_received = 0;
			my $per = 0;
			my $oldper = 0;
			open (my $OUT, ">", "$file\.tmp") or return (1, "Unable to open $file\.tmp: $!");
			binmode ($OUT);
			print "...0\%\n";
			$res = $ua->request($req,
				sub {
				my($chunk, $res) = @_;
				$bytes_received += length($chunk);
				unless (defined $expected_length) {$expected_length = $res->content_length || 0}
				if ($expected_length) {
					my $per = int(100 * $bytes_received / $expected_length);
					if ((int($per / 5) == $per / 5) and ($per != $oldper)) {
						print "...$per\%\n";
						$oldper = $per;
					}
				} else {
					print ".";
				}
				print $OUT $chunk;
			});
			close ($OUT);
			print "\n";
		} else {
			$res = $ua->request($req);
		}
		alarm(0);
		if ($res->is_success) {
			if ($file) {
				rename ("$file\.tmp","$file") or return (1, "Unable to rename $file\.tmp to $file: $!");
				return (0, $file);
			} else {
				return (0, $res->content);
			}
		} else {
			return (1, "Unable to download: ".$res->message);
		}
	};
	alarm(0);
	if ($@) {
		return (1, $@);
	}
	if ($text) {
		return ($status,$text);
	} else {
		return (1, "Download timeout after $timeout seconds");
	}
}
# end urlget
###############################################################################
## start printcmd
sub printcmd {
	my @command = @_;
	my ($childin, $childout);
	my $pid = open3($childin, $childout, $childout, @command);
	while (<$childout>) {print $_}
	waitpid ($pid, 0);
	return;
}
## end printcmd
###############################################################################
## start getdownloadserver
sub getdownloadserver {
	my @servers;
	my $downloadservers = "/etc/cmq/downloadservers";
	my $chosen;
	if (-e $downloadservers) {
		open (my $DOWNLOAD, "<", $downloadservers);
		flock ($DOWNLOAD, LOCK_SH);
		my @data = <$DOWNLOAD>;
		close ($DOWNLOAD);
		chomp @data;
		foreach my $line (@data) {
			if ($line =~ /^download/) {push @servers, $line}
		}
		$chosen = $servers[rand @servers];
	}
	if ($chosen eq "") {$chosen = "download.configserver.com"}
	return $chosen;
}
## end getdownloadserver
###############################################################################

1;
