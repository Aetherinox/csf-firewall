# #
#   Copyright (c) 2025 Aetherinox
#   
#   Permission is hereby granted, free of charge, to any person obtaining a copy
#   of this software and associated documentation files (the "Software"), to
#   deal in the Software without restriction, including without limitation the
#   rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
#   sell copies of the Software, and to permit persons to whom the Software is
#   furnished to do so, subject to the following conditions:
#   
#   The above copyright notice and this permission notice shall be included in
#   all copies or substantial portions of the Software.
#   
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
#   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
#   IN THE SOFTWARE.
# #

# #
#   <!-- md:command `-s,  --start` -->
#   <!-- md:backers -->
#   <!-- md:flag metadata -->
#   <!-- md:default `false` -->
#   <!-- md:default none -->
#   <!-- md:default computed -->
#   <!-- md:flag required -->
#   <!-- md:flag customization -->
#   <!-- md:flag experimental -->
#   <!-- md:flag multiple -->
#   <!-- md:example my-example-file -->
#   <!-- md:3rdparty -->
#   <!-- md:3rdparty [mike] -->
#   <!-- md:option social.icon -->
#   <!-- md:setting config.reeee -->
#   <!-- md:feature -->
# #

from __future__ import annotations

# #
#   Import
# #

import posixpath
import re
import inspect
import os

# #
#   From
# #

from mkdocs.config.defaults import MkDocsConfig
from mkdocs.structure.files import File, Files
from mkdocs.structure.pages import Page
from re import Match

# #
#   ASCII Colors
# #

class clr( ):
    BLACK = '\033[30m'
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    WHITE = '\033[37m'
    GREY = '\033[90m'
    UNDERLINE = '\033[4m'
    RESET = '\033[0m'

# #
#   Pages
#   
#   these must be configured to a valid page path; otherwise the script will error
# #

PAGE_CHANGELOG = "about/changelog.md"
PAGE_BACKERS = "insiders/index.md"
PAGE_CONVENTIONS = "about/conventions.md"

# #
#   Hooks › on_page_markdown
#   
#   there are two ways you can make a badge appear
#       1.  the actual badge                <!-- md:flag required -->
#       2.  an html raw code example        <!-- @md:flag required -->
#   
#   @warning    do not change this function name
#   
#   @args       markdown        returns the full markdown of the entire page
#               page            returns page name                               Page(title='Troubleshooting', url='/csf-firewall/usage/troubleshooting/')
#               config          full mkdocs config parameters                   {'config_file_path': '/path/csf-firewall/docs/mkdocs.yml', 'site_name': 'Doc Name', 'nav': [{'Home': 'home.md'}
#               files           file structure                                  <mkdocs.structure.files.Files object at 0x000002296F748C20>
# #

def on_page_markdown( markdown: str, *, page: Page, config: MkDocsConfig, files: Files ):
    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Loading Page: ' + clr.YELLOW + str(page) + clr.WHITE )

    def replace(match: Match):
        esc_marker, type, args = match.groups( )
        args = args.strip( )

        # #
        #   if user wrote <!-- @md:... --> -> return literal comment (strip @)
        # #

        if esc_marker == "@":
            if args:
                literal = f"<!-- md:{type} {args} -->"
            else:
                literal = f"<!-- md:{type} -->"

            # Return literal directly, no wrapping in backticks
            return literal

        # #
        #   process badge
        # #

        if type == "version":
            if re.match(r"^(dev(elopment)?-)", args, re.I):
                return badgeVersionDev( args, page, files )
            elif re.match(r"^(stable-|public-)", args, re.I):
                return badgeVersionStable( args, page, files )
            else:
                return badgeVersionDefault( args, page, files )

        elif type == "link":            return newLink( args, page, files )
        elif type == "control":         return badgeControl( args, page, files )
        elif type == "flag":            return badgeFlag( args, page, files )
        elif type == "option":          return badgeOption( args )
        elif type == "setting":         return badgeSetting( args )
        elif type == "sponsor":         return badgeSponsors( page, files )
        elif type == "command":         return badgeCommand( args, page, files )
        elif type == "feature":         return badgeFeature( args, page, files )
        elif type == "plugin":          return badgePlugin( args, page, files )
        elif type == "markdown":        return badgeMarkdown( args, page, files )
        elif type == "3rdparty":        return badge3rdParty( args, page, files )
        elif type == "docs":            return badgeDocs( args, page, files )
        elif type == "fileViewDLExt":   return badgeFileViewDLExt( args, page, files )
        elif type == "fileDLExt":       return badgeFileDLExt( args, page, files )
        elif type == "fileView":        return badgeFileView( args, page, files )
        elif type == "fileBaseView":    return badgeFileBaseView( args, page, files )
        elif type == "fileBaseDL":      return badgeFileBaseDL( args, page, files )
        elif type == "source":          return badgeFileSource( args, page, files )
        elif type == "requires":        return badgeFileRequires( args, page, files )
        elif type == "default":
            if   args == "none":        return badgeDefaultNone( page, files )
            elif args == "computed":    return badgeDefaultComputed( page, files )
            else:                       return badgeDefaultCustom( args, page, files )

        raise RuntimeError( f"Error in shortcodes.yp - Specified an unknown shortcode: {type}" )

    # #
    #   one-pass replacement
    # #

    return re.sub(
        r"<!--\s*(@?)md:(\w+)(.*?)-->",
        replace, markdown, flags=re.I | re.M
    )

# #
#   Helper Function › Resolve
#   
#   Resolve path of file relative to given page - the posixpath always includes
#   one additional level of `..` which we need to remove
#   
#   used by function _resolve_path
# #

def _resolve( file: File, page: Page ):
    path = posixpath.relpath(file.src_uri, page.file.src_uri)
    return posixpath.sep.join(path.split(posixpath.sep)[1:])

# #
#   Helper Function › Resolve Paths
#   
#   Resolve path of file relative to given page - the posixpath always includes
#   one additional level of `..` which we need to remove
# #

def _resolve_path( path: str, page: Page, files: Files ):
    path, anchor, *_ = f"{path}#".split("#")
    path = _resolve(files.get_file_from_path(path), page)
    return "#".join([path, anchor]) if anchor else path

# #
#   Links
#   
#   Creates a link to either an external or internal location.
#   Can specify a new or same target.
#   
#   <!-- md:link "Example Text" https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/get.sh -->
#   <!-- md:link "Local Link" #firefox-this-address-is-restricted same -->
# #

def newLink( text: str, page: Page, files: Files ):

    # #
    #   Extract: "label with spaces" href target
    #   
    #   Regex groups:
    #     1 › quoted label (optional)
    #     2 › unquoted label (optional)
    #     3 › href
    #     4 › target (optional)
    # #

    m = re.match(
        r'^\s*(?:"([^"]+)"|(\S+))\s+(\S+)(?:\s+(\S+))?\s*$',
        text
    )

    if not m:
        return ""

    label       = m.group(1) if m.group(1) else m.group(2)
    href        = m.group(3)
    target      = (m.group(4) or "blank").lower()

    # #
    #   Map target → valid HTML target attribute
    # #

    target_map = {
        "blank": "_blank",
        "new":   "_blank",
        "b":     "_blank",

        "self":  "_self",
        "same":  "_self",
        "s":     "_self",

        "parent": "_parent",
        "p":      "_parent",

        "top": "_top",
        "t":   "_top"
    }

    target_attr = target_map.get(target, "_blank")

    # #
    #   Build final link
    # #

    icon = "aetherx-axs-link"

    return (
        f"<span class=\"aether-doc-link\">"
        f"<a href=\"{href}\" target=\"{target_attr}\">"
        f"<span class=\"aether-doc-link-icon\">:{icon}:</span>"
        f"<span class=\"aether-doc-link-text\">{label}</span>"
        f"</a>"
        f"</span>"
    )

# #
#   Badge › Flag
#       
#   Normal Badges
#       <!-- md:flag experimental --> Experimental
#       <!-- md:flag required --> Required 
#       <!-- md:flag customization --> Customization
#       <!-- md:flag metadata --> Metadata
#       <!-- md:flag dangerous --> Dangerous
#       <!-- md:flag multiple --> Multiple
#       <!-- md:flag setting --> Setting
#   
#   @args       args            setting, required, experimental, customization, dangerous
# #

def badgeFlag( args: str, page: Page, files: Files ):
    type, *_ = args.split(" ", 1)
    if   type == "experimental":    return badgeFlagExperimental( page, files )
    elif type == "required":        return badgeFlagRequired( page, files )
    elif type == "customization":   return badgeFlagCustomization( page, files )
    elif type == "metadata":        return badgeFlagMetadata( page, files )
    elif type == "dangerous":       return badgeFlagDangerous( page, files )
    elif type == "multiple":        return badgeFlagMultiInstances( page, files )
    elif type == "setting":         return badgeFlagSetting( page, files )
    else: return badgeFlagDefault( page, files )

    raise RuntimeError( f"Unknown type: {type}" )

# #
#   Badge › Controls › Default
#   
#   This function is activated if no control type specified and is considered the default control
#   
#   Normal Badges:
#       <!-- md:control -->
# #

def newControlDefault( page: Page, files: Files ):
    icon = "aetherx-axs-hand-pointer"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#controls", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Type: Textbox')"
    )

# #
#   Badge › Controls
#   
#   Use these to indicate if a setting can be triggered by a specific in-app control.
#   
#   Normal Badges:
#       <!-- md:control -->                             default
#       <!-- md:control toggle -->                      toggle
#       <!-- md:control toggle_on -->                   toggle on
#       <!-- md:control toggle_off -->                  toggle off
#       <!-- md:control textbox -->                     textbox
#       <!-- md:control dropdown -->                    dropdown
#       <!-- md:control button -->                      button
#       <!-- md:control slider -->                      slider
#       <!-- md:control env -->                         env variable
#       <!-- md:control volume -->                      volume
#       <!-- md:control color #FFFFFF #121315 -->   color wheel
# #

def badgeControl( args: str, page: Page, files: Files ):
    type, *_ = args.split( " ", 2 )
    if   type == "toggle":      return newControlToggle( page, files )
    elif type == "toggle_on":   return newControlToggleOn( page, files )
    elif type == "toggle_off":  return newControlToggleOff( page, files )
    elif type == "textbox":     return newControlTextbox( page, files )
    elif type == "dropdown":    return newControlDropdown( page, files )
    elif type == "button":      return newControlButton( page, files )
    elif type == "slider":      return newControlSlider( page, files )
    elif type == "env":         return newControlEnvVar( page, files )
    elif type == "volume":      return newControlVolume( page, files )
    elif type == "color":       return newControlColor( args, page, files )
    else: return newControlDefault( page, files )

    raise RuntimeError( f"Unknown type: {type}" )

# #
#   Badge › Version › Default
#   
#   In order for the version badge to work, you must have a corresponding version entry in your changelog.md.
#   if not, you will receive the console error `'NoneType' object has no attribute 'src_uri'`
#   
#   Normal Badges:
#       <!-- md:version -->
#       <!-- md:version 1.6.1 -->
# #

def badgeVersionDefault( text: str, page: Page, files: Files ):
    spec        = text
    path        = f"{PAGE_CHANGELOG}#{spec}"

    # Return badge
    icon        = "aetherx-axs-box"
    href        = _resolve_path( f"{PAGE_CONVENTIONS}#release-types", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon    = f"[:{icon}:]({href} 'Public Release')",
        text    = f"[{text}]({_resolve_path(path, page, files )})" if spec else "",
        type    = "version"
    )

# #
#   Badge › Version › Stable
#   
#   Normal Badges:
#       <!-- md:version stable- -->
#       <!-- md:version stable-1.6.1 -->
#       <!-- md:version public-1.6.1 -->
# #

def badgeVersionStable( text: str, page: Page, files: Files ):
    spec    = re.sub(r"^(stable-|public-)", "", text, flags=re.I)
    path    = f"{PAGE_CHANGELOG}#{spec}"

    # Return badge
    icon    = "aetherx-axs-tag"
    href    = _resolve_path( f"{PAGE_CONVENTIONS}#release-types", page, files )
    output  = ""

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    # spec not empty
    if spec:
        output = f"Requires stable version {spec}"
    else:
        output = f"Stable Release"

    return badgeCreate(
        icon = f"[:{icon}:]({href} '{output}' )",
        text = f"[{spec}]({_resolve_path(path, page, files )})" if spec else "",
        type = "version"
    )

# #
#   Badge › Version › Development
#   
#   Normal Badges:
#       <!-- md:version dev- -->
#       <!-- md:version dev-1.6.1 -->
#       <!-- md:version development-1.6.1 -->
# #

def badgeVersionDev( text: str, page: Page, files: Files ):
    spec    = re.sub(r"^(dev(elopment)?-)", "", text, flags=re.I)
    path    = f"{PAGE_CHANGELOG}#{spec}"

    # Return badge
    icon    = "aetherx-axs-code"
    href    = _resolve_path( f"{PAGE_CONVENTIONS}#release-types", page, files )
    output  = ""

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    # Spec not empty
    if spec:
        output = f"Requires dev version {spec}"
    else:
        output = f"Development Release"

    return badgeCreate(
        icon = f"[:{icon}:]({href} '{output}' )",
        text = f"[{spec}]({_resolve_path(path, page, files )})" if spec else "",
        type = "version"
    )

# #
#   Badge › Default Value › Custom
#   
#   This defines what the default value for a setting is.
#   
#   Normal Badges:
#       <!-- md:default `false` -->
#       <!-- md:default `my settings value` -->
# #

def badgeDefaultCustom( text: str, page: Page, files: Files ):
    icon = "material-water"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#default", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Default value')",
        text = text,
        type = "default"
    )

# #
#   Badge › Default Value › None / Empty
#   
#   This defines what the default value for a setting is.
#   
#   Normal Badges:
#       <!-- md:default none -->
# #

def badgeDefaultNone( page: Page, files: Files ):
    icon = "material-water-outline"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#default", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Default value is empty')",
        type = "default"
    )

# #
#   Badge › Default Value › Computed
#   
#   This defines what the default value for a setting is.
#   
#   Normal Badges:
#       <!-- md:default computed -->
# #

def badgeDefaultComputed( page: Page, files: Files ):
    icon = "material-water-check"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#default", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Default value is computed')",
        type = "default"
    )

# #
#   Badge › Command
#   
#   Used when specifying a command in an app
#   
#   Normal Badges:
#       <!-- md:command -->                     Specified setting has a default value  <!-- @md:command -->
#       <!-- md:command `-s,  --start` -->      Specified setting has a default value  <!-- @md:command -s, --start -->
# #

# reeee
def badgeCommand( text: str, page: Page, files: Files ):
    icon = "material-console-line"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#command", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Terminal / Console Command')",
        text = text,
        type = "command"
    )

# #
#   Badge › 3rd Party
#   
#   This symbol denotes that the item described is classified as something that changes the overall functionality of the plugin.
#   
#   Normal Badges:
#       <!-- md:3rdparty -->
#       <!-- md:3rdparty [mike] -->
# #

def badge3rdParty( text: str, page: Page, files: Files ):
    icon = "material-package-variant"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#3rdparty", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Third-party utility')",
        text = text,
        type = "3rdparty"
    )

# #
#   Badge › Docs
#   
#   This symbol denotes that the user can click the button and view additional documentation elsewhere
#   
#   Normal Badges:
#       <!-- md:docs ../advanced/services/blocklist.configserver/ -->
#       <!-- md:docs ../advanced/services/blocklist.configserver/ self -->
# #

def badgeDocs( text: str, page: Page, files: Files ):

    # #
    #   Parse arguments: "href [target]"
    # #

    parts       = text.strip().split()
    href        = parts[0] if len(parts) > 0 else ""
    target_arg  = parts[1].lower() if len(parts) > 1 else "blank"

    # #
    #   Normalize target argument
    # #

    target_map = {
        "blank": "_blank",
        "b": "_blank",
        "new": "_blank",
        "n": "_blank",
        "self": "_self",
        "s": "_self",
        "parent": "_parent",
        "p": "_parent",
        "top": "_top",
        "t": "_top"
    }

    target_attr = target_map.get( target_arg, "_blank" )

    # #
    #   If no href -> just show a generic docs icon
    # #

    if not href:
        icon    = "aetherx-axs-book-open"
        href    = _resolve_path(f"{PAGE_CONVENTIONS}#docs", page, files)

        return badgeCreate(
            icon=f"[:{icon}:]({href} 'View Docs')"
        )

    # #
    #   Otherwise, return docs badge with icon + link
    # #

    icon = "aetherx-axs-book-open"
    return badgeCreate(
        icon=f"[:{icon}:]({href} 'View Docs'){{: target=\"{target_attr}\" }}",
        text=f"[View Docs]({href}){{: target=\"{target_attr}\" }}",
        type="docs-view"
    )

# #
#   Badge › Option
#   
#   Normal Badges:
#       <!-- md:option rss.enabled -->
#       <!-- md:option rss.match_path -->
# #

def badgeOption( type: str ):
    parts   = re.split( r"[.:]", type )
    name    = parts[-1]  # last chunk only
    return f"[`{type}`](#+{type}){{ #+{type} }}\n\n"

# #
#   Badge › Setting
#   
#   Normal Badges:
#       #### <!-- md:setting example.setting.enabled -->
#       #### <!-- md:setting config.archive -->
# #

def badgeSetting( type: str ):
    _, *_, name = re.split( r"[.*]", type )
    return f"`{name}` {{ #{type} }}\n\n[{type}]: #{type}\n\n"

# #
#   Badge › Color Palette
#   
#   Normal Badges
#       <!-- md:control color #FFFFFF #121315 -->
# #

def badgeColorPalette( icon: str, text: str = "", type: str = "" ):
    args        = type.split( " " )

    bg1_clr     = "#000000"
    bg2_clr     = "#000000"
    bg1_dis     = "none"
    bg2_dis     = "none"

    if len( args ) > 1:
        bg1_clr = args[ 1 ]
        bg1_dis = "inline-block"

    if len( args ) > 2:
        bg2_clr = args[ 2 ]
        bg2_dis = "inline-block"

    classes = f"mdx-badge mdx-badge--{type}" if type else "mdx-badge"
    return "".join([
        f"<span class=\"{classes}\">",
        *([f"<span class=\"mdx-badge__icon\">{icon}</span>"] if icon else []),
        *([f"<span class=\"mdx-badge__text\">{text}</span>"] if text else []),
        f"<span style=\"display: {bg1_dis};\" class=\"color-container\"><span class=\"color-box\" style=\"background-color:{bg1_clr};\">  </span></span>",
        f"<span style=\"display: {bg2_dis};\" class=\"color-container\"><span class=\"color-box\" style=\"background-color:{bg2_clr};\">  </span></span></span>",
    ])

# #
#   Badge › Insiders Sponsor
#   
#       In order for the sponsor badge to work, you must have a sponsors page created in mkdocs.
#       add a new file; usually about/sponsors.md
#       create a new entry in your mkdocs.yml to add the page to your navigation
#   
#   Normal Badges:
#       <!-- md:sponsors --> __Sponsors only__ – this plugin is currently reserved to [our awesome sponsors].
#       <!-- md:sponsors -->
# #

def badgeSponsors( page: Page, files: Files ):
    icon = "material-heart"
    href = _resolve_path( PAGE_BACKERS, page, files )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Sponsors')",
        type = "heart"
    )

# #
#   Badge › Feature
#   
#   Normal Badges:
#       <!-- md:feature -->
# #

def badgeFeature( text: str, page: Page, files: Files ):
    icon    = "material-toggle-switch"
    href    = _resolve_path( f"{PAGE_CONVENTIONS}#feature", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Optional feature')",
        text = text,
        type = "feature"
    )

# #
#   Badge › Plugin
#   
#   Normal Badges:
#       <!-- md:plugin -->
#       <!-- md:plugin [glightbox] -->
#       <!-- md:plugin [typeset] – built-in -->
# #

def badgePlugin( text: str, page: Page, files: Files ):
    icon    = "material-floppy"
    href    = _resolve_path( f"{PAGE_CONVENTIONS}#plugin", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Plugin')",
        text = text,
        type = "plugin"
    )

# #
#   Badge › Markdown
#   
#   Normal Badges:
#       <!-- md:markdown [admonition][Admonition] -->
# #

def badgeMarkdown( text: str, page: Page, files: Files ):
    icon    = "material-language-markdown"
    href    = _resolve_path( f"{PAGE_CONVENTIONS}#markdown-extension", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Markdown extension')",
        text = text,
        type = "markdown"
    )
    
# #
#   Badge › Button:(View File)
#   
#   Shows a single view file button.
#   
#   @arg    href                URL / path for user to view file
#   
#   Badges:
#       <!-- md:fileBaseView https://example.com/file.txt -->
# #

def badgeFileBaseView( text: str, page: Page, files: Files ):
    href            = text
    basename, ext   = os.path.splitext(text)
    icon            = "material-folder-eye"

    # #
    #   Prevent empty `` ticks by only showing extension badge when ext is non-empty
    # #

    ext_badge = ""

    return badgeCreate(
        icon=f"[:{icon}:]({href} 'View'){{: target=\"_blank\" }}",
        text=ext_badge,
        type="files-view"
    )

# #
#   Badge › Button:(Download File)
#   
#   Shows a single download file button.
#   
#   @arg    href                URL / path for user to view file
#   
#   Badges:
#       <!-- md:fileBaseDL https://example.com/file.txt -->
# #

def badgeFileBaseDL( text: str, page: Page, files: Files ):
    href            = text
    basename, ext   = os.path.splitext(text)
    icon            = "material-folder-download"

    # #
    #   Prevent empty `` ticks by only showing extension badge when ext is non-empty
    # #

    ext_badge = ""
    if ext:
        ext_badge = f"[{ext}]({href}){{: target=\"_blank\" }}"

    return badgeCreate(
        icon=f"[:{icon}:]({href} 'Download'){{: target=\"_blank\" }}",
        text=ext_badge,
        type="files-download"
    )

# #
#   Badge › Button:(View File) + Button:(Download File) + Box:(File Extension)
#   
#   Accessible via front-end markdown
#   
#   Can show 3 buttons
#       1. View file button
#       2. Download file button
#       3. Box with extension of file (.zip)
#   
#   Uses functions:
#       badgeFileBaseView
#       badgeFileBaseDL
#   
#   @arg    filenameView        URL / path for user to view file
#   @arg    filenameDownload    URL / path for user to download file
#   @arg    alignment           Which direction to align buttons in (left, right)
#   
#   Badges:
#       <!-- md:fileViewDLExt https://example.com/file.txt https://example.com/fileabc.txt left -->
# #
    
def badgeFileViewDLExt( text: str, page: Page, files: Files ):

    # #
    #   Parse arguments: "filenameView filenameDownload [alignment]"
    # #

    parts               = text.strip().split()
    filenameView        = parts[0] if len(parts) > 0 else ""
    filenameDownload    = parts[1] if len(parts) > 1 else ""
    align_arg           = parts[2].lower() if len(parts) > 2 else "right"

    # #
    #   Normalize alignment argument
    # #

    if align_arg in ("l", "left"):
        align_class = "mdx-badge--files-group-left"
    else:
        align_class = "mdx-badge--files-group-right"

    # #
    #   No filenameView → show generic file icon badge
    # #

    if not filenameView:
        icon = "material-file"
        href = _resolve_path(f"{PAGE_CONVENTIONS}#file", page, files)
        return badgeCreate(
            icon=f"[:{icon}:]({href} 'File reference')"
        )

    # #
    #   Normal (view + download) badges
    # #

    return (
        f'<span class="mdx-badge {align_class}">'
        f'{badgeFileBaseView( filenameView, page, files )}'
        f'{badgeFileBaseDL( filenameDownload, page, files )}'
        f'</span>'
    )

# #
#   Badge › File › Download (Single)
#   
#   Can show 2 buttons
#       1. Download button
#       2. Box with file extension inside (.zip)
#   
#   Normal Badges:
#       <!-- md:fileDLExt https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/example_configs/etc/csf/csf.conf -->
#       <!-- md:fileDLExt https://example.com/files/sample.zip left -->
#       <!-- md:fileDLExt https://example.com/files/sample.zip right -->
# #

def badgeFileDLExt( text: str, page: Page, files: Files ):

    # #
    #   Parse arguments: "filenameDownload [alignment]"
    # #

    parts               = text.strip().split()
    filenameDownload    = parts[0] if len(parts) > 0 else ""
    align_arg           = parts[1].lower() if len(parts) > 1 else "right"

    # #
    #   Normalize alignment argument
    # #

    if align_arg in ("l", "left"):
        align_class = "mdx-badge--files-group-left"
    else:
        align_class = "mdx-badge--files-group-right"

    # #
    #   Otherwise, return both badges inside chosen-alignment container
    # #

    return (
        f'<span class="mdx-badge {align_class}">'
        f'{badgeFileBaseDL(filenameDownload, page, files)}'
        f'</span>'
    )

# #
#   Badge › File › View › Single
#   
#   Shows a single button with folder icon, can click to view file in URL.
#   Calls badgeFileBaseView
#   
#   Badges
#       <!-- md:fileView https://example.com/file.txt left --> 1
# #

def badgeFileView( text: str, page: Page, files: Files ):

    # #
    #   Parse arguments: "filenameView [alignment]"
    # #

    parts           = text.strip().split()
    filenameView    = parts[0] if len(parts) > 0 else ""
    align_arg       = parts[1].lower() if len(parts) > 1 else "right"

    # #
    #   Normalize alignment argument
    # #

    if align_arg in ("l", "left"):
        align_class = "mdx-badge--files-group-left"
    else:
        align_class = "mdx-badge--files-group-right"

    # #
    #   Otherwise, return both badges inside chosen-alignment container
    # #

    return (
        f'<span class="mdx-badge {align_class}">'
        f'{badgeFileBaseView(filenameView, page, files)}'
        f'</span>'
    )

# #
#   Badge › File › Requires
#   
#   This defines what the required file is.
#   
#   MUST add an entry in conventions.md
#   
#   can switch out css icons for js icons such as font-awesome's all.js
#       if you replace the icon line with
#       icon=f"<i class='axd ax-file'></i>",
#   
#   Normal Badges:
#       <!-- md:requires `/usr/local/cwpsrv` -->
# #

def badgeFileRequires( text: str, page: Page, files: Files ):
    icon        = "aetherx-axs-file"
    tooltip     = "This feature requires the file <pre>" + text + "</pre>"
    href        = _resolve_path( f"{PAGE_CONVENTIONS}#requires", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW +
          inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' +
          clr.GREY + str(href) + clr.WHITE + ' Text: ' + clr.GREY + text + ' Tooltip: ' + clr.GREY + tooltip + ' Icon: ' + clr.GREY + icon)

    return badgeCreate(
        icon = f"[:{icon}:]({href} '{tooltip}')",
        text=text,
        type = "file-required"
    )

# #
#   Badge › File › Source
#   
#   This defines where a setting can be found in what file
#   
#   MUST add an entry in conventions.md
#   
#   can switch out css icons for js icons such as font-awesome's all.js
#       if you replace the icon line with
#       icon=f"<i class='axd ax-file'></i>",
#   
#   Normal Badges:
#       <!-- md:source `/etc/csf/csf.conf` -->
# #

def badgeFileSource( text: str, page: Page, files: Files ):
    icon        = "aetherx-axd-file"
    tooltip     = "This setting can be found in the file <pre>" + text + "</pre>"
    href        = _resolve_path( f"{PAGE_CONVENTIONS}#source", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW +
          inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' +
          clr.GREY + str(href) + clr.WHITE)

    return badgeCreate(
        icon = f"[:{icon}:]({href} '{tooltip}')",
        text = text,
        type = "file-source"
    )

# #
#   Badge › Flags › Default
#   
#   This symbol denotes that the specified item is a customizable setting
#   
#   MUST add an entry in conventions.md
#   
#   Normal Badges
#       <!-- md:flag --> Default
# #

def badgeFlagDefault( page: Page, files: Files ):
    icon        = "material-flag"
    href        = _resolve_path( f"{PAGE_CONVENTIONS}#setting", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Configurable Setting')",
        type = "flag-default"
    )

# #
#   Badge › Flags › Metadata Property
#   
#   This symbol denotes that the item described is a metadata property, which can
#   be used in Markdown documents as part of the front matter definition.
#   
#   MUST add an entry in conventions.md
#   
#   Normal Badges
#       <!-- md:flag metadata --> Metadata
# #

def badgeFlagMetadata( page: Page, files: Files ):
    icon        = "material-list-box-outline"
    href        = _resolve_path( f"{PAGE_CONVENTIONS}#metadata", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Metadata property')",
        type = "flag-metadata"
    )

# #
#   Badge › Flags › Dangerous
#   
#   This symbol denotes that the item or setting specified may be dangerous to change.
#   
#   MUST add an entry in conventions.md
#   
#   Normal Badges
#       <!-- md:flag dangerous --> Dangerous
# #

def badgeFlagDangerous( page: Page, files: Files ):
    icon    = "aetherx-axd-skull-crossbones"
    href    = _resolve_path( f"{PAGE_CONVENTIONS}#dangerous", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'This setting is dangerous to change')",
        type = "dangerous"
    )

# #
#   Badge › Flags › Required
#   
#   Specifies that a value is required.
#   
#   MUST add an entry in conventions.md
#   
#   Normal Badges
#       <!-- md:flag required --> Required 
# #

def badgeFlagRequired( page: Page, files: Files ):
    icon    = "material-alert"
    href    = _resolve_path( f"{PAGE_CONVENTIONS}#required", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Required value')",
        type = "flag-required"
    )

# #
#   Badge › Flags › Customization
#   
#   This symbol denotes that the item described is a customization which affects the overall look of the app.
#   
#   MUST add an entry in conventions.md
#   
#   Normal Badges
#       <!-- md:flag customization --> Customization
# #

def badgeFlagCustomization( page: Page, files: Files ):
    icon = "material-brush-variant"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#customization", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Customization')",
        type = "flag-customization"
    )

# #
#   Badge › Flags › Experimental
#   
#   This symbol denotes that the item described is Experimental
#   
#   MUST add an entry in conventions.md
#   
#   Normal Badges
#       <!-- md:flag experimental --> Experimental
# #

def badgeFlagExperimental( page: Page, files: Files ):
    icon = "material-flask-outline"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#experimental", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Experimental')",
        type = "flag-experimental"
    )

# #
#   Badge › Flags › Multiple Instances
#   
#   This symbol denotes that the plugin supports multiple instances, i.e, that it
#   can be used multiple times in the `plugins` setting
#   
#   MUST add an entry in conventions.md
#   
#   Normal Badges
#       <!-- md:flag multiple --> Multiple Instances
# #

def badgeFlagMultiInstances( page: Page, files: Files ):
    icon = "material-inbox-multiple"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#multiple-instances", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Multiple instances')",
        type = "flag-instance"
    )

# #
#   Badge › Flags › Setting
#   
#   This symbol denotes that the specified item is a customizable setting
#   
#   MUST add an entry in conventions.md
#   
#   Normal Badges
#       <!-- md:flag setting --> Setting
# #

def badgeFlagSetting( page: Page, files: Files ):
    icon = "material-cog"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#setting", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Configurable Setting')",
        type = "flag-setting"
    )

# #
#   Icon › New Control › Textbox
#   
#   Normal Badges
#       <!-- md:control textbox -->
# #

def newControlTextbox( page: Page, files: Files ):
    icon = "aetherx-axs-input-text"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#controls", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Type: Textbox')"
    )

# #
#   Icon › New Control › Toggle Switch
#   
#   Normal Badges
#       <!-- md:control toggle -->
#       <!-- md:control toggle_on --> `Enabled`
#       <!-- md:control toggle_off --> `Disabled`
# #

def newControlToggle( page: Page, files: Files ):
    icon = "aetherx-axs-toggle-large-on"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#controls", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Type: Toggle Switch')"
    )

def newControlToggleOn( page: Page, files: Files ):
    icon = "aetherx-axd-toggle-on"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#controls", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Toggle: Enabled')"
    )

def newControlToggleOff( page: Page, files: Files ):
    icon = "aetherx-axd-toggle-off"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#controls", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Toggle: Disabled')"
    )

# #
#   Icon › New Control › Dropdown
#   
#   Normal Badges
#       <!-- md:control dropdown -->
# #

def newControlDropdown( page: Page, files: Files ):
    icon = "aetherx-axs-square-caret-down"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#controls", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Type: Dropdown')"
    )

# #
#   Icon › New Control › Button
#   
#   Normal Badges
#       <!-- md:control button -->
# #

def newControlButton( page: Page, files: Files ):
    icon = "material-button-pointer"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#controls", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Type: Button')"
    )

# #
#   Icon › New Control › Slider
#   
#   Normal Badges
#       <!-- md:control slider -->
# #

def newControlSlider( page: Page, files: Files ):
    icon = "aetherx-axd-sliders-simple"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#controls", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Type: Slider')"
    )

# #
#   Icon › New Control › Color
#   
#   Normal Badges
#       <!-- md:control color #FFFFFF #121315 -->
# #

def newControlColor( text: str, page: Page, files: Files ):
    icon = "aetherx-axs-palette"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#controls", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeColorPalette(
        icon = f"[:{icon}:]({href} 'Type: Color Wheel')",
        type = text
    )

# #
#   Icon › New Control › Env Variable
#   
#   Normal Badges
#       <!-- md:control env -->
# #

def newControlEnvVar( page: Page, files: Files ):
    icon = "aetherx-axd-puzzle-piece"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#controls", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Type: Environment Variable')",
        type = "env"
    )

# #
#   Icon › New Control › Volume
#   
#   Normal Badges
#       <!-- md:control volume -->
# #

def newControlVolume( page: Page, files: Files ):
    icon = "aetherx-axd-volume"
    href = _resolve_path( f"{PAGE_CONVENTIONS}#controls", page, files )

    print(clr.MAGENTA + 'VERBOSE - ' + clr.WHITE + ' Running ' + clr.YELLOW + inspect.stack( )[ 0 ][ 3 ] + clr.WHITE + ' for page ' + clr.GREY + str(href) + clr.WHITE )

    return badgeCreate(
        icon = f"[:{icon}:]({href} 'Type: Mountable Volume')",
        type = "volume"
    )

# #
#   Badge › Create
# #

def badgeCreate( icon: str, text: str = "", type: str = "" ):
    classes = f"mdx-badge mdx-badge--{type}" if type else "mdx-badge"
    return "".join([
        f"<span class=\"{classes}\">",
        *([f"<span class=\"mdx-badge__icon\">{icon}</span>"] if icon else []),
        *([f"<span class=\"mdx-badge__text\">{text}</span>"] if text else []),
        f"</span>",
    ])