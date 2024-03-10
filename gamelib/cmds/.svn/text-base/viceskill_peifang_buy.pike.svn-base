#include <command.h>
#include <gamelib/include/gamelib.h>
#define DUANZAO ROOT "/gamelib/clone/item/peifang/duanzao/"
#define LIANDAN ROOT "/gamelib/clone/item/peifang/liandan/"
#define CAIFENG ROOT "/gamelib/clone/item/peifang/caifeng/"
#define ZHIJIA ROOT "/gamelib/clone/item/peifang/zhijia/"
//arg = type name flag
// type为"duanzao" or "liandan" ;name为配方文件; flag为0表示察看，为1表示购买
int main(string arg)
{
	string s = "你只有学会了相关的技能，才能读懂这些卷轴上的东西\n";
	object me=this_player();
	string type = "";
	string filename = "";
	int p_id = 0;
	int flag = 0;
	int need_level = 100000;
	string producer_info = "";
	object peifang;
	sscanf(arg,"%s %s %d",type,filename,flag);
	if(type == "duanzao"){
		peifang = clone(DUANZAO+filename);
	}
	else if(type == "liandan"){
		peifang = clone(LIANDAN+filename);
	}
	else if(type == "caifeng"){
		peifang = clone(CAIFENG+filename);
	}
	else if(type == "zhijia"){
		peifang = clone(ZHIJIA+filename);
	}
	if(peifang){
		if(flag == 0){
			p_id = (int)peifang->peifang_id;
			s += peifang->query_name_cn()+"\n";
			s += peifang->query_picture_url()+"\n"+peifang->query_desc()+"\n";
			if(type == "duanzao"){
				need_level = (int)DUANZAOD->query_need_level(p_id);
				producer_info = (string)DUANZAOD->query_produce_info(p_id);
				s += "需要锻造熟练度:"+need_level+"\n";
			}
			else if(type == "liandan"){
				need_level = LIANDAND->query_need_level(p_id);
				producer_info = LIANDAND->query_produce_info(p_id);
				s += "需要炼丹熟练度:"+need_level+"\n";
			}
			else if(type == "caifeng"){
				need_level = CAIFENGD->query_need_level(p_id);
				producer_info = CAIFENGD->query_produce_info(p_id);
				s += "需要裁缝熟练度:"+need_level+"\n";
			}
			else if(type == "zhijia"){
				need_level = ZHIJIAD->query_need_level(p_id);
				producer_info = ZHIJIAD->query_produce_info(p_id);
				s += "需要制甲熟练度:"+need_level+"\n";
			}
			int value = (int)peifang->level_limit*50;
			s += "价格："+MUD_MONEYD->query_other_money_cn(value)+"\n";
			s +="--------\n";
			s += producer_info;
			s += "[购买:viceskill_peifang_buy "+type+" "+filename+" 1]\n";
		}
		else if(flag == 1){
			int value = peifang->level_limit*50;
			if(me->query_account()<value)
				s += "你身上没有足够的钱\n";
			else{
				me->del_account(value);
				s += "你购买了一个"+peifang->query_name_cn()+"\n";
				peifang->move(me);
			}
		}
	}
	else 
		s += "没有这样的卷轴配方\n";
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[返回:viceskill_peifang_view "+type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
