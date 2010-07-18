CREATE TABLE `dummies` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT
);
CREATE TABLE `category` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `authors_id` INTEGER,
 `title` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `articles` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `category_id` INTEGER,
 `authors_id` INTEGER,
 `title` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `comments` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `articles_id` INTEGER,
 `authors_id` INTEGER,
 `content` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `podcast` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `authors_id` INTEGER,
 `title` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `tags` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `name` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `article_tag_maps` (
 `articles_id` INTEGER,
 `tags_id` INTEGER,
 PRIMARY KEY(`articles_id`, `tags_id`)
) TYPE=innodb;
CREATE TABLE `authors` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `name` varchar(40) default '',
 `password` varchar(40) default '',
 UNIQUE(`name`)
) TYPE=innodb;
CREATE TABLE `author_admins` (
 `authors_id` INTEGER PRIMARY KEY,
 `beard` varchar(40) default ''
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
CREATE TABLE `family` (
 `id`          INTEGER PRIMARY KEY AUTO_INCREMENT,
 `parent_id`   INTEGER,
 `name`        VARCHAR(255)
) TYPE=innodb;
