/*
Navicat MySQL Data Transfer

Source Server         : 121.89.220.187
Source Server Version : 50734
Source Host           : 121.89.220.187:3306
Source Database       : petrel_record

Target Server Type    : MYSQL
Target Server Version : 50734
File Encoding         : 65001

Date: 2021-09-02 13:41:10
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for b_admin
-- ----------------------------
DROP TABLE IF EXISTS `b_admin`;
CREATE TABLE `b_admin` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(11) NOT NULL,
  `password` varchar(60) NOT NULL,
  `state` tinyint(4) DEFAULT '1',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Records of b_admin
-- ----------------------------
INSERT INTO `b_admin` VALUES ('1', 'root', '94973d12c7515e1958bd9e3988b60f3e', '1');
INSERT INTO `b_admin` VALUES ('2', 'cs2020', 'e10adc3949ba59abbe56e057f20f883e', '0');
INSERT INTO `b_admin` VALUES ('3', 'cs2222', 'e10adc3949ba59abbe56e057f20f883e', '0');
INSERT INTO `b_admin` VALUES ('4', 'yyqqaa11', '45ab9135539613e53d9fa80a7ac74f97', '0');
INSERT INTO `b_admin` VALUES ('5', 'cf1122', '45ab9135539613e53d9fa80a7ac74f97', '0');
INSERT INTO `b_admin` VALUES ('6', 'yyqqaa22', 'ae3db884edc7b34236248bbf1c9f553e', '0');

-- ----------------------------
-- Table structure for b_admin_role
-- ----------------------------
DROP TABLE IF EXISTS `b_admin_role`;
CREATE TABLE `b_admin_role` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `admin_id` int(11) NOT NULL,
  `role_id` int(11) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Records of b_admin_role
-- ----------------------------
INSERT INTO `b_admin_role` VALUES ('1', '1', '1');
INSERT INTO `b_admin_role` VALUES ('2', '1', '2');
INSERT INTO `b_admin_role` VALUES ('5', '3', '3');
INSERT INTO `b_admin_role` VALUES ('13', '5', '3');
INSERT INTO `b_admin_role` VALUES ('14', '2', '2');
INSERT INTO `b_admin_role` VALUES ('18', '4', '4');
INSERT INTO `b_admin_role` VALUES ('19', '6', '4');

-- ----------------------------
-- Table structure for b_permission
-- ----------------------------
DROP TABLE IF EXISTS `b_permission`;
CREATE TABLE `b_permission` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(11) DEFAULT NULL,
  `type` varchar(20) DEFAULT NULL,
  `menu` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Records of b_permission
-- ----------------------------
INSERT INTO `b_permission` VALUES ('1', '超级管理员', 'ROLE_ADMIN', null);
INSERT INTO `b_permission` VALUES ('2', '所有玩家', 'ROLE_USER', null);
INSERT INTO `b_permission` VALUES ('3', '禁用解禁玩家', 'ROLE_USER_BAN', '2');
INSERT INTO `b_permission` VALUES ('4', '控制', 'ROLE_USER_CONT', '2');
INSERT INTO `b_permission` VALUES ('5', '放控制', 'ROLE_USER_UP', '2');
INSERT INTO `b_permission` VALUES ('6', '特殊控制', 'ROLE_USER_BOUNS', '2');
INSERT INTO `b_permission` VALUES ('7', '上分', 'ROLE_USER_UPGOLD', '2');
INSERT INTO `b_permission` VALUES ('8', '房间系统', 'ROLE_ROOM', null);
INSERT INTO `b_permission` VALUES ('9', '卡系统', 'ROLE_CARD', null);
INSERT INTO `b_permission` VALUES ('10', '统计系统', 'ROLE_STATIS', null);
INSERT INTO `b_permission` VALUES ('11', ' 押注记录半', 'ROLE_USER_PLAYRECORD', '2');
INSERT INTO `b_permission` VALUES ('12', '查看所有玩家', 'ROLE_USER_ALLUSER', '2');
INSERT INTO `b_permission` VALUES ('13', '用户修改', 'ROLE_USER_UPDATE', '2');
INSERT INTO `b_permission` VALUES ('14', '税收调整', 'ROLE_ROOM_SUI', '8');

-- ----------------------------
-- Table structure for b_role
-- ----------------------------
DROP TABLE IF EXISTS `b_role`;
CREATE TABLE `b_role` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(11) DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Records of b_role
-- ----------------------------
INSERT INTO `b_role` VALUES ('1', '超级管理员');
INSERT INTO `b_role` VALUES ('2', '管理员');
INSERT INTO `b_role` VALUES ('3', '普通人');
INSERT INTO `b_role` VALUES ('4', '临时受');

-- ----------------------------
-- Table structure for b_role_permission
-- ----------------------------
DROP TABLE IF EXISTS `b_role_permission`;
CREATE TABLE `b_role_permission` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `role_id` int(5) NOT NULL,
  `permission_id` int(5) NOT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=102 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Records of b_role_permission
-- ----------------------------
INSERT INTO `b_role_permission` VALUES ('1', '1', '1');
INSERT INTO `b_role_permission` VALUES ('64', '3', '2');
INSERT INTO `b_role_permission` VALUES ('65', '3', '11');
INSERT INTO `b_role_permission` VALUES ('91', '4', '3');
INSERT INTO `b_role_permission` VALUES ('92', '4', '4');
INSERT INTO `b_role_permission` VALUES ('93', '4', '11');
INSERT INTO `b_role_permission` VALUES ('94', '4', '12');
INSERT INTO `b_role_permission` VALUES ('95', '2', '2');
INSERT INTO `b_role_permission` VALUES ('96', '2', '3');
INSERT INTO `b_role_permission` VALUES ('97', '2', '4');
INSERT INTO `b_role_permission` VALUES ('98', '2', '11');
INSERT INTO `b_role_permission` VALUES ('99', '2', '12');
INSERT INTO `b_role_permission` VALUES ('100', '2', '13');
INSERT INTO `b_role_permission` VALUES ('101', '2', '9');

-- ----------------------------
-- Table structure for r_card_usestor_record
-- ----------------------------
DROP TABLE IF EXISTS `r_card_usestor_record`;
CREATE TABLE `r_card_usestor_record` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `card_record_id` int(11) NOT NULL COMMENT '记录ID',
  `record_type` smallint(4) NOT NULL COMMENT '0 调拨入库（后台生成卡）  1 平调出库（vip->vip 送卡）  2 平调入库（vip->vip 领卡）  3  消耗出库（vip->普通 送卡） 4  调拨出库(清除卡)',
  `card_stor_id` int(11) NOT NULL COMMENT '库存ID',
  `use_number` int(11) NOT NULL COMMENT '使用数量',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=411335 DEFAULT CHARSET=utf8mb4 COMMENT='记录库存关联表';

-- ----------------------------
-- Records of r_card_usestor_record
-- ----------------------------

-- ----------------------------
-- Table structure for r_inout_lobby
-- ----------------------------
DROP TABLE IF EXISTS `r_inout_lobby`;
CREATE TABLE `r_inout_lobby` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) DEFAULT NULL,
  `mac` varchar(128) DEFAULT NULL,
  `ip` varchar(128) DEFAULT NULL COMMENT '登录IP',
  `devices_type` tinyint(1) DEFAULT NULL COMMENT '设备类型【0-unity 1-android 2-ios 3-windows 4-模拟器】',
  `login_time` timestamp NULL DEFAULT NULL COMMENT '登录时间',
  `out_time` timestamp NULL DEFAULT NULL COMMENT '退出世界',
  `server_id` varchar(64) DEFAULT NULL COMMENT '服务器IP',
  `state` tinyint(1) DEFAULT '1' COMMENT '0表示未完成，1表示已完成【退出】',
  `remark` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `mac` (`mac`)
) ENGINE=InnoDB AUTO_INCREMENT=1301778800450424872 DEFAULT CHARSET=utf8mb4;

-- ----------------------------
-- Records of r_inout_lobby
-- ----------------------------

-- ----------------------------
-- Table structure for r_inout_room
-- ----------------------------
DROP TABLE IF EXISTS `r_inout_room`;
CREATE TABLE `r_inout_room` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `loginout_id` bigint(20) DEFAULT '0',
  `user_id` bigint(20) NOT NULL,
  `game_id` int(11) DEFAULT '0',
  `room_id` int(11) DEFAULT NULL,
  `table_id` int(4) DEFAULT '0' COMMENT '桌子号',
  `seat_no` int(2) DEFAULT '0' COMMENT '座位号',
  `in_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT '进入房间时间',
  `devices_type` tinyint(1) DEFAULT '0' COMMENT '设备类型【0 未知，1，正常手机，2，模拟器，3云手机,】',
  `in_gold_number` bigint(20) DEFAULT '0' COMMENT '进入背包金币',
  `in_bank_number` bigint(20) DEFAULT '0' COMMENT '进入银行数量',
  `play_total` int(11) DEFAULT '0' COMMENT '押注次数',
  `bet_total` bigint(20) DEFAULT '0' COMMENT '押注金额',
  `payment_total` bigint(20) DEFAULT '0' COMMENT 'p赔付数量',
  `max_payment_number` bigint(20) DEFAULT '0',
  `max_payment_multiple` int(11) DEFAULT '0',
  `out_time` timestamp NULL DEFAULT NULL COMMENT '退出房间时间',
  `out_gold_number` bigint(20) DEFAULT '0' COMMENT '退出时 背包金币数量',
  `out_bank_number` bigint(20) DEFAULT '0' COMMENT '退出银行数量',
  `state` tinyint(1) DEFAULT '0' COMMENT '0表示未完成，1表示已完成【退出】',
  `remark` varchar(64) DEFAULT NULL,
  `server_id` varchar(64) DEFAULT NULL COMMENT '服务器IP',
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=135 DEFAULT CHARSET=utf8mb4 COMMENT='进出房间表';

-- ----------------------------
-- Records of r_inout_room
-- ----------------------------

-- ----------------------------
-- Table structure for r_log
-- ----------------------------
DROP TABLE IF EXISTS `r_log`;
CREATE TABLE `r_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `add_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `name` varchar(20) DEFAULT NULL COMMENT '操作账号',
  `operation` int(11) DEFAULT NULL COMMENT '操作模块 【0 登录，1  冻结解冻用户  ，2 修改金币 ， 3 控制  ， 4  其他】',
  `ip` varchar(20) DEFAULT NULL,
  `thing` text COMMENT '做了什么',
  `state` tinyint(4) DEFAULT NULL COMMENT '操作  0 失败  ，1 成功',
  `user_id` bigint(20) DEFAULT NULL,
  `number` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=38723 DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC COMMENT='后台日志';

-- ----------------------------
-- Records of r_log
-- ----------------------------

-- ----------------------------
-- Table structure for r_play_record
-- ----------------------------
DROP TABLE IF EXISTS `r_play_record`;
CREATE TABLE `r_play_record` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `relate_inout_id` bigint(20) DEFAULT '0' COMMENT '关联ID',
  `user_id` bigint(20) DEFAULT NULL,
  `game_id` int(11) DEFAULT NULL,
  `room_id` int(11) DEFAULT '0' COMMENT '房间ID',
  `table_id` tinyint(4) DEFAULT '0',
  `seat_no` tinyint(2) DEFAULT NULL,
  `devices_type` tinyint(1) DEFAULT '0' COMMENT '设备类型【0, 未知，1正常手机，2，模拟器，3，云手机】',
  `blood_balance` bigint(20) DEFAULT '0' COMMENT '血池平衡值',
  `blood_value` bigint(20) DEFAULT '0' COMMENT '血池值',
  `bet_array` varchar(128) DEFAULT NULL,
  `bet_number` int(11) DEFAULT '0' COMMENT '押注金额',
  `payment_number` int(11) DEFAULT '0' COMMENT '赔付',
  `payment_times` int(11) DEFAULT '0' COMMENT '倍数',
  `strategy_type` tinyint(2) DEFAULT '0' COMMENT '策略类型【1, 血池， 2，小波， 3大波，4，天花板， 5，最大次数，6，个控，7，房间空，8 VIP控】',
  `roller_id` int(11) DEFAULT NULL COMMENT '卷轴ID【没有则是 -1】',
  `control_type` tinyint(4) DEFAULT '0' COMMENT '控制类型【0普通，1大奖，2免费，3特殊，4jack】',
  `win_type` tinyint(1) DEFAULT '0' COMMENT '0: 没有； 1，免费， 2， 特殊，3，jackpot',
  `icon_result` varchar(512) DEFAULT NULL COMMENT '押注返回图标',
  `banker_result` varchar(512) DEFAULT NULL,
  `after_gold_num` bigint(20) DEFAULT NULL COMMENT '压住前_背包数量',
  `after_bank_num` bigint(20) DEFAULT NULL COMMENT '压住前_银行数量',
  `after_award` int(11) DEFAULT NULL COMMENT '返奖率',
  `add_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `relate_inout_id` (`relate_inout_id`)
) ENGINE=InnoDB AUTO_INCREMENT=18967 DEFAULT CHARSET=utf8mb4 COMMENT='押注记录';

-- ----------------------------
-- Records of r_play_record
-- ----------------------------

-- ----------------------------
-- Table structure for s_daily_tran_card
-- ----------------------------
DROP TABLE IF EXISTS `s_daily_tran_card`;
CREATE TABLE `s_daily_tran_card` (
  `id` int(8) NOT NULL,
  `from_gold` bigint(20) DEFAULT '0',
  `to_gold` bigint(20) DEFAULT '0',
  `user_num` int(11) DEFAULT '0',
  `num` int(11) DEFAULT '0',
  `card_num` int(11) DEFAULT '0',
  `card_gold` bigint(20) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------
-- Records of s_daily_tran_card
-- ----------------------------

-- ----------------------------
-- Table structure for s_gold_total
-- ----------------------------
DROP TABLE IF EXISTS `s_gold_total`;
CREATE TABLE `s_gold_total` (
  `id` bigint(20) NOT NULL,
  `up_gold` bigint(20) DEFAULT '0' COMMENT '后台上分',
  `all_gold` bigint(20) DEFAULT '0' COMMENT '今日总金币',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Records of s_gold_total
-- ----------------------------

-- ----------------------------
-- Table structure for s_online
-- ----------------------------
DROP TABLE IF EXISTS `s_online`;
CREATE TABLE `s_online` (
  `id` bigint(20) NOT NULL,
  `online` int(6) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----------------------------
-- Records of s_online
-- ----------------------------
