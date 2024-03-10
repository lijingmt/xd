#include <command.h>
int main(string arg)
{
	//绑定手机号码：me->mobile,安全码:bandpswd
	string path,user_name,regmobile,bandpswd,game_fg;//add by qianglee 0125
	int bandflag1 = 0;
	int bandflag2 = 0;
	string title = "";
	//send(writer,("login_band "+projname+" "+user+" "+regmobile+" "+bandpswd+" "+game_pre).getBytes());
	if(arg&&(sscanf(arg,"%s %s %s %s %s",path,user_name,regmobile,bandpswd,game_fg)==5)){
		if(!user_name || !regmobile || !bandpswd){
			write("error2");
			return 1;
		}
		else if( sizeof(user_name)<2 || sizeof(regmobile)<2 || sizeof(bandpswd)<2){
			write("error2");
			return 1;
		}
		for(int i=0;i<sizeof(user_name);i++){
			if( user_name[i]>='a'&&user_name[i]<='z'||user_name[i]>='A'&&user_name[i]<='Z'||user_name[i]>='0'&&user_name[i]<='9')
				;
			else{
				write("error2");
				return 1;
			}
		}
		string user_rtn = user_name;
		int clone_flag = 0;
		user_name = game_fg+user_name;
		object user_ob = find_player(user_name);
		if(!user_ob){
			/*program u;
			  u=(program)(ROOT+"/gamelib/clone/user.pike");
			  user_ob = u();
			  user_ob->set_name(user_name);
			  user_ob->set_project("gamelib");*/
			user_ob = load_user(user_name);
		}
		if(user_ob){
			//user_ob->command("save");
			//user_ob->remove();
			if(user_ob->mobile==regmobile){
				if(user_ob->bandpswd==bandpswd){
					string psw = "hYEfdf"+(string)random(100000);
					user_ob->set_password(psw);
					user_ob->command("save");
					user_ob->remove();
					write("bandok");
					return 1;
				}
				else
				{
					write("error5");
					return 1;
				}
			}
			else
			{
				write("error4");
				return 1;

			}
		}
		else
		{
			write("error6");
			return 1;
		}
		/*
		   string user=Stdio.read_file(DATA_ROOT+"u/"+user_name[sizeof(user_name)-2..]+"/"+user_name+".o");
		//有这个用户档案，直接进行对比，不管该用户在不在线，只要和档案一致，直接锁定
		if(user&&sizeof(user)){
		string _regmobile;
		string _bandpswd;
		array(string) usr_content=user/"\n";
		foreach(usr_content,string strCompare){
		if((strCompare/" ")[0]=="bandpswd"){
		if( (strCompare/" ")[1] ){
		string pswdTmp = (strCompare/" ")[1];
		_bandpswd =(pswdTmp/"\"")[1];
		}
		}
		if((strCompare/" ")[0]=="mobile"){
		if( (strCompare/" ")[1] ){
		string pswdTmp = (strCompare/" ")[1];
		_regmobile =(pswdTmp/"\"")[1];
		}
		}
		}
		if(_regmobile&&sizeof(_regmobile)){
		if(_regmobile==regmobile)
		bandflag1 = 1;//绑定手机号跟输入的相同
		}
		if(_bandpswd&&sizeof(_bandpswd)){
		if(_bandpswd==bandpswd)
		bandflag2 = 1;//安全密码跟输入的相同
		}
		if(!bandflag1){
		write("error4");
		return 1;
		}
		if(!bandflag2){
		write("error5");
		return 1;
		}
		if(bandflag1==bandflag2==1){
		write("bandok");
		return 1;
		}
		}
		else{
		write("error6");
		return 1;
		}
		}
		else{
		write("error2");
		return 1;
		}*/
}
return 1;
}
object load_user(string user_name)
{
	program u;
	object m,player;
	u=(program)(ROOT+"/gamelib/clone/user.pike");
	player=u();
	player->set_name(user_name);
	player->set_project("gamelib");
	if(player->restore()){
		return player;
	}
	else
		return 0;
}
