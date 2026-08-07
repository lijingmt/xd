private mapping(string:mapping(string:mixed)) event_shop_catalog()
{
	// 注意：money 类商品的 amount 单位是 _account（银），100 银 = 1 金。
	// "兑换10000金币" 的描述对应 amount=1,000,000（即 10000*100），
	// 否则玩家只会看到 100 金，与描述严重不符。
	return ([
		"th_gold":(["name":"天衡金囊","desc":"兑换10000金币。",
			"token_key":"tianheng_tokens","cost":1,"kind":"money",
			"amount":1000000]),
		"th_herald":(["name":"天衡传音符","desc":"一张绑定千里传音符。",
			"token_key":"tianheng_tokens","cost":3,"kind":"item",
			"item_path":"/gamelib/clone/item/other/qianlichuanyinfu"]),
		"th_guard":(["name":"天衡免战符","desc":"一张绑定免战符，使用后可免战一小时。",
			"token_key":"tianheng_tokens","cost":10,"kind":"item",
			"item_path":"/gamelib/clone/item/other/mianzhanfu"]),
		"th_xuanhuang":(["name":"绑定玄黄石","desc":"用于锻造的绑定玄黄石。",
			"token_key":"tianheng_tokens","cost":12,"kind":"item",
			"item_path":"/gamelib/clone/item/material/xuanhuangshi"]),
		"th_jingang":(["name":"绑定金刚钻","desc":"用于高阶锻造的绑定金刚钻。",
			"token_key":"tianheng_tokens","cost":36,"kind":"item",
			"item_path":"/gamelib/clone/item/material/jingangzuan"]),
		"th_badge":(["name":"天衡百战徽记","desc":"永久收藏徽记，只能兑换一次。",
			"token_key":"tianheng_tokens","cost":100,"kind":"badge",
			"badge_id":"tianheng_veteran"]),
		"jy_gold":(["name":"九曜金囊","desc":"兑换10000金币。",
			"token_key":"jiuyao_tokens","cost":1,"kind":"money",
			"amount":1000000]),
		"jy_xuanhuang":(["name":"绑定玄黄石","desc":"用于锻造的绑定玄黄石。",
			"token_key":"jiuyao_tokens","cost":8,"kind":"item",
			"item_path":"/gamelib/clone/item/material/xuanhuangshi"]),
		"jy_yufeicui":(["name":"绑定玉翡翠","desc":"用于进阶锻造的绑定玉翡翠。",
			"token_key":"jiuyao_tokens","cost":20,"kind":"item",
			"item_path":"/gamelib/clone/item/material/yufeicui"]),
		"jy_jingang":(["name":"绑定金刚钻","desc":"用于高阶锻造的绑定金刚钻。",
			"token_key":"jiuyao_tokens","cost":36,"kind":"item",
			"item_path":"/gamelib/clone/item/material/jingangzuan"]),
		"jy_zishuijing":(["name":"绑定紫水晶","desc":"用于顶阶锻造的绑定紫水晶。",
			"token_key":"jiuyao_tokens","cost":50,"kind":"item",
			"item_path":"/gamelib/clone/item/material/zishuijing"]),
		"jy_badge":(["name":"九曜镇渊徽记","desc":"永久收藏徽记，只能兑换一次。",
			"token_key":"jiuyao_tokens","cost":100,"kind":"badge",
			"badge_id":"jiuyao_guardian"]),
	]);
}

private array(string) event_shop_order()
{
	return ({"th_gold","th_herald","th_guard","th_xuanhuang",
		"th_jingang","th_badge","jy_gold","jy_xuanhuang",
		"jy_yufeicui","jy_jingang","jy_zishuijing","jy_badge"});
}

private string event_shop_token_name(string token_key)
{
	if(token_key=="tianheng_tokens")
		return "天衡令";
	return "九曜令";
}

private string event_shop_badge_name(string badge_id)
{
	if(badge_id=="tianheng_veteran")
		return "天衡百战";
	if(badge_id=="jiuyao_guardian")
		return "九曜镇渊";
	return "";
}

private string query_event_badges(mapping state)
{
	array(string) names = ({});
	mapping badges = state["badges"];
	if(!mappingp(badges))
		return "";
	foreach(({"tianheng_veteran","jiuyao_guardian"}),string badge_id)
		if((int)badges[badge_id])
			names += ({event_shop_badge_name(badge_id)});
	return names*"、";
}

string query_event_shop_page(object player)
{
	mapping catalog;
	mapping state;
	string out;
	string last_token_key = "";
	if(!player)
		return "活动兑换商店暂不可用。\n[返回:timed_event]\n";
	catalog = event_shop_catalog();
	state = normalize_player_event_state(player);
	out = "【活动令牌兑换商店】\n";
	out += "天衡令："+(string)state["tianheng_tokens"]+
		"　九曜令："+(string)state["jiuyao_tokens"]+"\n";
	out += "兑换实物均为人物绑定物品，不能交易、赠送或丢弃。\n\n";
	foreach(event_shop_order(),string product_id){
		mapping product = catalog[product_id];
		string token_key = (string)product["token_key"];
		string owned = "";
		if(token_key!=last_token_key){
			out += token_key=="tianheng_tokens" ?
				"【天衡令兑换】\n" : "\n【九曜令兑换】\n";
			last_token_key = token_key;
		}
		if((string)product["kind"]=="badge" &&
		   (int)state["badges"][(string)product["badge_id"]])
			owned = "（已拥有）";
		out += (string)product["name"]+"："+(string)product["desc"]+
			" 需要"+(string)product["cost"]+
			event_shop_token_name(token_key)+owned;
		if(owned=="")
			out += " [兑换:timed_event confirm "+product_id+"]";
		out += "\n";
	}
	out += "\n[返回活动页:timed_event]|[返回游戏:look]\n";
	return out;
}

string query_event_shop_confirm_page(object player,string product_id)
{
	mapping product = event_shop_catalog()[product_id];
	mapping state;
	string token_key;
	if(!player || !mappingp(product))
		return "没有找到该兑换项目。\n[返回商店:timed_event shop]\n";
	state = normalize_player_event_state(player);
	token_key = (string)product["token_key"];
	return "【确认兑换】\n"+(string)product["name"]+"\n"+
		(string)product["desc"]+"\n需要："+(string)product["cost"]+
		event_shop_token_name(token_key)+"\n当前持有："+
		(string)state[token_key]+event_shop_token_name(token_key)+"\n\n"+
		"[确认兑换:timed_event exchange "+product_id+"]|"+
		"[取消:timed_event shop]\n";
}

private object|zero create_bound_event_shop_item(string item_path)
{
	object|zero item = 0;
	mixed err = catch{
		item = clone(ROOT+item_path);
	};
	if(err || !item)
		return 0;
	item->set_item_canDrop(0);
	item->set_item_canGet(0);
	item->set_item_canTrade(0);
	item->set_item_canSend(0);
	item->set_item_canStorage(1);
	return item;
}

string exchange_event_shop_item(object player,string product_id)
{
	mapping product = event_shop_catalog()[product_id];
	mapping state;
	mapping badges;
	string token_key;
	string kind;
	string badge_id = "";
	int cost;
	int balance;
	int money_before = 0;
	int save_ok = 1;
	object|zero item = 0;
	if(!player || !mappingp(product))
		return "没有找到该兑换项目，本次没有扣除令牌。\n[返回商店:timed_event shop]\n";
	if(player->query_in_combat() || is_event_room(environment(player)))
		return "战斗或活动进行中不能兑换，请先安全结束当前战斗。\n[返回:look]\n";
	state = normalize_player_event_state(player);
	badges = state["badges"];
	token_key = (string)product["token_key"];
	kind = (string)product["kind"];
	cost = (int)product["cost"];
	balance = (int)state[token_key];
	if(cost<=0 || (token_key!="tianheng_tokens" &&
	   token_key!="jiuyao_tokens"))
		return "兑换配置异常，本次没有扣除令牌。\n[返回商店:timed_event shop]\n";
	if(kind=="badge"){
		badge_id = (string)product["badge_id"];
		if((int)badges[badge_id])
			return "该永久徽记已经拥有，不能重复兑换。\n[返回商店:timed_event shop]\n";
	}
	if(balance<cost)
		return event_shop_token_name(token_key)+"不足，需要"+
			(string)cost+"枚，当前只有"+(string)balance+
			"枚。\n[返回商店:timed_event shop]\n";
	if(kind=="item"){
		if(player->if_over_easy_load())
			return "包袱已满，请先整理物品再兑换。\n[返回商店:timed_event shop]\n";
		item = create_bound_event_shop_item((string)product["item_path"]);
		if(!item || !item->move(player) || environment(item)!=player){
			if(item)
				destruct(item);
			return "物品发放失败，本次没有扣除令牌。\n[返回商店:timed_event shop]\n";
		}
	}
	else if(kind=="money"){
		money_before = player->query_account();
		player->add_account((int)product["amount"]);
	}
	else if(kind!="badge")
		return "兑换配置异常，本次没有扣除令牌。\n[返回商店:timed_event shop]\n";
	state[token_key] = balance-cost;
	if(kind=="badge")
		badges[badge_id] = 1;
	if((string)player->sid!="5dwap"){
		if(!functionp(player->save_with_result))
			save_ok = 0;
		else
			save_ok = player->save_with_result();
	}
	if(!save_ok){
		state[token_key] = balance;
		if(kind=="badge")
			m_delete(badges,badge_id);
		if(kind=="money")
			player->set_account(money_before);
		if(item)
			destruct(item);
		return "人物存档失败，兑换已经回滚，令牌没有扣除。\n[返回商店:timed_event shop]\n";
	}
	Stdio.append_file(ROOT+"/log/timed_event_shop.log",
		ctime(time())[0..sizeof(ctime(time()))-2]+" user="+
		player->query_name()+" product="+product_id+" cost="+
		(string)cost+" balance="+(string)state[token_key]+"\n");
	return "兑换成功：获得"+(string)product["name"]+"，消耗"+
		(string)cost+event_shop_token_name(token_key)+"。\n剩余"+
		event_shop_token_name(token_key)+"："+(string)state[token_key]+
		"\n[继续兑换:timed_event shop]|[查看物品:inventory]|[返回游戏:look]\n";
}
