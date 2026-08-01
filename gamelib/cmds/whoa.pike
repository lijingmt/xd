#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string|zero arg)
{
	array(object) list;
	int j;
	object me = this_player();
	array(object) all_users = users(1);
	list = ({});
	for(j=0;j<sizeof(all_users);j++)
		if(LOGICALZONED->can_interact(me,all_users[j]))
			list += ({all_users[j]});
	write("在线用户数："+sizeof(list)+"\n");
	if(arg=="-a"){
		printf("用户                      空闲 在线 命令     地点 钱   道行  技能等级\n");
		printf("------------------------- ---- ---- ---- -------- ---- ----- --------\n");
		for (j = 0; j < sizeof(list); j++) {
			object env=environment(list[j]);
			catch{
			printf("%-25s %4d %4d %4d %8s %4d %4d %s", (string)list[j]->query_name_cn() +"("+ (string)list[j]->query_name() +")"
				,list[j]->query_idle()/60,list[j]->query_online()/60
				,list[j]->query_reconnect_count()
				,(env&&env->query_name_cn&&env->query_name_cn()!=0)?env->query_name_cn():""
				,list[j]->query_money()+list[j]->savings
				,list[j]->daoheng
				,replace(list[j]->view_enable(),(["\n":" ","有效等级：":":"]))
			);
/*			foreach(ob=first_inventory(list[j]);ob;ob=next_inventory(ob)){
				write(" "+ob->query_nick());
			}*/
			};
			write("\n");
		}
	}
	return 1;
}
