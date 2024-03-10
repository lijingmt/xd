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
		//s += "输入用户ID\n";
		//s += "[string:mgr_usr_data ...]\n";
		s += "参数错误\n";
		s += "[返回管理主界面:game_deal]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	string uid;
	string uname;
	if(arg){
		//s +="[改名字:mgr_set_name_cn "+player->name+" tmp]\n";
		werror("用户改名 arg=【"+arg+"】\n");
		sscanf(arg,"%s %s",uid,uname);
		werror("用户改名 uid=【"+uid+"】\n");
		werror("用户改名 uname=【"+uname+"】\n");
	}
	else{	
		s += "参数错误，用户id和名字不能为空\n";
		s += "[返回管理主界面:game_deal]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	if(uname=="tmp"){
		s = "请输入你的中文姓名，一旦选定无法更改，请仔细选取：[mgr_set_name_cn "+uid+" ...]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);                                                                          
		return 1;                                                                                                       
	}
	else{
		object player = find_player(uid);
		int remove_flag=0;
		if(!player){
			player=me->load_player(uid);
			remove_flag=1;
		}
		if(!player){
			s += "此用户账号不存在，请返回确认.\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s); 
			return 1; 
		}
		else{
			//uname = Locale.Charset.encoder("iso-8859-1")->feed(uname)->drain();
			werror("用户改名=【"+uname+"】\n");

			if(search(uname," ")!=-1) {//这里去重，有起名字老是重复2次，中间有空格
				array(string) t=uname/" ";
				if(sizeof(t)==2&&t[0]==t[1]){
					uname=t[0];
				}
			}
			uname=replace(uname,(["%20":""]));      

			for(int i=0;i<sizeof(uname);i++){
				if(uname[i]>=0&&uname[i]<=127){
					if(uname[i]>='a'&&uname[i]<='z'||uname[i]>='A'&&uname[i]<='Z'||uname[i]>='0'&&uname[i]<='9'){
						;
					}
					else{ 
						s = "---- 请使用中文、英文字母或者数字取名 ----\n";     
						s += "请输入你的中文姓名，一旦选定无法更改，请仔细选取：[mgr_set_name_cn "+uid+" ...]\n";
						me->write_view(WAP_VIEWD["/emote"],0,0,s);
						return 1; 
					}
				}
			}
			///////////////////////////////////////////
			player->name_cn=uname;
			s = "玩家 "+uid+" 名字修改完成\n"; 
			s += "新名字【"+player->name_cn+"】\n";
			if(remove_flag==1){
				if(player)
					player->remove();
			}
		}
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s); 
	return 1; 
}


