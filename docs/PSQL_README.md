The issue with the <version> placeholder arises because you need to use the actual PostgreSQL version installed on your LXC. Here’s how to correctly locate and edit the PostgreSQL configuration files:

1. Find the Installed PostgreSQL Version

To identify the version installed on your system:

psql --version

This will output something like:

psql (PostgreSQL) 14.5

The version here is 14.

2. Locate the Configuration Directory

PostgreSQL configuration files are typically located in /etc/postgresql/<version>/main/. Replace <version> with the version number (e.g., 14).

List the available directories:

ls /etc/postgresql

If version 14 is installed, the configuration directory will be:

/etc/postgresql/14/main/

3. Edit PostgreSQL Configuration Files

Edit postgresql.conf

    1.	Open the file:

nano /etc/postgresql/14/main/postgresql.conf

    2.	Find and update the listen_addresses setting:

listen_addresses = '\*'

This allows PostgreSQL to accept connections from any IP address.

    3.	Save and exit (CTRL+O, Enter, CTRL+X).

Edit pg_hba.conf

    1.	Open the file:

nano /etc/postgresql/14/main/pg_hba.conf

    2.	Add the following line at the end to allow connections from the Bytebase LXC’s IP range:

host all all 192.168.1.0/24 md5

Replace 192.168.1.0/24 with the subnet of your network if it’s different.

    3.	Save and exit.

4. Restart PostgreSQL

Restart PostgreSQL to apply the changes:

systemctl restart postgresql

5. Verify the Configuration

   1. Check that PostgreSQL is now listening on the correct address:

netstat -tuln | grep 5432

You should see something like:

tcp 0 0 0.0.0.0:5432 0.0.0.0:\* LISTEN

    2.	Test connectivity to the database from Bytebase or another host on the same network:

psql -h <postgresql-lxc-ip> -U postgres

Replace <postgresql-lxc-ip> with the actual IP of the PostgreSQL LXC.

Let me know if you encounter any issues or need further assistance!
