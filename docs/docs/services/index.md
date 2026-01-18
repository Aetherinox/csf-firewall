---
title: Services
tags:
  - services
  - blocklist.configserver.dev
  - download.configserver.dev
  - get.configserver.dev
---

# Services <!-- omit from toc -->

This page outlines the services offered through CSF.  

These services are designed to make it easier to access, install, and manage CSF while maintaining consistency and reliability across different environments.  

- :aetherx-axs-block-brick-fire: [**Blocklist Service**](#blocklistconfigserverdev)
:   Delivers curated and trusted blocklists in a consistent format, making it easy to integrate with security tools and workflows for reducing unwanted or malicious traffic.  
- :aetherx-axs-download: [**Download Service**](#downloadconfigserverdev)
:   Provides direct access to the latest CSF release in `.zip` or `.tgz` format, with options for standardized filenames, preserved release names, or programmatic access through a JSON API.  
- :aetherx-axs-box-isometric: [**Get Service**](#getconfigserverdev)
:   Offers a convenient Bash-based installer that can download, extract, and install CSF in a single step, with additional options for dry runs, cleanup, and installation from existing local files.  

Together, these services provide a streamlined way to keep CSF installations up to date and enhance server security with minimal effort.


<br />

---

<br />

## :aetherx-axs-block-brick-fire: blocklist.configserver.dev <!-- omit from toc -->
<!-- md:docs ../services/blocklist.configserver.md self -->

<div align="center" class="icon-container" markdown>

  [:aetherx-axs-block-brick-fire:](https://blocklist.configserver.dev){ .icon-size-48 .icon-dim target="_blank" }

</div>

The [blocklist.configserver.dev](https://blocklist.configserver.dev/master.ipset) service provides a streamlined way to access and use curated blocklists designed to enhance security and reduce unwanted traffic. It acts as a lightweight proxy that surfaces blocklists from trusted sources in a consistent, easy-to-use format, making it simple to integrate into existing security tools and workflows.

By centralizing access, the service eliminates the complexity of pulling blocklists from multiple vendors, ensuring faster updates and more reliable availability. It can be used alongside other security measures to strengthen protection against abusive IPs, malicious actors, and other unwanted traffic sources.

<br />

---

<br />

## :aetherx-axs-download: download.configserver.dev <!-- omit from toc -->
<!-- md:docs ../services/download.configserver.md self -->

<div align="center" class="icon-container" markdown>

  [:aetherx-axs-download:](https://download.configserver.dev){ .icon-size-48 .icon-dim target="_blank" }

</div>

The [download.configserver.dev](https://download.configserver.dev) service provides a simple and reliable way to obtain the latest release of CSF without needing to track version numbers or manually check for updates. Users can fetch the most up-to-date package directly through a browser or from the command line, ensuring they always have access to the newest version in either .zip or .tgz format. By standardizing filenames to csf.zip or csf.tgz, the service also makes it easier to integrate into scripts and automated workflows.

In addition to basic downloads, the service offers advanced features for users who need more flexibility. Options include preserving original release filenames, querying a JSON API to programmatically fetch the latest version, and retrieving direct download links. These features make the service not only a convenient tool for individuals but also a powerful resource for system administrators and developers who need to keep CSF deployments consistent and up to date.

<br />

---

<br />

## :aetherx-axs-box-isometric: get.configserver.dev <!-- omit from toc -->
<!-- md:docs ../services/get.configserver.md self -->

<div align="center" class="icon-container" markdown>

  [:aetherx-axs-box-isometric:](https://get.configserver.dev){ .icon-size-48 .icon-dim target="_blank" }

</div>

The [get.configserver.dev](https://get.configserver.dev) service offers a quick and flexible way to download and install the latest version of CSF using a single Bash command. Instead of manually fetching and managing release files, the service handles everything automatically—placing the newest archive in your current directory with the correct format (.zip or .tgz). This makes it especially useful for users who want a no-fuss method of obtaining CSF without needing to check for version numbers or file names.

Beyond simple downloads, the service provides optional arguments that extend its functionality. Users can choose to automatically extract the archive, install CSF immediately, or preserve the original release filename. It also supports dry-run installs and cleanup options, giving administrators fine-grained control over how CSF is managed on their systems. In short, the get service is designed to simplify installation and updates, whether for quick testing or production use.

<br />
<br />