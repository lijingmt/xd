#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	object me = this_player();
	string name ="";
	int count = 0;//出售数量
	int fg = 0;//价格标志，0为金钱，1为玉石
	int delay = 0;//出售期限
	int ind = 0; //摆摊位置
	int price =0 ;
	string s = "";
	if(!arg || sscanf(arg,"%d %s %d %d %d %d",fg,name,count,delay,price,ind)!=6){
		write("摆摊参数无效。\n[返回游戏:look]\n");
		return 1;
	}
	mapping(string:mixed) result=HOMED->create_shop_listing(me,fg,name,count,
		delay,price,ind);
	if((int)result["ok"]){
		string s_log = me->query_name_cn()+"("+me->query_name()+")在私家小店出售"+name+",数量为"+count+".\n";
		string now = ctime(time());
		Stdio.append_file(ROOT+"/log/home/baitan.log",now[0..sizeof(now)-2]+":"+s_log);
		s += "摆摊成功\n";
	}
	else
		s += (string)result["message"]+"\n";
	s += "[返回:home_myzone]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
