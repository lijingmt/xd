#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//-升级换玉石-推广活动，获得玉石的方法。

int main(string arg)
{
	object me = this_player();
	object yushi;
	string s_log = "";
	int yushi_num = (int)arg;
	string yushi_type = "suiyu";
	string yushi_type_cn = "碎玉";
	string now = ctime(time());
	int level = me->query_level();
	int yushi_flag= me->query_yushi_flag();
	string desc="";

	int n = level/5;

	if(yushi_flag<5*n)
	{
		if(yushi_num>=20)
		{
			yushi_type = "xianyuanyu";
			yushi_num = yushi_num/10;
			yushi_type_cn = "仙缘玉";
		}
		mixed err=catch{
			yushi = clone(YUSHI_PATH+yushi_type);
		};
		if(!err && yushi){
			yushi->amount = yushi_num;
			if(!me->if_over_load(yushi))
			{
				yushi->move_player(me->query_name());
				me->set_yushi_flag(5*n);
				desc += "恭喜!你已经获得"+yushi_num+"块"+yushi_type_cn+"\n";
				s_log = me->query_name_cn()+"("+me->query_name()+") 升级换玉石获得"+yushi_type_cn+yushi_num+"块\n";
				Stdio.append_file(ROOT+"/log/fee_log/yushi_tuiguang.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				desc += "你的背包已满，领取玉石失败。\n";
			}
		}
		else{
			s_log = me->query_name_cn()+"("+me->query_name()+") tuiguang_yushi error! 升级换玉石时无法获得物品\n";
			Stdio.append_file(ROOT+"/log/fee_log/yushi_tuiguang_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
		}
	}
	else
	{
		desc +="你已经领取过玉石，请返回游戏。\n";
	}
	desc += "[返回游戏:look]\n";
	write(desc);
	return 1;
}
