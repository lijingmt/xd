#include <command.h>
#include <gamelib/include/gamelib.h>
//把公告信息写入到内存中

int main(string arg)
{
	object me = this_player();
	string s = "";
	string title = "";
	string text = "";
	string text1 = "";
	string text2 = "";
	string text3 = "";
	string text4 = "";
	string text5 = "";
	string head = "";
	string nr1 = "";
	string nr2 = "";
	string nr3 = "";
	string nr4 = "";
	string nr5 = "";
	int id = 0;
	string s_log = "";
	//werror("-----arg="+arg+"--\n");
	//sscanf(arg,"%s %s %s %s %s %s %d",title,nr1,nr2,nr3,nr4,nr5,id);
	if(sscanf(arg,"%d %s %s %s %s %s %s",id,nr1,nr2,title,nr5,nr4,nr3)!=7)  //在不同服务器上的参数传递顺序有可能不同，可根据实际情况作调整
		sscanf(arg,"%s %s %s %s %s %s",nr1,nr2,title,nr5,nr4,nr3);
	sscanf(title,"tt=%s",head);
	sscanf(nr1,"c1=%s",text1);
	sscanf(nr2,"c2=%s",text2);
	sscanf(nr5,"c5=%s",text5);
	sscanf(nr4,"c4=%s",text4);
	sscanf(nr3,"c3=%s",text3);
	text += text1+"\n"+text2+"\n"+text3+"\n"+text4+"\n"+text5;
	//werror("---------id="+id+"---------------\n");
	array(string) msg = ({});
	msg += ({GAME_NAME_S}); 
	msg += ({me->query_name()});
	msg += ({me->query_name_cn()});
	msg += ({head});
	msg += ({text});
	if(id){
	//修改公告
		int a = MSGD->msg_rewrite(msg,id);
		if(a==2)
			s += "该公告不存在\n";
		else if(a==1){
			s += "修改成功\n";
			MSGD->write_file();
		}
		else if(a==0)
			s += "修改失败\n";
		s += "\n[返回:popview]\n";
		s += "[返回游戏:look]\n";
		write(s);
		return 1;
	}
	//werror("-----head="+head+"-----text="+text+"-----------------------\n");
	if(MSGD->msg_send(msg)){
		s += "添加公告成功\n";
		MSGD->write_file();
	}
	else {
		s += "可能是系统问题，请与技术联系。\n";
	}
	s += "\n[返回:popview]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
