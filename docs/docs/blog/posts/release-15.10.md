---
date: 2026-02-24
authors:
    - aetherinox
categories:
    - release
    - changelog
    - v15.x
    - cyberpanel
    - directadmin
    - webmin
    - vestacp
description: >
    Details regarding CSF release v15.10
title: >
    Release v15.10
comments: true
---

# Release: v15.10

The **v15.10** release includes a collection of minor bug fixes primarily focused on theme-related issues affecting both the revised original white theme and the new dark theme introduced in **v15.09**. 

One fix resolves an issue where the `CF_ENABLE` setting would continue to display the **Cloudflare Integration** buttons in the web interface even when the value was set to `0`. A similar issue was identified and corrected with the statistics buttons, which were appearing regardless of their corresponding configuration setting. 

Additionally, several stylesheet refinements were made to correct text positioning in the home navigation menu buttons, along with fixes for a small number of `<div>` elements that had incorrect CSS classes applied.

This release also introduces support for preserving **custom comments** in your `/etc/csf/csf.conf` file across updates. In previous versions, CSF compared your existing configuration against the default configuration shipped with each release, adding any missing settings as needed. This process resulted in the removal of any existing custom comments. With this update, custom comments are now retained, ensuring your configuration remains fully intact between upgrades.

Finally, a small bug was fixed regarding `Messenger v1` related to reCAPTCHA tokens being truncated depending on the length of bytes. The limit has been increased to `4096 bytes`, which provides approximately 4053 bytes for the token after accounting for the 43 bytes of URL overhead, comfortably accommodating current reCAPTCHA token sizes.

<!-- more -->

<br />

---

<br />

## Changelog

A list of the most important changes are outlined below.

<br />

### Dark Theme

Version `15.09` introduced the **dark theme** to CSF. This release focuses on correcting a number of styling issues
found across several control panels, with the majority affecting cPanel. These changes improve consistency, clarity, 
and overall visual refinement of the dark theme for all users. 

The light theme will continue to be updated if any styling bugs become known, but it will not receive additional major changes, as the 
intention is to preserve the white theme as closely as possible to the original. This means avoiding significant layout or visual
changes to the existing interface.

If a new theme is introduced in the future using the updated template system, the original theme will remain within CSf, which allows 
you to access what you're used to.

<br />

<figure markdown="span">
    ![cPanel › CSS › Bug](../../assets/images/blog/release-1510/cpanel-dark-css-row-01.png){ width="300" }
    ![cPanel › CSS › Fix](../../assets/images/blog/release-1510/cpanel-dark-css-row-02.png){ width="300" }
    <figcaption>cPanel › Dark Theme › Bug</figcaption>
</figure>

<br />
<br />

### Truncated reCAPTCHA

A bug was fixed regarding the `Messenger` module, which caused reCAPTCHA tokens to become truncated depending on the length of bytes. 

When a user submits a reCAPTCHA challenge, the token is passed as a query parameter in the HTTP request line (e.g., 
`GET /unblk?g-recaptcha-response=<token> HTTP/1.1`). The Messenger service previously imposed a **2048-byte** limit when reading this 
request line, which was sufficient when the code was originally written, as reCAPTCHA v2 tokens were typically around 600-1000 bytes.

However, Google has since increased token sizes, particularly with reCAPTCHA v3. This increase means that tokens can range from 1000 to 
4000+ bytes. When the full request line exceeded 2048 bytes, the token was silently truncated, causing Google's verification endpoint to 
reject it and leaving users unable to complete the process.

The limit has been increased to `4096 bytes`, which provides approximately 4053 bytes for the token after accounting for the 43 bytes of 
URL overhead, comfortably accommodating current reCAPTCHA token sizes. 

Currently, [RFC 7230, Sec 3.1.1](https://datatracker.ietf.org/doc/html/rfc7230#autoid-17) recommends that all HTTP senders and recipients 
support request-line lengths of at least 8000 octets; however, this is a recommendation, not a hard requirement.

Since the Messenger module is not a general purpose HTTP server and only handles a small list of endpoints, we opted for 4096, which is 
enough to comfortably fit current reCAPTCHA token sizes, and ensuring that we keep a tight limit to prevent potential abuse from excessively 
long requests.

<br />
<br />

### Persistent Config Comments

This release also introduces support for preserving **custom comments** in your `/etc/csf/csf.conf` file across updates. 

In previous versions, CSF compared your existing configuration against the default configuration shipped with each release, adding any 
missing settings as needed. This process resulted in the removal of any existing custom user comments.

With this update, custom comments are now retained, ensuring your configuration remains fully intact between upgrades. When writing custom 
comments in your `csf.conf`, you now have two options:

| Character     | Type              | Note                                                  |
| ------------- | ----------------- | ----------------------------------------------------- |
| `#`           | Generic Comment   | Must be placed **above** a setting, not below         |
| `##`          | Sticky Comment    | Can be placed anywhere                                |

<br />

#### Generic Comment

To place a **generic comment** in your `csf.conf`, simply prefix the comment with a single `#` character. All comments must be **above** the 
setting you are wanting to comment. 

When you update your copy of CSF, the comment will remain **above** the setting where it was placed. 

=== ":aetherx-axs-file: Before Update"

    ```ini title="/etc/csf/csf.conf" hl_lines="1"
    # This is a comment above TESTING    
    TESTING = "1"

    # #
    #   Defines how often the cron job runs, in minutes. This timing is based on the
    #   system clock, not when you manually start the firewall.
    # #

    TESTING_INTERVAL = "5"
    ```

=== ":aetherx-axs-file: After Update"

    ```ini title="/etc/csf/csf.conf" hl_lines="1"
    # This is a comment above TESTING
    TESTING = "1"

    # #
    #   Defines how often the cron job runs, in minutes. This timing is based on the
    #   system clock, not when you manually start the firewall.
    # #

    TESTING_INTERVAL = "5"
    ```

<br />

However, if you add a generic comment **below** a setting, the generic comment will be re-positioned in the updated config file 
**above thenext** setting in the file.

=== ":aetherx-axs-file: Before Update"

    ```ini title="/etc/csf/csf.conf" hl_lines="2"
    TESTING = "1"
    # This is a comment below TESTING

    # #
    #   Defines how often the cron job runs, in minutes. This timing is based on the
    #   system clock, not when you manually start the firewall.
    # #

    TESTING_INTERVAL = "5"
    ```

=== ":aetherx-axs-file: After Update"

    ```ini title="/etc/csf/csf.conf" hl_lines="8"
    TESTING = "1"

    # #
    #   Defines how often the cron job runs, in minutes. This timing is based on the
    #   system clock, not when you manually start the firewall.
    # #

    # This is a comment below TESTING
    TESTING_INTERVAL = "5"
    ```

<br />
<br />

#### Sticky Comment

To place a **sticky comment** in your `csf.conf`, simply prefix the comment with a single `##` character. A sticky comment can be
placed anywhere in the config, and it will remain in that position when updating CSF.

=== ":aetherx-axs-file: Before Update"

    ```ini title="/etc/csf/csf.conf" hl_lines="1 3"
    ## This is a sticky comment above TESTING; it will remain above TESTING.
    TESTING = "1"
    ## This is a sticky comment below TESTING; it will remain below TESTING.

    # #
    #   Defines how often the cron job runs, in minutes. This timing is based on the
    #   system clock, not when you manually start the firewall.
    # #

    TESTING_INTERVAL = "5"
    ```

=== ":aetherx-axs-file: After Update"

    ```ini title="/etc/csf/csf.conf" hl_lines="1 3"
    ## This is a sticky comment above TESTING; it will remain above TESTING.
    TESTING = "1"
    ## This is a sticky comment below TESTING; it will remain below TESTING.

    # #
    #   Defines how often the cron job runs, in minutes. This timing is based on the
    #   system clock, not when you manually start the firewall.
    # #

    TESTING_INTERVAL = "5"
    ```

<br />
<br />

### Real-time Blackhole List (RBL)

This update introduces a redesigned **Real-time Blackhole List (RBL)** interface, along with improvements to the core functionality.  
Hosts can now be retried multiple times before returning a timeout or error, and **Verbose** mode provides more detailed status
information for each host that is tested.

**What is an RBL?**  
A Real-time Blackhole List is a DNS-based blacklist of IP addresses known or suspected to engage in malicious activity, such as spam,
brute-force attacks, port scanning, or botnet behavior. CSF uses RBLs to proactively block or flag suspicious IPs, helping protect
your server from unwanted or harmful traffic.

<figure markdown="span">
    ![CSF › RBL Check](../../assets/images/blog/release-1510/rblcheck_01.png){ width="700" }
    <figcaption>CSF › RBL Check</figcaption>
</figure>

<br />
<br />

### New Mattermost Server (Discord Changes & Community Options)

Recently, **[Discord](https://discord.configserver.dev)** announced plans to introduce **age verification** in partnership with the company **Persona**. Under this system, users may be required to submit government issued identification or other sensitive personal documents. Accounts that do not complete verification could face restrictions or limited functionality. (_This is for Discord, not CSF_)

This announcement raises many concerns; particularly around how sensitive identification data would be stored, protected, and handled, and the potential risk of data breaches. Understandably, many users are uncomfortable with being required to provide personal identification in order to continue using the Discord platform.

Following significant community backlash, Discord has since **delayed** the rollout of age verification. However, the possibility remains that similar requirements could be implemented in the future.

Given this uncertainty with Discord, and the expectation that users may be asked to trust a third-party verification provider with highly sensitive data, we felt it was important to provide an alternative communication platform that does not impose these requirements.

As a result, we have launched a **[Mattermost](https://mm.configserver.dev)** server. **We will continue to operate our Discord server as usual**, but Mattermost is now available as an additional option for those who prefer it.

Our goal is to keep the community connected regardless of which platform you prefer, while also providing options for those who wish to avoid Discord's mandatory identity verification.

<br />

#### What Is Mattermost

Mattermost is a team communication platform that is similar to Discord in many ways. It supports real-time chat, channels, direct messaging, and file sharing, making it an easy transition for users who are already familiar with Discord’s style of communication. Mattermost is however, **open-source**.

<br />

#### How It Works

To ensure that no one is forced to choose between Discord or Mattermost, we have implemented a **Mattermost ↔ Discord bridge**. This bridge allows users on both platforms to communicate with one another. Messages sent on Mattermost appear in Discord, and messages sent on Discord appear in Mattermost.

We have also integrated our Github commit services on Mattermost as well, so you will get most of the same information as you do on Discord.

You may choose to stay on **Discord**, **Mattermost**, or use both; whatever works best for you.

<br />

#### Other Platforms

We are toying with the idea of also integrating services such as Fluxer. However, we want to ensure they are integrated properly, with bridges to link all of the services together.

<br />

#### Getting Started
- **Join the Mattermost server:** https://mm.configserver.dev  
- **Download the Mattermost desktop application:** https://mattermost.com/apps/

Mattermost also offers a **web client** for those who do not wish to install the Mattermost desktop app. You can access the web client using the [mm.configserver.dev](https://mm.configserver.dev/) link.

<br />

---

<br />

## Full Changelog

The full changelog is available [here](../../about/changelog.md).

<br />
<br />