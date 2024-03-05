# wikijs-mysql-to-postgres

> Ruby script to ease migration of wiki.js database from mysql to postgresql

It is possible that this script will let you clone another databases from mysql to postgresql.
That's why it is being published.

## Quickstart

- install prerequisits e.g. `sudo apt-get -y install ruby ruby-dev libmysqlclient-dev libpq-dev build-essential`
- make script executable `chmod +x ./cloner.rb`
- perform dry ruby to install needed gems: `./cloner.rb` This may take some time.
- copy provided example config and edit to suit your needs: `cp cloner.yml.example cloner.yml && editor cloner.yml`
- run the cloner again `./cloner.rb`
- watch for errors, if there are none, reconfigure wiki to use the new database

> :warning: **Dangerous, but usefull option**: perform truncate on target tables: `./cloner.rb --truncate`

## How to create empty tables for wikijs

```bash
psql -h localhost -U wikijs < wikijs_2.5.301_structure.sql
```

## Prerequisits

- ruby
- gems for database connection (mysql2, pg)
- access to source and destination databases

## How it works

It retrieves foreign keys from the target database, and using tsort it organizes the table names in correct order
not to violate constraints. Then it simply clones the data. Cloning may not be perfect, but is good enough for the purpose.
Thanks to ruby's way of exception handling, no silent data loss should occur.

## Why

Wiki.js has some glitches with uploading larger files, and in combination they are very confusing.
We had several instances running with mysql. Default max upload size of 5MB is ridiculously low.

- there are deprecated options in config file as well as options in admin panel
- the displayed limits in asset manager does not react to changes in admin panel - maybe i18n without interpolation?
- [wiki troubleshooting page](https://docs.requarks.io/en/troubleshooting) states single reason - wrong proxy configuration
- uploading of larger files always fails with mysql, regardles the configuration in admin panel and even in no proxy scenario

However, it seems to be working fine with postgres. So I decided to move the data from mysql to postgres.

After struggling for quite some time with "official" way using `pgloader`, I managed to work around
some issues with [authenticatioin](https://github.com/dimitri/pgloader/issues/782),
[table and column names](https://github.com/dimitri/pgloader/issues/1427). Then the next issue was having
all tables in different namespace, which I resolved by renaming original table to "public".
The last drop was finding out that JSON serialized data are corrupted.

