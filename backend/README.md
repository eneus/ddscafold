# DDScafold based on Drupal 9

Innovation Technology Projects Management based on Drupal (backend) and ReactJS (frontkend).

### Requirements

- PHP `>= 7.3` (recommend `7.4`)
  - [composer `latest 1.x`](https://getcomposer.org/download/)
  - drush `10.3` (instaled by composer) (https://docs.drush.org/en/8.x/install/#installupgrade-a-global-drush)
- nginx: latest [configuration for Drupal 8/9](https://www.nginx.com/resources/wiki/start/topics/recipes/drupal/)
- Database `MySQL 5.7.29` (percona `5.7`/ MariaDB `10`)

## PHP requirements
### PHP extensions needed
- Database extensions
  -  [PHP Data Objects (PDO)](https://www.drupal.org/node/549702)
  -  [mysql](https://www.php.net/manual/en/ref.mysql.php)
  -  [mysqli](https://www.php.net/manual/en/mysqli.summary.php)
- XML extension
  - [PHP XML extension](https://www.php.net/manual/en/ref.xml.php)
- Image library
  - [GD library](https://www.php.net/gd)
  - [ImageMagick](https://www.imagemagick.org/script/index.php)
- OpenSSL
  -  [PHP OpenSSL](https://php.net/manual/en/book.openssl.php)
- [JSON](https://www.php.net/manual/en/json.installation.php)
- [cURL](https://www.php.net/manual/en/book.curl.php)
- [Mbstring](https://php.net/manual/en/intro.mbstring.php)

#### Memory requirements
PHP memory requirements can vary significantly depending on the modules in use on your site. The minimum required memory size is 64MB.

Warning messages will be shown if the PHP configuration does not meet these requirements. However, while these values may be sufficient for a default Drupal installation, a production site with a number of commonly used modules enabled could require more memory. Typically 128 MB or 256 MB are found in production systems. Some installations may require much more, especially with media-rich implementations. If you are using a hosting service it is important to verify that your host can provide sufficient memory for the set of modules you are deploying or may deploy in the future. 

More detailes [here](https://www.drupal.org/docs/system-requirements/php-requirements)

## Installation
### Step 1
Install drupal 9 core and dependencies:

```
$ git clone git@github.com:eneus/ddscafold.git
$ cd /[PATH]/[TO]/backend/
$ composer install
```
### Step 2
Check drush version (expected `10.3`)

```
$ drush --version
```
### Step 3
Drupal project installation using `cmd`:

```
drush site:install --existing-config --config-dir='../config/sync' --db-url='mysql://[db_user]:[db_pass]@localhost/[db_name]' --account-name=admin --account-pass=admin
```

`--existing-config` - "DDScafold" configurations Project 

`--config-dir='../config/sync'` - sync configuration folder flag

`--db-url='mysql://[db_user]:[db_pass]@localhost/[db_name]'` - database flag with configs line

`--account-name=admin --account-pass=admin` - WEB UI User/Password.

drush site:install --existing-config --config-dir='../config/sync' --db-url='mysql://ddscafold:ddscafold@mysql/ddscafold' --account-name=admin --account-pass=admin

### Create backup by `mysqldump`:
```mysql
mysqldump -uroot -pddscafold -hmysql ddscafold > ./backups/ddscafold.sql
```
