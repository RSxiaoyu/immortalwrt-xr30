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

// 2. 自动兼容/迁移旧版订阅中的 legacy DNS 格式 (sing-box 1.14.0 规范)
let local_dns_tag = 'local';
if (profile.dns && profile.dns.servers) {
	for (let s in profile.dns.servers) {
		if (s.address) {
			if (s.address == 'local') {
				s.type = 'local';
				local_dns_tag = s.tag;
				delete s.address;
			} else if (s.address == 'fakeip') {
				s.type = 'fakeip';
				delete s.address;
				if (!s.inet4_range) s.inet4_range = '198.18.0.0/15';
			} else if (index(s.address, 'https://') == 0) {
				s.type = 'https';
				let rest = substr(s.address, 8);
				let slash = index(rest, '/');
				if (slash >= 0) {
					s.path = substr(rest, slash);
					s.server = substr(rest, 0, slash);
				} else {
					s.server = rest;
				}
				delete s.address;
				if (s.address_resolver) {
					s.domain_resolver = s.address_resolver;
					delete s.address_resolver;
				} else if (!s.domain_resolver) {
					s.domain_resolver = local_dns_tag;
				}
			} else if (index(s.address, 'tls://') == 0) {
				s.type = 'tls';
				s.server = substr(s.address, 6);
				delete s.address;
				if (s.address_resolver) {
					s.domain_resolver = s.address_resolver;
					delete s.address_resolver;
				} else if (!s.domain_resolver) {
					s.domain_resolver = local_dns_tag;
				}
			} else {
				s.type = 'udp';
				s.server = s.address;
				delete s.address;
			}
		}
	}
}
if (profile.dns && profile.dns.fakeip) {
	delete profile.dns.fakeip;
}

// 3. 自动注入基础透明代理入站 (解决机场订阅缺少 router-inbounds)
if (!profile.inbounds) {
	profile.inbounds = [];
}

let clean_inbounds = [];
for (let ib in profile.inbounds) {
	if (ib.tag != 'tun-in' && ib.tag != 'dns-in' && ib.tag != 'redirect-in' && ib.tag != 'tproxy-in') {
		push(clean_inbounds, ib);
	}
}
profile.inbounds = clean_inbounds;

push(profile.inbounds, {
	"type": "direct",
	"tag": "dns-in",
	"listen": "::",
	"listen_port": 6450
});

push(profile.inbounds, {
	"type": "redirect",
	"tag": "redirect-in",
	"listen": "::",
	"listen_port": 7892
});

push(profile.inbounds, {
	"type": "tproxy",
	"tag": "tproxy-in",
	"listen": "::",
	"listen_port": 7895
});

push(profile.inbounds, {
	"type": "tun",
	"tag": "tun-in",
	"interface_name": "momo-tun",
	"address": ["172.19.0.1/30"],
	"auto_route": false,
	"strict_route": false,
	"stack": "system"
});

// 4. 路由规则兼容与 DNS 劫持
if (!profile.route) {
	profile.route = {};
}
if (!profile.route.default_domain_resolver) {
	profile.route.default_domain_resolver = local_dns_tag;
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

// 5. 支持外置自定义混入文件 /etc/momo/mixin.json
const custom_mixin_raw = readfile('/etc/momo/mixin.json');
if (custom_mixin_raw) {
	const custom_mixin = json(custom_mixin_raw);
	if (custom_mixin) {
		profile = merge(profile, custom_mixin);
	}
}

// 6. 确保 Clash API / Zashboard 监听所有接口 (0.0.0.0:9090)，允许手机与局域网设备直接访问面板
if (!profile.experimental) {
	profile.experimental = {};
}
if (!profile.experimental.clash_api) {
	profile.experimental.clash_api = {};
}
if (!profile.experimental.clash_api.external_controller || index(profile.experimental.clash_api.external_controller, '127.0.0.1') == 0) {
	profile.experimental.clash_api.external_controller = '0.0.0.0:9090';
}
if (!profile.experimental.clash_api.external_ui) {
	profile.experimental.clash_api.external_ui = 'ui';
}

save_profile(profile);