-- Xiandao (仙道) - MySQL Database Initialization
-- This script creates the database schema for the Xiandao game server.
-- Version: 1.0.0
--
-- Usage:
--   mysql -u root -p < doc/mysql-init.sql
--
-- Or import directly:
--   mysql -u root -p
--   mysql> source /path/to/doc/mysql-init.sql;

-- Set character set
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS `xd01`
DEFAULT CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE `xd01`;

-- --------------------------------------------------------
-- Table: admin
-- --------------------------------------------------------
DROP TABLE IF EXISTS `admin`;
CREATE TABLE `admin` (
  `admin_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `account` varchar(200) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `password` varchar(200) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `channel_id` bigint(20) DEFAULT NULL,
  `channel_purview` char(1) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `data_purview` char(1) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `info_purview` char(1) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `system_purview` char(1) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `other_purview` char(1) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `question_purview` char(1) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `shop_purview` char(1) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `integral_purview` char(1) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `honor_purview` char(1) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  `wealth_purview` char(1) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  PRIMARY KEY (`admin_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------
-- Table: channel
-- --------------------------------------------------------
DROP TABLE IF EXISTS `channel`;
CREATE TABLE `channel` (
  `channel_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `channel_name` varchar(40) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci DEFAULT NULL,
  PRIMARY KEY (`channel_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------
-- Table: daily_data_count
-- --------------------------------------------------------
DROP TABLE IF EXISTS `daily_data_count`;
CREATE TABLE `daily_data_count` (
  `idx` bigint(20) NOT NULL AUTO_INCREMENT,
  `create_time` datetime DEFAULT NULL,
  `register_amount` int(11) DEFAULT NULL,
  `real_register_amount` int(11) DEFAULT NULL,
  `login_amount` int(11) DEFAULT NULL,
  `payusr_amount` int(11) DEFAULT NULL,
  `new_payusr_amount` int(11) DEFAULT NULL,
  `pay_percent` float(10,0) DEFAULT NULL,
  `payvalue_amount` int(11) DEFAULT NULL,
  `payusr_arpu` float(10,0) DEFAULT NULL,
  `register_arpu` float(10,0) DEFAULT NULL,
  `all_register` int(11) DEFAULT NULL,
  `all_real_register` int(11) DEFAULT NULL,
  `area` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------
-- Table: daoju_record
-- --------------------------------------------------------
DROP TABLE IF EXISTS `daoju_record`;
CREATE TABLE `daoju_record` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `item_id` varchar(100) DEFAULT NULL,
  `item_name` varchar(200) DEFAULT NULL,
  `amount` int(11) DEFAULT NULL,
  `player_id` varchar(100) DEFAULT NULL,
  `player_name` varchar(200) DEFAULT NULL,
  `reason` varchar(500) DEFAULT NULL,
  `create_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------
-- Table: day_usr_logined_record
-- --------------------------------------------------------
DROP TABLE IF EXISTS `day_usr_logined_record`;
CREATE TABLE `day_usr_logined_record` (
  `idx` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` varchar(100) DEFAULT NULL,
  `user_name` varchar(200) DEFAULT NULL,
  `login_date` date DEFAULT NULL,
  `channel` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`idx`),
  UNIQUE KEY `user_login_date` (`user_id`,`login_date`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------
-- Table: fee_record
-- --------------------------------------------------------
DROP TABLE IF EXISTS `fee_record`;
CREATE TABLE `fee_record` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` varchar(100) DEFAULT NULL,
  `user_name` varchar(200) DEFAULT NULL,
  `fee_amount` int(11) DEFAULT NULL,
  `fee_type` varchar(50) DEFAULT NULL,
  `create_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------
-- Table: gold_dairy
-- --------------------------------------------------------
DROP TABLE IF EXISTS `gold_dairy`;
CREATE TABLE `gold_dairy` (
  `idx` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` varchar(100) DEFAULT NULL,
  `user_name` varchar(200) DEFAULT NULL,
  `gold_amount` int(11) DEFAULT NULL,
  `reason` varchar(500) DEFAULT NULL,
  `create_time` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------
-- Table: gold_record
-- --------------------------------------------------------
DROP TABLE IF EXISTS `gold_record`;
CREATE TABLE `gold_record` (
  `idx` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` varchar(100) DEFAULT NULL,
  `user_name` varchar(200) DEFAULT NULL,
  `gold_amount` int(11) DEFAULT NULL,
  `reason` varchar(500) DEFAULT NULL,
  `create_time` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------
-- Table: newbie_pay_record
-- --------------------------------------------------------
DROP TABLE IF EXISTS `newbie_pay_record`;
CREATE TABLE `newbie_pay_record` (
  `idx` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` varchar(100) DEFAULT NULL,
  `user_name` varchar(200) DEFAULT NULL,
  `amount` int(11) DEFAULT NULL,
  `pay_time` datetime DEFAULT NULL,
  `is_newbie` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------
-- Table: online_amount_record
-- --------------------------------------------------------
DROP TABLE IF EXISTS `online_amount_record`;
CREATE TABLE `online_amount_record` (
  `idx` bigint(20) NOT NULL AUTO_INCREMENT,
  `area` varchar(20) DEFAULT NULL,
  `online_count` int(11) DEFAULT NULL,
  `create_time` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------
-- Table: online_data
-- --------------------------------------------------------
DROP TABLE IF EXISTS `online_data`;
CREATE TABLE `online_data` (
  `idx` bigint(20) NOT NULL AUTO_INCREMENT,
  `area` varchar(20) DEFAULT NULL,
  `online_count` int(11) DEFAULT NULL,
  `create_time` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------
-- Table: pay_record
-- --------------------------------------------------------
DROP TABLE IF EXISTS `pay_record`;
CREATE TABLE `pay_record` (
  `idx` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` varchar(100) DEFAULT NULL,
  `user_name` varchar(200) DEFAULT NULL,
  `amount` int(11) DEFAULT NULL,
  `pay_time` datetime DEFAULT NULL,
  `channel` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------
-- Table: pv_record
-- --------------------------------------------------------
DROP TABLE IF EXISTS `pv_record`;
CREATE TABLE `pv_record` (
  `idx` bigint(20) NOT NULL AUTO_INCREMENT,
  `area` varchar(20) DEFAULT NULL,
  `pv_count` bigint(20) DEFAULT NULL,
  `create_time` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------
-- Table: result_info
-- --------------------------------------------------------
DROP TABLE IF EXISTS `result_info`;
CREATE TABLE `result_info` (
  `idx` bigint(20) NOT NULL AUTO_INCREMENT,
  `info` varchar(500) DEFAULT NULL,
  `create_time` datetime DEFAULT NULL,
  PRIMARY KEY (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- --------------------------------------------------------
-- Database User for Docker Container
-- --------------------------------------------------------
-- Credential-bearing user provisioning is intentionally omitted.
-- Run scripts/setup-mysql-docker-access.sh with MYSQL_PASSWORD supplied
-- through the protected deployment environment.

-- --------------------------------------------------------
-- Verification
-- --------------------------------------------------------
SELECT 'Database created successfully!' AS Status;
SHOW DATABASES LIKE 'xd01';
SELECT user, host FROM mysql.user WHERE user='xiandao';
