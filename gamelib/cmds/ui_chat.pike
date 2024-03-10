#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
		werror("ui_chat begin\n");
	if(arg){

		if(search(arg," ")!=-1) {//?????????????2???????
			array(string) t=arg/" ";
			if(sizeof(t)==2&&t[0]==t[1]){
				arg=t[0];
			}
		} 
		//by calvin 2007-08-31
		werror("ui_chat original="+arg+"\n");
        arg = TIPSD->check_words(arg);
		werror("ui_chat check_words="+arg+"\n");
		arg = filter_msg(arg);
		werror("ui_chat filter_msg="+arg+"\n");
		if(sizeof(arg) > 40)
			arg = arg[0..39];
		werror("ui_chat cat="+arg+"\n");
		//arg = filter_msg(arg);
		string content = "";
		if(me->roomchatid=="pub"){ 
			content = me->query_name()+"|["+me->query_name_cn()+":ui_char "+me->query_name()+"]£º"+arg;
		werror("ui_chat content="+arg+"\n");
			if(me->query_raceId()=="human")
				CHATROOMD->add_chat_msg("pub_channel",content);
			else if(me->query_raceId()=="monst")
				CHATROOM2D->add_chat_msg("pub_channel",content);
		}
		else if(me->roomchatid=="sale"){ 
			content = me->query_name()+"|["+me->query_name_cn()+":ui_char "+me->query_name()+"]£º"+arg;
			if(me->query_raceId()=="human")
				CHATROOMD->add_chat_msg("sales_channel",content);
			else if(me->query_raceId()=="monst")
				CHATROOM2D->add_chat_msg("sales_channel",content);
		}
		else if(me->roomchatid=="term"){ 
			content = me->query_name_cn()+"£º"+arg;
			TERMD->add_termChat(me->query_term(),content);
		}
		else if(me->roomchatid=="bang"){
			content = me->query_name_cn()+"£º"+arg;
			BANGD->add_ui_chat(me->bangid,content);
		}
		string record_s = "";
		string now=ctime(time());
		record_s += now[0..sizeof(now)-2]+"|";
		record_s += content;
		Stdio.append_file(ROOT+"/log/chat_msg.log",record_s+"\n");
	}
	me->command("look");
	return 1;
}
string filter_msg(string arg)
{
	if(!arg)
		return "";
	arg=replace(arg,"'","¡®");
	arg=replace(arg,",","£¬");
	arg=replace(arg,".","¡£");
	arg=replace(arg,"@","¡£");
	arg=replace(arg,"#","¡£");
	arg=replace(arg,"%","¡£");
	arg=replace(arg,"~","¡£");
	arg=replace(arg,"^","¡£");
	arg=replace(arg,"$","¡£");
	arg=replace(arg,"+","¡£");
	arg=replace(arg,"|","¡£");
	arg=replace(arg,"&","¡£");
	arg=replace(arg,"=","£½");
	arg=replace(arg,"(","£¨");
	arg=replace(arg,")","£©");
	arg=replace(arg,"-","£­");
	arg=replace(arg,"_","£­");
	arg=replace(arg,"*","£­");
	arg=replace(arg,"?","£¿");
	arg=replace(arg,"!","£¡");
	arg=replace(arg,"<","£­");
	arg=replace(arg,">","£­");
	arg=replace(arg,"\/","¡°");
	arg=replace(arg,"\"","¡°");
	arg=replace(arg,"\\","¡°");
	arg=replace(arg,"\r\n","");
	arg=replace(arg,":","£º");
	arg=replace(arg,";","£»");
	arg=replace(arg,"\{","¡¸");
	arg=replace(arg,"\}","¡¸");
	arg=replace(arg,"[","¡¸");
	arg=replace(arg,"]","¡¹");
	arg=replace(arg,"%20","£­");	
	return arg;
}
