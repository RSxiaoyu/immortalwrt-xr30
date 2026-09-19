#!/usr/bin/ucode

'use strict';

import { readfile } from 'fs';
import { cursor } from 'uci';
import { load_profile, save_profile } from '/etc/momo/ucode/include.uc';

const uci = cursor();
const active_profile = uci.get('momo', 'config', 'profile') || '';

// 0. 智能放行：如果选中的既不是 mixin.json，也不是订阅 (例如用户自备的独立完整配置)，原样放行，退出脚本
if (active_profile != 'file:mixin.json' && index(active_profile, 'subscription:') != 0) {
	return;
}

let proxy_nodes = [], proxy_tags = [];

// 1. 节点提取决策流：
// 【模式 A】：选中 file:mixin.json ➔ 全量多订阅聚合模式 (聚合全部已下载的订阅，自动打上 [订阅名] 前缀)
if (active_profile == 'file:mixin.json') {
	uci.foreach('momo', 'subscription', function(s) {
		let sub_name = s.name || s['.name'];
		let sub_file = sprintf('/etc/momo/subscriptions/%s.json', s['.name']);
		let content = readfile(sub_file);
		if (!content) return;
		let raw = json(content);
		if (!raw || !raw.outbounds) return;

		for (let ob in raw.outbounds) {
			if (ob.type != 'selector' && ob.type != 'urltest' && ob.type != 'direct' && ob.type != 'block' && ob.type != 'dns') {
				ob.tag = sprintf("[%s] %s", sub_name, ob.tag);
				push(proxy_nodes, ob);
				push(proxy_tags, ob.tag);
			}
		}
	});
}
// 【模式 B】：选中单订阅 (如 subscription:xxx) ➔ 单订阅混入模式 (仅提取该特定订阅的节点)
else if (index(active_profile, 'subscription:') == 0) {
	let sub_id = substr(active_profile, 13);
	let s = uci.get_all('momo', sub_id);
	let sub_name = (s && s.name) ? s.name : sub_id;
	let sub_file = sprintf('/etc/momo/subscriptions/%s.json', sub_id);
	let content = readfile(sub_file);
	let raw = content ? json(content) : (load_profile() || {});

	for (let ob in (raw.outbounds || [])) {
		if (ob.type != 'selector' && ob.type != 'urltest' && ob.type != 'direct' && ob.type != 'block' && ob.type != 'dns') {
			ob.tag = sprintf("[%s] %s", sub_name, ob.tag);
			push(proxy_nodes, ob);
			push(proxy_tags, ob.tag);
		}
	}
}

// 2. 读取用户的 mixin.json
function get_mixin() {
	for (let p in ['/etc/momo/profiles/mixin.json', '/etc/momo/mixin.json']) {
		let str = readfile(p);
		if (str) { let obj = json(str); if (obj) return obj; }
	}
	return {};
}
let mixin = get_mixin();
delete mixin._comment;

// 3. 处理策略组正则筛选 (对齐 GfS)
let custom_outbounds = [];
for (let ob in (mixin.outbounds || [])) {
	if (ob.type == 'urltest' || ob.type == 'selector') {
		let inc = ob.include ? regexp(ob.include, 'i') : null;
		let exc = ob.exclude ? regexp(ob.exclude, 'i') : null;
		if (inc || exc) {
			let list = [];
			for (let tag in proxy_tags) {
				if (inc && !match(tag, inc)) continue;
				if (exc && match(tag, exc)) continue;
				push(list, tag);
			}
			let prefix = (ob.outbounds && length(ob.outbounds) > 0) ? ob.outbounds : [];
			let combined = [...prefix, ...list];
			ob.outbounds = length(combined) > 0 ? combined : ['DIRECT'];
			delete ob.include; delete ob.exclude;
		} else if (!ob.outbounds || length(ob.outbounds) == 0) {
			ob.outbounds = length(proxy_tags) > 0 ? proxy_tags : ['DIRECT'];
		}
	}
	push(custom_outbounds, ob);
}

// 4. 组装出站列表
let outbounds = [
	{ "type": "direct", "tag": "DIRECT" },
	{ "type": "block", "tag": "REJECT" },
	...custom_outbounds,
	...proxy_nodes
];

// 5. 过滤掉可能导致国内 local DNS 丢包卡死的 action: resolve
let user_rules = (mixin.route && mixin.route.rules) ? mixin.route.rules : (mixin.prepend_rules || []);
let safe_rules = [];
for (let r in user_rules) {
	if (r.action != 'resolve') push(safe_rules, r);
}

// 6. 组装最终纯净 Sing-box 配置 (规范对齐 1.14：rule_set 必须在 route 内部)
let config = {
	"log": mixin.log || { "level": uci.get('momo', 'mixin', 'log_level') || "warn", "timestamp": true },
	"dns": mixin.dns || {
		"servers": [
			{ "tag": "local", "type": "local" },
			{ "tag": "fakeip", "type": "fakeip", "inet4_range": "198.18.0.0/15" }
		],
		"rules": [
			{ "rule_set": "geosite-cn", "server": "local" },
			{ "query_type": ["A", "AAAA"], "server": "fakeip" }
		],
		"final": "local",
		"strategy": uci.get('momo', 'mixin', 'dns_strategy') || "prefer_ipv4",
		"optimistic": true,
		"reverse_mapping": true
	},
	"inbounds": [
		{ "type": "direct", "tag": "dns-in", "listen": "::", "listen_port": 6450 },
		{ "type": "redirect", "tag": "redirect-in", "listen": "::", "listen_port": 7892 },
		{ "type": "tproxy", "tag": "tproxy-in", "listen": "::", "listen_port": 7895 },
		{ "type": "tun", "tag": "tun-in", "interface_name": "momo-tun", "address": ["172.19.0.1/30"], "auto_route": false, "strict_route": false, "stack": "system" },
		{ "type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 7891 }
	],
	"outbounds": outbounds,
	"route": {
		"rules": [
			{ "action": "sniff" },
			{ "protocol": "dns", "action": "hijack-dns" },
			{ "ip_is_private": true, "outbound": "DIRECT" },
			{ "protocol": ["bittorrent"], "outbound": "DIRECT" },
			...safe_rules,
			{ "rule_set": "geosite-cn", "outbound": "DIRECT" }
		],
		"rule_set": (mixin.route && mixin.route.rule_set) ? mixin.route.rule_set : (mixin.rule_set || []),
		"final": (length(custom_outbounds) > 0 ? custom_outbounds[0].tag : "DIRECT"),
		"default_domain_resolver": "local"
	},
	"experimental": mixin.experimental || {
		"cache_file": { "enabled": true, "path": "/etc/momo/run/cache.db", "store_fakeip": true, "store_dns": true },
		"clash_api": {
			"external_controller": uci.get('momo', 'mixin', 'external_control_api_listen') || "0.0.0.0:9090",
			"external_ui": uci.get('momo', 'mixin', 'external_control_ui_path') || "ui",
			"external_ui_download_url": uci.get('momo', 'mixin', 'external_control_ui_download_url') || "https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip",
			"external_ui_download_detour": "DIRECT",
			"secret": uci.get('momo', 'mixin', 'external_control_api_secret') || ""
		}
	}
};

save_profile(config);
