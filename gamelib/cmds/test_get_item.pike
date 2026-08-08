#include <command.h>
#include <gamelib/include/gamelib.h>  
//此指令获得配方和材料，用于测试
int main(string|zero arg)
{
	string s = "";
	object me=this_player();
	object ob ;
	if(!me || MANAGERD->checkpower(me->query_name())!="admin"){
		write("该调试命令仅限管理员使用。\n[返回游戏:look]\n");
		return 1;
	}
	if(!arg){
		s += "请输入框中输入你想得到的物品文件名,\n";
		s += "在输入的文件名前面按种类加上相对应的目录,\n";
		s += "路径列表如下：\n";
		s += "材料：material/\n炼丹配方：peifang/liandan/\n锻造配方：peifang/duanzao/\n制甲配方：peifang/zhijia/\n";
		s += "裁缝配方：peifang/caifeng/\n";
		s += "采集家园植物得到的材料：home/mature/plant/\n";
		s += "[string nm:...]\n";
		s += "[submit 提交:test_get_item ...]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else{
		string fileName = "";
		sscanf(arg,"nm=%s",fileName);
		string nameCn = "";
		mixed err = catch{
			ob = clone(ITEM_PATH+fileName);
		};
		if(!err&&ob){
			nameCn = ob->query_name_cn();
			if(ob->is("combine_item")){
				ob->amount = 20;
				nameCn = ob->query_short();
			}
			ob->move(me);
			s += "你获得了"+nameCn+"\n";
		}
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
