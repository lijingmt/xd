#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUEBING ROOT "/gamelib/clone/item/zhongqiuyuebing/"
//用于实现购买月饼
//arg = name flag
int main(string arg)
{
	string s = "上好的月饼寄托更多的思恋\n\n";
	object me=this_player();
	string name = "";
	int flag = 0;
	sscanf(arg,"%s %d",name,flag);
	if(flag == 0){
		object ob = (object)(YUEBING+name);
		if(ob){
			s += ob->query_name_cn()+"\n";
			s += ob->query_desc()+"\n";
			//s += ob->query_content()+"\n";
			s += "价格：500金\n";
			s += "[来一个:yuebing_buy "+name+" 1]\n";
			s += "[没兴趣:yuebing_list]\n";
			//s += "[返回游戏:look]\n";
		}
	}
	else{
		if(me->query_account()<50000)
			s += "你身上的钱不够，无法购买\n";
		else{
			object ob = clone(YUEBING+name);
			if(ob){
				me->del_account(50000);
				s += "你购买了一个"+ob->query_name_cn()+"\n";
				string s_log = me->query_name_cn()+"("+me->query_name()+") 购买了一个"+ob->query_name_cn()+"\n";
				s += "中秋节快乐!\n";
				s += "[继续购买:yuebing_list]\n";
				//s += "[返回游戏:look]\n";
				ob->amount = 1;
				ob->move_player(me->query_name());
				string now=ctime(time());
				Stdio.append_file(ROOT+"/log/yuebing.log",now[0..sizeof(now)-2]+":"+s_log);
			}
		}
	}
	s += "\n[返回游戏:look]\n";
	write(s);
	return 1;
}
