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

// 4. 路由基础框架
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

// 5. GUI.for.SingBox 风格智能 Mixin 引擎
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

const mixin = load_mixin_config();
if (mixin) {
	// A. 自定义规则集 rule_set 合并 (按 tag 去重追加)
	if (mixin.rule_set && type(mixin.rule_set) == 'array') {
		if (!profile.route.rule_set) profile.route.rule_set = [];
		for (let rs in mixin.rule_set) {
			let found = false;
			for (let ex in profile.route.rule_set) {
				if (ex.tag == rs.tag) { found = true; break; }
			}
			if (!found) push(profile.route.rule_set, rs);
		}
	}

	// B. 自定义出站 outbounds 合并 (原生对齐 GfS 的 include / exclude 正则动态过滤)
	if (mixin.outbounds && type(mixin.outbounds) == 'array') {
		if (!profile.outbounds) profile.outbounds = [];

		let all_proxy_nodes = [];
		for (let p_ob in profile.outbounds) {
			if (p_ob.type != 'selector' && p_ob.type != 'urltest' && p_ob.type != 'direct' && p_ob.type != 'block') {
				push(all_proxy_nodes, p_ob.tag);
			}
		}

		for (let ob in mixin.outbounds) {
			if (ob.type == 'urltest' || ob.type == 'selector') {
				if (ob.include || ob.exclude || !ob.outbounds || length(ob.outbounds) == 0) {
					let inc_re = ob.include ? regexp(ob.include, 'i') : null;
					let exc_re = ob.exclude ? regexp(ob.exclude, 'i') : null;

					let source_nodes = (ob.outbounds && length(ob.outbounds) > 0) ? ob.outbounds : all_proxy_nodes;
					let filtered_nodes = [];
					for (let tag in source_nodes) {
						if (inc_re && !match(tag, inc_re)) continue;
						if (exc_re && match(tag, exc_re)) continue;
						push(filtered_nodes, tag);
					}
					ob.outbounds = filtered_nodes;
					delete ob.include;
					delete ob.exclude;
				}
			}

			let found = false;
			for (let ex in profile.outbounds) {
				if (ex.tag == ob.tag) { found = true; break; }
			}
			if (!found) push(profile.outbounds, ob);
		}
	}

	// C. 前置分流规则 prepend_rules (插入到 hijack-dns 之后)
	if (mixin.prepend_rules && type(mixin.prepend_rules) == 'array') {
		let insert_idx = 0;
		for (let i = 0; i < length(profile.route.rules); i++) {
			if (profile.route.rules[i].action == 'hijack-dns') {
				insert_idx = i + 1;
				break;
			}
		}
		for (let i = length(mixin.prepend_rules) - 1; i >= 0; i--) {
			splice(profile.route.rules, insert_idx, 0, mixin.prepend_rules[i]);
		}
	}

	// D. 后置分流规则 append_rules (追加到末尾作为兜底规则)
	if (mixin.append_rules && type(mixin.append_rules) == 'array') {
		for (let r in mixin.append_rules) {
			push(profile.route.rules, r);
		}
	}

	// E. 自定义 DNS 合并
	if (mixin.dns) {
		if (!profile.dns) profile.dns = {};
		if (mixin.dns.servers && type(mixin.dns.servers) == 'array') {
			if (!profile.dns.servers) profile.dns.servers = [];
			for (let s in mixin.dns.servers) {
				let found = false;
				for (let ex in profile.dns.servers) {
					if (ex.tag == s.tag) { found = true; break; }
				}
				if (!found) push(profile.dns.servers, s);
			}
		}
		if (mixin.dns.rules && type(mixin.dns.rules) == 'array') {
			if (!profile.dns.rules) profile.dns.rules = [];
			for (let i = length(mixin.dns.rules) - 1; i >= 0; i--) {
				unshift(profile.dns.rules, mixin.dns.rules[i]);
			}
		}
	}

	// F. 其他未特殊处理的顶层字段深度合并
	for (let k in keys(mixin)) {
		if (k != 'prepend_rules' && k != 'append_rules' && k != 'rule_set' && k != 'outbounds' && k != 'dns' && k != '_comment') {
			profile[k] = mixin[k];
		}
	}
}

save_profile(profile);
