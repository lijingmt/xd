#include <command.h>
#include <gamelib/include/gamelib.h>
// 挂机确认页面
int main(string arg)
{
	string s = "";
	object me = this_player();
	string type = "";  //挂机类型
	string typeDes = "";//挂机类型中文描述
	string yushi_s = "";
	int yushi = 0;     //玩家使用的玉石数目
	int time = 0;      //新增加的时间
	int myTime = 0;    //原有的时间
	int timeTotal = 0; //总时间
	int myYushi = YUSHID->query_yushi_num(me,1);   //玩家身上的碎玉数目
	sscanf(arg,"%s %s",type,yushi_s);
	sscanf(yushi_s,"no=%d",yushi);
	if(yushi>0)
	{
		if(me->query_level() <70)
		{
			if(myYushi>=yushi)
			{
				if(type == "xiuchan"){
					time = yushi*3;       //修禅：1碎玉3分钟
					myTime = me->query_auto_learn_xiuchan();
					typeDes = "修禅";
				}
				else if(type == "dazuo"){
					time = yushi*12;     //打坐：1碎玉12分钟;
					myTime = me->query_auto_learn_dazuo();
					typeDes = "打坐";
				}
				if(myTime) //如果玩家有剩余的 挂机 时间，则给出开始 挂机 的链接。
				{
					s += "你当前还剩余"+typeDes+"时间"+myTime+"分钟\n";
				}
				s += "确认要花费"+yushi+"碎玉来增加"+ time +"分钟"+typeDes+"时间吗？\n";
				timeTotal = time + myTime;
				s += "[确认:auto_learn_confirm "+type+" "+timeTotal+" "+yushi+"]\n";
				s += "\n[重新输入:auto_learn_set "+type+"]\n";
			}
			else
			{
				s += "你没有足够的碎玉，我们可不提供赊账服务\n";
				s += "\n[返回:look]\n";
			}
		}
		else
		{
			s += "你已经到达70级了，不能进行该项操作。\n";
			s += "\n[返回:look]\n";
		}
	}
	else
	{
		s += "输入有误，请输入大于0的整数\n";
		s += "\n[重新输入:auto_learn_set "+type+"]\n";
	}
	write(s);
	return 1;
}
