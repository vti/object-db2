PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE `dummies` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT
);
CREATE TABLE `authors` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `name` varchar(40) default '',
 `password` varchar(40) default '',
 UNIQUE(`name`)
);
CREATE TABLE `author_admins` (
 `author_id` INTEGER PRIMARY KEY,
 `beard` varchar(40) default ''
);
CREATE TABLE `articles` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `category_id` INTEGER,
 `author_id` INTEGER,
 `title` varchar(40) default '',
 `special_report_id` INTEGER,
 `main_category_id` INTEGER
);
CREATE TABLE `special_reports` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `title` varchar(40) default '',
 `main_category_id` INTEGER
);
CREATE TABLE `main_categories` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `title` varchar(40) default ''
);
CREATE TABLE `admin_histories` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `main_category_id` INTEGER,
 `from` date default '',
 `till` date default '',
 `admin_name` varchar(40) default ''
);
CREATE TABLE `comments` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `article_id` INTEGER,
 `author_id` INTEGER,
 `content` varchar(40) default '',
 `creation_date` date default '0000-00-00'
);
CREATE TABLE `to_do_articles` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `article_id` INTEGER,
 `to_do` varchar(40) default ''
);
CREATE TABLE `sub_comments` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `comment_id` INTEGER,
 `content` varchar(40) default ''
);
CREATE TABLE `article_tag_maps` (
 `article_id` INTEGER,
 `tag_id` INTEGER,
 PRIMARY KEY(`article_id`, `tag_id`)
);
CREATE TABLE `tags` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `name` varchar(40) default ''
);
CREATE TABLE `nested_comments` (
 `id`          INTEGER PRIMARY KEY AUTOINCREMENT,
 `parent_id`   INTEGER,
 `master_id`   INTEGER NOT NULL,
 `master_type` VARCHAR(20) NOT NULL ,
 `path`        VARCHAR(255),
 `level`       INTEGER NOT NULL ,
 `content`     VARCHAR(1024) NOT NULL,
 `addtime`     INTEGER NOT NULL,
 `lft`         INTEGER NOT NULL,
 `rgt`         INTEGER NOT NULL
);
CREATE TABLE `hotels` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `hotel_num_a` INTEGER,
 `hotel_num_a2` INTEGER,
 `name` varchar(40) default '',
 `city` varchar(40) default '',
 `street` varchar(40) default '',
 `lot_id_1_h` INTEGER,
 `lot_id_2_h` INTEGER,
 UNIQUE(`city`,   `street`), -- add some spaces between comma
 UNIQUE(`name`,`city`)
);
CREATE TABLE `employees` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `hotel_num_b2` INTEGER,
 `first_name` varchar(40) default '',
 `last_name` varchar(40) default ''
);
CREATE TABLE `apartments` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `hotel_num_b` INTEGER,
 `apartment_num_b` INTEGER,
 `image_num_b` INTEGER,
 `name` varchar(40) default '',
 `size` INTEGER
);
CREATE TABLE `images` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `image_num_c` INTEGER,
 `width` INTEGER,
 `height` INTEGER
);
CREATE TABLE `rooms` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `maid_id` INTEGER,
 `hotel_num_c` INTEGER,
 `apartment_num_c` INTEGER,
 `room_num_c` INTEGER,
 `size` INTEGER
);
CREATE TABLE `maids` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `hotel_num_d` INTEGER,
 `apartment_num_c` INTEGER,
 `room_num_d` INTEGER,
 `name` varchar(40) default '',
 `age` INTEGER
);
CREATE TABLE `managers` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `hotel_num_b` INTEGER,
 `manager_num_b` INTEGER,
 `name` varchar(40) default ''
);
CREATE TABLE `parking_lots` (
 `lot_id_1_l` INTEGER,
 `lot_id_2_l` INTEGER,
 `number_of_spots` INTEGER,
 PRIMARY KEY (lot_id_1_l,lot_id_2_l)
);
CREATE TABLE `parking_spots` (
 `spot_id_1` varchar(40),
 `spot_id_2` INTEGER,
 `lot_id_1_s` INTEGER,
 `lot_id_2_s` INTEGER,
 `size` INTEGER,
 PRIMARY KEY (spot_id_1,spot_id_2)
);
CREATE TABLE `offices` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `manager_num_b` INTEGER,
 `size` INTEGER,
 `floor` INTEGER
);
CREATE TABLE `cars` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `manager_num_b` INTEGER,
 `horsepower` INTEGER,
 `brand` varchar(40) default ''
);
CREATE TABLE `secretaries` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `hotel_num_c` INTEGER,
 `manager_num_c` INTEGER,
 `secretary_num_c` INTEGER,
 `first_name` varchar(40) default '',
 `last_name` varchar(40) default ''
);
CREATE TABLE `telefon_numbers` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `hotel_num_c` INTEGER,
 `manager_num_c` INTEGER,
 `tel_num_c` INTEGER,
 `telefon_number` varchar(40) default ''
);
COMMIT;
