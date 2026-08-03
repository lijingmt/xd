/** Vue人物装备面板的只读结构化数据。换装仍通过现有核心命令执行。 */

#ifndef XIAND_HTTP_API_EQUIPMENT_PANEL_PIKE
#define XIAND_HTTP_API_EQUIPMENT_PANEL_PIKE

private mapping(string:mapping(string:string)) equipment_panel_slots = ([
	"double_main_weapon":(["label":"双手武器","icon":"⚔","group":"weapon"]),
	"single_main_weapon":(["label":"主手","icon":"剑","group":"weapon"]),
	"single_other_weapon":(["label":"副手","icon":"刃","group":"weapon"]),
	"armor_head":(["label":"头部","icon":"冠","group":"body"]),
	"armor_cloth":(["label":"衣服","icon":"衣","group":"body"]),
	"armor_waste":(["label":"护腕","icon":"腕","group":"body"]),
	"armor_hand":(["label":"手部","icon":"手","group":"body"]),
	"armor_thou":(["label":"腿部","icon":"腿","group":"body"]),
	"armor_shoes":(["label":"脚部","icon":"履","group":"body"]),
	"jewelry_ring":(["label":"戒指","icon":"戒","group":"jewelry"]),
	"jewelry_neck":(["label":"项链","icon":"链","group":"jewelry"]),
	"jewelry_bangle":(["label":"手镯","icon":"镯","group":"jewelry"]),
	"decorate_manteau":(["label":"披风","icon":"披","group":"decorate"]),
	"decorate_thing":(["label":"挂件","icon":"佩","group":"decorate"]),
	"decorate_tool":(["label":"携带物","icon":"宝","group":"decorate"]),
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

private mapping query_equipment_panel_item(object item,int count)
{
	string item_type = (string)item->query_item_type();
	string item_name = (string)item->query_name();
	int equipped = (int)(item->equiped || 0);
	string action = equipped ?
		(is_equipment_panel_weapon(item_type) ? "unwield" : "unwear") :
		(is_equipment_panel_weapon(item_type) ? "wield" : "wear");
	return ([
		"id":item_name+"#"+count,
		"name":item_name,
		"name_cn":(string)item->query_short(),
		"slot":(string)item->query_item_kind(),
		"item_type":item_type,
		"level_requirement":(int)item->query_item_canLevel(),
		"rare_level":(int)item->query_item_rareLevel(),
		"equipped":equipped,
		"action":action,
		"action_label":equipped ? "卸下" : "穿戴",
		"action_cmd":action+" "+item_name+" "+count,
	]);
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
	result["player"] = ([
		"name":player->query_name(),
		"name_cn":player->query_name_cn(),
		"level":player->query_level(),
		"profession":player->query_profe_cn(player->query_profeId()),
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
