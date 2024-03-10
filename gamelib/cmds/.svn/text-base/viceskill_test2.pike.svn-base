#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name flag

array(string) caoyao = ({"muhudie","luohanguo","gancao","gouqizi","madouling","maozhuacao","jiulixiang","luxiancao","mingdangsen","juemingzi","huomaren","heshouwu","longdancao","lingzhi","dingxiangcao","liangmianzhen","qiyelian","niuhuang","xieteng","ziyancao","chuanbeimu","tiandongcao","mumianhua","taiyanghua","ganluzi","zitianlian","xuelianhua","yuanyingsen","fenghuangdan"});

int main(string arg)
{
	string s = "";
	object me=this_player();
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
