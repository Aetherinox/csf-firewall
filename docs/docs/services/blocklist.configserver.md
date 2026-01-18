---
title: Advanced › Services › blocklist.configserver.dev
tags:
  - services
  - blocklist.configserver.dev
---

# blocklist.configserver.dev <!-- omit from toc -->

CSF's [blocklist.configserver.dev](https://blocklist.configserver.dev) provides short, stable URLs for CSF’s official blocklists and other repo-hosted IPSETs. Accessing a URL returns the raw ipset file (one IP or CIDR per line), making it easy to consume and implement with CSF's blocklist feature. A JSON API is also available for statistical data, showing counts and metadata, while by default the plain text lists are served for direct consumption by tools.

IPSET files are formatted one entry per line (IP or CIDR), fully compatible with CSF. Administrators can add the URLs to `/etc/csf/csf.blocklists` or `/etc/csf/csf.deny`, allowing CSF to automatically apply the entries as iptables rules or via IPSET. The raw format is also easy to script against, mirror, or integrate into firewall automation workflows.

The blocklists aggregate trusted sources, including high-confidence feeds like AbusiveIPDB top offenders, known brute-force ranges, port scanners, and botnets. While built for CSF, the lists can also be used with Fail2Ban, FireHOL, pfSense, Shorewall, and other compatible firewall tools.

Read the chapter [Blocklists](../usage/blocklists.md) for more information about this feature and service.

<br />

---

<br />

## About Blocklists

A blocklist is a collection of IP addresses or entire networks (CIDRs) that you don’t want accessing your server. When an IP on the blocklist attempts to connect, CSF blocks the request, helping to protect your system from unwanted or malicious traffic.

Blocklists are powerful because they let you deny connections from known bad actors automatically. This includes IPs flagged for brute-force attacks, spam, port scanning, or other suspicious activity. Instead of manually adding rules for each offender, CSF can apply a list of rules that you maintain or import from external sources.

Many blocklists are published and maintained by security organizations that track malicious activity worldwide. By subscribing to these maintained blocklists, you can keep your server automatically protected from known threats without the need for constant manual intervention.

<br />

---

<br />

## Usage  <!-- omit from toc -->

This section explains the different ways you can access and work with our blocklist service.  

<br />

### Get IPSET

By default, each blocklist is served as a plain text file containing IP addresses and CIDR ranges.  
All lists are available as `.ipset` files and can be retrieved directly over HTTP.  

For example, you can open the following URL in your browser or use `curl` to download the master blocklist:

<div class="grid cards" markdown>

-   :aetherx-axs-earth-americas: &nbsp; [__IPSET__ › https://blocklist.configserver.dev/master.ipset](https://blocklist.configserver.dev/master.ipset)

</div>

This file can then be imported into CSF, FireHOL, or any firewall, security tool, or monitoring system that supports ipsets.  

<br />

### Get JSON API  <!-- omit from toc -->

Beyond simple blocklist retrieval, the service also provides an API with a statistics endpoint.  
By appending the query parameter `?stats=true` to any `.ipset` file, the server will return metadata instead of the raw list.  

<div class="grid cards" markdown>

-   :aetherx-axs-earth-americas: &nbsp; [__IPSET__ › https://blocklist.configserver.dev/master.ipset?stats=true](https://blocklist.configserver.dev/master.ipset?stats=true)

</div>

The statistics response is provided in JSON format and includes details such as the list name, source, number of entries, size, and timestamps.  

Example response:

```json title="https://blocklist.configserver.dev/master.ipset"
{
  "name": "Master Blocklist",
  "id": "master_ipset",
  "filename": "master.ipset",
  "category": "Master",
  "uuid": "ae40fa01-270d-3a98-98eb-249207584724",
  "source": "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/master.ipset",
  "url": "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/blocklists/master.ipset",
  "subnets": 5387,
  "ips_single": 425310,
  "ips_total": 612962028,
  "client_ip": "127.0.0.1",
  "timestamp": "2025-09-27T15:36:37.954Z",
  "date": "09-27-2025 08:36:38",
  "took": "0m 02s",
  "took_ms": 2001
}
```

<br />

---

<br />

## Add Blocklists to CSF  <!-- omit from toc -->

To use our [blocklist.configserver.dev](https://blocklist.configserver.dev) service, select the lists you want to add to CSF from the [blocklists](#blocklists) section below.  

For example, you might add the lists `master.ipset` and `highrisk.ipset`.

Open your `/etc/csf/csf.blocklists` and add the following:

```
# #
#   @blocklist              Official CSF Blocklists
#   @details:               https://aetherinox.github.io/csf-firewall/usage/blocklists/#official-blocklists
#                           https://aetherinox.github.io/csf-firewall/advanced/services/blocklist.configserver
#   
#   The official CSF blocklists contain a large number of IPs which range from various 
#   different services, including AbuseIPDB (100% confidency).
#   
#   You can also use our blocklist service:
#       https://blocklist.configserver.dev/master.ipset
#       https://blocklist.configserver.dev/highrisk.ipset
#   
#   We offer many others, but these two are the primary ones.
#   
#   Requires you to edit /etc/csf/csf.conf setting:
#       LF_IPSET_MAXELEM = "4000000"
# #

CSF_MASTER   | 43200 | 0      | https://blocklist.configserver.dev/master.ipset
CSF_HIGHRISK | 43200 | 0      | https://blocklist.configserver.dev/highrisk.ipset
```

<br />

---

<br />

## Blocklists  <!-- omit from toc -->

The following lists outline the blocklists that are available to use with our blocklist service

<br />

### Risk Assessments

The lists in this README use `⚝` and `★` icons to indicate risk levels. More stars mean higher risk. Lists marked as **High** or **Critical** should be added to your CSF blocklist to secure your server. Lower-risk lists are optional and can be added at your discretion.

Our automated CI generates this risk assessment each day.

<br />

| Rating      | Risk            | Description                                      |
| ----------- | --------------- | ------------------------------------------------ |
| `⚝⚝⚝⚝⚝`   | No Risk         | IPs pose no real threat, but possibly suspected  |
| `★⚝⚝⚝⚝`   | Low Risk        | IPs pose minimal threat                          |
| `★★⚝⚝⚝`   | Moderate Risk   | IPs may cause issues; monitor carefully          |
| `★★★⚝⚝`   | Elevated Risk   | IPs are risky; consider blocking                 |
| `★★★★⚝`   | High Risk       | IPs are dangerous; likely to cause harm          |
| `★★★★★`   | Critical Risk   | IPs are highly dangerous; block immediately      |

<br />

### Main Lists

These are the primary IPSETs that most people will be interested in. They contain a large number of IP addresses that have been reported recently for abusive behavior. These statistics are gathered from multiple sources, such as [AbuseIPDB](https://abuseipdb.com/) and [IPThreat](https://ipthreat.net/). IPs on this list have a 100% confidence level, meaning you should encounter no false positives from any of the IPs included.  

IP addresses in these lists have been flagged for engaging in activities such as:

- SSH Bruteforcing
- Port Scanning
- DDoS Attacks
- IoT Targeting
- Phishing

<br />

For most users, the blocklists `master.ipset` and `highrisk.ipset` are all you need. They contain a massive collection of IP addresses, all with a 100% confidence level, meaning you should encounter none or minimal false positives.

| Set Name | Description | Risk | View |
| --- | --- | --- | --- |
| `master.ipset` | Abusive IP addresses which have been reported for port scanning and SSH brute-forcing. HIGHLY recommended. <br> <span class="text-sm-9">Includes [AbuseIPDB](https://www.abuseipdb.com/), [IPThreat](https://ipthreat.net/), [CinsScore](https://cinsscore.com), [GreensNow](https://blocklist.greensnow.co/greensnow.txt)</span> | ★★★★★ | [view](https://blocklist.configserver.dev/master.ipset) |
| `highrisk.ipset` | IPs with highest risk to your network and have a possibility that the activity which comes from them are going to be fraudulent. | ★★★★★ | [view](https://blocklist.configserver.dev/highrisk.ipset) |

<br />

### Privacy

These blocklists help you control which third-party services can access your server, allowing you to block bad actors or unwanted service providers.

<br />

| Set | Description | Risk | View |
| --- | --- | --- | --- |
| `privacy_general.ipset` | Servers which scan ports for data collection and research purposes. <br> <span class="text-sm-9">List includes [Censys](https://censys.io), [Shodan](https://shodan.io/), [Project25499](https://blogproject25499.wordpress.com/), [InternetArchive](https://archive.org/), [Cyber Resilience](https://cyberresilience.io), [Internet Measurement](https://internet-measurement.com), [probe.onyphe.net](https://onyphe.net), [Security Trails](https://securitytrails.com) | ★★★★⚝ | [view](https://blocklist.configserver.dev/privacy_general.ipset)</span> |
| `privacy_ahrefs.ipset` | Ahrefs SEO and services | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_ahrefs.ipset) |
| `privacy_amazon_aws.ipset` | Amazon AWS | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_amazon_aws.ipset) |
| `privacy_amazon_ec2.ipset` | Amazon EC2 | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_amazon_ec2.ipset) |
| `privacy_applebot.ipset` | Apple Bots | ★★★⚝⚝ | [view](https://blocklist.configserver.dev/privacy_applebot.ipset) |
| `privacy_bing.ipset` | Microsoft Bind and Bing Crawlers / Bots | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_bing.ipset) |
| `privacy_bunnycdn.ipset` | Bunny CDN | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_bunnycdn.ipset) |
| `privacy_cloudflarecdn.ipset` | Cloudflare CDN | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_cloudflarecdn.ipset) |
| `privacy_cloudfront.ipset` | Cloudfront DNS | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_cloudfront.ipset) |
| `privacy_duckduckgo.ipset` | DuckDuckGo Web Crawlers / Bots | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_duckduckgo.ipset) |
| `privacy_facebook.ipset` | Facebook Bots & Trackers | ★★★⚝⚝ | [view](https://blocklist.configserver.dev/privacy_facebook.ipset) |
| `privacy_fastly.ipset` | Fastly CDN | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_fastly.ipset) |
| `privacy_google.ipset` | Google Crawlers | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_google.ipset) |
| `privacy_pingdom.ipset` | Pingdom Monitoring Service | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_pingdom.ipset) |
| `privacy_rssapi.ipset` | RSS API Reader | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_rssapi.ipset) |
| `privacy_stripe_api.ipset` | Stripe Payment Gateway API | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_stripe_api.ipset) |
| `privacy_stripe_armada_gator.ipset` | Stripe Armada Gator | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_stripe_armada_gator.ipset) |
| `privacy_stripe_webhooks.ipset` | Stripe Webhook Service | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_stripe_webhooks.ipset) |
| `privacy_telegram.ipset` | Telegram Trackers and Crawlers | ★★★⚝⚝ | [view](https://blocklist.configserver.dev/privacy_telegram.ipset) |
| `privacy_uptimerobot.ipset` | Uptime Robot Monitoring Service | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_uptimerobot.ipset) |
| `privacy_webpagetest.ipset` | Webpage Test Services | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/privacy_webpagetest.ipset) |

<br />
<br />
<br />

### Spam

These blocklists help prevent known spam sources from accessing your server. They include IPs identified by services like Spamhaus as well as spammers targeting forums and other online platforms.

<br />

| Set | Description | Risk | View |
| --- | --- | --- | --- |
| `spam_forums.ipset` | List of known forum / blog spammers and bots | ★★★⚝⚝ | [view](https://blocklist.configserver.dev/spam_forums.ipset) |
| `spam_spamhaus.ipset` | Bad actor IP addresses registered with Spamhaus | ★★★★⚝ | [view](https://blocklist.configserver.dev/spam_spamhaus.ipset) |

<br />
<br />
<br />

### Internet Service Providers

These blocklists allow you to filter traffic based on Internet Service Providers (ISPs). They can be used to block or restrict access from specific networks or providers.

<br />

| Set | Description | Risk | View |
|----------|------------|------------|------------|
| `isp_aol.ipset` | AOL Internet Service Provider IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_aol.ipset) |
| `isp_att.ipset` | AT&T Internet Service Provider IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_att.ipset) |
| `isp_cablevision.ipset` | Cablevision / Optimum ISP IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_cablevision.ipset) |
| `isp_charter_spectrum_timewarnercable.ipset` | Charter/Spectrum/TWC ISP IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_charter_spectrum_timewarnercable.ipset) |
| `isp_comcast.ipset` | Comcast / Xfinity ISP IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_comcast.ipset) |
| `isp_cox_communications.ipset` | Cox Communications ISP IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_cox_communications.ipset) |
| `isp_embarq.ipset` | Embarq / CenturyLink ISP IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_embarq.ipset) |
| `isp_frontier_communications.ipset` | Frontier Communications ISP IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_frontier_communications.ipset) |
| `isp_qwest.ipset` | Qwest / CenturyLink ISP IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_qwest.ipset) |
| `isp_spacex_starlink.ipset` | SpaceX Starlink satellite ISP IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_spacex_starlink.ipset) |
| `isp_sprint.ipset` | Sprint ISP IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_sprint.ipset) |
| `isp_suddenlink_altice_optimum.ipset` | Suddenlink / Altice / Optimum ISP IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_suddenlink_altice_optimum.ipset) |
| `isp_verizon.ipset` | Verizon ISP IPs | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/isp_verizon.ipset) |

<br />
<br />
<br />

### Transmission (BitTorrent Client)

This section includes blocklists which you can import into the [bittorrent client Transmission](https://transmissionbt.com/).

<br />

- In this repo, copy the direct URL to the Transmission blocklist, provided below:
    - https://github.com/Aetherinox/csf-firewall/raw/main/blocklists/transmission/blocklist.gz
- Open your Transmission application; depending on the version you run, do ONE of the follow two choices:
    - Paste the link to **Transmission** › `Settings` › `Peers` › `Blocklist`
    - Paste the link to **Transmission** › `Edit` › `Preferences` › `Privacy` › `Enable Blocklist`

<br />

| Set | Description | Risk | View | Website |
| --- | --- | --- | --- | --- |
| `transmission.ipset` | A large blocklist for the BitTorrent client [Transmission](https://transmissionbt.com/) | ★★★★★ | [view](https://blocklist.configserver.dev/transmission.ipset) | [view](https://transmissionbt.com/) |

<br />
<br />
<br />

### Continents (GeoLite2)

These blocklists let you control which geographical locations can access your server. They can be used as either a whitelist or a blacklist and include both **continents** and **countries**.  

All data is sourced directly from the GeoLite2 Database.

<br />

| Set | Description | Risk | View |
|----------|------------|------------|------------|
| `continent_africa.ipset` | All IPs located in Africa | ★★★⚝⚝ | [view](https://blocklist.configserver.dev/continent_africa.ipset) |
| `continent_antartica.ipset` | All IPs located in Antarctica | ⚝⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/continent_antartica.ipset) |
| `continent_asia.ipset` | All IPs located in Asia | ★★★★⚝ | [view](https://blocklist.configserver.dev/continent_asia.ipset) |
| `continent_europe.ipset` | All IPs located in Europe | ★★★⚝⚝ | [view](https://blocklist.configserver.dev/continent_europe.ipset) |
| `continent_north_america.ipset` | All IPs located in North America | ★★★★⚝ | [view](https://blocklist.configserver.dev/continent_north_america.ipset) |
| `continent_oceania.ipset` | All IPs located in Oceania | ★⚝⚝⚝⚝ | [view](https://blocklist.configserver.dev/continent_oceania.ipset) |
| `continent_south_america.ipset` | All IPs located in South America | ★★⚝⚝⚝ | [view](https://blocklist.configserver.dev/continent_south_america.ipset) |

<br />
<br />
<br />

### Countries (GeoLite2)

These blocklists let you control which geographical locations can access your server. They can be used as either a whitelist or a blacklist and include both **continents** and **countries**.  

All data is sourced directly from the GeoLite2 Database.

<br />

| Set                                            | Description                              | Risk  | View                                                                                    |
| ---------------------------------------------- | ---------------------------------------- | --------- | ---------------------------------------------------------------------------------------- |
| `country_afghanistan.ipset`                    | Afghanistan               | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_afghanistan.ipset)                    |
| `country_aland_islands.ipset`                  | Aland Islands                     | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_aland_islands.ipset)                  |
| `country_albania.ipset`                        | Albania                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_albania.ipset)                        |
| `country_algeria.ipset`                        | Algeria                           | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_algeria.ipset)                        |
| `country_american_samoa.ipset`                 | American Samoa                    | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_american_samoa.ipset)                 |
| `country_andorra.ipset`                        | Andorra                           | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_andorra.ipset)                        |
| `country_angola.ipset`                         | Angola                            | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_angola.ipset)                         |
| `country_anguilla.ipset`                       | Anguilla                          | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_anguilla.ipset)                       |
| `country_antarctica.ipset`                     | Antarctica                        | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_antarctica.ipset)                     |
| `country_antigua_barbuda.ipset`                | Antigua and Barbuda               | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_antigua_barbuda.ipset)                |
| `country_argentina.ipset`                      | Argentina                         | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_argentina.ipset)                      |
| `country_armenia.ipset`                        | Armenia                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_armenia.ipset)                        |
| `country_aruba.ipset`                          | Aruba                             | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_aruba.ipset)                          |
| `country_australia.ipset`                      | Australia                         | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_australia.ipset)                      |
| `country_austria.ipset`                        | Austria                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_austria.ipset)                        |
| `country_azerbaijan.ipset`                     | Azerbaijan                        | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_azerbaijan.ipset)                     |
| `country_bahamas.ipset`                        | The Bahamas                       | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_bahamas.ipset)                        |
| `country_bahrain.ipset`                        | Bahrain                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_bahrain.ipset)                        |
| `country_bangladesh.ipset`                     | Bangladesh                        | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_bangladesh.ipset)                     |
| `country_barbados.ipset`                       | Barbados                          | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_barbados.ipset)                       |
| `country_belarus.ipset`                        | Belarus                           | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_belarus.ipset)                        |
| `country_belgium.ipset`                        | Belgium                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_belgium.ipset)                        |
| `country_belize.ipset`                         | Belize                            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_belize.ipset)                         |
| `country_benin.ipset`                          | Benin                             | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_benin.ipset)                          |
| `country_bermuda.ipset`                        | Bermuda                           | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_bermuda.ipset)                        |
| `country_bhutan.ipset`                         | Bhutan                            | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_bhutan.ipset)                         |
| `country_bolivia.ipset`                        | Bolivia                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_bolivia.ipset)                        |
| `country_bonaire_sint_eustatius_saba.ipset`    | Bonaire, Sint Eustatius, and Saba | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_bonaire_sint_eustatius_saba.ipset)    |
| `country_bosnia_herzegovina.ipset`             | Bosnia and Herzegovina            | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_bosnia_herzegovina.ipset)             |
| `country_botswana.ipset`                       | Botswana                          | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_botswana.ipset)                       |
| `country_bouvet_island.ipset`                  | Bouvet Island                     | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_bouvet_island.ipset)                  |
| `country_brazil.ipset`                         | Brazil                            | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_brazil.ipset)                         |
| `country_british_indian_ocean_territory.ipset` | British Indian Ocean Territory    | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_british_indian_ocean_territory.ipset) |
| `country_british_virgin_islands.ipset`         | British Virgin Islands            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_british_virgin_islands.ipset)         |
| `country_brunei_darussalam.ipset`              | Brunei                            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_brunei_darussalam.ipset)              |
| `country_bulgaria.ipset`                       | Bulgaria                          | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_bulgaria.ipset)                       |
| `country_burkina_faso.ipset`                   | Burkina Faso                      | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_burkina_faso.ipset)                   |
| `country_burundi.ipset`                        | Burundi                           | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_burundi.ipset)                        |
| `country_cambodia.ipset`                       | Cambodia                          | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_cambodia.ipset)                       |
| `country_cameroon.ipset`                       | Cameroon                          | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_cameroon.ipset)                       |
| `country_canada.ipset`                         | Canada                            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_canada.ipset)                         |
| `country_cape_verde.ipset`                     | Cape Verde                        | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_cape_verde.ipset)                     |
| `country_cayman_islands.ipset`                 | Cayman Islands                    | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_cayman_islands.ipset)                 |
| `country_cc.ipset`                             | Cocos (Keeling) Islands           | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_cc.ipset)                             |
| `country_central_african_republic.ipset`       | Central African Republic          | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_central_african_republic.ipset)       |
| `country_chad.ipset`                           | Chad                              | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_chad.ipset)                           |
| `country_chile.ipset`                          | Chile                             | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_chile.ipset)                          |
| `country_china.ipset`                          | China                             | ★★★★★    | [view](https://blocklist.configserver.dev/country_china.ipset)                          |
| `country_christmas_island.ipset`               | Christmas Island                  | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_christmas_island.ipset)               |
| `country_colombia.ipset`                       | Colombia                          | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_colombia.ipset)                       |
| `country_comoros.ipset`                        | Comoros                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_comoros.ipset)                        |
| `country_congo.ipset`                       | Congo                            | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_congo.ipset)                       |
| `country_cook_islands.ipset`                | Cook Islands                     | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_cook_islands.ipset)                |
| `country_costa_rica.ipset`                  | Costa Rica                       | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_costa_rica.ipset)                  |
| `country_cote_divoire.ipset`                | Côte d'Ivoire                    | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_cote_divoire.ipset)                |
| `country_croatia.ipset`                     | Croatia                          | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_croatia.ipset)                     |
| `country_cuba.ipset`                        | Cuba                             | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_cuba.ipset)                        |
| `country_curacao.ipset`                     | Curaçao                          | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_curacao.ipset)                     |
| `country_cyprus.ipset`                      | Cyprus                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_cyprus.ipset)                      |
| `country_czech_republic.ipset`              | Czech Republic                   | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_czech_republic.ipset)              |
| `country_democratic_republic_congo.ipset`   | Democratic Republic of the Congo | ★★★★★    | [view](https://blocklist.configserver.dev/country_democratic_republic_congo.ipset)   |
| `country_denmark.ipset`                     | Denmark                          | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_denmark.ipset)                     |
| `country_djibouti.ipset`                    | Djibouti                         | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_djibouti.ipset)                    |
| `country_dominica.ipset`                    | Dominica                         | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_dominica.ipset)                    |
| `country_dominican_republic.ipset`          | Dominican Republic               | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_dominican_republic.ipset)          |
| `country_ecuador.ipset`                     | Ecuador                          | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_ecuador.ipset)                     |
| `country_egypt.ipset`                       | Egypt                            | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_egypt.ipset)                       |
| `country_el_salvador.ipset`                 | El Salvador                      | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_el_salvador.ipset)                 |
| `country_equatorial_guinea.ipset`           | Equatorial Guinea                | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_equatorial_guinea.ipset)           |
| `country_eritrea.ipset`                     | Eritrea                          | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_eritrea.ipset)                     |
| `country_estonia.ipset`                     | Estonia                          | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_estonia.ipset)                     |
| `country_eswatini.ipset`                    | Eswatini                         | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_eswatini.ipset)                    |
| `country_ethiopia.ipset`                    | Ethiopia                         | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_ethiopia.ipset)                    |
| `country_europe.ipset`                      | Europe                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_europe.ipset)                      |
| `country_falkland_islands_malvinas.ipset`   | Falkland Islands (Malvinas)      | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_falkland_islands_malvinas.ipset)   |
| `country_faroe_islands.ipset`               | Faroe Islands                    | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_faroe_islands.ipset)               |
| `country_fiji.ipset`                        | Fiji                             | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_fiji.ipset)                        |
| `country_finland.ipset`                     | Finland                          | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_finland.ipset)                     |
| `country_france.ipset`                      | France                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_france.ipset)                      |
| `country_french_guiana.ipset`               | French Guiana                    | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_french_guiana.ipset)               |
| `country_french_polynesia.ipset`            | French Polynesia                 | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_french_polynesia.ipset)            |
| `country_french_southern_territories.ipset` | French Southern Territories      | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_french_southern_territories.ipset) |
| `country_gabon.ipset`                       | Gabon                             | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_gabon.ipset)                             |
| `country_gambia.ipset`                      | Gambia                            | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_gambia.ipset)                            |
| `country_georgia.ipset`                     | Georgia                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_georgia.ipset)                           |
| `country_germany.ipset`                     | Germany                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_germany.ipset)                           |
| `country_ghana.ipset`                       | Ghana                             | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_ghana.ipset)                             |
| `country_gibraltar.ipset`                   | Gibraltar                         | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_gibraltar.ipset)                         |
| `country_great_britain.ipset`               | Great Britain                     | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_great_britain.ipset)                     |
| `country_greece.ipset`                      | Greece                            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_greece.ipset)                            |
| `country_greenland.ipset`                   | Greenland                         | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_greenland.ipset)                         |
| `country_grenada.ipset`                     | Grenada                           | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_grenada.ipset)                           |
| `country_guadeloupe.ipset`                  | Guadeloupe                        | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_guadeloupe.ipset)                        |
| `country_guam.ipset`                        | Guam                              | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_guam.ipset)                              |
| `country_guatemala.ipset`                   | Guatemala                         | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_guatemala.ipset)                         |
| `country_guernsey.ipset`                    | Guernsey                          | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_guernsey.ipset)                          |
| `country_guineabissau.ipset`                | Guinea-Bissau                     | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_guineabissau.ipset)                      |
| `country_guinea.ipset`                      | Guinea                            | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_guinea.ipset)                            |
| `country_guyana.ipset`                      | Guyana                            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_guyana.ipset)                            |
| `country_haiti.ipset`                       | Haiti                             | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_haiti.ipset)                             |
| `country_heard_island_and_mcdonald_islands.ipset` | Heard Island and McDonald Islands | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_heard_island_and_mcdonald_islands.ipset) |
| `country_honduras.ipset`                    | Honduras                          | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_honduras.ipset)                          |
| `country_hong_kong.ipset`                   | Hong Kong                         | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_hong_kong.ipset)                         |
| `country_hungary.ipset`                     | Hungary                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_hungary.ipset)                           |
| `country_iceland.ipset`                     | Iceland                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_iceland.ipset)                           |
| `country_india.ipset`                       | India                             | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_india.ipset)                             |
| `country_indonesia.ipset`                   | Indonesia                         | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_indonesia.ipset)                         |
| `country_iran.ipset`                        | Iran                              | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_iran.ipset)                              |
| `country_iraq.ipset`                        | Iraq                              | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_iraq.ipset)                              |
| `country_ireland.ipset`                     | Ireland                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_ireland.ipset)                           |
| `country_isle_of_man.ipset`                 | Isle of Man                       | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_isle_of_man.ipset)                       |
| `country_israel.ipset`                      | Israel                            | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_israel.ipset)                            |
| `country_italy.ipset`                       | Italy                             | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_italy.ipset)                             |
| `country_jamaica.ipset`                     | Jamaica                           | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_jamaica.ipset)                           |
| `country_japan.ipset`                       | Japan                             | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_japan.ipset)                             |
| `country_jersey.ipset`                      | Jersey                            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_jersey.ipset)                            |
| `country_jordan.ipset`                      | Jordan                            | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_jordan.ipset)                            |
| `country_kazakhstan.ipset`                  | Kazakhstan                        | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_kazakhstan.ipset)                        |
| `country_kenya.ipset`                       | Kenya                             | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_kenya.ipset)                             |
| `country_kiribati.ipset`                    | Kiribati                          | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_kiribati.ipset)                          |
| `country_kosovo.ipset`                      | Kosovo                            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_kosovo.ipset)                            |
| `country_kuwait.ipset`                      | Kuwait                            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_kuwait.ipset)                            |
| `country_kyrgyzstan.ipset`                  | Kyrgyzstan                        | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_kyrgyzstan.ipset)                        |
| `country_laos.ipset`                        | Laos                              | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_laos.ipset)                              |
| `country_latvia.ipset`                      | Latvia                            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_latvia.ipset)                            |
| `country_lebanon.ipset`                     | Lebanon                           | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_lebanon.ipset)                           |
| `country_lesotho.ipset`                     | Lesotho                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_lesotho.ipset)                           |
| `country_liberia.ipset`                     | Liberia                           | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_liberia.ipset)                           |
| `country_libya.ipset`                       | Libya                             | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_libya.ipset)                             |
| `country_liechtenstein.ipset`               | Liechtenstein                     | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_liechtenstein.ipset)                     |
| `country_lithuania.ipset`                   | Lithuania                         | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_lithuania.ipset)                         |
| `country_luxembourg.ipset`                  | Luxembourg                        | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_luxembourg.ipset)                        |
| `country_macedonia_republic.ipset`          | Macedonia        | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_macedonia_republic.ipset) |
| `country_madagascar.ipset`                  | Madagascar       | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_madagascar.ipset)         |
| `country_malawi.ipset`                      | Malawi           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_malawi.ipset)             |
| `country_malaysia.ipset`                    | Malaysia         | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_malaysia.ipset)           |
| `country_maldives.ipset`                    | Maldives         | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_maldives.ipset)           |
| `country_mali.ipset`                        | Mali             | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_mali.ipset)               |
| `country_malta.ipset`                       | Malta            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_malta.ipset)              |
| `country_marshall_islands.ipset`            | Marshall Islands | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_marshall_islands.ipset)   |
| `country_martinique.ipset`                  | Martinique       | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_martinique.ipset)         |
| `country_mauritania.ipset`                  | Mauritania       | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_mauritania.ipset)         |
| `country_mauritius.ipset`                   | Mauritius        | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_mauritius.ipset)          |
| `country_mayotte.ipset`                     | Mayotte          | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_mayotte.ipset)            |
| `country_mexico.ipset`                      | Mexico           | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_mexico.ipset)             |
| `country_micronesia.ipset`                  | Micronesia       | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_micronesia.ipset)         |
| `country_monaco.ipset`                      | Monaco           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_monaco.ipset)             |
| `country_mongolia.ipset`                    | Mongolia         | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_mongolia.ipset)           |
| `country_montenegro.ipset`                  | Montenegro       | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_montenegro.ipset)         |
| `country_montserrat.ipset`                  | Montserrat       | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_montserrat.ipset)         |
| `country_morocco.ipset`                     | Morocco          | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_morocco.ipset)            |
| `country_mozambique.ipset`                  | Mozambique       | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_mozambique.ipset)         |
| `country_myanmar.ipset`                     | Myanmar          | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_myanmar.ipset)            |
| `country_namibia.ipset`                     | Namibia          | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_namibia.ipset)            |
| `country_nauru.ipset`                       | Nauru            | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_nauru.ipset)              |
| `country_nepal.ipset`                       | Nepal            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_nepal.ipset)              |
| `country_netherlands.ipset`                 | Netherlands      | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_netherlands.ipset)        |
| `country_new_caledonia.ipset`               | New Caledonia    | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_new_caledonia.ipset)      |
| `country_new_zealand.ipset`                 | New Zealand      | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_new_zealand.ipset)        |
| `country_nicaragua.ipset`                   | Nicaragua                | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_nicaragua.ipset)                |
| `country_nigeria.ipset`                     | Nigeria                  | ★★★★★    | [view](https://blocklist.configserver.dev/country_nigeria.ipset)                  |
| `country_niger.ipset`                       | Niger                    | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_niger.ipset)                    |
| `country_niue.ipset`                        | Niue                     | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_niue.ipset)                     |
| `country_norfolk_island.ipset`              | Norfolk Island           | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_norfolk_island.ipset)           |
| `country_northern_mariana_islands.ipset`    | Northern Mariana Islands | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_northern_mariana_islands.ipset) |
| `country_north_korea.ipset`                 | North Korea              | ★★★★★    | [view](https://blocklist.configserver.dev/country_north_korea.ipset)              |
| `country_norway.ipset`                      | Norway                   | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_norway.ipset)                   |
| `country_oman.ipset`                        | Oman                     | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_oman.ipset)                     |
| `country_pakistan.ipset`                    | Pakistan                 | ★★★★★    | [view](https://blocklist.configserver.dev/country_pakistan.ipset)                 |
| `country_palau.ipset`                       | Palau                    | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_palau.ipset)                    |
| `country_palestine.ipset`                   | Palestine                | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_palestine.ipset)                |
| `country_panama.ipset`                      | Panama                   | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_panama.ipset)                   |
| `country_papua_new_guinea.ipset`            | Papua New Guinea         | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_papua_new_guinea.ipset)         |
| `country_paraguay.ipset`                    | Paraguay                 | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_paraguay.ipset)                 |
| `country_peru.ipset`                        | Peru                     | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_peru.ipset)                     |
| `country_philippines.ipset`                 | Philippines              | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_philippines.ipset)              |
| `country_pitcairn.ipset`                    | Pitcairn Islands         | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_pitcairn.ipset)                 |
| `country_poland.ipset`                      | Poland                   | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_poland.ipset)                   |
| `country_portugal.ipset`                    | Portugal                 | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_portugal.ipset)                 |
| `country_puerto_rico.ipset`                 | Puerto Rico              | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_puerto_rico.ipset)              |
| `country_qatar.ipset`                       | Qatar                    | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_qatar.ipset)                    |
| `country_republic_moldova.ipset`            | Moldova                  | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_republic_moldova.ipset)         |
| `country_reunion.ipset`                     | Réunion                  | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_reunion.ipset)                  |
| `country_romania.ipset`                     | Romania                  | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_romania.ipset)                  |
| `country_russia.ipset`                      | Russia                           | ★★★★★    | [view](https://blocklist.configserver.dev/country_russia.ipset)                   |
| `country_rwanda.ipset`                      | Rwanda                           | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_rwanda.ipset)                   |
| `country_saint_barthelemy.ipset`            | Saint Barthélemy                 | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_saint_barthelemy.ipset)         |
| `country_saint_helena.ipset`                | Saint Helena                     | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_saint_helena.ipset)             |
| `country_saint_kitts_nevis.ipset`           | Saint Kitts and Nevis            | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_saint_kitts_nevis.ipset)        |
| `country_saint_lucia.ipset`                 | Saint Lucia                      | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_saint_lucia.ipset)              |
| `country_saint_martin_north.ipset`          | Saint Martin (North)             | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_saint_martin_north.ipset)       |
| `country_saint_pierre_miquelon.ipset`       | Saint Pierre and Miquelon        | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_saint_pierre_miquelon.ipset)    |
| `country_saint_vincent_grenadines.ipset`    | Saint Vincent and the Grenadines | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_saint_vincent_grenadines.ipset) |
| `country_samoa.ipset`                       | Samoa                            | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_samoa.ipset)                    |
| `country_san_marino.ipset`                  | San Marino                       | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_san_marino.ipset)               |
| `country_sao_tome_principe.ipset`           | São Tomé and Príncipe            | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_sao_tome_principe.ipset)        |
| `country_saudi_arabia.ipset`                | Saudi Arabia                     | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_saudi_arabia.ipset)             |
| `country_senegal.ipset`                     | Senegal                          | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_senegal.ipset)                  |
| `country_serbia.ipset`                      | Serbia                           | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_serbia.ipset)                   |
| `country_seychelles.ipset`                  | Seychelles                       | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_seychelles.ipset)               |
| `country_sierra_leone.ipset`                | Sierra Leone                     | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_sierra_leone.ipset)             |
| `country_singapore.ipset`                   | Singapore                                    | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_singapore.ipset)                                    |
| `country_sint_maarten_south.ipset`          | Sint Maarten (South)                         | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_sint_maarten_south.ipset)                           |
| `country_slovakia.ipset`                    | Slovakia                                     | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_slovakia.ipset)                                     |
| `country_slovenia.ipset`                    | Slovenia                                     | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_slovenia.ipset)                                     |
| `country_solomon_islands.ipset`             | Solomon Islands                              | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_solomon_islands.ipset)                              |
| `country_somalia.ipset`                     | Somalia                                      | ★★★★★    | [view](https://blocklist.configserver.dev/country_somalia.ipset)                                      |
| `country_south_africa.ipset`                | South Africa                                 | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_south_africa.ipset)                                 |
| `country_south_georgia_and_the_south_sandwich_islands.ipset` | South Georgia and the South Sandwich Islands | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_south_georgia_and_the_south_sandwich_islands.ipset) |
| `country_south_korea.ipset`                 | South Korea                                  | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_south_korea.ipset)                                  |
| `country_south_sudan.ipset`                 | South Sudan                                  | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_south_sudan.ipset)                                  |
| `country_spain.ipset`                       | Spain                                        | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_spain.ipset)                                        |
| `country_sri_lanka.ipset`                   | Sri Lanka                                    | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_sri_lanka.ipset)                                    |
| `country_sudan.ipset`                       | Sudan                                        | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_sudan.ipset)                                        |
| `country_suriname.ipset`                    | Suriname                                     | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_suriname.ipset)                                     |
| `country_svalbard_jan_mayen.ipset`          | Svalbard and Jan Mayen                       | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_svalbard_jan_mayen.ipset)                           |
| `country_sweden.ipset`                      | Sweden                                       | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_sweden.ipset)                                       |
| `country_switzerland.ipset`                 | Switzerland                                  | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_switzerland.ipset)                                  |
| `country_syria.ipset`                       | Syria                                        | ★★★★★    | [view](https://blocklist.configserver.dev/country_syria.ipset)                                        |
| `country_taiwan.ipset`                      | Taiwan                                       | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_taiwan.ipset)                                       |
| `country_tajikistan.ipset`                  | Tajikistan                                   | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_tajikistan.ipset)                                   |
| `country_tanzania.ipset`                    | Tanzania                                     | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_tanzania.ipset)                                     |
| `country_thailand.ipset`                    | Thailand                 | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_thailand.ipset)             |
| `country_timorleste.ipset`                  | Timor-Leste              | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_timorleste.ipset)           |
| `country_togo.ipset`                        | Togo                     | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_togo.ipset)                 |
| `country_tokelau.ipset`                     | Tokelau                  | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_tokelau.ipset)              |
| `country_tonga.ipset`                       | Tonga                    | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_tonga.ipset)                |
| `country_trinidad_tobago.ipset`             | Trinidad and Tobago      | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_trinidad_tobago.ipset)      |
| `country_tunisia.ipset`                     | Tunisia                  | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_tunisia.ipset)              |
| `country_turkey.ipset`                      | Turkey                   | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_turkey.ipset)               |
| `country_turkmenistan.ipset`                | Turkmenistan             | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_turkmenistan.ipset)         |
| `country_turks_caicos_islands.ipset`        | Turks and Caicos Islands | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_turks_caicos_islands.ipset) |
| `country_tuvalu.ipset`                      | Tuvalu                   | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_tuvalu.ipset)               |
| `country_uganda.ipset`                      | Uganda                   | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_uganda.ipset)               |
| `country_ukraine.ipset`                     | Ukraine                  | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_ukraine.ipset)              |
| `country_united_arab_emirates.ipset`        | United Arab Emirates     | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_united_arab_emirates.ipset) |
| `country_united_states.ipset`               | United States            | ★★★★⚝    | [view](https://blocklist.configserver.dev/country_united_states.ipset)        |
| `country_united_states_minor_outlying_islands.ipset` | US Minor Outlying Islands | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_united_states_minor_outlying_islands.ipset) |
| `country_united_states_virgin_islands.ipset`  | US Virgin Islands         | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_united_states_virgin_islands.ipset)         |
| `country_uruguay.ipset`                     | Uruguay                              | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_uruguay.ipset)                              |
| `country_uzbekistan.ipset`                  | Uzbekistan                           | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_uzbekistan.ipset)                           |
| `country_vanuatu.ipset`                     | Vanuatu                              | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_vanuatu.ipset)                              |
| `country_vatican_city_holy_see.ipset`       | Vatican City / Holy See              | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_vatican_city_holy_see.ipset)                |
| `country_venezuela.ipset`                   | Venezuela                            | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_venezuela.ipset)                            |
| `country_vietnam.ipset`                     | Vietnam                              | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_vietnam.ipset)                              |
| `country_wallis_futuna.ipset`               | Wallis and Futuna                    | ⚝⚝⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_wallis_futuna.ipset)                        |
| `country_western_sahara.ipset`              | Western Sahara                       | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_western_sahara.ipset)                       |
| `country_yemen.ipset`                       | Yemen                                | ★★★★★    | [view](https://blocklist.configserver.dev/country_yemen.ipset)                                |
| `country_zambia.ipset`                      | Zambia                               | ★★⚝⚝⚝    | [view](https://blocklist.configserver.dev/country_zambia.ipset)                               |
| `country_zimbabwe.ipset`                    | Zimbabwe                             | ★★★⚝⚝    | [view](https://blocklist.configserver.dev/country_zimbabwe.ipset)                             |

<br />
<br />