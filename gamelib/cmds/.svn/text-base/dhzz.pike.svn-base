#include <command.h>
#include <gamelib/include/gamelib.h>

#define ITEM_PATH ROOT+"/gamelib/clone/item/"

int main(string arg){
	object me = this_player();
	object item;
	string s = "";
	string s_log = "";//打log
	int have_zongzi = 0;//记录玩家是否有的粽子
	array(object) all_ob = all_inventory(me);
	mapping(string:int) zz_tmp = ([]);
	mapping can_ex_zz = ([]);
	string zz_name = "";//粽子名称
	int need_count = 0;
	int count = 0;//换取或投放的数量
	int ex_type = 0;//换取标志 1：10个换1个；  2：100换1； 3：1换10； 4：1换100
	int get_count = 0;//玩家所得到的粽子的数量
	array zz = ({"nuomizongzi","huangshuzongzi","guxiangzongzi","xianrouzongzi","lurouzongzi","helezongzi","xiaozaozongzi","zaonizongzi","xingfuzongzi","lvdouzongzi","doushazongzi","wuweizongzi","danhuangzongzi","huotuizongzi","aixinzongzi","babaozongzi","shanludouzong","pinganzongzi","boluozongzi","jiaoyandouzong","guyunzongzi",});
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
		if(!arg){
			s += "选择您所要兑换的粽子:\n";
			array all_zz = indices(zz_tmp);
			foreach(all_zz,string z_name){
				int i = search(zz,z_name);
				//int count_tmp = zz_tmp[zz]/10;
				if(i%3==0){
					can_ex_zz[zz[i+1]]=1;
					can_ex_zz[zz[i+2]]=1;
				}
				else if(i%3==1){
					can_ex_zz[zz[i+1]]=1;
					can_ex_zz[zz[i-1]]=1;
				}
				else if(i%3==2){
					can_ex_zz[zz[i-1]]=1;
					can_ex_zz[zz[i-2]]=1;
				}
			}
			if(can_ex_zz){
				foreach(indices(can_ex_zz),string eachname){
					object each_ob = (object)(ITEM_PATH+"zongzi/"+eachname);
					s += "["+each_ob->query_name_cn()+":dhzz "+eachname+" 0 0 0]\n";
				}
			}
		}
		else {
			sscanf(arg,"%s %d %d %d",zz_name,need_count,get_count,ex_type);
			int i = search(zz,zz_name);
			if(need_count==0){
				object zz_ob = (object)(ITEM_PATH+"zongzi/"+zz_name);
				s += zz_ob->query_name_cn()+"\n";
				s += zz_ob->query_picture_url()+"\n"+zz_ob->query_desc()+"\n";
				if(i%3==0){
					object zz_ob1 = (object)(ITEM_PATH+"zongzi/"+zz[i+1]);
					object zz_ob2 = (object)(ITEM_PATH+"zongzi/"+zz[i+2]);
					s += "[用1个"+zz_ob1->query_name_cn()+"兑换10个:dhzz "+zz[i+1]+" 1 10 3]\n";
					s += "[用1个"+zz_ob2->query_name_cn()+"兑换100个:dhzz "+zz[i+2]+" 1 100 4]\n";
				}
				else if(i%3==1){
					object zz_ob1 = (object)(ITEM_PATH+"zongzi/"+zz[i+1]);
					object zz_ob2 = (object)(ITEM_PATH+"zongzi/"+zz[i-1]);
					s += "[用1个"+zz_ob1->query_name_cn()+"兑换10个:dhzz "+zz[i+1]+" 1 10 3]\n";
					s += "[用10个"+zz_ob2->query_name_cn()+"兑换1个:dhzz "+zz[i-1]+" 10 1 1]\n";
				}
				else if(i%3==2){
					object zz_ob1 = (object)(ITEM_PATH+"zongzi/"+zz[i-1]);
					object zz_ob2 = (object)(ITEM_PATH+"zongzi/"+zz[i-2]);
					s += "[用10个"+zz_ob1->query_name_cn()+"兑换1个:dhzz "+zz[i-1]+" 10 1 1]\n";
					s += "[用100个"+zz_ob2->query_name_cn()+"兑换1个:dhzz "+zz[i-2]+" 100 1 2]\n";
				}
			}
			else {
				if(zz_tmp[zz_name]&&zz_tmp[zz_name]>=need_count){
					string get_zz_name = "";
					if(ex_type==1){
						get_zz_name = zz[i+1];
					}
					else if(ex_type==2){
						get_zz_name = zz[i+2];
					}
					else if(ex_type==3){
						get_zz_name = zz[i-1];
					}
					else if(ex_type==4){
						get_zz_name = zz[i-2];
					}
					if(get_count==100){
						for(int j=0;j<5;j++){
							mixed err=catch{
								item = clone(ITEM_PATH+"zongzi/"+get_zz_name);
							};
							if(!err){
								item->amount = 20;
								item->move(me);
							}
						}
						s += "兑换成功，祝你端午节玩得愉快^_^\n";
					}
					else {
						mixed err=catch{
							item = clone(ITEM_PATH+"zongzi/"+get_zz_name);
						};
						if(!err){
							item->amount = get_count;
							item->move(me);
						}
						s += "兑换成功，祝你端午节玩得愉快^_^\n";
					}
					me->remove_combine_item(zz_name,need_count);
					s_log += me->query_name_cn()+"("+me->query_name()+") 花费"+need_count+"个"+zz[i-1]+"换取"+get_count+"个"+zz_name+"\n";
					string now=ctime(time());
					Stdio.append_file(ROOT+"/log/hyq_exchange.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
				}
				else {
					s += "您没有足够的粽子\n";
				}
			}
		}
		s += "\n";
		s += "[返回:dhzz]\n";
	}
	else {
		s += "您身上没有粽子可兑换\n";
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
