---
title: Usage › Troubleshooting › Cyberpanel
tags:
    - usage
    - configure
    - troubleshoot
    - cyberpanel
---

# Troubleshooting › Cyberpanel

This page outlines common errors or issues the end-user may come across, and lists steps that can be taken to address the listed issues.

<br />

## Web Interface

These issues are related to users who are accessing CSF via the Cyberpanel integrated web interface.

<br />

### Data supplied is not accepted - forbidden characters

The following error may occur when accessing the CSF **Firewall Configuration** page and attempting to save any changes made to the application:

```
{"error_message": "Data supplied is not accepted, following characters are not allowed in the input ` $ & ( ) [ ] { } ; : 
  \u2018 < >.", "errorMessage": "Data supplied is not accepted, following characters are not allowed in the input 
  ` $ & ( ) [ ] { } ; : \u2018 < >."}
```

<br />

#### Problem

This error originates from CyberPanel's middleware file `/usr/local/CyberCP/CyberCP/secMiddleware.py`, approximately at line `219`.

```python
# Skip validation for API endpoints that need JSON structure characters
if not isAPIEndpoint and valueAlreadyChecked == 0:
      # Only check string values, skip lists and other types
      if (type(value) == str or type(value) == bytes) and (value.find('- -') > -1 or value.find('\n') > -1 or value.find(';') > -1 or value.find(
                  '&&') > -1 or value.find('|') > -1 or value.find('...') > -1 \
                  or value.find("`") > -1 or value.find("$") > -1 or value.find("(") > -1 or value.find(
            ")") > -1 \
                  or value.find("'") > -1 or value.find("[") > -1 or value.find("]") > -1 or value.find(
            "{") > -1 or value.find("}") > -1 \
                  or value.find(":") > -1 or value.find("<") > -1 or value.find(">") > -1 or value.find(
            "&") > -1):
```

<br />

This middleware validates input values submitted during a POST request when saving changes in the application.

Any input containing the colon ++colon++ character will trigger this error if you attempt to click the **Change** button at the bottom of the page to save your CSF settings.

Previously, this was not an issue. However, around August 2025, CyberPanel removed CSF integration support after the original CSF developer ceased operations. CyberPanel has not provided any updated exceptions within their code for our version of CSF, so this must be added manually.

<br />

#### Solution

To resolve this issue, you must run the installation script `src/install.sh` for CSF `v15.07` or newer, which applies the necessary fixes to allow you to save your CSF settings correctly.

The alternative to this is that all input fields within your settings must not contain a ++colon++, this includes the following settings:

- DROP_NOLOG
- PT_APACHESTATUS
- PS_PORTS
- UID_PORTS
- UI_CIPHER
- UI_SSL_VERSION
- DOCKER_NETWORK6

<br />
<br />
