#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "开帮立派:\n(请注意，一切与政治，粗口，非法字符相关的帮派名，一律删无赦)\n";
	int level = 0;
	object ob = present("kaibanglingpai",me,0);//检查玩家身上是否有开帮令牌
	if(!ob){
		s += "很抱歉,您没有\"开帮令牌\"，不能建帮立派，请准备好再来吧.\n";
	}
	else if(me->query_level()<35){
		s += "开帮立派需要35级以上，你再努把力吧\n";
	}
	else if(!YUSHID->have_enough_yushi(me,100)){
		s += "玉石数量不足, 不能建立帮派. 请准备好了再来吧!\n";
		s += "\n\n";
		s += "[直接捐赠:add_szx_fee]\n";
	}
	else if(me->query_account()<100000){
		s += "开帮需要1000金，你身上钱不够\n";
	}
	else if(me->bangid != 0){
		s += "你已经在另一个帮派里了，无法开帮立派\n";
	}
	else if(arg && sizeof(arg)>0 && sizeof(arg)<12){
		arg = filter_msg(arg);
		int be = BANGD->create_bang(me,arg);
		//create_bang()返回 1：建立成功
		//                  0：建立失败
		//                  2：你已经在另一个帮会里了
		if(be == 1){
			string now = ctime(time());
			me->del_account(100000);
			int del_yushi = YUSHID->give_yushi(me,100);
			me->remove_combine_item("kaibanglingpai",1);
			s += "恭喜您! \n";
			s += "你建立了帮派<"+arg+">:\n";
			s += "你作为帮主，可以在 我的帮派->管理帮派 里修改你的帮公告，帮简介，帮派等级称谓\n";
			Stdio.append_file(ROOT+"/log/bang.log",now[0..sizeof(now)-2]+":"+me->query_name_cn()+"("+me->query_name()+"):建立了帮派<"+arg+">\n");
		}
		else if(be == 0){
			s += "你的输入有问题或者此帮派名已被申请，请重新更换名称后再试试\n";
			s += "请输入帮派名称:\n";
			s += "[bang_create ...]\n";
		}
		else if(be == 2){
			s += "你已经在另一个帮派里了，无法开帮立派\n";
		}
	}
	else{
		s += "请输入帮派名称(不能多于6个字):\n";
		s += "[bang_create ...]\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
string filter_msg(string arg)
{
	if(!arg)
		return "";
	arg=replace(arg,"'","‘");
	arg=replace(arg,",","，");
	arg=replace(arg,".","。");
	arg=replace(arg,"@","。");
	arg=replace(arg,"#","。");
	arg=replace(arg,"%","。");
	arg=replace(arg,"~","。");
	arg=replace(arg,"^","。");
	arg=replace(arg,"$","。");
	arg=replace(arg,"+","。");
	arg=replace(arg,"|","。");
	arg=replace(arg,"&","。");
	arg=replace(arg,"=","＝");
	arg=replace(arg,"(","（");
	arg=replace(arg,")","）");
	arg=replace(arg,"-","－");
	arg=replace(arg,"_","－");
	arg=replace(arg,"*","－");
	arg=replace(arg,"?","？");
	arg=replace(arg,"!","！");
	arg=replace(arg,"<","－");
	arg=replace(arg,">","－");
	arg=replace(arg,"\/","“");
	arg=replace(arg,"\"","“");
	arg=replace(arg,"\\","“");
	arg=replace(arg,"\r\n","");
	arg=replace(arg,":","：");
	arg=replace(arg,";","；");
	arg=replace(arg,"\{","「");
	arg=replace(arg,"\}","「");
	arg=replace(arg,"[","「");
	arg=replace(arg,"]","」");
	arg=replace(arg,"%20","－");	
	return arg;
}
