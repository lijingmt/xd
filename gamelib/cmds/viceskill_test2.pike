#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name flag

array(string) caoyao = ({"muhudie","luohanguo","gancao","gouqizi","madouling","maozhuacao","jiulixiang","luxiancao","mingdangsen","juemingzi","huomaren","heshouwu","longdancao","lingzhi","dingxiangcao","liangmianzhen","qiyelian","niuhuang","xieteng","ziyancao","chuanbeimu","tiandongcao","mumianhua","taiyanghua","ganluzi","zitianlian","xuelianhua","yuanyingsen","fenghuangdan"});

int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	if(!me || MANAGERD->checkpower(me->query_name())!="admin"){
		write("该调试命令仅限管理员使用。\n[返回游戏:look]\n");
		return 1;
	}
	object ob;
	foreach(caoyao,string name){
		ob = clone(ITEM_PATH_KUANG+name);
		if(ob){
			ob->amount = 20;
			ob->move_player(me->query_name());
		}
	}
	me->command("look");
	return 1;
}
