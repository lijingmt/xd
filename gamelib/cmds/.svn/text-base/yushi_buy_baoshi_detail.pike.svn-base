#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//列出玉石购买的宝石的具体信息
//arg =   name       yushi_rareLevel    amount       type       money      flag
//     宝石文件名    所需玉石的稀有度   玉石的个数  药品类型   所需金钱 

int main(string arg)
{
	object me = this_player();
	string yushi_name = "";
	int rarelevel = 0;
	int amount = 0;
	string type = "";
	int money = 0;
	int flag = 0;
	string s = "";
	sscanf(arg,"%s %d %d %s %d %d",yushi_name,rarelevel,amount,type,money,flag);//modify
	object yushi;
	mixed err = catch{
		yushi = clone(YUSHI_PATH+yushi_name);
	};
	if(!err && yushi){
		s += yushi->query_name_cn()+"：\n";
		s += yushi->query_picture_url()+"\n"+yushi->query_desc()+"\n";
		string need_namecn = YUSHID->get_yushi_namecn(rarelevel);
		int have_num = YUSHID->query_yushi_num(me,rarelevel);
		s += "--------\n";
		if(flag == 0){
			s += "需要："+amount+"块"+need_namecn+"("+have_num+")\n";
			//s += "（你目前拥有"+need_namecn+"："+have_num+"块）\n";
			s += "购买个数(1-20)：\n[int no:...]\n";
			s += "[submit 确定购买:yushi_buy_baoshi_confirm "+yushi_name+" "+rarelevel+" "+amount+" "+money+" 0 ...]\n";
		}
		else if(flag == 1){
			s += "需要："+amount+"块"+need_namecn+","+money+"金("+have_num+")\n";
			s += "每天只能买一次,一次只能购买"+yushi->query_short()+"\n";
			s += "[购买:yushi_buy_baoshi_confirm "+yushi_name+" "+rarelevel+" "+amount+" "+money+" 1 1]\n";
		}
	}
	else
		s += "这东西好像已经卖光了，改天再来吧！\n";
	s += "[返回:yushi_buy_baoshi_list "+type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
