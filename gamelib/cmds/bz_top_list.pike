#include <command.h>
#include <gamelib/include/gamelib.h>  
//��ָ����ʾ���ɵ�����
int main(string arg)
{
	string s = "";
	object me=this_player();
	s += "���ɰ�����\n";
	array(int) top_list = BANGZHAND->get_top_list();
	if(top_list && sizeof(top_list)){
		for(int i=0;i<sizeof(top_list);i++){
			string bang_name = BANGD->query_bang_name(top_list[i]);
			if(bang_name && sizeof(bang_name)){
				int baqi = BANGZHAND->query_bang_baqi(top_list[i]);
				s += (i+1)+"��[��"+bang_name+"��:bz_view_banginfo "+top_list[i]+" 1]��������"+baqi+"��\n";
			}
		}
	}
	//s += "[ˢ�����а�:bz_update_toplist]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "\n[������Ϸ:look]\n";
	//write(s);
	return 1;
}
