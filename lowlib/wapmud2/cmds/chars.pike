#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	/*
	if(!this_player()->is("npc")){
		object me = this_player();
		int difftime = 900;//测试5分钟间隔
		int entry_flag = 1;
		if(!me["/tmp/random_ctime"]){
			entry_flag = 1;
			me["/tmp/random_ctime"] = (System.Time()->usec_full)/1000000;
		}
		else{
			if( ((System.Time()->usec_full)/1000000 - me["/tmp/random_ctime"]) < difftime )
				entry_flag = 0;
		}
		//会员不触发答题me->all_fee += fee;//记录玩家的捐赠总数
		if(me->all_fee>=1) entry_flag = 0;
		//10级以下不触发答题和迷宫
		if(me->query_level()<=10) entry_flag = 0;
		//触发迷宫/随机奖励，间隔需要大于30分钟
		if(entry_flag==1){
			int ts_num = 0;//!!!!!!!!!!!!!! 调试数据，正式版设置为0即可
			int add = 0;
			if(random(1000)<100+ts_num+add){
				if(me["/plus/random_award"]>0){
					//逃跑触发的leave问题不大，因为会先调用停止战斗，再leave
					if(!me->in_combat){
						if(random(100)<50){ //触发完全随机，
							//1.如果触发，则写入存档，下线再上线，调用leave时，也会触发
							me["/plus/random_rcd"] = 1;//触发就置为1，正确完成了，置为0，否则，下线重登录也会触发验证强制界面
							int t1 = random(10) + 1;
							int t2 = random(10) + 1;
							if(random(100)<30) t1 = random(20)+1;
							if(random(100)<5) t2 = random(20)+1;
							int t3 = t1*t2;
							int c1 = random(10) + 1;
							int c2 = random(10) + 1;
							int d1 = random(10) + 1;
							int d2 = random(10) + 1;
							array tmp1 = ({ 
									"<font style=\"color:red\">"+t1+"</font>"+c1+d1,
									""+c1+"<font style=\"color:red\">"+t1+"</font>"+d1,
									""+c1+""+d1+"<font style=\"color:red\">"+t1+"</font>"
									});
							array tmp2 = ({ 
									"<font style=\"color:red\">"+t2+"</font>"+c2+d2,
									""+c2+"<font style=\"color:red\">"+t2+"</font>"+d2,
									""+c2+""+d2+"<font style=\"color:red\">"+t2+"</font>"
									});
							string s1 = tmp1[random(sizeof(tmp1))]; 
							string s2 = tmp2[random(sizeof(tmp2))];
							me["/tmp/rd_tmp1"] = s1;
							me["/tmp/rd_tmp2"] = s2;
							me["/tmp/rd_tmp3"] = t3;
							tell_object(me,"<font style=\"color:red; font-size:x-large;\">请输入两个颜色相同数字相乘的结果</font>\n");	
							werror("leave call /tmp/rd_tmp1=["+me["/tmp/rd_tmp1"]+"]\n");
							werror("leave call /tmp/rd_tmp2=["+me["/tmp/rd_tmp2"]+"]\n");
							werror("leave call /tmp/rd_tmp3=["+me["/tmp/rd_tmp3"]+"]\n");
							//////////////////////////////////////////////
							string now=ctime(time());
							string record_s = now[0..sizeof(now)-2]+"|"+me->name+"|"+me->name_cn+"|yanzheng award! left count= ["+me["/plus/random_award"]+"]\n";	
							Stdio.append_file(ROOT+"/log/random_award.log",record_s);
							//////////////////////////////////////////////
							me->reset_view(WAP_VIEWD["/modal_award"]);//该视图负责调出随机抽奖界面，并输入参数供random_award验证
							me->write_view();
							return 1;
						}
					}
				}
			}
		}
	}
	*/
	
	if(arg){
		if(arg=="npc"){
			this_player()->write_view(WAP_VIEWD["/chars_npc"]);
		}
		else if(arg=="player"){
			this_player()->write_view(WAP_VIEWD["/chars_player"]);
		}
		else{
			this_player()->write_view(WAP_VIEWD["/chars"]);
		}
	}
	else
		this_player()->write_view(WAP_VIEWD["/chars"]);
	return 1;
}
