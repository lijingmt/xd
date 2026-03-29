#include <command.h>
#include <gamelib/include/gamelib.h>

/**
 * 解锁方士职业命令
 * 方士是免费职业，所有玩家都可以解锁
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

	// 显示解锁确认界面
	if(!arg){
		s += "【方士职业解锁】\n\n";
		s += "方士介绍：\n";
		s += "- 中立阵营，召唤师/辅助职业\n";
		s += "- 可以召唤虎灵（物理攻击）、鹤灵（治疗）、龟灵（防御）\n";
		s += "- 终极技能三灵合一，全面强化自身\n\n";
		s += "解锁是免费的，所有玩家都可以创建方士角色！\n\n";
		s += "[确认解锁:unlock_fangshi confirm]\n";
		s += "[返回游戏:look]\n";
		me->write(s);
		return 1;
	}

	// 确认解锁
	if(arg == "confirm"){
		// 直接解锁，无需任何条件
		SEASONALD->unlock_fangshi(me->query_name());

		s += "恭喜！你成功解锁了方士职业！\n\n";
		s += "现在你可以创建方士角色了！\n";
		s += "重新登录后即可在职业选择中选择方士。\n";
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
