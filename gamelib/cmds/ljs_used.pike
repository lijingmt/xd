#include <command.h>
#include <gamelib/include/gamelib.h>
//鎏金石的使用
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(arg=="open"){
		if(!me->ljs_time||me->ljs_time<=0){
			s += "抱歉，鎏金石的有效时间已经使用完,您只有购买才能继续使用\n";
			s += "[购买:ljs_chongzhi_detail]\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
		else{
			me->ljs_sw = arg;
			s += "鎏金石已生效并开始计时\n";
		}
	}
	else if(arg=="close"){
		me->ljs_sw = arg;
		s += "鎏金石的效果已被关闭，在这期间如果被其它玩家或怪杀死，您的经验将会损失\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
