---
title: "Usage › Integration › AbuseIPDB"
tags:
    - 3rd-party
    - install
    - integration
    - abuseipdb
    - blocklist
---

# AbuseIPDB

This section explains how to integrate [AbuseIPDB]((https://abuseipdb.com))'s blocklist services into your copy of ConfigServer Security and Firewall.

<br />

## Useful Resources

The following are useful resources regarding this page.

<div class="grid cards" markdown>

-   :aetherx-axb-abuseipdb: &nbsp; __[AbuseIPDB: CSF Integration](https://abuseipdb.com/csf)__

    ---

    CSF Integration guide provided by AbuseIPDB.
    
-   :aetherx-axb-abuseipdb: &nbsp; __[AbuseIPDB: API Docs](https://docs.abuseipdb.com/#introduction)__

    ---

    Full API documentation for AbuseIPDB.

-   :aetherx-axb-abuseipdb: &nbsp; __[AbuseIPDB: Create API Key](https://abuseipdb.com/account/api)__

    ---

    Create an AbuseIPDB and generate an API key.

-   :aetherx-axs-block-brick-fire: &nbsp; __[CSF: Download & Install Guide](../../install/dependencies.md)__

    ---

    The starting point for our official installation guide to get CSF installed on
    your server.

</div>

<br />

---

<br />

## What is AbuseIPDB?

[AbuseIPDB](https://abuseipdb.com/) is a community-driven project focused on tracking and sharing information about IP addresses involved in abusive or malicious activity across the internet. The service allows individuals to report IPs associated with behaviors such as brute-force attacks, spam, port scanning, DDoS attempts, and other forms of network abuse. Each report includes contextual details like the abuse category, a brief description explaining the cause for the report, and the time it was observed.

The platform aggregates reports from thousands of contributors worldwide and analyzes them to generate an **abuse confidence score** for each IP address. This score is calculated based on factors such as how frequently an IP is reported, the severity of the reported activity, and how recent the reports are. AbuseIPDB also maintains historical data, allowing users to see patterns over time and understand what types of abuse an IP has been associated with.

AbuseIPDB offers both a free tier and several [paid plans](https://abuseipdb.com/pricing) with expanded capabilities. The free plan includes:
- **1,000** IP checks and reports per day
- **100** bulk blocklist checks per day
- Access to a basic blacklist of up to **10,000 IPs**

Users can interact with AbuseIPDB through its web interface for manual lookups, or integrate it directly into scripts, firewalls (including CSF), and security tools using the official [API](https://docs.abuseipdb.com/#introduction). This flexibility makes it valuable for individual server operators as well as large-scale infrastructure and security teams.

<br />

---

<br />

## Before You Begin

Before integrating AbuseIPDB with CSF, make sure that **ConfigServer Security & Firewall (CSF)** is already installed and working correctly on your server.

If CSF is not yet installed, begin with the [Installation](../../install/dependencies.md) guide. That section walks you through installing the required dependencies, downloading CSF, and completing the initial setup so your system is ready for AbuseIPDB integration.

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axd-earth-europe: &nbsp; __[Geographical IP Block Integration](../usage/geoip.md)__

    ---

    Geographical IP blocking allows you to control access to your server based on
    the country or region an IP address originates from, rather than individual
    IP reputation or blocklist entries.

    This section explains what geographical IP blocks are, how they differ from
    blocklists and IPSETs, and when it makes sense to use country-based filtering.

    You’ll also learn how to integrate CSF with GeoIP data providers to apply
    regional access rules safely and efficiently.

</div>

<br />
<br />