---
title: "Cheatsheet › Example Configs"
tags:
  - cheatsheet
  - configure
  - configs
  - resource
---

# Cheatsheet: Example Configs <!-- omit from toc -->

Two versions of the config file have been provided below. A **full version** which contains comments, and a **clean version** which contains no comments and only the config settings. 

You may copy the contents, and place it within your server under the path `/etc/csf/csf.conf`.

- [Full Version](#full-version)
- [Clean Version](#clean-version)

<br />

After you have set your config file to its desired values; you must restart the CSF service to apply the configurations. Open Terminal and run:

```shell
sudo csf -r
```

<br />

You can also restart both CSF and LFD services with `-ra, --restartall`

```shell
sudo csf -ra
```

<br />

---

<br />

## Full Version

This is a copy of the original CSF `/etc/csf/csf.conf` config file available from our :aetherx-axb-github: [repository](https://github.com/Aetherinox/csf-firewall). It contains all comments and is the version you receive when downloading the latest version of ConfigServer Firewall & Security.

```ini
--8<-- "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/example_configs/etc/csf/csf.conf"
```

<br />

---

<br />

## Clean Version

This is a copy of our **clean** version of the CSF `/etc/csf/csf.conf` config file available from our :aetherx-axb-github: [repository](https://github.com/Aetherinox/csf-firewall). It contains all of the settings available in our [full version](#full-version), but with all comments removed.

```ini
--8<-- "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/example_configs/etc/csf/csf.conf.clean"
```


<br />

---

<br />
