# Homelab SSO with Keycloak, Grafana, Caddy, and OpenLDAP

This project sets up a single sign-on (SSO) environment with multi-factor authentication (MFA) and LDAP integration using Keycloak, Grafana, Caddy, OpenLDAP, and phpLDAPadmin. Keycloak provides identity management, Grafana serves as an example application with SSO, Caddy acts as a reverse proxy, OpenLDAP is the directory service, and phpLDAPadmin offers a web interface for LDAP management. This setup uses HTTP (not HTTPS) for local testing.


## Prerequisites

- **Docker and docker-compose**: Ensure both are installed on your system.
- **Basic Knowledge**: Familiarity with Docker, SSO, MFA, and LDAP concepts.
- **Required Files**: Place the following in your project directory:
  - `docker-compose.yml`: The provided compose file.
  - `Caddyfile`: Configuration for Caddy reverse proxy (example provided below).
  - `entrypoint.sh`: Script for Grafana to read the Keycloak client secret (example provided below).
  - `secret.txt`: File containing the Keycloak client secret for Grafana.
  - `./ldap/`: Directory with LDIF files for OpenLDAP initialization (example provided below).
- **System Resources**: A machine with sufficient CPU, memory, and storage for Docker containers.
- **Network**: The `localtest.me` domain resolves to `127.0.0.1`, suitable for local testing without hosts file changes.

## Installation Steps

1. **Create the External Network**:
   ```bash
   docker network create reverse_proxy
   ```
   This network is required as it’s marked `external: true` in the compose file.

2. **Prepare Configuration Files**:
   - Ensure `docker-compose.yml` is in your project directory.
   - Create a `Caddyfile` (see example in Configuration section).
   - Create `entrypoint.sh` for Grafana:
     ```bash
     #!/bin/sh
     export GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=$(cat /secrets/client_secret)
     exec /run.sh "$@"
     ```
     Make it executable: `chmod +x entrypoint.sh`.
   - Create `secret.txt` (initially empty; you’ll add the client secret later).
   - Create `./ldap/` directory and add `init.ldif` (see example in LDAP Setup section).

3. **Start the Services**:
   ```bash
   docker-compose up -d
   ```
   This launches Keycloak, Grafana, Caddy, OpenLDAP, and phpLDAPadmin in detached mode.

## Configuration

### Keycloak Setup (SSO and MFA)

1. **Access Keycloak Admin Console**:
   - URL: `http://keycloak.localtest.me` (via Caddy) or `http://localhost:8080` (direct).
   - Login: Username `admin`, Password `admin`.

2. **Create a Realm**:
   - Click "Add Realm", name it `homelab`, and save.

3. **Create a Client for Grafana**:
   - In the `homelab` realm, go to "Clients" -> "Create".
   - Client ID: `grafana`.
   - Client Protocol: `openid-connect`.
   - Access Type: `confidential`.
   - Valid Redirect URIs: `http://grafana.localtest.me/login/generic_oauth`.
   - Root URI / Web Origin: `http://grafana.localtest.me`.
   - Save, then go to the "Credentials" tab and copy the client secret.
   - Feel free to configure according to requirement.

4. **Store the Client Secret**:
   - Open `secret.txt` in your project directory and paste the client secret.
   - Restart Grafana to apply:
     ```bash
     docker-compose restart grafana
     ```

5. **Create User***:
   - Make sure that the current realm reflects the client name created (top left).
   - Go to users and add a new user, do provide name and credentials.


6. **Configure MFA (Optional)**:
   - MFA is configured per user in their account console, not in the admin console.
   - Users can enable MFA by logging into the Keycloak account console (`http://keycloak.localtest.me/realms/homelab/account`), going to "Authenticator", and setting up OTP or WebAuthn.

### Grafana Setup (SSO Integration)

- Grafana is pre-configured in `docker-compose.yml` to use Keycloak for SSO over HTTP.
- After adding the client secret to `secret.txt` and restarting, Grafana will authenticate via Keycloak at `http://grafana.localtest.me`.

### LDAP Setup

1. **Initialize LDAP with LDIF**:
   - Create `./ldap/init.ldif` with the following content to set up organizational units and a user:
     ```ldif
     # Base Organizational Unit: devops
     dn: ou=devops,dc=example,dc=com
     objectClass: organizationalUnit
     ou: devops

     # Base Organizational Unit: appdev
     dn: ou=appdev,dc=example,dc=com
     objectClass: organizationalUnit
     ou: appdev

     # User: amrutha
     dn: cn=amrutha,ou=devops,dc=example,dc=com
     objectClass: inetOrgPerson
     cn: amrutha
     sn: Smith
     uid: amrutha
     userPassword: userpassword
     mail: amrutha@example.com
     ```
   - This file will be mounted into OpenLDAP to initialize the directory.

2. **Access phpLDAPadmin**:
   - URL: `http://localhost:8081` (direct) or configure Caddy for `http://phpldapadmin.localtest.me`.
   - Login DN: `cn=admin,dc=example,dc=com`, Password: `adminpassword`.

3. **Manage LDAP Directory**:
   - Use phpLDAPadmin to add, modify, or delete users and groups.
   - Alternatively, you can add new users and groups with :
     ```bash
     docker exec openldap ldapadd -x -D "cn=admin,dc=example,dc=com" -w adminpassword -f /tmp/add_users.ldif
     ```
   - Verify User is also possible with:
      ```bash
     docker exec openldap ldapsearch -x -b "dc=example,dc=com" -D "cn=admin,dc=example,dc=com" -w adminpassword "(uid=john)"
     ```


4. **Integrate LDAP with Keycloak**:
   - In Keycloak admin console, go to "User Federation" -> "Add provider" -> "ldap".
   - Configure:
     - Vendor: `Active Directory`.
     - Connection URL: `ldap://openldap:389`.
     - Bind DN: `cn=admin,dc=example,dc=com`.
     - Bind Credential: `adminpassword`.
     - Users DN: `ou=devops,dc=example,dc=com` (or other OUs as needed).
     - Username LDAP Attribute: `uid`
     - RDN LDAP Attribute: `cn`
     - UUID LDAP Attrbute: `uid`
     - User Object Classes: `inetOrgPerson, organizationalPerson` 
     - Search scope: `subtree`
   - Save and click "Synchronize all users" to import LDAP users into Keycloak.

### Caddy Configuration

- Ensure your `Caddyfile` routes traffic correctly over HTTP. Example:
  ```caddy
  http://grafana.localtest.me {
    reverse_proxy grafana:3000
  }

  http://keycloak.localtest.me {
    reverse_proxy keycloak:8080
  }

  http://phpldapadmin.localtest.me {
    reverse_proxy phpldapadmin:80
  }
  ```
- Caddy will serve these domains over HTTP for local testing.

## Usage

- **Grafana**: Visit `http://grafana.localtest.me`, log in via Keycloak SSO. If MFA is enabled by the user, complete the additional authentication step.
- **Keycloak Admin**: Manage users and settings at `http://keycloak.localtest.me/`.
- **Keycloak Account Console**: Users manage MFA at `http://keycloak.localtest.me/realms/homelab/account`.
- **phpLDAPadmin**: Manage LDAP at `http://localhost:8081` or `http://phpldapadmin.localtest.me` (if configured in Caddy).
- Data persists across restarts due to named volumes (`keycloak_data`, `grafana_data`, etc.).

## Required Procedures and Notes

- **Security**: For production, replace hardcoded passwords (e.g., `admin`, `adminpassword`, `userpassword`) with secure values, ideally using Docker secrets or a `.env` file.
- **LDIF Files**: Customize `./ldap/init.ldif` to add more users or groups as needed.
- **MFA Configuration**: MFA is managed by individual users in their Keycloak account console, not by the admin. Admins can enforce MFA policies if needed.
- **Troubleshooting**:
  - Check logs: `docker-compose logs <service>`.
  - Ensure `reverse_proxy` network exists and services are connected.
- **Customization**: Adjust environment variables in `docker-compose.yml` for your domain or organization details.
