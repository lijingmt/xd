#include <command.h>
#include <gamelib/include/gamelib.h>

//购买狗调用指令

int main(string arg)
{
	object me = this_player();
	string s = "";
	string name = "";
	int need_money = 0;
	string my_name = me->query_name();
	if(!HOMED->if_have_home(my_name)){
		s += "您还没有家，没必要浪费钱买个看门狗,知道您钱多，但也没必要这么浪费嘛～\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	object room = HOMED->query_room_by_masterId(my_name,"main");
	if(HOMED->is_have_dog(room)==1){
		s += "汪～一家不容二狗，休想把我带走，您请回吧\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(HOMED->is_have_dog(room)==2){
		s += "汪～我们狗狗真可怜，死后就没人理了，您不想使它复活至少也得安葬一下嘛，我不想跟你这样的主人\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	sscanf(arg,"%s %d",name,need_money);
	object dog = (object)(NPC_PATH+name);
	s += dog->query_name_cn()+"\n";
	s += dog->query_picture_url()+"\n";
	s += dog->query_desc()+"\n";
	s += "生命："+dog->query_life_max()+"\n力量："+dog->query_str()+"\n智力："+dog->query_think()+"\n敏捷："+dog->query_dex()+"\n";
	s += "需要"+YUSHID->get_yushi_for_desc(need_money)+"\n";
	s += "\n\n[购买:home_buy_dog_conferm "+name+" "+need_money+"]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
