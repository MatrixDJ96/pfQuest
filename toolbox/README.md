# pfQuest-toolbox

## Setup Dependencies

### Archlinux

    # pacman -S mariadb mariadb-clients luarocks
    # mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
    # systemctl start mariadb
    # luarocks install luasql-mysql MYSQL_INCDIR=/usr/include/mysql

## Prepare Databases

The pfQuest extractor supports VMaNGOS and CMaNGOS databases. By default, VMaNGOS is used vanilla and CMaNGOS is used for TBC. For CMaNGOS translations, the Mangos-Extras project is used.

### Create Users And Permissions

    mysql -u root -p"vagrant" < prepare.sql

### Import Client Data

Import the game client data SQL files:

    mysql -u mangos -p"mangos" pfquest < client-data.sql

### Vanilla (VMaNGOS)

Manually download the latest [VMaNGOS Database](https://github.com/vmangos/core/releases/tag/db_latest) and unzip it.

    mysql -u mangos -p"mangos" vmangos < mangos.sql

    cd core/sql/migrations
    for file in *_world.sql; do mysql -u mangos -p"mangos" vmangos < $file; done
    cd -

    mysql -u mangos -p"mangos" vmangos < entries.sql

    cd core/sql/translations/ptBR

    sed -i 's/`name`/`name_loc10`/g' *.sql
    sed -i 's/`subname`/`subname_loc10`/g' *.sql
    sed -i 's/`description`/`description_loc10`/g' *.sql
    sed -i 's/`Title`/`Title_loc10`/g' *.sql
    sed -i 's/`Details`/`Details_loc10`/g' *.sql
    sed -i 's/`Objectives`/`Objectives_loc10`/g' *.sql
    sed -i 's/`ObjectiveText1`/`ObjectiveText1_loc10`/g' *.sql
    sed -i 's/`ObjectiveText2`/`ObjectiveText2_loc10`/g' *.sql
    sed -i 's/`ObjectiveText3`/`ObjectiveText3_loc10`/g' *.sql
    sed -i 's/`ObjectiveText4`/`ObjectiveText4_loc10`/g' *.sql
    sed -i 's/`OfferRewardText`/`OfferRewardText_loc10`/g' *.sql
    sed -i 's/`RequestItemsText`/`RequestItemsText_loc10`/g' *.sql
    sed -i 's/`EndText`/`EndText_loc10`/g' *.sql

    sed -i 's/`creature_template`/`locales_creature`/' *.sql
    sed -i 's/`gameobject_template`/`locales_gameobject`/' *.sql
    sed -i 's/`item_template`/`locales_item`/' *.sql
    sed -i 's/`quest_template`/`locales_quest`/' *.sql

    mysql -u mangos -p"mangos" vmangos < creature_template.sql
    mysql -u mangos -p"mangos" vmangos < gameobject_template.sql
    mysql -u mangos -p"mangos" vmangos < item_template.sql
    mysql -u mangos -p"mangos" vmangos < quest_template.sql

    cd -

    cd database/Translations/Translations/Italian

    mysql -u mangos -p"mangos" vmangos < Italian_Creature.sql
    mysql -u mangos -p"mangos" vmangos < Italian_Gameobject.sql
    mysql -u mangos -p"mangos" vmangos < Italian_Items.sql
    mysql -u mangos -p"mangos" vmangos < Italian_Quest.sql

    cd -

## Optimize Database Performance

    mysql -u root -p"vagrant" < optimize.sql

## Run the Extractor

Start the database extractor

    make
