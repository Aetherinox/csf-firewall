---
title: "Configure: Basics"
tags:
  - configure
---

# Configure: Basics
After you have installed ConfigServer Firewall in the previous chapter; you can start configuring it to suit your server’s requirements. The main configuration file for CSF is located at `/etc/csf/csf.conf`. You can use your preferred text editor to modify the file, such as nano or vim:

```shell
sudo nano /etc/csf/csf.conf
```

<br />

The list below outlines just a few of the important settings that you can modify within ConfigServer Firewall.

!!! note annotate "Patcher Note"

    When you run the patcher `install.sh`; **TESTING MODE** will automatically
    be disabled after the script has successfully completed.

- `TESTING`: Set this value to 0 to disable testing mode and activate the firewall.
- `TCP_IN` and `TCP_OUT`: These settings define the allowed incoming and outgoing TCP ports, respectively. Add or remove ports as required, separated by commas.
- `UDP_IN` and `UDP_OUT`: These settings define the allowed incoming and outgoing UDP ports, respectively. Add or remove ports as required, separated by commas.
- `DENY_IP_LIMIT`: This setting defines the maximum number of IP addresses that can be listed in the /etc/csf/csf.deny file. Adjust this limit as needed.
- `CT_LIMIT`: This setting controls the number of connections from a single IP address that are allowed before the IP is temporarily blocked. Adjust this value according to your server’s requirements.

<br />

Make sure to review the configuration file and adjust the settings to suit your server’s needs. After making changes to the configuration file, save and exit the text editor.

After you have set your config file to its desired values; you must restart the CSF service to apply the configurations. Open Terminal and run:

```shell
sudo csf -r
```

You can also restart both CSF and LFD services with `-ra, --restartall`
```shell
sudo csf -ra
```

<br />

Two **csf.conf** configuration files have been provided as examples; a full version, and clean (uncommented) version, and can be viewed on the [csf.conf](./conf.md) page.

<br />

---

<br />
