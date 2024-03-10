#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	int sale_id = 0;
	string gd_str = "";
	string sv_str = "";
	string s_rtn = "";
	sscanf(arg,"%d %s %s",sale_id,gd_str,sv_str);
	//sscanf(arg,"%d %s %s",sale_id,sv_str,gd_str);
	int gd_num = 0;
	int sv_num = 0;
	sscanf(gd_str,"gd=%d",gd_num);
	sscanf(sv_str,"sv=%d",sv_num);
	
	/*werror("========= [arg]="+arg +" ==========\n");
	werror("========= [gd_str]="+gd_str +" ==========\n");
	werror("========= [sv_str]="+sv_str +" ==========\n");
	werror("========= [sv_num]="+sv_num +" ==========\n");
	werror("========= [sv_num]="+sv_num +" ==========\n");
	*/
	
	if(gd_num<0 || sv_num<0){
		s_rtn +="���۸�����������ʵ�ˣ���������ȷ�ľ���\n";
	}
	else if(gd_num==0 && sv_num==0){
		s_rtn +="���Ͽɲ������ѵ��ձ�~����������ľ���\n";
	}
	else{
		mapping(string:mixed) sale_info = AUCTIOND->query_sale_info(sale_id);
		object ob = clone(sale_info["goods_filename"]);
		int cur_value = (int)sale_info["cur_value"];
		int end_value = (int)sale_info["end_value"];
		int now_value = gd_num*100 + sv_num;
		//11111������Ҫ����������Ǯ�Ƿ��㹻���ж�
		if(now_value>this_player()->query_account())
			s_rtn += "������û����ô��Ǯ~����׬��Ǯ���������԰�\n";
		//�Ƚ�����ľ����뵱ǰ�ۣ�����������ʾ�û�
		else if(now_value<=cur_value)
			s_rtn +="��ľ���һ��Ҫ���ڵ�ǰ�ۣ��ٿ���Щ��~�ⶫ��Ҳ����������\n";
		else{
			//Ҫ������ľ��۵��ڻ��߸���һ�ڼۣ���ֱ��ʤ������
			if(end_value && now_value>=end_value){
				if(!AUCTIOND->reset_sale_info(this_player(),sale_id,now_value,1))
					s_rtn += "�������Ѿ�������\n";
				else{
					//�۳���Ҿ��۵ķ���
					this_player()->del_account(now_value);
					s_rtn +="��ľ��۳�����һ�ڼۣ���ϲ�㣬��Ӯ���˶�"+ob->query_name_cn()+"�ľ���\n";
					s_rtn +="�뼰ʱ��ȡ�����Ʒ��7��������Щδ�������Ʒ���ǽ�һ�ɻ��գ��Խ�����ڷǳ�ʱ�ڵ���Դ��ȱ����\n";
				}
			}
			else if(this_player()->query_name()==sale_info["winner_id"])
				s_rtn +="��Ŀǰ���ǵ�ǰ��߾����ˣ������˷�Ǯ�ƣ����ĵȵȰ�\n";
			else{
				if(!AUCTIOND->reset_sale_info(this_player(),sale_id,now_value,0))
					s_rtn = "�������Ѿ�������\n";
				else{
					//�۳���Ҿ��۵ķ���
					this_player()->del_account(now_value);
					string value_str = MUD_MONEYD->query_other_money_cn(now_value);
					s_rtn +="�㵱ǰ��"+ob->query_name_cn()+"�ĳ���Ϊ"+value_str+"\n";
				}
			}
		}
	}
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,s_rtn);
	return 1;
}




