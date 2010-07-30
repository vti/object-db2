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
 `content` varchar(40) default ''
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
COMMIT;
