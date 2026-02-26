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
#   @updated            02.25.2026
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

=head1 NAME

ConfigServer::Sanitize - Sanitize strings and html output

=head1 TESTING

Compare uri_escape implementations:

	perl -I "/usr/local/csf/lib" -e '
	use ConfigServer::Sanitize ();
	use ConfigServer::Perl::URI ();

	my $test = "sanitize=config&server fw";

	print "Sanitize: " . ConfigServer::Sanitize::uri_escape($test) . "\n";
	print "URI:      " . ConfigServer::Perl::URI::uri_escape($test) . "\n";

	print(
		ConfigServer::Sanitize::uri_escape($test)
			eq ConfigServer::Perl::URI::uri_escape($test)
		? "MATCH\n"
		: "MISMATCH\n"
	);
	'


=cut

# #
#	@package		ConfigServer::Sanitize
#	@desc			In-house uri_sanitize
# #

## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef)
package ConfigServer::Sanitize;

use strict;
use lib '/usr/local/csf/lib';
use Carp;

use Exporter 		qw(import);
our $VERSION 		= '5.35';
our @ISA			= qw(Exporter);
our @EXPORT_OK		= qw(html_safe html_escape uri_escape);

# #
#   Sanitize › HTML › Whitelisted Tags / Attribs
#	
#	Tag only (attrib => 1)		allow tags only; no attribs.
#	Tags w/ attrib hash			allow tags with specific attribs.
#	
#	@assoc		ConfigServer::Sanitize::html_safe
#	@usage		b => 1,							'bold' tag alloweed; no attribs allowed
#				span => { class => 1 },			'span' tag allowed; 'class' attrib allowed
# #

my %HTML_WHITELIST_TAGS = (
	b		=> 1,
	u		=> 1,
	i		=> 1,
	em		=> 1,
	strong	=> 1,
	code	=> 1,
	span	=> { class => 1 },
);

# #
#   Sanitize › HTML › Safe
#	
#	When displaying information on the settings page; certain settings may contain 
#	html for emphasis.  
#	 
#	Escapes html sensitive chars ( &, <, > ), and ensures only certain  
#		tags and attribs are allowed. onclick, onerror, etc are stripped. 
#	Restores tags / attribs listed in HTML_WHITELIST_TAGS
#	
#	@package	ConfigServer::Sanitize
#   @usage      my $safe = html_safe( "<b>bold</b> <script>alert(1)</script>" );
#					# returns: <b>bold</b> &lt;script&gt;alert(1)&lt;/script&gt;
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

    foreach my $tag ( keys %HTML_WHITELIST_TAGS )
	{
		my $allowed = $HTML_WHITELIST_TAGS{$tag};
		
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
#   Escape all HTML-sensitive chars (&, <, >, ", ') into their entity variant.
#	Unlike html_safe(), no tags are restored; everything is escaped.
#	
#	@assoc		ConfigServer::Sanitize::html_escape
#	@package	ConfigServer::Sanitize
#   @usage      my $safe = html_escape( '<script>alert(1)</script>' );
#					# returns: &lt;script&gt;alert(1)&lt;/script&gt;
#   @scope      public
#   @param      text        str        				html to escape
#   @return                 str         			escaped text safe for HTML attributes
# #

my %HTML_ESCAPE_MAP = (
	'&' => '&amp;',
	'<' => '&lt;',
	'>' => '&gt;',
	'"' => '&quot;',
	"'" => '&#39;'
);

sub html_escape
{
    my ( $text ) = @_;
    return '' unless defined $text;
    return $text if $text !~ tr/&<>"'//;

    $text =~ s/([&<>"'])/$HTML_ESCAPE_MAP{$1}/sg;

    return $text;
}

# #
#   Sanitize › URI › Escape
#	
#   Percent-encode strings for use in URI. All chars except RFC 3986 
#	unreserved chars (A-Za-z0-9 - . _ ~) are encoded as %XX hex pairs.
#	Handles UTF-8 flagged strings by encoding to bytes first.
#	
#   In-house replacement for perl package URI::Escape::uri_escape; no external deps.
#	
#	@package	ConfigServer::Sanitize
#	@ref		https://metacpan.org/pod/URI::Escape
#				https://raw.githubusercontent.com/libwww-perl/URI/185b40aabcef277d7dffdd2ba7c1c38f00302084/lib/URI/Escape.pm
#   @usage      use ConfigServer::Sanitize qw(uri_escape);
#					my $encoded = uri_escape( "configserver=foo&bar" );
#					# returns: configserver%3Dfoo%26bar
#   @scope      public
#   @param      str         str         			string to encode
#   @return                 str         			percent-encoded string
# #

sub uri_escape
{
	my ( $str ) = @_;
	return undef unless defined $str;

	utf8::encode( $str ) if utf8::is_utf8( $str );
	$str =~ s/([^A-Za-z0-9\-\.\_\~])/sprintf( "%%%02X", ord( $1 ) )/ge;

	return $str;
}

1;
