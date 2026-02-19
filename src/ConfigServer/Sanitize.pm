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
#   @updated            02.19.2026
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
## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef)
package ConfigServer::Sanitize;

use strict;
use lib '/usr/local/csf/lib';

use Exporter qw(import);
our $VERSION	= 1.00;
our @ISA		= qw(Exporter);
our @EXPORT_OK	= qw(html_safe html_escape);

# #
#   Sanitize › HTML › Whitelisted Tags / Attribs
#	
#	Tag only (attrib => 1)		allow tags only; no attribs.
#	Tags w/ attrib hash			allow tags with specific attribs.
#	
#	@usage		b => 1,							'bold' tag alloweed; no attribs allowed
#				span => { class => 1 },			'span' tag allowed; 'class' attrib allowed
# #

my %allowed_tags = (
	b		=> 1,
	u		=> 1,
	i		=> 1,
	em		=> 1,
	strong	=> 1,
	code	=> 1,
	span	=> { class => 1 },
);

# #
#   Sanitize › HTML › Escape
#	
#	When displaying information on the settings page; certain settings may contain
#	html for emphasis. 
#	
#	This sub escapes html sensitive chars ( &, <, > ), and ensures only certain 
#		tags and attribs are allowed. onclick, onerror, etc are stripped.
#	After filtering the setting description, only the safe tags and attribs remain.
#	
#   @usage      my $safe = html_safe( $unsafe_html );
#   @scope      public
#   @param      line        str                     text to sanitize
#   @return                 str                     sanitized text
# #

sub html_safe
{
    my ($line) = @_;

	# #
    #	escape
	# #

    $line =~ s/&/&amp;/g;
    $line =~ s/</&lt;/g;
    $line =~ s/>/&gt;/g;

	# #
    #	restore allowed tags
	# #

    foreach my $tag ( keys %allowed_tags )
	{
		my $allowed = $allowed_tags{$tag};
		
		if ( ref($allowed) eq 'HASH' )
		{
			# #
			#	tag: allow specific attribs
			#	
			#	Regex sub; run replacement code
			# #
			
			$line =~ s{&lt;($tag)(\s+[^&]+?)&gt;}{
				my $tagname			= $1;
				my $attrib_escape	= $2;

				# unescape the attribs portion to parse
				$attrib_escape =~ s/&amp;/&/g;
				$attrib_escape =~ s/&lt;/</g;
				$attrib_escape =~ s/&gt;/>/g;
				$attrib_escape =~ s/&quot;/"/g;

				# extract safe attribs
				my @attrib_safe;
				while ( $attrib_escape =~ /(\w+)\s*=\s*["']([^"']*)["']/g )
				{
					my ( $attr_name, $attr_val ) = ( lc($1), $2 );

					# skip dangerous attribs
					next if $attr_name =~ /^on/i;                    # event handlers
					next if $attr_name eq 'style';                   # css injection
					next if $attr_name eq 'href' && $attr_val =~ /^\s*javascript:/i;
					next if $attr_name eq 'src' && $attr_val =~ /^\s*javascript:/i;

					# only allow whitelisted attributes for this tag
					if ( $allowed->{$attr_name} )
					{
						# escape the value for safe output
						$attr_val =~ s/"/&quot;/g;
						push @attrib_safe, qq{$attr_name="$attr_val"};
					}
				}

				if ( @attrib_safe )
				{
					'<' . $tagname . ' ' . join(' ', @attrib_safe) . '>';
				}
				else
				{
					'<' . $tagname . '>';
				}
			}gei;
		}
		else
		{
			# #
			#	unescape opening tags with no attribs.
			#		&lt;tagname&gt; => <tagname>
			# #
			
			$line =~ s/&lt;($tag)&gt;/<$1>/gi;
		}
		
		# #
		#	unescape closing tags with no attribs.
		#		&lt;/tagname&gt; => </tagname>
		# #

		$line =~ s/&lt;\/($tag)&gt;/<\/$1>/gi;
    }

    return $line;
}

# #
#   Sanitize › HTML › Escape
#	
#   Escape html before output.
#	Utilized to output setting descriptions on "Firewall Configuration" page where html can
#		be present.
#   
#   @usage      my $safe_html = html_escape( $untrusted );
#   
#   @param      text        str         html to escape
#   @return                 str         escaped text safe for HTML attributes
# #

sub html_escape
{
    my ($text) = @_;
    return '' unless defined $text;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&quot;/g;
    $text =~ s/'/&#39;/g;
    return $text;
}

1;
