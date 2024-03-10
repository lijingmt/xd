#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>

//服务中心
int main(string arg)
{
	object me = this_player();
	string s = "";
	string masterId = me->query_name();
	object env = environment(me);
	int ind = (int)arg;
	//只有房间的主人才能进服务中心领取物品
	if(HOMED->is_master(env->homeId)){
	int result = HOMED->get_pass_time_ob(me,ind);
	if(result){
		s += "领取成功\n";
		HOMED->save_shopItem(masterId,"",ind);
	}
	else 
		s += "领取失败，请与客服联系\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
