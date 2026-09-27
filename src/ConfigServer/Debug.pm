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
#   @updated            09.27.2026
#   @linter             <ConfigServer::Linter>1.01:1:1:0:1:1:1:1:1
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
#   Declare › Package
# #

package ConfigServer::Debug;

# #
#   Declare › Use
# #

use strict;
use warnings;
use Encode ();
use Fcntl ();
use utf8 ();

# #
#	Declare › Colors
# #

my %C =
(
    reset               => "\e[0m",
    bold                => "\e[1m",
    dim                 => "\e[2m",
    white               => "\e[37m",
    greyl               => "\e[38;5;245m",
    greym               => "\e[90m",
    greyd               => "\e[38;5;236m",
    redl                => "\e[38;5;210m",
    redm                => "\e[38;5;203m",
    redd                => "\e[31m",
    purplel             => "\e[38;5;177m",
    purplem             => "\e[38;5;201m",
    purpled             => "\e[38;5;90m",
    bluel               => "\e[38;5;75m",
    bluem               => "\e[38;5;33m",
    blued               => "\e[38;5;25m",
    fucsial             => "\e[38;5;198m",
    fucsiam             => "\e[38;5;197m",
    fucsiad             => "\e[38;5;161m",
    orangel             => "\e[38;5;214m",
    orangem             => "\e[38;5;208m",
    oranged             => "\e[38;5;166m",
    yellowl             => "\e[38;5;229m",
    yellowm             => "\e[38;5;226m",
    yellowd             => "\e[38;5;220m",
    greenl              => "\e[38;5;120m",
    greenm              => "\e[32m",
    greend              => "\e[38;5;22m",

    strength_poor       => "\e[38;5;197m",
    strength_weak       => "\e[38;5;202m",
    strength_ok         => "\e[38;5;214m",
    strength_good       => "\e[38;5;184m",
    strength_strong     => "\e[38;5;47m",
    strength_excellent  => "\e[38;5;40m",
    strength_insane     => "\e[38;5;28m"
);

# #
#   Define › Constants › Internal
#   
#   DEBUG
#       Enables detailed STDERR outputs for this module.
#       DEBUG constant accepts value from 0 to 5:
#           0       Show normal logs
#           1       Show normal debug logs
#           2       Show verbose debug logs
#           3       Show trace debug logs
#           4       Show prolix debug logs
#           5       Show specialized logs
#   
#   @important  DEBUG messages NOT written to log files.
#               Sent to STDERR through warn().
#   
#   @note       The custom 'pre-commit' git hook will automatically
#               check to ensure constant DEBUG = 0 before it will
#               allow a git commit.
#   
#   @test       Note:           Manually override DEBUG constant
#               Command:        sudo env DEBUG=5 perl -I. -MConfigServer::Debug -e 'ConfigServer::Debug::log(5, q{info}, q{uid}, 974, q{gid}, 974, q{details}, q{before:[allow_root_own=0, gid=undef, mode=384, uid=974]});'
# #

use constant
{
    DEBUG                   => defined( $ENV{DEBUG} ) && $ENV{DEBUG} =~ /\A[0-5]\z/ ? 0 + $ENV{DEBUG} : 0,
    DEBUG_TRUNCATE_CHARS    => 50,
    DEBUG_SPACER_WIDTH      => 56,
    DEBUG_DUMP_NEST_MAX     => 7
};

# #
#   Declare › Redaction State
#   
#   Prevent debug messages made during redaction from being sent
#   through the redaction process again, which would cause recursion
#   over and over:
#       0       Debug output can run as normal
#       1       Redaction is active; suppress internal debug output
# #

our $debug_redaction_active = 0;

# #
#   Declare › Output State
#   
#   Prevent log() from running again while it is already
#   formatting another debug message.
# #

our $debug_output_active = 0;

# #
#	Declare › Status › Labels
#   
#   Map numeric and string log statuses to their display value.
#   Specifying a status when calling this sub is optional;
#   otherwise, default to 'info'.
#
#   Status may be supplied by name or number:
#       0       fail
#       1       ok
#       2       warn
#       3       abort
#       4       info
# #

my %STATUS_MAP =
(
    0       => 'FAIL',
    1       => 'OK',
    2       => 'WARN',
    3       => 'ABORT',
    4       => 'INFO',
    'fail'  => 'FAIL',
    'ok'    => 'OK',
    'warn'  => 'WARN',
    'abort' => 'ABORT',
    'info'  => 'INFO',
);

# #
#	Define › Status › Colors
#   
#   Colors associated with status labels defined in hash %STATUS_MAP
# #

my %STATUS_CLR =
(
    ok      => "\e[38;5;46m",
    fail    => "\e[38;5;196m",
    warn    => "\e[38;5;208m",
    abort   => "\e[38;5;198m",
    info    => "\e[38;5;33m",
);

# #
#   Debug › Log
#   
#   Prints detailed STDERR outputs for this module.
#   
#   DEBUG constant accepts value from 0 to 5:
#       0       Show normal logs
#       1       Show normal debug logs
#       2       Show verbose debug logs
#       3       Show trace debug logs
#       4       Show prolix debug logs
#       5       Show specialized logs
#   
#   Supports two output formats:
#       1.      Grouped value pairs                 (@test 1)
#       2.      Single message on one line          (@test 2)
#   
#   @usage      Single line; colored labels:
#               log( 1, 'warn',
#                   $C{bluem} .
#                   "name:[$name] len:[$name_bytes] " .
#                   "max:[" . SETTING_NAME_BYTE_MAXIMUM . "] status:[start]" .
#                   $C{reset}
#               );
#   
#   @important  DEBUG messages NOT written to any log files.
#               Sent to STDERR through warn().
# #

sub log
{
    my ( $level, @values ) = @_;

    return
        if ( DEBUG == 5 and $level != 5 ) or ( DEBUG != 5 and DEBUG < $level );

    return
        if $debug_redaction_active or $debug_output_active;

    local $debug_output_active = 1;

    my $caller      = ( caller( 1 ) )[ 3 ] // 'main';
    my $line_number = ( caller( 0 ) )[ 2 ] // 0;
    my $status      = 'info';

    if ( @values > 1 && defined( $values[ 0 ] ) && !ref( $values[ 0 ] ) )
    {
        my $requested_status = lc( "$values[ 0 ]" );
        if ( exists( $STATUS_MAP{$requested_status} ) )
        {
            shift @values;
            $status = $STATUS_MAP{$requested_status};
        }
    }

    my $clean_debug_value = sub
    {
        my ( $value ) = @_;

        return 'undef'
            if !defined( $value );

        return ref( $value )
            if ref( $value );

        $value                  = "$value";
        my $value_decoded_byte  = 0;
        if ( !utf8::is_utf8( $value ) and $value =~ /[\x80-\xFF]/ )
        {
            my $value_encoded = $value;
            my $value_decoded = eval
            {
                Encode::decode( 'UTF-8', $value_encoded, Encode::FB_CROAK( ) )
            };

            if ( defined( $value_decoded ) and !$@ )
            {
                $value              = $value_decoded;
                $value_decoded_byte = 1;
            }
        }

        my $value_is_wide = utf8::is_utf8( $value );

        $value =~ s/\x{001B}\][^\x{0007}]*(?:\x{0007}|\x{001B}\\)//g;
        $value =~ s{
            \x{001B}\[
            ([0-?]*[ -\/]*)
            ([@-~])
        }{
            $2 eq 'm' ? "\x{001B}[$1$2" : ''
        }gex;
    
        $value =~ s/\r\n|[\r\n\t\x{2028}\x{2029}]/ /g;
        $value =~ s/[\x{0000}-\x{0008}\x{000B}\x{000C}\x{000E}-\x{001A}\x{001C}-\x{001F}\x{007F}]//g;
        $value =~ s/\x{001B}(?!\[[0-?]*[ -\/]*m)//g;
        $value =~ s/[\x{0080}-\x{009F}]//g;
        $value =~ s/[\x{061C}\x{200E}\x{200F}\x{202A}-\x{202E}\x{2066}-\x{2069}]//g
            if $value_is_wide;

        return $value_decoded_byte ? Encode::encode_utf8( $value ) : $value;
    };

    my $caller_short    = $caller;
    $caller_short       =~ s/\A[^:]+:://;
    my $status_label    = "[$status]";

    my $header_plain    = "[$level]$status_label$caller_short:$line_number";
    my $header_padding  = ' ' x (
        length( $header_plain ) < DEBUG_SPACER_WIDTH
            ? DEBUG_SPACER_WIDTH - length( $header_plain )
            : 1
    );

    my $header  =   $C{bluem}       . "[$level]"    . $C{reset} .
                    $C{yellowm}     . $caller_short . $C{reset} .
                    $C{greyl}       . ":"           . $C{reset} .
                    $C{fucsial}     . $line_number  . $C{reset};

    if ( @values == 1 )
    {
        my $message         = $clean_debug_value->( $values[ 0 ] );

        if ( DEBUG != 5 )
        {
            require ConfigServer::Secrets;

            $message = ConfigServer::Secrets::redact_obj_log(
                $message,
            );
        }

        my $message_color   = $C{white};
        my $bracket_depth   = 0;

        while ( length( $message ) )
        {
            if ( $message =~ s/\A(\x{001B}\[[0-?]*[ -\/]*m)// )
            {
                $message_color .= $1;
                next;
            }

            my $char = substr( $message, 0, 1, '' );
            if ( $char eq '[' )
            {
                $bracket_depth++;

                $message_color .=
                    ( $bracket_depth == 1 ? $C{greym} : $C{white} ) .
                    '[' .
                    $C{orangem};

                next;
            }

            if ( $char eq ']' and $bracket_depth > 0 )
            {
                $message_color .=
                    ( $bracket_depth == 1 ? $C{greym} : $C{white} ) .
                    ']';

                $bracket_depth--;

                $message_color .= $bracket_depth > 0
                    ? $C{orangem}
                    : $C{white};

                next;
            }

            $message_color .= $char;
        }

        $message = $message_color . $C{reset};
        $message = Encode::encode_utf8( $message )
            if utf8::is_utf8( $message );

        warn(
            $header .
            ' ' .
            $C{reset} .
            $header_padding .
            $STATUS_CLR{ lc( $status ) } .
            $status_label .
            $C{reset} .
            $C{greyl} . ' => ' . $C{reset} .
            $message .
            "\n"
        );

        return;
    }

    my $out =
        $header .
        ' ' .
        $header_padding .
        $STATUS_CLR{ lc( $status ) } .
        $status_label .
        $C{reset} .
        $C{greyl} . ' => ' . $C{reset} .
        "GROUP" .
        "\n{\n";

    my $edge_len = DEBUG_TRUNCATE_CHARS;
    my @constants;

    while ( @values )
    {
        my $name = shift @values;

        if ( defined( $name ) and $name =~ /\A(?:\r\n|\r|\n)+\z/ )
        {
            $out .= $name;
            next;
        }

        $name       = $clean_debug_value->( $name );
        my $value   = $clean_debug_value->( shift @values );

        if ( DEBUG != 5 )
        {
            require ConfigServer::Secrets;

            $value = ConfigServer::Secrets::redact_obj_field(
                $name,
                $value,
            );

            $value = ConfigServer::Secrets::redact_obj_log(
                $value,
            );
        }

        $value = join( "\n",
            map
            {
                length( $_ ) > $edge_len * 2
                    ? substr( $_, 0, $edge_len ) .
                        ' ... ' . substr( $_, -$edge_len ) : $_
            }
            split( /\n/, $value, -1 )
        );

        my $display = utf8::is_utf8( $value ) ? Encode::encode_utf8( $value ) : $value;
        my $is_step = lc( $name ) eq 'step';

        my $is_constant = $name =~ /\A[A-Z][A-Z0-9_]*\z/;
        if ( $is_constant )
        {
            push @constants, [ $name, $display ];
            next;
        }

        my $no_dollar   = $is_step || $name =~ /\(\s*\)\z/;
        my $label       = $no_dollar ? ( $is_step ? ucfirst( $name ) : $name ) . ':' : "$name:";

        $out .= sprintf( "    %-28s%s\n", $label, $display );
    }

    if ( @constants )
    {
        $out .=
            "    " .
            $C{greyl} .
            "CONSTANTS:" .
            $C{reset} .
            "\n";

        $out .=
            "    " .
            $C{fucsial} .
            "{" .
            $C{reset} .
            "\n";

        for my $constant ( @constants )
        {
            my ( $name, $display ) = @{$constant};

            $out .= sprintf(
                "        %-24s%s\n",
                "$name:",
                $display,
            );
        }

        $out .=
            "    " .
            $C{fucsial} .
            "}" .
            $C{reset} .
            "\n";
    }

    $out .= "}\n\n";

    warn(
        utf8::is_utf8( $out ) ? Encode::encode_utf8( $out ) : $out
    );

    return;
}

# #
#   Debug › Get Options
#   
#   Convert a hash containing options into one single line for debug
#   output.
#   
#   (Optional) first param 'style' controls the output style:
#   
#       colon   key:[value]
#                   fields separated by spaces
#                   Eg: gid:[REDACTED] mode:[384] path:[/tmp/test]
#   
#       def     key=value
#                   fields separated by commas
#                   Default option
#                   Eg: gid=[REDACTED], mode=384, path=/tmp/test
#   
#   Lists are sorted differently depending on if a hash or array is
#   used.
#   
#       { } Hash ref:
#           Sort order not preserved.
#           getopts() sorts names alphabetically.
#   
#       [ ] Array ref:
#           Sort order preserved.
#   
#   @param      style           str         Style format, eg: 'colon'
#               opts            hashref     Hash to format
#   @return                     str         Hash values formatted on one line
# #

sub getopts
{
    my ( $style, $opts ) = @_;

    if ( @_ == 1 )
    {
        $opts   = $style;
        $style  = '';
    }

    $style = ''
        if !defined( $style );

    return "(invalid)"
        if ref( $style ) or ( $style ne '' and $style ne 'colon' );

    my @pairs;
    if ( ref( $opts ) eq 'HASH' )
    {
        return "(none)"
            if !keys( %{$opts} );

        for my $name ( sort keys( %{$opts} ) )
        {
            push @pairs, $name, $opts->{$name};
        }
    }

    elsif ( ref( $opts ) eq 'ARRAY' )
    {
        return "(none)"
            if !@{$opts};

        return "(invalid)"
            if @{$opts} % 2;

        @pairs = @{$opts};
    }

    else
    {
        return "(invalid)";
    }

    my @fields;
    while ( @pairs )
    {
        my $name    = shift( @pairs );
        my $value   = shift( @pairs );

        return "(invalid)"
            if !defined( $name ) or ref( $name );

        $value      = !defined( $value ) ? "undef" : ref( $value ) ? ref( $value ) : "$value";
        $value =~ s/[\r\n\t]+/ /g;

        push @fields,
            $style eq 'colon' ? $name . ':[' . $value . ']' : $name . '=' . $value;
    }

    return join( $style eq 'colon' ? ' ' : ', ', @fields );
}

# #
#   Debug › Dump
#   
#   Format values into a human readable debug dump.
#   
#   Dumbed down version of Data::Dumper, with a few extra things.
#   
#   Eg:         dump( $value );
#               dump( @values );
#   
#   @param      values          list        Input name/values to format
#   @return                     str         Formatted dump
# #

sub dump
{
    my ( @values ) = @_;

    my $value = !@values ? undef : @values == 1 ? $values[ 0 ] : \@values;
    return _debug_dump_value( $value ) . "\n";
}

# #
#   Debug › Dump › Value
#   
#   Convert a scalar, array, hash, or other objects into something
#   more human readable.
#   
#   @param      value           scalar      Input data to format
#               depth           int|undef   Current nesting level (used internally)
#                                               (int)       Nested recursive call
#                                               (undef)     Initial call (starts at 0)
#   @return                     str         Formatted dump
# #

sub _debug_dump_value
{
    my ( $value, $depth ) = @_;

    my $is_root = !defined( $depth );
    $depth = 0
        if $is_root;

    my $out;
    my $indent      = '    ' x $depth;
    my $indent_next = '    ' x ( $depth + 1 );

    if ( $depth >= DEBUG_DUMP_NEST_MAX )
    {
        $out = '...';
    }

    elsif ( !defined( $value ) )
    {
        $out = 'undef';
    }

    elsif ( !ref( $value ) )
    {
        $value = "$value";          # $value to text
        $value =~ s{\\}{\\\\}g;     # esc backslashes
        $value =~ s{'}{\\'}g;       # esc single quotes
        $value =~ s{\r}{\\r}g;      # show carriage returns => \r
        $value =~ s{\n}{\\n}g;      # show line breaks => \n
        $value =~ s{\t}{\\t}g;      # show tabs => \t

        if ( length( $value ) > DEBUG_TRUNCATE_CHARS * 2 )
        {
            $value =
                substr( $value, 0, DEBUG_TRUNCATE_CHARS ) .
                ' [...] ' .
                substr( $value, -DEBUG_TRUNCATE_CHARS );
        }

        $out = $value =~ /\A-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?\z/ ? $value : "'$value'";
    }

    elsif ( ref( $value ) eq 'HASH' )
    {
        my @lines;
        for my $name ( sort keys( %{$value} ) )
        {
            my $name_esc    = "$name";
            $name_esc       =~ s{\\}{\\\\}g;    # esc backslashes
            $name_esc       =~ s{'}{\\'}g;      # esc single quotes

            push @lines,
                $indent_next .
                "'$name_esc' => " .
                _debug_dump_value( $value->{$name}, $depth + 1 );
        }

        $out = @lines ? "{\n" . join( ",\n", @lines ) . "\n$indent}" : '{}';
    }

    elsif ( ref( $value ) eq 'ARRAY' )
    {
        my @lines = map
        {
            $indent_next . _debug_dump_value( $_, $depth + 1 )
        }
        @{$value};

        $out = @lines ? "[\n" . join( ",\n", @lines ) . "\n$indent]" : '[]';
    }

    elsif ( ref( $value ) eq 'SCALAR' or ref( $value ) eq 'REF' )
    {
        $out = '\\' . _debug_dump_value( ${$value}, $depth + 1 );
    }

    elsif ( ref( $value ) eq 'GLOB' )
    {
        my $file_number = fileno( $value );

        my %glob_info =
        (
            type            => 'GLOB',
            state           => defined( $file_number ) ? 'open' : 'closed',
            file_number     => $file_number,
            glob_name       => eval { *{$value}{NAME} },
            glob_package    => eval { *{$value}{PACKAGE} },
        );

        if ( defined( $file_number ) )
        {
            my $pos                     = tell( $value );
            $glob_info{pos}             = $pos >= 0 ? $pos : 'unavailable';
            $glob_info{is_terminal}     = -t $value ? 1 : 0;

            my $flag_cmd = eval { Fcntl::F_GETFL() };
            if ( defined( $flag_cmd ) )
            {
                my $flags = fcntl( $value, $flag_cmd, 0 );

                $glob_info{flags} = 0 + $flags
                    if defined( $flags );
            }

            my @status = stat( $value );
            if ( @status )
            {
                my $mode        = $status[ 2 ];
                my $file_type   = Fcntl::S_ISREG( $mode )  ? 'regular file'
                                    : Fcntl::S_ISDIR( $mode )  ? 'directory'
                                    : Fcntl::S_ISCHR( $mode )  ? 'character device'
                                    : Fcntl::S_ISBLK( $mode )  ? 'block device'
                                    : Fcntl::S_ISFIFO( $mode ) ? 'fifo'
                                    : Fcntl::S_ISSOCK( $mode ) ? 'socket'
                                    : 'unknown';

                $glob_info{file_type}       = $file_type;
                $glob_info{device}          = $status[ 0 ];
                $glob_info{inode}           = $status[ 1 ];
                $glob_info{mode}            = sprintf( '%06o', $mode );
                $glob_info{permissions}     = sprintf( '%04o', $mode & 07777 );
                $glob_info{links}           = $status[ 3 ];
                $glob_info{uid}             = $status[ 4 ];
                $glob_info{gid}             = $status[ 5 ];
                $glob_info{device_type}     = $status[ 6 ];
                $glob_info{size}            = $status[ 7 ];
                $glob_info{accessed}        = $status[ 8 ];
                $glob_info{modified}        = $status[ 9 ];
                $glob_info{changed}         = $status[ 10 ];
                $glob_info{block_size}      = $status[ 11 ];
                $glob_info{blocks}          = $status[ 12 ];
            }
        }

        $out = 'GLOB ' . _debug_dump_value( \%glob_info, $depth );
    }

    else
    {
        my $class = ref( $value );

        my $is_array = eval
        {
            my $index_last = $#{$value};
            1;
        };

        if ( $is_array )
        {
            my @lines = map
            {
                $indent_next . _debug_dump_value( $_, $depth + 1 )
            }
            @{$value};

            my $arr = @lines ? "[\n" . join( ",\n", @lines ) . "\n$indent]" : '[]';
            $out    = "bless( $arr, '$class' )";
        }
        else
        {
            $out    = "'$class'";
        }
    }

    return $is_root ? 'Dump = ' . $out . ';' : $out;
}

1;