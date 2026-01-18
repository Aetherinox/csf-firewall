---
title: "Usage › Integration › Authentik"
tags:
    - 3rd-party
    - usage
    - configure
    - integration
    - authentik
    - traefik
    - authentication
    - 2fa
    - passkey
---

# Authentik Integration

This section explains how to add Authentik as a **middleware** through [Traefik](../integrations/traefik.md) 
so that you can secure the CSF web interface behind an authentication server.

<br />

---

<br />

## What is Authentik?

[Authentik](https://goauthentik.io/) is an open-source identity provider that helps you manage authentication 
and access control for your applications. It acts as a centralized system for securely verifying the identity 
of users before they can access your services. By using Authentik, you can enforce consistent security policies 
across all the software you manage, rather than relying on separate logins for each service.

With Authentik, you can protect your applications using traditional passwords, implement two-factor 
authentication (2FA), or even leverage modern passkey solutions. This includes hardware keys such as YubiKey, 
or software-based passkeys stored in password managers like KeePassXC or Vaultwarden.

Using Authentik adds an extra layer of security and simplifies access management, ensuring that only authorized 
users can reach sensitive applications like the CSF web interface. It can also integrate with middleware to 
enforce access policies without exposing your services to the public internet.

<br />

---

<br />

## Before You Begin

Currently, CSF does not have built-in functionality to detect if your system is protected by an authentication 
service such as [Authentik](https://goauthentik.io/) or [Authelia](https://authelia.com/).

If you choose to put CSF behind Authentik, you will encounter two authentication prompts when accessing the CSF 
web interface:

1. The Authentik sign-in screen
2. CSF’s native login interface

<br />

We are working on a feature that will allow CSF to disable its built-in login system and rely entirely on a 
third-party authentication app. When this is implemented, you will only see a single login screen.

<br />

---

<br />

## Setup

If you are adding [Authentik](https://goauthentik.io/) as middleware in the steps above; the last thing you must 
do is log in to your Authentik admin panel and add a new **Provider** so that we can access the CSF web interface 
via your domain.

<br />

Once you sign into the Authentik admin panel, go to the left-side navigation, select **Applications** › **Providers**.

<br />

<figure markdown="span">
    ![Authentik › Menu › Applications › Providers](https://github.com/user-attachments/assets/8fe1dfc8-bbdc-4c8c-bc5a-be5b103e7404){ width="300" }
    <figcaption>Authentik › Menu › Applications › Providers</figcaption>
</figure>

<br />

Then at the top of the new page, click **Create**.

<br />

<figure markdown="span">
    ![Authentik › Create New Provider](https://github.com/user-attachments/assets/82e3f027-b058-4b3c-86db-bdc4505a4e4e){ width="450" }
    <figcaption>Authentik › Create New Provider</figcaption>
</figure>

<br />

For the **provider**, select `Proxy Provider`.

<br />

<figure markdown="span">
    ![Authentik › New Provider › Proxy Provider](https://github.com/user-attachments/assets/086ae998-964f-45e3-8606-ae8a36ecf82c){ width="450" }
    <figcaption>Authentik › New Provider › Proxy Provider</figcaption>
</figure>

<br />

Add the following provider values:

- Name: `CSF ForwardAuth`
- Authentication Flow: `default-source-authentication (Welcome to authentik!)`
- Authorization Flow: `default-provider-authorization-implicit-consent (Authorize Application)`

<br />

Select **Forward Auth (single application)**:

- External Host: `https://csf.domain.com`

<br />

<figure markdown="span">
    ![Authentik › New Provider › Settings](https://github.com/user-attachments/assets/b1d6258a-f53e-4225-a4e9-9f9b5b69b191){ width="450" }
    <figcaption>Authentik › New Provider › Settings</figcaption>
</figure>

<br />

Once finished, click **Create**. Then on the left-side menu, select **Applications** › **Applications**.

<br />

<figure markdown="span">
    ![Authentik › Menu › Applications › Applications](https://github.com/user-attachments/assets/405fb566-0384-4345-8f07-ad52b9af9358){ width="300" }
    <figcaption>Authentik › Menu › Applications › Applications</figcaption>
</figure>

<br />

Then at the top of the new page, click **Create**.

<br />

<figure markdown="span">
    ![Authentik › Create New App](https://github.com/user-attachments/assets/82e3f027-b058-4b3c-86db-bdc4505a4e4e){ width="450" }
    <figcaption>Authentik › Create New App</figcaption>
</figure>

<br />

Add the following parameters:

- Name: `CSF (ConfigServer Firewall)`
- Slug: `csf`
- Group: `Administrative`
- Provider: `CSF ForwardAuth`
- Backchannel Providers: `None`
- Policy Engine Mode: `any`

<br />

<figure markdown="span">
    ![Authentik › Menu › Applications › Create](https://github.com/user-attachments/assets/11425a7a-f049-4434-a232-3ea2847145d7){ width="450" }
    <figcaption>Authentik › Menu › Applications › Create</figcaption>
</figure>

<br />

Save, and then on the left-side menu, select **Applications** › **Outposts**:

<br />

<figure markdown="span">
    ![Authentik › Menu › Applications › Outposts](https://github.com/user-attachments/assets/cb975af4-d167-44c5-8587-b366aa591716){ width="350" }
    <figcaption>Authentik › Menu › Applications › Outposts</figcaption>
</figure>

<br />

Find your **Outpost** and edit it.

<figure markdown="span">
    ![Authentik › Outposts › Edit](https://github.com/user-attachments/assets/a349423f-6db5-431d-888e-8ba658053b2c){ width="450" }
    <figcaption>Authentik › Outposts › Edit</figcaption>
</figure>

<br />

Move `CSF (ConfigServer Firewall)` to the right side **Selected Applications** box.

<br />

<figure markdown="span">
    ![Authentik › Outposts › Update](https://github.com/user-attachments/assets/b4b882d4-8f41-4af9-b788-cef649a48d24){ width="450" }
    <figcaption>Authentik › Outposts › Update</figcaption>
</figure>

<br />

You should be able to access `csf.domain.com` and be prompted now to authenticate with Authentik.

<br />

---

<br />

## Authentication Types

When CSF is placed behind Authentik, you will be prompted to log in through Authentik to access the CSF web 
interface. The method of login depends on your Authentik configuration. Common authentication types include:

- [Username + password](https://docs.goauthentik.io/users-sources/user/user_basic_operations/)
- [Username + password + secondary authentication (2FA)](https://docs.goauthentik.io/users-sources/user/user_basic_operations/)
- [Passkey (SSO / FIDO2)](https://docs.goauthentik.io/add-secure-apps/flows-stages/stages/authenticator_webauthn/) / [Passwordless Login](https://youtube.com/watch?v=aEpT2fYGwLw)
- [Duo Authentication](https://docs.goauthentik.io/add-secure-apps/flows-stages/stages/authenticator_duo/)
- [Email](https://docs.goauthentik.io/add-secure-apps/flows-stages/stages/authenticator_email/)

<br />

This guide does not cover the full setup of Authentik, as that is outside the scope of CSF. However, there are many 
tutorials and video guides available online that explain the process in detail.

<br />

---

<br />

## Next Steps <!-- omit from toc -->

{==

Select what documentation you would like to proceed with next ...

==}

<div class="grid cards" markdown>

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