//�û��޸ļ�԰������
#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	string p_name = "";
	arg=replace(arg,(["%20":""]));                                                                                  
	sscanf(arg,"na=%s",p_name);
	p_name = filter_msg(p_name);
	if(p_name !=""){
		if(NAMESD->is_name_reserved(p_name)){                                                                         
			s += "�㲻��ȡ������ֵ����֡�\n"; 
			s += "[����:home_myzone]\n";
			write(s);
			return 1;
		}
		else if(sizeof(p_name)>12){
			s += "���ֳ��Ȳ��ܳ����������ĺ��֡�\n"; 
			s += "[����:home_myzone]\n";
			write(s);
			return 1;
		}
		else{                                                                                                           
			for(int i=0;i<sizeof(p_name);i++){
				if(p_name[i]>=0&&p_name[i]<=127){
					if(p_name[i]>='a'&&p_name[i]<='z'||p_name[i]>='A'&&p_name[i]<='Z'||p_name[i]>='0'&&p_name[i]<='9'){
					}
					else{ 
						s += "��ʹ�����ġ�Ӣ����ĸ��������ȡ����\n";     
						s += "[����:home_myzone]\n";
						write(s);
						return 1; 
					}
				}
			}
			p_name = HOMED->reset_home_name(p_name);
			s += "��ϲ����ļ�԰�ѱ�����Ϊ:"+p_name+"\n";
			s += "[����:look]\n";
			write(s);
			return 1;
		}
	}
	else{
		s += "���ֳ��Ȳ�������1��Ӣ���ַ�,�Ҳ�Ҫʹ�����֡���ĸ�ͺ���������ַ���\n";
		s += "[����:home_myzone]\n";
		write(s);

	}
}

string filter_msg(string arg)
{
	if(!arg)
		return "";
	arg=replace(arg,"'","");
	arg=replace(arg,",","");
	arg=replace(arg,".","");
	arg=replace(arg,"@","");
	arg=replace(arg,"#","");
	arg=replace(arg,"%","");
	arg=replace(arg,"~","");
	arg=replace(arg,"^","");
	arg=replace(arg,"$","");
	arg=replace(arg,"+","");
	arg=replace(arg,"|","");
	arg=replace(arg,"&","");
	arg=replace(arg,"=","");
	arg=replace(arg,"(","");
	arg=replace(arg,")","");
	arg=replace(arg,"-","");
	arg=replace(arg,"_","");
	arg=replace(arg,"*","");
	arg=replace(arg,"?","");
	arg=replace(arg,"!","");
	arg=replace(arg,"<","");
	arg=replace(arg,">","");
	arg=replace(arg,"\/","");
	arg=replace(arg,"\"","");
	arg=replace(arg,"\\","");
	arg=replace(arg,"\r\n","");
	arg=replace(arg,":","");
	arg=replace(arg,";","");
	arg=replace(arg,"\{","");
	arg=replace(arg,"\}","");
	arg=replace(arg,"[","");
	arg=replace(arg,"]","");
	arg=replace(arg,"%20","");	
	return arg;
}
