#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	if(!this_player()->is("npc")){
		object me = this_player();
		int entry_flag = 0;
		//attack/use_perform记录超过300次连击，判定进入调用
		if(me["/tmp/wg_times"]>=100) entry_flag = 1;
		else entry_flag = 0;
		//会员不触发答题me->all_fee += fee;//记录玩家的捐赠总数
		if(me->all_fee>=1) entry_flag = 0;
		//10级以下不触发答题和迷宫
		if(me->query_level()<=10) entry_flag = 0;
	
		werror("---player["+me->name+"]------ kill call tmp-wg_times=["+me["/tmp/wg_times"]+"]\n");
		
		if(entry_flag==1){
			int ts_num = 0;//!!!!!!!!!!!!!! 调试数据，正式版设置为0即可
			int add = 0;
			if(random(1000)<1000+ts_num+add){
				if(me["/plus/random_award"]>0){
					//逃跑触发的leave问题不大，因为会先调用停止战斗，再leave
					if(!me->in_combat){
						if(random(100)<100){
							//1.如果触发，则写入存档，下线再上线，调用leave时，也会触发
							me["/plus/random_rcd"] = 1;//触发就置为1，正确完成了，置为0，否则，下线重登录也会触发验证强制界面
							int t1 = random(10) + 1;
							int t2 = random(10) + 1;
							if(random(100)<30) t1 = random(100)+1;
							if(random(100)<5) t2 = random(100)+1;
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
							werror("kill call /tmp/rd_tmp1=["+me["/tmp/rd_tmp1"]+"]\n");
							werror("kill call /tmp/rd_tmp2=["+me["/tmp/rd_tmp2"]+"]\n");
							werror("kill call /tmp/rd_tmp3=["+me["/tmp/rd_tmp3"]+"]\n");
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
	
	string name=arg;
	int count;
	int flag = 0;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(this_player()),count,this_player());
	if(!ob){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"你攻击的目标不存在！\n");
		return 1;
	}
	if(environment(this_player())->is("peaceful")){
		this_player()->write_view(WAP_VIEWD["/fight_peaceful"]);
		return 1;
	}
	//新年年兽不接受高级玩家的杀戮，由liaocheng于08/01/26添加
	if(ob->query_picture()=="nianshou"){
		if(this_player()->query_level() > ob->query_level()+20){
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,"年兽可不想打没胜算的架~\n");
			return 1;                                                                                 
		}
	}
	else if(ob&&ob->query_raceId()==this_player()->query_raceId()){
		//帮战杀戮，由liaocheng于08/08/30添加
		if(ob->bangid && this_player()->bangid && BANGZHAND->is_in_bangzhan(ob->bangid,this_player()->bangid)) 
			flag = 1;
		else{
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,"你不能攻击那个目标！\n");
			return 1;
		}
	}
	////////////////////////////////////////////	
	//阵营控制，不能攻击敌对地图中的玩家
	object env = environment(ob);
	string map_race = env->room_race;
	//攻击者阵营
	string a_raceid = this_player()->query_raceId();
	//被攻击者阵营
	string e_raceid = ob->query_raceId();
	if(a_raceid !=e_raceid &&!ob->is("npc")){
		//判断是否敌对阵营地图
		if(map_race!="third" && a_raceid!=map_race){
			if(env->query_room_type() == "city" && ob->red_flag)
				flag = 1;
			else{
				//人类不能在敌对阵营主动攻击敌人
				this_player()->write_view(WAP_VIEWD["/emote"],0,0,"你不能在敌对阵营攻击那个目标！\n");
				return 1;
			}
		}
		else{
			if(env->query_room_type() == "city")
				this_player()->red_flag = 1;
			flag = 1;
		}
	}
	if(ob->query_buff("mianzhan",0) != "none"&&env->query_room_type() != "city"){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"免战神符在此，别打扰我修行\n");
		return 1;
	}
	if(ob->is("npc"))
		flag = 1;
	///////////////////////////////////////////////////
	if(flag){
		this_player()->kill(name,count);
		this_player()->reset_view(WAP_VIEWD["/fight"]);
		this_player()->write_view();
		return 1;
	}
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,"你要攻击哪个目标？\n");
	return 1;
}
