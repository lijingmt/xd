#include <command.h>
#include <gamelib/include/gamelib.h>

private string view_names(array names)
{
	string out;
	int maximum;
	out = "";
	maximum = sizeof(names) > 12 ? 12 : sizeof(names);
	for(int i = 0;i < maximum;i++)
		out += "· "+names[i]+"\n";
	if(sizeof(names) > maximum)
		out += "· 另有"+(sizeof(names)-maximum)+"种\n";
	return out;
}

int main(string|zero arg)
{
	object me;
	mapping preview;
	mapping result;
	array names;
	string out;
	me = this_player();
	if(!me)
		return 1;
	if(me->in_combat){
		write("战斗中不能清理背包，请脱离战斗后再试。\n");
		write("[返回游戏:look]\n");
		return 1;
	}
	if(arg == "confirm"){
		result = AUTOFIGHTD->perform_non_equipment_destroy(me,"manual");
		if((int)result["object_count"] <= 0){
			write("当前没有符合安全规则的非装备物品可销毁。\n");
			write("[返回背包:inventory]|[挂机清理设置:autofight cleanup]\n");
			return 1;
		}
		write("已销毁"+(int)result["object_count"]+"组，共"+
			(int)result["item_count"]+"个非装备物品。\n");
		names = result["names"];
		write(view_names(names));
		write("装备和受保护物品均已保留；本次操作已写入审计日志。\n");
		write("[返回背包:inventory]|[挂机清理设置:autofight cleanup]\n");
		return 1;
	}
	preview = AUTOFIGHTD->query_non_equipment_destroy_preview(me);
	out = "【一键安全销毁非装备】\n";
	if((int)preview["object_count"] <= 0){
		out += "当前没有符合安全规则的非装备物品可销毁。\n\n";
		out += "[返回背包:inventory]|[挂机清理设置:autofight cleanup]\n";
		write(out);
		return 1;
	}
	out += "即将销毁"+(int)preview["object_count"]+"组，共"+
		(int)preview["item_count"]+"个：\n";
	names = preview["names"];
	out += view_names(names);
	out += "\n永久保留：全部装备、任务物品、技能书、玉石、宝箱、丹药、食物饮品，以及不可丢弃/交易/存储、唯一、特殊来源或玩家标记物品。\n";
	out += "销毁后不能恢复，也不会获得金币。\n\n";
	out += "[确认销毁:cleanup_non_equipment confirm]\n";
	out += "[一键摧毁低级书卷:book_cleanup]|[取消:inventory]|[挂机清理设置:autofight cleanup]\n";
	write(out);
	return 1;
}
