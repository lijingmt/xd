#include <globals.h>

int main(string arg)
{
	string path,user_name,lgpswd,userip;
	string title = "";
	title += "=玩家登录=\n";
	if(arg&&(sscanf(arg,"%s %s %s %s",path,user_name,lgpswd,userip)==4)){
		if(!path || !user_name || !lgpswd || !userip){
			title += "登录错误！\n";
			title += "您输入的用户名和密码不符合规范，请返回重试。\n";
			title += "[url 返回:http://"+INDEX_URL+"]\n";
			write(title);
			return 1;
		}
		else if( sizeof(user_name)<2 || sizeof(lgpswd)<2 ){
			title += "登录错误！\n";
			title += "您输入的用户名和密码不符合规范，请返回重试。\n";
			title += "[url 返回:http://"+INDEX_URL+"]\n";
			write(title);
			return 1;
		}
		object me = find_player(user_name);
		if(!me){
			//如果这个用户不再线状态,第一步还是要去档案里面检查物理档案中的密码
			string user=Stdio.read_file(DATA_ROOT+"u/"+user_name[sizeof(user_name)-2..]+"/"+user_name+".o");
			if(user&&sizeof(user))
				;
			else{
				werror("----"+user_name+"----\n");
				title += "登录错误！\n";
				title += "您输入的用户名不存在，请返回重试。\n";
				title += "[url 返回:http://"+INDEX_URL+"]\n";
				write(title);
				return 1;
			}
			//这里需要找到该用户档案中的密码字段并对比lgpswd
			string pswd;
			string userSid;	
			array(string) usr_content=user/"\n";
			foreach(usr_content,string strCompare){
				if( (strCompare/" ")[0]=="password" ){
					if( (strCompare/" ")[1] ){
						string pswdTmp = (strCompare/" ")[1];
						pswd =(pswdTmp/"\"")[1];
					}
				}
				//jsessionid 不是原来的那个账号，让其重新登陆
				if( (strCompare/" ")[0]=="userip" ){
					if( (strCompare/" ")[1] ){
						string Tmp = (strCompare/" ")[1];
						userSid =(Tmp/"\"")[1];
					}
				}
			}
			if(!pswd||!userSid){
				title += "登录错误！\n";
				title += "安全认证失败，请返回重试。\n";
				title += "[url 返回:http://"+INDEX_URL+"]\n";
				write(title);
				return 1;
			}
			else if( (pswd && lgpswd==pswd) && (userSid && userip==userSid) ){
				program u;
				object m;
				catch{
					m=(object)(ROOT+"/"+path+"/master.pike");
				};
				if(m){
					u=m->connect();
				}
				if(!u)
					u=(program)(ROOT+"/"+path+"/clone/user.pike");
				me=u();

				me->set_name(user_name);
				me->set_project(path);
				if(me->setup(pswd)){
					
					//写d/init里面没用，因为已经缓存到viewd视图中，rd_tmp值都是0
					if(me["/plus/random_rcd"]==1){ //抽奖强制问答未完成下线，上线后，重置tmp1，tmp2，tmp3 
						int t1 = random(100) + 1;
						int t2 = random(100) + 1;
						int t3 = t1*t2;
						me["/tmp/rd_tmp1"] = t1;
						me["/tmp/rd_tmp2"] = t2;
						me["/tmp/rd_tmp3"] = t3;
						//werror("login.pike call rd_tmp1=["+me["/tmp/rd_tmp1"]+"]\n");
						//werror("login.pike call rd_tmp2=["+me["/tmp/rd_tmp2"]+"]\n");
						//werror("login.pike call rd_tmp3=["+me["/tmp/rd_tmp3"]+"]\n");
					}

					exec(me,previous_object());
					if(environment(me)==0)
						me->move(LOW_VOID_OB);
					destruct(previous_object());
				}
			}
			else{
				title += "登录错误！\n";
				title += "安全认证失败，请返回重试。\n";
				title += "[url 返回:http://"+INDEX_URL+"]\n";
				write(title);
				return 1;
			}
		}
		else{//如果这个用户刚才再线并且project路径正确,就调用reconnect
			string pswd = me->password;
			string userSID = me->query_userip();
			//如果不是同一个手机登陆，jsessionid不同，就踢出去
			if( (pswd && lgpswd==pswd) && (userSID && userip==userSID) ){
				if(me->project==path&&me["reconnect"]&&me->reconnect(lgpswd)){
					exec(me,previous_object());
					destruct(previous_object());
				}
			}
			else{
				title += "登录错误！\n";
				title += "安全认证失败，请返回重试。\n";
				title += "[url 返回:http://"+INDEX_URL+"]\n";
				write(title);
				return 1;
			}
		}
	}
	else{
		title += "登录错误！\n";
		title += "您的登陆已经过期，请返回重新登陆！\n";
		title += "[url 返回:http://"+INDEX_URL+"]\n";
		write(title);
		return 1;
	}
	return 1;
}
