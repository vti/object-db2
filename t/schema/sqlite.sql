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
 `authors_id` INTEGER PRIMARY KEY,
 `beard` varchar(40) default ''
);
CREATE TABLE `articles` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `category_id` INTEGER,
 `authors_id` INTEGER,
 `title` varchar(40) default ''
);
CREATE TABLE `article_tag_maps` (
 `articles_id` INTEGER,
 `tags_id` INTEGER,
 PRIMARY KEY(`articles_id`, `tags_id`)
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
