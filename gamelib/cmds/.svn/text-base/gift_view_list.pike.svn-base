#include <command.h>
#include <gamelib/include/gamelib.h>  
//此指令查看游戏活动直接赠送物品列表，
int main(string arg)
{
	string s = "";
	object me=this_player();
	s += "可以领取的物品（物品唯一，每天一次）：\n";
	if(!arg){
		object gift;
		string gift_name = "teyao/tenongqiaokeli";
		mixed err = catch{
			gift = (object)(ITEM_PATH+gift_name);
		};
		if(gift && !err){
			s += gift->query_name_cn()+"\n";
			s += gift->query_desc()+"\n";
			s += "----\n";
			if(!me->get_gift){
				s += "[领取:gift_take_confirm "+gift_name+"]\n";
			}
			else{
				s += "今天已领取\n";
			}
		}
		else 
			s += "暂无\n";
	}
	else
		s += "暂无\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "\n[返回游戏:look]\n";
	//write(s);
	return 1;
}
