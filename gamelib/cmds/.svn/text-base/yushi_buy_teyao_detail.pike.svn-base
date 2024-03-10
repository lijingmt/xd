#include <command.h>
#include <gamelib/include/gamelib.h>
#define TEYAO_PATH ROOT "/gamelib/clone/item/teyao/"
//列出玉石购买的某药品的具体信息
//arg =   name       yushi_rareLevel    amount       type
//     药品文件名    所需玉石的稀有度   玉石的个数  药品类型

int main(string arg)
{
	object me = this_player();
	string teyao_name = "";
	int rarelevel = 0;
	int amount = 0;
	string type = "";
	int money = 0;//add by caijie 08/06/10
	int flag = 0;//add by caijie 08/06/10
	string s = "";
	sscanf(arg,"%s %d %d %s %d %d",teyao_name,rarelevel,amount,type,money,flag);//modify
	object teyao;
	mixed err = catch{
		teyao = clone(TEYAO_PATH+teyao_name);
	};
	if(!err && teyao){
		s += teyao->query_name_cn()+"：\n";
		s += teyao->query_picture_url()+"\n"+teyao->query_desc()+"\n";
		string need_namecn = YUSHID->get_yushi_namecn(rarelevel);
		int have_num = YUSHID->query_yushi_num(me,rarelevel);
		s += "--------\n";
		if(flag == 0){
			s += "需要："+amount+"块"+need_namecn+"("+have_num+")\n";
			//s += "（你目前拥有"+need_namecn+"："+have_num+"块）\n";
			s += "购买个数(1-20)：\n[int no:...]\n";
			s += "[submit 确定购买:yushi_buy_teyao_confirm "+teyao_name+" "+rarelevel+" "+amount+" "+money+" 0 ...]\n";
		}
		else if(flag == 1){
			s += "需要："+amount+"块"+need_namecn+","+money+"金("+have_num+")\n";
			s += "每天只能买一次,一次只能购买"+teyao->query_short()+"\n";
			s += "[购买:yushi_buy_teyao_confirm "+teyao_name+" "+rarelevel+" "+amount+" "+money+" 1 1]\n";
		}
	}
	else
		s += "无法查看，请联系版主，我们将尽快为你解决\n";
	s += "[返回:yushi_buy_teyao_list "+type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
