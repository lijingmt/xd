#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	object env = environment(me);
	string s = "";
	string masterId = me->query_name();
	string homeId = env->query_homeId();
	//werror("------homeId="+homeId+"-----\n");
	//werror("------is_master="+HOMED->is_master(homeId)+"--if_have_shopLicense="+HOMED->if_have_shopLicense(masterId)+"\n");
	if(HOMED->is_master(homeId) && HOMED->if_have_shopLicense(masterId)){
		//是房间的主人且已经购买了小店许可
		int tw_count = HOMED->query_tanwei_count(masterId);
		int tanwei_up = HOMED->query_tanwei_up(masterId);
		if(tw_count<tanwei_up){
			//摊位数量还没达到上限
			HOMED->save_shopItem(masterId,"",tw_count+1);//增加一个摊位
			s += "增加摊位成功^0^\n";
		}
		else{
			s += HOMED->get_home_level(masterId)+"级的家园最多能设置"+tanwei_up+"个摊位，您已经达到了这个限制\n";
		}
	}
	else{
		s += "您还没有店铺，不能在家园里摆摊，维护家园秩序，人人有责\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
