#include <command.h>
#include <gamelib/include/gamelib.h>
//��ָ���г�������Ͽɹ�����ת����װ���б�
int main(string arg)
{
	object me = this_player();
	string s = "";
	string s_log = "";
	string item_name = "";
	string baoshi_name = "";
	int id = 0;//ԭ����ʯ��Ƕ��λ��
	int flag = 0;
	int count = 0;
	sscanf(arg,"%s %s %d %d %d",item_name,baoshi_name,count,id,flag);
	if(flag==0){
		s += "���Ĳ�������ݻ�ԭ�����۵ı�ʯ, ����Ƕ�µı�ʯ,��ȷ��Ҫ��Ƕô?\n";
		s += "[ע��]2009��2��24��ǰ��ˮ��ϵ�б�ʯ���ᱻ�ݻ�\n";
		s += "[ȷ��:equip_xiangqian_change "+item_name+" "+baoshi_name+" "+count+" "+id+" 1]\n";
		s += "[��������:look]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	if(flag==1){
		object baoshi = present(baoshi_name,me,0);
		object item = present(item_name,me,count);
		//û�����Ӧ�ı�ʯ
		if(!baoshi){
			s += "��û�������ı�ʯ���뷵��\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		//û��װ��
		if(!item){
			s += "��ѡ��Ҫ��Ƕ��ʯ����Ʒ�����ڣ��뷵��\n";
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		//�б�ʯҲ��װ��,
		string color = baoshi->query_color();//��ñ�ʯ��ɫ
		string color_cn = baoshi->query_color_cn();//��ñ�ʯ��ɫ������������
		string baoshi_name_cn = baoshi->query_name_cn();
		string item_name_cn = item->query_name_cn();
		//werror("----id="+id+"----\n");
		string old_bsh_nm = item->query_baoshi_by_id(color,id);//Ҫ�滻�ı�ʯ������
		if(old_bsh_nm!=""){
			object old_baoshi;
			string s_log;
			mixed err=catch{
				old_baoshi=clone(ITEM_PATH+old_bsh_nm);
			};
			if(!err&&old_baoshi){
				string old_baoshi_name = old_baoshi->query_short();
				if(old_baoshi->query_name()=="pshuangshuiyu"||old_baoshi->query_name()=="slhuangshuiyu"||old_baoshi->query_name()=="jinghuangshuiyu"||old_baoshi->query_name()=="nianshoulingshi"||old_baoshi->query_name()=="nianshoulingshi2"||old_baoshi->query_name()=="nianshoulingshi3"){
					s += old_baoshi->query_short()+"�ѷŵ����ı�����\n";
					old_baoshi->move_player(me->query_name());
				}
				item->set_baoshi(color,baoshi,id+1);//��װ������ӱ�ʯ�ֶ�,�滻��ʯ��λ�ô�1��ʼ����Ϊid=0���ʱ��ʾֱ����Ƕ��ʯ�������滻
				me->remove_combine_item(baoshi->query_name(),1);//�۳���ʯ
				s += "����"+item_name_cn+"�ϳɹ���Ƕ��"+baoshi_name_cn+"\n";
				s_log = me->query_name_cn()+"("+me->query_name()+")��"+baoshi_name_cn+"�滻"+old_baoshi_name+"\n";
				string now=ctime(time());
				Stdio.append_file(ROOT+"/log/xiangqian_change.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
			}
		}
		else{
			s += "ϵͳ���ˣ�����ͷ���ϵ\n";
			string s_log = me->query_name_cn()+"("+me->query_name()+")��"+baoshi_name_cn+"�滻����\n";
			string now=ctime(time());
			Stdio.append_file(ROOT+"/log/xiangqian_change_error.log",now[0..sizeof(now)-2]+":"+s_log+"\n");
		}
	}
	s += "[����:popview]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
