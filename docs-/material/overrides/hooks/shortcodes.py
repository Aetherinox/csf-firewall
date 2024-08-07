# Copyright (c) 2024 Aetherinox

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

from __future__ import annotations

import posixpath
import re

from mkdocs.config.defaults import MkDocsConfig
from mkdocs.structure.files import File, Files
from mkdocs.structure.pages import Page
from re import Match

# -----------------------------------------------------------------------------
# Hooks
# -----------------------------------------------------------------------------

# @todo
def on_page_markdown(
    markdown: str, *, page: Page, config: MkDocsConfig, files: Files
):

    # Replace callback
    def replace(match: Match):
        type, args = match.groups()
        args = args.strip()
        if type == "version":
            if args.startswith( "beta-" ):
                return version_beta(args, page, files)
            elif args.startswith( "stable-" ):
                return version_stable( args, page, files )
            else:
                return version( args, page, files )

        #elif type == "sponsors":     return _badge_for_sponsors(page, files)
        elif type == "color":           return flag(args, page, files)
        elif type == "control":         return control(args, page, files)
        elif type == "flag":            return flag(args, page, files)
        elif type == "option":          return option(args)
        elif type == "setting":         return setting(args)
        elif type == "feature":         return _badge_for_feature(args, page, files)
        elif type == "plugin":          return _badge_for_plugin(args, page, files)
        elif type == "extension":       return _badge_for_extension(args, page, files)
        elif type == "utility":         return _badge_for_utility(args, page, files)
        elif type == "example":         return _badge_for_example(args, page, files)
        elif type == "default":
            if   args == "none":        return _badge_for_default_none(page, files)
            elif args == "computed":    return _badge_for_default_computed(page, files)
            else:                       return _badge_for_default(args, page, files)

        # Otherwise, raise an error
        raise RuntimeError(f"Unknown shortcode: {type}")

    # Find and replace all external asset URLs in current page
    return re.sub(
        r"<!-- md:(\w+)(.*?) -->",
        replace, markdown, flags = re.I | re.M
    )

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

# Create a flag of a specific type
def flag(args: str, page: Page, files: Files):
    type, *_ = args.split(" ", 1)
    if   type == "experimental":    return _badge_for_experimental(page, files)
    elif type == "required":        return _badge_for_required(page, files)
    elif type == "customization":   return _badge_for_customization(page, files)
    elif type == "metadata":        return _badge_for_metadata(page, files)
    elif type == "multiple":        return _badge_for_multiple(page, files)
    raise RuntimeError(f"Unknown type: {type}")

# -----------------------------------------------------------------------------
# Control Type
# -----------------------------------------------------------------------------

# Create a flag of a specific type
def control( args: str, page: Page, files: Files ):
    type, *_ = args.split( " ", 2 )
    if   type == "toggle":      return icon_control_toggle( page, files )
    elif type == "toggle_on":   return icon_control_toggle_on( page, files )
    elif type == "toggle_off":  return icon_control_toggle_off( page, files )
    elif type == "textbox":     return icon_control_textbox( page, files )
    elif type == "dropdown":    return icon_control_dropdown( page, files )
    elif type == "button":      return icon_control_button( page, files )
    elif type == "slider":      return icon_control_slider( page, files )
    elif type == "color":       return icon_control_color( args, page, files )
    else: return icon_control_default( page, files )

    raise RuntimeError(f"Unknown type: {type}")

# Create a linkable option
def option(type: str):
    _, *_, name = re.split(r"[.:]", type)
    return f"[`{name}`](#+{type}){{ #+{type} }}\n\n"

# Create a linkable setting - @todo append them to the bottom of the page
def setting(type: str):
    _, *_, name = re.split(r"[.*]", type)
    return f"`{name}` {{ #{type} }}\n\n[{type}]: #{type}\n\n"

# -----------------------------------------------------------------------------

# Resolve path of file relative to given page - the posixpath always includes
# one additional level of `..` which we need to remove
def _resolve_path(path: str, page: Page, files: Files):
    path, anchor, *_ = f"{path}#".split("#")
    path = _resolve(files.get_file_from_path(path), page)
    return "#".join([path, anchor]) if anchor else path

# Resolve path of file relative to given page - the posixpath always includes
# one additional level of `..` which we need to remove
def _resolve(file: File, page: Page):
    path = posixpath.relpath(file.src_uri, page.file.src_uri)
    return posixpath.sep.join(path.split(posixpath.sep)[1:])

# -----------------------------------------------------------------------------

# Create badge
def _badge(icon: str, text: str = "", type: str = ""):
    classes = f"mdx-badge mdx-badge--{type}" if type else "mdx-badge"
    return "".join([
        f"<span class=\"{classes}\">",
        *([f"<span class=\"mdx-badge__icon\">{icon}</span>"] if icon else []),
        *([f"<span class=\"mdx-badge__text\">{text}</span>"] if text else []),
        f"</span>",
    ])

def _badge_color(icon: str, text: str = "", type: str = ""):
    args = type.split( " " )

    bg1_clr = "#000000"
    bg2_clr = "#000000"
    bg1_dis = "none"
    bg2_dis = "none"
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

# Create sponsors badge
def _badge_for_sponsors(page: Page, files: Files):
    icon = "material-heart"
    href = _resolve_path("insiders/index.md", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Sponsors only')",
        type = "heart"
    )

# Create badge for version
def version( text: str, page: Page, files: Files ):
    spec = text
    path = f"changelog.md#{spec}"

    # Return badge
    icon = "aetherx-axs-box"
    href = _resolve_path("about/conventions.md#version", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Proteus Release')",
        text = f"[{text}]({_resolve_path(path, page, files)})" if spec else ""
    )

# Create badge for version of beta
def version_stable( text: str, page: Page, files: Files ):
    spec = text.replace( "stable-", "" )
    path = f"changelog.md#{spec}"

    # Return badge
    icon = "aetherx-axs-tag"
    href = _resolve_path( "about/conventions.md#version-beta", page, files )
    output  = ""

    # spec not empty
    if spec:
        output = f"Requires version {spec}"
    else:
        output = f"Stable Release"
    
    return _badge(
        icon = f"[:{icon}:]({href} '{output}' )",
        text = f"[{spec}]({_resolve_path(path, page, files)})" if spec else ""
    )

# Create badge for version of beta
def version_beta( text: str, page: Page, files: Files ):
    spec = text.replace( "beta-", "" )
    path = f"changelog.md#{spec}"

    # Return badge
    icon    = "aetherx-axs-b"
    href    = _resolve_path( "about/conventions.md#version-beta", page, files )
    output  = ""

    # spec not empty
    if spec:
        output = f"Requires version {spec}"
    else:
        output = f"Beta Release"

    return _badge(
        icon = f"[:{icon}:]({href} '{output}' )",
        text = f"[{text}]({_resolve_path(path, page, files)})" if spec else ""
    )

# Create badge for feature
def _badge_for_feature(text: str, page: Page, files: Files):
    icon = "material-toggle-switch"
    href = _resolve_path("about/conventions.md#feature", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Optional feature')",
        text = text
    )

# Create badge for plugin
def _badge_for_plugin(text: str, page: Page, files: Files):
    icon = "material-floppy"
    href = _resolve_path("about/conventions.md#plugin", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Plugin')",
        text = text
    )

# Create badge for extension
def _badge_for_extension(text: str, page: Page, files: Files):
    icon = "material-language-markdown"
    href = _resolve_path("about/conventions.md#extension", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Markdown extension')",
        text = text
    )

# Create badge for utility
def _badge_for_utility(text: str, page: Page, files: Files):
    icon = "material-package-variant"
    href = _resolve_path("about/conventions.md#utility", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Third-party utility')",
        text = text
    )

# Create badge for example
def _badge_for_example(text: str, page: Page, files: Files):
    return "\n".join([
        _badge_for_example_download(text, page, files),
        _badge_for_example_view(text, page, files)
    ])

# Create badge for example view
def _badge_for_example_view(text: str, page: Page, files: Files):
    icon = "material-folder-eye"
    href = f"https://mkdocs-material.github.io/examples/{text}/"
    return _badge(
        icon = f"[:{icon}:]({href} 'View example')",
        type = "right"
    )

# Create badge for example download
def _badge_for_example_download(text: str, page: Page, files: Files):
    icon = "material-folder-download"
    href = f"https://mkdocs-material.github.io/examples/{text}.zip"
    return _badge(
        icon = f"[:{icon}:]({href} 'Download example')",
        text = f"[`.zip`]({href})",
        type = "right"
    )

# Create badge for default value
def _badge_for_default(text: str, page: Page, files: Files):
    icon = "material-water"
    href = _resolve_path("about/conventions.md#default", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Default value')",
        text = text
    )

# Create badge for empty default value
def _badge_for_default_none(page: Page, files: Files):
    icon = "material-water-outline"
    href = _resolve_path("about/conventions.md#default", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Default value is empty')"
    )

# Create badge for computed default value
def _badge_for_default_computed(page: Page, files: Files):
    icon = "material-water-check"
    href = _resolve_path("about/conventions.md#default", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Default value is computed')"
    )

# Create badge for metadata property flag
def _badge_for_metadata(page: Page, files: Files):
    icon = "material-list-box-outline"
    href = _resolve_path("about/conventions.md#metadata", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Metadata property')"
    )

# Create badge for required value flag
def _badge_for_required(page: Page, files: Files):
    icon = "material-alert"
    href = _resolve_path("about/conventions.md#required", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Required value')"
    )

# Create badge for customization flag
def _badge_for_customization(page: Page, files: Files):
    icon = "material-brush-variant"
    href = _resolve_path("about/conventions.md#customization", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Customization')"
    )

# Create badge for experimental flag
def _badge_for_experimental(page: Page, files: Files):
    icon = "material-flask-outline"
    href = _resolve_path("about/conventions.md#experimental", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Experimental')"
    )

# Icon : Control : Textbox
def icon_control_default( page: Page, files: Files ):
    icon = "aetherx-axs-hand-pointer"
    href = _resolve_path( "about/conventions.md#control", page, files )
    return _badge(
        icon = f"[:{icon}:]({href} 'Type: Textbox')"
    )

# Icon : Control : Textbox
def icon_control_textbox( page: Page, files: Files ):
    icon = "aetherx-axs-input-text"
    href = _resolve_path( "about/conventions.md#control", page, files )
    return _badge(
        icon = f"[:{icon}:]({href} 'Type: Textbox')"
    )

# Icon : Control : Toggle Switch
def icon_control_toggle( page: Page, files: Files ):
    icon = "aetherx-axs-toggle-large-on"
    href = _resolve_path("about/conventions.md#control", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Type: Toggle Switch')"
    )

# Icon : Control : Toggle Switch > Enabled
def icon_control_toggle_on( page: Page, files: Files ):
    icon = "aetherx-axd-toggle-on"
    href = _resolve_path("about/conventions.md#control", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Toggle: Enabled')"
    )

# Icon : Control : Toggle Switch > Disabled
def icon_control_toggle_off( page: Page, files: Files ):
    icon = "aetherx-axd-toggle-off"
    href = _resolve_path("about/conventions.md#control", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Toggle: Disabled')"
    )

# Icon : Control : Dropdown
def icon_control_dropdown( page: Page, files: Files ):
    icon = "aetherx-axs-square-caret-down"
    href = _resolve_path("about/conventions.md#control", page, files)
    return _badge(
        icon = f"[:{icon}:]({href} 'Type: Dropdown')"
    )

# Icon : Control : Button
def icon_control_button( page: Page, files: Files ):
    icon = "material-button-pointer"
    href = _resolve_path( "about/conventions.md#control", page, files )
    return _badge(
        icon = f"[:{icon}:]({href} 'Type: Button')"
    )

# Icon : Control : Slider
def icon_control_slider( page: Page, files: Files ):
    icon = "aetherx-axd-sliders-simple"
    href = _resolve_path( "about/conventions.md#control", page, files )
    return _badge(
        icon = f"[:{icon}:]({href} 'Type: Slider')"
    )

# Icon : Control : Color
def icon_control_color( text: str, page: Page, files: Files ):
    icon = "aetherx-axs-palette"
    href = _resolve_path( "about/conventions.md#control", page, files )
    return _badge_color(
        icon = f"[:{icon}:]({href} 'Type: Color Wheel')",
        type = text
    )