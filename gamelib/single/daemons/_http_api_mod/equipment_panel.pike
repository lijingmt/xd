/** Vue人物装备面板的只读结构化数据。换装仍通过现有核心命令执行。 */

#ifndef XIAND_HTTP_API_EQUIPMENT_PANEL_PIKE
#define XIAND_HTTP_API_EQUIPMENT_PANEL_PIKE

private mapping(string:mapping(string:string)) equipment_panel_slots = ([
	"double_main_weapon":(["label":"双手武器","icon":"⚔","group":"weapon",
		"image":"/images/equipment/fallback/double_main_weapon.png"]),
	"single_main_weapon":(["label":"主手","icon":"剑","group":"weapon",
		"image":"/images/equipment/fallback/single_main_weapon.png"]),
	"single_other_weapon":(["label":"副手","icon":"刃","group":"weapon",
		"image":"/images/equipment/fallback/single_other_weapon.png"]),
	"armor_head":(["label":"头部","icon":"冠","group":"body",
		"image":"/images/equipment/fallback/armor_head.png"]),
	"armor_cloth":(["label":"衣服","icon":"衣","group":"body",
		"image":"/images/equipment/fallback/armor_cloth.png"]),
	"armor_waste":(["label":"护腕","icon":"腕","group":"body",
		"image":"/images/equipment/fallback/armor_waste.png"]),
	"armor_hand":(["label":"手部","icon":"手","group":"body",
		"image":"/images/equipment/fallback/armor_hand.png"]),
	"armor_thou":(["label":"腿部","icon":"腿","group":"body",
		"image":"/images/equipment/fallback/armor_thou.png"]),
	"armor_shoes":(["label":"脚部","icon":"履","group":"body",
		"image":"/images/equipment/fallback/armor_shoes.png"]),
	"jewelry_ring":(["label":"戒指","icon":"戒","group":"jewelry",
		"image":"/images/equipment/fallback/jewelry_ring.png"]),
	"jewelry_neck":(["label":"项链","icon":"链","group":"jewelry",
		"image":"/images/equipment/fallback/jewelry_neck.png"]),
	"jewelry_bangle":(["label":"手镯","icon":"镯","group":"jewelry",
		"image":"/images/equipment/fallback/jewelry_bangle.png"]),
	"decorate_manteau":(["label":"披风","icon":"披","group":"decorate",
		"image":"/images/equipment/fallback/decorate_manteau.png"]),
	"decorate_thing":(["label":"挂件","icon":"佩","group":"decorate",
		"image":"/images/equipment/fallback/decorate_thing.png"]),
	"decorate_tool":(["label":"携带物","icon":"宝","group":"decorate",
		"image":"/images/equipment/fallback/decorate_tool.png"]),
]);

private int is_equipment_panel_type(string item_type)
{
	return search(({"weapon","single_weapon","double_weapon","armor",
		"jewelry","decorate"}),item_type)!=-1;
}

private int is_equipment_panel_weapon(string item_type)
{
	return search(({"weapon","single_weapon","double_weapon"}),
		item_type)!=-1;
}

private int valid_equipment_picture_name(string picture)
{
	if(!picture || picture=="" || sizeof(picture)>160 ||
	   search(picture,"..")!=-1)
		return 0;
	foreach(picture;int index;int one){
		if((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		   (one>='0' && one<='9') || one=='_' || one=='-' || one=='/')
			continue;
		return 0;
	}
	return 1;
}

private string query_equipment_panel_image(object item,string slot)
{
	string fallback = equipment_panel_slots[slot] ?
		(string)equipment_panel_slots[slot]["image"] :
		"/images/equipment/fallback/decorate_tool.png";
	string picture = functionp(item->query_picture) ?
		(string)(item->query_picture() || "") : "";
	if(!valid_equipment_picture_name(picture))
		return fallback;
	foreach(({".gif",".png",".webp",".jpg"}),string extension)
		if(Stdio.file_size(ROOT+"/images/"+picture+extension)>0)
			return "/images/"+picture+extension;
	return fallback;
}

private mapping query_equipment_panel_item(object item,int count)
{
	string item_type = (string)item->query_item_type();
	string item_name = (string)item->query_name();
	string slot = (string)item->query_item_kind();
	int equipped = (int)(item->equiped || 0);
	string action = equipped ?
		(is_equipment_panel_weapon(item_type) ? "unwield" : "unwear") :
		(is_equipment_panel_weapon(item_type) ? "wield" : "wear");
	return ([
		"id":item_name+"#"+count,
		"name":item_name,
		"name_cn":(string)item->query_short(),
		"slot":slot,
		"item_type":item_type,
		"image_url":query_equipment_panel_image(item,slot),
		"image_fallback":equipment_panel_slots[slot] ?
			(string)equipment_panel_slots[slot]["image"] :
			"/images/equipment/fallback/decorate_tool.png",
		"level_requirement":(int)item->query_item_canLevel(),
		"rare_level":(int)item->query_item_rareLevel(),
		"equipped":equipped,
		"action":action,
		"action_label":equipped ? "卸下" : "穿戴",
		"action_cmd":action+" "+item_name+" "+count,
		"attrs":query_equipment_panel_attrs(item,item_type),
	]);
}

/* 只读属性快照（与 auto_equip 评分同一批 getter），供客户端
 * 做"候选装备 vs 已穿戴"的增减对比。只返回非零项。 */
private mapping query_equipment_panel_attrs(object item,string item_type)
{
	mapping(string:int) attrs = ([]);
	if(is_equipment_panel_weapon(item_type)){
		if((int)item->query_attack_power()>0)
			attrs["attack"]=(int)item->query_attack_power();
		if((int)item->query_attack_power_limit()>0)
			attrs["attack_limit"]=(int)item->query_attack_power_limit();
		if((int)item->query_attack_add()>0)
			attrs["attack_add"]=(int)item->query_attack_add();
		if((int)item->query_hitte_add()>0)
			attrs["hitte"]=(int)item->query_hitte_add();
		if((int)item->query_doub_add()>0)
			attrs["doub"]=(int)item->query_doub_add();
	}
	else{
		if((int)item->query_equip_defend()>0)
			attrs["defend"]=(int)item->query_equip_defend();
		if((int)item->query_dodge_add()>0)
			attrs["dodge"]=(int)item->query_dodge_add();
		if((int)item->query_recive_add()>0)
			attrs["recive"]=(int)item->query_recive_add();
	}
	if((int)item->query_str_add()>0)
		attrs["str"]=(int)item->query_str_add();
	if((int)item->query_dex_add()>0)
		attrs["dex"]=(int)item->query_dex_add();
	if((int)item->query_think_add()>0)
		attrs["think"]=(int)item->query_think_add();
	if((int)item->query_life_add()>0)
		attrs["life"]=(int)item->query_life_add();
	if((int)item->query_mofa_add()>0)
		attrs["mofa"]=(int)item->query_mofa_add();
	if((int)item->query_all_add()>0)
		attrs["all"]=(int)item->query_all_add();
	return attrs;
}

private mapping query_equipment_panel_state(object player)
{
	mapping result = ([
		"slots":copy_value(equipment_panel_slots),
		"equipped":([]),
		"candidates":([]),
		"slot_order":({"armor_head","jewelry_neck","decorate_manteau",
			"single_main_weapon","armor_cloth","single_other_weapon",
			"armor_waste","armor_hand","jewelry_bangle","jewelry_ring",
			"decorate_thing","armor_thou","armor_shoes","decorate_tool",
			"double_main_weapon"}),
	]);
	mapping(string:int) name_count = ([]);
	foreach(indices(equipment_panel_slots),string slot)
		result["candidates"][slot] = ({});
	foreach(all_inventory(player),object item){
		if(!item || !item->is || !item->is("equip") ||
		   !is_equipment_panel_type((string)item->query_item_type()))
			continue;
		string name = (string)item->query_name();
		int count = (int)name_count[name];
		name_count[name] = count+1;
		mapping item_view = query_equipment_panel_item(item,count);
		string slot = (string)item_view["slot"];
		if(!equipment_panel_slots[slot])
			continue;
		result["candidates"][slot] += ({item_view});
		if(item_view["equipped"])
			result["equipped"][slot] = item_view;
	}
	int heart_str=(int)player->query_taiji_heart_bonus("str")+
		(int)player->query_wuxiang_heart_bonus("str");
	int heart_dex=(int)player->query_taiji_heart_bonus("dex")+
		(int)player->query_wuxiang_heart_bonus("dex");
	int heart_think=(int)player->query_taiji_heart_bonus("think")+
		(int)player->query_wuxiang_heart_bonus("think");
	result["player"] = ([
		"name":player->query_name(),
		"name_cn":player->query_name_cn(),
		"level":player->query_level(),
		"profession":player->query_profe_cn(player->query_profeId()),
		"total_str":(int)player->query_str(),
		"total_dex":(int)player->query_dex(),
		"total_think":(int)player->query_think(),
		"heart_bonus_str":heart_str,
		"heart_bonus_dex":heart_dex,
		"heart_bonus_think":heart_think,
	]);
	return result;
}

void handle_api_equipment_panel(Protocols.HTTP.Server.Request req)
{
	mapping params = get_params(req);
	string txd = url_decode(params["txd"]);
	if(!txd || txd=="" || txd==" "){
		send_json(req,(["error":"需要认证信息：txd"]),400);
		return;
	}
	mapping auth = decode_txd(txd);
	if(!auth){
		send_json(req,(["error":"TXD认证信息无效"]),401);
		return;
	}
	string userid = (string)auth["userid"];
	// 装备面板是只读查询，不延长玩家在线时间。
	object player = get_player_from_connection(userid,0);
	if(!player)
		player = find_player(userid);
	if(!player){
		send_json(req,(["error":"玩家未登录"]),401);
		return;
	}
	send_json(req,query_equipment_panel_state(player));
}

#endif
