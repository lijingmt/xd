#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
#define ROOM_PATH ROOT "/gamelib/d/"
//���͵��ߴ��͵�ָ���Ĵ�����
//arg = transfer_name count to_name yushi_type need_num
//to_name Ŀ�ĵط���
//yushi_type ��Ҫ���ĵ���ʯ����
//need_num ��Ҫ���ĵ���ʯ��
int main(string arg)
{
    object me = this_player();
    string transfer_name="";
    string to_name = "";
    int count = 0;
    int yushi_type = 0;
    int need_num = 0;
    string s = "";
    string s_log = "";
    sscanf(arg,"%s %d %s %d %d",transfer_name,count,to_name,yushi_type,need_num);
    object transfer = present(transfer_name,me,count);
    if(transfer)
    {
	int have_num = YUSHID->query_yushi_num(me,yushi_type);
	string yushi_name = YUSHID->get_yushi_name(yushi_type);
	if(!have_num || have_num < need_num || yushi_name == ""){
	    s += "����ʧ�ܣ���û���㹻����ʯ��\n";
	    s += "\n[����:inventory_daoju]\n";
	    s += "[������Ϸ:look]\n";
	    write(s);
	    return 1;
	}
	string path = ROOM_PATH+to_name;
	mixed err = catch{
	    me->move(path);
	};
	if(!err)
	    me->remove_combine_item(yushi_name,need_num);
	me->reset_view();
	me->command("look");
	return 1;
    }
    else
	s += "������û�������Ʒ��\n";
    s += "\n[����:inventory_daoju]\n";
    s += "[������Ϸ:look]\n";
    write(s);
    return 1;
}
