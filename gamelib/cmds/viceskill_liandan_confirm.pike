#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = p_id 和炼丹的数量 
//此指令完成炼丹的最后阶段，即炼制出成品
int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	int p_id = 0;
	int num = 0;
	string s_num = "";
	sscanf(arg,"%d %s",p_id,s_num);
	string recipe_type = LIANDAND->query_recipe_type(p_id);
	if(recipe_type=="")
		recipe_type = "normal";
	if(sscanf(s_num,"no=%d",num)!=1)
		num = (int)s_num;
	if(num <= 0 || num > 100){
		s += "您输入的数量不正确，炼制数量必须为1至100\n";
		s += "\n[继续炼制:viceskill_liandan_pf "+recipe_type+"]\n";
        	s += "[返回游戏:look]\n";
	        write(s);
		 return 1;
	}
	mapping result = ARTISAND->craft_medicine(me,p_id,num);
	s += (string)result["message"]+"\n";
	if((int)result["ok"] && objectp(result["item"])){
		object item = result["item"];
		s += "[查看"+item->query_name_cn()+":inv_other "+
			file_name(item)+"]\n";
	}
	s += "\n[继续炼制:viceskill_liandan_pf "+recipe_type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
