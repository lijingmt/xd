#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = p_id 
//此指令完成裁缝的最后阶段，即裁缝出成品
int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	int p_id = 0;
	int amount = 1;
	sscanf(arg,"%d %d",p_id,amount);
	string recipe_type = ZHIJIAD->query_recipe_type(p_id);
	if(recipe_type=="")
		recipe_type = "head";
	mapping result = ARTISAND->craft_equipment(me,"zhijia",p_id,amount,0);
	s += (string)result["message"]+"\n";
	if((int)result["ok"] && arrayp(result["items"])){
		array items = result["items"];
		foreach(items,object item){
			if(item)
				s += "[查看"+item->query_name_cn()+":inv_other "+
					file_name(item)+"]\n";
		}
	}
	s += "\n[继续制作:viceskill_zhijia_pf "+recipe_type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
