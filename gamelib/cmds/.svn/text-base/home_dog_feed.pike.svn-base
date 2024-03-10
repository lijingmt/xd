#include <command.h>
#include <gamelib/include/gamelib.h>
#define TIME_DELAY 3*3600
//#define TIME_DELAY 3

//够的喂养调用的指令

int main(string arg)
{
	object me = this_player();
	string s = "";
	object room = environment(me);
	if(!arg){
		if(!HOMED->is_have_dog(room)){
			s += "您家没狗\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		s += "您要用那种饲料喂养您家的狗呢？\n";
		s +=  ITEMSD->daoju_list(me,"home_dog_feed","feed");
		s += "\n\n";
		s += "[放弃:popview]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	else{
		if(!HOMED->is_have_dog(room)){
			s += "您家没狗\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		if(HOMED->is_have_dog(room)==2){
			s += "您家的狗狗已经死了，节哀吧～\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		//werror("=====if_ob====="+arg+"===\n");
		//string feed_name = (arg/"/")[1];
		string feed_name = arg;
		object feed_ob = present(feed_name,me,0);
		//object feed_ob = (object)(ITEM_PATH+arg);
		if(!feed_ob){
		//werror("=====if_ob====="+feed_name+"===\n");
			s += "您并没有这种饲料\n";
		}
		else{
			int life_add = feed_ob->query_life_add();
			int str_add = feed_ob->query_str_add();
			int think_add = feed_ob->query_think_add();
			int dex_add = feed_ob->query_dex_add();
			object dog = present("huoyunquan",environment(me),0);
			//int feed_result = HOMED->change_dog_att(room,life_add,str_add,think_add,dex_add);
			//werror("======"+dog->query_base_life()+"\n");
			int f_time = dog->query_feed_time();
			if(dog->get_cur_life()>0&&(time()-f_time)>=TIME_DELAY){
				dog->set_base_life(dog->query_base_life()+life_add);
				dog->set_str(dog->query_str()+str_add);
				dog->set_think(dog->query_think()+think_add);
				dog->set_dex(dog->query_dex()+dex_add);
				dog->set_feed_time(time());
				//werror("-----cur_life="+dog->query_life_max()+"----\n");
				HOMED->save_dog("1,vice_npc/huoyunquan,"+(string)dog->query_base_life()+","+(string)dog->query_str()+","+(string)dog->query_think()+","+(string)dog->query_dex()+","+(string)time(),me->query_name());
				//object dog = (object)(NPC_PATH+"vice_npc/huoyunquan");
				 s += "喂养成功，火云犬吃了您喂养的饲料后活力四射，\n生命马上增加了"+life_add+"点,\n力量上升了"+str_add+"点，\n智力上升了"+think_add+"点，\n敏捷上升了"+dex_add+"点\n";
				me->remove_combine_item(feed_name,1);
			}
			else {
				//s += "狗已死，您节哀吧\n";
				s += "隔3小时才能喂一次，您过会再来吧～\n";
			}
		}
		s += "\n[继续喂养:home_dog_feed]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
}
