#!/usr/bin/ucode

'use strict';

import { readfile } from 'fs';
import { cursor } from 'uci';
import { uci_bool, uci_int, uci_array, merge, trim_all, load_profile, save_profile } from '/etc/momo/ucode/include.uc';

const uci = cursor();

const config = {};

config['log'] = {};
config['log']['disabled'] = uci_bool(uci.get('momo', 'mixin', 'log_disabled'));
config['log']['level'] = uci.get('momo', 'mixin', 'log_level');
config['log']['timestamp'] = uci_bool(uci.get('momo', 'mixin', 'log_timestamp'));
config['log']['output'] = uci.get('momo', 'mixin', 'log_output');

config['dns'] = {};
config['dns']['strategy'] = uci.get('momo', 'mixin', 'dns_strategy');
config['dns']['disable_cache'] = uci_bool(uci.get('momo', 'mixin', 'dns_disable_cache'));
config['dns']['disable_expire'] = uci_bool(uci.get('momo', 'mixin', 'dns_disable_expire'));
config['dns']['independent_cache'] = uci_bool(uci.get('momo', 'mixin', 'dns_independent_cache'));
config['dns']['cache_capacity'] = uci_int(uci.get('momo', 'mixin', 'dns_cache_capacity'));
config['dns']['reverse_mapping'] = uci_bool(uci.get('momo', 'mixin', 'dns_reverse_mapping'));

config['ntp'] = {};
config['ntp']['enabled'] = uci_bool(uci.get('momo', 'mixin', 'ntp_enabled'));
config['ntp']['server'] = uci.get('momo', 'mixin', 'ntp_server');
config['ntp']['server_port'] = uci_int(uci.get('momo', 'mixin', 'ntp_server_port'));
config['ntp']['interval'] = uci.get('momo', 'mixin', 'ntp_interval');

config['experimental'] = {};

config['experimental']['cache_file'] = {};
config['experimental']['cache_file']['enabled'] = uci_bool(uci.get('momo', 'mixin', 'cache_enabled'));
config['experimental']['cache_file']['path'] = uci.get('momo', 'mixin', 'cache_path');
config['experimental']['cache_file']['store_fakeip'] = uci_bool(uci.get('momo', 'mixin', 'cache_store_fakeip'));
config['experimental']['cache_file']['store_rdrc'] = uci_bool(uci.get('momo', 'mixin', 'cache_store_rdrc'));

config['experimental']['clash_api'] = {};
config['experimental']['clash_api']['external_ui'] = uci.get('momo', 'mixin', 'external_control_ui_path');
config['experimental']['clash_api']['external_ui_download_url'] = uci.get('momo', 'mixin', 'external_control_ui_download_url');
config['experimental']['clash_api']['external_controller'] = uci.get('momo', 'mixin', 'external_control_api_listen');
config['experimental']['clash_api']['secret'] = uci.get('momo', 'mixin', 'external_control_api_secret');

let profile = load_profile();

// 1. 基础 UCI 配置合并
profile = merge(profile, trim_all(config));

// 2. 自动补全透明代理入站 (解决机场原生订阅缺少 dns-in / redirect-in / tun-in 报错)
if (!profile.inbounds) {
	profile.inbounds = [];
}

function has_inbound(tag) {
	for (let ib in profile.inbounds) {
		if (ib.tag == tag) return true;
	}
	return false;
}

if (!has_inbound('dns-in')) {
	push(profile.inbounds, {
		"type": "direct",
		"tag": "dns-in",
		"listen": "::",
		"listen_port": 6450
	});
}

if (!has_inbound('redirect-in')) {
	push(profile.inbounds, {
		"type": "redirect",
		"tag": "redirect-in",
		"listen": "::",
		"listen_port": 7892
	});
}

if (!has_inbound('tproxy-in')) {
	push(profile.inbounds, {
		"type": "tproxy",
		"tag": "tproxy-in",
		"listen": "::",
		"listen_port": 7895
	});
}

if (!has_inbound('tun-in')) {
	push(profile.inbounds, {
		"type": "tun",
		"tag": "tun-in",
		"interface_name": "momo-tun",
		"inet4_address": "172.19.0.1/30",
		"auto_route": false,
		"strict_route": false,
		"stack": "system"
	});
}

// 3. 补全 DNS 劫持路由规则
if (!profile.route) {
	profile.route = {};
}
if (!profile.route.rules) {
	profile.route.rules = [];
}

let has_dns_rule = false;
for (let r in profile.route.rules) {
	if (r.action == 'hijack-dns') {
		has_dns_rule = true;
		break;
	}
}
if (!has_dns_rule) {
	unshift(profile.route.rules, {
		"inbound": ["dns-in"],
		"action": "hijack-dns"
	});
}

// 4. 支持外置自定义混入文件 /etc/momo/mixin.json
const custom_mixin_raw = readfile('/etc/momo/mixin.json');
if (custom_mixin_raw) {
	const custom_mixin = json(custom_mixin_raw);
	if (custom_mixin) {
		profile = merge(profile, custom_mixin);
	}
}

save_profile(profile);
