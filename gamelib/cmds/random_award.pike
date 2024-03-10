#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg){
	object me=this_player();
	string s = "";
	int num;
	sscanf(arg,"%d",num);
	if(arg==0){
		me->reset_view(WAP_VIEWD["/modal_award"]);
		me->write_view();
		return 1;
	}
	else{
		//如果是后退过来的操作，返回，不让刷
		if(me["/plus/random_rcd"]==1){
			if((int)me["/tmp/rd_tmp3"]==num){
				//如果这里输入正确了，就消除....貌似业务逻辑不对，取消。。。只要外挂下线10分钟重新上线，就重置错误次数可以重新走掉落了
				me["/tmp/wrong_rd"] = 1; //重置次数 //1.下线10分钟后，再上来 2.回答正确 3.进牢房
				me["/plus/random_rcd"] = 0;//正确完成了，置为0
				me["/plus/random_award"]--;
				me["/tmp/wg_times"]=0;//attack/use_perform连击状态重置
				if(me["/plus/random_award"]<=0) me["/plus/random_award"] = 0;//随机奖励次数--，直到为0不再出现
				s += "您输入的答案 "+ arg +" 完全正确，获得本次的奖励如下：\n";
				s += get_random_award(me);
				me["/tmp/random_ctime"] = (System.Time()->usec_full)/1000000;//迷宫/随机奖励的触发时间间隔控制
				s += "[返回游戏:look]\n";
				write(s);
				return 1;
			}
			else{
				//如果这里连续输入错误超过10次，证明是外挂穷举法破解，可以加入标识，不走怪物掉落
				if(!me["/tmp/wrong_rd"]) me["/tmp/wrong_rd"] = 1;
				else me["/tmp/wrong_rd"]++;
				//增加到一定值时，以一定概率进入天牢。
				if(me["/tmp/wrong_rd"]<=1)
				{
					tell_object(me,"<font style=\"color:red; font-size:x-large;\">天空中出现一个诡异的笑脸。。。</font>\n");
					werror("!! warning 1 !!! random_award --> wrong_rd player=["+me->name+"] wrong times=["+me["/tmp/wrong_rd"]+"]\n");
				}
				else if(me["/tmp/wrong_rd"]<=2){
					tell_object(me,"<font style=\"color:red; font-size:x-large;\">周围逐渐开始变得黑暗。。。一阵阵诡异的低吼从四面八方围了过来。。。</font>\n");
					werror("!! warning 2 !!! random_award --> wrong_rd player=["+me->name+"] wrong times=["+me["/tmp/wrong_rd"]+"]\n");
				}
				else{
					tell_object(me,"<font style=\"color:red; font-size:x-large;\">你两眼一黑，晕了过去。。。</font>\n");
					me["/tmp/wrong_rd"] = 1; //重置次数 //这里除非下线10分钟后，再上来
					me["/plus/random_rcd"] = 0;//完成了，置为0
					me->unconscious();//改为晕倒一段时间
					me["/tmp/wg_times"]=50+random(50);//非正常解除答题流程，连击状态改为60，不久会再次触发
					//me->jailTime=10;//61个房间，1/300机会随机到出口，然后jailTime--，直到<=0才能看到出口                                                                      
					//me->move(ROOT+"gamenv/d/chtianlao/chtianlao1");                                           
					//me->command("look");
					werror("!! done!! random_award --> wrong yanzheng num player=["+me->name+"] wg_times=["+me["/tmp/wg_times"]+"] call unconscious()...\n");
					return 1;
				}
				tell_object(me,"您输入的答案错误，请重新输入正确答案\n\n");
				me->reset_view(WAP_VIEWD["/modal_award"]);
				me->write_view();
				return 1;
			}
		}
		else{
			s += "您刚刚已经领取过奖励了，请返回\n";
			s += "[返回游戏:look]\n";
			write(s);
			return 1;
		}
	}
	return 1;
}
string get_random_award(object me){
	string rtn = "";
	//object item = ITEMD->get_worlddrop_item(dh_year);
	object item = ITEMSD->get_item(me->query_level(), me->query_level(), me->query_lunck());
	if(item){
		string iname = item->name;
		item->move(me);	
		rtn += "你获得了 "+item->name_cn+" !!!\n";
		//log记录
		string record_s = "";
		string now=ctime(time());
		record_s += now[0..sizeof(now)-2]+"|";
		record_s += "uid:"+me->name+"|name:"+me->name_cn+"|type: award|";
		record_s += "get item:"+iname+"|";
		record_s += "\n";
		Stdio.append_file(ROOT+"/log/random_award.log",record_s);
	}
	else{
		int m_low = me->query_level()*10-(int)(me->query_level());
		int m_high = me->query_level()*10+(int)(me->query_level());
		int g_m = m_low + random(m_high-m_low+1);
		g_m = g_m/2;
		if(g_m<=0) g_m = 1;
		me->add_account(g_m);
		rtn += "你获得了 "+MUD_MONEYD->query_other_money_cn(g_m)+" !!!\n";
		//log记录
		string record_s2 = "";
		string now2=ctime(time());
		record_s2 += now2[0..sizeof(now2)-2]+"|";
		record_s2 += "uid:"+me->name+"|name:"+me->name_cn+"|type: award";
		record_s2 += " money:"+g_m+"|";
		record_s2 += "\n";
		Stdio.append_file(ROOT+"/log/random_award.log",record_s2);
	}
	return rtn;
}
