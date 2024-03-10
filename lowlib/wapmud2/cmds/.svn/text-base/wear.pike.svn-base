#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,this_player(),count);
	string s = "";
	int flagstr,flagthink,flagdex = 0;
	int equipflag = 0;
	//判断该物品是否是可穿戴的物品类型
	if(ob->query_item_type()!="armor"&&ob->query_item_type()!="jewelry"&&ob->query_item_type()!="decorate"){
		s += "只有防具，首饰和饰物才可以穿戴\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	//任务物品不可穿戴
	else if(ob->query_item_task()==1){
		s += "该物品为任务物品不能穿戴\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	//特殊标记的物品不可穿戴
	else if(ob->query_item_canEquip()==0){
		s += "该物品为特殊物品不能穿戴\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	//判断玩家的等级是否可以穿戴装载该等级武器
	else if(this_player()->query_level()<ob->query_item_canLevel()){
		s += "你的级别尚不能穿戴此物品\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	//判断玩家的职业限制
	for(int i=0; i<sizeof(ob->query_item_profeLimit()); i++){
		if(ob->query_item_profeLimit()[i]==this_player()->query_profeId())
			equipflag = 1;
		if(equipflag)
			break;
	}
	if(equipflag==0){
		s += "你的职业不能装备此种物品\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	//判断该武器需要的属性限制，玩家是否具备
	else if(ob->query_item_strLimit()&&ob->query_item_strLimit()>this_player()->query_str()){
		s += "你的力量不够不能穿戴此种物品\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	else if(ob->query_item_dexLimit()&&ob->query_item_dexLimit()>this_player()->query_dex()){
		s += "你的敏捷不够不能穿戴此种物品\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	else if(ob->query_item_thinkLimit()&&ob->query_item_thinkLimit()>this_player()->query_think()){
		s += "你的智力不够不能穿戴此种物品\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	else{
		//黄水玉超过四颗不能穿戴
		int have_shuiyu_num = this_player()->query_baoshi_xiangqian_num("pshuangshuiyu",1)+this_player()->query_baoshi_xiangqian_num("slhuangshuiyu",1)+this_player()->query_baoshi_xiangqian_num("jinghuangshuiyu",1);
		int ob_shuiyu_num=0;//该装备上含有的玉石数量
		if(ob->query_if_aocao("yellow")&&ob->query_baoshi("yellow")){
			foreach(ob->query_baoshi("yellow"),object tmp_ob){
				string name = tmp_ob->query_name();
				if(name=="pshuangshuiyu"||name=="slhuangshuiyu"||name=="jinghuangshuiyu"){
					ob_shuiyu_num ++;
				}
			}
		}
		//werror("have_shuiyu_num="+have_shuiyu_num+"--ob_shuiyu_num="+ob_shuiyu_num+"--\n");
		if((have_shuiyu_num+ob_shuiyu_num)>4){
			s += "每个玩家所有穿戴的装备所带有的黄水玉系列宝石不能超过4颗\n";
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
	}
	//穿戴防具
	int rst = this_player()->wear(ob);
	switch(rst){
		case 2 ..7:
			this_player()->pop_view();
			this_player()->write_view(WAP_VIEWD["/wear_armor"],ob);
		break;
		case 8 ..10:
		this_player()->pop_view();
		this_player()->write_view(WAP_VIEWD["/wear_jewelry"],ob);
		break;
		case 11 ..13:
		this_player()->pop_view();
		this_player()->write_view(WAP_VIEWD["/wear_decorate"],ob);
		break;
		default:
		this_player()->pop_view();
		this_player()->write_view(WAP_VIEWD["/wear_same"]);
		break;
	}
	return 1;
}
