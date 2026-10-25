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

const profile = load_profile();
delete profile.subscriptions;
delete profile._comment;
let mixed = merge(profile, trim_all(config));

// 声明式覆写：仅激活 file:mixin.json 时生效，其余 profile 保持原生行为
if (uci.get('momo', 'config', 'profile') == 'file:mixin.json') {
	const str = readfile('/etc/momo/profiles/mixin.json');
	const mixin = (str ? json(str) : null) || {};

	// 节点池：缺省聚合全部订阅；显式数组 = 精确名单（[] = 不聚合，纯自建）
	const has_pool = exists(mixin, 'subscriptions');
	const pool = mixin.subscriptions || [];
	delete mixin.subscriptions;
	delete mixin._comment;
	const skip = { selector: 1, urltest: 1, direct: 1, block: 1, dns: 1 };
	const nodes = [], tags = [];
	uci.foreach('momo', 'subscription', (s) => {
		if (has_pool && index(pool, s.name || s['.name']) < 0) return;
		const raw = json(readfile(`/etc/momo/subscriptions/${s['.name']}.json`));
		const name = s.name || s['.name'];
		for (let ob in (raw?.outbounds || []))
			if (!skip[ob.type]) {
				ob.tag = `[${name}] ${ob.tag}`;
				push(nodes, ob);
				push(tags, ob.tag);
			}
	});

	// 分组正则展开（对齐 mihomo filter 语义），空组回退 DIRECT
	for (let group in (mixin.outbounds || [])) {
		const inc = group.include ? regexp(group.include, 'i') : null;
		const exc = group.exclude ? regexp(group.exclude, 'i') : null;
		if (inc || exc) {
			const list = filter(tags, (t) => (!inc || match(t, inc)) && (!exc || !match(t, exc)));
			group.outbounds = [...(group.outbounds || []), ...list];
			if (length(group.outbounds) == 0) group.outbounds = ['DIRECT'];
			delete group.include;
			delete group.exclude;
		}
	}

	// 分组在前、节点在后；声明层置顶（> UCI > 原始 profile）
	mixin.outbounds = [...(mixin.outbounds || []), ...nodes];
	mixed = merge(mixed, trim_all(mixin) || {});
}

save_profile(mixed);
