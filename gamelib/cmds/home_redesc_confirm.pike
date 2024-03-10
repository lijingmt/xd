//用户修改家园的描述
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
			s += "你不能使用那样奇怪的描述。\n"; 
			s += "[返回:home_myzone]\n";
			write(s);
			return 1;
		}
		else if(sizeof(p_name)>16){
			s += "描述长度不能超过八个中文汉字。\n"; 
			s += "[返回:home_myzone]\n";
			write(s);
			return 1;
		}
		else{                                                                                                           
			for(int i=0;i<sizeof(p_name);i++){
				if(p_name[i]>=0&&p_name[i]<=127){
					if(p_name[i]>='a'&&p_name[i]<='z'||p_name[i]>='A'&&p_name[i]<='Z'||p_name[i]>='0'&&p_name[i]<='9'){
					}
					else{ 
						s += "请使用中文、英文字母或者数字。\n";     
						s += "[返回:home_myzone]\n";
						write(s);
						return 1; 
					}
				}
			}
			p_name = HOMED->reset_home_desc(p_name);
			s += "恭喜，你的家园描述已经修改为:"+p_name+"\n";
			s += "[返回:look]\n";
			write(s);
			return 1;
		}
	}
	else{
		s += "描述长度不能少于1个英文字符,且不要使用数字、字母和汉字以外的字符。\n";
		s += "[返回:home_myzone]\n";
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
