#include <command.h>
#include <gamelib/include/gamelib.h>
#define ITEM_PATH ROOT "/gamelib/clone/item/other/"

//列出千里传音符的具体信息

int main(string arg)
{
	object me = this_player();
	string bc_name = "";
	int rarelevel = 0;
	int amount = 0;
	int money = 0;
	string s = "";
	sscanf(arg,"%s %d %d",bc_name,rarelevel,amount);
	object bc;
	mixed err = catch{
		bc = (object)(ITEM_PATH+bc_name);
	};
	if(!err && bc){
		s += bc->query_name_cn()+"：\n";
		s += bc->query_picture_url()+"\n"+bc->query_desc()+"\n";
		string need_namecn = YUSHID->get_yushi_namecn(rarelevel);
		int have_num = YUSHID->query_yushi_num(me,rarelevel);
		string shf_name =  bc->query_name();
		s += "--------\n";
		s += "需要："+amount+"块"+need_namecn+"("+have_num+")\n";
		s += "\n\n";
		if(bc_name=="qianlichuanyinfu"){
			int num = BROADCASTD->query_num(bc_name);
			//s += "（你目前拥有"+need_namecn+"："+have_num+"块）\n";
			if(num>0){
				s += "购买数量(1-50)：\n[int no:...]\n";
				s += "[submit 确定购买:yushi_buy_bc_confirm "+bc_name+" "+rarelevel+" "+amount+" ...]\n";
			}
			else 
				s += "这玩意儿太受欢迎了，已经卖光了，您下回再来吧\n";
		}
		else if(bc_name=="mianzhanfu"){
			if(me->query_raceId()=="monst"){
				s += "每天最多只能使用3张\n";
				s += "[int no:...]\n";
				s += "[submit 确定购买:yushi_buy_bc_confirm "+bc_name+" "+rarelevel+" "+amount+" ...]\n";
			}
			else {
				s += "只有妖魔才有权利购买\n";
			}
		}
	}
	else
		s += "这东西好像已经卖光了，改天再来吧！\n";
	s += "[返回:yushi_buy_shenfu_list]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
