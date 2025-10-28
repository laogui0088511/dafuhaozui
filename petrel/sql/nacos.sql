/*
Navicat MySQL Data Transfer

Source Server         : 121.89.220.187
Source Server Version : 50734
Source Host           : 121.89.220.187:3306
Source Database       : nacos

Target Server Type    : MYSQL
Target Server Version : 50734
File Encoding         : 65001

Date: 2021-09-02 13:39:41
*/

SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for config_info
-- ----------------------------
DROP TABLE IF EXISTS `config_info`;
CREATE TABLE `config_info` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'id',
  `data_id` varchar(255) COLLATE utf8_bin NOT NULL COMMENT 'data_id',
  `group_id` varchar(255) COLLATE utf8_bin DEFAULT NULL,
  `content` longtext COLLATE utf8_bin NOT NULL COMMENT 'content',
  `md5` varchar(32) COLLATE utf8_bin DEFAULT NULL COMMENT 'md5',
  `gmt_create` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `gmt_modified` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '修改时间',
  `src_user` text COLLATE utf8_bin COMMENT 'source user',
  `src_ip` varchar(20) COLLATE utf8_bin DEFAULT NULL COMMENT 'source ip',
  `app_name` varchar(128) COLLATE utf8_bin DEFAULT NULL,
  `tenant_id` varchar(128) COLLATE utf8_bin DEFAULT '' COMMENT '租户字段',
  `c_desc` varchar(256) COLLATE utf8_bin DEFAULT NULL,
  `c_use` varchar(64) COLLATE utf8_bin DEFAULT NULL,
  `effect` varchar(64) COLLATE utf8_bin DEFAULT NULL,
  `type` varchar(64) COLLATE utf8_bin DEFAULT NULL,
  `c_schema` text COLLATE utf8_bin,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_configinfo_datagrouptenant` (`data_id`,`group_id`,`tenant_id`)
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='config_info';

-- ----------------------------
-- Records of config_info
-- ----------------------------
INSERT INTO `config_info` VALUES ('8', 'nacos-payment-provider.yaml', 'DEFAULT_GROUP', 0x757365723A0D0A202020206E616D653A204445565F4445560D0A202020206167653A2031, '08a12c5f72393f8f4a68dbbdcdaaea55', '2020-10-07 05:27:56', '2020-10-07 05:27:56', null, '0:0:0:0:0:0:0:1', '', '0ec4577c-dbf8-49e0-8bef-adf2e80aa837', null, null, null, 'yaml', null);
INSERT INTO `config_info` VALUES ('9', 'data-config.yaml', 'DEFAULT_GROUP', 0x6D7973716C3A0D0A2075726C3A206D7973716C2E75726C2D30360D0A72656469733A0D0A202069703A2072656469732E69702D3032, 'a40ba6372d23c97c4cb92984ee5d62c3', '2020-10-07 05:55:03', '2020-10-20 05:54:37', null, '0:0:0:0:0:0:0:1', '', '0ec4577c-dbf8-49e0-8bef-adf2e80aa837', '', '', '', 'yaml', '');
INSERT INTO `config_info` VALUES ('10', 'definition-config.yaml', 'DEFAULT_GROUP', 0x6465663A0D0A20636F6E6669672D613A20636F6E6669672D612D30310D0A20636F6E6669672D623A20636F6E6669672D622D3031, 'f9919588166c5321ec784215c363cfb8', '2020-10-07 06:04:19', '2020-10-07 06:14:16', null, '0:0:0:0:0:0:0:1', '', '0ec4577c-dbf8-49e0-8bef-adf2e80aa837', '', '', '', 'yaml', '');
INSERT INTO `config_info` VALUES ('29', 'petrel-lobby-user-config.yaml', 'DEFAULT_GROUP', 0x6769643A0D0A2020206C656E3A20380D0A20202073746172743A20300D0A757365723A0D0A2020202320E6B3A8E5868CE98081E98791E5B8810D0A20202072656769737465722D6E756D6265723A20300D0A736D733A200D0A2020202075726C3A20687474703A2F2F61706930312E6D6F6E79756E2E636E3A373930312F736D732F76322F7374642F73696E676C655F73656E640D0A202020206170696B65793A2066376361343933656638363661316532643430313761383836356231633765330D0A7369676E3A0D0A20202020706C6179733A203230300D0A20202020646179732D68616C663A2031340D0A20202020646179733A2032380D0A20202020676F6C643A2031350D0A2020202068616C663A2033300D0A20202020616C6C3A203630, '991bedcea14afd284350b1958080b54f', '2020-11-07 02:50:07', '2021-05-14 09:48:35', null, '154.202.60.18', '', '', '', '', '', 'yaml', '');
INSERT INTO `config_info` VALUES ('34', 'petrel-game-config.yaml', 'DEFAULT_GROUP', 0x686F73743A0D0A20202075726C3A20687474703A2F2F70697A322D75702E73646963616C6761652E636E2F7963645F7570646174652F0D0A77783A0D0A20202069643A20777869645F76616C75650D0A2020207365637265743A2077785365637265745F76616C75650D0A6C6F6262793A0D0A20202076657273696F6E3A20330D0A2020207666783A20594344, '6bc355d8825c0bd87953f78a5be33855', '2020-12-03 15:13:20', '2021-07-13 03:42:35', null, '101.204.219.199', '', '', '', '', '', 'yaml', '');
INSERT INTO `config_info` VALUES ('39', 'petrel-strategy-config.yaml', 'DEFAULT_GROUP', 0x6365696C696E673A0D0A20206C6173742D646966662D74696D65733A20305F33307C31303B33305F35307C33303B35305F2D317C3530300D0A20206D756C7469706C653A20332D350D0A202066697865643A203135300D0A2020636172642D72616E67653A2035302D3230300D0A73747261746567793A0D0A202063686561743A2031303030300D0A20206C6F73652D613A20302E35330D0A20206C6F73652D623A20302E30303030313531350D0A2020706C61792D74696D65733A203830302D313030302D313330300D0A6A61636B706F72743A0D0A202023E68EA8E98081E697B6E997B420E7A7920D0A2020707573682D74696D653A20360D0A202023E79C9FE5A596E6B1A0E9858DE7BDAE0D0A20207265616C3A0D0A2020202023E8BF94E5A596E78E87E99990E588B62020E4BD8EE4BA8EE5A1ABE585A5E580BC0D0A2020202061776172642D72657374726963743A20313030300D0A2020202023E6B8B8E6888FE8AEB0E5BD95E99990E588B62020E4BD8EE4BA8EE5A1ABE585A5E580BC0D0A20202020706C61792D746F74616C2D72657374726963743A203230300D0A636F6D6D6F6E3A0D0A2020726F6C6C65723A0D0A2020202075726C3A20687474703A2F2F3232322E3138362E3137302E35373A383535352F636866732F7368617265642F6A61766120202020, 'e8e43a9db0dd8ee654991ce1874e172f', '2020-12-08 10:11:03', '2021-01-12 08:03:32', null, '101.204.30.201', '', '', '', '', '', 'yaml', '');
INSERT INTO `config_info` VALUES ('40', 'petrel-lobby-gold-config.yaml', 'DEFAULT_GROUP', 0x2320E8BDACE8B4A6E79BB8E585B30D0A676F6C643A0D0A2020202023E8BDACE8B4A6E58A9FE883BDE5BC80E585B32030E585B3E997AD202031E68993E5BC800D0A202020207472616E736665723A20310D0A2020202023E6898BE7BBADE8B4B9E6AF94E4BE8B0D0A202020207472612D7072653A20320D0A2020202023E6898BE7BBADE8B4B9E9A286E58F96E6AF94E4BE8B0D0A202020207472612D726563656976652D7072653A203130300D0A2020202023E699AEE9809AE794A8E688B7E8BDACE8B4A6202030E585B3E997AD202031E68993E5BC800D0A202020206E6F722D7472613A20300D0A2020202023E699AEE9809AE794A8E688B7E8BDACE8B4A6E69C80E5B08FE580BC0D0A202020206E6F722D6D696E3A20313635303030300D0A2020202023564950E8BDACE8B4A6E8BDACE8B4A6E69C80E5B08FE580BC0D0A202020207669702D6D696E3A2031303030300D0A2020202023E998B2E58092E58886E98791E9A29D0D0A202020206D61782D686F6C642D676F6C643A203130303030300D0A202020202323766970E7A681E6ADA2E4BA92E79BB8E8BDACE8B4A62020E4BE8B3A3920202876697039E4B98BE997B4E4B88DE883BDE79BB8E4BA92E8BDAC2920E4BE8B3A382C3920202839E5928C392C38E5928C382C38E5928C39E4B98BE997B4E4B88DE883BDE79BB8E4BA92E8BDAC290D0A20202020766970327669703A20390D0A2020202023E58581E8AEB8E4BFAEE694B9E4B88AE5AEB6EFBC8CE5AE9AE59091E8BDACE8B4A620203020E4B88DE58581E8AEB8E4BFAEE694B9203120E58581E8AEB8E4BFAEE694B90D0A202020206368616E67652D7669703A20310D0A20202020233020676964E5A4B4E79BB8E5908C20EFBC8C3120E883BDE587BA20EFBC8C3220E883BDE8BF9B20EFBC8C3320E883BDE4BA92E8BDACEFBC88E9BB98E8AEA4E4B88DE883BDE4BA92E8BDACEFBC892020E4BE8BEFBC9A302C312C330D0A20202020766970373A20302C310D0A2320E98081E58DA1E79BB8E585B30D0A636172643A0D0A2020202023E98791E5B881E99990E588B60D0A20202020676F6C642D72657374726963743A203130303030300D0A2020202023E99990E588B6E98081E699AEE9809AE78EA9E5AEB6E58D95E6ACA1E98081E58DA1E695B0E9878F0D0A202020206F6E63652D70726573656E743A20310D0A2020202023E99990E588B6E6A8A1E68B9FE599A8E4B88DE883BDE98081E58DA1206D6163E4B8BA3030E5BC80E5A4B40D0A2020202073696D756C61746F722D72657374726963743A20310D0A2020202023E69CAAE7BB91E5AE9AE6898BE69CBAE4B88DE883BDE98081E58DA10D0A202020206E6F742D74656C3A20300D0A2020202023E6B2A1E69C89E8BDACE585A5E8AEB0E5BD95E4B88DE883BDE98081E58DA10D0A202020206E6F742D696E2D7472616E736665723A20300D0A2020202023E6B8B8E6888FE59CBAE695B0E99990E588B620E5A1ABE695B0E9878F0D0A20202020706C61792D72657374726963743A20300D0A2020202023766970E6AF8FE5A4A9E98081E58DA1E99990E588B620E99288E5AFB9766970E98081E699AEE9809A20E5A1ABE695B0E9878F0D0A202020207669702D70726573656E743A203130300D0A2020202023E7A681E6ADA2766970E980817669700D0A202020207669702D6E6F742D7669703A2031, '7a7c0afdef33eb91b1326f9014091915', '2020-12-15 01:45:00', '2021-04-21 05:26:10', null, '175.154.141.13', '', '', '', '', '', 'yaml', '');

-- ----------------------------
-- Table structure for config_info_aggr
-- ----------------------------
DROP TABLE IF EXISTS `config_info_aggr`;
CREATE TABLE `config_info_aggr` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'id',
  `data_id` varchar(255) COLLATE utf8_bin NOT NULL COMMENT 'data_id',
  `group_id` varchar(255) COLLATE utf8_bin NOT NULL COMMENT 'group_id',
  `datum_id` varchar(255) COLLATE utf8_bin NOT NULL COMMENT 'datum_id',
  `content` longtext COLLATE utf8_bin NOT NULL COMMENT '内容',
  `gmt_modified` datetime NOT NULL COMMENT '修改时间',
  `app_name` varchar(128) COLLATE utf8_bin DEFAULT NULL,
  `tenant_id` varchar(128) COLLATE utf8_bin DEFAULT '' COMMENT '租户字段',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_configinfoaggr_datagrouptenantdatum` (`data_id`,`group_id`,`tenant_id`,`datum_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='增加租户字段';

-- ----------------------------
-- Records of config_info_aggr
-- ----------------------------

-- ----------------------------
-- Table structure for config_info_beta
-- ----------------------------
DROP TABLE IF EXISTS `config_info_beta`;
CREATE TABLE `config_info_beta` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'id',
  `data_id` varchar(255) COLLATE utf8_bin NOT NULL COMMENT 'data_id',
  `group_id` varchar(128) COLLATE utf8_bin NOT NULL COMMENT 'group_id',
  `app_name` varchar(128) COLLATE utf8_bin DEFAULT NULL COMMENT 'app_name',
  `content` longtext COLLATE utf8_bin NOT NULL COMMENT 'content',
  `beta_ips` varchar(1024) COLLATE utf8_bin DEFAULT NULL COMMENT 'betaIps',
  `md5` varchar(32) COLLATE utf8_bin DEFAULT NULL COMMENT 'md5',
  `gmt_create` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `gmt_modified` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '修改时间',
  `src_user` text COLLATE utf8_bin COMMENT 'source user',
  `src_ip` varchar(20) COLLATE utf8_bin DEFAULT NULL COMMENT 'source ip',
  `tenant_id` varchar(128) COLLATE utf8_bin DEFAULT '' COMMENT '租户字段',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_configinfobeta_datagrouptenant` (`data_id`,`group_id`,`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='config_info_beta';

-- ----------------------------
-- Records of config_info_beta
-- ----------------------------

-- ----------------------------
-- Table structure for config_info_tag
-- ----------------------------
DROP TABLE IF EXISTS `config_info_tag`;
CREATE TABLE `config_info_tag` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'id',
  `data_id` varchar(255) COLLATE utf8_bin NOT NULL COMMENT 'data_id',
  `group_id` varchar(128) COLLATE utf8_bin NOT NULL COMMENT 'group_id',
  `tenant_id` varchar(128) COLLATE utf8_bin DEFAULT '' COMMENT 'tenant_id',
  `tag_id` varchar(128) COLLATE utf8_bin NOT NULL COMMENT 'tag_id',
  `app_name` varchar(128) COLLATE utf8_bin DEFAULT NULL COMMENT 'app_name',
  `content` longtext COLLATE utf8_bin NOT NULL COMMENT 'content',
  `md5` varchar(32) COLLATE utf8_bin DEFAULT NULL COMMENT 'md5',
  `gmt_create` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `gmt_modified` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '修改时间',
  `src_user` text COLLATE utf8_bin COMMENT 'source user',
  `src_ip` varchar(20) COLLATE utf8_bin DEFAULT NULL COMMENT 'source ip',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_configinfotag_datagrouptenanttag` (`data_id`,`group_id`,`tenant_id`,`tag_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='config_info_tag';

-- ----------------------------
-- Records of config_info_tag
-- ----------------------------

-- ----------------------------
-- Table structure for config_tags_relation
-- ----------------------------
DROP TABLE IF EXISTS `config_tags_relation`;
CREATE TABLE `config_tags_relation` (
  `id` bigint(20) NOT NULL COMMENT 'id',
  `tag_name` varchar(128) COLLATE utf8_bin NOT NULL COMMENT 'tag_name',
  `tag_type` varchar(64) COLLATE utf8_bin DEFAULT NULL COMMENT 'tag_type',
  `data_id` varchar(255) COLLATE utf8_bin NOT NULL COMMENT 'data_id',
  `group_id` varchar(128) COLLATE utf8_bin NOT NULL COMMENT 'group_id',
  `tenant_id` varchar(128) COLLATE utf8_bin DEFAULT '' COMMENT 'tenant_id',
  `nid` bigint(20) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`nid`),
  UNIQUE KEY `uk_configtagrelation_configidtag` (`id`,`tag_name`,`tag_type`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='config_tag_relation';

-- ----------------------------
-- Records of config_tags_relation
-- ----------------------------

-- ----------------------------
-- Table structure for group_capacity
-- ----------------------------
DROP TABLE IF EXISTS `group_capacity`;
CREATE TABLE `group_capacity` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `group_id` varchar(128) COLLATE utf8_bin NOT NULL DEFAULT '' COMMENT 'Group ID，空字符表示整个集群',
  `quota` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '配额，0表示使用默认值',
  `usage` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '使用量',
  `max_size` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '单个配置大小上限，单位为字节，0表示使用默认值',
  `max_aggr_count` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '聚合子配置最大个数，，0表示使用默认值',
  `max_aggr_size` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '单个聚合数据的子配置大小上限，单位为字节，0表示使用默认值',
  `max_history_count` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '最大变更历史数量',
  `gmt_create` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `gmt_modified` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '修改时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_group_id` (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='集群、各Group容量信息表';

-- ----------------------------
-- Records of group_capacity
-- ----------------------------

-- ----------------------------
-- Table structure for his_config_info
-- ----------------------------
DROP TABLE IF EXISTS `his_config_info`;
CREATE TABLE `his_config_info` (
  `id` bigint(64) unsigned NOT NULL,
  `nid` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `data_id` varchar(255) COLLATE utf8_bin NOT NULL,
  `group_id` varchar(128) COLLATE utf8_bin NOT NULL,
  `app_name` varchar(128) COLLATE utf8_bin DEFAULT NULL COMMENT 'app_name',
  `content` longtext COLLATE utf8_bin NOT NULL,
  `md5` varchar(32) COLLATE utf8_bin DEFAULT NULL,
  `gmt_create` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `gmt_modified` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `src_user` text COLLATE utf8_bin,
  `src_ip` varchar(20) COLLATE utf8_bin DEFAULT NULL,
  `op_type` char(10) COLLATE utf8_bin DEFAULT NULL,
  `tenant_id` varchar(128) COLLATE utf8_bin DEFAULT '' COMMENT '租户字段',
  PRIMARY KEY (`nid`),
  KEY `idx_gmt_create` (`gmt_create`),
  KEY `idx_gmt_modified` (`gmt_modified`),
  KEY `idx_did` (`data_id`)
) ENGINE=InnoDB AUTO_INCREMENT=115 DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='多租户改造';

-- ----------------------------
-- Records of his_config_info
-- ----------------------------
INSERT INTO `his_config_info` VALUES ('34', '114', 'petrel-game-config.yaml', 'DEFAULT_GROUP', '', 0x686F73743A0D0A20202075726C3A20687474703A2F2F70697A322D75702E73646963616C6761652E636E2F7963645F7570646174652F0D0A77783A0D0A20202069643A20777869645F76616C75650D0A2020207365637265743A2077785365637265745F76616C75650D0A6C6F6262793A0D0A20202076657273696F6E3A20310D0A2020207666783A20434A4D4C, '9d0ee6932f68041dcca63ac5bd7b9f91', '2021-07-13 11:42:34', '2021-07-13 03:42:35', null, '101.204.219.199', 'U', '');

-- ----------------------------
-- Table structure for permissions
-- ----------------------------
DROP TABLE IF EXISTS `permissions`;
CREATE TABLE `permissions` (
  `role` varchar(50) NOT NULL,
  `resource` varchar(255) NOT NULL,
  `action` varchar(8) NOT NULL,
  UNIQUE KEY `uk_role_permission` (`role`,`resource`,`action`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Records of permissions
-- ----------------------------

-- ----------------------------
-- Table structure for roles
-- ----------------------------
DROP TABLE IF EXISTS `roles`;
CREATE TABLE `roles` (
  `username` varchar(50) NOT NULL,
  `role` varchar(50) NOT NULL,
  UNIQUE KEY `idx_user_role` (`username`,`role`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Records of roles
-- ----------------------------
INSERT INTO `roles` VALUES ('nacos', 'ROLE_ADMIN');

-- ----------------------------
-- Table structure for tenant_capacity
-- ----------------------------
DROP TABLE IF EXISTS `tenant_capacity`;
CREATE TABLE `tenant_capacity` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `tenant_id` varchar(128) COLLATE utf8_bin NOT NULL DEFAULT '' COMMENT 'Tenant ID',
  `quota` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '配额，0表示使用默认值',
  `usage` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '使用量',
  `max_size` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '单个配置大小上限，单位为字节，0表示使用默认值',
  `max_aggr_count` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '聚合子配置最大个数',
  `max_aggr_size` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '单个聚合数据的子配置大小上限，单位为字节，0表示使用默认值',
  `max_history_count` int(10) unsigned NOT NULL DEFAULT '0' COMMENT '最大变更历史数量',
  `gmt_create` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `gmt_modified` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '修改时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='租户容量信息表';

-- ----------------------------
-- Records of tenant_capacity
-- ----------------------------

-- ----------------------------
-- Table structure for tenant_info
-- ----------------------------
DROP TABLE IF EXISTS `tenant_info`;
CREATE TABLE `tenant_info` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'id',
  `kp` varchar(128) COLLATE utf8_bin NOT NULL COMMENT 'kp',
  `tenant_id` varchar(128) COLLATE utf8_bin DEFAULT '' COMMENT 'tenant_id',
  `tenant_name` varchar(128) COLLATE utf8_bin DEFAULT '' COMMENT 'tenant_name',
  `tenant_desc` varchar(256) COLLATE utf8_bin DEFAULT NULL COMMENT 'tenant_desc',
  `create_source` varchar(32) COLLATE utf8_bin DEFAULT NULL COMMENT 'create_source',
  `gmt_create` bigint(20) NOT NULL COMMENT '创建时间',
  `gmt_modified` bigint(20) NOT NULL COMMENT '修改时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tenant_info_kptenantid` (`kp`,`tenant_id`),
  KEY `idx_tenant_id` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin COMMENT='tenant_info';

-- ----------------------------
-- Records of tenant_info
-- ----------------------------

-- ----------------------------
-- Table structure for users
-- ----------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `username` varchar(50) NOT NULL,
  `password` varchar(500) NOT NULL,
  `enabled` tinyint(1) NOT NULL,
  PRIMARY KEY (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- ----------------------------
-- Records of users
-- ----------------------------
INSERT INTO `users` VALUES ('nacos', '$2a$10$EuWPZHzz32dJN7jexM34MOeYirDdFAZm2kuWj7VEOJhhZkDrxfvUu', '1');
