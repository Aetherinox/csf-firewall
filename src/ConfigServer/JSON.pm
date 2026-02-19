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
## no critic (RequireUseWarnings, ProhibitExplicitReturnUndef, ProhibitMixedBooleanOperators, RequireBriefOpen)
package ConfigServer::JSON;

use strict;
use lib '/usr/local/csf/lib';
use Carp;
use IPC::Open3;
use ConfigServer::Config;

use Exporter qw(import);
our $VERSION     = 1.07;
our @ISA         = qw(Exporter);
our @EXPORT_OK   = qw(decode_json encode_json);

# #
#   Security Values
#   
#   All of these have been defined based on our usage. Should not need to be 
#   increased in the near future. 
#   
#   MAX_DEPTH               Max nesting depth; prevent stack overflow from malicious input.
#                               default: 64
#   
#   MAX_SIZE                Max input size (bytes); prevent memory exhaustion.
#                               default: 10MB
#   
#   MAX_STRING_LEN          Max string length (characters); prevent memory exhaustion from single strings.
#                               default: 1,000,000
#   
#   MAX_KEYS                Max keys per object; prevent hash collision / memory exhaustion.
#                               default: 10,000
#   
#   MAX_ARRAY_LEN           Max elements per array; prevent array bomb attacks.
#                               default: 100,000
# #

our $MAX_DEPTH = 64;
our $MAX_SIZE = 10 * 1024 * 1024;
our $MAX_STRING_LEN = 1_000_000;
our $MAX_KEYS = 10_000;
our $MAX_ARRAY_LEN = 100_000;

# #
#   JSON Module
#   
#   Most modern distros can use perl's JSON module. However, since we support VestaCP which uses
#   CentOS 7; certain installs will not include the JSON module.
#   
#   This module utilized as an alternative. (See below):
#   
#   JSON            Recommended perl module; automatically selects the best available backend.
#                       Priority: JSON::XS => JSON::PP
#   JSON::XS        C-accelerated implementation; faster.
#   JSON::PP        Perl implementation; bundled with Perl cores (since Perl 5.14); portable 
#                       fallback for envs where JSON::XS cannot be utilized.
#   JSON::MaybeXS   Alternative wrapper module
#   
#   @usage          (1)     use ConfigServer::JSON qw( encode_json decode_json );
#                           my $licenseJson = encode_json( $licenseObj );
#                   (2)     my $licenseJson = ConfigServer::JSON->encode_json( $licenseObj );
#   @ref            https://perldoc.perl.org/JSON::PP
#                   https://docs.activestate.com/activeperl/5.26/perl/JSON/PP.html
#                   https://metacpan.org/pod/JSON
#                   https://perldoc.perl.org/functions/scalar
# #

# #
#   JSON › Decode
#	
#   Parse json string, return data structure.
#	
#   @usage      my $data = decode_json( '{ "name": "ConfigServer", "license": "xxxx-xxxx-xxx-xxxx"}' );
#               print $data->{name};  # "ConfigServer"
#   
#   @scope      public
#   @param      json        str                     json-encoded str
#   @return                 mixed
# #

sub decode_json
{
    my ($json)  = @_;
    return undef unless defined $json && length $json;

    # reject oversized input
    if ( length($json) > $MAX_SIZE )
    {
        carp "JSON: Input exceeds max size limit ($MAX_SIZE bytes)";
        return undef;
    }

    # strip utf8 BOM if exists (EF BB BF)
    # @ref:     https://en.wikipedia.org/wiki/Byte_order_mark
    if ( substr( $json, 0, 3 ) eq "\xEF\xBB\xBF" )
    {
        $json = substr( $json, 3 );
    }

    my $pos     = 0;
    my $depth   = 0;
    my $res     = _decodeValue( \$json, \$pos, \$depth );                       # pass references

    return undef unless defined $res;                                           # error occurred in parsing

    _skipWs( \$json, \$pos );                                                   # ensure no trailing crap other than whitespace

    if ( $pos < length( $json ) )
    {
        carp "JSON: Unexpected data near end of decoded JSON at position $pos";
        return undef;
    }

    return $res;
}

# #
#   JSON › _decodeValue
#	
#   Run the correct decoder based on chars provided.
#   Supports        str, obj, array, bool, null, num
#   
#   @scope      local
#   @param      json        scalarref               ref to json str
#               pos         scalarref               ref to current parse pos
#               depth       scalarref               ref to nesting depth
#   @return                 mixed
# #

sub _decodeValue
{
    my ( $json, $pos, $depth ) = @_;

    _skipWs( $json, $pos );

    # out of bounds
    if ( $$pos >= length( $$json ) )
    {
        carp "JSON: Unexpected end of input when decoding value";
        return undef;
    }

    my $char = substr( $$json, $$pos, 1 );

    return _decodeStr( $json, $pos ) if $char eq '"';                           # str: starts with double quote
    return _decodeObj( $json, $pos, $depth) if $char eq '{';                    # obj: starts with opening brace
    return _decodeArr( $json, $pos, $depth) if $char eq '[';                    # array: starts with opening bracket

    # bool: return 1 if true
    if ( substr( $$json, $$pos, 4 ) eq 'true' )
    {
        $$pos += 4;
        return 1;
    }

    # bool: return 0 if false
    if ( substr( $$json, $$pos, 5 ) eq 'false' )
    {
        $$pos += 5;
        return 0;
    }

    # null: return empty hashref for null (distinguishes from error)
    if ( substr( $$json, $$pos, 4 ) eq 'null' )
    {
        $$pos += 4;
        return { _null => 1 };
    }

    # num: return decoded num (0-9 or minus sign)
    if ( $char =~ /^[-0-9]$/ )
    {
        return _decodeNum( $json, $pos );
    }

    carp "JSON: Unexpected character '$char' at position $$pos";
    return undef;
}

# #
#   JSON › _skipWs
#	
#   Advance parser pos past json whitespace chars.
#   Whitespace      space ( ) (0x20), tab (\t) (0x09), newline (\n) (0x0A), carriage return (\r) (0x0D)
#   
#   @scope      local
#   @param      json        scalarref               ref to json str
#               pos         scalarref               ref to current parse pos
#   @return                 void
# #

sub _skipWs
{
    my ( $json, $pos ) = @_;
    while ( $$pos < length( $$json ) &&  index( " \t\n\r", substr( $$json, $$pos, 1 ) ) >= 0 )
    {
        $$pos++;
    }
}

# #
#   JSON › _decodeStr
#	
#   Parse json str, handle escape sequences.
#   Escape          \", \\, \/, \b, \f, \n, \r, \t, \uXXXX
#   
#   @scope          local
#   @param          json        scalarref               ref to json str
#                   pos         scalarref               ref to current parse pos
#   @return                     str                     decoded str
# #

sub _decodeStr
{
    my ( $json, $pos ) = @_;

    $$pos++;
    my $str = '';

    while ( $$pos < length( $$json ) )
    {
        my $char = substr( $$json, $$pos, 1 );

        # end of str
        if ( $char eq '"' )
        {
            $$pos++;

            # check string length limit
            if ( length( $str ) > $MAX_STRING_LEN )
            {
                carp "JSON: String exceeds max length limit ($MAX_STRING_LEN characters)";
                return undef;
            }

            return $str;
        }

        # escape sequence
        if ( $char eq '\\' )
        {
            $$pos++;

            if ( $$pos >= length( $$json ) )
            {
                carp "JSON: Unexpected end of string escape during decode";
                return undef;
            }

            my $esc = substr( $$json, $$pos, 1 );
            $$pos++;

            if    ( $esc eq 'n' )   { $str .= "\n"; }
            elsif ( $esc eq 'r' )   { $str .= "\r"; }
            elsif ( $esc eq 't' )   { $str .= "\t"; }
            elsif ( $esc eq 'b' )   { $str .= "\b"; }
            elsif ( $esc eq 'f' )   { $str .= "\f"; }
            elsif ( $esc eq '\\' )  { $str .= '\\'; }
            elsif ( $esc eq '"' )   { $str .= '"'; }
            elsif ( $esc eq '/' )   { $str .= '/'; }
            elsif ( $esc eq 'u' )
            {
                # Unicode escape: \uXXXX
                if ( $$pos + 4 > length( $$json ) )
                {
                    carp "JSON: Invalid unicode escape during decode";
                    return undef;
                }

                my $hex = substr( $$json, $$pos, 4 );
                if ( $hex !~ /^[0-9a-fA-F]{4}$/ )
                {
                    carp "JSON: Invalid unicode escape '\\u$hex' during decode";
                    return undef;
                }

                $$pos   += 4;
                $str    .= chr( hex( $hex ) );
            }
            else
            {
                carp "JSON: Invalid escape sequence '\\$esc' during decode";
                return undef;
            }
        }

        # reject unescaped control chars; r => \r; first non-printable char is 0x20 ' '
        elsif ( ord( $char ) < 0x20 )
        {
            carp "JSON: Unescaped control character at position $$pos during decode";
            return undef;
        }
        else
        {
            $str .= $char;
            $$pos++;
        }
    }

    carp "JSON: Unterminated string";
    return undef;
}

# #
#   JSON › _decodeNum
#	
#   Parse json num values.
#   
#   @scope          local
#   @param          json        scalarref               ref to json str
#                   pos         scalarref               ref to current parse pos
#   @return                     num                     decoded num
# #

sub _decodeNum
{
    my ( $json, $pos ) = @_;
    my $start = $$pos;

    # minus sign: advance pos
    if ( substr( $$json, $$pos, 1 ) eq '-' )
    {
        $$pos++;
    }

    # leading zero: 01, 02 not allowed; advance pos.
    my $first_digit = substr( $$json, $$pos, 1 );
    if ( $first_digit eq '0' )
    {
        $$pos++;
    }

    # leading num: (1-9); no leading 0; look for additional numbers
    elsif ( $first_digit =~ /^[1-9]$/ )
    {
        $$pos++;
        while ( $$pos < length( $$json ) && substr( $$json, $$pos, 1 ) =~ /^[0-9]$/ )
        {
            $$pos++;
        }
    }

    # not a valid num
    else
    {
        carp "JSON: Invalid number at position $start";
        return undef;
    }

    # decimal points: check if num is floating point; sasve decimal pos; look for trailing nums
    if ( $$pos < length( $$json ) && substr( $$json, $$pos, 1 ) eq '.' )
    {
        $$pos++;

        # starting point of decimal
        my $dec_pos = $$pos;
        while ( $$pos < length( $$json ) && substr( $$json, $$pos, 1 ) =~ /^[0-9]$/ )
        {
            $$pos++;
        }

        # no nums following decimal point
        if ( $$pos == $dec_pos )
        {
            carp "JSON: Invalid number - decimal point must be followed by digits";
            return undef;
        }
    }

    # exponents: 1e10, 3.14E-2, etc.
    if ( $$pos < length( $$json ) && substr( $$json, $$pos, 1 ) =~ /^[eE]$/ )
    {
        $$pos++;

        # sign: + or -
        if ($$pos < length( $$json ) && substr( $$json, $$pos, 1 ) =~ /^[+-]$/ )
        {
            $$pos++;
        }

        my $exp_pos = $$pos;
        while ( $$pos < length( $$json ) && substr( $$json, $$pos, 1 ) =~ /^[0-9]$/ )
        {
            $$pos++;
        }

        if ( $$pos == $exp_pos )
        {
            carp "JSON: Invalid number - exponent must have digits";
            return undef;
        }
    }

    my $num_str = substr( $$json, $start, $$pos - $start );

    # check for extreme exponents that could cause issues
    if ( $num_str =~ /[eE][+-]?(\d+)/ && $1 > 308 )
    {
        carp "JSON: Number exponent too large (max 308)";
        return undef;
    }

    return 0 + $num_str;
}

# #
#   JSON › _decodeObj
#	
#   Parse json object to hashref.
#       { "key": value, ... }
#   
#   @scope      local
#   @param      json        scalarref               ref to json str
#               pos         scalarref               ref to current parse pos
#               depth       scalarref               ref to current nesting depth
#   @return                 hashref                 decoded hash ref
# #

sub _decodeObj
{
    my ( $json, $pos, $depth ) = @_;

    # dont allow max depth to be exceeded
    $$depth++;
    if ( $$depth > $MAX_DEPTH )
    {
        carp "JSON: Max nesting depth exceeded: $MAX_DEPTH";
        return undef;
    }

    $$pos++;

    my %hash;
    my $key_count = 0;
    _skipWs( $json, $pos );

    # empty object
    if ( substr( $$json, $$pos, 1 ) eq '}' )
    {
        $$pos++;
        $$depth--;

        return \%hash;
    }

    while (1)
    {
        # check key count limit
        $key_count++;
        if ( $key_count > $MAX_KEYS )
        {
            carp "JSON: Object exceeds max key limit ($MAX_KEYS)";
            return undef;
        }

        _skipWs( $json, $pos );
    
        # key should be a string
        if ( substr( $$json, $$pos, 1 ) ne '"' )
        {
            carp "JSON: Expected string key at position $$pos";
            return undef;
        }

        my $key = _decodeStr( $json, $pos );
        return undef unless defined $key;

        _skipWs( $json, $pos );

        # expect colon after key
        if ( substr( $$json, $$pos, 1 ) ne ':' )
        {
            carp "JSON: Expected ':' after object key at position $$pos";
            return undef;
        }

        $$pos++;

        # decoded val
        my $val = _decodeValue( $json, $pos, $depth );
        return undef unless defined $val;
        $hash{$key} = $val;

        _skipWs( $json, $pos );

        my $char = substr( $$json, $$pos, 1 );
        $$pos++;

        if ( $char eq '}' )
        {
            $$depth--;
            return \%hash;
        }
        elsif ( $char ne ',' )
        {
            carp "JSON: Expected ',' or '}' in object at position " . ( $$pos - 1 );
            return undef;
        }
    }
}

# #
#   JSON › _decodeArr
#	
#   Parse json array to arrayref.
#       [ value, ... ]
#   
#   @scope      local
#   @param      json        scalarref               ref to json str
#               pos         scalarref               ref to current parse pos
#               depth       scalarref               ref to current nesting depth
#   @return                 arrayref                decoded array ref
# #

sub _decodeArr
{
    my ( $json, $pos, $depth ) = @_;

    $$depth++;
    if ( $$depth > $MAX_DEPTH )
    {
        carp "JSON: Max nesting depth exceeded for arrayref during decode: $MAX_DEPTH";
        return undef;
    }

    $$pos++;
    my @arr;

    _skipWs( $json, $pos );

    # array is empty
    if ( substr( $$json, $$pos, 1 ) eq ']' )
    {
        $$pos++;
        $$depth--;

        return \@arr;
    }

    while (1)
    {
        # check array length limit
        if ( scalar( @arr ) >= $MAX_ARRAY_LEN )
        {
            carp "JSON: Array exceeds max element limit ($MAX_ARRAY_LEN)";
            return undef;
        }

        my $val = _decodeValue( $json, $pos, $depth );
        return undef unless defined $val;
        push @arr, $val;

        _skipWs( $json, $pos );

        my $char = substr( $$json, $$pos, 1 );
        $$pos++;

        if ( $char eq ']' )
        {
            $$depth--;
            return \@arr;
        }
        elsif ( $char ne ',' )
        {
            carp "JSON: Expected ',' or ']' in array at position " . ( $$pos - 1 );
            return undef;
        }
    }
}

# #
#   JSON › encode_json
#	
#   Convert perl data struct to json str.
#   
#   Mapping:
#       hashref         :   json obj
#       arrayref        :   json arr
#       scalarref to 1  :   true
#       scalarref to 0  :   false
#       undef           :   null
#       number          :   json num
#       string          :   json str
#   
#   @usage          my $csfJson = encode_json( { name => "ConfigServer", valid => \1 } );
#                   { "name":"ConfigServer","valid":true }
#   
#   @scope      public
#   @param      data        mixed                   scalar, arrayref, or hashref
#   @return                 str                     encoded json str
# #

sub encode_json
{
    my ($data)  = @_;
    my $depth   = 0;

    return _encodeVal( $data, \$depth );
}

# #
#   JSON › _encodeVal
#	
#   Recursively encode val to json.
#   
#   @scope      local
#   @param      val             mixed               value to encode
#               depth           scalarref           reference to current nesting depth
#   @return     str                                 json
# #

sub _encodeVal
{
    my ( $val, $depth ) = @_;
    return 'null' unless defined $val;

    my $ref = ref $val;

    # scalarref to json bool
    if ( $ref eq 'SCALAR' )
    {
        return $$val ? 'true' : 'false';
    }

    # arrayref to json array str
    if ( $ref eq 'ARRAY' )
    {
        $$depth++;
        if ( $$depth > $MAX_DEPTH )
        {
            carp "JSON: Max nesting depth exceeded for arrayref during encode: $MAX_DEPTH";
            return 'null';
        }

        my $result = '[' . join( ',', map { _encodeVal( $_, $depth ) } @$val) . ']';
        $$depth--;

        return $result;
    }

    # hashref to json object str
    if ( $ref eq 'HASH' )
    {
        $$depth++;
        if ( $$depth > $MAX_DEPTH )
        {
            carp "JSON: Max nesting depth exceeded for hashref during encode: $MAX_DEPTH";
            return 'null';
        }

        my @pairs;
        for my $k ( sort keys %$val )
        {
            push @pairs, _encodeStr( $k ) . ':' . _encodeVal( $val->{$k}, $depth );
        }

        $$depth--;

        return '{' . join( ',', @pairs ) . '}';
    }
    
    # reject any other types
    if ( $ref )
    {
        carp "JSON: Cannot encode reference type: '$ref'";
        return 'null';
    }

    # num: int/floats without leading zeros
    if ( $val =~ /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$/ )
    {
        # must be real num; not a str num
        no warnings 'numeric';
        if ( $val + 0 eq $val )
        {
            return $val;
        }
    }

    return _encodeStr( $val );
}

# #
#   JSON › _encodeStr
#	
#   Encode a string to output to json, escape special chars.
#   
#   @scope      local
#   @param      str         str                     str to encode
#   @return     str                                 escaped str
# #

sub _encodeStr
{
    my ( $str ) = @_;

    $str =~ s/\\/\\\\/g;      # backslash
    $str =~ s/"/\\"/g;        # double quotes
    $str =~ s/\n/\\n/g;       # newline
    $str =~ s/\r/\\r/g;       # carriage return
    $str =~ s/\t/\\t/g;       # tab
    $str =~ s/\f/\\f/g;       # form feed
    $str =~ s/\x08/\\b/g;     # backspace

    # escape rest of chars as \uXXXX
    $str =~ s/([\x00-\x1f])/sprintf('\\u%04x', ord($1))/ge;

    return qq{"$str"};
}

1;