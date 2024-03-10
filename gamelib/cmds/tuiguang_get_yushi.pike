#include <command.h>
#include <gamelib/include/gamelib.h>
#define YUSHI_PATH ROOT "/gamelib/clone/item/yushi/"
//-��������ʯ-�ƹ��������ʯ�ķ�����

int main(string arg)
{
	object me = this_player();
	object yushi;
	string s_log = "";
	int yushi_num = (int)arg;
	string yushi_type = "suiyu";
	string yushi_type_cn = "����";
	string now = ctime(time());
	int level = me->query_level();
	int yushi_flag= me->query_yushi_flag();
	string desc="";

	int n = level/5;

	if(yushi_flag<5*n)
	{
		if(yushi_num>=20)
		{
			yushi_type = "xianyuanyu";
			yushi_num = yushi_num/10;
			yushi_type_cn = "��Ե��";
		}
		mixed err=catch{
			yushi = clone(YUSHI_PATH+yushi_type);
		};
		if(!err && yushi){
			yushi->amount = yushi_num;
			if(!me->if_over_load(yushi))
			{
				yushi->move_player(me->query_name());
				me->set_yushi_flag(5*n);
				desc += "��ϲ!���Ѿ����"+yushi_num+"��"+yushi_type_cn+"\n";
				s_log = me->query_name_cn()+"("+me->query_name()+") ��������ʯ���"+yushi_type_cn+yushi_num+"��\n";
				Stdio.append_file(ROOT+"/log/fee_log/yushi_tuiguang.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
			else{
				desc += "��ı�����������ȡ��ʯʧ�ܡ�\n";
			}
		}
		else{
			s_log = me->query_name_cn()+"("+me->query_name()+") tuiguang_yushi error! ��������ʯʱ�޷������Ʒ\n";
			Stdio.append_file(ROOT+"/log/fee_log/yushi_tuiguang_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
		}
	}
	else
	{
		desc +="���Ѿ���ȡ����ʯ���뷵����Ϸ��\n";
	}
	desc += "[������Ϸ:look]\n";
	write(desc);
	return 1;
}
