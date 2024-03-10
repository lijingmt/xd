#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name 即将成为帮主的玩家id
int main(string arg)
{
	object me = this_player();
	string s = "";
	int level = 0;
	if(!me->bangid){
		s = "你未加入任何帮派\n";
	}
	else{
		string bang_name = BANGD->query_bang_name(me->bangid);
		s += "<"+bang_name+">：\n";
		int be = BANGD->set_bang_root(me,arg);
		//set_bang_root()返回 1：转交成功
		//                    2：转交对象没有资格
		//					  3：不能自己转给自己
		//                    0：帮派有问题
		if(be == 1){
			object new_root = find_player(arg);
			if(new_root){
				string content = me->query_name_cn()+"将帮主一职转交给了"+new_root->query_name_cn()+"\n";
				BANGD->bang_notice(me->bangid,content);
			}
			else{
				new_root = me->load_player(arg);
				string content = me->query_name_cn()+"将帮主一职转交给了"+new_root->query_name_cn()+"\n";
				BANGD->bang_notice(me->bangid,content);
				new_root->remove();	
			}
			s += "[返回:my_bang]\n";
			s += "[返回游戏:look]\n";
		}
		else if(be == 2){
			s += "无法将帮主转交给对方，对方可能已不在帮里或者等级不够\n";
			s +="[返回:bang_change_root]\n";
			s +="[返回游戏:look]\n";
		}
		else if(be == 3){
			s += "你已经是帮主了\n";
			s +="[返回:bang_change_root]\n";
			s +="[返回游戏:look]\n";
		}
		else if(be == 0){
			s += "帮派有问题，请联系管理员\n";
			s +="[返回:my_bang]\n";
			s +="[返回游戏:look]\n";
		}
	}
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
