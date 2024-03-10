/*wiz_find.pike 
 * 找玩家
 * @author liaocheng
 * @date 7/5/2007
 */
#include <command.h>
#include <wapmud2/include/wapmud2.h>

int main(string file)
{
	object ob,env;
	int flag = 0;
	ob = find_player(file);
	if(ob){
		env = environment(ob);
		if(env){
			write("找到%s在%s(%s).\n",ob->name_cn,env->name_cn,file_name(env));
			flag = 1;
		}
	}
	if(!flag)
		write("没找到名字为%s的物件。\n",file);
	return 1;
}
