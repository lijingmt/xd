/**
 * iOS 内购：Apple收据校验结果验证 + 交易幂等台账（移植自txpike9）。
 *
 * Apple verifyReceipt 调用在 http_api_daemon.pike；本模块负责：
 *  - 产品ID → 充值面额（元），入账走账号级共享充值钱包；
 *  - 从已验证收据中精确匹配交易（含 latest_receipt_info）；
 *  - bundle/商品/取消校验；
 *  - 跨进程重启的交易台账（pending/granted/failed），保证同一笔
 *    Apple交易号只入账一次。
 * 账号钱包自身还有一层 request_id 幂等与原子落盘，双层防重。
 */

string iap_transaction_ledger_file =
	ROOT + "/data_xiand/iap_transaction_ledger.json";
mapping iap_transaction_ledger = ([ ]);
Thread.Mutex iap_transaction_lock = Thread.Mutex();
int iap_transaction_ledger_state = 0;

/* ===== App Store Server API（现代交易验证）=====
 * iOS 18+ 不再更新经典SK1收据，verifyReceipt 会"验证通过但查不到
 * 新交易"。配置 gamelib/etc/iap_server_api.json + .p8 私钥后，
 * /api/iap_verify 优先按 transaction_id 直连 Apple Server API 查询；
 * 未配置时回退经典收据路径。 */
private mapping iap_server_api_cache;

private string iap_base64url(string data)
{
	string b64 = MIME.encode_base64(data);
	b64 = replace(b64, ({ "+", "/", "\n", "\r" }),
		({ "-", "_", "", "" }));
	while(sizeof(b64) > 0 && b64[-1] == '=')
		b64 = b64[..sizeof(b64)-2];
	return b64;
}

private string iap_base64url_decode(string data)
{
	string b64 = replace(data, ({ "-", "_" }), ({ "+", "/" }));
	int pad = (4 - sizeof(b64) % 4) % 4;
	return MIME.decode_base64(b64 + "=" * pad);
}

/** 解析PKCS#8 EC私钥（P-256）为32字节标量。 */
private string|zero iap_parse_pkcs8_ec_scalar(string pem)
{
	array(string) lines = pem / "\n";
	string b64 = "";
	int inside;
	foreach(lines,string line){
		if(has_prefix(line,"-----BEGIN")){ inside = 1; continue; }
		if(has_prefix(line,"-----END")) break;
		if(inside) b64 += line;
	}
	if(sizeof(b64) < 40) return 0;
	mixed err = catch {
		object root = Standards.ASN1.Decode.simple_der_decode(
			MIME.decode_base64(b64));
		object inner = Standards.ASN1.Decode.simple_der_decode(
			root->elements[2]->value);
		string scalar = (string)inner->elements[1]->value;
		if(sizeof(scalar) >= 24 && sizeof(scalar) <= 32)
			return scalar;
	};
	return 0;
}

mapping|zero load_iap_server_api_config()
{
	if(mappingp(iap_server_api_cache))
		return iap_server_api_cache;
	/* 开源仓库只提交占位模板；真实密钥参数放在
	 * iap_server_api.local.json（gitignore），优先读取。 */
	string raw = Stdio.read_file(
		ROOT + "/gamelib/etc/iap_server_api.local.json");
	if(!raw || raw == "")
		raw = Stdio.read_file(
			ROOT + "/gamelib/etc/iap_server_api.json");
	if(!raw || raw == "")
		return 0;
	mixed err = catch {
		mapping cfg = Standards.JSON.decode(raw);
		if(!mappingp(cfg)) return 0;
		string issuer_id = String.trim_all_whites(
			(string)(cfg["issuer_id"] || ""));
		string key_id = String.trim_all_whites(
			(string)(cfg["key_id"] || ""));
		string bundle_id = String.trim_all_whites(
			(string)(cfg["bundle_id"] || "com.wapmud.xiandao"));
		/* 占位符/短值视为未配置，回退经典收据路径。 */
		if(has_prefix(issuer_id,"FILL_") ||
		   has_prefix(key_id,"FILL_") ||
		   sizeof(issuer_id) < 8 || sizeof(key_id) < 8)
			return 0;
		string key_file = (string)(cfg["key_file"] ||
			"gamelib/etc/iap_server_api_key.p8");
		if(has_prefix(key_file,"/"))
			key_file = key_file[sizeof(ROOT)..];
		string pem = Stdio.read_file(ROOT + "/" + key_file);
		if(!pem || pem == "")
			return 0;
		string scalar = iap_parse_pkcs8_ec_scalar(pem);
		if(!scalar)
			return 0;
		object ecdsa = Crypto.ECC.SECP_256R1.ECDSA();
		ecdsa->set_private_key(scalar);
		iap_server_api_cache = ([
			"issuer_id": issuer_id,
			"key_id": key_id,
			"bundle_id": bundle_id,
			"ecdsa": ecdsa,
		]);
		return iap_server_api_cache;
	};
	return 0;
}

/** ES256 JWT（App Store Connect API 规范的请求令牌）。 */
string build_appstore_server_api_jwt(mapping cfg)
{
	string header = Standards.JSON.encode(([
		"alg": "ES256",
		"kid": cfg["key_id"],
		"typ": "JWT",
	]));
	int now = time();
	string payload = Standards.JSON.encode(([
		"iss": cfg["issuer_id"],
		"iat": now,
		"exp": now + 1200,
		"aud": "appstoreconnect-v1",
		"bid": cfg["bundle_id"],
	]));
	string signing_input = iap_base64url(header) + "." +
		iap_base64url(payload);
	array rs = cfg["ecdsa"]->raw_sign(
		Crypto.SHA256.hash(signing_input));
	string fix32(string raw){
		while(sizeof(raw) < 32) raw = "\0" + raw;
		return raw;
	}
	string sig = fix32(rs[0]->digits(256)) +
		fix32(rs[1]->digits(256));
	return signing_input + "." + iap_base64url(sig);
}

/** 解码 signedTransactionInfo 的JWS payload（不含验签，数据
 * 直接来自Apple TLS响应，可信）。 */
mapping|zero iap_decode_jws_payload(string jws)
{
	array(string) parts = jws / ".";
	if(sizeof(parts) < 2) return 0;
	mixed err = catch {
		mapping payload = Standards.JSON.decode(
			iap_base64url_decode(parts[1]));
		return mappingp(payload) ? payload : 0;
	};
	return 0;
}

/**
 * 按交易号向 App Store Server API 查询：先生产后沙盒。
 * 返回 (["ok":1,"data":payload,"environment":...]) 或
 * (["ok":0,"error":...])。
 */
mapping query_appstore_server_transaction(string transaction_id)
{
	mapping cfg = load_iap_server_api_config();
	if(!mappingp(cfg))
		return (["ok":0,"error":"服务器未配置App Store Server API密钥"]);
	if(!transaction_id || transaction_id == "" ||
	   sizeof(transaction_id) > 64)
		return (["ok":0,"error":"交易编号无效"]);
	array(string) hosts = ({
		"https://api.storekit.itunes.apple.com",
		"https://api.storekit-sandbox.itunes.apple.com",
	});
	string token = build_appstore_server_api_jwt(cfg);
	string last_error = "";
	foreach(hosts,string host){
		mixed err = catch {
			object query = Protocols.HTTP.Query();
			query->maxtime = 30;
			object response = Protocols.HTTP.do_method("GET",
				host + "/inApps/v1/transactions/" + transaction_id,
				0, ([
					"Authorization": "Bearer " + token,
					"Accept": "application/json",
				]), query, 0);
			if(response && response->status == 200){
				mapping body = Standards.JSON.decode(
					response->data());
				string signed_info =
					(string)(body && body["signedTransactionInfo"]);
				if(signed_info && signed_info != ""){
					mapping payload =
						iap_decode_jws_payload(signed_info);
					if(mappingp(payload))
						return ([
							"ok":1,
							"data":payload,
							"environment":
								has_prefix(host,
									"https://api.storekit-sandbox")
								? "Sandbox" : "Production",
						]);
					last_error = "交易响应解析失败";
				}
				else
					last_error = "交易响应缺少签名数据";
			}
			else if(response){
				int status = response->status;
				string data = response->data();
				if(status == 404)
					last_error = "Apple查无此交易";
				else{
					last_error = "Apple验证服务HTTP " + status;
					werror("[IAP] server api %s -> %d %s\n",
						host, status,
						data[0..sizeof(data)<120 ? sizeof(data)-1 : 119]);
				}
			}
			else
				last_error = "Apple验证服务无响应";
		};
		if(err){
			last_error = "Apple验证网络异常";
			werror("[IAP] server api exception: %s\n",
				describe_error(err));
		}
	}
	return (["ok":0,"error":last_error]);
}

mapping new_iap_transaction_ledger()
{
	return ([
		"version": 1,
		"transactions": ([ ]),
	]);
}

int is_iap_synthetic_receipt(string receipt)
{
	if(!receipt || receipt == "")
		return 0;
	return has_prefix(receipt, "test_");
}

/** 产品ID → 充值面额（人民币元）。碎玉=面额×10，由账号钱包换算。 */
int query_iap_product_fee(string product_id)
{
	switch(product_id) {
		case "com.wapmud.xiandao.1000suiyu":
			return 100;
		case "com.wapmud.xiandao.3000suiyu":
			return 300;
		case "com.wapmud.xiandao.10000suiyu":
			return 1000;
	}
	return 0;
}

string query_iap_product_label(string product_id)
{
	switch(product_id) {
		case "com.wapmud.xiandao.1000suiyu":
			return "1000碎玉";
		case "com.wapmud.xiandao.3000suiyu":
			return "3000碎玉";
		case "com.wapmud.xiandao.10000suiyu":
			return "10000碎玉";
	}
	return "";
}

mapping|zero query_iap_verified_transaction(mapping verify_result,
	string transaction_id)
{
	mapping receipt;
	array transactions;
	mixed latest;
	int i;

	if(!mappingp(verify_result) || !transaction_id || transaction_id == "")
		return 0;
	receipt = verify_result["receipt"];
	if(mappingp(receipt) && arrayp(receipt["in_app"])) {
		transactions = receipt["in_app"];
		for(i = 0; i < sizeof(transactions); i++) {
			if(mappingp(transactions[i]) &&
			   transactions[i]["transaction_id"] == transaction_id)
				return transactions[i];
		}
	}
	latest = verify_result["latest_receipt_info"];
	if(arrayp(latest)) {
		transactions = latest;
		for(i = 0; i < sizeof(transactions); i++) {
			if(mappingp(transactions[i]) &&
			   transactions[i]["transaction_id"] == transaction_id)
				return transactions[i];
		}
	}
	else if(mappingp(latest) &&
	        latest["transaction_id"] == transaction_id) {
		return latest;
	}
	return 0;
}

int is_iap_verified_bundle(mapping verify_result)
{
	mapping receipt;

	if(!mappingp(verify_result))
		return 0;
	receipt = verify_result["receipt"];
	if(!mappingp(receipt))
		return 0;
	return receipt["bundle_id"] == "com.wapmud.xiandao";
}

int is_iap_transaction_product_match(mapping transaction,
	string product_id)
{
	if(!mappingp(transaction) || !product_id || product_id == "")
		return 0;
	if(!stringp(transaction["transaction_id"]) ||
	   transaction["transaction_id"] == "")
		return 0;
	if(transaction["product_id"] != product_id)
		return 0;
	if(transaction["cancellation_date"] ||
	   transaction["cancellation_date_ms"])
		return 0;
	return 1;
}

/** 已入账交易的再提交策略：duplicate=幂等成功，conflict=拒绝重放。 */
mapping query_iap_existing_transaction_policy(mapping|zero existing,
	string account_id)
{
	if(!mappingp(existing))
		return ([ "grant": 1, "duplicate": 0, "conflict": 0 ]);
	if(existing["account_id"] != account_id)
		return ([ "grant": 0, "duplicate": 0, "conflict": 1 ]);
	if(existing["status"] == "granted")
		return ([ "grant": 0, "duplicate": 1, "conflict": 0 ]);
	if(existing["status"] == "failed")
		return ([ "grant": 1, "duplicate": 0, "conflict": 0 ]);
	return ([ "grant": 0, "duplicate": 0, "conflict": 1 ]);
}

int write_iap_transaction_ledger()
{
	string content;
	string temp_file;
	string backup_file;
	string backup_temp_file;
	int live_size;
	int temp_size;
	mixed err;

	err = catch {
		content = Standards.JSON.encode(iap_transaction_ledger);
	};
	if(err || !content || content == "")
		return 0;
	temp_file = iap_transaction_ledger_file + ".tmp";
	backup_file = iap_transaction_ledger_file + ".bak";
	backup_temp_file = iap_transaction_ledger_file + ".bak.tmp";
	mkdir(dirname(iap_transaction_ledger_file));
	rm(temp_file);
	rm(backup_temp_file);
	err = catch {
		Stdio.write_file(temp_file, content);
	};
	temp_size = Stdio.file_size(temp_file);
	if(err || temp_size != sizeof(content)) {
		rm(temp_file);
		return 0;
	}
	live_size = Stdio.file_size(iap_transaction_ledger_file);
	if(live_size > 0) {
		err = catch {
			Stdio.cp(iap_transaction_ledger_file, backup_temp_file);
		};
		if(err || Stdio.file_size(backup_temp_file) != live_size) {
			rm(temp_file);
			rm(backup_temp_file);
			return 0;
		}
		if(!mv(backup_temp_file, backup_file)) {
			rm(temp_file);
			rm(backup_temp_file);
			return 0;
		}
	}
	if(!mv(temp_file, iap_transaction_ledger_file)) {
		rm(temp_file);
		return 0;
	}
	return Stdio.file_size(iap_transaction_ledger_file) > 0;
}

mapping|zero decode_iap_transaction_ledger(string raw)
{
	mapping decoded;
	mixed err;

	if(!raw || raw == "")
		return 0;
	err = catch {
		decoded = Standards.JSON.decode(raw);
	};
	if(err || !mappingp(decoded) ||
	   !mappingp(decoded["transactions"]))
		return 0;
	return decoded;
}

int load_iap_transaction_ledger()
{
	string raw;
	mapping decoded;
	int loaded_from_backup;
	int live_size;
	int backup_size;

	if(iap_transaction_ledger_state != 0)
		return iap_transaction_ledger_state > 0;
	live_size = Stdio.file_size(iap_transaction_ledger_file);
	backup_size = Stdio.file_size(
		iap_transaction_ledger_file + ".bak");
	raw = Stdio.read_file(iap_transaction_ledger_file);
	if(raw && raw != "")
		decoded = decode_iap_transaction_ledger(raw);
	if(!mappingp(decoded) && backup_size > 0) {
		raw = Stdio.read_file(
			iap_transaction_ledger_file + ".bak");
		if(raw && raw != "") {
			decoded = decode_iap_transaction_ledger(raw);
			loaded_from_backup = mappingp(decoded);
		}
	}
	if(mappingp(decoded)) {
		iap_transaction_ledger = decoded;
		if(loaded_from_backup) {
			if(live_size > 0 &&
			   !rm(iap_transaction_ledger_file)) {
				iap_transaction_ledger_state = -1;
				werror("[IAP] Cannot restore ledger backup; purchases disabled\n");
				return 0;
			}
			if(!write_iap_transaction_ledger()) {
				iap_transaction_ledger_state = -1;
				werror("[IAP] Cannot restore ledger backup; purchases disabled\n");
				return 0;
			}
		}
		iap_transaction_ledger_state = 1;
		return 1;
	}
	if(live_size > 0 || backup_size > 0) {
		iap_transaction_ledger_state = -1;
		werror("[IAP] Ledger unreadable; purchases disabled\n");
		return 0;
	}
	iap_transaction_ledger = new_iap_transaction_ledger();
	if(!write_iap_transaction_ledger()) {
		iap_transaction_ledger_state = -1;
		werror("[IAP] Cannot initialize ledger; purchases disabled\n");
		return 0;
	}
	iap_transaction_ledger_state = 1;
	return 1;
}

int ensure_iap_transaction_ledger()
{
	object lock_key;
	int ok;

	lock_key = iap_transaction_lock->lock();
	ok = load_iap_transaction_ledger();
	destruct(lock_key);
	return ok;
}

/**
 * 入账：Apple交易号幂等 + 账号共享充值钱包。
 * fee 为充值面额（元），钱包按 ×10 换算碎玉入 balance。
 * 返回 ([ok,duplicate,balance(碎玉),message,code])。
 */
mapping grant_iap_transaction(object player,string account_id,
	string transaction_id,string product_id,int fee,
	string environment)
{
	object ledger_key;
	object wallet_key;
	mapping transactions;
	mapping existing;
	mapping policy;
	mapping credit;
	mapping result;

	result = (["ok":0,"code":500,"message":"充值处理失败"]);
	if(!objectp(player) || !account_id || account_id == "" ||
	   !transaction_id || transaction_id == "" || fee <= 0) {
		result["code"] = 400;
		result["message"] = "交易参数无效";
		return result;
	}
	if(!ensure_iap_transaction_ledger()) {
		result["code"] = 503;
		result["message"] = "交易账本暂时不可用";
		return result;
	}

	ledger_key = iap_transaction_lock->lock();
	transactions = iap_transaction_ledger["transactions"];
	if(!mappingp(transactions)) {
		transactions = ([ ]);
		iap_transaction_ledger["transactions"] = transactions;
	}
	existing = transactions[transaction_id];
	if(mappingp(existing)) {
		policy = query_iap_existing_transaction_policy(
			existing, account_id);
		if(policy["duplicate"]) {
			result = ([
				"ok":1,
				"code":200,
				"duplicate":1,
				"balance":ACCOUNT_WALLETD->query_balance(player),
				"message":"本次充值已经入账，请勿重复提交",
			]);
			destruct(ledger_key);
			return result;
		}
		if(!policy["grant"]) {
			result["code"] = 409;
			result["message"] = "该交易已经处理";
			destruct(ledger_key);
			return result;
		}
	}

	transactions[transaction_id] = ([
		"status": "pending",
		"account_id": account_id,
		"character_id": player->query_name(),
		"product_id": product_id,
		"fee": fee,
		"environment": environment,
		"created_at": time(),
	]);
	if(!write_iap_transaction_ledger()) {
		m_delete(transactions, transaction_id);
		result["code"] = 503;
		result["message"] = "无法记录交易，请稍后重试";
		destruct(ledger_key);
		return result;
	}

	credit = ACCOUNT_WALLETD->credit_recharge(player, fee,
		"iap:" + product_id);
	if(!(int)credit["ok"]) {
		transactions[transaction_id]["status"] = "failed";
		transactions[transaction_id]["failed_at"] = time();
		transactions[transaction_id]["message"] =
			(string)(credit["message"] || "");
		write_iap_transaction_ledger();
		result["code"] = 502;
		result["message"] = (string)(credit["message"] ||
			"账号钱包入账失败，本次未发放");
		destruct(ledger_key);
		return result;
	}

	transactions[transaction_id]["status"] = "granted";
	transactions[transaction_id]["granted_at"] = time();
	transactions[transaction_id]["credited_amount"] =
		(int)credit["amount"];
	if(!write_iap_transaction_ledger())
		werror("[IAP] Granted but ledger finalize failed: %s\n",
			transaction_id);
	result = ([
		"ok":1,
		"code":200,
		"duplicate":0,
		"balance":(int)credit["balance"],
		"message":"",
	]);
	destruct(ledger_key);
	return result;
}
