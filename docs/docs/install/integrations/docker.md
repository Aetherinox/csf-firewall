---
title: "Usage › Integration › Docker"
tags:
    - 3rd-party
    - usage
    - configure
    - integration
    - docker
---

# Docker Integration
<!-- md:version stable-15.00 --> <!-- md:fileViewDLExt https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/scripts/docker.sh https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/scripts/docker.sh left -->

Running CSF in environments that leverage Docker requires special considerations due to containerized networking and isolated interfaces.

This section provides guidance on configuring CSF to recognize Docker networks, manage container IP ranges, and ensure that firewall rules do not interfere with container-to-host or container-to-container communication.

Following these steps will help maintain both security and functionality in your Docker-based infrastructure.

<br />

---

<br />

## What is Docker?

[:aetherx-axb-docker: Docker](https://docker.com/) is a platform that lets you run applications inside **containers**, which are small, isolated environments that bundle everything your app needs to run.

A container can be described as a sealed mini virtual machine which includes:

- Distro binaries
  - If your image runs on a distro such as Alpine or Ubuntu
- The application’s code 
- Any required libraries or dependencies 
- Configuration files

Because all of this is packaged together, it ensures that the app runs exactly the same everywhere, such as your laptop, a production server, a homelab machine, or in the cloud. It attempts to solve the problem of _"It works on my machine, but not on yours"_.

Unlike full virtual machines, Docker containers don’t include an entire operating system. Instead, they **share the host OS** while keeping their processes isolated. This gives each container the feel of a mini-system, but with:

- Much less overhead
- Faster startup
- Lower resource usage

Docker containers run isolated from the host system and from each other, using their own virtualized networking interfaces. ConfigServer Firewall (CSF) needs to understand this containerized network environment in order to properly manage traffic.

By supporting Docker, CSF can allow containers to communicate with each other internally, while also controlling and securing access to the public internet.

Without Docker-aware firewall rules, containers may be blocked from sending or receiving traffic, breaking applications that rely on network communication.

CSF ensures that container-to-container communication, external access, and port mappings are properly managed, maintaining both security and functionality in environments where Docker is used.

<br />

---

<br />

## Setup

Open your CSF config file :aetherx-axd-file: `/etc/csf/csf.conf` and change the following setting to the value :aetherx-axd-gear: `1`:

=== ":aetherx-axs-file-magnifying-glass: Find"

    ``` bash title="/etc/csf/csf.conf"
    DOCKER = "0"
    ```

=== ":aetherx-axs-file-pen: Change To"

    ``` bash title="/etc/csf/csf.conf"
    DOCKER = "1"
    ```

<br />

Create a new folder on your server where we can download and place the Docker integration script. 

=== ":aetherx-axs-command: Command"

    ```bash
    sudo mkdir -p /usr/local/include/csf/{pre.d,post.d}
    ```

<br />

The command above will create two folders:

1. :aetherx-axd-folder: `/usr/local/include/csf/pre.d/`
    - Place all bash scripts inside this folder to have firewall rules added **BEFORE** CSF configures iptables.
2. :aetherx-axd-folder: `/usr/local/include/csf/post.d/`
    - Place all bash scripts inside this folder to have firewall rules added **AFTER** CSF configures iptables.

<br />

We need to download the **:aetherx-axb-docker: Docker integration script** from our [:aetherx-axb-github: repository](), and place it within the newly created folder :aetherx-axd-folder: `/usr/local/include/csf/post.d/`. 

To download the Docker integration script, run ONE of the two commands below:

=== ":aetherx-axb-wget: Wget"

    ```bash
    wget -qO "usr/local/include/csf/post.d/docker.sh" \
        "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/scripts/docker.sh"
    ```

=== ":aetherx-axb-curl: Curl"

    ```bash
    curl -fsSL "https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/scripts/docker.sh" \
      -o "usr/local/include/csf/post.d/docker.sh"
    ```

<br />

You should now have the following structure:

<div class="icon-tree" markdown>
<code>
└── :aetherx-axs-folder:{ .icon-clr-tree-folder } usr  
    └── :aetherx-axs-folder:{ .icon-clr-tree-folder } local  
        └── :aetherx-axs-folder:{ .icon-clr-tree-folder } include  
            └── :aetherx-axs-folder:{ .icon-clr-tree-folder } csf  
                └── :aetherx-axs-folder:{ .icon-clr-tree-folder } pre.d  
                └── :aetherx-axs-folder:{ .icon-clr-tree-folder } post.d  
                    └── :aetherx-axd-file:{ .icon-clr-tree-file } docker.sh  
        └── :aetherx-axs-folder:{ .icon-clr-tree-folder } csf  
            └── :aetherx-axs-folder:{ .icon-clr-tree-folder } bin  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } csfpre.sh  
                └── :aetherx-axd-file:{ .icon-clr-tree-file } csfpost.sh  
</code>
</div>

<br />

Next, open up the file :aetherx-axd-file: `/usr/local/include/csf/post.d/docker.sh` and locate the configurable settings at the top:

=== ":aetherx-axd-file: /usr/local/include/csf/post.d/docker.sh"

    ```bash
    docker0_eth="docker0"
    csf_comment="Docker container whitelist"
    file_csf_allow="/etc/csf/csf.allow"
    containers_ip_cidr="172.17.0.0/16"
    ```

<br />

Adjust the settings to fit your needs. Save the file and then give CSF a restart:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -ra
      ```

<br />

CSF may take slightly longer to restart; the Docker integration script needs to be able to scan your entire Docker setup, find all other bridges, find each container, and set up a firewall rules.

You will see output similar to the following:

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      INFO               Initializing csfpost script /usr/local/csf/bin/csfpost.sh
      INFO               Script /usr/local/csf/bin/csfpost.sh loading post.d initialzation scripts in folder /usr/local/include/csf/post.d 
      PASS               Found installed package CSF + LFD  
      PASS               Found installed package Docker     
      PASS               Found installed package iptables   
      PASS               Declared iptables4 binary /usr/sbin/iptables 
      PASS               Declared iptables6 binary /usr/sbin/ip6tables 
      INFO               Cleaning comments in csf allow file /etc/csf/csf.allow 
      INFO               Stripping all DOCKER chains from existing iptable rules; restoring without DOCKER chain 
      INFO               Re-creating required DOCKER chains           
                            + CHAIN [ADD] -t filter -N DOCKER 
                            + CHAIN [ADD] -t filter -N DOCKER-USER 
                            + CHAIN [ADD] -t filter -N DOCKER-ISOLATION-STAGE-1 
                            + CHAIN [ADD] -t filter -N DOCKER-ISOLATION-STAGE-2 
                            + CHAIN [ADD] -t nat -N DOCKER 
      INFO               Apply ACCEPT rule DOCKER table for INPUT chain 
                            + RULES [ADD] -A INPUT -i docker0 -j ACCEPT 
                            + RULES [ADD] -A FORWARD -j DOCKER-USER 
                            + RULES [ADD] -A FORWARD -j DOCKER-ISOLATION-STAGE-1 
                            + RULES [ADD] -A FORWARD -o docker0 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT 
                            + RULES [ADD] -A FORWARD -o docker0 -j DOCKER 
                            + RULES [ADD] -A FORWARD -i docker0 ! -o docker0 -j ACCEPT 
                            + RULES [ADD] -A FORWARD -i docker0 -o docker0 -j ACCEPT 
                            + RULES [ADD] -t nat -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER 
                            + RULES [ADD] -t nat -A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER 

      INFO               Configuring Docker subnet      
                            172.17.0.0/16        
                            + RULES [ADD] -t nat -A POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE 
                            ! RULES [SKP] -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE 
      PASS               Finished configuring Docker subnet 
      ```

<br />

After the Docker integration script runs, you should now have your Docker network firewall rules set up with CSF and iptables.

Finally, give your Docker service a restart:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo service docker restart
      ```

<br />

For more information about the Docker integration script, review the next section below.

<br />

---

<br />

## Integration Script

CSF utilizes a **Docker Integration** script that we have developed to work alongside of CSF. You can view or download the full integration script [here](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/scripts/docker.sh).

<br />

You have two ways to run this script:

1. Place the file in your CSF pre/post folder via :aetherx-axd-folder: `/usr/local/include/csf/post.d/docker.sh`, and automatically load it by restarting CSF.
2. Manually run the script directly.

<br />

### Automatic 

To run the script automatically, drop it in the folder:

<div class="icon-tree" markdown>
<code>
└── :aetherx-axs-folder:{ .icon-clr-tree-folder } usr  
    └── :aetherx-axs-folder:{ .icon-clr-tree-folder } local  
        └── :aetherx-axs-folder:{ .icon-clr-tree-folder } include  
            └── :aetherx-axs-folder:{ .icon-clr-tree-folder } csf  
                └── :aetherx-axs-folder:{ .icon-clr-tree-folder } pre.d  
                └── :aetherx-axs-folder:{ .icon-clr-tree-folder } post.d  
                    └── :aetherx-axd-file:{ .icon-clr-tree-file } docker.sh  
        └── :aetherx-axs-folder:{ .icon-clr-tree-folder } csf  
            └── :aetherx-axs-folder:{ .icon-clr-tree-folder } bin  
                ├── :aetherx-axd-file:{ .icon-clr-tree-file } csfpre.sh  
                └── :aetherx-axd-file:{ .icon-clr-tree-file } csfpost.sh  
</code>
</div>

<br />

Once the script is added to the correct path, restart CSF:

=== ":aetherx-axs-command: Command"

    ``` shell
    sudo csf -ra
    ```

<br />

### Manual

You can activate the `docker.sh` script manually. You will need to download it from our [:aetherx-axb-github: repository](https://raw.githubusercontent.com/Aetherinox/csf-firewall/main/extras/scripts/docker.sh) and place it somewhere on your server.

Then set the permission to be **executable**:

=== ":aetherx-axs-command: Command"

    ```bash
    sudo chmod +x /path/to/docker.sh
    ```

<br />

Finally, run the script with the command:

=== ":aetherx-axs-command: Command"

    ```bash
    sudo sh /usr/local/include/csf/post.d/docker.sh
    ```

<br />

You should see the following output:

=== ":aetherx-axs-square-terminal: Output"

      ```shell
      INFO               Initializing csfpost script /usr/local/csf/bin/csfpost.sh
      INFO               Script /usr/local/csf/bin/csfpost.sh loading post.d initialzation scripts in folder /usr/local/include/csf/post.d 
      PASS               Found installed package CSF + LFD  
      PASS               Found installed package Docker     
      PASS               Found installed package iptables   
      PASS               Declared iptables4 binary /usr/sbin/iptables 
      PASS               Declared iptables6 binary /usr/sbin/ip6tables 
      INFO               Cleaning comments in csf allow file /etc/csf/csf.allow 
      INFO               Stripping all DOCKER chains from existing iptable rules; restoring without DOCKER chain 
      INFO               Re-creating required DOCKER chains           
                            + CHAIN [ADD] -t filter -N DOCKER 
                            + CHAIN [ADD] -t filter -N DOCKER-USER 
                            + CHAIN [ADD] -t filter -N DOCKER-ISOLATION-STAGE-1 
                            + CHAIN [ADD] -t filter -N DOCKER-ISOLATION-STAGE-2 
                            + CHAIN [ADD] -t nat -N DOCKER 
      INFO               Apply ACCEPT rule DOCKER table for INPUT chain 
                            + RULES [ADD] -A INPUT -i docker0 -j ACCEPT 
                            + RULES [ADD] -A FORWARD -j DOCKER-USER 
                            + RULES [ADD] -A FORWARD -j DOCKER-ISOLATION-STAGE-1 
                            + RULES [ADD] -A FORWARD -o docker0 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT 
                            + RULES [ADD] -A FORWARD -o docker0 -j DOCKER 
                            + RULES [ADD] -A FORWARD -i docker0 ! -o docker0 -j ACCEPT 
                            + RULES [ADD] -A FORWARD -i docker0 -o docker0 -j ACCEPT 
                            + RULES [ADD] -t nat -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER 
                            + RULES [ADD] -t nat -A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER 

      INFO               Configuring Docker subnet      
                            172.17.0.0/16        
                            + RULES [ADD] -t nat -A POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE 
                            ! RULES [SKP] -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE 
      PASS               Finished configuring Docker subnet 
      ```

<br />

### Command Flags

This script includes numerous flags you can specify if you run the `docker.sh` script manually.

<br />

#### Help
<!-- md:version stable-15.01 --> <!-- md:command `-h,  --help` -->

Shows a list of all available commands included in the Docker integration script:

=== ":aetherx-axs-command: Command"

    ```bash
    sudo sh /usr/local/include/csf/post.d/docker.sh --help
    ```

<br />
<br />

#### List
<!-- md:version stable-15.09 --> <!-- md:command `-l, --list` -->

Will display a list of all available docker containers, and their assigned ports and subnets

=== ":aetherx-axs-command: Command"

    ```bash
    sudo sh /usr/local/include/csf/post.d/docker.sh --list
    ```

<br />
<br />

#### Restart
<!-- md:version stable-15.09 --> <!-- md:command `-r, --restart` -->

Restarts **csf** and **lfd** services.

=== ":aetherx-axs-command: Command"

    ```bash
    sudo sh /usr/local/include/csf/post.d/docker.sh --restart
    ```

<br />
<br />

#### Flush
<!-- md:version stable-15.09 --> <!-- md:command `-f, --flush` -->

Completely flushes all **iptable** rules.

=== ":aetherx-axs-command: Command"

    ```bash
    sudo sh /usr/local/include/csf/post.d/docker.sh --flush
    ```

<br />
<br />

#### Dryrun
<!-- md:version stable-15.05 --> <!-- md:command `-d, --dryrun` -->

Simulates running the entire script but does not actually make changes.

=== ":aetherx-axs-command: Command"

    ```bash
    sudo sh /usr/local/include/csf/post.d/docker.sh --dryrun
    ```

<br />
<br />

#### Version
<!-- md:version stable-15.00 --> <!-- md:command `-v, --version` -->

Shows information about the current version of the integration script you are running.

=== ":aetherx-axs-command: Command"

    ```bash
    sudo sh /usr/local/include/csf/post.d/docker.sh --version
    ```

<br />

---

<br />

## Troubleshooting

The following section highlights common issues or errors you might encounter when configuring CSF to work with Docker, along with potential solutions to resolve them.

<br />

### Error response from daemon: failed to set up container networking

After integrating CSF, you might encounter the following error when trying to start or restart a Docker container:

``` shell
Error response from daemon: failed to set up container networking:
    driver failed programming external connectivity on endpoint my_container (cc81da8c4XXXXXXXXX): 
        Unable to enable DNAT rule:  (iptables failed: 
            iptables --wait -t nat -A DOCKER -p tcp -d 0/0 --dport 80 -j DNAT --to-destination 172.XX.XX.XX:80 ! -i br-6f611f185f
```

<br />

To correct the above error, restart your docker service:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo service docker restart
      ```

<br />

You can now restart the Docker container again.

=== ":aetherx-axd-command: Command (docker restart)"

      ``` shell
      docker restart <container_name_or_id>
      ```

=== ":aetherx-axd-command: Command (docker compose)"

      ``` shell
      docker-compose restart <container_name_or_id>
      ```

=== ":aetherx-axd-command: Command (docker run)"

      ``` shell
      docker run --name <container_name_or_id> --restart unless-stopped ...
      ```

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axb-authentik: &nbsp; __[Authentik Integration](../integrations/authentik.md)__

    ---

    Enhance the security of CSF by placing it behind the **Authentik** identity 
    provider using a forward proxy. 
    
    This ensures that all traffic to the CSF web interface passes through Authentik, 
    giving you centralized control over authentication and access.
    
    With this setup, CSF is protected by modern authentication methods such as
    passwords, two-factor authentication (2FA), or passkeys.

-   :aetherx-axd-earth-europe: &nbsp; __[Geographical IP Block Integration](../../usage/geoip.md)__

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
