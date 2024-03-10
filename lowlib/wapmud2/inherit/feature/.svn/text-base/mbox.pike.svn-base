#include <sys_config.h>
#define MBOX_SIZE 12
array(array) inbox=({});//({from,from_cn,to,to_cn,subject,body,read_flag})
int have_new_mail;
string msg_history;
#define FROM 0
#define FROM_CN 1
#define TO 2
#define TO_CN 3
#define SUBJECT 4
#define BODY 5
#define READ_FLAG 6
void clean_mail_box_all()
{
	inbox=({});
	have_new_mail = 0;
}
string view_new_mail_info()
{
	if(inbox==0)
		inbox=({});
	if(sizeof(inbox)>=MBOX_SIZE*8/10){
		return "[邮箱将满:mailbox]";
	}
	else if(sizeof(inbox)>=MBOX_SIZE){
		return "[邮箱已满，新信件将丢失:mailbox]";
	}
	else if(have_new_mail){
		return "[有新信件:mailbox]";
	}
	return "";
}
string view_inbox_full_info()
{
	if(sizeof(inbox)>=MBOX_SIZE*8/10){
		return "[邮箱将满:mailbox]";
	}
	else if(sizeof(inbox)>=MBOX_SIZE){
		return "[邮箱已满，新信件将丢失:mailbox]";
	}
	return "";
}
int recieve_mail(string from,string from_cn,string to,string to_cn,string subject,string body)
{
	if(inbox==0)
		inbox=({});
	if(sizeof(inbox)>MBOX_SIZE){
		return 0;
	}
	inbox=({({from,from_cn,to,to_cn,subject,body,0})})+inbox;
	string now=ctime(time());
    Stdio.append_file(ROOT+"/log/mail.log",now[0..sizeof(now)-2]+":"+from_cn+"("+to_cn+"):"+subject+":"+body+"\n");
	have_new_mail++;
	return 1;
}
string view_mail_list()
{
	if(inbox==0)
		inbox=({});
	string out="";
	for(int i=0;i<sizeof(inbox);i++){
		array a=inbox[i];
		//out+=a[FROM_CN]+"："+a[SUBJECT]+"\n";
		out+="发信人："+a[FROM_CN]+"\n";
		out+="标题："+a[SUBJECT]+"\n";
		if(a[READ_FLAG]==0){
			out+="(新)";
		}
		out+="[阅读:mailbox_read "+i+"] [删除:mailbox_delete "+i+"]\n";
	}
	if(out=="")
		return "你没有任何信件。";
	else
		out = "[清空邮箱:delete_all_mail]\n"+out; 
	return out;
}
string view_mail(int n)
{
	if(inbox==0)
		inbox=({});
	if(inbox[n][READ_FLAG]==0){
		inbox[n][READ_FLAG]=1;
		have_new_mail=0;
		foreach(inbox,array a){
			if(a[READ_FLAG]==0)
				have_new_mail++;
		}
	}
	string add="";
	if(inbox[n][FROM]!="CHAT"){
		//add="[回信:mailbox_compose "+inbox[n][FROM]+"]\n[加入永久屏蔽列表:blacklist "+inbox[n][FROM]+" -add 1]";
		add="[回信:mailbox_compose "+inbox[n][FROM]+"] [删除:mailbox_delete "+n+"]\n[加入永久屏蔽列表:blacklist "+inbox[n][FROM]+" -add 1]";
	}
	//return "发信人："+inbox[n][FROM_CN]+"\n收信人："+inbox[n][TO_CN]+"\n标题："+inbox[n][SUBJECT]+"\n"+inbox[n][BODY]+"\n"+add+"\n";
	return "发信人："+inbox[n][FROM_CN]+"\n标题："+inbox[n][SUBJECT]+"\n"+inbox[n][BODY]+"\n"+add+"\n";
}
void delete_mail(int n)
{
	if(inbox==0)
		inbox=({});
	inbox=a_delete(inbox,n);
	have_new_mail=0;
	foreach(inbox,array a){
		if(a[READ_FLAG]==0)
			have_new_mail++;
	}
}
