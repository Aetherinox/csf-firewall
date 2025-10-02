---
title: "Usage › Docker Integration"
tags:
    - usage
    - configure
    - integration
    - docker
---

# Docker Integration

Running CSF in environments that leverage Docker requires special considerations due to containerized networking and isolated interfaces. This section provides guidance on configuring CSF to recognize Docker networks, manage container IP ranges, and ensure that firewall rules do not interfere with container-to-host or container-to-container communication. Following these steps will help maintain both security and functionality in your Docker-based infrastructure.

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

## What is Docker?

Docker is a platform that allows developers and system administrators to package applications and their dependencies into lightweight, portable containers. These containers run consistently across different environments, ensuring that software behaves the same on a developer’s laptop as it does on production servers. By isolating applications from the underlying operating system, Docker simplifies deployment, scaling, and management, making it an essential tool for modern infrastructure and DevOps practices.

While Docker containers are not full virtual machines, they function in a similar way by providing isolated environments for applications. Each container has its own filesystem, processes, and network interfaces, allowing multiple containers to run on the same host without interfering with each other. This isolation provides many of the benefits of traditional virtual machines but with far lower overhead and faster startup times.

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

## Conclusion

If you do all of the steps above, you should now be able to access the CSF web interface through your browser, with the added protection of Traefik. This will allow you to access the web interface from other locations, implement middleware such as IP whitelisting, and not expose the CSF web interface port to the world. You should **NOT** be allowing any connection to access the web interface, even if they don't have the username and password to sign in.

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

-   :aetherx-axb-authentik: &nbsp; __[Authentik Integration](../install/authentik.md)__

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
