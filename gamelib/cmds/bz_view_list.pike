#include <command.h>
#include <gamelib/include/gamelib.h>  
//此指令查看所有参与帮战的帮
int main(string arg)
{
	string s = "";
	object me=this_player();
	s += "目前已加入生死状的帮派(非排名)：\n";
	array(int) bang_arr = BANGZHAND->query_bangzhan_list();
	if(bang_arr && sizeof(bang_arr)){
		for(int i=0;i<sizeof(bang_arr);i++){
			if(bang_arr[i]){
				string race_cn = "(妖)";
				if(bang_arr[i]%2 == 0)
					race_cn = "(人)";
				string bang_name = BANGD->query_bang_name(bang_arr[i]);
				if(bang_name != ""){
					s += "[＜"+bang_name+"＞:bz_view_banginfo "+bang_arr[i]+" 0]"+race_cn+" ";
					if(i%2 == 1)
						s += "\n";
				}
			}
		}
	}
	else
		s += "暂无\n";
	//s += "[帮战生死状:bz_get_info]\n\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "\n[返回游戏:look]\n";
	//write(s);
	return 1;
}
