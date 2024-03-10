#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "";
	string item_name = "";
	string baoshi_name = "";
	int flag = 0;
	int count = 0;
	string s_log = "";
	sscanf(arg,"%s %d %d %s",item_name,count,flag,baoshi_name);
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
	int xq_flag = 1;
	//�б�ʯҲ��װ��,
	string color = baoshi->query_color();//��ñ�ʯ��ɫ
	string color_cn = baoshi->query_color_cn(color);//��ñ�ʯ��ɫ������������
	//werror("--------name="+baoshi->query_name()+"--color="+color+"--color_cn="+color_cn+"-\n");
	string baoshi_name_cn = baoshi->query_name_cn();
	string item_name_cn = item->query_name_cn();
	if(baoshi_name=="pshuangshuiyu"||baoshi_name=="slhuangshuiyu"||baoshi_name=="jinghuangshuiyu"){
		int shuiyu_num = me->query_baoshi_xiangqian_num("pshuangshuiyu",0)+me->query_baoshi_xiangqian_num("slhuangshuiyu",0)+me->query_baoshi_xiangqian_num("jinghuangshuiyu",0);
		if(shuiyu_num>=4){
			s += "ÿ��������ֻ����Ƕ4�Ż�ˮ�񣨰���������ˮ�����ػ�ˮ��͡�������ˮ��\n";
			xq_flag = 0;
		}
	}
	if(!xq_flag){
		s += "[����:equip_xiangqian_list]\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	if(flag==0){
		//�г�Ҫ��Ƕ�ı�ʯ�������Ϣ
		
		s += baoshi_name_cn+"\n";
		s += baoshi->query_picture_url()+"\n";
		s += "��Ӧ"+color_cn+"���\n";
		s += baoshi->query_desc()+"\n";
		s += "\n";
		s += "[��Ƕ:equip_xiangqian_confirm "+item_name+" "+count+" 1 "+baoshi_name+"]\n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else if(flag==1){
		//û�����Ӧ�İ���
		if(!item->query_if_aocao(color)){
			s += baoshi_name_cn+"Ϊ"+color_cn+"��ʯ,������"+color_cn+"���۲�����Ƕ���뷵��\n";
		}
		//�����Ӧ�İ���
		else{
			int num = item->query_aocao(color);//��ø���Ʒ���п��е�colorָ������ɫ���۵�����
			//ȫ�������Ѿ���Ƕ�˱�ʯ
			if(!num||num<1){
				array(object) all_baoshi = item->query_baoshi(color);
				if(all_baoshi&&sizeof(all_baoshi)){
					for(int i=0;i<sizeof(all_baoshi);i++){
						s += all_baoshi[i]->query_name_cn()+"("+(all_baoshi[i]->query_desc()-"\n")+") [�滻:equip_xiangqian_change "+item_name+" "+baoshi_name+" "+count+" "+i+" 0]\n";
					}
				}
				me->write_view(WAP_VIEWD["/emote"],0,0,s);
				return 1;
			}
			//�п��еİ���
			//string baoshi_path = file_name(baoshi)-ITEM_PATH;
			//baoshi_path = (baoshi_path/"#")[0];//��ñ�ʯ���ļ�·������baoshi/pshongchuoshi
			item->set_baoshi(color,baoshi);//��װ������ӱ�ʯ�ֶ�
			item->set_aocao(color,num-1);//��װ������һ�����Ӧ��ɫ�İ���
			me->remove_combine_item(baoshi->query_name(),1);//�۳���ʯ
			s += "����"+item_name_cn+"�ϳɹ���Ƕ��"+baoshi_name_cn+"\n";
		}
	}
	s += "[����:popview]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
