#!/usr/bin/ucode

'use strict';

import { readfile, writefile } from 'fs';
import { cursor } from 'uci';
import { uci_bool, uci_int, uci_array, merge, trim_all, load_profile, save_profile } from '/etc/momo/ucode/include.uc';

const uci = cursor();

// 1. 读取原生订阅或旧配置
const raw_profile = load_profile();

// 2. 纯净提取机场订阅中唯一的真实资产：所有代理节点 (Proxy Nodes)
let proxy_nodes = [];
let proxy_tags = [];

for (let ob in raw_profile.outbounds) {
	if (ob.type != 'selector' && ob.type != 'urltest' && ob.type != 'direct' && ob.type != 'block' && ob.type != 'dns') {
		if (index(ob.tag, '流量') < 0 && index(ob.tag, '到期') < 0) {
			push(proxy_nodes, ob);
			push(proxy_tags, ob.tag);
		}
	}
}

// 3. 读取用户自定义 mixin.json (支持在 LuCI WebUI 在线编辑自由修改)
function load_mixin_config() {
	const paths = ['/etc/momo/profiles/mixin.json', '/etc/momo/mixin.json'];
	for (let p in paths) {
		const raw = readfile(p);
		if (raw) {
			const parsed = json(raw);
			if (parsed) return parsed;
		}
	}
	return null;
}
const mixin = load_mixin_config() || {};

// 4. 组装自定义出站策略组 (支持 GfS 风格 include / exclude 正则筛选)
let custom_outbounds = [];
if (mixin.outbounds && type(mixin.outbounds) == 'array') {
	for (let ob in mixin.outbounds) {
		if (ob.type == 'urltest' || ob.type == 'selector') {
			let inc_re = ob.include ? regexp(ob.include, 'i') : null;
			let exc_re = ob.exclude ? regexp(ob.exclude, 'i') : null;

			let source_tags = (ob.outbounds && length(ob.outbounds) > 0) ? ob.outbounds : proxy_tags;
			let filtered = [];
			for (let tag in source_tags) {
				if (inc_re && !match(tag, inc_re)) continue;
				if (exc_re && match(tag, exc_re)) continue;
				push(filtered, tag);
			}
			ob.outbounds = length(filtered) > 0 ? filtered : ['DIRECT'];
			delete ob.include;
			delete ob.exclude;
		}
		push(custom_outbounds, ob);
	}
}

// 5. 组装规则集 (默认包含广告拦截与全量大陆域名，支持 mixin 增量合并)
let rule_sets = [
	{
		"tag": "geosite-ads",
		"type": "remote",
		"format": "binary",
		"url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/category-ads-all.srs",
		"download_detour": "DIRECT"
	},
	{
		"tag": "geosite-cn",
		"type": "remote",
		"format": "binary",
		"url": "https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/cn.srs",
		"download_detour": "DIRECT"
	}
];
if (mixin.rule_set && type(mixin.rule_set) == 'array') {
	for (let rs in mixin.rule_set) {
		let found = false;
		for (let ex in rule_sets) {
			if (ex.tag == rs.tag) { found = true; break; }
		}
		if (!found) push(rule_sets, rs);
	}
}

// 6. 组装分流规则链：嗅探 -> DNS劫持 -> 私有IP -> BT下载 -> 广告拦截 -> 用户前置规则 -> 大陆直连 -> 用户后置规则
let rules = [
	{ "action": "sniff" },
	{ "protocol": "dns", "action": "hijack-dns" },
	{ "ip_is_private": true, "outbound": "DIRECT" },
	{ "protocol": ["bittorrent"], "outbound": "DIRECT" },
	{ "rule_set": "geosite-ads", "action": "reject" }
];

if (mixin.prepend_rules && type(mixin.prepend_rules) == 'array') {
	for (let r in mixin.prepend_rules) {
		push(rules, r);
	}
}

push(rules, { "rule_set": "geosite-cn", "outbound": "DIRECT" });

if (mixin.append_rules && type(mixin.append_rules) == 'array') {
	for (let r in mixin.append_rules) {
		push(rules, r);
	}
}

// 7. 读取 WebUI 界面设定的配置
const api_listen = uci.get('momo', 'mixin', 'external_control_api_listen') || '0.0.0.0:9090';
const api_secret = uci.get('momo', 'mixin', 'external_control_api_secret') || '';
const api_ui = uci.get('momo', 'mixin', 'external_control_ui_path') || 'ui';

// 8. 合成 100% 优雅纯净的 GUI.for.SingBox 范式配置
let clean_profile = {
	"log": {
		"level": uci.get('momo', 'mixin', 'log_level') || 'info',
		"timestamp": true
	},
	"dns": {
		"servers": [
			{
				"tag": "local",
				"type": "local"
			},
			{
				"tag": "fakeip",
				"type": "fakeip",
				"inet4_range": "198.18.0.0/15"
			}
		],
		"rules": [
			{
				"rule_set": "geosite-cn",
				"server": "local"
			},
			{
				"query_type": ["A", "AAAA"],
				"server": "fakeip"
			}
		],
		"final": "local",
		"strategy": "prefer_ipv4",
		"reverse_mapping": true
	},
	"inbounds": [
		{
			"type": "direct",
			"tag": "dns-in",
			"listen": "::",
			"listen_port": 6450
		},
		{
			"type": "redirect",
			"tag": "redirect-in",
			"listen": "::",
			"listen_port": 7892
		},
		{
			"type": "tproxy",
			"tag": "tproxy-in",
			"listen": "::",
			"listen_port": 7895
		},
		{
			"type": "tun",
			"tag": "tun-in",
			"interface_name": "momo-tun",
			"address": ["172.19.0.1/30"],
			"auto_route": false,
			"strict_route": false,
			"stack": "system"
		},
		{
			"type": "mixed",
			"tag": "mixed-in",
			"listen": "127.0.0.1",
			"listen_port": 7891
		}
	],
	"outbounds": [
		{
			"type": "direct",
			"tag": "DIRECT"
		},
		{
			"type": "block",
			"tag": "REJECT"
		},
		{
			"type": "selector",
			"tag": "节点选择",
			"outbounds": ["自动选择", ...proxy_tags, "DIRECT"]
		},
		{
			"type": "urltest",
			"tag": "自动选择",
			"outbounds": proxy_tags,
			"url": "https://www.gstatic.com/generate_204",
			"interval": "5m",
			"tolerance": 50
		},
		...custom_outbounds,
		...proxy_nodes
	],
	"route": {
		"rules": rules,
		"rule_set": rule_sets,
		"final": "节点选择",
		"default_domain_resolver": "local"
	},
	"experimental": {
		"cache_file": {
			"enabled": true,
			"path": "/etc/momo/run/cache.db",
			"store_fakeip": true,
			"store_rdrc": true
		},
		"clash_api": {
			"external_controller": api_listen,
			"external_ui": api_ui,
			"secret": api_secret
		}
	}
};

save_profile(clean_profile);
