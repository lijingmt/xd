/**                                                                                                                          
 * �ṩ�޸�ͨ���Ĺ���
 * @author jess
 * @date 19/04/2007
 */

#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s="";
	string name = arg;
	int fe = 1;
	int remove_flag=0;

	if(sscanf(arg,"%s %d",name,fe)!=2){
		//s+="�������ֵ��ͨ����[string:txadd "+name+" ...]\n";
		s+="[��ֵ50Ԫ:txadd "+name+" 50]\n";
		s+="[��ֵ100Ԫ:txadd "+name+" 100]\n";
		s+="[��ֵ200Ԫ:txadd "+name+" 200]\n";
		s+="[��ֵ300Ԫ:txadd "+name+" 300]\n";
		s+="[��ֵ400Ԫ:txadd "+name+" 400]\n";
		s+="[��ֵ500Ԫ:txadd "+name+" 500]\n";
		s += "[�����ϼ�:mgr_usr_data "+name+"]\n";
		s += "[���ع���������:game_deal]\n";
		s+="[������Ϸ:look]\n";
		write("%s",s);
		return 1;
	}
	else{
		object player = find_player(name);
		if(!player)
		{
			player=this_player()->load_player(name);
			remove_flag=1;                                                                                      
		}
		if(!player && (remove_flag==1)){
			s += "û�������Ϸid����˶Ժ��ٲ顣\n";
			s += "[�����ϼ�:mgr_usr_data "+name+"]\n";
			s += "[���ع���������:game_deal]\n";
			s+="[������Ϸ:look]\n";
			write("%s",s);
			return 1;
		}
		if(player){
			string lgs = "�����ˣ�"+this_player()->name+"|"+this_player()->name_cn+"||||"+name+"|"+player->name_cn;//+"|��ǰͨ����"+player->query_tongbao()+"|";
			lgs += "|��ֵ��"+(fe)+"|\n";
			s = "�û�����"+name+"|��ֵ��"+fe;//+"|���û���ǰͨ��Ϊ��"+player->query_tongbao()+"\n";
			//player->command("wiz_add_fee "+name+" "+fe);
			
			////////////////////////////////////////////////////////////////////////
			player->command("yushi_add_fee "+fe+" 2 szx");	
			////////////////////////////////////////////////////////////////////////
			
			//lgs += "|���ͨ����"+player->query_tongbao()+"\n";
			s += "�û�����"+name+"|��ֵ��"+fe;//+"|���û���ֵ��ͨ��Ϊ��"+player->query_tongbao()+"\n";
			mapping now_time = localtime(time());
			string now = ctime(time());
			int year = now_time["year"] + 1900;
			int mon = now_time["mon"]+1;                                               
			Stdio.append_file(ROOT+"/log/manage_addfee.log",now[0..sizeof(now)-2]+"|"+lgs);
			//s += "ͨ���� "+(fe*10)+" ��ֵ�ɹ����뷵�ء�\n";
			s += "��ֵ�ɹ����뷵�ء�\n";
			player->command("save");
		}
		if(remove_flag){
			//player->remove();	
			//ɾ���ǿ϶��ģ�����Ҫʹ��remove������ֱ��ɾ������
			player->net_dead();
		}
	}
	s += "[����:mgr_usr_data "+name+"]\n";
	s += "[���ع���������:game_deal]\n";
	s += "[������Ϸ:look]\n";
	write("%s",s);
	return 1;
}
