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
#   @updated            11.07.2026
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
#   
#   @commands       Load module directly:
#                       sudo perl -I. ConfigServer/Validate.pm
#   
#                   Check module for syntax errors:
#                       sudo  perl -I. -c ConfigServer/Validate.pm
#   
#                   Module docs:
#                       perldoc -T ConfigServer/Validate.pm
#   
#                   Run test suite:
#                       sudo prove -I. -v tests/Validate.t
# #

=head1 NAME

C<ConfigServer::Validate> - Validate CSF and LFD input fields and
normalize text used in firewall rules, stored comments, and logs.

=head1 COMMANDS

=over 4

=item *

Load module:

    sudo perl -I. ConfigServer/Validate.pm

=item *

Check module for syntax errors:

    sudo perl -I. -c ConfigServer/Validate.pm

=item *

Display module documentation:

    perldoc -T ConfigServer/Validate.pm

=item *

Run test suite:

    Linux:      sudo prove -I. -v tests/Validate.t
    Windows:    prove -Isrc -v tests/Validate.t

=back

=head1 COPYRIGHT

Copyright (C) 2025-2027.

This program is free software; you may redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or (at
your option) any later version.

=cut

# #
#   Declare › Package
# #

package ConfigServer::Validate;

# #
#   Declare › Use
# #

use strict;
use warnings;
use Encode ( );
use Math::BigInt ( );
use Net::IP ( );
use Exporter qw( import );

# #
#   Declare › Export
# #

our @EXPORT_OK = qw(
	resolve_username
	validate_filter_chars
	validate_port
	validate_owner
	validate_username
);

# #
#   Declare › Version
# #

our $VERSION = 15.11;

# #
#   Declare › Constants
#   
#   COMMENT_BYTES_DEFAULT
#       Default bytes allowed for comment when custom $opts{bytes_max}
#       arg not specified.
#       If comment exceeds this number, validation fails.
#   
#   COMMENT_BYTES_MAX
#       Max bytes allowed when custom arg $opts{bytes_max} specified.
#       If $opts{bytes_max} exceeds this value, validation fails.
#   
#   PREFIX_LENGTH_MAX
#       Max allowed length of rule prefix.
#       
#   USERNAME_LENGTH_MAX
#       Max allowed length of username.
#       
#   USERNAME_VALUE_REGEX
#       Regex allowed for usernames.
#   
#   OWNER_LENGTH_MAX
#       Max length of chars for one valid owner field.
#           (account name, group name, uid, gid).
#       Names longer than 256 chars returns 0 (invalid).
#   
#   OWNER_ID_DIGIT_MAX
#       Max number of digits if uid or gid is int only.
#   
#           Eg: $uid = 9876543210;  # accepted
#               $uid = 98765432101; # denied
#   
#   OWNER_ID_VALUE_MAX
#       Max value if uid or gid is int only.
#   
#           Eg: $uid = 4294967294;  # accepted
#               $uid = 4294967295;  # denied
#   
#   PORT_LENGTH_MAX
#       Max length of chars for one valid port.
#   
#   PORT_MULTIPORT_OPT_MAX
#       Total number of individual ports that can be listed in a 
#       single call using --multiport.
#   
#       Note:   Iptables --multiport allows max of 15 ports passed in
#               a single command. Port ranges (port:port) count as two
#               ports. Can only be used in conjunction with the protos:
#                   tcp, udp, udplite, dccp and sctp.
#   
#   PORT_VALUE_MAX
#       Max allowed numeric port value. Limit does not apply to
#       service names like "sshd".
#   
#           Eg: $port = 65535;  # accepted
#               $port = 65536;  # denied
#   
#   PORT_VALUE_REGEX
#       Regex to match allowed chars for a port.
#       Hhyphen not allowed as first char.
#   
#   TEXT_FRAG_BYTES_MIN
#       Min number of bytes allowed for custom $opts{bytes_max} text
#       limit. Allows enough bytes to keep one complete utf8 char.
#   
#       Prevents normalize_text_fragment() from returning only [...].
#   
#       If value specified in $opts{bytes_max} is less than the value
#       TEXT_FRAG_BYTES_MIN, then TEXT_FRAG_BYTES_DEFAULT will be used.
#   
#           Eg: normalize_text_fragment( "abcdef", bytes_max => 1 );
#                   returns "abcdef"
#               normalize_text_fragment( "abcdef", bytes_max => 4 );
#                   returns "abcd [...]"
#   
#   TEXT_FRAG_BYTES_DEFAULT
#       Default number of bytes allowed when custom $opts{bytes_max}
#       is not specified. Anything over limit is truncated. Truncate
#       marker does not count toward limit.
#   
#           Eg: normalize_text_fragment( "Server address" );
#               returns "Server address"
#   
#   TEXT_FRAG_BYTES_MAX
#       Max number of bytes allowed for custom $opts{bytes_max} text 
#       limit. Higher value uses TEXT_FRAG_BYTES_DEFAULT instead.
#       Truncation marker does not count toward limit.
#   
#           Eg: normalize_text_fragment( "B" x 31, bytes_max => 10 );
#               returns "BBBBBBBBBB [...]"
#   
#   TEXT_FRAG_INPUT_CHARS_MAX
#       Max number of chars read when text already decoded.
#       Used automatically when Perl stores text as unicode text.
#   
#           Eg: normalize_text_fragment( "é" x ( TEXT_FRAG_INPUT_CHARS_MAX + 1 ) );
#   
#   TEXT_FRAG_INPUT_BYTES_MAX
#       Max number of bytes kept when text has not been decoded.
#       Up to 3 extra bytes may be read to finish one utf8 char.
#   
#           Eg: normalize_text_fragment( "A" x ( TEXT_FRAG_INPUT_BYTES_MAX + 1 ) );
#       
#   TEXT_FRAG_TRUNC_MARKER
#       When text is too long, truncate the text and place a marker at
#       the end to indicate it was truncated.
#   
#           Eg: (Before)    "CSF FIREWALLLLLLLLLLLLLLLLL"
#               (After)     "CSF FIREWALL [...]"
#   
#   TEXT_UNSAFE_CHARS_REGEX
#       Match control chars, invisible formatting, and line separators.
#       Used to validate / cleaning text.
#   
#   TEXT_UNTAINT_REGEX
#       If Perl runs with -T taint mode, capture already validated or
#       normalized text, so that $1 returns a copy without taint flag.
#       Captures all chars, does not validate or filter text.
# #

use constant
{
	COMMENT_BYTES_DEFAULT       => 512,
	COMMENT_BYTES_MAX           => 4 * 1024,
	PREFIX_LENGTH_MAX           => 1 * 1024,
	USERNAME_LENGTH_MAX         => 256,
    USERNAME_VALUE_REGEX        => qr/\A([A-Za-z0-9_.][A-Za-z0-9_.-]*\$?)\z/,
	OWNER_LENGTH_MAX            => 256,
	OWNER_ID_DIGIT_MAX          => 10,
	OWNER_ID_VALUE_MAX          => 4_294_967_294,
	PORT_LENGTH_MAX             => 128,
	PORT_MULTIPORT_OPT_MAX      => 15,
    PORT_VALUE_MAX              => 65_535,
	PORT_VALUE_REGEX            => qr{\A[A-Za-z0-9_,:/][A-Za-z0-9_,:/-]*\z},
    TEXT_FRAG_BYTES_MIN         => 4,
    TEXT_FRAG_BYTES_DEFAULT     => 512,
	TEXT_FRAG_BYTES_MAX         => 6 * 1024,
	TEXT_FRAG_INPUT_CHARS_MAX   => 16 * 1024,
	TEXT_FRAG_INPUT_BYTES_MAX   => 64 * 1024,
    TEXT_FRAG_TRUNC_MARKER      => "[...]",
    TEXT_UNSAFE_CHARS_REGEX     => qr/[\x{0000}-\x{001F}\x{007F}-\x{009F}\x{2028}-\x{2029}\p{Cf}]+/,
    TEXT_UNTAINT_REGEX          => qr/\A(.*)\z/s,
};

# #
#   Validate › Text › Decode
#   
#   Decode utf8 bytes, check text already decoded.
#   Return error instead of accepting bad input.
#   
#   @params     value           str         Text or utf8 bytes
#   @return     text            str|undef   Decoded text / undef on error
#               error           str|undef   Error message / undef on success
# #

sub _text_decode
{
	my ( $text ) = @_;

	return ( undef, "Text to decode must be type scalar" )
		if !defined( $text ) or ref( $text );

	my $is_unicode      = utf8::is_utf8( $text );
	my $flags_strict    = Encode::LEAVE_SRC( ) | Encode::FB_CROAK( );
	my $output          = $text;
	my $is_valid;

	{
		local $SIG{__DIE__};
		local $@;

		$is_valid = eval
		{
			Encode::encode( "UTF-8", $text, $flags_strict )
				if $is_unicode;

			$output = Encode::decode( "UTF-8", $text, $flags_strict )
				if !$is_unicode;

			1;
		};
	}

	if ( !$is_valid )
	{
		my $err = $is_unicode ? "Text not valid unicode" : "Text not valid utf8";
		return ( undef, $err );
	}

	return ( $output, undef );
}

# #
#   Validate › Port
#   
#   Check if input is valid port number or string service name.
#   Does not check advanced filter rule syntax:
#       "tcp|out|d=22|d=11.22.33.44|u=root"
#   
#   Eg:         validate_port( "22" )           # returns 1
#               validate_port( "22;test" )      # returns 0
#               validate_port( "ssh" )          # returns 1
#   
#   @note       IPTABLES --multiport: This module matches a set of src
#               or dest ports. --multiport allows up to 15 ports to be
#               specified. Port ranges (port:port) count as two ports.
#               Can only be used in conjunction with one of the
#               following protos:
#                   tcp, udp, udplite, dccp and sctp.
#   
#               Ref:            https://man7.org/linux/man-pages/man8/iptables-extensions.8.html
#   
#   @params     port            str         Port field
#   @return     is_valid        int         Validate result
#                                               1           Valid
#                                               0           Invalid
# #

sub validate_port
{
	my ( $port ) = @_;

	return 0
		if !defined( $port ) or ref( $port ) or $port eq "";

	return 0
		if length( $port ) > PORT_LENGTH_MAX;

	return 0
		if $port !~ PORT_VALUE_REGEX;

	return 0
		if grep { $_ eq "" } split( /,/, $port, -1 );

	if ( $port =~ /,/ )
	{
		my $multiport_i = 0;
		for my $port_item ( split( /,/, $port ) )
		{
			$multiport_i += $port_item =~ /[:_]/ ? 2 : 1;
		}

        # allow 15 multiport_i max
		return 0
			if $multiport_i > PORT_MULTIPORT_OPT_MAX;
	}

	my $port_max = "" . PORT_VALUE_MAX;
	for my $port_part ( split( /[,_:\/]/, $port, -1 ) )
	{
		next
			if $port_part !~ /\A[0-9]+\z/;

		my $port_num    = $port_part;
		$port_num       =~ s/\A0+//;
		$port_num       = "0"
                        if $port_num eq "";

		return 0
			if length( $port_num ) > length( $port_max ) or
			   (
					length( $port_num ) == length( $port_max ) and
					$port_num gt $port_max
			   );
	}

	return 1;
}

# #
#   Validate > Owner ID
#   
#   Check if $id is valid numeric uid or gid.
#   Does not actually check if uid or gid exists on the server.
#   
#   @params     id              scalar      Numeric uid or gid
#   @return     is_valid        int         Validation result
#                                               1           Valid
#                                               0           Invalid
# #

sub _owner_id_valid
{
	my ( $id ) = @_;

	return 0
		if !defined( $id ) or ref( $id ) or $id !~ /\A[0-9]+\z/;

	return 0
		if length( $id ) > OWNER_ID_DIGIT_MAX;

	my $id_max = "" . OWNER_ID_VALUE_MAX;
	return 0
		if length( $id ) == OWNER_ID_DIGIT_MAX and $id gt $id_max;

	return 1;
}

# #
#   Validate › Owner
#   
#   Check if input is valid uid, gid, account name, or group name.
#   
#   Does not check if account / group actually exists.
#   Does not check advanced filter rule syntax:
#       "tcp|out|d=22|d=11.22.33.44|u=root"
#   
#   Eg:         validate_owner( "aether-long-name" )    # return 1; skip 10 digit check; validates name chars
#               validate_owner( "974" )                 # return 1; apply numeric id limits
#               validate_owner( "4294967294" )          # return 1; match OWNER_ID_VALUE_MAX
#               validate_owner( "4294967295" )          # return 0; above OWNER_ID_VALUE_MAX
#               validate_owner( "0" )                   # return 1
#   
#   @note       Account name regex based on:
#               Ref:    https://github.com/shadow-maint/shadow/blob/master/lib/chkname.c
#                       https://wiki.debian.org/UserAccountsPhilosophy
#   
#   @params     owner           str         Owner field
#   @return     is_valid        int         Validate result
#                                               1           Valid
#                                               0           Invalid
# #

sub validate_owner
{
	my ( $owner ) = @_;

	return 0
		if !defined( $owner ) or ref( $owner ) or $owner eq "";

	return 0
		if length( $owner ) > OWNER_LENGTH_MAX;

	return 0
		if $owner eq "." or $owner eq "..";

	if ( $owner =~ /\A[0-9]+\z/ )
	{
		return _owner_id_valid( $owner );
	}

    # #
    #   Allow $ at the end (Samba machine accounts)
    #   
    #   @ref        https://github.com/shadow-maint/shadow/blob/master/lib/chkname.c
    # #

	return 0
		if $owner !~ USERNAME_VALUE_REGEX;

	return 1;
}

# #
#   Validate › Username
#   
#   Check if input is valid string username.
#   Does not validate if username exists on system as account.
#   
#   @note       Account name regex based on:
#               Ref:    https://github.com/shadow-maint/shadow/blob/master/lib/chkname.c
#                       https://wiki.debian.org/UserAccountsPhilosophy
#   
#               Fully numeric usernames, and '.' or '..' disallowed.
#               Usernames may only be up to 256 chars long.
#               Ref:    https://man7.org/linux/man-pages/man8/useradd.8.html
#   
#   @params     user            str         Sys account name
#   @return                     str|undef   Validated sys account name
#                                               str         Valid account name
#                                               undef       Invalid
# #

sub validate_username
{
	my ( $user ) = @_;

	return undef
		if !defined( $user ) or ref( $user ) or $user eq "";

	return undef
		if length( $user ) > USERNAME_LENGTH_MAX;

	return undef
		if $user eq "." or $user eq ".." or $user =~ /\A[0-9]+\z/;

    # #
    #   Allow $ at the end (Samba machine accounts)
    #   
    #   @ref        https://github.com/shadow-maint/shadow/blob/master/lib/chkname.c
    # #

	return $user =~ USERNAME_VALUE_REGEX ? $1 : undef;
}

# #
#   Validate › Username › Resolve
#   
#   Check if input is valid username (as string), then validate the
#   username on the system using getpwnam() by locating the account's
#   system assigned uid and gid.
#   
#   $findcb     optional    callback can replace getpwnam() with
#                           custom username lookup sub.
#   
#   @note       Account name regex based on:
#               https://github.com/shadow-maint/shadow/blob/master/lib/chkname.c
#   
#   @params     user            str             Valid existing workstation user
#               findcb          coderef|undef   (Optional) callback to replace username lookup getpwnam()
#   @return     username        str|undef       Verified account name or undef
#                                                   str             account name if valid / exists
#                                                   undef           lookup failed
# #

sub resolve_username
{
	my ( $user, $findcb ) = @_;

	my $username = validate_username( $user );
	return
		if !defined( $username );

	return
		if defined( $findcb ) and ref( $findcb ) ne "CODE";

	my @res;
	my $find_ok = eval
	{
		local $SIG{__DIE__};
		@res = defined( $findcb ) ? $findcb->( $username ) : getpwnam( $username );
		1;
	};

	return
		if !$find_ok;

	my ( $username_resolved, undef, $uid, $gid ) = @res;
	return
		if !defined( $username_resolved ) or ref( $username_resolved ) or
			!defined( $uid ) or ref( $uid ) or !defined( $gid ) or ref( $gid );

	return
		if $username_resolved ne $username;

	return
		if !_owner_id_valid( $uid ) or !_owner_id_valid( $gid );

	return $username;
}

# #
#   Validate › Filter Prefix Rule
#   
#   Check that firewall rule prefix has only allowed chars and doesn't
#   exceed max length.
#   
#   This checks only the accepted chars and length; does NOT validate
#   the rule's syntax.
#   
#   Eg:         validate_filter_chars( undef )                  # return 1
#               validate_filter_chars( "tcp:in:d=80:s=" )       # return 1
#               validate_filter_chars( "tcp in d=80" )          # return 0
#               validate_filter_chars( "tcp:in;d=80" )          # return 0
#               validate_filter_chars( undef, required => 1 );  # return 0
#   
#   @note       Allow Chars:        A-Z a-z 0-9 _ , . : | = / -
#               Disallow Chars:     No spaces, No semicolons
#   
#   @params     prefix          str|undef       Rule
#               opts            hash            (Optional) Additional options
#                   required                        Reject undefined rule
#   @return     is_valid        int             Validate Result
#                                                   1           Valid or unused
#                                                   0           Invalid
# #

sub validate_filter_chars
{
	my ( $rule, %opts ) = @_;

	my $opt_required = delete( $opts{required} ) // 0;

	my ( $opt_unknown ) = sort keys %opts;
	return 0
		if defined( $opt_unknown );

	return 0
		if $opt_required and !defined( $rule );

	return 1
		if !defined( $rule );

	return 0
		if ref( $rule ) or length( $rule ) > PREFIX_LENGTH_MAX;

    # allowed chars (see @note)
	return 0
		if $rule !~ m{\A[A-Za-z0-9_,.:/|=][A-Za-z0-9_,.:/|=-]*\z};

	return 1;
}

# #
#   Validate › Client › Comment
#   
#   Check a client / user comment before it is processed.
#   
#   Used when adding a new IP to csf.allow / csf.deny:
#       sudo csf --deny 1.2.3.4 "Valid deny IP rule"
#   
#   Eg:         validate_client_comment( "CSF comment test" )               # (pass); return "CSF comment test",undef
#               validate_client_comment( "Bad\ncomment" )                   # (fail); return undef,"Comment cannot have control character"
#               validate_client_comment( "Bad;comment" )                    # (fail); return undef,"Comment cannot have reserved delimiters"
#               validate_client_comment( "12345678901", bytes_max => 10 )   # (fail); return undef,"Comment bytes oversized"
#                                                                               Comment bytes exceeds bytes_max limit.
#               validate_client_comment( "Test", bytes_max => COMMENT_BYTES_MAX + 1 )  # (fail); return undef,"Comment has invalid size limit"
#                   bytes_max exceeds COMMENT_BYTES_MAX limit.
#   
#   @note       Disallow Chars:     ';', '|', '\n\t\f\r', etc.
#               Optionally reject leading '#' with $opts{no_leading_hash} => 1
#   
#   @params     comment         str|undef       Client/user comment
#               opts            hash            (Optional) Additional options
#                   ascii_only                      Reject non ascii chars
#                   bytes_max                       Max allowed comment bytes
#                   details                         Include safe details in error msgs
#                   no_leading_hash                 Reject # as first non whitespace char
#                   required                        Reject empty or whitespace only comment
#   
#   @return     comment         str|undef       Valid utf8 bytes or undef on error
#               error           str|undef       Error message or undef on success
# #

sub validate_client_comment
{
	my ( $comment, %opts ) = @_;

	my ( $comment_text, $decode_err ) = _text_decode( $comment // "" );
	return ( undef, $decode_err )
		if defined( $decode_err );

	my $opt_ascii_only      = delete( $opts{ascii_only} )       // 0;
	my $opt_bytes_max       = delete( $opts{bytes_max} )        // COMMENT_BYTES_DEFAULT;
	my $opt_details         = delete( $opts{details} )          // 0;
	my $opt_no_leading_hash = delete( $opts{no_leading_hash} )  // 0;
	my $opt_required        = delete( $opts{required} )         // 0;

	my ( $opt_unknown ) = sort keys %opts;
	if ( defined( $opt_unknown ) )
	{
		my $unknown_err     = $opt_details
                                ? "Comment has unknown option: $opt_unknown"
                                : "Comment has unknown option";

		return ( undef, $unknown_err );
	}

	my $bytes_limit_err     = $opt_details
                                ? "Comment byte limit must be from 1 to " . COMMENT_BYTES_MAX
                                : "Comment has invalid byte size limit";

	return ( undef, $bytes_limit_err )
		if ref( $opt_bytes_max ) or $opt_bytes_max !~ /\A[1-9][0-9]*\z/ or
		   $opt_bytes_max > COMMENT_BYTES_MAX;

	# Reject control chars, invisible formatting, and line separators
	return ( undef, "Comment cannot have control chars" )
		if $comment_text =~ TEXT_UNSAFE_CHARS_REGEX;

	return ( undef, "Comment cannot have reserved delimiters ';' or '|'" )
		if $comment_text =~ /[;|]/;

	return ( undef, "Comment cannot be empty; ('opt:required')" )
		if $opt_required and $comment_text =~ /\A\s*\z/;

	return ( undef, "Comment cannot start with # hash char ('opt:no_leading_hash')" )
		if $opt_no_leading_hash and $comment_text =~ /\A\s*#/;

	return ( undef, "Comment must only use ascii chars; ('opt:ascii_only')" )
		if $opt_ascii_only and $comment_text =~ /[^\x{0000}-\x{007F}]/;

	my $comment_bytes       = Encode::encode( "UTF-8", $comment_text, Encode::LEAVE_SRC( ) | Encode::FB_CROAK( ) );
	my $comment_bytes_len   = length( $comment_bytes );
	my $comment_size_err    = $opt_details
                                ? "Comment is $comment_bytes_len bytes, maximum is $opt_bytes_max bytes"
                                : "Comment bytes oversized";

	return ( undef, $comment_size_err )
		if $comment_bytes_len > $opt_bytes_max;

	my ( $comment_out ) = $comment_bytes =~ TEXT_UNTAINT_REGEX;
	return ( $comment_out, undef );
}

# #
#   Validate › Text › Fragment
#   
#   Return normalized string of text to append to existing logs. Used
#   for ip rule comments, log messages, etc.
#   
#   Disallowed chars        => single space
#   Multiple whitespace     => single space
#   Empty, undef, ref       => "Unavailable"
#   Truncate text exceeding byte limit with marker "[...]"
#   
#   Disallow:   Control chars, tabs, line breaks, invisible formatting
#               chars, line / paragraph separators.
#               '#', ';', '|', leading/trailing whitespace.
#   
#   Eg:         normalize_text_fragment( "Server addr" )                # return "Server addr"
#               normalize_text_fragment( "Bad;val" )                    # return "Bad val"
#               normalize_text_fragment( "abcdef", bytes_max => 4 )     # return "abcd [...]"
#               normalize_text_fragment( undef )                        # return "Unavailable"
#   
#   @params     text            scalar|undef    Text fragment
#               opts            hash            (Optional) Additional options
#                   bytes_max                       Max allowed bytes for text
#   @return     text            scalar          Normalized utf8 byte string
# #

sub normalize_text_fragment
{
	my ( $text, %opts ) = @_;

	my $flags_strict    = Encode::LEAVE_SRC( ) | Encode::FB_CROAK( );
	my $trunc_marker    = TEXT_FRAG_TRUNC_MARKER;
	my $trunc_suffix    = " " . $trunc_marker;
	my $bytes_max       = TEXT_FRAG_BYTES_DEFAULT;
	my $req_max         = $opts{bytes_max};
	my $is_truncated    = 0;

	if ( defined( $req_max ) and !ref( $req_max ) and
		$req_max =~ /\A([1-9][0-9]*)\z/ and
		$1 >= TEXT_FRAG_BYTES_MIN and
		$1 <= TEXT_FRAG_BYTES_MAX )
	{
		$bytes_max = $1;
	}

	my $output = "";
	if ( defined( $text ) and !ref( $text ) )
	{
		my $is_unicode  = utf8::is_utf8( $text );
		my $input_max   = $is_unicode ? TEXT_FRAG_INPUT_CHARS_MAX : TEXT_FRAG_INPUT_BYTES_MAX;
        
		my ( $decoded_txt, $decode_err );

		if ( length( $text ) > $input_max )
		{
			$is_truncated = 1;

			if ( $is_unicode )
			{
				my $input                       = substr( $text, 0, $input_max );
				( $decoded_txt, $decode_err )   = _text_decode( $input );
			}
			else
			{
				# read up to 3 extra bytes to finish one utf8 char
				for my $extra_bytes ( 0 .. 3 )
				{
					my $input = substr( $text, 0, $input_max + $extra_bytes );
					( $decoded_txt, $decode_err ) = _text_decode( $input );

					next
						if defined( $decode_err );

					chop $decoded_txt
						if $extra_bytes;

					last;
				}
			}
		}
		else
		{
			( $decoded_txt, $decode_err ) = _text_decode( $text );
		}

		$output = $decoded_txt
			if !defined( $decode_err );
	}

    # #
    #   Replace control chars, invisible formatting, line seps,
	#   reserved delimiters with one space (x{0020})
    # #
    
	$output =~ s/@{[ TEXT_UNSAFE_CHARS_REGEX ]}/\x{0020}/g;
	$output =~ s/[#;|]+/\x{0020}/g;     # replace # ; | with single space
	$output =~ s/\s+/\x{0020}/g;        # replace multiple whitespace with one space
	$output =~ s/\A\s+|\s+\z//g;        # remove whitespace (start and end)

    # #
    #   No output
    # #

	$output = "Unavailable"
                if $output eq "";

	my $output_bytes = Encode::encode( "UTF-8", $output, $flags_strict );
	$is_truncated = 1
		if length( $output_bytes ) > $bytes_max;

	if ( $is_truncated )
	{
		if ( length( $output_bytes ) > $bytes_max )
		{
			my $prefix_byte = substr( $output_bytes, 0, $bytes_max );
			my $flags_quiet = Encode::FB_QUIET( ) | Encode::LEAVE_SRC( );
			$output         = Encode::decode( "UTF-8", $prefix_byte, $flags_quiet );
		}

		$output =~ s/\s+\z//;
		$output = $output eq "" ? $trunc_marker : $output . $trunc_suffix;
	}

	$output_bytes = Encode::encode( "UTF-8", $output, $flags_strict );
	return $output_bytes =~ TEXT_UNTAINT_REGEX ? $1 : undef;
}

1;