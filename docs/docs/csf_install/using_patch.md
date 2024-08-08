---
title: Install CSF > Using Patch
tags:
  - install
---

# Install CSF: Manually

If you would like to install ConfigServer Firewall using this repo's patcher; download the patch:
```shell
git clone https://github.com/Aetherinox/csf-firewall.git
```

<br />

Set the permissions for the `install.sh` file:
```shell
sudo chmod +x /csf-firewall/patch/install.sh
```

<br />

Run the script:
```shell
sudo ./csf-firewall/patch/install.sh
```

<br />

If ConfigServer Firewall is not already installed on your system; you should see:
```
  Installing package iptables
  Installing package ipset
  Installing package ConfigServer Firewall

  Docker patch will now start ...
```

<br />

---

<br />
