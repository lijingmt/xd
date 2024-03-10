#include <command.h>
#include <gamelib/include/gamelib.h>

#define ITEM_PATH ROOT+"/gamelib/clone/item/"

//此指令用于实现"投放粽子"功能，即玩家放入一个粽子可随机获得《离骚》、《天问》《九歌》或者什么都得不到

int main(string arg){
	object me = this_player();
	object item;
	string s = "";
	string s_log = "";//打log
	int have_zongzi = 0;//记录玩家是否有的粽子
	array(object) all_ob = all_inventory(me);
	mapping(string:int) zz_tmp = ([]);
	string zz_name = "";//粽子名称
	array zz = ({"nuomizongzi","huangshuzongzi","guxiangzongzi","xianrouzongzi","lurouzongzi","helezongzi","xiaozaozongzi","zaonizongzi","xingfuzongzi","lvdouzongzi","doushazongzi","wuweizongzi","danhuangzongzi","huotuizongzi","aixinzongzi","babaozongzi","shanludouzong","pinganzongzi","boluozongzi","jiaoyandouzong","guyunzongzi",});
	int count = 0;//换取或投放的数量
	foreach(all_ob,object ob){
		string name = ob->query_name();
		if(search(zz,name)!=-1){
			if(zz_tmp[name]){
				zz_tmp[name] += ob->amount;
			}
			else {
				zz_tmp[name] = ob->amount;
			}
		}
	}
	if(zz_tmp&&sizeof(zz_tmp)){
		array all_zz = indices(zz_tmp);
		if(!arg){
			//显示连接
			if(me->get_once_day["zongzi"]==1){
				s += "一天只能投放一次，您今天已经投放过了\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			foreach(all_zz,string zz){
				object zz_ob = (object)(ITEM_PATH+"zongzi/"+zz);
				s += "["+zz_ob->query_name_cn()+":tfzz "+zz+"](x"+zz_tmp[zz]+")\n";
			}
		}
		else {
			if(me->get_once_day["zongzi"]==1){
				s += "一天只能投放一次，您今天已经投放过了\n";
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			object zz_ob = (object)(ITEM_PATH+"zongzi/"+arg);
			s += "您投放了1个"+zz_ob->query_name_cn()+"\n";
			s += "\n";
			me->remove_combine_item(arg,1);
			me->get_once_day["zongzi"]=1;
			int ran = random(100);
			if(ran>=0&&ran<40){
				s += "江面随风飘起阵阵涟漪，吹散了粽子激起的波纹，想象着先人的冤屈，带着无限感慨，回到现实……\n";
			}
			else{
				s += "恍惚间您仿佛见到了先人屈原的影像，一如往昔带着忧国忧民的笑容，忽的又消失了...\n";
				s += "\n";
				object item;
				if(ran>=40&&ran<60){
					mixed err=catch{
						item = clone(ITEM_PATH+"zongzi/tianwen");
					};
					if(!err){
						item->move(me);
						s += "你手边多了一本["+item->query_name_cn()+":inv "+item->query_name()+" 0]\n";
						s_log = me->query_name_cn()+"投放一个"+zz_ob->query_name_cn()+"得到"+item->query_name_cn()+"\n";
						string now=ctime(time());
						Stdio.append_file(ROOT+"/log/hyq_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
					}
				}
				else if(ran>=60&&ran<80){
					mixed err=catch{
						item = clone(ITEM_PATH+"zongzi/jiuge");
					};
					if(!err){
						item->move(me);
						me->remove_combine_item(arg,1);
						s += "你手边多了一本["+item->query_name_cn()+":inv "+item->query_name()+" 0]\n";
						s_log = me->query_name_cn()+"投放一个"+zz_ob->query_name_cn()+"得到"+item->query_name_cn()+"\n";
						string now=ctime(time());
						Stdio.append_file(ROOT+"/log/hyq_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
					}
				}
				else if(ran>=80&&ran<100){
					mixed err=catch{
						item = clone(ITEM_PATH+"zongzi/lisao");
					};
					if(!err){
						item->move(me);
						me->remove_combine_item(arg,1);
						s += "你手边多了一本["+item->query_name_cn()+":inv "+item->query_name()+" 0]\n";
						s_log = me->query_name_cn()+"投放一个"+zz_ob->query_name_cn()+"得到"+item->query_name_cn()+"\n";
						string now=ctime(time());
						Stdio.append_file(ROOT+"/log/hyq_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
					}
				}
			}
		}
	}
	else {
		s += "您目前没有粽子- -!\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
