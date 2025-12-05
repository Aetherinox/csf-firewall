---
title: Usage › Troubleshooting › WebUI
tags:
    - usage
    - configure
    - troubleshoot
    - webui
    - interface
status: new
---

# Troubleshooting › WebUI

This page outlines common errors or issues the end-user may come across in regards to the CSF web user interface.

<br />

## Browser: This Address Is Restricted

By default, CSF assigns its web interface to port `6666`. 

It is important to note that both Firefox and Chromium based browsers have blocked access to a number of ports internally, including port `6666`. This is done for security reasons, in order to prevent potential attacks and unsafe connections. Attempting to access the CSF web interface in your browser on the default port will result in the following errors:

| Browser | Error |
| --- | --- |
| :aetherx-axb-firefox: Firefox | This address is restricted. <br /> This address uses a network port which is normally used for purposes other than Web browsing. Firefox has canceled the request for your protection. |
| :aetherx-axb-chrome: Chromium | This site can’t be reached <br /> `ERR_UNSAFE_PORT` |

<br />
<br />

### Firefox

The following is a list of ports that have been blocked by :aetherx-axb-firefox: [Firefox](https://firefox.com/en-US). The entire source can be found [here](https://searchfox.org/firefox-main/source/netwerk/base/nsIOService.cpp#106).

```c++ linenums="1" hl_lines="77"
int16_t gBadPortList[] = {
    1,      // tcpmux
    7,      // echo
    9,      // discard
    11,     // systat
    13,     // daytime
    15,     // netstat
    17,     // qotd
    19,     // chargen
    20,     // ftp-data
    21,     // ftp
    22,     // ssh
    23,     // telnet
    25,     // smtp
    37,     // time
    42,     // name
    43,     // nicname
    53,     // domain
    69,     // tftp
    77,     // priv-rjs
    79,     // finger
    87,     // ttylink
    95,     // supdup
    101,    // hostriame
    102,    // iso-tsap
    103,    // gppitnp
    104,    // acr-nema
    109,    // pop2
    110,    // pop3
    111,    // sunrpc
    113,    // auth
    115,    // sftp
    117,    // uucp-path
    119,    // nntp
    123,    // ntp
    135,    // loc-srv / epmap
    137,    // netbios
    139,    // netbios
    143,    // imap2
    161,    // snmp
    179,    // bgp
    389,    // ldap
    427,    // afp (alternate)
    465,    // smtp (alternate)
    512,    // print / exec
    513,    // login
    514,    // shell
    515,    // printer
    526,    // tempo
    530,    // courier
    531,    // chat
    532,    // netnews
    540,    // uucp
    548,    // afp
    554,    // rtsp
    556,    // remotefs
    563,    // nntp+ssl
    587,    // smtp (outgoing)
    601,    // syslog-conn
    636,    // ldap+ssl
    989,    // ftps-data
    990,    // ftps
    993,    // imap+ssl
    995,    // pop3+ssl
    1719,   // h323gatestat
    1720,   // h323hostcall
    1723,   // pptp
    2049,   // nfs
    3659,   // apple-sasl
    4045,   // lockd
    4190,   // sieve
    5060,   // sip
    5061,   // sips
    6000,   // x11
    6566,   // sane-port
    6665,   // irc (alternate)
    6666,   // irc (alternate)
    6667,   // irc (default)
    6668,   // irc (alternate)
    6669,   // irc (alternate)
    6679,   // osaut
    6697,   // irc+tls
    10080,  // amanda
    0,      // Sentinel value: This MUST be zero
};
```

<br />

### Chromium

The following is a list of ports that have been blocked by :aetherx-axb-chrome: [Chromium](https://chrome.google.com). The entire source can be found [here](https://chromium.googlesource.com/chromium/src.git/+/refs/heads/master/net/base/port_util.cc).

```c++ linenums="1" hl_lines="81"
// The general list of blocked ports. Will be blocked unless a specific
// protocol overrides it. (Ex: ftp can use port 21)
// When adding a port to the list, consider also adding it to kAllowablePorts,
// below. See <https://fetch.spec.whatwg.org/#port-blocking>.
const int kRestrictedPorts[] = {
    0,      // Not in Fetch Spec.
    1,      // tcpmux
    7,      // echo
    9,      // discard
    11,     // systat
    13,     // daytime
    15,     // netstat
    17,     // qotd
    19,     // chargen
    20,     // ftp data
    21,     // ftp access
    22,     // ssh
    23,     // telnet
    25,     // smtp
    37,     // time
    42,     // name
    43,     // nicname
    53,     // domain
    69,     // tftp
    77,     // priv-rjs
    79,     // finger
    87,     // ttylink
    95,     // supdup
    101,    // hostriame
    102,    // iso-tsap
    103,    // gppitnp
    104,    // acr-nema
    109,    // pop2
    110,    // pop3
    111,    // sunrpc
    113,    // auth
    115,    // sftp
    117,    // uucp-path
    119,    // nntp
    123,    // NTP
    135,    // loc-srv /epmap
    137,    // netbios
    139,    // netbios
    143,    // imap2
    161,    // snmp
    179,    // BGP
    389,    // ldap
    427,    // SLP (Also used by Apple Filing Protocol)
    465,    // smtp+ssl
    512,    // print / exec
    513,    // login
    514,    // shell
    515,    // printer
    526,    // tempo
    530,    // courier
    531,    // chat
    532,    // netnews
    540,    // uucp
    548,    // AFP (Apple Filing Protocol)
    554,    // rtsp
    556,    // remotefs
    563,    // nntp+ssl
    587,    // smtp (rfc6409)
    601,    // syslog-conn (rfc3195)
    636,    // ldap+ssl
    989,    // ftps-data
    990,    // ftps
    993,    // ldap+ssl
    995,    // pop3+ssl
    1719,   // h323gatestat
    1720,   // h323hostcall
    1723,   // pptp
    2049,   // nfs
    3659,   // apple-sasl / PasswordServer
    4045,   // lockd
    5060,   // sip
    5061,   // sips
    6000,   // X11
    6566,   // sane-port
    6665,   // Alternate IRC [Apple addition]
    6666,   // Alternate IRC [Apple addition]
    6667,   // Standard IRC [Apple addition]
    6668,   // Alternate IRC [Apple addition]
    6669,   // Alternate IRC [Apple addition]
    6697,   // IRC + TLS
    10080,  // Amanda
};
```

<br />


### Solution

If you wish to keep CSF's web interface on the default port `6666`; you have a few options below to circumvent this block:

1. <!-- md:link "Change CSF Web Port" #change-csf-web-port same -->
2. <!-- md:link "Whitelist port in Firefox" #whitelist-port-in-firefox same -->
3. <!-- md:link "Whitelist port in Chromium" #whitelist-port-in-chromium same -->

<br />


#### Change CSF Web Port

If you decide to go with the route of changing the port assigned to the CSF web interface, you must open the CSF config file `/etc/csf/csf.conf` and modify the setting `UI_PORT`:

=== ":aetherx-axs-file-magnifying-glass: Find"

    ``` bash title="/etc/csf/csf.conf"
    UI_PORT = "6666"
    ```

=== ":aetherx-axs-file-pen: Change To"

    ``` bash title="/etc/csf/csf.conf"
    UI_PORT = "8750"
    ```

<br />

Once you have changed the port, be sure to give CSF's lfd and csf services a restart:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -ra
      ```

<br />
<br />

#### Whitelist Port In Firefox

The second option requires that you open your Firefox browser and add the default port `6666` to the browser's whitelist. 

1. Open Firefox
2. In the address bar, type `about:config`.
3. In the top bar labeled `Search perference name`, type `network.security.ports.banned.override`.
    You should see the setting appear, with options to the right, and a :aetherx-axs-plus: button.
4. Select the option `String`, and click the :aetherx-axs-plus: button.
    - [ ] Boolean
    - [ ] Number
    - [x] String
5. When the textbox changes, add your custom port `6666` and click the :aetherx-axs-check: button.
    - You can add multiple ports to the list as long as they are comma delimited: `6666,6667,...`

<figure markdown="span">
    ![Firefox › Whitelist Port](../../../assets/images/usage/troubleshooting/webui/firefox_01.gif){ width="700" }
    <figcaption>Firefox › Whitelist Port</figcaption>
</figure>

<br />
<br />

#### Whitelist Port In Chromium

Allowing restricted ports in Google Chrome requires you to take the original Chrome icon, create a shortcut, and modify the **target** parameter to include the port you wish to whitelist.

1. Right-click on the Chrome desktop icon / shortcut, and select **Properties** from the context menu.
2. In the Google Chrome **Properties** box, go to the **Shortcut** tab.
3. Add the following line at the end of the **Target** box:
    ``` shell
    --explicitly-allowed-ports=6666
    ```
    - To whitelist multiple ports; use a comma delimiter
    ``` shell
    --explicitly-allowed-ports=6666,6667
    ```
    - Your **target** should be something along the lines of:
    ``` shell
    "C:\Program Files\Google\Chrome\Application\chrome.exe" --explicitly-allowed-ports=6666
    ```
4. Click on **Apply** and then click on **OK**.

<figure markdown="span">
    ![Chrome › Whitelist Port](../../../assets/images/usage/troubleshooting/webui/chrome_01.png){ width="370" }
    <figcaption>Chrome › Whitelist Port</figcaption>
</figure>

<br />
<br />
