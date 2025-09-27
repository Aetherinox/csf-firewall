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

Read the chapter [Blocklists](../../usage/blocklists.md) for more information about this feature and service.

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

### Basic

By default, each blocklist is served as a plain text file containing IP addresses and CIDR ranges.  
All lists are available as `.ipset` files and can be retrieved directly over HTTP.  

For example, you can open the following URL in your browser or use `curl` to download the master blocklist:

<div class="grid cards" markdown>

-   :aetherx-axs-earth-americas: &nbsp; [__IPSET__ › https://blocklist.configserver.dev/master.ipset](https://blocklist.configserver.dev/master.ipset)

</div>

This file can then be imported into CSF, FireHOL, or any firewall, security tool, or monitoring system that supports ipsets.  

<br />

### Advanced  <!-- omit from toc -->

Beyond simple blocklist retrieval, the service also provides an API with a statistics endpoint.  
By appending the query parameter `?stats=true` to any `.ipset` file, the server will return metadata instead of the raw list.  

The statistics response is provided in JSON format and includes details such as the list name, source, number of entries, size, and timestamps.  

Example response:

```json title="http://blocklist.configserver.dev/master.ipset"
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
#       http://blocklist.configserver.dev/master.ipset
#       http://blocklist.configserver.dev/highrisk.ipset
#   
#   We offer many others, but these two are the primary ones.
#   
#   Requires you to edit /etc/csf/csf.conf setting:
#       LF_IPSET_MAXELEM = "4000000"
# #

CSF_MASTER   | 43200 | 0      | http://blocklist.configserver.dev/master.ipset
CSF_HIGHRISK | 43200 | 0      | http://blocklist.configserver.dev/highrisk.ipset
```

<br />

---

<br />

## Blocklists  <!-- omit from toc -->

The following lists outline the blocklists that are available to use with our blocklist service

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

| Filename | Description |
|----------|------------|
| `master.ipset` | Abusive IPs reported for port scanning and SSH brute-forcing. HIGHLY recommended. <br> <span class="text-sm-9">Includes [AbuseIPDB](https://www.abuseipdb.com/), [IPThreat](https://ipthreat.net/), [CinsScore](https://cinsscore.com), [GreensNow](https://blocklist.greensnow.co/greensnow.txt)</span> |
| `highrisk.ipset` | IPs with highest risk to your network and have a possibility that the activity which comes from them are going to be fraudulent. |

<br />

### Privacy

These blocklists help you control which third-party services can access your server, allowing you to block bad actors or unwanted service providers.

<br />

| Filename | Description |
|----------|------------|
| `privacy_general.ipset` | Servers which scan ports for data collection and research purposes. <span class="text-sm-9">List includes [Censys](https://censys.io), [Shodan](https://shodan.io/), [Project25499](https://blogproject25499.wordpress.com/), [InternetArchive](https://archive.org/), [Cyber Resilience](https://cyberresilience.io), [Internet Measurement](https://internet-measurement.com), [probe.onyphe.net](https://onyphe.net), [Security Trails](https://securitytrails.com)</span> |
| `privacy_activision.ipset` | IPs used by Activision services and bots |
| `privacy_ahrefs.ipset` | IPs from Ahrefs crawler and data collectors |
| `privacy_amazon_aws.ipset` | Amazon AWS infrastructure IPs |
| `privacy_amazon_ec2.ipset` | Amazon EC2 instances |
| `privacy_applebot.ipset` | Applebot crawler IPs |
| `privacy_bing.ipset` | Microsoft Bing crawler IPs |
| `privacy_blizzard.ipset` | Blizzard services and game IPs |
| `privacy_bunnycdn.ipset` | BunnyCDN infrastructure IPs |
| `privacy_cloudflarecdn.ipset` | Cloudflare CDN and network IPs |
| `privacy_cloudfront.ipset` | AWS CloudFront IP ranges |
| `privacy_duckduckgo.ipset` | DuckDuckGo crawler IPs |
| `privacy_electronicarts_ign.ipset` | EA / IGN related services and IPs |
| `privacy_facebook.ipset` | Facebook service IPs |
| `privacy_fastly.ipset` | Fastly CDN network IPs |
| `privacy_google.ipset` | Google crawler and services IPs |
| `privacy_nintendo.ipset` | Nintendo services IPs |
| `privacy_pandora.ipset` | Pandora network IPs |
| `privacy_pingdom.ipset` | Pingdom monitoring service IPs |
| `privacy_piratebay.ipset` | PirateBay-related IPs |
| `privacy_punkbuster.ipset` | PunkBuster anti-cheat service IPs |
| `privacy_riot_games.ipset` | Riot Games IPs |
| `privacy_rssapi.ipset` | RSS API service IPs |
| `privacy_sony.ipset` | Sony services and network IPs |
| `privacy_steam.ipset` | Steam service IPs |
| `privacy_stripe_api.ipset` | Stripe API endpoints |
| `privacy_stripe_armada_gator.ipset` | Stripe-related monitoring IPs |
| `privacy_stripe_webhooks.ipset` | Stripe webhook IPs |
| `privacy_telegram.ipset` | Telegram service IPs |
| `privacy_ubisoft.ipset` | Ubisoft network IPs |
| `privacy_uptimerobot.ipset` | UptimeRobot monitoring IPs |
| `privacy_webpagetest.ipset` | WebPageTest infrastructure IPs |
| `privacy_xfire.ipset` | Xfire service IPs |

<br />
<br />
<br />

### Spam

These blocklists help prevent known spam sources from accessing your server. They include IPs identified by services like Spamhaus as well as spammers targeting forums and other online platforms.

<br />

| Filename | Description |
|----------|------------|
| `spam_forums.ipset` | IPs associated with forum spam |
| `spam_spamhaus.ipset` | Spamhaus blocklist IPs |

<br />
<br />
<br />

### Internet Service Providers

These blocklists allow you to filter traffic based on Internet Service Providers (ISPs). They can be used to block or restrict access from specific networks or providers.

<br />

| Filename | Description |
|----------|------------|
| `isp_aol.ipset` | AOL Internet Service Provider IPs |
| `isp_att.ipset` | AT&T Internet Service Provider IPs |
| `isp_cablevision.ipset` | Cablevision / Optimum ISP IPs |
| `isp_charter_spectrum_timewarnercable.ipset` | Charter/Spectrum/TWC ISP IPs |
| `isp_comcast.ipset` | Comcast / Xfinity ISP IPs |
| `isp_cox_communications.ipset` | Cox Communications ISP IPs |
| `isp_embarq.ipset` | Embarq / CenturyLink ISP IPs |
| `isp_frontier_communications.ipset` | Frontier Communications ISP IPs |
| `isp_qwest.ipset` | Qwest / CenturyLink ISP IPs |
| `isp_spacex_starlink.ipset` | SpaceX Starlink satellite ISP IPs |
| `isp_sprint.ipset` | Sprint ISP IPs |
| `isp_suddenlink_altice_optimum.ipset` | Suddenlink / Altice / Optimum ISP IPs |
| `isp_verizon.ipset` | Verizon ISP IPs |

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

| Filename | Description |
|----------|------------|
| `transmission.ipset` | IPs related to BitTorrent Transmission clients |

<br />
<br />
<br />

### Continents (GeoLite2)

These blocklists let you control which geographical locations can access your server. They can be used as either a whitelist or a blacklist and include both **continents** and **countries**.  

All data is sourced directly from the GeoLite2 Database.

<br />

| Filename | Description |
|----------|------------|
| `continent_africa.ipset` | All IPs located in Africa |
| `continent_antartica.ipset` | IPs in Antarctica |
| `continent_asia.ipset` | All Asian IPs |
| `continent_europe.ipset` | European IPs |
| `continent_north_america.ipset` | North American IPs |
| `continent_oceania.ipset` | Oceania IPs |
| `continent_south_america.ipset` | South American IPs |

<br />
<br />
<br />

### Countries (GeoLite2)

These blocklists let you control which geographical locations can access your server. They can be used as either a whitelist or a blacklist and include both **continents** and **countries**.  

All data is sourced directly from the GeoLite2 Database.

<br />

| Filename | Description |
|----------|------------|
| `country_afghanistan.ipset` | IPs located in Afghanistan |
| `country_aland_islands.ipset` | IPs in Aland Islands |
| `country_albania.ipset` | IPs in Albania |
| `country_algeria.ipset` | IPs in Algeria |
| `country_american_samoa.ipset` | IPs in American Samoa |
| `country_andorra.ipset` | IPs in Andorra |
| `country_angola.ipset` | IPs in Angola |
| `country_anguilla.ipset` | IPs in Anguilla |
| `country_antarctica.ipset` | IPs in Antarctica |
| `country_antigua_barbuda.ipset` | IPs in Antigua and Barbuda |
| `country_argentina.ipset` | IPs in Argentina |
| `country_armenia.ipset` | IPs in Armenia |
| `country_aruba.ipset` | IPs in Aruba |
| `country_australia.ipset` | IPs in Australia |
| `country_austria.ipset` | IPs in Austria |
| `country_azerbaijan.ipset` | IPs in Azerbaijan |
| `country_bahamas.ipset` | IPs in The Bahamas |
| `country_bahrain.ipset` | IPs in Bahrain |
| `country_bangladesh.ipset` | IPs in Bangladesh |
| `country_barbados.ipset` | IPs in Barbados |
| `country_belarus.ipset` | IPs in Belarus |
| `country_belgium.ipset` | IPs in Belgium |
| `country_belize.ipset` | IPs in Belize |
| `country_benin.ipset` | IPs in Benin |
| `country_bermuda.ipset` | IPs in Bermuda |
| `country_bhutan.ipset` | IPs in Bhutan |
| `country_bolivia.ipset` | IPs in Bolivia |
| `country_bonaire_sint_eustatius_saba.ipset` | IPs in Bonaire, Sint Eustatius, and Saba |
| `country_bosnia_herzegovina.ipset` | IPs in Bosnia and Herzegovina |
| `country_botswana.ipset` | IPs in Botswana |
| `country_bouvet_island.ipset` | IPs in Bouvet Island |
| `country_brazil.ipset` | IPs in Brazil |
| `country_british_indian_ocean_territory.ipset` | IPs in British Indian Ocean Territory |
| `country_british_virgin_islands.ipset` | IPs in British Virgin Islands |
| `country_brunei_darussalam.ipset` | IPs in Brunei |
| `country_bulgaria.ipset` | IPs in Bulgaria |
| `country_burkina_faso.ipset` | IPs in Burkina Faso |
| `country_burundi.ipset` | IPs in Burundi |
| `country_cambodia.ipset` | IPs in Cambodia |
| `country_cameroon.ipset` | IPs in Cameroon |
| `country_canada.ipset` | IPs in Canada |
| `country_cape_verde.ipset` | IPs in Cape Verde |
| `country_cayman_islands.ipset` | IPs in Cayman Islands |
| `country_cc.ipset` | IPs in Cocos (Keeling) Islands |
| `country_central_african_republic.ipset` | IPs in Central African Republic |
| `country_chad.ipset` | IPs in Chad |
| `country_chile.ipset` | IPs in Chile |
| `country_china.ipset` | IPs in China |
| `country_christmas_island.ipset` | IPs in Christmas Island |
| `country_colombia.ipset` | IPs in Colombia |
| `country_comoros.ipset` | IPs in Comoros |
| `country_congo.ipset` | IPs in Congo |
| `country_cook_islands.ipset` | IPs in Cook Islands |
| `country_costa_rica.ipset` | IPs in Costa Rica |
| `country_cote_divoire.ipset` | IPs in Côte d'Ivoire |
| `country_croatia.ipset` | IPs in Croatia |
| `country_cuba.ipset` | IPs in Cuba |
| `country_curacao.ipset` | IPs in Curaçao |
| `country_cyprus.ipset` | IPs in Cyprus |
| `country_czech_republic.ipset` | IPs in Czech Republic |
| `country_democratic_republic_congo.ipset` | IPs in Democratic Republic of the Congo |
| `country_denmark.ipset` | IPs in Denmark |
| `country_djibouti.ipset` | IPs in Djibouti |
| `country_dominica.ipset` | IPs in Dominica |
| `country_dominican_republic.ipset` | IPs in Dominican Republic |
| `country_ecuador.ipset` | IPs in Ecuador |
| `country_egypt.ipset` | IPs in Egypt |
| `country_el_salvador.ipset` | IPs in El Salvador |
| `country_equatorial_guinea.ipset` | IPs in Equatorial Guinea |
| `country_eritrea.ipset` | IPs in Eritrea |
| `country_estonia.ipset` | IPs in Estonia |
| `country_eswatini.ipset` | IPs in Eswatini |
| `country_ethiopia.ipset` | IPs in Ethiopia |
| `country_europe.ipset` | IPs in Europe |
| `country_falkland_islands_malvinas.ipset` | IPs in Falkland Islands (Malvinas) |
| `country_faroe_islands.ipset` | IPs in Faroe Islands |
| `country_fiji.ipset` | IPs in Fiji |
| `country_finland.ipset` | IPs in Finland |
| `country_france.ipset` | IPs in France |
| `country_french_guiana.ipset` | IPs in French Guiana |
| `country_french_polynesia.ipset` | IPs in French Polynesia |
| `country_french_southern_territories.ipset` | IPs in French Southern Territories |
| `country_gabon.ipset` | IPs in Gabon |
| `country_gambia.ipset` | IPs in Gambia |
| `country_georgia.ipset` | IPs in Georgia |
| `country_germany.ipset` | IPs in Germany |
| `country_ghana.ipset` | IPs in Ghana |
| `country_gibraltar.ipset` | IPs in Gibraltar |
| `country_great_britain.ipset` | IPs in Great Britain |
| `country_greece.ipset` | IPs in Greece |
| `country_greenland.ipset` | IPs in Greenland |
| `country_grenada.ipset` | IPs in Grenada |
| `country_guadeloupe.ipset` | IPs in Guadeloupe |
| `country_guam.ipset` | IPs in Guam |
| `country_guatemala.ipset` | IPs in Guatemala |
| `country_guernsey.ipset` | IPs in Guernsey |
| `country_guineabissau.ipset` | IPs in Guinea-Bissau |
| `country_guinea.ipset` | IPs in Guinea |
| `country_guyana.ipset` | IPs in Guyana |
| `country_haiti.ipset` | IPs in Haiti |
| `country_heard_island_and_mcdonald_islands.ipset` | IPs in Heard Island and McDonald Islands |
| `country_honduras.ipset` | IPs in Honduras |
| `country_hong_kong.ipset` | IPs in Hong Kong |
| `country_hungary.ipset` | IPs in Hungary |
| `country_iceland.ipset` | IPs in Iceland |
| `country_india.ipset` | IPs in India |
| `country_indonesia.ipset` | IPs in Indonesia |
| `country_iran.ipset` | IPs in Iran |
| `country_iraq.ipset` | IPs in Iraq |
| `country_ireland.ipset` | IPs in Ireland |
| `country_isle_of_man.ipset` | IPs in Isle of Man |
| `country_israel.ipset` | IPs in Israel |
| `country_italy.ipset` | IPs in Italy |
| `country_jamaica.ipset` | IPs in Jamaica |
| `country_japan.ipset` | IPs in Japan |
| `country_jersey.ipset` | IPs in Jersey |
| `country_jordan.ipset` | IPs in Jordan |
| `country_kazakhstan.ipset` | IPs in Kazakhstan |
| `country_kenya.ipset` | IPs in Kenya |
| `country_kiribati.ipset` | IPs in Kiribati |
| `country_kosovo.ipset` | IPs in Kosovo |
| `country_kuwait.ipset` | IPs in Kuwait |
| `country_kyrgyzstan.ipset` | IPs in Kyrgyzstan |
| `country_laos.ipset` | IPs in Laos |
| `country_latvia.ipset` | IPs in Latvia |
| `country_lebanon.ipset` | IPs in Lebanon |
| `country_lesotho.ipset` | IPs in Lesotho |
| `country_liberia.ipset` | IPs in Liberia |
| `country_libya.ipset` | IPs in Libya |
| `country_liechtenstein.ipset` | IPs in Liechtenstein |
| `country_lithuania.ipset` | IPs in Lithuania |
| `country_luxembourg.ipset` | IPs in Luxembourg |
| `country_macao.ipset` | IPs in Macao |
| `country_macedonia_republic.ipset` | IPs in Macedonia |
| `country_madagascar.ipset` | IPs in Madagascar |
| `country_malawi.ipset` | IPs in Malawi |
| `country_malaysia.ipset` | IPs in Malaysia |
| `country_maldives.ipset` | IPs in Maldives |
| `country_mali.ipset` | IPs in Mali |
| `country_malta.ipset` | IPs in Malta |
| `country_marshall_islands.ipset` | IPs in Marshall Islands |
| `country_martinique.ipset` | IPs in Martinique |
| `country_mauritania.ipset` | IPs in Mauritania |
| `country_mauritius.ipset` | IPs in Mauritius |
| `country_mayotte.ipset` | IPs in Mayotte |
| `country_mexico.ipset` | IPs in Mexico |
| `country_micronesia.ipset` | IPs in Micronesia |
| `country_monaco.ipset` | IPs in Monaco |
| `country_mongolia.ipset` | IPs in Mongolia |
| `country_montenegro.ipset` | IPs in Montenegro |
| `country_montserrat.ipset` | IPs in Montserrat |
| `country_morocco.ipset` | IPs in Morocco |
| `country_mozambique.ipset` | IPs in Mozambique |
| `country_myanmar.ipset` | IPs in Myanmar |
| `country_namibia.ipset` | IPs in Namibia |
| `country_nauru.ipset` | IPs in Nauru |
| `country_nepal.ipset` | IPs in Nepal |
| `country_netherlands.ipset` | IPs in Netherlands |
| `country_new_caledonia.ipset` | IPs in New Caledonia |
| `country_new_zealand.ipset` | IPs in New Zealand |
| `country_nicaragua.ipset` | IPs in Nicaragua |
| `country_nigeria.ipset` | IPs in Nigeria |
| `country_niger.ipset` | IPs in Niger |
| `country_niue.ipset` | IPs in Niue |
| `country_norfolk_island.ipset` | IPs in Norfolk Island |
| `country_northern_mariana_islands.ipset` | IPs in Northern Mariana Islands |
| `country_north_korea.ipset` | IPs in North Korea |
| `country_norway.ipset` | IPs in Norway |
| `country_oman.ipset` | IPs in Oman |
| `country_pakistan.ipset` | IPs in Pakistan |
| `country_palau.ipset` | IPs in Palau |
| `country_palestine.ipset` | IPs in Palestine |
| `country_panama.ipset` | IPs in Panama |
| `country_papua_new_guinea.ipset` | IPs in Papua New Guinea |
| `country_paraguay.ipset` | IPs in Paraguay |
| `country_peru.ipset` | IPs in Peru |
| `country_philippines.ipset` | IPs in Philippines |
| `country_pitcairn.ipset` | IPs in Pitcairn Islands |
| `country_poland.ipset` | IPs in Poland |
| `country_portugal.ipset` | IPs in Portugal |
| `country_puerto_rico.ipset` | IPs in Puerto Rico |
| `country_qatar.ipset` | IPs in Qatar |
| `country_republic_moldova.ipset` | IPs in Moldova |
| `country_reunion.ipset` | IPs in Réunion |
| `country_romania.ipset` | IPs in Romania |
| `country_russia.ipset` | IPs in Russia |
| `country_rwanda.ipset` | IPs in Rwanda |
| `country_saint_barthelemy.ipset` | IPs in Saint Barthélemy |
| `country_saint_helena.ipset` | IPs in Saint Helena |
| `country_saint_kitts_nevis.ipset` | IPs in Saint Kitts and Nevis |
| `country_saint_lucia.ipset` | IPs in Saint Lucia |
| `country_saint_martin_north.ipset` | IPs in Saint Martin (North) |
| `country_saint_pierre_miquelon.ipset` | IPs in Saint Pierre and Miquelon |
| `country_saint_vincent_grenadines.ipset` | IPs in Saint Vincent and the Grenadines |
| `country_samoa.ipset` | IPs in Samoa |
| `country_san_marino.ipset` | IPs in San Marino |
| `country_sao_tome_principe.ipset` | IPs in São Tomé and Príncipe |
| `country_saudi_arabia.ipset` | IPs in Saudi Arabia |
| `country_senegal.ipset` | IPs in Senegal |
| `country_serbia.ipset` | IPs in Serbia |
| `country_seychelles.ipset` | IPs in Seychelles |
| `country_sierra_leone.ipset` | IPs in Sierra Leone |
| `country_singapore.ipset` | IPs in Singapore |
| `country_sint_maarten_south.ipset` | IPs in Sint Maarten (South) |
| `country_slovakia.ipset` | IPs in Slovakia |
| `country_slovenia.ipset` | IPs in Slovenia |
| `country_solomon_islands.ipset` | IPs in Solomon Islands |
| `country_somalia.ipset` | IPs in Somalia |
| `country_south_africa.ipset` | IPs in South Africa |
| `country_south_georgia_and_the_south_sandwich_islands.ipset` | IPs in South Georgia and the South Sandwich Islands |
| `country_south_korea.ipset` | IPs in South Korea |
| `country_south_sudan.ipset` | IPs in South Sudan |
| `country_spain.ipset` | IPs in Spain |
| `country_sri_lanka.ipset` | IPs in Sri Lanka |
| `country_sudan.ipset` | IPs in Sudan |
| `country_suriname.ipset` | IPs in Suriname |
| `country_svalbard_jan_mayen.ipset` | IPs in Svalbard and Jan Mayen |
| `country_sweden.ipset` | IPs in Sweden |
| `country_switzerland.ipset` | IPs in Switzerland |
| `country_syria.ipset` | IPs in Syria |
| `country_taiwan.ipset` | IPs in Taiwan |
| `country_tajikistan.ipset` | IPs in Tajikistan |
| `country_tanzania.ipset` | IPs in Tanzania |
| `country_thailand.ipset` | IPs in Thailand |
| `country_timorleste.ipset` | IPs in Timor-Leste |
| `country_togo.ipset` | IPs in Togo |
| `country_tokelau.ipset` | IPs in Tokelau |
| `country_tonga.ipset` | IPs in Tonga |
| `country_trinidad_tobago.ipset` | IPs in Trinidad and Tobago |
| `country_tunisia.ipset` | IPs in Tunisia |
| `country_turkey.ipset` | IPs in Turkey |
| `country_turkmenistan.ipset` | IPs in Turkmenistan |
| `country_turks_caicos_islands.ipset` | IPs in Turks and Caicos Islands |
| `country_tuvalu.ipset` | IPs in Tuvalu |
| `country_uganda.ipset` | IPs in Uganda |
| `country_ukraine.ipset` | IPs in Ukraine |
| `country_united_arab_emirates.ipset` | IPs in United Arab Emirates |
| `country_united_states.ipset` | IPs in United States |
| `country_united_states_minor_outlying_islands.ipset` | IPs in United States Minor Outlying Islands |
| `country_united_states_virgin_islands.ipset` | IPs in United States Virgin Islands |
| `country_uruguay.ipset` | IPs in Uruguay |
| `country_uzbekistan.ipset` | IPs in Uzbekistan |
| `country_vanuatu.ipset` | IPs in Vanuatu |
| `country_vatican_city_holy_see.ipset` | IPs in Vatican City / Holy See |
| `country_venezuela.ipset` | IPs in Venezuela |
| `country_vietnam.ipset` | IPs in Vietnam |
| `country_wallis_futuna.ipset` | IPs in Wallis and Futuna |
| `country_western_sahara.ipset` | IPs in Western Sahara |
| `country_yemen.ipset` | IPs in Yemen |
| `country_zambia.ipset` | IPs in Zambia |
| `country_zimbabwe.ipset` | IPs in Zimbabwe |


<br />
<br />