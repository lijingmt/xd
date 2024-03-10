#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "";
	string userid="";
	string username="";
	string type="";
	string action1="";
	string action2="";
	string action3="";
	if(!arg || arg==""){
		s += "--游戏内部管理接口平台--\n";
		//s+="管理神秘货币(目前暂停)[进入:mgr_smhb]\n";
		s+="管理神秘货币(目前暂停)\n";
		s+="在线更新脚本[进入:mgr_script]\n";
		s+="用户数据管理[进入:mgr_usr_data]\n";
		//s+="测试购买空间[进入:user_package_buy_list]\n";
		s += "[实时在线总数:game_deal manager_user_online allcount not not]\n";
		s += "[实时在线用户查询管理:game_deal manager_user_online not not not]\n";
		s += "[禁言用户列表:game_deal unchat_user_list not not not]\n";
		s += "[封号用户列表:game_deal unlogin_user_list not not not]\n";
		s += "[历史用户查询管理:game_deal manager_user_history not not not]\n";
		//s += "[关闭游戏:game_deal downgame not not not]\n";
	}
	else{
		if(sscanf(arg,"%s %s %s %s",type,action1,action2,action3)!=4){
			s += "(参数传递错误，请返回重试)\n";
			s += "[实时在线用户查询管理:game_deal manager_user_online not not not]\n";
			s += "[禁言用户列表:game_deal unchat_user_list not not not]\n";
			s += "[封号用户列表:game_deal unlogin_user_list not not not]\n";
			s += "[历史用户查询管理:game_deal manager_user_history not not not]\n";
		}
		else{
			switch(type){
				case "downgame":
				{
					s += "该接口取消\n";
					//me->command("shutdown");
				}
				break;
			
				case "free_chat":
				{
					if(action1&&sizeof(action1)){
						int remove_flag=0;
						object player = find_player(action1);
						if(!player){
							player=this_player()->load_player(action1);
							remove_flag=1;
						}
						if(!player){
							s += "此用户账号不存在，请返回确认.\n";
							remove_flag=0;
						}
						else
						{
							s += MANAGERD->free_user_chat(me->name,player->name);	
						}
						if(remove_flag){
							if(player)
								player->remove();
						}
					}
					else{
						s += "未找到该id对应用户，解除禁言失败，请返回检查\n";
					}
					s += "[查看在线列表:game_deal manager_user_online not not not]\n";
					s += "查看禁言列表\n";
					s += "[查看封号列表:game_deal unlogin_user_list not not not]\n";
					s += "[返回管理主界面:game_deal]\n";
				}
				break;
				case "free_login":
				{
					if(action1&&sizeof(action1)){
						int remove_flag=0;
						object player = find_player(action1);
						if(!player){
							player=this_player()->load_player(action1);
							remove_flag=1;
						}
						if(!player){
							s += "此用户账号不存在，请返回确认.\n";
							remove_flag=0;
						}
						else
						{
							s += MANAGERD->free_user_login(me->name,player->name);	
						}
						if(remove_flag){
							if(player)
								player->remove();
						}
					}
					else{
						s += "未找到该id对应用户，解除封号失败，请返回检查\n";
					}
					s += "[查看在线列表:game_deal manager_user_online not not not]\n";
					s += "[查看禁言列表:game_deal unchat_user_list not not not]\n";
					s += "查看封号列表\n";
					s += "[返回管理主界面:game_deal]\n";
				}
				break;
				case "unchat_user_list":
				{
					s += MANAGERD->list_nochat_user(me->name);	
					s += "[查看在线列表:game_deal manager_user_online not not not]\n";
					s += "查看禁言列表\n";
					s += "[查看封号列表:game_deal unlogin_user_list not not not]\n";
					s += "[返回管理主界面:game_deal]\n";
				}
				break;
				case "unlogin_user_list":
				{
					s += MANAGERD->list_nologin_user(me->name);	
					s += "[查看在线列表:game_deal manager_user_online not not not]\n";
					s += "[查看禁言列表:game_deal unchat_user_list not not not]\n";
					s += "查看封号列表\n";
					s += "[返回管理主界面:game_deal]\n";
				}
				break;
				case "manager_user_online":
				{
					if(action1&&sizeof(action1)){
						if(action1=="char_user"){
							if(action2&&sizeof(action2)){
								int remove_flag=0;
								object player = find_player(action2);
								if(!player){
									player=this_player()->load_player(action2);
									remove_flag=1;
								}
								if(!player){
									s += "此用户账号不存在，请返回确认.\n";
									remove_flag=0;
								}
								else
								{
									//列出用户状态：禁言，封号现在就两种
									if(remove_flag)
										s += "用户状态：离线";
									else{
										if(!living(player))
											s += "用户状态：发呆\n";
										else
											s += "用户状态：在线\n";
									}
									s += MANAGERD->query_user_deal_status(me->name,player->name);	
									//|禁言|禁止指令执行|强制下线|加入禁止登陆名单\n";
									s += "---->禁言\n";
									s += "[1小时:game_deal manager_user_online unchat "+action2+" hour1]|";
									s += "[4小时:game_deal manager_user_online unchat "+action2+" hour4]|";
									s += "[8小时:game_deal manager_user_online unchat "+action2+" hour8]\n";
									s += "[1天:game_deal manager_user_online unchat "+action2+" day1]|";
									s += "[2天:game_deal manager_user_online unchat "+action2+" day2]|";
									s += "[4天:game_deal manager_user_online unchat "+action2+" day4]|";
									s += "[8天:game_deal manager_user_online unchat "+action2+" day8]\n";
									//s += "[永久禁言:game_deal manager_user_online unchat "+action2+" band]\n";
									//s += "----------------\n";
									s += "---->封号\n";
									s += "[1小时:game_deal manager_user_online band_user "+action2+" hour1]|";
									s += "[4小时:game_deal manager_user_online band_user "+action2+" hour4]|";
									s += "[8小时:game_deal manager_user_online band_user "+action2+" hour8]\n";
									s += "[1天:game_deal manager_user_online band_user "+action2+" day1]|";
									s += "[2天:game_deal manager_user_online band_user "+action2+" day2]|";
									s += "[4天:game_deal manager_user_online band_user "+action2+" day4]|";
									s += "[8天:game_deal manager_user_online band_user "+action2+" day8]\n";
									//s += "[永久封号:game_deal manager_user_online band_user "+action2+" band]\n";
									s += "-------------------\n";
									s += "账号："+player->name+"\n";
									s += "密码："+player->password+" 修改\n";
									s += "名字："+player->name_cn+"\n";
									s += "等级："+player->query_level()+"("+player->view_level_status()+") 修改\n";
									s += "性别："+player->query_gender()+"\n";
									s += "年龄："+player->query_age_cn()+"\n";
									s += "生命："+player->get_cur_life()+"/"+player->query_life_max()+"\n";
									s += "法力："+player->get_cur_mofa()+"/"+player->query_mofa_max()+"\n";
									s += "杀人数："+player->killcount+"\n";
									s += "被杀数："+player->bekilledcount+"\n";
									s += "戾气值："+player->query_liqi()+" 修改\n";
									s += "【通宝】："+player->query_tongbao()+" 修改\n";
									s += "【通宝历史数额】："+player->history_tongbao+"\n";
									s += "紫晶石："+player->query_zijingshi()+" 修改\n";
									s += "勇气奖章："+player->query_rongyujiangzhang()+" 修改\n";
									s += "魔精："+player->query_mojing()+" 修改\n";
									//s+="随身物品查看处理\n";
									//s+="仓库物品查看处理\n";
									//s+="挂售物品查看处理\n";
									//s+="师徒关系查看处理\n";
									//s+="夫妻关系查看处理\n";
									//s+="结义关系查看处理\n";
									string menpai = "门派:"+player->query_school_desc();
									s += menpai;
									s += "\n";
									if(player->school=="pingmin")
										;//s += "\n";
									else{
										int sw_value = player->query_user_sw(player->school); 
										int next_value = player->query_next_sw_value(sw_value); 
										string sw_desc = player->query_sw_level_cn(player->school); 
										s += "声望:"+sw_desc+"("+sw_value+"/"+next_value+")\n"; 
									}
									string bangs = player->query_guild();
									if(bangs&&sizeof(bangs))
										s += bangs+"\n";
									string lv = "游戏级别：【"+(player->query_user_gamelevel())+"】\n";
									s += lv;
								}
								if(remove_flag){
									if(player)
										player->remove();
								}
								s += "[查看禁言列表:game_deal unchat_user_list not not not]\n";
								s += "[查看封号列表:game_deal unlogin_user_list not not not]\n";
								s += "[返回管理主界面:game_deal]\n";
							}
						}
						else if(action1=="unchat"){
							//game_deal manager_user_online unchat name time_str]\n";
							int f_hib_times = 0;
							if(action3&&sizeof(action3)){
								int remove_flag=0;
								object player = find_player(action2);
								if(!player){
									player=this_player()->load_player(action2);
									remove_flag=1;
								}
								if(!player){
									s += "此用户账号不存在，请返回确认.\n";
									remove_flag=0;
								}else{
									string id = player->name;
									string namecn = player->query_name_cn();
									f_hib_times = get_hibTime(action3);
									s+=MANAGERD->add_unchat(me->name,id,namecn,f_hib_times);
									if(remove_flag){
										if(player)
											player->remove();
									}
								}
							}
							else{
								s += "禁言时间设定出错，请返回确认或联系管理员。\n";
							}
							s += "[返回在线列表:game_deal manager_user_online not not not]\n";
							s += "[查看禁言列表:game_deal unchat_user_list not not not]\n";
							s += "[查看封号列表:game_deal unlogin_user_list not not not]\n";
							s += "[返回管理主界面:game_deal]\n";
						}
						else if(action1=="band_user"){
							//game_deal manager_user_online unchat name time_str]\n";
							int f_hib_times = 0;
							if(action3&&sizeof(action3)){
								f_hib_times = get_hibTime(action3);
								int remove_flag=0;
								object player = find_player(action2);
								if(!player){
									player=this_player()->load_player(action2);
									remove_flag=1;
								}
								if(!player){
									s += "此用户账号不存在，请返回确认.\n";
									remove_flag=0;
								}else{
									string id = player->name;
									string namecn = player->query_name_cn();
									f_hib_times = get_hibTime(action3);
									s+=MANAGERD->add_unlogin(me->name,id,namecn,f_hib_times);
									if(remove_flag){
										if(player)
											player->remove();
									}
								}
							}
							else{
								s += "封号时间设定出错，请返回确认或联系管理员。\n";
							}
							s += "[返回在线列表:game_deal manager_user_online not not not]\n";
							s += "[查看禁言列表:game_deal unchat_user_list not not not]\n";
							s += "[查看封号列表:game_deal unlogin_user_list not not not]\n";
							s += "[返回管理主界面:game_deal]\n";
						}
						else if(action1=="allcount"){
							int count = sizeof(users());
							s += "在线总用户："+count+"\n";
							s += "[查看禁言列表:game_deal unchat_user_list not not not]\n";
							s += "[查看封号列表:game_deal unlogin_user_list not not not]\n";
							s += "[返回管理主界面:game_deal]\n";
						}
						else if(action1=="not"){
							array list;
							int j;
							int count = sizeof(users());
							s += "在线总用户："+count+"\n";
							//int ct=0;
							for (list = users(1), j = 0; j < sizeof(list); j++) {
								catch{
									string gender=list[j]->query_gender();
									string idle="";
									if(list[j]->query_idle()/60>3)
										idle="<发呆"+list[j]->query_idle()/60+"分钟>";
									string postions="";
									object env = environment(list[j]);
									postions = (string)env->query_name_cn();
									if(postions&&sizeof(postions))
										;
									else
										postions = "未知";
									string tbnow = list[j]->tongbao;
									string tbhis = list[j]->history_tongbao;
									string jinbi = list[j]->query_account()/100;
									if((string)list[j]->name!=me->name){
											s+=""+j+"|"+list[j]->query_level()+"级|"+(string)list[j]->query_name_cn()+"|"+(string)list[j]->name+"|"+postions;
											//s+="|通宝("+tbnow+")|通宝历史("+tbhis+")|金币("+jinbi+")";
											s+="|[密语:tell start "+(string)list[j]->query_name()+" 0]|[管理:game_deal manager_user_online char_user "+(string)list[j]->name+" not]|"+idle+"\n";
										}
									};
							}
							s += "[查看禁言列表:game_deal unchat_user_list not not not]\n";
							s += "[查看封号列表:game_deal unlogin_user_list not not not]\n";
							s += "[返回管理主界面:game_deal]\n";
						}
					}
				}
				break;
				case "manager_user_history":
				{
					s += "(历史用户查询管理，尚未实现，需调用数据库)\n";	
					s += "输入要查找的用户中文名\n";
					s += "输入要查找的用户id\n";
					s += "[查看实时在线列表:game_deal manager_user_online not not not]\n";
					s += "[查看禁言列表:game_deal unchat_user_list not not not]\n";
					s += "[查看封号列表:game_deal unlogin_user_list not not not]\n";
					s += "[返回管理主界面:game_deal]\n";
				}
				break;
			}
		}
	}
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
int get_hibTime(string action3){
	int tmp = 0;
	switch(action3){
		case "hour1":
			tmp = 3600;
		break;
		case "hour4":
			tmp = 3600*4;
		break;
		case "hour8":
			tmp = 3600*8;
		break;
		case "day1":
			tmp = 3600*24;
		break;
		case "day2":
			tmp = 3600*48;
		break;
		case "day4":
			tmp = 3600*96;
		break;
		case "day8":
			tmp = 3600*192;
		break;
		case "band":
			tmp = 3600*24*365;//永久band，有效期一年
		break;
	}
	return tmp;
}
