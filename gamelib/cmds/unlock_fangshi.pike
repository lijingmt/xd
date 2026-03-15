#include <command.h>
#include <gamelib/include/gamelib.h>

/**
 * 解锁方士职业命令
 * 需要钻石会员(VIP level 4)才能解锁
 */
int main(string|zero arg)
{
	object me = this_player();
	string s = "";

	if(!me)
		return 0;

	// 检查是否已解锁
	if(SEASONALD->is_fangshi_unlocked(me->query_name())){
		s += "你已经解锁了方士职业！\n";
		s += "[返回游戏:look]\n";
		me->write(s);
		return 1;
	}

	// 检查VIP等级
	int vip_level = me->query_vip_flag();
	if(vip_level < 4){
		s += "【方士职业解锁】\n\n";
		s += "方士是赛季限定职业，需要钻石会员才能解锁！\n\n";
		s += "你当前的会员等级：";
		switch(vip_level){
			case 0: s += "非会员\n"; break;
			case 1: s += "水晶会员\n"; break;
			case 2: s += "黄金会员\n"; break;
			case 3: s += "白金会员\n"; break;
		}
		s += "\n升级到钻石会员后即可解锁方士职业！\n";
		s += "[查看会员服务:vip_service_extend_list]\n";
		s += "[返回游戏:look]\n";
		me->write(s);
		return 1;
	}

	// 显示解锁确认界面
	if(!arg){
		int cost = SEASONALD->get_unlock_cost();
		s += "【方士职业解锁】\n\n";
		s += "恭喜你，你是钻石会员，可以解锁方士职业！\n\n";
		s += "方士介绍：\n";
		s += "- 中立阵营，召唤师/辅助职业\n";
		s += "- 可以召唤虎灵（物理攻击）、鹤灵（治疗）、龟灵（防御）\n";
		s += "- 终极技能三灵合一，全面强化自身\n\n";
		s += "解锁需要：\n";
		s += "- " + YUSHID->get_yushi_for_desc(cost) + "\n\n";
		s += "[确认解锁:unlock_fangshi confirm]\n";
		s += "[返回游戏:look]\n";
		me->write(s);
		return 1;
	}

	// 确认解锁
	if(arg == "confirm"){
		int cost = SEASONALD->get_unlock_cost();

		// 检查碎玉
		if(me->query_yushi() < cost){
			s += "你的碎玉不足！需要 " + YUSHID->get_yushi_for_desc(cost) + "\n";
			s += "[返回游戏:look]\n";
			me->write(s);
			return 1;
		}

		// 扣除碎玉
		me->add_yushi(-cost);

		// 解锁
		SEASONALD->unlock_fangshi(me->query_name());

		// 广播
		BROADCASTD->broadcast(me->query_name_cn() + " 解锁了方士职业，从此踏上了召唤师之路！\n");

		s += "恭喜！你成功解锁了方士职业！\n\n";
		s += "现在你可以创建方士角色了！\n";
		s += "方士将随机在从仙镇或聚妖岛出生\n";
		s += "[返回游戏:look]\n";
		me->write(s);

		// 保存
		me->save();
		return 1;
	}

	s += "参数错误\n[解锁方士:unlock_fangshi]\n";
	me->write(s);
	return 1;
}
