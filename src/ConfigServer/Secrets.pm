# #
#   @app                ConfigServer Security & Firewall (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.dev
#   @docs               https://docs.configserver.dev
#   @download           https://download.configserver.dev
#   @repo               https://github.com/Aetherinox/csf-firewall
#   @copyright          Copyright (C) 2025-2027 Aetherinox
#                       Copyright (C) 2006-2025 Jonathan Michaelson
#                       Copyright (C) 2006-2025 Way to the Web Ltd.
#   @license            GPLv3
#   @updated            10.27.2026
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

C<ConfigServer::Secrets> - Detect, protect, and redact secret
values used by ConfigServer Security & Firewall.

=head1 SYNOPSIS

=over 4

=item *

Load module:

    use ConfigServer::Secrets ( );

=item *

Register a secret value for redaction:

    ConfigServer::Secrets::register_secret(
        "API_KEY", "secret-api-key"
    );

=item *

Read a protected file as separate lines:

    my @lines = ConfigServer::Secrets::read_lines(
        "/etc/csf/csf.conf",
        max_lines => 1_000,
    );

=item *

Redact sensitive values from text:

    my $safe_text = ConfigServer::Secrets::redact_obj_str(
        "Login failed using secret-api-key"
    );

=over 4

B<Note>: C<read_file()> and C<read_lines()> support Linux only.

=back

=back

=head1 SUMMARY

The following is a list outlining the main features of this module,
and the most important notes to take into consideration.

=over 4

=item *

Register one or multiple secrets at a time, including secrets from a
config hash. Registered secret values are redacted:

    ConfigServer::Secrets::register_secret(
        "API_KEY", "secret-api-key"
    );

    my %config = (
        UI_PASS     => "secret-password",
        API_SECRET  => "secret-api-secret",
    );

    ConfigServer::Secrets::register_secrets( \%config );

=item *

Redact secrets in plain text, log messages, config data, colon
separated records, command options, XML, etc.

=item *

Create a snapshot of a file before and after it is read for secrets.

If the file's size, owner, perms, hardlinks, mod time, or other file 
details change during the read, abort the operation.

=item *

Detect known secret CSF settings in config data, log messages, and
plain text. Known settings include:

=over 4

=item *

AT_PASSWD

=item *

CFAPIKEY

=item *

CLUSTER_KEY

=item *

MM_LICENSE_KEY

=item *

SPONSOR_LICENSE

=item *

RECAPTCHA_SECRET

=item *

ST_MYSQL_PASS

=item *

UI_PASS

=back

Eg:

    Before:     UI_PASS=secret-password
    After:      UI_PASS=[REDACTED]

=item *

Detect and redact values when their setting names end with known 
secret suffixes which include:

=over 4

=item *

API_KEY, APIKEY

=item *

ACCESS_KEY, ACCESSKEY, ACCESS_TOKEN, ACCESSTOKEN, REFRESH_TOKEN,
REFRESHTOKEN, ID_TOKEN, IDTOKEN, TOKEN, SECRET, KEY

=item *

CLIENT_SECRET, CLIENTSECRET

=item *

PRIVATE_KEY, PRIVATEKEY, SIGNATURE

=item *

AUTH, AUTHORIZATION, AUTH_KEY, CREDENTIAL

=item *

PASSWORD, PASSWD, PASSPHRASE, PWD

=item *

LICENSE, LICENSE_KEY, LICENSEKEY

=item *

JWT, AWSACCESSKEYID, X_AMZ_SIGNATURE, X_AMZ_CREDENTIAL

=back


Eg:

    Before:     CLOUDFLARE_API_KEY=secret-api-key
    After:      CLOUDFLARE_API_KEY=[REDACTED]

    Before:     DATABASE_PASSWORD=secret-password
    After:      DATABASE_PASSWORD=[REDACTED]

    Before:     USER_SESSION_ID=secret-session-id
    After:      USER_SESSION_ID=[REDACTED]

=item *

Recognize and redact secret field names such as:

=over 4

=item *

uid

=item *

gid

=item *

dir

=item *

secret

=item *

token

=item *

api

=back

Eg:

    Before:     uid:[1000] gid:[1000] mode:[0755]
    After:      uid:[REDACTED] gid:[REDACTED] mode:[0755]

=item *

Recognize and redact sensitive HTTP headers, which includes:

=over 4

=item *

API-Key

=item *

Authorization

=item *

CF-Access-Client-Secret

=item *

Cf-Access-Jwt-Assertion

=item *

Set-Cookie / Cookie

=item *

Proxy-Authorization

=item *

X-Access-Token

=item *

X-Amz-Security-Token

=item *

X-API-Key / X-API-Token

=item *

X-Auth-Key

=item *

X-CSRF-Token

=item *

X-XSRF-Token

=back

Eg:

    Before:     [Authorization: Bearer secret-token]
    After:      [Authorization: [REDACTED]]


=item *

Recognize and redact private keys, including PGP and GPG:

Eg:

    Before:     -----BEGIN PRIVATE KEY-----
                fake-private-key-data
                -----END PRIVATE KEY-----

    After:      [REDACTED PRIVATE KEY MATERIAL]

=item *

Redacte login credentials from urls, secret values passed as query
parameters, path segments for sensitive routes, and remove fragments.

Some of the routes or parameters included are:

=over 4

=item *

C<auth>

=item *

C<callback>

=item *

C<credential>

=item *

C<invite>

=item *

C<reset>

=item *

C<secret>

=item *

C<token>

=item *

C<verify>

=item *

C<webhook>

=back

Eg:

    Route before:   https://configserver.dev/token/csf-secret-123
    Route after:    https://configserver.dev/token/[REDACTED]

    Query before:   https://configserver.dev?token=csf-secret&mode=test;api_key=csf-secret-key
    Query after:    https://configserver.dev?token=[REDACTED]&mode=test;api_key=[REDACTED]

    Frag before:    https://configserver.dev/#test
    Frag after:     https://configserver.dev/

=item *

Recognize token formats like:

=over 4

=item *

AWS access keys: C<AKIA...> and C<ASIA...>

=item *

JSON Web Tokens: C<eyJ...>

=item *

UUID v4 and v5 tokens: C<550e8400-e29b-41d4-a716-446655440000>

=back

Restrict oversized output without exposing part of these tokens or
registered secret values.

=item *

Clean log messages:

=over 4

=item *

Convert line breaks and tabs into spaces.

=item *

Remove terminal esc codes, control chars, and invisible unicode
formatting chars.

=item *

Replace consecutive spaces with a single space.

=back

=item *

Return a redacted config hash without changing the original.

=back

=head1 DESCRIPTION

The C<ConfigServer::Secrets> module provides functions for identifying
secret settings, registering sensitive values, redacting secrets from
output, and securely reading secret files.

The module helps prevent passwords, API keys, tokens, private keys,
and other sensitive values from being exposed in logs and other areas
that could be logged or public-facing.

=head1 USAGE

Load module:

    use ConfigServer::Secrets ( );

Read a complete secret file or return separate lines:

=over 4

B<Note>: C<read_file()> and C<read_lines()> support Linux only.

=back

    my $contents = ConfigServer::Secrets::read_file(
        "/etc/csf/csf.conf"
    );

    my @lines = ConfigServer::Secrets::read_lines(
        "/etc/csf/csf.conf",
        max_lines => 1_000,
    );

Register secret values:

    my %config = (
        UI_PASS             => "secret-password",
        RECAPTCHA_SECRET    => "secret-captcha-secret",
        RECAPTCHA_SITEKEY   => "public-site-key",
    );

    ConfigServer::Secrets::register_secrets( \%config );

    ConfigServer::Secrets::register_secret(
        "API_KEY",
        "secret-api-key",
    );

Redact text, log messages, and config lines:

    my $safe_text = ConfigServer::Secrets::redact_obj_str(
        "Login failed using secret-password"
    );

    my $safe_log = ConfigServer::Secrets::redact_obj_log(
        "password=secret-password\nStatus: failed"
    );

    my $safe_config = ConfigServer::Secrets::redact_obj_cfg_line(
        'UI_PASS="secret-password"'
    );

Sanitize URLs:

    my $url_without_query = ConfigServer::Secrets::redact_obj_url(
        "https://user:pass\@example.com/check?token=secret"
    );

    my $url_with_safe_query = ConfigServer::Secrets::redact_obj_url_replace(
        "https://user:pass\@example.com/check?token=secret&mode=test"
    );

Check if a name is secret:

    if ( ConfigServer::Secrets::is_config_secret( "DATABASE_PASSWORD" ) )
    {
        print "Secret setting\n";
    }

Clear all registered secret values:

    ConfigServer::Secrets::registry_clear();

Read safe registry totals without exposing registered values:

    my $stats = ConfigServer::Secrets::registry_stats();

Redact a complete config hash without changing the original:

    my $safe_config = ConfigServer::Secrets::redact_obj_cfg_hash( \%config );

=head1 COMMANDS

=over 4

=item *

Load module:

    sudo perl -I. ConfigServer/Secrets.pm

=item *

Check module for syntax errors:

    sudo perl -I. -c ConfigServer/Secrets.pm

=item *

Display module documentation:

    perldoc -T ConfigServer/Secrets.pm

=item *

Run test suite:

    Linux:      sudo prove -I. -v tests/Logger.t
    Windows:    prove -Isrc -v tests/Logger.t

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

package ConfigServer::Secrets;

# #
#   Declare › Use
# #

use strict;
use warnings;
use Carp ();
use Encode ();
use Errno ();
use Fcntl ();
use File::Spec ();
use POSIX ();
use utf8 ();
use ConfigServer::DebugLocal ();

# #
#	Declare › Export
#   
#   registry_clear          Clear registered secrets and redaction filters.
#   
#   registry_stats          Return safe registry counts and limits.
#   
#   is_config_secret           Determine if config setting name is secret
#                               and should be redacted.
#   
#   redact_obj_cfg_hash            Redact secret values in a copy of a config hash.
#   
#   read_file               Validate and read a secret file as one string.
#   
#   read_lines              Validate and read a secret file as separate lines.
#                               Calls read_file: splits single config string into lines, and returns a list of lines.
#   
#   redact_obj_url          Redact and remove all query strings and fragments.
#                               https://[REDACTED]@configserver.dev/check
#   
#   redact_obj_url_replace  Redact but keep secret query strings in url.
#                               https://[REDACTED]@configserver.dev/check?token=[REDACTED]&mode=test
#   
#   redact_obj_cfg_line          Redact value of a secret config setting.
#   
#   redact_obj_log          Redacts secrets and unsafe controls from a log.
#                               Redacts text, enforces log size limit.
#                               Calls _log_fit_record()
#   
#   redact_obj_str          Redact secrets from general text and mark truncated input.
#   
#   register_secrets        Register secret values from an config hash.
#                               Bulk wrapper for register_secret for every setting.
#   
#   register_secret         Register one setting as name/value pair.
# #

use Exporter qw( import );
our @EXPORT_OK = qw(
    registry_clear
    registry_stats
    is_config_secret
    redact_obj_cfg_hash
    read_file
    read_lines
    redact_obj_url
    redact_obj_url_replace
    redact_obj_cfg_line
    redact_obj_log
    redact_obj_str
    redact_obj_field
    register_secrets
    register_secret
);

# #
#	Declare › Version
# #

our $VERSION = 15.11;

# #
#   Declare › Constants
#   
#   Limits used for configs, secrets, registered values, sanitization,
#   urls, and log output. Short definitions provided below, I'm not 
#   typing out insanely long descriptions.
#   
#   FILE_BYTE_DEFAULT
#       Default max secret file size when $opts{max_bytes} not
#       provided. Files larger rejected.
#   
#   FILE_BYTE_MAXIMUM
#       Max secret file size allowed with $opts{max_bytes}. Larger
#       limits rejected.
#   
#   FILE_LINE_MAXIMUM
#       Default and max num of lines accepted to read_lines().
#       Larger limits rejected.
#   
#   FILE_READ_BLOCK
#       Number of bytes requested by each sysread() while reading a
#       secrets file.
#   
#   FILE_HARDLINK_MAX
#       Required fs link count for a secret file. Values above 1
#       means another hard link exists.
#   
#   SETTING_NAME_BYTE_MAXIMUM
#       Max size of a setting's name in bytes. Names exceeding this
#       limit will be automatically classified as a secret, and will
#       be redacted from any public facing outputs, including logs.
#   
#   OWNER_UID_MAXIMUM
#       Max owner uid accepted by read_file(). The effective
#       EUID for the process used when owner not supplied. Absolute
#       max this should ever be set is 4,294,967,294.
#   
#   LOCK_POLL_COUNT
#       Max num of file lock attempts before reading a secrets
#       file fails. If a lock can't be obtained, read aborted.
#   
#   LOCK_POLL_INTERVAL
#       Time to wait between unsuccessful file lock attempts when
#       reading secrets file.
#   
#   LOG_BYTE_MAXIMUM
#       Max size returned by redact_obj_log(). Larger msgs truncated.
#   
#       This limit applies to each individual log msg, not the
#       total log file size.
#   
#   PATH_BYTE_MAXIMUM
#       Max length of a secret's entire file path that is accepted.
#   
#   REGISTRY_BYTE_MAXIMUM
#       Max combined size of all registered secret values. If this
#       limit is reached and a new secret is added, the oldest secret
#       is removed and the new secret takes the newest position.
#   
#   REGISTRY_ENTRY_MAXIMUM
#       Max num of unique secret values stored in memory.
#       Once this limit is reached and another secret is added, the
#       oldest secret is removed and the new secret takes the newest
#       position.
#   
#   SCAN_CHARACTER_MAXIMUM
#       Max num of chars that can be passed through sanitizer.
#       If a log msg exceeds this limit, log truncated.
#   
#   URL_CHARACTER_MAXIMUM
#       Max num of chars allowed for a url that will be processed
#       by the url sanitizer redact_obj_url(). If a url is longer than
#       this limit, it will be truncated.
#   
#   URL_DECODE_PASS_MAXIMUM
#       Max num of times an encoded url can be decoded. If encoded
#       text remains after this limit, it is treated as a secret to
#       prevent nested encoding from bypassing redaction.
#   
#   SECRET_BYTE_MINIMUM
#       Min secret value size in bytes, accepted by register_secret().
#       Any secrets shorter than this are rejected.
#   
#   SECRET_BYTE_MAXIMUM
#       Max secret value size in bytes, accepted by register_secret().
#       Any secrets longer than this are rejected.
#   
#       Highly recommended to not set this lower than '6'; otherwise
#       redactions may cause false positives and will engage mass chaos.
#   
#   LABEL_SECRET_REDACT
#       Redaction text to use when redacting secrets.
#       Default:    [REDACTED]
#   
#   LABEL_PRIVKEY_REDACT
#       Redaction text to use when redacting private keys.
#       SSL/TLS, OpenSSH, PGP / GPG, etc.
#       Default:    [REDACTED PRIVATE KEY MATERIAL]
#   
#   LABEL_TRUNCATE
#       Redaction text to use when redacting logs.
#       Default:    [TRUNCATED]
#       Eg:         This is a long log mes ... [TRUNCATED]
# #

use constant
{
    FILE_BYTE_DEFAULT           => 16 * 1024 * 1024,
    FILE_BYTE_MAXIMUM           => 64 * 1024 * 1024,
    FILE_LINE_MAXIMUM           => 262_144,
    FILE_READ_BLOCK             => 64 * 1024,
    FILE_HARDLINK_MAX           => 1,
    SETTING_NAME_BYTE_MAXIMUM   => 256,
    OWNER_UID_MAXIMUM           => 4_294_967_294,
    LOCK_POLL_COUNT             => 20,
    LOCK_POLL_INTERVAL          => 0.01,
    LOG_BYTE_MAXIMUM            => 64 * 1024,
    PATH_BYTE_MAXIMUM           => 4096,
    REGISTRY_BYTE_MAXIMUM       => 64 * 1024,
    REGISTRY_ENTRY_MAXIMUM      => 256,
    SCAN_CHARACTER_MAXIMUM      => 256 * 1024,
    URL_CHARACTER_MAXIMUM       => 8 * 1024,
    URL_DECODE_PASS_MAXIMUM     => 8,
    SECRET_BYTE_MINIMUM         => 6,
    SECRET_BYTE_MAXIMUM         => 4096,
    LABEL_SECRET_REDACT         => '[REDACTED]',
    LABEL_PRIVKEY_REDACT        => '[REDACTED PRIVATE KEY MATERIAL]',
    LABEL_TRUNCATE              => ' [TRUNCATED]',
};

# #
#   Declare › Registry › Secret Settings
#   
#   Some settings in /etc/csf/csf.conf file have sensitive values.
#   These sensitive values will automatically be classified as a
#   'secret'. 
#   
#   If any of these secret values are read through logging, redact.
#   
#   Values:
#       0   (Public)        Remain visible in output.
#       1   (Secret)        Flag as secret, redact
# #

my %REGISTRY_SECRET_SETTINGS =
(
    AT_PASSWD               => 1,
    CFAPIKEY                => 1,
    CLUSTER_KEY             => 1,
    MM_LICENSE_KEY          => 1,
    SPONSOR_LICENSE         => 1,
    RECAPTCHA_SECRET        => 1,
    ST_MYSQL_PASS           => 1,
    UI_PASS                 => 1,
    MESSENGER_HTTPS_KEY     => 0,
    PORTS_HTPASSWD          => 0,
    RECAPTCHA_SITEKEY       => 0,
);

# #
#   Declare › Registry › Secret Fields
#   
#   Log field names whose bracketed values must always be redacted:
#       Input:      uid:[1000] gid:[1000]
#       Result:     uid:[REDACTED] gid:[REDACTED]
#   
#   Field names are matched without case sensitivity.
#   
#   These types of values are typically found in internal subs such
#   as ConfigServer::DebugLocal::log(), which can output each process
#   as it happens.
# #

my %REGISTRY_SECRETS_FIELDS =
(
    api     => 1,
    uid     => 1,
    gid     => 1,
    dir     => 1,
    path    => 1,
    secret  => 1,
    token   => 1
);

my $REGISTRY_SECRETS_FIELDS_MATCH = _build_literal_match(
    sort grep
    {
        $REGISTRY_SECRETS_FIELDS{$_}
    }
    keys( %REGISTRY_SECRETS_FIELDS )
);

# #
#   Declare › Registry › HTTP Headers › Secret Headers
#   
#   List of http headers known to have sensitive values. Not case
#   sensitive.
#   
#       Before:     [API-Key: MySecretToken]
#       After:      [API-Key: [REDACTED]]
#   
#       Eg:         - API-Key
#                   - api-key
#                   - API-KEY
#                   - Api-Key
# #

my @REGISTRY_HEADERS_HTTP =
(
    "API-Key",
    "Authorization",
    "CF-Access-Client-Secret",
    "Cf-Access-Jwt-Assertion",
    "Cookie",
    "Proxy-Authorization",
    "Set-Cookie",
    "X-Access-Token",
    "X-Amz-Security-Token",
    "X-API-Key",
    "X-API-Token",
    "X-Auth-Key",
    "X-CSRF-Token",
    "X-XSRF-Token"
);

# #
#   Declare › Registry › HTTP Headers › Register
# #

my %REGISTRY_HEADERS_HTTP_LOOKUP = map
{
    lc( $_ ) => 1
} @REGISTRY_HEADERS_HTTP;

# #
#   Declare › Registry › Private Key Headers
#   
#   Private key labels after "BEGIN" tag.
#   Eg:         -----BEGIN PRIVATE KEY-----
#               -----BEGIN RSA PRIVATE KEY-----
#               -----BEGIN EC PRIVATE KEY-----
#               -----BEGIN OPENSSH PRIVATE KEY-----
#               -----BEGIN ENCRYPTED PRIVATE KEY-----
#               -----BEGIN PGP PRIVATE KEY BLOCK-----
#   
#   @test       Note:           Test private keys
#               Commands:       sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::redact_obj_str(qq{-----BEGIN RSA PRIVATE KEY-----\nfake-private-key-data\n-----END RSA PRIVATE KEY-----}), qq{\n};"
#                               sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::redact_obj_str(qq{-----BEGIN EC PRIVATE KEY-----\nfake-private-key-data\n-----END EC PRIVATE KEY-----}), qq{\n};"
#                               sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::redact_obj_str(qq{-----BEGIN OPENSSH PRIVATE KEY-----\nfake-private-key-data\n-----END OPENSSH PRIVATE KEY-----}), qq{\n};"
#               Result:         Response:   [REDACTED PRIVATE KEY MATERIAL]
# #

my @REGISTRY_PRIVATE_KEYS =
(
    "PGP PRIVATE KEY BLOCK",
    "PRIVATE KEY",
);

# #
#   Declare › Registry › Secret Url Routes
#   
#   Url routes that could contain secrets. Route names url decoded
#   and converted to lowercase before checked:
#   
#   Eg:     /reset/secret-token     => /reset/[REDACTED]
#           /webhook/private-secret => /webhook/[REDACTED]
#   
#   Values:
#       0   (Public)        Don't redact
#       1   (Secret)        Redact route
# #

my %REGISTRY_SECRET_URL_ROUTES =
(
    auth        => 1,
    callback    => 1,
    credential  => 1,
    invite      => 1,
    reset       => 1,
    secret      => 1,
    token       => 1,
    verify      => 1,
    webhook     => 1,
);

# #
#   Declare › Registry › Exemption
#   
#   Values in this list will NOT be registered for redaction.
#   28
#       Eg:     Original:   Please changeme after installation
#               Result:     Please changeme after installation
#   
#   Value is still redacted if assigned to a setting marked as a
#   secret, such as UI_PASS. That list of secrets are defined at:
#        %REGISTRY_SECRET_SETTINGS
#   
#       Eg:     Original:   UI_PASS="changeme"
#               Result:     UI_PASS="[REDACTED]"
# #

my %REGISTRY_EXEMPT =
(
    changeme    => 1,
    change_me   => 1,
    default     => 1,
    none        => 1,
    null        => 1,
    password    => 1,
    secret      => 1,
    test        => 1,
    token       => 1,
);

# #
#   Declare › Registry › Secret Name Suffixes
#   
#   These are settings, log fields, cli options, and url param
#   names that flag a value as a secret.
#   
#   Entries are:
#       - Converted to uppercase
#       - Hyphens converted to underscores
#   
#   Entry may match full or partial suffix beginning after an
#   underscore:
#   
#       UI_PASS             => secret; declared in %REGISTRY_SECRET_SETTINGS with value 1
#       RECAPTCHA_SITEKEY   => public; declared in %REGISTRY_SECRET_SETTINGS with value 0
#       CLOUDFLARE_API_KEY  => secret; partial match API_KEY
#       DATABASE_PASSWORD   => secret; partial match PASSWORD
#       PUBLIC_VALUE        => public; no secret suffix matches
#   
#   %REGISTRY_SECRET_SETTINGS checked first. Provides secret
#   and public rules for specific CSF settings:
#   
#       UI_PASS             secret; assigned 1
#       RECAPTCHA_SITEKEY   public; assigned 0
#   
#   Values:
#       0   (Public)        Don't redact suffix
#       1   (Secret)        Redact suffix as secret
# #

my %REGISTRY_SECRET_SUFFIX =
(
    API_KEY                 => 1,
    APIKEY                  => 1,

    ACCESS_KEY              => 1,
    ACCESSKEY               => 1,
    ACCESS_TOKEN            => 1,
    ACCESSTOKEN             => 1,
    REFRESH_TOKEN           => 1,
    REFRESHTOKEN            => 1,
    ID_TOKEN                => 1,
    IDTOKEN                 => 1,

    CLIENT_SECRET           => 1,
    CLIENTSECRET            => 1,
    PRIVATE_KEY             => 1,
    PRIVATEKEY              => 1,

    AUTH                    => 1,
    AUTHORIZATION           => 1,
    AUTH_KEY                => 1,
    CREDENTIAL              => 1,

    PASSWORD                => 1,
    PASSWD                  => 1,
    PASSPHRASE              => 1,
    PWD                     => 1,

    TOKEN                   => 1,
    TOKENS                  => 1,
    SECRET                  => 1,
    SECRETS                 => 1,
    KEY                     => 1,
    SIGNATURE               => 1,

    LICENSE                 => 1,
    LICENSE_KEY             => 1,
    LICENSEKEY              => 1,

    JWT                     => 1,

    AWSACCESSKEYID          => 1,
    X_AMZ_SIGNATURE         => 1,
    X_AMZ_CREDENTIAL        => 1,

    SESSION                 => 1,
    SESSION_ID              => 1,
    SESSIONID               => 1,
    SESS_ID                 => 1,
    SESSID                  => 1,
    COOKIE                  => 1,

    CSRF_TOKEN              => 1,
    G_RECAPTCHA_RESPONSE    => 1,
);

# #
#   Declare › Rules › Tokens
#   
#   Regex to find AWS access keys, jwt and uuids and redact.
# #

my $AWS_TOKEN_MATCH = qr{
    (?<![A-Za-z0-9])
    (?:AKIA|ASIA)[A-Z0-9]{16}
    (?![A-Za-z0-9])
}x;

my $JWT_TOKEN_MATCH = qr{
    (?<![A-Za-z0-9])
    eyJ[A-Za-z0-9_-]{8,}
    \.[A-Za-z0-9_-]{8,}
    \.[A-Za-z0-9_-]{8,}
    (?![A-Za-z0-9])
}x;

my $UUID_TOKEN_MATCH = qr{
    (?<![A-Za-z0-9])
    [A-Fa-f0-9]{8}-
    [A-Fa-f0-9]{4}-
    [45][A-Fa-f0-9]{3}-
    [89ABab][A-Fa-f0-9]{3}-
    [A-Fa-f0-9]{12}
    (?![A-Za-z0-9])
}x;

# #
#   Declare › Registry › Private Keys
#   
#   Escape each label, join with '|' so that the rule can match
#   any private key header with any label in @REGISTRY_PRIVATE_KEYS.
#   
#   Char '|' represents 'OR' in regex.
#       Eg: "PGP\ PRIVATE\ KEY\ BLOCK|PRIVATE\ KEY"
#   
#   Built once when the module loads.
# #

my $PRIVATE_KEYS_MATCH = _build_literal_match( @REGISTRY_PRIVATE_KEYS );

# #
#   Declare › Registry › File Line Separators
#   
#   List of line breaks / endings to match for.
#   
#   Windows \r\n matched first so that it is treated as one line
#   break instead of two separate chars.
#   
#   Both raw utf8 file data and decoded perl text supported.
#   
#       CRLF    \r\n                Windows
#       LF      \n                  Unix/Linux
#       CR      \r                  Classic
#       VT      \x0B                Vertical tab
#       FF      \f                  Form feed
#       NEL     \x85 / U+0085       Next line
#       LS      U+2028              Unicode line separator
#       PS      U+2029              Unicode paragraph separator
#   
#   @ref            https://en.wikipedia.org/wiki/Newline
#                   https://en.wikipedia.org/wiki/Whitespace_character#Unicode
#                   https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-5/#G10213
# #

my $REGISTRY_LINE_BREAKS = qr{
    \r\n |
    \xC2\x85 |
    \xE2\x80[\xA8\xA9] |
    \x{2028} |
    \x{2029} |
    [\n\x0B\f\r\x85]
}x;

# #
#   Declare › Registry › Secrets
#   
#   Used for secret storage and redaction.
#   
#   %registry_secrets
#       Store each secret and order of registration. Secret with
#       lowest reg number is oldest.
#   
#       If > 256 (REGISTRY_ENTRY_MAXIMUM) secrets are stored, remove
#       oldest, add the newest secret.
#   
#   $registry_secrets_sequence
#       Generates reg numbers. Increases when a new secret is added
#       to the registry $registry_secrets.
#   
#   $registry_secrets_bytes
#       Total size of all stored secrets. Used to ensure the cache
#       size stays within its byte limit 64 KB (REGISTRY_BYTE_MAXIMUM)
#   
#   $registry_secrets_match_bytes
#       Regex with all stored secrets. Used to find and replace
#       registered secrets with redaction.
#   
#   $registry_secrets_match_decoded
#       Regex to redact registered secrets from decoded unicode text.
#   
#   @registry_secrets_decoded
#       Decoded unicode copies of registered secret values.
# #

my %registry_secrets;
my $registry_secrets_sequence   = 0;
my $registry_secrets_bytes      = 0;
my $registry_secrets_match_bytes;
my $registry_secrets_match_decoded;
my @registry_secrets_decoded;

# #
#   Secrets › Truncation › Get Position
#   
#   Move cut pos before a secret would be split. Prevents accidentally
#   exposing part of a secret.
#   
#   SECRET      "csf123-key"
#   BAD         [Log] Random log with secret ... csf1 [TRUNCATED]
#   GOOD        [Log] Random log with secret ... [TRUNCATED]
#   
#   @note       Secrets must be registered first;
#                   register_secret( "API_KEY", "csf123-key" );
#   
#   @test       Note:           Move cut before a secret
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "ConfigServer::Secrets::registry_clear(); ConfigServer::Secrets::register_secret(q{API_KEY}, q{csf123-key}); print ConfigServer::Secrets::_truncate_get_pos(q{Log: csf123-key}, 12), qq{\n};"
#               Result:         5
#   
#   @params     text            str         Text to check
#               i               int         Desired cut pos
#   @return                     int         Cut pos, count from 0
# #

sub _truncate_get_pos
{
    my ( $text, $i ) = @_;

    _build_regex_secret_values( )
        if keys( %registry_secrets ) and !defined( $registry_secrets_match_bytes );

    my $boundary_changed = 1;
    while ( $boundary_changed )
    {
        my $shift_i = $i;

        my @registered_values = utf8::is_utf8( $text )
            ? @registry_secrets_decoded
                : keys( %registry_secrets );

        for my $secret ( @registered_values )
        {
            # #
            #   Search backward from pos 7 ($i = 8 - 1).
            #   At each pos, rindex() checks for the complete secret:
            #       pos 7:  "f123-key"      No match
            #       pos 6:  "sf123-key"     No match
            #       pos 5:  "csf123-key"    Match
            #
            #   Complete secret starts at pos 5, rindex() returns 5.
            # #

            my $start = rindex( $text, $secret, $i - 1 );

            next
                if $start < 0 or
                   $start + length( $secret ) <= $i;

            $shift_i = $start
                if $start < $shift_i;
        }

        my $scan_end    = $i + SCAN_CHARACTER_MAXIMUM;
        $scan_end       = length( $text )
                            if $scan_end > length( $text );

        my $scan_text   = substr( $text, 0, $scan_end );

        for my $token_match (
            $AWS_TOKEN_MATCH,
            $JWT_TOKEN_MATCH,
            $UUID_TOKEN_MATCH,
        )
        {
            pos( $scan_text ) = 0;

            while ( $scan_text =~ /$token_match/g )
            {
                my $start   = $-[ 0 ];
                my $end     = $+[ 0 ];

                last
                    if $start >= $i;

                next
                    if $end <= $i;

                $shift_i = $start
                    if $start < $shift_i;
            }
        }

        # hide jwt prefix when bounded lookahead ends inside it
        if (
            $scan_end < length( $text ) and
            $scan_text =~ /(?<![A-Za-z0-9])(eyJ[A-Za-z0-9_-]*(?:\.[A-Za-z0-9_-]*){0,2})\z/
        )
        {
            my $start       = $-[ 1 ];
            my $next_char   = substr( $text, $scan_end, 1 );

            $shift_i = $start
                if $start < $i and
                   $next_char =~ /[A-Za-z0-9_.-]/ and
                   $start < $shift_i;
        }

        # repeat only when boundary moved backward
        $boundary_changed = $shift_i < $i;

        $i = $shift_i
            if $boundary_changed;
    }

    return $i;
}

# #
#   Secrets › Build › Literal Match
#   
#   Escape literal names, combine into one regex pattern.
#   Input:      "PGP PRIVATE KEY BLOCK", "PRIVATE KEY"
#   Result:     PGP\ PRIVATE\ KEY\ BLOCK|PRIVATE\ KEY
#   
#   @note       Char '|' represents 'OR' in regex.
#   
#   @test       Note:           Combine two private key labels.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_build_literal_match( q{PGP PRIVATE KEY BLOCK}, q{PRIVATE KEY} ), qq{\n};"
#               Result:         PGP\ PRIVATE\ KEY\ BLOCK|PRIVATE\ KEY
#   
#   @params     names           arr         Names to escape and combine
#   @return     pattern         str         Combined regex pattern
# #

sub _build_literal_match
{
    return join( "|", map { quotemeta( $_ ) } @_ );
}

# #
#   Secrets › Build › Registered Secrets Regex Filters
#   
#   Build byte and decoded regex filters from all registered secret values.
#   
#   Longer values placed first so shorter secrets cannot expose
#   part of a longer secret.
#   
#   register_secret() builds hash %registry_secrets; this sub then
#   uses the hash.
#   
#   @note       %registry_secrets           Plain secret as hash key mapped with reg id
#                                               = ( "päss" => 1 );      # 5 bytes (ä = 2)
#               @registry_secrets_decoded   Plain secret as decoded chars
#                                               = ( "päss" );           # 4 chars
#   
#   @test       Note:           Match longer overlapping secrets first.
#               Command:        sudo env DEBUG=5 perl -I. -MConfigServer::Secrets -e "ConfigServer::Secrets::registry_clear(); ConfigServer::Secrets::register_secret(q{API_KEY}, q{csf-key-A7X9}); ConfigServer::Secrets::register_secret(q{API_KEY}, q{csf-key-A7X9-extended-B4Q2}); print ConfigServer::Secrets::redact_obj_str(q{csf-key-A7X9-extended-B4Q2}), qq{\n};"
#               Result:         [REDACTED]
#   
#   @params     void
#   @return     void
# #

sub _build_regex_secret_values
{
    # sort reg'd secrets from longest => shortest
    my @eligible = sort
    {
        length( $b ) <=> length( $a ) || $a cmp $b
    } keys %registry_secrets;

    # build regex; undef if registry empty
    $registry_secrets_match_bytes = @eligible
        ? qr/(?:@{[ join( "|", map { quotemeta( $_ ) } @eligible ) ]})/
        : undef;

    @registry_secrets_decoded = ( );
    for my $secret ( @eligible )
    {
        my $secret_encoded = $secret;
        my $secret_decoded = eval
        {
            Encode::decode( 'UTF-8', $secret_encoded, Encode::FB_CROAK( ) )
        };

        push @registry_secrets_decoded, $secret_decoded
            if defined( $secret_decoded ) and !$@;
    }

    $registry_secrets_match_decoded = @registry_secrets_decoded
        ? qr/(?:@{[ join( "|", map { quotemeta( $_ ) } @registry_secrets_decoded ) ]})/
        : undef;

    my $filter_built = defined( $registry_secrets_match_bytes ) ? 1 : 0;
    ConfigServer::DebugLocal::log( 1, $filter_built ? 'ok' : 'info',
        "count:[" . scalar( @eligible ) . "] " .
        "built:[$filter_built] " .
        "status:[" .
            ( $filter_built ? 'secret filter built' : 'registry empty' ) .
        "]"
    );

    # #
    #   Debug prints; require DEBUG 5.
    # #

    if ( ConfigServer::DebugLocal::DEBUG( ) == 5 )
    {
        my $snapshot_i  = $registry_secrets_sequence;
        my $match_i     = 0;
        my $entries_i   = scalar( @eligible );

        for my $secret ( @eligible )
        {
            $match_i++;

            my $registry_id     = $registry_secrets{$secret};
            my $secret_redacted = $secret;
            my $redacted_i      = defined( $registry_secrets_match_bytes )
                                    ? ( $secret_redacted =~ s/$registry_secrets_match_bytes/LABEL_SECRET_REDACT/eg )
                                    : 0;
            $secret_redacted    = LABEL_SECRET_REDACT
                                    if !$redacted_i;
            my $secret_encoded  = $secret_redacted;
            my $secret_decoded  = eval
            {
                Encode::decode( 'UTF-8', $secret_encoded, Encode::FB_CROAK( ) )
            };

            my $decode_ok       = defined( $secret_decoded ) && !$@;
            my $decoded_text    = $decode_ok
                                    ? Encode::encode_utf8( $secret_decoded )
                                    : 'invalid utf8';

            my $unicode_text    = $decode_ok
                                    ? join( " ", map { sprintf( "U+%04X", ord( $_ ) ) } split( //, $secret_decoded ) )
                                    : 'invalid utf8';

            ConfigServer::DebugLocal::log( 5, 'info',
                "snapshot:[$snapshot_i] entries:[$entries_i] " .
                "match:[$match_i] registry_id:[$registry_id] " .
                "bytes:[" . join( " ", map { sprintf( "%02X", ord( $_ ) ) } split( //, $secret_redacted ) ) . "] " .
                "decoded:[$decoded_text] " .
                "unicode:[$unicode_text]"
            );
        }
    }

    return;
}

# #
#   Secrets › Build › Redaction Marker (Quoted)
#   
#   Build redaction marker.
#   Keep single or double quotes if value starts with one.
#   
#   @test       Note:           Keep single quotes around redaction marker
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_build_redact_marker_quoted(q{'csf-secret'}), qq{\n};"
#               Result:         '[REDACTED]'
#   
#               Note:           Return unquoted redaction marker
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_build_redact_marker_quoted(q{csf-secret}), qq{\n};"
#               Result:         [REDACTED]
#   
#   @params     value           str         Value to replace
#   @return     result          str         Replacement text with matching quotes
#                                           (if input starts with quotes)
# #

sub _build_redact_marker_quoted
{
    my ( $value ) = @_;

    my $quote       = defined( $value ) ? substr( $value, 0, 1 ) : "";
    my $is_quoted   = $quote eq '"' || $quote eq "'";
    my $replacement = $is_quoted
                        ? $quote . LABEL_SECRET_REDACT . $quote
                            : LABEL_SECRET_REDACT;

    ConfigServer::DebugLocal::log( 1, 'ok',
        "quoted:[" . ( $is_quoted ? 1 : 0 ) . "] " .
        "status:[mask value with original quotes]"
    );

    return $replacement;
}

# #
#   Secrets › Octet › Calculate Text Size in Bytes
#   
#   Calculate number of bytes used by ascii or unicode text.
#   Unicode text encoded as utf8 before counting the length.
#   
#   @test       Note:           Count bytes in ascii string
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_octet_length(q{csf123}), qq{\n};"
#               Result:         6
#               
#               Note:           Count bytes in unicode string.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_octet_length(chr(0x2603)), qq{\n};"
#               Result:         3
#   
#   @params     text            str         Text
#   @return     bytes           int         Num of bytes used by text
# #

sub _octet_length
{
    my ( $text ) = @_;
    return length( utf8::is_utf8( $text ) ? Encode::encode_utf8( $text ) : $text );
}

# #
#   Secrets › Octet › Decode Url Percent Values
#   
#   Convert url percent encoded values into actual chars:
#       %2F => /
#   
#   Multiple passes may be needed since a value could be encoded
#   more than once.
#       %252F => %2F => /
#   
#   Stop decoding after we hit the nested limit defined by const 
#   URL_DECODE_PASS_MAXIMUM (8). This ensures that deeply encoded
#   values can't keep the decoder running.
#   
#   @test       Note:           Decode value that was percent encoded twice
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print join(q{, }, ConfigServer::Secrets::_octet_percent_decode(q{%252Fsecret})), qq{\n};"
#               Result:         /secret, 0
#   
#               Note:           Attempt 9 nested decode passes, sub allows 8, 
#                               flag remaining percent encoded octets as unsafe.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'print join(q{, }, ConfigServer::Secrets::_octet_percent_decode(q{user%25252525252525255Bpassword%25252525252525255D})), qq{\n};'
#               Result:         user%5Bpassword%5D, 1
#   
#   @params     value           str         Percent encoded text to decode
#   
#   @return     value           str         Decoded text
#               is_unsafe       int         If encoded values still exist
#                                               1           Nest limit reached  (unsafe)
#                                               0           Decode finished     (safe)
# #

sub _octet_percent_decode
{
    my ( $value ) = @_;

    for my $pass ( 1 .. URL_DECODE_PASS_MAXIMUM )
    {
        my $decoded = $value =~ s/%([0-9A-Fa-f]{2})/chr( hex( $1 ) )/eg;

        ConfigServer::DebugLocal::log( 1, 'ok',
            "passes:[" . ( $pass - 1 ) . "] " .
            "status:[ok]"
        ) if !$decoded;

        return ( $value, 0 )
            if !$decoded;
    }

    ConfigServer::DebugLocal::log( 1, 'fail',
        "limit:[" . URL_DECODE_PASS_MAXIMUM . "] status:[fail; hit nested decoding limit. still contains encoded bytes]"
    );

    # #
    #   If $value still has %XX encoded bytes after reaching max
    #   nested pass limit, mark as unsafe:
    #       %5B, %5D, %20, %25
    #   
    #   If returned no %XX sequences after the max passes, we're good.
    #   
    #   return      0 safe
    #               1 unsafe
    # #

    return ( $value, $value =~ /%[0-9A-Fa-f]{2}/ ? 1 : 0 );
}

# #
#   Secrets › Max Allowed Chars
#   
#   Check text before it's sanitized. If message is longer than
#   262,144 chars, shorten at a safe pos without exposing secrets.
#   
#   Accept optional 3rd param to force max allowed char limit:
#   Default:    SCAN_CHARACTER_MAXIMUM  (262,144)
#   Optional:   URL_CHARACTER_MAXIMUM   (8,192)
#   
#   @test       Note:           Return text without shortening
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print join(qq{\n}, ConfigServer::Secrets::_chars_allow_max(q{Normal message}, q{[INVALID LOG MESSAGE]})), qq{\n};"
#               Result:         Normal message, 0
#   
#               Note:           Shorten text that exceeds len limit
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print join(qq{\n}, ConfigServer::Secrets::_chars_allow_max(q{A} x 300000, q{[INVALID LOG MESSAGE]})), qq{\n};"
#               Result:         AAAAAAAAAAAAAAAAAAAAAAAAAAAA [...], 1
#   
#   @params     input           str         Text to check
#               err             str         Text returned for undef or ref input
#               limit           int         Max chars to return
#                                               undef       Use SCAN_CHARACTER_MAXIMUM
#                                               1+          Use specified char limit
#   
#   @return                     str         Checked text or fallback err msg
#                               int         If text was shortened
#                                               0           Text not shortened
#                                               1           Text shortened
# #

sub _chars_allow_max
{
    my ( $input, $err, $limit ) = @_;

    $limit = SCAN_CHARACTER_MAXIMUM
        if !defined( $limit );

    return ( $err, 0 )
        if !defined( $input ) or ref( $input );

    my $text = "$input";
    return ( $text, 0 )
        if length( $text ) <= $limit;

    my $safe_boundary = _truncate_get_pos(
        $text,  # my message [...]
        $limit, # 262144 (or 8,192 for urls)
    );

    return ( substr( $text, 0, $safe_boundary ), 1 );
}

# #
#   Secrets › Check Secret Name Ending
#   
#   Check if complete setting name OR the ending name after an
#   underscore exists in %REGISTRY_SECRET_SUFFIX.
#   
#   For "DATABASE_PASSWORD", check DATABASE_PASSWORD. If it is not
#   registered, remove DATABASE_ and check PASSWORD.
#   
#   Return 1 since "PASSWORD" is in hash %REGISTRY_SECRET_SUFFIX.
#   
#   @test       Note:           Compare secret suffix with name.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print join( qq{\n}, ConfigServer::Secrets::_has_secret_name_suffix( q{DATABASE_PASSWORD} ), ConfigServer::Secrets::_has_secret_name_suffix( q{PUBLIC_SETTING} ) ), qq{\n};"
#               Result:         1, 0
#   
#   @params     name            str         Secret name to check
#   @return     is_secret       int         If secret suffix found
#                                               1           Name or suffix is secret
#                                               0           No secret suffix found
# #

sub _has_secret_name_suffix
{
    my ( $name ) = @_;

    my $name_suffix = $name;
    my $start       = 0;

    while ( defined( $start ) )
    {
        $name_suffix    = substr( $name, $start );
        my $has_suffix  = exists( $REGISTRY_SECRET_SUFFIX{$name_suffix} );

        ConfigServer::DebugLocal::log( 1, 'ok',
            "name:[$name] suffix:[$name_suffix] " .
            "status:[secret suffix found]"
        ) if $has_suffix;

        return 1
            if $has_suffix;

        my $underscore_pos = index( $name, '_', $start );
        $start = $underscore_pos >= 0 ? $underscore_pos + 1 : undef;
    }

    ConfigServer::DebugLocal::log( 1, 'ok',
        "suffix:[$name_suffix] status:[complete]"
    );

    return 0;
}

# #
#   Secrets › Get Oldest Registered Secret Value
#   
#   Return secret value that was registered first (oldest).
#   
#   @test       Note:           Register two values, return first one
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "ConfigServer::Secrets::registry_clear(); ConfigServer::Secrets::register_secret(q{API_KEY}, q{first-secret}); ConfigServer::Secrets::register_secret(q{API_KEY}, q{second-secret}); print ConfigServer::Secrets::_oldest_registered_value(), qq{\n};"
#               Result:         first-secret
#   
#   @params     void
#   @return     secret_oldest   str         Oldest registered secret or undef
#                                               str         Oldest registered secret
#                                               undef       Registry empty
# #

sub _oldest_registered_value
{
    my ( $secret_oldest ) = sort
    {
        $registry_secrets{$a} <=> $registry_secrets{$b}
    } keys %registry_secrets;

    my $is_found    = defined( $secret_oldest ) ? 1 : 0;
    my $bytes       = $is_found ? _octet_length( $secret_oldest ) : 0;

    ConfigServer::DebugLocal::log( 1, $is_found ? 'ok' : 'info',
        "found:[$is_found] bytes:[$bytes] " .
        "status:[returned oldest registered secret]"
    );

    return $secret_oldest;
}

# #
#   Secrets › Find Secret Header Value
#   
#   Return pos where value of a registered http header begins.
#   Skip spaces, read the header name, require ':' or '=' after name
#   
#   @note       Does not redact anything. _redact_headers() uses the
#               returned pos to replace the header value.
#   
#   @test       Note:           Find out where 'csf-secret' starts inside an auth header.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_header_value_start(q{[Authorization: csf-secret]}, 1, 29), qq{\n};"
#               Result:         16
#   
#   @params     text            str         Text with header
#               start           int         Pos to begin after the opening '['
#               limit           int         Check limit (don't check past this header)
#   
#   @return                     int|undef   Result of header's secret value pos;
#                                               int         Pos where secret starts
#                                               undef       if the header is not a secret
# #

sub _header_value_start
{
    my ( $text, $start, $limit ) = @_;

    my $cursor = $start;

    $cursor++
        while $cursor < $limit and substr( $text, $cursor, 1 ) =~ /[ \t]/;

    return
        if $cursor >= $limit or substr( $text, $cursor, 1 ) !~ /[A-Za-z]/;

    my $name_start = $cursor;

    $cursor++;
    $cursor++
        while $cursor < $limit and substr( $text, $cursor, 1 ) =~ /[A-Za-z0-9_-]/;

    # #
    #   Convert extracted header name to lowercase before checking
    #   %REGISTRY_HEADERS_HTTP_LOOKUP:
    #       $text:              [Authorization: csf-secret]
    #       $name_header:       authorization
    #       $name_start         1
    #       $cursor             14
    # #

    my $name_header = lc( substr( $text, $name_start, $cursor - $name_start ) );
    return
        if !exists( $REGISTRY_HEADERS_HTTP_LOOKUP{$name_header} );

    $cursor++
        while $cursor < $limit and substr( $text, $cursor, 1 ) =~ /[ \t]/;

    return
        if $cursor >= $limit or substr( $text, $cursor, 1 ) !~ /[=:]/;

    $cursor++;

    $cursor++
        while $cursor < $limit and substr( $text, $cursor, 1 ) =~ /[ \t]/;

    return $cursor;
}

# #
#   Secrets › Find Bracketed Field End
#
#   Find closing bracket ']' for one bracketed log field.
#   
#   Could place ']' inside a header value and trick the sanitizer
#   into stopping early. The remaining secret would then be exposed.
#   
#   Accept a closing bracket only when it is followed by another
#   bracketed field or the end of the text.
#   
#   @note       Used by _redact_headers() to prevent part of a secret
#               header value from remaining visible.
#
#   @test       Note:           Test header with proper closing bracket
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_bracket_field_end(q{[Authorization: csf-secret] [Status: 200]}, 0), qq{\n};"
#               Result:         26
#   
#               Note:           Test header with bad extra closing bracket
#                               Prevents part of its secret from being exposed.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_bracket_field_end(q{[Authorization: secret]still-secret] [Status: 401]}, 0), qq{\n};"
#               Result:         35
#
#   @params     text            str         Text field with bracket
#               start           int         Pos where the search begins
#
#   @return     end             int         Closing bracket position or undef
#                                               int         Pos of closing bracket ']'
#                                               undef       No closing bracket found
# #

sub _bracket_field_end
{
    # #
    #   $text:          [Authorization: csf-secret] [Status: 200]
    #   $start:         0
    #   $text_leng      43
    #   $close          28
    # #

    my ( $text, $start ) = @_;

    my $text_len    = length( $text );
    my $close       = index( $text, ']', $start );

    while ( $close >= 0 )
    {
        my $after = $close + 1;

        $after++
            while $after < $text_len and
                  substr( $text, $after, 1 ) =~ /[ \t]/;

        return $close
            if $after == $text_len or
               substr( $text, $after, 1 ) eq '[';

        $close = index( $text, ']', $close + 1 );
    }

    return;
}

# #
#   Secrets › Helper › Find Value Length
#   
#   Find how many chars belong to an assigned value.
#   
#   Support quoted and unquoted values. If a quoted value has no
#   closing quote, treat everything after it as part of the value.
#   
#   @test       Note:           Find length of the value
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_value_get_len(q{password=hidden; mode=public}, 9, qr/[;\s]/), qq{\n};"
#               Result:         6
#   
#   @params     text            str         Text containing the value
#               start           int         Pos where the value begins
#               regex_stop      regex       Chars that end an unquoted value
#   
#   @return     length          int|undef   Length of value
#                                               int         num of chars in value
#                                               undef       no value is found
# #

sub _value_get_len
{
    my ( $text, $start, $regex_stop ) = @_;

    my $text_len = length( $text );
    return
        if $start >= $text_len;

    return length( LABEL_SECRET_REDACT )
        if substr( $text, $start, length( LABEL_SECRET_REDACT ) ) eq LABEL_SECRET_REDACT;

    my $first = substr( $text, $start, 1 );
    if ( $first eq '"' or $first eq "'" )
    {
        my $cursor = $start + 1;
        while ( $cursor < $text_len )
        {
            # #
            #   Skip escaped pairs: \", \', or \\
            #   make sure we don't confuse these for closign quotes
            # #

            my $char = substr( $text, $cursor, 1 );
            if ( $char eq '\\' and $cursor + 1 < $text_len )
            {
                $cursor += 2;
                next;
            }

            return $cursor - $start + 1
                if $char eq $first;

            $cursor++;
        }

        # #
        #   Value starts with a quote, but no closing quote was found.
        #   Treat all remaining text as the value so that no secret
        #   is exposed.
        #       Input:      password="csf-secret Status: 500
        #       Value:      "csf-secret Status: 500
        # #

        return $text_len - $start;
    }

    my $cursor = $start;
    $cursor++
        while $cursor < $text_len and substr( $text, $cursor, 1 ) !~ $regex_stop;

    return
        if $cursor == $start;

    return $cursor - $start;
}

# #
#   Secrets › Check Secret Url Query Name
#   
#   Check if a url query param name is a secret.
#   
#   Url query names might be encoded to hide secret words; decode them
#   before checking if they have a secret:
#   
#       api%5Fkey               => api_key
#       user%5Bpassword%5D      => user[password]
#       database+password       => database password
#   
#   After the decode, names like api_key or password can be detected
#   and treated as secret.
#   
#   Structured names are split into separate parts so names like
#   user[password] still detect "password" as a secret.
#   
#   Oversized names and names that need too many decode passes are
#   treated as secret.
#   
#   @test       Note:           Detect password inside encoded name
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_query_name_is_secret(q{user%5Bpassword%5D}), qq{\n};"
#               Result:         1
#   
#   @params     name_encoded    str         Encoded url query param name
#   @return     is_private      int         If query name is secret
#                                               1           Name is secret / unsafe
#                                               0           Name is public / invalid
# #

sub _query_name_is_secret
{
    my ( $name_encoded ) = @_;

    my $name_invalid = !defined( $name_encoded ) || ref( $name_encoded );

    ConfigServer::DebugLocal::log( 1, 'warn', "status:[public; invalid query name input]" )
        if $name_invalid;

    return 0
        if $name_invalid;

    my $name_bytes      = _octet_length( "$name_encoded" );
    my $name_too_long   = $name_bytes > SETTING_NAME_BYTE_MAXIMUM;

    ConfigServer::DebugLocal::log( 1, 'warn',
        "len:[$name_bytes] " .
        "max:[" . SETTING_NAME_BYTE_MAXIMUM . "] " .
        "status:[secret; query name exceeds byte limit]"
    ) if $name_too_long;

    return 1
        if $name_too_long;

    my $name_decoded    = "$name_encoded";
    $name_decoded       =~ tr/+/ /;

    # #
    #   Limit how many levels deep we want to bother with nested
    #   decoding, block excessive rescans.
    #   
    #   Nested rescans are limited by URL_DECODE_PASS_MAXIMUM (8).
    #   The following would hit that limit:
    #       Eg:     _query_name_is_secret( "user%25252525252525255Bpassword%25252525252525255D" );
    # #

    my $is_nested_reached;
    ( $name_decoded, $is_nested_reached ) = _octet_percent_decode( $name_decoded );

    ConfigServer::DebugLocal::log( 1, 'warn',
        "limit:[" . URL_DECODE_PASS_MAXIMUM . "] " .
        "status:[secret; percent decode limit reached]"
    ) if $is_nested_reached;

    # nested decode limit reached; flag as secret
    return 1
        if $is_nested_reached;

    if ( !utf8::is_utf8( $name_decoded ) and $name_decoded =~ /[\x80-\xFF]/ )
    {
        my $name_utf8 = eval
        {
            Encode::decode( 'UTF-8', $name_decoded, Encode::FB_CROAK( ) )
        };

        return 1
            if !defined( $name_utf8 ) or $@;

        $name_decoded = $name_utf8;
    }

    $name_decoded =~ s/\p{Cc}//g;
    $name_decoded =~ s/\p{Cf}//g
        if utf8::is_utf8( $name_decoded );

    my $name_is_secret = is_config_secret( $name_decoded );

    ConfigServer::DebugLocal::log( 1, 'ok', "route:[complete query name] status:[secret]" )
        if $name_is_secret;

    return 1
        if $name_is_secret;

    # #
    #   Also recognize structured names such as user[password].
    #       Eg: Form HTML:      <input name="user[password]">
    #           Browser Sends:  ?user%5Bpassword%5D=csf-secret
    #           Decoded:        user[password]=csf-secret
    #
    #   This loop splits them into:
    #       user
    #       password
    # #

    my @name_parts = grep
    {
        length( $_ )
    } split( /[^A-Za-z0-9_-]+/, $name_decoded );

    my $secret_seg_i = grep
    {
        is_config_secret( $_ )
    } @name_parts;

    ConfigServer::DebugLocal::log( 1, $secret_seg_i ? 'ok' : 'info',
        "parts:[" . scalar( @name_parts ) . "] " .
        "matches:[$secret_seg_i] " .
        "route:[structured query name] " .
        "status:[" . ( $secret_seg_i ? 'secret' : 'public' ) . "]"
    );

    return $secret_seg_i ? 1 : 0;
}

# #
#   Secrets › Url › Check Path Part
#
#   Check one part of a url path for secret names / token patterns.
#   Decode url escapes first. Treat oversized parts as secret.
#
#   @test       Note:           Decode an encoded token name, mark as secret
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_url_path_segment_is_secret(q{api-%74oken-value}), qq{\n};"
#               Result:         1
#
#   @params     segment_encoded str         Url path part to check
#
#   @return     is_secret       int         If the url path part is secret
#                                               1           Path part is secret
#                                               0           No secret match found
# #

sub _url_path_segment_is_secret
{
    my ( $segment_encoded ) = @_;
    my $segment_bytes = _octet_length( $segment_encoded );

    # return flagged as secret; treat parts over the byte limit as secret
    return 1
        if _octet_length( $segment_encoded ) > SETTING_NAME_BYTE_MAXIMUM;

    my ( $segment_decoded, $is_nested_reached ) = _octet_percent_decode( $segment_encoded );
    # return flagged as secret; decode limit, or contains \ or /
    return 1
        if $is_nested_reached or
            $segment_decoded =~ m{[\\/]};

    # decode utf8 bytes; treat invalid utf8 as not safe
    if ( !utf8::is_utf8( $segment_decoded ) and $segment_decoded =~ /[\x80-\xFF]/ )
    {
        my $segment_utf8 = eval
        {
            Encode::decode( 'UTF-8', $segment_decoded, Encode::FB_CROAK( ) )
        };

        return 1
            if !defined( $segment_utf8 ) or $@;

        $segment_decoded = $segment_utf8;
    }

    $segment_decoded =~ s/\p{Cc}//g;
    $segment_decoded =~ s/\p{Cf}//g
        if utf8::is_utf8( $segment_decoded );

    my $segment_checked = _redact_registered_values( $segment_decoded );

    return 1
        if $segment_checked ne $segment_decoded or
           $segment_decoded =~ /$AWS_TOKEN_MATCH/ or
           $segment_decoded =~ /$JWT_TOKEN_MATCH/ or
           $segment_decoded =~ /$UUID_TOKEN_MATCH/;

    # split into words; check each for a secret name
    my $loop = 0;
    for my $name_part ( grep { length( $_ ) } split( /[^A-Za-z0-9_-]+|[-_]+/, $segment_decoded ) )
    {
        $loop++;
        return 1
            if is_config_secret( $name_part );
    }

    return 0;
}

# #
#   Secrets › Url › Split Url Components
#   
#   Split a url into its scheme, authority, path, and query.
#   Accept valid scheme or protocol prefix //
#   
#   @test       Note:           Split one url into 4 components
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print join(q{ | }, ConfigServer::Secrets::_url_components(q{https://configserver.dev/check?mode=test})), qq{\n};"
#               Result:         https | configserver.dev | /check | mode=test
#   
#   @params     url             str         Url to split
#   
#   @return     scheme          str         Url scheme
#               authority       str         Host and optional login info
#               path            str         Url path or empty str
#               query           str         Url query or undef
#                                               str         Query found
#                                               undef       Url has no query
# #

sub _url_components
{
    # #
    #   $url:           https://configserver.dev/check?mode=test
    #   $scheme:        https
    #   $scheme_end:    5
    #   $remainder:     configserver.dev/check
    #   $path_pos:      16
    #   $authority:     configserver.dev
    #   $path:          /check
    #   $query:         mode=test
    # #

    my ( $url ) = @_;

    my $scheme_end = index( $url, '://' );
    my ( $scheme, $remainder );

    if ( index( $url, '//' ) == 0 )
    {
        $scheme     = '';
        $remainder  = substr( $url, 2 );
    }
    else
    {
        return
            if $scheme_end < 1;

        $scheme = substr( $url, 0, $scheme_end );
        return
            if $scheme !~ /\A[A-Za-z][A-Za-z0-9+.-]*\z/;

        # everything after 'scheme://'
        $remainder = substr( $url, $scheme_end + 3 );
    }

    # separate '?query' from the url
    my $query_pos = index( $remainder, '?' );
    my $query;

    if ( $query_pos >= 0 )
    {
        $query      = substr( $remainder, $query_pos + 1 );
        $remainder  = substr( $remainder, 0, $query_pos );
    }

    # separate 'authority' from the path
    my $path_pos    = index( $remainder, '/' );
    my $authority   = $path_pos >= 0 ? substr( $remainder, 0, $path_pos ) : $remainder;
    my $path        = $path_pos >= 0 ? substr( $remainder, $path_pos ) : '';

    # just debug vars
    my $found_scheme    = defined( $scheme ) ? 1 : 0;
    my $found_authority = $authority ne '' ? 1 : 0;
    my $found_path      = $path ne '' ? 1 : 0;
    my $found_query     = defined( $query ) ? 1 : 0;

    ConfigServer::DebugLocal::log( 1, 'ok',
        "scheme:[$found_scheme] " .
        "authority:[$found_authority] " .
        "path:[$found_path] " .
        "query:[$found_query] " .
        "status:[split url components]"
    );

    return ( $scheme, $authority, $path, $query );
}

# #
#   Secrets › Log › Flatten Controls
#   
#   Remove all crap like esc codes, control chars, invisible unicode.
#   Replace linebreaks / tabs with spaces, replace multiple spaces with 1.
#   
#   @ref        https://en.wikipedia.org/wiki/C0_and_C1_control_codes
#   
#   @test       Note:           Replace linebreaks and tabs with spaces.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_log_flatten_ctrls(qq{CSF\nTest\tString}), qq{\n};"
#               Result:         CSF Test String
#   
#   @params     text            str         Text to clean
#               keep_linebreaks int         If linebreaks remain during redaction
#                                               1           Preserve as \n
#                                               0           Replace with spaces
#   @return     text            str         Text cleaned
# #

sub _log_flatten_ctrls
{
    my ( $text, $keep_linebreaks ) = @_;

    # #
    #   If text has utf8 bytes, decode so that unicode control chars 
    #   can be found and removed properly.
    #
    #   Invalid utf8 stays unchanged, handled as raw bytes.
    # #

    my $text_is_decoded_s1  = utf8::is_utf8( $text );
    my $text_decoded_byte   = 0;

    if ( !$text_is_decoded_s1 and $text =~ /[\x80-\xFF]/ )
    {
        my $text_encoded    = $text;
        my $text_decoded    = eval
        {
            Encode::decode( 'UTF-8', $text_encoded, Encode::FB_CROAK( ) )
        };

        if ( defined( $text_decoded ) and !$@ )
        {
            $text               = $text_decoded;
            $text_decoded_byte  = 1;
        }
    }

    # #
    #   $text could have been decoded above, so check again to 
    #   see if $text now has unicode chars.
    # #

    my $text_is_decoded_s2 = utf8::is_utf8( $text );

    $text =~ s/\x1B\][^\x07]*(?:\x07|\x1B\\)//g;
    $text =~ s/\x1B\[[0-?]*[ -\/]*[@-~]//g;
    $text =~ s/\x9B[0-?]*[ -\/]*[@-~]//g;

    if ( $keep_linebreaks )
    {
        $text =~ s/$REGISTRY_LINE_BREAKS/\n/g;
        $text =~ s/\t/ /g;
    }
    else
    {
        $text =~ s/(?:$REGISTRY_LINE_BREAKS|\t)/ /g;
    }

    $text =~ s/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]//g;

    # #
    #   Remove remaining unicode c1 control chars (U+0080 - U+009F)
    #   Only apply to decoded unicode text so raw utf8 bytes remain intact.
    # #

    $text =~ s/[\x{0080}-\x{009F}]//g
        if $text_is_decoded_s2;

    # remove raw c1 bytes from input that are not valid utf8
    $text =~ s/[\x80-\x9F]//g
        if !$text_is_decoded_s2;

    # remove invis unicode format / directional controls
    $text =~ s/\p{Cf}//g
        if $text_is_decoded_s2;

    # convert spaces; two or more become one
    $text =~ s/[ ]{2,}/ /g;

    my $out = $text_decoded_byte ? Encode::encode_utf8( $text ) : $text;

    ConfigServer::DebugLocal::log( 1, 'ok',
        "wide_before:[" . ( $text_is_decoded_s1 ? 1 : 0 ) . "] " .
        "wide_after:[" . ( $text_is_decoded_s2 ? 1 : 0 ) . "] " .
        "decoded_bytes:[$text_decoded_byte] " .
        "status:[flatten log controls]"
    );

    return $out
}

# #
#   Secrets › Log › Fit Record
#   
#   Keep log record within byte limit. Shorten oversized records
#   without splitting unicode chars, then add truncation marker.
#   
#   @test       Note:           Shorten oversized log to its byte limit.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print length(ConfigServer::Secrets::_log_fit_record(q{A} x 70000, 0)), qq{\n};"
#               Result:         65536
#   
#               Note:           Keep unicode char in the result
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'my $text = "csf " . chr(0x2603); print ConfigServer::Secrets::_log_fit_record($text, 0), qq{\n};'
#               Result:         csf ☃
#   
#   @params     text            str         Log text
#               is_already_cut  int         If text was previously shortened
#                                               1           Text already shortened
#                                               0           Text not shortened
#   @return     record          str         Byte limited log record
# #

sub _log_fit_record
{
    my ( $text, $is_already_cut ) = @_;

    my $text_chars_decoded = utf8::is_utf8( $text );

    # decode utf8 bytes before truncation so that no char is split
    if (
        !$text_chars_decoded and
        length( $text ) > LOG_BYTE_MAXIMUM and
        $text =~ /[\x80-\xFF]/
    )
    {
        my $text_encoded        = $text;
        my $text_decoded        = eval
        {
            Encode::decode( 'UTF-8', $text_encoded, Encode::FB_CROAK( ) )
        };

        if ( defined( $text_decoded ) and !$@ )
        {
            $text               = $text_decoded;
            $text_chars_decoded = 1;
        }
    }

    my $text_record = $text_chars_decoded ? Encode::encode_utf8( $text ) : $text;

    # flag oversized text to be truncated
    $is_already_cut = 1
        if length( $text_record ) > LOG_BYTE_MAXIMUM;

    ConfigServer::DebugLocal::log( 1, 'info',
        "cut:[$is_already_cut] status:[log length]"
    );

    # return text that doesn't need truncation marker
    return $text_record
        if !$is_already_cut;

    # reserve some space for the truncation marker
    my $payload_ceil = LOG_BYTE_MAXIMUM - length( LABEL_TRUNCATE );

    # only if $text_chars_decoded = 1; decode utf8 unicode text (utf8 flag)
    if ( $text_chars_decoded )
    {
        my $accepted        = 0;
        my $rejected        = length( $text );

        # #
        #   Figure out how many chars fit within the limit of
        #   65,536 byte LOG_BYTE_MAXIMUM without cutting a multibyte
        #   utf8 char in half:
        #       € = 3 bytes; keep the entire char if it fits; or remove
        #
        #   Reserve 12 bytes for the truncation marker:
        #       65,536 - 12 = 65,524 bytes of space free
        #   
        #   Grab a test length half between $accepted and $rejected
        #   to see if it fits in our free space. If it fits, try more
        #   chars; otherwise, try less chars. Repeat until we find
        #   the largest amount that fits.
        # #

        # true as long as this search has more chars to test
        while ( $accepted < $rejected )
        {
            my $sample_len      = int( ( $accepted + $rejected + 1 ) / 2 );
            my $sample_bytes    = Encode::encode_utf8( substr( $text, 0, $sample_len ) );

            if ( length( $sample_bytes ) <= $payload_ceil )
            {
                 # sample str fits; accept this len, try more
                $accepted = $sample_len;
            }
            else
            {
                # sample str too big; reject len, try less
                $rejected = $sample_len - 1;
            }
        }

        # if $text_chars_decoded = 1; cut by chars, then encode to bytes
        $text_record = Encode::encode_utf8( substr( $text, 0, $accepted ) );
    }
    else
    {
        # #
        #   if $text_chars_decoded = 0; $text_record is byte str, cut
        #   directly to byte limit since each ascii char = 1 byte
        # #

        $text_record = substr( $text_record, 0, $payload_ceil );
    }

    my $out = $text_record . LABEL_TRUNCATE;

    ConfigServer::DebugLocal::log( 1, 'ok',
        "cut:[1] bytes:[" . length( $out ) . "] " .
        "max:[" . LOG_BYTE_MAXIMUM . "] " .
        "status:[record truncated]"
    );

    return $out;
}

# #
#   Secrets › Config › Read Setting Name
#   
#   Return setting name and the text before its value.
#   Return nothing when the line does not begin with a valid name.
#   
#   Eg:         $prefix = 'UI_PASS = ';
#               $name   = 'UI_PASS';
#   
#   @test       Note:           Read a setting name and its assignment prefix.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'my ($prefix, $name) = ConfigServer::Secrets::_config_parse_line(q{  UI_PASS = csf-secret}); print qq{Prefix: [$prefix]\nName: [$name]\n};'
#               Result:         Prefix: [  UI_PASS = ]
#                               Name: [UI_PASS]
#   
#   @params     line            str         Line to check
#   @return     prefix          str         Text before setting value
#               name            str         Setting name
# #

sub _config_parse_line
{
    my ( $line ) = @_;

    my $line_size   = length( $line );
    my $cursor      = 0;

    while ( $cursor < $line_size and substr( $line, $cursor, 1 ) =~ /\s/ )
    {
        $cursor++;
    }

    # return if cursor is past the end of the line, or not on a letter
    return
        if $cursor >= $line_size or substr( $line, $cursor, 1 ) !~ /[A-Za-z]/;

    my $name_start = $cursor;
    $cursor++;
    while ( $cursor < $line_size and substr( $line, $cursor, 1 ) =~ /[A-Za-z0-9_-]/ )
    {
        $cursor++;
    }

    my $name = substr( $line, $name_start, $cursor - $name_start );
    return
        if substr( $name, -1, 1 ) !~ /[A-Za-z0-9_]/;

    while ( $cursor < $line_size and substr( $line, $cursor, 1 ) =~ /\s/ )
    {
        $cursor++;
    }

    if ( $cursor < $line_size and substr( $line, $cursor, 1 ) =~ /[=:]/ )
    {
        $cursor++;
        while ( $cursor < $line_size and substr( $line, $cursor, 1 ) =~ /\s/ )
        {
            $cursor++;
        }
    }

    ConfigServer::DebugLocal::log( 1, 'ok', "setting:[$name] cursor:[$cursor] status:[read]" );

    # #
    #   line        UI_PASS = csf-secret
    #   cursor      12
    #   name        UI_PASS
    # #

    # return prefix and setting name (UI_PASS)
    return ( substr( $line, 0, $cursor ), $name );
}

# #
#   Secrets › Bounded › Get File Lock
#   
#   Try to get non blocking file lock. Retry for a limited amount
#   of time instead of waiting forever.
#   
#   @test       Note:           Get shared lock without waiting forever.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -MFile::Temp=tempfile -MFcntl=:flock -e 'my ($fh) = tempfile(); print ConfigServer::Secrets::_bounded_lock($fh, LOCK_SH) ? 1 : 0, qq{\n};'
#               Result:         1
#   
#   @params     fh              filehandle  File to lock
#               lock_mode       int         Type of lock to request
#                                               LOCK_SH     Shared lock
#                                               LOCK_EX     Exclusive lock
#   @return     locked          int         If the file was locked
#                                               1           File was locked
#                                               undef       Lock could not be obtained
# #

sub _bounded_lock
{
    my ( $fh, $lock_mode ) = @_;

    # #
    #   Try to get a shared file lock.
    #   
    #   Another app can ignore this lock, so make sure
    #   read_file() can also check if the file changed
    #   while it's being read.
    #   
    #   @const          LOCK_POLL_COUNT         20
    #                   LOCK_POLL_INTERVAL      0.01
    # #

    for my $poll ( 1 .. LOCK_POLL_COUNT )
    {
        return 1
            if CORE::flock( $fh, $lock_mode | Fcntl::LOCK_NB() );

        select( undef, undef, undef, LOCK_POLL_INTERVAL )
            if $poll < LOCK_POLL_COUNT;
    }

    # couldn't get lock within polling limit
    return;
}

# #
#   Secrets › Validate Unsigned Int
#   
#   Return unsigned int (0 or more) within min / max values.
#   
#   @test       Note:           Accept a num inside the allowed range
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::is_unsigned_int(20, 1, 100), qq{\n};"
#               Result:         20
#   
#   @params     val             str         Value to check
#               min             int         Min num allowed
#               max             int         Max num allowed
#   
#   @return     num             int         Validated num or undef
#                                               int         Value within allowed range
#                                               undef       Value invalid / outside range
# #

sub is_unsigned_int
{
    my ( $val, $min, $max ) = @_;

    return
        if !defined( $val ) or ref( $val ) or "$val" !~ /\A([0-9]+)\z/;

    my $num = 0 + $1;
    return
        if $num < $min or $num > $max;

    return $num;
}

# #
#   Secrets › Validate › Registry Value
#   
#   Check if value can be stored in the secret registry.
#   
#   Reject values that are public, missing values, refs, exempt words,
#   and values outside size limits.
#   
#   @test       Note:           Accept a valid API key value for registration.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_validate_registry_value(q{API_KEY}, q{csf-secret}), qq{\n};"
#               Result:         csf-secret
#   
#   @params     name            str         Setting name to check
#               value           str         Value to check
#   
#   @return     secret          str         Checked secret value
#                                               str         Secret value accepted
#                                               undef       Secret value rejected
# #

sub _validate_registry_value
{
    my ( $name, $value ) = @_;

    my $name_display    = !defined( $name ) ? 'undef' : ref( $name ) ? ref( $name ) : "$name";
    my $name_is_secret  = is_config_secret( $name );
    my $value_invalid   = !defined( $value ) || ref( $value );
    my $params_reject   = !$name_is_secret || $value_invalid;
    my $reject_reason   = !$name_is_secret
                            ? 'name is public or invalid'
                            : !defined( $value )
                                ? 'value is undef'
                                : 'value is ref';

    ConfigServer::DebugLocal::log( 1, 'warn',
        "name:[$name_display] status:[rejected; $reject_reason]"
    ) if $params_reject;

    return
        if $params_reject;

    my $secret = "$value";
    # store one utf8 byte, prevent same unicode secret being registered twice
    $secret = Encode::encode_utf8( $secret )
        if utf8::is_utf8( $secret );

    my $secret_bytes        = _octet_length( $secret );
    my $secret_too_short    = $secret_bytes < SECRET_BYTE_MINIMUM;
    my $secret_too_long     = $secret_bytes > SECRET_BYTE_MAXIMUM;
    my $secret_is_exempt    = exists( $REGISTRY_EXEMPT{lc( $secret )} );
    my $secret_rejected     = $secret_too_short || $secret_too_long || $secret_is_exempt;

    $reject_reason  = $secret_too_short ? 'value is below minimum byte limit'
                    : $secret_too_long  ? 'value exceeds maximum byte limit'
                    : 'value is exempt';

    ConfigServer::DebugLocal::log( 1, 'warn',
        "name:[$name_display] len:[$secret_bytes] " .
        "min:[" . SECRET_BYTE_MINIMUM . "] " .
        "max:[" . SECRET_BYTE_MAXIMUM . "] " .
        "status:[rejected; $reject_reason]"
    ) if $secret_rejected;

    return
        if $secret_rejected;

    ConfigServer::DebugLocal::log( 1, 'ok',
        "name:[$name_display] len:[$secret_bytes] " .
        "min:[" . SECRET_BYTE_MINIMUM . "] " .
        "max:[" . SECRET_BYTE_MAXIMUM . "] " .
        "status:[accepted]"
    );

    return $secret;
}

# #
#   Secrets › Validate › Protected File
#   
#   Check that an opened secret file is safe to read.
#   
#   When $state_before is provided, confirm the file did not change
#   while it was being read.
#   
#   @test       Note:           Reject file when expected owner is wrong
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -MFile::Temp=tempfile -e 'my ($fh, $path) = tempfile(); chmod(0600, $path); my $owner = (stat($fh))[4]; my $state = ConfigServer::Secrets::_validate_secret_file($fh, $path, $owner + 1, 1024, undef); print defined($state) ? 1 : 0, qq{\n}; close($fh);'
#               Result:         0
#   
#               Note:           Accept valid regular file, correct owner and perms
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -MFile::Temp=tempfile -e 'my ($fh, $path) = tempfile(); chmod(0600, $path); my $owner = (stat($fh))[4]; my $state = ConfigServer::Secrets::_validate_secret_file($fh, $path, $owner, 1024, undef); print defined($state) ? 1 : 0, qq{\n}; close($fh);'
#               Result:         1
#   
#   @params     fh              handle      Open file handle
#               path            str         Path used to open the file
#               owner           int         Required owner UID
#               byte_ceil       int         Max file size in bytes
#               state_before    arrayref    Earlier file state; undef for first check
#   
#   @return     state_fh        arrayref    File state when all checks pass
#                                           undef if any check fails
# #

sub _validate_secret_file
{
    my ( $fh, $path, $owner, $byte_ceil, $state_before ) = @_;

    my @state_curr  = stat( $fh );
    my @state_path  = lstat( $path );

    # #
    #   Run safety checks; if any fail, return.
    #   
    #   Each check listed below because there's a crap ton.
    #   Keep errors generic as to not disclose info.
    # #

    ConfigServer::DebugLocal::log( 1, 'info', "path:[$path] safetycheck:[start]" );

    my $failure =
        !@state_curr
            ? "stat file handle failed"

        : !@state_path
            ? "lstat path failed"

        : !Fcntl::S_ISREG( $state_curr[ 2 ] )
            ? "file handle is not a regular file"

        : !Fcntl::S_ISREG( $state_path[ 2 ] )
            ? "path is not a regular file"

        : $state_curr[ 0 ] != $state_path[ 0 ]
            ? "filesystem device does not match"

        : $state_curr[ 1 ] != $state_path[ 1 ]
            ? (
                 ConfigServer::DebugLocal::DEBUG( ) == 5
                    ? "inode mismatch; handle=$state_curr[ 1 ], path=$state_path[ 1 ]"
                    : "file path does not match the opened file"
            )

        : $state_curr[ 3 ] != FILE_HARDLINK_MAX
            ? (
                ConfigServer::DebugLocal::DEBUG( ) == 5
                    ? "hard link count is $state_curr[ 3 ]; expected " .
                        FILE_HARDLINK_MAX
                    : "file has an unsafe hard link count"
            )

        : $state_curr[ 4 ] != $owner
        #   ? "file owner $state_curr[ 4 ] does not match; expected $owner"
            ? "file owner does not match expected owner"

        : ( $state_curr[ 2 ] & 0077 ) != 0
            ? "group or other file permissions are enabled"

        : $state_curr[ 7 ] > $byte_ceil
            ? (
                ConfigServer::DebugLocal::DEBUG( ) == 5
                    ? "file size is $state_curr[ 7 ]; maximum is $byte_ceil"
                    : "file size exceeds maximum bytes allowed"
            )

        : "";

    # fail; one of the req conditions above were not met
    if ( $failure ne "" )
    {
        ConfigServer::DebugLocal::log( 1, 'fail', "path:[$path] safetycheck:[failed] reason:[$failure]" );
        return;
    }

    # #
    #   Compare current state of file details with the earlier state.
    #   Reject file if anything changed while reading the file.
    # #

    if ( defined( $state_before ) )
    {
        for my $field ( 0, 1, 2, 3, 4, 7, 9, 10 )
        {
            # return state check failed
            return
                if $state_curr[ $field ] != $state_before->[ $field ];
        }
    }

    ConfigServer::DebugLocal::log( 1, 'ok', "path:[$path] safetycheck:[passed]" );

    # returns stat(); dev, ino, mode, nlink, uid, gid, rdev, size, atime, mtime, ctime, blockize, blocks
    return \@state_curr;
}

# #
#   Secrets › Validate › File Parent Dirs
#   
#   Check every parent dir in a protected file path. Will return
#   nothing if at least one parent in the path failed the
#   requirements.
#   
#   Reject missing dirs, symlinks, unsafe owners, bad perms, and
#   paths with:
#       '.'
#       ..'
#
#   Folders that are root owned with sticky bit (/tmp) are allowed.
#   
#   @note       Windows returns 1 and stops; doesn't have lstat()
#
#   @test       Note:           Accept trusted parent path
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'print ConfigServer::Secrets::_validate_secret_parent_dirs(q{/usr/local/csf/lib/ConfigServer/Secrets.pm}, 0) ? qq{Safe\n} : qq{Unsafe\n};'
#               Result:         Safe
#   
#               Note:           Reject missing parent path
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'print ConfigServer::Secrets::_validate_secret_parent_dirs(q{/usr/local/csf/lib/ConfigServer/__csf_missing_parent_test__/secret.conf}, 0) ? qq{Safe\n} : qq{Unsafe\n};'
#               Result:         lstat failed for parent component [__csf_missing_parent_test__] (component 6): No such file or directory
#                               Unsafe
#   
#   @params     path            str         Absolute file path to check
#               owner           int         Allowed parent dir owner uid
#   
#   @return     is_trusted      int         If parent path is trusted
#                                               1           Parent path safe
#                                               undef       Parent path unsafe
# #

sub _validate_secret_parent_dirs
{
    # #
    #   $path   =   /usr/local/csf/lib/ConfigServer/Secrets.pm
    #   $owner  =   1000
    # #

    my ( $path, $owner ) = @_;

    # abort on windows; doesn't use these linux parent checks
    return 1
        if $^O eq 'MSWin32';

    # #
    #   Split path into separate dir names
    #   
    #   $path       =   /usr/local/csf/lib/ConfigServer/Secrets.pm
    #   $volume     =   []
    #   $dirs       =   /usr/local/csf/lib/ConfigServer/
    #   $owner      =   1000
    # #

    my ( $volume, $dirs )   = File::Spec->splitpath( $path );
    my @components          = File::Spec->splitdir( $dirs );
    my $dir_curr            = File::Spec->catpath( $volume, File::Spec->rootdir( ), '' );
    my $component_num       = 0;
    for my $component ( @components )
    {
        next
            if $component eq '';

        $component_num++;

        if ( $component eq '.' or $component eq '..' )
        {
            warn "Failure: Path cannot contain '.' or '..' [$component] (component $component_num)\n"
                if ConfigServer::DebugLocal::DEBUG( ) >= 1;

            return;
        }

        $dir_curr = File::Spec->catdir( $dir_curr, $component );
        my @state = lstat( $dir_curr );

        warn "lstat failed for parent component [$component] (component $component_num): $!\n"
            if ConfigServer::DebugLocal::DEBUG( ) >= 1 and !@state;

        # reject missing dirs, not dirs, symlinks, unsafe owners
        return
            if !@state or
               !Fcntl::S_ISDIR( $state[ 2 ] ) or
               ( $state[ 4 ] != 0 and $state[ 4 ] != $owner );
  
        my $is_dir_writable         = ( $state[ 2 ] & 0022 ) != 0;
        my $is_dir_root_stickybit   = ( $state[ 4 ] == 0 and ( $state[ 2 ] & 01000 ) != 0 );

        # #
        #   Writable parent dirs are rejected because other users 
        #   could replace/redirect files in them.
        #
        #   @note       Allowed Dirs:
        #                   - Dir cannot be group or world writable
        #                   - Dir is owned by root + sticky bit (/tmp, /var/tmp)
        #                       find / -type d -user root -perm -1000 -printf '%m %u %p\n' 2>/dev/null
        # #
    
        return
            if $is_dir_writable and !$is_dir_root_stickybit;
    }

    return 1;
}

# #
#   Secrets › Reader › Finish Protected File
#   
#   Release file from its lock; and close.
#   
#   @test       Note:           Unlock and close temp secret file.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -MFile::Temp=tempfile -MFcntl=:flock -e 'my ($fh) = tempfile(); flock($fh, LOCK_SH) or die $!; print ConfigServer::Secrets::_secrets_reader_finish($fh), qq{\n};'
#               Result:         1
#   
#   @params     fh              filehandle  Open locked fh
#   @return                     int         If file was unlocked and closed
#                                               1           File unlocked and closed
# #

sub _secrets_reader_finish
{
    my ( $fh ) = @_;

    my $fh_unlocked     = CORE::flock( $fh, Fcntl::LOCK_UN() );
    my $fh_closed       = close( $fh );

    Carp::croak 'Secret file cannot release file lock'
        if !$fh_unlocked;

    Carp::croak 'Secret file cannot close file'
        if !$fh_closed;

    return 1;
}

# #
#   Secrets › Reader › Abort Protected File
#
#   Release lock, close the file, and throw the custom error.
#   Adds custom message if unlocking / closing fails.
#
#   @test       Note:           Close a temp file and throw custom err.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -MFile::Temp -e "ConfigServer::Secrets::_secrets_reader_abort((File::Temp::tempfile())[0], q{Test read failed}, 0);"
#               Result:         Test read failed at -e line 1.
#
#   @params     fh              filehandle  Open file to close
#               msg             str         Custom err to return
#               was_locked      int         If the file lock must be released
#                                               1           File locked
#                                               0           File not locked
#   @return     void                        Throws err
# #

sub _secrets_reader_abort
{
    my ( $fh, $msg, $was_locked ) = @_;

    my $cleanup_failed = 0;

    $cleanup_failed = 1
        if $was_locked and !CORE::flock( $fh, Fcntl::LOCK_UN() );

    $cleanup_failed = 1
        if !close( $fh );

    $msg .= '; protected file cleanup also failed'
        if $cleanup_failed;

    Carp::croak $msg;
}

# #
#   Secrets › Reader › Split Lines
#   
#   Split file's contents into separate lines.
#   Reject if the file has more than the allowed number of lines.
#   Remove empty lines from the end.
#   
#   @test       Note:           Split three lines and remove trailing empty line
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print join(q{, }, ConfigServer::Secrets::_secrets_reader_split_lines(qq{one\ntwo\nthree\n}, 10)), qq{\n};"
#               Result:         one, two, three
#   
#   @params     contents        str         File contents to split
#               line_ceil       int         Max num of lines
#   
#   @return     lines           arr         Lines read from contents
# #

sub _secrets_reader_split_lines
{
    my ( $contents, $line_ceil ) = @_;

    my @lines = split( $REGISTRY_LINE_BREAKS, $contents, $line_ceil + 1 );

    # reject content containing more than the allowed lines
    if ( @lines > $line_ceil )
    {
        my $overflow = pop @lines;
        Carp::croak 'Secret file has too many lines'
            if $overflow !~ /\A(?:$REGISTRY_LINE_BREAKS)*\z/;
    }

    # #
    #   Remove empty lines from the end of the array.
    #       "" = Blank line in split
    #   
    #       Before: ( "csf", "", "firewall", "", "" )
    #       After:  ( "csf", "", "firewall" )
    # #

    pop @lines
        while @lines and $lines[ -1 ] eq '';

    return @lines;
}

# #
#   Secrets › Close File During Exec
#   
#   Close protected files during exec(); ensure another process can't
#   inherit it.
#   
#   @test       Note:           Protect a temp file handle from exec
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -MFile::Temp=tempfile -e "print(ConfigServer::Secrets::_set_close_on_exec((File::Temp::tempfile())[0]) ? 1 : 0, qq{\n});"
#               Result:         Linux:      1
#                               Windows:    0
#   
#   @params     fh              filehandle  Open file handle
#   
#   @return     is_protected    int         If FD_CLOEXEC was enabled
#                                               1           File handle protected
#                                               undef       Protection unavailable or failed
# #

sub _set_close_on_exec
{
    my ( $fh ) = @_;

    # #
    #   Load descriptor settings required by fcntl()
    #   
    #   Linux:
    #       F_GETFD:        1       Read file descriptor flags
    #       F_SETFD:        2       Change file descriptor flags
    #       FD_CLOEXEC:     1       Close file during exec()
    #   
    #   Windows:
    #       F_GETFD:        undef   Not available
    #       F_SETFD:        undef   '
    #       FD_CLOEXEC:     undef   '
    # #

    my $flags_cmd_get   = eval { Fcntl::F_GETFD( ) };
    my $flags_cmd_set   = eval { Fcntl::F_SETFD( ) };
    my $flag_cloexec    = eval { Fcntl::FD_CLOEXEC( ) };

    # stop if fcntl not available (or windows)
    return
        if !defined( $flags_cmd_get ) or
           !defined( $flags_cmd_set ) or
           !defined( $flag_cloexec );

    my $flags_curr = fcntl( $fh, $flags_cmd_get, 0 );
    return
        if !defined( $flags_curr );

    return fcntl(
        $fh,
        $flags_cmd_set,
        $flags_curr | $flag_cloexec,
    ) ? 1 : undef;
}

# #
#   Secrets › Secret › Prepare Name
#   
#   Normalize setting name, remove spaces, reject missing / refs /
#   oversized, convert to uppercase.
#   
#   This sub does NOT pass the secret's value, name only.
#   
#   Eg:         " --api-key "           => API_KEY
#               "-password"             => PASSWORD
#               "database-password"     => DATABASE_PASSWORD
#               "api.key"               => undef
#               "api key"               => undef
#   
#   @test       Note:           Prepare cmd option with secret.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_secret_prepare_name(q{ --api-key }), qq{\n};"
#               Result:         API_KEY
#   
#   @params     name            str         Setting name to prepare as secret
#   @return     secret_name     str         Secret name
#                                               str         Uppercase secret name
#                                               undef       Name not valid
# #

sub _secret_prepare_name
{
    my ( $name ) = @_;

    return
        if !defined( $name ) or ref( $name );

    $name               = "$name";
    my $name_bytes      = _octet_length( $name );
    my $name_too_long   = $name_bytes > SETTING_NAME_BYTE_MAXIMUM;

    ConfigServer::DebugLocal::log( 0, 'warn',
        "name:[$name] len:[$name_bytes] " .
        "max:[" . SETTING_NAME_BYTE_MAXIMUM . "] " .
        "status:[rejected; name exceeds byte limit]"
    ) if $name_too_long;

    return
        if $name_too_long;

    # #
    #   @note       Only 1 or 2 leading hyphens are removed.
    #               Additional hyphens are converted to underscores:
    #                   ---DEV-SETTING => _DEV_SETTING
    # #

    # remove leading / trailing spaces
    ( $name ) = $name =~ /\A\s*(.*?)\s*\z/s;

    # count leading hyphens: '--' = 2, '-' = 1, none = 0
    my $opt_prefix_len = index( $name, "--" ) == 0
                            ? 2
                            : index( $name, "-"  ) == 0
                                ? 1
                                : 0;

    substr( $name, 0, $opt_prefix_len, "" )
        if $opt_prefix_len;

    $name               =~ tr/-/_/; # remaining - to _
    my $name_invalid    = $name eq "" || $name !~ /\A[A-Za-z0-9_]+\z/;

    ConfigServer::DebugLocal::log( 1, 'warn',
        "name:[$name] status:[rejected; name empty or has invalid chars]"
    ) if $name_invalid;

    return
        if $name_invalid;

    $name = uc( $name );

    ConfigServer::DebugLocal::log( 1, 'ok',
        "name:[$name] len:[" . _octet_length( $name ) . "] " .
        "max:[" . SETTING_NAME_BYTE_MAXIMUM . "] status:[ok]"
    );

    return $name;
}

# #
#   Secrets › Redact › Start
#   
#   Main redaction sub. Runs sub _redact_text().
#   
#   @test       Note:           Sanitize url, assignment, and http header
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_start(q{URL=https://operator:password@configserver.dev/check?token=url-secret&mode=test password=hidden [Authorization: Bearer header-secret]}), qq{\n};"
#               Result:         URL=https://[REDACTED]@configserver.dev/check password=[REDACTED] [Authorization: [REDACTED]]
#   
#               Note:           Sanitize normal log message without urls
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'print ConfigServer::Secrets::_redact_start(q{Login failed: account=admin password=hidden source=123.44.56.78}), qq{\n};'
#               Result:         Login failed: account=admin password=[REDACTED] source=123.44.56.78
#   
#   @params     text            str         Text to sanitize
#   @return     text            str         Redacted text
# #

sub _redact_start
{
    my ( $text ) = @_;

    # #
    #   Redact registered values before changing tabs or line breaks:
    #       Registered: registered\tsecret
    #       Input:      Value: registered\tsecret
    #       Result:     Value: [REDACTED]
    # #

    $text = _redact_registered_values( $text );

    # #
    #   Remove any terminal codes; change any tabs or line breaks to
    #   spaces:
    #       Input:      pass\e[31mword=secret
    #       Result:     password=secret
    # #

    $text = _log_flatten_ctrls( $text, 1 );

    # #
    #   Redact url login details and remove query strings or #frags:
    #       Input:      https://user:pass@configserver.dev/?token=secret
    #       Result:     https://[REDACTED]@configserver.dev/
    # #

    $text = _redact_urls( $text );

    # #
    #   Run remaining redaction checks
    # #

    $text = _redact_text( $text );

    # #
    #   Replace remaining linebreaks with spaces before rechecking
    #   values that may continue on the next line.
    # #

    $text = _log_flatten_ctrls( $text );

    # #
    #   Recheck values and command options after linebreaks replaced
    #   with spaces.
    # #

    $text = _redact_assigned_values( $text );
    $text = _redact_cmdoptions( $text );

    ConfigServer::DebugLocal::log( 1, 'ok',
        "text:[$text] status:[run]"
    );

    return $text;
}

# #
#   Secrets › Redact › Text
#   
#   Run remaining redactions for private keys, headers, command
#   options, xml.
#   
#   @test       Note:           Test all other secret redaction rules
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "ConfigServer::Secrets::register_secret(q{API_KEY}, q{remembered-123}); print ConfigServer::Secrets::_redact_text(q{remembered-123 password=hidden}), qq{\n};"
#               Result:         [REDACTED] password=[REDACTED]
#
#               Note:           Redact private key block
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_text(qq{Result: -----BEGIN RSA PRIVATE KEY-----\nfake-private-data}), qq{\n};"
#               Result:         Result: [REDACTED PRIVATE KEY MATERIAL]
#   
#   @params     text            str         Text to redact
#   @return     text            str         Redacted text
# #

sub _redact_text
{
    my ( $text ) = @_;

    # #
    #   Registered during config loading:
    #   
    #   @test       Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "ConfigServer::Secrets::register_secrets({ UI_PASS => q{RandomCSFAdminPassword123} }); print ConfigServer::Secrets::_redact_registered_values(q{Login failed using RandomCSFAdminPassword123}), qq{\n};"
    #               Input:          Login failed using RandomCSFAdminPassword123
    #               Result:         Login failed using [REDACTED]
    #   
    #   @note       Only protects secrets registered using:
    #                   register_secrets( { UI_PASS => "RandomCSFAdminPassword123" } );
    #   
    #   @note       Protects values in the csf.conf if they end up in a log:
    #                   UI_PASS = "RandomCSFAdminPassword123"
    # #

    $text = _redact_registered_values( $text );

    # #
    #   Redact private key blocks:
    #       Input:      -----BEGIN RSA PRIVATE KEY----- [...]
    #       Result:     [REDACTED PRIVATE KEY MATERIAL]
    # #

    $text = _redact_private_keys( $text );

    # #
    #   Redact secret http header values:
    #       Input:      [Authorization: Bearer secret-token]
    #       Result:     [Authorization: [REDACTED]]
    # #

    $text = _redact_headers( $text );

    # #
    #   Redact secret values assigned with = : or =>
    #       Input:      UI_PASS = "password"
    #       Result:     UI_PASS = "[REDACTED]"
    # #

    $text = _redact_assigned_values( $text );

    # #
    #   Redact registered bracketed log fields:
    #       Input:      uid:[0] gid:[0] mode:[0755]
    #       Result:     uid:[REDACTED] gid:[REDACTED] mode:[0755]
    # #

    $text = _redact_registered_names( $text );

    # #
    #   Redact secret values in colon separated records:
    #       Input:      DOMAIN:any:USER:myusername:CFACCOUNT:user@email.com:CFAPIKEY:12345abcdef6789
    #       Result:     DOMAIN:any:USER:myusername:CFACCOUNT:user@email.com:CFAPIKEY:[REDACTED]
    # #

    $text = _redact_colon_fields( $text );

    # #
    #   Redact secrets passed through cli options:
    #       Input:      csf --version --api-key "key-secret-xxxx"
    #       Result:     csf --version --api-key "[REDACTED]"
    # #

    $text = _redact_cmdoptions( $text );

    # #
    #   Redact secret values inside xml tags:
    #       Input:      <password>csf-secret</password>
    #       Result:     <password>[REDACTED]</password>
    # #

    $text = _redact_xml( $text );

    # #
    #   Redact aws keys and jwt tokens:
    #       Input:      AKIAABCDEFGHIJKLMNOP
    #       Result:     [REDACTED]
    # #

    $text = _redact_tokens_common( $text );

    # #
    #   Redact uuid v4 and v5 tokens:
    #       Input:      token=550e8400-e29b-41d4-a716-446655440000
    #       Result:     token=[REDACTED]
    # #

    $text = _redact_tokens_uuid( $text );

    # #
    #   Re-run redaction again after the other checks. Ensures we get
    #   any registered secret values still remaining:
    #       Input:      Remaining value: csf-secret-x123
    #       Result:     Remaining value: [REDACTED]
    # #

    $text = _redact_registered_values( $text );

    ConfigServer::DebugLocal::log( 1, 'ok',
        "content:[$text] status:[run]"
    );

    return $text;
}

# #
#   Secrets › Redact › Escaped Regex Values
#   
#   Redact escaped secret values from regex string.
#   
#   Eg:         csf-secret.x123 => csf\-secret\.x123 => [REDACTED]
#   
#   @test       Note:           Redact registered value from escaped regex text
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'ConfigServer::Secrets::register_secret(q{API_KEY}, q{csf-secret.x123}); my $escaped = quotemeta(q{csf-secret.x123}); print ConfigServer::Secrets::_redact_regex_text(qq{(?^:(?:$escaped))}), qq{\n};'
#               Result:         (?^:(?:[REDACTED]))
#   
#   @params     text            str         Text with escaped secrets
#   @return     text            str         Redacted text
# #

sub _redact_regex_text
{
    my ( $text ) = @_;

    #   return $text
    #       if ConfigServer::DebugLocal::DEBUG( ) == 5;

    my @values  = utf8::is_utf8( $text )
                    ? @registry_secrets_decoded
                        : keys( %registry_secrets );

    for my $secret (
        sort
        {
            length( $b ) <=> length( $a ) || $a cmp $b
        }
        @values
    )
    {
        my $secret_esc = quotemeta( $secret );
        $text =~ s/\Q$secret_esc\E/LABEL_SECRET_REDACT/eg;
    }

    return $text;
}

# #
#   Secrets › Redact › Registered Secret Values
#   
#   Check / redact registered secret values; field name not required.
#   Value must be registered first via one of the subs:
#       register_secret() or register_secrets()
#      
#   Before:     Value: csf-secret-x123
#   After:      Value: [REDACTED]
#   
#   @note       Called by _redact_text()
#   
#   @test       Note:           Register api key, confirm same value is redacted if it appears.
#               Command:        sudo env DEBUG=5 perl -I. -MConfigServer::Secrets -e "ConfigServer::Secrets::register_secret(q{API_KEY}, q{csf-secret-x123}); print ConfigServer::Secrets::_redact_registered_values(q{Value: csf-secret-x123}), qq{\n};"
#               Result:         Value: [REDACTED]
#   
#   @params     text            str         Text to check
#   @return     text            str         Redacted text
# #

sub _redact_registered_values
{
    my ( $text ) = @_;

    _build_regex_secret_values( )
        if keys( %registry_secrets ) and !defined( $registry_secrets_match_bytes );

    # #
    #   Debugging only, these can be expensive to run.
    #   Secrets still redacted for security.
    # #

    if ( ConfigServer::DebugLocal::DEBUG( ) == 5 )
    {
        my $registry_match_bytes = defined( $registry_secrets_match_bytes )
            ? "$registry_secrets_match_bytes"
            : 'undef';

        my $registry_match_decoded = defined( $registry_secrets_match_decoded )
            ? "$registry_secrets_match_decoded"
            : 'undef';

        $registry_match_bytes   = _redact_regex_text( $registry_match_bytes );
        $registry_match_decoded = _redact_regex_text( $registry_match_decoded );

        my $registry_values_redacted = join(
            ", ",
            ( LABEL_SECRET_REDACT ) x scalar( keys( %registry_secrets ) ),
        );

        ConfigServer::DebugLocal::log( 5, 'info',
            "storage:[bytes] " .
            "raw:[$registry_values_redacted] " .
            "utf8:[" . ( utf8::is_utf8( $registry_match_bytes ) ? 1 : 0 ) . "] " .
            "filter:[$registry_match_bytes]"
        );

        ConfigServer::DebugLocal::log( 5, 'info',
            "storage:[decoded] " .
            "raw:[$registry_values_redacted] " .
            "utf8:[" . ( utf8::is_utf8( $registry_match_decoded ) ? 1 : 0 ) . "] " .
            "filter:[$registry_match_decoded]"
        );
    }

    my $registry_match = utf8::is_utf8( $text )
        ? $registry_secrets_match_decoded
        : $registry_secrets_match_bytes;

    if ( !defined( $registry_match ) )
    {
        ConfigServer::DebugLocal::log( 1, 'info',
            "count:[0] " .
            "status:[registered secret filter unavailable]"
        );

        return $text;
    }

    #   return $text
    #       if ConfigServer::DebugLocal::DEBUG( ) == 5;

    my $i = ( $text =~ s/$registry_match/LABEL_SECRET_REDACT/eg );

    $i ||= 0;
    ConfigServer::DebugLocal::log( 1, $i ? 'ok' : 'info',
        "count:[$i] " .
        "status:[redact registered secret values]"
    );

    return $text;
}

# #
#   Secrets › Redact › Registered Field Names
#   
#   Redact secrets by field name. Names come from:
#       %REGISTRY_SECRETS_FIELDS
#   
#   Square [brackets] around field not required.
#   
#   @test       Note:           Redact registered uid and gid fields
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'print ConfigServer::Secrets::_redact_registered_names(q{dir:[/var] uid:0 gid:0 mode:[0755]}), qq{\n};'
#               Input:          dir:[/var] uid:0 gid:0 mode:[0755]
#               Result:         dir:[REDACTED] uid:[REDACTED] gid:[REDACTED] mode:[0755]
#   
#   @params     text            str         Text with fields
#   @return     text            str         Redacted fields
# #

sub _redact_registered_names
{
    my ( $text ) = @_;

    #   return $text
    #       if ConfigServer::DebugLocal::DEBUG( ) == 5;

    my $i = 0;

    $text =~ s{
        (?<![A-Za-z0-9_])
        ($REGISTRY_SECRETS_FIELDS_MATCH)
        ([ \t]*(?:=>|=|:)[ \t]*)
        (?:\[[^\]\r\n]*\]|[^\s,\]\}\)]+)
    }{
        $i++;
        $1 . $2 . LABEL_SECRET_REDACT
    }egix;

    ConfigServer::DebugLocal::log( 1, $i ? 'ok' : 'info',
        "count:[$i] status:[redact registered fields]"
    );

    return $text;
}

# #
#   Secrets › Redact › Assigned Values
#   
#   Redact secret values by field name; supports name/value seperators:
#       =, :, or =>
#   
#   Value doesn't need to be registered.
#   
#   @note       Called by _redact_text()
#   
#   Eg:         password=my-csf-secret
#               api_key: my-csf-secret
#               "token" => "my-csf-secret"
#               'database_password'='my-csf-secret'
#   
#   @test       Note:           Redact secret, leave public text unchanged.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_assigned_values(q{password=my-csf-secret; mode=public}), qq{\n};"
#               Result:         password=[REDACTED]; mode=public
#   
#   @params     text            str         Text with possible values
#   @return     text            str         Redacted text
# #

sub _redact_assigned_values
{
    my ( $text ) = @_;

    return $text
        if index( $text, '=' ) < 0 and index( $text, ':' ) < 0;

    my @replacements;
    my $text_len        = length( $text );
    my $cursor          = 0;

    while ( $cursor < $text_len )
    {
        my $before = $cursor > 0 ? substr( $text, $cursor - 1, 1 ) : '';
        if ( $before =~ /[A-Za-z0-9_-]/ )
        {
            $cursor++;
            next;
        }

        my $name_quote  = substr( $text, $cursor, 1 );
        my $name_start  = $cursor;
        if ( $name_quote eq '"' or $name_quote eq "'" )
        {
            $name_start++;
        }
        else
        {
            $name_quote = '';
        }

        if ( substr( $text, $name_start, 1 ) !~ /[A-Za-z]/ )
        {
            $cursor++;
            next;
        }

        my $name_end    = $name_start + 1;
        $name_end++
            while $name_end < $text_len and
                  substr( $text, $name_end, 1 ) =~ /[A-Za-z0-9_-]/;

        my $name        = substr( $text, $name_start, $name_end - $name_start );
        my $pos         = $name_end;
        if ( $name_quote ne '' )
        {
            if ( substr( $text, $pos, 1 ) ne $name_quote )
            {
                $cursor++;
                next;
            }

            $pos++;
        }

        $pos++
            while $pos < $text_len and substr( $text, $pos, 1 ) =~ /[ \t]/;

        my $separator_size  = substr( $text, $pos, 2 ) eq '=>' ? 2
                                : substr( $text, $pos, 1 ) =~ /[=:]/ ? 1
                                : 0;

        if ( !$separator_size )
        {
            $cursor = $name_end;
            next;
        }

        $pos += $separator_size;
        $pos++
            while $pos < $text_len and substr( $text, $pos, 1 ) =~ /[ \t]/;

        # _value_get_len( "password=my-csf-secret", "9", qr/[\s,;&\}\]]/ );
        my $value_size = _value_get_len( $text, $pos, qr/[\s,;&\}\]]/ );
        if ( defined( $value_size ) and is_config_secret( $name ) )
        {
            my $replacement = _build_redact_marker_quoted(
                substr( $text, $pos, $value_size )
            );

            push @replacements, [ $pos, $value_size, $replacement ];
        }

        $cursor = defined( $value_size ) ? $pos + $value_size : $name_end;
    }

    return _redact_apply( $text, \@replacements );
}

# #
#   Secrets › Redact › Apply
#   
#   Apply replacements from end of text to start.
#   
#   @test       Note:           Apply two replacements (from right to left)
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_apply(q{one secret two private}, [[4, 6, q{[REDACTED]}], [15, 7, q{[REDACTED]}]]), qq{\n};"
#               Result:         one [REDACTED] two [REDACTED]
#   
#   @params     text            str         Text to do replacements
#               replacements    arrayref    [ pos, len, replacement ]
#   @return     text            str         Text with replacements for redaction
# #

sub _redact_apply
{
    # #
    #   $text               one secret two private
    #   $replacements:      [ [ 4, 6, '[REDACTED]' ], [ 15, 7, '[REDACTED]' ] ];
    # #

    my ( $text, $replacements ) = @_;

    my $replacements_i = scalar( @{$replacements} );
    for my $replacement ( reverse @{$replacements} )
    {
        substr(
            $text,
            $replacement->[ 0 ],
            $replacement->[ 1 ],
            $replacement->[ 2 ],
        );
    }

    ConfigServer::DebugLocal::log( 1, 'ok',
        "count:[$replacements_i] " .
        "status:[apply replacements]"
    );

    return $text;
}

# #
#   Secrets › Redact › Private Keys
#   
#   Replace everything from a private key's BEGIN marker to the end
#   of the text, redacted with:
#       [REDACTED PRIVATE KEY MATERIAL]
#   
#   This sub also covers keys with no END marker.
#   
#   @note       Called by _redact_text()
#   
#   @test       Note:           Redact rsa private key
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_private_keys(qq{TLS key:\n-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAu8vK7nQ3fH2x9mY5pL4sT8wZ\nk6D1cR9bV3nM7qW2fJ5hP8sX4tG0aL6eN1yC9uB7\n-----END RSA PRIVATE KEY-----}), qq{\n};"
#               Result:         TLS key:
#                               [REDACTED PRIVATE KEY MATERIAL]
#   
#               Note:           Return regular text unchanged; no private key
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_private_keys(q{Regular message}), qq{\n};"
#               Result:         Regular message
#   
#   @params     text            str         Text for private key header
#   @return     text            str         Redacted private key header
# #

sub _redact_private_keys
{
    my ( $text ) = @_;

    my $found_i = (
        $text =~ s{
            -----BEGIN[ ]
            (?:[A-Z0-9]+[ ])*
            (?:$PRIVATE_KEYS_MATCH)
            -----
            .*\z
        }{LABEL_PRIVKEY_REDACT}egisxo
    );

    # 0 = no header found
    $found_i = 0
        if !$found_i;

    ConfigServer::DebugLocal::log( 1, 'ok',
        "count:[$found_i] status:[redact private key]"
    );

    return $text;
}

# #
#   Secrets › Redact › Http Headers
#   
#   Redact http header values.
#   
#   @note       Supports ':' or '=' chars between header name / value:
#                   [Authorization: csf-secret]
#                   [Authorization=csf-secret]
#   
#   @note       Called by _redact_text()
#   
#   @test       Note:           Redact 'Authorization' header's value;
#                               keep 'Status:' field unchanged.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_headers(q{[Authorization: csf-secret] [Status: 200]}), qq{\n};"
#               Result:         [Authorization: [REDACTED]] [Status: 200]
#   
#   @params     text            str         Text with http headers
#   @return     text            str         Headers with redacted secrets
# #

sub _redact_headers
{
    # #
    #   $text:          [Authorization: csf-secret] [Status: 200]
    #   $text_len:      43
    #   $cursor:        0
    # #

    my ( $text ) = @_;

    return $text
        if index( $text, ':' ) < 0 and index( $text, '=' ) < 0;

    my $redacted_header_i   = 0;
    my $text_len            = length( $text );
    my $result              = '';
    my $cursor              = 0;

    # loop each char in $text; going to search for opening brackets
    while ( $cursor < $text_len )
    {
        # found opening bracket '['
        if ( substr( $text, $cursor, 1 ) eq '[' )
        {
            # confirm bracket starts reg'ed secret before searching remaining text for closing bracket
            my $start       = _header_value_start( $text, $cursor + 1, $text_len );
            my $field_end   = defined( $start )
                                ? _bracket_field_end( $text, $cursor + 1 )
                                : undef;

            # secret in header found
            if ( defined( $field_end ) )
            {
                if ( defined( $start ) )
                {
                    $result .= substr( $text, $cursor, $start - $cursor );
                    $result .= LABEL_SECRET_REDACT . ']';

                    $redacted_header_i++;

                    $cursor = $field_end + 1;
                    next;
                }
            }
        }

        # #
        #   Detect header secrets not within brackets
        #       Input:      Authorization: Bearer secret-token
        #       Result:     Authorization: [REDACTED]
        # #

        my $before = $cursor > 0 ? substr( $text, $cursor - 1, 1 ) : '';
        if ( $before !~ /[A-Za-z0-9_-]/ )
        {
            my $start = _header_value_start( $text, $cursor, $text_len );
            if ( defined( $start ) )
            {
                my $line_end = $start;

                $line_end++
                    while $line_end < $text_len and
                          substr( $text, $line_end, 1 ) !~ /[\r\n]/;

                while (
                    my ( $continuation ) = substr( $text, $line_end ) =~
                        /\A((?:\r\n|[\r\n])[ \t][^\r\n]*)/
                )
                {
                    $line_end += length( $continuation );
                }

                # keep header name, replace value
                $result .= substr( $text, $cursor, $start - $cursor );
                $result .= LABEL_SECRET_REDACT;
                $redacted_header_i++;

                $cursor = $line_end;

                next;
            }
        }

        $result .= substr( $text, $cursor, 1 );
        $cursor++;
    }

    ConfigServer::DebugLocal::log( 1, 'ok',
        "count:[$redacted_header_i] status:[redact headers]"
    );

    return $result;
}

# #
#   Secrets › Redact › Colon Separated
#   
#   Replace secret values in records; separated by colons. Used for
#   things like Cloudflare settings.
#   
#   @note       Called by _redact_text()
#   
#   @test       Note:           Redact a Cloudflare API key field.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_colon_fields(q{DOMAIN:any:CFAPIKEY:csf-secret}), qq{\n};"
#               Result:         DOMAIN:any:CFAPIKEY:[REDACTED]
#
#   @params     text            str         Text to check
#   @return     text            str         Text with secret values replaced
# #

sub _redact_colon_fields
{
    my ( $text ) = @_;
    my @secrets;
    my $redact_i = 0;

    # find all field names between colons
    while ( $text =~ /(?:\A|:)[ \t]*([A-Za-z][A-Za-z0-9_-]*)[ \t]*:[ \t]*/g )
    {
        my $field_name = $1;
        next
            if !is_config_secret( $field_name );

        my $start = pos( $text );
        next
            if substr( $text, $start, length( LABEL_SECRET_REDACT ) ) eq LABEL_SECRET_REDACT;

        my ( $field_value ) = substr( $text, $start ) =~ /\A([^:\s,\]\);&}]+)/;
        next
            if !defined( $field_value ) or $field_value eq '';

        push @secrets,
            [ $start, length( $field_value ) ];
    }

    # #
    #   Replace last secret first. Keep the saved pos of earlier
    #   secrets correct
    # #

    for my $loc ( reverse @secrets )
    {
        substr(
            $text,
            $loc->[ 0 ],
            $loc->[ 1 ],
            LABEL_SECRET_REDACT,
        );

        $redact_i++;
    }

    ConfigServer::DebugLocal::log( 1, 'ok',
        "count:[$redact_i] " .
        "status:[redact colon delimited values]"
    );

    return $text;
}

# #
#   Secrets › Redact › Command Options
#   
#   Redacts any secrets a user may have passed in command. Supports:
#       --api-key=csf-secret
#       --api-key csf-secret
#       --password "csf-secret"
#   
#   The option name is checked with is_config_secret(). Public options
#   such as --mode not changed.
#   
#   Input:      csf --version --mode --api-key key-secret-xxxx
#   Result:     csf --version --mode --api-key [REDACTED]
#   
#   @note       Called by _redact_text()
#   
#   @test       Note:           Redact secrets passed in command as option
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_cmdoptions(q{csf --version --api-key key-secret-xxxx}), qq{\n};"
#               Result:         csf --version --api-key [REDACTED]
#   
#   @params     text            str         Text with passed command options
#   @return     text            str         Text with passed command (secret values redacted)
# #

sub _redact_cmdoptions
{
    my ( $text ) = @_;

    # return $text unchanged; doesn't have '--'
    return $text
        if index( $text, '--' ) < 0;

    my @replacements;
    my $text_len        = length( $text );
    my $cursor          = 0;

    while ( ( $cursor = index( $text, '--', $cursor ) ) >= 0 )
    {
        my $name_start = $cursor + 2;
        if ( substr( $text, $name_start, 1 ) !~ /[A-Za-z]/ )
        {
            $cursor = $name_start;
            next;
        }

        my $pos = $name_start + 1;
        $pos++
            while $pos < $text_len and
                  substr( $text, $pos, 1 ) =~ /[A-Za-z0-9_-]/;

        my $name = substr( $text, $name_start, $pos - $name_start );
        if ( substr( $text, $pos, 1 ) eq '=' )
        {
            $pos++;
        }

        # #
        #   Ensure that if a command option has no value, and another
        #   option follows; we properly verify that option does not
        #   have a secret and consume.
        #   
        #   Eg:     csf --version --api-key key-secret-xxxx
        #           csf --version --api-key [REDACTED]
        # #

        elsif ( substr( $text, $pos, 1 ) =~ /[ \t]/ )
        {
            $pos++
                while $pos < $text_len and
                      substr( $text, $pos, 1 ) =~ /[ \t]/;

            # current option has no value when another option follows
            if ( substr( $text, $pos, 2 ) eq '--' )
            {
                $cursor = $pos;
                next;
            }
        }
        else
        {
            $cursor = $pos;
            next;
        }

        my $value_size = _value_get_len( $text, $pos, qr/\s/ );
        if ( defined( $value_size ) and is_config_secret( $name ) )
        {
            my $replacement = _build_redact_marker_quoted(
                substr( $text, $pos, $value_size )
            );

            push @replacements, [ $pos, $value_size, $replacement ];
        }

        $cursor = defined( $value_size ) ? $pos + $value_size : $pos;
    }

    return _redact_apply( $text, \@replacements );
}

# #
#   Secrets › Redact › Xml Values
#   
#   Find xml tags with secret names and replace their values.
#   Complete tags keep their opening and closing tags.
#   
#   If a secret tag has no closing tag, redact everything after it:
#       Input:      Login failed: <password>my-secret Status: 401
#       Result:     Login failed: <password>[REDACTED]
#   
#   @note       Called by _redact_text()
#   
#   @test       Note:           Redact a password inside xml tag
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_xml(q{<password>secret-csf-value</password>}), qq{\n};"
#               Result:         <password>[REDACTED]</password>
#   
#   @params     text            str         Text with xml
#   @return     text            str         Xml with redacted secrets
# #

sub _redact_xml
{
    my ( $text ) = @_;

    return $text
        if index( $text, '<' ) < 0;

    my @replacements;
    my $text_len        = length( $text );
    my $text_lower      = lc( $text );
    my $cursor          = 0;

    while ( ( $cursor = index( $text, '<', $cursor ) ) >= 0 )
    {
        my $name_start = $cursor + 1;
        if ( substr( $text, $name_start, 1 ) !~ /[A-Za-z]/ )
        {
            $cursor = $name_start;
            next;
        }

        my $name_end        = $name_start + 1;
        $name_end++
            while $name_end < $text_len and
                  substr( $text, $name_end, 1 ) =~ /[A-Za-z0-9_:-]/;

        my $tag_name        = substr( $text, $name_start, $name_end - $name_start );
        my ( $name )        = $tag_name =~ /([^:]+)\z/;

        # #
        #   Find end of the opening tag without treating a '>'
        #   inside a quoted attribute as the end of the tag.
        # #

        my $opening_end     = $name_end;
        my $opening_quote   = '';

        while ( $opening_end < $text_len )
        {
            my $opening_char = substr( $text, $opening_end, 1 );

            if ( $opening_quote ne '' )
            {
                $opening_quote = ''
                    if $opening_char eq $opening_quote;

                $opening_end++;
                next;
            }

            if ( $opening_char eq '"' or $opening_char eq "'" )
            {
                $opening_quote = $opening_char;
                $opening_end++;
                next;
            }

            last
                if $opening_char eq '>';

            $opening_end++;
        }

        if ( $opening_end >= $text_len )
        {
            push @replacements,
            [
                $cursor,
                $text_len - $cursor,
                LABEL_SECRET_REDACT,
            ] if is_config_secret( $name );

            last;
        }

        my $opening_tag = substr(
            $text,
            $cursor,
            $opening_end - $cursor + 1,
        );

        my $is_self_closing     = $opening_tag =~ m{/[ \t\r\n]*>\z};
        my $masked_attribute_i  = 0;

        # #
        #   Redact quoted xml attrib value only when name is secret.
        # #

        $opening_tag =~ s{
            (
                ([A-Za-z_:][A-Za-z0-9_.:-]*)
                [ \t\r\n]*=[ \t\r\n]*
            )
            (["'])
            (.*?)
            \3
        }{
            my $attrib_start    = $1;
            my $attrib_name     = $2;
            my $attrib_quote    = $3;
            my $attrib_value    = $4;
            my $colon_pos       = rindex( $attrib_name, ':' );

            $attrib_name = substr( $attrib_name, $colon_pos + 1 )
                if $colon_pos >= 0;

            my $attrib_secret = is_config_secret( $attrib_name );
            $masked_attribute_i++
                if $attrib_secret;

            $attrib_start . $attrib_quote .
                ( $attrib_secret ? LABEL_SECRET_REDACT : $attrib_value ) .
                $attrib_quote
        }egxs;

        push @replacements,
        [
            $cursor,
            $opening_end - $cursor + 1,
            $opening_tag,
        ] if $masked_attribute_i;

        if ( $is_self_closing )
        {
            $cursor = $opening_end + 1;
            next;
        }

        if ( is_config_secret( $name ) )
        {

            # #
            #   Find closing tag if tag name is secret
            # #

            my $closing_tag     = '</' . lc( $tag_name ) . '>';
            my $closing_start   = index( $text_lower, $closing_tag, $opening_end + 1 );
            my $next_tag        = index( $text, '<', $opening_end + 1 );

            # #
            #   If tag complete, mask only the text between tags:
            #       Input:      <password>my-secret</password> Status: 401
            #       Result:     <password>[REDACTED]</password> Status: 401
            #   
            #   If closing tag missing, mask everything after <password>:
            #       Input:      <password>my-secret Status: 401
            #       Result:     <password>[REDACTED]
            # #

            my $value_end   = $closing_start >= 0 && $next_tag == $closing_start
                                ? $closing_start
                                    : $text_len;

            push @replacements,
            [
                $opening_end + 1,
                $value_end - $opening_end - 1,
                LABEL_SECRET_REDACT,
            ];

            last
                if $value_end == $text_len;
        }

        $cursor = $opening_end + 1;
    }

    return _redact_apply( $text, \@replacements );
}

# #
#   Secrets › Redact › Tokens › Common
#   
#   Redact common token formats like AWS / JWT:
#   
#   @note       Called by _redact_text()
#   
#   @test       Note:           Redact one AWS key and one JWT
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_tokens_common(q{AKIAABCDEFGHIJKLMNOP eyJabcdefgh.abcdefgh.abcdefgh}), qq{\n};"
#               Result:         [REDACTED] [REDACTED]
#   
#   @params     text            str         Text with common secret tokens
#   @return     text            str         Text with redacted tokens
# #

sub _redact_tokens_common
{
    # #
    #   Run         _redact_tokens_common( 'AKIAABCDEFGHIJKLMNOP eyJabcdefgh.abcdefgh.abcdefgh' );
    #   $text       AKIAABCDEFGHIJKLMNOP eyJabcdefgh.abcdefgh.abcdefgh
    # #

    my ( $text ) = @_;

    # $text       [REDACTED] eyJabcdefgh.abcdefgh.abcdefgh
    $text =~ s/$AWS_TOKEN_MATCH/LABEL_SECRET_REDACT/eg;

    # $text       [REDACTED] [REDACTED]
    $text =~ s/$JWT_TOKEN_MATCH/LABEL_SECRET_REDACT/eg;

    return $text;
}

# #
#   Secrets › Redact › Tokens › UUID
#
#   Redact uuid 4 and 5 tokens.
#
#   @note       Some notes about UUID4 and UUID5 below for future ref:
#                   Version     1st char of 3rd group
#                   Variant     1st char of 4th group
#   
#               UUID:           550e8400-e29b-41d4-a716-446655440000
#                   Group 1:    550e8400
#                   Group 2:    e29b
#                   Group 3:    41d4            Version = 4
#                   Group 4:    a716            Variant = a
#                   Group 5:    446655440000
#   
#               Supported variants:
#                   8 = 1000
#                   9 = 1001
#                   a = 1010
#                   b = 1011
#   
#               UUID Versions:
#                   v4 = Random; 122 bits
#                   v5 = Deterministic; generated from a namespace
#                           UUID and name using SHA-1
#
#   @note       Called by _redact_text()
#
#   @test       Note:           Redact uuid v4 and v5 tokens.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_tokens_uuid(q{v4=550e8400-e29b-41d4-a716-446655440000 v5=cfbff0d1-9375-5685-968c-48ce8b15ae17}), qq{\n};"
#               Result:         v4=[REDACTED] v5=[REDACTED]
#
#   @params     text            str         Text with uuid tokens
#   @return     text            str         Text with tokens redacted
# #

sub _redact_tokens_uuid
{
    my ( $text ) = @_;

    my $replacements_i = (
        $text =~ s/$UUID_TOKEN_MATCH/LABEL_SECRET_REDACT/eg
    );

    $replacements_i ||= 0;

    ConfigServer::DebugLocal::log(
        1,
        $replacements_i ? 'ok' : 'info',
        "count:[$replacements_i] " .
        "status:[redact uuid tokens]"
    );

    return $text;
}

# #
#   Secrets › Redact › Urls
#   
#   Find / redact multiple urls in a string.
#   
#   Url login details are redacted.
#   Query strings and fragments are removed.
#   Text around the url stays visible.
#   
#   Input:      Request failed: https://user:password@configserver.dev/check?token=url-secret#details
#   Result:     Request failed: https://[REDACTED]@configserver.dev/check
#   
#   @test       Note:           Sanitize one url inside surrounding text.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_urls(q{Request: https://user:password@configserver.dev/check?token=url-secret#fragment}), qq{\n};"
#               Result:         Request: https://[REDACTED]@configserver.dev/check
#   
#   @params     text            str         Text with urls
#   @return     text            str         Text with urls sanitized
# #

sub _redact_urls
{
    my ( $text ) = @_;

    # #
    #   text        request https://user:password@configserver.dev/check?token=secret failed
    # #

    if ( index( $text, '//' ) < 0 )
    {
        ConfigServer::DebugLocal::log( 1, 'info', "count:[0] status:[no urls found]" );
        return $text;
    }

    my @found;
    my $text_len    = length( $text );
    my $cursor      = 0;

    while ( ( my $slashes = index( $text, '//', $cursor ) ) >= 0 )
    {
        my $start   = $slashes;
        my $end     = $slashes + 2;

        if ( $slashes > 0 and substr( $text, $slashes - 1, 1 ) eq ':' )
        {
            my $separator   = $slashes - 1;
            $start          = $separator;
            while ( $start > 0 and substr( $text, $start - 1, 1 ) =~ /[A-Za-z0-9+.-]/ )
            {
                $start--;
            }

            my $scheme_text = substr( $text, $start, $separator - $start );
            my ( $scheme )  = $scheme_text =~ /\A([A-Za-z][A-Za-z0-9+.-]*)\z/;

            if ( !defined( $scheme ) )
            {
                $cursor = $end;
                next;
            }
        }

        while ( $end < $text_len and substr( $text, $end, 1 ) !~ /[\s<>"'\]\)]/ )
        {
            $end++;
        }

        my $url = substr( $text, $start, $end - $start );

        push @found,
        [
            $start,
            $end - $start,
            redact_obj_url( $url ),
        ];

        $cursor = $end;
    }

    for my $found ( reverse @found )
    {
        substr(
            $text,
            $found->[ 0 ],
            $found->[ 1 ],
            $found->[ 2 ],
        );
    }

    my $urls_i = scalar( @found );

    ConfigServer::DebugLocal::log( 1, $urls_i ? 'ok' : 'info',
        "count:[$urls_i] status:[mask urls]"
    );

    # request https://[REDACTED]@configserver.dev/check failed
    return $text;
}

# #
#   Secrets › Redact › Url
#   
#   Internal url sanitizer used by:
#       - redact_obj_url()
#       - redact_obj_url_replace()
#   
#   Login credentials and #fragments are always removed or redacted.
#   
#   @note       This sub calls _chars_allow_max() which by default, 
#               limits all text to 262,144 chars, (defined as const
#               SCAN_CHARACTER_MAXIMUM). This is too large for urls.
#   
#               The max chars for urls is set to 8,192 chars, (defined
#               as const URL_CHARACTER_MAXIMUM).
#   
#   @test       Note:           Redact credentials, query secrets, and #fragment.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_url(q{https://user:password@configserver.dev/check?token=secret&mode=test#section}, 1), qq{\n};"
#               Result:         https://[REDACTED]@configserver.dev/check?token=[REDACTED]&mode=test
#   
#   @params     url_raw         str         Url to sanitize
#               keep_query      int         If the query string is kept
#                                               1           Keep query with secret values redacted
#                                               0           Remove query string
#   @return     url             str         Sanitized url or empty string
#                                               str         Sanitized url
#                                               ''          Input is empty or invalid
# #

sub _redact_url
{
    # #
    #   $url_raw:       https://user:password@configserver.dev/check?token=secret&mode=test#section
    #   $keep_query:    1
    #   $url:           https://user:password@configserver.dev/check?token=secret&mode=test
    #   $is_cut:        0
    #   $query:         token=secret&mode=test
    # #

    my ( $url_raw, $keep_query ) = @_;

    # #
    #   Check if $url_raw is plain text, shorten if > 262,144 chars
    #   
    #   @note       _chars_allow_max() caps char limit at 262,144
    #               chars (const SCAN_CHARACTER_MAXIMUM)
    #   
    #               However, for urls, max limit is 8.192 chars
    #               (const URL_CHARACTER_MAXIMUM)
    # #

    my ( $url, $is_cut ) = _chars_allow_max( $url_raw, '', URL_CHARACTER_MAXIMUM );
    return ''
        if $url eq '';

    # #
    #   _redact_registered_values() Tasks:
    #       If no registry filter exists, return text unchanged
    #       If registry filter exists, redact all matching secret values
    #       Return redacted text
    # #

    $url = _redact_registered_values( $url );

    # #
    #   Flatten terminal escapes, line breaks, and control chars
    #   from direct url calls; make safe to log.
    # #

    $url = _log_flatten_ctrls( $url );

    # #
    #   Remove url #fragments
    #
    #   Eg:     https://configserver.dev/docs?mode=test#installation
    #           https://configserver.dev/docs?mode=test
    # #

    my $frag_pos    = index( $url, '#' );
    $url            = substr( $url, 0, $frag_pos )
                        if $frag_pos >= 0;

    my @components = _url_components( $url );
    if ( !@components )
    {
        return LABEL_SECRET_REDACT . LABEL_TRUNCATE
            if $is_cut;

        # remove query when it shouldn't be kept
        if ( !$keep_query )
        {
            my $query_pos   = index( $url, '?' );
            $url            = substr( $url, 0, $query_pos )
                                if $query_pos >= 0;
        }

        my $sanitized = _redact_text( $url );

        return $sanitized . ( $is_cut ? LABEL_TRUNCATE : '' );
    }

    # #
    #   $scheme:            https
    #   $authority:         user:password@configserver.dev
    #   $path:              /check
    #   $query:             token=secret&mode=test
    # #

    my ( $scheme, $authority, $path, $query ) = @components;
    my $prefix = $scheme eq '' ? '//' : "$scheme://";

    return $prefix . LABEL_SECRET_REDACT . LABEL_TRUNCATE
        if $is_cut and $path eq '' and !defined( $query );

    my $userinfo_end    = rindex( $authority, '@' );
    $authority          = LABEL_SECRET_REDACT . '@' . substr( $authority, $userinfo_end + 1 )
                            if $userinfo_end >= 0;

    $authority  =~ s/[\0-\x1f\x7f]//g;
    $path       =~ s/[\0-\x1f\x7f]//g;
    $path       = _redact_url_path( $path );

    # #
    #   Rebuild sanitized url
    #   
    #   $res:           https://[REDACTED]@configserver.dev/check?token=[REDACTED]&mode=test
    #   $url_raw:       https://user:password@configserver.dev/check?token=secret&mode=test#section
    #   $url:           https://user:password@configserver.dev/check?token=secret&mode=test
    #   $query:         token=secret&mode=test
    # #

    my $res = "$prefix$authority$path";
    if ( $keep_query and defined( $query ) and $query ne '' )
    {
        $query  =~ s/[\0-\x1f\x7f]//g;
        $res    .= '?' . _redact_url_query( $query );
    }

    return $res . ( $is_cut ? LABEL_TRUNCATE : '' );
}

# #
#   Secrets › Redact › Url › Query
#
#   Redact secret query param values.
#
#   Input:      _redact_url_query( "token=secret&mode=test" );
#               _redact_url_query( "?token=secret&mode=test" );
#   Output:     token=[REDACTED]&mode=test
#   
#   @test       Note:           Redact secret query values, keep public values
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_url_query(q{token=secret&mode=test;api_key=secret-key}), qq{\n};"
#               Result:         token=[REDACTED]&mode=test;api_key=[REDACTED]
#
#   @params     query           str         Url query to sanitize
#   @return     query           str         Query with secret param values redacted
# #

sub _redact_url_query
{
    my ( $query ) = @_;

    $query          =~ s/\A\?//;                        # remove ?
    my @segs        = split( /([&;])/, $query, -1 );    # split & and ;
    my $redact_i    = 0;
    for ( my $pos = 0; $pos < @segs; $pos += 2 )
    {
        my ( $query_name, $query_value ) = split( /=/, $segs[ $pos ], 2 );

        if ( _query_name_is_secret( $query_name ) )
        {
            $segs[ $pos ] = $query_name . '=' . LABEL_SECRET_REDACT;
            $redact_i++;
            next;
        }

        next
            if !defined( $query_value );

        my $value_encoded   = $query_value;
        $value_encoded      =~ tr/+/ /;

        my ( $value_decoded, $is_nested_reached ) = _octet_percent_decode( $value_encoded );

        my $value_checked   = _redact_registered_values( $value_decoded );
        $value_checked      = _redact_tokens_common( $value_checked );
        $value_checked      = _redact_tokens_uuid( $value_checked );

        if ( $is_nested_reached or $value_checked ne $value_decoded )
        {
            $segs[ $pos ]   = $query_name . '=' . LABEL_SECRET_REDACT;
            $redact_i++;
        }
    }

    ConfigServer::DebugLocal::log( 1, $redact_i ? 'ok' : 'info',
        "count:[$redact_i] " .
        "status:[redact URL query values]"
    );

    # #
    #   @segs =  [
    #       'token=[REDACTED]',
    #       '&',
    #       'mode=test',
    #       ';',
    #       'api_key=[REDACTED]'
    #   ];
    # #

    # token=[REDACTED]&mode=test;api_key=[REDACTED]
    return join( '', @segs );
}

# #
#   Secrets › Redact › Url › Path
#   
#   Redact secret paths in url.
#   Also hide the segment after a listed route, such as "reset".
#   
#   @test       Note:           Redact the value after a secret route
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::_redact_url_path(q{/reset/account-code-123}), qq{\n};"
#               Result:         /reset/[REDACTED]
#   
#   @params     path            str         Url path
#   @return     path            str         Url with path redactions
# #

sub _redact_url_path
{
    my ( $path ) = @_;

    my @segments                = split( /\//, $path, -1 );
    my $redact_next_segment     = 0;
    my $is_path_ambiguous       = 0;
    my $loop                    = 0;
    for my $position ( 0 .. $#segments )
    {
        # #
        #   $path beginning with '/' creates empty first $segment.
        #   Skip the empty $segment
        #   
        #   Path:       /reset/csf-secret
        #   Segments:   ( "", "reset", "csf-secret" )
        # #

        my $segment = $segments[ $position ];
        next
            if $segment eq '';

        # #
        #   Decode url percent (%2F) into each actual char.
        #   
        #   Nested url percent decoding has limit of 8 levels deep,
        #   and then we determine the passed url is unsafe.
        # #
    
        my ( $route_name, $is_nested_reached ) = _octet_percent_decode( $segment );

        # #
        #   Make route matching case insensitive:
        #       _redact_url_path( "/reset/account-code-123" );
        #   
        #       Segment     $route_name
        #       1           reset
        #       2           account-code-123
        # #

        if (
            !$is_nested_reached and
            !utf8::is_utf8( $route_name ) and
            $route_name =~ /[\x80-\xFF]/
        )
        {
            my $route_utf8 = eval
            {
                Encode::decode( 'UTF-8', $route_name, Encode::FB_CROAK( ) )
            };

            if ( !defined( $route_utf8 ) or $@ )
            {
                $is_nested_reached = 1;
            }
            else
            {
                $route_name = $route_utf8;
            }
        }

        $route_name =~ s/\p{Cc}//g;
        $route_name =~ s/\p{Cf}//g
            if utf8::is_utf8( $route_name );

        $route_name = lc( $route_name );
        my ( $route_base, $route_params ) =
            split( /;/, $route_name, 2 );

        my $route_has_params = defined( $route_params );

        $is_path_ambiguous = 1
            if $route_name eq '.' or $route_name eq '..';

        # #
        #   Check if the route protects its next segment:
        #       auth, callback, credential, invite, reset, secret, etc.
        # #

        my $route_registered = !$is_nested_reached &&
            exists( $REGISTRY_SECRET_URL_ROUTES{$route_base} );

        my $is_secret_route = $route_registered &&
            $REGISTRY_SECRET_URL_ROUTES{$route_base};

        my $segment_is_secret = $redact_next_segment ||
                                $is_nested_reached ||
                                $is_path_ambiguous ||
                                $route_has_params ||
                                ( !$route_registered && _url_path_segment_is_secret( $segment ) );

        $segments[ $position ] = LABEL_SECRET_REDACT
            if $segment_is_secret;

        # #
        #   Redact next segment after a secret route or route that 
        #   can't be completely decoded.
        # #

        $redact_next_segment = $is_secret_route || $is_nested_reached ? 1 : 0;

        $loop++;
    }

    ConfigServer::DebugLocal::log( 1, $loop ? 'ok' : 'info',
        "segments:[$loop] " .
        "status:[checked url path segments]"
    );

    return join( '/', @segments );
}

# #
#   Secrets › Redact › Url
#
#   Redacts url login credentials. Removes the complete query string
#   and #fragment.
#   
#   Alternative to sub redact_obj_url_replace()
#
#   @test       Note:           Redact creds and remove query and #fragment
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::redact_obj_url(q{https://user:password@configserver.dev/check?token=secret&mode=test#section}), qq{\n};"
#               Result:         https://[REDACTED]@configserver.dev/check
#   
#   @params     url             str         Url that must be sanitized
#   @return     url             str         Sanitized url or empty string
#                                               str         Creds redacted; query and #fragment removed
#                                               ''          Input is undefined, empty / ref
# #

sub redact_obj_url
{
    my ( $url ) = @_;
    return _redact_url( $url, 0 );
}

# #
#   Secrets › Redact › Url › Query (Replace) 
#
#   Redact url login creds and secret query values.
#   Public query values untouched, fragment removed.
#   
#   Alternative to sub redact_obj_url()
#
#   @test       Note:           Redact creds and secret query values.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::redact_obj_url_replace(q{https://user:password@configserver.dev/check?token=secret&mode=test#section}), qq{\n};"
#               Result:         https://[REDACTED]@configserver.dev/check?token=[REDACTED]&mode=test
#
#   @params     url             str         Url to sanitize
#   @return     url             str         Sanitized url or empty string
#                                               str         Creds and secret query values redacted
#                                               ''          Input undefined / empty / ref
# #

sub redact_obj_url_replace
{
    my ( $url ) = @_;
    return _redact_url( $url, 1 );
}

# #
#   Secrets › Redact › String
#   
#   Limit one string, redact secrets, truncate if needed.
#   
#   @test       Note:           Redact assigned API key value
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::redact_obj_str(q{API_KEY=csf-secret}), qq{\n};"
#               Result:         API_KEY=[REDACTED]
#   
#   @params     text            str         Text to sanitize
#   @return     text            str         Redacted text (with truncation)
# #

sub redact_obj_str
{
    my ( $text ) = @_;

    my ( $_text, $is_cut )  = _chars_allow_max( $text, '' );
    $_text                  = _redact_start( $_text );

    my $out                 = $_text . ( $is_cut ? LABEL_TRUNCATE : '' );

    ConfigServer::DebugLocal::log( 1, 'ok',
        "text:[$out] cut:[$is_cut] status:[run]"
    );

    return $out;
}

# #
#   Secrets › Redact › Field
#   
#   Redact one field value.
#   Redacts anything found in %REGISTRY_SECRETS_FIELDS, not case 
#   sensitive.
#   
#   Undefined values return 'none', refs return their type, 
#   tabs / line breaks in normal values replaced with spaces.
#   
#   Eg:         redact_obj_field( "dir", "/var/log" )       Returns: /var/log
#               redact_obj_field( "uid", 1000 )             Returns: [REDACTED]
#               redact_obj_field( "UID", 1000 )             Returns: [REDACTED]
#               redact_obj_field( "gid", 1000 )             Returns: [REDACTED]
#               redact_obj_field( "value", undef )          Returns: none
#               redact_obj_field( "value", [] )             Returns: ARRAY
#               redact_obj_field( "value", "one\ntwo" )     Returns: one two
#   
#   @test       Note:           Redact a registered field
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'print ConfigServer::Secrets::redact_obj_field(q{uid}, 1000), qq{\n};'
#               Result:         [REDACTED]
#   
#               Note:           Return normal field without redaction
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'print ConfigServer::Secrets::redact_obj_field(q{dir}, q{/var/log}), qq{\n};'
#               Result:         /var/log
#   
#               Note:           Return ref type
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'print ConfigServer::Secrets::redact_obj_field(q{value}, []), qq{\n};'
#               Result:         ARRAY
#   
#   @params     name            str|undef   Field name
#               value           any         Field value
#   
#   @return     value           str         Formatted field value
#                                               none        Value undefined
#                                               [REDACTED]  Field registered
#                                               ref type    Value is ref
#                                               value       Normal formatted value
# #
 
sub redact_obj_field
{
    my ( $name, $value ) = @_;

    return 'none'
        if !defined( $value );

    my $field_name = defined( $name ) && !ref( $name )
        ? lc( "$name" )
        : '';

    my $field_name_clean = $field_name ne ''
        ? _log_flatten_ctrls( $field_name )
        : '';

    return LABEL_SECRET_REDACT
        if $field_name ne $field_name_clean;

    $field_name = $field_name_clean;

    return LABEL_SECRET_REDACT
        if $field_name ne '' and
           (
                $REGISTRY_SECRETS_FIELDS{$field_name} or
                is_config_secret( $field_name )
           );

    return ref( $value )
        if ref( $value );

    return redact_obj_str( "$value" );
}

# #
#   Secrets › Redact › Log Line
#   
#   Redact single log line; apply final log byte limit.
#   
#   @test       Note:           Redact a password inside a log message.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'print ConfigServer::Secrets::redact_obj_log(q{password=csf-csf-secret}), qq{\n};'
#               Result:         password=[REDACTED]
#   
#               Note:           Realistic log with redaction
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'my $log = q{Oct 24 14:32:17 server1 lfd[18452]: API authentication failed: user=admin password=csf-csf-secret source=1.22.33.42}; print ConfigServer::Secrets::redact_obj_log($log), qq{\n};'
#               Result:         Oct 24 14:32:17 server1 lfd[18452]: API authentication failed: user=admin password=[REDACTED] source=1.22.33.42
#
#   @params     line            str         Log line to sanitize
#   @return     line            str         Log line with redactions
# #

sub redact_obj_log
{
    my ( $line ) = @_;

    my ( $_line, $is_cut );
    my $out;

    # suppress internal debug messages during the complete log preparation
    {
        local $ConfigServer::DebugLocal::debug_redaction_active = 1;

        # check $line is plain text, shorten if > 262,144 chars
        ( $_line, $is_cut ) = _chars_allow_max( $line, '[INVALID LOG MESSAGE]' );
        $_line              = _redact_start( $_line );

        # enforce final log byte limit; add truncation marker (if shortened)
        $out                = _log_fit_record( $_line, $is_cut );
    }

    return $out;
}

# #
#   Secrets › Redact › Config Line
#   
#   Sanitize one config line with redactions if setting is secret.
#   Public settings are checked by the normal sanitizer.
#   
#   @test       Note:           Redact a secret config value.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::redact_obj_cfg_line(q{UI_PASS=secret-password}), qq{\n};"
#               Result:         UI_PASS=[REDACTED]
#   
#               Note:           Keep a public config value unredacted.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::redact_obj_cfg_line(q{RECAPTCHA_SITEKEY=public-key}), qq{\n};"
#               Result:         RECAPTCHA_SITEKEY=public-key
#   
#   @params     line            str         Config line to redact
#   @return     text            str         Sanitized config line
# #

sub redact_obj_cfg_line
{
    # #
    #   $line:      RECAPTCHA_SITEKEY=public-key
    # #

    my ( $line ) = @_;

    my ( $_line ) = _chars_allow_max( $line, '' );

    my ( $prefix, $setting_name ) = _config_parse_line( $_line );
    if ( defined( $setting_name ) and is_config_secret( $setting_name ) )
    {
        return redact_obj_log( $prefix . LABEL_SECRET_REDACT );
    }

    my $setting_display = defined( $setting_name ) ? $setting_name : 'undef';
    my $prefix_display  = defined( $prefix ) ? $prefix : 'undef';

    ConfigServer::DebugLocal::log( 1, 'ok',"setting:[$setting_display] prefix:[$prefix_display] status:[run]" );

    return redact_obj_log( $_line );
}

# #
#   Secrets › Redact › Config Hash
#
#   Return redacted copy of config hash without modifying original.
#   Replace secret settings and nested refs.
#
#   @test       Note:           Redact secret values, keep public values.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'my $safe = ConfigServer::Secrets::redact_obj_cfg_hash({ UI_PASS => q{secret-password}, RECAPTCHA_SITEKEY => q{public-key} }); print join(q{, }, $safe->{UI_PASS}, $safe->{RECAPTCHA_SITEKEY}), qq{\n};'
#               Result:         [REDACTED], public-key
#
#   @params     cfg             hashref     Config setting names and values
#   @return     cfg_safe        hashref     Config hash with secrets redacted
# #

sub redact_obj_cfg_hash
{
    my ( $cfg ) = @_;

    return { }
        if ref( $cfg ) ne 'HASH';

    my %cfg_safe;

    for my $name ( sort keys( %{$cfg} ) )
    {
        my $value = $cfg->{$name};

        if ( is_config_secret( $name ) )
        {
            $cfg_safe{$name} = LABEL_SECRET_REDACT;
            next;
        }

        if ( !defined( $value ) )
        {
            $cfg_safe{$name} = undef;
            next;
        }

        # don't return nested data that could have unredacted secrets
        if ( ref( $value ) )
        {
            $cfg_safe{$name} = LABEL_SECRET_REDACT;
            next;
        }

        $cfg_safe{$name} = redact_obj_str( $value );
    }

    return \%cfg_safe;
}

# #
#   Secrets › Read › Secret File
#   
#   Validate and read one protected secret file. Reject if anything
#   such as owners, perms, hardlinks, etc changed during read.
#   
#   @test       Note:           Create / read temp secret file.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -MFile::Temp=tempfile -MFile::Spec -e 'my ($fh, $path) = tempfile(DIR => File::Spec->tmpdir(), UNLINK => 1); binmode($fh, q{:raw}) or die $!; print {$fh} qq{API_KEY=csf-secret\n} or die $!; close($fh) or die $!; my $contents = ConfigServer::Secrets::read_file($path, max_bytes => 1024); print q{Bytes: }, length($contents), qq{\nContents: [$contents]\n};'
#               Result:         Bytes: 19
#                               Contents: [API_KEY=csf-secret
#                               ]
#   
#   @params     path            str         Absolute file path
#               opts            hash        Optional max_bytes and owner values
#   @return     contents        str         Secret file contents
# #

sub read_file
{

    # #
    #   $path       /tmp/sNYWLPue8Q
    #   %opts       max_bytes => 1024
    # #

    my ( $path, %opts ) = @_;

    Carp::croak 'Secret file cannot be opened, a bad option was provided'
        if grep
        {
            $_ ne "max_bytes" and $_ ne "owner"
        } keys %opts;

    my $opt_max_bytes_ceil = exists( $opts{max_bytes} ) ? $opts{max_bytes} : FILE_BYTE_DEFAULT;

    my $use_max_bytes_ceil = is_unsigned_int(
        $opt_max_bytes_ceil,
        1,
        FILE_BYTE_MAXIMUM,
    );

    my $max_bytes_display = defined( $use_max_bytes_ceil )
        ? $use_max_bytes_ceil
        : 'undef';

    my $max_bytes_input_display = defined( $opt_max_bytes_ceil )
        ? ref( $opt_max_bytes_ceil ) || "$opt_max_bytes_ceil"
        : 'undef';

    my $path_display = !defined( $path ) ? 'undef'
        : ref( $path ) ? ref( $path )
        : "$path";

    ConfigServer::DebugLocal::log( 1, 'info',
        "path:[$path_display] bytes_use:[$max_bytes_display] " .
        "bytes_max:[$max_bytes_input_display] " .
        "opts:[%" . ConfigServer::DebugLocal::log_singleize( \%opts ) . "] status:[start]"
    );

    my $opt_owner   = exists( $opts{owner} )
                        ? $opts{owner}
                        : ( $^O eq 'MSWin32'
                            ? $>
                            : POSIX::geteuid( ) );

    my $use_owner = is_unsigned_int( $opt_owner, 0, OWNER_UID_MAXIMUM );

    Carp::croak 'Secret file requires an absolute path'
        if !defined( $path ) or ref( $path ) or
           !File::Spec->file_name_is_absolute( $path );

    Carp::croak 'Secret file path exceeds PATH_BYTE_MAXIMUM or contains control chars'
        if _octet_length( $path ) > PATH_BYTE_MAXIMUM or
           $path =~ /[\x00-\x1F\x7F]/;

    Carp::croak 'Secret file size limit is not valid'
        if !defined( $use_max_bytes_ceil );

    Carp::croak 'Secret file owner is not valid'
        if !defined( $use_owner );

    # $path_verified = /tmp/alZ0M0FNDe
    my ( $path_verified ) = $path =~ /\A([^\x00-\x1F\x7F]+)\z/;
    Carp::croak 'Secret file path could not be validated'
        if !defined( $path_verified );

    # #
    #   Reject non linux (for tests), Windows uses different file
    #   perms and links.
    #   
    #   This sub only supports Linux.
    # #

    Carp::croak 'Secret file reading is unsupported on systems that are not Linux'
        if $^O ne 'linux';

    # $owner = 1000
    Carp::croak 'Secret file parent path is unsafe, aborting for security'
        if !_validate_secret_parent_dirs( $path_verified, $use_owner );

    # #
    #   Prepare Fileopen Flags
    #   
    #   O_NOFOLLOW      Don't open file if its final name is a symlink.
    #                   Prevents path from pointing to a different file.
    #   
    #   O_CLOEXEC       Close fh if the process starts another program.
    #                   Prevents new program from  getting the secret file.
    #   
    #   @note           Older versions of perl don't include 
    #                   O_CLOEXEC. If it's missing; use fallback.
    #                   
    #                   Fallback opens the file first and then
    #                    _set_close_on_exec() applies the 
    #                   protections after it opens.
    #   
    #                   Fallback has small delay between opening
    #                   and protecting the file, but allows older
    #                   perl builds to work.
    # #

    my $nofollow    = eval { Fcntl::O_NOFOLLOW( ) };
    my $cloexec     = eval { Fcntl::O_CLOEXEC( ) };

    Carp::croak 'O_NOFOLLOW is not available for protected secret files'
        if !defined( $nofollow );

    # open read only, without waiting on an unsafe file type
    my $flags_fopen = Fcntl::O_RDONLY( ) | Fcntl::O_NONBLOCK( ) | $nofollow;

    # use O_CLOEXEC if available; auto close file if another process starts
    $flags_fopen |= $cloexec
        if defined( $cloexec );

    my $reader;
    Carp::croak "Secret file could not be opened and read: $!"
        if !CORE::sysopen( $reader, $path_verified, $flags_fopen );

    _secrets_reader_abort( $reader, 'Secret file parent path changed while opening, aborted for security', 0 )
        if !_validate_secret_parent_dirs( $path_verified, $use_owner );

    # #
    #   verify O_CLOEXEC, or apply fallback FD_CLOEXEC (if O_CLOEXEC unavailable)
    #       O_CLOEXEC       Main        Protect while opening file
    #       FD_CLOEXEC      Fallback    Protect after file is opened
    # #

    _secrets_reader_abort( $reader, 'Secret file cannot be protected from exec inheritance, aborting for security', 0 )
        if !_set_close_on_exec( $reader );

    _secrets_reader_abort( $reader, 'Secret file could not be set to binary mode', 0 )
        if !binmode( $reader, ':raw' );

    _secrets_reader_abort( $reader, 'Secret file cannot be lock protected, aborting for security', 0 )
        if !_bounded_lock( $reader, Fcntl::LOCK_SH() );

    # #
    #   Create snapshot of file (type, owner, perms, links, size),
    #   save the current state so that we can verify it again later
    # #

    my $snapshot_initial = _validate_secret_file(
        $reader,
        $path_verified,
        $use_owner,
        $use_max_bytes_ceil,
        undef,
    );

    _secrets_reader_abort( $reader, 'Secret file was found to be unsafe', 1 )
        if !$snapshot_initial;

    my $expected_bytes          = $snapshot_initial->[ 7 ];
    my $contents                = '';

    # read file in limited chunks until we get everything
    while ( length( $contents ) < $expected_bytes )
    {
        my $bytes_remaining     = $expected_bytes - length( $contents );
        my $request_size        = $bytes_remaining < FILE_READ_BLOCK ? $bytes_remaining : FILE_READ_BLOCK;

        # read next block
        my $block               = '';
        my $received            = CORE::sysread( $reader, $block, $request_size );

        # retry if the system interrupts read for some reason
        next
            if !defined( $received ) and $! == Errno::EINTR();

        _secrets_reader_abort( $reader, 'Secret file cannot be read in its entirety, aborting', 1 )
            if !defined( $received ) or $received == 0;

        $contents .= $block;
    }

    # ensure the file did not change any while it was being read
    my $snapshot_state = _validate_secret_file(
        $reader,
        $path_verified,
        $use_owner,
        $use_max_bytes_ceil,
        $snapshot_initial,
    );

    _secrets_reader_abort( $reader, 'Secret file changed while reading, operation aborted for security', 1 )
        if !$snapshot_state or $snapshot_state->[ 7 ] != length( $contents );

    _secrets_reader_abort( $reader, 'Secret file parent path changed while reading, operation aborted for security', 1 )
        if !_validate_secret_parent_dirs( $path_verified, $use_owner );

    # unlock / release $reader on the file
    _secrets_reader_finish( $reader );

    ConfigServer::DebugLocal::log( 1, 'ok',
        "path:[$path_verified] bytes_use:[$use_max_bytes_ceil] bytes_max:[$opt_max_bytes_ceil] opts:[%" . ConfigServer::DebugLocal::log_singleize( \%opts ) . "] status:[success]"
    );

    return $contents;
}

# #
#   Secrets › Read › Protected File Lines
#   
#   Read a protected file and return its contents as separate lines
#   
#   Use max_lines when supplied; else, use FILE_LINE_MAXIMUM
#   
#   @test       Note:           Create temp file and read it as separate lines
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -MFile::Temp=tempfile -MFile::Spec -e 'my ($file, $path) = tempfile(DIR => File::Spec->tmpdir(), UNLINK => 1); print {$file} "one\ntwo\n"; close($file); print join(q{, }, ConfigServer::Secrets::read_lines($path, max_lines => 10)), "\n";'
#               Result:         one, two
#   
#   @params     path            str         Absolute file path
#               opts            hash        Optional max_lines, max_bytes, owner
#   
#   @return     lines           arr         Lines read from the file
# #

sub read_lines
{
    # #
    #   $path = '/tmp/secrets-lines-EGJZVN'
    #   
    #   $opts{max_lines} contains the supplied value:
    #       Eg: 10, 0, "invalid", undef, or []
    # #

    my ( $path, %opts ) = @_;

    # #
    #   $has_line_limit:
    #       0   $opts{max_lines} not supplied
    #       1   $opts{max_lines} was supplied, even if value invalid / undef
    # #

    my $has_line_limit = exists( $opts{max_lines} );

    # value can be either valid max_lines, or undef/invalid value; verified later
    my $use_line_limit = $has_line_limit ? delete( $opts{max_lines} ) : FILE_LINE_MAXIMUM;

    # #
    #   Validate the requested line limit:
    #       1 - 262,144     Return the valid number
    #       Anything else   Return undef; croak below rejects it
    # #

    my $use_line_ceil = is_unsigned_int(
        $use_line_limit,
        1,
        FILE_LINE_MAXIMUM,
    );

    Carp::croak 'Secret file line limit is invalid'
        if !defined( $use_line_ceil );

    return _secrets_reader_split_lines( read_file( $path, %opts ), $use_line_ceil );
}

# #
#   Secrets › Register › Secret Value
#   
#   Store a secret value for redaction. Reject invalid values.
#   
#   Remove the oldest values when the registry hits its entry/byte 
#   limit. Register the newest.
#   
#   @test       Note:           Test one accepted + one rejected secret
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print join(q{, }, ConfigServer::Secrets::register_secret(q{API_KEY}, q{csf-secret}), ConfigServer::Secrets::register_secret(q{API_KEY}, q{short})), qq{\n};"
#               Result:         1, 0
#   
#               Note:           Clear the registry and register two new values.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "ConfigServer::Secrets::registry_clear(); print join(q{, }, ConfigServer::Secrets::register_secret(q{API_KEY}, q{first-csf-secret}), ConfigServer::Secrets::register_secret(q{DB_PASSWORD}, q{second-csf-secret})), qq{\n};"
#               Result:         1, 1
#   
#   @params     name            str         Setting name to check
#               value           str         Setting value to register
#   
#   @return     is_registered   int         If the secret was registered
#                                               1           Secret was registered
#                                               0           Secret was rejected
# #

sub register_secret
{
    my ( $name, $value ) = @_;

    my $name_display    = !defined( $name ) ? 'undef'
                            : ref( $name ) ? ref( $name )
                            : "$name";

    my $secret          = _validate_registry_value( $name, $value );
    my $secret_rejected = !defined( $secret );

    ConfigServer::DebugLocal::log( 1, 'warn', "name:[$name_display] status:[registration rejected]" )
        if $secret_rejected;

    return 0
        if !defined( $secret );

    my $secret_bytes    = _octet_length( $secret );
    my $secret_exists   = exists( $registry_secrets{$secret} );

    ConfigServer::DebugLocal::log( 1, 'info',
        "name:[$name_display] " .
        "status:[already registered]"
    ) if $secret_exists;

    # $secret already reg'd
    return 1
        if $secret_exists;

    my $expired_i = 0;

    # max number of secrets (256); remove oldest secret
    if ( keys( %registry_secrets ) >= REGISTRY_ENTRY_MAXIMUM )
    {
        my $secret_oldest       = _oldest_registered_value( );
        $registry_secrets_bytes -= _octet_length( $secret_oldest );

        delete $registry_secrets{$secret_oldest};
        $expired_i++;
    }

    # max combined byte size; remove old secrets until new value fits within byte limit (64 * 1024 (64 KB))
    while ( keys( %registry_secrets ) and $registry_secrets_bytes + _octet_length( $secret ) > REGISTRY_BYTE_MAXIMUM )
    {
        my $secret_oldest           = _oldest_registered_value( );
        $registry_secrets_bytes     -= _octet_length( $secret_oldest );

        delete $registry_secrets{$secret_oldest};
        $expired_i++;
    }

    # register $secret and registration order
    $registry_secrets{$secret} = ++$registry_secrets_sequence;

    # record $secret size bytes to the registry total
    $registry_secrets_bytes += _octet_length( $secret );

    # #
    #   Clear any stored filters after changes to the registry. Build
    #   only when needed, otherwise we take performance hits.
    # #

    $registry_secrets_match_bytes   = undef;
    $registry_secrets_match_decoded = undef;
    @registry_secrets_decoded       = ( );

    my $registry_i = scalar( keys( %registry_secrets ) );

    ConfigServer::DebugLocal::log( 1, 'ok',
        "name:[$name_display] " .
        "entries:[$registry_i] " .
        "expired:[$expired_i] " .
        "status:[secret registered]"
    );

    return 1;
}

# #
#   Secrets › Register › Configuration Secrets
#   
#   Register secret values from config hash. The following will
#   not be registered as secrets:
#       - public settings
#       - invalid values
#       - exempt words
#       - bad sizes
#   
#   @test       Note:           Register two secret values, skip public one
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print ConfigServer::Secrets::register_secrets({ UI_PASS => q{secret-password}, RECAPTCHA_SECRET => q{secret-captcha-secret}, RECAPTCHA_SITEKEY => q{public-site-key} }), qq{\n};"
#               Result:         2
#   
#   @params     cfg             hashref     Setting names and values to register
#   @return     registered      int         Num of secrets registered
#                                               0           No secrets registered
#                                               1+          Num of accepted secrets
# #

sub register_secrets
{
    my ( $cfg ) = @_;

    return 0
        if ref( $cfg ) ne 'HASH';

    # #
    #   Process setting names in sorted order; count how many values
    #   register_secret() accepts
    # #

    return scalar(
        grep
        {
            register_secret( $_, $cfg->{$_} )
        }
        sort keys %{$cfg}
    );
}

# #
#   Secrets › Registry › Clear Registered Secrets
#   
#   Remove all secret values stored for redaction.
#   Reset registry count, size,regex filter, etc.
#   
#   @test       Note:           Clear the registry and confirm the value remains visible.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "ConfigServer::Secrets::register_secret(q{API_KEY}, q{csf-secret}); print ConfigServer::Secrets::registry_clear(), qq{\n}; print ConfigServer::Secrets::redact_obj_str(q{csf-secret}), qq{\n};"
#               Result:         1
#                               csf-secret
#   
#   @params     void
#   @return     is_cleared      int         If registry was cleared
#                                               1           Registry cleared
# #

sub registry_clear
{
    # remove all registered values
    %registry_secrets = ( );

    # reset registration order
    $registry_secrets_sequence = 0;

    # reset combined byte count
    $registry_secrets_bytes = 0;

    # remove compiled redaction filter
    $registry_secrets_match_bytes = undef;

    # clear decoded unicode
    @registry_secrets_decoded          = ( );
    $registry_secrets_match_decoded    = undef;

    my $registry_i      = scalar( keys( %registry_secrets ) );
    my $filter_exists   = defined( $registry_secrets_match_bytes ) ? 1 : 0;

    ConfigServer::DebugLocal::log( 1, 'ok',
        "entries:[$registry_i] " .
        "sequence:[$registry_secrets_sequence] " .
        "bytes:[$registry_secrets_bytes] " .
        "filter:[$filter_exists] " .
        "status:[cleared secrets]"
    );

    # cleared
    return 1;
}

# #
#   Secrets › Registry Stats
#
#   Return registry totals and limits. Does not return secret names
#   and values.
#
#   @test       Note:           Return stats after registering one secret.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e 'ConfigServer::Secrets::registry_clear(); ConfigServer::Secrets::register_secret(q{API_KEY}, q{csf-secret}); my $stats = ConfigServer::Secrets::registry_stats(); print join(q{, }, map { qq{$_=$stats->{$_}} } qw(entry_count byte_count entry_maximum byte_maximum)), qq{\n};'
#               Result:         entry_count=1, byte_count=10, entry_maximum=256, byte_maximum=65536
#
#   @params     void
#   @return     stats           hashref     Registry counts and limits
# #

sub registry_stats
{
    return
    {
        entry_count     => scalar( keys( %registry_secrets ) ),
        byte_count      => $registry_secrets_bytes,
        entry_maximum   => REGISTRY_ENTRY_MAXIMUM,
        byte_maximum    => REGISTRY_BYTE_MAXIMUM,
    };
}

# #
#   Secrets › Is Config Secret
#   
#   Check if the specified setting name is a secret.
#   
#   Max length of a secret name is restricted by const
#   SETTING_NAME_BYTE_MAXIMUM. Any secrets that are longer will be
#   automatically marked as a secret.
#   
#   @test       Note:           Get status of specific setting names.
#               Command:        sudo env DEBUG=4 perl -I. -MConfigServer::Secrets -e "print join(q{, }, ConfigServer::Secrets::is_config_secret(q{UI_PASS}), ConfigServer::Secrets::is_config_secret(q{RECAPTCHA_SITEKEY}), ConfigServer::Secrets::is_config_secret(q{DATABASE_PASSWORD}), ConfigServer::Secrets::is_config_secret(q{PUBLIC_VALUE})), qq{\n};"
#               Result:         1, 0, 1, 0
#   
#   @params     name            str         Name to check
#   @return     is_secret       int         If the name is treated as secret
#                                               1           Name is secret or oversized
#                                               0           Name is public or invalid
# #

sub is_config_secret
{
    my ( $name ) = @_;

    my $name_invalid    = !defined( $name ) || ref( $name );
    my $name_display    = !defined( $name ) ? 'undef'
                            : ref( $name ) ? ref( $name )
                            : "$name";

    ConfigServer::DebugLocal::log( 1, 'warn', "name:[$name_display] status:[public; invalid input]" )
        if $name_invalid;

    # flag as public
    return 0
        if $name_invalid;

    $name               = "$name";
    my $name_bytes      = _octet_length( $name );
    my $name_too_long   = $name_bytes > SETTING_NAME_BYTE_MAXIMUM;

    ConfigServer::DebugLocal::log( 1, 'warn',
        "len:[$name_bytes] " .
        "max:[" . SETTING_NAME_BYTE_MAXIMUM . "] " .
        "status:[secret; name exceeds byte limit]"
    ) if $name_too_long;

    # flag as secret
    return 1
        if $name_too_long;

    my $name_prepared   = _secret_prepare_name( $name );
    $name_invalid       = !defined( $name_prepared );

    ConfigServer::DebugLocal::log( 1, 'warn',
        "name:[$name] status:[public; invalid name]"
    ) if $name_invalid;

    # flag as public
    return 0
        if $name_invalid;

    $name = $name_prepared;

    # return exact CSF setting hash rule if it exists
    my $rule_exists = exists( $REGISTRY_SECRET_SETTINGS{$name} );
    my $is_secret   = $rule_exists ? $REGISTRY_SECRET_SETTINGS{$name}
                        : _has_secret_name_suffix( $name );

    my $route       = $rule_exists ? 'exact setting' : 'suffix';
    my $result      = $is_secret ? 'secret' : 'public';

    ConfigServer::DebugLocal::log( 1, $is_secret ? 'ok' : 'info',
        "name:[$name] route:[$route] status:[$result]"
    );

    # flag as secret
    return $is_secret;
}

1;
