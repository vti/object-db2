CREATE TABLE `dummies` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT
);
CREATE TABLE `authors` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `name` varchar(40) default '',
 `password` varchar(40) default '',
 UNIQUE(`name`)
) TYPE=innodb;
CREATE TABLE `author_admins` (
 `author_id` INTEGER PRIMARY KEY,
 `beard` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `articles` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `category_id` INTEGER,
 `author_id` INTEGER,
 `title` varchar(40) default '',
 `special_report_id` INTEGER,
 `main_category_id` INTEGER
) TYPE=innodb;
CREATE TABLE `special_reports` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `title` varchar(40) default '',
 `main_category_id` INTEGER
)  TYPE=innodb;
CREATE TABLE `main_categories` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `title` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `admin_histories` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `main_category_id` INTEGER,
 `tag_id` INTEGER,
 `from` date default '0000-00-00',
 `till` date default '0000-00-00',
 `admin_name` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `comments` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `article_id` INTEGER,
 `author_id` INTEGER,
 `content` varchar(40) default '',
 `creation_date` date default '0000-00-00'
) TYPE=innodb;
CREATE TABLE `to_do_articles` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `article_id` INTEGER,
 `to_do` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `sub_comments` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `comment_id` INTEGER,
 `content` varchar(40) default ''
);
CREATE TABLE `article_tag_maps` (
 `article_id` INTEGER,
 `tag_id` INTEGER,
 PRIMARY KEY(`article_id`, `tag_id`)
) TYPE=innodb;
CREATE TABLE `tags` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `name` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `nested_comments` (
 `id`          INTEGER PRIMARY KEY AUTO_INCREMENT,
 `parent_id`   INTEGER,
 `master_id`   INTEGER NOT NULL,
 `master_type` VARCHAR(20) NOT NULL ,
 `path`        VARCHAR(255),
 `level`       INTEGER NOT NULL ,
 `content`     VARCHAR(1024) NOT NULL,
 `addtime`     INTEGER NOT NULL,
 `lft`         INTEGER NOT NULL,
 `rgt`         INTEGER NOT NULL
) TYPE=innodb;
CREATE TABLE `category` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `author_id` INTEGER,
 `title` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `podcast` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `author_id` INTEGER,
 `title` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `family` (
 `id`          INTEGER PRIMARY KEY AUTO_INCREMENT,
 `parent_id`   INTEGER,
 `name`        VARCHAR(255)
) TYPE=innodb;
CREATE TABLE `hotels` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `hotel_num_a` INTEGER,
 `hotel_num_a2` INTEGER,
 `name` varchar(40) default '',
 `city` varchar(40) default '',
 `street` varchar(40) default '',
 `lot_id_1_h` INTEGER,
 `lot_id_2_h` INTEGER,
 UNIQUE(`city`,`street`),
 UNIQUE(`name`,`city`)
) TYPE=innodb;
CREATE TABLE `employees` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `hotel_num_b2` INTEGER,
 `first_name` varchar(40) default '',
 `last_name` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `apartments` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `hotel_num_b` INTEGER,
 `apartment_num_b` INTEGER,
 `image_num_b` INTEGER,
 `name` varchar(40) default '',
 `size` INTEGER
) TYPE=innodb;
CREATE TABLE `images` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `image_num_c` INTEGER,
 `width` INTEGER,
 `height` INTEGER
) TYPE=innodb;
CREATE TABLE `rooms` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `maid_id` INTEGER,
 `hotel_num_c` INTEGER,
 `apartment_num_c` INTEGER,
 `room_num_c` INTEGER,
 `size` INTEGER
) TYPE=innodb;
CREATE TABLE `maids` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `hotel_num_d` INTEGER,
 `apartment_num_c` INTEGER,
 `room_num_d` INTEGER,
 `name` varchar(40) default '',
 `age` INTEGER
) TYPE=innodb;
CREATE TABLE `managers` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `hotel_num_b` INTEGER,
 `manager_num_b` INTEGER,
 `name` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `parking_lots` (
 `lot_id_1_l` INTEGER,
 `lot_id_2_l` INTEGER,
 `number_of_spots` INTEGER,
 PRIMARY KEY (lot_id_1_l,lot_id_2_l)
) TYPE=innodb;;
CREATE TABLE `parking_spots` (
 `spot_id_1` varchar(40),
 `spot_id_2` INTEGER,
 `lot_id_1_s` INTEGER,
 `lot_id_2_s` INTEGER,
 `size` INTEGER,
 PRIMARY KEY (spot_id_1,spot_id_2)
) TYPE=innodb;;
CREATE TABLE `offices` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `manager_num_b` INTEGER,
 `size` INTEGER,
 `floor` INTEGER
) TYPE=innodb;
CREATE TABLE `cars` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `manager_num_b` INTEGER,
 `horsepower` INTEGER,
 `brand` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `secretaries` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `hotel_num_c` INTEGER,
 `manager_num_c` INTEGER,
 `secretary_num_c` INTEGER,
 `first_name` varchar(40) default '',
 `last_name` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `telefon_numbers` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `hotel_num_c` INTEGER,
 `manager_num_c` INTEGER,
 `tel_num_c` INTEGER,
 `telefon_number` varchar(40) default ''
);
CREATE TABLE `messages` (
 `sender_id` INTEGER NOT NULL,
 `recipient_id` INTEGER NOT NULL,
 `message` VARCHAR(255) NOT NULL,
 `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE `identificators` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT NOT NULL,
 `name` VARCHAR(255) NOT NULL
);
