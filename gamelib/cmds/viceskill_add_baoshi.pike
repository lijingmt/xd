#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = p_id 
//��ָ���г���ҿ��Լ���ı�ʯ
int main(string arg)
{
	string s = "��ѡ����Ҫ����ı�ʯ��ÿ�ֱ�ʯֻ�ܼ���һ�š�\n";
	object me=this_player();
	array(object) all_obj = all_inventory(me);
	int p_id = (int)arg;
	foreach(all_obj,object ob){
		if(ob->is_combine_item() && ob->query_for_material() == "baoshi"){
			if(me->baoshi_add[ob->query_name()] == 0){
				s += "["+ob->query_name_cn()+":viceskill_pf_detail duanzao "+p_id+" 1 "+ob->query_name()+"]";
				s += "("+me->material_m[ob->query_name()]+")\n";
			}
		}
	}
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[����:viceskill_pf_detail duanzao "+p_id+" 1 none]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
