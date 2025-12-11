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

Running CSF in environments that leverage Docker requires special considerations due to containerized networking and isolated interfaces.

This section provides guidance on configuring CSF to recognize Docker networks, manage container IP ranges, and ensure that firewall rules do not interfere with container-to-host or container-to-container communication.

Following these steps will help maintain both security and functionality in your Docker-based infrastructure.

<br />

---

<br />

## What is Docker?

Docker is a platform that lets you run applications inside **containers**, which are small, isolated environments that bundle everything your app needs to run.

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

<br />

---

<br />

## Docker and CSF

Docker containers run isolated from the host system and from each other, using their own virtualized networking interfaces. ConfigServer Firewall (CSF) needs to understand this containerized network environment in order to properly manage traffic.

By supporting Docker, CSF can allow containers to communicate with each other internally, while also controlling and securing access to the public internet.

Without Docker-aware firewall rules, containers may be blocked from sending or receiving traffic, breaking applications that rely on network communication.

CSF ensures that container-to-container communication, external access, and port mappings are properly managed, maintaining both security and functionality in environments where Docker is used.

<br />

---

<br />

## Enable Docker Mode

Open your CSF config file located at `/etc/csf/csf.conf` and change the following setting to the value `1`:

=== ":aetherx-axs-file-magnifying-glass: Find"

    ``` bash title="/etc/csf/csf.conf"
    DOCKER = "0"
    ```

=== ":aetherx-axs-file-pen: Change To"

    ``` bash title="/etc/csf/csf.conf"
    DOCKER = "1"
    ```

<br />

Save the file and then give CSF a restart:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo csf -ra
      ```

<br />

Afterward, give your Docker service a restart:

=== ":aetherx-axd-command: Command"

      ```shell
      sudo service docker restart
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

-   :aetherx-axb-authentik: &nbsp; __[Authentik Integration](../install/integrations/authentik.md)__

    ---

    Enhance the security of CSF by placing it behind the **Authentik** identity 
    provider using a forward proxy. 
    
    This ensures that all traffic to the CSF web interface passes through Authentik, 
    giving you centralized control over authentication and access.
    
    With this setup, CSF is protected by modern authentication methods such as
    passwords, two-factor authentication (2FA), or passkeys.

-   :aetherx-axd-earth-europe: &nbsp; __[Geographical IP Block Integration](../usage/geoip.md)__

    ---

    Configure geographical restrictions in CSF to whitelist or blacklist specific
    regions from accessing your server.
    
    This chapter covers enabling the GeoIP blocklist feature using third-party
    services such as MaxMind (requires an API key), db-ip, ipdeny, or iptoasn.
    
    These services allow you to control access based on location while keeping
    your server secure.

</div>

<br />
<br />
