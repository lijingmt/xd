#include <globals.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
#define NPC_PATH ROOT+"/gamelib/clone/npc/"
inherit LOW_DAEMON;

/*
//#define FLUSH_TIME 7200
#define FLUSH_TIME 120  //测试两分钟刷新

private protected mapping(int:array) items_current_level = ([]);

void create()
{
	flush_dubo_items();
}
void flush_dubo_items()
{
	for(int i=1;i<=1000;i++){
		items_current_level[i]=({});
		object ob;
		mixed err = catch{
			if(random(1000)<950)
				ob = ITEMSD->get_openbox_aj_worlddrop(i,"chengse");
			else
				ob = ITEMSD->get_openbox_aj_worlddrop(i,"lvse");		
		};
		if(!err && ob){
			int range = (int)i/10+1;
			items_current_level[range]+=({ob});
		}
	}
	call_out(flush_dubo_items,FLUSH_TIME);
	return;
}
//声望装备获得接口-新改接口，实现2小时刷新一次，而不是，点击查看就直接刷新，直接刷到顶级橙色装备和顶级绿色装备
object get_random_npc_item_ob_2_hour(string type,int item_level,void|int loop_count){
	int range = (int)item_level/10+1;
	int num = random(sizeof(items_current_level[range]));
	object ob = items_current_level[range][num];
	if(ob) {
		//werror(" ---- get item=["+ob->name+"] ---- \n");
		return ob;
	}
	return 0;
}
*/

void create()
{

}
/**
刷新房间npc为玩家等级
*/
void refresh_room_npc_to_currentlevel(object me,string path){
	//werror("===refresh_room_npc_to_currentlevel begin\n");
	object env=environment(me);
	if(env->is("peaceful")) return;
	int first_player=1;
	foreach(all_inventory(env),object player){
		if(!player->is("npc")&&!player->is("item")&&player!=me) 
			first_player=0;
	}
	mixed err = catch{
		foreach(all_inventory(env),object npc_player){
			if(npc_player->is("npc")&&!npc_player->in_combat&&npc_player->_tasknpc!=1){
				if(first_player){ //第一个进来房间的，刷新怪为玩家自己等级
					int levelbase = me->level  + random(3);
					if(levelbase<=1) levelbase=1; //得到上下3级的怪物
					npc_player->_npcLevel = levelbase;	
					npc_player->setup_npc();
					//werror("===============refresh_room_npcto_currentlevel monster=["+npc_player->name+"] change level=["+npc_player->level+"]\n");
				}
			}
		}
	};
	if(err) 
		werror("===refresh_room_npc_to_currentlevel error\n");
}
//获得重置属性/等级的npc
object get_npc_level(string orgi_path,int npclevel){
	//werror("===============orgi_path:"+orgi_path+"\n");
	object rtn_ob = 0;
	mixed err = catch{ rtn_ob=clone(ROOT+orgi_path); };
	if(err){
		rtn_ob=0;
		return (rtn_ob);
	}
	///////////////////////////////////////////////////////////
	if(rtn_ob){
		//int levelbase = npclevel - 3 + random(6);
		int levelbase = npclevel + random(3);//怪的等级比自己高6的随机数
		if(levelbase<=1) levelbase=1; //得到上下3级的怪物
		//werror("===============org monster=["+rtn_ob->name+"] org level=["+rtn_ob->level+"]\n");
		rtn_ob->_npcLevel = levelbase;
		//werror("===============change monster=["+rtn_ob->name+"] change level=["+rtn_ob->level+"]\n");
		int rdm = random(1000);
		if(rdm<5){ //0.5%几率出boss
			rtn_ob->_boss = 1;
			//werror("===============at last monster=["+rtn_ob->name+"] type=[boss]\n");
		}
		/*
		else if(rdm<50){ //4%几率出银英
			int rdm2 = random(100);
			if(rdm2<30) rtn_ob->_caoyao = 1;
			else if(rdm2<70) rtn_ob->_caikuang = 1;
			else rtn_ob->_diaoyu = 1;
			werror("===============at last monster=["+rtn_ob->name+"] type=[yinying]\n");
		}
		*/
		else if(rdm<30){ //2.5%几率出精英
			rtn_ob->_meritocrat = 1;
			//werror("===============at last monster=["+rtn_ob->name+"] type=[jingying]\n");
		}
		else{ //普通怪物
			//werror("===============at last monster=["+rtn_ob->name+"] type=[normal]\n");
		}
		//设定boss和精英后，再次进行属性重置和计算
		rtn_ob->setup_npc();
	}
	return rtn_ob;
}
