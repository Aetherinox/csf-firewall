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
#   @updated            02.26.2026
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

ConfigServer::Perl::URI - Percent-encode and percent-decode unsafe characters

=head1 SYNOPSIS

 use ConfigServer::Perl::URI;
 $safe      = uri_escape( "10% is enough\n" );
 $verysafe  = uri_escape( "foo", "\0-\377" );
 $str       = uri_unescape( $safe );

=head1 DESCRIPTION

This module is an enhancement of the original perl URI::Escape which includes
o few bug-fixes.

This module provides functions to percent-encode and percent-decode URI strings as
defined by RFC 3986. Percent-encoding URI's is informally called "URI escaping".
This is the terminology used by this module, which predates the formalization of the
terms by the RFC by several years.

A URI consists of a restricted set of characters.  The restricted set
of characters consists of digits, letters, and a few graphic symbols
chosen from those common to most of the character encodings and input
facilities available to Internet users.  They are made up of the
"unreserved" and "reserved" character sets as defined in RFC 3986.

   unreserved    = ALPHA / DIGIT / "-" / "." / "_" / "~"
   reserved      = ":" / "/" / "?" / "#" / "[" / "]" / "@"
                   "!" / "$" / "&" / "'" / "(" / ")"
                 / "*" / "+" / "," / ";" / "="

In addition, any byte (octet) can be represented in a URI by an escape
sequence: a triplet consisting of the character "%" followed by two
hexadecimal digits.  A byte can also be represented directly by a
character, using the US-ASCII character for that octet.

Some of the characters are I<reserved> for use as delimiters or as
part of certain URI components.  These must be escaped if they are to
be treated as ordinary data.  Read RFC 3986 for further details.

The functions provided (and exported by default) from this module are:

=over 4

=item uri_escape( $string )

=item uri_escape( $string, $unsafe )

Replaces each unsafe character in the $string with the corresponding
escape sequence and returns the result.  The $string argument should
be a string of bytes.  The uri_escape() function will croak if given a
characters with code above 255.  Use uri_escape_utf8() if you know you
have such chars or/and want chars in the 128 .. 255 range treated as
UTF-8.

The uri_escape() function takes an optional second argument that
overrides the set of characters that are to be escaped.  The set is
specified as a string that can be used in a regular expression
character class (between [ ]).  E.g.:

  "\x00-\x1f\x7f-\xff"          # all control and hi-bit characters
  "a-z"                         # all lower case characters
  "^A-Za-z"                     # everything not a letter

The default set of characters to be escaped is all those which are
I<not> part of the C<unreserved> character class shown above as well
as the reserved characters.  I.e. the default is:

    "^A-Za-z0-9\-\._~"

The second argument can also be specified as a regular expression object:

  qr/[^A-Za-z]/

Any strings matched by this regular expression will have all of their
characters escaped.

=item uri_escape_utf8( $string )

=item uri_escape_utf8( $string, $unsafe )

Works like uri_escape(), but will encode chars as UTF-8 before
escaping them.  This makes this function able to deal with characters
with code above 255 in $string.  Note that chars in the 128 .. 255
range will be escaped differently by this function compared to what
uri_escape() would.  For chars in the 0 .. 127 range there is no
difference.

Equivalent to:

    utf8::encode($string);
    my $uri = uri_escape($string);

Note: JavaScript has a function called escape() that produces the
sequence "%uXXXX" for chars in the 256 .. 65535 range.  This function
has really nothing to do with URI escaping but some folks got confused
since it "does the right thing" in the 0 .. 255 range.  Because of
this you sometimes see "URIs" with these kind of escapes.  The
JavaScript encodeURIComponent() function is similar to uri_escape_utf8().

=item uri_unescape($string,...)

Returns a string with each %XX sequence replaced with the actual byte
(octet).

This does the same as:

   $string =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

but does not modify the string in-place as this RE would.  Using the
uri_unescape() function instead of the RE might make the code look
cleaner and is a few characters less to type.

In a simple benchmark test I did,
calling the function (instead of the inline RE above) if a few chars
were unescaped was something like 40% slower, and something like 700% slower if none were.  If
you are going to unescape a lot of times it might be a good idea to
inline the RE.

If the uri_unescape() function is passed multiple strings, then each
one is returned unescaped.

=back

The module can also export the C<%escapes> hash, which contains the
mapping from all 256 bytes to the corresponding escape codes.  Lookup
in this hash is faster than evaluating C<sprintf("%%%02X", ord($byte))>
each time.

=head1 SEE ALSO

L<URI>


=head1 COPYRIGHT

Copyright 1995-2004 Gisle Aas.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# #
#	@package		ConfigServer::Perl::URI
#	@desc			Modified version of the perl package URI::Escape with bug fixes.
#   
#   @ref			https://metacpan.org/pod/URI::Escape
#					https://raw.githubusercontent.com/libwww-perl/URI/185b40aabcef277d7dffdd2ba7c1c38f00302084/lib/URI/Escape.pm
#   
#   @usage			use ConfigServer::Perl::URI qw( uri_escape );
#					my $enc = uri_escape( "Config Server" );
#						# returns: Config%20Server
# #

## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef)
package ConfigServer::Perl::URI;

use strict;
use lib '/usr/local/csf/lib';
use Carp;

use Exporter    qw(import);
our $VERSION    = '5.36';
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw(uri_escape uri_escape_utf8 uri_unescape escape_char %escapes);

# #
#	Build char › hex map
# #

our %escapes;
for ( 0..255 )
{
	$escapes{chr( $_ )} = sprintf( "%%%02X", $_ );
}

my %subst;
my %Unsafe = (
	RFC2732 => qr/[^A-Za-z0-9\-_.!~*'()]/,
	RFC3986 => qr/[^A-Za-z0-9\-\._~]/,
);

# #
#   Perl › URI › Escape
#	
#   Percent-encoder from the original URI::Escape module. Supports optional 
#	second arg to specify which chars to escape (as regex char class or compiled qr//).
#	Terminates on error with chars > 255 (like multi-byte Unicode character); 
#	use uri_escape_utf8() for wide chars.
#	
#	@package	ConfigServer::Perl::URI
#   @usage      use ConfigServer::Perl::URI qw(uri_escape);
#				my $enc = uri_escape( "Config Server" );
#					# returns: Config%20Server
#				my $enc = uri_escape( "hello", "a-z" );
#					# returns: %68%65%6C%6C%6F
#   @scope      public
#   @param      text        str         			string to encode
#   @param      patn        str|regex   			(optional) chars to escape
#   @return                 str         			percent-encoded string
# #

sub uri_escape
{
    my($text, $patn) = @_;
    return undef unless defined $text;

    my $re;
    if ( defined $patn )
	{
        if ( ref $patn eq 'Regexp' )
		{
            $text =~ s{($patn)}{
                join('', map +($escapes{$_} || _failure_Escape($_)), split //, "$1")
            }ge;
            return $text;
        }

        $re = $subst{$patn};
        if ( !defined $re )
		{
            $re = $patn;
	
			# #
            #	escape [] characters, except for those used in posix classes.
			#	if prefixed by backslash, allow them through unmodified.
			# #
	
            $re =~ s{(\[:\w+:\])|(\\)?([\[\]]|\\\z)}{
                defined $1 ? $1 : defined $2 ? "$2$3" : "\\$3"
            }ge;
            eval
			{
				# #
                #	disable warnings, since they will trigger later when used.
				#	Only allow them to appear once per call, but every time the
				#	same pattern is used.
				# #

                no warnings 'regexp';
                $re = $subst{$patn} = qr{[$re]};
                1;
            }
		    or Carp::croak( "uri_escape: $@" );
        }
    }
    else
	{
        $re = $Unsafe{RFC3986};
    }

    $text =~ s/($re)/$escapes{$1} || _failure_Escape($1)/ge;
    $text;
}

# #
#   Perl › URI › Fail
#	
#   Internal error handler. Croaks when uri_escape encounters a character
#	with a code point > 255 that cannot be percent-encoded as a single byte.
#	
#	@package	ConfigServer::Perl::URI
#   @scope      local
# #

sub _failure_Escape
{
    my $chr = shift;
    Carp::croak( sprintf "Can't escape \\x{%04X}, try uri_escape_utf8() instead", ord( $chr ) );
}

# #
#   Perl :: URI › Escape UTF8
#	
#   Encodes wide characters to UTF-8 bytes, then percent-encodes the result.
#	Safe for strings containing characters > 255. Accepts the same optional
#	second argument as uri_escape().
#	
#	@package	ConfigServer::Perl::URI
#   @usage      use ConfigServer::Perl::URI qw(uri_escape_utf8);
#				my $enc = uri_escape_utf8( "caf\x{e9}" );
#					# returns: caf%C3%A9
#   @scope      public
#   @param      text        str         			string to encode
#   @param      patn        str|regex   			(optional) chars to escape
#   @return                 str         			percent-encoded string
# #

sub uri_escape_utf8
{
    my $text = shift;
    return undef unless defined $text;

    utf8::encode( $text );
    return uri_escape( $text, @_ );
}

# #
#   Perl › URI › Unescape
#	
#   Decodes percent-encoded strings. Replaces each %XX sequence with the
#	corresponding byte. Accepts multiple strings in list context.
#	
#	@package	ConfigServer::Perl::URI
#   @usage      use ConfigServer::Perl::URI qw(uri_unescape);
#				my $str = uri_unescape( "foo%20bar" );
#					# returns: foo bar
#				my @decoded = uri_unescape( "a%20b", "c%20d" );
#					# returns: ("a b", "c d")
#   @scope      public
#   @param      str         str         			one or more percent-encoded strings
#   @return                 str|list    			decoded string(s)
# #

sub uri_unescape
{
	# #
    #	RFC1630:
	#		"Sequences which start with a percent sign but are not followed by
	#		two hexadecimal characters are reserved for future extension"
	#	
	#	@ref		https://datatracker.ietf.org/doc/html/rfc1630
	# #

    my $str = shift;
    if ( @_ && wantarray )
	{
        my @str = ( $str, @_ );
        for ( @str )
		{
            s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
        }

        return @str;
    }

    $str =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg if defined $str;
    $str;
}

# #
#   Perl › URI › Escape Char
#	
#   Percent-encode every byte in a string, including unreserved chars.
#	Unlike uri_escape() which preserves safe chars (A-Z, 0-9, etc); this
#	encodes everything. Handles UTF-8 flagged strings safely.
#	
#	@package	ConfigServer::Perl::URI
#   @usage      use ConfigServer::Perl::URI qw(escape_char);
#				my $enc = escape_char( "abc" );
#					# returns: %61%62%63
#   @scope      public
#   @param      str         str         			string to encode
#   @return                 str         			fully percent-encoded string
# #

sub escape_char
{
	my ( $str ) = @_;
	return '' unless defined $str;
	utf8::encode( $str ) if utf8::is_utf8( $str );
	return join '', map { $escapes{$_} } split //, $str;
}

1;
