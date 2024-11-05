# gitlab-proxmox

InfraOps Guide for Gitlab CI/CD Setup with Hetzner + CloudFlare + Proxmox + PfSense + HaProxy

```bash
chmod -R +x ./
```

The “permission denied” error when accessing the Docker daemon socket usually occurs because your current user does not have the necessary permissions to access Docker. To fix this, you can add your user to the Docker group, which grants permission to run Docker commands without needing sudo.

Here’s how to add your user to the Docker group:

    1.	Add User to Docker Group:

Run the following command to add your user to the Docker group:

sudo usermod -aG docker $USER

    2.	Log Out and Log In Again:

You’ll need to log out and log back in (or restart your session) for the group changes to take effect. 3. Verify Docker Access:
After logging back in, run this command to verify that Docker is accessible without sudo:

docker ps

If this runs without issues, you should now be able to execute Docker commands, including the one for running Theila, without encountering a permission error.
