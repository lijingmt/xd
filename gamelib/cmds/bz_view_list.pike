#include <command.h>
#include <gamelib/include/gamelib.h>  
//��ָ��鿴���в����ս�İ�
int main(string arg)
{
	string s = "";
	object me=this_player();
	s += "Ŀǰ�Ѽ�������״�İ���(������)��\n";
	array(int) bang_arr = BANGZHAND->query_bangzhan_list();
	if(bang_arr && sizeof(bang_arr)){
		for(int i=0;i<sizeof(bang_arr);i++){
			if(bang_arr[i]){
				string race_cn = "(��)";
				if(bang_arr[i]%2 == 0)
					race_cn = "(��)";
				string bang_name = BANGD->query_bang_name(bang_arr[i]);
				if(bang_name != ""){
					s += "[��"+bang_name+"��:bz_view_banginfo "+bang_arr[i]+" 0]"+race_cn+" ";
					if(i%2 == 1)
						s += "\n";
				}
			}
		}
	}
	else
		s += "����\n";
	//s += "[��ս����״:bz_get_info]\n\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "\n[������Ϸ:look]\n";
	//write(s);
	return 1;
}
