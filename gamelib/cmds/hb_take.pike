#include <command.h>
#include <gamelib/include/gamelib.h>
//��������ȡ�����ָ�
int main(string arg)
{
    object me = this_player();
    string s="";
    string s_log="";
    if(me->query_level()<10)
	s += "��ȡʧ�ܣ�10��������Ҳ�����ȡ\n";
    else if(me->get_once_day["hongbao"])
	s += "��ȡʧ�ܣ��������Ѿ���ȡ�ˣ�����������\n";
    else{
    	object hb;
	mixed err = catch{
	    hb = clone(ITEM_PATH+"baoxiang/hongbao");
	};
	if(!err && hb){
	    string now=ctime(time());
	    s += "��ȡ�ɹ���������"+hb->query_short()+"\n";
	    s_log += me->query_name_cn()+"("+me->query_name()+") get "+hb->query_short()+"("+hb->query_name()+")\n";
	    Stdio.append_file(ROOT+"/log/get_gift.log",now[0..sizeof(now)-2]+":"+s_log);
	    me->get_once_day["hongbao"] = 1;
	    hb->move(me);
	}
    }
    s += "\n[������Ϸ:look]\n";
    write(s);
    return 1;
}
