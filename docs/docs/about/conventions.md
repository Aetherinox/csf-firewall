# Conventions

This documentation use some symbols for illustration purposes. Before you read on, please make sure you've made yourself familiar with the following list of conventions on this page, as they are used quite frequently.

<br />

## General Badges

The badges in this section are for general use.

<br />

### <!-- md:flag -->  Flags { #flags data-toc-label="Flags" }

=== "Description"

    These icons denote / mark a particular item with a specific category type. Use these to indicate that a feature or service is `experimental`, 
    `dangerous`, `setting`, or `required`.

    `Examples`

    :   <!-- md:flag --> Default  `<!-- @md:flag -->`
    :   <!-- md:flag experimental --> Experimental  `<!-- @md:flag experimental -->`
    :   <!-- md:flag required --> Required  `<!-- @md:flag required -->`
    :   <!-- md:flag customization --> Customization  `<!-- @md:flag customization -->`
    :   <!-- md:flag metadata --> Metadata  `<!-- @md:flag metadata -->`
    :   <!-- md:flag dangerous --> Dangerous  `<!-- @md:flag dangerous -->`
    :   <!-- md:flag multiple --> Multiple  `<!-- @md:flag multiple -->`
    :   <!-- md:flag setting --> Setting  `<!-- @md:flag setting -->`



<br />



### <!-- md:control --> Controls { #controls data-toc-label="Controls" }

=== "Description"

    These icons deonote what type of control a specified setting uses if the settings are controlled by a graphical user interface.

    `Examples`

    :   <!-- md:control --> default  `<!-- @md:control -->`
    :   <!-- md:control toggle --> toggle  `<!-- @md:control toggle -->`
    :   <!-- md:control toggle_on --> toggle on  `<!-- @md:control toggle_on -->`
    :   <!-- md:control toggle_off --> toggle off  `<!-- @md:control toggle_off -->`
    :   <!-- md:control textbox --> textbox  `<!-- @md:control textbox -->`
    :   <!-- md:control dropdown --> dropdown  `<!-- @md:control dropdown -->`
    :   <!-- md:control button --> button  `<!-- @md:control button -->`
    :   <!-- md:control slider --> slider  `<!-- @md:control slider -->`
    :   <!-- md:control volume --> docker volume  `<!-- @md:control volume -->`
    :   <!-- md:control env --> env variable  `<!-- @md:control env -->`
    :   <!-- md:control color #FFFFFF #121315 -->  `<!-- @md:control color #FFFFFF #121315 -->`

<br />

### <!-- md:version --> Release Type { #release-types data-toc-label="Release Types" }

=== "Description"

    The tag symbol in conjunction with a version number denotes when a specific feature or functionality was added. Make sure 
    you're at least on this version if you want to use the specified feature or functionality.

    `Examples`

    :   <!-- md:version --> default  `<!-- @md:version -->`
    :   <!-- md:version stable- --> stable  `<!-- @md:version stable -->`
    :   <!-- md:version development- --> development  `<!-- @md:version development -->`
    :   <!-- md:version 1.6.1 -->  `<!-- @md:version 1.6.1 -->`
    :   <!-- md:version stable-1.6.1 -->  `<!-- @md:version stable-1.6.1 -->`
    :   <!-- md:version development-1.6.1 -->  `<!-- @md:version development-1.6.1 -->`



<br />


### <!-- md:default -->  Default Value { #default data-toc-label="Default Values" }

=== "Description"

    Denotes what the default value is for a particular setting. If you ever change a setting and wish to revert back to the
    default value; this is the value you should use.

    `Examples`

    :   <!-- md:default --> Specified setting has a default value  `<!-- @md:default -->`
    :   <!-- md:default none --> Specified setting has no default value and is empty  `<!-- @md:default none -->`
    :   <!-- md:default computed --> Specified setting is automatically computed by the app  `<!-- @md:default computed -->`
    :   <!-- md:default `false` --> Default value is false  `<!-- @md:default false -->`



<br />



### <!-- md:command -->  Command { #command data-toc-label="Commands" }

=== "Description"

    Denotes that this item is a command which can be executed via a terminal, command prompt or some other console.

    `Examples`

    :   <!-- md:command --> Specified setting has a default value  `<!-- @md:command -->`
    :   <!-- md:command `-s,  --start` --> Specified setting has a default value  `<!-- @md:command -s, --start -->`



<br />



### <!-- md:3rdparty -->  3rd Party { #3rdparty data-toc-label="3rd Party" }

=== "Description"

    Denotes that this item is provided by a 3rd party service or app which is not directly associated with this application.

    `Examples`

    :   <!-- md:3rdparty -->  `<!-- @md:3rdparty -->`
    :   <!-- md:3rdparty mike -->  `<!-- @md:3rdparty mike -->`



<br />



### <!-- md:docs -->  Documentation { #docs data-toc-label="View Documentation" }

=== "Description"

    Denotes that this item has additional documentation which the user can click the icon for and be taken to another site / page

    `Examples`

    :   <!-- md:docs -->  `<!-- @md:docs -->`
    :   <!-- md:docs ../advanced/services/blocklist.configserver/ self --> `<!-- @md:docs ../advanced/services/blocklist.configserver/ self -->`
    :   <!-- md:docs ../advanced/services/blocklist.configserver/ self --> `<!-- @md:docs ../advanced/services/blocklist.configserver/ new -->`

<br />




### <!-- md:plugin -->  Plugin { #plugin data-toc-label="Plugins" }

=== "Description"

    Denotes that this item requires a specific plugin in order to function.

    `Examples`

    :   <!-- md:plugin -->  `<!-- @md:plugin -->`
    :   <!-- md:plugin name -->  `<!-- @md:plugin name -->`
    :   <!-- md:plugin [typeset] – built-in --> With Details  `<!-- @md:plugin [typeset] – built-in -->`



<br />
<br />



### <!-- md:feature -->  Feature { #feature data-toc-label="Features" }

=== "Description"

    Denotes a feature available within the app.

    `Examples`

    :   <!-- md:feature -->  `<!-- @md:feature -->`
    :   <!-- md:feature name -->  `<!-- @md:feature name -->`



<br />
<br />


### <!-- md:requires -->  Requires File { #requires data-toc-label="Requires" }

=== "Description"

    Denotes that a particular feature or functionality looks for, or requires a specific file on your system.

    `Examples`

    :   <!-- md:requires -->  `<!-- @md:requires -->`
    :   <!-- md:requires /etc/csf/csf.conf -->  `<!-- @md:requires /etc/csf/csf.conf -->`



<br />
<br />



### <!-- md:source -->  Source File { #source data-toc-label="Source" }

=== "Description"

    Denotes a feature's source file location. This explains what file the feature or setting can be found in.

    `Examples`

    :   <!-- md:source -->  `<!-- @md:source -->`
    :   <!-- md:source /etc/csf/csf.conf -->  `<!-- @md:source /etc/csf/csf.conf -->`



<br />
<br />



### <!-- md:flag setting -->  Configurable Settings { #setting data-toc-label="Configurable Setting" }

=== "Description"

    Denotes that this item is a configurable setting. Using this requires that you place it within a heading, typically `h4`

    `Examples`

    :   #### <!-- md:setting config.archive -->

=== "Usage"

    ```markdown
    #### <!-- @md:setting config.archive -->
    ```



<br />
<br />



### <!-- md:argument -->  Command Argument { #setting data-toc-label="Command Argument" }

=== "Description"

    This symbol denotes that the thing described is a command argument.

    `Examples`

    :   <!-- md:argument -->  `<!-- @md:argument -->`
    :   <!-- md:argument [admonition][Admonition] -->  `<!-- @md:argument [admonition][Admonition] -->`

    [Admonition]: https://python-markdown.github.io/extensions/admonition/

=== "Usage"

    ```markdown
    :   <!-- @md:argument [admonition][Admonition] -->

    [Admonition]: https://python-markdown.github.io/extensions/admonition/
    ```



<br />


### <!-- md:markdown -->  Markdown Extension { #markdown-extension data-toc-label="Markdown Extension" }

=== "Description"

    This symbol denotes that the thing described is a Markdown element. When adding links, ensure you create a reference-style link

    `Examples`

    :   <!-- md:markdown -->  `<!-- @md:markdown -->`
    :   <!-- md:markdown [admonition][Admonition] -->  `<!-- @md:markdown [admonition][Admonition] -->`

    [Admonition]: https://python-markdown.github.io/extensions/admonition/

=== "Usage"

    ```markdown
    :   <!-- @md:markdown [admonition][Admonition] -->

    [Admonition]: https://python-markdown.github.io/extensions/admonition/
    ```


<br />
<br />



### <!-- md:fileViewDLExt -->  File Preview { #file-preview data-toc-label="File Preview" }

=== "Description"

    Multiple badges exist which show buttons so that the user can **View** a file, **Download** a file, and also display an extension box which shows
    the file extension itself.

    <br />

    #### fileViewDLExt

        1. View file button
        2. Download file button
        3. Box with extension of file

    :   <!-- md:fileViewDLExt --> Icon Only `<!-- @md:fileViewDLExt -->`
    :   <!-- md:fileViewDLExt test.zip https://example.com/test.zip left --> Left Aligned `<!-- @md:fileViewDLExt test.zip https://github.com/.com/test.zip left -->`
    :   <!-- md:fileViewDLExt test.zip https://example.com/test.zip Right --> Right Aligned `<!-- @md:fileViewDLExt test.zip https://example.com/test.zip Right -->`
    :   <!-- md:fileViewDLExt path/to/view path/to/download left --> View + Download Only (Left) `<!-- @md:fileViewDLExt path/to/view path/to/download -->`

    <br />

    #### fileDLExt

        1. Download file button
        2. Box with extension of file

    :   <!-- md:fileDLExt https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/example_configs/etc/csf/csf.conf --> Download + Ext
    :   <!-- md:fileDLExt https://example.com/files/sample.zip left --> Left Aligned `<!-- @md:fileDLExt https://example.com/files/sample.zip left -->`
    :   <!-- md:fileDLExt https://example.com/files/sample.zip right --> Right Aligned `<!-- @md:fileDLExt https://example.com/files/sample.zip right -->`

    <br />

    #### fileView

        1. View file button

    :   <!-- md:fileView https://example.com/file.txt left --> Left Aligned `<!-- @md:fileView https://example.com/file.txt left -->`
    :   <!-- md:fileView https://example.com/file.txt right --> Right Aligned `<!-- @md:fileView https://example.com/file.txt right -->`

<br />
<br />


### <!-- md:sponsor -->  Insiders Sponsor { #sponsor data-toc-label="Sponsor" }

=== "Description"

    The pumping heart symbol denotes a person who has been generous enough to support our development
    through donations.

    `Examples`

    :   <!-- md:sponsor --> Sponsor <!-- @md:sponsor --> 


<br />
<br />

<br />

---

<br />

## Options

Options are another form of setting which lists what the option does, and then examples of how it works.

<!-- md:option rss.enabled -->

:   <!-- md:default `true` --> This option specifies whether
    the plugin is enabled when building your project. If you want to speed up
    local builds, you can use an [environment variable][mkdocs.env]:

    ``` yaml
    plugins:
      - rss:
          enabled: !ENV [CI, false]
    ```

<!-- md:option rss.match_path -->

:   <!-- md:default `.*` --> This option specifies which
    pages should be included in the feed. For example, to only include blog
    posts in the feed, use the following regular expression:

    ``` yaml
    plugins:
      - rss:
          match_path: blog/posts/.*
    ```


<br />
<br />

---

<br />

## General Examples

These are just generic examples with no specific purpose. They demonstrate how badges can be used.

<br />

#### <!-- md:flag setting --> DEBUG_ENABLED 
<!-- md:version stable-2.0.0 --> <!-- md:default `false` --> <!-- md:flag required --> <!-- md:fileViewDLExt test.zip https://example.com/test.zip -->

This is an example setting.

=== "example.md"

    ```markdown
    #### <!-- @md:flag setting --> DEBUG_ENABLED 
    <!-- @md:version stable-2.0.0 --> <!-- @md:default `false` --> <!-- @md:flag required --> <!-- @md:fileViewDLExt test.zip -->

    This is an example setting.
    ```

<br />
<br />

---

<br />

## Icons

Some parts of this documentation may also display icons in one of two ways

1.  Using HTML
    ```
    <i class="axd ax-file axd-xs"></i> [View Raw Version](https://license.md/wp-content/uploads/2022/06/gpl-3.0.txt)
    ```
2.  Using Markdown
    ```
    :aetherx-axd-file:
    ```

<br />

---

<br />

## Emoji in Tooltips

You can display an emoji / icon search bar which can be called from a codeblock tooltip as shown below.

``` html
<span class="twemoji">
    <img src="/.icons/aetherx/axs/csf-logo-1.svg" alt="CSF Logo" width="32"> <!-- (1)! -->
</span>
```

1.  Enter a few keywords to find the perfect icon using our [icon search] and
    click on the shortcode to copy it to your clipboard:

    <div class="mdx-iconsearch" data-mdx-component="iconsearch">
        <input class="md-input md-input--stretch mdx-iconsearch__input" placeholder="Search icon" data-mdx-component="iconsearch-query" value="aetherx csf" />
        <div class="mdx-iconsearch-result" data-mdx-component="iconsearch-result" data-mdx-mode="file">
            <div class="mdx-iconsearch-result__meta"></div>
            <ol class="mdx-iconsearch-result__list"></ol>
        </div>
    </div>

<br />
<br />

---

<br />

## Icon Search

Use the following to search our database for a specific icon which is available through our documentation.

<div class="mdx-iconsearch" data-mdx-component="iconsearch">
    <input class="md-input md-input--stretch mdx-iconsearch__input" placeholder="Search the icon and emoji database" data-mdx-component="iconsearch-query"/>
    <div class="mdx-iconsearch-result" data-mdx-component="iconsearch-result">
        <div class="mdx-iconsearch-result__meta"></div>
        <ol class="mdx-iconsearch-result__list"></ol>
    </div>
</div>

<small>
    :octicons-light-bulb-16:
    **Tip:** Enter some keywords to find icons and emojis and click on the
    shortcode to copy it to your clipboard.
</small>


<br />
<br />

