#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg){
	object me = this_player();
	string s = "";
	string powers = MANAGERD->checkpower(me->name);
	if(powers=="admin")
		;
	else
	{
		string stmp = "需要管理员权限才可以进入管理房间\n";
		stmp += "[返回游戏:look]\n";
		write(stmp);
		return 1;
	}
	s += "====在线管理用户数据====\n";
	if(!arg || arg==""){
		s += "输入用户ID\n";
		s += "[string:mgr_usr_data ...]\n";
		s += "[返回管理主界面:game_deal]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	else{
		string uid = (arg/" ")[0];
		int remove_flag=0;
		object player = find_player(uid);
		if(!player){
			player=this_player()->load_player(uid);
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
				s += "用户状态：离线\n";
			else{
				if(!living(player))
					s += "用户状态：发呆\n";
				else
					s += "用户状态：在线\n";
			}
			s += "-------------------\n";
			s += "账号："+player->name+"\n";
			s += "密码："+player->password+"\n";//" [string:change password "+player->name+" ...]\n";
			s += "名字："+player->name_cn+"\n";//" [string:change namecn "+player->name+" ...]\n";
			s +="[改名字:mgr_set_name_cn "+player->name+" tmp]\n";
			//s += "名字："+player->name_cn+" [string:change namecn "+player->name+" ...]\n";
			//s += "头像开关："+player->name_cn+"(1为开启头像，2关闭) [string:change photo "+player->name+" ...]\n";
			s += "等级："+player->query_level()+"\n";//+"(输入大于0整数) [string:change level "+player->name+" ...]\n";
			//s += "性别："+player->query_gender()+"\n";
			//s += "年龄："+player->query_age_cn()+"\n";
			//s += "生命："+player->get_cur_life()+"/"+player->query_life_max()+"\n";
			//s += "法力："+player->get_cur_mofa()+"/"+player->query_mofa_max()+"\n";
			//s += "杀人数："+player->killcount+"\n";
			//s += "被杀数："+player->bekilledcount+"\n";
			//s += "戾气值："+player->query_liqi()+" 修改[string:change liqi "+player->name+" ...]\n";
			//s += "金币："+player->query_gold();//+" (正数加钱，负数减钱)[string:change jb "+player->name+" ...]\n";
			//s += "【仙玉】："+player->query_tongbao()+" (正数加通宝，负数减通宝)[string:change tb "+player->name+" ...]\n";
			s += "-------------------\n";
			//con->write("yushi_add_fee "+fee+" "+yushi_level+" "+spec_fg+"\n");
			//50 2 szx = 充值50元，获得类型为2的仙缘玉50个（1元=1仙缘玉）
			s += "[给此用户在线直接充值:txadd "+uid+"]\n";
			s += "-------------------\n";
			//s += "【通宝历史数额】："+player->history_tongbao+" (输入大于等于0的整数)[string:change history_tb "+player->name+" ...]\n";
			//int qhs_count = check_need_item(player,"qhs");
			//int xybs_count = check_need_item(player,"xybs");
			//s += "强化石："+qhs_count+" 输入正数加，负数减 [string:change qhs "+player->name+" ...]\n";
			//s += "幸运宝石："+xybs_count+" 输入正数加，负数减 [string:change xybs "+player->name+" ...]\n";
			//s += "紫晶石："+player->query_zijingshi()+" 修改[string:change zjs "+player->name+" ...]\n";
			//s += "勇气奖章："+player->query_rongyujiangzhang()+" --修改[string:change ryjz "+player->name+" ...]\n";
			//s += "魔精："+player->query_mojing()+" --修改[string:change mj "+player->name+" ...]\n";
			//s+="随身物品查看处理\n";
			//s+="仓库物品查看处理\n";
			//s+="挂售物品查看处理\n";
			//s+="师徒关系查看处理\n";
			//s+="夫妻关系查看处理\n";
			//s+="结义关系查看处理\n";
			//string menpai = "门派:"+player->query_school_desc();
			/*
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
			*/
		}
		if(remove_flag){
			if(player)
				player->remove();
		}
	}

	s += "[返回:mgr_usr_data]\n";
	s += "[返回管理主界面:game_deal]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
//检查玩家身上物品的个数
int check_need_item(object me, string need_org){
	array(object) all_obj = all_inventory(me);
	int tmp = 0;
	foreach(all_obj,object ob1)
	{
		if(ob1)
		{
			//如果是复数物品
			if(ob1->is_combine_item()&&ob1->query_name()==need_org)
				tmp+=ob1->amount;
			//如果是单数物品
			if(!ob1->is_combine_item()&&ob1->query_name()==need_org)
				tmp++;
		}
	}
	return tmp;
}
//减除强化石、幸运宝石
int del_need_item(object player,string item_name,int num){
	array all_obj = all_inventory(player);
	int i = 0;
	int temp_num = num;
	foreach(all_obj,object ob1){
		if(!ob1->is_combine_item()&&ob1->query_name() == item_name){
			i++;
			ob1->remove();
			if(i >= num)
				break;
		}
		if(ob1->is_combine_item()&&ob1->query_name() == item_name){
			if(ob1->amount<=temp_num){
				i+=ob1->amount;
				temp_num -= ob1->amount;
				ob1->remove();
			}
			else{
				i+=temp_num;
				ob1->amount -= temp_num;
			}
			if(i >= num)
				break;
		}
	}
	return i;
}
int set_name_cn(string arg)                                                                                       
{
	string s;                                                                                                        
	object me = this_player();                                                                                       
	if(me->sid == "5dwap"){
		tell_object(me,"欢迎尝试仙道，您现在是游客身份，你的档案将不会被保存，欢迎点击注册一个正式帐号来体验仙道的乐趣。\n[注册帐号:reg_account]\n[返回游戏:look]\n");
		return 1; 
	}
	/*
	if(me->have_name_cn()){
		s = "你已经有名字了，每个人只能取一次名字。\n";                                                                 
		me->write_view(WAP_VIEWD["/emote"],0,0,s);                                                                          
		return 1;                                                                                                      
	}                                                                                                                
	*/
	if(arg){
		//werror("===== 69 arg "+arg+"\n"); 
		if(search(arg," ")!=-1) {//这里去重，有起名字老是重复2次，中间有空格
			array(string) t=arg/" ";
			if(sizeof(t)==2&&t[0]==t[1]){
				arg=t[0];
			}
		}
		arg=replace(arg,(["%20":""]));                                                                                  
	}
	else{                                                                                                            
		s = "请输入你的中文姓名，一旦选定无法更改，请仔细选取：[set_name_cn ...]\n";                                    
		me->write_view(WAP_VIEWD["/emote"],0,0,s);                                                                          
		return 1;                                                                                                       
	}
	if(arg&&arg!=""){
		//////////////////////////////////////////////////////////////////////////////////
		//arg = Locale.Charset.encoder("GB18030")->feed(arg)->drain();
		arg = Locale.Charset.encoder("iso-8859-1")->feed(arg)->drain();
		//////////////////////////////////////////////////////////////////////////////////
		/*
		if(NAMESD->is_name_reserved(arg)){                                                                         
			s = "你不能取那种奇怪的名字。\n";                                                                              
			me->write_view(WAP_VIEWD["/emote"],0,0,s);    
			return 1;                                                                                                      
		}
		else if(NAMESD->is_name_regged(arg)){
			s = "你取得名字有人取过了,请另外取一个名字。\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;   
		}
		else if(sizeof(arg)>8){ 
			werror("=====90arg "+arg+"\n");                                                                                        
			s = "名字长度不能超过四个中文汉字。\n";                                                                        
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;                                                                                                      
		}                                                                                                               
		else
		*/
		{
			for(int i=0;i<sizeof(arg);i++){                                                                                
				if(arg[i]>=0&&arg[i]<=127){
					if(arg[i]>='a'&&arg[i]<='z'||arg[i]>='A'&&arg[i]<='Z'||arg[i]>='0'&&arg[i]<='9'){     
					}
					else{ 
						arg=0;  
						s = "请使用中文、英文字母或者数字取名。\n";     
						me->write_view(WAP_VIEWD["/emote"],0,0,s);
						return 1; 
					}
				}
			}
			//me["/tmp/tmp"]=arg; 
			me->name_cn=arg;//me["/tmp/tmp"]; 
		}
	}
	s = "名字修改完成\n"; 
	me->write_view(WAP_VIEWD["/emote"],0,0,s); 
	return 1; 
}


