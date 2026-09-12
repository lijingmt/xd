/**
 * 三战斗系统（建议12）：一键在“打怪输出/BOSS幸运/PK”三套
 * 装备+技能逻辑之间切换。
 *
 * 方案：玩家先穿好某一身装备、调好挂机技能队列，用“保存”录入
 * 对应槽位（快照存人物档 /plus/battle_systems/，按装备模板与
 * 部位记录，跨重启可还原）。切换时卸下当前全身装备，按快照从
 * 背包找回同模板装备穿回，再恢复该槽位保存的技能模式与队列：
 * 槽1默认智能推荐（AOE优先，适合打怪），槽2/3默认手动队列
 * （玩家自配单体高CD、治疗净化或PK逻辑）。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define BATTLE_SYSTEM_COUNT 3

private array(string) battle_system_titles = ({
	"打怪输出","BOSS幸运","PK对决",
});
private array(string) battle_system_descs = ({
	"技能走智能推荐（优先群攻）",
	"切幸运装打BOSS掉落/洗练（自配技能队列）",
	"切PK装对战（自配技能队列）",
});

private string battle_system_item_template(object item)
{
	return (file_name(item)/"#")[0];
}

private int battle_system_is_weapon(object item)
{
	return search(({"weapon","single_weapon","double_weapon"}),
		(string)item->query_item_type())!=-1;
}

string query_battle_system_title(int slot)
{
	return slot>=1 && slot<=BATTLE_SYSTEM_COUNT ?
		battle_system_titles[slot-1] : "";
}

array(mapping(string:mixed)) query_battle_systems(object me)
{
	array(mapping(string:mixed)) out = ({});
	if(!me)
		return out;
	for(int slot=1;slot<=BATTLE_SYSTEM_COUNT;slot++){
		mapping saved = me["/plus/battle_systems/"+slot];
		out += ({([
			"slot":slot,
			"title":battle_system_titles[slot-1],
			"desc":battle_system_descs[slot-1],
			"saved":mappingp(saved) &&
				sizeof((array)(saved["equips"] || ({})))>0,
			"saved_at":mappingp(saved) ? (int)(saved["saved_at"] || 0) : 0,
			"equip_count":mappingp(saved) ?
				sizeof((array)(saved["equips"] || ({}))) : 0,
			"skill_mode":mappingp(saved) ?
				(string)(saved["skill_mode"] || "") : "",
		])});
	}
	return out;
}

/** 保存当前穿戴+技能逻辑为指定槽位。 */
mapping save_battle_system(object me,int slot)
{
	array(mapping(string:string)) entries = ({});
	if(!me || !functionp(me->query_name))
		return (["ok":0,"message":"参数无效。"]);
	if(slot<1 || slot>BATTLE_SYSTEM_COUNT)
		return (["ok":0,"message":"槽位无效。"]);
	if(me->query_in_combat())
		return (["ok":0,"message":"交战中不能保存，请脱离战斗后再试。"]);
	foreach(all_inventory(me),object item){
		if(!item || !item->is || !item->is("equip") || !item->equiped)
			continue;
		string kind = (string)item->query_item_kind();
		if(kind=="")
			continue;
		entries += ({([
			"kind":kind,
			"template":battle_system_item_template(item),
			"name_cn":(string)item->query_name_cn(),
		])});
	}
	if(!sizeof(entries))
		return (["ok":0,"message":"你身上没有穿戴任何装备"]);
	me["/plus/battle_systems/"+slot] = ([
		"saved_at":time(),
		"equips":entries,
		"skill_mode":AUTOFIGHTD->query_auto_skill_mode(me),
		"skill_queue":AUTOFIGHTD->query_auto_skill_queue(me),
	]);
	if(!me->save_with_result())
		return (["ok":0,"message":"存档失败，请稍后再试。"]);
	return (["ok":1,"count":sizeof(entries)]);
}

/** 切换到指定槽位：卸下全身→按快照穿回→恢复技能逻辑。 */
mapping use_battle_system(object me,int slot)
{
	mapping saved;
	array(mapping(string:string)) entries;
	int equipped = 0;
	array(string) missing = ({});
	if(!me || !functionp(me->query_name))
		return (["ok":0,"message":"参数无效。"]);
	if(slot<1 || slot>BATTLE_SYSTEM_COUNT)
		return (["ok":0,"message":"槽位无效。"]);
	if(me->query_in_combat())
		return (["ok":0,"message":"交战中不能切换，请脱离战斗后再试。"]);
	saved = me["/plus/battle_systems/"+slot];
	if(!mappingp(saved) || !arrayp(saved["equips"]) ||
	   !sizeof((array)saved["equips"]))
		return (["ok":0,"message":"这一槽位还没有保存过装备：先穿好对应套装，回到战斗系统页执行[保存]。"]);
	entries = (array(mapping(string:string)))saved["equips"];
	// 1. 卸下当前全身装备。
	foreach(all_inventory(me),object item){
		if(!item || !item->equiped)
			continue;
		if(battle_system_is_weapon(item))
			me->unwield(item);
		else
			me->unwear(item);
	}
	// 2. 按快照从背包找回同模板装备穿回。
	foreach(entries,mapping entry){
		object|zero found = 0;
		string template = (string)entry["template"];
		if(template=="")
			continue;
		foreach(all_inventory(me),object item){
			if(!item || !item->is || !item->is("equip") ||
			   item->equiped)
				continue;
			if(battle_system_item_template(item)!=template)
				continue;
			found = item;
			break;
		}
		if(!found){
			missing += ({(string)entry["name_cn"]});
			continue;
		}
		int worn = battle_system_is_weapon(found) ?
			me->wield(found) : me->wear(found);
		if(worn && found->equiped)
			equipped++;
		else
			missing += ({(string)entry["name_cn"]});
	}
	// 3. 恢复该槽位的技能模式与队列。
	string mode = (string)(saved["skill_mode"] || "");
	if(mode=="smart")
		AUTOFIGHTD->set_auto_skill_mode(me,"smart");
	else if(mode=="manual" && arrayp(saved["skill_queue"]))
		AUTOFIGHTD->restore_auto_skill_queue(me,
			(array(string))saved["skill_queue"]);
	if(!me->save_with_result())
		return (["ok":0,"message":"切换后存档失败，请重新登录确认状态。"]);
	mapping result = (["ok":1,"equipped":equipped,
		"title":battle_system_titles[slot-1]]);
	if(sizeof(missing))
		result["missing"] = missing;
	return result;
}

string query_battle_system_page(object me)
{
	string s;
	if(!me || !functionp(me->query_name))
		return "参数无效。\n[返回游戏:look]\n";
	s = "§g战斗系统§r（装备+技能逻辑一键切换）\n";
	s += "用法：先穿好一身装备并调好挂机技能队列，[保存]到槽位；"+
		"之后随时[切换]回该套装。\n";
	s += "槽1推荐保存打怪输出装（技能=智能推荐，优先群攻）；"+
		"槽2保存BOSS幸运装；槽3保存PK装。\n\n";
	foreach(query_battle_systems(me),mapping one){
		s += "§y"+(string)(int)one["slot"]+"．"+(string)one["title"]+"§r　"+
			(string)one["desc"]+"\n";
		if((int)one["saved"])
			s += "　已保存"+(string)(int)one["equip_count"]+"件"+
				"（技能："+(string)one["skill_mode"]+"）"+
				"[切换:battle_system use "+(string)(int)one["slot"]+"]"+
				"[覆盖保存:battle_system save "+(string)(int)one["slot"]+"]\n";
		else
			s += "　未保存　[保存当前穿戴:battle_system save "+
				(string)(int)one["slot"]+"]\n";
	}
	s += "\n提示：切下的装备留在背包；找不到的部件会在结果里点名。\n";
	s += "[智能换装:auto_equip]|[返回游戏:look]\n";
	return s;
}
