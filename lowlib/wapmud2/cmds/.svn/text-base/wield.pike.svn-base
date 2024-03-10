#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	string s = "";
	int flagstr,flagthink,flagdex = 0;
	int equipflag = 0;
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,this_player(),count);
	//判断该物品是否是可装备的物品类型
	if(ob->query_item_type()!="single_weapon"&&ob->query_item_type()!="double_weapon"){
		s += "只有武器才可以装备\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	//任务物品不可装备
	else if(ob->query_item_task()==1){
		s += "任务物品不能装备\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	//特殊标记的物品不可装备
	else if(ob->query_item_canEquip()==0){
		s += "特殊物品不能装备\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	//判断玩家的等级是否可以装载该等级武器
	else if(this_player()->query_level()<ob->query_item_canLevel()){
		s += "你的级别尚不能装备此物品\n";	
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
	//判断玩家的武器技能(单手剑，双手剑，单手斧．．．)是否学习过该技能
	/*
	else if(this_player()->query_()!=ob->item_skill){
		s += "你还不具备装备此类物品的技能\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	*/
	//判断该武器需要的属性限制，玩家是否具备
	else if(ob->query_item_strLimit()&&ob->query_item_strLimit()>this_player()->query_str()){
		s += "你的力量不够不能装备此种物品\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	else if(ob->query_item_dexLimit()&&ob->query_item_dexLimit()>this_player()->query_dex()){
		s += "你的敏捷不够不能装备此种物品\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	else if(ob->query_item_thinkLimit()&&ob->query_item_thinkLimit()>this_player()->query_think()){
		s += "你的智力不够不能装备此种物品\n";	
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);	
		return 1;
	}
	else if(this_player()->wield(ob)==2){
		//可以装备双手武器
		this_player()->pop_view();
		this_player()->write_view(WAP_VIEWD["/wield_double_main"],ob);
	}
	else if(this_player()->wield(ob)==3){
		//可以装备单手主手武器
		this_player()->pop_view();
		this_player()->write_view(WAP_VIEWD["/wield_single_main"],ob);
	}
	else if(this_player()->wield(ob)==4){
		//可以装备单手副手武器
		this_player()->pop_view();
		this_player()->write_view(WAP_VIEWD["/wield_single_other"],ob);
	}
	else{
		//不可装备同样类型武器，比如双手武器，同样的
		this_player()->pop_view();
		this_player()->write_view(WAP_VIEWD["/wield_same"]);
	}
	return 1;
}
