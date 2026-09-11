#include <command.h>
#include <gamelib/include/gamelib.h>
//此指令列出玩家身上可供属性转换的装备列表。
// 已装备的排最前并带【已装备】标识；支持按部位筛选，便于从
// 几百件装备里快速定位（玩家反馈 2026-08-27）。
mapping(string:string) query_convert_slot_labels()
{
	return ([
		"double_main_weapon":"双手武器",
		"single_main_weapon":"主手",
		"single_other_weapon":"副手",
		"armor_head":"头部",
		"armor_cloth":"衣服",
		"armor_waste":"护腕",
		"armor_hand":"手部",
		"armor_thou":"腿部",
		"armor_shoes":"脚部",
		"jewelry_ring":"戒指",
		"jewelry_neck":"项链",
		"jewelry_bangle":"手镯",
		"decorate_manteau":"披风",
		"decorate_thing":"挂件",
		"decorate_tool":"携带物",
	]);
}

int main(string|zero arg)
{
	mapping(string:string) slots=query_convert_slot_labels();
	string filter = arg ? String.trim_all_whites(arg) : "all";
	string s;
	object me=this_player();
	array(object) all_obj = all_inventory(me);
	array(object) equipped=({});
	array(object) loose=({});
	if(!slots[filter])
		filter="all";
	foreach(all_obj,object ob){
		if(ob && functionp(ob->query_catchup_equipment) &&
		   ob->query_catchup_equipment())
			continue;
		if(!(ob && ITEMSD->can_equip(ob) &&
		   ((ob->query_item_rareLevel()>0)||
		    (ob->query_item_canLevel()>=1 &&
		     (sizeof(ob->query_name_cn()/"】"))==1)||
		    (functionp(ob->query_newmoon_collection_id)&&
		     (string)ob->query_newmoon_collection_id()!=""))))
			continue;
		if(filter!="all" &&
		   (string)ob->query_item_kind()!=filter)
			continue;
		if((int)ob->equiped)
			equipped+=({ob});
		else
			loose+=({ob});
	}
	s="选择你需要炼化的装备"+
		(filter=="all" ? "" : "（"+slots[filter]+"）")+"\n";
	/* 最近炼化扣费历史（最近5条）：玩家从随身洗装入口进来第一眼
	 * 就能看到花了多少，不用点进具体装备。 */
	{
		array fee_history=me["/plus/convert_fee_history"];
		if(arrayp(fee_history) && sizeof(fee_history)){
			int shown=0;
			int total_jade=0;
			int total_gold=0;
			string history_text="";
			for(int hi=0;hi<sizeof(fee_history) && shown<5;hi++){
				mapping one=fee_history[hi];
				mapping lt;
				if(!mappingp(one))
					continue;
				lt=localtime((int)one["t"]);
				total_jade+=(int)one["cost"];
				total_gold+=(int)one["money"];
				history_text+=sprintf("· %02d:%02d %s 扣%d碎玉%s\n",
					(int)lt["hour"],(int)lt["min"],
					(string)one["label"],(int)one["cost"],
					(int)one["money"]>0 ?
						sprintf("，%d金币",(int)one["money"]) : "");
				shown++;
			}
			if(shown>0){
				history_text+="以上"+shown+"次合计：扣"+total_jade+"碎玉"+
					(total_gold>0 ? "，"+total_gold+"金币" : "")+"。\n";
				s+="【炼化历史】最近"+shown+"次\n"+history_text;
			}
		}
	}
	if(!sizeof(equipped) && !sizeof(loose))
		s+="没有符合条件的装备。\n";
	foreach(equipped,object ob)
		s+="[【已装备】"+ob->query_name_cn()+
			":convert_equip_detail "+ob->query_name()+" 0]\n";
	foreach(loose,object ob)
		s+="["+ob->query_name_cn()+
			":convert_equip_detail "+ob->query_name()+" 0]\n";
	s+="\n部位：";
	foreach(sort(indices(slots)),string slot)
		s+=(slot==filter ? "【"+slots[slot]+"】" :
			"["+slots[slot]+":convert_equip_list "+slot+"]")+" ";
	s+="[全部:convert_equip_list]\n[返回游戏:look]\n";
	write(s);
	return 1;
}
