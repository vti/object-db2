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
 `title` varchar(40) default ''
) TYPE=innodb;
CREATE TABLE `comments` (
 `id` INTEGER PRIMARY KEY AUTO_INCREMENT,
 `article_id` INTEGER,
 `author_id` INTEGER,
 `content` varchar(40) default ''
) TYPE=innodb;
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
